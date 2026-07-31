import { showDialog } from './dialog.svelte';

// Wybór zdjęcia przez systemowy <input type="file"> webview'a - na Androidzie
// otwiera natywny wybór z galerii, a z atrybutem `capture` aparat.

function pickFile(capture: boolean): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    if (capture) input.setAttribute('capture', 'environment');
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.oncancel = () => resolve(null);
    input.click();
  });
}

/** Wybór zdjęcia: aparat albo galeria. Zwraca plik albo null. */
export async function pickPhoto(): Promise<File | null> {
  const choice = await showDialog('Zdjęcie', undefined, [
    { text: 'Anuluj', value: 'cancel', style: 'cancel' },
    { text: 'Galeria', value: 'gallery' },
    { text: 'Aparat', value: 'camera' },
  ]);
  if (choice !== 'gallery' && choice !== 'camera') return null;
  return pickFile(choice === 'camera');
}
