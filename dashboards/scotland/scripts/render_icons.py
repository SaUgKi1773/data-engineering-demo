"""Render the Premiership raster icons from the same geometry as static/icon.svg.

No SVG rasteriser is installed, so the mark is drawn directly with Pillow at
4x and downsampled. Coordinates are lifted verbatim from icon.svg's 512x512
viewBox so the PNGs and the SVG stay the same drawing.
"""
import os

from PIL import Image, ImageDraw

S = 4                        # supersample factor
N = 512 * S                  # working canvas
DARK = (11, 18, 32, 255)     # #0B1220
WHITE = (255, 255, 255, 255)

# linearGradient id="neon": x1 0% y1 100% -> x2 100% y2 0% (bottom-left to top-right)
# Saltire blue ramped to a lighter azure so the mark still reads on the dark tile.
STOPS = [(0.00, (0x00, 0x65, 0xBF)),
         (1.00, (0x3E, 0x9B, 0xE0))]


def gradient(n):
    """The neon gradient painted across an n x n square."""
    img = Image.new("RGBA", (n, n))
    px = img.load()
    for y in range(n):
        # projection onto the bottom-left -> top-right diagonal
        ky = 1.0 - y / (n - 1)
        for x in range(n):
            t = (x / (n - 1) + ky) / 2.0
            for i in range(len(STOPS) - 1):
                t0, c0 = STOPS[i]
                t1, c1 = STOPS[i + 1]
                if t <= t1 or i == len(STOPS) - 2:
                    f = 0.0 if t1 == t0 else max(0.0, min(1.0, (t - t0) / (t1 - t0)))
                    px[x, y] = (round(c0[0] + (c1[0] - c0[0]) * f),
                                round(c0[1] + (c1[1] - c0[1]) * f),
                                round(c0[2] + (c1[2] - c0[2]) * f), 255)
                    break
    return img


def mask(draw_fn):
    m = Image.new("L", (N, N), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def s(v):
    return v * S


GRAD = gradient(N)
canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))

# outer rounded square, gradient filled
canvas.paste(GRAD, (0, 0),
             mask(lambda d: d.rounded_rectangle([0, 0, N - 1, N - 1], radius=s(96), fill=255)))

# dark inner tile
d = ImageDraw.Draw(canvas)
d.rounded_rectangle([s(16), s(16), s(496) - 1, s(496) - 1], radius=s(84), fill=DARK)

# football: white disc, dark pentagons clipped to it, dark rim
ball = mask(lambda dr: dr.ellipse([s(146), s(120), s(366), s(340)], fill=255))
d.ellipse([s(146), s(120), s(366), s(340)], fill=WHITE)

PENTAGONS = [
    [(256, 145), (290, 170), (278, 208), (234, 208), (222, 170)],
    [(366, 185), (380, 220), (350, 244), (322, 228), (326, 192)],
    [(328, 295), (344, 330), (316, 352), (286, 336), (284, 300)],
    [(184, 295), (168, 330), (196, 352), (226, 336), (228, 300)],
    [(146, 185), (186, 192), (190, 228), (162, 244), (132, 220)],
]
patches = Image.new("RGBA", (N, N), (0, 0, 0, 0))
pd = ImageDraw.Draw(patches)
for poly in PENTAGONS:
    pd.polygon([(s(x), s(y)) for x, y in poly], fill=DARK)
canvas.paste(patches, (0, 0), Image.composite(patches.split()[3], Image.new("L", (N, N), 0), ball))

d.ellipse([s(146), s(120), s(366), s(340)], outline=DARK, width=s(6))

# analytics bars
BARS = [(148, 380, 30, 64), (196, 360, 30, 84), (244, 340, 30, 104),
        (292, 355, 30, 89), (340, 370, 30, 74)]


def draw_bars(dr):
    for x, y, w, h in BARS:
        dr.rounded_rectangle([s(x), s(y), s(x + w) - 1, s(y + h) - 1], radius=s(6), fill=255)


canvas.paste(GRAD, (0, 0), mask(draw_bars))

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "static") + "/"
for name, size in [("icon-512.png", 512), ("icon-192.png", 192), ("apple-touch-icon.png", 180)]:
    canvas.resize((size, size), Image.LANCZOS).save(out + name)
    print("wrote", name, size)

canvas.resize((48, 48), Image.LANCZOS).save(
    out + "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
print("wrote favicon.ico")
