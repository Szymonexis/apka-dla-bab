<script lang="ts">
  import DateField from '../components/DateField.svelte';
  import Input from '../components/Input.svelte';
  import TimeField from '../components/TimeField.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { Reminder } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { dateStr, parseLocalDate } from '../lib/util';

  const existing = takeStash<Reminder>();
  const initial = existing ? new Date(existing.remindAt) : new Date(Date.now() + 60 * 60 * 1000);

  let title = $state(existing?.title ?? '');
  let date = $state<string | null>(dateStr(initial));
  let time = $state({ hour: initial.getHours(), minute: initial.getMinutes() });
  let busy = $state(false);

  async function save() {
    if (!title.trim() || !date) {
      showError('Podaj treść i termin przypomnienia');
      return;
    }
    busy = true;
    try {
      const d = parseLocalDate(date);
      d.setHours(time.hour, time.minute, 0, 0);
      const body = { title: title.trim(), remindAt: d.toISOString() };
      if (existing) {
        await Api.put(`/api/reminders/${existing.id}`, body);
      } else {
        await Api.post('/api/reminders', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }
</script>

<div class="screen">
  <TopBar title={existing ? 'Edytuj przypomnienie' : 'Nowe przypomnienie'} />
  <div class="screen-body">
    <Input label="O czym Ci przypomnieć?" bind:value={title} autofocus={!existing} />
    <DateField label="Data" value={date} onchange={(v) => (date = v)} />
    <TimeField label="Godzina" value={time} onchange={(v) => (time = v)} />
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz</button>
  </div>
</div>
