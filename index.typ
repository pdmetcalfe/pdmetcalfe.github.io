#import "/.calepin/calepin.typ" as calepin

#set document(title: [My little bit of the web])
#metadata((title: "Home", translation_key: "home")) <website-metadata>

#calepin.setup(
  echo: true,
  eval: false,
  fenced-chunks: true,
)

#let target = sys.inputs.at("calepin-target", default: "paged")

#show: body => {
  if target == "html" {
    body
  } else {
    set page(columns: 2)
    body
  }
}

#title()

This is my little home on the web, where I can whinge about things that irritate me (and possibly do useful things as well).

#if target == "html" {
  html.elem("img", "", attrs: (
    class: "calepin-float-right calepin-scaffold-portrait",
    src: "assets/portrait.jpg",
    alt: "One man and his dog",
    width: "1440",
    height: "1440",
    loading: "lazy",
    decoding: "async",
  ))
} else {
  place(
    top + right,
    float: true,
    clearance: 1em,
    image("/assets/portrait.jpg", width: 32%),
  )
}
