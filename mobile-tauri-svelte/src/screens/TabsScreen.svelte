<script module lang="ts">
  // Aktywna zakładka przeżywa wejścia w ekrany edycji (stan modułu).
  let activeTab = $state('today');
</script>

<script lang="ts">
  import Icon from '../components/Icon.svelte';
  import type { IconName } from '../components/Icon.svelte';
  import BudgetTab from './tabs/BudgetTab.svelte';
  import KitchenTab from './tabs/KitchenTab.svelte';
  import NotesTab from './tabs/NotesTab.svelte';
  import TodayTab from './tabs/TodayTab.svelte';
  import WeekTab from './tabs/WeekTab.svelte';

  const tabs: { id: string; label: string; icon: IconName }[] = [
    { id: 'today', label: 'Dziś', icon: 'sunny' },
    { id: 'week', label: 'Tydzień', icon: 'calendar' },
    { id: 'kitchen', label: 'Kuchnia', icon: 'restaurant' },
    { id: 'budget', label: 'Budżet', icon: 'wallet' },
    { id: 'notes', label: 'Notatki', icon: 'document-text' },
  ];
</script>

<div class="tabs-screen">
  <div class="tab-content">
    {#if activeTab === 'today'}
      <TodayTab />
    {:else if activeTab === 'week'}
      <WeekTab />
    {:else if activeTab === 'kitchen'}
      <KitchenTab />
    {:else if activeTab === 'budget'}
      <BudgetTab />
    {:else}
      <NotesTab />
    {/if}
  </div>
  <nav class="tabbar">
    {#each tabs as t (t.id)}
      <button
        class="tab"
        class:active={activeTab === t.id}
        onclick={() => (activeTab = t.id)}
        aria-label={t.label}
      >
        <Icon name={t.icon} size={22} />
        <span>{t.label}</span>
      </button>
    {/each}
  </nav>
</div>

<style>
  .tabs-screen {
    display: flex;
    flex-direction: column;
    height: 100dvh;
    padding-top: var(--safe-top);
  }

  .tab-content {
    flex: 1;
    min-height: 0;
    position: relative;
    display: flex;
    flex-direction: column;
  }

  .tabbar {
    display: flex;
    background: var(--surface);
    border-top: 1px solid rgba(0, 0, 0, 0.05);
    padding-bottom: var(--safe-bottom);
  }

  .tab {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    padding: 8px 0 6px;
    color: var(--muted);
    font-size: 11px;
  }

  .tab.active {
    color: var(--primary);
    font-weight: 600;
  }
</style>
