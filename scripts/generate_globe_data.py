"""Build the hub's spinning-globe geometry as a committed JS module.

Run by hand — the output only changes when the covered-league roster changes,
so it is generated once and committed rather than fetched at build or run time.
The browser gets a plain ES module import: no network call, no geo library, no
runtime projection maths beyond a dot product per dot.

Two layers come out of it:

  * ``dots``      an evenly spaced dot matrix over every landmass on Earth,
                  drawn in light gray. Spacing is constant *on the sphere*, so
                  the longitude step widens towards the poles.
  * ``countries`` real polygon outlines for the countries we cover, drawn
                  filled in the accent colour on top of the dots, plus the
                  label anchor for each one's pin.

Usage:
    python scripts/generate_globe_data.py

Writes: dashboards/hub/components/globe-data.js
"""

from __future__ import annotations

import json
import math
import urllib.request
from pathlib import Path

NE_BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"

# 110m is plenty for the gray dot matrix — it only has to answer "is this point
# on land?" at 2-degree resolution. The covered countries are drawn as real
# outlines, so they come from 50m, and from *map units* rather than countries so
# that Scotland exists as its own shape instead of being folded into the UK.
WORLD_URL = f"{NE_BASE}/ne_110m_admin_0_countries.geojson"
UNITS_URL = f"{NE_BASE}/ne_50m_admin_0_map_units.geojson"

# Dot spacing on the sphere, in degrees of great-circle arc. 2.0 lands at
# roughly 3,000 land dots — dense enough to read as continents at 340px, light
# enough that a frame is a few thousand canvas ops.
DOT_SPACING_DEG = 2.0

# Douglas-Peucker tolerance for the covered-country outlines, in degrees.
# At globe scale a degree is a couple of pixels, so this throws away detail
# nobody can see while keeping each country's silhouette recognisable.
SIMPLIFY_TOLERANCE_DEG = 0.06

# Rings smaller than this (in square degrees) are dropped: offshore islets that
# render as sub-pixel specks but cost as much to store as a mainland.
MIN_RING_AREA_SQ_DEG = 0.03

# name in ne_50m_admin_0_map_units -> (label, label anchor lon/lat)
# The anchor is set by hand rather than taken from the polygon centroid: a
# centroid puts Denmark's pin in the Kattegat and Scotland's in a firth.
COVERED = {
    "Denmark": {"label": "Denmark", "anchor": (9.5, 56.0)},
    "Scotland": {"label": "Scotland", "anchor": (-4.2, 56.8)},
    "Mexico": {"label": "Mexico", "anchor": (-102.0, 23.5)},
    "Turkey": {"label": "Turkey", "anchor": (35.0, 39.0)},
    "Spain": {"label": "Spain", "anchor": (-3.7, 40.2)},
}

OUT_PATH = Path(__file__).resolve().parents[1] / "dashboards/hub/components/globe-data.js"


def fetch(url: str) -> dict:
    print(f"  fetching {url.rsplit('/', 1)[-1]} ...")
    with urllib.request.urlopen(url) as resp:
        return json.load(resp)


def rings_of(geometry: dict) -> list[list[list[float]]]:
    """Flatten a (Multi)Polygon to its exterior rings as [lon, lat] lists.

    Interior rings (holes) are dropped: at this scale the only holes on Earth
    are Lesotho and the Vatican, neither of which we cover or can see.
    """
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"][0]]
    if geometry["type"] == "MultiPolygon":
        return [poly[0] for poly in geometry["coordinates"]]
    return []


def bbox(ring: list[list[float]]) -> tuple[float, float, float, float]:
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return min(lons), min(lats), max(lons), max(lats)


def point_in_ring(lon: float, lat: float, ring: list[list[float]]) -> bool:
    """Standard ray-casting crossing count."""
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > lat) != (yj > lat):
            if lon < (xj - xi) * (lat - yi) / (yj - yi) + xi:
                inside = not inside
        j = i
    return inside


