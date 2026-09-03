import { useEffect, useState } from 'react';
import { Lock, Check, Wallet, ShoppingCart, Store } from 'lucide-react';
import { AppHeader, Panel, Button, Badge, EmptyState, LoadingState, KeybindHint, cn, fetchNui, useNuiEvent, useEscape, isBrowser, mockMessage } from '@flrp/components';

interface Item { weaponName: string; displayName?: string; priceCents: number; owned?: boolean; eligible?: boolean; certRequired?: string; requiredPermission?: string; }
interface Catalog { catalog: Item[]; balanceCents: number }
const money = (c?: number) => '$' + ((Number(c) || 0) / 100).toLocaleString(undefined, { maximumFractionDigits: 2 });
const ERR: Record<string, string> = { busy: 'please wait a moment', too_far: 'you are too far from the store', bad_store: 'invalid store', bad_weapon: 'invalid weapon', not_available: 'not available here', need_cert: 'you lack the required certification', no_permission: 'you are not permitted to buy this', already_owned: 'you already own this', insufficient_funds: 'not enough money', ownership_failed: 'could not grant weapon (refunded)', no_player: 'player error' };

export function App() {
  const [open, setOpen] = useState(false);
  const [store, setStore] = useState<{ label?: string }>({});
  const [cat, setCat] = useState<Catalog | null>(null);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);
  const [buying, setBuying] = useState<string | null>(null);

  const close = () => { setOpen(false); fetchNui('close'); };
  useEscape(close, open);
  useNuiEvent<{ store: any }>('open', (d) => { setStore(d.store || {}); setOpen(true); setCat(null); setNotice(null); });
  useNuiEvent<Catalog>('catalog', (d) => { setCat({ catalog: d.catalog || [], balanceCents: d.balanceCents }); setBuying(null); });
  useNuiEvent<{ ok: boolean; result: any }>('purchaseResult', (d) => {
    setBuying(null);
    setNotice(d.ok ? { ok: true, text: `Purchased ${d.result?.weapon || ''}`.trim() } : { ok: false, text: 'Purchase failed: ' + (ERR[d.result] || String(d.result || 'unknown error')) });
  });
  useEffect(() => { if (isBrowser()) { mockMessage('open', { store: { label: 'Ammu-Nation' } }); mockMessage('catalog', MOCK); } }, []);

  if (!open) return null;
  const buy = (it: Item) => { setBuying(it.weaponName); setNotice(null); fetchNui('buy', { weaponName: it.weaponName }); };

  return (
    <div className="absolute inset-0 flex items-center justify-center animate-flrp-in">
      <div className="flex max-h-[86vh] w-[560px] max-w-[92vw] flex-col overflow-hidden rounded-lg border border-border bg-bg shadow-xl shadow-black/40 animate-flrp-rise">
        <AppHeader title={store.label || 'Gun Store'} subtitle="Firearms & equipment" onClose={close}
          right={<Badge tone="success"><Wallet className="size-3" />{cat ? money(cat.balanceCents) : '—'}</Badge>} />
        {notice && <div className={cn('mx-4 mt-3 rounded-sm px-3 py-2 text-[13px] font-medium', notice.ok ? 'bg-success/15 text-success' : 'bg-danger/15 text-danger')}>{notice.text}</div>}
        <div className="min-h-0 flex-1 overflow-y-auto p-4">
          {!cat ? <LoadingState label="Loading catalog…" />
            : cat.catalog.length === 0 ? <EmptyState icon={<Store />} title="Nothing in stock" hint="No weapons are available here right now." />
            : <div className="flex flex-col gap-1.5">
                {cat.catalog.map((it) => {
                  const afford = (cat.balanceCents || 0) >= (it.priceCents || 0);
                  const locked = !it.owned && !it.eligible;
                  const meta = [it.certRequired && `Requires ${it.certRequired}`, it.requiredPermission && `Perm: ${it.requiredPermission}`].filter(Boolean).join('  ·  ');
                  return (
                    <Panel key={it.weaponName} className="flex items-center gap-3 p-2.5 hover:bg-panel-hover">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2 font-semibold">
                          {it.displayName || it.weaponName}
                          {it.owned && <Badge tone="success"><Check className="size-3" />Owned</Badge>}
                          {locked && <Badge tone="danger"><Lock className="size-3" />Locked</Badge>}
                        </div>
                        <div className="text-2xs text-fg-muted">{meta || it.weaponName}</div>
                      </div>
                      <div className="text-right text-sm font-bold tabular-nums text-fg">{money(it.priceCents)}</div>
                      <Button variant={it.owned || locked ? 'ghost' : 'primary'} size="sm"
                        disabled={!!it.owned || locked || !afford || buying === it.weaponName}
                        onClick={() => buy(it)}>
                        {it.owned ? 'Owned' : buying === it.weaponName ? 'Buying…' : !afford ? 'Too expensive' : <><ShoppingCart />Buy</>}
                      </Button>
                    </Panel>
                  );
                })}
              </div>}
        </div>
        <footer className="flex items-center border-t border-border-soft bg-panel px-4 py-2.5">
          <KeybindHint keys="Esc">Close</KeybindHint>
          <span className="ml-auto text-2xs font-medium text-fg-muted">Server re-validates every purchase</span>
        </footer>
      </div>
    </div>
  );
}
const MOCK: Catalog = { balanceCents: 250000, catalog: [
  { weaponName: 'WEAPON_COMBATPISTOL', displayName: 'Combat Pistol', priceCents: 45000, eligible: true },
  { weaponName: 'WEAPON_CARBINERIFLE', displayName: 'Carbine Rifle', priceCents: 320000, eligible: false, certRequired: 'Cert Civ III' },
  { weaponName: 'WEAPON_PUMPSHOTGUN', displayName: 'Pump Shotgun', priceCents: 90000, owned: true },
] };
