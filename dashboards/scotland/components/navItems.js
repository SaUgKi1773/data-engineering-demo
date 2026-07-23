// Shared navigation model for the side pane (SideNav) and bottom bar (BottomNav).
// Icons + tile tints mirror the home page cards (index.md) so the two stay in sync.
// tint = Tailwind pastel hex, applied inline so it survives regardless of purge.

// UI control glyphs (not destinations) — kept as stroke SVGs.
export const icons = {
  close: 'M6 18 18 6M6 6l12 12'
};

// Grouped links for the side pane.
export const navGroups = [
  {
    label: 'Overview',
    items: [
      { href: '/standings', label: 'Standings', emoji: '🏆', tint: '#fffbeb' }
    ]
  },
  {
    label: 'Matches',
    items: [
      { href: '/upcoming-matches', label: 'Upcoming Fixtures', emoji: '📅', tint: '#f5f3ff' },
      { href: '/match-results', label: 'Match Results', emoji: '⚽', tint: '#eff6ff' },
      { href: '/predictions', label: 'Prediction Module', emoji: '🔮', tint: '#fdf4ff' }
    ]
  },
  {
    label: 'Intelligence',
    items: [
      { href: '/league-analytics', label: 'League Intelligence', emoji: '📈', tint: '#ecfdf5' },
      { href: '/team-analytics', label: 'Team Intelligence', emoji: '👥', tint: '#f0f9ff' },
      { href: '/player-analytics', label: 'Player Intelligence', emoji: '👟', tint: '#eef2ff' },
      { href: '/stadium-analytics', label: 'Stadium Intelligence', emoji: '🏟️', tint: '#fff7ed' },
      { href: '/referee-analytics', label: 'Referee Intelligence', emoji: '🟨', tint: '#fef2f2' },
      { href: '/transfer-intelligence', label: 'Transfer Intelligence', emoji: '🔁', tint: '#faf5ff' }
    ]
  },
  {
    label: 'More',
    items: [
      { href: '/glossary', label: 'Data Glossary', emoji: '📖', tint: '#f1f5f9' },
      { href: '/about', label: 'About This Project', emoji: '👤', tint: '#f3f4f6' }
    ]
  }
];

// External links, mirrored from the About page. Rendered as a small icon row
// pinned to the foot of the side pane. Icons are Lucide-style stroke glyphs
// (24 viewBox, fill none) so they read as one muted family.
export const externalLinks = [
  {
    label: 'Source on GitHub',
    href: 'https://github.com/SaUgKi1773/data-engineering-demo',
    path: 'M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4M9 18c-4.51 2-5-2-7-2'
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
    label: 'Krogvad Analytics Hub',
    href: 'https://krogvadanalyticshub.vercel.app/',
    path: 'M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z'
  },
  {
    label: 'LinkedIn — Salih Ugur Kimilli',
    href: 'https://www.linkedin.com/in/salih-ugur-kimilli-since1773/',
    path: 'M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6zM2 9h4v12H2zM4 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4z'
  }
];

// Primary destinations for the solid bottom bar. The side pane is opened from
// the header toggle, so the bar is pure quick-nav — no menu button here.
export const bottomItems = [
  { href: '/standings', label: 'Standings', emoji: '🏆' },
  { href: '/upcoming-matches', label: 'Fixtures', emoji: '📅' },
  { href: '/', label: 'Home', logo: '/logo-circle.svg' },
  { href: '/match-results', label: 'Results', emoji: '⚽' },
  { href: '/predictions', label: 'Predictions', emoji: '🔮' }
];
