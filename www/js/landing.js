/* =========================================================
   MOOZIAC — LANDING PAGE INTERACTION & MOTION
   ========================================================= */

/* Logo image synchronizer across site chrome */
(function() {
  const logo = document.getElementById('artworkLogo');
  const logoSrc = logo ? logo.getAttribute('src') : 'assets/artwork-default.jpg';

  ['chipLogo', 'footerLogo'].forEach(function(id) {
    const el = document.getElementById(id);
    if (el) el.setAttribute('src', logoSrc);
  });

  const dl = document.getElementById('dlLogo');
  if (dl) dl.setAttribute('src', 'assets/launch_transparent.png');

  const nav = document.getElementById('navLogo');
  if (nav) nav.setAttribute('src', 'assets/launch_transparent.png');
})();

/* Showcase cinematic motion: staggered entrance + cursor parallax */
(function() {
  const stage = document.querySelector('.showcase-stage');
  if (!stage) return;

  const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  stage.setAttribute('data-anim', 'on');
  const floats = stage.querySelectorAll('.shot-float');
  const main = stage.querySelector('.shot-main');

  if (!reduce && 'IntersectionObserver' in window) {
    const io = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          stage.classList.add('in-view');
          io.disconnect();
        }
      });
    }, { threshold: 0.25 });
    io.observe(stage);
  } else {
    stage.classList.add('in-view');
  }

  if (reduce) return;

  let raf = null;
  stage.addEventListener('mousemove', function(e) {
    if (raf) return;
    raf = requestAnimationFrame(function() {
      raf = null;
      const r = stage.getBoundingClientRect();
      const nx = ((e.clientX - r.left) / r.width) - 0.5;
      const ny = ((e.clientY - r.top) / r.height) - 0.5;

      floats.forEach(function(f) {
        const d = parseFloat(f.dataset.depth || 14);
        f.style.setProperty('--px', (nx * d) + 'px');
        f.style.setProperty('--py', (ny * d) + 'px');
      });

      if (main) {
        main.style.setProperty('--px', (nx * 8) + 'px');
        main.style.setProperty('--py', (ny * 6) + 'px');
      }
    });
  });

  stage.addEventListener('mouseleave', function() {
    [].slice.call(floats).concat(main).forEach(function(el) {
      if (el) {
        el.style.removeProperty('--px');
        el.style.removeProperty('--py');
      }
    });
  });
})();

/* =========================================================
   GSAP SCROLLTRIGGER & TYPOGRAPHY SCROLLING EFFECTS
   ========================================================= */
