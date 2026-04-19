<script>
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount } from 'svelte';
  import { inject } from '@vercel/analytics';

  export let data;

  onMount(() => {
    inject();
    const script = document.createElement('script');
    script.defer = true;
    script.src = 'https://static.cloudflareinsights.com/beacon.min.js';
    script.dataset.cfBeacon = JSON.stringify({ token: '167db4d57c9742e1883b3e1ea858bccc' });
    document.head.appendChild(script);
  });
</script>

<EvidenceDefaultLayout {data} hideBreadcrumbs={true}>
  <slot slot="content" />
</EvidenceDefaultLayout>
