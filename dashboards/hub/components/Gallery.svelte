<script>
  // A single sliding row of photos, with a click-to-enlarge lightbox.
  //
  // A row rather than a grid, because the collection grows. The strip is a
  // fixed height whatever the count, so photo thirty costs the page no more
  // vertical space than photo four. The grid this replaced grew by roughly
  // 200px per photo — thirty of them would have stood 6,000px tall and buried
  // the footer under the gallery.
  //
  // Fixed height, automatic width: each photo keeps its own proportions, so a
  // portrait phone shot sits as a narrow tile beside a wide landscape one and
  // neither is cropped. It also means the row never reflows as images arrive,
  // because its height is known before anything loads.
  //
  // This component owns the entire section, heading and all, so that it can
  // render nothing at all when there are no photos. A marketing page with a
  // visibly empty gallery reads as broken, and the hub's index.md has no
  // script block to test the array from.
  import { fade } from 'svelte/transition';
  import { gallery } from './galleryItems.js';

  let track;
  let atStart = true;
  let atEnd = false;
  let open = -1;

  // A nudge is most of the visible width, so the eye keeps a photo of context.
  function slide(dir) {
    if (!track) return;
    track.scrollBy({ left: dir * track.clientWidth * 0.8, behavior: 'smooth' });
  }

  function onScroll() {
    if (!track) return;
    atStart = track.scrollLeft <= 2;
    atEnd = track.scrollLeft + track.clientWidth >= track.scrollWidth - 2;
  }

  const close = () => (open = -1);
  const prev = () => (open = (open - 1 + gallery.length) % gallery.length);
  const next = () => (open = (open + 1) % gallery.length);

  function onKey(e) {
    if (open < 0) return;
    if (e.key === 'Escape') close();
    if (e.key === 'ArrowLeft') prev();
    if (e.key === 'ArrowRight') next();
  }
</script>

<svelte:window on:keydown={onKey} />

{#if gallery.length}
  <div class="mb-14">
    <div class="text-center">
      <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">Gallery</div>
      <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-3" style="margin-top:0.25rem;">Moments from the build.</h2>
      <p class="text-gray-500 text-base max-w-2xl mx-auto leading-relaxed mb-9">Matchdays, desks, and the small wins worth a photo.</p>
    </div>

    <div class="relative">
      <!-- Scrolls natively: a swipe on a phone, a trackpad flick on a laptop,
           the arrows on anything else. -->
      <div
        bind:this={track}
        on:scroll={onScroll}
        class="track flex snap-x snap-mandatory gap-3 overflow-x-auto scroll-smooth pb-1 md:gap-4"
      >
        {#each gallery as photo, i}
          <button
            type="button"
            class="group relative h-56 shrink-0 snap-start overflow-hidden rounded-2xl border-0 p-0 focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-400 md:h-72"
            style="background:#f5f5f7;"
            on:click={() => (open = i)}
            aria-label="Enlarge: {photo.alt}"
          >
            <img
              src={photo.src}
              alt={photo.alt}
              loading="lazy"
              decoding="async"
              class="block h-full w-auto max-w-none transition-transform duration-300 group-hover:scale-[1.03]"
            />
            {#if photo.caption}
              <span class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent px-3 pb-2.5 pt-8 text-left text-[12px] leading-snug text-white opacity-0 transition-opacity duration-200 group-hover:opacity-100 md:text-[13px]">
                {photo.caption}
              </span>
            {/if}
          </button>
        {/each}
      </div>

      {#if gallery.length > 1}
        <button
          type="button"
          class="absolute left-0 top-1/2 z-10 hidden -translate-y-1/2 rounded-full bg-white/95 p-2.5 text-gray-700 shadow-md transition-opacity hover:text-gray-900 disabled:pointer-events-none disabled:opacity-0 md:block"
          aria-label="Previous photos" disabled={atStart} on:click={() => slide(-1)}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <button
          type="button"
          class="absolute right-0 top-1/2 z-10 hidden -translate-y-1/2 rounded-full bg-white/95 p-2.5 text-gray-700 shadow-md transition-opacity hover:text-gray-900 disabled:pointer-events-none disabled:opacity-0 md:block"
          aria-label="More photos" disabled={atEnd} on:click={() => slide(1)}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
        </button>
      {/if}
    </div>
  </div>

  {#if open >= 0}
    <!-- The backdrop is the close affordance; the image sits above it. -->
    <div class="fixed inset-0 z-[80] flex items-center justify-center bg-black/85 p-4" transition:fade={{ duration: 120 }}>
      <button type="button" class="absolute inset-0 cursor-default border-0 bg-transparent p-0" aria-label="Close" on:click={close}></button>

      <figure class="relative z-10 max-h-full max-w-4xl">
        <img src={gallery[open].src} alt={gallery[open].alt} class="max-h-[78vh] w-auto rounded-xl object-contain" />
        {#if gallery[open].caption}
          <figcaption class="mt-3 text-center text-sm text-white/80">{gallery[open].caption}</figcaption>
        {/if}
      </figure>

      <button type="button" class="absolute right-4 top-4 z-20 rounded-full bg-white/10 p-2 text-white transition-colors hover:bg-white/20" aria-label="Close" on:click={close}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M6 18 18 6M6 6l12 12"/></svg>
      </button>

      {#if gallery.length > 1}
        <button type="button" class="absolute left-2 z-20 rounded-full bg-white/10 p-2 text-white transition-colors hover:bg-white/20 md:left-6" aria-label="Previous photo" on:click={prev}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <button type="button" class="absolute right-2 z-20 rounded-full bg-white/10 p-2 text-white transition-colors hover:bg-white/20 md:right-6" aria-label="Next photo" on:click={next}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>
        </button>
      {/if}
    </div>
  {/if}
{/if}

<style>
  /* The strip scrolls; a scrollbar under a row of photos is only noise. */
  .track {
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  .track::-webkit-scrollbar {
    display: none;
  }
</style>
