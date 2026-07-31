// Dialogi (odpowiednik Alert.alert): promise rozwiązywany wartością
// klikniętego przycisku. DialogHost.svelte renderuje aktualny stan.

export interface DialogButton {
  text: string;
  value: string;
  style?: 'default' | 'cancel' | 'destructive';
}

export interface DialogState {
  title: string;
  message?: string;
  buttons: DialogButton[];
  resolve: (value: string) => void;
}

let current = $state.raw<DialogState | null>(null);

export function showDialog(
  title: string,
  message: string | undefined,
  buttons: DialogButton[],
): Promise<string> {
  return new Promise((resolve) => {
    current = { title, message, buttons, resolve };
  });
}

export function confirmDelete(what: string): Promise<boolean> {
  return showDialog('Na pewno usunąć?', what, [
    { text: 'Anuluj', value: 'cancel', style: 'cancel' },
    { text: 'Usuń', value: 'ok', style: 'destructive' },
  ]).then((v) => v === 'ok');
}

export function dialogState(): DialogState | null {
  return current;
}

export function resolveDialog(value: string): void {
  const d = current;
  current = null;
  d?.resolve(value);
}
