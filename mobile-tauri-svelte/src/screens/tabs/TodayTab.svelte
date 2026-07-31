<script lang="ts">
  import ActionSheet from '../../components/ActionSheet.svelte';
  import Card from '../../components/Card.svelte';
  import CheckCircle from '../../components/CheckCircle.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import Fab from '../../components/Fab.svelte';
  import Icon from '../../components/Icon.svelte';
  import PageHeader from '../../components/PageHeader.svelte';
  import SectionHeader from '../../components/SectionHeader.svelte';
  import { Api } from '../../lib/api.svelte';
  import type { EventItem, MealPlanEntry, Reminder, TaskItem } from '../../lib/models';
  import { syncReminderNotifications } from '../../lib/notifications';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError, toast } from '../../lib/toast.svelte';
  import {
    addDays,
    dayOnly,
    longDate,
    mealOrder,
    mealTypeEmoji,
    mealTypeLabels,
    prettyDate,
    prettyDateTime,
    timeOf,
    todayStr,
  } from '../../lib/util';

  const now = new Date();
  const today = todayStr();

  let reminders = $state.raw<Reminder[]>([]);
  let tasks = $state.raw<TaskItem[]>([]);
  let events = $state.raw<EventItem[]>([]);
  let meals = $state.raw<MealPlanEntry[]>([]);
  let sheetOpen = $state(false);

  function greeting(): string {
    const hour = new Date().getHours();
    const name = Api.displayName ? `, ${Api.displayName}` : '';
    if (hour < 5) return `Dobranoc${name} 🌙`;
    if (hour < 12) return `Dzień dobry${name} ☀️`;
    if (hour < 18) return `Cześć${name} 💗`;
    return `Dobry wieczór${name} 🌆`;
  }

  async function load() {
    const start = dayOnly(new Date());
    const end = addDays(start, 1);
    const [rem, tsk, evs, mls] = await Promise.all([
      Api.get('/api/reminders') as Promise<Reminder[]>,
      Api.get('/api/tasks', { includeDone: 'true' }) as Promise<TaskItem[]>,
      Api.get('/api/events', {
        from: start.toISOString(),
        to: end.toISOString(),
      }) as Promise<EventItem[]>,
      Api.get('/api/mealplan', { from: today, to: today }) as Promise<MealPlanEntry[]>,
    ]);
    syncReminderNotifications(rem);
    const soon = addDays(end, 2).getTime();
    reminders = rem.filter((r) => new Date(r.remindAt).getTime() < soon);
    tasks = tsk.filter(
      (t) =>
        (!t.done && (t.dueDate == null || t.dueDate <= today)) || (t.done && t.dueDate === today),
    );
    events = evs;
    meals = [...mls].sort((a, b) => mealOrder(a.mealType) - mealOrder(b.mealType));
  }

  $effect(() => {
    load().catch(showError);
  });

  async function toggleTask(t: TaskItem) {
    try {
      await Api.post(`/api/tasks/${t.id}/toggle`);
      if (!t.done && t.repeat !== 'none') toast('Odhaczone! Zaplanowałam kolejny termin 📅');
      await load();
    } catch (e) {
      showError(e);
    }
  }

  async function toggleReminder(r: Reminder) {
    try {
      await Api.post(`/api/reminders/${r.id}/toggle`);
      await load();
    } catch (e) {
      showError(e);
    }
  }
</script>

<PageHeader title={greeting()} subtitle={longDate(now)}>
  {#snippet right()}
    <div class="header-actions">
      <button class="icon-btn" onclick={() => router.push('tasks')} aria-label="Obowiązki">
        <Icon name="checkbox" />
      </button>
      <button class="icon-btn" onclick={() => router.push('reminders')} aria-label="Przypomnienia">
        <Icon name="notifications" />
      </button>
      <button class="icon-btn" onclick={() => router.push('settings')} aria-label="Ustawienia">
        <Icon name="settings" />
      </button>
    </div>
  {/snippet}
</PageHeader>

<div class="screen-body with-fab">
  {#if reminders.length > 0}
    <SectionHeader title="🔔 Przypomnienia" />
    <Card>
      {#each reminders as r (r.id)}
        <div class="row">
          <CheckCircle checked={r.done} onclick={() => toggleReminder(r)} />
          <div class="row-main">
            <div class="row-title">{r.title}</div>
            <div class="row-sub" class:overdue={!r.done && new Date(r.remindAt) < now}>
              {prettyDateTime(r.remindAt)}
            </div>
          </div>
        </div>
      {/each}
    </Card>
  {/if}

  <SectionHeader title="✅ Obowiązki na dziś" />
  <Card>
    {#if tasks.length === 0}
      <EmptyState emoji="🎉" text="Nic do zrobienia - możesz odpocząć!" />
    {:else}
      {#each tasks as t (t.id)}
        <div class="row">
          <CheckCircle checked={t.done} onclick={() => toggleTask(t)} />
          <div class="row-main">
            <div class="row-title" class:struck={t.done}>{t.title}</div>
            {#if t.dueDate && t.dueDate < today}
              <div class="row-sub overdue">zaległe od {prettyDate(t.dueDate)}</div>
            {/if}
          </div>
        </div>
      {/each}
    {/if}
  </Card>

  <SectionHeader title="📅 Dzisiejsze wydarzenia" />
  <Card>
    {#if events.length === 0}
      <EmptyState emoji="🛋️" text="Kalendarz na dziś jest pusty" />
    {:else}
      {#each events as e (e.id)}
        <div class="row">
          <span class="time">{e.allDay ? '📌' : timeOf(e.startsAt)}</span>
          <div class="row-main">
            <div class="row-title">{e.title}</div>
            {#if e.description}<div class="row-sub">{e.description}</div>{/if}
          </div>
        </div>
      {/each}
    {/if}
  </Card>

  <SectionHeader title="🍽️ Dziś jemy" />
  <Card>
    {#if meals.length === 0}
      <EmptyState emoji="🤔" text={'Nie zaplanowano posiłków.\nZajrzyj do Kuchni!'} />
    {:else}
      {#each meals as m (m.id)}
        <div class="row">
          <span class="meal-emoji">{mealTypeEmoji[m.mealType] ?? '🍽️'}</span>
          <div class="row-main">
            <div class="row-title">{m.recipeTitle ?? m.note}</div>
            <div class="row-sub">{mealTypeLabels[m.mealType] ?? m.mealType}</div>
          </div>
        </div>
      {/each}
    {/if}
  </Card>
</div>

<Fab onclick={() => (sheetOpen = true)} />
<ActionSheet
  open={sheetOpen}
  onclose={() => (sheetOpen = false)}
  actions={[
    {
      icon: 'checkbox',
      label: 'Obowiązek',
      onPress: () => {
        setStash(undefined);
        router.push('task-edit', { initialDue: today });
      },
    },
    {
      icon: 'notifications',
      label: 'Przypomnienie',
      onPress: () => {
        setStash(undefined);
        router.push('reminder-edit');
      },
    },
    {
      icon: 'calendar',
      label: 'Wydarzenie',
      onPress: () => {
        setStash(undefined);
        router.push('event-edit');
      },
    },
    {
      icon: 'restaurant',
      label: 'Posiłek na dziś',
      onPress: () => {
        setStash(undefined);
        router.push('meal-edit', { date: today });
      },
    },
  ]}
/>

<style>
  .header-actions {
    display: flex;
  }

  .time {
    font-weight: 700;
    margin-right: 10px;
    min-width: 44px;
  }

  .meal-emoji {
    font-size: 22px;
    margin-right: 10px;
  }
</style>
