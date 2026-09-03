import { useState } from 'react';
import { Hand, LogIn, ArrowDownToLine, Check, Send, MessageSquare } from 'lucide-react';
import { Panel, Button, Badge, StatusIndicator, Input } from '@flrp/components';
import { req, dur, ago, clock, statusTone } from '../lib';
import type { State, Report } from '../types';

export function ReportDetail({ state, report, onChange }:
  { state: State; report: Report | null; onChange: () => void }) {
  const [draft, setDraft] = useState('');
  const [resolving, setResolving] = useState(false);
  const [resNote, setResNote] = useState('');
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const staff = state.isStaff;

  if (!report) return (
    <div className="flex flex-1 flex-col items-center justify-center gap-2 p-8 text-center text-fg-faint">
      <MessageSquare className="size-7" />
      <div className="font-semibold text-fg-muted">Select a report</div>
      <div className="text-xs">{staff ? 'Claim it, message the player, teleport, resolve.' : 'Track its status and read replies from staff.'}</div>
    </div>
  );

  const act = async (action: string, payload: Record<string, unknown> = {}) => {
    if (busy) return; setBusy(true);
    const r = await req<any>(action, { id: report.id, ...payload });
    setBusy(false);
    if (!r.ok) return setNotice(r.error || 'Failed.');
    setNotice(null); onChange();
  };
  const send = () => { const v = draft.trim(); if (!v) return; setDraft(''); act('message', { body: v }); };
  const resolve = () => { act('resolve', { resolution: resNote.trim() }); setResolving(false); setResNote(''); };
  const canSelfBlock = report.own && !state.canSelfClaim;

  return (
    <div className="flex-1 space-y-3.5 overflow-y-auto p-5">
      {notice && <div className="rounded-sm bg-danger/15 px-3 py-2 text-[13px] font-medium text-danger">{notice}</div>}
      <div className="flex items-start gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2 text-xl font-bold">Report #{report.id}<StatusIndicator tone={statusTone(report.status)} label={report.status} /></div>
          <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-fg-muted">
            <Badge tone="neutral"><span className="size-1.5 rounded-full" style={{ background: report.categoryColour }} />{report.categoryLabel}</Badge>
            <span>by <b className="text-fg">{report.reporter.name}</b>{staff && report.reporter.src != null && <span className="text-fg-faint"> (id {report.reporter.src})</span>}</span>
            <Badge tone={report.reporter.online ? 'success' : 'danger'}>{report.reporter.online ? '● online' : '○ offline'}</Badge>
            {report.target && <span>against <b className="text-fg">{report.target}</b></span>}
            <span>{ago(report.createdAt)}</span>
          </div>
        </div>
        {staff && (
          <div className="ml-auto flex flex-wrap justify-end gap-2">
            {report.status === 'open' && (canSelfBlock
              ? <Badge tone="neutral" className="self-center">Your report — another staffer must claim it</Badge>
              : <Button variant="primary" onClick={() => act('claim')}><Hand />Claim</Button>)}
            {report.status === 'claimed' && report.claimedByMe && <Button variant="ghost" onClick={() => act('unclaim')}>Release</Button>}
            {report.status !== 'resolved' && <>
              <Button size="sm" disabled={!report.reporter.online} onClick={() => act('goto')}><LogIn />Go to</Button>
              <Button size="sm" disabled={!report.reporter.online} onClick={() => act('bring')}><ArrowDownToLine />Bring</Button>
              {!canSelfBlock && <Button variant="success" size="sm" onClick={() => setResolving(true)}><Check />Resolve</Button>}
            </>}
          </div>
        )}
      </div>

      {resolving && staff && report.status !== 'resolved' && (
        <Panel className="p-3">
          <div className="mb-1.5 text-2xs font-bold uppercase tracking-wider text-fg-faint">Resolution note (sent to the player)</div>
          <div className="flex gap-2">
            <Input autoFocus maxLength={255} value={resNote} onChange={(e) => setResNote(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && resolve()} placeholder="e.g. Spoke to both parties, warning issued." />
            <Button variant="success" onClick={resolve}>Confirm</Button>
            <Button variant="ghost" onClick={() => setResolving(false)}>Cancel</Button>
          </div>
        </Panel>
      )}

      <Panel className="p-3.5"><div className="mb-1.5 text-2xs font-bold uppercase tracking-wider text-fg-faint">Description</div><div className="whitespace-pre-wrap break-words text-[13px] leading-relaxed">{report.description}</div></Panel>

      <div className="grid grid-cols-3 gap-2.5">
        {[['Submitted', clock(report.createdAt), ago(report.createdAt)],
          ['Claimed', report.claimedAt ? dur(report.claimedAt - report.createdAt) : '—', report.claimedBy ? 'by ' + report.claimedBy : report.status === 'open' ? 'waiting' : ''],
          ['Resolved', report.resolvedAt ? dur(report.resolvedAt - (report.claimedAt || report.createdAt)) : '—', report.resolution || (report.resolvedAt ? 'closed' : '')]]
          .map(([l, v, s]) => (
          <Panel key={l as string} className="p-2.5"><div className="text-[10px] font-bold uppercase tracking-wider text-fg-faint">{l}</div><div className="mt-0.5 text-[15px] font-bold tabular-nums">{v}</div><div className="truncate text-2xs text-fg-muted">{s}</div></Panel>
        ))}
      </div>

      <Panel className="p-3.5">
        <div className="mb-2 text-2xs font-bold uppercase tracking-wider text-fg-faint">Conversation</div>
        <div className="flex flex-col gap-2">
          {report.messages.length === 0
            ? <div className="self-center text-xs italic text-fg-faint">No messages yet{staff ? ' — say hi to the player.' : ' — staff will reply here.'}</div>
            : report.messages.map((m, i) => (
              <div key={i} className={`max-w-[78%] break-words rounded-lg px-3 py-2 text-[13px] leading-snug ${m.staff ? 'self-end border border-primary/40 bg-primary/10' : 'bg-panel-hover'}`}>
                <div className={`mb-0.5 flex gap-2 text-2xs font-bold ${m.staff ? 'text-primary' : 'text-fg-muted'}`}><span>{m.name}{m.staff ? ' · staff' : ''}</span><span className="ml-auto font-medium text-fg-faint">{clock(m.at)}</span></div>{m.body}
              </div>
            ))}
        </div>
        {report.status !== 'resolved' && (
          <div className="mt-2.5 flex gap-2">
            <Input value={draft} maxLength={state.maxMsg} onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && send()} placeholder={staff ? `Message ${report.reporter.name}…` : 'Reply to staff…'} />
            <Button variant="primary" onClick={send}><Send />Send</Button>
          </div>
        )}
      </Panel>
    </div>
  );
}
