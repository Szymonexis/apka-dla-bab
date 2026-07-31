<script lang="ts">
  import AuthImage from '../components/AuthImage.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { router } from '../lib/router.svelte';

  // Pełnoekranowy podgląd zdjęcia (np. paragonu).
  const fileId = router.route.params.fileId;
</script>

<div class="screen photo-screen">
  <TopBar title="" dark />
  <div class="photo-body">
    <AuthImage {fileId} alt="Zdjęcie" contain />
  </div>
</div>

<style>
  .photo-screen {
    background: #000;
  }

  .photo-body {
    flex: 1;
    min-height: 0;
  }
</style>
