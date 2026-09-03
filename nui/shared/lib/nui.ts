/* FLRP NUI bridge — preserves the exact message contract the Lua already uses:
 *  inbound : window 'message' events { action, ... }
 *  outbound: fetch POST https://<resource>/<cb>  (RegisterNUICallback)
 * Nothing here changes any Lua event name. */
import { useEffect, useRef } from 'react';

export const RESOURCE: string =
  // @ts-ignore — provided by CEF in-game
  (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'flrp');

/** true only inside a normal browser (dev), false inside the FiveM CEF. */
export const isBrowser = (): boolean =>
  !(window as any).invokeNative && !(window as any).GetParentResourceName;

/** POST to a RegisterNUICallback. In the browser returns the dev mock. */
export async function fetchNui<T = any>(cb: string, data: unknown = {}, mock?: T): Promise<T> {
  if (isBrowser()) return (typeof mock !== 'undefined' ? mock : ({} as T));
  try {
    const res = await fetch(`https://${RESOURCE}/${cb}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return (await res.json()) as T;
  } catch {
    return ({ ok: false, error: 'No response from server.' } as unknown as T);
  }
}

/** Subscribe to a SendNUIMessage action. Handler kept in a ref so it never re-binds. */
export function useNuiEvent<T = any>(action: string, handler: (data: T) => void) {
  const saved = useRef(handler);
  saved.current = handler;
  useEffect(() => {
    const listener = (e: MessageEvent) => {
      const d = e.data || {};
      if (d.action === action || d.type === action) saved.current(d);
    };
    window.addEventListener('message', listener);
    return () => window.removeEventListener('message', listener);
  }, [action]);
}

/** Close on ESC (calls the given callback, usually a 'close' NUI callback). */
export function useEscape(onEsc: () => void, active = true) {
  useEffect(() => {
    if (!active) return;
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onEsc(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onEsc, active]);
}

/** Feed mock messages when running in a plain browser (dev only). */
export function mockMessage(action: string, payload: Record<string, unknown> = {}) {
  if (!isBrowser()) return;
  window.dispatchEvent(new MessageEvent('message', { data: { action, ...payload } }));
}
