<script lang="ts">
  import AuthImage from '../../components/AuthImage.svelte';
  import Card from '../../components/Card.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import Fab from '../../components/Fab.svelte';
  import Icon from '../../components/Icon.svelte';
  import { Api } from '../../lib/api.svelte';
  import { showDialog } from '../../lib/dialog.svelte';
  import type { Recipe } from '../../lib/models';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError, toast } from '../../lib/toast.svelte';
  import { todayStr } from '../../lib/util';

  let recipes = $state.raw<Recipe[]>([]);
  let search = $state('');

  async function load() {
    recipes = (await Api.get('/api/recipes')) as Recipe[];
  }

  $effect(() => {
    load().catch(showError);
  });

  async function toggleFavorite(r: Recipe) {
    try {
      await Api.put(`/api/recipes/${r.id}`, { ...r, favorite: !r.favorite });
      await load();
    } catch (e) {
      showError(e);
    }
  }

  async function randomIdea() {
    try {
      const r = (await Api.get('/api/recipes/random')) as Recipe;
      const choice = await showDialog(
        'Pomysł na obiad 🎲',
        r.timeMinutes ? `${r.title}\n⏱️ ok. ${r.timeMinutes} min` : r.title,
        [
          { text: 'Zamknij', value: 'close', style: 'cancel' },
          { text: 'Zobacz', value: 'view' },
          { text: 'Na dziś!', value: 'today' },
        ],
      );
      if (choice === 'view') {
        router.push('recipe', { id: r.id });
      } else if (choice === 'today') {
        await Api.put('/api/mealplan', {
          date: todayStr(),
          mealType: 'obiad',
          recipeId: r.id,
          note: '',
        });
        toast('Zaplanowane na dziś! 🍽️');
      }
    } catch (e) {
      showError(e);
    }
  }

  const filtered = $derived.by(() => {
    const q = search.trim().toLowerCase();
    if (!q) return recipes;
    return recipes.filter(
      (r) => r.title.toLowerCase().includes(q) || r.tags.some((t) => t.toLowerCase().includes(q)),
    );
  });
</script>

<div class="screen-body with-fab">
  <div class="search-row">
    <div class="search-box">
      <Icon name="search" size={18} color="var(--muted)" />
      <input placeholder="Szukaj przepisu lub tagu..." bind:value={search} />
    </div>
    <button class="text-btn" onclick={randomIdea}>🎲 Wylosuj</button>
  </div>

  {#if filtered.length === 0}
    <EmptyState emoji="👩‍🍳" text={'Brak przepisów.\nDodaj pierwszy plusem na dole!'} />
  {/if}

  {#each filtered as r (r.id)}
    <button class="full-width" onclick={() => router.push('recipe', { id: r.id })}>
      <Card>
        <div class="recipe-row">
          {#if r.imageFileId}
            <div class="thumb"><AuthImage fileId={r.imageFileId} alt={r.title} /></div>
          {:else}
            <span class="thumb-emoji">🍲</span>
          {/if}
          <span class="recipe-main">
            <span class="recipe-title">{r.title}</span>
            <span class="row-sub">
              {[r.timeMinutes ? `⏱️ ${r.timeMinutes} min` : null, r.tags.join(', ') || null]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </span>
          <span
            class="fav"
            role="button"
            tabindex="0"
            aria-label="Ulubiony"
            onclick={(e) => {
              e.stopPropagation();
              toggleFavorite(r);
            }}
            onkeydown={(e) => {
              if (e.key === 'Enter') {
                e.stopPropagation();
                toggleFavorite(r);
              }
            }}
          >
            <Icon
              name={r.favorite ? 'heart' : 'heart-outline'}
              size={22}
              color={r.favorite ? 'var(--primary)' : 'var(--muted)'}
            />
          </span>
        </div>
      </Card>
    </button>
  {/each}
</div>
<Fab
  onclick={() => {
    setStash(undefined);
    router.push('recipe-edit');
  }}
/>

<style>
  .search-row {
    display: flex;
    align-items: center;
    gap: 4px;
    padding-top: 8px;
  }

  .search-box {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 6px;
    border: 1px solid var(--outline);
    border-radius: var(--radius-field);
    padding: 0 10px;
    background: var(--surface);
  }

  .search-box input {
    flex: 1;
    min-width: 0;
    border: none;
    outline: none;
    padding: 9px 0;
    background: transparent;
  }

  .full-width {
    display: block;
    width: 100%;
    text-align: left;
  }

  .recipe-row {
    display: flex;
    align-items: center;
  }

  .thumb {
    width: 52px;
    height: 52px;
    border-radius: 8px;
    margin-right: 10px;
    overflow: hidden;
    flex-shrink: 0;
  }

  .thumb-emoji {
    font-size: 28px;
    margin-right: 10px;
  }

  .recipe-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .recipe-title {
    font-weight: 600;
  }

  .fav {
    display: inline-flex;
    padding: 4px;
  }
</style>
