// Navigation and identity config.
//
// The five leagues are duplicated here and in mart_leagues.sql: the layout
// cannot run a query, and the shell must render before any page data arrives.
// Keep the two in step — colour and site_url are the fields that matter.
//
// Nav chrome is deliberately neutral grey. The five hues identify leagues and
// nothing else; spending one of them on an active-link state would teach the
// reader that colour means UI, which is exactly what the charts rely on it not
// meaning.

// UI control glyphs (not destinations) — kept as stroke SVGs.
export const icons = {
  close: 'M6 18 18 6M6 6l12 12'
};

// Grouped links for the side pane. Icons + tints mirror the home page cards.
export const navGroups = [
  {
    label: 'Overview',
    items: [
      { href: '/', label: 'Home', emoji: '🏠', tint: '#f8fafc' }
    ]
  },
  {
    label: 'Compare',
    items: [
      { href: '/leagues', label: 'Leagues', emoji: '🏆', tint: '#fffbeb' },
      { href: '/clubs',   label: 'Clubs',   emoji: '🛡️', tint: '#eff6ff' },
      { href: '/players', label: 'Players', emoji: '👥', tint: '#ecfdf5' },
      { href: '/matches', label: 'Matches', emoji: '⚽', tint: '#f5f3ff' }
    ]
  }
];

// Bottom bar, phone only. The centre slot is the brand mark.
export const bottomItems = [
  { href: '/leagues', label: 'Leagues', emoji: '🏆' },
  { href: '/clubs',   label: 'Clubs',   emoji: '🛡️' },
  { href: '/',        label: 'Home',    logo: '/logo-circle.svg' },
  { href: '/players', label: 'Players', emoji: '👥' },
  { href: '/matches', label: 'Matches', emoji: '⚽' }
];

// Launch order, matching the platform shelf on the Hub home page.
//
// Order and colour are separate decisions and only one of them is free. The
// hues were handed out alphabetically by league name once and are frozen to
// the league from then on, so no filter, sort or reorder can ever repaint one;
// this array only decides where each league APPEARS. It was alphabetical too,
// which sorted on the league name while the screen showed the country code —
// a list sorted by something invisible.
export const leagues = [
  { code: 'DEN', league_name: 'Superliga',   colour: '#eda100', site_url: 'https://superligaanalytics.vercel.app' },
  { code: 'SCO', league_name: 'Premiership', colour: '#1baf7a', site_url: 'https://scottishpremiershipanalytics.vercel.app' },
  { code: 'MEX', league_name: 'Liga MX',     colour: '#eb6834', site_url: 'https://mexicanligamxanalytics.vercel.app' },
  { code: 'TUR', league_name: 'Süper Lig',   colour: '#e87ba4', site_url: 'https://turkishsuperliganalytics.vercel.app' },
  { code: 'ESP', league_name: 'La Liga',     colour: '#2a78d6', site_url: 'https://spanishlaligaanalytics.vercel.app' }
];

// Name -> code and name -> colour, for pages that get league_name from SQL.
export const codeOf   = Object.fromEntries(leagues.map((l) => [l.league_name, l.code]));
export const colourOf = Object.fromEntries(leagues.map((l) => [l.league_name, l.colour]));

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
    label: 'Build with us',
    href: 'https://forms.gle/vPCoCNZvehu5yyze8',
    path: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM19 8v6M22 11h-6'
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
