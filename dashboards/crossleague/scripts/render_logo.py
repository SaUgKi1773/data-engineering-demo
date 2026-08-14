"""Render every crossleague logo asset from one geometry definition.

The other sites keep the mark in static/*.svg and redraw it a second time in
render_icons.py, which means a change has to be made twice and the two can
drift. Here the geometry lives once, in this file, and both the SVG and the
PNGs are emitted from it. Edit the constants below, run the script, commit
what it writes.

    python3 scripts/render_logo.py

The mark is the Krogvad Analytics Hub badge — near-black disc, white football,
five red analytics bars — with an arc of five red stars over the ball, one per
league. The stars take the bars' own reds, palest at the ends and strongest in
the middle, so the two rows read as the same family rather than two ideas.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static")

# ── palette ─────────────────────────────────────────────────────────────────
INK = (0x1D, 0x1D, 0x1F)          # near-black badge, straight from the Hub
WHITE = (0xFF, 0xFF, 0xFF)
REDS = [(0xFF, 0x5A, 0x6A), (0xFF, 0x46, 0x57), (0xF5, 0x23, 0x3A),
        (0xFF, 0x46, 0x57), (0xFF, 0x5A, 0x6A)]

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

# Five stars on an arc over the ball — struck from the ball's own centre, so
# the arc stays concentric with it however the ball moves.
STAR_ARC_R = 148.0
STAR_A0, STAR_A1 = -160.0, -20.0
STAR_R = 24.0


def star_centres():
    n = len(REDS)
    return [(BALL[0] + STAR_ARC_R * math.cos(math.radians(a)),
             BALL[1] + STAR_ARC_R * math.sin(math.radians(a)))
            for a in (STAR_A0 + (STAR_A1 - STAR_A0) * i / (n - 1) for i in range(n))]


def star_points(cx, cy, r):
    """Five-pointed star, one point up."""
    return [(cx + (r if k % 2 == 0 else r * 0.382) * math.cos(math.radians(-90 + k * 36)),
             cy + (r if k % 2 == 0 else r * 0.382) * math.sin(math.radians(-90 + k * 36)))
            for k in range(10)]


def hexof(c):
    return "#%02X%02X%02X" % tuple(c[:3])


# ── SVG ─────────────────────────────────────────────────────────────────────
def mark_body(indent="  "):
    """Everything inside the badge: stars, ball, bars."""
    bx, by, br = BALL
    L = []
    for (cx, cy), col in zip(star_centres(), REDS):
        pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in star_points(cx, cy, STAR_R))
        L.append(f'{indent}<polygon points="{pts}" fill="{hexof(col)}"/>')
    L.append(f'{indent}<circle cx="{bx:.0f}" cy="{by:.0f}" r="{br:.0f}" fill="{hexof(WHITE)}"/>')
    L.append(f'{indent}<g clip-path="url(#ball)">')
    for p in PATCHES:
        pts = " ".join(f"{x},{y}" for x, y in p)
        L.append(f'{indent}  <polygon points="{pts}" fill="{hexof(INK)}"/>')
    L.append(f'{indent}</g>')
    L.append(f'{indent}<circle cx="{bx:.0f}" cy="{by:.0f}" r="{br:.0f}" fill="none" '
             f'stroke="{hexof(INK)}" stroke-width="6"/>')
    for (x, y, w, h), col in zip(BARS, REDS):
        L.append(f'{indent}<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" '
                 f'fill="{hexof(col)}"/>')
    return L


DEFS = ['  <defs>',
        f'    <clipPath id="ball"><circle cx="{BALL[0]:.0f}" cy="{BALL[1]:.0f}" r="{BALL[2]:.0f}"/></clipPath>',
        '  </defs>']


def build_svg(shell, indent="  "):
    return "\n".join(['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">']
                     + DEFS + shell + mark_body(indent) + ['</svg>', ''])


CIRCLE_SHELL = [f'  <circle cx="256" cy="256" r="256" fill="{hexof(INK)}"/>']
TILE_SHELL = [f'  <rect width="512" height="512" rx="96" fill="{hexof(INK)}"/>']


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

    for (cx, cy), col in zip(star_centres(), REDS):
        d.polygon([(sc(x), sc(y)) for x, y in star_points(cx, cy, STAR_R)], fill=col + (255,))

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
    for (x, y, w, h), col in zip(BARS, REDS):
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
