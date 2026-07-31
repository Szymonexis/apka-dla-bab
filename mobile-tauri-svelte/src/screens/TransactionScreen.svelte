<script lang="ts">
  import AuthImage from '../components/AuthImage.svelte';
  import DateField from '../components/DateField.svelte';
  import Icon from '../components/Icon.svelte';
  import Input from '../components/Input.svelte';
  import PickerField from '../components/PickerField.svelte';
  import Segmented from '../components/Segmented.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import { confirmDelete } from '../lib/dialog.svelte';
  import type { Tx } from '../lib/models';
  import { pickPhoto } from '../lib/photos';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { categoryEmoji, parseMoney, todayStr, txCategories } from '../lib/util';

  const existing = takeStash<Tx>();

  let kind = $state<string>(existing?.kind ?? 'expense');
  let amount = $state(existing ? (existing.amountGrosze / 100).toFixed(2).replace('.', ',') : '');
  let category = $state(existing?.category ?? 'jedzenie');
  let date = $state<string | null>(existing?.occurredOn ?? todayStr());
  let description = $state(existing?.description ?? '');
  let receiptFileId = $state<string | null>(existing?.receiptFileId ?? null);
  let pickedFile = $state.raw<File | null>(null);
  let busy = $state(false);

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

  const hasReceipt = $derived(pickedUrl != null || receiptFileId != null);
  const categories = [...new Set([...txCategories, existing?.category ?? 'jedzenie'])];

  async function save() {
    const grosze = parseMoney(amount);
    if (!grosze || grosze <= 0) {
      showError('Podaj prawidłową kwotę, np. 24,99');
      return;
    }
    if (!date) {
      showError('Wybierz datę');
      return;
    }
    busy = true;
    try {
      let receiptId = receiptFileId;
      if (pickedFile) receiptId = await Api.uploadFile(pickedFile);
      const body = {
        occurredOn: date,
        kind,
        amountGrosze: grosze,
        category,
        description: description.trim(),
        receiptFileId: receiptId,
      };
      if (existing) {
        await Api.put(`/api/transactions/${existing.id}`, body);
      } else {
        await Api.post('/api/transactions', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }

  async function remove() {
    if (!existing) return;
    if (!(await confirmDelete('Transakcja zostanie usunięta.'))) return;
    try {
      await Api.del(`/api/transactions/${existing.id}`);
      router.back();
    } catch (e) {
      showError(e);
    }
  }

  async function pick() {
    const file = await pickPhoto();
    if (file) pickedFile = file;
  }
</script>

<div class="screen">
  <TopBar title={existing ? 'Edytuj transakcję' : 'Nowa transakcja'}>
    {#snippet right()}
      {#if existing}
        <button class="icon-btn" onclick={remove} aria-label="Usuń">
          <Icon name="trash" size={22} />
        </button>
      {/if}
    {/snippet}
  </TopBar>
  <div class="screen-body">
    <Segmented
      value={kind}
      onchange={(v) => (kind = v)}
      options={[
        { value: 'expense', label: '− Wydatek' },
        { value: 'income', label: '+ Przychód' },
      ]}
    />
    <Input label="Kwota (zł)" bind:value={amount} inputmode="decimal" autofocus={!existing} big />
    <PickerField
      label="Kategoria"
      value={category}
      onchange={(v) => (category = v)}
      options={categories.map((c) => ({ value: c, label: `${categoryEmoji[c] ?? '✨'} ${c}` }))}
    />
    <DateField label="Data" value={date} onchange={(v) => (date = v)} />
    <Input label="Opis (np. Biedronka, rachunek za prąd)" bind:value={description} />
    <p class="receipt-label">Paragon 🧾</p>
    {#if hasReceipt}
      <div class="receipt">
        <AuthImage src={pickedUrl} fileId={receiptFileId} alt="Paragon" />
      </div>
    {/if}
    <div class="btn-row">
      <button class="btn-outline" onclick={pick}>
        {hasReceipt ? '📷 Zmień zdjęcie' : '📷 Dodaj zdjęcie paragonu'}
      </button>
      {#if hasReceipt}
        <button
          class="btn-outline shrink"
          onclick={() => {
            pickedFile = null;
            receiptFileId = null;
          }}
        >
          Usuń
        </button>
      {/if}
    </div>
    <div class="spacer"></div>
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz</button>
  </div>
</div>

<style>
  .receipt-label {
    font-weight: 700;
    margin: 4px 0 8px;
  }

  .receipt {
    height: 200px;
    border-radius: 12px;
    margin-bottom: 10px;
    overflow: hidden;
  }

  .shrink {
    flex: 0 1 auto;
    padding-left: 16px;
    padding-right: 16px;
  }

  .spacer {
    height: 12px;
  }
</style>
