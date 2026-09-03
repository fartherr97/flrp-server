(function () {
  var stack = document.getElementById('toasts');

  function notify(data) {
    var max = data.max || 4;
    var dur = data.duration || 5000;

    var el = document.createElement('div');
    el.className = 'toast';

    var bar = document.createElement('span');
    bar.className = 'tbar';
    if (data.color) bar.style.background = data.color;

    var name = document.createElement('span');
    name.className = 'tname';
    name.textContent = data.name;                       // textContent = no HTML injection

    var msg = document.createElement('span');
    msg.className = 'tmsg';
    msg.textContent = (data.kind === 'leave')
      ? (data.leaveMsg || 'left the server')
      : (data.joinMsg || 'joined the server');

    el.appendChild(bar);
    el.appendChild(name);
    el.appendChild(msg);
    stack.appendChild(el);

    // enter on next frame so the transition runs
    requestAnimationFrame(function () { el.classList.add('in'); });

    // cap the stack — drop the oldest
    while (stack.children.length > max) {
      stack.removeChild(stack.firstChild);
    }

    // auto-dismiss
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
