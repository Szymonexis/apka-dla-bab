import React, { useState } from 'react';
import { View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Segmented } from '../../components/forms';
import DiaryTab from '../../components/kitchen/DiaryTab';
import MealPlanTab from '../../components/kitchen/MealPlanTab';
import RecipesTab from '../../components/kitchen/RecipesTab';
import { PageHeader } from '../../components/ui';
import { colors } from '../../lib/theme';

export default function KitchenScreen() {
  const [tab, setTab] = useState('recipes');

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: colors.bg }} edges={['top']}>
      <PageHeader title="Kuchnia 🍳" />
      <View style={{ paddingHorizontal: 16 }}>
        <Segmented
          value={tab}
          onChange={setTab}
          options={[
            { value: 'recipes', label: 'Przepisy' },
            { value: 'mealplan', label: 'Jadłospis' },
            { value: 'diary', label: 'Dzienniczek' },
          ]}
        />
      </View>
      {tab === 'recipes' ? <RecipesTab /> : tab === 'mealplan' ? <MealPlanTab /> : <DiaryTab />}
    </SafeAreaView>
  );
}
