// Akcje Svelte współdzielone przez formularze.

/** Fokus po zamontowaniu (odpowiednik autoFocus), bez ostrzeżeń a11y. */
export function autofocus(node: HTMLElement, enabled: boolean) {
  if (enabled) setTimeout(() => node.focus(), 50);
}
