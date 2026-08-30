/* =========================================================
   MOOZIAC — 3D PLAYER CORE LOGIC & INTERACTION ENGINE
   ========================================================= */

/* ================= SVG ICONS (Clean Standard Vector Icons) ================= */
const I = {
  play: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.14v13.72a1 1 0 0 0 1.5.86l11.04-6.86a1 1 0 0 0 0-1.72L9.5 4.28A1 1 0 0 0 8 5.14z"/></svg>',
  pause: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 5a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5zm7 0a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2V5z"/></svg>',
  backward: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 18.5V5.5L2 12l9 6.5zm1.5-6.5l9 6.5V5.5l-9 6.5z"/></svg>',
  forward: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 18.5l9-6.5-9-6.5v13zm10-13v13l9-6.5-9-6.5z"/></svg>',
  heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>',
  heartfill: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>',
  repeat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>',
  repeat1: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/><path d="M11 10h1.5v4.5" stroke-width="1.8"/></svg>',
  search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7.5"/><line x1="21" y1="21" x2="16.5" y2="16.5"/></svg>',
  xmark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
  download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><polyline points="8 12 12 16 16 12"/><line x1="12" y1="8" x2="12" y2="16"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><polyline points="8 12 11 15 16 9.5"/></svg>',
  fullscreen: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="13" rx="2" ry="2"/><line x1="8" y1="20" x2="16" y2="20"/><line x1="12" y1="17" x2="12" y2="20"/></svg>',
  ellipsis: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="1.8"/><circle cx="5.5" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/></svg>',
  plusDoc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="6" x2="14" y2="6"/><line x1="3" y1="12" x2="14" y2="12"/><line x1="3" y1="18" x2="10" y2="18"/><line x1="18" y1="15" x2="18" y2="21"/><line x1="15" y1="18" x2="21" y2="18"/></svg>',
  plus: '<span style="font-size:13px;font-weight:800">+</span>',
  musicNote: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l10-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="16" cy="16" r="3"/></svg>',
  clockOutline: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
  searchOutline: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
  wand: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20L18 6M14 4l.9 2 2 .9-2 .9-.9 2-.9-2-2-.9 2-.9.9-2zM19.5 11l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6.6-1.4z"/></svg>',
  pulse: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h3l2-7 4 14 3-11 2 4h6"/></svg>',
  speakerOutline: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="M16.2 8.5a5 5 0 010 7"/></svg>',
  handTap: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11.2V6a1.5 1.5 0 013 0v4.7M12 10.7V4.8a1.5 1.5 0 013 0v6M6 12.3v-2a1.5 1.5 0 013 0v1.4M15 10.8v-.5a1.5 1.5 0 013 0V13c0 3.7-2.2 6.7-6 6.7-3.5 0-5.3-1.7-6.3-4.6l-1-2.8a1.4 1.4 0 012.6-1.1L8.5 13"/></svg>',
  chatBubble: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5.5h16v10H8.5L4 19.5v-4z"/></svg>',
  hashOutline: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9h16M4 15h16M10 3L7 21M17 3l-3 18"/></svg>'
};

function icon(name) {
  return I[name] || '';
}

const $ = id => document.getElementById(id);

/* ================= SAMPLE TRACKS ================= */
const TRACKS = [
  { title: "Mooziac", artist: "Now Playing", dur: 225, c1: "#ff7aa2", c2: "#ff9a62" },
  { title: "Mooziac", artist: "Now Playing", dur: 252, c1: "#6a5cff", c2: "#00e5ff" },
  { title: "Mooziac", artist: "Now Playing", dur: 178, c1: "#00d2a0", c2: "#3f5efb" }
];

/* ================= PLAYER STATE ================= */
let idx = 0;
let isPlaying = false;
let isLiked = false;
let repeatOn = false;
let currentTime = 0;
let theme = localStorage.getItem("mooziacTheme") === "light" ? "light" : "dark";
let addedToPlaylist = new Set();
let activeTab = "playlists";
let historyList = [];
let isDownloaded = false;

const BASE_HEIGHTS = [
  0.35, 0.55, 0.80, 0.45, 0.70, 0.95, 0.60, 0.85, 0.40, 0.75,
  0.90, 0.50, 0.80, 0.95, 0.55, 0.85, 0.45, 0.70, 0.90, 0.40,
  0.65, 0.85, 0.55, 0.75, 0.45, 0.70, 0.85, 0.35, 0.60, 0.75,
  0.50, 0.35
];
let waveEls = [];
let raf = null;
let lastT = 0;

