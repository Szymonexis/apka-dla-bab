import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Api } from '../../lib/api';
import type { MealPlanEntry } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors } from '../../lib/theme';
import {
  addDays,
  dateStr,
  dayHeader,
  mealOrder,
  mealTypeEmoji,
  mealTypeLabels,
  mondayOf,
  shortDate,
  todayStr,
} from '../../lib/util';
import { Card, HeaderIcon, NavRow, showError } from '../ui';

export default function MealPlanTab() {
  const [weekOffset, setWeekOffset] = useState(0);
  const [meals, setMeals] = useState<MealPlanEntry[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  const monday = addDays(mondayOf(new Date()), 7 * weekOffset);
  const sunday = addDays(monday, 6);

  const load = useCallback(async () => {
    const from = addDays(mondayOf(new Date()), 7 * weekOffset);
    const to = addDays(from, 6);
    const res = (await Api.get('/api/mealplan', {
      from: dateStr(from),
      to: dateStr(to),
    })) as MealPlanEntry[];
    setMeals(res);
  }, [weekOffset]);

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

  const remove = async (m: MealPlanEntry) => {
    try {
      await Api.del(`/api/mealplan/${m.id}`);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  return (
    <View style={{ flex: 1 }}>
      <NavRow
        label={`${shortDate(monday)} – ${shortDate(sunday)}`}
        onPrev={() => setWeekOffset(weekOffset - 1)}
        onNext={() => setWeekOffset(weekOffset + 1)}
      />
      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 24 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {Array.from({ length: 7 }, (_, i) => {
          const day = addDays(monday, i);
          const ds = dateStr(day);
          const isToday = ds === todayStr();
          const dayMeals = meals
            .filter((m) => m.date === ds)
            .sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType));
          return (
            <Card key={ds} style={isToday ? { backgroundColor: colors.primaryContainer } : undefined}>
              <View style={styles.dayHeader}>
                <Text style={styles.dayTitle}>{dayHeader(day)}</Text>
                <HeaderIcon
                  name="add-circle-outline"
                  onPress={() => {
                    setStash(undefined);
                    router.push({ pathname: '/meal-edit', params: { date: ds } });
                  }}
                />
              </View>
              {dayMeals.map((m) => (
                <TouchableOpacity
                  key={m.id}
                  style={styles.mealRow}
                  onPress={() => {
                    setStash(m);
                    router.push({ pathname: '/meal-edit', params: { date: ds } });
                  }}
                >
                  <Text style={{ fontSize: 20, marginRight: 10 }}>
                    {mealTypeEmoji[m.mealType] ?? '🍽️'}
                  </Text>
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: colors.text }}>{m.recipeTitle ?? m.note}</Text>
                    <Text style={{ color: colors.muted, fontSize: 12 }}>
                      {mealTypeLabels[m.mealType] ?? m.mealType}
                    </Text>
                  </View>
                  <TouchableOpacity onPress={() => remove(m)} hitSlop={8}>
                    <Ionicons name="trash-outline" size={19} color={colors.muted} />
                  </TouchableOpacity>
                </TouchableOpacity>
              ))}
            </Card>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  dayHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  dayTitle: { fontWeight: '800', color: colors.text },
  mealRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 6 },
});
