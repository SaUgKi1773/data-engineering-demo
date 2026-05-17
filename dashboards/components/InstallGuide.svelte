<script>
  import { onMount } from 'svelte';

  let platform = 'other';

  onMount(() => {
    const ua = navigator.userAgent;
    if (/iphone|ipad|ipod/i.test(ua)) {
      platform = 'ios';
    } else if (/android/i.test(ua)) {
      platform = 'android';
    }
  });
</script>

<div class="rounded-xl border border-blue-100 bg-blue-50 p-5 mt-2">

  {#if platform === 'ios'}
    <p class="text-sm font-semibold text-blue-700 mb-3">📱 You're on iOS — follow these steps in Safari:</p>
    <ol class="text-sm text-gray-700 space-y-2 list-none pl-0">
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">1.</span> Open this page in <strong>Safari</strong> (not Chrome or Firefox)</li>
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">2.</span> Tap the <strong>Share</strong> button <span class="inline-block px-1.5 py-0.5 bg-gray-200 rounded text-xs font-mono">⎙</span> at the bottom of the screen</li>
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">3.</span> Scroll down and tap <strong>Add to Home Screen</strong></li>
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">4.</span> Tap <strong>Add</strong> — the app appears on your home screen</li>
    </ol>

  {:else if platform === 'android'}
    <p class="text-sm font-semibold text-blue-700 mb-3">📱 You're on Android — follow these steps in Chrome:</p>
    <ol class="text-sm text-gray-700 space-y-2 list-none pl-0">
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">1.</span> Open this page in <strong>Chrome</strong></li>
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">2.</span> Tap the <strong>⋮</strong> menu in the top-right corner</li>
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">3.</span> Tap <strong>Add to Home screen</strong></li>
      <li class="flex items-start gap-2"><span class="font-bold text-blue-600 shrink-0">4.</span> Tap <strong>Add</strong> — the app appears on your home screen</li>
    </ol>

  {:else}
    <p class="text-sm font-semibold text-blue-700 mb-3">📱 Open this page on your phone to install the app:</p>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm text-gray-700">
      <div>
        <p class="font-semibold mb-1">iOS (Safari)</p>
        <ol class="space-y-1 list-none pl-0">
          <li>1. Open in <strong>Safari</strong></li>
          <li>2. Tap <strong>Share ⎙</strong></li>
          <li>3. Tap <strong>Add to Home Screen</strong></li>
          <li>4. Tap <strong>Add</strong></li>
        </ol>
      </div>
      <div>
        <p class="font-semibold mb-1">Android (Chrome)</p>
        <ol class="space-y-1 list-none pl-0">
          <li>1. Open in <strong>Chrome</strong></li>
          <li>2. Tap <strong>⋮</strong> menu</li>
          <li>3. Tap <strong>Add to Home screen</strong></li>
          <li>4. Tap <strong>Add</strong></li>
        </ol>
      </div>
    </div>
  {/if}

</div>
