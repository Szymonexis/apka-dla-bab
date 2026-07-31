<script module lang="ts">
  let tab = $state('recipes');
</script>

<script lang="ts">
  import PageHeader from '../../components/PageHeader.svelte';
  import Segmented from '../../components/Segmented.svelte';
  import DiaryTab from '../kitchen/DiaryTab.svelte';
  import MealPlanTab from '../kitchen/MealPlanTab.svelte';
  import RecipesTab from '../kitchen/RecipesTab.svelte';
</script>

<PageHeader title="Kuchnia 🍳" />
<div class="segmented-wrap">
  <Segmented
    value={tab}
    onchange={(v) => (tab = v)}
    options={[
      { value: 'recipes', label: 'Przepisy' },
      { value: 'mealplan', label: 'Jadłospis' },
      { value: 'diary', label: 'Dzienniczek' },
    ]}
  />
</div>
{#if tab === 'recipes'}
  <RecipesTab />
{:else if tab === 'mealplan'}
  <MealPlanTab />
{:else}
  <DiaryTab />
{/if}

<style>
  .segmented-wrap {
    padding: 0 16px;
  }
</style>
