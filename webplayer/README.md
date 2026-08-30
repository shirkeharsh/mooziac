# 🏝️ Mooziac Webplayer (Embeddable Component)

A standalone, pure **Web Component Model** of the **Mooziac macOS Dynamic Island Player**.

---

## 🚀 Embed on Any Website

### Option 1: 1-Line `iframe` Embed
```html
<iframe 
  src="path/to/webplayer/index.html" 
  width="390" 
  height="480" 
  frameborder="0" 
  style="border: none; overflow: hidden; background: transparent;"
></iframe>
```

### Option 2: Direct Script Embed (HTML / React / Next.js / Vue)
1. Add stylesheet:
   ```html
   <link rel="stylesheet" href="path/to/webplayer/style.css">
   ```
2. Insert player markup from [`index.html`](file:///Users/harshshirke/local/projects/Mooziac/mp3kal/webplayer/index.html).
3. Include scripts before `</body>`:
   ```html
   <script src="path/to/webplayer/icons.js"></script>
   <script src="path/to/webplayer/player.js"></script>
   ```

---

## 🎨 Features
* **Zero Outer Clutter**: Pure player widget, no demo headings or unwanted text.
* **Exact Fixed SVG Icons**: Correctly oriented heart (unliked/liked with heart-pop animation), crisp search icon, play/pause, prev/next, repeat, download ring, and settings.
* **3D Mouse Tilt**: Smooth cursor-following 3D perspective effect.
* **32-Bar Real-Time Waveform**: Animated audio visualizer with interactive click-and-drag scrub bar.
* **Interactive Drawers**: 3-dots Settings flyout & Playlist Library drawer.
* **Click Musical Notes**: Glowing musical note burst (`♪`, `♫`, `♬`, `♩`, `🎶`, `✨`) on click/touch outside the card.
