import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { Stack, router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { Input, OutlineButton, PickerField, PrimaryButton } from '../components/forms';
import { Card, SectionHeader, confirmDelete, showError, toast } from '../components/ui';
import { Api } from '../lib/api';
import type { PushSettings } from '../lib/models';
import { colors } from '../lib/theme';

export default function SettingsScreen() {
  const [url, setUrl] = useState(Api.baseUrl);
  const [push, setPush] = useState<PushSettings | null>(null);

  useEffect(() => {
    if (Api.isLoggedIn) {
      (Api.get('/api/push/settings') as Promise<PushSettings>).then(setPush).catch(() => {});
    }
  }, []);

  const saveUrl = async () => {
    await Api.setBaseUrl(url);
    setUrl(Api.baseUrl);
    toast('Zapisano adres serwera');
  };

  const testConnection = async () => {
    await Api.setBaseUrl(url);
    try {
      await Api.get('/healthz');
      toast('Połączenie działa! 🎉');
    } catch (e) {
      showError(e);
    }
  };

  const setDigestHour = async (hour: number) => {
    try {
      const res = (await Api.put('/api/push/settings', { digestHour: hour })) as PushSettings;
      setPush(res);
    } catch (e) {
      showError(e);
    }
  };

  const testPush = async () => {
    try {
      await Api.post('/api/push/test');
      toast('Wysłane! Sprawdź powiadomienie z ntfy 🎉');
    } catch (e) {
      showError(e);
    }
  };

  const regenerate = async () => {
    if (
      !(await confirmDelete(
        'Stary temat przestanie działać - trzeba będzie zmienić subskrypcję w aplikacji ntfy.',
      ))
    ) {
      return;
    }
    try {
      const res = (await Api.post('/api/push/regenerate')) as PushSettings;
      setPush(res);
      toast('Wygenerowano nowy temat');
    } catch (e) {
      showError(e);
    }
  };

  const copy = async (label: string, value: string) => {
    await Clipboard.setStringAsync(value);
    toast(`Skopiowano ${label}`);
  };

  const logout = async () => {
    await Api.logout();
    router.replace('/login');
  };

  return (
    <>
      <Stack.Screen options={{ title: 'Ustawienia ⚙️' }} />
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <SectionHeader title="🌐 Serwer" />
        <Input
          label="Adres serwera"
          value={url}
          onChangeText={setUrl}
          keyboardType="url"
          autoCapitalize="none"
          autoCorrect={false}
          placeholder="http://10.0.2.2:8080"
        />
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <OutlineButton title="Sprawdź połączenie" onPress={testConnection} style={{ flex: 1 }} />
          <PrimaryButton title="Zapisz" onPress={saveUrl} />
        </View>
        <Card style={{ marginTop: 12 }}>
          <Text style={styles.hint}>
            Podpowiedź 💡{'\n\n'}• Emulator Androida: http://10.0.2.2:8080{'\n'}• Prawdziwy telefon
            (i Expo Go): adres IP komputera z backendem w tej samej sieci Wi-Fi, np.
            http://192.168.1.20:8080
          </Text>
        </Card>

        {Api.isLoggedIn ? (
          <>
            <SectionHeader title="🔔 Powiadomienia" />
            <Card>
              <Text style={styles.hint}>
                Przypomnienia dzwonią na tym telefonie automatycznie (lokalne alarmy - działają bez
                internetu). Poniższy push przez Twój własny serwer ntfy to opcjonalny dodatek:
                dociera nawet wtedy, gdy Ogarniaczka jest zamknięta, i na inne urządzenia.
              </Text>
            </Card>
            {push && !push.enabled ? (
              <Card>
                <Text style={styles.hint}>
                  Serwer push (ntfy) nie jest skonfigurowany na backendzie.{'\n'}Uruchom kontener
                  ntfy z docker-compose i ustaw NTFY_URL.
                </Text>
              </Card>
            ) : null}
            {push?.enabled ? (
              <>
                <Card>
                  <SettingRow
                    icon="server-outline"
                    title="Serwer ntfy"
                    subtitle={push.serverUrl}
                    onCopy={() => copy('adres serwera', push.serverUrl)}
                  />
                  <SettingRow
                    icon="key-outline"
                    title="Twój sekretny temat"
                    subtitle={push.topic}
                    onCopy={() => copy('temat', push.topic)}
                  />
                  <PickerField
                    label="Poranne podsumowanie obowiązków"
                    value={String(push.digestHour)}
                    onChange={(v) => setDigestHour(parseInt(v, 10))}
                    options={[
                      { value: '-1', label: 'wyłączone' },
                      ...Array.from({ length: 8 }, (_, i) => i + 5).map((h) => ({
                        value: String(h),
                        label: `${h}:00`,
                      })),
                    ]}
                  />
                  <View style={{ flexDirection: 'row', gap: 8 }}>
                    <OutlineButton title="Wyślij testowe" onPress={testPush} style={{ flex: 1 }} />
                    <OutlineButton title="Nowy temat" onPress={regenerate} style={{ flex: 1 }} />
                  </View>
                </Card>
                <Card>
                  <Text style={styles.hint}>
                    Jak włączyć push na telefonie 📲{'\n\n'}1. Zainstaluj darmową aplikację "ntfy"
                    (Google Play lub F-Droid).{'\n'}2. W ntfy: Dodaj subskrypcję → wklej temat
                    skopiowany powyżej.{'\n'}3. W "Użyj innego serwera" podaj adres serwera ntfy z
                    tej strony.{'\n'}4. Kliknij "Wyślij testowe" i sprawdź, czy przyszło. 🎉{'\n\n'}
                    Temat traktuj jak hasło - kto go zna, może czytać Twoje powiadomienia.
                  </Text>
                </Card>
              </>
            ) : null}

            <SectionHeader title="👤 Konto" />
            <Card>
              <View style={{ flexDirection: 'row', alignItems: 'center', marginBottom: 10 }}>
                <Ionicons name="person-outline" size={20} color={colors.text} style={{ marginRight: 8 }} />
                <Text style={{ color: colors.text }}>{Api.displayName || 'Zalogowano'}</Text>
              </View>
              <OutlineButton title="Wyloguj się" onPress={logout} danger />
            </Card>
          </>
        ) : null}
      </ScrollView>
    </>
  );
}

function SettingRow({
  icon,
  title,
  subtitle,
  onCopy,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  title: string;
  subtitle: string;
  onCopy: () => void;
}) {
  return (
    <View style={styles.row}>
      <Ionicons name={icon} size={20} color={colors.text} style={{ marginRight: 10 }} />
      <View style={{ flex: 1 }}>
        <Text style={{ color: colors.text }}>{title}</Text>
        <Text style={{ color: colors.muted, fontSize: 12 }}>{subtitle}</Text>
      </View>
      <TouchableOpacity onPress={onCopy} hitSlop={8}>
        <Ionicons name="copy-outline" size={19} color={colors.primary} />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  hint: { color: colors.text, fontSize: 13, lineHeight: 19 },
  row: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8 },
});
