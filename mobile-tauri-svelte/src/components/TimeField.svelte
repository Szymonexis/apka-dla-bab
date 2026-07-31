<script lang="ts">
  import FieldButton from './FieldButton.svelte';

  // Godzina {hour, minute}.
  let {
    label,
    value,
    onchange,
  }: {
    label?: string;
    value: { hour: number; minute: number };
    onchange: (value: { hour: number; minute: number }) => void;
  } = $props();

  const supportsPicker =
    typeof HTMLInputElement !== 'undefined' && 'showPicker' in HTMLInputElement.prototype;

  const pad = (n: number) => n.toString().padStart(2, '0');
  const asText = $derived(`${pad(value.hour)}:${pad(value.minute)}`);

  let input: HTMLInputElement | undefined = $state();

  function openPicker() {
    if (!input) return;
    input.value = asText;
    try {
      input.showPicker();
    } catch {
      input.click();
    }
  }

  function onNativeChange(e: Event) {
    const v = (e.currentTarget as HTMLInputElement).value;
    if (!v) return;
    const [h, m] = v.split(':').map(Number);
    onchange({ hour: h, minute: m });
  }
</script>

{#if supportsPicker}
  <FieldButton {label} value={asText} onclick={openPicker} />
  <input
    class="hidden-picker"
    type="time"
    bind:this={input}
    onchange={onNativeChange}
    tabindex="-1"
    aria-hidden="true"
  />
{:else}
  <label class="field-wrap">
    {#if label}<span class="field-label">{label}</span>{/if}
    <input class="input" type="time" value={asText} onchange={onNativeChange} />
  </label>
{/if}