def build_dots(world: dict) -> list[int]:
    """Sample land on an equal-arc-spacing grid, quantised to 0.1 degrees.

    Returns a flat [lon, lat, lon, lat, ...] array of tenths of a degree, which
    packs far smaller in JSON than an array of pairs of floats.
    """
    indexed = []
    for feature in world["features"]:
        for ring in rings_of(feature["geometry"]):
            if len(ring) >= 4:
                indexed.append((bbox(ring), ring))
    print(f"  {len(indexed)} land rings indexed")

    dots: list[int] = []
    tested = 0
    # Stop short of the poles: the ice caps add a dense cap of dots that reads
    # as a smear rather than as land.
    lat = -84.0
    while lat <= 84.0:
        # Keep the arc between neighbouring dots constant as the parallels
        # shrink towards the poles.
        cos_lat = math.cos(math.radians(lat))
        lon_step = DOT_SPACING_DEG / max(cos_lat, 0.02)
        if lon_step >= 360.0:
            lat += DOT_SPACING_DEG
            continue
        steps = int(round(360.0 / lon_step))
        for i in range(steps):
            lon = -180.0 + i * (360.0 / steps)
            tested += 1
            for (min_lon, min_lat, max_lon, max_lat), ring in indexed:
                if min_lon <= lon <= max_lon and min_lat <= lat <= max_lat:
                    if point_in_ring(lon, lat, ring):
                        dots.append(round(lon * 10))
                        dots.append(round(lat * 10))
                        break
        lat += DOT_SPACING_DEG

    print(f"  {tested} grid points tested -> {len(dots) // 2} land dots")
    return dots


def perpendicular_distance(pt, start, end) -> float:
    if start == end:
        return math.hypot(pt[0] - start[0], pt[1] - start[1])
    dx, dy = end[0] - start[0], end[1] - start[1]
    num = abs(dy * pt[0] - dx * pt[1] + end[0] * start[1] - end[1] * start[0])
    return num / math.hypot(dx, dy)


def simplify(points: list[list[float]], tolerance: float) -> list[list[float]]:
    """Iterative Douglas-Peucker (recursion blows the stack on 50m coastlines)."""
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        if last <= first + 1:
            continue
        max_dist, index = 0.0, first
        for i in range(first + 1, last):
            dist = perpendicular_distance(points[i], points[first], points[last])
            if dist > max_dist:
                max_dist, index = dist, i
        if max_dist > tolerance:
            keep[index] = True
            stack.append((first, index))
            stack.append((index, last))
    return [p for p, k in zip(points, keep) if k]


def ring_area(ring: list[list[float]]) -> float:
    """Unsigned shoelace area in square degrees — a size filter, not geodesy."""
    total = 0.0
    for i in range(len(ring)):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % len(ring)]
        total += x1 * y2 - x2 * y1
    return abs(total) / 2.0


def build_countries(units: dict) -> list[dict]:
    by_name = {}
    for feature in units["features"]:
        props = feature["properties"]
        name = props.get("NAME") or props.get("NAME_EN")
        if name in COVERED:
            by_name[name] = feature

    missing = set(COVERED) - set(by_name)
    if missing:
        raise SystemExit(f"map units not found in Natural Earth: {sorted(missing)}")

    countries = []
    for name, spec in COVERED.items():
        rings = []
        for ring in rings_of(by_name[name]["geometry"]):
            if ring_area(ring) < MIN_RING_AREA_SQ_DEG:
                continue
            reduced = simplify([[p[0], p[1]] for p in ring], SIMPLIFY_TOLERANCE_DEG)
            if len(reduced) < 3:
                continue
            flat = []
            for lon, lat in reduced:
                flat.append(round(lon * 100))
                flat.append(round(lat * 100))
            rings.append(flat)
        rings.sort(key=len, reverse=True)
        points = sum(len(r) // 2 for r in rings)
        print(f"  {name}: {len(rings)} rings, {points} points")
        countries.append(
            {
                "name": spec["label"],
                "anchor": [round(spec["anchor"][0] * 100), round(spec["anchor"][1] * 100)],
                "rings": rings,
            }
        )
    return countries


def main() -> None:
    print("Building hub globe geometry")
    dots = build_dots(fetch(WORLD_URL))
    countries = build_countries(fetch(UNITS_URL))

    header = (
        "// GENERATED FILE — do not edit by hand.\n"
        "// Rebuild with: python scripts/generate_globe_data.py\n"
        "//\n"
        "// Source: Natural Earth (public domain). `dots` is a flat [lon, lat, ...]\n"
        "// array in TENTHS of a degree; country ring coordinates are flat\n"
        "// [lon, lat, ...] arrays in HUNDREDTHS of a degree. Integers keep the\n"
        "// payload small — Globe.svelte scales them back on mount.\n\n"
    )
    body = (
        f"export const DOT_SCALE = 10;\n"
        f"export const RING_SCALE = 100;\n\n"
        f"export const dots = {json.dumps(dots, separators=(',', ':'))};\n\n"
        f"export const countries = {json.dumps(countries, separators=(',', ':'))};\n"
    )
    OUT_PATH.write_text(header + body)
    print(f"\nWrote {OUT_PATH.relative_to(Path(__file__).resolve().parents[1])} "
          f"({OUT_PATH.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
