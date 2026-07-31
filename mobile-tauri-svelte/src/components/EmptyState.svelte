<script lang="ts">
  let { emoji, text }: { emoji: string; text: string } = $props();
</script>

<div class="empty">
  <span class="emoji">{emoji}</span>
  <span class="text">{text}</span>
</div>
