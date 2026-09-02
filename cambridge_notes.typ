#set document(title: [Cambridge maths notes])
#metadata((
  title: "Cambridge maths notes",
  translation_key: "cambridge_notes")) <website-metadata>

#title()

Some years ago#footnote[OK: "more than a quarter-century ago"] I read the
#link("https://www.maths.cam.ac.uk/undergrad/undergrad")[Mathematical
Tripos]. Because my handwriting was even then famously awful, I took some
time to transcribe lectures into LaTeX, and even released them on the
then-new "WWW". Over the years they've shifted around, and are now
#link("https://github.com/pdmetcalfe/cambridge-maths/")[on github].

The Tripos has of course changed since those days#footnote[Presumably,
  reflecting how the world has changed since Noah came off the ark.], but oddly-enough maths
hasn't and the notes are still found useful. You may of course note that Parts
IIA and IIB no longer exist. After much debate by the faculty they were 
removed and replaced by Parts IIC and IID. Go figure.

#let courses = (
  (
    "IA", (
      ("Discrete Mathematics", "discrete"),
      ("Probability", "probab")
    )
  ),
  (
    "IB",
    (
      ("Analysis", "analysis"),
      ("Further Analysis", "fanalysis"), 
      ("Fluid Dynamics", "fluids"),
      ("Geometry", "geometry"),
      ("Methods", "methods"),
      ("Quadratic Mathematics", "quadratic"),
      ("Quantum Mechanics", "quantum"),
    )
  ),
  (
    "IIA", 
    (
      ("Dynamics of differential equations", "dde"),
    )
  ),
  (
    "IIB",
    (
      ("Dynamical Systems", "dyn-syst"),
      ("Electrodynamics", "electro"),
      ("Fluid Mechanics", "fluids"),
      ("Foundations of Quantum Mechanics", "fqm"),
      ("Methods of Mathematical Physics", "mmp"),
      ("Statistical Physics", "statphys"),
      ("Waves in Fluid & Solid Media", "waves"),
    )
  )
)

#{
  let cells = ()
  let github = "https://github.com/pdmetcalfe/cambridge-maths/tree/master"
  for (year, year_courses) in courses {
    cells.push(table.cell([Part #year], rowspan: year_courses.len()))
    for (course, slug) in year_courses {
      let url = (github, year, slug, "")
      cells.push(link(url.join("/"))[#course])
    }
  }

  table(
    columns: 2,
    table.header([Year], [Course]),
    ..cells,
  )
}