import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ActionSheet } from '../../components/forms';
import {
  Card,
  CheckCircle,
  EmptyState,
  Fab,
  HeaderIcon,
  PageHeader,
  SectionHeader,
  showError,
  toast,
} from '../../components/ui';
import { Api } from '../../lib/api';
import type { EventItem, MealPlanEntry, Reminder, TaskItem } from '../../lib/models';
import { syncReminderNotifications } from '../../lib/notifications';
import { setStash } from '../../lib/stash';
import { colors } from '../../lib/theme';
import {
  addDays,
  dayOnly,
  longDate,
  mealOrder,
  mealTypeEmoji,
  mealTypeLabels,
  prettyDate,
  prettyDateTime,
  timeOf,
  todayStr,
} from '../../lib/util';

function greeting(): string {
  const hour = new Date().getHours();
  const name = Api.displayName ? `, ${Api.displayName}` : '';
  if (hour < 5) return `Dobranoc${name} 🌙`;
  if (hour < 12) return `Dzień dobry${name} ☀️`;
  if (hour < 18) return `Cześć${name} 💗`;
  return `Dobry wieczór${name} 🌆`;
}

export default function TodayScreen() {
  const [reminders, setReminders] = useState<Reminder[]>([]);
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [events, setEvents] = useState<EventItem[]>([]);
  const [meals, setMeals] = useState<MealPlanEntry[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);

  const load = useCallback(async () => {
    const start = dayOnly(new Date());
    const end = addDays(start, 1);
    const today = todayStr();
    const [rem, tsk, evs, mls] = await Promise.all([
      Api.get('/api/reminders') as Promise<Reminder[]>,
      Api.get('/api/tasks', { includeDone: 'true' }) as Promise<TaskItem[]>,
      Api.get('/api/events', {
        from: start.toISOString(),
        to: end.toISOString(),
      }) as Promise<EventItem[]>,
      Api.get('/api/mealplan', { from: today, to: today }) as Promise<MealPlanEntry[]>,
    ]);
    syncReminderNotifications(rem);
    const soon = addDays(end, 2).getTime();
    setReminders(rem.filter((r) => new Date(r.remindAt).getTime() < soon));
    setTasks(
      tsk.filter(
        (t) =>
          (!t.done && (t.dueDate == null || t.dueDate <= today)) || (t.done && t.dueDate === today),
      ),
    );
    setEvents(evs);
    setMeals([...mls].sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType)));
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

  const toggleTask = async (t: TaskItem) => {
    try {
      await Api.post(`/api/tasks/${t.id}/toggle`);
      if (!t.done && t.repeat !== 'none') toast('Odhaczone! Zaplanowałam kolejny termin 📅');
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const toggleReminder = async (r: Reminder) => {
    try {
      await Api.post(`/api/reminders/${r.id}/toggle`);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const now = new Date();
  const today = todayStr();

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top']}>
      <PageHeader
        title={greeting()}
        subtitle={longDate(now)}
        right={
          <View style={{ flexDirection: 'row' }}>
            <HeaderIcon name="checkbox-outline" onPress={() => router.push('/tasks')} />
            <HeaderIcon name="notifications-outline" onPress={() => router.push('/reminders')} />
            <HeaderIcon name="settings-outline" onPress={() => router.push('/settings')} />
          </View>
        }
      />
      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        {reminders.length > 0 ? (
          <>
            <SectionHeader title="🔔 Przypomnienia" />
            <Card>
              {reminders.map((r) => {
                const overdue = !r.done && new Date(r.remindAt) < now;
                return (
                  <View key={r.id} style={styles.row}>
                    <CheckCircle checked={r.done} onPress={() => toggleReminder(r)} />
                    <View style={{ flex: 1 }}>
                      <Text style={styles.rowTitle}>{r.title}</Text>
                      <Text style={[styles.rowSub, overdue ? { color: colors.error } : null]}>
                        {prettyDateTime(r.remindAt)}
                      </Text>
                    </View>
                  </View>
                );
              })}
            </Card>
          </>
        ) : null}

        <SectionHeader title="✅ Obowiązki na dziś" />
        <Card>
          {tasks.length === 0 ? (
            <EmptyState emoji="🎉" text={'Nic do zrobienia - możesz odpocząć!'} />
          ) : (
            tasks.map((t) => (
              <View key={t.id} style={styles.row}>
                <CheckCircle checked={t.done} onPress={() => toggleTask(t)} />
                <View style={{ flex: 1 }}>
                  <Text style={[styles.rowTitle, t.done ? styles.struck : null]}>{t.title}</Text>
                  {t.dueDate && t.dueDate < today ? (
                    <Text style={[styles.rowSub, { color: colors.error }]}>
                      zaległe od {prettyDate(t.dueDate)}
                    </Text>
                  ) : null}
                </View>
              </View>
            ))
          )}
        </Card>

        <SectionHeader title="📅 Dzisiejsze wydarzenia" />
        <Card>
          {events.length === 0 ? (
            <EmptyState emoji="🛋️" text="Kalendarz na dziś jest pusty" />
          ) : (
            events.map((e) => (
              <View key={e.id} style={styles.row}>
                <Text style={styles.time}>{e.allDay ? '📌' : timeOf(e.startsAt)}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.rowTitle}>{e.title}</Text>
                  {e.description ? <Text style={styles.rowSub}>{e.description}</Text> : null}
                </View>
              </View>
            ))
          )}
        </Card>

        <SectionHeader title="🍽️ Dziś jemy" />
        <Card>
          {meals.length === 0 ? (
            <EmptyState emoji="🤔" text={'Nie zaplanowano posiłków.\nZajrzyj do Kuchni!'} />
          ) : (
            meals.map((m) => (
              <View key={m.id} style={styles.row}>
                <Text style={{ fontSize: 22, marginRight: 10 }}>
                  {mealTypeEmoji[m.mealType] ?? '🍽️'}
                </Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.rowTitle}>{m.recipeTitle ?? m.note}</Text>
                  <Text style={styles.rowSub}>{mealTypeLabels[m.mealType] ?? m.mealType}</Text>
                </View>
              </View>
            ))
          )}
        </Card>
        <View style={{ height: 90 }} />
      </ScrollView>

      <Fab onPress={() => setSheetOpen(true)} />
      <ActionSheet
        visible={sheetOpen}
        onClose={() => setSheetOpen(false)}
        actions={[
          {
            icon: 'checkbox-outline',
            label: 'Obowiązek',
            onPress: () => {
              setStash(undefined);
              router.push({ pathname: '/task-edit', params: { initialDue: today } });
            },
          },
          {
            icon: 'notifications-outline',
            label: 'Przypomnienie',
            onPress: () => {
              setStash(undefined);
              router.push('/reminder-edit');
            },
          },
          {
            icon: 'calendar-outline',
            label: 'Wydarzenie',
            onPress: () => {
              setStash(undefined);
              router.push('/event-edit');
            },
          },
          {
            icon: 'restaurant-outline',
            label: 'Posiłek na dziś',
            onPress: () => {
              setStash(undefined);
              router.push({ pathname: '/meal-edit', params: { date: today } });
            },
          },
        ]}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  content: { paddingHorizontal: 16 },
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8 },
  rowTitle: { color: colors.text, fontSize: 15 },
  rowSub: { color: colors.muted, fontSize: 12.5, marginTop: 1 },
  struck: { textDecorationLine: 'line-through', color: colors.muted },
  time: { fontWeight: '700', color: colors.text, marginRight: 10, minWidth: 44 },
});
