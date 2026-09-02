#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Nerd sniped by bit vectors])
#metadata((
  title: "Nerd sniped by bit vectors",
  kind: "post",
  date: "2026-08-25",
  tags: ("programming", "rust", "optimization"),
  summary: "compilers are weird",
)) <website-metadata>

#title()

For _reasons_ I needed to unpack MSB-stored-first bit vectors into a vector of booleans. The basic algorithm is simple enough, and is nice and clear.

```rust
fn is_set(byte: u8, ix: usize) -> bool {
    byte & (0x80 >> ix) != 0
}

pub fn unpack_bits(source: &[u8], count: usize) -> Vec<bool> {
    let bitvec_count = count.div_ceil(8);
    let source = &source[..bitvec_count];
    let mut result = vec![false; count];

    for (ind, dst) in result.iter_mut().enumerate() {
        let byte_idx = ind.div_euclid(8);
        let bit_index = ind.rem_euclid(8);
        let byte = source[byte_idx];
        *dst = is_set(byte, bit_index);
    }

    result
}
```

But of course (note title of post) there are far more interesting questions you can ask
and you of course want to make it go as fast as possible. A look on
#link("https://godbolt.org/z/nbfoGvo5P")[godbolt] is informative#footnote[For those poor
    benighted souls on `x86-64` exactly the same patterns hold.]
--- note all the bounds checks in the inner loop, and it's done no unrolling at all. So
can we write it in such a way that we skip this? For a first step, we can think about
what we're doing, load the source byte once, and then splat it into the 8 output bytes
it feeds. There'll be a bit of a tail to worry about, but we can handle that.

```rust
pub fn unpack_bits_chunked(source: &[u8], count: usize) -> Vec<bool> {
    let bitvec_count = count.div_ceil(8);
    let source = &source[..bitvec_count];

    let tail_bits = count.rem_euclid(8);

    let mut result = vec![false; count];
    let mut chunks = result.chunks_exact_mut(8);
    for (chunk, byte) in chunks.by_ref().zip(source.iter()) {
        for (ind, dest) in chunk.iter_mut().enumerate() {
            *dest = is_set(*byte, ind)
        }
    }

    if tail_bits > 0 {
        let byte = source.last().expect("there *must* be a last element");
        for (ind, dest) in chunks.into_remainder().iter_mut().enumerate() {
            *dest = is_set(byte, ind)
        }
    }

    result
}
```

#link("https://godbolt.org/z/3Mssooc9v")[Godbolt] now shows a _whole mess_ (technical term). But this is nice code. What we've got is a bulk NEON 16-bytes-at-a-time loop, then we've got a NEON 1-byte-at-a-time loop to clean up anything that's not a multiple of 16 bytes, and then we've finally got the tail bits handling. Aren't compilers great? (The NEON version is *always* faster than the scalar version, by a factor of approximately 10 for large arrays.)

However. The nice code snippet above is where I ended up. I _actually_ went via #link("https://godbolt.org/z/4c1xcq3ov")[this version] because I was clever and tried to abstract out the commonalities that I was going to need to try a few different passes. And that was interesting. Looking at *that* code we see that:

1. `unpack_bits_chunked` is *very* similar to our version above, except that the 1-byte-at-a-time NEON cleanup loop is scalar code (boo). For _reasons_ LLVM has failed to hoist 8 redundant loads here.
2. `unpack_bits_chunked_copy` is identical to our nice clean code above: dereferencing our byte once was enough to force LLVM to realize that it didn't have to do 8 loads.

This is (another technical term) peculiar. With our standalone function above LLVM vectorizes the whole thing sanely with minimal help. It's also smart enough to prove that the "there *must* be a last element" path is never reached. With the `BitSource` versions LLVM can do the bulk vectorization sensibly regardless of dereferencing, but needs the `&byte` dereference to fix the spill code sensibly. (Version 3, which I haven't shown you, constructs the `BitSource` in `unpack_bits_foo`, doesn't do the dereferencing, and perfectly matches our nice code.)

The fun thing was, though, that when running `criterion` benchmarks locally, the whole toolchain was smart enough to decide that `unpack_bits_chunked` and `unpack_bits_chunked_copy` were the same thing and only emit one function. Compilers are *weird*.
