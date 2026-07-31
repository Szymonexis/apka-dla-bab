<script module lang="ts">
  // Wybrany miesiąc przeżywa wejścia w ekrany edycji.
  let month = $state.raw(new Date(new Date().getFullYear(), new Date().getMonth(), 1));
</script>

<script lang="ts">
  import Card from '../../components/Card.svelte';
  import EmptyState from '../../components/EmptyState.svelte';
  import Fab from '../../components/Fab.svelte';
  import Icon from '../../components/Icon.svelte';
  import Input from '../../components/Input.svelte';
  import Modal from '../../components/Modal.svelte';
  import NavRow from '../../components/NavRow.svelte';
  import PageHeader from '../../components/PageHeader.svelte';
  import ProgressBar from '../../components/ProgressBar.svelte';
  import SectionHeader from '../../components/SectionHeader.svelte';
  import { Api } from '../../lib/api.svelte';
  import type { BudgetSummary, Tx } from '../../lib/models';
  import { router } from '../../lib/router.svelte';
  import { setStash } from '../../lib/stash';
  import { showError } from '../../lib/toast.svelte';
  import {
    categoryEmoji,
    formatMoney,
    monthHeader,
    monthStr,
    parseMoney,
    prettyDate,
    txCategories,
  } from '../../lib/util';

  let summary = $state.raw<BudgetSummary | null>(null);
  let txs = $state.raw<Tx[]>([]);
  let limitCategory = $state<string | null>(null);
  let limitInput = $state('');
  let pickAddCategory = $state(false);

  async function load(m: Date) {
    const ms = monthStr(m);
    const [s, t] = await Promise.all([
      Api.get('/api/budget/summary', { month: ms }) as Promise<BudgetSummary>,
      Api.get('/api/transactions', { month: ms }) as Promise<Tx[]>,
    ]);
    summary = s;
    txs = t;
  }

  $effect(() => {
    load(month).catch(showError);
  });

  function shiftMonth(delta: number) {
    month = new Date(month.getFullYear(), month.getMonth() + delta, 1);
  }

  function openLimit(category: string, currentLimit: number) {
    limitCategory = category;
    limitInput = currentLimit > 0 ? (currentLimit / 100).toFixed(2).replace('.', ',') : '';
  }

  async function saveLimit() {
    if (!limitCategory) return;
    const grosze = parseMoney(limitInput) ?? 0;
    try {
      await Api.put('/api/budget/limits', {
        month: monthStr(month),
        category: limitCategory,
        limitGrosze: grosze,
      });
      limitCategory = null;
      await load(month);
    } catch (e) {
      showError(e);
    }
  }

  const balance = $derived((summary?.incomeGrosze ?? 0) - (summary?.expenseGrosze ?? 0));
  const addable = $derived.by(() => {
    const existing = new Set(summary?.categories.map((c) => c.category) ?? []);
    return txCategories.filter((c) => !existing.has(c));
  });
</script>

<PageHeader title="Budżet domowy 💰" />
<NavRow label={monthHeader(month)} onprev={() => shiftMonth(-1)} onnext={() => shiftMonth(1)} />

