(function () {
  var stack = document.getElementById('toasts');

  // Static, safe (no user data) — a Lucide shield-check, stroked in the accent.
  var SHIELD =
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' +
    'stroke-linecap="round" stroke-linejoin="round">' +
    '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1' +
    'c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>' +
    '<path d="m9 12 2 2 4-4"/></svg>';

  function notify(data) {
    var max = data.max || 4;
    var dur = data.duration || 5000;

    var el = document.createElement('div');
    el.className = 'toast';
    el.style.color = data.color || '#35d07f';           // drives icon ring + glow via currentColor

    var icon = document.createElement('div');
    icon.className = 'ticon';
    icon.innerHTML = SHIELD;                              // static markup, safe

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
