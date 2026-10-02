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

= Publications

- Naguib et al 2026. #link("https://arxiv.org/abs/2607.17908")[PIONEER: Bayesian Joint Modelling of Mechanistic
  Tumour Growth and Time-to-Event Endpoints for Dynamic Prediction of Ongoing Oncology Trials]
- Gendrin-Brokmann et al 2024. #link("https://doi.org/10.1016/j.ibmed.2024.100152")[Investigating deep-learning
  NLP for automating the extraction of oncology efficacy endpoints from scientific literature]
- Patwardhan et al 2024. #link("https://doi.org/10.3389/fimmu.2024.1383644")[Towards a survival risk prediction
  model for metastatic NSCLC patients on durvalumab using whole-lung CT radiomics]
- Gendrin et al 2023. #link("https://doi.org/10.2196/44876")[
Identifying Patient Populations in Texts Describing Drug Approvals Through Deep Learning–Based Information Extraction: Development of a Natural Language Processing Algorithm]
- Urbas et al 2020. #link("https://doi.org/10.1093/biostatistics/kxaa036")[Interim recruitment prediction
  for multi-center clinical trials]
- Mukhopadhyay et al 2020. #link("https://doi.org/10.1080/10543406.2020.1815035")[Statistical and practical
   considerations in designing of immuno-oncology trials]
- Davies et al 2019. #link("https://doi.org/10.1016/j.ijmedinf.2019.104008")[Biomarker data visualisation for
  decision making in clinical trials]
- FitzGerald et al 2018. #link("https://doi.org/10.1016/S2213-2600(17)30344-2")[Predictors of enhanced response
  with benralizumab for patients with severe asthma: pooled analysis of the SIROCCO and CALIMA studies]
- Sechidis et al 2018. #link("https://doi.org/10.1093/bioinformatics/bty357")[Distinguishing prognostic and
  predictive biomarkers: an information theoretic approach]
- Vella et al 2007. #link("https://doi.org/10.1063/1.2747235")[Surface tension dominated impact]
- Vella et al 2006. #link("https://doi.org/10.1017/S0022112005008013")[Equilibrium conditions for the floating
  of multiple interfacial objects]
- Metcalfe 2005. #link("https://doi.org/10.1098/rspa.2004.1397")[Ribbed Elastic Structures under a Mean Flow]
- Hinch et al 2004. #link("https://doi.org/10.1098/rspa.2004.1327")[Shock-like Free-Surface Perturbations
  in Low-Surface-Tension, Viscous, Thin-Film Flow Exterior to a Rotating Cylinder]