<div class="screen-body with-fab">
  <Card>
    <div class="summary">
      <div>
        <p class="small-label">Przychody</p>
        <p class="money income">{formatMoney(summary?.incomeGrosze ?? 0)}</p>
        <p class="small-label gap">Wydatki</p>
        <p class="money expense">{formatMoney(summary?.expenseGrosze ?? 0)}</p>
      </div>
      <div class="balance">
        <p class="small-label">Bilans</p>
        <p class="money big" class:income={balance >= 0} class:expense={balance < 0}>
          {formatMoney(balance)}
        </p>
      </div>
    </div>
  </Card>

  <SectionHeader title="📊 Kategorie i limity">
    {#snippet right()}
      {#if addable.length > 0}
        <button class="text-btn" onclick={() => (pickAddCategory = true)}>+ Limit</button>
      {/if}
    {/snippet}
  </SectionHeader>
  {#if !summary || summary.categories.length === 0}
    <Card>
      <EmptyState emoji="🧮" text={'Dodaj wydatki albo ustaw limity,\nżeby coś tu zobaczyć'} />
    </Card>
  {:else}
    {#each summary.categories as c (c.category)}
      {@const over = c.limitGrosze > 0 && c.spentGrosze > c.limitGrosze}
      <button class="full-width" onclick={() => openLimit(c.category, c.limitGrosze)}>
        <Card>
          <div class="cat-row">
            <span class="cat-emoji">{categoryEmoji[c.category] ?? '✨'}</span>
            <span class="cat-name">{c.category}</span>
            <span class="cat-amounts">
              <span class="spent" class:overspent={over}>{formatMoney(c.spentGrosze)}</span>
              {#if c.limitGrosze > 0}
                <span class="of-limit">z {formatMoney(c.limitGrosze)}</span>
              {/if}
            </span>
          </div>
          {#if c.limitGrosze > 0}
            <ProgressBar value={c.spentGrosze / c.limitGrosze} {over} />
          {/if}
        </Card>
      </button>
    {/each}
  {/if}

  <SectionHeader title="🧾 Transakcje" />
  {#if txs.length === 0}
    <Card>
      <EmptyState emoji="🛍️" text={'Brak transakcji w tym miesiącu.\nDodaj plusem!'} />
    </Card>
  {:else}
    {#each txs as t (t.id)}
      <button
        class="full-width"
        onclick={() => {
          setStash(t);
          router.push('transaction');
        }}
      >
        <Card>
          <div class="tx-row">
            <span class="cat-emoji">
              {t.kind === 'income' ? '💵' : (categoryEmoji[t.category] ?? '✨')}
            </span>
            <span class="tx-main">
              <span class="tx-desc">{t.description || t.category}</span>
              <span class="row-sub">{prettyDate(t.occurredOn)} · {t.category}</span>
            </span>
            {#if t.receiptFileId}
              <span
                class="receipt-btn"
                role="button"
                tabindex="0"
                aria-label="Paragon"
                onclick={(e) => {
                  e.stopPropagation();
                  router.push('photo', { fileId: t.receiptFileId! });
                }}
                onkeydown={(e) => {
                  if (e.key === 'Enter') {
                    e.stopPropagation();
                    router.push('photo', { fileId: t.receiptFileId! });
                  }
                }}
              >
                <Icon name="receipt" size={22} color="var(--primary)" />
              </span>
            {/if}
            <span class="tx-amount" class:income={t.kind === 'income'} class:expense={t.kind === 'expense'}>
              {t.kind === 'income' ? '+' : '-'}{formatMoney(t.amountGrosze)}
            </span>
          </div>
        </Card>
      </button>
    {/each}
  {/if}
</div>

<Fab
  onclick={() => {
    setStash(undefined);
    router.push('transaction');
  }}
/>

<!-- wybór kategorii dla nowego limitu -->
<Modal open={pickAddCategory} onclose={() => (pickAddCategory = false)}>
  <p class="dialog-title">Limit dla kategorii</p>
  {#each addable as c (c)}
    <button
      class="option"
      onclick={() => {
        pickAddCategory = false;
        openLimit(c, 0);
      }}
    >
      {categoryEmoji[c] ?? '✨'}
      {c}
    </button>
  {/each}
</Modal>

<!-- edycja limitu -->
<Modal open={limitCategory != null} onclose={() => (limitCategory = null)}>
  <p class="dialog-title">
    Limit: {limitCategory ? `${categoryEmoji[limitCategory] ?? '✨'} ${limitCategory}` : ''}
  </p>
  <Input
    label="Limit miesięczny (zł)"
    placeholder="0 = usuń limit"
    bind:value={limitInput}
    inputmode="decimal"
    autofocus
  />
  <button class="btn-primary" onclick={saveLimit}>Zapisz</button>
  <button class="btn-outline cancel-btn" onclick={() => (limitCategory = null)}>Anuluj</button>
</Modal>

<style>
  .summary {
    display: flex;
    justify-content: space-between;
  }

  .balance {
    text-align: right;
  }

  .small-label {
    font-size: 12px;
    color: var(--muted);
  }

  .small-label.gap {
    margin-top: 8px;
  }

  .money {
    font-weight: 700;
    font-size: 16px;
  }

  .money.big {
    font-size: 24px;
  }

  .income {
    color: var(--green);
  }

  .expense {
    color: var(--error);
  }

  .full-width {
    display: block;
    width: 100%;
    text-align: left;
  }

  .cat-row,
  .tx-row {
    display: flex;
    align-items: center;
  }

  .cat-emoji {
    font-size: 22px;
    margin-right: 10px;
  }

  .cat-name {
    flex: 1;
    font-weight: 600;
  }

  .cat-amounts {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
  }

  .spent {
    font-weight: 700;
  }

  .spent.overspent {
    color: var(--error);
  }

  .of-limit {
    font-size: 11px;
    color: var(--muted);
  }

  .tx-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .tx-desc {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .receipt-btn {
    display: inline-flex;
    padding: 4px;
    margin-right: 8px;
  }

  .tx-amount {
    font-weight: 700;
  }

  .cancel-btn {
    margin-top: 8px;
  }
</style>
