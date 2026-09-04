export interface JailPlayer { id: number; name: string; discord: string; total: number; jailed: boolean }
export interface Hospital { id: string; label: string }
export interface Injury { id: string; label: string; seconds: number }
export interface Charge { id: string; name: string; class?: string; jailSeconds: number; fine?: number }
export interface Perms { jail: boolean; hospitalize: boolean; leoHospitalize: boolean }
export interface State {
  ok: boolean; perms: Perms; players: JailPlayer[];
  hospitals: Hospital[]; injuries: Injury[]; charges: Charge[];
  logo: string; serverName: string;
  maxSeconds: number; defaultSeconds: number; defaultInjury: string; leoHospSeconds: number;
}
