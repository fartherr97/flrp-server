const wrap = document.getElementById('wrap');
const grid = document.getElementById('grid');
const logo = document.getElementById('logo');
const toast = document.getElementById('toast');

function resourceName() {
  // GetParentResourceName is injected by the CEF host; fall back to the folder.
  return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'flrp_spawn';
}

function post(endpoint, data) {
  return fetch(`https://${resourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

function showToast(msg) {
  toast.textContent = msg;
  toast.classList.remove('hidden');
  clearTimeout(showToast._t);
  showToast._t = setTimeout(() => toast.classList.add('hidden'), 2500);
}

function renderPoints(points) {
  grid.innerHTML = '';
  points.forEach((p) => {
    const card = document.createElement('div');
    card.className = 'card';
    const badge = p.locked ? '<span class="badge">LEO</span>' : '';
    card.innerHTML = `<div class="name">${p.name}${badge}</div><div class="area">${p.area || ''}</div>`;
    card.addEventListener('click', () => post('select', { index: p.index }));
    grid.appendChild(card);
  });
}

window.addEventListener('message', (event) => {
  const d = event.data || {};
  switch (d.action) {
    case 'open':
      if (d.logo) logo.src = d.logo;
      wrap.classList.remove('hidden');
      grid.innerHTML = '';
      break;
    case 'points':
      renderPoints(d.points || []);
      break;
    case 'denied':
      showToast('You are not allowed to spawn there.');
      break;
    case 'close':
      wrap.classList.add('hidden');
      break;
  }
});
