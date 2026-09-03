# Gallery media

Drop photos and video clips here, then add a line for each in
`components/galleryItems.js`. A file with no entry there does not appear on the
page — deliberately, so a stray upload never publishes itself.

## Photos

- **Any shape.** The strip is a fixed-height row; each photo keeps its own proportions.
- **Under ~400KB.** These load on every visit to the home page.
- **Long side ~2000px** is plenty — the lightbox caps at 78% of viewport height.
- **`.jpg` for photos**, `.png` only if you need transparency.

## Videos

- **`.mp4`, H.264 video and AAC audio.** Every browser plays it; other codecs do not.
- **Short.** A few seconds. This is a gallery tile, not a showreel.
- **Under ~5MB.** Only someone who clicks the tile downloads it, but they wait for it.
- **A poster frame is required** — a `.jpg` still from the clip, same pixel
  dimensions as the video. It is what stands in the strip, and its dimensions
  are what the entry declares as `w`/`h`. Grab one with
  `ffmpeg -i clip.mp4 -frames:v 1 clip-poster.jpg`, or `qlmanage -t` on a Mac
  without ffmpeg.
- **Assume it plays silently.** The player autoplays muted — browsers block
  a clip that starts with sound — and the viewer unmutes from the controls. If
  the clip only works with audio, it is the wrong clip for the strip.

## Both

Everyone identifiable in a photo or clip should be happy for it to be on a
public page. Once deployed these are served to anyone, and search engines index
them. Read the banners in the background before you publish a matchday shot.
