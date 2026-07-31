<script lang="ts">
  import { autofocus as focusAction } from '../components/actions';
  import Icon from '../components/Icon.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import { confirmDelete } from '../lib/dialog.svelte';
  import type { Note } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';

  const existing = takeStash<Note>();

  let title = $state(existing?.title ?? '');
  let content = $state(existing?.content ?? '');
  let pinned = $state(existing?.pinned ?? false);

  async function save() {
    if (!title.trim() && !content.trim()) {
      showError('Notatka nie może być pusta');
      return;
    }
    try {
      const body = { title: title.trim(), content, pinned };
      if (existing) {
        await Api.put(`/api/notes/${existing.id}`, body);
      } else {
        await Api.post('/api/notes', body);
      }
      router.back();
    } catch (e) {
      showError(e);
    }
  }

  async function remove() {
    if (!existing) return;
    if (!(await confirmDelete('Notatka zostanie usunięta.'))) return;
    try {
      await Api.del(`/api/notes/${existing.id}`);
      router.back();
    } catch (e) {
      showError(e);
    }
  }
</script>

<div class="screen">
  <TopBar title={existing ? 'Notatka' : 'Nowa notatka'}>
    {#snippet right()}
      <button class="icon-btn" onclick={() => (pinned = !pinned)} aria-label="Przypnij">
        <Icon
          name={pinned ? 'pin' : 'pin-outline'}
          size={22}
          color={pinned ? 'var(--primary)' : 'var(--text)'}
        />
      </button>
      {#if existing}
        <button class="icon-btn" onclick={remove} aria-label="Usuń">
          <Icon name="trash" size={22} />
        </button>
      {/if}
      <button class="icon-btn" onclick={save} aria-label="Zapisz">
        <Icon name="checkmark" size={26} color="var(--primary)" />
      </button>
    {/snippet}
  </TopBar>
  <div class="note-body">
    <input
      class="note-title"
      placeholder="Tytuł"
      bind:value={title}
      use:focusAction={!existing}
    />
    <div class="divider"></div>
    <textarea class="note-content" placeholder="Pisz śmiało..." bind:value={content}></textarea>
  </div>
</div>

<style>
  .note-body {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    padding: 0 16px calc(16px + var(--safe-bottom));
  }

  .note-title {
    font-size: 22px;
    font-weight: 700;
    padding: 10px 0;
    border: none;
    outline: none;
    background: transparent;
  }

  .note-title::placeholder,
  .note-content::placeholder {
    color: var(--muted);
  }

  .divider {
    height: 1px;
    background: var(--outline);
  }

  .note-content {
    flex: 1;
    font-size: 16px;
    padding-top: 10px;
    border: none;
    outline: none;
    background: transparent;
    resize: none;
    line-height: 1.45;
  }
</style>
