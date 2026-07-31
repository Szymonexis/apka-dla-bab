<script lang="ts">
  import Icon from './Icon.svelte';
  import type { IconName } from './Icon.svelte';

  let { onclick, icon = 'add' }: { onclick: () => void; icon?: IconName } = $props();
</script>

<button class="fab" {onclick} aria-label="Dodaj">
  <Icon name={icon} size={28} color="#fff" />
</button>

<style>
  .fab {
    position: absolute;
    right: 20px;
    bottom: calc(24px + var(--safe-bottom));
    width: 56px;
    height: 56px;
    border-radius: 18px;
    background: var(--primary);
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 4px 10px rgba(216, 27, 96, 0.4);
    z-index: 10;
  }
</style>
