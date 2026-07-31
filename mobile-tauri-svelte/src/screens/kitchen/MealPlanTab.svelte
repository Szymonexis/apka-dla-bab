<script module lang="ts">
  let weekOffset = $state(0);
</script>

<script lang="ts">
  import Card from '../../components/Card.svelte';
  import Icon from '../../components/Icon.svelte';
  import NavRow from '../../components/NavRow.svelte';
  import { Api } from '../../lib/api.svelte';
  import type { MealPlanEntry } from '../../lib/models';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError } from '../../lib/toast.svelte';
  import {
    addDays,
    dateStr,
    dayHeader,
    mealOrder,
    mealTypeEmoji,
    mealTypeLabels,
    mondayOf,
    shortDate,
    todayStr,
  } from '../../lib/util';

  let meals = $state.raw<MealPlanEntry[]>([]);

  const monday = $derived(addDays(mondayOf(new Date()), 7 * weekOffset));
  const sunday = $derived(addDays(monday, 6));

  async function load(offset: number) {
    const from = addDays(mondayOf(new Date()), 7 * offset);
    const to = addDays(from, 6);
    meals = (await Api.get('/api/mealplan', {
      from: dateStr(from),
      to: dateStr(to),
    })) as MealPlanEntry[];
  }

  $effect(() => {
    load(weekOffset).catch(showError);
  });

  async function remove(m: MealPlanEntry) {
    try {
      await Api.del(`/api/mealplan/${m.id}`);
      await load(weekOffset);
    } catch (e) {
      showError(e);
    }
  }
</script>

<NavRow
  label={`${shortDate(monday)} – ${shortDate(sunday)}`}
  onprev={() => (weekOffset -= 1)}
  onnext={() => (weekOffset += 1)}
/>
<div class="screen-body">
  {#each Array.from({ length: 7 }, (_, i) => addDays(monday, i)) as day (dateStr(day))}
    {@const ds = dateStr(day)}
    {@const dayMeals = meals
      .filter((m) => m.date === ds)
      .sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType))}
    <Card highlight={ds === todayStr()}>
      <div class="day-header">
        <span class="day-title">{dayHeader(day)}</span>
        <button
          class="icon-btn"
          aria-label="Dodaj posiłek"
          onclick={() => {
            setStash(undefined);
            router.push('meal-edit', { date: ds });
          }}
        >
          <Icon name="add-circle" />
        </button>
      </div>
      {#each dayMeals as m (m.id)}
        <button
          class="meal-row"
          onclick={() => {
            setStash(m);
            router.push('meal-edit', { date: ds });
          }}
        >
          <span class="meal-emoji">{mealTypeEmoji[m.mealType] ?? '🍽️'}</span>
          <span class="meal-main">
            <span>{m.recipeTitle ?? m.note}</span>
            <span class="row-sub">{mealTypeLabels[m.mealType] ?? m.mealType}</span>
          </span>
          <span
            class="del"
            role="button"
            tabindex="0"
            aria-label="Usuń"
            onclick={(e) => {
              e.stopPropagation();
              remove(m);
            }}
            onkeydown={(e) => {
              if (e.key === 'Enter') {
                e.stopPropagation();
                remove(m);
              }
            }}
          >
            <Icon name="trash" size={19} color="var(--muted)" />
          </span>
        </button>
      {/each}
    </Card>
  {/each}
</div>

<style>
  .day-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .day-title {
    font-weight: 800;
  }

  .meal-row {
    display: flex;
    align-items: center;
    padding: 6px 0;
    width: 100%;
    text-align: left;
  }

  .meal-emoji {
    font-size: 20px;
    margin-right: 10px;
  }

  .meal-main {
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
