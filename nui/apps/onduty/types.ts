export interface RankOpt { id: string; label: string }
export interface DeptAvail { id: string; label: string; short: string; colour: string; requireCallsign: boolean; ranks: RankOpt[] }
export interface OnDutyView { entity: string; short: string; label: string; colour: string; rank: string; rankLabel: string; callsign: string; since: number }
export interface DutyState {
  ok: boolean; onDuty: OnDutyView | null; available: DeptAvail[]; counts: Record<string, number>;
  logo: string; serverName: string; key: string; callsignMax: number; now: number;
}
export interface UnitRow { src: number; name: string; callsign?: string; rank: string; since: number }
export interface UnitsDept { id: string; label: string; short: string; colour: string; count: number; units: UnitRow[] }
export interface UnitsState { ok: boolean; depts: UnitsDept[]; total: number; now: number; error?: string }
export interface Result<T> { ok: boolean; error?: string }
