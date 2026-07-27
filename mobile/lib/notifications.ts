import * as Notifications from 'expo-notifications';

import type { Reminder } from './models';

// Lokalne alarmy: przypomnienia dzwonią na telefonie o właściwej porze nawet
// bez internetu i przy zamkniętej aplikacji. To pierwszy poziom powiadomień -
// zero infrastruktury. Drugi (opcjonalny) to push przez self-hostowany ntfy,
// obsługiwany w całości przez backend.

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

let ready = false;

async function init(): Promise<boolean> {
  const perm = await Notifications.requestPermissionsAsync();
  if (!perm.granted) return false;
  if (!ready) {
    await Notifications.setNotificationChannelAsync('przypomnienia', {
      name: 'Przypomnienia',
      importance: Notifications.AndroidImportance.MAX,
    });
    ready = true;
  }
  return true;
}

/**
 * Przeplanowuje alarmy tak, by odpowiadały aktualnej liście przypomnień.
 * Wołane po każdym pobraniu/zmianie przypomnień. Awaria powiadomień nie może
 * wywalić aplikacji, stąd szeroki catch.
 */
export async function syncReminderNotifications(reminders: Reminder[]): Promise<void> {
  try {
    if (!(await init())) return;
    await Notifications.cancelAllScheduledNotificationsAsync();
    const now = Date.now();
    for (const r of reminders) {
      if (r.done) continue;
      const at = new Date(r.remindAt);
      if (at.getTime() <= now) continue;
      await Notifications.scheduleNotificationAsync({
        content: { title: 'Przypomnienie 🔔', body: r.title, sound: true },
        trigger: {
          type: Notifications.SchedulableTriggerInputTypes.DATE,
          date: at,
          channelId: 'przypomnienia',
        },
      });
    }
  } catch {
    // powiadomienia to dodatek - cicho ignorujemy (np. brak zgody, Expo Go)
  }
}
