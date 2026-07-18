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
      { href: '/', label: 'Home', logo: '/logo-circle.svg' },
      { href: '/standings', label: 'Standings', emoji: '🏆', tint: '#fffbeb' },
      { href: '/upcoming-matches', label: 'Upcoming Fixtures', emoji: '📅', tint: '#f5f3ff' }
    ]
  },
  {
    label: 'Matches',
    items: [
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

// Primary destinations for the solid bottom bar. The side pane is opened from
// the header toggle, so the bar is pure quick-nav — no menu button here.
export const bottomItems = [
  { href: '/standings', label: 'Standings', emoji: '🏆' },
  { href: '/upcoming-matches', label: 'Fixtures', emoji: '📅' },
  { href: '/', label: 'Home', logo: '/logo-circle.svg' },
  { href: '/match-results', label: 'Results', emoji: '⚽' },
  { href: '/predictions', label: 'Predictions', emoji: '🔮' }
];
