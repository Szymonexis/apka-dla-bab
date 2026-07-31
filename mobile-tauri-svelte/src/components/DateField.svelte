<script lang="ts">
  import { dateStr, prettyDate } from '../lib/util';
  import FieldButton from './FieldButton.svelte';

  // Data 'YYYY-MM-DD' (albo null = brak terminu, gdy allowClear).
  // Chromium (Android WebView, desktopowy Chrome): ładny przycisk +
  // input.showPicker(). WebKitGTK bez showPicker: widoczny input[type=date].
  let {
    label,
    value,
    onchange,
    allowClear = false,
    placeholder,
  }: {
    label?: string;
    value: string | null;
    onchange: (value: string | null) => void;
    allowClear?: boolean;
    placeholder?: string;
  } = $props();

  const supportsPicker =
    typeof HTMLInputElement !== 'undefined' && 'showPicker' in HTMLInputElement.prototype;

  let input: HTMLInputElement | undefined = $state();

  function openPicker() {
    if (!input) return;
    input.value = value ?? dateStr(new Date());
    try {
      input.showPicker();
    } catch {
      input.click();
    }
  }

  function onNativeChange(e: Event) {
    const v = (e.currentTarget as HTMLInputElement).value;
    onchange(v ? v : null);
  }
</script>

{#if supportsPicker}
  <FieldButton
    {label}
    value={value ? prettyDate(value) : null}
    placeholder={placeholder ?? 'Wybierz datę'}
    onclick={openPicker}
    onclear={allowClear && value ? () => onchange(null) : undefined}
  />
  <input
    class="hidden-picker"
    type="date"
    bind:this={input}
    onchange={onNativeChange}
    tabindex="-1"
    aria-hidden="true"
  />
{:else}
  <label class="field-wrap">
    {#if label}<span class="field-label">{label}</span>{/if}
    <input class="input" type="date" value={value ?? ''} onchange={onNativeChange} />
  </label>
{/if}
