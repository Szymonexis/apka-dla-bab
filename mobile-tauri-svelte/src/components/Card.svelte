<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    highlight = false,
    children,
  }: { highlight?: boolean; children: Snippet } = $props();
</script>

<div class="card" class:highlight>
  {@render children()}
</div>

<style>
  .highlight {
    background: var(--primary-container);
  }
</style>
