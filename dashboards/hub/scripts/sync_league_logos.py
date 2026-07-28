"""Copy each league site's round logo into the hub's static/logos/.

The hub is deployed as its own Evidence app, so it cannot reach the league
sites' static assets at build time - it needs its own copies. That makes these
files a duplicate of the source of truth in dashboards/<site>/static/, so
rerun this whenever a league logo changes or the hub side pane will keep
showing the old mark.

    python3 dashboards/hub/scripts/sync_league_logos.py
"""
import pathlib
import shutil

# hub key -> league dashboard directory name
SITES = {
    "superligaen": "superligaen",
    "scotland": "scotland",
    "ligamx": "ligamx",
    "turkey": "turkey",
}

hub = pathlib.Path(__file__).resolve().parent.parent
dashboards = hub.parent
out = hub / "static" / "logos"
out.mkdir(parents=True, exist_ok=True)

for key, site in SITES.items():
    src = dashboards / site / "static" / "logo-circle.svg"
    if not src.exists():
        raise SystemExit("missing source logo: %s" % src)
    dst = out / ("%s.svg" % key)
    shutil.copyfile(src, dst)
    print("synced", src.relative_to(dashboards), "->", dst.relative_to(hub))
