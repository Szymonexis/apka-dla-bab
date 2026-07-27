import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import { FlatList, RefreshControl, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { EmptyState, Fab, PageHeader, showError } from '../../components/ui';
import { Api } from '../../lib/api';
import type { Note } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors, radius } from '../../lib/theme';

export default function NotesScreen() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    const res = (await Api.get('/api/notes')) as Note[];
    setNotes(res);
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

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top']}>
      <PageHeader title="Notatki 📝" />
      <FlatList
        data={notes}
        keyExtractor={(n) => n.id}
        numColumns={2}
        columnWrapperStyle={{ gap: 10 }}
        contentContainerStyle={{ padding: 16, paddingBottom: 96, gap: 10 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
        ListEmptyComponent={
          <EmptyState emoji="📝" text={'Brak notatek.\nZapisz coś, zanim wyleci z głowy!'} />
        }
        renderItem={({ item: n }) => (
          <TouchableOpacity
            style={styles.note}
            onPress={() => {
              setStash(n);
              router.push('/note-edit');
            }}
          >
            <View style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
              <Text style={styles.noteTitle} numberOfLines={2}>
                {n.title || '(bez tytułu)'}
              </Text>
              {n.pinned ? <Ionicons name="pin" size={14} color={colors.primary} /> : null}
            </View>
            <Text style={styles.noteContent} numberOfLines={6}>
              {n.content}
            </Text>
          </TouchableOpacity>
        )}
      />
      <Fab
        onPress={() => {
          setStash(undefined);
          router.push('/note-edit');
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  note: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    padding: 12,
    minHeight: 120,
  },
  noteTitle: { flex: 1, fontWeight: '700', color: colors.text, marginBottom: 4 },
  noteContent: { color: colors.muted, fontSize: 13 },
});
