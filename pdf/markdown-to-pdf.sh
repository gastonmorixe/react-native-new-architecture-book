#!/usr/bin/env bash
# Convert any Markdown file to PDF without a browser.
# Requires: pandoc and typst.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: markdown-to-pdf.sh [options] INPUT.md [OUTPUT.pdf] [pandoc options...]

Examples:
  ./markdown-to-pdf.sh tutorial.md
  ./markdown-to-pdf.sh notes.md notes.pdf
  ./markdown-to-pdf.sh --landscape tutorial.md
  ./markdown-to-pdf.sh notes.md notes.pdf -V papersize=a4
  ./markdown-to-pdf.sh --page-numbers tutorial.md
  ./markdown-to-pdf.sh --header-left '{title}' --header-right '{date}' \
      --footer-right '{page} / {pages}' tutorial.md

Options:
  --landscape              A4 landscape pages (more room for wide tables)
  --page-numbers           Footer center "Page {page} of {pages}"
                           (unless --footer-center is given)
  --header-left TEXT       Text in a page corner or center. Plain text.
  --header-center TEXT     Setting any header slot replaces the header.
  --header-right TEXT      Setting any footer slot replaces the default
  --footer-left TEXT       page number, so add {page} where you want it.
  --footer-center TEXT
  --footer-right TEXT
  --date-format FMT        strftime format for {date} (default %Y-%m-%d)
  --no-citation-list       Do not repeat the footnote definitions under a
                           "Citations:" heading (see below)

Tokens in slot text:
  {page}    current page number      {title}  first "# " heading, else
  {pages}   total page count                  the file name without .md
  {date}    today, see --date-format {file}   input file name
  {h2}      running heading of level 2 (1-6 work): the first one on the
            page, else the last one before it. A higher heading resets it.
  {h3+}     the same for level 3 or deeper (section or subsection).
            A heading slot stays on one line: a long one ends in "...".

Citations: pandoc moves footnotes to the page bottom, so a heading such as
"**Citations:**" followed by [^n]: definitions would print empty, and
definitions that no text refers to would vanish. By default the script
prints those definitions again as a visible list under the heading
(Citations, References or Sources). The footnotes stay as they are. In the
list, a label like [^3::c05] shows as [3]: text after "::" is hidden.

The default output is INPUT.pdf. Markdown is parsed as GitHub-Flavored
Markdown so GitHub-style heading/table anchors are preserved. Wide fenced
``` and ```text ASCII blocks are scaled down by font size (never
word-wrapped, never geometrically squashed, never truncated) until they
fit the page width. Named fences (```sh, ```bash, ...) keep default size.
EOF
}

landscape=0
page_numbers=0
date_format='%Y-%m-%d'
citation_list=1
# Page slots: header/footer x left/center/right. Plain variables (no
# associative arrays) so the script still runs on macOS /bin/bash 3.2.
# Values reach Typst through `typst --input`, so they are plain text: no
# Typst markup injection, no escaping needed.
header_left='' header_center='' header_right=''
footer_left='' footer_center='' footer_right=''
need_value() {
  if [[ $2 -lt 2 ]]; then
    printf 'Error: %s needs a value\n' "$1" >&2
    exit 1
  fi
}
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --landscape) landscape=1 ;;
    --page-numbers) page_numbers=1 ;;
    --no-citation-list) citation_list=0 ;;
    --date-format) need_value "$1" $#; date_format=$2; shift ;;
    --header-left) need_value "$1" $#; header_left=$2; shift ;;
    --header-center) need_value "$1" $#; header_center=$2; shift ;;
    --header-right) need_value "$1" $#; header_right=$2; shift ;;
    --footer-left) need_value "$1" $#; footer_left=$2; shift ;;
    --footer-center) need_value "$1" $#; footer_center=$2; shift ;;
    --footer-right) need_value "$1" $#; footer_right=$2; shift ;;
    *) positional+=("$1") ;;
  esac
  shift
done
set -- ${positional[@]+"${positional[@]}"}
if [[ $page_numbers -eq 1 && -z "$footer_center" ]]; then
  footer_center='Page {page} of {pages}'
fi

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

input=$1
shift
if [[ ! -f "$input" ]]; then
  printf 'Error: input file not found: %s\n' "$input" >&2
  exit 1
fi

