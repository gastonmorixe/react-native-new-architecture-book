// Extra Typst passed to pandoc via --include-in-header.
// Page break before each Part (H1) and Chapter (H2).
// A Chapter right after its Part heading stays on the same page.
#let mdpdf-prev = state("mdpdf-prev-level", 0)
#show heading: it => {
  if it.level <= 2 {
    context {
      let prev = mdpdf-prev.get()
      if it.level == 1 or prev != 1 { pagebreak(weak: true) }
    }
    mdpdf-prev.update(it.level)
  } else if it.level == 3 {
    // keep state untouched
  }
  it
}