(function() {
  function initScrollEffects() {
    if (typeof gsap === 'undefined') return;

    const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) return;

    if (typeof ScrollTrigger !== 'undefined') {
      gsap.registerPlugin(ScrollTrigger);
    }

    // 1. Hero Title Kinetic Entrance
    const heroTitle = document.querySelector('.hero-title');
    const heroEyebrow = document.querySelector('.hero-copy .eyebrow');
    const heroPara = document.querySelector('.hero-copy p');
    const heroActions = document.querySelector('.hero-actions');
    const heroStats = document.querySelector('.hero-stats');
    const heroStage = document.querySelector('.player-stage');

    if (heroTitle) {
      const heroTl = gsap.timeline({ defaults: { ease: 'power4.out', force3D: true } });

      if (heroEyebrow) {
        heroTl.fromTo(heroEyebrow, 
          { opacity: 0, y: 20, scale: 0.95 }, 
          { opacity: 1, y: 0, scale: 1, duration: 0.7, delay: 0.1 }
        );
      }

      heroTl.fromTo(heroTitle,
        { opacity: 0, y: 35, scale: 0.96 },
        { opacity: 1, y: 0, scale: 1, duration: 0.9 },
        '-=0.45'
      );

      if (heroPara) {
        heroTl.fromTo(heroPara,
          { opacity: 0, y: 18 },
          { opacity: 1, y: 0, duration: 0.7 },
          '-=0.6'
        );
      }

      if (heroActions) {
        heroTl.fromTo(heroActions,
          { opacity: 0, y: 16, scale: 0.96 },
          { opacity: 1, y: 0, scale: 1, duration: 0.7 },
          '-=0.55'
        );
      }

      if (heroStats) {
        heroTl.fromTo(heroStats.children,
          { opacity: 0, y: 15, scale: 0.95 },
          { opacity: 1, y: 0, scale: 1, duration: 0.6, stagger: 0.08 },
          '-=0.5'
        );
      }

      // Smooth Desktop Parallax (Disabled on mobile to ensure zero touch lag)
      if (typeof ScrollTrigger !== 'undefined' && window.innerWidth > 960) {
        gsap.to('.hero-copy', {
          y: -40,
          opacity: 0.7,
          ease: 'none',
          force3D: true,
          scrollTrigger: {
            trigger: '.hero',
            start: 'top top',
            end: 'bottom top',
            scrub: 0.4
          }
        });

        if (heroStage) {
          gsap.to(heroStage, {
            y: 30,
            scale: 0.98,
            ease: 'none',
            force3D: true,
            scrollTrigger: {
              trigger: '.hero',
              start: 'top top',
              end: 'bottom top',
              scrub: 0.4
            }
          });
        }
      }
    }

    // 2. Section Titles Scroll Entrance
    const sectionHeads = document.querySelectorAll('.section-head, .features-head, .dl-panel');

    sectionHeads.forEach(function(head) {
      const title = head.querySelector('.section-title, .features-title, .dl-title');
      const kicker = head.querySelector('.kicker');
      const sub = head.querySelector('.section-sub, .features-sub, .dl-sub');

      if (!title) return;

      const targets = [kicker, title, sub].filter(Boolean);

      if (typeof ScrollTrigger !== 'undefined') {
        gsap.fromTo(targets,
          { opacity: 0, y: 30, scale: 0.96 },
          {
            opacity: 1,
            y: 0,
            scale: 1,
            duration: 0.75,
            stagger: 0.1,
            ease: 'power3.out',
            force3D: true,
            scrollTrigger: {
              trigger: head,
              start: 'top 88%',
              toggleActions: 'play none none none'
            }
          }
        );
      } else if ('IntersectionObserver' in window) {
        const observer = new IntersectionObserver(function(entries) {
          entries.forEach(function(entry) {
            if (entry.isIntersecting) {
              gsap.fromTo(targets,
                { opacity: 0, y: 30, scale: 0.96 },
                { opacity: 1, y: 0, scale: 1, duration: 0.75, stagger: 0.1, ease: 'power3.out', force3D: true }
              );
              observer.disconnect();
            }
          });
        }, { threshold: 0.15 });
        observer.observe(head);
      }
    });

    // 3. Feature Cards Staggered Pop-In
    const fCards = document.querySelectorAll('.features-grid .fcard');
    if (fCards.length && typeof ScrollTrigger !== 'undefined') {
      gsap.fromTo(fCards,
        { opacity: 0, y: 40, scale: 0.95 },
        {
          opacity: 1,
          y: 0,
          scale: 1,
          duration: 0.7,
          stagger: 0.08,
          ease: 'power3.out',
          force3D: true,
          scrollTrigger: {
            trigger: '.features-grid',
            start: 'top 85%',
            toggleActions: 'play none none none'
          }
        }
      );
    }

    // 4. Showcase Floating Layers Scroll Parallax
    const showcaseStage = document.querySelector('.showcase-stage');
    if (showcaseStage && typeof ScrollTrigger !== 'undefined') {
      const floats = showcaseStage.querySelectorAll('.shot-float');
      if (floats.length && window.innerWidth > 960) {
        gsap.to('.shot-float.left-top', {
          y: -40,
          x: -22,
          ease: 'none',
          scrollTrigger: {
            trigger: showcaseStage,
            start: 'top bottom',
            end: 'bottom top',
            scrub: 1.2
          }
        });
        gsap.to('.shot-float.right-top', {
          y: -50,
          x: 28,
          ease: 'none',
          scrollTrigger: {
            trigger: showcaseStage,
            start: 'top bottom',
            end: 'bottom top',
            scrub: 1.2
          }
        });
        gsap.to('.shot-float.left-bottom', {
          y: 35,
          x: -26,
          ease: 'none',
          scrollTrigger: {
            trigger: showcaseStage,
            start: 'top bottom',
            end: 'bottom top',
            scrub: 1.2
          }
        });
        gsap.to('.shot-float.right-bottom', {
          y: 45,
          x: 22,
          ease: 'none',
          scrollTrigger: {
            trigger: showcaseStage,
            start: 'top bottom',
            end: 'bottom top',
            scrub: 1.2
          }
        });
      }
    }

    // 6. Download CTA Panel Noticeable Elevation
    const dlPanel = document.querySelector('.dl-panel');
    if (dlPanel && typeof ScrollTrigger !== 'undefined') {
      gsap.fromTo(dlPanel,
        { opacity: 0, y: 40, scale: 0.95 },
        {
          opacity: 1,
          y: 0,
          scale: 1,
          duration: 0.8,
          ease: 'power3.out',
          force3D: true,
          scrollTrigger: {
            trigger: dlPanel,
            start: 'top 88%',
            toggleActions: 'play none none none'
          }
        }
      );
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initScrollEffects);
  } else {
    initScrollEffects();
  }
})();


