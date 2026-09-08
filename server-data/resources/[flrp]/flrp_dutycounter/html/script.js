(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'flrp_dutycounter';
  const post = (cb, body) =>
    fetch(`https://${RES}/${cb}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {}),
    }).catch(() => {});

  const wrap    = document.getElementById('wrap');
  const counter = document.getElementById('counter');
  const tools   = document.getElementById('tools');
  const hint    = document.getElementById('hint');
  const pct     = document.getElementById('pct');
  const els = {
    leo: document.getElementById('leo'),
    fire: document.getElementById('fire'),
    staff: document.getElementById('staff'),
  };

  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  let layout = { x: 22.4, y: 78, scale: 1 };
  let editing = false;
  let drag = null;

  function apply() {
    wrap.style.left = layout.x + 'vw';
    wrap.style.top = layout.y + 'vh';
    wrap.style.transform = 'scale(' + layout.scale + ')';
    pct.textContent = Math.round(layout.scale * 100) + '%';
  }

  // ---- live counts ----------------------------------------------------------
  function set(key, value) {
    const el = els[key];
    if (!el) return;
    const n = parseInt(value, 10) || 0;
    el.classList.toggle('zero', n === 0);
    el.classList.toggle('active', n > 0);
    const next = String(n);
    if (el.textContent === next) return;
    el.textContent = next;
    el.classList.remove('bump');
    void el.offsetWidth;
    el.classList.add('bump');
    // Remove it after the pop so the number settles back to its normal size
    // (leaving it on kept the value stuck at scale(1.25) → looked oversized).
    clearTimeout(el._bumpT);
    el._bumpT = setTimeout(() => el.classList.remove('bump'), 200);
  }

  // ---- edit mode ------------------------------------------------------------
  function setEditing(on) {
    editing = on;
    document.body.classList.toggle('editing', on);
    tools.classList.toggle('hidden', !on);
    hint.classList.toggle('hidden', !on);
  }

  counter.addEventListener('mousedown', (e) => {
    if (!editing) return;
    e.preventDefault();
    const px = (layout.x / 100) * window.innerWidth;
    const py = (layout.y / 100) * window.innerHeight;
    drag = { dx: e.clientX - px, dy: e.clientY - py };
  });
  window.addEventListener('mousemove', (e) => {
    if (!editing || !drag) return;
    layout.x = clamp(((e.clientX - drag.dx) / window.innerWidth) * 100, 0, 96);
    layout.y = clamp(((e.clientY - drag.dy) / window.innerHeight) * 100, 0, 96);
    apply();
  });
  window.addEventListener('mouseup', () => { drag = null; });

  function resize(d) { layout.scale = clamp(+(layout.scale + d).toFixed(2), 0.6, 2); apply(); }
  document.getElementById('minus').addEventListener('click', () => resize(-0.1));
  document.getElementById('plus').addEventListener('click', () => resize(0.1));
  document.getElementById('reset').addEventListener('click', () => post('dccReset'));
  document.getElementById('cancel').addEventListener('click', () => { setEditing(false); post('dccCancel'); });
  document.getElementById('save').addEventListener('click', () => { setEditing(false); post('dccSave', layout); });
  window.addEventListener('keydown', (e) => { if (e.key === 'Escape' && editing) { setEditing(false); post('dccCancel'); } });

  // ---- messages from the client ---------------------------------------------
  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'update') {
      set('leo', d.leo); set('fire', d.fire); set('staff', d.staff);
    } else if (d.type === 'layout') {
      if (d.layout) { layout = { x: +d.layout.x, y: +d.layout.y, scale: +d.layout.scale }; apply(); }
    } else if (d.type === 'edit') {
      if (d.layout) { layout = { x: +d.layout.x, y: +d.layout.y, scale: +d.layout.scale }; }
      apply();
      setEditing(!!d.on);
    }
  });

  apply();
})();
