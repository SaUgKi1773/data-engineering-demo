<script>
  // Slowly spinning orthographic globe: the world as a gray dot matrix, with
  // the countries we cover filled in the accent colour and pinned with a label.
  //
  // Everything geographic is precomputed and committed (globe-data.js, built by
  // scripts/generate_globe_data.py) — no geo library ships to the browser and no
  // projection maths runs at build time. Per frame the cost is one multiply-add
  // chain per dot: each dot's position on the unit sphere is trigged once on
  // mount, and rotation after that is pure arithmetic.
  //
  // Canvas draws the sphere; the three labels are real DOM on top, so they get
  // the page's font and antialiasing instead of canvas text.
  import { onMount } from 'svelte';
  import { DOT_SCALE, RING_SCALE, dots as rawDots, countries as rawCountries } from './globe-data.js';

  /** Accent colour for covered countries, pins and labels. */
  export let accent = '#c8102e';
  /** Seconds per full revolution. Slow enough to read as calm, not as a loader. */
  export let secondsPerRevolution = 38;
  /** Seconds per revolution under `prefers-reduced-motion: reduce`. The globe
   *  keeps turning rather than freezing, but slowly enough to read as ambient
   *  drift instead of movement. */
  export let reducedSecondsPerRevolution = 120;
  /** Latitude at the centre of the globe. A northward tilt keeps all three
   *  covered countries in the upper half of the disc as they come round. */
  export let tiltDeg = 22;

  const RAD = Math.PI / 180;

  // Depth buckets: dots are drawn as one path per bucket rather than one path
  // per dot, which turns ~1,500 fills a frame into 8. Alpha and radius are
  // constant inside a bucket; 8 steps is fine enough that the fade towards the
  // limb reads as continuous.
  const DEPTH_BUCKETS = 8;

  // Drag feel. Half a degree per pixel means a flick crosses a continent and a
  // nudge nudges; the cap stops a fast swipe turning the globe into a blur.
  const DEG_PER_PIXEL = 0.5;
  // rotationDeg is the longitude sitting at the centre of the disc, and the
  // projection puts larger longitudes to the right. So moving the surface
  // rightward — following the pointer — means moving the centre longitude the
  // other way. Without this the globe fights your finger.
  const SCREEN_TO_SPIN = -1;
  const MAX_FLING_DEG_PER_SEC = 720;
  const FLING_DECAY_SECONDS = 0.55;

  let container;
  let canvas;
  let width = 0;
  let markers = [];
  let reduceMotion = false;

  // Per-dot unit-sphere components, precomputed on mount.
  let dotP, dotQ, dotR;
  // Per-country rings, in the same precomputed form.
  let countryGeom = [];

  function precompute() {
    const n = rawDots.length / 2;
    dotP = new Float32Array(n);
    dotQ = new Float32Array(n);
    dotR = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const lon = (rawDots[i * 2] / DOT_SCALE) * RAD;
      const lat = (rawDots[i * 2 + 1] / DOT_SCALE) * RAD;
      const cosLat = Math.cos(lat);
      dotP[i] = cosLat * Math.cos(lon);
      dotQ[i] = cosLat * Math.sin(lon);
      dotR[i] = Math.sin(lat);
    }

    countryGeom = rawCountries.map((c) => ({
      name: c.name,
      anchor: unit(c.anchor[0] / RING_SCALE, c.anchor[1] / RING_SCALE),
      rings: c.rings.map((ring) => {
        const m = ring.length / 2;
        const p = new Float32Array(m);
        const q = new Float32Array(m);
        const r = new Float32Array(m);
        for (let i = 0; i < m; i++) {
          const lon = (ring[i * 2] / RING_SCALE) * RAD;
          const lat = (ring[i * 2 + 1] / RING_SCALE) * RAD;
          const cosLat = Math.cos(lat);
          p[i] = cosLat * Math.cos(lon);
          q[i] = cosLat * Math.sin(lon);
          r[i] = Math.sin(lat);
        }
        return { p, q, r, length: m };
      })
    }));
  }

  function unit(lonDeg, latDeg) {
    const lon = lonDeg * RAD;
    const lat = latDeg * RAD;
    const cosLat = Math.cos(lat);
    return { p: cosLat * Math.cos(lon), q: cosLat * Math.sin(lon), r: Math.sin(lat) };
  }

  // Orthographic projection. `view.z > 0` means the point is on the near face.
  // Kept as a mutable out-param so the hot dot loop allocates nothing.
  function project(p, q, r, cosLon, sinLon, cosTilt, sinTilt, out) {
    const y = p * cosLon + q * sinLon;
    out.x = q * cosLon - p * sinLon;
    out.y = r * cosTilt - y * sinTilt;
    out.z = r * sinTilt + y * cosTilt;
  }

  onMount(() => {
    precompute();

    const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    reduceMotion = motionQuery.matches;
    const onMotionChange = (e) => (reduceMotion = e.matches);
    motionQuery.addEventListener('change', onMotionChange);

    const ctx = canvas.getContext('2d');
    const out = { x: 0, y: 0, z: 0 };

    // Start over the Atlantic so the very first frame already has Scotland and
    // Denmark on the near face rather than an empty Pacific.
    let rotationDeg = 8;
    let lastFrame = 0;
    let running = false;
    let frame = 0;

    // Drag state. `flingDegPerSec` is the leftover velocity from a flick; it
    // decays away and the idle rotation underneath takes back over.
    let dragging = false;
    let lastPointerX = 0;
    let lastPointerTime = 0;
    let flingDegPerSec = 0;

    const dpr = () => Math.min(window.devicePixelRatio || 1, 2);

    function resize() {
      const size = container.clientWidth;
      if (!size) return;
      width = size;
      const ratio = dpr();
      canvas.width = Math.round(size * ratio);
      canvas.height = Math.round(size * ratio);
      canvas.style.width = `${size}px`;
      canvas.style.height = `${size}px`;
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      draw();
    }

    function draw() {
      const size = width;
      if (!size) return;
      // Leave room around the disc for the pin halos and the drop shadow.
      const radius = size * 0.44;
      const cx = size / 2;
      const cy = size / 2;
      const lon = rotationDeg * RAD;
      const cosLon = Math.cos(lon);
      const sinLon = Math.sin(lon);
      const cosTilt = Math.cos(tiltDeg * RAD);
      const sinTilt = Math.sin(tiltDeg * RAD);

      ctx.clearRect(0, 0, size, size);

      // ── Sphere body ──────────────────────────────────────────────────────
      // Off-centre highlight towards the top-left reads as a light source and
      // stops the disc looking like a flat circle.
      const body = ctx.createRadialGradient(
        cx - radius * 0.35, cy - radius * 0.4, radius * 0.1,
        cx, cy, radius
      );
      body.addColorStop(0, '#ffffff');
      body.addColorStop(0.55, '#f7f7f9');
      body.addColorStop(1, '#e9e9ee');
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.fillStyle = body;
      ctx.fill();

      // ── Land dots ────────────────────────────────────────────────────────
      // One pass, bucketed by depth: collect into per-bucket paths, then fill.
      const paths = [];
      for (let b = 0; b < DEPTH_BUCKETS; b++) paths.push(new Path2D());

      const baseDotRadius = Math.max(radius * 0.0092, 0.6);
      for (let i = 0; i < dotP.length; i++) {
        project(dotP[i], dotQ[i], dotR[i], cosLon, sinLon, cosTilt, sinTilt, out);
        if (out.z <= 0.02) continue;
        const bucket = Math.min(DEPTH_BUCKETS - 1, (out.z * DEPTH_BUCKETS) | 0);
        const r = baseDotRadius * (0.62 + 0.38 * out.z);
        const px = cx + radius * out.x;
        const py = cy - radius * out.y;
        paths[bucket].moveTo(px + r, py);
        paths[bucket].arc(px, py, r, 0, Math.PI * 2);
      }
      for (let b = 0; b < DEPTH_BUCKETS; b++) {
        const depth = (b + 0.5) / DEPTH_BUCKETS;
        ctx.fillStyle = `rgba(60, 60, 67, ${(0.1 + 0.24 * depth).toFixed(3)})`;
        ctx.fill(paths[b]);
      }

      // ── Covered countries ────────────────────────────────────────────────
      const nextMarkers = [];
      for (const country of countryGeom) {
        for (const ring of country.rings) {
          const path = new Path2D();
          let visible = true;
          for (let i = 0; i < ring.length; i++) {
            project(ring.p[i], ring.q[i], ring.r[i], cosLon, sinLon, cosTilt, sinTilt, out);
            // A ring straddling the limb would fold back on itself when
            // projected. These countries are small enough relative to a
            // hemisphere that dropping the whole ring is invisible — it happens
            // only while the country is edge-on and already faded out.
            if (out.z <= 0.02) {
              visible = false;
              break;
            }
            const px = cx + radius * out.x;
            const py = cy - radius * out.y;
            if (i === 0) path.moveTo(px, py);
            else path.lineTo(px, py);
          }
          if (!visible) continue;
          path.closePath();
          ctx.fillStyle = accent;
          ctx.fill(path);
          // A hairline stroke keeps Denmark's islands from vanishing at small
          // sizes, where each one covers barely a pixel.
          ctx.strokeStyle = accent;
          ctx.lineWidth = 1.1;
          ctx.lineJoin = 'round';
          ctx.stroke(path);
        }

        // Pin + label anchor. Fades out as the country turns towards the limb.
        const a = country.anchor;
        project(a.p, a.q, a.r, cosLon, sinLon, cosTilt, sinTilt, out);
        if (out.z > 0.18) {
          const px = cx + radius * out.x;
          const py = cy - radius * out.y;
          const opacity = Math.min(1, (out.z - 0.18) / 0.22);

          ctx.beginPath();
          ctx.arc(px, py, radius * 0.032, 0, Math.PI * 2);
          ctx.fillStyle = hexToRgba(accent, 0.14 * opacity);
          ctx.fill();

          ctx.beginPath();
          ctx.arc(px, py, radius * 0.014, 0, Math.PI * 2);
          ctx.fillStyle = hexToRgba(accent, opacity);
          ctx.fill();
          ctx.strokeStyle = `rgba(255, 255, 255, ${opacity})`;
          ctx.lineWidth = 1.5;
          ctx.stroke();

          nextMarkers.push({
            name: country.name,
            // Percentages so the labels track the canvas at any width.
            left: (px / size) * 100,
            top: (py / size) * 100,
            px,
            py,
            dy: 0,
            opacity
          });
        }
      }
      markers = declutter(nextMarkers);

      // ── Limb ─────────────────────────────────────────────────────────────
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, Math.PI * 2);
      ctx.strokeStyle = 'rgba(60, 60, 67, 0.12)';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    function tick(now) {
      if (!running) return;
      const elapsed = lastFrame ? now - lastFrame : 0;
      lastFrame = now;
      const dt = elapsed / 1000;

      if (dragging) {
        // The pointer owns the rotation outright while it is down.
      } else {
        const period = reduceMotion ? reducedSecondsPerRevolution : secondsPerRevolution;
        // Negative because rotationDeg is the longitude at the centre of the
        // disc: for the surface to drift east — rightward, the way a real Earth
        // turns — the centre longitude has to move west. See SCREEN_TO_SPIN.
        const idleDegPerSec = -360 / period;
        // Idle spin plus whatever is left of a flick. Because the fling decays
        // towards zero rather than towards the idle rate, a throw always eases
        // back into the normal rotation instead of stopping dead.
        rotationDeg += dt * (idleDegPerSec + flingDegPerSec);
        flingDegPerSec *= Math.exp(-dt / FLING_DECAY_SECONDS);
        if (Math.abs(flingDegPerSec) < 1) flingDegPerSec = 0;
      }
      draw();
      frame = requestAnimationFrame(tick);
    }

    function start() {
      // Reduced motion slows the spin right down rather than stopping it (see
      // reducedSecondsPerRevolution) — a frozen globe reads as a broken one.
      if (running || document.hidden) return;
      running = true;
      lastFrame = 0;
      frame = requestAnimationFrame(tick);
    }

    function stop() {
      running = false;
      cancelAnimationFrame(frame);
    }

    // Only spin while the hero is actually on screen.
    const io = new IntersectionObserver(
      (entries) => (entries.some((e) => e.isIntersecting) ? start() : stop()),
      { threshold: 0 }
    );
    io.observe(container);

    const onVisibility = () => (document.hidden ? stop() : start());
    document.addEventListener('visibilitychange', onVisibility);

    const ro = new ResizeObserver(resize);
    ro.observe(container);
    resize();

    // ── Drag to spin ───────────────────────────────────────────────────────
    // Rotation is only ever mutated here; the animation loop reads it next
    // frame, so a drag never has to force its own redraw.
    function onPointerDown(e) {
      dragging = true;
      flingDegPerSec = 0;
      lastPointerX = e.clientX;
      lastPointerTime = e.timeStamp;
      canvas.setPointerCapture(e.pointerId);
    }

    function onPointerMove(e) {
      if (!dragging) return;
      const dx = e.clientX - lastPointerX;
      const dt = (e.timeStamp - lastPointerTime) / 1000;
      const deltaDeg = dx * DEG_PER_PIXEL * SCREEN_TO_SPIN;
      rotationDeg += deltaDeg;
      // Keep the instantaneous velocity for the release. Sub-millisecond gaps
      // between events would divide by ~0 and produce a nonsense fling.
      if (dt > 0.004) {
        const velocity = deltaDeg / dt;
        flingDegPerSec = Math.max(-MAX_FLING_DEG_PER_SEC, Math.min(MAX_FLING_DEG_PER_SEC, velocity));
      }
      lastPointerX = e.clientX;
      lastPointerTime = e.timeStamp;
    }

    function onPointerUp(e) {
      if (!dragging) return;
      dragging = false;
      // A drag that ended in a pause should stop, not coast: the last recorded
      // velocity is stale by then.
      if (e.timeStamp - lastPointerTime > 90) flingDegPerSec = 0;
      if (canvas.hasPointerCapture(e.pointerId)) canvas.releasePointerCapture(e.pointerId);
    }

    canvas.addEventListener('pointerdown', onPointerDown);
    canvas.addEventListener('pointermove', onPointerMove);
    canvas.addEventListener('pointerup', onPointerUp);
    canvas.addEventListener('pointercancel', onPointerUp);

    return () => {
      stop();
      io.disconnect();
      ro.disconnect();
      motionQuery.removeEventListener('change', onMotionChange);
      document.removeEventListener('visibilitychange', onVisibility);
      canvas.removeEventListener('pointerdown', onPointerDown);
      canvas.removeEventListener('pointermove', onPointerMove);
      canvas.removeEventListener('pointerup', onPointerUp);
      canvas.removeEventListener('pointercancel', onPointerUp);
    };
  });

  // Denmark and Scotland sit ten degrees apart, so their labels land on top of
  // each other whenever both are on the near face. Stack them instead: work
  // down the screen and lift each label clear of the ones already placed.
  const LABEL_HEIGHT = 21;
  const LABEL_GAP = 4;

  function labelHalfWidth(name) {
    // Cheap proxy for the rendered pill: ~5.9px per character at 11px semibold,
    // plus the horizontal padding. Only used to decide whether two labels
    // overlap, so an approximation is enough.
    return (name.length * 5.9 + 18) / 2;
  }

  function declutter(list) {
    const sorted = [...list].sort((a, b) => a.py - b.py);
    const placed = [];
    for (const marker of sorted) {
      const halfWidth = labelHalfWidth(marker.name);
      for (const other of placed) {
        const overlapsX = Math.abs(marker.px - other.px) < halfWidth + labelHalfWidth(other.name);
        const dy = marker.py + marker.dy - (other.py + other.dy);
        if (overlapsX && Math.abs(dy) < LABEL_HEIGHT + LABEL_GAP) {
          marker.dy = other.py + other.dy - marker.py - (LABEL_HEIGHT + LABEL_GAP);
        }
      }
      placed.push(marker);
    }
    return sorted;
  }

  function hexToRgba(hex, alpha) {
    const value = hex.replace('#', '');
    const r = parseInt(value.slice(0, 2), 16);
    const g = parseInt(value.slice(2, 4), 16);
    const b = parseInt(value.slice(4, 6), 16);
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  const countryNames = rawCountries.map((c) => c.name);
</script>

<div class="globe" bind:this={container}>
  <canvas
    bind:this={canvas}
    role="img"
    aria-label="A slowly rotating globe with the countries we cover highlighted: {countryNames.join(', ')}."
  ></canvas>

  {#each markers as marker (marker.name)}
    <span
      class="label"
      style="left: {marker.left}%; top: {marker.top}%; opacity: {marker.opacity}; transform: translate(-50%, calc(-100% - 0.85rem + {marker.dy}px));"
      aria-hidden="true"
    >{marker.name}</span>
  {/each}
</div>

<style>
  .globe {
    position: relative;
    width: 100%;
    aspect-ratio: 1 / 1;
    /* Nothing to see before the canvas mounts, and no layout shift when it
       does — the box is already square and sized by its container. */
  }

  canvas {
    display: block;
    width: 100%;
    height: 100%;
    cursor: grab;
    /* The disc only fills the inscribed circle, so round off the hit area too —
       otherwise the empty corners of the canvas grab drags aimed at the page. */
    border-radius: 50%;
    /* Horizontal drags spin the globe, vertical ones still scroll the page —
       otherwise the hero becomes a trap you can't swipe past on a phone. */
    touch-action: pan-y;
    /* The disc is a lit sphere; a soft ground shadow finishes the illusion. */
    filter: drop-shadow(0 18px 34px rgba(0, 0, 0, 0.09));
  }

  canvas:active {
    cursor: grabbing;
  }

  .label {
    position: absolute;
    /* Sits just above its pin, centred on it. */
    transform: translate(-50%, calc(-100% - 0.85rem));
    white-space: nowrap;
    pointer-events: none;
    padding: 0.2rem 0.55rem;
    border-radius: 9999px;
    background: rgba(255, 255, 255, 0.92);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12);
    color: #1d1d1f;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.01em;
    line-height: 1.4;
  }
</style>
