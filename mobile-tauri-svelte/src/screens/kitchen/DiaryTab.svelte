<script module lang="ts">
  import { dayOnly as dayOnlyFn } from '../../lib/util';

  let date = $state.raw(dayOnlyFn(new Date()));
</script>

<script lang="ts">
  import Card from '../../components/Card.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import Fab from '../../components/Fab.svelte';
  import Icon from '../../components/Icon.svelte';
  import NavRow from '../../components/NavRow.svelte';
  import { Api } from '../../lib/api.svelte';
  import type { DiaryEntry } from '../../lib/models';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError } from '../../lib/toast.svelte';
  import {
    addDays,
    dateStr,
    dayOnly,
    longDate,
    mealOrder,
    mealTypeEmoji,
    mealTypeLabels,
    todayStr,
  } from '../../lib/util';

  let entries = $state.raw<DiaryEntry[]>([]);

  async function load(d: Date) {
    const ds = dateStr(d);
    const res = (await Api.get('/api/diary', { from: ds, to: ds })) as DiaryEntry[];
    entries = [...res].sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType));
  }

  $effect(() => {
    load(date).catch(showError);
  });

  async function remove(e: DiaryEntry) {
    try {
      await Api.del(`/api/diary/${e.id}`);
      await load(date);
    } catch (err) {
      showError(err);
    }
  }

  const totalKcal = $derived(entries.reduce((sum, e) => sum + (e.calories ?? 0), 0));
  const isToday = $derived(dateStr(date) === todayStr());
</script>

<NavRow
  label={longDate(date)}
  onprev={() => (date = addDays(date, -1))}
  onnext={() => (date = addDays(date, 1))}
>
  {#snippet right()}
    {#if !isToday}
      <button class="text-btn" onclick={() => (date = dayOnly(new Date()))}>Dziś</button>
    {/if}
  {/snippet}
</NavRow>
<div class="screen-body with-fab">
  <Card>
    <div class="kcal-row">
      <span class="fire">🔥</span>
      <div>
        <p class="kcal">{totalKcal} kcal</p>
        <p class="row-sub">suma z wpisów tego dnia</p>
      </div>
    </div>
  </Card>

  {#if entries.length === 0}
    <EmptyState emoji="🥣" text={'Brak wpisów.\nDodaj plusem, co zjadłaś!'} />
  {/if}

  {#each entries as e (e.id)}
    <button
      class="full-width"
      onclick={() => {
        setStash(e);
        router.push('diary-edit', { date: e.date });
      }}
    >
      <Card>
        <div class="entry-row">
          <span class="meal-emoji">{mealTypeEmoji[e.mealType] ?? '🍽️'}</span>
          <span class="entry-main">
            <span>{e.description}</span>
            <span class="row-sub">
              {[mealTypeLabels[e.mealType] ?? e.mealType, e.calories ? `${e.calories} kcal` : null]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </span>
          <span
            class="del"
            role="button"
            tabindex="0"
            aria-label="Usuń"
            onclick={(ev) => {
              ev.stopPropagation();
              remove(e);
            }}
            onkeydown={(ev) => {
              if (ev.key === 'Enter') {
                ev.stopPropagation();
                remove(e);
              }
            }}
          >
            <Icon name="trash" size={19} color="var(--muted)" />
          </span>
        </div>
      </Card>
    </button>
  {/each}
</div>
<Fab
  onclick={() => {
    setStash(undefined);
    router.push('diary-edit', { date: dateStr(date) });
  }}
/>

<style>
  .kcal-row {
    display: flex;
    align-items: center;
  }

  .fire {
    font-size: 24px;
    margin-right: 10px;
  }

  .kcal {
    font-weight: 800;
    font-size: 17px;
  }

  .full-width {
    display: block;
    width: 100%;
    text-align: left;
  }

  .entry-row {
    display: flex;
    align-items: center;
  }

  .meal-emoji {
    font-size: 22px;
    margin-right: 10px;
  }

  .entry-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .del {
    display: inline-flex;
    padding: 4px;
  }
</style>
