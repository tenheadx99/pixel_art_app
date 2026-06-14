# Devotional artwork source images

Drop one source image per deity/figure here, named `<id>.png` (or `.jpg`,
`.jpeg`, `.webp`) where `<id>` matches an entry in
[`../devotional_artwork_spec.json`](../devotional_artwork_spec.json).

Examples: `ganesha.png`, `durga.png`, `nataraja.png`, `diwali_diya.png`.

Then run from the project root:

```bash
python3 tool/build_devotional_artworks.py
```

The tool converts every image present into `assets/pixel_art_devotional/<id>.json`
using the same algorithm as the in-app photo→pixel converter, and rebuilds
`manifest.json`. Entries without an image are reported as PENDING and skipped,
so you can add deities incrementally.

## Tips for good low-res results
- Use **flat, high-contrast** art with clean outlines — busy/realistic images
  turn to mud at 24–48 px.
- Put the figure on a **transparent background** (alpha < 128 becomes empty,
  uncolored cells) so the silhouette reads clearly.
- Keep distinct regions to a handful of colors; the converter keeps the top 16
  by frequency and the coloring UI is tuned for ~16 numbers.
- After generating, open the artwork in the app and hand-tune the JSON
  (`grid` / `colorMap`) if a region needs cleanup.

## Licensing / cultural note
Use art you have the rights to (original, commissioned, or licensed). Keep
iconography respectful and recognizable — correct attributes, vahanas (mounts)
and color conventions per deity.
