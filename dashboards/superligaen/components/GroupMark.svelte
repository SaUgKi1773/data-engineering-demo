<script>
  // Group endorsement mark: quiet footer on every page linking back to the parent hub.
  // The home page renders its own merged mark + data-freshness line, so skip it there.
  import { page } from '$app/stores';
</script>

{#if $page.url.pathname !== '/'}
  <div class="mt-16 border-t border-gray-100 pt-6 pb-2 text-center">
    <a
      href="https://krogvadanalyticshub.vercel.app/"
      target="_blank"
      rel="noreferrer"
      class="text-xs text-gray-400 no-underline transition-colors hover:text-gray-600"
    >
      A <span class="font-semibold">Krogvad Analytics Hub</span> platform · Built in Farum, Denmark
    </a>
  </div>
{/if}
