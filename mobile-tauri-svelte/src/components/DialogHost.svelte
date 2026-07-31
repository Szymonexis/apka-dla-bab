<script lang="ts">
  import { dialogState, resolveDialog } from '../lib/dialog.svelte';

  const dialog = $derived(dialogState());

  function cancelValue(): string {
    return dialog?.buttons.find((b) => b.style === 'cancel')?.value ?? 'cancel';
  }
</script>

<svelte:window
  onkeydown={(e) => {
    if (dialog && e.key === 'Escape') resolveDialog(cancelValue());
  }}
/>

{#if dialog}
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
  <div class="backdrop" onclick={() => resolveDialog(cancelValue())}>
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div class="panel" role="alertdialog" tabindex="-1" onclick={(e) => e.stopPropagation()}>
      <p class="dialog-title">{dialog.title}</p>
      {#if dialog.message}<p class="message">{dialog.message}</p>{/if}
      <div class="buttons" class:column={dialog.buttons.length > 2}>
        {#each dialog.buttons as b (b.value)}
          <button
            class="dlg-btn"
            class:destructive={b.style === 'destructive'}
            class:cancel={b.style === 'cancel'}
            onclick={() => resolveDialog(b.value)}
          >
            {b.text}
          </button>
        {/each}
      </div>
    </div>
  </div>
{/if}

<style>
  .message {
    color: var(--text);
    white-space: pre-line;
    margin-bottom: 14px;
    line-height: 1.4;
  }

  .buttons {
    display: flex;
    justify-content: flex-end;
    gap: 4px;
  }

  .buttons.column {
    flex-direction: column;
    align-items: stretch;
  }

  .dlg-btn {
    color: var(--primary);
    font-weight: 700;
    padding: 10px 12px;
    border-radius: 8px;
    text-align: center;
  }

  .buttons.column .dlg-btn {
    text-align: right;
  }

  .dlg-btn.cancel {
    color: var(--muted);
  }

  .dlg-btn.destructive {
    color: var(--error);
  }

  .dlg-btn:active {
    background: var(--primary-container);
  }
</style>
