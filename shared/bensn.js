/* bensn.js — shared across all bensn.me pages */

(function() {
  const BLOBS = [
    { color: '#00A6FB', w: 520, h: 460, x: 0.72, y: 0.08, vx: 0.16, vy: 0.11 },
    { color: '#FF0051', w: 460, h: 400, x: 0.10, y: 0.65, vx: -0.13, vy: -0.15 },
    { color: '#00A6FB', w: 320, h: 280, x: 0.45, y: 0.45, vx: 0.09, vy: -0.18 },
    { color: '#FF0051', w: 280, h: 260, x: 0.80, y: 0.75, vx: -0.20, vy: 0.08 },
  ];

  const container = document.getElementById('blobs');
  if (!container) return;

  const els = BLOBS.map(b => {
    const el = document.createElement('div');
    el.className = 'blob';
    el.style.width = b.w + 'px';
    el.style.height = b.h + 'px';
    el.style.background = b.color;
    container.appendChild(el);
    return el;
  });

  const state = BLOBS.map(b => ({ ...b }));

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  let rafId = null;

  function render() {
    const W = window.innerWidth;
    const H = window.innerHeight;
    state.forEach((b, i) => {
      const maxX = 1 - b.w / W;
      const maxY = 1 - b.h / H;
      b.x = Math.min(Math.max(b.x, 0), Math.max(maxX, 0));
      b.y = Math.min(Math.max(b.y, 0), Math.max(maxY, 0));
      els[i].style.transform = 'translate(' + Math.round(b.x * W) + 'px,' + Math.round(b.y * H) + 'px)';
    });
  }

  function tick() {
    const W = window.innerWidth;
    const H = window.innerHeight;
    state.forEach((b) => {
      b.x += b.vx * 0.0025;
      b.y += b.vy * 0.0025;
      const maxX = 1 - b.w / W;
      const maxY = 1 - b.h / H;
      if (b.x <= 0) { b.x = 0; b.vx = Math.abs(b.vx); }
      if (b.x >= maxX) { b.x = maxX; b.vx = -Math.abs(b.vx); }
      if (b.y <= 0) { b.y = 0; b.vy = Math.abs(b.vy); }
      if (b.y >= maxY) { b.y = maxY; b.vy = -Math.abs(b.vy); }
    });
    render();
    rafId = requestAnimationFrame(tick);
  }

  // The blurred blobs are expensive to repaint. Freeze them while the page is hidden or a
  // text field is focused (on-screen keyboard + repaint load can stall Safari on iOS).
  function isTyping() {
    const a = document.activeElement;
    return !!a && (a.tagName === 'TEXTAREA' || a.tagName === 'SELECT' ||
      (a.tagName === 'INPUT' && !/^(range|checkbox|radio|button|submit|file)$/.test(a.type)));
  }
  function sync() {
    const shouldRun = !reduceMotion && !document.hidden && !isTyping();
    if (shouldRun && rafId === null) rafId = requestAnimationFrame(tick);
    else if (!shouldRun && rafId !== null) { cancelAnimationFrame(rafId); rafId = null; }
  }
  document.addEventListener('visibilitychange', sync);
  document.addEventListener('focusin', sync);
  document.addEventListener('focusout', () => setTimeout(sync, 0));
  window.addEventListener('resize', render);
  render();
  sync();
})();

// Expose the visible viewport (area above the on-screen keyboard) as CSS variables so
// fixed bottom sheets can size and position themselves inside it. iOS Safari does not
// shrink the layout viewport when the keyboard opens.
(function() {
  const vv = window.visualViewport;
  if (!vv) return;
  const root = document.documentElement;
  function update() {
    root.style.setProperty('--vv-height', vv.height + 'px');
    root.style.setProperty('--vv-top', vv.offsetTop + 'px');
  }
  vv.addEventListener('resize', update);
  vv.addEventListener('scroll', update);
  update();
})();
