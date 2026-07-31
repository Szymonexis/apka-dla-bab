<script lang="ts">
  import DateField from '../components/DateField.svelte';
  import Input from '../components/Input.svelte';
  import PickerField from '../components/PickerField.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { TaskItem } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { repeatLabels } from '../lib/util';

  const existing = takeStash<TaskItem>();
  const initialDue = router.route.params.initialDue;

  let title = $state(existing?.title ?? '');
  let due = $state<string | null>(existing?.dueDate ?? initialDue ?? null);
  let repeat = $state<string>(existing?.repeat ?? 'none');
  let busy = $state(false);

  async function save() {
    if (!title.trim()) {
      showError('Podaj treść obowiązku');
      return;
    }
    busy = true;
    try {
      const body = { title: title.trim(), notes: existing?.notes ?? '', dueDate: due, repeat };
      if (existing) {
        await Api.put(`/api/tasks/${existing.id}`, body);
      } else {
        await Api.post('/api/tasks', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }
</script>

<div class="screen">
  <TopBar title={existing ? 'Edytuj obowiązek' : 'Nowy obowiązek'} />
  <div class="screen-body">
    <Input label="Co jest do zrobienia?" bind:value={title} autofocus={!existing} />
    <DateField
      label="Termin"
      value={due}
      onchange={(v) => (due = v)}
      allowClear
      placeholder="Bez terminu"
    />
    <PickerField
      label="Powtarzanie"
      value={repeat}
      onchange={(v) => (repeat = v)}
      options={Object.entries(repeatLabels).map(([value, label]) => ({ value, label }))}
    />
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz</button>
  </div>
</div>
