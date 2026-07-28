// Navigation model for the hub's side pane (SideNav).
//
// The hub is a one-page site, so unlike the league sites this is not a page
// list — it is the shelf of platforms. Each entry points at a separate Evidence
// deployment, and the logos are the copies synced by scripts/sync_league_logos.py.
//
// The URLs and display names are duplicated from the `leagues` query in
// pages/index.md, where they live inside a SQL case statement that JS cannot
// read. Adding a league means editing both.

// UI control glyphs (not destinations) — kept as stroke SVGs.
export const icons = {
  close: 'M6 18 18 6M6 6l12 12'
};

// Launch order, matching the shelf on the home page.
export const leagues = [
  {
    href: 'https://superligaanalytics.vercel.app/',
    label: 'Superligaen',
    country: 'Denmark',
    logo: '/logos/superligaen.svg'
  },
  {
    href: 'https://scottishpremiershipanalytics.vercel.app/',
    label: 'Premiership',
    country: 'Scotland',
    logo: '/logos/scotland.svg'
  },
  {
    href: 'https://mexicanligamxanalytics.vercel.app/',
    label: 'Liga MX',
    country: 'Mexico',
    logo: '/logos/ligamx.svg'
  },
  {
    href: 'https://turkishsuperliganalytics.vercel.app/',
    label: 'Süper Lig',
    country: 'Turkey',
    logo: '/logos/turkey.svg'
  }
];

// External links, mirrored from the footer on the home page. Rendered as a
// small icon row pinned to the foot of the side pane. Icons are Lucide-style
// stroke glyphs (24 viewBox, fill none) so they read as one muted family.
// The league sites' equivalent row carries a link back to this hub; here that
// would point at the page you are already on, so it is left out.
export const externalLinks = [
  {
    label: 'Source on GitHub',
    href: 'https://github.com/SaUgKi1773/data-engineering-demo',
    path: 'M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4M9 18c-4.51 2-5-2-7-2'
  },
  {
    label: 'Request Data Access',
    href: 'https://forms.gle/2wDZcfwm8jk6aWGS9',
    path: 'M12 2C7.03 2 3 3.34 3 5s4.03 3 9 3 9-1.34 9-3-4.03-3-9-3ZM3 5v14c0 1.66 4.03 3 9 3s9-1.34 9-3V5M3 12c0 1.66 4.03 3 9 3s9-1.34 9-3'
  },
  {
    label: "Data Engineer's Diary",
    href: 'https://saugki1773.github.io/data-engineering-blog/',
    path: 'M12 7v14M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z'
  },
  {
    label: 'Support via Revolut',
    href: 'https://revolut.me/salihugurkimilli',
    path: 'M10 2v2M14 2v2M16 8a1 1 0 0 1 1 1v8a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V9a1 1 0 0 1 1-1h14zM16 8h1a4 4 0 1 1 0 8h-1'
  },
  {
    label: 'Share a Suggestion',
    href: 'https://github.com/SaUgKi1773/data-engineering-demo/issues/new?template=suggestion.md',
    path: 'M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5M9 18h6M10 22h4'
  },
  {
    label: 'LinkedIn — Salih Ugur Kimilli',
    href: 'https://www.linkedin.com/in/salih-ugur-kimilli-since1773/',
    path: 'M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6zM2 9h4v12H2zM4 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4z'
  }
];
