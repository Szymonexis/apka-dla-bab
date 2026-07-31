<script lang="ts">
  import Icon from './Icon.svelte';

  // Pole-przycisk otwierające coś (picker, kalendarz).
  let {
    label,
    value,
    placeholder = 'Wybierz...',
    onclick,
    onclear,
    disabled = false,
  }: {
    label?: string;
    value: string | null;
    placeholder?: string;
    onclick: () => void;
    onclear?: () => void;
    disabled?: boolean;
  } = $props();
</script>

<div class="field-wrap">
  {#if label}<span class="field-label">{label}</span>{/if}
  <button class="input field-button" {onclick} {disabled} type="button">
    <span class="value" class:placeholder={!value}>{value ?? placeholder}</span>
    {#if onclear && value}
      <span
        class="clear"
        role="button"
        tabindex="0"
        aria-label="Wyczyść"
        onclick={(e) => {
          e.stopPropagation();
          onclear();
        }}
        onkeydown={(e) => {
          if (e.key === 'Enter') {
            e.stopPropagation();
            onclear();
          }
        }}
      >
        <Icon name="close" size={18} color="var(--muted)" />
      </span>
    {:else}
      <Icon name="chevron-down" size={18} color="var(--muted)" />
    {/if}
  </button>
</div>

<style>
  .clear {
    display: inline-flex;
    padding: 2px;
  }
</style>
