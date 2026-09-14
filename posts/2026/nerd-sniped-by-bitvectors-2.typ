#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Nerd sniped by bit vectors again])
#metadata((
  title: "Nerd sniped by bit vectors again",
  kind: "post",
  date: "2026-09-11",
  tags: ("programming", "rust", "optimization"),
  summary: "compilers are weird",
)) <website-metadata>

#title()

Remember that some guy mentioned he'd been #link("nerd-sniped-by-bitvectors.html")[nerd-sniped by
bit vectors]. Let's have another go. We'll spend a bit of time optimizing bit vector unpacking and
start with the simple implementation.

```rust
pub fn unpack_bits(src: &[u8], count: usize) -> Vec<bool> {
    let mut result = vec![false; count];
    let src = &src[..count.div_ceil(8)];
    for (ind, dst) in result.iter_mut().enumerate() {
        let source_byte = ind.div_euclid(8);
        let source_bit = 7 - ind.rem_euclid(8);
        let byte = src[source_byte];
        *dst = byte & (1 << source_bit) != 0;
    }
    result
}
```

Benchmarking this implementation with `criterion` across output sizes ranging from a handful of bytes up to the order of an L2 cache gives:

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Elements / s*]),
  [7 B], [602 Melem/s],
  [64 B], [2.32 Gelem/s],
  [512 B], [2.43 Gelem/s],
  [4 KiB], [2.65 Gelem/s],
  [32 KiB], [2.62 Gelem/s],
  [256 KiB], [2.65 Gelem/s],
  [1 MiB], [2.62 Gelem/s],
  [4 MiB], [2.64 Gelem/s],
)

Looking at the disassembly#footnote[AArch64, `-O -C target-cpu=native`] for the inner 
loop is instructive, particularly around bounds checking:

```
        add   x8, x19, #7          ; x8 = count + 7
        lsr   x1, x8, #3            ; x1 = (count + 7) >> 3  = count.div_ceil(8), i.e. len of the resliced `src`
        cmp   x1, x23                ; compare against the *original* src.len() (x23)
        b.hi  LBB0_9                  ; bounds check #1: panics (slice_index_fail) if src is too short for `&src[..count.div_ceil(8)]`
        mov   x8, #0                  ; ind = 0
        mov   w9, #7                  ; constant 0b111, reused every iteration below
LBB0_5:                               ; ---- inner loop: one bool produced per iteration ----
        lsr   x0, x8, #3               ; source_byte = ind >> 3        (ind.div_euclid(8): division by a power of two folds to a shift)
        cmp   x0, x1
        b.hs  LBB0_10                   ; bounds check #2: re-checks source_byte < src.len() on EVERY iteration
        ldrb  w10, [x22, x0]             ; byte = src[source_byte]
        bic   w11, w9, w8                ; source_bit = 7 & !ind  = 7 - (ind & 7)  (LLVM fused the subtract+rem into one AND-NOT)
        lsr   w10, w10, w11               ; byte >> source_bit
        and   w10, w10, #0x1              ; mask to the low bit -> bool
        strb  w10, [x20, x8]               ; result[ind] = bit
        add   x8, x8, #1                    ; ind += 1
        cmp   x19, x8
        b.ne  LBB0_5                         ; loop while ind != count
```

Two things stand out:

- *Bounds check #1* (before the loop) is a good thing: it's the reslice `&src[..count.div_ceil(8)]` that
  ensures that the output bool count is compatible with the number of bytes we've got.
- *Bounds check #2*, inside the loop, is paid on *every single element*. It's redundant:
  `source_byte = ind / 8` for `ind < count` is always `< count.div_ceil(8) == src.len()` after the reslice above. 
  LLVM can't see that relationship through the ceiling division, so it inserts a `cmp` + conditional branch per bit unpacked anyway.
  While branches make or may not be predictable, the greater problem is that this has stopped LLVM from doing Deep Compiler Magic.

So let's go and make it clear to LLVM that it is safe to invoke the deep magic.

= Deep magic

What we'll do here is split our output into 8 byte chunks, each coming from one source byte. We can iterate along our output and our
source in lockstep, and we'll not need those pesky bounds checks.

