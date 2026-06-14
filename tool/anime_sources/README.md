# Anime artwork source images

Drop one source image per artwork here, named `<id>.png` (or `.jpg`/`.webp`)
matching an entry in [`../anime_artwork_spec.json`](../anime_artwork_spec.json):
e.g. `chibi_hero.png`, `anime_eye_blue.png`, `mecha_robot.png`.

Then run from the project root:

```bash
python3 tool/build_artworks.py anime
```

Converted artworks land in `assets/pixel_art_anime/<id>.json` and the manifest
is rebuilt. The current Anime catalog ships a "Kawaii" starter set re-tagged
from existing app assets; these converted figures add the Chibi / Eyes / Mecha
categories.

## Tips
- Flat, bold, high-contrast art reads best at 24–48 px; transparent background
  keeps the silhouette clean (alpha < 128 = empty cell).
- Keep distinct regions to ~16 colors (the converter keeps the top 16).

## IMPORTANT — licensing
Do **not** use copyrighted characters from anime/manga you don't have rights to.
Use original characters, commissioned art, or properly licensed assets. The spec
uses generic descriptors (Chibi Hero, Cat Girl, Battle Mecha) for this reason.
