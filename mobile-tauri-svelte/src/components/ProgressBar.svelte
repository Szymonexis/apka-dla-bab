<script lang="ts">
  let { value, over = false }: { value: number; over?: boolean } = $props();

  const width = $derived(Math.min(100, Math.max(0, value * 100)));
</script>

<div class="track">
  <div class="fill" class:over style="width: {width}%"></div>
</div>

<style>
  .track {
    height: 6px;
    border-radius: 3px;
    background: var(--primary-container);
    overflow: hidden;
    margin-top: 6px;
  }

  .fill {
    height: 100%;
    border-radius: 3px;
    background: var(--primary);
  }

  .fill.over {
    background: var(--error);
  }
</style>
