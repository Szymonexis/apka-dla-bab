<script lang="ts">
  import EmptyState from '../../components/EmptyState.svelte';
  import Fab from '../../components/Fab.svelte';
  import Icon from '../../components/Icon.svelte';
  import PageHeader from '../../components/PageHeader.svelte';
  import { Api } from '../../lib/api.svelte';
  import type { Note } from '../../lib/models';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError } from '../../lib/toast.svelte';

  let notes = $state.raw<Note[]>([]);

  $effect(() => {
    (Api.get('/api/notes') as Promise<Note[]>).then((res) => (notes = res)).catch(showError);
  });
</script>

<PageHeader title="Notatki 📝" />
<div class="screen-body with-fab">
  {#if notes.length === 0}
    <EmptyState emoji="📝" text={'Brak notatek.\nZapisz coś, zanim wyleci z głowy!'} />
  {:else}
    <div class="grid">
      {#each notes as n (n.id)}
        <button
          class="note"
          onclick={() => {
            setStash(n);
            router.push('note-edit');
          }}
        >
          <div class="note-head">
            <span class="note-title">{n.title || '(bez tytułu)'}</span>
            {#if n.pinned}
              <Icon name="pin" size={14} color="var(--primary)" />
            {/if}
          </div>
          <span class="note-content">{n.content}</span>
        </button>
      {/each}
    </div>
  {/if}
</div>
<Fab
  onclick={() => {
    setStash(undefined);
    router.push('note-edit');
  }}
/>

<style>
  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .note {
    background: var(--surface);
    border-radius: var(--radius-card);
    padding: 12px;
    min-height: 120px;
    text-align: left;
    display: flex;
    flex-direction: column;
    align-items: stretch;
    overflow: hidden;
  }

  .note-head {
    display: flex;
    align-items: flex-start;
    gap: 4px;
  }

  .note-title {
    flex: 1;
    font-weight: 700;
    margin-bottom: 4px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .note-content {
    color: var(--muted);
    font-size: 13px;
    white-space: pre-line;
    display: -webkit-box;
    -webkit-line-clamp: 6;
    line-clamp: 6;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
</style>
