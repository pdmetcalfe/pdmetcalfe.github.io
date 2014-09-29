---
layout: post
title: "Maximum entropy as common sense"
categories: maths statistics
---

Some tools are quite nice substitutes for having a well-defined
problem.  Let's suppose that someone has kidnapped your cat and will
only return it if you can produce a probability distribution on
$$1\dots 6$$ with mean $$5$$.  There's the obvious answer, of course,
but that's a bit of a special case and a bit boring.  What's the least
special answer to the question?

Amazingly enough problems like this come up surprisingly often ---
although I've yet to see it in the stated context.  In general, can
you produce a probability distribution that satisfies some constraint
but is otherwise underdetermined?

A sensible solution is surprisingly simple, but it does require a bit
of numerics (or grinding one's way through $$\tanh$$).  The trick is
to remember entropy.  Barring boring factors, the entropy of a
probability distribution is $$ \sum_i -p_i \log p_i $$ and is a
measure of the fuzziness of a distribution.

The maximum entropy distribution --- the distribution that maximizes
the entropy --- is of course the uniform.  (Jensen's inequality.)  But
if we maximize the entropy subject to constraints, we get the fuzziest
distribution possible compatible with the constraints.  In our case,
we want to maximize

$$
L = -\sum_i p_i \log p_i - \mu(1 - \sum_i p_i) - \nu(5 - \sum_i i
p_i)
$$

over $$p_i$$, $$\mu$$, and $$\nu$$.  ($$\mu$$ and $$\nu$$ are Lagrange
multipliers that enforce normalization and our mean constraint.)  We
find that

$$
p_i = \frac{\exp i \nu}{\sum_j \exp j \nu}.
$$

We've got to find $$\nu$$ by enforcing the mean constraint, most
conveniently done numerically.

~~~ R
cost <- function(x, s, target) {
    probs <- x * s
    probs <- probs - max(probs)
    probs <- exp(probs)
    probs <- probs / sum(probs)
    m <- s %*% probs
    m - target
}

s <- seq(1, 6, by=1)

vals <- seq(-2, 2, by=0.05)
t <- vapply(vals, cost, 0, s, 5)

plot(vals, t, type='l')

crit <- uniroot(cost, c(-2, 2), s, 5)
cost(crit$root,s , 5)

p <- exp(s * crit$root)
p <- p / sum(p)
p
~~~

And, behold, the cat is free.

If our catnapper is a statistical physicist and is shouting about
ensembles we can of course tell them that
$$
\frac{\sum_i i e^{\nu i}}{\sum_i e^\nu i} = S^{-1} \frac{\partial}{\partial \nu} S = \frac{\partial}{\partial \nu} \log S,
$$
where
$$
S = \sum_i e^{\nu i} = \frac{e^\nu - e^{7 \nu}}{1 - e^{\nu}}.
$$
