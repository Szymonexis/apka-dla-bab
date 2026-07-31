<script lang="ts">
  import DialogHost from './components/DialogHost.svelte';
  import ToastHost from './components/ToastHost.svelte';
  import { Api } from './lib/api.svelte';
  import { router } from './lib/router.svelte';
  import DiaryEditScreen from './screens/DiaryEditScreen.svelte';
  import EventEditScreen from './screens/EventEditScreen.svelte';
  import LoginScreen from './screens/LoginScreen.svelte';
  import MealEditScreen from './screens/MealEditScreen.svelte';
  import NoteEditScreen from './screens/NoteEditScreen.svelte';
  import PhotoScreen from './screens/PhotoScreen.svelte';
  import RecipeDetailScreen from './screens/RecipeDetailScreen.svelte';
  import RecipeEditScreen from './screens/RecipeEditScreen.svelte';
  import ReminderEditScreen from './screens/ReminderEditScreen.svelte';
  import RemindersScreen from './screens/RemindersScreen.svelte';
  import SettingsScreen from './screens/SettingsScreen.svelte';
  import TabsScreen from './screens/TabsScreen.svelte';
  import TaskEditScreen from './screens/TaskEditScreen.svelte';
  import TasksScreen from './screens/TasksScreen.svelte';
  import TransactionScreen from './screens/TransactionScreen.svelte';

  // Ekrany dostępne bez zalogowania (ustawienia też - żeby dało się wpisać
  // adres serwera przed pierwszym logowaniem).
  const PUBLIC = new Set(['login', 'settings']);

  const screen = $derived(
    !Api.isLoggedIn && !PUBLIC.has(router.route.name) ? 'login' : router.route.name,
  );
</script>

{#key router.epoch}
  {#if screen === 'login'}
    <LoginScreen />
  {:else if screen === 'task-edit'}
    <TaskEditScreen />
  {:else if screen === 'reminder-edit'}
    <ReminderEditScreen />
  {:else if screen === 'event-edit'}
    <EventEditScreen />
  {:else if screen === 'meal-edit'}
    <MealEditScreen />
  {:else if screen === 'diary-edit'}
    <DiaryEditScreen />
  {:else if screen === 'note-edit'}
    <NoteEditScreen />
  {:else if screen === 'recipe'}
    <RecipeDetailScreen />
  {:else if screen === 'recipe-edit'}
    <RecipeEditScreen />
  {:else if screen === 'transaction'}
    <TransactionScreen />
  {:else if screen === 'reminders'}
    <RemindersScreen />
  {:else if screen === 'tasks'}
    <TasksScreen />
  {:else if screen === 'settings'}
    <SettingsScreen />
  {:else if screen === 'photo'}
    <PhotoScreen />
  {:else}
    <TabsScreen />
  {/if}
{/key}

<ToastHost />
<DialogHost />
