#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [A hanging chain])
#metadata((
  title: "A hanging chain",
  kind: "post",
  date: "2026-09-10",
  tags: ("maths"),
  summary: "cool maths",
)) <website-metadata>

#title()

I remember reading Feynman II back in my youth and being blown away
by #link("https://www.feynmanlectures.caltech.edu/II_19.html")[the calculus of variations chapter],
and immediately trying to play with it in every single different context I could.
This is one of them, slightly more complex than those in the gospel according to RPF. We're going to go on
a route around the world and end up in a perhaps unexpected place.

Suppose you've got a chain hanging under gravity. What shape does it take?
Let's parametrize the shape as $(x(s), y(s))$ where $s$ is arc length. Then
its potential energy is
$
  integral_0^L rho g y(s) dif s
$
where $L$ is total length, $rho$ is mass-per-unit-length and $g$ is, of
course, gravity. When the chain is in steady state this will be at a
minimum.

But, I hear you say, this clearly has no minimum because $y$ can be made
arbitrarily negative. There is a trick --- remember I said that $s$ is
arc length. We need to include that constraint in our minimization; what we
actually minimize is

$
  cal(L) = integral_0^L rho g y(s) + lambda(s)/2 (((dif x)/(dif s))^2 + ((dif y)/(dif s))^2 - 1) dif s
$

where $lambda(s)$ is a Lagrange multiplier to enforce the arc length constraint
#footnote[If I was a real man I would use $lambda(s) (sqrt(((dif x)/(dif s))^2 + ((dif y)/(dif s))^2) - 1)$, but
we will in fact get the same differential equations back from our version.].
It'll actually turn out to be the tension in the chain.

Now the calculus of variations trick. What we're going to do is to say that
$cal(L)$ is stationary with respect to first-order variations in $x(s)$, $y(s)$,
and $lambda(s)$.  This is exactly the same "stationary to first order" trick
that works for minimization of functions, here played on this integral. Let's
set $x(s) |-> x(s) + delta x(s)$, $y(s) |-> y(s) + delta y(s)$, and
$lambda(s) -> lambda(s) + delta lambda(s)$ and catch the first order terms. We get
$
delta cal(L) = integral_0^L rho g delta y(s) + (delta lambda(s)) / 2 (((dif x)/(dif s))^2 + ((dif y)/(dif s))^2 - 1) + 
  lambda(s) ( (dif x)/(dif s) (dif delta x)/(dif s) + (dif y)/(dif s) (dif delta y)/(dif s)) dif s,
$
and a bit of staring reveals that we've got $(dif delta x)/(dif s)$ and $(dif delta y)/(dif s)$ terms that
we don't know what to do with. So we need to get rid of them. Fortunately we remember that we can integrate by parts to get
$
  delta cal(L) = integral_0^L (rho g - (dif)/(dif s) (lambda(s) (dif y)/(dif s))) delta y(s) 
    - ((dif)/(dif s) (lambda(s) (dif x)/(dif s))) delta x(s)
    + (((dif x)/(dif s))^2 + ((dif y)/(dif s))^2 - 1) (delta lambda(s)) / 2 dif s.
$

The endpoint terms go away because we require $delta x(0) = delta y(0) = delta x(L) = delta y(L) = 0$ ---
the chain is fixed at its start and end and our variations $delta x$ and $delta y$ must respect that.

= Differential equations for fun and profit

Our variational terms are otherwise arbitrary, so if we want first-order variations to be
zero (i.e. stationary energy) we get
$
  (dif)/(dif s) (lambda(s) (dif y)/(dif s)) &= rho g, \
  (dif)/(dif s) (lambda(s) (dif x)/(dif s)) &= 0, \
  ((dif x)/(dif s))^2 + ((dif y)/(dif s))^2 &= 1.
$

We'll impose the conditions $y(0) = y(L) = 0$, $x(0) = -a$, $x(L) = a$, so that our
string hangs between $(-a, 0)$ and $(a, 0)$. Integrating the first two equations we get

$
  lambda(s) (dif x)/(dif s) &= rho g p, \
  lambda(s) (dif y)/(dif s) &= rho g (s - s_*).
$

