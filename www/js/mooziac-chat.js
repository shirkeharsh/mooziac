/**
 * =========================================================
 * MOOZIAC LIQUID GLASS AI SUPPORT WIDGET (mooziac-chat.js)
 * 100% Autonomous AI Support Assistant (Powered by Mooziac Knowledge Base & Llama 3.2)
 * Brand: Ask Minimoo 🤖
 * Pure Text Support - Clean, Fast & Minimalist
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

  // Rate Limiting
  const MSG_COOLDOWN_SEC = 2;
  let isCooldownActive = false;
  let cooldownRemaining = 0;

  // Ground-Truth Quick Topics
  const QUICK_TOPICS = {
    human: {
      label: "👤 Connect to Human / Agent",
      reply: "I'd be glad to connect you directly with our developer (Harsh Shirke). Please enter your email below to connect:"
    },
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

  // ==========================================
  // Email Connect Card (Human Lead Gate)
  // ==========================================
  function renderEmailConnectCard() {
    if (document.getElementById('mzc-email-gate')) return;
    const feed = document.getElementById('mzc-messages');
    if (!feed) return;

    const gate = document.createElement('div');
    gate.className = 'mzc-msg bot';
    gate.id = 'mzc-email-gate';
    gate.innerHTML = `
      <div class="mzc-bubble mzc-connect-bubble">
        <p class="mzc-connect-title">Connect to Human Agent / Developer 👤</p>
        <p class="mzc-connect-desc">Enter your email so our developer (Harsh Shirke) can reach out to you directly and assist you:</p>
        <form id="mzc-email-gate-form" class="mzc-connect-form">
          <input type="email" id="mzc-gate-email" class="mzc-connect-input" placeholder="your@email.com" required autocomplete="email">
          <button type="submit" class="mzc-connect-btn">Connect</button>
        </form>
      </div>
    `;
    feed.appendChild(gate);
    scrollMessages();

    // Prompt input bar placeholder
    const input = document.getElementById('mzc-input');
    if (input) {
      input.placeholder = "Enter your email above or type here...";
    }

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
            message: `User requested to connect with human agent / reached chat limit in session ${sessionId}.`
          })
        }).catch(() => {});

        gate.remove();
        appendMsg(userEmail, 'user');
        showTyping(true);
        setTimeout(() => {
          showTyping(false);
          appendMsg(`Thank you! Your email (**${userEmail}**) has been connected with our developer (Harsh Shirke). He has received your request and will reach out to you directly.\n\nIn the meantime, feel free to ask Minimoo anything about Mooziac!`, 'bot');
        }, 350);

        if (input) {
          input.disabled = false;
          input.placeholder = "Ask Minimoo anything...";
          input.focus();
        }
        const sendBtn = document.getElementById('mzc-send');
        if (sendBtn) {
          sendBtn.style.opacity = '1';
          sendBtn.style.cursor = 'pointer';
        }
      });
    }
  }

  // ==========================================
  // Mount Clean Liquid Glass UI
  // ==========================================
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
        <span class="mzc-launcher-label">Ask Minimoo</span>
      </div>

      <!-- Main Glass Window -->
      <div id="mzc-window" class="mzc-window" style="display: none;">
        
        <!-- Toast Notification -->
        <div id="mzc-toast" class="mzc-toast" style="display: none;"></div>

        <!-- Header -->
        <div class="mzc-header">
          <div class="mzc-profile">
            <div class="mzc-avatar">
              🤖
              <span id="mzc-dot" class="mzc-online-dot"></span>
            </div>
            <div class="mzc-profile-info">
              <span class="mzc-name">Ask Minimoo</span>
              <span id="mzc-status" class="mzc-status">Minimoo • Built for Mooziac Support</span>
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
              <p><strong>Hi, I'm Minimoo! 🤖</strong></p>
              <p>I was built exclusively to assist you with Mooziac. Ask anything about gestures, downloads, lyrics, formats, or macOS fixes:</p>
              <div class="mzc-options-group" id="mzc-initial-options">
                <button class="mzc-option-pill" data-key="gestures">🖐️ Trackpad Edge Volume</button>
                <button class="mzc-option-pill" data-key="gatekeeper">⚠️ App Is Damaged Fix</button>
                <button class="mzc-option-pill" data-key="lyrics">🎤 Synced Lyrics & Notch HUD</button>
                <button class="mzc-option-pill" data-key="downloads">⬇️ Downloads & Offline Music</button>
                <button class="mzc-option-pill" data-key="formats">🎵 Supported Formats</button>
                <button class="mzc-option-pill" data-key="human">👤 Connect to Human / Agent</button>
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

        <!-- Input Bar (Pure Text Only) -->
        <div class="mzc-input-bar">
          <input type="text" id="mzc-hp" name="mzc_hp" style="display:none !important;" tabindex="-1" autocomplete="off">
          <input type="text" id="mzc-input" class="mzc-input-field" placeholder="Ask Minimoo anything..." maxlength="500" autocomplete="off">
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

    // Enforce 10-message gate on initial load / reload
    if (userMessageCount >= 10 && !userEmail) {
      setTimeout(renderEmailConnectCard, 300);
      const input = document.getElementById('mzc-input');
      const sendBtn = document.getElementById('mzc-send');
      if (input) {
        input.disabled = true;
        input.placeholder = "Please enter your email above to connect...";
      }
      if (sendBtn) {
        sendBtn.style.opacity = '0.5';
        sendBtn.style.cursor = 'not-allowed';
      }
    }
  }

  function setupEvents() {
    const launcher = document.getElementById('mzc-launcher');
    const closeBtn = document.getElementById('mzc-close-btn');
    const input = document.getElementById('mzc-input');
    const sendBtn = document.getElementById('mzc-send');

    if (launcher) launcher.addEventListener('click', toggleWindow);
    if (closeBtn) closeBtn.addEventListener('click', closeWindow);

    if (input) {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          handleSend();
        }
      });

      input.addEventListener('focus', () => {
        if (window.innerWidth <= 640) {
          setTimeout(() => {
            updateMobileViewport();
            scrollMessages();
          }, 250);
        }
      });
    }

    if (sendBtn) sendBtn.addEventListener('click', handleSend);

    if (window.visualViewport) {
      window.visualViewport.addEventListener('resize', updateMobileViewport);
      window.visualViewport.addEventListener('scroll', updateMobileViewport);
    }

    window.addEventListener('resize', () => {
      if (window.innerWidth > 640 && isOpen) {
        unlockBodyScroll();
        resetMobileViewport();
      } else if (window.innerWidth <= 640 && isOpen) {
        lockBodyScroll();
        updateMobileViewport();
      }
    });
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

    if (key === 'human') {
      appendMsg(topic.label, 'user');
      showTyping(true);
      setTimeout(() => {
        showTyping(false);
        if (userEmail) {
          appendMsg(`You're already connected with email **${userEmail}**! Our developer (Harsh Shirke) has received your request.\n\nIf you want to use a different email or have an urgent question, simply enter your new email or message below:`, 'bot');
        } else {
          appendMsg(topic.reply, 'bot');
        }
        renderEmailConnectCard();
      }, 250);
      return;
    }

    // Enforce 10-message gate strictly on quick topics
    if (userMessageCount >= 10 && !userEmail) {
      showToast("👤 Connect with human agent to continue");
      renderEmailConnectCard();
      return;
    }

    userMessageCount++;
    localStorage.setItem('mzc_msg_count', userMessageCount.toString());

    // 1. Post user selection
    appendMsg(topic.label, 'user');

    // 2. Post instant solution with slight typing animation
    showTyping(true);
    setTimeout(() => {
      showTyping(false);
      appendMsg(topic.reply, 'bot');

      // Check if this reached the 10th message
      if (userMessageCount >= 10 && !userEmail) {
        setTimeout(renderEmailConnectCard, 400);
      }
    }, 250);
  }

  let savedScrollY = 0;

  function lockBodyScroll() {
    savedScrollY = window.scrollY || window.pageYOffset || 0;
    document.body.classList.add('mzc-chat-locked');
    document.body.style.position = 'fixed';
    document.body.style.top = `-${savedScrollY}px`;
    document.body.style.left = '0';
    document.body.style.right = '0';
    document.body.style.width = '100%';
  }

  function unlockBodyScroll() {
    document.body.classList.remove('mzc-chat-locked');
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.left = '';
    document.body.style.right = '';
    document.body.style.width = '';
    window.scrollTo(0, savedScrollY);
  }

  function updateMobileViewport() {
    if (!isOpen || window.innerWidth > 640) return;
    const root = document.getElementById('mzc-widget-root');
    const win = document.getElementById('mzc-window');
    if (!root || !win) return;

    if (window.visualViewport) {
      const vv = window.visualViewport;
      const height = vv.height;
      const offsetTop = vv.offsetTop || 0;

      root.style.height = `${height}px`;
      root.style.top = `${offsetTop}px`;
      win.style.height = `${height}px`;

      // Detect if virtual keyboard is likely raised
      const isKeyboardOpen = height < (window.screen.height * 0.75) && height < (window.innerHeight - 80);
      if (isKeyboardOpen) {
        root.classList.add('mzc-keyboard-open');
      } else {
        root.classList.remove('mzc-keyboard-open');
      }
    }
    scrollMessages();
  }

  function resetMobileViewport() {
    const root = document.getElementById('mzc-widget-root');
    const win = document.getElementById('mzc-window');
    if (root) {
      root.style.height = '';
      root.style.top = '';
      root.classList.remove('mzc-keyboard-open');
    }
    if (win) {
      win.style.height = '';
    }
  }

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
        lockBodyScroll();
        updateMobileViewport();
      } else {
        if (input && !input.disabled) input.focus();
      }
      scrollMessages();
    } else {
      root.classList.remove('mzc-is-open');
      if (win) win.style.display = 'none';
      if (launcher) launcher.style.display = 'flex';

      if (window.innerWidth <= 640) {
        unlockBodyScroll();
        resetMobileViewport();
      }
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
      showToast("👤 Connect with human agent to continue");
      return;
    }

    const input = document.getElementById('mzc-input');
    const query = (input?.value || '').trim();
    if (!query) return;

    // Check if user is entering/updating their email address directly in chat
    const emailMatch = query.match(/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/);
    if (emailMatch) {
      userEmail = emailMatch[0];
      localStorage.setItem('mzc_user_email', userEmail);
      appendMsg(query, 'user');
      input.value = '';

      const gate = document.getElementById('mzc-email-gate');
      if (gate) gate.remove();

      if (input) {
        input.disabled = false;
        input.placeholder = "Ask Minimoo anything...";
      }

      fetch(`${API_BASE}/api/feedback`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'CONNECT',
          name: 'Connected Chat User',
          email: userEmail,
          session_id: sessionId,
          message: `User provided email via chat input in session ${sessionId}.`
        })
      }).catch(() => {});

      showTyping(true);
      setTimeout(() => {
        showTyping(false);
        appendMsg(`Thank you! Your email (**${userEmail}**) has been connected with our developer (Harsh Shirke). He has received your request and will reach out to you directly.\n\nIn the meantime, feel free to ask Minimoo anything about Mooziac!`, 'bot');
      }, 350);
      return;
    }

    // Check if user explicitly asks for human/developer
    if (/\b(human|agent|talk to human|connect me to human|speak to human|real person|developer|support agent|harsh)\b/i.test(query)) {
      appendMsg(query, 'user');
      input.value = '';
      showTyping(true);
      setTimeout(() => {
        showTyping(false);
        if (userEmail) {
          appendMsg(`You're already connected with email **${userEmail}**! Our developer (Harsh Shirke) has received your request.\n\nIf you want to use a different email or have an urgent question, simply enter your new email or message below:`, 'bot');
        } else {
          appendMsg("I'd be glad to connect you directly with our developer (Harsh Shirke). Please enter your email below to connect:", 'bot');
        }
        renderEmailConnectCard();
      }, 300);
      return;
    }

    userMessageCount++;
    localStorage.setItem('mzc_msg_count', userMessageCount.toString());

    // Start 2s cooldown
    startCooldownTimer();

    // Append to UI immediately
    appendMsg(query, 'user');
    input.value = '';

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
          msg_count: userMessageCount,
          email: userEmail,
          mzc_hp: document.getElementById('mzc-hp')?.value || ''
        })
      });

      showTyping(false);

      if (chatRes.ok) {
        const chatData = await chatRes.json();

        if (chatData.connected_email) {
          userEmail = chatData.connected_email;
          localStorage.setItem('mzc_user_email', userEmail);
          const gate = document.getElementById('mzc-email-gate');
          if (gate) gate.remove();
        }

        if (chatData.requires_email) {
          if (chatData.reply) appendMsg(chatData.reply, 'bot');
          renderEmailConnectCard();
          return;
        }

        if (chatData && chatData.reply) {
          appendMsg(chatData.reply, 'bot');
          // Add to context history
          conversationHistory.push({ role: 'user', content: query });
          conversationHistory.push({ role: 'assistant', content: chatData.reply });

          // Gate after 10th message if not yet connected
          if (userMessageCount >= 10 && !userEmail) {
            setTimeout(() => {
              renderEmailConnectCard();
            }, 600);
          }
        } else {
          appendMsg("If you need direct assistance with Mooziac, feel free to enter your email above or check [GitHub Issues](https://github.com/shirkeharsh/mooziac/issues).", 'bot');
        }
      } else if (chatRes.status === 429) {
        const errData = await chatRes.json().catch(() => ({}));
        appendMsg(errData.reply || "⏳ You're sending questions too quickly. Please wait a minute.", 'bot');
      } else {
        const errData = await chatRes.json().catch(() => ({}));
        const errReply = errData.reply || (errData.error ? `⚠️ ${errData.error}` : null) || "For immediate assistance, feel free to submit an issue on [GitHub Issues](https://github.com/shirkeharsh/mooziac/issues) or enter your email above to connect with our developer.";
        appendMsg(errReply, 'bot');
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

  function appendMsg(text, sender) {
    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const container = document.getElementById('mzc-messages');
    const msg = document.createElement('div');
    msg.className = `mzc-msg ${sender}`;

    msg.innerHTML = `
      <div class="mzc-bubble">
        ${text ? formatMarkdown(text) : ''}
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
