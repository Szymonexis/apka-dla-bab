<script lang="ts">
  import { activeToasts } from '../lib/toast.svelte';
</script>

<div class="toasts" aria-live="polite">
  {#each activeToasts() as t (t.id)}
    <div class="toast">{t.message}</div>
  {/each}
</div>

<style>
  .toasts {
    position: fixed;
    left: 0;
    right: 0;
    bottom: calc(84px + var(--safe-bottom));
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    pointer-events: none;
    z-index: 60;
  }

  .toast {
    background: rgba(31, 26, 28, 0.92);
    color: #fff;
    font-size: 13.5px;
    border-radius: 999px;
    padding: 9px 18px;
    max-width: 86%;
    text-align: center;
  }
</style>
