#let signature(
  city:"",
  date:none,
  name:"",
) = {
  grid(
    columns: (auto, auto),
    align(left)[
      #city, 03. August 2026
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
  set heading(outlined: false, numbering: none)

  page(
    footer: [],
    [
      == Eidesstattliche Erklärung
      Ich erkläre an Eides statt, dass ich die vorliegende Arbeit selbstständig und ohne die Beteiligung
      Dritter verfasst habe und keine anderen Quellen und Hilfsmittel als die angegebenen benutzt habe.
      Alle Stellen der Arbeit, die wörtlich oder sinngemäß aus Veröffentlichungen oder anderweitigen
      fremden Äußerungen entnommen wurden, sind als solche kenntlich gemacht. Ich versichere des
      Weiteren, dass die elektronische Version mit der gedruckten Version übereinstimmt.

      Insbesondere bestätige ich hiermit, dass ich alle mittels künstlicher Intelligenz betriebenen Software
      (z. B. ChatGPT) generierten und/oder bearbeiteten Teile der Arbeit unter Angabe des Prompts, des
      verwendeten Modells, des Datums und der Zeit der Interaktion kenntlich gemacht und als Hilfsmittel
      angegeben habe. Ich erkläre mich damit einverstanden, dass die Arbeit mit einer Plagiatssoftware
      überprüft wird.
      
      Mir ist bewusst, dass der Verstoß gegen diese Versicherung zum Nichtbestehen der Prüfung bis hin
      zum Verlust des Prüfungsanspruchs führen kann.

      Ich habe ausschließlich die folgenden Hilfsmittel benutzt:

      - GitHub Copilot Inline Suggestions: Integriert in Visual Studio Code, verwendet es künstliche Intelligenz, um Autovervollständigung und Code-Vorschläge während der Implementierung zu erstellen.

      #v(100pt)
      #signature(city: city, date: date, name: name)
    ]
  )

  pagebreak(weak: true, to: "odd")
}
