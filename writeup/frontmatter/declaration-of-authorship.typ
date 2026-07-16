#let signature(
  city:"",
  date:none,
  name:"",
) = {
  grid(
    columns: (auto, auto),
    align(left)[
      #city, #date.display("[day]. [month repr:long], [year]")
      #h(12pt)
    ],
    align(right)[
      #move(dy: 8pt, line(length: 100%, stroke: (thickness: 0.5pt)))
      #move(dy: 2pt,name)
    ],
  )
}

#let declaration-of-authorship(
  city: "",
  date: none,
  name: "",
) = {
  set heading(outlined: false)

  page(
    footer: [],
    [
      == Eidesstattliche Erklärung
      Hiermit versichere ich an Eides statt, dass ich diese Arbeit selbständig angefertigt und keine anderen als die angegebenen Hilfsmittel verwendet habe. Alle wörtlichen oder sinngemäßen Entlehnungen sind deutlich als Solche gekennzeichnet.


      #v(100pt)
      #signature(city: city, date: date, name: name)
    ]
  )

  pagebreak(weak: true, to: "odd")
}