const pill = $("pill");
const scene = $("scene");
const artwork = $("artwork");

/* ================= WAVEFORM GENERATOR & ANIMATION ================= */
function buildWaveform() {
  const wf = $("waveform");
  if (!wf) return;
  wf.innerHTML = "";
  waveEls = [];
  BASE_HEIGHTS.forEach((h, i) => {
    const d = document.createElement("div");
    d.className = "wave";
    d.style.height = (h * 100) + "%";
    if (i < BASE_HEIGHTS.length * 0.33) d.classList.add("done");
    wf.appendChild(d);
    waveEls.push(d);
  });
}

function setProgress(ratio) {
  const doneCount = Math.round(ratio * BASE_HEIGHTS.length);
  waveEls.forEach((el, i) => {
    el.classList.toggle("done", i < doneCount);
    if (!isPlaying) el.style.height = (BASE_HEIGHTS[i] * 100) + "%";
  });
}

function animateWave(t) {
  if (!isPlaying) {
    raf = null;
    return;
  }
  const dt = (t - lastT) / 1000;
  lastT = t;
  currentTime = Math.min(currentTime + dt, TRACKS[idx].dur);
  waveEls.forEach((el, i) => {
    const phase = (t / 400) + i * 0.55;
    const amp = Math.sin(phase) * 0.28 + 0.72;
    el.style.height = (BASE_HEIGHTS[i] * amp * 100) + "%";
  });
  updateTimecode();
  if (currentTime >= TRACKS[idx].dur) {
    if (repeatOn) {
      currentTime = 0;
    } else {
      nextTrack(true);
      return;
    }
  }
  raf = requestAnimationFrame(animateWave);
}

function startWave() {
  lastT = performance.now();
  if (raf) cancelAnimationFrame(raf);
  raf = requestAnimationFrame(animateWave);
}

function stopWave() {
  if (raf) cancelAnimationFrame(raf);
  raf = null;
  setProgress(currentTime / TRACKS[idx].dur);
}

function fmt(s) {
  const m = Math.floor(s / 60);
  const r = Math.floor(s % 60);
  return m + ":" + String(r).padStart(2, "0");
}

function updateTimecode() {
  const tc = $("timecode");
  if (tc) tc.textContent = fmt(currentTime) + " / " + fmt(TRACKS[idx].dur);
}

/* ================= LOAD TRACK ================= */
function loadTrack(i) {
  idx = (i + TRACKS.length) % TRACKS.length;
  const t = TRACKS[idx];
  if ($("title")) $("title").textContent = t.title;
  if ($("artist")) $("artist").textContent = t.artist;
  if (artwork) {
    artwork.style.setProperty("--track-c1", t.c1);
    artwork.style.setProperty("--track-c2", t.c2);
    if (typeof anime !== "undefined") {
      anime.remove(artwork);
      anime({
        targets: artwork,
        scale: [0.86, 1.08, 1],
        rotate: [-8, 3, 0],
        duration: 600,
        easing: "easeOutElastic(1, .6)"
      });
    }
  }
  currentTime = 0;
  if (isPlaying) {
    stopWave();
    startWave();
  }
  setProgress(0);
  updateTimecode();
  applyTheme();
  if (typeof anime !== "undefined") {
    anime.remove("#waveform .wave");
    anime({
      targets: "#waveform .wave",
      scaleY: [0.3, 1.3, 1],
      duration: 480,
      delay: anime.stagger(12, { from: "center" }),
      easing: "easeOutElastic(1, .6)"
    });
  }
  historyList = historyList.filter(h => h !== idx);
  historyList.unshift(idx);
  if (typeof isOpen === "function" && isOpen("playlistsPanel")) renderTabBody();
}

function nextTrack(auto) {
  loadTrack(idx + 1);
  if (!auto) toast("Next track");
}

