<script>
  // Hideable side pane: a left drawer listing every platform in the group.
  // Opened from the header toggle; closes on backdrop, Esc, or navigation.
  //
  // The league sites' equivalent pane navigates within one app. Here every
  // entry is a separate deployment, so there is no active state to track — a
  // click leaves the hub entirely.
  import { createEventDispatcher } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  import { icons, leagues, externalLinks } from './navItems.js';

  export let open = false;

  const dispatch = createEventDispatcher();
  const close = () => dispatch('close');

  function onKey(e) {
    if (e.key === 'Escape') close();
  }
</script>

<svelte:window on:keydown={onKey} />

{#if open}
  <button
    class="fixed inset-0 z-[60] cursor-default bg-gray-900/40 focus:outline-none"
    aria-label="Close menu"
    tabindex="-1"
    on:click={close}
    transition:fade={{ duration: 150 }}
  ></button>

  <aside
    class="fixed inset-y-0 left-0 z-[70] flex w-[17rem] max-w-[85vw] flex-col border-r border-gray-200 bg-white shadow-xl"
    transition:fly={{ x: -288, duration: 180 }}
  >
    <!-- header -->
    <div class="flex h-14 flex-none items-center justify-between border-b border-gray-100 px-4">
      <a href="/" class="flex items-center gap-2 no-underline" on:click={close}>
        <img src="/header-logo.svg" alt="Home" class="h-7 w-auto" />
      </a>
      <button
        type="button"
        aria-label="Close menu"
        class="rounded-lg p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-300"
        on:click={close}
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d={icons.close} />
        </svg>
      </button>
    </div>

    <!-- scrollable nav -->
    <nav class="flex-1 overflow-y-auto px-3 py-4">
      <div class="mb-1 px-3 text-[0.65rem] font-semibold uppercase tracking-wider text-gray-400">
        Our platforms
      </div>
      {#each leagues as league}
        <a
          href={league.href}
          on:click={close}
          class="mb-0.5 flex items-center gap-3 rounded-lg px-2.5 py-2 no-underline transition-colors hover:bg-gray-50"
        >
          <img src={league.logo} alt="" class="h-9 w-9 flex-none" aria-hidden="true" />
          <span class="min-w-0">
            <span class="block truncate text-sm font-medium text-gray-900">{league.label}</span>
            <span class="block truncate text-xs text-gray-500">{league.country}</span>
          </span>
        </a>
      {/each}
    </nav>

    <!-- external links, mirrored from the home page footer -->
    <div class="flex-none border-t border-gray-100 px-4 py-3">
      <div class="flex items-center justify-between">
        {#each externalLinks as link}
          <a
            href={link.href}
            target="_blank"
            rel="noopener noreferrer"
            title={link.label}
            aria-label={link.label}
            class="flex h-8 w-8 flex-none items-center justify-center rounded-lg text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-300"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path d={link.path} />
            </svg>
          </a>
        {/each}
      </div>
    </div>
  </aside>
{/if}
