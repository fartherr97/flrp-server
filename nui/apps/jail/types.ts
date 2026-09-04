export interface JailPlayer { id: number; name: string; discord: string; total: number; jailed: boolean }
export interface Hospital { id: string; label: string }
export interface Perms { jail: boolean; hospitalize: boolean; leoHospitalize: boolean }
export interface State {
  ok: boolean; perms: Perms; players: JailPlayer[]; hospitals: Hospital[];
  logo: string; serverName: string;
  maxSeconds: number; defaultSeconds: number; hospitalSeconds: number; leoHospSeconds: number;
}
