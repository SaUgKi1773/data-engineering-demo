<script>
  // Solid, always-present bottom bar of primary destinations. The side pane is
  // opened from the header toggle, not from here.
  import { page } from '$app/stores';
  import { bottomItems } from './navItems.js';

  const isActive = (href, path) => (href === '/' ? path === '/' : path === href || path.startsWith(href + '/'));
</script>

<nav
  class="fixed inset-x-0 bottom-0 z-50 border-t border-gray-200 bg-white/95 backdrop-blur md:hidden"
  style="padding-bottom: env(safe-area-inset-bottom);"
  aria-label="Primary"
>
  <div class="mx-auto flex h-16 max-w-7xl items-stretch justify-around px-2">
    {#each bottomItems as item}
      {@const active = isActive(item.href, $page.url.pathname)}
      {#if item.logo}
        <!-- Center brand button: the logo rises above the bar's top edge. -->
        <a
          href={item.href}
          aria-current={active ? 'page' : undefined}
          class="relative flex flex-1 flex-col items-center justify-end pb-[0.9rem] no-underline transition-colors
            {active ? 'text-blue-600' : 'text-gray-500 hover:text-gray-800'}"
        >
          <img
            src={item.logo}
            alt={item.label}
            class="absolute left-1/2 top-[-1.6rem] h-14 w-14 -translate-x-1/2 drop-shadow-lg transition-transform {active ? 'scale-105' : ''}"
          />
          <span class="text-[0.65rem] font-medium leading-none tracking-wide {active ? 'font-semibold' : ''}">{item.label}</span>
        </a>
      {:else}
        <a
          href={item.href}
          aria-current={active ? 'page' : undefined}
          class="flex flex-1 flex-col items-center justify-center gap-1 rounded-lg no-underline transition-colors
            {active ? 'text-blue-600' : 'text-gray-500 hover:text-gray-800'}"
        >
          <span class="text-[1.3rem] leading-none transition-opacity {active ? '' : 'opacity-70'}" aria-hidden="true">{item.emoji}</span>
          <span class="text-[0.65rem] font-medium leading-none tracking-wide {active ? 'font-semibold' : ''}">{item.label}</span>
        </a>
      {/if}
    {/each}
  </div>
</nav>
