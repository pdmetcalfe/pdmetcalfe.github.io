#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Adding up numbers])
#metadata((
  title: "Adding up numbers",
  kind: "post",
  date: "2026-10-01",
  tags: ("programming", "rust", "optimization"),
  summary: "compilers are weird",
)) <website-metadata>

#title()

I was preparing a talk on making R fast and wanted to give a simple
example of writing an R extension using #link("https://extendr.rs/")[extendr]. It's a
bit hard to do such a thing with a _meaningful_ algorithm, so I thought I'd see what
I could do with the simplest thing in the world: `sum`. All benchmarks run on an Apple M5.
Caution: we aren't going to end up with a tidy answer at the end of all this.

The naive rust implementation (which has problems) is this:

```rust
fn rust_sum(xs: &[f64]) -> f64 {
    xs.iter().sum::<f64>()
}
```

The main problem with this is `NA` handling. R (bless it, it isn't #link("apache-arrow-ftw.html")[Arrow])
stores missing values inline using a
specific sentinel `NaN` value, and there's no guarantee that specific `NaN` values will
propagate correctly. Let's try handling that (note that we need to do
the `.to_bits()` dance because Thou Shalt Not compare `NaN` values and expect sanity).

```rust
#[inline(always)]
fn classify(x: f64, sentinel: u64) -> Option<f64> {
    if x.to_bits() == sentinel {
        None
    } else {
        Some(x)
    }
}

#[extendr]
fn rust_sum(xs: &[f64]) -> Option<f64> {
    let na_bits = f64::na().to_bits();
    let class = |&x| classify(x, na_bits);
    let (sum, seen_na) = xs.iter()
        .map(class)
        .fold((0.0_f64, false),
            |(accum, seen_na), value| { (accum + value.unwrap_or(0.0), seen_na | value.is_none())});
    if seen_na { None } else { Some(sum) }
}
```

This works, and is slightly surprisingly faster than the builtin `sum`. We're going to find this throughout:
R's `sum` leaves performance on the table.

```
> x <- rnorm(10000)
> microbenchmark(sum(x), rust_sum(x))
Unit: microseconds
        expr    min     lq     mean median      uq    max neval
      sum(x) 11.480 11.521 11.59685 11.562 11.6030 12.792   100
 rust_sum(x)  5.535  5.658  5.92245  5.699  5.8015 14.391   100
```

The assembler is -- frankly -- a mess. It's trying to operate on 16 double precision numbers
at a time, it's doing the comparison to the sentinel `NaN` value (`0x7ff00000000007a2`)
vectorized, but is then doing a Whole Bunch Of Stuff to unpack the doubles into scalar registers
and do scalar addition. These days compilers tend to be pretty reluctant to rearrange floating point numerics
because, like wizards, IEEE-754 is subtle and quick to anger. But if we give the compiler permission
to rearrange additions (which you can do in recent rust), you can do this:

```rust
#[extendr]
fn rust_sum_vectorized(xs: &[f64]) -> Option<f64> {
    let na_bits = f64::na().to_bits();
    let class = |&x| classify(x, na_bits);
    let (sum, seen_na) = xs.iter()
        .map(class)
        .fold((0.0_f64, false),
            |(accum, seen_na), value| { 
                (accum.algebraic_add(value.unwrap_or(0.0)), seen_na | value.is_none())
            });
    if seen_na { None } else { Some(sum) }
}
```

So this has worked: we've done better than our naive version above, and we're a factor of 6-ish
faster than the intrinsic `sum`. Looking at the assembler it's now NEON throughout: it's working
16 doubles at a time, accumulating the sums into 8 vector registers.

```
Unit: microseconds
                   expr    min     lq     mean median     uq    max neval
                 sum(x) 11.357 11.521 11.63088 11.562 11.562 14.350   100
            rust_sum(x)  5.494  5.658  5.99789  5.699  5.781 14.145   100
 rust_sum_vectorized(x)  1.599  1.681  1.82778  1.722  1.763  8.487   100
```

