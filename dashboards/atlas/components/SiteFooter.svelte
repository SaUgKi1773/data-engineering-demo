<script>
  export let lastUpdated = undefined;
</script>

<!-- Same footer as the Krogvad Analytics Hub home page. Two deliberate
     differences: mt-16, because league pages end in content rather than a
     spaced band; and the Hub name links out, since these sites are not the
     Hub. lastUpdated already arrives formatted ("29 Jul 2026 15:40 UTC"), so
     unlike the Hub there is nothing to slice here.

     The links sit in two tiers: the three things we want clicked, then the
     about-and-support set in a lighter weight. Seven links at one size read as
     a wall, especially on a phone where the row wraps to three lines. -->
<div class="mt-4 border-t border-gray-200 pt-8 pb-12 text-center">
  <div class="flex flex-wrap items-center justify-center gap-x-5 gap-y-2 mb-2.5">
    <a href="https://forms.gle/vPCoCNZvehu5yyze8" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Build with us</a>
    <a href="https://forms.gle/2wDZcfwm8jk6aWGS9" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Request Data Access</a>
    <a href="https://github.com/SaUgKi1773/data-engineering-demo/issues/new?template=suggestion.md" target="_blank" class="text-sm font-medium text-gray-500 hover:text-gray-900 no-underline">Share a Suggestion</a>
  </div>
  <div class="flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5 mb-4">
    <a href="https://github.com/SaUgKi1773/data-engineering-demo" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">GitHub</a>
    <a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">Blog</a>
    <a href="https://revolut.me/salihugurkimilli" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">Revolut</a>
    <a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="text-xs text-gray-400 hover:text-gray-600 no-underline">LinkedIn</a>
  </div>
  <p class="text-gray-500 text-sm mb-2">Built in beautiful Farum, Denmark — free for the whole world, forever.</p>
  <p class="text-gray-400 text-xs mb-0">© 2026 <a href="https://krogvadanalyticshub.vercel.app/" target="_blank" rel="noreferrer" class="text-gray-400 no-underline transition-colors hover:text-gray-600">Krogvad Analytics Hub</a> · Data updated {lastUpdated ?? '–'}</p>
</div>
