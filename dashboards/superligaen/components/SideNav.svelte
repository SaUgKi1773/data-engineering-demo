<script>
  // Hideable side pane: a left drawer with the full, grouped page list.
  // Opened from the bottom bar's "Menu" button; closes on backdrop, Esc, or navigation.
  import { createEventDispatcher } from 'svelte';
  import { fly, fade } from 'svelte/transition';
  import { page } from '$app/stores';
  import { icons, navGroups } from './navItems.js';

  export let open = false;

  const dispatch = createEventDispatcher();
  const close = () => dispatch('close');

  function onKey(e) {
    if (e.key === 'Escape') close();
  }

  // Exact match for "/", prefix-safe match for the rest.
  const isActive = (href, path) => (href === '/' ? path === '/' : path === href || path.startsWith(href + '/'));
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
        class="rounded-lg p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-300"
        on:click={close}
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d={icons.close} />
        </svg>
      </button>
    </div>

    <!-- scrollable nav -->
    <nav class="flex-1 overflow-y-auto px-3 py-4">
      {#each navGroups as group}
        <div class="mb-1 mt-4 px-3 text-[0.65rem] font-semibold uppercase tracking-wider text-gray-400 first:mt-0">
          {group.label}
        </div>
        {#each group.items as item}
          {@const active = isActive(item.href, $page.url.pathname)}
          <a
            href={item.href}
            on:click={close}
            aria-current={active ? 'page' : undefined}
            class="mb-0.5 flex items-center gap-3 rounded-lg px-2.5 py-1.5 text-sm no-underline transition-colors
              {active ? 'bg-blue-50 font-semibold text-blue-700' : 'font-medium text-gray-600 hover:bg-gray-50 hover:text-gray-900'}"
          >
            {#if item.logo}
              <img src={item.logo} alt="" class="h-8 w-8 flex-none" aria-hidden="true" />
            {:else}
              <span class="flex h-8 w-8 flex-none items-center justify-center rounded-lg text-base leading-none" style="background-color: {item.tint};" aria-hidden="true">{item.emoji}</span>
            {/if}
            {item.label}
          </a>
        {/each}
      {/each}
    </nav>
  </aside>
{/if}
