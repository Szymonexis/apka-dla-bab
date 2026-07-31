<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    open,
    onclose,
    sheet = false,
    children,
  }: { open: boolean; onclose: () => void; sheet?: boolean; children: Snippet } = $props();

  function onkeydown(e: KeyboardEvent) {
    if (open && e.key === 'Escape') onclose();
  }
</script>

<svelte:window {onkeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
  <div class="backdrop" class:bottom={sheet} onclick={onclose}>
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
    <div class="panel" class:sheet role="dialog" tabindex="-1" onclick={(e) => e.stopPropagation()}>
      {@render children()}
    </div>
  </div>
{/if}
