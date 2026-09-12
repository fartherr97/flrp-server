const query = new URLSearchParams(location.search);
const resource = query.get('resource');
const canvas = document.getElementById('map');
const ctx = canvas.getContext('2d');
const notify = action => resource && fetch(`https://${resource}/${action}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}'
}).catch(() => {});
window.addEventListener('message', event => {
  const d = event.data;
  if (!d || d.action !== 'render') return;
  canvas.width = canvas.height = d.size;
  const b = d.bounds;
  ctx.clearRect(0, 0, d.size, d.size);
  for (const label of d.labels) {
    const x = (label.x - b.minX) / (b.maxX - b.minX) * d.size;
    const y = (b.maxY - label.y) / (b.maxY - b.minY) * d.size;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate((label.rotation || 0) * Math.PI / 180);
    ctx.font = `bold ${label.size}px ${d.style.font}`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
    ctx.lineWidth = d.style.outlineWidth;
    ctx.strokeStyle = d.style.outline; ctx.fillStyle = d.style.fill;
    ctx.strokeText(label.text, 0, 0); ctx.fillText(label.text, 0, 0);
    ctx.restore();
  }
  notify('rendered');
});
notify('ready');
