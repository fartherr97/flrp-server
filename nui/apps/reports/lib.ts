import { fetchNui } from '@flrp/components';
export const req = <T,>(action: string, payload: Record<string, unknown> = {}, mock?: T) =>
  fetchNui<T>('req', { action, payload }, mock);
export function dur(sec?: number | null) {
  if (sec == null) return '—';
  sec = Math.max(0, Math.floor(sec));
  if (sec < 60) return sec + 's';
  const m = Math.floor(sec / 60), s = sec % 60;
  if (m < 60) return `${m}m ${s < 10 ? '0' : ''}${s}s`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60 < 10 ? '0' : ''}${m % 60}m`;
}
export const ago = (ts?: number) => (ts ? dur(Date.now() / 1000 - ts) + ' ago' : '—');
export const clock = (ts?: number | null) =>
  ts ? new Date(ts * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '—';
/** vReports-style stamp: "14:05 9/9/2026" */
export const stamp = (ts?: number | null) => {
  if (!ts) return '—';
  const d = new Date(ts * 1000);
  const mm = d.getMinutes();
  return `${d.getHours()}:${mm < 10 ? '0' : ''}${mm} ${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`;
};
export const statusTone = (s: string): 'warning' | 'primary' | 'success' => (s === 'open' ? 'warning' : s === 'claimed' ? 'primary' : 'success');
const KEY = 'flrp_reports_notifications';
export const notificationsEnabled = () => { try { return localStorage.getItem(KEY) !== 'off'; } catch { return true; } };
export const setNotificationsEnabled = (on: boolean) => { try { localStorage.setItem(KEY, on ? 'on' : 'off'); } catch { /* ignore */ } };
