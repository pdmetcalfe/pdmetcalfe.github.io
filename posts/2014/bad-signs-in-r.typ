#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Things I don't like seeing in R code #23])
#metadata((
  title: "Things I don't like seeing in R code #23",
  kind: "post",
  date: "2014-08-11",
  tags: ("numerics", "rng", "rants", "R"),
  summary: "me whinging about wheel reinvention",
)) <website-metadata>

#title()

This code is a personal bugbear.

```R
x <- -log(1 - runif(n))
```

Why is this bad?  First off, it's exactly equivalent to:

```R
x <- -log(runif(n))
```

because if $X ~ U(0, 1)$, $1 - X ~ U(0,1)$ --- and, yes I
know about the very unlikely corner case.

But even better, it's also equivalent to:

```R
x <- rexp(n)
```

because as any fule kno, this is exactly the invert-the-cdf method
for generating standard exponentials. Learn your distributions, folks.
