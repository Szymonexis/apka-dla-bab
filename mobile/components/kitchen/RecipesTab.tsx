import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import {
  Alert,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';

import { Api } from '../../lib/api';
import type { Recipe } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors, radius } from '../../lib/theme';
import { todayStr } from '../../lib/util';
import { Card, EmptyState, Fab, showError, toast } from '../ui';

export default function RecipesTab() {
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [search, setSearch] = useState('');
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const res = (await Api.get('/api/recipes')) as Recipe[];
    setRecipes(res);
  }, []);

  useFocusEffect(
    useCallback(() => {
      load().catch(showError);
    }, [load]),
  );

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await load();
    } catch (e) {
      showError(e);
    } finally {
      setRefreshing(false);
    }
  }, [load]);

  const toggleFavorite = async (r: Recipe) => {
    try {
      await Api.put(`/api/recipes/${r.id}`, { ...r, favorite: !r.favorite });
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const randomIdea = async () => {
    try {
      const r = (await Api.get('/api/recipes/random')) as Recipe;
      Alert.alert(
        'Pomysł na obiad 🎲',
        r.timeMinutes ? `${r.title}\n⏱️ ok. ${r.timeMinutes} min` : r.title,
        [
          { text: 'Zamknij', style: 'cancel' },
          {
            text: 'Zobacz',
            onPress: () => router.push({ pathname: '/recipe/[id]', params: { id: r.id } }),
          },
          {
            text: 'Na dziś!',
            onPress: async () => {
              try {
                await Api.put('/api/mealplan', {
                  date: todayStr(),
                  mealType: 'obiad',
                  recipeId: r.id,
                  note: '',
                });
                toast('Zaplanowane na dziś! 🍽️');
              } catch (e) {
                showError(e);
              }
            },
          },
        ],
      );
    } catch (e) {
      showError(e);
    }
  };

  const q = search.trim().toLowerCase();
  const filtered = q
    ? recipes.filter(
        (r) =>
          r.title.toLowerCase().includes(q) || r.tags.some((t) => t.toLowerCase().includes(q)),
      )
    : recipes;

  return (
    <View style={{ flex: 1 }}>
      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 96, paddingTop: 8 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        keyboardShouldPersistTaps="handled"
      >
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <View style={styles.searchBox}>
            <Ionicons name="search" size={18} color={colors.muted} style={{ marginRight: 6 }} />
            <TextInput
              style={{ flex: 1, color: colors.text, paddingVertical: 8 }}
              placeholder="Szukaj przepisu lub tagu..."
              placeholderTextColor={colors.muted}
              value={search}
              onChangeText={setSearch}
            />
          </View>
          <TouchableOpacity style={styles.randomBtn} onPress={randomIdea}>
            <Text style={{ color: colors.primary, fontWeight: '700' }}>🎲 Wylosuj</Text>
          </TouchableOpacity>
        </View>

        {filtered.length === 0 ? (
          <EmptyState emoji="👩‍🍳" text={'Brak przepisów.\nDodaj pierwszy plusem na dole!'} />
        ) : null}

        {filtered.map((r) => (
          <TouchableOpacity
            key={r.id}
            onPress={() => router.push({ pathname: '/recipe/[id]', params: { id: r.id } })}
          >
            <Card>
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                {r.imageFileId ? (
                  <Image
                    source={{ uri: Api.fileUrl(r.imageFileId), headers: Api.imageHeaders }}
                    style={styles.thumb}
                    contentFit="cover"
                  />
                ) : (
                  <Text style={{ fontSize: 28, marginRight: 10 }}>🍲</Text>
                )}
                <View style={{ flex: 1 }}>
                  <Text style={{ fontWeight: '600', color: colors.text }}>{r.title}</Text>
                  <Text style={{ color: colors.muted, fontSize: 12.5 }}>
                    {[r.timeMinutes ? `⏱️ ${r.timeMinutes} min` : null, r.tags.join(', ') || null]
                      .filter(Boolean)
                      .join(' · ')}
                  </Text>
                </View>
                <TouchableOpacity onPress={() => toggleFavorite(r)} hitSlop={8}>
                  <Ionicons
                    name={r.favorite ? 'heart' : 'heart-outline'}
                    size={22}
                    color={r.favorite ? colors.primary : colors.muted}
                  />
                </TouchableOpacity>
              </View>
            </Card>
          </TouchableOpacity>
        ))}
      </ScrollView>
      <Fab
        onPress={() => {
          setStash(undefined);
          router.push('/recipe-edit');
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  searchBox: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.outline,
    borderRadius: radius.field,
    paddingHorizontal: 10,
    backgroundColor: colors.surface,
  },
  randomBtn: { paddingHorizontal: 10, paddingVertical: 10 },
  thumb: { width: 52, height: 52, borderRadius: 8, marginRight: 10 },
});
