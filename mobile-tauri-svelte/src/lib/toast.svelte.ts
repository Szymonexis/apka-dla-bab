// Toasty (odpowiednik ToastAndroid): kolejka w $state, host renderuje ją
// na dole ekranu.

export interface Toast {
  id: number;
  message: string;
}

let queue = $state<Toast[]>([]);
let nextId = 1;

export function toast(message: string): void {
  const id = nextId++;
  queue.push({ id, message });
  setTimeout(() => {
    const i = queue.findIndex((t) => t.id === id);
    if (i >= 0) queue.splice(i, 1);
  }, 2600);
}

export function showError(error: unknown): void {
  toast(error instanceof Error ? error.message : String(error));
}

export function activeToasts(): Toast[] {
  return queue;
}
