<script lang="ts">
  import { Api } from '../lib/api.svelte';

  // Obrazek zza autoryzacji: <img> nie umie wysłać nagłówka Bearer, więc
  // pobieramy plik fetchem (z tokenem) i pokazujemy blob-URL.
  // `src` (np. podgląd świeżo wybranego pliku) ma pierwszeństwo przed `fileId`.
  let {
    fileId = null,
    src = null,
    alt = '',
    contain = false,
  }: {
    fileId?: string | null;
    src?: string | null;
    alt?: string;
    contain?: boolean;
  } = $props();

  let blobUrl = $state<string | null>(null);

  $effect(() => {
    if (src || !fileId) {
      blobUrl = null;
      return;
    }
    const id = fileId;
    let cancelled = false;
    let created: string | null = null;
    Api.fetchBlob(id)
      .then((blob) => {
        if (cancelled) return;
        created = URL.createObjectURL(blob);
        blobUrl = created;
      })
      .catch(() => {
        if (!cancelled) blobUrl = null;
      });
    return () => {
      cancelled = true;
      if (created) URL.revokeObjectURL(created);
    };
  });

  const shown = $derived(src ?? blobUrl);
</script>

{#if shown}
  <img src={shown} {alt} class:contain />
{:else}
  <div class="placeholder" class:contain></div>
{/if}

<style>
  img,
  .placeholder {
    display: block;
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: inherit;
  }

  img.contain {
    object-fit: contain;
  }

  .placeholder {
    background: var(--primary-container);
  }
</style>
