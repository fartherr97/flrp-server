/* FLRP Reports — NUI app (staff console + player support) */
(function () {
  'use strict';
  var RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'flrp_reports';

  var S = {
    open: false, state: null, view: null, sel: null, analytics: null,
    offset: 0,                       // server-unix*1000 - Date.now()
    form: { category: 'player', target: '', description: '' },
    drafts: {}, notice: null, resolving: false, busy: false, tick: null
  };

  var $ = function (id) { return document.getElementById(id); };
  var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]; }); };
  var nowS = function () { return Math.floor((Date.now() + S.offset) / 1000); };
  function dur(sec) {
    sec = Math.max(0, Math.floor(Number(sec) || 0));
    if (sec < 60) return sec + 's';
    var m = Math.floor(sec / 60), s = sec % 60;
    if (m < 60) return m + 'm ' + (s < 10 ? '0' : '') + s + 's';
    var h = Math.floor(m / 60); m = m % 60;
    return h + 'h ' + (m < 10 ? '0' : '') + m + 'm';
  }
  var ago = function (ts) { return ts ? dur(nowS() - ts) + ' ago' : '—'; };
  function clock(ts) { if (!ts) return '—'; var d = new Date(ts * 1000); return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }); }

  function post(action, payload) {
    return fetch('https://' + RES + '/req', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: action, payload: payload || {} })
    }).then(function (r) { return r.json(); }).catch(function () { return { ok: false, error: 'No response from server.' }; });
  }
  function closeMenu() { fetch('https://' + RES + '/close', { method: 'POST', body: '{}' }); }

  /* ------------------------------------------------------------ toasts */
  function toast(t) {
    var stack = $('toasts');
    var el = document.createElement('div');
    el.className = 'toast ' + (t.kind || 'info');
    var secs = t.seconds || 8;
    el.innerHTML =
      '<span class="bar"></span><div style="min-width:0">' +
      '<div class="tt">' + esc(t.title) + '</div>' +
      (t.body ? '<div class="tb">' + esc(t.body) + '</div>' : '') +
      (t.reportId ? '<div class="tk">Press <kbd>' + esc(S.state && S.state.key || 'J') + '</kbd> to open</div>' : '') +
      '</div><span class="prog" style="animation-duration:' + secs + 's"></span>';
    stack.appendChild(el);
    requestAnimationFrame(function () { el.classList.add('in'); });
    while (stack.children.length > 4) stack.removeChild(stack.firstChild);
    setTimeout(function () {
      el.classList.remove('in'); el.classList.add('out');
      setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 220);
    }, secs * 1000);
  }

  /* ------------------------------------------------------------ state */
  function applyState(state) {
    S.state = state;
    S.offset = (state.now * 1000) - Date.now();
    if (!S.view) S.view = state.isStaff ? 'queue' : 'new';
    // keep selection valid
    if (S.sel && !state.reports.some(function (r) { return r.id === S.sel; })) S.sel = null;
    $('logo').src = state.logo || '';
    $('hd-sub').textContent = state.isStaff ? 'Staff Console' : 'Player Support';
    $('staff-online').textContent = state.staffOnline + ' staff online';
    $('ft-key').textContent = state.key || 'J';
    $('ft-brand').textContent = state.serverName || 'Florida Roleplay';
  }
  function report(id) { return (S.state.reports || []).filter(function (r) { return r.id === id; })[0] || null; }
  function statusRank(s) { return s === 'open' ? 0 : s === 'claimed' ? 1 : 2; }
  function sortReports(list) {
    return list.slice().sort(function (a, b) { return statusRank(a.status) - statusRank(b.status) || b.createdAt - a.createdAt; });
  }
  function listFor(view) {
    var all = S.state.reports || [];
    if (view === 'queue')    return sortReports(all.filter(function (r) { return r.status !== 'resolved'; }));
    if (view === 'mine')     return sortReports(all.filter(function (r) { return r.claimedByMe && r.status !== 'resolved'; }));
    if (view === 'resolved') return all.filter(function (r) { return r.status === 'resolved'; }).sort(function (a, b) { return (b.resolvedAt || 0) - (a.resolvedAt || 0); });
    if (view === 'myreports')return sortReports(all);
    return [];
  }

  /* ------------------------------------------------------------ render */
  function render() {
    if (!S.state) return;
    renderNav(); renderList(); renderDetail();
  }

  function renderNav() {
    var st = S.state, all = st.reports || [];
    var items = st.isStaff ? [
      { id: 'queue',    icon: '◉', label: 'Queue',     cnt: all.filter(function (r) { return r.status === 'open'; }).length, cls: 'warn' },
      { id: 'mine',     icon: '✎', label: 'My Claims', cnt: all.filter(function (r) { return r.claimedByMe && r.status !== 'resolved'; }).length, cls: 'hot' },
      { id: 'resolved', icon: '✓', label: 'Resolved',  cnt: all.filter(function (r) { return r.status === 'resolved'; }).length },
      { sep: true },
      { id: 'analytics',icon: '▤', label: 'Analytics' }
    ] : [
      { id: 'new',      icon: '＋', label: 'New Report' },
      { id: 'myreports',icon: '◉', label: 'My Reports', cnt: all.filter(function (r) { return r.status !== 'resolved'; }).length, cls: 'hot' }
    ];
    var html = '';
    items.forEach(function (it) {
      if (it.sep) { html += '<div class="nav-sep"></div>'; return; }
      html += '<button class="nav-item' + (S.view === it.id ? ' active' : '') + '" data-view="' + it.id + '">' +
        '<span>' + it.icon + '</span><span>' + esc(it.label) + '</span>' +
        (it.cnt != null ? '<span class="cnt' + (it.cnt > 0 && it.cls ? ' ' + it.cls : '') + '">' + it.cnt + '</span>' : '') + '</button>';
    });
    html += '<div class="nav-foot">' + (st.isStaff
      ? 'New reports pop a toast — press <kbd>' + esc(st.key) + '</kbd> while it shows to jump straight to it.'
      : 'Type <b>/report</b> or <b>/calladmin</b> any time. Staff will message you here.') + '</div>';
    $('nav').innerHTML = html;
    Array.prototype.forEach.call($('nav').querySelectorAll('.nav-item'), function (b) {
      b.onclick = function () { S.view = b.getAttribute('data-view'); S.resolving = false; S.notice = null; if (S.view === 'analytics') loadAnalytics(); render(); };
    });
  }

  function cardHTML(r) {
    var mine = r.claimedByMe;
    return '<button class="card' + (S.sel === r.id ? ' active' : '') + '" data-id="' + r.id + '">' +
      '<div class="card-top"><span class="card-id">#' + r.id + '</span>' +
      '<span class="chip" style="color:' + esc(r.categoryColour) + '"><span class="dot"></span>' + esc(r.categoryLabel) + '</span>' +
      '<span class="card-age">' + ago(r.createdAt) + '</span></div>' +
      '<div class="card-who">' + esc(r.reporter.name) + (r.target ? ' <span style="color:var(--dim);font-weight:600">vs</span> ' + esc(r.target) : '') + '</div>' +
      '<div class="card-desc">' + esc(r.description) + '</div>' +
      '<div class="card-bot"><span class="pill ' + r.status + '">' + r.status + '</span>' +
      (r.claimedBy ? '<span>' + (mine ? 'you' : esc(r.claimedBy)) + '</span>' : '') +
      (r.messages && r.messages.length ? '<span style="margin-left:auto">✉ ' + r.messages.length + '</span>' : '') +
      '</div></button>';
  }

  function renderList() {
    var list = $('list'), detail = $('detail');
    if (S.view === 'analytics' || S.view === 'new') { list.classList.add('hidden'); detail.style.borderLeft = 'none'; return; }
    list.classList.remove('hidden');
    var rows = listFor(S.view);
    var title = { queue: 'Live queue', mine: 'Claimed by you', resolved: 'Recently resolved', myreports: 'Your reports' }[S.view] || '';
    var html = '<div class="sec-title">' + title + ' · ' + rows.length + '</div>';
    if (!rows.length) {
      html += '<div class="empty"><div class="big">' + (S.view === 'queue' ? '☕' : '◌') + '</div><div class="t">' +
        (S.view === 'queue' ? 'Queue is clear' : S.view === 'mine' ? 'Nothing claimed' : S.view === 'resolved' ? 'No resolved reports yet' : 'You have no reports') + '</div></div>';
    } else rows.forEach(function (r) { html += cardHTML(r); });
    list.innerHTML = html;
    Array.prototype.forEach.call(list.querySelectorAll('.card'), function (c) {
      c.onclick = function () { S.sel = Number(c.getAttribute('data-id')); S.resolving = false; S.notice = null; render(); };
    });
  }

  function renderDetail() {
    var d = $('detail');
    if (S.view === 'analytics') return renderAnalytics(d);
    if (S.view === 'new') return renderForm(d);
    var r = S.sel ? report(S.sel) : null;
    if (!r) {
      d.innerHTML = '<div class="empty"><div class="big">☰</div><div class="t">Select a report</div><div>' +
        (S.state.isStaff ? 'Claim it, message the player, teleport, resolve.' : 'Track its status and read replies from staff.') + '</div></div>';
      return;
    }
    var st = S.state, staff = st.isStaff;
    var html = '';
    if (S.notice) html += '<div class="' + S.notice.cls + '">' + esc(S.notice.text) + '</div>';

    // header
    html += '<div class="d-head"><div><div class="d-title">Report #' + r.id + ' <span class="pill ' + r.status + '" style="vertical-align:middle;margin-left:6px">' + r.status + '</span></div>' +
      '<div class="d-meta"><span class="chip" style="color:' + esc(r.categoryColour) + '"><span class="dot"></span>' + esc(r.categoryLabel) + '</span>' +
      '<span>by <b style="color:var(--text)">' + esc(r.reporter.name) + '</b>' + (staff && r.reporter.src ? ' <span style="color:var(--dim)">(id ' + r.reporter.src + ')</span>' : '') + '</span>' +
      '<span class="pill ' + (r.reporter.online ? 'online' : 'offline') + '">' + (r.reporter.online ? '● online' : '○ offline') + '</span>' +
      (r.target ? '<span>against <b style="color:var(--text)">' + esc(r.target) + '</b></span>' : '') +
      '<span>' + ago(r.createdAt) + '</span></div></div>';

    // actions
    var acts = '';
    if (staff) {
      if (r.status === 'open') acts += r.own
        ? '<span class="pill soft" style="align-self:center">Your report — another staffer must claim it</span>'
        : '<button class="btn primary" data-act="claim">✋ Claim</button>';
      if (r.status === 'claimed' && r.claimedByMe) acts += '<button class="btn ghost" data-act="unclaim">Release</button>';
      if (r.status !== 'resolved') {
        acts += '<button class="btn" data-act="goto"' + (r.reporter.online ? '' : ' disabled') + '>➜ Go to</button>';
        acts += '<button class="btn" data-act="bring"' + (r.reporter.online ? '' : ' disabled') + '>⤵ Bring</button>';
        if (!(r.status === 'open' && r.own)) acts += '<button class="btn good" data-act="resolve-open">✓ Resolve</button>';
      }
    }
    html += '<div class="d-actions">' + acts + '</div></div>';

    if (S.resolving && staff && r.status !== 'resolved') {
      html += '<div class="box"><div class="lbl">Resolution note (sent to the player)</div>' +
        '<div class="composer"><input id="res-note" maxlength="255" placeholder="e.g. Spoke to both parties, warning issued." />' +
        '<button class="btn good" data-act="resolve">Confirm</button><button class="btn ghost" data-act="resolve-cancel">Cancel</button></div></div>';
    }

    // description
    html += '<div class="box"><div class="lbl">Description</div><div class="val">' + esc(r.description) + '</div></div>';

    // timeline
    html += '<div class="timeline">' +
      '<div class="tl"><div class="lbl">Submitted</div><div class="val">' + clock(r.createdAt) + '</div><div class="sub">' + ago(r.createdAt) + '</div></div>' +
      '<div class="tl"><div class="lbl">Claimed</div><div class="val">' + (r.claimedAt ? dur(r.claimedAt - r.createdAt) : '—') + '</div><div class="sub">' + (r.claimedBy ? 'by ' + esc(r.claimedBy) : (r.status === 'open' ? 'waiting for staff' : '')) + '</div></div>' +
      '<div class="tl"><div class="lbl">Resolved</div><div class="val">' + (r.resolvedAt ? dur(r.resolvedAt - (r.claimedAt || r.createdAt)) : '—') + '</div><div class="sub">' + (r.resolution ? esc(r.resolution) : (r.resolvedAt ? 'closed' : '')) + '</div></div>' +
      '</div>';

    // thread
    html += '<div class="box"><div class="lbl">Conversation</div><div class="thread">';
    if (!r.messages || !r.messages.length) html += '<div class="msg sys">No messages yet' + (staff ? ' — say hi to the player.' : ' — staff will reply here.') + '</div>';
    else r.messages.forEach(function (m) {
      html += '<div class="msg' + (m.staff ? ' staff' : '') + '"><div class="who"><span>' + esc(m.name) + (m.staff ? ' · staff' : '') + '</span><span class="t">' + clock(m.at) + '</span></div>' + esc(m.body) + '</div>';
    });
    html += '</div>';
    if (r.status !== 'resolved') {
      html += '<div class="composer" style="margin-top:10px"><input id="msg-in" maxlength="' + (st.maxMsg || 400) + '" placeholder="' + (staff ? 'Message ' + esc(r.reporter.name) + '…' : 'Reply to staff…') + '" value="' + esc(S.drafts[r.id] || '') + '" />' +
        '<button class="btn primary" data-act="send">Send</button></div>';
    }
    html += '</div>';
    d.innerHTML = html;

    // wire actions
    Array.prototype.forEach.call(d.querySelectorAll('[data-act]'), function (b) {
      b.onclick = function () { action(b.getAttribute('data-act'), r); };
    });
    var mi = $('msg-in');
    if (mi) {
      mi.oninput = function () { S.drafts[r.id] = mi.value; };
      mi.onkeydown = function (e) { if (e.key === 'Enter') { e.preventDefault(); action('send', r); } };
    }
    var rn = $('res-note'); if (rn) { rn.focus(); rn.onkeydown = function (e) { if (e.key === 'Enter') action('resolve', r); }; }
  }

  function action(act, r) {
    if (S.busy) return;
    if (act === 'resolve-open') { S.resolving = true; return render(); }
    if (act === 'resolve-cancel') { S.resolving = false; return render(); }
    var payload = { id: r.id };
    if (act === 'send') {
      var v = ($('msg-in') && $('msg-in').value || '').trim();
      if (!v) return;
      payload.body = v;
      act = 'message';
    }
    if (act === 'resolve') payload.resolution = ($('res-note') && $('res-note').value || '').trim();
    S.busy = true;
    post(act, payload).then(function (res) {
      S.busy = false;
      if (!res || !res.ok) { S.notice = { cls: 'err', text: (res && res.error) || 'Failed.' }; return render(); }
      if (act === 'message') S.drafts[r.id] = '';
      if (act === 'resolve') S.resolving = false;
      S.notice = null;
      refreshState();
    });
  }

  function refreshState() {
    post('state').then(function (st) { if (st && st.ok) { applyState(st); render(); } });
  }

  /* ------------------------------------------------------------ player form */
  function renderForm(d) {
    var st = S.state, f = S.form;
    var html = '';
    if (S.notice) html += '<div class="' + S.notice.cls + '">' + esc(S.notice.text) + '</div>';
    html += '<div class="d-title">Submit a report</div>' +
      '<div style="color:var(--muted);font-size:13px;margin-top:-6px">Staff online now: <b style="color:var(--text)">' + st.staffOnline + '</b>. You\'ll get a notification when someone claims it, and can chat with them from <b>My Reports</b>.</div>' +
      '<div class="form">' +
      '<div><label>Category</label><div class="cats">' +
      (st.categories || []).map(function (c) {
        return '<button class="cat' + (f.category === c.id ? ' active' : '') + '" data-cat="' + esc(c.id) + '"><span class="dot" style="background:' + esc(c.colour) + '"></span>' + esc(c.label) + '</button>';
      }).join('') + '</div></div>' +
      '<div><label>Player involved <span style="color:var(--dim);font-weight:600;letter-spacing:0;text-transform:none">(optional — name or ID)</span></label><input id="f-target" maxlength="100" placeholder="e.g. 42 or John Doe" value="' + esc(f.target) + '" /></div>' +
      '<div><label>What happened?</label><textarea id="f-desc" maxlength="' + (st.maxDesc || 600) + '" placeholder="Be specific: what, where, when. Include IDs if you can.">' + esc(f.description) + '</textarea><div class="cnt"><span id="f-cnt">' + (f.description || '').length + '</span> / ' + (st.maxDesc || 600) + '</div></div>' +
      '<div style="display:flex;gap:10px;align-items:center"><button class="btn primary" id="f-submit">Submit report</button><span class="hint">One open report at a time. Abuse of the report system is punishable.</span></div>' +
      '</div>';
    d.innerHTML = html;
    Array.prototype.forEach.call(d.querySelectorAll('.cat'), function (b) { b.onclick = function () { f.category = b.getAttribute('data-cat'); render(); }; });
    $('f-target').oninput = function () { f.target = this.value; };
    $('f-desc').oninput = function () { f.description = this.value; $('f-cnt').textContent = this.value.length; };
    $('f-submit').onclick = function () {
      if (S.busy) return;
      S.busy = true;
      post('submit', { category: f.category, target: f.target, description: f.description }).then(function (res) {
        S.busy = false;
        if (!res || !res.ok) { S.notice = { cls: 'err', text: (res && res.error) || 'Failed.' }; return render(); }
        S.form = { category: 'player', target: '', description: '' };
        S.notice = { cls: 'ok', text: 'Report #' + res.id + ' submitted — staff have been notified.' };
        S.view = 'myreports'; S.sel = res.id;
        refreshState();
      });
    };
  }

  /* ------------------------------------------------------------ analytics */
  function loadAnalytics() {
    S.analytics = null;
    post('analytics').then(function (a) { if (a && a.ok) { S.analytics = a; if (S.view === 'analytics') render(); } });
  }
  function renderAnalytics(d) {
    var a = S.analytics;
    if (!a) { d.innerHTML = '<div class="empty"><div class="big">▤</div><div class="t">Crunching numbers…</div></div>'; return; }
    var o = a.overall || {}, t = a.today || {};
    var html = '<div class="d-title">Analytics</div>' +
      '<div class="stats">' +
      '<div class="stat warn"><div class="lbl">Open right now</div><div class="val">' + (a.open || 0) + '</div><div class="sub">' + (a.claimed || 0) + ' being handled</div></div>' +
      '<div class="stat"><div class="lbl">Avg time to claim</div><div class="val">' + (o.avg_claim != null ? dur(o.avg_claim) : '—') + '</div><div class="sub">today: ' + (t.avgClaim != null ? dur(t.avgClaim) : '—') + '</div></div>' +
      '<div class="stat"><div class="lbl">Avg time to resolve</div><div class="val">' + (o.avg_resolve != null ? dur(o.avg_resolve) : '—') + '</div><div class="sub">after claim</div></div>' +
      '<div class="stat good"><div class="lbl">Resolved today</div><div class="val">' + (t.resolved || 0) + '</div><div class="sub">' + (t.reports || 0) + ' reports today · ' + (o.resolved || 0) + ' / ' + (o.total || 0) + ' all-time</div></div>' +
      '</div>';

    var rows = (a.staff || []).map(function (s) { return { name: s.name, claims: Number(s.claims) || 0, resolved: Number(s.resolved) || 0, avg: s.avg_claim != null ? Number(s.avg_claim) : null, fastest: s.fastest != null ? Number(s.fastest) : null, avgRes: s.avg_resolve != null ? Number(s.avg_resolve) : null }; });
    var ranked = rows.filter(function (s) { return s.claims >= a.minClaims && s.avg != null; }).sort(function (x, y) { return x.avg - y.avg; });
    var unranked = rows.filter(function (s) { return !(s.claims >= a.minClaims && s.avg != null); }).sort(function (x, y) { return y.claims - x.claims; });
    var slowest = Math.max.apply(null, rows.map(function (s) { return s.avg || 0; }).concat([1]));

    html += '<div class="box"><div class="lbl">Fastest responders · leaderboard <span style="color:var(--dim);font-weight:600;letter-spacing:0;text-transform:none">(ranked by avg time to claim, min ' + a.minClaims + ' claims)</span></div>';
    if (!rows.length) html += '<div class="empty" style="padding:18px"><div class="t">No claims recorded yet</div><div>Rankings appear once staff start claiming reports.</div></div>';
    else {
      html += '<table class="table"><thead><tr><th>#</th><th>Staff</th><th>Claims</th><th>Resolved</th><th style="width:26%">Avg to claim</th><th>Fastest</th><th>Avg to resolve</th></tr></thead><tbody>';
      ranked.forEach(function (s, i) {
        html += '<tr><td class="rank g' + (i + 1) + '">' + (i < 3 ? ['🥇', '🥈', '🥉'][i] : (i + 1)) + '</td><td class="name">' + esc(s.name) + '</td><td class="num">' + s.claims + '</td><td class="num">' + s.resolved + '</td>' +
          '<td><span class="num">' + dur(s.avg) + '</span><div class="meter' + (i === 0 ? ' good' : '') + '"><i style="width:' + Math.max(4, Math.round(100 * s.avg / slowest)) + '%"></i></div></td>' +
          '<td>' + (s.fastest != null ? dur(s.fastest) : '—') + '</td><td>' + (s.avgRes != null ? dur(s.avgRes) : '—') + '</td></tr>';
      });
      unranked.forEach(function (s) {
        html += '<tr style="opacity:.7"><td class="rank">–</td><td class="name">' + esc(s.name) + '<span class="unranked">needs ' + (a.minClaims - s.claims) + ' more</span></td><td class="num">' + s.claims + '</td><td class="num">' + s.resolved + '</td>' +
          '<td>' + (s.avg != null ? dur(s.avg) : '—') + '</td><td>' + (s.fastest != null ? dur(s.fastest) : '—') + '</td><td>' + (s.avgRes != null ? dur(s.avgRes) : '—') + '</td></tr>';
      });
      html += '</tbody></table>';
    }
    html += '</div>';
    d.innerHTML = html;
  }

  /* ------------------------------------------------------------ open / close */
  function openMenu(msg) {
    applyState(msg.state);
    if (msg.view) S.view = msg.view;
    if (msg.reportId) {
      S.sel = msg.reportId;
      S.view = msg.state.isStaff ? (report(msg.reportId) && report(msg.reportId).claimedByMe ? 'mine' : 'queue') : 'myreports';
      if (!report(msg.reportId)) S.view = msg.state.isStaff ? 'queue' : 'myreports';
    }
    S.open = true; S.notice = null; S.resolving = false;
    $('app').classList.remove('hidden');
    render();
    if (S.tick) clearInterval(S.tick);
    S.tick = setInterval(function () { if (S.open && S.view !== 'new' && !document.activeElement.matches('input,textarea')) render(); }, 10000);
  }
  function hideMenu() {
    S.open = false;
    $('app').classList.add('hidden');
    if (S.tick) { clearInterval(S.tick); S.tick = null; }
  }

  window.addEventListener('message', function (e) {
    var m = e.data || {};
    if (m.action === 'open')  openMenu(m);
    else if (m.action === 'state' && S.open) { applyState(m.state); render(); }
    else if (m.action === 'close') hideMenu();
    else if (m.action === 'toast' && m.toast) toast(m.toast);
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && S.open) closeMenu(); });
  $('btn-close').onclick = closeMenu;
})();
