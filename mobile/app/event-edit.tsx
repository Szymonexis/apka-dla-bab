import { Stack, router, useLocalSearchParams } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { DateField, Input, PrimaryButton, TimeField } from '../components/forms';
import { showError } from '../components/ui';
import { Api } from '../lib/api';
import type { EventItem } from '../lib/models';
import { takeStash } from '../lib/stash';
import { colors } from '../lib/theme';
import { dateStr, parseLocalDate, todayStr } from '../lib/util';

export default function EventEditScreen() {
  const params = useLocalSearchParams<{ initialDate?: string }>();
  const [existing] = useState(() => takeStash<EventItem>());
  const start = existing ? new Date(existing.startsAt) : null;
  const [title, setTitle] = useState(existing?.title ?? '');
  const [description, setDescription] = useState(existing?.description ?? '');
  const [date, setDate] = useState<string | null>(
    start ? dateStr(start) : (params.initialDate ?? todayStr()),
  );
  const [allDay, setAllDay] = useState(existing?.allDay ?? false);
  const [time, setTime] = useState(
    start ? { hour: start.getHours(), minute: start.getMinutes() } : { hour: 12, minute: 0 },
  );
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!title.trim() || !date) {
      showError('Podaj tytuł i termin wydarzenia');
      return;
    }
    setBusy(true);
    try {
      const d = parseLocalDate(date);
      if (!allDay) d.setHours(time.hour, time.minute, 0, 0);
      const body = {
        title: title.trim(),
        description: description.trim(),
        startsAt: d.toISOString(),
        allDay,
      };
      if (existing) {
        await Api.put(`/api/events/${existing.id}`, body);
      } else {
        await Api.post('/api/events', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  return (
    <>
      <Stack.Screen options={{ title: existing ? 'Edytuj wydarzenie' : 'Nowe wydarzenie' }} />
      <ScrollView contentContainerStyle={{ padding: 16 }} keyboardShouldPersistTaps="handled">
        <Input
          label="Co się dzieje?"
          value={title}
          onChangeText={setTitle}
          autoFocus={!existing}
          autoCapitalize="sentences"
        />
        <Input
          label="Szczegóły (opcjonalnie)"
          value={description}
          onChangeText={setDescription}
          autoCapitalize="sentences"
        />
        <DateField label="Data" value={date} onChange={setDate} />
        <View style={styles.switchRow}>
          <Text style={{ color: colors.text, flex: 1 }}>Cały dzień</Text>
          <Switch
            value={allDay}
            onValueChange={setAllDay}
            trackColor={{ true: colors.primaryContainer }}
            thumbColor={allDay ? colors.primary : undefined}
          />
        </View>
        {!allDay ? <TimeField label="Godzina" value={time} onChange={setTime} /> : null}
        <PrimaryButton title="Zapisz" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  switchRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 12, paddingHorizontal: 2 },
});
