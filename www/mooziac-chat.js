/**
 * =========================================================
 * MOOZIAC LIQUID GLASS AI SUPPORT WIDGET (mooziac-chat.js)
 * 100% Autonomous AI Support Assistant (Powered by Mooziac Knowledge Base & Llama 3.2)
 * =========================================================
 */

(function() {
  'use strict';

  const API_BASE = (window.location.protocol === 'file:' || window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? (window.location.port === '8080' ? '' : 'http://localhost:8080')
    : '';

  // State
  let isOpen = false;
  let toastTimer = null;
  let pendingAttachments = [];

  // Rate Limiting
  const MSG_COOLDOWN_SEC = 2;
  let isCooldownActive = false;
  let cooldownRemaining = 0;

  // Ground-Truth Quick Topics
  const QUICK_TOPICS = {
    gestures: {
      label: "🖐️ Trackpad Edge Volume & Corners",
      reply: "**Trackpad Edge Volume & Gestures:**\n• **Volume:** Slide 1 finger along the far right edge of your trackpad (top 30% area, requires 3mm movement to engage).\n• **Bottom-Right Corner:** 2 taps = Next Track; 3 taps = Previous Track.\n• **Bottom-Left Corner:** 2 taps = Play/Pause; 3 taps = Toggle Lyrics HUD.\n\n*Zero accessibility permissions needed! Works with built-in and Magic Trackpads.*"
    },
    gatekeeper: {
      label: "⚠️ App Is Damaged / Gatekeeper",
      reply: "**Fixing 'Mooziac is damaged' or unverified developer:**\n1. Open **Terminal** on your Mac.\n2. Run: `xattr -cr /Applications/Mooziac.app`\n3. Or go to **System Settings** → **Privacy & Security** → click **Open Anyway**."
    },
    lyrics: {
      label: "🎤 Synced Lyrics & Notch HUD",
      reply: "**Synchronized Lyrics:**\n• Press **⌘ + Shift + L** to toggle the Centered Lyrics HUD docked right under your MacBook notch.\n• Works automatically with YouTube Music & LRCLib.\n• For local tracks, drop a matching `.lrc` file beside your song (e.g. `song.flac` and `song.lrc`)."
    },
    downloads: {
      label: "⬇️ Downloads & Offline Music",
      reply: "**Offline Downloads:**\n• Downloaded songs are stored in: `~/Music/Mooziac/`.\n• Mooziac auto-installs `yt-dlp` helper in Application Support—no Homebrew needed!\n• You can change the download folder in Mooziac Settings → Downloads."
    },
    formats: {
      label: "🎵 Audio Formats & Lossless",
      reply: "**Supported Audio Formats:**\n• Native support for **FLAC** (bit-perfect up to 24-bit/192kHz), **MP3**, **WAV**, **AAC**, **M4A**, **AIFF**, **OGG**, and **OPUS**.\n• Includes **-14 LUFS** Loudness Normalization with smooth 250ms cosine easing."
    }
  };

  // Visitor Session & Email Gate
  let sessionId = localStorage.getItem('mzc_session_id');
  if (!sessionId) {
    sessionId = `sess_${Math.floor(1000 + Math.random() * 9000)}`;
    localStorage.setItem('mzc_session_id', sessionId);
  }

  let userEmail = localStorage.getItem('mzc_user_email') || '';
  let userMessageCount = parseInt(localStorage.getItem('mzc_msg_count') || '0', 10);

  // Conversation history for context
  let conversationHistory = [];

  function renderEmailConnectCard() {
    if (document.getElementById('mzc-email-gate')) return;
    const feed = document.getElementById('mzc-messages');
    if (!feed) return;

    const gate = document.createElement('div');
    gate.className = 'mzc-msg bot';
    gate.id = 'mzc-email-gate';
    gate.innerHTML = `
      <div class="mzc-bubble" style="background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.18); border-radius: 12px; padding: 12px; max-width: 90%;">
        <p style="margin: 0 0 8px 0; font-size: 13px; font-weight: 600; color: #fff;">Stay Connected with Support 💌</p>
        <p style="margin: 0 0 10px 0; font-size: 12px; color: rgba(255, 255, 255, 0.8);">Please share your email address so our developer can follow up with you and continue our conversation:</p>
        <form id="mzc-email-gate-form" style="display: flex; gap: 6px; margin: 0;">
          <input type="email" id="mzc-gate-email" placeholder="name@example.com" required style="flex: 1; padding: 7px 10px; border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.2); background: rgba(0, 0, 0, 0.4); color: #fff; font-size: 12px; outline: none;">
          <button type="submit" style="padding: 7px 12px; border-radius: 8px; border: none; background: #0071E3; color: #fff; font-weight: 600; font-size: 12px; cursor: pointer;">Connect</button>
        </form>
      </div>
    `;
    feed.appendChild(gate);
    scrollMessages();

    const form = document.getElementById('mzc-email-gate-form');
    if (form) {
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        const val = document.getElementById('mzc-gate-email')?.value.trim();
        if (!val || !val.includes('@')) return;
        userEmail = val;
        localStorage.setItem('mzc_user_email', userEmail);

        // Forward lead to Discord Webhook via /api/feedback
        fetch(`${API_BASE}/api/feedback`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type: 'CONNECT',
            name: 'Connected Chat User',
            email: userEmail,
            session_id: sessionId,
            message: `User connected their email in chat widget (session: ${sessionId}).`
          })
        }).catch(() => {});

        gate.remove();
        appendMsg(`Thank you! Your email (${userEmail}) is connected. You can continue asking questions! 🚀`, 'bot');
        const input = document.getElementById('mzc-input');
        if (input) {
          input.disabled = false;
          input.placeholder = "Ask Mooziac AI anything...";
          input.focus();
        }
      });
    }

    const input = document.getElementById('mzc-input');
    if (input) {
      input.disabled = true;
      input.placeholder = "Please share your email above to continue...";
    }
  }

  // Mount Clean Liquid Glass UI
  function mountWidget() {
    if (document.getElementById('mzc-widget-root')) return;

    const root = document.createElement('div');
    root.id = 'mzc-widget-root';
    root.className = 'mzc-widget-root';
    root.innerHTML = `
      <!-- Launcher Pill -->
      <div id="mzc-launcher" class="mzc-launcher">
        <div class="mzc-launcher-icon">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
          </svg>
        </div>
        <span class="mzc-launcher-label">AI Support</span>
      </div>

      <!-- Main Glass Window -->
      <div id="mzc-window" class="mzc-window" style="display: none;">
        
        <!-- Toast Notification -->
        <div id="mzc-toast" class="mzc-toast" style="display: none;"></div>

        <!-- Header -->
        <div class="mzc-header">
          <div class="mzc-profile">
            <div class="mzc-avatar">
              🎵
              <span id="mzc-dot" class="mzc-online-dot"></span>
            </div>
            <div class="mzc-profile-info">
              <span class="mzc-name">Mooziac AI Support</span>
              <span id="mzc-status" class="mzc-status">⚡ Online 24/7 • Instant Answers</span>
            </div>
          </div>

          <div class="mzc-header-actions">
            <button id="mzc-close-btn" class="mzc-action-btn" title="Close">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
            </button>
          </div>
        </div>

        <!-- Clean Messages Feed -->
        <div id="mzc-messages" class="mzc-messages">
          <div class="mzc-msg bot">
            <div class="mzc-bubble">
              <p><strong>Welcome to Mooziac AI Support! 👋</strong></p>
              <p>I can answer any question about gestures, downloads, lyrics, formats, or macOS issues. Ask anything or pick a topic:</p>
              <div class="mzc-options-group" id="mzc-initial-options">
                <button class="mzc-option-pill" data-key="gestures">🖐️ Trackpad Edge Volume</button>
                <button class="mzc-option-pill" data-key="gatekeeper">⚠️ App Is Damaged Fix</button>
                <button class="mzc-option-pill" data-key="lyrics">🎤 Synced Lyrics & Notch HUD</button>
                <button class="mzc-option-pill" data-key="downloads">⬇️ Downloads & Offline Music</button>
                <button class="mzc-option-pill" data-key="formats">🎵 Supported Formats</button>
              </div>
            </div>
            <span class="mzc-time">Just now</span>
          </div>
        </div>

        <!-- Typing Indicator -->
        <div id="mzc-typing" class="mzc-typing" style="display: none;">
          <div class="mzc-typing-dot"></div>
          <div class="mzc-typing-dot"></div>
          <div class="mzc-typing-dot"></div>
        </div>

        <!-- Attachment Preview Strip -->
        <div id="mzc-preview-bar" class="mzc-preview-bar" style="display: none;"></div>

        <!-- Input Bar -->
        <div class="mzc-input-bar">
          <button id="mzc-attach-btn" class="mzc-attach-btn" title="Attach screenshot (⌘V)">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"></path>
            </svg>
          </button>
          <input type="file" id="mzc-file-input" accept="image/*,.txt,.log" multiple style="display: none;">

          <input type="text" id="mzc-hp" name="mzc_hp" style="display:none !important;" tabindex="-1" autocomplete="off">
          <input type="text" id="mzc-input" class="mzc-input-field" placeholder="Ask Mooziac AI anything..." maxlength="500" autocomplete="off">

          <button id="mzc-send" class="mzc-send-btn" title="Send (Enter)">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(root);
    setupEvents();
    bindOptionPills();
  }

  function setupEvents() {
    const launcher = document.getElementById('mzc-launcher');
    const closeBtn = document.getElementById('mzc-close-btn');
    const input = document.getElementById('mzc-input');
    const sendBtn = document.getElementById('mzc-send');
    const attachBtn = document.getElementById('mzc-attach-btn');
    const fileInput = document.getElementById('mzc-file-input');

    if (launcher) launcher.addEventListener('click', toggleWindow);
    if (closeBtn) closeBtn.addEventListener('click', closeWindow);

    if (input) {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          handleSend();
        }
      });

      // Handle Command+V / Ctrl+V screenshot pasting
      input.addEventListener('paste', handlePaste);
    }

    if (sendBtn) sendBtn.addEventListener('click', handleSend);

    if (attachBtn && fileInput) {
      attachBtn.addEventListener('click', () => fileInput.click());
      fileInput.addEventListener('change', handleFileSelect);
    }
  }

  function bindOptionPills() {
    const pills = document.querySelectorAll('.mzc-option-pill');
    pills.forEach(pill => {
      pill.addEventListener('click', (e) => {
        const key = e.currentTarget.getAttribute('data-key');
        if (key && QUICK_TOPICS[key]) {
          handleTopicSelection(key);
        }
      });
    });
  }

  function handleTopicSelection(key) {
    const topic = QUICK_TOPICS[key];
    if (!topic) return;

    // 1. Post user selection
    appendMsg(topic.label, 'user');

    // 2. Post instant solution with slight typing animation
    showTyping(true);
    setTimeout(() => {
      showTyping(false);
      appendMsg(topic.reply, 'bot');
    }, 250);
  }

  function handlePaste(e) {
    const clipboardData = e.clipboardData || window.clipboardData;
    if (!clipboardData) return;

    const items = clipboardData.items;
    if (!items) return;

    for (let i = 0; i < items.length; i++) {
      if (items[i].type.indexOf('image') !== -1) {
        e.preventDefault();
        const file = items[i].getAsFile();
        if (file) {
          processFile(file, `screenshot_${Date.now()}.png`);
        }
        break;
      }
    }
  }

  function handleFileSelect(e) {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    for (let i = 0; i < files.length; i++) {
      processFile(files[i]);
    }
    e.target.value = '';
  }

  function processFile(file, customName = null) {
    if (file.size > 8 * 1024 * 1024) {
      showToast('⚠️ File exceeds 8MB limit.');
      return;
    }

    const filename = customName || file.name;
    const reader = new FileReader();

    reader.onload = function(e) {
      const dataUrl = e.target.result;
      if (file.type.startsWith('image/')) {
        pendingAttachments.push({
          name: filename,
          data: dataUrl,
          isImage: true
        });
      } else {
        pendingAttachments.push({
          name: filename,
          data: dataUrl,
          isImage: false
        });
      }
      renderAttachmentPreviews();
    };
    reader.readAsDataURL(file);
  }

  function renderAttachmentPreviews() {
    const bar = document.getElementById('mzc-preview-bar');
    if (!bar) return;

    if (pendingAttachments.length === 0) {
      bar.style.display = 'none';
      bar.innerHTML = '';
      return;
    }

    bar.style.display = 'flex';
    bar.innerHTML = pendingAttachments.map((att, index) => `
      <div class="mzc-preview-chip">
        ${att.isImage ? `<img src="${att.data}" class="mzc-chip-thumb" alt="thumb">` : `<span class="mzc-chip-icon">📄</span>`}
        <span class="mzc-chip-name">${escapeHtml(att.name)}</span>
        <button class="mzc-chip-remove" onclick="window.__mzc_remove_att(${index})">×</button>
      </div>
    `).join('');
  }

  window.__mzc_remove_att = function(index) {
    pendingAttachments.splice(index, 1);
    renderAttachmentPreviews();
  };

  function setWindowState(open) {
    isOpen = open;
    const root = document.getElementById('mzc-widget-root');
    const win = document.getElementById('mzc-window');
    const launcher = document.getElementById('mzc-launcher');
    const input = document.getElementById('mzc-input');

    if (!root) return;

    if (isOpen) {
      root.classList.add('mzc-is-open');
      if (win) win.style.display = 'flex';
      if (launcher) launcher.style.display = 'none';

      if (window.innerWidth <= 640) {
        document.body.classList.add('mzc-chat-locked');
      } else {
        if (input) input.focus();
      }
      scrollMessages();
    } else {
      root.classList.remove('mzc-is-open');
      if (win) win.style.display = 'none';
      if (launcher) launcher.style.display = 'flex';
      document.body.classList.remove('mzc-chat-locked');
    }
  }

  function toggleWindow() {
    setWindowState(!isOpen);
  }

  function closeWindow() {
    setWindowState(false);
  }

  function showToast(text) {
    const toast = document.getElementById('mzc-toast');
    if (!toast) return;

    if (toastTimer) clearTimeout(toastTimer);
    toast.textContent = text;
    toast.style.display = 'flex';

    toastTimer = setTimeout(() => {
      toast.style.display = 'none';
    }, 2500);
  }

  async function handleSend() {
    if (isCooldownActive) {
      showToast(`⏳ Please wait ${cooldownRemaining}s`);
      return;
    }

    if (userMessageCount >= 10 && !userEmail) {
      renderEmailConnectCard();
      return;
    }

    const input = document.getElementById('mzc-input');
    const query = input.value.trim();
    const attachmentsToSend = [...pendingAttachments];

    if (!query && attachmentsToSend.length === 0) return;

    userMessageCount++;
    localStorage.setItem('mzc_msg_count', userMessageCount.toString());

    // Start 2s cooldown
    startCooldownTimer();

    // Append to UI immediately
    appendMsg(query, 'user', attachmentsToSend);
    input.value = '';
    pendingAttachments = [];
    renderAttachmentPreviews();

    // Show AI typing indicator
    showTyping(true);

    try {
      const chatRes = await fetch(`${API_BASE}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: query,
          session_id: sessionId,
          history: conversationHistory,
          email: userEmail,
          mzc_hp: document.getElementById('mzc-hp')?.value || ''
        })
      });

      showTyping(false);

      if (chatRes.ok) {
        const chatData = await chatRes.json();
        if (chatData.requires_email) {
          renderEmailConnectCard();
          return;
        }
        if (chatData && chatData.reply) {
          appendMsg(chatData.reply, 'bot');
          // Add to context history
          conversationHistory.push({ role: 'user', content: query });
          conversationHistory.push({ role: 'assistant', content: chatData.reply });

          // Prompt email after 10th message if not yet connected
          if (userMessageCount >= 10 && !userEmail) {
            setTimeout(() => {
              renderEmailConnectCard();
            }, 600);
          }
        } else {
          appendMsg("Sorry, I couldn't generate a response right now. Please try again.", 'bot');
        }
      } else if (chatRes.status === 429) {
        const errData = await chatRes.json().catch(() => ({}));
        appendMsg(errData.reply || "⏳ You're sending questions too quickly. Please wait a minute.", 'bot');
      } else {
        appendMsg("I'm having trouble reaching the support service. Please check your connection or visit [GitHub Issues](https://github.com/shirkeharsh/mooziac/issues).", 'bot');
      }
    } catch (err) {
      showTyping(false);
      appendMsg("Network connection error. If you are running locally, make sure the local server is running at `http://localhost:8080`.", 'bot');
    }
  }

  function startCooldownTimer() {
    isCooldownActive = true;
    cooldownRemaining = MSG_COOLDOWN_SEC;
    const sendBtn = document.getElementById('mzc-send');
    if (!sendBtn) return;
    const originalSvg = sendBtn.innerHTML;

    sendBtn.style.opacity = '0.5';
    sendBtn.style.cursor = 'not-allowed';
    sendBtn.innerHTML = `<span style="font-size: 10px; font-weight: 700; color: #fff;">${cooldownRemaining}s</span>`;

    const timer = setInterval(() => {
      cooldownRemaining--;
      if (cooldownRemaining > 0) {
        sendBtn.innerHTML = `<span style="font-size: 10px; font-weight: 700; color: #fff;">${cooldownRemaining}s</span>`;
      } else {
        clearInterval(timer);
        isCooldownActive = false;
        sendBtn.style.opacity = '1';
        sendBtn.style.cursor = 'pointer';
        sendBtn.innerHTML = originalSvg;
      }
    }, 1000);
  }

  function appendMsg(text, sender, attachments = []) {
    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const container = document.getElementById('mzc-messages');
    const msg = document.createElement('div');
    msg.className = `mzc-msg ${sender}`;

    let imgHtml = '';
    if (attachments && attachments.length > 0) {
      attachments.forEach(att => {
        if (att.isImage) {
          imgHtml += `<img src="${att.data}" class="mzc-bubble-img" alt="${escapeHtml(att.name)}" onclick="window.open('${att.data}', '_blank')">`;
        } else {
          imgHtml += `<div style="font-size: 11px; padding: 4px; background: rgba(0,0,0,0.25); border-radius: 4px; margin-top: 4px;">📎 ${escapeHtml(att.name)}</div>`;
        }
      });
    }

    msg.innerHTML = `
      <div class="mzc-bubble">
        ${text ? formatMarkdown(text) : ''}
        ${imgHtml}
      </div>
      <span class="mzc-time">${time}</span>
    `;

    container.appendChild(msg);
    scrollMessages();
  }

  function formatMarkdown(text) {
    let html = escapeHtml(text);
    html = html.replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>');
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener" style="color:#0071e3;text-decoration:underline;">$1</a>');
    html = html.replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br>');
    return `<p>${html}</p>`;
  }

  function escapeHtml(s) {
    const d = document.createElement('div');
    d.textContent = s;
    return d.innerHTML;
  }

  function showTyping(show) {
    const el = document.getElementById('mzc-typing');
    if (el) {
      el.style.display = show ? 'flex' : 'none';
      if (show) scrollMessages();
    }
  }

  function scrollMessages() {
    const el = document.getElementById('mzc-messages');
    if (el) el.scrollTop = el.scrollHeight;
  }

  // Self-initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', mountWidget);
  } else {
    mountWidget();
  }
})();
