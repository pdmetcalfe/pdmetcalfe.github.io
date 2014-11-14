---
layout: post
title: "Optimized linear algebra is faster than pessimized linear algebra"
categories: numerics programming R
---

[A recent post on benchmarking
R](http://www.brodrigues.co/2014/11/11/benchmarks-r-blas-atlas-rro/)
suggests that the thing to do is use Revolution R - because it's
fastest on a linear algebra rich benchmark.  Why would that be?

The relevant thing here is that Revo R is linked against the Intel
MKL; that which is referred to as "vanilla" R is linked against
something that isn't too far from the [reference
BLAS](http://www.netlib.org/blas/).

Let's have a look at the difference with some particularly awful C.

~~~C
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#define SIZE 5000

void dgetrf_(int*, int*, double*, int*, int*, int*);

void rand_fill(double* x, size_t size) {
  for(;size;--size, ++x) {
    *x = rand() / (1.0 + RAND_MAX);
  }
}

int main() {
  double* work = malloc(SIZE * SIZE * sizeof(double));
  int* ipiv = malloc(SIZE * sizeof(int));
  int dim = SIZE;
  int ind, info;
  clock_t start, end;
  if (!(ipiv && work)) {
    fprintf(stderr, "Buy a better box.\n");
    exit(-1);
  }
  rand_fill(work, SIZE * SIZE);
  start = clock();
  dgetrf_(&dim, &dim, work, &dim, ipiv, &info);
  end = clock();
  if (info) {
    fprintf(stderr, "You're massively unlucky.\n");
  }
  /* let's ensure this does something */
  for (;dim;dim--,++ipiv) {
    info += *ipiv;
  }
  printf("%i\n", info);
  printf("%f\n", (end - start)/((double)CLOCKS_PER_SEC));
}
~~~

What this does is generate a random 5000x5000 matrix and compute its
LU factorization[^invertibility].  The LU factorization bit is a standard bit of
linear algebra and its the first thing to try to work out how fast a
linear algebra library is.  Linked against the reference BLAS, the
best of 5 runs is 37.5s.  Now let's try
[ATLAS](http://math-atlas.sourceforge.net/) - to get 9.27s. Now let's
try [OpenBLAS](http://www.openblas.net/) - to get 8.94s.

[^invertibility]: Remember, almost all - in the technical sense - matrices are invertible, so if you get "You're massively unlucky" you _really really_ are.  Don't walk under any ladders.

What we have learnt: the speed of linear algebra is directly related
to the quality of the linear algebra library.  So if you _must_
you can run R against the MKL, which is the best for this particular
benchmark. But I've done enough HPC to know that if you really care
you should always use the vendor's optimized linear algebra.  If you
want an easy but good life, use OpenBLAS or ATLAS.  If you're an idiot
have *this*
(lollipop)[http://en.wikipedia.org/wiki/Lollipop]
and use the reference BLAS.

In related news, the Pope *is* Catholic and bears do _unspeakable_
things in the woods.

What I've learnt from this exercise is that I should probably be using
OpenBLAS rather than ATLAS, so this wasn't a total loss.

How did I switch between these?  Well, I'm an adult and I use
(Debian)[http://debian.org/], so this was just a bit of
update-alternatives jiggery pokery.

If you've read this far and care about doing benchmarking rigorously,
this machine was pretty much the cheapest thing that Dell sold
whenever I bought it.  Oh, and I have to admit that I haven't really
looked at the R benchmarks cites, but, hey.