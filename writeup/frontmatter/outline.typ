#import "outrageous-copy.typ" as outrageous

#let default-outline() = {
  show outline.entry: outrageous.show-entry.with(
    font: ("IBM Plex Sans", auto),
    vspace: (15pt, none),
  )

  show outline: it => {
    set heading(outlined: true)
    it
  }

  // Show outline
  outline(depth: 3)

  pagebreak(weak: true, to: "odd")

  show outline.entry: outrageous.show-entry.with(
    // the typst preset retains the normal Typst appearance
    ..outrageous.presets.outrageous-figures,
    prefix-transform: (location, lvl, prefix) => {
      let (supplement, _, _, number) = prefix.children

      let v = if number.text.ends-with(regex("[^\d]1[^\d]*")) and not number.text.starts-with("1") {
        v(10pt)
      }
      box[#numbering("1.", ..counter(heading.where(level: 1)).at(location))#v#number.]
    },
    font: ("IBM Plex Sans", auto),
    vspace: (15pt, none),
  )

  show outline: it => {
    set heading(outlined: true)
    it
  }

  // Show outline
  outline(title: "List of Figures", depth: 3, target: figure)
}
