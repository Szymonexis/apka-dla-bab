<script lang="ts">
  let { label }: { label: string } = $props();
</script>

<span class="chip">{label}</span>

<style>
  .chip {
    background: var(--primary-container);
    border-radius: 999px;
    padding: 4px 10px;
    margin: 0 6px 6px 0;
    font-size: 12px;
  }
</style>
