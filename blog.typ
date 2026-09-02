#import "/.calepin/calepin.typ" as calepin

#let _meta(page, key, default: none) = {
  let meta = page.at("meta", default: (:))
  if type(meta) == dictionary {
    meta.at(key, default: default)
  } else {
    default
  }
}

#let _date(page) = _meta(page, "date", default: "unknown")

#let _listing-thumbnail(page) = {
  let thumbnail = _meta(page, "thumbnail", default: none)
  if thumbnail != none {
    thumbnail
  } else {
    let path = page.at("path", default: none)
    if type(path) != str or not path.ends-with(".typ") {
      none
    } else {
      let stem = path.slice(0, path.len() - 4)
      let results-path = "/.calepin/" + stem + "/results.json"
      let results-doc = json(results-path)
      let image-paths = ()
      for (_, chunk) in results-doc.at("chunks", default: (:)).pairs() {
        for item in chunk.at("items", default: ()) {
          let data = item.at("data", default: none)
          if type(data) == dictionary {
            for (mime, value) in data.pairs() {
              if type(mime) == str and mime.starts-with("image/") {
                let image-path = value.at("path", default: none)
                if type(image-path) == str {
                  image-paths.push(image-path)
                }
              }
            }
          }
        }
      }
      if image-paths.len() == 0 {
        none
      } else {
        image-paths.first()
      }
    }
  }
}

#let _listing-asset(path) = {
  if type(path) != str {
    none
  } else if path.starts-with("http://") or path.starts-with("https://") {
    path
  } else if path.starts-with("/") {
    calepin._resolve-asset-path(path)
  } else {
    calepin._resolve-asset-path("/" + path)
  }
}

#let entries(source, kind: none, language: none) = {
  source
    .filter(page => kind == none or _meta(page, "kind") == kind)
    .filter(page => language == none or page.at("language", default: none) == language)
    .filter(page => _meta(page, "draft", default: false) != true)
    .sorted(key: _date)
    .rev()
}

#let listing(title, source, kind: "post", language: none) = {
  let year = none;
  if title != none {
    [= #title]
  }
  let items = entries(source, kind: kind, language: language)
  for page in items {
    let page_date = _date(page)
    let page_year = page_date.split("-").at(0)
    
    if page_year != year {
        [== #page_year]
      year = page_year
    }
    [ - #link(page.href)[#page.title] ]
  }
}

#set document(title: [Blog])
#metadata((title: "Blog", translation_key: "blog")) <website-metadata>

#title()

All posts, sorted from newest to oldest.

#listing("Posts", calepin.pages(), kind: "post", language: "en")
