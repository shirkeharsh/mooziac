#!/usr/bin/env python3
"""
Mooziac Brain PDF Generator
Compiles all .mooziac-brain knowledge, system architecture, and blueprints
into a single publication-grade PDF and exports it to ~/Desktop/Mooziac_Brain_System_Design.pdf.
"""

import os
import re
import sys
import subprocess
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
BRAIN_DIR = REPO_DIR / ".mooziac-brain"
DESKTOP_DIR = Path.home() / "Desktop"
OUT_PDF = DESKTOP_DIR / "Mooziac_Brain_System_Design.pdf"
TEMP_MD = REPO_DIR / "dist" / "Mooziac_Brain_Combined.md"

TEMP_MD.parent.mkdir(parents=True, exist_ok=True)

# Order of knowledge modules to compile
KNOWLEDGE_FILES = [
    ("Master Knowledge Index", BRAIN_DIR / "brain.md"),
    ("System Architecture", BRAIN_DIR / "knowledge" / "architecture.md"),
    ("App Lifecycle & Foundation", BRAIN_DIR / "knowledge" / "application.md"),
    ("Player State & UI Pipeline", BRAIN_DIR / "knowledge" / "player.md"),
    ("Audio & Playback Engines", BRAIN_DIR / "knowledge" / "audio.md"),
    ("Gestures & Multi-Touch Input", BRAIN_DIR / "knowledge" / "gestures_input.md"),
    ("Library & Database Services", BRAIN_DIR / "knowledge" / "library.md"),
    ("WebKit & Network Architecture", BRAIN_DIR / "knowledge" / "network_web.md"),
    ("UI Components & Themes", BRAIN_DIR / "knowledge" / "ui.md"),
    ("Website & Distribution", BRAIN_DIR / "knowledge" / "website.md"),
    ("GitHub & Release Pipeline", BRAIN_DIR / "knowledge" / "github.md"),
    ("Development Workflows", BRAIN_DIR / "knowledge" / "workflows.md"),
    ("Known Issues & Risk Register", BRAIN_DIR / "issues" / "known-issues.md"),
    ("System Design Overview", REPO_DIR / "SYSTEM_DESIGN.md"),
    ("Engineering Session Log & Architecture Manual", REPO_DIR / "AGY.md"),
]

def sanitize_for_latex(text: str) -> str:
    """Strip or replace emoji glyphs that cannot be rendered by standard TeX fonts."""
    replacements = {
        "🧠": "[Brain]", "🚀": "[Launch]", "⚡": "[Fast]", "✨": "[Feature]",
        "🎨": "[Design]", "🛠️": "[Tools]", "🛠": "[Tools]", "📦": "[Package]",
        "💡": "[Tip]", "⚠️": "[Warning]", "🛑": "[Stop]", "🔍": "[Search]",
        "📊": "[Stats]", "🍎": "[Apple]", "🌐": "[Web]", "🔒": "[Security]",
        "✅": "[OK]", "❌": "[Error]", "🟢": "[Active]", "🟡": "[Pending]",
        "🎉": "[New]", "🖐️": "[Gestures]", "🖐": "[Gestures]", "📜": "[Lyrics]",
        "🎮": "[Discord]", "📱": "[Remote]", "🎧": "[Audio]", "🏷️": "[Tag]",
        "🏷": "[Tag]", "•": "-", "—": "--", "–": "-", "…": "...",
        "“": '"', "”": '"', "‘": "'", "’": "'", "→": "->", "←": "<-",
        "├─": "|-", "└─": "`-", "│": "|", "─": "-",
    }
    for k, v in replacements.items():
        text = text.replace(k, v)
    
    cleaned = []
    for ch in text:
        code = ord(ch)
        if code < 128 or (0x00A0 <= code <= 0x00FF):
            cleaned.append(ch)
        else:
            cleaned.append(" ")
    return "".join(cleaned)

def main():
    print(f"🧠 [Mooziac Brain] Compiling knowledge modules for PDF generation...")
    
    combined_content = []
    
    front_matter = """---
title: "Mooziac Brain — Complete System Design & Knowledge Manual"
subtitle: "Native macOS Music Player Architecture, Subsystems, and Knowledge Graph"
author: "Mooziac Autonomous Engineering System"
date: "Version 0.1.0 (2026)"
geometry: "margin=2cm"
fontsize: 10pt
mainfont: "Helvetica Neue"
monofont: "Menlo"
colorlinks: true
linkcolor: "NavyBlue"
toccolor: "NavyBlue"
urlcolor: "NavyBlue"
number-sections: true
toc: true
toc-depth: 3
---

\\newpage
"""
    combined_content.append(front_matter)
    
    section_num = 1
    for title, filepath in KNOWLEDGE_FILES:
        if not filepath.exists():
            print(f"⚠️ Warning: File not found, skipping: {filepath}")
            continue
            
        print(f"  + [{section_num}] Adding {title} ({filepath.name})")
        raw_text = filepath.read_text(encoding="utf-8", errors="ignore")
        sanitized = sanitize_for_latex(raw_text)
        
        demoted = []
        for line in sanitized.splitlines():
            if line.startswith("#"):
                demoted.append("#" + line)
            else:
                demoted.append(line)
        
        section_block = f"\n\n# {title}\n\n" + "\n".join(demoted) + "\n\n\\newpage\n"
        combined_content.append(section_block)
        section_num += 1
        
    combined_md_text = "\n".join(combined_content)
    TEMP_MD.write_text(combined_md_text, encoding="utf-8")
    print(f"📝 Wrote unified markdown ({len(combined_md_text):,} bytes) to {TEMP_MD}")
    
    print(f"⚙️ Rendering PDF via pandoc + xelatex...")
    cmd = [
        "/opt/homebrew/bin/pandoc",
        str(TEMP_MD),
        "--pdf-engine=/usr/local/texlive/2025basic/bin/universal-darwin/xelatex",
        "-V", "pagestyle=plain",
        "-o", str(OUT_PDF)
    ]
    
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        pdf_size = OUT_PDF.stat().st_size / (1024 * 1024)
        print(f"🎉 SUCCESS! Brain PDF generated: {OUT_PDF} ({pdf_size:.2f} MB)")
    except subprocess.CalledProcessError as e:
        print(f"❌ Pandoc/XeLaTeX Error:\n{e.stderr}")
        sys.exit(1)

if __name__ == "__main__":
    main()
