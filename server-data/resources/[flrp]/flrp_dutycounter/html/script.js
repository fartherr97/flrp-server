(function () {
  const els = { leo: document.getElementById('leo'), staff: document.getElementById('staff') };

  function set(key, value) {
    const el = els[key];
    if (!el) return;
    const next = String(value ?? 0);
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
