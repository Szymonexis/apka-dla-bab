<script lang="ts">
  import Input from '../components/Input.svelte';
  import PickerField from '../components/PickerField.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { MealPlanEntry, Recipe } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { mealTypeEmoji, mealTypeLabels, mealTypes, prettyDate, todayStr } from '../lib/util';

  const existing = takeStash<MealPlanEntry>();
  const date = existing?.date ?? router.route.params.date ?? todayStr();

  let mealType = $state(existing?.mealType ?? 'obiad');
  // '' oznacza "bez przepisu"
  let recipeChoice = $state(existing?.recipeId ?? '');
  let note = $state(existing?.note ?? '');
  let recipes = $state.raw<Recipe[]>([]);
  let busy = $state(false);

  $effect(() => {
    (Api.get('/api/recipes') as Promise<Recipe[]>)
      .then((res) => (recipes = res))
      .catch(() => (recipes = []));
  });

  async function save() {
    busy = true;
    try {
      await Api.put('/api/mealplan', {
        date,
        mealType,
        recipeId: recipeChoice || null,
        note: note.trim(),
      });
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }
</script>

<div class="screen">
  <TopBar title={`Posiłek - ${prettyDate(date)}`} />
  <div class="screen-body">
    <PickerField
      label="Posiłek"
      value={mealType}
      onchange={(v) => (mealType = v)}
      disabled={existing != null}
      options={mealTypes.map((t) => ({
        value: t,
        label: `${mealTypeEmoji[t]} ${mealTypeLabels[t]}`,
      }))}
    />
    <PickerField
      label="Przepis z Twojej bazy"
      value={recipeChoice}
      onchange={(v) => (recipeChoice = v)}
      options={[
        { value: '', label: '— bez przepisu —' },
        ...recipes.map((r) => ({ value: r.id, label: r.title })),
      ]}
    />
    <Input label="Albo wpisz, co jecie" placeholder="np. pierogi od mamy" bind:value={note} />
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz</button>
  </div>
</div>
