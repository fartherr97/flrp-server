/* FLRP Duty — NUI */
(function () {
  'use strict';
  var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'flrp_onduty';
  var S = { open: false, state: null, sel: null, rank: null, callsign: '', err: null, busy: false, tick: null, view: 'duty', units: null };
  var $ = function (id) { return document.getElementById(id); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); };
  function dur(sec) { sec = Math.max(0, Math.floor(sec)); var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60; return (h ? h + 'h ' : '') + (m < 10 && h ? '0' : '') + m + 'm ' + (s < 10 ? '0' : '') + s + 's'; }

  function post(action, payload) {
    return fetch('https://' + RES + '/req', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: action, payload: payload || {} }) })
      .then(function (r) { return r.json(); }).catch(function () { return { ok: false, error: 'No response.' }; });
  }
  function closeMenu() { fetch('https://' + RES + '/close', { method: 'POST', body: '{}' }); }

  function setView(v) {
    S.view = v;
    $('tab-duty').classList.toggle('active', v === 'duty');
    $('tab-units').classList.toggle('active', v === 'units');
    if (v === 'units') loadUnits();
    render();
  }
  function loadUnits() {
    post('units').then(function (res) { S.units = res || { ok: false, error: 'No response.' }; if (S.view === 'units') render(); });
  }

  function render() {
    var st = S.state; if (!st) return;
    $('logo').src = st.logo || ''; $('hd-sub').textContent = st.serverName || ''; $('ft-key').textContent = st.key || 'F6';
    if (S.view === 'units') return renderUnits();
    renderDuty();
  }

  function renderUnits() {
    var b = $('body'), u = S.units, html = '';
    if (!u) { b.innerHTML = '<div class="empty"><b>Loading units…</b></div>'; return; }
    if (!u.ok) { b.innerHTML = '<div class="empty"><b>Units unavailable</b>' + esc(u.error || '') + '</div>'; return; }
    var now = Math.floor(Date.now() / 1000);
    html += '<div class="utotal"><b>' + u.total + '</b> unit' + (u.total === 1 ? '' : 's') + ' on duty across ' + u.depts.length + ' departments</div>';
    u.depts.forEach(function (d) {
      html += '<div class="ugroup"><div class="uhead"><span class="bar" style="background:' + esc(d.colour) + '"></span><span class="nm">' + esc(d.short) + '</span><span class="sub">' + esc(d.label) + '</span><span class="cnt' + (d.count ? ' on' : '') + '">' + d.count + ' on duty</span></div>';
      if (!d.units.length) html += '<div class="unone">No units on duty.</div>';
      d.units.forEach(function (x) {
        html += '<div class="urow"><span class="cs' + (x.callsign ? '' : ' none') + '">' + esc(x.callsign || '—') + '</span><span class="who">' + esc(x.name) + '</span><span class="rk">' + esc(x.rank) + '</span><span class="tm">' + dur(now - x.since) + '</span></div>';
      });
      html += '</div>';
    });
    b.innerHTML = html;
  }

  function renderDuty() {
    var st = S.state;
    var b = $('body'), html = '';

    if (st.onDuty) {
      var d = st.onDuty, since = Math.floor(Date.now() / 1000) - d.since;
      html += '<div class="status"><span class="bar" style="background:' + esc(d.colour || '#00bfc4') + '"></span><div>' +
        '<div class="t">On duty · ' + esc(d.short) + '</div><div class="nm">' + esc(d.label) + '</div>' +
        '<div class="sub">' + esc(d.rankLabel) + (d.callsign ? ' · <b>' + esc(d.callsign) + '</b>' : '') + ' · ' + dur(since) + '</div></div>' +
        '<div class="right"><button class="btn off" data-act="off">Go Off Duty</button></div></div>';
      html += '<div class="sec">Switch department</div>';
    } else {
      html += '<div class="sec">Departments</div>';
    }

    if (!st.available.length) {
      html += '<div class="empty"><b>No departments available</b>You don\'t hold a department role. Ask staff if that\'s wrong.</div>';
    }
    st.available.forEach(function (dp) {
      var n = (st.counts && st.counts[dp.id]) || 0;
      html += '<div class="dept' + (S.sel === dp.id ? ' sel' : '') + '"><span class="bar" style="background:' + esc(dp.colour) + '"></span>' +
        '<div><div class="nm">' + esc(dp.label) + '</div><div class="sub">' + esc(dp.short) + ' · ' + dp.ranks.map(function (r) { return esc(r.label); }).join(' / ') + '</div></div>' +
        '<span class="cnt">' + n + ' on duty</span>' +
        '<button class="btn go" data-sel="' + esc(dp.id) + '">' + (S.sel === dp.id ? 'Selected' : 'Go On Duty') + '</button></div>';
      if (S.sel === dp.id) {
        var multi = dp.ranks.length > 1;
        html += '<div class="join">' + (S.err ? '<div class="err">' + esc(S.err) + '</div>' : '');
        if (multi) html += '<div class="field"><label>Rank</label><div class="ranks">' + dp.ranks.map(function (r) { return '<button class="rank' + (S.rank === r.id ? ' active' : '') + '" data-rank="' + esc(r.id) + '">' + esc(r.label) + '</button>'; }).join('') + '</div></div>';
        if (dp.requireCallsign) html += '<div class="field"><label>Callsign <span style="color:var(--dim);letter-spacing:0;text-transform:none;font-weight:600">(required, e.g. 1A-12)</span></label><input id="cs" maxlength="' + (st.callsignMax || 8) + '" placeholder="1A-12" value="' + esc(S.callsign) + '" /></div>';
        html += '<div class="row"><button class="btn primary" data-act="on">Confirm · ' + esc(dp.short) + '</button><button class="btn ghost" data-act="cancel">Cancel</button></div></div>';
      }
    });
    b.innerHTML = html;

    Array.prototype.forEach.call(b.querySelectorAll('[data-sel]'), function (el) {
      el.onclick = function () { var id = el.getAttribute('data-sel'); if (S.sel === id) return; S.sel = id; S.err = null;
        var dp = st.available.filter(function (x) { return x.id === id; })[0]; S.rank = dp && dp.ranks.length ? dp.ranks[0].id : null; render();
        var cs = $('cs'); if (cs) cs.focus(); };
    });
    Array.prototype.forEach.call(b.querySelectorAll('[data-rank]'), function (el) { el.onclick = function () { S.rank = el.getAttribute('data-rank'); render(); }; });
    Array.prototype.forEach.call(b.querySelectorAll('[data-act]'), function (el) { el.onclick = function () { act(el.getAttribute('data-act')); }; });
    var cs = $('cs'); if (cs) { cs.oninput = function () { S.callsign = cs.value.toUpperCase(); }; cs.onkeydown = function (e) { if (e.key === 'Enter') act('on'); }; }
  }

  function act(a) {
    if (S.busy) return;
    if (a === 'cancel') { S.sel = null; S.err = null; return render(); }
    S.busy = true;
    var p = a === 'on' ? post('goOn', { entity: S.sel, rank: S.rank, callsign: S.callsign }) : post('goOff');
    p.then(function (res) {
      S.busy = false;
      if (!res || !res.ok) { S.err = (res && res.error) || 'Failed.'; return render(); }
      S.sel = null; S.err = null; S.state = res; render();
    });
  }

  window.addEventListener('message', function (e) {
    var m = e.data || {};
    if (m.action === 'open') { S.state = m.state; S.open = true; S.sel = null; S.err = null; S.units = null; $('app').classList.remove('hidden');
      setView(m.view === 'units' ? 'units' : 'duty');
      if (S.tick) clearInterval(S.tick);
      S.tick = setInterval(function () {
        if (!S.open || document.activeElement.matches('input')) return;
        if (S.view === 'units') { loadUnits(); } else if (S.state && S.state.onDuty) render();
      }, S.view === 'units' ? 5000 : 1000); }
    else if (m.action === 'state' && S.open) { S.state = m.state; render(); }
    else if (m.action === 'close') { S.open = false; $('app').classList.add('hidden'); if (S.tick) { clearInterval(S.tick); S.tick = null; } }
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && S.open) closeMenu(); });
  $('btn-close').onclick = closeMenu;
  $('tab-duty').onclick = function () { setView('duty'); };
  $('tab-units').onclick = function () { setView('units'); };
})();
