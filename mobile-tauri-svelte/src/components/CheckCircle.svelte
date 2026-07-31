<script lang="ts">
  import Icon from './Icon.svelte';

  let { checked, onclick }: { checked: boolean; onclick: () => void } = $props();
</script>

<button class="check" {onclick} role="checkbox" aria-checked={checked} aria-label="Odhacz">
  {#if checked}
    <Icon name="checkmark-circle" size={26} color="var(--primary)" />
  {:else}
    <Icon name="ellipse" size={26} color="var(--muted)" />
  {/if}
</button>

<style>
  .check {
    display: inline-flex;
    margin-right: 10px;
    flex-shrink: 0;
  }
</style>
