<script>
  export let lastUpdated = undefined;
</script>

<div class="mt-16 border-t border-gray-100 pt-6 pb-2 text-center">
  <a href="https://krogvadanalyticshub.vercel.app/" target="_blank" rel="noreferrer" class="text-xs text-gray-400 no-underline transition-colors hover:text-gray-600">A <span class="font-semibold">Krogvad Analytics Hub</span> platform · Built in Farum, Denmark</a>
  <div class="mt-1.5 text-[11px] text-gray-400">Data last updated: {lastUpdated ?? '–'}</div>
</div>
