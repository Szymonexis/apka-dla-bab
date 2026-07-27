import { Image } from 'expo-image';
import { Stack, useLocalSearchParams } from 'expo-router';
import React from 'react';
import { View } from 'react-native';

import { Api } from '../lib/api';

/** Pełnoekranowy podgląd zdjęcia (np. paragonu). */
export default function PhotoScreen() {
  const { fileId } = useLocalSearchParams<{ fileId: string }>();
  return (
    <>
      <Stack.Screen
        options={{
          title: '',
          headerStyle: { backgroundColor: '#000' },
          headerTintColor: '#fff',
          contentStyle: { backgroundColor: '#000' },
        }}
      />
      <View style={{ flex: 1, backgroundColor: '#000' }}>
        <Image
          source={{ uri: Api.fileUrl(fileId), headers: Api.imageHeaders }}
          style={{ flex: 1 }}
          contentFit="contain"
        />
      </View>
    </>
  );
}
