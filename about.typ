#import "/.calepin/calepin.typ" as calepin

#set document(title: [About me])
#metadata((title: "About me", translation_key: "about")) <website-metadata>

#title()

I am Paul Metcalfe, am an applied mathematician by training, and have been doing
semi-useful things in drug development for the past 14 years, for most of that
leading a team of statistical / computational experts. Before my pharma phase
I was briefly the world expert in silent underwater
breakfasts#footnote[it's not a _large_ field of study].

= Things that interest me

#calepin.elements.card[
/ #link("https://docs.jax.dev/en/latest/")[JAX]: is the nicest way in the world to write
  the kind of linear algebra that's used for things like deep learning (or, more usefully,
  for bayesian things).
/ #link("https://blackjax-devs.github.io/blackjax/")[blackjax]: is my current favourite way
  to do #link("./posts/2026/why-i-now-do-mcmc-with-blackjax.html")[Bayes Stuff].
/ #link("https://rust-lang.org/")[rust]: current favourite programming language (I've been through
  C++, #link("https://python.org/")[python],
  #link("https://lisp-lang.org/")[common lisp],
  #link("https://haskell.org/")[haskell], and various others all the way back to
  #link("https://en.wikipedia.org/wiki/BBC_BASIC")[BBC BASIC])
  but I'm now on rust.
/ #link("https://arrow.apache.org/")[Apache Arrow]: if you do do data and do not do Arrow you are
  behind the times.
/ #link("https://proceedings.mlr.press/v5/carvalho09a.html")[horseshoe prior]: and other ways to
  sanely do inference in high dimensions.
/ #link("https://www.tripod-statement.org/")[TRIPOD]: what you actually have to think about if you
  want to make statistical prediction models actually work#footnote[_A fortiori_ this includes ML and AI.].
/ dog training: I have a Doberman and a working-line spaniel, and do a bunch of (mostly) positive training with
  them. I _really_ want a Malinois, but lack the necessary 48 hours in the day.
]