```rust
fn unpack(byte: u8) -> [bool; 8] {
    std::array::from_fn(|ix| {
        let mask = 1_u8 << (7 - ix);
        byte & mask != 0
    })
}

pub fn unpack_bits(src: &[u8], count: usize) -> Vec<bool> {
    let mut result = vec![false; count];
    let src = &src[..count.div_ceil(8)];
    let (chunks, tail) = result.as_chunks_mut::<8>();
    for (chunk, src) in chunks.iter_mut().zip(src) {
        *chunk = unpack(*src)
    }

    if !tail.is_empty() {
        let last = src.last().expect("we must have a byte here");
        for (dst, src) in tail.iter_mut().zip(unpack(*last)) {
            *dst = src;
        }
    }
    result
}
```

Benchmarking this implementation with `criterion`, across the same output sizes as before:

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Elements / s*]),
  [7 B], [680 Melem/s],
  [64 B], [4.21 Gelem/s],
  [512 B], [9.82 Gelem/s],
  [4 KiB], [10.23 Gelem/s],
  [32 KiB], [10.15 Gelem/s],
  [256 KiB], [10.07 Gelem/s],
  [1 MiB], [10.37 Gelem/s],
  [4 MiB], [10.25 Gelem/s],
)

That's roughly 4x the throughput of the naive version once we're past the smallest sizes, and it holds steady out to the order
of an L2 cache. But we still aren't hitting 100 Gelem/s.

Disassembling shows why: LLVM did the deep magic. The single bounds check is now hoisted completely out of any loop,
and the body has been auto-vectorized with NEON into a loop that turns 16 source bytes into 128 output bools per iteration:

```
        ; -- one bounds check for the WHOLE call, done ONCE, before any loop runs --
        lsr   x9, x19, #3             ; x9 = count >> 3            (number of full 8-bool chunks)
        ands  x8, x19, #0x7            ; x8 = count & 7             (leftover tail bools, 0..7)
        cinc  x1, x9, ne                 ; x1 = x9 + (tail != 0)    = count.div_ceil(8) == src.len() needed
        cmp   x1, x23
        b.hi  LBB0_8                      ; panics (slice_index_fail) if src is too short -- and that's the only check in the whole function

        ; -- main loop: 16 source bytes -> 128 output bools per iteration, no bounds checks at all --
LBB0_13:
        ldr    q1, [x14], #16              ; load 16 bytes of src into a 128-bit NEON register, src ptr += 16
        ushr.16b v2, v1, #6                  ; take bit 6 of all 16 bytes at once ...
        and.16b  v2, v2, v0                   ; ... mask each down to a single 0/1 lane
        ushr.16b v3, v1, #5                    ; ... same trick again for bit 5
        and.16b  v3, v3, v0
        ; ... six more shift+mask pairs, one per remaining bit position (7 down to 0): LLVM
        ; has turned our scalar "one bool per iteration" loop into 8 parallel bit-plane
        ; extractions, each producing one bool per source byte
        ushll.8h v17, v16, #0                   ; then ~180 elided lines of ushll/shl/orr widen each
        ushll.4s v18, v17, #0                     ; 1-byte-per-source-byte bit-plane out to
        ...                                         ; 1-byte-per-*output-bool*, and interleave the 8
        ...                                         ; planes back together in the right bit order --
                                                      ; a SIMD "bit-plane transpose"
        stp    q19, q18, [x13, #96]                ; the 128 freshly-produced bools are written out
        stp    q20, q16, [x13, #64]                 ; as four 32-byte (256-bool... no, 32-bool) stores
        stp    q17, q6,  [x13, #32]
        stp    q3,  q1,  [x13], #128                 ; last store also advances dst ptr by 128 bytes
        subs   x15, x15, #16                          ; 16 more source bytes consumed
        b.ne   LBB0_13                                 ; loop while >= 16 source bytes remain
```

Below this, LLVM also emits a scaled-down 4-bytes-at-a-time NEON loop and a 1-byte-at-a-time NEON loop to mop up
whatever the 16-byte loop couldn't consume, and finally a straight-line, branch-per-bit sequence for the last partial
chunk (`< 8` bools) that corresponds directly to the `if !tail.is_empty()` arm in the Rust source -- all of it still
without a single per-element bounds check.