/* ================= THEME CONTROLLER ================= */
function applyTheme() {
  if (theme !== "light" && theme !== "dark") theme = "dark";
  const light = theme === "light";

  // Website stays permanently black/dark
  document.body.classList.remove("theme-light");
  document.body.classList.add("theme-dark");

  // Switch player pill theme
  if (pill) {
    pill.classList.remove("theme-dark", "theme-light");
    pill.classList.add(light ? "theme-light" : "theme-dark");

    const root = pill.style;
    if (light) {
      root.setProperty("--pill-bg", "#ffffff");
      root.setProperty("--pill-border", "rgba(0,0,0,.15)");
      root.setProperty("--text-primary", "#080808");
      root.setProperty("--text-secondary", "rgba(0,0,0,.62)");
      root.setProperty("--time-color", "rgba(0,0,0,.52)");
      root.setProperty("--icon-color", "rgba(0,0,0,.82)");
      root.setProperty("--icon-play", "#080808");
      root.setProperty("--accent", "#080808");
      root.setProperty("--panel-bg", "rgba(0,0,0,.035)");
      root.setProperty("--panel-border", "rgba(0,0,0,.12)");
      root.setProperty("--ambient-glow", "rgba(0,0,0,.06)");
    } else {
      root.setProperty("--pill-bg", "#0b0b0b");
      root.setProperty("--pill-border", "rgba(255,255,255,.16)");
      root.setProperty("--text-primary", "#ffffff");
      root.setProperty("--text-secondary", "rgba(255,255,255,.66)");
      root.setProperty("--time-color", "rgba(255,255,255,.55)");
      root.setProperty("--icon-color", "rgba(255,255,255,.88)");
      root.setProperty("--icon-play", "#ffffff");
      root.setProperty("--accent", "#ffffff");
      root.setProperty("--panel-bg", "rgba(255,255,255,.045)");
      root.setProperty("--panel-border", "rgba(255,255,255,.12)");
      root.setProperty("--ambient-glow", "rgba(255,255,255,.09)");
    }

    pill.animate(
      [{ filter: "brightness(1)" }, { filter: "brightness(1.08)" }, { filter: "brightness(1)" }],
      { duration: 420, easing: "ease-out" }
    );
  }

  const label = $("themeName");
  if (label) label.textContent = light ? "White · Light" : "Black · OLED";

  const toggle = $("toggleThemes");
  if (toggle) {
    toggle.classList.add("on");
    toggle.dataset.theme = theme;
    toggle.setAttribute("aria-label", "Switch player theme between black and white");
    toggle.title = light ? "Switch to Black" : "Switch to White";
  }
}

function cycleTheme() {
  theme = theme === "dark" ? "light" : "dark";
  localStorage.setItem("mooziacTheme", theme);
  applyTheme();
  toast(theme === "light" ? "White player theme" : "Black player theme");
}

/* ================= 120FPS HARDWARE-ACCELERATED 3D TILT ================= */
if (scene && pill) {
  let curRotX = 0, curRotY = 0;
  let tgtRotX = 0, tgtRotY = 0;
  let isHovering = false;
  let tiltRafId = null;
  let pillRect = null;

  function updatePillRect() {
    pillRect = pill.getBoundingClientRect();
  }
  window.addEventListener("resize", () => { pillRect = null; }, { passive: true });
  window.addEventListener("scroll", () => { pillRect = null; }, { passive: true });

  function renderTilt120fps() {
    // 120Hz smooth exponential interpolation
    curRotX += (tgtRotX - curRotX) * 0.15;
    curRotY += (tgtRotY - curRotY) * 0.15;

    pill.style.transform = `rotateY(${curRotY.toFixed(2)}deg) rotateX(${curRotX.toFixed(2)}deg) translateZ(0)`;

    if (isHovering || Math.abs(tgtRotX - curRotX) > 0.02 || Math.abs(tgtRotY - curRotY) > 0.02) {
      tiltRafId = requestAnimationFrame(renderTilt120fps);
    } else {
      pill.style.transform = `rotateY(${tgtRotY}deg) rotateX(${tgtRotX}deg) translateZ(0)`;
      tiltRafId = null;
    }
  }

  function startTiltRaf() {
    if (!tiltRafId) {
      tiltRafId = requestAnimationFrame(renderTilt120fps);
    }
  }

  scene.addEventListener("mouseenter", () => {
    isHovering = true;
    updatePillRect();
    startTiltRaf();
  });

  scene.addEventListener("mousemove", (e) => {
    if (!pillRect) updatePillRect();
    const px = (e.clientX - pillRect.left) / pillRect.width - 0.5;
    const py = (e.clientY - pillRect.top) / pillRect.height - 0.5;
    tgtRotY = px * 16;
    tgtRotX = -py * 16;
    isHovering = true;
    startTiltRaf();
  }, { passive: true });

  scene.addEventListener("mouseleave", () => {
    isHovering = false;
    tgtRotX = 0;
    tgtRotY = 0;
    startTiltRaf();
  });

  scene.addEventListener("touchstart", () => {
    if (window.innerWidth > 960) {
      isHovering = true;
      updatePillRect();
      startTiltRaf();
    }
  }, { passive: true });

  scene.addEventListener("touchend", () => {
    if (window.innerWidth > 960) {
      isHovering = false;
      tgtRotX = 0;
      tgtRotY = 0;
      startTiltRaf();
    }
  }, { passive: true });
}

