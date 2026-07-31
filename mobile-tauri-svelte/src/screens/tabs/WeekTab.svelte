<script module lang="ts">
  // Przesunięcie tygodnia przeżywa wejścia w ekrany edycji.
  let weekOffset = $state(0);
</script>

<script lang="ts">
  import ActionSheet from '../../components/ActionSheet.svelte';
  import Card from '../../components/Card.svelte';
  import Chip from '../../components/Chip.svelte';
  import Icon from '../../components/Icon.svelte';
  import NavRow from '../../components/NavRow.svelte';
  import PageHeader from '../../components/PageHeader.svelte';
  import { Api } from '../../lib/api.svelte';
  import type { EventItem, MealPlanEntry, TaskItem } from '../../lib/models';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError } from '../../lib/toast.svelte';
  import {
    addDays,
    dateStr,
    dayHeader,
    mealOrder,
    mealTypeEmoji,
    mondayOf,
    shortDate,
    timeOf,
    todayStr,
  } from '../../lib/util';

  let events = $state.raw<EventItem[]>([]);
  let tasks = $state.raw<TaskItem[]>([]);
  let meals = $state.raw<MealPlanEntry[]>([]);
  let sheetDate = $state<string | null>(null);

  const monday = $derived(addDays(mondayOf(new Date()), 7 * weekOffset));
  const sunday = $derived(addDays(monday, 6));

  async function load(offset: number) {
    const from = addDays(mondayOf(new Date()), 7 * offset);
    const to = addDays(from, 6);
    const [evs, tsk, mls] = await Promise.all([
      Api.get('/api/events', {
        from: from.toISOString(),
        to: addDays(from, 7).toISOString(),
      }) as Promise<EventItem[]>,
      Api.get('/api/tasks', {
        includeDone: 'true',
        dueFrom: dateStr(from),
        dueTo: dateStr(to),
      }) as Promise<TaskItem[]>,
      Api.get('/api/mealplan', { from: dateStr(from), to: dateStr(to) }) as Promise<
        MealPlanEntry[]
      >,
    ]);
    events = evs;
    tasks = tsk;
    meals = mls;
  }

  $effect(() => {
    load(weekOffset).catch(showError);
  });

  async function toggleTask(t: TaskItem) {
    try {
      await Api.post(`/api/tasks/${t.id}/toggle`);
      await load(weekOffset);
    } catch (e) {
      showError(e);
    }
  }
</script>

<PageHeader title="Plan tygodnia 🗓️">
  {#snippet right()}
    {#if weekOffset !== 0}
      <button class="text-btn" onclick={() => (weekOffset = 0)}>Dziś</button>
    {/if}
  {/snippet}
</PageHeader>
<NavRow
  label={`${shortDate(monday)} – ${shortDate(sunday)}`}
  onprev={() => (weekOffset -= 1)}
  onnext={() => (weekOffset += 1)}
/>

<div class="screen-body">
  {#each Array.from({ length: 7 }, (_, i) => addDays(monday, i)) as day (dateStr(day))}
    {@const ds = dateStr(day)}
    {@const isToday = ds === todayStr()}
    {@const dayEvents = events.filter((e) => dateStr(new Date(e.startsAt)) === ds)}
    {@const dayTasks = tasks.filter((t) => t.dueDate === ds)}
    {@const dayMeals = meals
      .filter((m) => m.date === ds)
      .sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType))}
    <Card highlight={isToday}>
      <div class="day-header">
        <span class="day-title" class:today={isToday}>{dayHeader(day)}</span>
        <button class="icon-btn" onclick={() => (sheetDate = ds)} aria-label="Dodaj">
          <Icon name="add-circle" />
        </button>
      </div>
      {#if dayEvents.length === 0 && dayTasks.length === 0 && dayMeals.length === 0}
        <p class="empty-day">nic nie zaplanowano</p>
      {/if}
      {#if dayMeals.length > 0}
        <div class="chip-row">
          {#each dayMeals as m (m.id)}
            <Chip label={`${mealTypeEmoji[m.mealType]} ${m.recipeTitle ?? m.note}`} />
          {/each}
        </div>
      {/if}
      {#each dayEvents as e (e.id)}
        <div class="line">
          <span class="time">{e.allDay ? '📌' : timeOf(e.startsAt)}</span>
          <span class="line-text">{e.title}</span>
        </div>
      {/each}
      {#each dayTasks as t (t.id)}
        <button class="line" onclick={() => toggleTask(t)}>
          {#if t.done}
            <Icon name="checkmark-circle" size={20} color="var(--primary)" />
          {:else}
            <Icon name="ellipse" size={20} color="var(--muted)" />
          {/if}
          <span class="line-text" class:struck={t.done}>{t.title}</span>
        </button>
      {/each}
    </Card>
  {/each}
</div>

<ActionSheet
  open={sheetDate != null}
  onclose={() => (sheetDate = null)}
  actions={[
    {
      icon: 'checkbox',
      label: 'Obowiązek',
      onPress: () => {
        setStash(undefined);
        router.push('task-edit', { initialDue: sheetDate! });
      },
    },
    {
      icon: 'calendar',
      label: 'Wydarzenie',
      onPress: () => {
        setStash(undefined);
        router.push('event-edit', { initialDate: sheetDate! });
      },
    },
    {
      icon: 'restaurant',
      label: 'Posiłek',
      onPress: () => {
        setStash(undefined);
        router.push('meal-edit', { date: sheetDate! });
      },
    },
  ]}
/>

<style>
  .day-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .day-title {
    font-weight: 800;
    font-size: 15px;
  }

  .day-title.today {
    color: var(--primary);
  }

  .empty-day {
    color: var(--muted);
    font-size: 13px;
    padding-bottom: 6px;
  }

  .line {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 3px 0;
    width: 100%;
    text-align: left;
  }

  .line-text {
    flex: 1;
    min-width: 0;
  }

  .time {
    font-weight: 700;
    font-size: 13px;
    min-width: 42px;
  }
</style>