But LLVM chose poorly. It loaded a bunch of data and then vectorized in exactly the way it shouldn't have.

= Deep magic v2

Let's try and hint it into doing the Right Thing: come up with a sane vectorization axis ourselves and pray
that LLVM doesn't break it horribly.

```rust
trait Unpackable {
    type Output;
    fn unpack(&self) -> Self::Output;
}

impl Unpackable for [u8; 2] {
    type Output = [bool; 16];

    #[inline(always)]
    fn unpack(&self) -> Self::Output {
        let src: u16 = u16::from_be_bytes(*self);
        core::array::from_fn(|ix| {
            let mask = 1_u16 << (15 - ix);
            mask & src != 0
        })
    }
}

impl Unpackable for [u8; 1] {
    type Output = [bool; 8];

    #[inline(always)]
    fn unpack(&self) -> Self::Output {
        self[0].unpack()
    }
}

impl Unpackable for u8 {
    type Output = [bool; 8];

    #[inline(always)]
    fn unpack(&self) -> Self::Output {
        let src = *self;
        core::array::from_fn(|ix| {
            let mask = 1_u8 << (7 - ix);
            mask & src != 0
        })
    }
}

pub fn unpack_bits(src: &[u8], count: usize) -> Vec<bool> {
    let mut result = vec![false; count];
    let src = &src[..count.div_ceil(8)];

    const SOURCE_BYTES: usize = 2;
    const RESULT_BYTES: usize = 8 * SOURCE_BYTES;

    // first find the big chunks we can NEON

    let num_result_chunks = count.div_euclid(RESULT_BYTES);
    let (result_chunks, result_tail) = result.split_at_mut(RESULT_BYTES * num_result_chunks);
    let (source_chunks, source_tail) = src.split_at(SOURCE_BYTES * num_result_chunks);

    for (result_chunk, src_chunk) in result_chunks
        .as_chunks_mut::<RESULT_BYTES>()
        .0
        .iter_mut()
        .zip(source_chunks.as_chunks::<SOURCE_BYTES>().0)
    {
        *result_chunk = src_chunk.unpack()
    }

    // now the tail: individual bytes

    let num_result_bytes = result_tail.len().div_euclid(8);
    let (result_bytes, result_tail) = result_tail.split_at_mut(8 * num_result_bytes);
    let (source_bytes, _) = source_tail.split_at(num_result_bytes);

    for (result_chunk, source_byte) in result_bytes
        .as_chunks_mut::<8>()
        .0
        .iter_mut()
        .zip(source_bytes)
    {
        *result_chunk = source_byte.unpack();
    }

    if !result_tail.is_empty() {
        let last = src.last().expect("we must have a byte here");
        for (dst, src) in result_tail.iter_mut().zip(last.unpack()) {
            *dst = src;
        }
    }
    result
}
```

Benchmarking this implementation with `criterion`, across the same output sizes as before:

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Elements / s*]),
  [7 B], [701 Melem/s],
  [64 B], [5.49 Gelem/s],
  [512 B], [20.09 Gelem/s],
  [4 KiB], [34.52 Gelem/s],
  [32 KiB], [42.69 Gelem/s],
  [256 KiB], [45.15 Gelem/s],
  [1 MiB], [46.94 Gelem/s],
  [4 MiB], [45.77 Gelem/s],
)

Another 4x-plus on top of LLVM's attempt, and we're finally in shouting distance of that 100
Gelem/s figure -- steady in the mid-40 Gelem/s range from 32 KiB up.

On disassembling the result is obvious: the main loop is tiny compared to the previous sprawling
bit-plane transpose, because we only asked LLVM to vectorize *one* 2-byte chunk (16 bools)
at a time instead of leaving it to figure out how far to unroll on its own:

