/* =========================================================
   MOOZIAC WEB PLAYER — EXACT DITTO JAVASCRIPT ENGINE
   1:1 macOS Menu Bar Player Logic + Real No-Copyright Music & Seeking
   ========================================================= */

(function () {
  'use strict';

  // =========================================================
  // 1. APPLE SF SYMBOLS VECTOR SVG ICONS
  // Pixel-perfect upright standard vectors
  // =========================================================
  const ICONS = {
    play: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.14v13.72a1 1 0 0 0 1.5.86l11.04-6.86a1 1 0 0 0 0-1.72L9.5 4.28A1 1 0 0 0 8 5.14z"/></svg>`,
    pause: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 5a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5zm7 0a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2V5z"/></svg>`,
    prev: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 18.5V5.5L2 12l9 6.5zm1.5-6.5l9 6.5V5.5l-9 6.5z"/></svg>`,
    next: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 18.5l9-6.5-9-6.5v13zm10-13v13l9-6.5-9-6.5z"/></svg>`,
    heart: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>`,
    heartFill: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>`,
    repeat: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>`,
    repeat1: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/><path d="M11 10h1.5v4.5" stroke-width="1.8"/></svg>`,
    search: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7.5"/><line x1="21" y1="21" x2="16.5" y2="16.5"/></svg>`,
    xmark: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`,
    playlist: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="6" x2="14" y2="6"/><line x1="3" y1="12" x2="14" y2="12"/><line x1="3" y1="18" x2="10" y2="18"/><line x1="18" y1="15" x2="18" y2="21"/><line x1="15" y1="18" x2="21" y2="18"/></svg>`,
    download: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><polyline points="8 12 12 16 16 12"/><line x1="12" y1="8" x2="12" y2="16"/></svg>`,
    downloadCheck: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><polyline points="8 12 11 15 16 9.5"/></svg>`,
    fullscreen: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="13" rx="2" ry="2"/><line x1="8" y1="20" x2="16" y2="20"/><line x1="12" y1="17" x2="12" y2="20"/></svg>`,
    dots: `<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="1.8"/><circle cx="5.5" cy="12" r="1.8"/><circle cx="18.5" cy="12" r="1.8"/></svg>`,
    // Settings Icons
    paintbrush: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.8 2.2a2.3 2.3 0 0 1 3.2 0 2.3 2.3 0 0 1 0 3.2l-1.5 1.5-3.2-3.2 1.5-1.5zm-3 3L4.2 16.8c-.3.3-.5.7-.6 1.1l-1 4.5a.7.7 0 0 0 .9.9l4.5-1c.4-.1.8-.3 1.1-.6L20.7 10.1l-4.9-4.9z"/></svg>`,
    waveform: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h3l2-6 4 12 3-8 2 5h4"/></svg>`,
    speaker: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11 5L6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
    gestures: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v8"/><path d="M8 8a4 4 0 0 1 8 0v4"/><circle cx="12" cy="3" r="1"/><path d="M7 14v-2a2 2 0 0 1 4 0v6a6 6 0 0 0 12 0v-4a2 2 0 0 0-4 0v2"/></svg>`,
    lyrics: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M20 2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h4l4 4 4-4h4c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zM9 11H7V9h2v2zm4 0h-2V9h2v2zm4 0h-2V9h2v2z"/></svg>`,
    discord: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><line x1="4" y1="9" x2="20" y2="9"/><line x1="4" y1="15" x2="20" y2="15"/><line x1="10" y1="3" x2="8" y2="21"/><line x1="16" y1="3" x2="14" y2="21"/></svg>`,
    // Library Tabs
    tabPlaylists: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>`,
    tabLiked: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>`,
    tabDownloads: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="8 12 12 16 16 12"/><line x1="12" y1="4" x2="12" y2="16"/><path d="M4 20h16"/></svg>`,
    tabHistory: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15 15"/></svg>`,
    shuffle: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/><line x1="4" y1="4" x2="9" y2="9"/></svg>`
  };

  // =========================================================
  // 2. 32-BAR SWIFT BASE HEIGHTS
  // Direct port of WaveformProgressView.swift baseHeights
  // =========================================================
  const BASE_HEIGHTS = [
    0.35, 0.55, 0.80, 0.45, 0.70, 0.95, 0.60, 0.85, 0.40, 0.75,
    0.90, 0.50, 0.80, 0.95, 0.55, 0.85, 0.45, 0.70, 0.90, 0.40,
    0.65, 0.85, 0.55, 0.75, 0.45, 0.70, 0.85, 0.35, 0.60, 0.75,
    0.50, 0.35
  ];

  // =========================================================
  // 3. REAL NO-COPYRIGHT MUSIC (NCS) TRACKS WITH SYNCED LYRICS
  // =========================================================
  const TRACKS = [
    {
      title: "Happy Life",
      artist: "NCS • Upbeat Pop",
      duration: 90.85,
      accent: "#00d9ff",
      ambient: "rgba(0, 217, 255, 0.40)",
      artwork: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=256&q=85",
      audio: "./audio/happy_life.mp3",
      audioBackup: "https://raw.githubusercontent.com/effacestudios/Royalty-Free-Music-Pack/master/Happy%20Life.mp3",
      lyrics: [
        { t: 0, text: "♪ (Upbeat acoustic intro groove…)" },
        { t: 6, text: "Sunshine waking up across the sky" },
        { t: 12, text: "Watching all the golden clouds float by" },
        { t: 18, text: "Every morning brings a brand new day" },
        { t: 24, text: "Chasing all the stormy clouds away" },
        { t: 30, text: "Living in this happy melody" },
        { t: 36, text: "Feel the joy and spirit floating free" },
        { t: 42, text: "♪ (Lively whistling and guitar hook…)" },
        { t: 50, text: "Step outside and take a breath of air" },
        { t: 56, text: "Smiles and laughter waiting everywhere" },
        { t: 62, text: "Together we can light the darkest night" },
        { t: 68, text: "Everything is gonna be alright" },
        { t: 75, text: "Happy life, the music carries on" },
        { t: 82, text: "Singing out our favorite summer song" }
      ]
    },
    {
      title: "Bubbles",
      artist: "Royalty Free • Chill Pop",
      duration: 91.01,
      accent: "#ff7aa2",
      ambient: "rgba(255, 122, 162, 0.42)",
      artwork: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=256&q=85",
      audio: "./audio/bubbles.mp3",
      audioBackup: "https://raw.githubusercontent.com/effacestudios/Royalty-Free-Music-Pack/master/Bubbles.mp3",
      lyrics: [
        { t: 0, text: "♪ (Light and playful bubble melody…)" },
        { t: 5, text: "Bubbles floating upward in the air" },
        { t: 11, text: "Floating gently without any care" },
        { t: 17, text: "Colors shining through the morning dew" },
        { t: 23, text: "Every shade of violet, pink, and blue" },
        { t: 29, text: "Pop and vanish into gentle light" },
        { t: 35, text: "Glittering like stars throughout the night" },
        { t: 42, text: "♪ (Playful chime arpeggio…)" },
        { t: 49, text: "Dancing on the breezes soft and mild" },
        { t: 56, text: "Pure imagination like a child" },
        { t: 63, text: "Rising higher till they reach the sun" },
        { t: 70, text: "Our magical adventure has begun" },
        { t: 78, text: "Sweet harmonious echoes float along" },
        { t: 84, text: "In this peaceful, happy bubble song" }
      ]
    },
    {
      title: "Gamer Guy",
      artist: "NCS • 8-Bit Chiptune",
      duration: 81.87,
      accent: "#38ef7d",
      ambient: "rgba(56, 239, 125, 0.38)",
      artwork: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=256&q=85",
      audio: "./audio/gamer_guy.mp3",
      audioBackup: "https://raw.githubusercontent.com/effacestudios/Royalty-Free-Music-Pack/master/Gamer%20Guy.mp3",
      lyrics: [
        { t: 0, text: "♪ (Retro 8-bit chiptune synth start…)" },
        { t: 4, text: "Press start, insert coin to play" },
        { t: 8, text: "Level one is underway" },
        { t: 13, text: "Collecting gold coins on the run" },
        { t: 18, text: "Underneath the pixel sun" },
        { t: 23, text: "Speed run jumping through the stage" },
        { t: 28, text: "Turn the next arcade page" },
        { t: 33, text: "♪ (High energy synth breakdown…)" },
        { t: 40, text: "Boss battle on the horizon now" },
        { t: 46, text: "We will beat the level somehow" },
        { t: 52, text: "Combo multipliers in the zone" },
        { t: 58, text: "Victory is ready to be shown" },
        { t: 64, text: "High score flashing on the screen" },
        { t: 70, text: "Greatest player that you've ever seen" },
        { t: 76, text: "GAME OVER • NEW RECORD SET!" }
      ]
    },
    {
      title: "Dubstepper",
      artist: "NCS • Electronic Bass",
      duration: 91.01,
      accent: "#fa4059",
      ambient: "rgba(250, 64, 89, 0.42)",
      artwork: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=256&q=85",
      audio: "./audio/dubstepper.mp3",
      audioBackup: "https://raw.githubusercontent.com/effacestudios/Royalty-Free-Music-Pack/master/Dubstepper.mp3",
      lyrics: [
        { t: 0, text: "♪ (Sub bass building tension…)" },
        { t: 6, text: "Feel the pressure rising through the floor" },
        { t: 12, text: "Step inside and close the soundproof door" },
        { t: 18, text: "Warning: bass drop incoming now" },
        { t: 23, text: "3... 2... 1... DROP!" },
        { t: 25, text: "♪ (Heavy wobbling bass synth drops!)" },
        { t: 36, text: "Wobble bass shaking up the room" },
        { t: 42, text: "Laser synths piercing through the gloom" },
        { t: 48, text: "Feel the impact of the heavy beat" },
        { t: 54, text: "Moving everyone on the dance street" },
        { t: 60, text: "♪ (Second drop: aggressive lead rhythm!)" },
        { t: 72, text: "Electrified and running wild tonight" },
        { t: 79, text: "Underneath the strobe flashing light" },
        { t: 85, text: "Dubstep power till the morning light" }
      ]
    },
    {
      title: "Party Time",
      artist: "Royalty Free • Dance Anthem",
      duration: 102.71,
      accent: "#8b5cf6",
      ambient: "rgba(139, 92, 246, 0.40)",
      artwork: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=256&q=85",
      audio: "./audio/party_time.mp3",
      audioBackup: "https://raw.githubusercontent.com/effacestudios/Royalty-Free-Music-Pack/master/Party%20Time.mp3",
      lyrics: [
        { t: 0, text: "♪ (Punchy four-on-the-floor dance beat…)" },
        { t: 6, text: "Welcome to the party, kick off your shoes" },
        { t: 12, text: "Tonight we've got nothing left to lose" },
        { t: 18, text: "Hands up high reaching for the sky" },
        { t: 24, text: "Watch the disco spotlight flying by" },
        { t: 30, text: "Feel the groove taking over you" },
        { t: 36, text: "Everything you ever wanted to do" },
        { t: 42, text: "♪ (Main dance club anthem chorus!)" },
        { t: 50, text: "Turn the speakers to eleven loud" },
        { t: 56, text: "Get lost inside the jumping crowd" },
        { t: 63, text: "Party time from midnight to the dawn" },
        { t: 70, text: "Keep the celebration going on" },
        { t: 77, text: "Bass reverberates throughout your chest" },
        { t: 84, text: "Tonight is better than all the rest" },
        { t: 92, text: "One more beat before the daylight shines" }
      ]
    }
  ];

  // Theme metadata from SettingsPanel+Appearance.swift
  const THEMES = [
    { key: "adaptive", name: "Adaptive", desc: "Live dynamic artwork backdrop" },
    { key: "oled", name: "OLED Dark", desc: "Deep pitch-black dark contrast" },
    { key: "glass", name: "Crystal Glass", desc: "Translucent frosted glass panel" },
    { key: "fluid", name: "Watery Transparent", desc: "Watery pure transparent liquid glass" }
  ];

  // Progress Style metadata from ProgressStyle.swift
  const PROGRESS_STYLES = [
    { key: "waveform", name: "Waveform Bars", desc: "Dynamic 32-bar reactive waves" },
    { key: "neonGlow", name: "Neon Glow", desc: "Glowing neon capsule progress" },
    { key: "cyberDots", name: "Cyber Dots", desc: "Pulsing LED dot-matrix counter" },
    { key: "minimalLine", name: "Minimal Line", desc: "Ultra-clean precision audio line" }
  ];

  // =========================================================
  // 4. PLAYER STATE & REAL AUDIO ENGINE
  // =========================================================
  let currentTrackIdx = 0;
  let isPlaying = false;
  let isLiked = false;
  let repeatMode = 0; // 0: off, 1: all, 2: one
  let currentTime = 0;
  // Index 1 = "oled", the pitch-black dark theme. This is also the theme the
  // landing page's showcase cards default to, so the two stay in sync on load.
  const DEFAULT_THEME_IDX = 1;
  let currentThemeIdx = DEFAULT_THEME_IDX;
  let currentProgressStyleIdx = 0;
  let isSearchOpen = false;
  let isSettingsOpen = false;
  let isPlaylistOpen = false;
  // Live Lyric Flow is off by default; the toggle in the settings drawer turns
  // it on. The bar carries .lyrics-hidden in the markup so it is already
  // collapsed before this script runs.
  let isLyricsEnabled = false;
  let isScrubbing = false;
  let currentTab = "playlists";

  // Preferences-drawer reveal state. The drawer is not open on load — that made
  // the pill jump from 140px to 422px before the visitor had done anything.
  let hasRevealedSettings = false;
  let settingsRevealTimer = null;

  // Real HTML5 Audio Element
  const audio = new Audio();
  audio.crossOrigin = "anonymous";
  audio.preload = "auto";

  // Waveform animation physics
  let wavePhase = 0;
  let lastFrameTime = performance.now();
  let rafId = null;
  let toastTimer = null;

  // DOM Elements
  const $ = (id) => document.getElementById(id);
  const playerPill = $('playerPill');
  const stage = $('stage');
  // On the landing page the player is embedded in a scrollable document, so the
  // "playing" state class is applied to the stage wrapper rather than <body>
  // to avoid any chance of it colliding with page-level styles.
  const stageRoot = (stage && stage.closest('.player-stage')) || document.body;
  const artwork = $('artwork');
  const trackTitle = $('title');
  const trackArtist = $('artist');
  const timecodeLabel = $('time');
  const ambientGlow = $('ambientGlow');
  const toastBanner = $('toastBanner');
  const toastText = $('toastText');

  // Floating Lyrics Bar
  const lyricsBar = $('lyricsBar');
  const lyricLine = $('lyricLine');

  // Controls
  const btnPlay = $('btnPlay');
  const btnPrev = $('btnPrev');
  const btnNext = $('btnNext');
  const btnLike = $('btnLike');
  const btnRepeat = $('btnRepeat');
  const btnSearch = $('btnSearch');
  const btnPlaylist = $('btnPlaylist');
  const btnDownload = $('btnDownload');
  const btnFullscreen = $('btnFullscreen');
  const btnSettings = $('btnSettings');

  // Search
  const searchInput = $('searchInput');
  const searchClearBtn = $('searchClearBtn');

  // Seeker views
  const seekerContainer = $('seekerContainer');
  const waveformView = $('waveform');
  const neonView = $('neonView');
  const neonFill = $('neonFill');
  const cyberView = $('cyberView');
  const minimalView = $('minimalView');
  const minimalFill = $('minimalFill');

  // Settings
  const themeDesc = $('themeDesc');
  const progressDesc = $('progressDesc');
  const themeStepToggle = $('themeStepToggle');
  const progressStepToggle = $('progressStepToggle');

  // Playlist drawer
  const libSearchInput = $('libSearchInput');
  const libraryList = $('libraryList');

  let waveBars = [];
  let cyberDots = [];

  // =========================================================
  // 5. ICON INJECTION
  // =========================================================
  function injectIcons() {
    btnPlay.innerHTML = ICONS.play;
    btnPrev.innerHTML = ICONS.prev;
    btnNext.innerHTML = ICONS.next;
    btnLike.innerHTML = ICONS.heart;
    btnRepeat.innerHTML = ICONS.repeat;
    btnSearch.innerHTML = ICONS.search;
    btnPlaylist.innerHTML = ICONS.playlist;
    btnDownload.innerHTML = ICONS.download;
    btnFullscreen.innerHTML = ICONS.fullscreen;
    btnSettings.innerHTML = ICONS.dots;

    $('searchInnerIcon').innerHTML = ICONS.search;

    $('iconThemes').innerHTML = ICONS.paintbrush;
    $('iconProgress').innerHTML = ICONS.waveform;
    $('iconLoudness').innerHTML = ICONS.speaker;
    $('iconGestures').innerHTML = ICONS.gestures;
    $('iconLyrics').innerHTML = ICONS.lyrics;
    $('iconDiscord').innerHTML = ICONS.discord;

    $('tabIconPlaylists').innerHTML = ICONS.tabPlaylists;
    $('tabIconLiked').innerHTML = ICONS.tabLiked;
    $('tabIconDownloads').innerHTML = ICONS.tabDownloads;
    $('tabIconHistory').innerHTML = ICONS.tabHistory;

    $('btnLibPlayAll').innerHTML = ICONS.play;
    $('btnLibShuffle').innerHTML = ICONS.shuffle;
  }

  // =========================================================
  // 6. BUILD SEEKER VIEWS
  // =========================================================
  function buildSeekers() {
    // 1. Build 32 Waveform Bars
    waveformView.innerHTML = '';
    waveBars = [];
    BASE_HEIGHTS.forEach((h, i) => {
      const bar = document.createElement('div');
      bar.className = 'waveform-bar';
      bar.dataset.base = h;
      bar.style.height = `${Math.max(3, 12 * h)}px`;
      waveformView.appendChild(bar);
      waveBars.push(bar);
    });

    // 2. Build 24 Cyber Dots
    cyberView.innerHTML = '';
    cyberDots = [];
    const DOT_COUNT = 24;
    for (let i = 0; i < DOT_COUNT; i++) {
      const dot = document.createElement('div');
      dot.className = 'cyber-dot';
      cyberView.appendChild(dot);
      cyberDots.push(dot);
    }
  }

  // =========================================================
  // 7. TIME FORMATTER (0:00 / 0:00)
  // =========================================================
  function formatTime(sec) {
    if (isNaN(sec) || !isFinite(sec) || sec < 0) sec = 0;
    const mins = Math.floor(sec / 60);
    const secs = Math.floor(sec % 60);
    return `${mins}:${String(secs).padStart(2, '0')}`;
  }

  function getEffectiveDuration() {
    if (audio.duration && !isNaN(audio.duration) && isFinite(audio.duration) && audio.duration > 1) {
      return audio.duration;
    }
    return TRACKS[currentTrackIdx].duration || 90;
  }

  // =========================================================
  // 8. SYNCHRONIZED LYRICS ENGINE (Live Lyric Flow)
  // Positioned directly above the player pill
  // =========================================================
  function updateLyrics(time) {
    if (!isLyricsEnabled) return;
    const track = TRACKS[currentTrackIdx];
    if (!track.lyrics || track.lyrics.length === 0) {
      if (lyricLine) lyricLine.textContent = `♪ ${track.title} • ${track.artist}`;
      return;
    }

    let activeText = track.lyrics[0].text;
    for (let i = 0; i < track.lyrics.length; i++) {
      if (time >= track.lyrics[i].t) {
        activeText = track.lyrics[i].text;
      } else {
        break;
      }
    }

    if (lyricLine && lyricLine.textContent !== activeText) {
      lyricLine.classList.add('animating');
      setTimeout(() => {
        lyricLine.textContent = activeText;
        lyricLine.classList.remove('animating');
      }, 140);
    }
  }

  // =========================================================
  // 9. UPDATE PROGRESS & ANIMATION
  // Calibrated wave speed: 2.4 rad/sec matching WaveformProgressView.swift
  // =========================================================
  function updateProgressVisuals() {
    const totalDuration = getEffectiveDuration();
    const progress = Math.max(0, Math.min(1, currentTime / totalDuration));

    // Timecode
    timecodeLabel.textContent = `${formatTime(currentTime)} / ${formatTime(totalDuration)}`;

    // 1. Waveform styling
    const activeCount = Math.round(progress * BASE_HEIGHTS.length);
    waveBars.forEach((bar, i) => {
      bar.classList.toggle('active', i < activeCount);
      if (!isPlaying) {
        const base = parseFloat(bar.dataset.base);
        bar.style.height = `${Math.max(3, 12 * base)}px`;
      }
    });

    // 2. Neon glow styling
    if (neonFill) {
      neonFill.style.width = `${progress * 100}%`;
    }

    // 3. Cyber dots styling
    const activeDotCount = Math.round(progress * cyberDots.length);
    cyberDots.forEach((dot, i) => {
      dot.classList.toggle('active', i < activeDotCount);
    });

    // 4. Minimal line styling
    if (minimalFill) {
      minimalFill.style.width = `${progress * 100}%`;
    }
  }

  // Calm, natural wave animation: 2.4 rad/sec (NOT 18 rad/sec!)
  function tick(timestamp) {
    if (!isPlaying) {
      rafId = null;
      return;
    }

    const dt = Math.min(0.1, (timestamp - lastFrameTime) / 1000);
    lastFrameTime = timestamp;

    // Advance time only when NOT scrubbing
    if (!isScrubbing) {
      if (!audio.paused && !isNaN(audio.currentTime) && audio.currentTime >= 0) {
        currentTime = audio.currentTime;
      } else {
        const totalDuration = getEffectiveDuration();
        currentTime = Math.min(totalDuration, currentTime + dt);
      }
    }

    // Speed of wave oscillation: 2.4 radians per second
    wavePhase += dt * 2.4;

    // Animate active waveform bars
    waveBars.forEach((bar, i) => {
      const base = parseFloat(bar.dataset.base);
      const waveOffset = Math.sin(wavePhase + i * 0.4) * 0.20;
      const dynamicH = Math.max(0.20, Math.min(1.0, base + waveOffset));
      bar.style.height = `${Math.max(3, 12 * dynamicH)}px`;
    });

    // Pulse cyber dots when playing
    if (currentProgressStyleIdx === 2) {
      cyberDots.forEach((dot, i) => {
        if (dot.classList.contains('active')) {
          const pulse = Math.sin(wavePhase + i * 0.5) * 0.25;
          dot.style.transform = `scale(${1 + pulse})`;
        } else {
          dot.style.transform = 'scale(1)';
        }
      });
    }

    updateProgressVisuals();
    updateLyrics(currentTime);

    const totalDuration = getEffectiveDuration();

    // Auto next / loop
    if (currentTime >= totalDuration) {
      if (repeatMode === 2) {
        currentTime = 0;
        try { audio.currentTime = 0; audio.play().catch(() => {}); } catch(e) {}
      } else if (repeatMode === 1 || currentTrackIdx < TRACKS.length - 1) {
        loadTrack((currentTrackIdx + 1) % TRACKS.length);
        startPlayback();
        return;
      } else {
        pausePlayback();
        currentTime = 0;
        updateProgressVisuals();
        return;
      }
    }

    rafId = requestAnimationFrame(tick);
  }

  // =========================================================
  // 10. REAL AUDIO PLAYBACK
  // =========================================================
  function startPlayback() {
    isPlaying = true;
    stageRoot.classList.add('playing');
    btnPlay.innerHTML = ICONS.pause;
    btnPlay.title = "Pause";
    btnPlay.style.transform = 'scale(1.15)';
    setTimeout(() => { btnPlay.style.transform = ''; }, 140);
    lastFrameTime = performance.now();

    // Play real audio stream
    if (audio.src) {
      audio.play().catch((err) => {
        console.warn("Audio autoplay policy or stream error:", err);
      });
    }

    if (!rafId) rafId = requestAnimationFrame(tick);
  }

  function pausePlayback() {
    isPlaying = false;
    stageRoot.classList.remove('playing');
    btnPlay.innerHTML = ICONS.play;
    btnPlay.title = "Play";
    btnPlay.style.transform = 'scale(0.88)';
    setTimeout(() => { btnPlay.style.transform = ''; }, 140);

    try { audio.pause(); } catch(e) {}

    if (rafId) {
      cancelAnimationFrame(rafId);
      rafId = null;
    }
    updateProgressVisuals();
  }

  function togglePlayback() {
    if (isPlaying) pausePlayback();
    else startPlayback();
  }

  function loadTrack(idx) {
    currentTrackIdx = (idx + TRACKS.length) % TRACKS.length;
    const t = TRACKS[currentTrackIdx];

    trackTitle.textContent = t.title;
    trackArtist.textContent = t.artist;

    artwork.style.opacity = '0';
    const img = new Image();
    img.onload = () => {
      artwork.src = t.artwork;
      artwork.style.opacity = '1';
    };
    img.src = t.artwork;

    document.documentElement.style.setProperty('--accent', t.accent);
    document.documentElement.style.setProperty('--ambient-color', t.ambient);

    // Load real audio source
    currentTime = 0;
    if (t.audio) {
      audio.src = t.audio;
      audio.load();
    }

    updateProgressVisuals();
    updateLyrics(0);
    renderLibrary();
  }

  function playRandomTrack() {
    let nextIdx;
    do {
      nextIdx = Math.floor(Math.random() * TRACKS.length);
    } while (nextIdx === currentTrackIdx && TRACKS.length > 1);
    loadTrack(nextIdx);
    startPlayback();
    showToast(`🔀 Shuffled: "${TRACKS[nextIdx].title}"`);
  }

  function nextTrack() {
    loadTrack(currentTrackIdx + 1);
    if (isPlaying) startPlayback();
  }

  function prevTrack() {
    if (currentTime > 3) {
      currentTime = 0;
      try { audio.currentTime = 0; } catch(e) {}
      updateProgressVisuals();
      updateLyrics(0);
    } else {
      loadTrack(currentTrackIdx - 1);
    }
    if (isPlaying) startPlayback();
  }

  function toggleLike() {
    isLiked = !isLiked;
    btnLike.classList.toggle('liked', isLiked);
    btnLike.innerHTML = isLiked ? ICONS.heartFill : ICONS.heart;
    btnLike.title = isLiked ? "Unlike" : "Like Track";
  }

  function toggleRepeat() {
    repeatMode = (repeatMode + 1) % 3;
    btnRepeat.classList.remove('repeat-on');
    if (repeatMode === 0) {
      btnRepeat.innerHTML = ICONS.repeat;
      btnRepeat.title = "Repeat Off";
      showToast("Repeat: Off");
    } else if (repeatMode === 1) {
      btnRepeat.innerHTML = ICONS.repeat;
      btnRepeat.classList.add('repeat-on');
      btnRepeat.title = "Repeat All";
      showToast("Repeat: All Tracks");
    } else {
      btnRepeat.innerHTML = ICONS.repeat1;
      btnRepeat.classList.add('repeat-on');
      btnRepeat.title = "Repeat One";
      showToast("Repeat: Current Track");
    }
  }

  function handleDownload() {
    if (btnDownload.classList.contains('downloaded') || btnDownload.classList.contains('downloading')) return;
    btnDownload.classList.add('downloading');
    showToast("Downloading offline audio…");
    setTimeout(() => {
      btnDownload.classList.remove('downloading');
      btnDownload.classList.add('downloaded');
      btnDownload.innerHTML = ICONS.downloadCheck;
      showToast("Downloaded (Available Offline)");
    }, 1500);
  }

  // =========================================================
  // 11. EXPANDABLE SEARCH BAR
  // 1:1 match with Core.swift expandSearchField() / collapseSearchField()
  // =========================================================
  function expandSearch() {
    if (isSearchOpen) return;
    isSearchOpen = true;
    playerPill.classList.add('search-open');
    btnSearch.innerHTML = ICONS.xmark;
    btnSearch.title = "Close Search";
    searchInput.value = '';
    searchInput.focus();
  }

  function collapseSearch() {
    if (!isSearchOpen) return;
    isSearchOpen = false;
    playerPill.classList.remove('search-open');
    btnSearch.innerHTML = ICONS.search;
    btnSearch.title = "Search YouTube Music";
    searchInput.blur();
    searchClearBtn.style.display = 'none';
  }

  function toggleSearch() {
    if (isSearchOpen) collapseSearch();
    else expandSearch();
  }

  function handleSearchSubmit() {
    const q = searchInput.value.trim();
    if (!q) {
      collapseSearch();
      return;
    }

    // URL validation matching URLFilter.containsLink(query)
    const hasUrl = /https?:\/\/|www\.|\.[a-z]{2,}(\/|$)/i.test(q);
    if (hasUrl) {
      searchInput.value = '';
      showToast("⚠️ Links/URLs are not allowed in search", true);
      return;
    }

    // Search query matching
    const matchIdx = TRACKS.findIndex(
      (t) => t.title.toLowerCase().includes(q.toLowerCase()) || t.artist.toLowerCase().includes(q.toLowerCase())
    );

    collapseSearch();

    if (matchIdx !== -1) {
      showToast(`▶ Playing "${TRACKS[matchIdx].title}"`);
      loadTrack(matchIdx);
      startPlayback();
    } else {
      showToast(`⚡ Searching "${q}" on YouTube Music…`);
    }
  }

  // =========================================================
  // 12. TOAST NOTIFICATION BANNER
  // Floating capsule at top center with smooth dissolve
  // =========================================================
  function showToast(msg) {
    if (toastTimer) clearTimeout(toastTimer);
    toastText.textContent = msg;
    toastBanner.classList.add('show');
    toastTimer = setTimeout(() => {
      toastBanner.classList.remove('show');
    }, 2400);
  }

  // =========================================================
  // 13. THEME PALETTE MANAGER (SettingsPanel+Appearance.swift)
  // Adaptive (0), OLED Dark (1), Crystal Glass (2), Watery Fluid (3)
  // =========================================================
  function applyTheme(idx, silent) {
    currentThemeIdx = (idx + THEMES.length) % THEMES.length;
    const theme = THEMES[currentThemeIdx];

    playerPill.classList.remove('theme-oled', 'theme-glass', 'theme-fluid');
    if (theme.key === 'oled') playerPill.classList.add('theme-oled');
    else if (theme.key === 'glass') playerPill.classList.add('theme-glass');
    else if (theme.key === 'fluid') playerPill.classList.add('theme-fluid');

    themeDesc.textContent = theme.desc;

    // Update 4-step dots
    document.querySelectorAll('#themeStepToggle .step-dot').forEach((dot, i) => {
      dot.classList.toggle('active', i === currentThemeIdx);
    });

    if (!silent) showToast(`Theme: ${theme.name}`);
  }

  function cycleTheme() {
    applyTheme(currentThemeIdx + 1);
  }

  // =========================================================
  // 14. TIMELINE PROGRESS STYLE MANAGER (ProgressStyle.swift)
  // Waveform (0), Neon Glow (1), Cyber Dots (2), Minimal Line (3)
  // =========================================================
  function applyProgressStyle(idx, silent) {
    currentProgressStyleIdx = (idx + PROGRESS_STYLES.length) % PROGRESS_STYLES.length;
    const style = PROGRESS_STYLES[currentProgressStyleIdx];

    waveformView.style.display = currentProgressStyleIdx === 0 ? 'flex' : 'none';
    neonView.style.display = currentProgressStyleIdx === 1 ? 'flex' : 'none';
    cyberView.style.display = currentProgressStyleIdx === 2 ? 'flex' : 'none';
    minimalView.style.display = currentProgressStyleIdx === 3 ? 'flex' : 'none';

    progressDesc.textContent = style.desc;

    // Update 4-step dots
    document.querySelectorAll('#progressStepToggle .step-dot').forEach((dot, i) => {
      dot.classList.toggle('active', i === currentProgressStyleIdx);
    });

    updateProgressVisuals();
    if (!silent) showToast(`Progress Bar: ${style.name}`);
  }

  function cycleProgressStyle() {
    applyProgressStyle(currentProgressStyleIdx + 1);
  }

  // =========================================================
  // 15. SETTINGS & PLAYLIST DRAWERS
  // =========================================================
  function toggleSettings() {
    // A manual toggle counts as the reveal, so a pending desktop timer never
    // fights the user for control of the drawer.
    hasRevealedSettings = true;
    if (settingsRevealTimer) {
      clearTimeout(settingsRevealTimer);
      settingsRevealTimer = null;
    }

    isSettingsOpen = !isSettingsOpen;
    if (isSettingsOpen && isPlaylistOpen) {
      isPlaylistOpen = false;
      playerPill.classList.remove('playlist-open');
    }
    playerPill.classList.toggle('settings-open', isSettingsOpen);
    btnSettings.style.color = isSettingsOpen ? 'var(--accent)' : '';
  }

  // Opens the drawer at most once, and only ever opens it — never toggles.
  function revealSettings() {
    if (hasRevealedSettings) return;
    hasRevealedSettings = true;
    if (settingsRevealTimer) {
      clearTimeout(settingsRevealTimer);
      settingsRevealTimer = null;
    }
    if (!isSettingsOpen) toggleSettings();
  }

  // Device capability, not viewport width: a rotated or resized phone is still
  // a phone, and a narrow desktop window should not change the behaviour.
  function isTouchPrimaryDevice() {
    return (navigator.maxTouchPoints > 0) ||
      (window.matchMedia && window.matchMedia('(hover: none)').matches);
  }

  function revealSettingsOnFirstInteraction() {
    if (isTouchPrimaryDevice()) {
      // Phones: reveal on the first tap, or on the first scroll for visitors
      // who start flicking the page before tapping anything.
      const events = ['pointerdown', 'keydown', 'scroll'];

      function onFirstInteraction(e) {
        // The ellipsis opens the drawer through its own click handler. Reveal
        // here as well and the capture-phase pointerdown would shut it again.
        if (e.target && e.target.closest && e.target.closest('#btnSettings')) return;

        events.forEach(ev => window.removeEventListener(ev, onFirstInteraction, true));
        revealSettings();
      }

      events.forEach(ev => window.addEventListener(ev, onFirstInteraction, true));
    } else {
      // Desktop: open it once the page has settled.
      settingsRevealTimer = setTimeout(revealSettings, 1000);
    }
  }

  function togglePlaylist() {
    isPlaylistOpen = !isPlaylistOpen;
    if (isPlaylistOpen && isSettingsOpen) {
      isSettingsOpen = false;
      playerPill.classList.remove('settings-open');
      btnSettings.style.color = '';
    }
    playerPill.classList.toggle('playlist-open', isPlaylistOpen);
    btnPlaylist.style.color = isPlaylistOpen ? 'var(--accent)' : '';
    if (isPlaylistOpen) renderLibrary();
  }

  // =========================================================
  // 16. PLAYLIST & LIBRARY DRAWER TABS
  // =========================================================
  function renderLibrary() {
    if (!libraryList) return;
    const filter = (libSearchInput.value || '').trim().toLowerCase();

    libraryList.innerHTML = '';

    TRACKS.forEach((t, i) => {
      const match = !filter || t.title.toLowerCase().includes(filter) || t.artist.toLowerCase().includes(filter);
      if (!match) return;

      const isCurrent = i === currentTrackIdx;
      const row = document.createElement('div');
      row.className = `lib-item-row ${isCurrent ? 'active' : ''}`;

      let badgeHtml = '';
      if (currentTab === 'liked') {
        badgeHtml = `<span class="lib-item-badge" style="color:#ff3b5c">${ICONS.heartFill}</span>`;
      } else if (currentTab === 'downloads') {
        badgeHtml = `<span class="lib-item-badge" style="color:#2ecc71">${ICONS.downloadCheck}</span>`;
      } else if (currentTab === 'history') {
        badgeHtml = `<span class="lib-item-sub">${i === 0 ? 'Just now' : `${i * 3}m ago`}</span>`;
      }

      row.innerHTML = `
        <div class="lib-item-play-btn">${isCurrent && isPlaying ? ICONS.pause : ICONS.play}</div>
        <div class="lib-item-text">
          <div class="lib-item-title">${t.title}</div>
          <div class="lib-item-sub">${t.artist}</div>
        </div>
        ${badgeHtml}
      `;

      row.addEventListener('click', () => {
        if (isCurrent) {
          togglePlayback();
        } else {
          loadTrack(i);
          startPlayback();
        }
      });

      libraryList.appendChild(row);
    });
  }

  // =========================================================
  // 17. 100% PRECISE & ROBUST SEEKING ENGINE
  // =========================================================
  function getSeekRatio(e) {
    const rect = seekerContainer.getBoundingClientRect();
    const clientX = e.clientX !== undefined ? e.clientX : (e.touches && e.touches[0] ? e.touches[0].clientX : 0);
    return Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
  }

  function applyScrub(ratio) {
    const totalDuration = getEffectiveDuration();
    currentTime = ratio * totalDuration;
    updateProgressVisuals();
    updateLyrics(currentTime);
  }

  function commitSeek(ratio) {
    const totalDuration = getEffectiveDuration();
    currentTime = ratio * totalDuration;

    // Apply to real audio element
    if (!isNaN(currentTime) && currentTime >= 0) {
      try {
        audio.currentTime = currentTime;
      } catch (err) {
        console.warn("Audio seek exception:", err);
      }
    }

    lastFrameTime = performance.now();
    updateProgressVisuals();
    updateLyrics(currentTime);
  }

  function setupSeekerEvents() {
    seekerContainer.addEventListener('pointerdown', (e) => {
      isScrubbing = true;
      seekerContainer.classList.add('scrubbing');
      try { seekerContainer.setPointerCapture(e.pointerId); } catch(err) {}

      const ratio = getSeekRatio(e);
      applyScrub(ratio);

      function onPointerMove(ev) {
        if (isScrubbing) {
          const r = getSeekRatio(ev);
          applyScrub(r);
        }
      }

      function onPointerUp(ev) {
        if (isScrubbing) {
          isScrubbing = false;
          seekerContainer.classList.remove('scrubbing');
          const r = getSeekRatio(ev);
          commitSeek(r);

          try { seekerContainer.releasePointerCapture(ev.pointerId); } catch(err) {}
          window.removeEventListener('pointermove', onPointerMove);
          window.removeEventListener('pointerup', onPointerUp);
          window.removeEventListener('pointercancel', onPointerUp);
        }
      }

      window.addEventListener('pointermove', onPointerMove);
      window.addEventListener('pointerup', onPointerUp);
      window.addEventListener('pointercancel', onPointerUp);
    });

    // Direct click handler fallback
    seekerContainer.addEventListener('click', (e) => {
      const r = getSeekRatio(e);
      commitSeek(r);
    });
  }

  // =========================================================
  // 18. 3D PERSPECTIVE TILT
  // =========================================================
  function setup3DTilt() {
    if (!stage || !playerPill) return;

    stage.addEventListener('mousemove', (e) => {
      const rect = playerPill.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;

      const rotX = -(y / (rect.height / 2)) * 8.0;
      const rotY = (x / (rect.width / 2)) * 8.0;

      playerPill.style.transform = `rotateX(${rotX.toFixed(2)}deg) rotateY(${rotY.toFixed(2)}deg)`;
    });

    stage.addEventListener('mouseleave', () => {
      playerPill.style.transform = 'rotateX(0deg) rotateY(0deg)';
    });
  }

  // =========================================================
  // 19. FLOATING MUSICAL NOTE PARTICLES
  // =========================================================
  function setupMusicalNotes() {
    const notes = ['♪', '♫', '♬', '♩', '🎶', '✨'];
    const colors = ['#00d9ff', '#fa4059', '#ff7aa2', '#8b5cf6', '#38ef7d', '#ffd166'];

    function spawnBubble(x, y) {
      const bubble = document.createElement('span');
      bubble.className = 'floating-music-bubble';
      bubble.textContent = notes[Math.floor(Math.random() * notes.length)];

      const color = colors[Math.floor(Math.random() * colors.length)];
      bubble.style.color = color;
      bubble.style.textShadow = `0 0 10px ${color}, 0 0 20px ${color}`;

      const dx = (Math.random() - 0.5) * 80;
      const dy = -45 - Math.random() * 45;
      const rot = (Math.random() - 0.5) * 50;

      bubble.style.setProperty('--dx', `${dx}px`);
      bubble.style.setProperty('--dy', `${dy}px`);
      bubble.style.setProperty('--rot', `${rot}deg`);
      bubble.style.left = `${x}px`;
      bubble.style.top = `${y}px`;

      const noteHost = stage.closest('.player-stage') || document.body;
      noteHost.appendChild(bubble);
      setTimeout(() => bubble.remove(), 1100);
    }

    // Notes are scoped to the player stage. On the standalone page the stage
    // fills the viewport, but on the landing page a document-level listener
    // would spray notes over every nav link and download button.
    const noteRoot = stage.closest('.player-stage') || document;
    noteRoot.addEventListener('click', (e) => {
      if (e.target && e.target.closest && (e.target.closest('.mooziac-player') || e.target.closest('.floating-lyrics-bar'))) {
        return;
      }
      const count = 3 + Math.floor(Math.random() * 2);
      for (let i = 0; i < count; i++) {
        setTimeout(() => {
          spawnBubble(e.clientX + (Math.random() - 0.5) * 16, e.clientY + (Math.random() - 0.5) * 16);
        }, i * 65);
      }
    });
  }

  // =========================================================
  // 20. ATTACH ALL EVENT LISTENERS
  // =========================================================
  function setupEventListeners() {
    // Playback buttons
    btnPlay.addEventListener('click', togglePlayback);
    btnPrev.addEventListener('click', prevTrack);
    btnNext.addEventListener('click', nextTrack);
    btnLike.addEventListener('click', toggleLike);
    btnRepeat.addEventListener('click', toggleRepeat);
    btnDownload.addEventListener('click', handleDownload);
    btnFullscreen.addEventListener('click', () => {
      showToast("Opened Browser View");
    });

    // Audio element metadata & time update events
    audio.addEventListener('loadedmetadata', () => {
      if (audio.duration && !isNaN(audio.duration)) {
        TRACKS[currentTrackIdx].duration = audio.duration;
      }
      updateProgressVisuals();
    });

    audio.addEventListener('timeupdate', () => {
      if (!isScrubbing) {
        currentTime = audio.currentTime;
      }
    });

    audio.addEventListener('ended', () => {
      if (repeatMode === 2) {
        audio.currentTime = 0;
        audio.play().catch(() => {});
      } else {
        nextTrack();
      }
    });

    audio.addEventListener('error', () => {
      console.warn("Audio load error, trying backup stream...");
      const t = TRACKS[currentTrackIdx];
      if (t.audioBackup && audio.src !== t.audioBackup) {
        audio.src = t.audioBackup;
        audio.load();
        if (isPlaying) audio.play().catch(() => {});
      }
    });

    // Expandable Search
    btnSearch.addEventListener('click', toggleSearch);
    searchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        handleSearchSubmit();
      } else if (e.key === 'Escape') {
        collapseSearch();
      }
    });
    searchInput.addEventListener('input', () => {
      searchClearBtn.style.display = searchInput.value ? 'flex' : 'none';
    });
    searchClearBtn.addEventListener('click', () => {
      searchInput.value = '';
      searchClearBtn.style.display = 'none';
      searchInput.focus();
    });

    // Drawers
    btnSettings.addEventListener('click', toggleSettings);
    btnPlaylist.addEventListener('click', togglePlaylist);

    // Lyrics Bar Interaction
    if (lyricsBar) {
      lyricsBar.addEventListener('click', () => {
        showToast(`♫ Lyrics: "${lyricLine.textContent}"`);
      });
    }

    // Settings rows
    $('rowThemes').addEventListener('click', cycleTheme);
    $('rowProgressStyle').addEventListener('click', cycleProgressStyle);

    // Feature Toggles (Loudness, Gestures, Lyrics, Discord)
    ['toggleLoudness', 'toggleGestures', 'toggleLyrics', 'toggleDiscord'].forEach((id) => {
      const el = $(id);
      if (el) {
        el.addEventListener('click', (e) => {
          e.stopPropagation();
          el.classList.toggle('on');
          const isToggledOn = el.classList.contains('on');

          if (id === 'toggleLyrics') {
            isLyricsEnabled = isToggledOn;
            syncLyricsToggle();
          }

          const name = el.closest('.feature-row').querySelector('.feature-title').textContent;
          showToast(`${name}: ${isToggledOn ? 'On' : 'Off'}`);
        });
      }
    });

    // Library Tabs
    document.querySelectorAll('.lib-tab').forEach((tab) => {
      tab.addEventListener('click', () => {
        document.querySelectorAll('.lib-tab').forEach((t) => t.classList.remove('active'));
        tab.classList.add('active');
        currentTab = tab.dataset.tab;
        const placeholders = {
          playlists: "Search your playlists…",
          liked: "Search liked songs…",
          downloads: "Search downloaded tracks…",
          history: "Search listening history…"
        };
        libSearchInput.placeholder = placeholders[currentTab] || "Search your library…";
        renderLibrary();
      });
    });

    libSearchInput.addEventListener('input', renderLibrary);
    $('btnLibPlayAll').addEventListener('click', () => {
      showToast("Playing all library tracks");
      loadTrack(0);
      startPlayback();
    });
    $('btnLibShuffle').addEventListener('click', playRandomTrack);
    $('btnCreatePlaylist').addEventListener('click', () => {
      showToast("Create New Playlist");
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) {
        return;
      }
      if (e.code === 'Space') {
        e.preventDefault();
        togglePlayback();
      } else if (e.code === 'ArrowRight') {
        e.preventDefault();
        nextTrack();
      } else if (e.code === 'ArrowLeft') {
        e.preventDefault();
        prevTrack();
      } else if (e.key === 'l' || e.key === 'L') {
        toggleLike();
      } else if (e.key === 'r' || e.key === 'R') {
        toggleRepeat();
      } else if (e.key === 's' || e.key === 'S') {
        playRandomTrack();
      } else if (e.key === '/') {
        e.preventDefault();
        expandSearch();
      } else if (e.key === 'Escape') {
        collapseSearch();
        if (isSettingsOpen) toggleSettings();
        if (isPlaylistOpen) togglePlaylist();
      }
    });
  }

  // =========================================================
  // 21. BOOTSTRAP INITIALIZATION
  // =========================================================

  // The lyrics switch only ever reacted to clicks, so the initial state came
  // from markup alone. Derive it from isLyricsEnabled instead so the two
  // cannot drift apart.
  function syncLyricsToggle() {
    const el = $('toggleLyrics');
    if (el) {
      el.classList.toggle('on', isLyricsEnabled);
      el.setAttribute('aria-checked', isLyricsEnabled ? 'true' : 'false');
    }
    if (lyricsBar) {
      lyricsBar.classList.toggle('lyrics-hidden', !isLyricsEnabled);
    }
  }

  function init() {
    injectIcons();
    buildSeekers();
    applyTheme(DEFAULT_THEME_IDX, true);
    loadTrack(currentTrackIdx);
    setupSeekerEvents();
    setup3DTilt();
    setupMusicalNotes();
    setupEventListeners();
    syncLyricsToggle();

    revealSettingsOnFirstInteraction();

    // Check if embedded in an iframe (such as MacBook 3D display)
    if (window.self !== window.top) {
      document.documentElement.classList.add('embedded-mode');
      document.body.classList.add('embedded-mode');
    }

    // =========================================================
    // PUBLIC API — lets the surrounding landing page drive the
    // player without reaching into these internals.
    // =========================================================
    window.MooziacPlayer = {
      THEMES: THEMES.map((t) => t.key),
      PROGRESS_STYLES: PROGRESS_STYLES.map((s) => s.key),

      getTheme() { return THEMES[currentThemeIdx].key; },
      getProgressStyle() { return PROGRESS_STYLES[currentProgressStyleIdx].key; },

      setTheme(key, silent) {
        const idx = THEMES.findIndex((t) => t.key === key);
        if (idx === -1) return false;
        applyTheme(idx, silent);
        return true;
      },

      setProgressStyle(key, silent) {
        const idx = PROGRESS_STYLES.findIndex((s) => s.key === key);
        if (idx === -1) return false;
        applyProgressStyle(idx, silent);
        return true;
      },

      play: startPlayback,
      pause: pausePlayback,
      toggle: togglePlayback,
      next: nextTrack,
      prev: prevTrack,
    };
  }

  // Cross-frame API for embedded MacBook integration
  window.addEventListener('message', (e) => {
    if (!e.data) return;
    if (e.data.action === 'play') {
      startPlayback();
    } else if (e.data.action === 'pause') {
      pausePlayback();
    } else if (e.data.action === 'toggle') {
      togglePlayback();
    } else if (e.data.action === 'next') {
      nextTrack();
    } else if (e.data.action === 'prev') {
      prevTrack();
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
