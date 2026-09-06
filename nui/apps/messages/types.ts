export type Convo = {
  key: string;
  peerName: string;
  peerId?: number | null;
  lastText: string;
  lastTs: number;
  fromMe: boolean;
};

export type ThreadMsg = { mine: boolean; fromName: string; text: string; ts: number };
export type LiveMsg = { fromName: string; toName: string; text: string; ts: number; fromKey: string; toKey: string };
export type MonitorMsg = { fromName: string; toName: string; text: string; ts: number };
export type OnlineP = { id: number; name: string };

export type OpenState = {
  ok: boolean;
  me: { id: number; name: string };
  isStaff: boolean;
  maxLength: number;
  now: number;
  conversations: Convo[];
  online: OnlineP[];
  monitor?: MonitorMsg[];
};

export type ThreadState = {
  ok: boolean;
  error?: string;
  peer: { key: string; peerName: string; peerId?: number | null };
  messages: ThreadMsg[];
};
