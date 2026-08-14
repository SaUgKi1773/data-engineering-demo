"""Render every crossleague logo asset from one geometry definition.

The other sites keep the mark in static/*.svg and redraw it a second time in
render_icons.py, which means a change has to be made twice and the two can
drift. Here the geometry lives once, in this file, and both the SVG and the
PNGs are emitted from it. Edit the constants below, run the script, commit
what it writes.

    python3 scripts/render_logo.py

The mark is the Krogvad Analytics Hub badge — near-black disc, white football,
five analytics bars — with the bars carrying the five league hues instead of
the Hub's reds. Nothing is added: the Hub already draws exactly five bars, so
colour alone does the differentiating, in the same palette every chart on the
site uses. An earlier attempt hung a third row on the badge, an arc of stars.
Two problems killed it — stars over a crest already mean titles won, and a
two-row mark stops reading at favicon size once it becomes three.
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static")

# ── palette ─────────────────────────────────────────────────────────────────
INK = (0x1D, 0x1D, 0x1F)          # near-black badge, straight from the Hub
WHITE = (0xFF, 0xFF, 0xFF)

# One bar per league, left to right in launch order — the same order and the
# same hues as `leagues` in components/navItems.js. Keep the two in step.
BAR_HUES = [(0xED, 0xA1, 0x00),   # DEN  Superliga
            (0x1B, 0xAF, 0x7A),   # SCO  Premiership
            (0xEB, 0x68, 0x34),   # MEX  Liga MX
            (0xE8, 0x7B, 0xA4),   # TUR  Süper Lig
            (0x2A, 0x78, 0xD6)]   # ESP  La Liga

# ── geometry, in the 512x512 viewBox every asset shares ─────────────────────
# Ball, patches and bars are lifted verbatim from the Hub's icon.svg.
BALL = (256.0, 230.0, 110.0)
PATCHES = [[(256, 145), (290, 170), (278, 208), (234, 208), (222, 170)],
           [(366, 185), (380, 220), (350, 244), (322, 228), (326, 192)],
           [(328, 295), (344, 330), (316, 352), (286, 336), (284, 300)],
           [(184, 295), (168, 330), (196, 352), (226, 336), (228, 300)],
           [(146, 185), (186, 192), (190, 228), (162, 244), (132, 220)]]
BARS = [(148, 380, 30, 64), (196, 360, 30, 84), (244, 340, 30, 104),
        (292, 355, 30, 89), (340, 370, 30, 74)]


def hexof(c):
    return "#%02X%02X%02X" % tuple(c[:3])


# ── SVG ─────────────────────────────────────────────────────────────────────
def mark_body(indent="  "):
    """Everything inside the badge: ball, then bars."""
    bx, by, br = BALL
    L = [f'{indent}<circle cx="{bx:.0f}" cy="{by:.0f}" r="{br:.0f}" fill="{hexof(WHITE)}"/>',
         f'{indent}<g clip-path="url(#ball)">']
    for p in PATCHES:
        pts = " ".join(f"{x},{y}" for x, y in p)
        L.append(f'{indent}  <polygon points="{pts}" fill="{hexof(INK)}"/>')
    L.append(f'{indent}</g>')
    L.append(f'{indent}<circle cx="{bx:.0f}" cy="{by:.0f}" r="{br:.0f}" fill="none" '
             f'stroke="{hexof(INK)}" stroke-width="6"/>')
    for (x, y, w, h), col in zip(BARS, BAR_HUES):
        L.append(f'{indent}<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" '
                 f'fill="{hexof(col)}"/>')
    return L


DEFS = ['  <defs>',
        f'    <clipPath id="ball"><circle cx="{BALL[0]:.0f}" cy="{BALL[1]:.0f}" '
        f'r="{BALL[2]:.0f}"/></clipPath>',
        '  </defs>']

CIRCLE_SHELL = [f'  <circle cx="256" cy="256" r="256" fill="{hexof(INK)}"/>']
TILE_SHELL = [f'  <rect width="512" height="512" rx="96" fill="{hexof(INK)}"/>']


def build_svg(shell, indent="  "):
    return "\n".join(['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">']
                     + DEFS + shell + mark_body(indent) + ['</svg>', ''])


def write_svgs():
    open(os.path.join(OUT, "logo-circle.svg"), "w").write(build_svg(CIRCLE_SHELL))
    open(os.path.join(OUT, "icon.svg"), "w").write(build_svg(TILE_SHELL))

    # Header lockup: the circular mark at 40px plus the wordmark. Ink is dark;
    # this sits on Evidence's white header.
    font = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
    inner = "\n".join(CIRCLE_SHELL + mark_body("    "))
    head = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 230 40">\n'
            + "\n".join(DEFS) + "\n"
            '  <svg x="0" y="0" width="40" height="40" viewBox="0 0 512 512">\n'
            + inner + "\n  </svg>\n"
            f'  <text x="50" y="18" font-family="{font}" font-weight="600" '
            f'font-size="14" fill="{hexof(INK)}" letter-spacing="-0.4">Krogvad</text>\n'
            f'  <text x="51" y="30" font-family="{font}" font-weight="500" '
            'font-size="7.5" fill="#6e6e73" letter-spacing="1.8">CROSS-LEAGUE ANALYTICS</text>\n'
            '</svg>\n')
    open(os.path.join(OUT, "header-logo.svg"), "w").write(head)


# ── raster ──────────────────────────────────────────────────────────────────
def draw_mark(n, tile=False):
    """The same drawing as the SVG, at n x n. Supersample via a large n."""
    s = n / 512.0
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def sc(v):
        return v * s

    if tile:
        d.rounded_rectangle([0, 0, n - 1, n - 1], radius=sc(96), fill=INK + (255,))
    else:
        d.ellipse([0, 0, n - 1, n - 1], fill=INK + (255,))

    bx, by, br = BALL
    box = [sc(bx - br), sc(by - br), sc(bx + br), sc(by + br)]
    d.ellipse(box, fill=WHITE + (255,))

    # Patches are clipped to the ball, exactly as clipPath#ball does in the SVG.
    ball_m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(ball_m).ellipse(box, fill=255)
    patch = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    pd = ImageDraw.Draw(patch)
    for p in PATCHES:
        pd.polygon([(sc(x), sc(y)) for x, y in p], fill=INK + (255,))
    img.paste(patch, (0, 0), Image.composite(patch.split()[3], Image.new("L", (n, n), 0), ball_m))

    d = ImageDraw.Draw(img)
    d.ellipse(box, outline=INK + (255,), width=max(1, int(round(6 * s))))
    for (x, y, w, h), col in zip(BARS, BAR_HUES):
        d.rounded_rectangle([sc(x), sc(y), sc(x + w), sc(y + h)], radius=sc(6), fill=col + (255,))
    return img


def write_pngs():
    S = 4
    circ = draw_mark(512 * S, tile=False)
    tile = draw_mark(512 * S, tile=True)
    tile.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon-512.png"))
    tile.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "icon-192.png"))
    tile.resize((180, 180), Image.LANCZOS).save(os.path.join(OUT, "apple-touch-icon.png"))
    circ.resize((64, 64), Image.LANCZOS).save(
        os.path.join(OUT, "favicon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])


if __name__ == "__main__":
    write_svgs()
    write_pngs()
    for f in ("logo-circle.svg", "icon.svg", "header-logo.svg", "icon-512.png",
              "icon-192.png", "apple-touch-icon.png", "favicon.ico"):
        p = os.path.join(OUT, f)
        print(f"  {f:24} {os.path.getsize(p):>8,} bytes")