/* ================= CONTROLS & ICONS ================= */
function renderPlayIcon() {
  const b = $("btnPlay");
  if (!b) return;
  b.innerHTML = isPlaying ? icon("pause") : icon("play");
  b.title = isPlaying ? "Pause" : "Play";
  b.classList.toggle("playing", true);
}

function renderLikeIcon() {
  const b = $("btnLike");
  if (!b) return;
  b.innerHTML = isLiked ? icon("heartfill") : icon("heart");
  b.classList.toggle("liked", isLiked);
}

function renderRepeatIcon() {
  const b = $("btnRepeat");
  if (!b) return;
  b.innerHTML = repeatOn ? icon("repeat1") : icon("repeat");
  b.classList.toggle("repeat-on", repeatOn);
}

function renderStaticIcons() {
  if ($("btnPrev")) $("btnPrev").innerHTML = icon("backward");
  if ($("btnNext")) $("btnNext").innerHTML = icon("forward");
  if ($("btnDownload")) $("btnDownload").innerHTML = icon("download");
  if ($("btnFullscreen")) $("btnFullscreen").innerHTML = icon("fullscreen");
  if ($("btnSettings")) $("btnSettings").innerHTML = icon("ellipsis");

  /* Preferences row icons */
  if ($("prefIconThemes")) $("prefIconThemes").innerHTML = icon("wand");
  if ($("prefIconTimeline")) $("prefIconTimeline").innerHTML = icon("pulse");
  if ($("prefIconAudio")) $("prefIconAudio").innerHTML = icon("speakerOutline");
  if ($("prefIconGestures")) $("prefIconGestures").innerHTML = icon("handTap");
  if ($("prefIconLyrics")) $("prefIconLyrics").innerHTML = icon("chatBubble");
  if ($("prefIconDiscord")) $("prefIconDiscord").innerHTML = icon("hashOutline");
}

/* ================= EVENT LISTENERS ================= */
if ($("btnPlay")) {
  $("btnPlay").addEventListener("click", () => {
    isPlaying = !isPlaying;
    renderPlayIcon();
    if (isPlaying) startWave(); else stopWave();
  });
}

if ($("btnPrev")) {
  $("btnPrev").addEventListener("click", () => {
    loadTrack(idx - 1);
  });
}

if ($("btnNext")) {
  $("btnNext").addEventListener("click", () => {
    nextTrack();
  });
}

if ($("btnLike")) {
  $("btnLike").addEventListener("click", () => {
    isLiked = !isLiked;
    renderLikeIcon();
  });
}

if ($("btnRepeat")) {
  $("btnRepeat").addEventListener("click", () => {
    repeatOn = !repeatOn;
    renderRepeatIcon();
  });
}

/* Waveform seek */
if ($("waveform")) {
  $("waveform").addEventListener("click", (e) => {
    const r = $("waveform").getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width));
    currentTime = ratio * TRACKS[idx].dur;
    setProgress(ratio);
    updateTimecode();
    if (isPlaying) {
      if (raf) cancelAnimationFrame(raf);
      startWave();
    }
  });
}

/* ================= 120FPS HARDWARE-ACCELERATED PREFERENCES PANEL ================= */
function openPanel(id) {
  const el = $(id);
  if (!el) return;
  el.classList.add("open");
  if (typeof anime !== "undefined") {
    anime.remove(el);
    anime({
      targets: el,
      opacity: [0, 1],
      translateY: [-10, 0],
      scale: [0.97, 1],
      duration: 450,
      easing: "cubicBezier(0.16, 1, 0.3, 1)"
    });
  }
}

function closePanel(id) {
  const el = $(id);
  if (!el || !el.classList.contains("open")) return;
  if (typeof anime !== "undefined") {
    anime.remove(el);
    anime({
      targets: el,
      opacity: [1, 0],
      translateY: [0, -8],
      scale: [1, 0.98],
      duration: 220,
      easing: "cubicBezier(0.4, 0, 1, 1)",
      complete: function() {
        el.classList.remove("open");
        el.style.opacity = "";
        el.style.transform = "";
      }
    });
  } else {
    el.classList.remove("open");
  }
}

function isOpen(id) {
  const el = $(id);
  return el ? el.classList.contains("open") : false;
}

/* Preferences toggle button (3-dots) */
if ($("btnSettings")) {
  $("btnSettings").addEventListener("click", () => {
    const willOpen = !isOpen("prefsPanel");
    if (willOpen) openPanel("prefsPanel"); else closePanel("prefsPanel");
  });
}