in which $p$ and $s_*$ are constants of integration#footnote[I have been cunning and scaled the
constants appropriately because I know how this is going to go.]. Now we substitute into the
arc length constraint to get
$
  lambda(s)^2 = rho^2 g^2 ( p^2 + (s - s_*)^2)
$
and therefore#footnote[There is a choice of sign here: our optimization has two solutions --- a maximum
in which the chain goes up and a minimum in which the chain goes down. We want the minimum and have
chosen the _positive_ square root, and, slight subtlety, this means that $p>0$.]
$
  (dif y)/(dif s) = (s-s_*) / sqrt(p^2 + (s-s_*)^2),
$
giving
$
  y(s) = q + sqrt(p^2 + (s - s_*)^2).
$
We are almost home and dry:
$
  (dif x) / (dif s) = 1 / sqrt(1 + p^(-2) (s - s_*)^2).
$

Make the change of variable $s = s_* + p sinh theta$ to get $x = p (theta - theta_0)$, which we rewrite as

$
  y = q + p cosh(x/p + theta_0).
$

Continuing on our merry way we find $theta_0 = 0$ and
$
  y = p ( cosh x/p - cosh a / p ).
$

We get $p$ by solving $L = 2 p sinh a/p$; the simplest way to do this is to let
$p = a / xi$ and solve $L/(2 a) = (sinh xi) / xi$. Reassuringly, we see there is
no solution if $L < 2 a$. A perhaps slightly surprising result is that the shape
does _not_ depend on $rho$ or $g$ --- all heavy chains hang the same way. (This is
in fact not surprising: by redefining $lambda(s)$ we can factor $rho g$
out of our Lagrangian.)

(Some years ago those nice guys
#link("https://arxiv.org/abs/physics/0509009")[Vella, Metcalfe, and Whittaker]
did something very much like this for floating rafts.)

= Where this goes

Honestly, lots of places. One route ends up in Serious Numerical Analysis --- the
finite element methods that are the standard PDE solvers for solid mechanics and the
Sobolev spaces that are the mathematical theory thereof
#footnote[If you try solving our problem this way, note that our Lagrangian integral needs $x(s)$
and $y(s)$ to have square integrable derivatives, and $lambda(s)$ just has to be integrable.
The simplest way of doing this is to let $x(s)$ and $y(s)$ be piecewise linear,
and $lambda(s)$ be piecewise constant. You'll find (once you factor $rho g$ out of $lambda$)
$
  0 &= lambda_(i-1/2)/delta_(i-1/2) (x_i - x_(i - 1)) + lambda_(i+1/2)/delta_(i+1/2) (x_i - x_(i + 1)), \
  0 &= 1/2 delta_(i-1/2) + 1/2 delta_(i+1/2) + lambda_(i-1/2)/delta_(i-1/2) (y_i - y_(i - 1)) + lambda_(i+1/2)/delta_(i+1/2) (y_i - y_(i + 1)), \
  1 &= (x_(i+1) - x_i)^2/(delta_(i+1/2)^2) + (y_(i+1) - y_i)^2/(delta_(i+1/2)^2).
$
which you solve on $0 = s_0 < s_1 < ... < s_(N-1) < s_N = L$ with $x_0 = -a$, $x_N = a$, $y_0 = y_N = 0$
probably by using Newton
iteration from some initial guess (the linear algebra is sparse).]. Another
route ends up in the very beautiful
#link("https://doi.org/10.1007/978-0-387-21792-5")[Lagrangian and Hamiltonian]
formulations of physics.

And one _trivial and irrelevant_ byway that second route goes down is symplectic geometry,
where you learn that the iteration
$
  p_(n+1/2) = p_n - lr((partial U)/(partial q)|)_(q_n) (Delta t)/2 \
  q_(n+1) = q_n + p_(n+1/2) Delta t \
  p_(n+1) = p_(n+1/2) - lr((partial U)/(partial q)|)_(q_(n+1)) (Delta t) /2
$
#link("https://doi.org/10.1017/S0962492902000144")[exactly preserves the 2-form $dif p_n and dif q_n$]. And
*that* is the reason that Hamiltonian Monte Carlo methods are so effective, linking us neatly back to my usual
beat#footnote[When the AI folk start muttering about "hidden structure on the latent manifold" I feel a strong urge
to describe HMC as "iterated stochastic symplectic transformations on the cotangent bundle of the latent manifold".]. Maths... gotta know it all.