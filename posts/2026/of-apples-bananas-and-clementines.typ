#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Of apples, bananas, and clementines])
#metadata((
  title: "Of apples, bananas, and clementines",
  kind: "post",
  date: "2026-09-21",
  tags: ("maths", "interviews"),
  summary: "surviving maths interviews unscathed",
)) <website-metadata>

#title()

Your hero has a former life interviewing prospective university maths undergraduates. The standard
approach for doing this is to ask them questions a little bit harder than they should
be able to solve directly, where they have to put a few different ideas together, and then see what happens.
Does the student get stuck in, do they flounder? Do they get bogged down in arithmetic or algebra, or
are they sufficiently fluent to do the mechanical bits on autopilot and save brain space for actual ideas.
Good questions are hard to come up with... but here's
one I produced#footnote[These questions eventually make their way onto the internet and have to
be replaced; this one already has, so don't treat it as a hint. That having been said,
"sketch $e^(-x^(-2))$" has been an old chestnut for at least a quarter-century, and candidates
show little sign of having noticed.]. The art of these questions is to start
simple and to be able to push them almost arbitrarily far.

#calepin.elements.callout(kind: "tip", title: [The Question])[
  Given only a fair coin, how can I choose fairly between three different
objects?#footnote[The standard introduction: "After this interview I want to have a snack. I have a choice of
an apple, a banana, or a clementine. I have no reason to prefer any of them and because I am a mathematician
and therefore _very very weird_ I want to choose perfectly fairly between them. But I only have a fair coin. How can I do it?"]
]

This is of course a _mathematical_ fair coin, that perfect coin that produces heads or tails
with exactly $50:50$ odds. The first step is realizing that there is a problem. Some students
grovel around a bit (variants on "choose between item 1 and item 2, item 2 and item 3,
item 3 and item 1"). The crucial idea is that with our coin we can choose fairly on a sample-space
of size $2^n$ in $n$ coin tosses -- but to choose between our 3 items we need $3$ to divide $2^n$.
And that can't work#footnote[This step -- although
conceptually simple -- is hard to come up with from cold.].

The simplest approach is "throw the coin twice: HH gives item 1, HT gives item 2,
TH gives item 3, TT -- throw it again twice". Then, conditional on making a choice,
we see that we clearly choose fairly. But this is also a difficult step to get to.
The simplest way is for the interviewer to frame the problem as a choice between an apple,
a banana, a clementine, and an imaginary doughnut. Most students get the choice between
four objects as two coin tosses; then they need to reject the imaginary doughnut.

So if the candidate gets to this stage easily we can ask how many coin tosses it takes to make a choice.
The hope here is that the candidate gets to the geometric distribution; the probability we make a choice
at the $n^"th"$ step is $3/4 (1/4)^(n-1)$. Compute an expectation $sum_(n >= 1) n (3/4) (1/4)^(n-1) = 4/3$#footnote[This
is bookwork, go look it up...] and then remember that each step is two coin
tosses#footnote[Candidates who make it this far are likely to forget this factor of two and will then get
asked why they think they can do this in $approx 1.3$ coin tosses.] to say that it
takes $8/3$ coin tosses to produce 1 choice between 3 objects.

What have we tested so far? Technically -- not, actually, a lot. Understanding of the size of a
sample space and that no matter how far you go you'll never find $3$ dividing $2^n$. Realizing that matters.
Realizing how to take the imaginary doughnut hint and see how to apply it. Then a bit of geometric distribution
dancing and that's really it.
More importantly, candidates have to connect ideas they've not connected before, work out how to apply them cleanly,
and realise the consequences thereof. When you interview potential undergraduates you're really trying to find
out how teachable they are and how fluently they can apply things they know. Candidates who get bogged down in
the algebra don't have the brain space to think about the new ideas, and questions like this _really_ show it.

= Why is this a good question?

+ There are no tricks: nothing in the question requires candidates to have a brilliant or unreasonable insight.
+ It's accessible: candidates don't need really complicated maths to get stuck in and there's no really painful
  algebraic manipulation. It just presents ideas candidates already know in a slightly unusual way.
+ It's extensible: even if candidates make it cleanly and fluently to the end of the geometric series the
  interviewer can push further.#footnote[Suppose you have _lots_ of choices
  between 3 objects to make. Given only a fair coin, how can you do it? How many coin tosses per 3-choice
  does it take? You can just about push our geometric series approach to get to $log_2 3$ -- and now we've
  gone from a simple interview question to Shannon entropy. No candidate in the history of
  candidates has made it this far.]

= Advice to candidates

From this interview question you can derive a few reusable principles.

- The point is to give you things you've not seen before and see how you handle stuckness. So expect that. Being
  pushed out of your comfort zone is a good sign.
- Remember the big picture of what you're doing; don't get bogged down in minutiae and do remember why your
  calculations matter.
- Your interviewer will try to help you if necessary, so if they ask you stupid questions about imaginary
  doughnuts, they have _probably_ not gone mad.
- Practice your algebra & calculus. If you are not _fluent_ you will have a seriously bad time in the stress
  of an interview, no matter how kind your interviewer is being.#footnote[This also comes up in Real Life. I have
  interviewed any number of prospective data scientists who claim to understand random-deep-learning-architecture-of-choice
  but are unable to talk about #link("https://en.wikipedia.org/wiki/Generalized_linear_model")[GLMs] convincingly.]
- Problem framing matters. There's quite a large conceptual step between "I want to choose a snack" and "you can't
  get $3$ to divide $2^n$ no matter how far you go". Again, this is testing how fluently you apply things you know.
