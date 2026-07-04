<script>
  // "About this project" overflow menu, mirrored top-right against the logo.
  // Aligned to Evidence's header container (max-w-7xl + matching padding) so it
  // sits exactly where the built-in kebab did, symmetric with the logo.
  import { fly } from 'svelte/transition';
  let open = false;
  const close = () => (open = false);
  const toggle = () => (open = !open);
  function onKey(e) {
    if (e.key === 'Escape') close();
  }
</script>

<svelte:window on:keydown={onKey} />

<div class="pointer-events-none fixed top-0 left-0 z-50 h-12 w-full">
  <div class="mx-auto flex h-full max-w-7xl items-center justify-end px-5 sm:px-6 md:px-12">
    <div class="pointer-events-auto relative">
      <button
        type="button"
        aria-label="About this project"
        aria-haspopup="true"
        aria-expanded={open}
        class="rounded-lg p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-300"
        on:click|stopPropagation={toggle}
      >
        <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <circle cx="4" cy="10" r="1.6" />
          <circle cx="10" cy="10" r="1.6" />
          <circle cx="16" cy="10" r="1.6" />
        </svg>
      </button>

      {#if open}
        <!-- click-away backdrop -->
        <button class="pointer-events-auto fixed inset-0 z-40 cursor-default focus:outline-none" aria-label="Close menu" tabindex="-1" on:click={close}></button>

        <div
          class="pointer-events-auto absolute right-0 top-11 z-50 w-60 overflow-hidden rounded-xl border border-gray-200 bg-white py-1.5 text-sm shadow-lg"
          transition:fly={{ y: -4, duration: 130 }}
        >
          <a href="https://saugki1773.github.io/data-engineering-blog" target="_blank" rel="noreferrer" class="flex items-center justify-between px-4 py-2 text-gray-700 no-underline hover:bg-gray-50" on:click={close}>
            Data Engineer's Diary <span class="text-xs text-gray-300">↗</span>
          </a>
          <a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" rel="noreferrer" class="flex items-center justify-between px-4 py-2 text-gray-700 no-underline hover:bg-gray-50" on:click={close}>
            Source Code on GitHub <span class="text-xs text-gray-300">↗</span>
          </a>
          <div class="my-1 border-t border-gray-100"></div>
          <a href="/glossary" class="block px-4 py-2 text-gray-700 no-underline hover:bg-gray-50" on:click={close}>Data Glossary</a>
          <a href="/about" class="block px-4 py-2 text-gray-700 no-underline hover:bg-gray-50" on:click={close}>About This Project</a>
        </div>
      {/if}
    </div>
  </div>
</div>
