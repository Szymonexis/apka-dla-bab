<script lang="ts">
  import Icon from './Icon.svelte';
  import type { IconName } from './Icon.svelte';
  import Modal from './Modal.svelte';

  export interface SheetAction {
    icon: IconName;
    label: string;
    onPress: () => void;
  }

  // Dolny arkusz z akcjami (odpowiednik bottom sheet).
  let {
    open,
    onclose,
    actions,
  }: { open: boolean; onclose: () => void; actions: SheetAction[] } = $props();
</script>

<Modal {open} {onclose} sheet>
  {#each actions as a (a.label)}
    <button
      class="sheet-item"
      onclick={() => {
        onclose();
        a.onPress();
      }}
    >
      <span class="ico"><Icon name={a.icon} size={22} /></span>
      <span>{a.label}</span>
    </button>
  {/each}
</Modal>
