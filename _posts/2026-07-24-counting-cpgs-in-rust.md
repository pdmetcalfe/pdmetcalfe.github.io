---
layout: post
title: "How fast can you count CpGs? (Rust edition)"
categories: programming rust numerics
---

I got [nerd-sniped](https://xkcd.com/356/) by [Ben
Sidders](https://sidderb.wordpress.com/2013/10/04/how-fast-can-you-count-the-number-of-cpgs-in-the-human-genome-2/),
who asked: how fast can you count the CpG dinucleotides (a `C` immediately
followed by a `G`) in the human reference genome? He got from 38 seconds down
to 3 by dropping Perl's regex engine for `index()` and `tr`, and by
threading across the 24 chromosome files. That's a reasonable excuse to fiddle with high-performance [Rust](https://rust-lang.org/),
and also a good reason to sit down and fiddle with SIMD. Not yet
worth its own repo, so code fragments below rather than a link; numbers
are from an M5 MacBook Pro on GRCh37 chromosome 1 (253MB) and, for
contrast, the tiny mitochondrial chromosome (17KB).

### Simple and (for all practical purposes) good enough

FASTA files wrap sequence at 60-ish characters a line, so step one is
"read the file and strip the newlines out":

~~~ rust
fn read_stripped(path: &Path) -> std::io::Result<Vec<u8>> {
    let reader = BufReader::new(File::open(path)?);
    let mut bytes = Vec::new();
    for line in reader.split(b'\n') {
        bytes.extend_from_slice(&line?);
    }
    Ok(bytes)
}
~~~

(`split(b'\n')` rather than `.lines()` --- a FASTA file is bytes, not
`str`, and `.lines()` insists on checking every one of those bytes is
valid UTF-8 before it'll hand them back as a `String`. Splitting on the
raw byte is both more honest about what we're doing and, since we never
needed the UTF-8 guarantee, strictly less work.)

Once you've got one contiguous slice with no line breaks in it, counting
CpGs is the obvious thing:

~~~ rust
pub fn simple(data: &[u8]) -> usize {
    data.windows(2).filter(|w| *w == b"CG").count()
}
~~~

`windows(2)` slides a two-byte view along the slice one position at a time,
so every adjacent pair gets checked exactly once. On chromosome 1 this
takes about 190ms. Nothing clever, nothing wrong with it[^perfectly-good].

[^perfectly-good]: And also probably good enough for use in practice. But who wants "good enough" when we could have "perfection"?

### SIMD take 1

Because I want to play, the obvious next move for a "how fast" benchmark is SIMD: instead of
comparing two bytes at a time, compare sixteen. I'm on Apple Silicon, so
that means NEON, wrapped in a tiny `ByteVector` so the counting logic
doesn't have to look at intrinsics directly[^llvm-hates-me]:

~~~ rust
pub struct ByteVector(uint8x16_t);

impl ByteVector {
    pub const LANES: usize = 16;

    pub fn load(data: &[u8], offset: usize) -> Self {
        unsafe { Self(vld1q_u8(data.as_ptr().add(offset))) }
    }
    pub fn eq(self, other: Self) -> Self {
        unsafe { Self(vceqq_u8(self.0, other.0)) }
    }
    pub fn and(self, other: Self) -> Self { /* vandq_u8 */ }
    pub fn add(self, other: Self) -> Self { /* vaddq_u8 */ }
    pub fn mask_count(self) -> usize {
        unsafe { (-vaddlvq_s8(vreinterpretq_s8_u8(self.0))) as usize }
    }
}
~~~

[^llvm-hates-me]: I originally tried to be clever and write high-level code that would tempt LLVM's autovectorizer. Unfortunately I managed to tempt LLVM to pessimize the code by vectorizing along the wrong axis. The simplest way out was to do the intrinsics by hand, even if I'll have to write more code when I play on `x86_64`.

Then the counting loop looks up two overlapping 16-byte lanes at once ---
one for the `C` positions, one shifted right by one for the corresponding
`G` positions --- compares each against a splatted constant, ANDs the two
comparison masks together, and accumulates:

~~~ rust
let mask = first.eq(vc).and(second.eq(vg));
acc.add(mask)
~~~

There's a wrinkle. `eq` on NEON returns `0xFF` for true and `0x00` for false per
byte lane. But `0xFF` reinterpreted as `i8` is just `-1`, so just accumulate the raw masks,
and reduce with a
*signed* widening sum (`vaddlvq_s8`), which adds up sixteen `-1`s and
`0`s into one negative total --- negate it and you have your count. The reduction can't run forever
between reduces, since a `u8`... sorry, `i8` lane can
only go so low before wrapping past `i8::MIN` (-128). A two-level `block_iter`
chunks the data into groups of
127 SIMD rounds, reduces each group to a `usize` with `mask_count`, and
sums the (much smaller number of) group totals:

~~~ rust
let mut blocks = data.block_iter(LANES * ROUNDS_PER_REDUCTION + 1, LANES * ROUNDS_PER_REDUCTION);
let bulk = (&mut blocks).map(|big_chunk| {
    big_chunk
        .block_iter(LANES + 1, LANES)
        .fold(ByteVector::zero(), |acc, chunk| {
            let first = ByteVector::load(chunk, 0);
            let second = ByteVector::load(chunk, 1);
            let mask = first.eq(vc).and(second.eq(vg));
            acc.add(mask)
        })
        .mask_count()
}).sum::<usize>();

bulk + simple(blocks.remainder())
~~~

(`block_iter` is a small home-grown iterator that yields overlapping
windows of a chosen size and advance, so a `LANES + 1`-byte block advancing
by `LANES` gives every lane both its own byte and a peek at the next one.
Whatever doesn't divide evenly falls out through `remainder()` and gets
handled by good old `simple`.)

This is, by any reasonable measure, *more* code.
On chromosome 1 it took **~190ms** ---
statistically indistinguishable from `simple`'s ~190ms. On the 17KB
mitochondrial file the two are close enough to call a tie (22.1µs vs
20.4µs). All that vectorized cleverness bought essentially nothing,
because `read_stripped` --- one line-buffered read plus a `Vec` extend per
line --- dominates the wall clock. You cannot SIMD your way out of a
bottleneck that isn't in the loop you vectorized.

### Facepalm: don't do unnecessary clever stuff

So: stop copying the genome. `mmap` the file directly and work on the raw
bytes, newlines and all, which means every 61st byte pair (the `C` at the
end of one 60-character line and the `G` at the start of the next) has a
`\n` sitting in between them. Rather than solve that with more machinery,
widen the window by one byte and accept either shape:

~~~ rust
pub fn simple_2(data: &[u8]) -> usize {
    data.windows(3).filter(|w| {
        (&&w[..2] == &b"CG") || (w == &b"C\nG")
    }).count()
}
~~~

A window still starts at every byte, so a `CG` that's on the same line is
caught by the first branch just as before; a `CG` split by a line wrap is
caught by the second. No newline-stripping, no allocation, no copy of a
253MB file --- just a slice straight out of the page cache. Despite doing
*more* comparison work per window than our first go, this drops chromosome 1
from 190ms to **80ms**. The fastest code, again, turns out to be the code
that skips work rather than the code that does the remaining work harder.

### SIMD take 2

Now I'm not wasting time on string fiddling, going back to SIMD is (hopefully)
worth it. The second take at SIMD is just the first take with the sliding window widened.

~~~ rust
let first = ByteVector::load(chunk, 0);
let second = ByteVector::load(chunk, 1);
let third = ByteVector::load(chunk, 2);
let is_c = first.eq(vc);
let cg = is_c.and(second.eq(vg));
let c_nl_g = is_c.and(second.eq(vnl)).and(third.eq(vg));
let mask = cg.or(c_nl_g);
acc.add(mask)
~~~

Same 127-round accumulation trick, same `mask_count` reduction,
same `mmap`'d input, and no copying. Chromosome 1:
**~15ms**. That's roughly 13x `windows` take 1, 5x `windows` take 2, and a
13x over SIMD take 1 too, because now the SIMD loop is actually
the bottleneck it was written to speed up.

### Putting numbers next to each other

| | chr1 (253MB) | MT (17KB) |
|---|---|---|
| `windows` take 1 | ~190ms | 22.1µs |
| SIMD take 1 | ~190ms | 20.4µs |
| `windows` take 2 | ~80ms | 16.4µs |
| SIMD take 2 | ~15ms | 12.8µs |

I did of course run all four on every chromosome and assert that they agree, mostly
so I'd notice immediately if I'd fouled-up[^fouled-up] the NEON intrinsics. They do
agree: 27,999,538 CpGs across the 24 GRCh37 files, autosomes, X and MT
included.

[^fouled-up]: Other equivalent phrases are available.

The moral is of course profile before you optimize. The expensive part
of this problem was never
the byte comparison --- it was a line-by-line read copying 253MB into a
growing `Vec`. `mmap` fixed that in four lines and beat a hand-rolled NEON
kernel by 2.4x. SIMD earned its keep, but only
*after* the actual bottleneck was gone; applied to the wrong loop it's just
more code that runs at the same speed as the code it replaced.
