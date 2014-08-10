---
layout: post
title:  "Things I don't like seeing in R code #23"
categories: numerics rng rant R
---

This code is a personal bugbear.

~~~ R
x <- log(1 - runif(n))
~~~

Why is this bad?  First off, it's exactly equivalent to:

~~~ R
x <- log(runif(n))
~~~

(because if $$X \sim U(0, 1)$$, $$1 - X \sim U(0,1)$$)

But even better, it's also equivalent to:

~~~ R
x <- rexp(n)
~~~

because as any fule kno, this is exactly the invert-the-cdf method
for generating standard exponentials.

