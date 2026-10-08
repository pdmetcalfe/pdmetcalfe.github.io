#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Science in the age of AI])
#metadata((
  title: "Science in the age of AI",
  kind: "post",
  date: "2026-10-08",
  tags: ("rants", "AI", "boring stuff like statistics"),
  summary: "people are weird",
)) <website-metadata>

#title()

One of the particular joys of the current AI boom is getting asked by
hopeful optimists
such as your line manager or the folks from the Other Functions things like "what can
AI do for me?" or "can AI solve this for me?"#footnote[Before you tear your hair out,
remember that you are fortunate that the folks
from the Other Functions are talking to you rather than going to some contractor who'll
do exactly what they're asked. And note also that there is nothing particularly unique about "AI" --- 
a hype cycle is a hype cycle and some years ago this post could quite easily have been written about
#link("https://eprint.iacr.org/2017/375.pdf")[blockchain], for instance.]. And the
field in question being drug development, "this" is always "what patients will benefit from my
molecule-in-development"#footnote[The concept that
_no_ patients might benefit from your molecule-in-development is an alien philosophy.
Like Lake Wobegon, all our children are above average.].

This is a good point in your life to go
and reread Feynman's #link("https://calteches.library.caltech.edu/51/2/CargoCult.htm")[cargo cult science]
essay, eat your initial answer of "oh no, not again", and only once you've done that go on to treat
these questions as an invitation to talk, rather than
as a set of serious proposals#footnote[Remember, no-one _actually_ knows what "AI" is, and the answers to the
questions as asked are probably "nothing good" and "no" in that order. Remember too
that in any given project there are three different things to worry about:

+ What the stakeholder asks for,
+ What the stakeholder actually wants,
+ What the stakeholder actually needs,

and your job is to move from the first to the last without causing any more upset than
necessary.]. The _actual_ question is always something more like "I have data on 20
patients and a cat on a single-arm trial, and I want to find a subgroup with
differential treatment effect against standard-of-care in a clinical trial I haven't done".

The best approach here --- if your interlocutor or their problem is sufficiently
important#footnote[All the other problems that you and your team are working on are likely
  more important than #link("the-best-model-I-ever-built.html")[this thing that's turned up out of the blue],
  and "I'm sorry, I'm happy to chat but we're very busy at the moment on projects P, Q, and R" is a valid answer.
  Don't play this one too often, and beware getting the "_Very Senior Leader_ wants this" response.
  You need to be savvy enough to know that and to communicate that _Very Senior Leader_ wants projects
  P, Q, and R more.] --- is to very carefully and gently elicit their prior
knowledge#footnote[This is _hard_. You need to pitch your questioning just right so you don't
come across as a querulous pedant, and you may need
to play the "OK, I'll go away and come back with some proposals" game.]
and to very carefully and gently educate on the limitations imposed by sample size.
The ideal outcome is either to make your interlocutor realize that they have
asked for the impossible or to shape their question towards a
statistical approach that _might_ be valid enough with the scarcity of data they have ("we can't do _that_,
but here's what we _can_ do").
If you are lucky and you do this well you gain influence as a pragmatic realist and your
interlocutor will go back to their own function and sing your praises#footnote[If you
do it badly you will lose influence because you are a closed-minded pedant rather than a
creative and open-minded AI type.]. If you are *really* lucky your interlocutor
will bring you or your folks into the Other Function so you can help steer towards sanity. If you are
*really* *really* lucky you might be able to use the phrase "autocomplete on crack"
and have it influence organizational thinking.

But, pharma being pharma, you can guarantee that there's some optimist somewhere
"training a foundation model" on your 20 patients and a cat#footnote[The optimist
would say something like "foundation models, transfer learning, and pretraining on external/public
data are precisely the tools that work around small-$n$ problems". The optimist
is unfortunately incorrect. The step that actually answers
"does this subgroup show differential treatment effect" is a fit of an outcome (treatment × 
subgroup interaction) onto model features using the local $n=20$. That last-mile fit is
exactly classical regression (possibly gussied up with some form of shrinkage).
A brave optimist will then start to say things like
"priors", "meta-analysis", and "hierarchy". At this stage of the process you can consider
walking out to the car park and
screaming very loudly "why are you describing Bayesian statistics?". Once you've done
that, point your optimist to #link("https://doi.org/10.1136/bmj-2023-078378")[TRIPOD+AI].
And hope. Do not at any stage reflect on the agonizing pain suffered by any statistician
who has tried to talk a stakeholder out of dichotomization and wonder why The Stakeholder
is prepared to accept output from a massively nonlinear stochastic black box.].