<script lang="ts">
  import AuthImage from '../components/AuthImage.svelte';
  import Card from '../components/Card.svelte';
  import Chip from '../components/Chip.svelte';
  import DateField from '../components/DateField.svelte';
  import Icon from '../components/Icon.svelte';
  import PickerField from '../components/PickerField.svelte';
  import SectionHeader from '../components/SectionHeader.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import { confirmDelete } from '../lib/dialog.svelte';
  import type { Recipe } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { setStash } from '../lib/stash';
  import { showError, toast } from '../lib/toast.svelte';
  import { mealTypeEmoji, mealTypeLabels, mealTypes, todayStr } from '../lib/util';

  const id = router.route.params.id;

  let recipe = $state.raw<Recipe | null>(null);
  let planOpen = $state(false);
  let planDate = $state<string | null>(todayStr());
  let planMeal = $state('obiad');

  $effect(() => {
    (Api.get(`/api/recipes/${id}`) as Promise<Recipe>)
      .then((r) => (recipe = r))
      .catch((e) => {
        showError(e);
        router.back();
      });
  });

  async function remove() {
    if (!recipe) return;
    if (!(await confirmDelete(`Przepis "${recipe.title}" zniknie na zawsze.`))) return;
    try {
      await Api.del(`/api/recipes/${recipe.id}`);
      router.back();
    } catch (e) {
      showError(e);
    }
  }

  async function plan() {
    if (!recipe || !planDate) return;
    try {
      await Api.put('/api/mealplan', {
        date: planDate,
        mealType: planMeal,
        recipeId: recipe.id,
        note: '',
      });
      planOpen = false;
      toast('Zaplanowane! 🍽️');
    } catch (e) {
      showError(e);
    }
  }
</script>

<div class="screen">
  <TopBar title={recipe?.title ?? '...'}>
    {#snippet right()}
      {#if recipe}
        <button
          class="icon-btn"
          aria-label="Edytuj"
          onclick={() => {
            setStash(recipe);
            router.push('recipe-edit');
          }}
        >
          <Icon name="create" size={22} />
        </button>
        <button class="icon-btn" onclick={remove} aria-label="Usuń">
          <Icon name="trash" size={22} />
        </button>
      {/if}
    {/snippet}
  </TopBar>
  {#if recipe}
    <div class="screen-body">
      {#if recipe.imageFileId}
        <div class="image"><AuthImage fileId={recipe.imageFileId} alt={recipe.title} /></div>
      {/if}
      <div class="chip-row">
        {#if recipe.timeMinutes}<Chip label={`⏱️ ${recipe.timeMinutes} min`} />{/if}
        {#if recipe.servings}<Chip label={`👥 ${recipe.servings} porcje`} />{/if}
        {#each recipe.tags as t (t)}
          <Chip label={`#${t}`} />
        {/each}
      </div>
      {#if recipe.description}
        <SectionHeader title="Opis" />
        <p class="text">{recipe.description}</p>
      {/if}
      {#if recipe.ingredients}
        <SectionHeader title="🛒 Składniki" />
        <Card><p class="text">{recipe.ingredients}</p></Card>
      {/if}
      {#if recipe.steps}
        <SectionHeader title="👩‍🍳 Przygotowanie" />
        <Card><p class="text">{recipe.steps}</p></Card>
      {/if}
      <div class="spacer"></div>
      {#if planOpen}
        <Card>
          <DateField label="Data" value={planDate} onchange={(v) => (planDate = v)} />
          <PickerField
            label="Posiłek"
            value={planMeal}
            onchange={(v) => (planMeal = v)}
            options={mealTypes.map((t) => ({
              value: t,
              label: `${mealTypeEmoji[t]} ${mealTypeLabels[t]}`,
            }))}
          />
          <button class="btn-primary" onclick={plan}>Zaplanuj</button>
        </Card>
      {:else}
        <button class="btn-primary" onclick={() => (planOpen = true)}>
          🗓️ Dodaj do jadłospisu
        </button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .image {
    height: 220px;
    border-radius: 16px;
    margin-bottom: 12px;
    overflow: hidden;
  }

  .text {
    line-height: 1.4;
    white-space: pre-line;
  }

  .spacer {
    height: 12px;
  }
</style>
