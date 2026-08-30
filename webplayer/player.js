/* =========================================================
   MOOZIAC — DYNAMIC ISLAND WEBPLAYER ENGINE
   Clean 1:1 macOS Logic & 60+ FPS Waveform Engine
   ========================================================= */

(function() {
  'use strict';

  // Vector SVG Icons (100% Upright, Clean Standard ViewBoxes)
  const ICONS = {
    play: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.14v13.72a1 1 0 0 0 1.5.86l11.04-6.86a1 1 0 0 0 0-1.72L9.5 4.28A1 1 0 0 0 8 5.14z"/></svg>`,
    pause: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 5a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5zm7 0a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2V5z"/></svg>`,
    prev: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 18.5V5.5L2 12l9 6.5zm1.5-6.5l9 6.5V5.5l-9 6.5z"/></svg>`,
    next: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 18.5l9-6.5-9-6.5v13zm10-13v13l9-6.5-9-6.5z"/></svg>`,
    heart: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>`,
    heartFill: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>`,
    repeat: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>`,
    repeat1: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/><path d="M11 10h1.5v4.5" stroke-width="1.8"/></svg>`,
    download: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><polyline points="8 12 12 16 16 12"/><line x1="12" y1="8" x2="12" y2="16"/></svg>`,
    downloadCheck: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><polyline points="8 12 11 15 16 9.5"/></svg>`,
    fullscreen: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="13" rx="2" ry="2"/><line x1="8" y1="20" x2="16" y2="20"/><line x1="12" y1="17" x2="12" y2="20"/></svg>`,
    dots: `<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="1.8"/><circle cx="5.5" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/></svg>`,
    palette: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="13.5" cy="6.5" r=".5"/><circle cx="17.5" cy="10.5" r=".5"/><circle cx="8.5" cy="7.5" r=".5"/><circle cx="6.5" cy="12.5" r=".5"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.9 0 1.6-.7 1.6-1.6 0-.4-.2-.8-.5-1.1-.3-.3-.5-.7-.5-1.1 0-.9.7-1.6 1.6-1.6H16c3.3 0 6-2.7 6-6 0-5.5-4.5-10-10-10z"/></svg>`,
    pulse: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h3l2-7 4 14 3-11 2 4h6"/></svg>`,
    gesture: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 11V6a2 2 0 0 0-2-2v0a2 2 0 0 0-2 2v0M14 10V4a2 2 0 0 0-2-2v0a2 2 0 0 0-2 2v6M10 10.5V6a2 2 0 0 0-2-2v0a2 2 0 0 0-2 2v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/></svg>`,
    lyrics: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`,
    discord: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9h16M4 15h16M10 3L7 21M17 3l-3 18"/></svg>`
  };

  // Sample Tracks
  const TRACKS = [
    { title: "Neon Sunrise", artist: "Aurora Waves", dur: 225, c1: "#ff7aa2", c2: "#ff9a62", accent: "#fa4059" },
    { title: "Midnight Drive", artist: "The Midnight Club", dur: 252, c1: "#6a5cff", c2: "#00e5ff", accent: "#00d9ff" },
    { title: "Velvet Skyline", artist: "Luma", dur: 178, c1: "#00d2a0", c2: "#3f5efb", accent: "#2ecc71" }
  ];

  // 32-Bar Heights Profile from Swift Codebase
  const BASE_HEIGHTS = [
    0.35, 0.55, 0.80, 0.45, 0.70, 0.95, 0.60, 0.85, 0.40, 0.75,
    0.90, 0.50, 0.80, 0.95, 0.55, 0.85, 0.45, 0.70, 0.90, 0.40,
    0.65, 0.85, 0.55, 0.75, 0.45, 0.70, 0.85, 0.35, 0.60, 0.75,
    0.50, 0.35
  ];

  // State
  let idx = 0;
  let isPlaying = false;
  let isLiked = false;
  let repeatMode = 0; // 0: off, 1: all, 2: one
  let currentTime = 48;
  let isSettingsOpen = false;
  let isLightMode = false;
  let isDownloaded = false;
  let isDownloading = false;

  let waveEls = [];
  let animId = null;
  let lastT = 0;

  const $ = (id) => document.getElementById(id);
  const pill = $('pill');
  const stage = $('stage');
  const artwork = $('artwork');
  const btnPlay = $('btnPlay');
  const btnPrev = $('btnPrev');
  const btnNext = $('btnNext');
  const btnLike = $('btnLike');
  const btnRepeat = $('btnRepeat');
  const btnDownload = $('btnDownload');
  const btnFullscreen = $('btnFullscreen');
  const btnSettings = $('btnSettings');
  const waveform = $('waveform');
  const timecode = $('timecode');
  const prefsPanel = $('prefsPanel');

  // ================= 1. INJECT ICONS =================
  function setupIcons() {
    btnPlay.innerHTML = ICONS.play;
    btnPrev.innerHTML = ICONS.prev;
    btnNext.innerHTML = ICONS.next;
    btnLike.innerHTML = ICONS.heart;
    btnRepeat.innerHTML = ICONS.repeat;
    btnDownload.innerHTML = ICONS.download;
    btnFullscreen.innerHTML = ICONS.fullscreen;
    btnSettings.innerHTML = ICONS.dots;

    if ($('prefIconThemes')) $('prefIconThemes').innerHTML = ICONS.palette;
    if ($('prefIconTimeline')) $('prefIconTimeline').innerHTML = ICONS.pulse;
    if ($('prefIconGestures')) $('prefIconGestures').innerHTML = ICONS.gesture;
    if ($('prefIconLyrics')) $('prefIconLyrics').innerHTML = ICONS.lyrics;
    if ($('prefIconDiscord')) $('prefIconDiscord').innerHTML = ICONS.discord;
  }

  // ================= 2. WAVEFORM GENERATOR =================
  function buildWaveform() {
    if (!waveform) return;
    waveform.innerHTML = '';
    waveEls = [];
    BASE_HEIGHTS.forEach((h) => {
      const bar = document.createElement('div');
      bar.className = 'wave';
      bar.style.height = `${h * 100}%`;
      waveform.appendChild(bar);
      waveEls.push(bar);
    });
    updateProgressVisuals();
  }

  function updateProgressVisuals() {
    const track = TRACKS[idx];
    const ratio = Math.max(0, Math.min(1, currentTime / track.dur));
    const activeCount = Math.round(ratio * BASE_HEIGHTS.length);

    waveEls.forEach((bar, i) => {
      bar.classList.toggle('done', i < activeCount);
      if (!isPlaying) {
        bar.style.height = `${BASE_HEIGHTS[i] * 100}%`;
      }
    });

    if (timecode) {
      timecode.textContent = `${formatTime(currentTime)} / ${formatTime(track.dur)}`;
    }
  }

  function formatTime(s) {
    const mins = Math.floor(s / 60);
    const secs = Math.floor(s % 60);
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }

  function animateWave(t) {
    if (!isPlaying) {
      animId = null;
      return;
    }

    if (!lastT) lastT = t;
    const dt = (t - lastT) / 1000;
    lastT = t;

    const track = TRACKS[idx];
    currentTime = Math.min(track.dur, currentTime + dt);

    waveEls.forEach((bar, i) => {
      const phase = (t / 380) + (i * 0.45);
      const waveOffset = Math.sin(phase) * 0.25;
      const dynamicH = Math.max(0.20, Math.min(1.0, BASE_HEIGHTS[i] + waveOffset));
      bar.style.height = `${dynamicH * 100}%`;
    });

    updateProgressVisuals();

    if (currentTime >= track.dur) {
      if (repeatMode === 2) {
        currentTime = 0;
      } else if (repeatMode === 1 || idx < TRACKS.length - 1) {
        nextTrack();
        return;
      } else {
        pauseTrack();
        currentTime = 0;
        updateProgressVisuals();
        return;
      }
    }

    animId = requestAnimationFrame(animateWave);
  }

  // ================= 3. PLAYBACK CONTROLLER =================
  function playTrack() {
    isPlaying = true;
    btnPlay.innerHTML = ICONS.pause;
    btnPlay.style.transform = 'scale(1.15)';
    setTimeout(() => btnPlay.style.transform = '', 140);
    lastT = performance.now();
    animId = requestAnimationFrame(animateWave);
  }

  function pauseTrack() {
    isPlaying = false;
    btnPlay.innerHTML = ICONS.play;
    btnPlay.style.transform = 'scale(0.9)';
    setTimeout(() => btnPlay.style.transform = '', 140);
    if (animId) {
      cancelAnimationFrame(animId);
      animId = null;
    }
    updateProgressVisuals();
  }

  function togglePlay() {
    if (isPlaying) pauseTrack();
    else playTrack();
  }

  function loadTrack(i) {
    idx = (i + TRACKS.length) % TRACKS.length;
    const t = TRACKS[idx];
    if ($('title')) $('title').textContent = t.title;
    if ($('artist')) $('artist').textContent = t.artist;
    if (artwork) {
      artwork.style.setProperty('--track-c1', t.c1);
      artwork.style.setProperty('--track-c2', t.c2);
    }
    pill.style.setProperty('--accent', t.accent);
    currentTime = 0;
    updateProgressVisuals();
  }

  function nextTrack() {
    loadTrack(idx + 1);
    if (isPlaying) playTrack();
  }

  function prevTrack() {
    if (currentTime > 3) {
      currentTime = 0;
      updateProgressVisuals();
    } else {
      loadTrack(idx - 1);
    }
    if (isPlaying) playTrack();
  }

  function toggleLike() {
    isLiked = !isLiked;
    btnLike.classList.toggle('liked', isLiked);
    btnLike.innerHTML = isLiked ? ICONS.heartFill : ICONS.heart;
  }

  function toggleRepeat() {
    repeatMode = (repeatMode + 1) % 3;
    if (repeatMode === 0) {
      btnRepeat.innerHTML = ICONS.repeat;
      btnRepeat.classList.remove('repeat-on');
    } else if (repeatMode === 1) {
      btnRepeat.innerHTML = ICONS.repeat;
      btnRepeat.classList.add('repeat-on');
    } else {
      btnRepeat.innerHTML = ICONS.repeat1;
      btnRepeat.classList.add('repeat-on');
    }
  }

  function handleDownload() {
    if (isDownloading || isDownloaded) return;
    isDownloading = true;
    btnDownload.style.transform = 'scale(0.85)';
    setTimeout(() => {
      btnDownload.style.transform = 'scale(1.15)';
      btnDownload.innerHTML = ICONS.downloadCheck;
      btnDownload.classList.add('downloaded');
      isDownloading = false;
      isDownloaded = true;
      setTimeout(() => btnDownload.style.transform = '', 180);
    }, 600);
  }

  function toggleSettings() {
    isSettingsOpen = !isSettingsOpen;
    if (prefsPanel) prefsPanel.classList.toggle('open', isSettingsOpen);
    btnSettings.style.color = isSettingsOpen ? '#00d9ff' : '';
  }

  // ================= 4. 3D PERSPECTIVE TILT =================
  function init3DTilt() {
    if (!stage || !pill) return;

    stage.addEventListener('mousemove', (e) => {
      const rect = pill.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;

      const rotX = -(y / (rect.height / 2)) * 8.5;
      const rotY = (x / (rect.width / 2)) * 8.5;

      pill.style.transform = `rotateX(${rotX.toFixed(2)}deg) rotateY(${rotY.toFixed(2)}deg)`;
    });

    stage.addEventListener('mouseleave', () => {
      pill.style.transform = 'rotateX(0deg) rotateY(0deg)';
    });
  }

  // ================= 5. CLICK MUSICAL NOTE PARTICLES =================
  function initMusicalNotes() {
    const notes = ['♪', '♫', '♬', '♩', '🎶', '✨'];
    const colors = ['#fa4059', '#8b7bff', '#ff6584', '#a78bfa', '#38ef7d', '#ffd166'];

    function spawn(x, y) {
      const bubble = document.createElement('span');
      bubble.className = 'floating-music-bubble';
      bubble.textContent = notes[Math.floor(Math.random() * notes.length)];

      const color = colors[Math.floor(Math.random() * colors.length)];
      bubble.style.color = color;
      bubble.style.textShadow = `0 0 12px ${color}, 0 0 24px ${color}`;

      const dx = (Math.random() - 0.5) * 75;
      const dy = -45 - Math.random() * 45;
      const rot = (Math.random() - 0.5) * 55;

      bubble.style.setProperty('--dx', `${dx}px`);
      bubble.style.setProperty('--dy', `${dy}px`);
      bubble.style.setProperty('--rot', `${rot}deg`);
      bubble.style.left = `${x}px`;
      bubble.style.top = `${y}px`;

      document.body.appendChild(bubble);
      setTimeout(() => bubble.remove(), 1100);
    }

    document.addEventListener('click', (e) => {
      if (e.target && e.target.closest && e.target.closest('.player-pill')) {
        return;
      }
      const count = 3 + Math.floor(Math.random() * 2);
      for (let i = 0; i < count; i++) {
        setTimeout(() => {
          spawn(e.clientX + (Math.random() - 0.5) * 16, e.clientY + (Math.random() - 0.5) * 16);
        }, i * 60);
      }
    });
  }

  // ================= 6. EVENT LISTENERS =================
  function setupEvents() {
    btnPlay.addEventListener('click', togglePlay);
    btnNext.addEventListener('click', nextTrack);
    btnPrev.addEventListener('click', prevTrack);
    btnLike.addEventListener('click', toggleLike);
    btnRepeat.addEventListener('click', toggleRepeat);
    btnDownload.addEventListener('click', handleDownload);
    btnSettings.addEventListener('click', toggleSettings);

    // Waveform Click & Scrub
    if (waveform) {
      waveform.addEventListener('click', (e) => {
        const rect = waveform.getBoundingClientRect();
        const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
        currentTime = ratio * TRACKS[idx].dur;
        updateProgressVisuals();
      });
    }

    // Toggle Switches in Settings
    document.querySelectorAll('.toggle').forEach((tg) => {
      tg.addEventListener('click', () => {
        tg.classList.toggle('on');
        if (tg.id === 'toggleThemes') {
          isLightMode = !isLightMode;
          pill.classList.toggle('theme-light', isLightMode);
          if ($('themeName')) $('themeName').textContent = isLightMode ? 'White · Light' : 'Black · OLED';
        }
      });
    });
  }

  // ================= 7. BOOTSTRAP =================
  document.addEventListener('DOMContentLoaded', () => {
    setupIcons();
    buildWaveform();
    loadTrack(idx);
    init3DTilt();
    initMusicalNotes();
    setupEvents();
  });

})();
