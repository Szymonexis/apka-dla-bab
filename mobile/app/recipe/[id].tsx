import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { Stack, router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { DateField, PickerField, PrimaryButton } from '../../components/forms';
import { Card, Chip, SectionHeader, confirmDelete, showError, toast } from '../../components/ui';
import { Api } from '../../lib/api';
import type { Recipe } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors } from '../../lib/theme';
import { mealTypeEmoji, mealTypeLabels, mealTypes, todayStr } from '../../lib/util';

export default function RecipeDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const [recipe, setRecipe] = useState<Recipe | null>(null);
  const [planOpen, setPlanOpen] = useState(false);
  const [planDate, setPlanDate] = useState<string | null>(todayStr());
  const [planMeal, setPlanMeal] = useState('obiad');

  useFocusEffect(
    useCallback(() => {
      (Api.get(`/api/recipes/${id}`) as Promise<Recipe>).then(setRecipe).catch((e) => {
        showError(e);
        router.back();
      });
    }, [id]),
  );

  const remove = async () => {
    if (!recipe) return;
    if (!(await confirmDelete(`Przepis "${recipe.title}" zniknie na zawsze.`))) return;
    try {
      await Api.del(`/api/recipes/${recipe.id}`);
      router.back();
    } catch (e) {
      showError(e);
    }
  };

  const plan = async () => {
    if (!recipe || !planDate) return;
    try {
      await Api.put('/api/mealplan', {
        date: planDate,
        mealType: planMeal,
        recipeId: recipe.id,
        note: '',
      });
      setPlanOpen(false);
      toast('Zaplanowane! 🍽️');
    } catch (e) {
      showError(e);
    }
  };

  return (
    <>
      <Stack.Screen
        options={{
          title: recipe?.title ?? '...',
          headerRight: () =>
            recipe ? (
              <View style={{ flexDirection: 'row' }}>
                <TouchableOpacity
                  style={styles.action}
                  hitSlop={8}
                  onPress={() => {
                    setStash(recipe);
                    router.push('/recipe-edit');
                  }}
                >
                  <Ionicons name="create-outline" size={22} color={colors.text} />
                </TouchableOpacity>
                <TouchableOpacity style={styles.action} hitSlop={8} onPress={remove}>
                  <Ionicons name="trash-outline" size={22} color={colors.text} />
                </TouchableOpacity>
              </View>
            ) : null,
        }}
      />
      {recipe ? (
        <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }}>
          {recipe.imageFileId ? (
            <Image
              source={{ uri: Api.fileUrl(recipe.imageFileId), headers: Api.imageHeaders }}
              style={styles.image}
              contentFit="cover"
            />
          ) : null}
          <View style={styles.chips}>
            {recipe.timeMinutes ? <Chip label={`⏱️ ${recipe.timeMinutes} min`} /> : null}
            {recipe.servings ? <Chip label={`👥 ${recipe.servings} porcje`} /> : null}
            {recipe.tags.map((t) => (
              <Chip key={t} label={`#${t}`} />
            ))}
          </View>
          {recipe.description ? (
            <>
              <SectionHeader title="Opis" />
              <Text style={styles.text}>{recipe.description}</Text>
            </>
          ) : null}
          {recipe.ingredients ? (
            <>
              <SectionHeader title="🛒 Składniki" />
              <Card>
                <Text style={styles.text}>{recipe.ingredients}</Text>
              </Card>
            </>
          ) : null}
          {recipe.steps ? (
            <>
              <SectionHeader title="👩‍🍳 Przygotowanie" />
              <Card>
                <Text style={styles.text}>{recipe.steps}</Text>
              </Card>
            </>
          ) : null}
          <View style={{ height: 12 }} />
          {planOpen ? (
            <Card>
              <DateField label="Data" value={planDate} onChange={setPlanDate} />
              <PickerField
                label="Posiłek"
                value={planMeal}
                onChange={setPlanMeal}
                options={mealTypes.map((t) => ({
                  value: t,
                  label: `${mealTypeEmoji[t]} ${mealTypeLabels[t]}`,
                }))}
              />
              <PrimaryButton title="Zaplanuj" onPress={plan} />
            </Card>
          ) : (
            <PrimaryButton title="🗓️ Dodaj do jadłospisu" onPress={() => setPlanOpen(true)} />
          )}
        </ScrollView>
      ) : null}
    </>
  );
}

const styles = StyleSheet.create({
  action: { paddingHorizontal: 8, paddingVertical: 4 },
  image: { height: 220, borderRadius: 16, marginBottom: 12 },
  chips: { flexDirection: 'row', flexWrap: 'wrap' },
  text: { color: colors.text, lineHeight: 21 },
});