```
        ; -- setup: same single bounds check as always, plus splitting src/result into
        ;    "big 2-byte chunks" and a leftover tail, mirroring the Rust source directly --
        lsr   x9, x19, #3               ; x9 = count >> 3
        ands  x8, x19, #0x7               ; x8 = count & 7            (leftover tail bools, 0..7)
        cinc  x1, x9, ne                   ; x1 = count.div_ceil(8) = src.len() needed
        cmp   x1, x23
        b.hi  LBB0_21                        ; bounds check: panics if src is too short
        and   x9, x9, #0xffffffffffffffe      ; x9 = SOURCE_BYTES * num_result_chunks (round down to even)
        subs  x10, x1, x9                      ; x10 = source_tail.len()
        lsr   x11, x19, #4                      ; x11 = num_result_chunks = count / 16
        cbz   x11, LBB0_8                        ; skip the main loop entirely if count < 16

        ; -- main loop: one 2-byte chunk -> 16 bools per iteration --
LBB0_7:
        ldrh  w14, [x12], #2              ; load the next 2 source bytes as u16, src ptr += 2
        rev   w14, w14                      ; byte-swap into big-endian order (u16::from_be_bytes)
        lsr   w14, w14, #16                  ; ... and shift the swapped value back down into the low half
        dup.8h  v3, w14                       ; broadcast that one u16 into all 8 lanes of a vector
        ushl.8h v4, v3, v0                      ; v0 holds per-lane shift amounts -15..-8: right-shift each
                                                  ; lane by a different amount, pulling bits 15..8 into the low byte
        uzp1.16b v3, v4, v3                       ; interleave those 8 partially-shifted bytes with 8 copies of the
                                                    ; untouched value -> 16 bytes, one per output bool, still needing
                                                    ; their individual bit isolated
        ushl.16b v3, v3, v1                         ; per-byte shift amounts (0 for the first 8, -7..0 for the rest)
                                                      ; finish isolating one bit per byte
        and.16b  v3, v3, v2                           ; mask down to a clean 0/1 per byte
        str    q3, [x13], #16                          ; store all 16 freshly-produced bools in ONE 128-bit write,
                                                         ; dst ptr += 16
        subs   x11, x11, #1                              ; one more chunk done
        b.ne   LBB0_7                                      ; loop while chunks remain
```

Compare that to our previous best effort; here we have roughly a dozen instructions versus the previous 200-ish
lines of widening and interleaving#footnote[One minor nit is that LLVM has not been able to
elide the checks in `.split_at` and `.split_at_mut`. If I really cared I'd use the `_unchecked` versions.].

= Skipping the zero-fill

Where we're spending time now is interesting, and we're finally going to have to go to unsafe code to fix it.
The next problem is `vec![false; count]`, which ends up as `calloc` and zeroes the whole buffer. And whilst
the OS can give zero pages for cheap, when the `libc` is _reusing_ freed allocations it has to `memset` them to
zero itself. We can work around this, but we need `MaybeUninit` and `unsafe`.

```rust
pub fn unpack_bits(src: &[u8], count: usize) -> Vec<bool> {
    let mut result_vec = Vec::<bool>::with_capacity(count);
    let result = &mut result_vec.spare_capacity_mut()[..count];
    let src = &src[..count.div_ceil(8)];

    const SOURCE_BYTES: usize = 2;
    const RESULT_BYTES: usize = 8 * SOURCE_BYTES;

    // first find the big chunks we can NEON

    let num_result_chunks = count.div_euclid(RESULT_BYTES);
    let (result_chunks, result_tail) = result.split_at_mut(RESULT_BYTES * num_result_chunks);
    let (source_chunks, source_tail) = src.split_at(SOURCE_BYTES * num_result_chunks);

    for (result_chunk, src_chunk) in result_chunks
        .as_chunks_mut::<RESULT_BYTES>()
        .0
        .iter_mut()
        .zip(source_chunks.as_chunks::<SOURCE_BYTES>().0)
    {
        *result_chunk = src_chunk.unpack().map(MaybeUninit::new);
    }

    // now the tail: individual bytes

    let num_result_bytes = result_tail.len().div_euclid(8);
    let (result_bytes, result_tail) = result_tail.split_at_mut(8 * num_result_bytes);
    let (source_bytes, _) = source_tail.split_at(num_result_bytes);

    for (result_chunk, source_byte) in result_bytes
        .as_chunks_mut::<8>()
        .0
        .iter_mut()
        .zip(source_bytes)
    {
        *result_chunk = source_byte.unpack().map(MaybeUninit::new);
    }

    if !result_tail.is_empty() {
        let last = src.last().expect("we must have a byte here");
        for (dst, src) in result_tail.iter_mut().zip(last.unpack()) {
            dst.write(src);
        }
    }

    unsafe { result_vec.set_len(count) };
    result_vec
}
```

