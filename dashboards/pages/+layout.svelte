<script>
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount } from 'svelte';
  import { inject } from '@vercel/analytics';

  export let data;

  onMount(() => inject());
</script>

<EvidenceDefaultLayout {data}>
  <slot slot="content" />
</EvidenceDefaultLayout>
