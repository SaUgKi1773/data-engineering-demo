// Navigation and identity config for the console shell.
//
// The five leagues are duplicated here and in mart_leagues.sql: the layout
// cannot run a query, and the header key must render before any page data
// arrives. Keep the two in step — colour and site_url are the fields that
// matter.

export const tabs = [
  { href: '/',        label: 'Home' },
  { href: '/leagues', label: 'Leagues' },
  { href: '/clubs',   label: 'Clubs' },
  { href: '/players', label: 'Players' },
  { href: '/matches', label: 'Matches' }
];

// Alphabetical by league name, which is how the hues were assigned — so a
// filter can never repaint a league.
export const leagues = [
  { code: 'ESP', league_name: 'La Liga',     colour: '#2a78d6', site_url: 'https://spanishlaligaanalytics.vercel.app' },
  { code: 'MEX', league_name: 'Liga MX',     colour: '#eb6834', site_url: 'https://mexicanligamxanalytics.vercel.app' },
  { code: 'SCO', league_name: 'Premiership', colour: '#1baf7a', site_url: 'https://scottishpremiershipanalytics.vercel.app' },
  { code: 'DEN', league_name: 'Superliga',   colour: '#eda100', site_url: 'https://superligaanalytics.vercel.app' },
  { code: 'TUR', league_name: 'Süper Lig',   colour: '#e87ba4', site_url: 'https://turkishsuperliganalytics.vercel.app' }
];

// Name -> code and name -> colour, for pages that get league_name from SQL.
export const codeOf   = Object.fromEntries(leagues.map((l) => [l.league_name, l.code]));
export const colourOf = Object.fromEntries(leagues.map((l) => [l.league_name, l.colour]));

export const externalLinks = [
  { label: 'Source on GitHub', href: 'https://github.com/SaUgKi1773/data-engineering-demo' },
  { label: 'Request Data Access', href: 'https://forms.gle/2wDZcfwm8jk6aWGS9' },
  { label: 'Build with us', href: 'https://forms.gle/vPCoCNZvehu5yyze8' },
  { label: "Data Engineer's Diary", href: 'https://saugki1773.github.io/data-engineering-blog/' },
  { label: 'Krogvad Analytics Hub', href: 'https://krogvadanalyticshub.vercel.app/' },
  { label: 'LinkedIn', href: 'https://www.linkedin.com/in/salih-ugur-kimilli-since1773/' }
];
