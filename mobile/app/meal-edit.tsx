import { Stack, router, useLocalSearchParams } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ScrollView } from 'react-native';

import { Input, PickerField, PrimaryButton } from '../components/forms';
import { showError } from '../components/ui';
import { Api } from '../lib/api';
import type { MealPlanEntry, Recipe } from '../lib/models';
import { takeStash } from '../lib/stash';
import { mealTypeEmoji, mealTypeLabels, mealTypes, prettyDate, todayStr } from '../lib/util';

export default function MealEditScreen() {
  const params = useLocalSearchParams<{ date?: string }>();
  const [existing] = useState(() => takeStash<MealPlanEntry>());
  const date = existing?.date ?? params.date ?? todayStr();
  const [mealType, setMealType] = useState(existing?.mealType ?? 'obiad');
  // '' oznacza "bez przepisu"
  const [recipeChoice, setRecipeChoice] = useState(existing?.recipeId ?? '');
  const [note, setNote] = useState(existing?.note ?? '');
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    (Api.get('/api/recipes') as Promise<Recipe[]>).then(setRecipes).catch(() => setRecipes([]));
  }, []);

  const save = async () => {
    setBusy(true);
    try {
      await Api.put('/api/mealplan', {
        date,
        mealType,
        recipeId: recipeChoice || null,
        note: note.trim(),
      });
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  return (
    <>
      <Stack.Screen options={{ title: `Posiłek - ${prettyDate(date)}` }} />
      <ScrollView contentContainerStyle={{ padding: 16 }} keyboardShouldPersistTaps="handled">
        <PickerField
          label="Posiłek"
          value={mealType}
          onChange={setMealType}
          disabled={existing != null}
          options={mealTypes.map((t) => ({
            value: t,
            label: `${mealTypeEmoji[t]} ${mealTypeLabels[t]}`,
          }))}
        />
        <PickerField
          label="Przepis z Twojej bazy"
          value={recipeChoice}
          onChange={setRecipeChoice}
          options={[
            { value: '', label: '— bez przepisu —' },
            ...recipes.map((r) => ({ value: r.id, label: r.title })),
          ]}
        />
        <Input
          label="Albo wpisz, co jecie"
          placeholder="np. pierogi od mamy"
          value={note}
          onChangeText={setNote}
          autoCapitalize="sentences"
        />
        <PrimaryButton title="Zapisz" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}
