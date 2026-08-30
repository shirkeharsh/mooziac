#!/bin/bash
# Build MooziacBeta.pdf from the entire Project Blueprint folder.
# Pipeline: reduce+combine -> pandoc (markdown) -> xelatex -> PDF
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BLUEPRINT_DIR="$REPO_DIR/Project Blueprint"
OUT_DIR="$REPO_DIR/dist"
SCRIPTS_DIR="$REPO_DIR/scripts"

COMBINED_MD="$OUT_DIR/MooziacBeta.md"
COMBINED_PDF="$OUT_DIR/MooziacBeta.pdf"

mkdir -p "$OUT_DIR"

echo "==> Combining & reducing blueprint markdown..."
python3 "$SCRIPTS_DIR/combine_book.py" "$BLUEPRINT_DIR" -o "$COMBINED_MD"

echo "==> Rendering PDF via pandoc + xelatex..."
pandoc "$COMBINED_MD" \
  --pdf-engine=xelatex \
  --toc \
  --toc-depth=2 \
  --number-sections \
  -V mainfont="Helvetica Neue" \
  -V monofont="Menlo" \
  -V fontsize=9pt \
  -V geometry:margin=2cm \
  -V colorlinks=true \
  -V linkcolor=NavyBlue \
  -V toccolor=NavyBlue \
  -V urlcolor=NavyBlue \
  -V pagestyle=plain \
  -o "$COMBINED_PDF" 2> "$OUT_DIR/pandoc_warnings.log" \
  && echo "PDF OK: $COMBINED_PDF"

echo "==> Pandoc warnings (glyphs the font can't render):"
grep -c "Missing character" "$OUT_DIR/pandoc_warnings.log" | xargs echo "  missing-glyph warnings:"
grep "Missing character" "$OUT_DIR/pandoc_warnings.log" | sed 's/^.*There is no //' | sort | uniq -c | sort -rn | head -20

ls -lh "$OUT_DIR"