if ! command -v pandoc >/dev/null 2>&1; then
  printf 'Error: pandoc is required (macOS: brew install pandoc)\n' >&2
  exit 1
fi
if ! command -v typst >/dev/null 2>&1; then
  printf 'Error: typst is required (macOS: brew install typst)\n' >&2
  exit 1
fi

if [[ "${1:-}" != -* && $# -gt 0 ]]; then
  output=$1
  shift
else
  output="${input%.*}.pdf"
fi

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/markdown-to-pdf.XXXXXX")
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

# ASCII fitting: measure unlabeled ``` and ```text blocks; render at natural
# size when they fit, otherwise shrink the FONT SIZE so the widest line fills
# the text width. No word wrap, no transform, no truncation. Named fences
# (```sh, ...) are left alone so normal code keeps default sizing.
cat >"$tmpdir/ascii-fit.typ" <<'EOF'
// Bold the running-balance rows: the tutorial marks them with "* Balance"
// in the description column. raw.line fires once per line of every raw block;
// matching on the text lets us restyle just those rows. DejaVu Sans Mono
// keeps the same advance in bold, so the fit math below stays exact.
#show raw.line: it => {
  if it.text.trim().contains("* Balance") {
    text(weight: "bold", it.body)
  } else {
    it.body
  }
}
#show raw.where(block: true): it => {
  // Fit unlabeled fences (pandoc emits lang: none) and ```text (Selinger
  // ledgers / ASCII diagrams). Skip named languages so ```sh stays default.
  let lang = it.lang
  let is-ascii = lang == none or lang == "" or lang == "text"
  if not is-ascii {
    it
  } else {
    context {
      // Box-drawing glyphs span ~1.01em of ink; Typst's default line pitch is
      // ~1.41em (visible gaps between rows), while 0em leading would overlap.
      // 0.42em lands the pitch at ~1.18em: rows keep a hair of separation that
      // still reads as solid boxes. Applied here so BOTH the natural-size and
      // the scaled-down branches get the same tight line height.
      set par(leading: 0.42em)
      layout(size => {
        // m = measured width of the widest line. measure() applies the raw 0.8em
        // default, but re-emitting the block inside this show rule renders at the
        // bare size, so the fit divides by the 0.8 factor to cancel it.
        let m = 0pt
        for line in it.text.split("\n") {
          let w = measure(text(font: "DejaVu Sans Mono", size: 1pt, raw(line))).width
          if w > m { m = w }
        }
        // Natural width of the untouched raw block (0.8em applied by measure).
        let natural = measure(it).width
        if natural <= size.width {
          // Fits at natural size: keep the native raw block untouched.
          it
        } else {
          // Too wide: shrink the FONT SIZE so the widest line exactly fills the
          // text width.
          text(size: 1pt * (size.width * 0.8 / m))[#it]
        }
      })
    }
  }
}

// Table fitting. Same idea as the ASCII fit above (measure, keep if it fits,
// else shrink the FONT SIZE), plus a floor and explicit column widths:
//   1. Natural fit: every cell on one line fits the text width. Keep as is.
//   2. Scale fit: shrink the font until one-line cells fit, but not below
//      TABLE_FLOOR. No wrapping.
//   3. Wrap fit: at TABLE_FLOOR, give each column its min-content width (its
//      widest unbreakable piece) plus a share of the free room in proportion
//      to how much it wants (max - min). Columns never go under min-content,
//      so cells never draw over each other.
//   4. If even the min-content widths do not fit, shrink further down to
//      TABLE_HARD_FLOOR.
// Inline code in tables may break after _ / . : - (zero-width space), so
// URLs and identifiers have break points. Cells are not justified.
// Pandoc emits `columns: <int>`, which Typst stores as (auto, auto, ...).
// The rebuilt table has explicit lengths, so the rule skips its own output
// (and any hand-written table with fixed columns).
// Break tiers for inline code in table cells, tried in order until the
// min-content widths fit:
//   1. after _ / . : -           (URLs, paths, kebab and snake case)
//   2. tier 1 plus CamelCase     (AmazonSSMRole|For|Instances|Quick|Setup)
//   3. after any character       (last resort: hashes, ids, base64)
// TABLE_MIN_SIZE is an absolute floor for table text, so the relative
// floors do not stack on a caller that already made tables small.
#let TABLE_FLOOR = 0.82
#let TABLE_HARD_FLOOR = 0.62
#let TABLE_MIN_SIZE = 7.5pt
#let TABLE_TIER_RE = (
  regex("[_/.:\-]"),
  regex("[_/.:\-]|[a-z][A-Z]"),
  regex("."),
)
#let table-breaks(tier, sep, body) = {
  show raw.where(block: false): r => {
    show TABLE_TIER_RE.at(tier - 1): m => {
      let t = m.text
      // Two-char CamelCase match: break between the two characters.
      if t.len() == 2 { t.slice(0, 1) + sep + t.slice(1) } else { m + sep }
    }
    r
  }
  body
}
#let table-mincontent(tier, body) = {
  show " ": linebreak()
  table-breaks(tier, linebreak(), body)
}
#show table: set par(justify: false)
#show table: it => {
  if type(it.columns) != array or it.columns.any(c => c != auto) { return it }
  context layout(size => {
    let n = it.columns.len()
    let cells = ()
    for ch in it.children {
      if ch.func() == table.header or ch.func() == table.footer {
        cells += ch.children
      } else if ch.func() == table.hline or ch.func() == table.vline {
      } else {
        cells.push(ch)
      }
    }
    // Pandoc tables have no colspan, so cell i is in column i mod n.
    // Header cells are measured bold too: callers often bold the header
    // row with a table.cell rule that does not apply inside measure().
    let nhead = 0
    for ch in it.children {
      if ch.func() == table.header { nhead += ch.children.len() }
    }
    let wide(b, i) = if i < nhead { (b, text(weight: "bold", b)) } else { (b,) }
    let bodies = cells.map(c => if c.func() == table.cell { c.body } else { c })
    let maxs = range(n).map(_ => 0pt)
    for (i, b) in bodies.enumerate() {
      let k = calc.rem(i, n)
      for v in wide(b, i) { maxs.at(k) = calc.max(maxs.at(k), measure(table-breaks(1, sym.zws, v)).width) }
    }
    let mins-for(tier) = {
      let m = range(n).map(_ => 0pt)
      for (i, b) in bodies.enumerate() {
        let k = calc.rem(i, n)
        for v in wide(b, i) { m.at(k) = calc.max(m.at(k), measure(table-mincontent(tier, v)).width) }
      }
      m
    }
    // Horizontal inset per column, from the live table (pandoc sets 6pt).
    // It is an absolute length, so it does not scale with the font. The 0.5pt
    // epsilon absorbs measure rounding so a "just fits" cell does not wrap.
    let ins = it.inset
    let ins-y = if type(ins) == dictionary { ins.at("y", default: ins.at("rest", default: 6pt)) } else if type(ins) == array { 6pt } else { ins }
    if type(ins) == dictionary { ins = ins.at("x", default: ins.at("rest", default: 6pt)) }
    if type(ins) == array { ins = ins.at(0) }
    if type(ins) == relative { ins = ins.length }
    let smax = maxs.sum()
    let room(i) = size.width - (2 * i + 0.5pt) * n
    // Scale limits. `lo` is the smallest scale allowed: the relative hard
    // floor, but never under TABLE_MIN_SIZE (unless the caller's own size
    // is already smaller, then we do not shrink at all).
    let lo = calc.max(TABLE_HARD_FLOOR, calc.min(1.0, TABLE_MIN_SIZE / text.size))
    let floor = calc.max(TABLE_FLOOR, lo)
    // Steps 1 and 2: one-line cells, full inset.
    if smax <= room(ins) { return table-breaks(1, sym.zws, it) }
    let s = 1.0
    let tier = 1
    let cols = maxs
    if smax * floor <= room(ins) {
      s = room(ins) / smax
    } else {
      // Steps 3 and 4: wrap. Try plans in order, cheapest loss first:
      // padding, then CamelCase breaks, then font size, then any-char
      // breaks. The last plan always applies.
      let plans = (
        (1, ins, floor), (1, ins / 2, floor), (2, ins / 2, floor),
        (2, ins / 2, lo), (3, ins / 2, lo),
      )
      let mins = none
      for (j, (t, i, smin-scale)) in plans.enumerate() {
        let m = mins-for(t)
        let r = room(i)
        let need = r / m.sum()  // scale at which min-content fills the room
        if need >= smin-scale or j == plans.len() - 1 {
          tier = t
          ins = i
          mins = m
          s = calc.max(smin-scale, calc.min(floor, need))
          break
        }
      }
      let r = room(ins)
      let extra = r - mins.sum() * s
      let want = maxs.zip(mins).map(((a, b)) => calc.max(0pt, a - b)).sum()
      // Widths in unscaled units: min-content plus a share of the free room.
      cols = maxs.zip(mins).map(((a, b)) => {
        let share = if want > 0pt and extra > 0pt { extra * (calc.max(0pt, a - b) / want) } else { 0pt }
        b + share / s
      })
    }
    let cpad = 2 * ins + 0.5pt
    let fields = it.fields()
    let children = fields.remove("children")
    let _ = fields.remove("columns")
    fields.insert("inset", (x: ins, y: ins-y))
    // Apply the scale as an ABSOLUTE size through a show-set rule in this
    // scope. The rebuilt table is a new element, so the caller's own
    // `show table: set text(...)` rules run on it again. A plain
    // text(size: s * 1em) wrapper loses to them: an absolute caller size
    // (9pt) replaces it, and a relative one (0.82em) compounds with it.
    // A show-set rule here is closer to the table than the caller's rule,
    // so it wins. text.size already includes the caller's size (this is
    // the size we measured at), so the result is exactly s x that size.
    // Not scale(): it does not break across pages.
    let fs = s * text.size
    show table: set text(size: fs)
    table-breaks(tier, sym.zws, table(
      ..fields,
      columns: cols.map(w => w * s + cpad),
      ..children,
    ))
  })
}
EOF

