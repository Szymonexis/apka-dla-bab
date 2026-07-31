<script lang="ts">
  import FieldButton from './FieldButton.svelte';
  import Icon from './Icon.svelte';
  import Modal from './Modal.svelte';

  // Prosty picker: pole + modal z listą opcji.
  let {
    label,
    value,
    options,
    onchange,
    disabled = false,
  }: {
    label?: string;
    value: string;
    options: { value: string; label: string }[];
    onchange: (value: string) => void;
    disabled?: boolean;
  } = $props();

  let open = $state(false);

  const current = $derived(options.find((o) => o.value === value));
</script>

<FieldButton {label} value={current?.label ?? null} onclick={() => (open = true)} {disabled} />

<Modal {open} onclose={() => (open = false)}>
  {#each options as o (o.value)}
    <button
      class="option"
      onclick={() => {
        open = false;
        onchange(o.value);
      }}
    >
      <span class="option-label">{o.label}</span>
      {#if o.value === value}
        <Icon name="checkmark" size={18} color="var(--primary)" />
      {/if}
    </button>
  {/each}
</Modal>

<style>
  .option-label {
    flex: 1;
  }
</style>