Benchmarking this implementation with `criterion`, across the same output sizes as before:

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Elements / s*]),
  [7 B], [722 Melem/s],
  [64 B], [5.51 Gelem/s],
  [512 B], [21.12 Gelem/s],
  [4 KiB], [44.28 Gelem/s],
  [32 KiB], [58.75 Gelem/s],
  [256 KiB], [60.62 Gelem/s],
  [1 MiB], [61.75 Gelem/s],
  [4 MiB], [62.13 Gelem/s],
)

Another clean win plateauing around 60 Gelem/s instead of the mid-40s. Our
code is now up at speeds where saving a `memset` matters. 

= Unrolling the chunk loop

Next trick: process two 2-byte chunks (32 bools) per loop iteration instead of one, using
`as_chunks`/`as_chunks_mut` again to peel off pairs before falling back to the single-chunk
loop for whatever's left:

```rust
pub fn unpack_bits(src: &[u8], count: usize) -> Vec<bool> {
    let mut result_vec = Vec::<bool>::with_capacity(count);
    let result = &mut result_vec.spare_capacity_mut()[..count];
    let src = &src[..count.div_ceil(8)];

    const SOURCE_BYTES: usize = 2;
    const RESULT_BYTES: usize = 8 * SOURCE_BYTES;
    const UNROLL: usize = 2;

    // first find the big chunks we can NEON

    let num_result_chunks = count.div_euclid(RESULT_BYTES);
    let (result_chunks, result_tail) = result.split_at_mut(RESULT_BYTES * num_result_chunks);
    let (source_chunks, source_tail) = src.split_at(SOURCE_BYTES * num_result_chunks);

    let result_chunks = result_chunks.as_chunks_mut::<RESULT_BYTES>().0;
    let source_chunks = source_chunks.as_chunks::<SOURCE_BYTES>().0;

    let (big_result_chunks, result_chunks) = result_chunks.as_chunks_mut::<UNROLL>();
    let (big_source_chunks, source_chunks) = source_chunks.as_chunks::<UNROLL>();

    for (big_result_chunk, big_source_chunk) in big_result_chunks.iter_mut().zip(big_source_chunks) {
        *big_result_chunk = big_source_chunk.map(|x| x.unpack().map(MaybeUninit::new))
    }

    for (result_chunk, source_chunk) in result_chunks.iter_mut().zip(source_chunks) {
        *result_chunk = source_chunk.unpack().map(MaybeUninit::new);
    }

    // now the tail: individual bytes

    let num_result_bytes = result_tail.len().div_euclid(8);
    let (result_bytes, result_tail) = result_tail.split_at_mut(8 * num_result_bytes);
    let (source_bytes, _) = source_tail.split_at(num_result_bytes);

    for (result_chunk, source_byte) in result_bytes
        .as_chunks_mut::<8>()
        .0
        .iter_mut()
        .zip(source_bytes)
    {
        *result_chunk = source_byte.unpack().map(MaybeUninit::new);
    }

    if !result_tail.is_empty() {
        let last = src.last().expect("we must have a byte here");
        for (dst, src) in result_tail.iter_mut().zip(last.unpack()) {
            dst.write(src);
        }
    }

    unsafe { result_vec.set_len(count) };
    result_vec
}
```

Benchmarking this implementation with `criterion`, across the same output sizes as before:

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Elements / s*]),
  [7 B], [691 Melem/s],
  [64 B], [5.59 Gelem/s],
  [512 B], [20.83 Gelem/s],
  [4 KiB], [51.59 Gelem/s],
  [32 KiB], [63.61 Gelem/s],
  [256 KiB], [65.53 Gelem/s],
  [1 MiB], [66.68 Gelem/s],
  [4 MiB], [67.06 Gelem/s],
)

