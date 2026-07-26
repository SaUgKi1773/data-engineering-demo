<script>
  // Sidebar-toggle icon pinned to the far right of the header. Opens the
  // hideable side pane. The logo stays the flush-left brand anchor.
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();
</script>

<!-- Full-width bar matching Evidence's header container so the button lines up
     to the container's right edge. -->
<div class="pointer-events-none fixed top-0 left-0 z-50 h-12 w-full print:hidden">
  <div class="mx-auto flex h-full max-w-7xl items-center justify-end px-5 sm:px-6 md:px-12">
    <button
      type="button"
      aria-label="Open navigation"
      aria-haspopup="true"
      class="pointer-events-auto rounded-lg p-2 text-gray-500 transition-colors hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-300"
      on:click={() => dispatch('open')}
    >
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <rect x="3" y="4.5" width="18" height="15" rx="2.2" />
        <line x1="9" y1="4.5" x2="9" y2="19.5" />
      </svg>
    </button>
  </div>
</div>
