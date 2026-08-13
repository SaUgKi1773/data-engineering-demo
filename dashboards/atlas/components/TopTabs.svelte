<script>
  // The five page tabs, always visible in the nav band.
  //
  // The previous attempt hid navigation behind a drawer icon and its second
  // page went unfound for days. Tabs are the fix; they are text with a 2px
  // underline, not buttons, because this is an instrument rather than a site.
  import { page } from '$app/stores';
  export let tabs = [];

  const isActive = (href, path) => (href === '/' ? path === '/' : path === href || path.startsWith(href + '/'));
</script>

<nav class="flex items-stretch gap-0.5 overflow-x-auto" aria-label="Primary">
  {#each tabs as t}
    {@const active = isActive(t.href, $page.url.pathname)}
    <a href={t.href}
       aria-current={active ? 'page' : undefined}
       class="flex flex-none items-center border-b-2 px-2.5 text-[11px] font-semibold uppercase tracking-wider no-underline transition-colors
              {active ? 'border-white text-white' : 'border-transparent text-white/45 hover:text-white/80'}">
      {t.label}
    </a>
  {/each}
</nav>
