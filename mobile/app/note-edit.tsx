import { Ionicons } from '@expo/vector-icons';
import { Stack, router } from 'expo-router';
import React, { useState } from 'react';
import { StyleSheet, TextInput, TouchableOpacity, View } from 'react-native';

import { confirmDelete, showError } from '../components/ui';
import { Api } from '../lib/api';
import type { Note } from '../lib/models';
import { takeStash } from '../lib/stash';
import { colors } from '../lib/theme';

export default function NoteEditScreen() {
  const [existing] = useState(() => takeStash<Note>());
  const [title, setTitle] = useState(existing?.title ?? '');
  const [content, setContent] = useState(existing?.content ?? '');
  const [pinned, setPinned] = useState(existing?.pinned ?? false);

  const save = async () => {
    if (!title.trim() && !content.trim()) {
      showError('Notatka nie może być pusta');
      return;
    }
    try {
      const body = { title: title.trim(), content, pinned };
      if (existing) {
        await Api.put(`/api/notes/${existing.id}`, body);
      } else {
        await Api.post('/api/notes', body);
      }
      router.back();
    } catch (e) {
      showError(e);
    }
  };

  const remove = async () => {
    if (!existing) return;
    if (!(await confirmDelete('Notatka zostanie usunięta.'))) return;
    try {
      await Api.del(`/api/notes/${existing.id}`);
      router.back();
    } catch (e) {
      showError(e);
    }
  };

  return (
    <>
      <Stack.Screen
        options={{
          title: existing ? 'Notatka' : 'Nowa notatka',
          headerRight: () => (
            <View style={{ flexDirection: 'row' }}>
              <TouchableOpacity onPress={() => setPinned(!pinned)} style={styles.action} hitSlop={8}>
                <Ionicons
                  name={pinned ? 'pin' : 'pin-outline'}
                  size={22}
                  color={pinned ? colors.primary : colors.text}
                />
              </TouchableOpacity>
              {existing ? (
                <TouchableOpacity onPress={remove} style={styles.action} hitSlop={8}>
                  <Ionicons name="trash-outline" size={22} color={colors.text} />
                </TouchableOpacity>
              ) : null}
              <TouchableOpacity onPress={save} style={styles.action} hitSlop={8}>
                <Ionicons name="checkmark" size={26} color={colors.primary} />
              </TouchableOpacity>
            </View>
          ),
        }}
      />
      <View style={{ flex: 1, paddingHorizontal: 16 }}>
        <TextInput
          style={styles.title}
          placeholder="Tytuł"
          placeholderTextColor={colors.muted}
          value={title}
          onChangeText={setTitle}
          autoFocus={!existing}
          autoCapitalize="sentences"
        />
        <View style={styles.divider} />
        <TextInput
          style={styles.content}
          placeholder="Pisz śmiało..."
          placeholderTextColor={colors.muted}
          value={content}
          onChangeText={setContent}
          multiline
          textAlignVertical="top"
          autoCapitalize="sentences"
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  action: { paddingHorizontal: 8, paddingVertical: 4 },
  title: { fontSize: 22, fontWeight: '700', color: colors.text, paddingVertical: 10 },
  divider: { height: 1, backgroundColor: colors.outline },
  content: { flex: 1, fontSize: 16, color: colors.text, paddingTop: 10 },
});
