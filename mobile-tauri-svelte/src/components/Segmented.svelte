<script lang="ts">
  let {
    options,
    value,
    onchange,
  }: {
    options: { value: string; label: string }[];
    value: string;
    onchange: (value: string) => void;
  } = $props();
</script>

<div class="segmented">
  {#each options as o (o.value)}
    <button class="segment" class:active={o.value === value} onclick={() => onchange(o.value)}>
      {o.label}
    </button>
  {/each}
</div>

<style>
  .segmented {
    display: flex;
    border: 1px solid var(--primary);
    border-radius: var(--radius-field);
    overflow: hidden;
    margin-bottom: 12px;
  }

  .segment {
    flex: 1;
    padding: 10px 4px;
    font-weight: 600;
    font-size: 13px;
    text-align: center;
  }

  .segment.active {
    background: var(--primary);
    color: #fff;
  }
</style>
