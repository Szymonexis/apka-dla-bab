<script lang="ts">
  import AuthImage from '../components/AuthImage.svelte';
  import Input from '../components/Input.svelte';
  import Toggle from '../components/Toggle.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { Recipe } from '../lib/models';
  import { pickPhoto } from '../lib/photos';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';

  const existing = takeStash<Recipe>();

  let title = $state(existing?.title ?? '');
  let description = $state(existing?.description ?? '');
  let ingredients = $state(existing?.ingredients ?? '');
  let steps = $state(existing?.steps ?? '');
  let tags = $state(existing?.tags.join(', ') ?? '');
  let time = $state(existing?.timeMinutes?.toString() ?? '');
  let servings = $state(existing?.servings?.toString() ?? '');
  let favorite = $state(existing?.favorite ?? false);
  let imageFileId = $state<string | null>(existing?.imageFileId ?? null);
  let pickedFile = $state.raw<File | null>(null);
  let busy = $state(false);

  // Podgląd świeżo wybranego pliku (blob-URL sprzątany przy zmianie).
  let pickedUrl = $state<string | null>(null);
  $effect(() => {
    if (!pickedFile) {
      pickedUrl = null;
      return;
    }
    const url = URL.createObjectURL(pickedFile);
    pickedUrl = url;
    return () => URL.revokeObjectURL(url);
  });

  const hasImage = $derived(pickedUrl != null || imageFileId != null);

  async function save() {
    if (!title.trim()) {
      showError('Przepis musi mieć nazwę');
      return;
    }
    busy = true;
    try {
      let imageId = imageFileId;
      if (pickedFile) imageId = await Api.uploadFile(pickedFile);
      const timeParsed = parseInt(time.trim(), 10);
      const servingsParsed = parseInt(servings.trim(), 10);
      const body = {
        title: title.trim(),
        description: description.trim(),
        ingredients: ingredients.trim(),
        steps: steps.trim(),
        tags: tags
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .filter(Boolean),
        timeMinutes: Number.isFinite(timeParsed) ? timeParsed : null,
        servings: Number.isFinite(servingsParsed) ? servingsParsed : null,
        favorite,
        imageFileId: imageId,
      };
      if (existing) {
        await Api.put(`/api/recipes/${existing.id}`, body);
      } else {
        await Api.post('/api/recipes', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }

  async function pick() {
    const file = await pickPhoto();
    if (file) pickedFile = file;
  }
</script>

<div class="screen">
  <TopBar title={existing ? 'Edytuj przepis' : 'Nowy przepis'} />
  <div class="screen-body">
    <Input label="Nazwa *" bind:value={title} />
    <Input label="Krótki opis" bind:value={description} />
    <div class="two-col">
      <Input label="Czas (min)" bind:value={time} inputmode="numeric" />
      <Input label="Porcje" bind:value={servings} inputmode="numeric" />
    </div>
    <Input label="Tagi (po przecinku)" placeholder="obiad, szybkie, wege" bind:value={tags} />
    <Input label="Składniki (każdy w nowej linii)" bind:value={ingredients} multiline />
    <Input label="Przygotowanie" bind:value={steps} multiline />
    <Toggle label="Ulubiony 💗" checked={favorite} onchange={(v) => (favorite = v)} />
    {#if hasImage}
      <div class="image">
        <AuthImage src={pickedUrl} fileId={imageFileId} alt="Zdjęcie przepisu" />
      </div>
    {/if}
    <div class="btn-row">
      <button class="btn-outline" onclick={pick}>
        {hasImage ? '📷 Zmień zdjęcie' : '📷 Zdjęcie'}
      </button>
      {#if hasImage}
        <button
          class="btn-outline"
          onclick={() => {
            pickedFile = null;
            imageFileId = null;
          }}
        >
          Usuń zdjęcie
        </button>
      {/if}
    </div>
    <div class="spacer"></div>
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz przepis</button>
  </div>
</div>

<style>
  .two-col {
    display: flex;
    gap: 12px;
  }

  .two-col > :global(*) {
    flex: 1;
  }

  .image {
    height: 180px;
    border-radius: 12px;
    margin-bottom: 10px;
    overflow: hidden;
  }

  .spacer {
    height: 12px;
  }
</style>
