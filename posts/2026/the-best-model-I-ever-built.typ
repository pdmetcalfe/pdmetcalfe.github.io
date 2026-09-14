#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [The best model I ever built])
#metadata((
  title: "The best model I ever built",
  kind: "post",
  date: "2026-09-14",
  tags: ("statistics", "oops"),
  summary: "I once built the perfect predictive model",
)) <website-metadata>

#title()

I once built a statistical prediction model with $"AUC" approx 0.99$, and in \$HOWEVER_MANY
years of doing this stuff that remains the most predictive model I have ever built. The
story is perhaps instructive. One of the Folks From The Other Functions turned up with
a dataset, a binary patient outcome, and A Bunch Of Data from a new assay they were testing
out. Being young, stupid, and helpful I of course engaged with this problem, and I was of
course clever enough to talk The Stakeholder through the problem and filter the dataset
down to the pre-outcome data. And I knew of course that you don't do clever stuff like oversampling
because you've got to deal with the patient cohort in front of you rather than the one
you want. Go me.

Feeling slightly proud of myself I built the model (ISTR it was gradient boosting). And
it worked. It worked almost perfectly. And whilst I was young and stupid I wasn't quite
_that_ young and stupid and fortunately did not go back to colleague-from-other-function with
"we can do this perfectly". When anything works better than it has any right to you first
suspect that you have enthusiastically kicked yourself in the _anatomy_ and fouled up your
coding. But, no, coding perfect.

Next step. What's the actual data?#footnote[Yes, I know _now_.] Plot it out, take a look, see
what's going on. And it was curious. About half the data seemed to saturate at a lower
limit of about $0.1$, the other half went down to $0.01$#footnote[The memory has fortunately faded
over the years so I make the numbers up, but it was that kind of thing.]. Well that's a bit odd.

And what's more, the upper half of the data all had $"outcome" = "yes"$, the lower half all had
$"outcome" = "no"$. So this is now something I need to talk to colleague-from-other-function
about. So I did. It went something like this.

#table(
  columns: 2,
  [*your hero*], [Hi --- I've noticed this weird thing in the data, take a look at this plot.],
  [*CFOF*], [What's going on here?],
  [*your hero*], [Well, you see \<insert explanation here\>],
  [*CFOF*], [That's what I expected --- we tested the patients-with-outcome with v1 of the assay
    and then when we saw it did something we went and tested the patients-without-outcome with
    v2, which has LLoQ 10 times smaller.],
  [*your hero*#footnote[Manfully resisting the urge to say something like "if you had wanted this to be a complete waste of time you could not have done better".]], [Ah, I see. That actually matters quite a bit.]
  )

Your hero then goes away, artificially censors the v2 data, and refits the model. The phrase
"coin toss" is appropriate at this stage of the discussion.

But, I once built a perfect model.