/* =========================================================
   GLOBAL INTERACTIVE MUSICAL NOTE BUBBLES
   (Spawns musical notes on CLICK and on CURSOR MOVEMENT)
   ========================================================= */
(function() {
  const notes = ['♪', '♫', '♬', '♩', '🎶', '✨'];
  const colors = ['#fa4059', '#8b7bff', '#ff6584', '#a78bfa', '#38ef7d', '#ffd166', '#00d9ff'];

  function spawnMusicBubble(x, y, isTrail = false) {
    const bubble = document.createElement('span');
    bubble.className = 'floating-music-bubble';
    bubble.textContent = notes[Math.floor(Math.random() * notes.length)];
    
    const color = colors[Math.floor(Math.random() * colors.length)];
    bubble.style.color = color;
    bubble.style.textShadow = `0 0 10px ${color}`;

    const dx = (Math.random() - 0.5) * (isTrail ? 45 : 80);
    const dy = (isTrail ? -35 : -50) - Math.random() * (isTrail ? 25 : 45);
    const rot = (Math.random() - 0.5) * 50;

    bubble.style.setProperty('--dx', dx + 'px');
    bubble.style.setProperty('--dy', dy + 'px');
    bubble.style.setProperty('--rot', rot + 'deg');
    bubble.style.left = x + 'px';
    bubble.style.top = y + 'px';

    const sz = isTrail ? (12 + Math.random() * 5) : (14 + Math.random() * 7);
    bubble.style.fontSize = sz + 'px';
    bubble.style.opacity = isTrail ? '0.9' : '1';

    document.body.appendChild(bubble);
    setTimeout(() => bubble.remove(), 1000);
  }

  function triggerBurst(clientX, clientY) {
    if (typeof clientX !== 'number' || typeof clientY !== 'number' || isNaN(clientX) || isNaN(clientY)) return;
    const count = 6 + Math.floor(Math.random() * 3);
    for (let i = 0; i < count; i++) {
      setTimeout(() => {
        spawnMusicBubble(clientX + (Math.random() - 0.5) * 28, clientY + (Math.random() - 0.5) * 28, false);
      }, i * 35);
    }
  }

  // 1. ON TOUCH START: Tap burst for phone
  let lastTouchTime = 0;
  document.addEventListener('touchstart', function(e) {
    if (e.touches && e.touches[0]) {
      lastTouchTime = performance.now();
      const touch = e.touches[0];
      triggerBurst(touch.clientX, touch.clientY);
    }
  }, { passive: true });

  // 2. ON TOUCH MOVE: Finger drag musical note trail on phone
  let lastTouchMoveTime = 0;
  let lastTouchX = 0, lastTouchY = 0;

  document.addEventListener('touchmove', function(e) {
    if (!e.touches || !e.touches[0]) return;
    const touch = e.touches[0];
    const now = performance.now();
    const dist = Math.hypot(touch.clientX - lastTouchX, touch.clientY - lastTouchY);

    if (now - lastTouchMoveTime > 50 && dist > 12) {
      lastTouchMoveTime = now;
      lastTouchX = touch.clientX;
      lastTouchY = touch.clientY;
      spawnMusicBubble(touch.clientX + (Math.random() - 0.5) * 8, touch.clientY + (Math.random() - 0.5) * 8, true);
    }
  }, { passive: true });

  // 3. ON CLICK: Desktop / Pointer burst
  document.addEventListener('click', function(e) {
    if (performance.now() - lastTouchTime < 350) return;
    triggerBurst(e.clientX, e.clientY);
  });

  // 4. ON MOUSE MOVE: Fluid musical note trail on desktop
  let lastMoveTime = 0;
  let lastX = 0, lastY = 0;
  let isScrolling = false;
  let scrollTimeout = null;

  window.addEventListener('scroll', function() {
    isScrolling = true;
    clearTimeout(scrollTimeout);
    scrollTimeout = setTimeout(function() {
      isScrolling = false;
    }, 120);
  }, { passive: true });

  window.addEventListener('mousemove', function(e) {
    if (isScrolling) return;
    const now = performance.now();
    const dist = Math.hypot(e.clientX - lastX, e.clientY - lastY);

    if (now - lastMoveTime > 55 && dist > 14) {
      lastMoveTime = now;
      lastX = e.clientX;
      lastY = e.clientY;

      spawnMusicBubble(e.clientX + (Math.random() - 0.5) * 8, e.clientY + (Math.random() - 0.5) * 8, true);
    }
  }, { passive: true });

  // 5. Hover on brand logo
  const brand = document.querySelector('.brand');
  if (brand) {
    let hoverTimer = null;
    brand.addEventListener('mouseenter', function() {
      const rect = brand.getBoundingClientRect();
      spawnMusicBubble(rect.left + rect.width * 0.4, rect.top + rect.height * 0.5);
      hoverTimer = setInterval(() => {
        spawnMusicBubble(rect.left + Math.random() * rect.width * 0.8, rect.top + rect.height * 0.5);
      }, 400);
    });
    brand.addEventListener('mouseleave', function() {
      clearInterval(hoverTimer);
    });
  }
})();

/* =========================================================
   DESKTOP SHORTCUT & WHEEL ZOOM PREVENTION
   ========================================================= */
(function() {
  // Prevent trackpad / mouse wheel pinch-to-zoom (Ctrl/Cmd + Wheel)
  window.addEventListener('wheel', function(e) {
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();
    }
  }, { passive: false });

  // Prevent keyboard zoom shortcuts (Ctrl/Cmd +, -, =, 0, _)
  window.addEventListener('keydown', function(e) {
    if ((e.ctrlKey || e.metaKey) && (e.key === '+' || e.key === '-' || e.key === '=' || e.key === '0' || e.key === '_')) {
      e.preventDefault();
    }
  });
})();


/* First-time installation command copy handler */
function copyInstallCmd(btn) {
  const code = "xattr -cr /Applications/Mooziac.app";
  navigator.clipboard.writeText(code).then(() => {
    const span = btn ? btn.querySelector("span") : null;
    if (span) {
      const original = span.textContent;
      span.textContent = "Copied!";
      btn.style.borderColor = "#30D158";
      btn.style.color = "#30D158";
      setTimeout(() => {
        span.textContent = original;
        btn.style.borderColor = "";
        btn.style.color = "";
      }, 2000);
    }
  });
}

