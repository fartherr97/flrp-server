(function () {
  const els = { leo: document.getElementById('leo'), staff: document.getElementById('staff') };

  function set(key, value) {
    const el = els[key];
    if (!el) return;
    const n = parseInt(value, 10) || 0;
    // red when nobody's on, green when units are on
    el.classList.toggle('zero', n === 0);
    el.classList.toggle('active', n > 0);
    const next = String(n);
    if (el.textContent === next) return;
    el.textContent = next;
    el.classList.remove('bump');
    void el.offsetWidth; // restart the animation
    el.classList.add('bump');
  }

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'update') {
      set('leo', d.leo);
      set('staff', d.staff);
    }
  });
})();
