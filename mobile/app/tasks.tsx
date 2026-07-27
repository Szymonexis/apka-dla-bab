import { Ionicons } from '@expo/vector-icons';
import { Stack, router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Card, CheckCircle, EmptyState, Fab, showError, toast } from '../components/ui';
import { Api } from '../lib/api';
import type { TaskItem } from '../lib/models';
import { setStash } from '../lib/stash';
import { colors } from '../lib/theme';
import { prettyDate, repeatLabels } from '../lib/util';

export default function TasksScreen() {
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [showDone, setShowDone] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const res = (await Api.get('/api/tasks', { includeDone: 'true' })) as TaskItem[];
    setTasks(res);
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

  const toggle = async (t: TaskItem) => {
    try {
      await Api.post(`/api/tasks/${t.id}/toggle`);
      if (!t.done && t.repeat !== 'none') toast('Odhaczone! Zaplanowałam kolejny termin 📅');
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const remove = async (t: TaskItem) => {
    try {
      await Api.del(`/api/tasks/${t.id}`);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const item = (t: TaskItem) => {
    const sub = [
      t.dueDate ? prettyDate(t.dueDate) : null,
      t.repeat !== 'none' ? `🔁 ${repeatLabels[t.repeat]?.toLowerCase()}` : null,
    ]
      .filter(Boolean)
      .join(' · ');
    return (
      <TouchableOpacity
        key={t.id}
        onPress={() => {
          setStash(t);
          router.push('/task-edit');
        }}
      >
        <Card>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <CheckCircle checked={t.done} onPress={() => toggle(t)} />
            <View style={{ flex: 1 }}>
              <Text style={[styles.title, t.done ? styles.struck : null]}>{t.title}</Text>
              {sub ? <Text style={styles.sub}>{sub}</Text> : null}
            </View>
            <TouchableOpacity onPress={() => remove(t)} hitSlop={8}>
              <Ionicons name="trash-outline" size={19} color={colors.muted} />
            </TouchableOpacity>
          </View>
        </Card>
      </TouchableOpacity>
    );
  };

  const active = tasks.filter((t) => !t.done);
  const done = tasks.filter((t) => t.done);

  return (
    <>
      <Stack.Screen options={{ title: 'Obowiązki ✅' }} />
      <View style={{ flex: 1 }}>
        <ScrollView
          contentContainerStyle={{ padding: 16, paddingBottom: 96 }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        >
          {active.length === 0 ? (
            <EmptyState emoji="🏖️" text={'Wszystko zrobione.\nCzas na kawę!'} />
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
            router.push('/task-edit');
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
