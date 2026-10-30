# PDF build

Builds one PDF of the whole book with `markdown-to-pdf.sh` (pandoc + typst).

    uv run pdf/build_book.py                # pdf/dist/react-native-new-architecture-book_rn-v<ver>_<commit>_<YYYYMMDD-HHMMSS>.pdf
    uv run pdf/build_book.py --md-only      # only pdf/build/book.md
    uv run pdf/build_book.py --no-mermaid   # skip diagram rendering
    uv run pdf/build_book.py --out X.pdf --toc-depth 2

`markdown-to-pdf.sh` in this folder is a vendored copy of the generator
(pandoc + typst). The build uses it by default. Env or flag `MD2PDF` /
`--md2pdf` points to another copy, for example to test a newer version.
Requires `pandoc`, `typst`, `bun` (for mermaid-cli) and `uv`.

How it works:

1. Order and Parts come from the Table of Contents in `../README.md`.
   The build stops if a `NN-*.md` file is missing from it, or listed twice.
2. README body becomes "About this book". Its TOC list is removed.
3. Each chapter: YAML frontmatter removed, all headings moved down one level
   (Part = H1, Chapter = H2), headings in code fences are not touched.
4. Footnotes are renamed per chapter (`[^1]` to `[^1::c03]`) so numbers from
   different chapters do not collide.
5. Pandoc `--toc` builds the TOC. Typst computes page numbers.
   `book-style.typ` adds a page break before each Part and Chapter.
6. Page 1 is a text-only cover (`build/cover.typ`), on the same paper as the
   rest. The page header shows the chapter (`{h2}`) on the left and the
   current section or subsection (`{h3+}`) on the right. The footer holds
   author, title, RN version, date and page numbers. The `{hN}` tokens need
   the `markdown-to-pdf.sh` version that supports running headings (the
   vendored copy does).

Mermaid blocks are rendered to PNG (3x) with mermaid-cli (`bunx`) and the Chrome in `puppeteer.json`. Edit that path if Chrome lives elsewhere. A failed diagram stops the build.

Output folders `build/` and `dist/` are git-ignored.