/* Preferences row toggles */
document.querySelectorAll(".toggle").forEach(t => {
  t.addEventListener("click", () => {
    if (t.id === "toggleThemes") {
      cycleTheme();
      return;
    }
    t.classList.toggle("on");
  });
});

/* Download button animation */
if ($("btnDownload")) {
  $("btnDownload").addEventListener("click", () => {
    const b = $("btnDownload");
    if (b.dataset.done) return;
    b.innerHTML = "";
    const ring = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    ring.setAttribute("viewBox", "0 0 24 24");
    ring.style.width = ring.style.height = "18px";
    ring.style.transform = "rotate(-90deg)";
    const circ = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    circ.setAttribute("cx", "12");
    circ.setAttribute("cy", "12");
    circ.setAttribute("r", "9");
    circ.setAttribute("fill", "none");
    circ.setAttribute("stroke", "currentColor");
    circ.setAttribute("stroke-width", "2");
    circ.setAttribute("stroke-linecap", "round");
    circ.setAttribute("stroke-dasharray", "56.5");
    circ.setAttribute("stroke-dashoffset", "56.5");
    ring.appendChild(circ);
    b.appendChild(ring);
    let p = 0;
    const iv = setInterval(() => {
      p += 0.06;
      circ.setAttribute("stroke-dashoffset", String(56.5 * (1 - p)));
      if (p >= 1) {
        clearInterval(iv);
        b.dataset.done = "1";
        b.innerHTML = icon("check");
        b.style.color = "#34c759";
        isDownloaded = true;
      }
    }, 40);
  });
}

/* Fullscreen trigger */
if ($("btnFullscreen")) {
  $("btnFullscreen").addEventListener("click", () => {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  });
}

/* ================= ANIME.JS 3D MODEL PHYSICS & HAPTIC FEEDBACK ================= */
function bounceBtn(el, scale = 0.84) {
  if (typeof anime === "undefined" || !el) return;
  anime.remove(el);
  anime({
    targets: el,
    scale: [scale, 1.12, 1],
    duration: 420,
    easing: "easeOutElastic(1, .55)"
  });
}

function initAnimeModelPhysics() {
  // Attach bounce to all interactive player buttons
  document.querySelectorAll(".btn, .chip-btn").forEach(b => {
    b.addEventListener("click", function() {
      bounceBtn(this);
    });
  });
}

/* ================= INIT ================= */
buildWaveform();
renderStaticIcons();
renderPlayIcon();
renderLikeIcon();
renderRepeatIcon();
loadTrack(0);
applyTheme();
initAnimeModelPhysics();

/* On desktop: wait 1 second after page load, then expand the 3-dot preferences panel */
if (window.innerWidth > 960) {
  setTimeout(() => {
    if (!isOpen("prefsPanel")) {
      openPanel("prefsPanel");
      const btn = $("btnSettings");
      if (btn && typeof bounceBtn === "function") {
        bounceBtn(btn, 0.85);
      }
    }
  }, 1000);
}

/* ================= AUTO-EXPAND PLAYER ON MOBILE SCROLL ONLY ================= */
(function() {
  let userManuallyToggled = false;
  let manualTimer = null;
  let isTicking = false;
  let autoOpened = false;

  const btn = $("btnSettings");
  if (btn) {
    btn.addEventListener("click", () => {
      userManuallyToggled = true;
      clearTimeout(manualTimer);
      manualTimer = setTimeout(() => {
        userManuallyToggled = false;
      }, 6000);
    });
  }

  function checkMobileScrollExpand() {
    if (window.innerWidth > 960) {
      isTicking = false;
      return;
    }

    const scrollY = window.scrollY || window.pageYOffset || 0;

    if (!userManuallyToggled) {
      // Automatically expand the player when scrolling down on phone
      if (scrollY > 30 && !isOpen("prefsPanel") && !autoOpened) {
        autoOpened = true;
        openPanel("prefsPanel");
        if (btn && typeof bounceBtn === "function") {
          bounceBtn(btn, 0.85);
        }
      }
      // Collapse back when returning to the very top of the page
      else if (scrollY <= 10 && isOpen("prefsPanel") && autoOpened) {
        autoOpened = false;
        closePanel("prefsPanel");
      }
    }

    isTicking = false;
  }

  window.addEventListener("scroll", () => {
    if (!isTicking && window.innerWidth <= 960) {
      isTicking = true;
      window.requestAnimationFrame(checkMobileScrollExpand);
    }
  }, { passive: true });
})();

