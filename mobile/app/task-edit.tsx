import { Stack, router, useLocalSearchParams } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView } from 'react-native';

import { DateField, Input, PickerField, PrimaryButton } from '../components/forms';
import { showError } from '../components/ui';
import { Api } from '../lib/api';
import type { TaskItem } from '../lib/models';
import { takeStash } from '../lib/stash';
import { repeatLabels } from '../lib/util';

export default function TaskEditScreen() {
  const params = useLocalSearchParams<{ initialDue?: string }>();
  const [existing] = useState(() => takeStash<TaskItem>());
  const [title, setTitle] = useState(existing?.title ?? '');
  const [due, setDue] = useState<string | null>(existing?.dueDate ?? params.initialDue ?? null);
  const [repeat, setRepeat] = useState<string>(existing?.repeat ?? 'none');
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!title.trim()) {
      showError('Podaj treść obowiązku');
      return;
    }
    setBusy(true);
    try {
      const body = { title: title.trim(), notes: existing?.notes ?? '', dueDate: due, repeat };
      if (existing) {
        await Api.put(`/api/tasks/${existing.id}`, body);
      } else {
        await Api.post('/api/tasks', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  return (
    <>
      <Stack.Screen options={{ title: existing ? 'Edytuj obowiązek' : 'Nowy obowiązek' }} />
      <ScrollView contentContainerStyle={{ padding: 16 }} keyboardShouldPersistTaps="handled">
        <Input
          label="Co jest do zrobienia?"
          value={title}
          onChangeText={setTitle}
          autoFocus={!existing}
          autoCapitalize="sentences"
        />
        <DateField label="Termin" value={due} onChange={setDue} allowClear placeholder="Bez terminu" />
        <PickerField
          label="Powtarzanie"
          value={repeat}
          onChange={setRepeat}
          options={Object.entries(repeatLabels).map(([value, label]) => ({ value, label }))}
        />
        <PrimaryButton title="Zapisz" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}
