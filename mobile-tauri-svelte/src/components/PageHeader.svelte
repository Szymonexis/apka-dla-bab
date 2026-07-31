<script lang="ts">
  import type { Snippet } from 'svelte';

  let {
    title,
    subtitle,
    right,
  }: { title: string; subtitle?: string; right?: Snippet } = $props();
</script>

<header class="page-header">
  <div class="titles">
    <h1>{title}</h1>
    {#if subtitle}<p>{subtitle}</p>{/if}
  </div>
  {@render right?.()}
</header>

<style>
  .page-header {
    display: flex;
    align-items: center;
    padding: 8px 16px 4px;
  }

  .titles {
    flex: 1;
    min-width: 0;
  }

  h1 {
    font-size: 22px;
    font-weight: 800;
  }

  p {
    font-size: 13px;
    color: var(--muted);
    margin-top: 2px;
  }
</style>
