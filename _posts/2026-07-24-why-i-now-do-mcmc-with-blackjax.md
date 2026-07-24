---
layout: post
title: "Why I now do MCMC with blackjax"
categories: statistics programming numerics
---

Boy, it's been quiet here for a while.

I was an early adopter of the wonder that is [Stan](https://mc-stan.org/), but
these days (because JAX FTW[^jax]) I'm now doing most of my Bayes in [BlackJAX](https://blackjax-devs.github.io/blackjax/). Herewith a small [eight schools](https://github.com/pdmetcalfe/jax-eight-schools) example, mostly so that I
have a canonical pattern to point at the next time I need to write a model. For those who haven't yet met it, eight schools (Rubin, 1981) is the [drosophila](https://en.wikipedia.org/wiki/Drosophila) of Bayesian computation --- eight SAT coaching programs, each with an estimated effect and a standard error, and the question of how much to shrink each estimate towards the others.

[^jax]: If you do not yet know about JAX, immediately go away and [read this](https://docs.jax.dev/en/latest/index.html).

### The model

Each school $$j$$ has an observed effect $$y_j$$ with known standard error
$$\sigma_j$$, drawn from a school-specific true effect $$\theta_j$$:

$$
y_j \sim N(\theta_j, \sigma_j^2).
$$

The $$\theta_j$$ are themselves drawn from a population distribution:

$$
\theta_j \sim N(\mu, \tau^2), \qquad \mu \sim N(0, 5^2), \qquad \tau \sim
\text{Half-Cauchy}(5).
$$

That's it. The interesting bit is how you parameterize it for a
sampler. Written as above --- $$\mu$$, $$\tau$$, and eight $$\theta_j$$ as
free parameters --- you get Neal's funnel: when $$\tau$$ is small, the
$$\theta_j$$ are pinned tightly to $$\mu$$, and the posterior develops a
narrowing throat that gradient-based samplers fall into and can't climb out
of. The standard fix is to reparameterize non-centered:

$$
\theta_j = \mu + \tau z_j, \qquad z_j \sim N(0, 1).
$$

Now $$\mu$$, $$\tau$$, and the $$z_j$$ are only loosely coupled, and NUTS
stops choking on the geometry. This is the one piece of domain knowledge you
need going in; everything else is bookkeeping.

### Two kinds of parameters

The repo splits "the parameters" into two classes, and getting that right is the trick.

[`Parameters`](https://github.com/pdmetcalfe/jax-eight-schools/blob/main/jax_mcmc/parameters.py)
lives on the natural, constrained scale --- the scale a statistician thinks
in. It knows the model (and also our non-centered reparametrization):

~~~ python
class Parameters(eqx.Module):
    global_mean: jax.Array
    z_school_effect: jax.Array
    global_sigma: jax.Array

    def school_effect(self) -> jax.Array:
        return (
            self.global_mean[..., None]
            + self.global_sigma[..., None] * self.z_school_effect
        )

    def prior(self) -> jax.Array:
        return (
            jsp.stats.norm.logpdf(self.global_mean, loc=0, scale=5)
            + jsp.stats.cauchy.logpdf(self.global_sigma, scale=5)
            + jsp.stats.norm.logpdf(self.z_school_effect).sum(axis=-1)
        )

    def log_likelihood(self, data: Data) -> jax.Array:
        return jsp.stats.norm.logpdf(
            data.effect, loc=self.school_effect(), scale=data.stderr
        )

    def log_pdf(self, data: Data) -> jax.Array:
        return self.prior() + self.log_likelihood(data).sum(axis=-1)
~~~

Every field here is exactly what's in the maths above: `global_mean` is
$$\mu$$, `global_sigma` is $$\tau$$, `z_school_effect` is the vector of
$$z_j$$. `school_effect` computes $$\theta_j$$ from them, and `log_pdf` is
just the log posterior, built out of ordinary named pieces.
Nothing here knows or cares about NUTS, warmup, or
sampling at all --- it's a description of the statistics, full stop.

The `[..., None]` broadcasting is there on purpose. Because
`Parameters` is a registered JAX pytree, there's no reason its fields
have to hold a single draw. Run the sampler and you get `Parameters` whose
fields have shape `(chain, draw)` or `(chain, draw, num_schools)`, and every
one of these methods keeps working unmodified, because the arithmetic was
written to broadcast rather than to assume a shape. You get vectorization
over chains and draws for free, without threading a batch axis through the
model code by hand.

[`Position`](https://github.com/pdmetcalfe/jax-eight-schools/blob/main/jax_mcmc/parameters.py),
by contrast, knows nothing about schools or hierarchies. It exists purely
because NUTS does leapfrog integration in an unconstrained space, and
$$\tau$$ is constrained to be positive:

~~~ python
class Position(eqx.Module):
    global_mean: jax.Array
    z_school_effect: jax.Array
    log_global_sigma: jax.Array

    @property
    def log_jacobian(self) -> jax.Array:
        return self.log_global_sigma

    def to_parameters(self) -> Parameters:
        return Parameters(
            self.global_mean, self.z_school_effect, jnp.exp(self.log_global_sigma)
        )

    def log_pdf(self, data: Data) -> jax.Array:
        return self.log_jacobian + self.to_parameters().log_pdf(data)
~~~

`Position` holds $$\log \tau$$ instead of $$\tau$$, maps back to
`Parameters` with `exp`, and corrects the density with the log absolute
Jacobian of that transform --- which, for $$\tau = e^{\log \tau}$$, is just
$$\log \tau$$ itself.

### The pattern, generalized

This is how I now do any Bayesian model:

1. Write one class in natural, constrained units, with `prior` and
   `log_likelihood` methods that read like the maths.
2. Write everything in that class to broadcast rather than assume a
   fixed shape, so a single leading axis or three give you chains and draws
   for nothing.
3. Write a second, thin class that holds the same information in
   unconstrained coordinates, with a transform back to the first class and
   the log Jacobian of that transform. Resist the temptation to put any
   model-specific logic here --- if it needs a `log_likelihood`, that logic
   belongs in the first class instead.
4. Hand the sampler only the unconstrained class's `log_pdf`. Convert back
   to natural units once, after sampling, for anything downstream ---
   diagnostics, plots, reporting --- that a human is going to read.

### A brief coda on the sampler

[`sampler.py`](https://github.com/pdmetcalfe/jax-eight-schools/blob/main/jax_mcmc/sampler.py)
runs one NUTS chain per device via `jax.shard_map` over `jax.vmap`, each
chain getting its own window-adapted step size and mass matrix from
`blackjax.window_adaptation` before sampling. There's nothing conceptually
new here beyond "vmap a chain function, shard it over devices". Because `Position` and `Parameters` already broadcast correctly, the sampler code doesn't have to know it's running four chains at once instead of one.
[`inference_data.py`](https://github.com/pdmetcalfe/jax-eight-schools/blob/main/jax_mcmc/inference_data.py)
then hands the constrained-space `Parameters` and the NUTS diagnostics off
to [ArviZ](https://python.arviz.org/), and the rest is your problem[^bayesian-workflow] rather than mine.

[^bayesian-workflow]: Read [this book](https://avehtari.github.io/Bayesian-Workflow/) now.