But doing this takes `.algebraic_add`. Can we do this on an earlier rust? Admittedly we can
always go to intrinsics and unsafe code, but because (hopefully)
#link("https://matklad.github.io/2023/04/09/can-you-trust-a-compiler-to-optimize-your-code.html")[
    compilers can handle well-written code
] we should be able to get to this by writing our code carefully, in a manner that will tempt LLVM into
doing great things.

A simple version should look a bit like this: we explicitly work on arrays of 2 `f64`s and
write everything out by hand. (For those who aren't rust natives, this code is exactly as
boring as it looks.)

```rust
use core::ops::{Add, AddAssign, BitOr, BitOrAssign};

#[inline(always)]
fn classify(x: f64, sentinel: u64) -> Option<f64> {
    if x.to_bits() == sentinel {
        None
    } else {
        Some(x)
    }
}

#[derive(Copy, Clone, Default)]
struct FloatVec([f64;2]);

impl FloatVec {
    fn reduce(self) -> f64 {
        self.0[0] + self.0[1]
    }

    fn mask(self, na_bits: u64) -> (FloatVec, MaskVec) {
        let mask = [
            classify(self.0[0], na_bits).is_none(),
            classify(self.0[1], na_bits).is_none()
            ];
        let float = [
            if mask[0] {0.0} else {self.0[0]},
            if mask[1] {0.0} else {self.0[1]}
        ];
        (
            float.into(), mask.into()
        )
    }
}

impl From<[f64;2]> for FloatVec {
    fn from(item: [f64;2]) -> Self {
        FloatVec(item)
    }
}

impl Add for FloatVec {
    type Output = Self;
    fn add(self, rhs: Self) -> Self::Output {
        FloatVec([
            self.0[0] + rhs.0[0],
            self.0[1] + rhs.0[1]]
        )
    }
}

impl AddAssign for FloatVec {
    fn add_assign(&mut self, rhs: Self) {
        self.0[0] += rhs.0[0];
        self.0[1] += rhs.0[1];
    }
}

#[derive(Copy, Clone, Default)]
struct MaskVec([bool;2]);

impl MaskVec {
    fn reduce(self) -> bool {
        self.0[0] | self.0[1]
    }
}

impl From<[bool;2]> for MaskVec {
    fn from(item: [bool;2]) -> Self {
        MaskVec(item)
    }
}

impl BitOr for MaskVec {
    type Output = Self;
    fn bitor(self, rhs: Self) -> Self::Output {
        MaskVec([
            self.0[0] | rhs.0[0],
            self.0[1] | rhs.0[1]
            ])
    }
}

impl BitOrAssign for MaskVec {
    fn bitor_assign(&mut self, rhs: Self) {
        self.0[0] |= rhs.0[0];
        self.0[1] |= rhs.0[1];
    }
}

#[extendr]
fn tempt_llvm(xs: &[f64]) -> Option<f64> {
    let na_bits = f64::na().to_bits();
    let (pairs, tail) = xs.as_chunks::<2>();

    let (sum, seen_na) = pairs
        .iter()
        .fold((FloatVec::default(), MaskVec::default()),
        |(accum, seen_na), pairs| {
            let floats: FloatVec = (*pairs).into();
            let (values, is_na) = floats.mask(na_bits);
            (accum + values, seen_na | is_na)
        });

    let bulk = (!seen_na.reduce()).then(|| sum.reduce());
    let tail = classify(tail.first().copied().unwrap_or(0.0), na_bits);

    Some(bulk? + tail?)
}
```

We're not going to be able to get the 8 vector accumulators like this (because we've not given LLVM permission
to rearrange floating point addition), but it should be close.

```
Unit: microseconds
                   expr    min      lq     mean median      uq    max neval
                 sum(x) 14.883 14.9240 14.99124 14.965 14.9650 17.794   100
            rust_sum(x)  7.093  7.5235  7.80353  7.667  7.9950  9.184   100
 rust_sum_vectorized(x)  2.050  2.2960  2.70723  2.460  2.5830 23.862   100
          tempt_llvm(x)  4.223  4.5510  4.85645  4.756  5.0225  6.150   100
```

