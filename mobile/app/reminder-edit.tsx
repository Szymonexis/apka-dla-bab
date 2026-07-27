import { Stack, router } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView } from 'react-native';

import { DateField, Input, PrimaryButton, TimeField } from '../components/forms';
import { showError } from '../components/ui';
import { Api } from '../lib/api';
import type { Reminder } from '../lib/models';
import { takeStash } from '../lib/stash';
import { dateStr, parseLocalDate } from '../lib/util';

export default function ReminderEditScreen() {
  const [existing] = useState(() => takeStash<Reminder>());
  const initial = existing ? new Date(existing.remindAt) : new Date(Date.now() + 60 * 60 * 1000);
  const [title, setTitle] = useState(existing?.title ?? '');
  const [date, setDate] = useState<string | null>(dateStr(initial));
  const [time, setTime] = useState({ hour: initial.getHours(), minute: initial.getMinutes() });
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!title.trim() || !date) {
      showError('Podaj treść i termin przypomnienia');
      return;
    }
    setBusy(true);
    try {
      const d = parseLocalDate(date);
      d.setHours(time.hour, time.minute, 0, 0);
      const body = { title: title.trim(), remindAt: d.toISOString() };
      if (existing) {
        await Api.put(`/api/reminders/${existing.id}`, body);
      } else {
        await Api.post('/api/reminders', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  return (
    <>
      <Stack.Screen options={{ title: existing ? 'Edytuj przypomnienie' : 'Nowe przypomnienie' }} />
      <ScrollView contentContainerStyle={{ padding: 16 }} keyboardShouldPersistTaps="handled">
        <Input
          label="O czym Ci przypomnieć?"
          value={title}
          onChangeText={setTitle}
          autoFocus={!existing}
          autoCapitalize="sentences"
        />
        <DateField label="Data" value={date} onChange={setDate} />
        <TimeField label="Godzina" value={time} onChange={setTime} />
        <PrimaryButton title="Zapisz" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}
