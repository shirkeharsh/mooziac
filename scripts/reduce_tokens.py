#!/usr/bin/env python3
"""Token + glyph reduction for the Mooziac blueprint markdown.

Reduces token count before PDF rendering:
- Strips redundant boilerplate (audit banners, "READ-ONLY" disclaimers repeated per file)
- Collapses consecutive blank lines
- Strips HTML comments and absolute local paths -> relative
- DELETES all emoji (no PDF font can render them)
- Transcribes Devanagari vowels to romanized form (they cannot render in Menlo)
- Dedupes "Related" footer cross-refs that repeat within the same doc

Usage:
    python3 reduce_tokens.py <file.md> [<file2.md> ...]

Writes reduced content to stdout; logs stats to stderr.
"""
import re
import sys
from collections import Counter

# Unicode emoji ranges to DELETE entirely (keeps box-drawing + CJK + arrows)
EMOJI_RANGES = [
    (0x1F000, 0x1FAFF),   # Emoticons, misc symbols, pictographs
    (0x2600, 0x27BF),     # Misc symbols, dingbats, arrows variants
    (0x2300, 0x23FF),     # Misc technical (⏭ ⏯ …)
    (0x2B00, 0x2BFF),     # Misc symbols & arrows (⬇ ⬆ …)
    (0xFE0F, 0xFE0F),     # variation selector
    (0x2190, 0x21FF),     # full-width arrows used as emoji (← ↑ …)
    (0x2700, 0x27BF),     # dingbats
    (0x2282, 0x2282),     # ⊂ subset (no glyph in STHeiti)
    (0x25B6, 0x25B6),     # ▶ play (no glyph in Helvetica Neue)
    (0xFF0B, 0xFF0B),     # ＋ fullwidth plus (no glyph in Helvetica Neue)
]

# Devanagari vowels -> romanized transcription (keeps content, renders in Menlo)
DEVANAGARI_MAP = {
    "\u0905": "a",   # अ
    "\u0906": "aa",  # आ
    "\u0907": "i",   # इ
    "\u0908": "ii",  # ई
    "\u0909": "u",   # उ
    "\u090A": "uu",  # ऊ
    "\u090E": "e",   # ऎ
    "\u090F": "e",   # ए
    "\u0910": "ai",  # ऐ
    "\u0912": "o",   # ऒ
    "\u0913": "o",   # ओ
    "\u0914": "au",  # औ
    "\u090B": "ri",  # ऋ
    "\u090C": "ri",  # ऌ
}

BOILERPLATE = [
    re.compile(r"^Reverse-engineering archive of the Mooziac app.*$", re.M),
    re.compile(r"^READ-ONLY analysis; no source was modified\.$", re.M),
    re.compile(r"^Facts are directly verified in source\.*", re.M),
]

_EMOJI_RE = None


def _emoji_re() -> re.Pattern:
    global _EMOJI_RE
    if _EMOJI_RE is None:
        _EMOJI_RE = re.compile(
            "[" + "".join(f"{chr(lo)}-{chr(hi)}" for lo, hi in EMOJI_RANGES) + "]"
        )
    return _EMOJI_RE


def strip_emoji(text: str) -> str:
    return _emoji_re().sub("", text)


def transcribe_devanagari(text: str) -> str:
    return "".join(DEVANAGARI_MAP.get(ch, ch) for ch in text)


def reduce(text: str, verbose: bool = True) -> str:
    before = len(text)
    stats = Counter()

    # 1. Strip HTML comments
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    stats["html_comments"] = 1

    # 2. Drop boilerplate banner lines
    for pat in BOILERPLATE:
        text, n = pat.subn("", text)
        stats["boilerplate"] += n

    # 3. Collapse 3+ blank lines to 1
    text = re.sub(r"\n\s*\n(\s*\n)+", "\n\n", text)
    stats["blank_runs"] = 1

    # 4. Collapse horizontal-rule runs to a single ---
    text = re.sub(r"-{3,}\s*\n(-{3,}\s*\n)+", "---\n", text)

    # 5. Absolute local paths -> relative
    text = re.sub(r"file:///Users/harshshirke/local/projects/mp3kal/", "", text)
    text = re.sub(r"/Users/harshshirke/local/projects/mp3kal/", "", text)
    stats["abs_paths"] = 1

    # 6. DELETE all emoji
    n = len(re.findall(_emoji_re(), text))
    text = strip_emoji(text)
    stats["emoji"] = n

    # 7. Transcribe Devanagari (vowel set in lyrics manager docs)
    text = transcribe_devanagari(text)

    # 8. Dedupe consecutive identical "Related" / "See also" footer lines
    seen = set()
    out_lines = []
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith(("Related:", "See also:")):
            if stripped in seen:
                continue
            seen.add(stripped)
        out_lines.append(line)
    text = "\n".join(out_lines)
    stats["related_dedup"] = len(seen)

    # 9. Final whitespace trim of each line (trailing spaces)
    text = "\n".join(l.rstrip() for l in text.split("\n"))
    text = text.strip() + "\n"

    if verbose:
        print(f"  reduce: {before} -> {len(text)} chars "
              f"({100 * (before - len(text)) / max(before, 1):.1f}% smaller)",
              file=sys.stderr)
    return text


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8") as fh:
            out = reduce(fh.read())
        sys.stdout.write(out)


if __name__ == "__main__":
    main()