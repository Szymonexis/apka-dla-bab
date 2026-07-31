<script lang="ts">
  import type { Snippet } from 'svelte';

  import Icon from './Icon.svelte';

  // Wiersz nawigacji tydzień/miesiąc/dzień: ‹ tekst › [+ opcjonalny przycisk]
  let {
    label,
    onprev,
    onnext,
    right,
  }: { label: string; onprev: () => void; onnext: () => void; right?: Snippet } = $props();
</script>

<div class="nav-row">
  <button class="icon-btn" onclick={onprev} aria-label="Poprzedni">
    <Icon name="chevron-back" />
  </button>
  <span class="label">{label}</span>
  <button class="icon-btn" onclick={onnext} aria-label="Następny">
    <Icon name="chevron-forward" />
  </button>
  {@render right?.()}
</div>

<style>
  .nav-row {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4px 0;
  }

  .label {
    font-weight: 700;
    margin: 0 4px;
  }
</style>
