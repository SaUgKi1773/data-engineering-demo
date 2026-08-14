export const prerender = true;

// Evidence ships a default manifest carrying icons and nothing else. Without a
// name, a start_url and display:standalone the browser will not offer to
// install, so this route replaces it — the same one the league sites serve.
const webmanifest = {
	name: 'Krogvad Cross-League Analytics',
	short_name: 'Cross-League',
	description: 'Five top-flight leagues compared on one set of measures — leagues, clubs, players and matches.',
	start_url: '/',
	display: 'standalone',
	orientation: 'portrait',
	background_color: '#ffffff',
	theme_color: '#1d1d1f',
	icons: [
		{ src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
		{ src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
		{ src: '/icon.svg', sizes: 'any', type: 'image/svg+xml' }
	],
	categories: ['sports', 'entertainment']
};

export const GET = () =>
	new Response(JSON.stringify(webmanifest), {
		headers: { 'Content-Type': 'application/manifest+json' }
	});
