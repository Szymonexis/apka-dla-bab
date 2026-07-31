import { isTauri } from '@tauri-apps/api/core';
import {
  cancel,
  createChannel,
  Importance,
  isPermissionGranted,
  pending,
  requestPermission,
  Schedule,
  sendNotification,
} from '@tauri-apps/plugin-notification';

import type { Reminder } from './models';

// Lokalne alarmy: przypomnienia dzwonią na telefonie o właściwej porze nawet
// bez internetu i przy zamkniętej aplikacji (harmonogram trzyma system).
// To pierwszy poziom powiadomień - zero infrastruktury. Drugi (opcjonalny)
// to push przez self-hostowany ntfy, obsługiwany w całości przez backend.

let channelReady = false;

async function init(): Promise<boolean> {
  let granted = await isPermissionGranted();
  if (!granted) granted = (await requestPermission()) === 'granted';
  if (!granted) return false;
  if (!channelReady) {
    try {
      await createChannel({
        id: 'przypomnienia',
        name: 'Przypomnienia',
        importance: Importance.High,
      });
    } catch {
      // kanały istnieją tylko na Androidzie
    }
    channelReady = true;
  }
  return true;
}

/**
 * Przeplanowuje alarmy tak, by odpowiadały aktualnej liście przypomnień.
 * Wołane po każdym pobraniu/zmianie przypomnień. Awaria powiadomień nie może
 * wywalić aplikacji, stąd szeroki catch (np. desktop bez harmonogramu).
 */
export async function syncReminderNotifications(reminders: Reminder[]): Promise<void> {
  if (!isTauri()) return;
  try {
    if (!(await init())) return;
    try {
      const scheduled = await pending();
      if (scheduled.length > 0) await cancel(scheduled.map((n) => n.id));
    } catch {
      // brak zaplanowanych albo platforma bez harmonogramu
    }
    const now = Date.now();
    let id = 1;
    for (const r of reminders) {
      if (r.done) continue;
      const at = new Date(r.remindAt);
      if (at.getTime() <= now) continue;
      sendNotification({
        id: id++,
        channelId: 'przypomnienia',
        title: 'Przypomnienie 🔔',
        body: r.title,
        schedule: Schedule.at(at),
      });
    }
  } catch {
    // powiadomienia to dodatek - cicho ignorujemy (np. brak zgody)
  }
}
