import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { MessageSquare, Eye, X, Send, PenSquare, ArrowLeft, Circle, Search } from 'lucide-react';
import {
  AppHeader, Tabs, Panel, Button, Input, EmptyState, Badge,
  fetchNui, useNuiEvent, useEscape, isBrowser, mockMessage,
} from '@flrp/components';
import type { Convo, ThreadMsg, LiveMsg, MonitorMsg, OnlineP, OpenState, ThreadState } from './types';

const req = <T,>(action: string, payload: Record<string, unknown> = {}, mock?: T) =>
  fetchNui<T>('req', { action, payload }, mock);

const clock = (ts: number) =>
  new Date(ts * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

export function App() {
  const [open, setOpen] = useState(false);
  const [me, setMe] = useState<{ id: number; name: string } | null>(null);
  const [isStaff, setIsStaff] = useState(false);
  const [maxLen, setMaxLen] = useState(300);
  const [tab, setTab] = useState<'chats' | 'monitor'>('chats');

  const [convos, setConvos] = useState<Convo[]>([]);
  const [online, setOnline] = useState<OnlineP[]>([]);
  const [monitor, setMonitor] = useState<MonitorMsg[]>([]);

  const [selKey, setSelKey] = useState<string | null>(null);
  const [peerName, setPeerName] = useState('');
  const [peerOnline, setPeerOnline] = useState(false);
  const [thread, setThread] = useState<ThreadMsg[]>([]);

  const [composing, setComposing] = useState(false);
  const [pickQuery, setPickQuery] = useState('');
  const [draft, setDraft] = useState('');
  const [err, setErr] = useState<string | null>(null);

  const selectAfterSend = useRef(false);
  const scroller = useRef<HTMLDivElement>(null);
  const monScroller = useRef<HTMLDivElement>(null);

  const close = useCallback(() => { fetchNui('close'); setOpen(false); }, []);
  useEscape(close, open);

  const scrollThread = () => requestAnimationFrame(() => {
    if (scroller.current) scroller.current.scrollTop = scroller.current.scrollHeight;
  });

  useNuiEvent<{ state: OpenState }>('open', (d) => {
    const s = d.state;
    setMe(s.me); setIsStaff(s.isStaff); setMaxLen(s.maxLength || 300);
    setConvos(s.conversations || []); setOnline(s.online || []); setMonitor(s.monitor || []);
    setTab('chats'); setSelKey(null); setThread([]); setComposing(false); setErr(null);
    setOpen(true);
  });
  useNuiEvent('close', () => setOpen(false));

  // Upsert a conversation from a live message (bump to top).
  const bump = useCallback((key: string, name: string, text: string, ts: number, fromMe: boolean) => {
    setConvos((cs) => {
      const rest = cs.filter((c) => c.key !== key);
      const prev = cs.find((c) => c.key === key);
      return [{ key, peerName: name, peerId: prev?.peerId ?? null, lastText: text, lastTs: ts, fromMe }, ...rest];
    });
  }, []);

  useNuiEvent<{ message: LiveMsg }>('incoming', (d) => {
    const m = d.message;
    bump(m.fromKey, m.fromName, m.text, m.ts, false);
    setSelKey((k) => {
      if (k === m.fromKey) { setThread((t) => [...t, { mine: false, fromName: m.fromName, text: m.text, ts: m.ts }]); scrollThread(); }
      return k;
    });
  });
  useNuiEvent<{ message: LiveMsg }>('sent', (d) => {
    const m = d.message;
    bump(m.toKey, m.toName, m.text, m.ts, true);
    if (selectAfterSend.current) {
      selectAfterSend.current = false;
      selectConvo(m.toKey, m.toName);
    } else {
      setSelKey((k) => {
        if (k === m.toKey) { setThread((t) => [...t, { mine: true, fromName: m.fromName, text: m.text, ts: m.ts }]); scrollThread(); }
        return k;
      });
    }
  });
  useNuiEvent<{ message: MonitorMsg }>('monitor', (d) => {
    setMonitor((ms) => [...ms.slice(-200), d.message]);
    requestAnimationFrame(() => { if (monScroller.current) monScroller.current.scrollTop = monScroller.current.scrollHeight; });
  });

  const selectConvo = useCallback(async (key: string, name: string) => {
    setSelKey(key); setPeerName(name); setComposing(false); setErr(null); setThread([]);
    const r = await req<ThreadState>('thread', { key }, undefined);
    if (r && r.ok) { setThread(r.messages); setPeerName(r.peer.peerName || name); setPeerOnline(!!r.peer.peerId); scrollThread(); }
  }, []);

  const sendTo = async (payload: Record<string, unknown>) => {
    const text = draft.trim();
    if (!text) return;
    setErr(null); setDraft('');
    const r = await req<{ ok: boolean; error?: string }>('send', { ...payload, text });
    if (!r?.ok) { setErr(r?.error || 'Failed to send.'); setDraft(text); }
  };
  const sendReply = () => selKey && sendTo({ key: selKey });
  const startWith = (id: number) => { selectAfterSend.current = true; sendTo({ toId: id }); };

  useEffect(() => { if (open) scrollThread(); }, [open, selKey]);

  // Dev harness.
  useEffect(() => {
    if (!isBrowser()) return;
    const now = Math.floor(Date.now() / 1000);
    mockMessage('open', { state: {
      ok: true, me: { id: 7, name: '7 | Deputy | Mike' }, isStaff: true, maxLength: 300, now,
      conversations: [
        { key: 'c1', peerName: '12 | Trooper | Alex', peerId: 12, lastText: 'On my way to the 10-50 now', lastTs: now - 40, fromMe: false },
        { key: 'c2', peerName: '3 | Dispatch | Sam', peerId: 3, lastText: 'Copy, units en route', lastTs: now - 600, fromMe: true },
      ],
      online: [{ id: 12, name: '12 | Trooper | Alex' }, { id: 3, name: '3 | Dispatch | Sam' }, { id: 21, name: '21 | Civilian | Jordan' }],
      monitor: [
        { fromName: '12 | Trooper | Alex', toName: '7 | Deputy | Mike', text: 'On my way to the 10-50 now', ts: now - 40 },
        { fromName: '21 | Civilian | Jordan', toName: '3 | Dispatch | Sam', text: 'Where do I pay my ticket?', ts: now - 120 },
      ],
    } });
    setTimeout(() => mockMessage('__noop', {}), 0);
  }, []);
  // Auto-open first thread in dev.
  useEffect(() => { if (isBrowser() && convos.length && !selKey) selectConvo('c1', '12 | Trooper | Alex'); }, [convos.length]);

  const pick = useMemo(() => {
    const q = pickQuery.trim().toLowerCase();
    const list = online.filter((o) => o.id !== me?.id);
    return q ? list.filter((o) => String(o.id).includes(q) || o.name.toLowerCase().includes(q)) : list;
  }, [online, pickQuery, me?.id]);

  if (!open) return null;

  const tabs = [
    { id: 'chats' as const, label: 'Chats', icon: <MessageSquare /> },
    ...(isStaff ? [{ id: 'monitor' as const, label: `Monitor${monitor.length ? ` · ${monitor.length}` : ''}`, icon: <Eye /> }] : []),
  ];

  return (
    <div className="absolute inset-0 flex items-center justify-center animate-flrp-in">
      <div className="flex h-[64vh] max-h-[680px] w-[860px] max-w-[95vw] flex-col overflow-hidden rounded-lg border border-border bg-bg shadow-xl shadow-black/40 animate-flrp-rise">
        <AppHeader title="Messages" subtitle={me ? `You are ${me.name}` : undefined}
          right={<Badge tone="neutral">{me ? `ID ${me.id}` : ''}</Badge>} onClose={close} />
        <div className="px-4 pt-2"><Tabs tabs={tabs} value={tab} onChange={setTab} /></div>

        {tab === 'chats' ? (
          <div className="grid min-h-0 flex-1 grid-cols-[248px_1fr]">
            {/* conversation list */}
            <div className="flex min-h-0 flex-col border-r border-border-soft">
              <div className="p-2.5">
                <Button variant="outline" className="w-full justify-start" onClick={() => { setComposing(true); setSelKey(null); setPickQuery(''); }}>
                  <PenSquare /> New message
                </Button>
              </div>
              <div className="min-h-0 flex-1 space-y-1 overflow-y-auto px-2 pb-2">
                {convos.length === 0 ? (
                  <div className="px-2 py-6 text-center text-xs text-fg-faint">No conversations yet.</div>
                ) : convos.map((c) => (
                  <button key={c.key} onClick={() => selectConvo(c.key, c.peerName)}
                    className={`w-full rounded-sm border px-3 py-2 text-left transition-colors ${
                      selKey === c.key ? 'border-primary/50 bg-panel-hover' : 'border-transparent hover:bg-panel-hover'}`}>
                    <div className="flex items-center gap-1.5">
                      <span className="truncate text-[13px] font-bold">{c.peerName}</span>
                      {c.peerId ? <Circle className="ml-auto size-2 shrink-0 fill-success text-success" /> : null}
                    </div>
                    <div className="mt-0.5 flex items-center gap-1 text-2xs text-fg-muted">
                      <span className="truncate">{c.fromMe ? 'You: ' : ''}{c.lastText}</span>
                      <span className="ml-auto shrink-0 tabular-nums text-fg-faint">{clock(c.lastTs)}</span>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* thread / composer */}
            <div className="flex min-h-0 flex-col">
              {composing ? (
                <NewMessage pick={pick} query={pickQuery} setQuery={setPickQuery}
                  draft={draft} setDraft={setDraft} maxLen={maxLen} err={err}
                  onCancel={() => setComposing(false)} onSend={startWith} />
              ) : selKey ? (
                <>
                  <div className="flex items-center gap-2 border-b border-border-soft px-4 py-2.5">
                    <span className="text-[13px] font-bold">{peerName}</span>
                    <Badge tone={peerOnline ? 'success' : 'neutral'} dot>{peerOnline ? 'Online' : 'Offline'}</Badge>
                  </div>
                  <div ref={scroller} className="min-h-0 flex-1 space-y-1.5 overflow-y-auto p-4">
                    {thread.length === 0 ? (
                      <div className="pt-8 text-center text-xs text-fg-faint">No messages yet — say hello.</div>
                    ) : thread.map((m, i) => <Bubble key={i} m={m} />)}
                  </div>
                  <Composer draft={draft} setDraft={setDraft} maxLen={maxLen} err={err} disabled={!peerOnline}
                    placeholder={peerOnline ? `Message ${peerName}…` : 'They are offline'} onSend={sendReply} />
                </>
              ) : (
                <EmptyState icon={<MessageSquare />} title="Select a conversation" hint="…or start a new message." />
              )}
            </div>
          </div>
        ) : (
          <div ref={monScroller} className="min-h-0 flex-1 space-y-1 overflow-y-auto p-4">
            <div className="mb-1 px-1 text-2xs text-fg-muted">Live feed of every private message on the server.</div>
            {monitor.length === 0 ? (
              <EmptyState icon={<Eye />} title="No messages yet" hint="PMs will appear here as they happen." />
            ) : monitor.map((m, i) => (
              <Panel key={i} className="flex items-start gap-2 px-3 py-2 text-[13px]">
                <span className="shrink-0 tabular-nums text-2xs text-fg-faint">{clock(m.ts)}</span>
                <div className="min-w-0">
                  <span className="font-bold">{m.fromName}</span>
                  <span className="text-fg-faint"> → </span>
                  <span className="font-bold">{m.toName}</span>
                  <div className="text-fg-muted">{m.text}</div>
                </div>
              </Panel>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Bubble({ m }: { m: ThreadMsg }) {
  return (
    <div className={`flex ${m.mine ? 'justify-end' : 'justify-start'}`}>
      <div className={`max-w-[76%] rounded-lg px-3 py-1.5 text-[13px] ${
        m.mine ? 'rounded-br-sm bg-primary text-primary-fg' : 'rounded-bl-sm bg-panel text-fg'}`}>
        <div className="whitespace-pre-wrap break-words">{m.text}</div>
        <div className={`mt-0.5 text-right text-[10px] tabular-nums ${m.mine ? 'text-primary-fg/70' : 'text-fg-faint'}`}>{clock(m.ts)}</div>
      </div>
    </div>
  );
}

function Composer({ draft, setDraft, maxLen, err, disabled, placeholder, onSend }: {
  draft: string; setDraft: (s: string) => void; maxLen: number; err: string | null;
  disabled?: boolean; placeholder: string; onSend: () => void;
}) {
  return (
    <div className="border-t border-border-soft p-2.5">
      {err && <div className="mb-1.5 rounded-sm bg-danger/15 px-3 py-1.5 text-2xs font-medium text-danger">{err}</div>}
      <div className="flex items-center gap-2">
        <Input value={draft} maxLength={maxLen} placeholder={placeholder} disabled={disabled}
          onChange={(e) => setDraft(e.target.value.slice(0, maxLen))}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); onSend(); } }} />
        <Button variant="primary" onClick={onSend} disabled={disabled || !draft.trim()}><Send /> Send</Button>
      </div>
    </div>
  );
}

function NewMessage({ pick, query, setQuery, draft, setDraft, maxLen, err, onCancel, onSend }: {
  pick: OnlineP[]; query: string; setQuery: (s: string) => void;
  draft: string; setDraft: (s: string) => void; maxLen: number; err: string | null;
  onCancel: () => void; onSend: (id: number) => void;
}) {
  const [target, setTarget] = useState<OnlineP | null>(null);
  return (
    <>
      <div className="flex items-center gap-2 border-b border-border-soft px-4 py-2.5">
        <Button size="sm" variant="ghost" onClick={onCancel}><ArrowLeft /></Button>
        <span className="text-[13px] font-bold">New message</span>
      </div>
      {target ? (
        <div className="flex min-h-0 flex-1 flex-col">
          <div className="flex items-center gap-2 px-4 py-2.5">
            <span className="text-xs text-fg-muted">To</span>
            <Badge tone="neutral">{target.name}</Badge>
            <Button size="sm" variant="ghost" onClick={() => setTarget(null)}>Change</Button>
          </div>
          <div className="flex-1" />
          <Composer draft={draft} setDraft={setDraft} maxLen={maxLen} err={err}
            placeholder={`Message ${target.name}…`} onSend={() => onSend(target.id)} />
        </div>
      ) : (
        <div className="flex min-h-0 flex-1 flex-col">
          <div className="p-3 pb-1.5">
            <div className="relative">
              <Search className="pointer-events-none absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-fg-faint" />
              <Input className="pl-8" placeholder="Search players by name or ID…" value={query} onChange={(e) => setQuery(e.target.value)} />
            </div>
          </div>
          <div className="min-h-0 flex-1 space-y-1 overflow-y-auto px-3 pb-3">
            {pick.length === 0 ? (
              <div className="px-2 py-6 text-center text-xs text-fg-faint">No players online.</div>
            ) : pick.map((o) => (
              <button key={o.id} onClick={() => setTarget(o)}
                className="flex w-full items-center gap-2 rounded-sm border border-transparent px-3 py-2 text-left hover:bg-panel-hover">
                <Badge tone="neutral">{o.id}</Badge>
                <span className="truncate text-[13px] font-semibold">{o.name}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </>
  );
}
