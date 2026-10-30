#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# ///
"""Build one combined Markdown file from the chapters, then make a PDF.

Source of truth for order and parts: the "Table of Contents" in README.md
(### Part N: ... headings, then chapter links). A chapter file that is not
listed there stops the build (no silent drops).

Combined file layout:
  YAML title block
  # About this book        (README body, TOC list and footnotes removed)
  # Part N: ...            (one per part, from README)
  ## Chapter N: ...        (chapter H1 moved down one level, all others too)
  ### ...                  (sections)

Pandoc builds the TOC (--toc) from these headings, so page numbers are right.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HERE = Path(__file__).resolve().parent
# Vendored copy, so the build works from a clean clone. Override with
# --md2pdf or the MD2PDF env var to test another version of the script.
DEFAULT_MD2PDF = HERE / "markdown-to-pdf.sh"
BOOK_TITLE = "React Native New Architecture Book"
STRICT = True
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
CHAPTER_LINK = re.compile(r"\]\(\./([0-9]{2}-[^)]+\.md)\)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def outside_fences(lines):
    """Yield (line, in_fence) while tracking fenced code blocks."""
    fence = None
    for line in lines:
        m = FENCE.match(line)
        if fence is None:
            if m:
                fence = m.group(1)
                yield line, True
                continue
            yield line, False
        else:
            yield line, True
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence):
                fence = None


def strip_frontmatter(text: str) -> str:
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[end + 5 :].lstrip("\n")
    return text


def parse_readme(readme: str):
    """Return (parts, intro_md, rn_version, last_update)."""
    parts: list[tuple[str, list[str]]] = []
    in_toc = False
    for line in readme.splitlines():
        if re.match(r"^##\s+.*Table of Contents", line):
            in_toc = True
            continue
        if in_toc and re.match(r"^(---|## )", line):
            in_toc = False
        if not in_toc:
            continue
        m = re.match(r"^###\s+(Part\s+\d+:.*?)\s*$", line)
        if m:
            parts.append((m.group(1), []))
            continue
        m = CHAPTER_LINK.search(line)
        if m and parts and line.lstrip().startswith("*   ["):
            parts[-1][1].append(m.group(1))
    if not parts:
        sys.exit("error: no Part headings found in README.md Table of Contents")

    # Intro: README without the TOC section, the H1, and the footnote defs.
    body = strip_frontmatter(readme).splitlines()
    out: list[str] = []
    skip_toc = False
    skip_foot = False
    for line, fenced in outside_fences(body):
        if fenced:
            out.append(line)
            continue
        if re.match(r"^##\s+.*Table of Contents", line):
            skip_toc = True
            continue
        if skip_toc:
            if line.startswith("## "):
                skip_toc = False
            else:
                continue
        if re.match(r"^##\s+Footnotes", line):
            skip_foot = True
            continue
        if skip_foot:
            continue
        if re.match(r"^# ", line):
            continue  # book title goes in the YAML block
        out.append(line)
    intro = re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip()
    # Drop horizontal rules left dangling at the end.
    intro = re.sub(r"(\n---\s*)+$", "", intro).strip()
    # Footnote defs of README (kept, namespaced later).
    foot = [l for l in readme.splitlines() if re.match(r"^\[\^[^\]]+\]:", l)]
    if foot:
        intro += "\n\n" + "\n".join(foot)

    ver = re.search(r"verified against[^`]*`(v[0-9][^`]*)`", readme)
    if not ver:
        ver = re.search(r"RN (v[0-9][0-9.]*)", readme)
    rn_version = ver.group(1) if ver else "unknown"
    upd = re.search(r"Last update:\s*(.+)", readme)
    return parts, intro, rn_version, (upd.group(1).strip() if upd else "")


def process_chapter(name: str, text: str, ns: str, demote: int):
    """Strip frontmatter, namespace footnotes, demote headings."""
    text = strip_frontmatter(text)
    out: list[str] = []
    for line, fenced in outside_fences(text.splitlines()):
        if fenced:
            out.append(line)
            continue
        m = HEADING.match(line)
        if m:
            level = min(len(m.group(1)) + demote, 6)
            line = "#" * level + " " + m.group(2)
        else:
            line = re.sub(r"\[\^([^\]\s]+)\]", lambda g: f"[^{g.group(1)}::{ns}]", line)
        out.append(line)
    return "\n".join(out).strip() + "\n"


def mermaid_to_svg(md: str, outdir: Path, tag: str) -> str:
    """Replace ```mermaid blocks by rendered SVG images. Needs bunx + mmdc."""
    outdir.mkdir(parents=True, exist_ok=True)
    res: list[str] = []
    buf: list[str] | None = None
    n = 0
    for line in md.splitlines():
        if buf is None:
            if re.match(r"^```mermaid\s*$", line):
                buf = []
            else:
                res.append(line)
            continue
        if line.strip() == "```":
            n += 1
            src = outdir / f"{tag}-{n}.mmd"
            svg = outdir / f"{tag}-{n}.png"
            src.write_text("\n".join(buf) + "\n")
            def render():
                return subprocess.run(
                    ["bunx", "-p", "@mermaid-js/mermaid-cli", "mmdc", "-i", str(src),
                     "-o", str(svg), "-b", "white", "-s", "3",
                     "-c", str(HERE / "mermaid.json"),
                     "-p", str(HERE / "puppeteer.json"), "--quiet"],
                    capture_output=True, text=True,
                )
            r = render()
            if r.returncode != 0:
                # Retry: quote [labels] that hold parentheses (invalid unquoted).
                fixed = re.sub(r'\[([^\]"]*[()][^\]"]*)\]', r'["\1"]', "\n".join(buf))
                if fixed != "\n".join(buf):
                    print(f"warn: mermaid {tag}-{n}: quoted labels with parentheses", file=sys.stderr)
                    src.write_text(fixed + "\n")
                    r = render()
            if r.returncode == 0 and svg.exists():
                res.append(f"![Diagram {n}]({svg})")
            else:
                print(f"error: mermaid {tag}-{n} failed:\n{r.stderr[-600:]}", file=sys.stderr)
                if STRICT:
                    sys.exit(1)
                res += ["```text", *buf, "```"]
            buf = None
        else:
            buf.append(line)
    return "\n".join(res)


