#set document(title: [Linear algebra for statisticians])
#metadata((
  title: "Linear algebra for statisticians",
  kind: "post",
  date: "2014-08-10",
  tags: ("numerics", "rants"),
  summary: "me whinging about linear algebra dun rong",
)) <website-metadata>

#title()

In the beginning was linear algebra, and God looked upon it, and saw
that it was good.  Shortly after that, so did most of the rest of the
world --- so good, in fact, that *everyone* thought that they could
implement it correctly.  After all, it's just adding and dividing and
subtracting.  How hard can it be?

Doing linear algebra right is an utter crawling horror.  Many very
clever people have spent a very long time writing much very clever
code to do linear algebra accurately and efficiently.  You've got to
get the numerics right, you've got to work out how it all interacts
with CPU caching, you've got to worry about bugs.  Anyone who thinks
they can do better is either:

1. a world-class expert in scientific computing and applied numerical
   analysis, or 
2. clinically insane, or
3. both.

= Good ways to do this stuff

There's really only one good way; it's called #link("https://netlib.org/lapack/")[LAPACK]. 
OK, I'm a little behind the times, the cool kids are using things like FLAME and
Eigen these days.  But if you're using R or numpy or Julia or matlab
or octave you're really using LAPACK.  The trick here is:

1. never invert a matrix
2. never form the normal equations
3. never attempt to be clever
4. you probably don't want eigenvalues and certainly don't want
   eigenvectors

If you're writing your own compiled code, the answer is that you're
going to have to do LAPACK.  Yes, the LAPACK documentation
is... hard going.  And yes, it's written in Fortran.  And yes,
the function names look like someone sneezed on their keyboard and
just hit the letters with lumps on#footnote[There _is_ a logic to the
function names, but _believing_ that requires you to accept
that the limitations of Fortran in the 1970s should apply 50-odd
years later.]. But go away and sort it out.

There is a special circle of hell reserved for those who take one look
at LAPACK and run away and write their own linear system solver.  And
there's another one reserved for those who copy code out of a
well-known book.

And for the love of God, universities, please stop producing people
who think they can write Gaussian elimination unless they are
_actually_ Kahan.

= To save me future bother

This rant applies, almost unchanged, to the Fast Fourier Transform.
#link("https://fftw.org/")[FFTW] FTW.  And it applies, doubled, to
ODE solvers.  Go away and read the
#link("https://computing.llnl.gov/projects/sundials")[SUNDIALS documentation].
Don't come back.