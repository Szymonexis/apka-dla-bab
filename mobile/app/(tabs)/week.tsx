import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ActionSheet } from '../../components/forms';
import { Card, Chip, HeaderIcon, NavRow, PageHeader, showError } from '../../components/ui';
import { Api } from '../../lib/api';
import type { EventItem, MealPlanEntry, TaskItem } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors } from '../../lib/theme';
import {
  addDays,
  dateStr,
  dayHeader,
  mealOrder,
  mealTypeEmoji,
  mondayOf,
  shortDate,
  timeOf,
  todayStr,
} from '../../lib/util';

export default function WeekScreen() {
  const [weekOffset, setWeekOffset] = useState(0);
  const [events, setEvents] = useState<EventItem[]>([]);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [meals, setMeals] = useState<MealPlanEntry[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [sheetDate, setSheetDate] = useState<string | null>(null);

  const monday = addDays(mondayOf(new Date()), 7 * weekOffset);
  const sunday = addDays(monday, 6);

  const load = useCallback(async () => {
    const from = addDays(mondayOf(new Date()), 7 * weekOffset);
    const to = addDays(from, 6);
    const [evs, tsk, mls] = await Promise.all([
      Api.get('/api/events', {
        from: from.toISOString(),
        to: addDays(from, 7).toISOString(),
      }) as Promise<EventItem[]>,
      Api.get('/api/tasks', {
        includeDone: 'true',
        dueFrom: dateStr(from),
        dueTo: dateStr(to),
      }) as Promise<TaskItem[]>,
      Api.get('/api/mealplan', { from: dateStr(from), to: dateStr(to) }) as Promise<MealPlanEntry[]>,
    ]);
    setEvents(evs);
    setTasks(tsk);
    setMeals(mls);
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

  const toggleTask = async (t: TaskItem) => {
    try {
      await Api.post(`/api/tasks/${t.id}/toggle`);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const dayCard = (day: Date) => {
    const ds = dateStr(day);
    const isToday = ds === todayStr();
    const dayEvents = events.filter((e) => dateStr(new Date(e.startsAt)) === ds);
    const dayTasks = tasks.filter((t) => t.dueDate === ds);
    const dayMeals = meals
      .filter((m) => m.date === ds)
      .sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType));
    const empty = dayEvents.length === 0 && dayTasks.length === 0 && dayMeals.length === 0;

    return (
      <Card key={ds} style={isToday ? { backgroundColor: colors.primaryContainer } : undefined}>
        <View style={styles.dayHeader}>
          <Text style={[styles.dayTitle, isToday ? { color: colors.primary } : null]}>
            {dayHeader(day)}
          </Text>
          <HeaderIcon name="add-circle-outline" onPress={() => setSheetDate(ds)} />
        </View>
        {empty ? <Text style={styles.emptyDay}>nic nie zaplanowano</Text> : null}
        {dayMeals.length > 0 ? (
          <View style={styles.chips}>
            {dayMeals.map((m) => (
              <Chip key={m.id} label={`${mealTypeEmoji[m.mealType]} ${m.recipeTitle ?? m.note}`} />
            ))}
          </View>
        ) : null}
        {dayEvents.map((e) => (
          <View key={e.id} style={styles.line}>
            <Text style={styles.time}>{e.allDay ? '📌' : timeOf(e.startsAt)}</Text>
            <Text style={styles.lineText}>{e.title}</Text>
          </View>
        ))}
        {dayTasks.map((t) => (
          <TouchableOpacity key={t.id} style={styles.line} onPress={() => toggleTask(t)}>
            <Ionicons
              name={t.done ? 'checkmark-circle' : 'ellipse-outline'}
              size={20}
              color={t.done ? colors.primary : colors.muted}
              style={{ marginRight: 8 }}
            />
            <Text style={[styles.lineText, t.done ? styles.struck : null]}>{t.title}</Text>
          </TouchableOpacity>
        ))}
      </Card>
    );
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top']}>
      <PageHeader
        title="Plan tygodnia 🗓️"
        right={
          weekOffset !== 0 ? (
            <TouchableOpacity onPress={() => setWeekOffset(0)}>
              <Text style={{ color: colors.primary, fontWeight: '700' }}>Dziś</Text>
            </TouchableOpacity>
          ) : undefined
        }
      />
      <NavRow
        label={`${shortDate(monday)} – ${shortDate(sunday)}`}
        onPrev={() => setWeekOffset(weekOffset - 1)}
        onNext={() => setWeekOffset(weekOffset + 1)}
      />
      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 24 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {Array.from({ length: 7 }, (_, i) => dayCard(addDays(monday, i)))}
      </ScrollView>

      <ActionSheet
        visible={sheetDate != null}
        onClose={() => setSheetDate(null)}
        actions={[
          {
            icon: 'checkbox-outline',
            label: 'Obowiązek',
            onPress: () => {
              setStash(undefined);
              router.push({ pathname: '/task-edit', params: { initialDue: sheetDate! } });
            },
          },
          {
            icon: 'calendar-outline',
            label: 'Wydarzenie',
            onPress: () => {
              setStash(undefined);
              router.push({ pathname: '/event-edit', params: { initialDate: sheetDate! } });
            },
          },
          {
            icon: 'restaurant-outline',
            label: 'Posiłek',
            onPress: () => {
              setStash(undefined);
              router.push({ pathname: '/meal-edit', params: { date: sheetDate! } });
            },
          },
        ]}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  dayHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  dayTitle: { fontWeight: '800', color: colors.text, fontSize: 15 },
  emptyDay: { color: colors.muted, fontSize: 13, paddingBottom: 6 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', paddingVertical: 4 },
  line: { flexDirection: 'row', alignItems: 'center', paddingVertical: 3 },
  lineText: { color: colors.text, flex: 1 },
  struck: { textDecorationLine: 'line-through', color: colors.muted },
  time: { fontWeight: '700', color: colors.text, fontSize: 13, marginRight: 8, minWidth: 42 },
});