# Header/footer slots. Static tokens ({date}, {title}, {file}) expand here in
# bash. Page tokens ({page}, {pages}) need the page counter, so Typst
# expands them per page. Text reaches Typst via `typst --input`.
doc_title=$(sed -n 's/^# \{1,\}//p' "$input" | head -n 1 | sed 's/ *#* *$//')
input_file=$(basename "$input")
[[ -n "$doc_title" ]] || doc_title=${input_file%.*}
today=$(date +"$date_format")
expand_static() {
  local s=$1
  s=${s//\{date\}/$today}
  s=${s//\{title\}/$doc_title}
  s=${s//\{file\}/$input_file}
  printf '%s' "$s"
}
typst_inputs=()
header_on=0 footer_on=0
for slot in header-left header-center header-right footer-left footer-center footer-right; do
  var=${slot//-/_}
  val=${!var}
  [[ -n "$val" ]] || continue
  typst_inputs+=(--input "mdpdf-$slot=$(expand_static "$val")")
  case "$slot" in
    header-*) header_on=1 ;;
    footer-*) footer_on=1 ;;
  esac
done

include_slots=()
if [[ $header_on -eq 1 || $footer_on -eq 1 ]]; then
  {
    cat <<'EOF'
// Page header/footer slots from markdown-to-pdf.sh (--header-*/--footer-*).
// A three-column grid: left and right take equal space, so the center slot
// stays centered on the page even when the sides differ in length.
#let mdpdf-slot(key) = sys.inputs.at("mdpdf-" + key, default: "")

// Plain text of a heading body. Footnotes are dropped, so a header never
// repeats a footnote mark.
#let mdpdf-plain(it) = {
  if type(it) == str { it }
  else if it.func() == footnote { "" }
  else if it.func() == [ ].func() { " " }
  else if it.has("text") { it.text }
  else if it.has("children") { it.children.map(mdpdf-plain).join("") }
  else if it.has("body") { mdpdf-plain(it.body) }
  else { "" }
}

// Running heading for tokens {hN} (level N only) and {hN+} (level N or
// deeper). Rule on page p: the first matching heading that starts on p.
// Else the last heading on or before p, if it matches. A heading of a
// higher rank (level < N) resets the token, so a new chapter clears the
// old section. Headings not in the outline (the outline title) are skipped.
#let mdpdf-running(p, n, deeper) = {
  let hs = query(heading).filter(h => h.outlined)
  let match(h) = if deeper { h.level >= n } else { h.level == n }
  let on = hs.filter(h => h.location().page() == p and match(h))
  let pick = if on.len() > 0 { on.first() } else {
    let before = hs.filter(h => h.location().page() <= p and (h.level <= n or match(h)))
    if before.len() > 0 and match(before.last()) { before.last() } else { none }
  }
  if pick == none { return "" }
  mdpdf-plain(pick.body).trim()
}

// Cut s to one line of width w, with "..." at the end when cut.
#let mdpdf-fit(s, w) = {
  if measure(s).width <= w { return s }
  let cs = s.clusters()
  let (lo, hi) = (0, cs.len())
  while lo < hi {
    let mid = calc.div-euclid(lo + hi + 1, 2)
    if measure(cs.slice(0, mid).join("").trim() + "...").width <= w { lo = mid } else { hi = mid - 1 }
  }
  cs.slice(0, lo).join("").trim() + "..."
}

