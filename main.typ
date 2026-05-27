#import "@preview/benplate:0.1.0": thesis, accent-color, todo
#import "frontmatter.typ": *
#import "backmatter.typ": *

#let author = "Nicolas Christian Edelmann"
#let date = datetime.today()

#show: thesis.with(
  title: "Heraklit X Fischertechnik Process Prediction using Transformers",
  author: author,
  date: date,
  frontmatter: default-frontmatter(
    university: "Saarland University",
    faculty: "Human and Business Sciences",
    field: "Business Informatics",
    type: "Bachelor Thesis",
    city: "Saarbrücken",
    author: author,
    date: date,
    advisor: "Prof. Dr. Peter Fettke",
    first-reviewer: "Prof. Dr. Peter Fettke",
    second-reviewer: "TODO Second Reviewer",
    abstract: todo[Write an abstract],
    acknowledgments: todo[Write your acknowledgments]
  ),
  appendix: [
    // Optional content for the appendix
  ],
  backmatter: default-backmatter(
    bibliography:  bibliography("references.bib"),
    bib-style: "apa"
  )
)

#include "introduction.typ"

#include "theory.typ"

#include "modelling.typ"

#include "implementation.typ"

#include "evaluation.typ"

#include "conclusion.typ"