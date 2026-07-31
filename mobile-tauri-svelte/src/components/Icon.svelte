<script module lang="ts">
  export type IconName =
    | 'add'
    | 'add-circle'
    | 'calendar'
    | 'checkbox'
    | 'checkmark'
    | 'checkmark-circle'
    | 'chevron-back'
    | 'chevron-down'
    | 'chevron-forward'
    | 'chevron-up'
    | 'close'
    | 'copy'
    | 'create'
    | 'document-text'
    | 'ellipse'
    | 'heart'
    | 'heart-outline'
    | 'key'
    | 'notifications'
    | 'person'
    | 'pin'
    | 'pin-outline'
    | 'receipt'
    | 'refresh'
    | 'restaurant'
    | 'search'
    | 'server'
    | 'settings'
    | 'sunny'
    | 'trash'
    | 'wallet';
</script>

<script lang="ts">
  // Własny, minimalny zestaw ikon (proste kreski w stylu outline) -
  // bez zależności od zewnętrznych fontów ikon.
  let {
    name,
    size = 24,
    color = 'currentColor',
  }: { name: IconName; size?: number; color?: string } = $props();
</script>

<svg
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke={color}
  stroke-width="1.8"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  {#if name === 'add'}
    <path d="M12 5v14M5 12h14" />
  {:else if name === 'add-circle'}
    <circle cx="12" cy="12" r="9" />
    <path d="M12 8.5v7M8.5 12h7" />
  {:else if name === 'calendar'}
    <rect x="3.5" y="5" width="17" height="15.5" rx="2.5" />
    <path d="M3.5 9.5h17M8 3v4M16 3v4" />
  {:else if name === 'checkbox'}
    <rect x="4" y="4" width="16" height="16" rx="4" />
    <path d="M8.5 12.2l2.5 2.6 4.7-5.4" />
  {:else if name === 'checkmark'}
    <path d="M5 13l4.5 4.5L19 7" />
  {:else if name === 'checkmark-circle'}
    <circle cx="12" cy="12" r="9" fill={color} stroke="none" />
    <path d="M8.3 12.4l2.5 2.5 4.9-5.5" stroke="#fff" stroke-width="2" />
  {:else if name === 'chevron-back'}
    <path d="M14.5 6l-6 6 6 6" />
  {:else if name === 'chevron-down'}
    <path d="M6 9.5l6 6 6-6" />
  {:else if name === 'chevron-forward'}
    <path d="M9.5 6l6 6-6 6" />
  {:else if name === 'chevron-up'}
    <path d="M6 14.5l6-6 6 6" />
  {:else if name === 'close'}
    <path d="M6 6l12 12M18 6L6 18" />
  {:else if name === 'copy'}
    <rect x="8.5" y="8.5" width="12" height="12" rx="2.5" />
    <path d="M15.5 8.5v-3a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2h3" />
  {:else if name === 'create'}
    <path d="M4 20l1.2-4.2L16.6 4.4a2.1 2.1 0 013 3L8.2 18.8 4 20z" />
    <path d="M14.5 6.5l3 3" />
  {:else if name === 'document-text'}
    <path d="M6 2.8h8l4 4v14.4H6z" />
    <path d="M14 2.8v4h4M9 12h6M9 15.5h6" />
  {:else if name === 'ellipse'}
    <circle cx="12" cy="12" r="9" />
  {:else if name === 'heart'}
    <path
      d="M12 20.5C7.2 16.3 3.5 13.1 3.5 9.4 3.5 7 5.4 5 7.9 5c1.7 0 3.2 1 4.1 2.4C12.9 6 14.4 5 16.1 5c2.5 0 4.4 2 4.4 4.4 0 3.7-3.7 6.9-8.5 11.1z"
      fill={color}
      stroke="none"
    />
  {:else if name === 'heart-outline'}
    <path
      d="M12 20.5C7.2 16.3 3.5 13.1 3.5 9.4 3.5 7 5.4 5 7.9 5c1.7 0 3.2 1 4.1 2.4C12.9 6 14.4 5 16.1 5c2.5 0 4.4 2 4.4 4.4 0 3.7-3.7 6.9-8.5 11.1z"
    />
  {:else if name === 'key'}
    <circle cx="8" cy="14.5" r="4" />
    <path d="M11 11.5L19.5 3M16 6.5l2.5 2.5M13.5 9l2 2" />
  {:else if name === 'notifications'}
    <path d="M18.5 16.5h-13c1.4-1.5 2.2-2.7 2.2-6.7a4.3 4.3 0 118.6 0c0 4 .8 5.2 2.2 6.7z" />
    <path d="M10.3 19.5a1.9 1.9 0 003.4 0" />
  {:else if name === 'person'}
    <circle cx="12" cy="8" r="4" />
    <path d="M4.5 20.5c1.2-3.4 4-5 7.5-5s6.3 1.6 7.5 5" />
  {:else if name === 'pin'}
    <path d="M8.5 3h7L14.4 9.8l2.6 3.2H7l2.6-3.2z" fill={color} />
    <path d="M12 13v7.5" />
  {:else if name === 'pin-outline'}
    <path d="M8.5 3h7L14.4 9.8l2.6 3.2H7l2.6-3.2z" />
    <path d="M12 13v7.5" />
  {:else if name === 'receipt'}
    <path d="M6 3h12v17l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4L6 20z" />
    <path d="M9 8h6M9 11.5h6" />
  {:else if name === 'refresh'}
    <path d="M19.5 12a7.5 7.5 0 11-2.2-5.3" />
    <path d="M19.5 3.5v3.7h-3.7" />
  {:else if name === 'restaurant'}
    <path d="M8 13v8M8 3v5M5.5 3v3.5a2.5 2.5 0 005 0V3" />
    <path d="M8 8v5M17 3c-1.8.6-3 3-3 5.8 0 2 1 3.2 2 3.2v9M17 3v18" />
  {:else if name === 'search'}
    <circle cx="10.5" cy="10.5" r="6.5" />
    <path d="M15.3 15.3L21 21" />
  {:else if name === 'server'}
    <rect x="4" y="4" width="16" height="6.5" rx="2" />
    <rect x="4" y="13.5" width="16" height="6.5" rx="2" />
    <path d="M8 7.2h.01M8 16.8h.01" />
  {:else if name === 'settings'}
    <path d="M4 7.2h9M17.5 7.2H20" />
    <circle cx="15.3" cy="7.2" r="2" />
    <path d="M4 16.8h2.5M11 16.8h9" />
    <circle cx="8.7" cy="16.8" r="2" />
  {:else if name === 'sunny'}
    <circle cx="12" cy="12" r="4" />
    <path
      d="M12 2.5v2.4M12 19.1v2.4M2.5 12h2.4M19.1 12h2.4M5.3 5.3L7 7M17 17l1.7 1.7M18.7 5.3L17 7M7 17l-1.7 1.7"
    />
  {:else if name === 'trash'}
    <path d="M4.5 6.5h15M9.5 6.5V4h5v2.5M6.5 6.5l1 14h9l1-14" />
    <path d="M10 10.5v6M14 10.5v6" />
  {:else if name === 'wallet'}
    <rect x="3" y="6.5" width="18" height="13" rx="2.5" />
    <path d="M5.5 6.5L15 3.5l1.3 3M16.5 13h.01" />
  {/if}
</svg>
