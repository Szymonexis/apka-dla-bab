import { Ionicons } from '@expo/vector-icons';
import { router, useFocusEffect } from 'expo-router';
import React, { useCallback, useState } from 'react';
import {
  Modal,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Input, OutlineButton, PickerField, PrimaryButton } from '../../components/forms';
import {
  Card,
  EmptyState,
  Fab,
  NavRow,
  PageHeader,
  ProgressBar,
  SectionHeader,
  showError,
} from '../../components/ui';
import { Api } from '../../lib/api';
import type { BudgetSummary, Tx } from '../../lib/models';
import { setStash } from '../../lib/stash';
import { colors, radius } from '../../lib/theme';
import {
  categoryEmoji,
  formatMoney,
  monthHeader,
  monthStr,
  parseMoney,
  prettyDate,
  txCategories,
} from '../../lib/util';

export default function BudgetScreen() {
  const [month, setMonth] = useState(() => new Date(new Date().getFullYear(), new Date().getMonth(), 1));
  const [summary, setSummary] = useState<BudgetSummary | null>(null);
  const [txs, setTxs] = useState<Tx[]>([]);
  const [refreshing, setRefreshing] = useState(false);
  const [limitCategory, setLimitCategory] = useState<string | null>(null);
  const [limitInput, setLimitInput] = useState('');

  const load = useCallback(async () => {
    const m = monthStr(month);
    const [s, t] = await Promise.all([
      Api.get('/api/budget/summary', { month: m }) as Promise<BudgetSummary>,
      Api.get('/api/transactions', { month: m }) as Promise<Tx[]>,
    ]);
    setSummary(s);
    setTxs(t);
  }, [month]);

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

  const shiftMonth = (delta: number) => {
    setMonth(new Date(month.getFullYear(), month.getMonth() + delta, 1));
  };

  const openLimit = (category: string, currentLimit: number) => {
    setLimitCategory(category);
    setLimitInput(currentLimit > 0 ? (currentLimit / 100).toFixed(2).replace('.', ',') : '');
  };

  const saveLimit = async () => {
    if (!limitCategory) return;
    const grosze = parseMoney(limitInput) ?? 0;
    try {
      await Api.put('/api/budget/limits', {
        month: monthStr(month),
        category: limitCategory,
        limitGrosze: grosze,
      });
      setLimitCategory(null);
      await load();
    } catch (e) {
      showError(e);
    }
  };

  const balance = (summary?.incomeGrosze ?? 0) - (summary?.expenseGrosze ?? 0);
  const existing = new Set(summary?.categories.map((c) => c.category) ?? []);
  const addable = txCategories.filter((c) => !existing.has(c));
  const [pickAddCategory, setPickAddCategory] = useState(false);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top']}>
      <PageHeader title="Budżet domowy 💰" />
      <NavRow label={monthHeader(month)} onPrev={() => shiftMonth(-1)} onNext={() => shiftMonth(1)} />
      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 96 }}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        <Card>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <View>
              <Text style={styles.smallLabel}>Przychody</Text>
              <Text style={[styles.money, { color: colors.green }]}>
                {formatMoney(summary?.incomeGrosze ?? 0)}
              </Text>
              <Text style={[styles.smallLabel, { marginTop: 8 }]}>Wydatki</Text>
              <Text style={[styles.money, { color: colors.error }]}>
                {formatMoney(summary?.expenseGrosze ?? 0)}
              </Text>
            </View>
            <View style={{ alignItems: 'flex-end' }}>
              <Text style={styles.smallLabel}>Bilans</Text>
              <Text
                style={[
                  styles.money,
                  { fontSize: 24, color: balance >= 0 ? colors.green : colors.error },
                ]}
              >
                {formatMoney(balance)}
              </Text>
            </View>
          </View>
        </Card>

        <SectionHeader
          title="📊 Kategorie i limity"
          right={
            addable.length > 0 ? (
              <TouchableOpacity onPress={() => setPickAddCategory(true)}>
                <Text style={{ color: colors.primary, fontWeight: '700' }}>+ Limit</Text>
              </TouchableOpacity>
            ) : undefined
          }
        />
        {!summary || summary.categories.length === 0 ? (
          <Card>
            <EmptyState emoji="🧮" text={'Dodaj wydatki albo ustaw limity,\nżeby coś tu zobaczyć'} />
          </Card>
        ) : (
          summary.categories.map((c) => {
            const over = c.limitGrosze > 0 && c.spentGrosze > c.limitGrosze;
            return (
              <TouchableOpacity key={c.category} onPress={() => openLimit(c.category, c.limitGrosze)}>
                <Card>
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <Text style={{ fontSize: 22, marginRight: 10 }}>
                      {categoryEmoji[c.category] ?? '✨'}
                    </Text>
                    <Text style={{ flex: 1, fontWeight: '600', color: colors.text }}>{c.category}</Text>
                    <View style={{ alignItems: 'flex-end' }}>
                      <Text style={{ fontWeight: '700', color: over ? colors.error : colors.text }}>
                        {formatMoney(c.spentGrosze)}
                      </Text>
                      {c.limitGrosze > 0 ? (
                        <Text style={{ fontSize: 11, color: colors.muted }}>
                          z {formatMoney(c.limitGrosze)}
                        </Text>
                      ) : null}
                    </View>
                  </View>
                  {c.limitGrosze > 0 ? (
                    <ProgressBar value={c.spentGrosze / c.limitGrosze} over={over} />
                  ) : null}
                </Card>
              </TouchableOpacity>
            );
          })
        )}

        <SectionHeader title="🧾 Transakcje" />
        {txs.length === 0 ? (
          <Card>
            <EmptyState emoji="🛍️" text={'Brak transakcji w tym miesiącu.\nDodaj plusem!'} />
          </Card>
        ) : (
          txs.map((t) => (
            <TouchableOpacity
              key={t.id}
              onPress={() => {
                setStash(t);
                router.push('/transaction');
              }}
            >
              <Card>
                <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                  <Text style={{ fontSize: 22, marginRight: 10 }}>
                    {t.kind === 'income' ? '💵' : (categoryEmoji[t.category] ?? '✨')}
                  </Text>
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: colors.text }}>{t.description || t.category}</Text>
                    <Text style={{ color: colors.muted, fontSize: 12.5 }}>
                      {prettyDate(t.occurredOn)} · {t.category}
                    </Text>
                  </View>
                  {t.receiptFileId ? (
                    <TouchableOpacity
                      hitSlop={8}
                      style={{ marginRight: 8 }}
                      onPress={() =>
                        router.push({ pathname: '/photo', params: { fileId: t.receiptFileId! } })
                      }
                    >
                      <Ionicons name="receipt-outline" size={22} color={colors.primary} />
                    </TouchableOpacity>
                  ) : null}
                  <Text
                    style={{
                      fontWeight: '700',
                      color: t.kind === 'income' ? colors.green : colors.error,
                    }}
                  >
                    {t.kind === 'income' ? '+' : '-'}
                    {formatMoney(t.amountGrosze)}
                  </Text>
                </View>
              </Card>
            </TouchableOpacity>
          ))
        )}
      </ScrollView>

      <Fab
        onPress={() => {
          setStash(undefined);
          router.push('/transaction');
        }}
      />

      {/* wybór kategorii dla nowego limitu */}
      <Modal visible={pickAddCategory} transparent animationType="fade">
        <TouchableOpacity
          style={styles.backdrop}
          activeOpacity={1}
          onPress={() => setPickAddCategory(false)}
        >
          <View style={styles.dialog}>
            <Text style={styles.dialogTitle}>Limit dla kategorii</Text>
            <ScrollView style={{ maxHeight: 380 }}>
              {addable.map((c) => (
                <TouchableOpacity
                  key={c}
                  style={styles.option}
                  onPress={() => {
                    setPickAddCategory(false);
                    openLimit(c, 0);
                  }}
                >
                  <Text style={{ color: colors.text }}>
                    {categoryEmoji[c] ?? '✨'} {c}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>
        </TouchableOpacity>
      </Modal>

      {/* edycja limitu */}
      <Modal visible={limitCategory != null} transparent animationType="fade">
        <View style={styles.backdrop}>
          <View style={styles.dialog}>
            <Text style={styles.dialogTitle}>
              Limit: {limitCategory ? `${categoryEmoji[limitCategory] ?? '✨'} ${limitCategory}` : ''}
            </Text>
            <Input
              label="Limit miesięczny (zł)"
              placeholder="0 = usuń limit"
              value={limitInput}
              onChangeText={setLimitInput}
              keyboardType="decimal-pad"
              autoFocus
            />
            <PrimaryButton title="Zapisz" onPress={saveLimit} />
            <OutlineButton title="Anuluj" onPress={() => setLimitCategory(null)} style={{ marginTop: 8 }} />
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  smallLabel: { fontSize: 12, color: colors.muted },
  money: { fontWeight: '700', fontSize: 16, color: colors.text },
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    justifyContent: 'center',
    padding: 28,
  },
  dialog: { backgroundColor: colors.surface, borderRadius: radius.card, padding: 18 },
  dialogTitle: { fontWeight: '800', fontSize: 17, color: colors.text, marginBottom: 12 },
  option: { paddingVertical: 12 },
});
