import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import {
  Alert,
  Platform,
  StyleSheet,
  Text,
  ToastAndroid,
  TouchableOpacity,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';

import { colors, radius } from '../lib/theme';

export function toast(message: string): void {
  if (Platform.OS === 'android') {
    ToastAndroid.show(message, ToastAndroid.SHORT);
  } else {
    Alert.alert('', message);
  }
}

export function showError(error: unknown): void {
  toast(error instanceof Error ? error.message : String(error));
}

export function confirmDelete(what: string): Promise<boolean> {
  return new Promise((resolve) => {
    Alert.alert('Na pewno usunąć?', what, [
      { text: 'Anuluj', style: 'cancel', onPress: () => resolve(false) },
      { text: 'Usuń', style: 'destructive', onPress: () => resolve(true) },
    ]);
  });
}

export function Card({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

export function SectionHeader({ title, right }: { title: string; right?: React.ReactNode }) {
  return (
    <View style={styles.sectionHeader}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {right}
    </View>
  );
}

export function EmptyState({ emoji, text }: { emoji: string; text: string }) {
  return (
    <View style={styles.empty}>
      <Text style={{ fontSize: 40 }}>{emoji}</Text>
      <Text style={styles.emptyText}>{text}</Text>
    </View>
  );
}

export function Fab({ onPress, icon = 'add' }: { onPress: () => void; icon?: keyof typeof Ionicons.glyphMap }) {
  return (
    <TouchableOpacity style={styles.fab} onPress={onPress} activeOpacity={0.8}>
      <Ionicons name={icon} size={28} color="#fff" />
    </TouchableOpacity>
  );
}

/** Nagłówek zakładki (zamiast natywnego headera): tytuł + akcje po prawej. */
export function PageHeader({
  title,
  subtitle,
  right,
}: {
  title: string;
  subtitle?: string;
  right?: React.ReactNode;
}) {
  return (
    <View style={styles.pageHeader}>
      <View style={{ flex: 1 }}>
        <Text style={styles.pageTitle}>{title}</Text>
        {subtitle ? <Text style={styles.pageSubtitle}>{subtitle}</Text> : null}
      </View>
      {right}
    </View>
  );
}

export function HeaderIcon({
  name,
  onPress,
}: {
  name: keyof typeof Ionicons.glyphMap;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity onPress={onPress} style={styles.headerIcon} hitSlop={8}>
      <Ionicons name={name} size={24} color={colors.text} />
    </TouchableOpacity>
  );
}

export function CheckCircle({ checked, onPress }: { checked: boolean; onPress: () => void }) {
  return (
    <TouchableOpacity onPress={onPress} hitSlop={8} style={{ marginRight: 10 }}>
      <Ionicons
        name={checked ? 'checkmark-circle' : 'ellipse-outline'}
        size={26}
        color={checked ? colors.primary : colors.muted}
      />
    </TouchableOpacity>
  );
}

export function Chip({ label }: { label: string }) {
  return (
    <View style={styles.chip}>
      <Text style={styles.chipText}>{label}</Text>
    </View>
  );
}

export function ProgressBar({ value, over }: { value: number; over?: boolean }) {
  return (
    <View style={styles.progressTrack}>
      <View
        style={[
          styles.progressFill,
          { width: `${Math.min(100, Math.max(0, value * 100))}%` },
          over ? { backgroundColor: colors.error } : null,
        ]}
      />
    </View>
  );
}

/** Wiersz nawigacji tydzień/miesiąc/dzień: ‹ tekst › [+ opcjonalny przycisk] */
export function NavRow({
  label,
  onPrev,
  onNext,
  right,
}: {
  label: string;
  onPrev: () => void;
  onNext: () => void;
  right?: React.ReactNode;
}) {
  return (
    <View style={styles.navRow}>
      <HeaderIcon name="chevron-back" onPress={onPrev} />
      <Text style={styles.navLabel}>{label}</Text>
      <HeaderIcon name="chevron-forward" onPress={onNext} />
      {right}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: radius.card,
    padding: 12,
    marginVertical: 5,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 18,
    marginBottom: 6,
    paddingHorizontal: 4,
  },
  sectionTitle: { flex: 1, fontSize: 16, fontWeight: '700', color: colors.text },
  empty: { alignItems: 'center', padding: 24 },
  emptyText: { color: colors.muted, textAlign: 'center', marginTop: 8 },
  fab: {
    position: 'absolute',
    right: 20,
    bottom: 24,
    width: 56,
    height: 56,
    borderRadius: 18,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
  },
  pageHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 4,
  },
  pageTitle: { fontSize: 22, fontWeight: '800', color: colors.text },
  pageSubtitle: { fontSize: 13, color: colors.muted, marginTop: 2 },
  headerIcon: { padding: 6 },
  chip: {
    backgroundColor: colors.primaryContainer,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 4,
    marginRight: 6,
    marginBottom: 6,
  },
  chipText: { fontSize: 12, color: colors.text },
  progressTrack: {
    height: 6,
    borderRadius: 3,
    backgroundColor: colors.primaryContainer,
    overflow: 'hidden',
    marginTop: 6,
  },
  progressFill: { height: 6, borderRadius: 3, backgroundColor: colors.primary },
  navRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 4,
  },
  navLabel: { fontWeight: '700', color: colors.text, marginHorizontal: 4 },
});
