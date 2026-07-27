import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { Stack, router } from 'expo-router';
import React, { useState } from 'react';
import { Alert, ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

import { Input, OutlineButton, PrimaryButton } from '../components/forms';
import { showError } from '../components/ui';
import { Api } from '../lib/api';
import type { Recipe } from '../lib/models';
import { takeStash } from '../lib/stash';
import { colors } from '../lib/theme';

/** Wybór zdjęcia: aparat albo galeria. Zwraca lokalne uri albo null. */
export async function pickPhoto(): Promise<string | null> {
  return new Promise((resolve) => {
    Alert.alert('Zdjęcie', undefined, [
      { text: 'Anuluj', style: 'cancel', onPress: () => resolve(null) },
      {
        text: 'Galeria',
        onPress: async () => {
          const res = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ['images'],
            quality: 0.8,
          });
          resolve(res.canceled ? null : res.assets[0].uri);
        },
      },
      {
        text: 'Aparat',
        onPress: async () => {
          const perm = await ImagePicker.requestCameraPermissionsAsync();
          if (!perm.granted) {
            resolve(null);
            return;
          }
          const res = await ImagePicker.launchCameraAsync({ quality: 0.8 });
          resolve(res.canceled ? null : res.assets[0].uri);
        },
      },
    ]);
  });
}

export default function RecipeEditScreen() {
  const [existing] = useState(() => takeStash<Recipe>());
  const [title, setTitle] = useState(existing?.title ?? '');
  const [description, setDescription] = useState(existing?.description ?? '');
  const [ingredients, setIngredients] = useState(existing?.ingredients ?? '');
  const [steps, setSteps] = useState(existing?.steps ?? '');
  const [tags, setTags] = useState(existing?.tags.join(', ') ?? '');
  const [time, setTime] = useState(existing?.timeMinutes?.toString() ?? '');
  const [servings, setServings] = useState(existing?.servings?.toString() ?? '');
  const [favorite, setFavorite] = useState(existing?.favorite ?? false);
  const [imageFileId, setImageFileId] = useState(existing?.imageFileId ?? null);
  const [pickedUri, setPickedUri] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const save = async () => {
    if (!title.trim()) {
      showError('Przepis musi mieć nazwę');
      return;
    }
    setBusy(true);
    try {
      let imageId = imageFileId;
      if (pickedUri) imageId = await Api.uploadFile(pickedUri);
      const timeParsed = parseInt(time.trim(), 10);
      const servingsParsed = parseInt(servings.trim(), 10);
      const body = {
        title: title.trim(),
        description: description.trim(),
        ingredients: ingredients.trim(),
        steps: steps.trim(),
        tags: tags
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .filter(Boolean),
        timeMinutes: Number.isFinite(timeParsed) ? timeParsed : null,
        servings: Number.isFinite(servingsParsed) ? servingsParsed : null,
        favorite,
        imageFileId: imageId,
      };
      if (existing) {
        await Api.put(`/api/recipes/${existing.id}`, body);
      } else {
        await Api.post('/api/recipes', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      setBusy(false);
    }
  };

  const imageUri = pickedUri ?? (imageFileId ? Api.fileUrl(imageFileId) : null);

  return (
    <>
      <Stack.Screen options={{ title: existing ? 'Edytuj przepis' : 'Nowy przepis' }} />
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <Input label="Nazwa *" value={title} onChangeText={setTitle} autoCapitalize="sentences" />
        <Input label="Krótki opis" value={description} onChangeText={setDescription} autoCapitalize="sentences" />
        <View style={{ flexDirection: 'row', gap: 12 }}>
          <View style={{ flex: 1 }}>
            <Input label="Czas (min)" value={time} onChangeText={setTime} keyboardType="number-pad" />
          </View>
          <View style={{ flex: 1 }}>
            <Input label="Porcje" value={servings} onChangeText={setServings} keyboardType="number-pad" />
          </View>
        </View>
        <Input label="Tagi (po przecinku)" placeholder="obiad, szybkie, wege" value={tags} onChangeText={setTags} />
        <Input
          label="Składniki (każdy w nowej linii)"
          value={ingredients}
          onChangeText={setIngredients}
          multiline
          autoCapitalize="sentences"
        />
        <Input
          label="Przygotowanie"
          value={steps}
          onChangeText={setSteps}
          multiline
          autoCapitalize="sentences"
        />
        <View style={styles.switchRow}>
          <Text style={{ color: colors.text, flex: 1 }}>Ulubiony 💗</Text>
          <Switch
            value={favorite}
            onValueChange={setFavorite}
            trackColor={{ true: colors.primaryContainer }}
            thumbColor={favorite ? colors.primary : undefined}
          />
        </View>
        {imageUri ? (
          <Image
            source={{ uri: imageUri, headers: pickedUri ? undefined : Api.imageHeaders }}
            style={styles.image}
            contentFit="cover"
          />
        ) : null}
        <View style={{ flexDirection: 'row', gap: 8 }}>
          <OutlineButton
            title={imageUri ? '📷 Zmień zdjęcie' : '📷 Zdjęcie'}
            onPress={async () => {
              const uri = await pickPhoto();
              if (uri) setPickedUri(uri);
            }}
            style={{ flex: 1 }}
          />
          {imageUri ? (
            <OutlineButton
              title="Usuń zdjęcie"
              onPress={() => {
                setPickedUri(null);
                setImageFileId(null);
              }}
              style={{ flex: 1 }}
            />
          ) : null}
        </View>
        <View style={{ height: 12 }} />
        <PrimaryButton title="Zapisz przepis" onPress={save} disabled={busy} />
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  switchRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 12, paddingHorizontal: 2 },
  image: { height: 180, borderRadius: 12, marginBottom: 10 },
});
