export const prerender = true;

const webmanifest = {
	name: 'Süper Lig Analytics',
	short_name: 'Süper Lig',
	description: 'Turkish Süper Lig — standings, match results, league & team intelligence.',
	start_url: '/',
	display: 'standalone',
	orientation: 'portrait',
	background_color: '#ffffff',
	theme_color: '#1D4ED8',
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