#let mdpdf-band(where) = context {
  let p = here().page()
  let cur = str(counter(page).get().first())
  let total = str(counter(page).final().first())
  let fill(s) = {
    s = s.replace("{page}", cur).replace("{pages}", total)
    for n in range(1, 7) {
      let t = "{h" + str(n) + "+}"
      if s.contains(t) { s = s.replace(t, mdpdf-running(p, n, true)) }
      let t = "{h" + str(n) + "}"
      if s.contains(t) { s = s.replace(t, mdpdf-running(p, n, false)) }
    }
    s
  }
  // A slot with a heading token stays on one line: it is cut to the cell
  // width. Other slot text wraps as before.
  let cell(key) = {
    let raw = mdpdf-slot(where + "-" + key)
    let s = fill(raw)
    if raw.match(regex("\{h[1-6]\+?\}")) == none { s } else {
      layout(sz => mdpdf-fit(s, sz.width))
    }
  }
  set text(size: 0.8em, fill: luma(90))
  set par(justify: false)
  grid(
    columns: (1fr, auto, 1fr),
    column-gutter: 1em,
    align(left, cell("left")),
    align(center, cell("center")),
    align(right, cell("right")),
  )
}
EOF
    # Only replace the band that has slots. An untouched footer keeps
    # Typst's default page number.
    [[ $header_on -eq 1 ]] && printf '#set page(header: mdpdf-band("header"))\n'
    [[ $footer_on -eq 1 ]] && printf '#set page(footer: mdpdf-band("footer"))\n'
  } >"$tmpdir/page-slots.typ"
  include_slots=(--include-in-header="$tmpdir/page-slots.typ")
