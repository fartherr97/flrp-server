export type Status = 'open' | 'claimed' | 'resolved';
export interface Msg { name: string; staff: boolean; body: string; at: number }
export interface Report {
  id: number; category: string; categoryLabel: string; categoryColour: string;
  description: string; target?: string | null; status: Status;
  reporter: { name: string; src?: number; online: boolean };
  claimedBy?: string | null; claimedByMe: boolean; own: boolean;
  createdAt: number; claimedAt?: number | null; resolvedAt?: number | null; resolution?: string | null;
  messages: Msg[]; canReturn?: boolean;
}
export interface Category { id: string; label: string; colour: string }
export interface ReturnLocation { id: string; label: string; x: number; y: number; z: number; h?: number }
export interface State {
  ok: boolean; isStaff: boolean; canSelfClaim?: boolean; me: { src: number; name: string };
  staffOnline: number; reports: Report[]; categories: Category[]; returnLocations?: ReturnLocation[];
  logo: string; serverName: string;
  key: string; toastSeconds: number; maxDesc: number; maxMsg: number; maxOpen?: number; now: number;
}
export interface StaffStat { name: string; claims: number|string; resolved: number|string; avg_claim?: number|null; fastest?: number|null; avg_resolve?: number|null }
export interface Analytics {
  ok: boolean; staff: StaffStat[]; overall: any; today: { reports: number; avgClaim?: number|null; resolved: number };
  open: number; claimed: number; minClaims: number; now: number;
}
export interface Toast { kind?: string; title: string; body?: string; reportId?: number; seconds?: number }