def typst_str(t: str) -> str:
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


def make_cover(rn_version: str, last_update: str) -> str:
    """Typst cover page: no header or footer, text only, centered on the page."""
    date = __import__("datetime").date.today().isoformat()
    return f"""#page(header: none, footer: none)[
  #set par(justify: false, leading: 0.7em)
  #align(center + horizon)[
    #text(size: 30pt, weight: "bold")[React Native]
    #v(0.15em)
    #text(size: 30pt, weight: "bold")[New Architecture Book]
    #v(1.6em)
    #text(size: 13pt)[Verified against React Native {rn_version}]
    #v(0.5em)
    #text(size: 11pt)[{date}]
  ]
  #align(center + bottom)[
    #text(size: 10pt)[Gaston Morixe]
  ]
]
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=None,
                    help="output PDF (default: dist/<name>_rn-<version>_<commit>_<timestamp>.pdf)")
    ap.add_argument("--md-only", action="store_true", help="write combined .md, skip PDF")
    ap.add_argument("--no-mermaid", action="store_true", help="keep mermaid blocks as code (skip rendering)")
    ap.add_argument("--toc-depth", type=int, default=3)
    ap.add_argument("--md2pdf", default=None, help="path to markdown-to-pdf.sh")
    a = ap.parse_args()

    build = HERE / "build"
    build.mkdir(exist_ok=True)
    readme = (ROOT / "README.md").read_text()
    parts, intro, rn_version, last_update = parse_readme(readme)

    cm = re.search(r"`main`\s+HEAD\s+`([0-9a-f]{7,40})`", readme) or re.search(
        r"\(main\s+`([0-9a-f]{7,40})`\)", readme)
    if not cm:
        sys.exit("error: RN commit not found in README.md")
    rn_commit = cm.group(1)[:11]
    stamp = __import__("datetime").datetime.now().strftime("%Y%m%d-%H%M%S")
    ver_file = re.sub(r"[^0-9A-Za-z.]+", "-", rn_version.removeprefix("v").split("+")[0])
    out_pdf = Path(a.out) if a.out else (
        HERE / "dist" / f"react-native-new-architecture-book_rn-v{ver_file}_{rn_commit}_{stamp}.pdf")
    out_pdf.parent.mkdir(parents=True, exist_ok=True)

    listed = [c for _, cs in parts for c in cs]
    on_disk = sorted(p.name for p in ROOT.glob("[0-9][0-9]-*.md"))
    missing = [c for c in listed if not (ROOT / c).is_file()]
    unlisted = [c for c in on_disk if c not in listed]
    dupes = {c for c in listed if listed.count(c) > 1}
    if missing or unlisted or dupes:
        sys.exit(f"error: README TOC mismatch. missing={missing} unlisted={unlisted} dupes={sorted(dupes)}")

    doc: list[str] = []
    doc.append("# About this book\n\n" + process_chapter("README.md", intro, "readme", 1))
    for part_title, chapters in parts:
        doc.append(f"# {part_title}\n")
        for c in chapters:
            ns = "c" + c[:2]
            doc.append(process_chapter(c, (ROOT / c).read_text(), ns, 1))

    combined = "\n\n".join(doc)
    if not a.no_mermaid:
        combined = mermaid_to_svg(combined, build / "diagrams", "d")
    cover = build / "cover.typ"
    cover.write_text(make_cover(rn_version, last_update))
    md_path = build / "book.md"
    md_path.write_text(combined)

    n_h = sum(1 for l, f in outside_fences(combined.splitlines()) if not f and HEADING.match(l))
    print(f"parts={len(parts)} chapters={len(listed)} headings={n_h} version={rn_version}")
    print(f"combined markdown: {md_path} ({len(combined.splitlines())} lines)")
    if a.md_only:
        return 0

    md2pdf = Path(a.md2pdf or __import__("os").environ.get("MD2PDF", DEFAULT_MD2PDF)).expanduser()
    if not md2pdf.is_file():
        sys.exit(f"error: markdown-to-pdf.sh not found: {md2pdf}")
    cmd = [
        str(md2pdf),
        # Running header: chapter (H2) left, current section/subsection right.
        "--header-left", "{h2}",
        "--header-right", "{h3+}",
        "--footer-left", "GASTON MORIXE",
        "--footer-center", f"{BOOK_TITLE}, RN {rn_version}, {{date}}",
        "--footer-right", "{page} / {pages}",
        str(md_path), str(out_pdf),
        "--toc", f"--toc-depth={a.toc_depth}",
        # Before-body, not in-header: the cover must come after the template's
        # conf() call, which sets the paper size, so page 1 gets the same size.
        f"--include-before-body={cover}",
        f"--include-in-header={HERE / 'book-style.typ'}",
    ]
    print("+", " ".join(cmd))
    # Typst resolves image paths against its root: let it read the diagram PNGs.
    return subprocess.call(cmd, env={**__import__("os").environ, "TYPST_ROOT": "/"})


if __name__ == "__main__":
    sys.exit(main())
