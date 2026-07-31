<script lang="ts">
  import Input from '../components/Input.svelte';
  import PickerField from '../components/PickerField.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { DiaryEntry } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { mealTypeEmoji, mealTypeLabels, mealTypes, prettyDate, todayStr } from '../lib/util';

  const existing = takeStash<DiaryEntry>();
  const date = existing?.date ?? router.route.params.date ?? todayStr();

  let mealType = $state(existing?.mealType ?? 'sniadanie');
  let description = $state(existing?.description ?? '');
  let calories = $state(existing?.calories?.toString() ?? '');
  let busy = $state(false);

  async function save() {
    if (!description.trim()) {
      showError('Napisz, co zjadłaś');
      return;
    }
    busy = true;
    try {
      const kcal = parseInt(calories.trim(), 10);
      const body = {
        date,
        mealType,
        description: description.trim(),
        calories: Number.isFinite(kcal) ? kcal : null,
      };
      if (existing) {
        await Api.put(`/api/diary/${existing.id}`, body);
      } else {
        await Api.post('/api/diary', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }
</script>

<div class="screen">
  <TopBar title={`Co zjadłaś? - ${prettyDate(date)}`} />
  <div class="screen-body">
    <PickerField
      label="Posiłek"
      value={mealType}
      onchange={(v) => (mealType = v)}
      options={mealTypes.map((t) => ({
        value: t,
        label: `${mealTypeEmoji[t]} ${mealTypeLabels[t]}`,
      }))}
    />
    <Input label="Opis" bind:value={description} autofocus={!existing} />
    <Input label="Kalorie (opcjonalnie)" bind:value={calories} inputmode="numeric" />
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz</button>
  </div>
</div>
