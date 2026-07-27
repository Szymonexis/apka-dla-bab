import { router } from 'expo-router';
import React, { useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Input, PrimaryButton } from '../components/forms';
import { HeaderIcon, showError } from '../components/ui';
import { Api } from '../lib/api';
import { colors } from '../lib/theme';

export default function LoginScreen() {
  const [registerMode, setRegisterMode] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    setBusy(true);
    try {
      if (registerMode) {
        await Api.register(email.trim(), password, name.trim());
      } else {
        await Api.login(email.trim(), password);
      }
      router.replace('/');
    } catch (e) {
      showError(e);
    } finally {
      setBusy(false);
    }
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }}>
      <View style={{ alignItems: 'flex-end', paddingHorizontal: 12 }}>
        <HeaderIcon name="settings-outline" onPress={() => router.push('/settings')} />
      </View>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView contentContainerStyle={styles.container} keyboardShouldPersistTaps="handled">
          <Text style={styles.emoji}>🏡💗</Text>
          <Text style={styles.title}>Ogarniaczka</Text>
          <Text style={styles.subtitle}>Twój domowy organizer - wszystko w jednym miejscu</Text>
          <View style={{ height: 24 }} />
          {registerMode ? (
            <Input
              label="Jak masz na imię?"
              value={name}
              onChangeText={setName}
              autoCapitalize="words"
            />
          ) : null}
          <Input
            label="E-mail"
            value={email}
            onChangeText={setEmail}
            keyboardType="email-address"
            autoCapitalize="none"
            autoCorrect={false}
          />
          <Input
            label="Hasło"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            onSubmitEditing={() => !busy && submit()}
          />
          <PrimaryButton
            title={busy ? '...' : registerMode ? 'Załóż konto' : 'Zaloguj się'}
            onPress={submit}
            disabled={busy}
          />
          <TouchableOpacity onPress={() => setRegisterMode(!registerMode)} style={{ marginTop: 14 }}>
            <Text style={styles.switchText}>
              {registerMode ? 'Masz już konto? Zaloguj się' : 'Nie masz konta? Zarejestruj się'}
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 24, maxWidth: 440, width: '100%', alignSelf: 'center' },
  emoji: { fontSize: 54, textAlign: 'center' },
  title: { fontSize: 30, fontWeight: '800', textAlign: 'center', color: colors.text, marginTop: 6 },
  subtitle: { textAlign: 'center', color: colors.muted, marginTop: 4 },
  switchText: { textAlign: 'center', color: colors.primary, fontWeight: '600' },
});