A smaller step than the previous ones, but still a real one -- another few Gelem/s on top of our previous best effort.
Disassembling shows the unrolling didn't fuse the actual bit-unpacking
maths across the two chunks (because it can't, because NEON isn't that big) -- it just batches the
load/byte-swap/store around it

```
LBB2_7:
        ldr   w17, [x16], #4       ; ONE 32-bit load fetches BOTH 2-byte chunks at once, src ptr += 4
        rev   w17, w17               ; ONE byte-reverse swaps all 4 bytes together
        lsr   w0, w17, #16             ; chunk 0's swapped u16 (top half)
        dup.8h v3, w0
        ushl.8h v4, v3, v0
        uzp1.16b v3, v4, v3              ; chunk 0's 16 raw bit-bytes
        and   w17, w17, #0xffff            ; chunk 1's swapped u16 (bottom half, free after the one `rev`)
        dup.8h v4, w17
        ushl.8h v5, v4, v0
        uzp1.16b v4, v5, v4               ; chunk 1's 16 raw bit-bytes -- this whole pipeline is just duplicated,
        ushl.16b v3, v3, v1                ; not fused into a wider vector op
        and.16b  v3, v3, v2
        ushl.16b v4, v4, v1
        and.16b  v4, v4, v2
        stp   q3, q4, [x15, #-16]           ; ONE 32-byte store for both chunks' 32 bools
        add   x15, x15, #32
        subs  x14, x14, #1
        b.ne  LBB2_7
```

The saving is one load + one `rev` + one store per pair instead of two each -- the `dup`/`ushl`/`uzp1`/`ushl`/`and`
bit-unpacking work is still fully duplicated per chunk, just issued back-to-back.

= Conclusions

How much further can we go? Let's have a benchmark that just `fill`s a buffer of an appropriate size to get a reference for
just how fast a single core can store data.

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Store bandwidth*]),
  [7 B], [2.68 GiB/s],
  [64 B], [36.0 GiB/s],
  [512 B], [109.0 GiB/s],
  [4 KiB], [127.0 GiB/s],
  [32 KiB], [73.6 GiB/s],
  [256 KiB], [73.5 GiB/s],
  [1 MiB], [73.8 GiB/s],
  [4 MiB], [74.5 GiB/s],
)

The numbers below 4 KiB are mostly noise -- dominated by fixed per-call overhead rather than real bandwidth -- but the steady
state from 32 KiB up (hitting 73-75 GiB/s) is meaningful. *We* are hitting about 65-67 Gelem/s at those same sizes,
which is 1 byte per element -- we're already within about 10-15% of pure single-core store bandwidth and there's not a
lot of room to improve the single-core performance; to do much better we'd have to get a couple of cores trying to
saturate memory bandwidth.

== The actual final version

We can in fact simplify the code further.

```rust
const BYTE_LUT: [[bool; 8]; 256] = {
    let mut table = [[false; 8]; 256];
    let mut byte = 0usize;
    while byte < 256 {
        let mut bit = 0usize;
        while bit < 8 {
            table[byte][bit] = (byte as u8) & (1 << (7 - bit)) != 0;
            bit += 1;
        }
        byte += 1;
    }
    table
};

pub struct ByteLut(pub u8);

impl Unpackable for ByteLut {
    type Output = [bool; 8];

    #[inline(always)]
    fn unpack(&self) -> Self::Output {
        BYTE_LUT[self.0 as usize]
    }
}

pub fn unpack_bits(src: &[u8], count: usize) -> Vec<bool> {
    let mut result = Vec::with_capacity(count);
    let res = &mut result.spare_capacity_mut()[..count];
    let src = &src[..count.div_ceil(8)];

    const UNROLL: usize = 4;

    let (dest_bytes, dest_tail) = res.as_chunks_mut::<8>();
    let (src_bytes, src_tail) = src.split_at(dest_bytes.len());

    let (dest_unroll, dest_bytes) = dest_bytes.as_chunks_mut::<UNROLL>();
    let (src_unroll, src_bytes) = src_bytes.as_chunks::<UNROLL>();

    for (dst, src) in dest_unroll.iter_mut().zip(src_unroll) {
        *dst = src.map(|x| ByteLut(x).unpack().map(MaybeUninit::new));
    }

    for (dst, src) in dest_bytes.iter_mut().zip(src_bytes) {
        *dst = ByteLut(*src).unpack().map(MaybeUninit::new);
    }

    if !dest_tail.is_empty() {
        // by construction of src_tail
        let src = src_tail.first().expect("the impossible has happened");
        for (dst, src) in dest_tail.iter_mut().zip(ByteLut(*src).unpack()) {
            dst.write(src);
        }
    }

    unsafe {result.set_len(count)};
    result
}
```

