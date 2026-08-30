#!/usr/bin/env python3
"""Combine all Mooziac blueprint markdown into a single structured book.

Ordering follows the numbered section folders (00_INDEX .. 99_APPENDIX).
Each section becomes a "Part" heading; each doc becomes a chapter heading.
Raw discovery notes are appended as an appendix after the main docs.

Usage:
    python3 combine_book.py <blueprint_root> -o <combined.md>

Writes the combined, token-reduced markdown book to the output path.
"""
import argparse
import os
import re
import sys
from datetime import date

from reduce_tokens import reduce

PART_TITLES = {
    "00_INDEX": "Index, Coverage & Status",
    "01_PROJECT_OVERVIEW": "Project Overview",
    "02_CODEBASE": "Codebase Map",
    "03_ARCHITECTURE": "Architecture",
    "04_FUNCTIONS": "Functions Reference",
    "05_UI": "User Interface",
    "06_AUDIO": "Audio System",
    "07_LYRICS": "Lyrics System",
    "08_DATA": "Data & Storage",
    "09_NETWORK": "Network & Services",
    "10_BACKGROUND_SYSTEMS": "Background Systems",
    "11_CONFIGURATION": "Configuration & Environment",
    "12_SECURITY": "Security & Privacy",
    "13_WORKFLOWS": "Workflows",
    "14_DIAGRAMS": "Diagrams",
    "15_ISSUES_AND_RISKS": "Issues & Risks",
    "99_APPENDIX": "Appendix",
}


def section_key(name: str) -> int:
    try:
        return int(name.split("_")[0])
    except ValueError:
        return 999


def demote_headings(text: str) -> str:
    """Bump every heading level by +1 so doc titles nest under Part headings."""
    out = []
    for line in text.split("\n"):
        if line.startswith("#"):
            m = re.match(r"^(#+)(.*)$", line)
            if m:
                line = "#" + m.group(1) + m.group(2)
        out.append(line)
    return "\n".join(out)


def chapter_title(path: str) -> str:
    base = os.path.splitext(os.path.basename(path))[0]
    base = base.replace("_", " ").title()
    return base


def _cell_width(cell: str) -> int:
    return len(cell.strip())


def widen_first_table_column(text: str) -> str:
    """Rewrite pipe-table separator rows so column widths match content.

    pandoc derives pipe-table column widths from the relative lengths of the
    dashes in the separator line. Long unbreakable tokens (filenames) overflow
    equal-width columns and visually collide with the next cell, so we widen
    the first column whenever its content is the widest.
    """
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^\|(\s*:?-+:?\s*)\|(?:\s*:?-+:?\s*\|)+\s*$", line)
        if m:
            header = lines[i - 1] if i > 0 else ""
            hcells = [c.strip() for c in header.split("|")[1:-1]] if "|" in header else []
            cols = line.split("|")[1:-1]
            if hcells and len(cols) == len(hcells):
                # measure first body row too
                body = lines[i + 1] if i + 1 < len(lines) else ""
                bcells = [c.strip() for c in body.split("|")[1:-1]] if "|" in body else []
                first_w = max(
                    _cell_width(hcells[0]) if hcells else 3,
                    _cell_width(bcells[0]) + 1 if bcells else 3,
                )
                others = [
                    _cell_width(h) for h in hcells[1:]
                ] + ([_cell_width(b) for b in bcells[1:]] if bcells else [])
                max_other = max(others) if others else 10
                total = first_w + max_other * len(hcells[1:])
                if first_w > max_other and first_w * len(hcells) > total:
                    # give first column real proportional weight
                    first_dash = max(first_w, 6)
                    other_dash = max(min(first_dash - 1, 6), 3)
                    cols = ["-" * first_dash] + ["-" * other_dash] * (len(cols) - 1)
                    line = "|" + "|".join(f" {c} " for c in cols) + "|"
            out.append(line)
        else:
            out.append(line)
        i += 1
    return "\n".join(out)


def collect_docs(root: str) -> list:
    """Return (section_name, [doc_paths...]) sorted by section number."""
    sections = {}
    for entry in os.listdir(root):
        full = os.path.join(root, entry)
        if os.path.isdir(full):
            docs = sorted(
                os.path.join(full, f)
                for f in os.listdir(full)
                if f.endswith(".md")
            )
            if docs:
                sections[entry] = docs
    ordered = sorted(sections.items(), key=lambda kv: section_key(kv[0]))
    return ordered


def build(root: str) -> str:
    parts = []
    total_files = 0
    for section, docs in collect_docs(root):
        title = PART_TITLES.get(section, section)
        parts.append(f"\n\\newpage\n\n# Part {section} — {title}\n")
        for doc in docs:
            if "RAW_DISCOVERY_NOTES" in doc:
                continue  # handled as appendix below
            with open(doc, encoding="utf-8") as fh:
                content = reduce(fh.read(), verbose=False)
            content = widen_first_table_column(content)
            parts.append(f"\n{demote_headings(content)}\n")
            total_files += 1

    # Appendix: raw discovery notes
    raw_dir = os.path.join(root, "99_APPENDIX", "RAW_DISCOVERY_NOTES")
    if os.path.isdir(raw_dir):
        parts.append("\n\\newpage\n\n# Part 99-A — Raw Discovery Notes (Work Packages)\n")
        for note in sorted(os.listdir(raw_dir)):
            if not note.endswith(".md"):
                continue
            path = os.path.join(raw_dir, note)
            with open(path, encoding="utf-8") as fh:
                content = reduce(fh.read(), verbose=False)
            parts.append(f"\n{demote_headings(content)}\n")
            total_files += 1

    title_page = (
        f"---\n"
        f"title: \"Mooziac Beta — Complete Technical Blueprint\"\n"
        f"subtitle: \"Reverse-engineering archive & engineering reference\"\n"
        f"date: \"{date.today().isoformat()}\"\n"
        f"lang: en\n"
        f"---\n"
        f"\n"
        f"{total_files} documents combined from the `Project Blueprint/` folder.\n"
    )
    return title_page + "\n".join(parts)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("blueprint_root")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    if not os.path.isdir(args.blueprint_root):
        print(f"Not a directory: {args.blueprint_root}", file=sys.stderr)
        sys.exit(1)

    combined = build(args.blueprint_root)
    with open(args.output, "w", encoding="utf-8") as fh:
        fh.write(combined)
    print(f"Wrote {args.output} ({len(combined):,} chars)")


if __name__ == "__main__":
    main()