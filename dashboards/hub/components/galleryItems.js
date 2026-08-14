// The Gallery section on the home page.
//
// Add a photo by dropping the file into static/gallery/ and adding a line
// here. Nothing scans the folder at build time, so a file with no entry simply
// does not appear — which is the safe direction for a public page.
//
// alt is required and is not decoration: it is what a screen reader announces
// and what shows if the file fails to load. Describe the picture, not the
// occasion — the caption already carries the occasion.
//
// Any shape is fine. The grid is a masonry that keeps each photo's own
// proportions, so a portrait phone shot and a landscape one sit together
// without either being cropped. Keep files under ~400KB; they load on every
// visit to the home page.

export const gallery = [
	{
		src: '/gallery/matchday-farum.jpeg',
		alt: 'A plastic cup of beer held up beside the pitch at a floodlit stadium, an assistant referee at the corner flag and players gathered in the goalmouth beyond',
		caption: 'Matchday at Right to Dream Park, Farum'
	},
	{
		src: '/gallery/building-superligaen.jpeg',
		alt: 'Someone working at a desk beneath a sloped attic window with pine trees outside, an external monitor showing the Superligaen site and a tablet of draft charts in hand',
		caption: 'Building the Superligaen site'
	},
	{
		src: '/gallery/home-screen-folder.jpeg',
		alt: 'A phone home-screen folder named Data Products holding two app icons, DataSat DK and Superligaen',
		caption: 'Superligaen, on the home screen'
	},
	{
		src: '/gallery/install-prompt.jpeg',
		alt: 'The Superligaen site on a phone, showing the season summary and a prompt offering to add it to the home screen',
		caption: 'The install prompt, doing its job'
	}
];