The assembler is *baroque*, though. LLVM has unrolled the loop to work on 32 doubles at a time,
is doing vector loads with deinterleaving (to pull all the `[0]` elements into the same vector),
is doing the comparison to `NA` on the vector registers, but then (because it has to)
descends to scalar code to do the floating point additions. Let's try again. `.algebraic_add` has
given us the Right Answer (8 vector accumulators mean that we can run multiple additions at
the same time and break the dependency chain on `f64` addition), so let's explicitly write that.

```rust 
#[derive(Copy, Clone, Default)]
struct FloatAccum([FloatVec;8]);

impl FloatAccum {
    fn mask(self, na_bits: u64) -> (FloatAccum, MaskVec) {
        let mut floats = FloatAccum::default();
        let mut masks = MaskAccum::default();
        for ((dst_float, dst_mask), src_float) in floats.0.iter_mut().zip(masks.0.iter_mut()).zip(self.0) {
            let (f, m) = src_float.mask(na_bits);
            *dst_float = f;
            *dst_mask = m;
        }
        (floats, masks)
    }

    fn reduce(self) -> f64 {
        let vec = self.0.iter().fold(
            FloatVec::default(),
            |accum, value| accum + *value
        );
        vec.reduce()
    }
}

impl From<[f64;16]> for FloatAccum {
    fn from(items: [f64;16]) -> Self {
        let mut res = FloatAccum::default();
        for (dst, src) in res.0.iter_mut().zip(items.as_chunks::<2>().0) {
            *dst = (*src).into();
        }
        res
    }
}

impl AddAssign for FloatAccum {
    fn add_assign(&mut self, other: Self) {
        for (dst, src) in self.0.iter_mut().zip(other.0) {
            *dst += src;
        }
    }
}

impl Add for FloatAccum {
    type Output = Self;
    fn add(mut self, other: Self) -> Self::Output {
        self += other;
        self
    }
}

#[derive(Copy, Clone, Default)]
struct MaskAccum([MaskVec;8]);

impl MaskAccum {
    fn reduce(self) -> bool {
        let vec = self.0.iter().fold(
            MaskVec::default(),
            |accum, value| accum | *value
        );
        vec.reduce()
    }
}

impl BitOrAssign for MaskAccum {
    fn bitor_assign(&mut self, other: Self) {
        for (dst, src) in self.0.iter_mut().zip(other.0) {
            *dst |= src;
        }
    }
}

impl BitOr for MaskAccum {
    type Output = Self;
    fn bitor(mut self, other: Self) -> Self::Output {
        self |= other;
        self
    }
}


#[extendr]
fn tempt_llvm_unroll(xs: &[f64]) -> Option<f64> {
    let na_bits = f64::na().to_bits();
    let (pairs, tail) = xs.as_chunks::<16>();

    let (sum, seen_na) = pairs
        .iter()
        .fold((FloatAccum::default(), MaskAccum::default()),
        |(accum, seen_na), pairs| {
            let floats: FloatAccum = (*pairs).into();
            let (values, na_mask) = floats.mask(na_bits);
            (accum + values, seen_na | na_mask)
        });

    let bulk = (!seen_na.reduce()).then(|| sum.reduce());

    let (accum, seen_na) = tail.iter().copied()
        .map(|x| classify(x, na_bits))
        .fold(
            (0.0_f64, false),
            |(accum, seen_na), value| {
                (accum + value.unwrap_or(0.0), seen_na | value.is_none())
            });
    let tail = (!seen_na).then_some(accum);

    Some(bulk? + tail?)
}
```

So compilers are great and now we've written everything in autovectorizable form...

