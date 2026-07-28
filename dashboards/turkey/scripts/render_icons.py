"""Render the Süper Lig raster icons from the same geometry as static/icon.svg.

No SVG rasteriser is installed, so the mark is drawn directly with Pillow at
4x and downsampled. Coordinates are lifted verbatim from icon.svg's 512x512
viewBox so the PNGs and the SVG stay the same drawing.

The mark is the Turkish flag: a flag-red field carrying a white football and
white bars, edged in a deeper red so the tile still reads against a white page.
The pentagon patches and the ball rim are painted in the field colour - they
are cut-outs in the ball, not marks on it.
"""
import os

from PIL import Image, ImageDraw

S = 4                        # supersample factor
N = 512 * S                  # working canvas
RED = (227, 10, 23, 255)     # #E30A17 flag red, the field
DEEP = (162, 6, 15, 255)     # #A2060F deeper red, the outer edge
WHITE = (255, 255, 255, 255)


def s(v):
    return v * S


canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(canvas)

# outer rounded square in deep red, then the flag-red field inside it
d.rounded_rectangle([0, 0, N - 1, N - 1], radius=s(96), fill=DEEP)
d.rounded_rectangle([s(16), s(16), s(496) - 1, s(496) - 1], radius=s(84), fill=RED)

# football: white disc, field-coloured pentagons clipped to it, field-coloured rim
d.ellipse([s(146), s(120), s(366), s(340)], fill=WHITE)

PENTAGONS = [
    [(256, 145), (290, 170), (278, 208), (234, 208), (222, 170)],
    [(366, 185), (380, 220), (350, 244), (322, 228), (326, 192)],
    [(328, 295), (344, 330), (316, 352), (286, 336), (284, 300)],
    [(184, 295), (168, 330), (196, 352), (226, 336), (228, 300)],
    [(146, 185), (186, 192), (190, 228), (162, 244), (132, 220)],
]
ball = Image.new("L", (N, N), 0)
ImageDraw.Draw(ball).ellipse([s(146), s(120), s(366), s(340)], fill=255)
patches = Image.new("RGBA", (N, N), (0, 0, 0, 0))
pd = ImageDraw.Draw(patches)
for poly in PENTAGONS:
    pd.polygon([(s(x), s(y)) for x, y in poly], fill=RED)
canvas.paste(patches, (0, 0), Image.composite(patches.split()[3], Image.new("L", (N, N), 0), ball))

d.ellipse([s(146), s(120), s(366), s(340)], outline=RED, width=s(6))

# analytics bars
BARS = [(148, 380, 30, 64), (196, 360, 30, 84), (244, 340, 30, 104),
        (292, 355, 30, 89), (340, 370, 30, 74)]
for x, y, w, h in BARS:
    d.rounded_rectangle([s(x), s(y), s(x + w) - 1, s(y + h) - 1], radius=s(6), fill=WHITE)

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "static") + "/"
for name, size in [("icon-512.png", 512), ("icon-192.png", 192), ("apple-touch-icon.png", 180)]:
    canvas.resize((size, size), Image.LANCZOS).save(out + name)
    print("wrote", name, size)

canvas.resize((48, 48), Image.LANCZOS).save(
    out + "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
print("wrote favicon.ico")
