<script lang="ts">
  import Icon from '../components/Icon.svelte';
  import Input from '../components/Input.svelte';
  import { Api } from '../lib/api.svelte';
  import { router } from '../lib/router.svelte';
  import { showError } from '../lib/toast.svelte';

  let registerMode = $state(false);
  let name = $state('');
  let email = $state('');
  let password = $state('');
  let busy = $state(false);

  async function submit() {
    if (busy) return;
    busy = true;
    try {
      if (registerMode) {
        await Api.register(email.trim(), password, name.trim());
      } else {
        await Api.login(email.trim(), password);
      }
      router.replace('tabs');
    } catch (e) {
      showError(e);
    } finally {
      busy = false;
    }
  }
</script>

<div class="screen">
  <div class="settings-row">
    <button class="icon-btn" onclick={() => router.push('settings')} aria-label="Ustawienia">
      <Icon name="settings" />
    </button>
  </div>
  <div class="screen-body">
    <div class="login-box">
      <p class="emoji">🏡💗</p>
      <h1>Ogarniaczka</h1>
      <p class="subtitle">Twój domowy organizer - wszystko w jednym miejscu</p>
      <div class="spacer"></div>
      {#if registerMode}
        <Input label="Jak masz na imię?" bind:value={name} />
      {/if}
      <Input label="E-mail" bind:value={email} inputmode="email" />
      <Input label="Hasło" bind:value={password} password onsubmit={submit} />
      <button class="btn-primary" onclick={submit} disabled={busy}>
        {busy ? '...' : registerMode ? 'Załóż konto' : 'Zaloguj się'}
      </button>
      <button class="switch-mode" onclick={() => (registerMode = !registerMode)}>
        {registerMode ? 'Masz już konto? Zaloguj się' : 'Nie masz konta? Zarejestruj się'}
      </button>
    </div>
  </div>
</div>

<style>
  .settings-row {
    display: flex;
    justify-content: flex-end;
    padding: 4px 12px 0;
  }

  .login-box {
    max-width: 440px;
    margin: 0 auto;
    padding: 8px;
  }

  .emoji {
    font-size: 54px;
    text-align: center;
  }

  h1 {
    font-size: 30px;
    font-weight: 800;
    text-align: center;
    margin-top: 6px;
  }

  .subtitle {
    text-align: center;
    color: var(--muted);
    margin-top: 4px;
  }

  .spacer {
    height: 24px;
  }

  .switch-mode {
    display: block;
    width: 100%;
    text-align: center;
    color: var(--primary);
    font-weight: 600;
    margin-top: 14px;
    padding: 6px;
  }
</style>