```
Unit: microseconds
                   expr    min      lq     mean  median      uq    max neval
                 sum(x) 13.981 14.9240 14.88259 14.9650 14.9650 20.377   100
            rust_sum(x)  6.642  7.2980  7.91874  7.5030  7.9950 31.529   100
 rust_sum_vectorized(x)  1.886  2.2140  2.37472  2.3370  2.5010  3.157   100
          tempt_llvm(x)  3.936  4.4690  4.80315  4.7355  5.0840  6.847   100
   tempt_llvm_unroll(x)  3.813  4.2845  4.61127  4.5510  4.8585  6.232   100
```

mmkay. That has done _nothing_ for us. Looking at the assembler we've got
nice floating point addition, but the mask tracking has descended into a
bunch of scalar ops. Oops.

By staring at the generated assembler and comparing to the `.algebraic_add` version
we can see that we can squash down the mask comparison.

```rust
#[derive(Copy, Clone, Default)]
struct FloatAccum([FloatVec;8]);

impl FloatAccum {
    fn mask(self, na_bits: u64) -> (FloatAccum, MaskAccum) {
        let mut floats = FloatAccum::default();
        let mut masks = MaskAccum::default();
        for (dst_float, src_float) in floats.0.iter_mut().zip(self.0) {
            let (f, m) = src_float.mask(na_bits);
            *dst_float = f;
            masks.0 |= m;
        }
        (floats, masks)
    }

    fn reduce(self) -> f64 {
        let vec = self.0.iter().fold(
            FloatVec::default(),
            |accum, value| accum + *value
        );
        vec.reduce()
    }
}

impl From<[f64;16]> for FloatAccum {
    fn from(items: [f64;16]) -> Self {
        let mut res = FloatAccum::default();
        for (dst, src) in res.0.iter_mut().zip(items.as_chunks::<2>().0) {
            *dst = (*src).into();
        }
        res
    }
}

impl AddAssign for FloatAccum {
    fn add_assign(&mut self, other: Self) {
        for (dst, src) in self.0.iter_mut().zip(other.0) {
            *dst += src;
        }
    }
}

impl Add for FloatAccum {
    type Output = Self;
    fn add(mut self, other: Self) -> Self::Output {
        self += other;
        self
    }
}

#[derive(Copy, Clone, Default)]
struct MaskAccum(MaskVec);

impl MaskAccum {
    fn reduce(self) -> bool {
        self.0.reduce()
    }
}

impl BitOrAssign for MaskAccum {
    fn bitor_assign(&mut self, other: Self) {
        self.0 |= other.0
    }
}

impl BitOr for MaskAccum {
    type Output = Self;
    fn bitor(mut self, other: Self) -> Self::Output {
        self |= other;
        self
    }
}
```

And we're about there...

```
Unit: microseconds
                   expr    min     lq     mean  median      uq    max neval
                 sum(x) 12.218 12.259 12.32378 12.2590 12.3000 15.539   100
            rust_sum(x)  5.781  5.904  6.66619  6.0680  7.0725 10.578   100
 rust_sum_vectorized(x)  1.599  1.681  2.57439  1.7630  2.7265 18.286   100
          tempt_llvm(x)  3.485  3.608  4.56330  4.0385  4.8790 10.086   100
   tempt_llvm_unroll(x)  1.886  2.009  3.10657  2.1320  3.0545 45.141   100
```

There is still a gap: `rust_sum_vectorized` arrived at a better representation
for the mask accumulation.  Attempting to get LLVM to use _that_ representation in
our code immediately tempts it to spill mask accumulation into general purpose registers
and slow down to the speed of `tempt_llvm`. I strongly suspect that if I want to do
better I need to write NEON intrinsics by hand (and it would probably have been
quicker to do that).

So #link("https://matklad.github.io/2023/04/09/can-you-trust-a-compiler-to-optimize-your-code.html")[can I
trust a compiler to optimize my code?] Maybe. The `.algebraic_add` version is genuinely good, but
attempting to get there without that essentially required an attempt to massage code through LLVM's
pessimiser, knowing ahead of time what the Right Answer should be. And I'm pretty sure that attempting
to do this across all the different incarnations of `x86_64` as well would turn into a horrible mess
not too different from writing the intrinsics by hand.