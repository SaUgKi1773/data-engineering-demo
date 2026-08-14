<script>
  // Photo grid with a click-to-enlarge lightbox.
  //
  // This component owns the entire section, heading and all, so that it can
  // render nothing at all when there are no photos. A marketing page with a
  // visibly empty gallery reads as broken, which is the opposite of what the
  // section is for, and the hub's index.md has no script block to test the
  // array from.
  //
  // The grid is a CSS-columns masonry rather than a fixed aspect box. The
  // photos arrive in every shape — 3:4 from a camera, roughly 1:2 from a phone
  // screenshot — and cropping them all to one ratio took the sky off a stadium
  // shot and the top off a screenshot. Columns keep each photo's own
  // proportions and cost nothing to render.
  //
  // Photos are ordinary <img> with loading="lazy": this sits at the foot of a
  // long page, so nothing here should compete with the hero for bandwidth.
  import { fade } from 'svelte/transition';
  import { gallery } from './galleryItems.js';

  let open = -1;

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
  <div class="mb-14 text-center">
    <div class="text-gray-400 text-xs font-semibold uppercase mb-1" style="letter-spacing: 0.14em;">Gallery</div>
    <h2 class="text-2xl md:text-3xl font-bold tracking-tight text-gray-900 mb-3" style="margin-top:0.25rem;">Moments from the build.</h2>
    <p class="text-gray-500 text-base max-w-2xl mx-auto leading-relaxed mb-9">Matchdays, desks, and the small wins worth a photo.</p>

    <div class="columns-2 gap-3 md:columns-3 md:gap-4">
      {#each gallery as photo, i}
        <button
          type="button"
          class="group relative mb-3 block w-full break-inside-avoid overflow-hidden rounded-2xl border-0 p-0 focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-400 md:mb-4"
        style="background:#f5f5f7;"
        on:click={() => (open = i)}
        aria-label="Enlarge: {photo.alt}"
      >
        <img
          src={photo.src}
          alt={photo.alt}
          loading="lazy"
          decoding="async"
          class="block h-auto w-full transition-transform duration-300 group-hover:scale-[1.03]"
        />
        {#if photo.caption}
          <span class="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/65 to-transparent px-3 pb-2.5 pt-8 text-left text-[12px] leading-snug text-white opacity-0 transition-opacity duration-200 group-hover:opacity-100 md:text-[13px]">
            {photo.caption}
          </span>
        {/if}
        </button>
      {/each}
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
