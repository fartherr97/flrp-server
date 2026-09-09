import { useState } from 'react';
import { ArrowDownToLine, Check, Hand, History, LogIn, MapPin, Ruler, Send, Undo2, X } from 'lucide-react';
import { cn } from '@flrp/components';
import { VModal } from './VModal';
import { req, dur, stamp, clock } from '../lib';
import type { State, Report } from '../types';

const statusClass = (s: string) => (s === 'open' ? 'text-warning' : s === 'claimed' ? 'text-primary' : 'text-success');
const Label = ({ children }: { children: React.ReactNode }) => <p className="v-label">{children}</p>;

export function ReportDetail({ state, report, onClose, onChange }:
  { state: State; report: Report | null; onClose: () => void; onChange: () => void }) {
  const [msgOpen, setMsgOpen] = useState(false);
  const [draft, setDraft] = useState('');
  const [resolving, setResolving] = useState(false);
  const [resNote, setResNote] = useState('');
  const [returning, setReturning] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  if (!report) return null;
  const staff = state.isStaff;
  const canSelfBlock = report.own && !state.canSelfClaim;
  const live = report.status !== 'resolved';

  const act = async (action: string, payload: Record<string, unknown> = {}) => {
    if (busy) return false; setBusy(true);
    const r = await req<any>(action, { id: report.id, ...payload });
    setBusy(false);
    if (!r.ok) { setNotice(r.error || 'Failed.'); return false; }
    setNotice(null); onChange(); return true;
  };
  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    const v = draft.trim(); if (!v) return;
    if (await act('message', { body: v })) { setDraft(''); setMsgOpen(false); }
  };
  const resolve = async (e: React.FormEvent) => {
    e.preventDefault();
    if (await act('resolve', { resolution: resNote.trim() })) { setResolving(false); setResNote(''); onClose(); }
  };

  const footer = (
    <>
      {live && <button className="v-btn v-btn-sm v-btn-panel" onClick={() => setMsgOpen(true)}><Send />Send Message</button>}
      {staff && live && <>
        {report.status === 'open' && !canSelfBlock && <button className="v-btn v-btn-sm v-btn-panel" onClick={() => act('claim')}><Hand />Claim</button>}
        {report.status === 'claimed' && report.claimedByMe && <button className="v-btn v-btn-sm v-btn-panel" onClick={() => act('unclaim')}><Undo2 />Release</button>}
        <button className="v-btn v-btn-sm v-btn-panel" disabled={!report.reporter.online} onClick={() => act('goto')}><LogIn />Goto</button>
        <button className="v-btn v-btn-sm v-btn-panel" disabled={!report.reporter.online} onClick={() => act('bring')}><ArrowDownToLine />Bring</button>
        <button className="v-btn v-btn-sm v-btn-panel" disabled={!report.reporter.online} onClick={() => setReturning((v) => !v)}><History />Return</button>
        {!canSelfBlock && <button className="v-btn v-btn-sm" onClick={() => setResolving(true)}><Check />Conclude Report</button>}
      </>}
      {!live && <button className="v-btn v-btn-sm" onClick={onClose}><X />Close</button>}
    </>
  );

  return (
    <>
      <VModal open onClose={onClose} width="w-[640px]" footer={footer}>
        <div className="flex flex-col gap-1 rounded p-1">
          <div className="flex items-center gap-2">
            <p className="text-base font-semibold">Report #{report.id}</p>
            <div className="ml-auto flex items-center gap-2">
              <span className={`v-tag font-semibold capitalize ${statusClass(report.status)}`}>{report.status}</span>
              <span className="v-tag" style={{ color: report.categoryColour }}>{report.categoryLabel}</span>
              <span className="v-tag opacity-60">{stamp(report.createdAt)}</span>
            </div>
          </div>
          {notice && <div className="mt-1 rounded border-2 border-danger/40 bg-danger/10 px-3 py-2 text-sm font-medium text-danger">{notice}</div>}
          {canSelfBlock && staff && live && <div className="mt-1 rounded border-2 border-border bg-bg px-3 py-2 text-xs text-fg-muted">Your own report — another staff member has to claim and conclude it.</div>}

          <div className="mt-2 flex flex-col gap-2 rounded px-2 py-1">
            <div className="grid grid-cols-2 gap-x-6 gap-y-2">
              <div>
                <Label>Player Name</Label>
                <p className="text-sm text-fg-muted">{report.reporter.name}{staff && report.reporter.src != null && <span className="text-fg-faint"> (ID {report.reporter.src})</span>}
                  <span className={cn('ml-2 text-xs font-semibold', report.reporter.online ? 'text-success' : 'text-danger')}>{report.reporter.online ? '● online' : '○ offline'}</span></p>
              </div>
              <div>
                <Label>Player Involved</Label>
                <p className="text-sm text-fg-muted">{report.target || '—'}</p>
              </div>
              <div>
                <Label>Claimed</Label>
                <p className="text-sm text-fg-muted">{report.claimedBy ? `${report.claimedByMe ? 'you' : report.claimedBy} · after ${dur((report.claimedAt || 0) - report.createdAt)}` : 'waiting for staff'}</p>
              </div>
              <div>
                <Label>{report.resolvedAt ? 'Concluded' : 'Submitted'}</Label>
                <p className="text-sm text-fg-muted">{report.resolvedAt ? `${clock(report.resolvedAt)}${report.resolution ? ' · ' + report.resolution : ''}` : stamp(report.createdAt)}</p>
              </div>
            </div>

            <Label>Report Description</Label>
            <p className="whitespace-pre-wrap break-words rounded border-2 border-border bg-bg px-3 py-2 text-sm leading-relaxed text-fg-muted">{report.description}</p>

            <Label>Report Messages</Label>
            <div className="h-[20dvh] overflow-y-auto rounded border-2 border-border bg-bg">
              <div className="flex flex-col gap-2 p-2">
                {report.messages.length === 0
                  ? <p className="py-4 text-center text-xs italic text-fg-faint">No messages yet{staff ? ' — say hi to the player.' : ' — staff will reply here.'}</p>
                  : report.messages.map((m, i) => (
                    <div key={i} className="rounded-[2px] border-2 border-border bg-panel px-2 py-1">
                      <div className="flex items-start gap-2 text-sm">
                        <span className={cn('shrink-0 font-semibold', m.staff ? 'text-primary' : 'text-fg')}>{m.name}{m.staff ? ' (Staff)' : ''}:</span>
                        <span className="min-w-0 break-words text-fg-muted">{m.body}</span>
                        <span className="ml-auto shrink-0 rounded-[2px] border border-border bg-bg px-2 py-0.5 text-xs opacity-50">{clock(m.at)}</span>
                      </div>
                    </div>
                  ))}
              </div>
            </div>

            {report.nearby && report.nearby.length > 0 && (
              <>
                <Label>Nearest Players</Label>
                <div className="max-h-[30dvh] overflow-y-auto rounded border-2 border-border bg-bg">
                  <div className="grid grid-cols-3 gap-2 p-3 text-sm">
                    {report.nearby.map((p) => (
                      <div key={p.id} className="flex items-center gap-1 rounded-[2px] bg-panel px-2 py-1">
                        <span className="text-fg-muted">[{p.id}]</span>
                        <span className="truncate">{p.name}</span>
                        <span className="ml-auto inline-flex shrink-0 items-center gap-1 rounded-[2px] bg-bg px-1 text-xs text-fg-muted"><Ruler className="size-3" />{Math.round(p.distance)}m</span>
                      </div>
                    ))}
                  </div>
                </div>
              </>
            )}

            {returning && staff && live && (
              <div className="rounded border-2 border-border bg-bg p-2">
                <div className="mb-2 flex items-center justify-between"><span className="text-xs font-semibold">Return {report.reporter.name} to…</span>
                  <button className="text-xs text-fg-muted hover:text-fg" onClick={() => setReturning(false)}>Cancel</button></div>
                <div className="flex flex-wrap gap-2">
                  <button className="v-btn v-btn-sm v-btn-panel" disabled={!report.canReturn} title={report.canReturn ? '' : 'Bring them first to save a spot'}
                    onClick={async () => { if (await act('returnPlayer', { dest: 'previous' })) setReturning(false); }}><History />Previous spot</button>
                  {(state.returnLocations ?? []).map((loc) => (
                    <button key={loc.id} className="v-btn v-btn-sm v-btn-panel" onClick={async () => { if (await act('returnPlayer', { dest: loc.id })) setReturning(false); }}><MapPin />{loc.label}</button>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </VModal>

      <VModal open={msgOpen} onClose={() => setMsgOpen(false)} width="w-[440px]" hideClose>
        <p className="mb-1 text-sm font-semibold">Send a message</p>
        <form className="flex items-center gap-1" onSubmit={send}>
          <input autoFocus className="v-input h-9" value={draft} maxLength={state.maxMsg} onChange={(e) => setDraft(e.target.value)} placeholder="Message…" />
          <button type="submit" className="v-btn h-9 rounded-[2px] px-3"><Check /></button>
        </form>
      </VModal>

      <VModal open={resolving} onClose={() => setResolving(false)} width="w-[460px]" hideClose>
        <p className="mb-1 text-sm font-semibold">Conclude report #{report.id}</p>
        <p className="mb-2 text-xs text-fg-muted">The note is sent to the player and kept on the report.</p>
        <form className="flex items-center gap-1" onSubmit={resolve}>
          <input autoFocus className="v-input h-9" value={resNote} maxLength={255} onChange={(e) => setResNote(e.target.value)} placeholder="e.g. Spoke to both parties, warning issued." />
          <button type="submit" className="v-btn h-9 rounded-[2px] px-3"><Check /></button>
        </form>
      </VModal>
    </>
  );
}
