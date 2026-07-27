import { Stack, router, useLocalSearchParams } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView } from 'react-native';

import { Input, PickerField, PrimaryButton } from '../components/forms';
import { showError } from '../components/ui';
import { Api } from '../lib/api';
import type { DiaryEntry } from '../lib/models';
import { takeStash } from '../lib/stash';
import { mealTypeEmoji, mealTypeLabels, mealTypes, prettyDate, todayStr } from '../lib/util';

export default function DiaryEditScreen() {
  const params = useLocalSearchParams<{ date?: string }>();
  const [existing] = useState(() => takeStash<DiaryEntry>());
  const date = existing?.date ?? params.date ?? todayStr();
  const [mealType, setMealType] = useState(existing?.mealType ?? 'sniadanie');
  const [description, setDescription] = useState(existing?.description ?? '');
  const [calories, setCalories] = useState(existing?.calories?.toString() ?? '');
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!description.trim()) {
      showError('Napisz, co zjadłaś');
      return;
    }
    setBusy(true);
    try {
      const kcal = parseInt(calories.trim(), 10);
      const body = {
        date,
        mealType,
        description: description.trim(),
        calories: Number.isFinite(kcal) ? kcal : null,
      };
      if (existing) {
        await Api.put(`/api/diary/${existing.id}`, body);
      } else {
        await Api.post('/api/diary', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  return (
    <>
      <Stack.Screen options={{ title: `Co zjadłaś? - ${prettyDate(date)}` }} />
      <ScrollView contentContainerStyle={{ padding: 16 }} keyboardShouldPersistTaps="handled">
        <PickerField
          label="Posiłek"
          value={mealType}
          onChange={setMealType}
          options={mealTypes.map((t) => ({
            value: t,
            label: `${mealTypeEmoji[t]} ${mealTypeLabels[t]}`,
          }))}
        />
        <Input
          label="Opis"
          value={description}
          onChangeText={setDescription}
          autoFocus={!existing}
          autoCapitalize="sentences"
        />
        <Input
          label="Kalorie (opcjonalnie)"
          value={calories}
          onChangeText={setCalories}
          keyboardType="number-pad"
        />
        <PrimaryButton title="Zapisz" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}
