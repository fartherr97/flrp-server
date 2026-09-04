export interface Zone { id: number; name: string; x: number; y: number; z: number; radius: number; weapons: boolean; damage: boolean; vehicles: boolean }
export interface ZoneOption { key: 'weapons' | 'damage' | 'vehicles'; label: string; desc?: string }
export interface State {
  ok: boolean; owner: boolean; zones: Zone[]; options: ZoneOption[];
  minRadius: number; maxRadius: number; defaultRadius: number;
  logo: string; serverName: string;
}
