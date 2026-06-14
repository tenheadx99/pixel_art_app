#!/usr/bin/env python3
"""Batch image -> pixel-art JSON converter for the Divine Pixels flavor.

Replicates the in-app PixelConverterService / ImageProcessingService algorithm
exactly (BOX-average downscale, 32-step per-channel quantization, top-N colors
by frequency, +16 channel offset, alpha<128 = empty cell) so generated artworks
look identical to ones produced by the app's photo->pixel feature.

Workflow
--------
1. Drop a source image for each artwork into tool/devotional_sources/, named
   "<id>.png" (or .jpg) — e.g. ganesha.png, durga.png. Use clean, flat,
   high-contrast art for the best low-res result.
2. Run:  python3 tool/build_devotional_artworks.py
   Every spec entry whose source image exists is converted; entries without an
   image are reported as PENDING and skipped (safe to run repeatedly).
3. The tool rewrites assets/pixel_art_devotional/manifest.json from ALL JSON in
   that folder (authored symbols + reused mandalas + converted figures),
   ordered by category.

Requires: Pillow  (pip install Pillow)
"""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = os.path.join(ROOT, "tool", "devotional_artwork_spec.json")
SRC_DIR = os.path.join(ROOT, "tool", "devotional_sources")
OUT_DIR = os.path.join(ROOT, "assets", "pixel_art_devotional")
ASSET_PREFIX = "assets/pixel_art_devotional"

# Gallery grouping order (matches the plan's category list).
CATEGORY_ORDER = [
    "Symbols", "Deities", "Goddesses", "Avatars", "Sacred", "Festivals", "Mandalas",
]


def quantize_channel(v):
    return (v // 32) * 32


def convert_image(path, gw, gh, max_colors=16):
    """Return (grid:list[list[int]], color_map:dict[int,int]) matching the app."""
    im = Image.open(path).convert("RGBA").resize((gw, gh), Image.Resampling.BOX)
    px = im.load()

    counts = {}
    for y in range(gh):
        for x in range(gw):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            q = (quantize_channel(r) << 16) | (quantize_channel(g) << 8) | quantize_channel(b)
            counts[q] = counts.get(q, 0) + 1

    top = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:max_colors]
    q_to_idx = {q: i + 1 for i, (q, _) in enumerate(top)}

    grid = [[0] * gw for _ in range(gh)]
    for y in range(gh):
        for x in range(gw):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            q = (quantize_channel(r) << 16) | (quantize_channel(g) << 8) | quantize_channel(b)
            grid[y][x] = q_to_idx.get(q, 0)

    color_map = {}
    for q, idx in q_to_idx.items():
        r = (q >> 16) & 0xFF
        g = (q >> 8) & 0xFF
        b = q & 0xFF
        # +16 centers the 32-wide quantization bucket (matches buildColorMap).
        color_map[idx] = 0xFF000000 | ((r + 16) << 16) | ((g + 16) << 8) | (b + 16)
    return grid, color_map


def find_source(entry_id):
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        p = os.path.join(SRC_DIR, entry_id + ext)
        if os.path.exists(p):
            return p
    return None


def main():
    with open(SPEC) as f:
        spec = json.load(f)

    converted, pending = [], []
    for e in spec:
        src = find_source(e["id"])
        if not src:
            pending.append(e["id"])
            continue
        gw = gh = e["grid"]
        grid, color_map = convert_image(src, gw, gh, e.get("maxColors", 16))
        out = {
            "id": e["id"],
            "name": e["name"],
            "gridWidth": gw,
            "gridHeight": gh,
            "grid": ";".join(",".join(str(c) for c in row) for row in grid),
            "colorMap": {str(k): v for k, v in color_map.items()},
            "category": e["category"],
            "difficulty": e["difficulty"],
            "isPremium": e.get("premium", False),
        }
        with open(os.path.join(OUT_DIR, e["id"] + ".json"), "w") as f:
            json.dump(out, f, indent=2)
        converted.append(e["id"])

    # Rebuild manifest from every artwork JSON in the folder, grouped by category.
    files = [n for n in os.listdir(OUT_DIR) if n.endswith(".json") and n != "manifest.json"]
    def sort_key(n):
        d = json.load(open(os.path.join(OUT_DIR, n)))
        cat = d.get("category", "")
        pri = CATEGORY_ORDER.index(cat) if cat in CATEGORY_ORDER else len(CATEGORY_ORDER)
        return (pri, d.get("difficulty", 1), d.get("name", n))
    files.sort(key=sort_key)
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump([f"{ASSET_PREFIX}/{n}" for n in files], f, indent=2)

    print(f"Converted {len(converted)} image(s): {', '.join(converted) or '(none)'}")
    print(f"Manifest now lists {len(files)} artworks.")
    if pending:
        print(f"\nPENDING ({len(pending)}) — add a source image to tool/devotional_sources/<id>.png:")
        for pid in pending:
            print("  -", pid)


if __name__ == "__main__":
    if not os.path.isdir(SRC_DIR):
        os.makedirs(SRC_DIR, exist_ok=True)
    main()
