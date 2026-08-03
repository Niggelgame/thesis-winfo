#import "frontmatter/declaration-of-authorship.typ": *

#let std-bibliography = bibliography

#let default-backmatter(
  bibliography: [],
  bib-style: "",
) = {
  set std-bibliography(style: bib-style)
  bibliography


  pagebreak(weak: true, to: "odd")

  declaration-of-authorship(
    city: "St. Ingbert",
  )
}