fi

# 0) Citations list. Copy the footnote definitions that follow a Citations /
#    References / Sources heading into a visible list under that heading.
#    Fenced code is skipped. The original definition lines stay, so inline
#    [^n] marks still become page-bottom footnotes.
pandoc_input="$input"

# 0a) Fence language aliases. Typst highlights a fixed list of languages and
#     leaves any other name as plain black text. Map common names to a
#     supported one: jsx/javascriptreact/typescriptreact -> tsx (it also
#     colors JSX tags), objc/objectivec -> objective-c, objcpp -> mm,
#     shell -> sh, jsonc/json5 -> json. Only opening fences change.
#     A js/javascript/ts/typescript block whose body holds JSX (a closing
#     tag </X>, a self-closing />, or a fragment </>) also becomes tsx:
#     the plain JS grammar breaks at the first tag and prints the rest of
#     the block in one color. Type generics (Promise<void>) never match.
awk '
  BEGIN {
    a["jsx"] = "tsx"; a["javascriptreact"] = "tsx"; a["typescriptreact"] = "tsx"
    a["objc"] = "objective-c"; a["objectivec"] = "objective-c"
    a["objcpp"] = "mm"; a["objective-cpp"] = "mm"; a["objectivecpp"] = "mm"
    a["shell"] = "sh"; a["jsonc"] = "json"; a["json5"] = "json"
    j["js"] = 1; j["javascript"] = 1; j["ts"] = 1; j["typescript"] = 1
    j["mjs"] = 1; j["cjs"] = 1
  }
  function flush(lang,   i) {
    if (jsx) lang = "tsx"
    print bmark lang btail
    for (i = 1; i <= nb; i++) print buf[i]
    nb = 0; jsx = 0; buffering = 0
  }
  {
    if (match($0, /^ {0,3}(```+|~~~+)/)) {
      mark = substr($0, 1, RLENGTH)
      if (!fence) {
        fence = 1; fch = substr(mark, RLENGTH, 1); flen = RLENGTH
        rest = substr($0, RLENGTH + 1)
        if (match(rest, /^ *[A-Za-z0-9_+#-]+/)) {
          word = rest; sub(/^ */, "", word); sub(/[^A-Za-z0-9_+#-].*$/, "", word)
          tail = rest; sub(/^ *[A-Za-z0-9_+#-]+/, "", tail)
          lw = tolower(word)
          if (lw in a) { print mark a[lw] tail; next }
          if (lw in j) { buffering = 1; bmark = mark; bword = word; btail = tail; nb = 0; jsx = 0; next }
        }
      } else if (substr(mark, RLENGTH, 1) == fch && RLENGTH >= flen && $0 ~ /^ {0,3}(```+|~~~+) *$/) {
        fence = 0
        if (buffering) { flush(bword); print; next }
      }
    }
    if (buffering) {
      buf[++nb] = $0
      if ($0 ~ /<\/[A-Za-z][A-Za-z0-9_.]*>|\/>|<\/>/) jsx = 1
      next
    }
    print
  }
  END { if (buffering) flush(bword) }