Benchmarking this implementation with `criterion`, across the same output sizes as before:

#table(
  columns: (auto, auto),
  align: (left, right),
  table.header([*Size*], [*Elements / s*]),
  [7 B], [730 Melem/s],
  [64 B], [5.89 Gelem/s],
  [512 B], [22.37 Gelem/s],
  [4 KiB], [51.64 Gelem/s],
  [32 KiB], [62.45 Gelem/s],
  [256 KiB], [66.42 Gelem/s],
  [1 MiB], [66.81 Gelem/s],
  [4 MiB], [66.16 Gelem/s],
)

It's essentially tied with the hand-rolled please-NEON-this-for-me version above, despite the main loop being
far simpler (a handful of table loads instead of the `dup`/`ushl`/`uzp1` bit-plane dance). The lookup table
and enough unrolling to keep the CPU's out-of-order machinery fed got us to the same place as SIMD shift
tricks. We're using no vector unit at all, just scalar loads and table lookups:

```
LBB4_6:
        ldr   w15, [x14], #4         ; ONE 32-bit load fetches all 4 source bytes for this iteration, src ptr += 4
        and   x16, x15, #0xff          ; extract byte 0 (no separate load -- it's already in the register)
        ldr   x16, [x9, x16, lsl #3]     ; table[byte0] -> 8 bool-bytes
        ubfx  x17, x15, #8, #8            ; extract byte 1
        ldr   x17, [x9, x17, lsl #3]        ; table[byte1]
        lsr   x0, x15, #24                   ; extract byte 3
        ubfx  x15, x15, #16, #8               ; extract byte 2
        ldr   x15, [x9, x15, lsl #3]            ; table[byte2]
        ldr   x0, [x9, x0, lsl #3]                ; table[byte3]
        stp   x16, x17, [x13, #-16]                 ; store bytes 0+1's results (16 bools)
        stp   x15, x0, [x13], #32                     ; store bytes 2+3's results (16 bools), dst ptr += 32
        subs  x12, x12, #1                              ; one fewer group of 4 done
        b.ne  LBB4_6                                      ; loop while groups remain
```

14 instructions producing 32 bools (4 bytes) per iteration. Only *one* memory access touches the source
(`ldr w15`, 4 bytes) -- the other three "byte extractions" (`and`/`ubfx`/`lsr`) are pure register ops
pulling bytes 1-3 out of the word already loaded, avoiding any separate per-byte source load. The four
table lookups are independent, with no data dependency on each other and the two `stp`s write all 32
bools in two instructions.  Bounds checks are in fact simplified: LLVM can prove our `split_at` and
our `first` don't go to the Bad Place, presumably because the loop setup code is much simpler.

== Where we got to

What did we learn?

+ Bounds checks are evil. Not perhaps because they are not predictable, but because they stop the
  compiler doing the Deep Magic.
+ The Deep Magic does not always help. LLVM's autovec is _fragile_ here. We almost had to write the SIMD code by hand (and it
  might have been more robust if we had). What I didn't show you was that even in its current state it's
  quite sensitive to the exact `impl Unpackable for Foo` implementation.
+ Lookup tables for teh win.
+ `calloc` is not free. If you care then write into a preallocated `&mut foo` _or_ do the
  `.spare_capacity_mut()` dance.
+ Different levels of blocking and unrolling worked for different algorithms. Experiment and measure.
+ (and, the old lesson -- start simple and experiment systematically)

I said it before, but *compilers are weird*.