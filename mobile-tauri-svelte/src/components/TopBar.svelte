<script lang="ts">
  import type { Snippet } from 'svelte';

  import { router } from '../lib/router.svelte';
  import Icon from './Icon.svelte';

  // Nagłówek ekranów "stackowych" z przyciskiem wstecz (odpowiednik
  // natywnego headera).
  let { title, right, dark = false }: { title: string; right?: Snippet; dark?: boolean } = $props();
</script>

<header class="topbar" class:dark>
  <button class="icon-btn" onclick={() => router.back()} aria-label="Wstecz">
    <Icon name="chevron-back" />
  </button>
  <h1>{title}</h1>
  {@render right?.()}
</header>

<style>
  .topbar {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 8px 10px 4px;
  }

  h1 {
    flex: 1;
    min-width: 0;
    font-size: 19px;
    font-weight: 800;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .dark {
    color: #fff;
  }

  .dark :global(.icon-btn) {
    color: #fff;
  }
</style>
