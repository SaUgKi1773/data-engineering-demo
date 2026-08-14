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
// w and h are the file's real pixel dimensions and are required. They let the
// browser reserve the right box before the image downloads: without them a
// lazily-loaded photo has no width until it arrives, so the strip starts empty
// and the arrows have nothing to scroll until it fills in.
//
// Any shape is fine. The strip is a fixed-height row and each photo keeps its
// own proportions, so a portrait phone shot sits as a narrow tile beside a wide
// landscape one and neither is cropped. Order here is the order on screen, and
// the first one is the one everybody sees without scrolling — lead with it.
// Keep files under ~400KB; they load on every visit to the home page.

export const gallery = [
	{
		src: '/gallery/matchday-farum.jpeg',
		w: 1536,
		h: 2048,
		alt: 'A plastic cup of beer held up beside the pitch at a floodlit stadium, an assistant referee at the corner flag and players gathered in the goalmouth beyond',
		caption: 'Matchday at Right to Dream Park, Farum'
	},
	{
		src: '/gallery/the-desk.jpeg',
		w: 1200,
		h: 1600,
		alt: 'A desk under a sloped attic window looking onto pine trees, a monitor showing the fixtures page, a laptop below, and a cat’s tail curling out from behind the screen',
		caption: 'The office, and the tail of its supervisor'
	},
	{
		src: '/gallery/explaining-league-intelligence.jpeg',
		w: 1366,
		h: 2048,
		alt: 'Hands raised towards a monitor showing season awards and a points-race chart, a laptop of code below, all backlit by a bright sloped window',
		caption: 'Talking through the league intelligence page'
	},
	{
		src: '/gallery/building-superligaen.jpeg',
		w: 1536,
		h: 2048,
		alt: 'Someone working at a desk beneath a sloped attic window with pine trees outside, an external monitor showing the Superligaen site and a tablet of draft charts in hand',
		caption: 'Building the Superligaen site'
	},
	{
		src: '/gallery/rainy-day-fixtures.jpeg',
		w: 1200,
		h: 1600,
		alt: 'Rain on a sloped window above a monitor split between the upcoming fixtures page and a video stream, a laptop of terminal output below, and a cat asleep beside it',
		caption: 'A wet afternoon on the fixtures page'
	},
	{
		src: '/gallery/reviewing-superligaen.jpeg',
		w: 1200,
		h: 1600,
		alt: 'Someone pointing a stylus at a monitor showing the Superligaen home page, a tablet of chart drafts in the other hand',
		caption: 'Reviewing the season summary'
	},
	{
		src: '/gallery/garden-off-season.jpeg',
		w: 1200,
		h: 1600,
		alt: 'Someone crouching and smiling beside a freshly planted shrub in a sunny garden, a beech hedge behind',
		caption: 'Gardening break, Farum'
	},
	{
		src: '/gallery/home-screen-folder.jpeg',
		w: 946,
		h: 2048,
		alt: 'A phone home-screen folder named Data Products holding two app icons, DataSat DK and Superligaen',
		caption: 'Superligaen, an old logo on the home screen'
	},
	{
		src: '/gallery/install-prompt.jpeg',
		w: 945,
		h: 2048,
		alt: 'The Superligaen site on a phone, showing the season summary and a prompt offering to add it to the home screen',
		caption: 'The install prompt, first tests on the feature'
	}
];
