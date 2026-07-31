<script lang="ts">
  import { autofocus as focusAction } from './actions';

  let {
    label,
    value = $bindable(''),
    placeholder = '',
    multiline = false,
    password = false,
    inputmode,
    autofocus = false,
    big = false,
    onsubmit,
  }: {
    label?: string;
    value?: string;
    placeholder?: string;
    multiline?: boolean;
    password?: boolean;
    inputmode?: 'text' | 'decimal' | 'numeric' | 'email' | 'url';
    autofocus?: boolean;
    big?: boolean;
    onsubmit?: () => void;
  } = $props();

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && onsubmit) {
      e.preventDefault();
      onsubmit();
    }
  }
</script>

<label class="field-wrap">
  {#if label}<span class="field-label">{label}</span>{/if}
  {#if multiline}
    <textarea class="input" bind:value {placeholder} use:focusAction={autofocus}></textarea>
  {:else if password}
    <input
      class="input"
      type="password"
      bind:value
      {placeholder}
      {onkeydown}
      use:focusAction={autofocus}
    />
  {:else}
    <input
      class="input"
      class:big
      type="text"
      bind:value
      {placeholder}
      {inputmode}
      {onkeydown}
      autocapitalize={inputmode === 'email' || inputmode === 'url' ? 'off' : 'sentences'}
      autocorrect={inputmode === 'email' || inputmode === 'url' ? 'off' : undefined}
      use:focusAction={autofocus}
    />
  {/if}
</label>

<style>
  .big {
    font-size: 24px;
    font-weight: 700;
  }
</style>
