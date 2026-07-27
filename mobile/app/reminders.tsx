import { Ionicons } from '@expo/vector-icons';
import { Stack, router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Card, CheckCircle, EmptyState, Fab, showError } from '../components/ui';
import { Api } from '../lib/api';
import type { Reminder } from '../lib/models';
import { syncReminderNotifications } from '../lib/notifications';
import { setStash } from '../lib/stash';
import { colors } from '../lib/theme';
import { prettyDateTime } from '../lib/util';

export default function RemindersScreen() {
  const [reminders, setReminders] = useState<Reminder[]>([]);
  const [showDone, setShowDone] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const res = (await Api.get('/api/reminders', { includeDone: 'true' })) as Reminder[];
    syncReminderNotifications(res);
    setReminders(res);
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

  const toggle = async (r: Reminder) => {
    try {
      await Api.post(`/api/reminders/${r.id}/toggle`);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const remove = async (r: Reminder) => {
    try {
      await Api.del(`/api/reminders/${r.id}`);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const item = (r: Reminder) => {
    const overdue = !r.done && new Date(r.remindAt) < new Date();
    return (
      <TouchableOpacity
        key={r.id}
        onPress={() => {
          setStash(r);
          router.push('/reminder-edit');
        }}
      >
        <Card>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <CheckCircle checked={r.done} onPress={() => toggle(r)} />
            <View style={{ flex: 1 }}>
              <Text style={[styles.title, r.done ? styles.struck : null]}>{r.title}</Text>
              <Text style={[styles.sub, overdue ? { color: colors.error } : null]}>
                {prettyDateTime(r.remindAt)}
              </Text>
            </View>
            <TouchableOpacity onPress={() => remove(r)} hitSlop={8}>
              <Ionicons name="trash-outline" size={19} color={colors.muted} />
            </TouchableOpacity>
          </View>
        </Card>
      </TouchableOpacity>
    );
  };

  const active = reminders.filter((r) => !r.done);
  const done = reminders.filter((r) => r.done);

  return (
    <>
      <Stack.Screen options={{ title: 'Przypomnienia 🔔' }} />
      <View style={{ flex: 1 }}>
        <ScrollView
          contentContainerStyle={{ padding: 16, paddingBottom: 96 }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        >
          {active.length === 0 ? (
            <EmptyState emoji="🔕" text={'Żadnych przypomnień.\nGłowa wolna!'} />
          ) : null}
          {active.map(item)}
          {done.length > 0 ? (
            <>
              <TouchableOpacity style={styles.doneHeader} onPress={() => setShowDone(!showDone)}>
                <Text style={{ color: colors.muted, fontWeight: '600' }}>
                  Zrobione ({done.length})
                </Text>
                <Ionicons
                  name={showDone ? 'chevron-up' : 'chevron-down'}
                  size={18}
                  color={colors.muted}
                />
              </TouchableOpacity>
              {showDone ? done.map(item) : null}
            </>
          ) : null}
        </ScrollView>
        <Fab
          onPress={() => {
            setStash(undefined);
            router.push('/reminder-edit');
          }}
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  title: { color: colors.text, fontSize: 15 },
  sub: { color: colors.muted, fontSize: 12.5, marginTop: 1 },
  struck: { textDecorationLine: 'line-through', color: colors.muted },
  doneHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 4,
  },
});
