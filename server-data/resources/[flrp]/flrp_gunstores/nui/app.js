/* ==========================================================================
   FLRP :: flrp_gunstores NUI logic
   --------------------------------------------------------------------------
   Presentation only. The server is authoritative for price, eligibility, and
   balance — this UI just displays what the server sends and forwards buy
   requests. Prices shown are informational; the server re-validates on buy.
   ========================================================================== */
(function () {
  'use strict';

  const root = document.getElementById('root');
  const catalogEl = document.getElementById('catalog');
  const balanceEl = document.getElementById('balance');
  const storeLabelEl = document.getElementById('store-label');
  const noticeEl = document.getElementById('notice');
  const closeBtn = document.getElementById('close');

  const RESOURCE = 'flrp_gunstores';

  function fmtMoney(cents) {
    const dollars = (Number(cents) || 0) / 100;
    return '$' + dollars.toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 });
  }

  function post(endpoint, data) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  function showNotice(msg, type) {
    noticeEl.textContent = msg;
    noticeEl.className = 'notice ' + (type || '');
    noticeEl.classList.remove('hidden');
  }
  function clearNotice() { noticeEl.classList.add('hidden'); }

  function open(store) {
    if (store && store.label) storeLabelEl.textContent = store.label;
    root.classList.remove('hidden');
    clearNotice();
    catalogEl.innerHTML = '<li class="empty">Loading catalog…</li>';
  }

  function close() {
    root.classList.add('hidden');
    post('close', {});
  }

  function renderCatalog(catalog, balanceCents) {
    balanceEl.textContent = fmtMoney(balanceCents);
    catalogEl.innerHTML = '';
    if (!catalog || catalog.length === 0) {
      catalogEl.innerHTML = '<li class="empty">No weapons are available here right now.</li>';
      return;
    }
    catalog.forEach((item) => {
      const li = document.createElement('li');
      li.className = 'item';

      const info = document.createElement('div');
      info.className = 'item-info';

      const name = document.createElement('div');
      name.className = 'item-name';
      name.textContent = item.displayName || item.weaponName;
      if (item.owned) name.appendChild(makeTag('Owned', 'owned'));
      else if (!item.eligible) name.appendChild(makeTag('Locked', 'locked'));
      info.appendChild(name);

      const meta = document.createElement('div');
      meta.className = 'item-meta';
      const bits = [];
      if (item.certRequired) bits.push('Requires: ' + item.certRequired);
      if (item.requiredPermission) bits.push('Perm: ' + item.requiredPermission);
      meta.textContent = bits.join('  ·  ') || item.weaponName;
      info.appendChild(meta);

      const price = document.createElement('div');
      price.className = 'item-price';
      price.textContent = fmtMoney(item.priceCents);

      const buy = document.createElement('button');
      buy.className = 'buy-btn';
      buy.textContent = item.owned ? 'Owned' : 'Buy';
      const affordable = (Number(balanceCents) || 0) >= (Number(item.priceCents) || 0);
      buy.disabled = item.owned || !item.eligible || !affordable;
      if (!item.owned && item.eligible && !affordable) buy.textContent = 'Too expensive';
      buy.addEventListener('click', () => {
        buy.disabled = true;
        buy.textContent = 'Buying…';
        post('buy', { weaponName: item.weaponName });
      });

      li.appendChild(info);
      li.appendChild(price);
      li.appendChild(buy);
      catalogEl.appendChild(li);
    });
  }

  function makeTag(text, cls) {
    const s = document.createElement('span');
    s.className = 'tag ' + cls;
    s.textContent = text;
    return s;
  }

  function purchaseResult(ok, result) {
    if (ok) {
      showNotice('Purchase successful: ' + (result && result.weapon ? result.weapon : ''), 'success');
    } else {
      showNotice('Purchase failed: ' + friendlyError(result), 'error');
    }
    // The client re-requests the catalog after a purchase attempt, so the
    // server pushes a fresh 'catalog' message (updated balance + owned flags).
  }

  function friendlyError(code) {
    const map = {
      busy: 'please wait a moment', too_far: 'you are too far from the store',
      bad_store: 'invalid store', bad_weapon: 'invalid weapon',
      not_available: 'not available here', need_cert: 'you lack the required certification',
      no_permission: 'you are not permitted to buy this', already_owned: 'you already own this',
      insufficient_funds: 'not enough money', ownership_failed: 'could not grant weapon (refunded)',
      no_player: 'player error',
    };
    return map[code] || String(code || 'unknown error');
  }

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    switch (d.action) {
      case 'open': open(d.store); break;
      case 'catalog': renderCatalog(d.catalog, d.balanceCents); break;
      case 'purchaseResult': purchaseResult(d.ok, d.result); break;
    }
  });

  document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape') close();
  });
  closeBtn.addEventListener('click', close);
})();
