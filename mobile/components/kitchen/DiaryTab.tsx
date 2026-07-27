import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Api } from '../../lib/api';
import type { DiaryEntry } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors } from '../../lib/theme';
import {
  addDays,
  dateStr,
  dayOnly,
  longDate,
  mealOrder,
  mealTypeEmoji,
  mealTypeLabels,
  todayStr,
} from '../../lib/util';
import { Card, EmptyState, Fab, NavRow, showError } from '../ui';

export default function DiaryTab() {
  const [date, setDate] = useState(() => dayOnly(new Date()));
  const [entries, setEntries] = useState<DiaryEntry[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const ds = dateStr(date);
    const res = (await Api.get('/api/diary', { from: ds, to: ds })) as DiaryEntry[];
    setEntries([...res].sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType)));
  }, [date]);

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

  const remove = async (e: DiaryEntry) => {
    try {
      await Api.del(`/api/diary/${e.id}`);
      await load();
    } catch (err) {
      showError(err);
    }
  };

  const totalKcal = entries.reduce((sum, e) => sum + (e.calories ?? 0), 0);
  const isToday = dateStr(date) === todayStr();

  return (
    <View style={{ flex: 1 }}>
      <NavRow
        label={longDate(date)}
        onPrev={() => setDate(addDays(date, -1))}
        onNext={() => setDate(addDays(date, 1))}
        right={
          !isToday ? (
            <TouchableOpacity onPress={() => setDate(dayOnly(new Date()))} style={{ marginLeft: 6 }}>
              <Text style={{ color: colors.primary, fontWeight: '700' }}>Dziś</Text>
            </TouchableOpacity>
          ) : undefined
        }
      />
      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 96 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        <Card>
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <Text style={{ fontSize: 24, marginRight: 10 }}>🔥</Text>
            <View>
              <Text style={{ fontWeight: '800', fontSize: 17, color: colors.text }}>
                {totalKcal} kcal
              </Text>
              <Text style={{ color: colors.muted, fontSize: 12.5 }}>suma z wpisów tego dnia</Text>
            </View>
          </View>
        </Card>

        {entries.length === 0 ? (
          <EmptyState emoji="🥣" text={'Brak wpisów.\nDodaj plusem, co zjadłaś!'} />
        ) : null}

        {entries.map((e) => (
          <TouchableOpacity
            key={e.id}
            onPress={() => {
              setStash(e);
              router.push({ pathname: '/diary-edit', params: { date: e.date } });
            }}
          >
            <Card>
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Text style={{ fontSize: 22, marginRight: 10 }}>
                  {mealTypeEmoji[e.mealType] ?? '🍽️'}
                </Text>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: colors.text }}>{e.description}</Text>
                  <Text style={{ color: colors.muted, fontSize: 12.5 }}>
                    {[mealTypeLabels[e.mealType] ?? e.mealType, e.calories ? `${e.calories} kcal` : null]
                      .filter(Boolean)
                      .join(' · ')}
                  </Text>
                </View>
                <TouchableOpacity onPress={() => remove(e)} hitSlop={8}>
                  <Ionicons name="trash-outline" size={19} color={colors.muted} />
                </TouchableOpacity>
              </View>
            </Card>
          </TouchableOpacity>
        ))}
      </ScrollView>
      <Fab
        onPress={() => {
          setStash(undefined);
          router.push({ pathname: '/diary-edit', params: { date: dateStr(date) } });
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({});
