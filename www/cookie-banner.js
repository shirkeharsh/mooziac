/* =========================================================
   MOOZIAC — LIQUID GLASS PRIVACY & COOKIE CONSENT BANNER
   ========================================================= */

(function() {
  const CONSENT_KEY = 'mzc_privacy_consent';

  function initCookieBanner() {
    if (localStorage.getItem(CONSENT_KEY)) return;

    const banner = document.createElement('div');
    banner.className = 'mzc-cookie-banner';
    banner.setAttribute('role', 'region');
    banner.setAttribute('aria-label', 'Privacy & Cookies');
    banner.innerHTML = `
      <div class="mzc-cookie-content">
        <span class="mzc-cookie-icon" aria-hidden="true">🍪</span>
        <div class="mzc-cookie-text">
          <strong>Privacy First:</strong> Mooziac operates 100% locally on your Mac with zero ad tracking. We only use essential local storage for your preferences & live support. <a href="privacy.html" class="mzc-cookie-link">Privacy Policy</a>
        </div>
      </div>
      <div class="mzc-cookie-actions">
        <button class="mzc-cookie-btn mzc-cookie-dismiss" id="mzc-cookie-decline">Essential Only</button>
        <button class="mzc-cookie-btn mzc-cookie-accept" id="mzc-cookie-accept">Accept All</button>
      </div>
    `;

    document.body.appendChild(banner);

    // Smooth reveal after 800ms
    setTimeout(() => {
      banner.classList.add('mzc-cookie-visible');
      document.body.classList.add('mzc-has-cookie-banner');
    }, 800);

    function dismiss(val) {
      localStorage.setItem(CONSENT_KEY, val);
      banner.classList.remove('mzc-cookie-visible');
      document.body.classList.remove('mzc-has-cookie-banner');
      setTimeout(() => banner.remove(), 500);
    }

    document.getElementById('mzc-cookie-accept')?.addEventListener('click', () => dismiss('accepted'));
    document.getElementById('mzc-cookie-decline')?.addEventListener('click', () => dismiss('essential'));
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initCookieBanner);
  } else {
    initCookieBanner();
  }
})();
