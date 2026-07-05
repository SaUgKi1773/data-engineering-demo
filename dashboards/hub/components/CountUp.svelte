<script>
  // Animated stat value: counts from 0 to `value` with ease-out when the
  // element scrolls into view. SSR renders the final value so the static
  // HTML (and no-JS visitors) always show the real number.
  // Deliberately does NOT gate on prefers-reduced-motion: a number ticker
  // involves no spatial movement, and the site owner chose always-on.
  import { onMount } from 'svelte';

  export let value = 0;
  export let duration = 1400;

  let el;
  let display = Number(value) || 0;
  let visible = false;
  let animated = false;

  function animate(target) {
    animated = true;
    const t0 = performance.now();
    function tick(now) {
      const p = Math.min((now - t0) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      display = Math.round(target * eased);
      if (p < 1) requestAnimationFrame(tick);
      else display = target;
    }
    requestAnimationFrame(tick);
  }

  // Fire once the element is visible AND the (possibly async) value is real
  $: if (visible && !animated && Number(value) > 0) animate(Number(value));

  onMount(() => {
    display = 0;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          visible = true;
          io.disconnect();
        }
      },
      { threshold: 0.4 }
    );
    io.observe(el);
    return () => io.disconnect();
  });
</script>

<span bind:this={el}>{display.toLocaleString('en-US')}</span>
