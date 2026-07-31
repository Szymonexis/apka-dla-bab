<script lang="ts">
  import Card from '../components/Card.svelte';
  import CheckCircle from '../components/CheckCircle.svelte';
  import EmptyState from '../components/EmptyState.svelte';
  import Fab from '../components/Fab.svelte';
  import Icon from '../components/Icon.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { TaskItem } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { setStash } from '../lib/stash';
  import { showError, toast } from '../lib/toast.svelte';
  import { prettyDate, repeatLabels } from '../lib/util';

  let tasks = $state.raw<TaskItem[]>([]);
  let showDone = $state(false);

  async function load() {
    tasks = (await Api.get('/api/tasks', { includeDone: 'true' })) as TaskItem[];
  }

  $effect(() => {
    load().catch(showError);
  });

  async function toggle(t: TaskItem) {
    try {
      await Api.post(`/api/tasks/${t.id}/toggle`);
      if (!t.done && t.repeat !== 'none') toast('Odhaczone! Zaplanowałam kolejny termin 📅');
      await load();
    } catch (e) {
      showError(e);
    }
  }

  async function remove(t: TaskItem) {
    try {
      await Api.del(`/api/tasks/${t.id}`);
      await load();
    } catch (e) {
      showError(e);
    }
  }

  function subOf(t: TaskItem): string {
    return [
      t.dueDate ? prettyDate(t.dueDate) : null,
      t.repeat !== 'none' ? `🔁 ${repeatLabels[t.repeat]?.toLowerCase()}` : null,
    ]
      .filter(Boolean)
      .join(' · ');
  }

  const active = $derived(tasks.filter((t) => !t.done));
  const done = $derived(tasks.filter((t) => t.done));
</script>

{#snippet item(t: TaskItem)}
  <button
    class="full-width"
    onclick={() => {
      setStash(t);
      router.push('task-edit');
    }}
  >
    <Card>
      <div class="item-row">
        <CheckCircle checked={t.done} onclick={() => toggle(t)} />
        <span class="row-main">
          <span class="row-title" class:struck={t.done}>{t.title}</span>
          {#if subOf(t)}<span class="row-sub">{subOf(t)}</span>{/if}
        </span>
        <span
          class="del"
          role="button"
          tabindex="0"
          aria-label="Usuń"
          onclick={(e) => {
            e.stopPropagation();
            remove(t);
          }}
          onkeydown={(e) => {
            if (e.key === 'Enter') {
              e.stopPropagation();
              remove(t);
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
  <TopBar title="Obowiązki ✅" />
  <div class="screen-body with-fab">
    {#if active.length === 0}
      <EmptyState emoji="🏖️" text={'Wszystko zrobione.\nCzas na kawę!'} />
    {/if}
    {#each active as t (t.id)}
      {@render item(t)}
    {/each}
    {#if done.length > 0}
      <button class="done-header" onclick={() => (showDone = !showDone)}>
        <span>Zrobione ({done.length})</span>
        <Icon name={showDone ? 'chevron-up' : 'chevron-down'} size={18} color="var(--muted)" />
      </button>
      {#if showDone}
        {#each done as t (t.id)}
          {@render item(t)}
        {/each}
      {/if}
    {/if}
  </div>
  <Fab
    onclick={() => {
      setStash(undefined);
      router.push('task-edit');
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
