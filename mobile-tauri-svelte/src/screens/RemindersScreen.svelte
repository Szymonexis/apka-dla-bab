<script lang="ts">
  import Card from '../components/Card.svelte';
  import CheckCircle from '../components/CheckCircle.svelte';
  import EmptyState from '../components/EmptyState.svelte';
  import Fab from '../components/Fab.svelte';
  import Icon from '../components/Icon.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { Reminder } from '../lib/models';
  import { syncReminderNotifications } from '../lib/notifications';
  import { router } from '../lib/router.svelte';
  import { setStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { prettyDateTime } from '../lib/util';

  let reminders = $state.raw<Reminder[]>([]);
  let showDone = $state(false);

  async function load() {
    const res = (await Api.get('/api/reminders', { includeDone: 'true' })) as Reminder[];
    syncReminderNotifications(res);
    reminders = res;
  }

  $effect(() => {
    load().catch(showError);
  });

  async function toggle(r: Reminder) {
    try {
      await Api.post(`/api/reminders/${r.id}/toggle`);
      await load();
    } catch (e) {
      showError(e);
    }
  }

  async function remove(r: Reminder) {
    try {
      await Api.del(`/api/reminders/${r.id}`);
      await load();
    } catch (e) {
      showError(e);
    }
  }

  const active = $derived(reminders.filter((r) => !r.done));
  const done = $derived(reminders.filter((r) => r.done));
</script>

{#snippet item(r: Reminder)}
  {@const overdue = !r.done && new Date(r.remindAt) < new Date()}
  <button
    class="full-width"
    onclick={() => {
      setStash(r);
      router.push('reminder-edit');
    }}
  >
    <Card>
      <div class="item-row">
        <CheckCircle checked={r.done} onclick={() => toggle(r)} />
        <span class="row-main">
          <span class="row-title" class:struck={r.done}>{r.title}</span>
          <span class="row-sub" class:overdue>{prettyDateTime(r.remindAt)}</span>
        </span>
        <span
          class="del"
          role="button"
          tabindex="0"
          aria-label="Usuń"
          onclick={(e) => {
            e.stopPropagation();
            remove(r);
          }}
          onkeydown={(e) => {
            if (e.key === 'Enter') {
              e.stopPropagation();
              remove(r);
            }
          }}
        >
          <Icon name="trash" size={19} color="var(--muted)" />
        </span>
      </div>
    </Card>
  </button>
{/snippet}

<div class="screen">
  <TopBar title="Przypomnienia 🔔" />
  <div class="screen-body with-fab">
    {#if active.length === 0}
      <EmptyState emoji="🔕" text={'Żadnych przypomnień.\nGłowa wolna!'} />
    {/if}
    {#each active as r (r.id)}
      {@render item(r)}
    {/each}
    {#if done.length > 0}
      <button class="done-header" onclick={() => (showDone = !showDone)}>
        <span>Zrobione ({done.length})</span>
        <Icon name={showDone ? 'chevron-up' : 'chevron-down'} size={18} color="var(--muted)" />
      </button>
      {#if showDone}
        {#each done as r (r.id)}
          {@render item(r)}
        {/each}
      {/if}
    {/if}
  </div>
  <Fab
    onclick={() => {
      setStash(undefined);
      router.push('reminder-edit');
    }}
  />
</div>

<style>
  .full-width {
    display: block;
    width: 100%;
    text-align: left;
  }

  .item-row {
    display: flex;
    align-items: center;
  }

  .row-main {
    display: flex;
    flex-direction: column;
  }

  .del {
    display: inline-flex;
    padding: 4px;
  }

  .done-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 12px 4px;
    color: var(--muted);
    font-weight: 600;
  }
</style>
