
#let def_count = counter("definitioncounter")


#let definition = (title, content) => {
  def_count.step()

  
  context[#block(breakable: false, inset: (left: 15pt))[
    *Definition #def_count.get().first()* _#[#title]_#label(title): #content
  ]]
}

#let ref_def = (title) => {
  context[#link(label(title))[_Def. #def_count.at(label(title)).first()_]]
}
