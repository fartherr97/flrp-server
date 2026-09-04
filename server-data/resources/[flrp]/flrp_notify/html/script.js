(function () {
  var stack = document.getElementById('toasts');

  // Static, safe (no user data) — Lucide icons, stroked in the accent colour.
  function svg(inner) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
      'stroke-linecap="round" stroke-linejoin="round">' + inner + '</svg>';
  }
  var ICONS = {
    info:  svg('<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>'),        // "i"
    ok:    svg('<path d="M20 6 9 17l-5-5"/>'),                                                         // check
    error: svg('<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>'),          // "!"
    warn:  svg('<path d="m21.73 18-8-14a2 2 0 0 0-3.46 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3z"/>' +
               '<path d="M12 9v4"/><path d="M12 17h.01"/>'),                                           // triangle !
    join:  svg('<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>' +
               '<line x1="19" x2="19" y1="8" y2="14"/><line x1="22" x2="16" y1="11" y2="11"/>'),       // user +
    leave: svg('<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>' +
               '<line x1="22" x2="16" y1="11" y2="11"/>')                                              // user -
  };
  // aliases
  ICONS.success = ICONS.ok;
  ICONS.warning = ICONS.warn;

  function notify(data) {
    var max = data.max || 4;
    var dur = data.duration || 5000;

    var el = document.createElement('div');
    el.className = 'toast';
    el.style.color = data.color || '#35d07f';           // drives icon ring + glow via currentColor

    var icon = document.createElement('div');
    icon.className = 'ticon';
    icon.innerHTML = ICONS[data.variant] || ICONS.info;  // static markup, safe

    var text = document.createElement('div');
    text.className = 'ttext';

    var name = document.createElement('div');
    name.className = 'tname';
    name.textContent = data.name;                         // textContent = no HTML injection

    var msg = document.createElement('div');
    msg.className = 'tmsg';
    msg.textContent = (data.kind === 'leave')
      ? (data.leaveMsg || 'left the server')
      : (data.joinMsg || 'joined the server');

    text.appendChild(name);
    text.appendChild(msg);
    el.appendChild(icon);
    el.appendChild(text);
    stack.appendChild(el);

    requestAnimationFrame(function () { el.classList.add('in'); });

    while (stack.children.length > max) {
      stack.removeChild(stack.firstChild);
    }

    setTimeout(function () {
      el.classList.remove('in');
      el.classList.add('out');
      setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 250);
    }, dur);
  }

  window.addEventListener('message', function (e) {
    var data = e.data || {};
    if (data.action === 'notify') notify(data);
  });
})();
