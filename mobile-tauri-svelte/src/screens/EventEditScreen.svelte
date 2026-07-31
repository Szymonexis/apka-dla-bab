<script lang="ts">
  import DateField from '../components/DateField.svelte';
  import Input from '../components/Input.svelte';
  import TimeField from '../components/TimeField.svelte';
  import Toggle from '../components/Toggle.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import type { EventItem } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { takeStash } from '../lib/stash';
  import { showError } from '../lib/toast.svelte';
  import { dateStr, parseLocalDate, todayStr } from '../lib/util';

  const existing = takeStash<EventItem>();
  const initialDate = router.route.params.initialDate;
  const start = existing ? new Date(existing.startsAt) : null;

  let title = $state(existing?.title ?? '');
  let description = $state(existing?.description ?? '');
  let date = $state<string | null>(start ? dateStr(start) : (initialDate ?? todayStr()));
  let allDay = $state(existing?.allDay ?? false);
  let time = $state(
    start ? { hour: start.getHours(), minute: start.getMinutes() } : { hour: 12, minute: 0 },
  );
  let busy = $state(false);

  async function save() {
    if (!title.trim() || !date) {
      showError('Podaj tytuł i termin wydarzenia');
      return;
    }
    busy = true;
    try {
      const d = parseLocalDate(date);
      if (!allDay) d.setHours(time.hour, time.minute, 0, 0);
      const body = {
        title: title.trim(),
        description: description.trim(),
        startsAt: d.toISOString(),
        allDay,
      };
      if (existing) {
        await Api.put(`/api/events/${existing.id}`, body);
      } else {
        await Api.post('/api/events', body);
      }
      router.back();
    } catch (e) {
      showError(e);
      busy = false;
    }
  }
</script>

<div class="screen">
  <TopBar title={existing ? 'Edytuj wydarzenie' : 'Nowe wydarzenie'} />
  <div class="screen-body">
    <Input label="Co się dzieje?" bind:value={title} autofocus={!existing} />
    <Input label="Szczegóły (opcjonalnie)" bind:value={description} />
    <DateField label="Data" value={date} onchange={(v) => (date = v)} />
    <Toggle label="Cały dzień" checked={allDay} onchange={(v) => (allDay = v)} />
    {#if !allDay}
      <TimeField label="Godzina" value={time} onchange={(v) => (time = v)} />
    {/if}
    <button class="btn-primary" onclick={save} disabled={busy}>Zapisz</button>
  </div>
</div>
