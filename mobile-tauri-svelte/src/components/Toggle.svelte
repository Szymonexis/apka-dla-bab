<script lang="ts">
  let {
    label,
    checked,
    onchange,
  }: { label: string; checked: boolean; onchange: (value: boolean) => void } = $props();
</script>

<div class="switch-row">
  <span class="switch-label">{label}</span>
  <button
    class="switch"
    class:on={checked}
    role="switch"
    aria-checked={checked}
    aria-label={label}
    onclick={() => onchange(!checked)}
  >
    <span class="knob"></span>
  </button>
</div>

<style>
  .switch-row {
    display: flex;
    align-items: center;
    margin-bottom: 12px;
    padding: 0 2px;
  }

  .switch-label {
    flex: 1;
  }

  .switch {
    width: 48px;
    height: 28px;
    border-radius: 999px;
    background: var(--outline);
    position: relative;
    transition: background 0.15s;
  }

  .switch.on {
    background: var(--primary-container);
  }

  .knob {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #fff;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
    transition: transform 0.15s;
  }

  .switch.on .knob {
    transform: translateX(20px);
    background: var(--primary);
  }
</style>