' "$input" >"$tmpdir/input-alias.md"
pandoc_input="$tmpdir/input-alias.md"

if [[ $citation_list -eq 1 ]]; then
  awk '
    function isfence(l) { return l ~ /^ {0,3}(```|~~~)/ }
    function label(k,   i) { i = index(k, "::"); return i ? substr(k, 1, i - 1) : k }
    { line[NR] = $0 }
    END {
      fence = 0; i = 1
      while (i <= NR) {
        l = line[i]
        if (isfence(l)) fence = !fence
        print l
        i++
        if (fence) continue
        t = l; gsub(/[*[:space:]]/, "", t); t = tolower(t)
        if (t !~ /^(citations|references|sources):?$/) continue
        n = 0; j = i; delete key; delete body; delete raw
        while (j <= NR) {
          m = line[j]
          if (match(m, /^\[\^[^] \t]+\]:/)) {
            n++
            key[n] = substr(m, 3, RLENGTH - 4)
            b = substr(m, RLENGTH + 1); sub(/^ +/, "", b); body[n] = b
          } else if (m ~ /^[ \t]*$/) {
          } else if (n > 0 && m ~ /^(    |\t)/) {
            b = m; sub(/^[ \t]+/, "", b); body[n] = body[n] " " b
          } else break
          raw[j] = 1; j++
        }
        if (n > 0) {
          print ""
          for (k = 1; k <= n; k++) print "- [" label(key[k]) "] " body[k]
          print ""
          for (k = i; k < j; k++) print line[k]
          i = j
        }
      }
    }
  ' "$pandoc_input" >"$tmpdir/input.md"
  pandoc_input="$tmpdir/input.md"
fi

# 1) Pandoc Markdown -> Typst (GitHub-Flavored Markdown so anchors match).
pandoc --from=gfm --to=typst -s \
  --include-in-header="$tmpdir/ascii-fit.typ" \
  ${include_slots[@]+"${include_slots[@]}"} \
  $( [[ $landscape -eq 1 ]] && printf '%s' '--variable papersize=a4' ) \
  "$pandoc_input" -o "$tmpdir/doc.typ" \
  "$@"

# 1b) Left-align table blocks (pandoc wraps every table in align(center)).
sed -i '' 's/align(center)\[#table(/align(left)[#table(/' "$tmpdir/doc.typ"

# 2) Patch the generated Typst: add a flipped param to the conf() signature
#    and, for landscape, request flipped pages with tighter margins.
awk -v flip="$landscape" '
  /^#show: doc => conf\(/ { in_call = 1 }
  in_call == 0 && /^  paper: "us-letter",$/ {
    print
    print "  flipped: false,"
    next
  }
  in_call == 0 && /^    paper: paper,$/ {
    print
    print "    flipped: flipped,"
    next
  }
  in_call == 1 && /^  paper: / && flip == 1 {
    print
    print "  flipped: true,"
    print "  margin: (x: 0.6in, y: 0.6in),"
    next
  }
  { print }
' "$tmpdir/doc.typ" >"$tmpdir/doc-patched.typ"

# 3) Typst -> PDF.
typst compile ${typst_inputs[@]+"${typst_inputs[@]}"} "$tmpdir/doc-patched.typ" "$output"

printf 'Wrote %s\n' "$output"
