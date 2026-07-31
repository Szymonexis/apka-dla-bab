<script lang="ts">
  import type { Snippet } from 'svelte';

  let { title, right }: { title: string; right?: Snippet } = $props();
</script>

<div class="section-header">
  <span class="section-title">{title}</span>
  {@render right?.()}
</div>
