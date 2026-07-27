import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { Stack, router } from 'expo-router';
import React, { useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { DateField, Input, OutlineButton, PickerField, PrimaryButton, Segmented } from '../components/forms';
import { confirmDelete, showError } from '../components/ui';
import { Api } from '../lib/api';
import type { Tx } from '../lib/models';
import { takeStash } from '../lib/stash';
import { colors } from '../lib/theme';
import { categoryEmoji, parseMoney, todayStr, txCategories } from '../lib/util';
import { pickPhoto } from './recipe-edit';

export default function TransactionScreen() {
  const [existing] = useState(() => takeStash<Tx>());
  const [kind, setKind] = useState<string>(existing?.kind ?? 'expense');
  const [amount, setAmount] = useState(
    existing ? (existing.amountGrosze / 100).toFixed(2).replace('.', ',') : '',
  );
  const [category, setCategory] = useState(existing?.category ?? 'jedzenie');
  const [date, setDate] = useState<string | null>(existing?.occurredOn ?? todayStr());
  const [description, setDescription] = useState(existing?.description ?? '');
  const [receiptFileId, setReceiptFileId] = useState(existing?.receiptFileId ?? null);
  const [pickedUri, setPickedUri] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const categories = [...new Set([...txCategories, category])];

  const save = async () => {
    const grosze = parseMoney(amount);
    if (!grosze || grosze <= 0) {
      showError('Podaj prawidłową kwotę, np. 24,99');
      return;
    }
    if (!date) {
      showError('Wybierz datę');
      return;
    }
    setBusy(true);
    try {
      let receiptId = receiptFileId;
      if (pickedUri) receiptId = await Api.uploadFile(pickedUri);
      const body = {
        occurredOn: date,
        kind,
        amountGrosze: grosze,
        category,
        description: description.trim(),
        receiptFileId: receiptId,
      };
      if (existing) {
        await Api.put(`/api/transactions/${existing.id}`, body);
      } else {
        await Api.post('/api/transactions', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!existing) return;
    if (!(await confirmDelete('Transakcja zostanie usunięta.'))) return;
    try {
      await Api.del(`/api/transactions/${existing.id}`);
      router.back();
    } catch (e) {
      showError(e);
    }
  };

  const receiptUri = pickedUri ?? (receiptFileId ? Api.fileUrl(receiptFileId) : null);

  return (
    <>
      <Stack.Screen
        options={{
          title: existing ? 'Edytuj transakcję' : 'Nowa transakcja',
          headerRight: () =>
            existing ? (
              <TouchableOpacity onPress={remove} hitSlop={8} style={{ padding: 6 }}>
                <Ionicons name="trash-outline" size={22} color={colors.text} />
              </TouchableOpacity>
            ) : null,
        }}
      />
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <Segmented
          value={kind}
          onChange={setKind}
          options={[
            { value: 'expense', label: '− Wydatek' },
            { value: 'income', label: '+ Przychód' },
          ]}
        />
        <Input
          label="Kwota (zł)"
          value={amount}
          onChangeText={setAmount}
          keyboardType="decimal-pad"
          autoFocus={!existing}
          style={{ fontSize: 24, fontWeight: '700' }}
        />
        <PickerField
          label="Kategoria"
          value={category}
          onChange={setCategory}
          options={categories.map((c) => ({ value: c, label: `${categoryEmoji[c] ?? '✨'} ${c}` }))}
        />
        <DateField label="Data" value={date} onChange={setDate} />
        <Input
          label="Opis (np. Biedronka, rachunek za prąd)"
          value={description}
          onChangeText={setDescription}
          autoCapitalize="sentences"
        />
        <Text style={styles.receiptLabel}>Paragon 🧾</Text>
        {receiptUri ? (
          <Image
            source={{ uri: receiptUri, headers: pickedUri ? undefined : Api.imageHeaders }}
            style={styles.receipt}
            contentFit="cover"
          />
        ) : null}
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <OutlineButton
            title={receiptUri ? '📷 Zmień zdjęcie' : '📷 Dodaj zdjęcie paragonu'}
            onPress={async () => {
              const uri = await pickPhoto();
              if (uri) setPickedUri(uri);
            }}
            style={{ flex: 1 }}
          />
          {receiptUri ? (
            <OutlineButton
              title="Usuń"
              onPress={() => {
                setPickedUri(null);
                setReceiptFileId(null);
              }}
            />
          ) : null}
        </View>
        <View style={{ height: 12 }} />
        <PrimaryButton title="Zapisz" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  receiptLabel: { fontWeight: '700', color: colors.text, marginBottom: 8, marginTop: 4 },
  receipt: { height: 200, borderRadius: 12, marginBottom: 10 },
});
