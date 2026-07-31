<script lang="ts">
  import Card from '../components/Card.svelte';
  import Icon from '../components/Icon.svelte';
  import type { IconName } from '../components/Icon.svelte';
  import Input from '../components/Input.svelte';
  import PickerField from '../components/PickerField.svelte';
  import SectionHeader from '../components/SectionHeader.svelte';
  import TopBar from '../components/TopBar.svelte';
  import { Api } from '../lib/api.svelte';
  import { confirmDelete } from '../lib/dialog.svelte';
  import type { PushSettings } from '../lib/models';
  import { router } from '../lib/router.svelte';
  import { showError, toast } from '../lib/toast.svelte';

  let url = $state(Api.baseUrl);
  let push = $state.raw<PushSettings | null>(null);

  $effect(() => {
    if (Api.isLoggedIn) {
      (Api.get('/api/push/settings') as Promise<PushSettings>)
        .then((p) => (push = p))
        .catch(() => {});
    }
  });

  function saveUrl() {
    Api.setBaseUrl(url);
    url = Api.baseUrl;
    toast('Zapisano adres serwera');
  }

  async function testConnection() {
    Api.setBaseUrl(url);
    try {
      await Api.get('/healthz');
      toast('Połączenie działa! 🎉');
    } catch (e) {
      showError(e);
    }
  }

  async function setDigestHour(hour: number) {
    try {
      push = (await Api.put('/api/push/settings', { digestHour: hour })) as PushSettings;
    } catch (e) {
      showError(e);
    }
  }

  async function testPush() {
    try {
      await Api.post('/api/push/test');
      toast('Wysłane! Sprawdź powiadomienie z ntfy 🎉');
    } catch (e) {
      showError(e);
    }
  }

  async function regenerate() {
    const sure = await confirmDelete(
      'Stary temat przestanie działać - trzeba będzie zmienić subskrypcję w aplikacji ntfy.',
    );
    if (!sure) return;
    try {
      push = (await Api.post('/api/push/regenerate')) as PushSettings;
      toast('Wygenerowano nowy temat');
    } catch (e) {
      showError(e);
    }
  }

  async function copy(label: string, value: string) {
    try {
      await navigator.clipboard.writeText(value);
      toast(`Skopiowano ${label}`);
    } catch {
      toast('Nie udało się skopiować');
    }
  }

  function logout() {
    Api.logout();
    router.replace('login');
  }
</script>

{#snippet settingRow(icon: IconName, title: string, subtitle: string, onCopy: () => void)}
  <div class="setting-row">
    <Icon name={icon} size={20} />
    <span class="setting-main">
      <span>{title}</span>
      <span class="row-sub break">{subtitle}</span>
    </span>
    <button class="icon-btn" onclick={onCopy} aria-label="Kopiuj">
      <Icon name="copy" size={19} color="var(--primary)" />
    </button>
  </div>
{/snippet}

<div class="screen">
  <TopBar title="Ustawienia ⚙️" />
  <div class="screen-body">
    <SectionHeader title="🌐 Serwer" />
    <Input label="Adres serwera" bind:value={url} inputmode="url" placeholder="http://10.0.2.2:8080" />
    <div class="btn-row">
      <button class="btn-outline" onclick={testConnection}>Sprawdź połączenie</button>
      <button class="btn-primary save-url" onclick={saveUrl}>Zapisz</button>
    </div>
    <Card>
      <p class="hint">
        Podpowiedź 💡<br /><br />• Emulator Androida: http://10.0.2.2:8080<br />• Prawdziwy telefon:
        adres IP komputera z backendem w tej samej sieci Wi-Fi, np. http://192.168.1.20:8080
      </p>
    </Card>

    {#if Api.isLoggedIn}
      <SectionHeader title="🔔 Powiadomienia" />
      <Card>
        <p class="hint">
          Przypomnienia dzwonią na tym telefonie automatycznie (lokalne alarmy - działają bez
          internetu). Poniższy push przez Twój własny serwer ntfy to opcjonalny dodatek: dociera
          nawet wtedy, gdy Ogarniaczka jest zamknięta, i na inne urządzenia.
        </p>
      </Card>
      {#if push && !push.enabled}
        <Card>
          <p class="hint">
            Serwer push (ntfy) nie jest skonfigurowany na backendzie.<br />Uruchom kontener ntfy z
            docker-compose i ustaw NTFY_URL.
          </p>
        </Card>
      {/if}
      {#if push?.enabled}
        <Card>
          {@render settingRow('server', 'Serwer ntfy', push.serverUrl, () =>
            copy('adres serwera', push!.serverUrl),
          )}
          {@render settingRow('key', 'Twój sekretny temat', push.topic, () =>
            copy('temat', push!.topic),
          )}
          <PickerField
            label="Poranne podsumowanie obowiązków"
            value={String(push.digestHour)}
            onchange={(v) => setDigestHour(parseInt(v, 10))}
            options={[
              { value: '-1', label: 'wyłączone' },
              ...Array.from({ length: 8 }, (_, i) => i + 5).map((h) => ({
                value: String(h),
                label: `${h}:00`,
              })),
            ]}
          />
          <div class="btn-row">
            <button class="btn-outline" onclick={testPush}>Wyślij testowe</button>
            <button class="btn-outline" onclick={regenerate}>Nowy temat</button>
          </div>
        </Card>
        <Card>
          <p class="hint">
            Jak włączyć push na telefonie 📲<br /><br />1. Zainstaluj darmową aplikację "ntfy"
            (Google Play lub F-Droid).<br />2. W ntfy: Dodaj subskrypcję → wklej temat skopiowany
            powyżej.<br />3. W "Użyj innego serwera" podaj adres serwera ntfy z tej strony.<br />4.
            Kliknij "Wyślij testowe" i sprawdź, czy przyszło. 🎉<br /><br />Temat traktuj jak hasło
            - kto go zna, może czytać Twoje powiadomienia.
          </p>
        </Card>
      {/if}

      <SectionHeader title="👤 Konto" />
      <Card>
        <div class="account-row">
          <Icon name="person" size={20} />
          <span>{Api.displayName || 'Zalogowano'}</span>
        </div>
        <button class="btn-outline danger" onclick={logout}>Wyloguj się</button>
      </Card>
    {/if}
  </div>
</div>

<style>
  .save-url {
    margin-top: 0;
    flex: 0 1 auto;
    padding-left: 22px;
    padding-right: 22px;
  }

  :global(.btn-row) + :global(.card) {
    margin-top: 12px;
  }

  .hint {
    font-size: 13px;
    line-height: 1.5;
  }

  .setting-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 0;
  }

  .setting-main {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }

  .break {
    word-break: break-all;
  }

  .account-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
  }
</style>
