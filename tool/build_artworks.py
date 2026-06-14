#!/usr/bin/env python3
"""Batch image -> pixel-art JSON converter for any flavor catalog.

Replicates the in-app PixelConverterService / ImageProcessingService algorithm
exactly (BOX-average downscale, 32-step per-channel quantization, top-N colors
by frequency, +16 channel offset, alpha<128 = empty cell) so generated artworks
look identical to ones produced by the app's photo->pixel feature.

Usage
-----
    python3 tool/build_artworks.py <flavor>      # e.g. devotional | anime

For flavor <f> it reads:
    tool/<f>_artwork_spec.json     - list of artworks + metadata
    tool/<f>_sources/<id>.png      - one source image per artwork id
and writes:
    assets/pixel_art_<f>/<id>.json - converted artwork
    assets/pixel_art_<f>/manifest.json (rebuilt from ALL json in the folder)

Entries whose source image is missing are reported as PENDING and skipped, so
you can fill a catalog incrementally. Re-running is safe/idempotent.

Requires: Pillow  (pip install Pillow)
"""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Gallery grouping order per flavor (unknown categories sort last).
CATEGORY_ORDER = {
    "devotional": ["Symbols", "Deities", "Goddesses", "Avatars", "Sacred", "Festivals", "Mandalas"],
    "anime": ["Kawaii", "Chibi", "Eyes", "Mecha"],
    "pixelcalm": ["Zen", "Mandalas", "Patterns", "Nature"],
}


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


def find_source(src_dir, entry_id):
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        p = os.path.join(src_dir, entry_id + ext)
        if os.path.exists(p):
            return p
    return None


def main(flavor):
    spec_path = os.path.join(ROOT, "tool", f"{flavor}_artwork_spec.json")
    src_dir = os.path.join(ROOT, "tool", f"{flavor}_sources")
    out_dir = os.path.join(ROOT, "assets", f"pixel_art_{flavor}")
    asset_prefix = f"assets/pixel_art_{flavor}"
    os.makedirs(src_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)

    if not os.path.exists(spec_path):
        sys.exit(f"No spec file: {spec_path}")
    spec = json.load(open(spec_path))
    order = CATEGORY_ORDER.get(flavor, [])

    converted, pending = [], []
    for e in spec:
        src = find_source(src_dir, e["id"])
        if not src:
            pending.append(e["id"])
            continue
        gw = gh = e["grid"]
        grid, color_map = convert_image(src, gw, gh, e.get("maxColors", 16))
        out = {
            "id": e["id"], "name": e["name"],
            "gridWidth": gw, "gridHeight": gh,
            "grid": ";".join(",".join(str(c) for c in row) for row in grid),
            "colorMap": {str(k): v for k, v in color_map.items()},
            "category": e["category"], "difficulty": e["difficulty"],
            "isPremium": e.get("premium", False),
        }
        json.dump(out, open(os.path.join(out_dir, e["id"] + ".json"), "w"), indent=2)
        converted.append(e["id"])

    files = [n for n in os.listdir(out_dir) if n.endswith(".json") and n != "manifest.json"]
    def sort_key(n):
        d = json.load(open(os.path.join(out_dir, n)))
        c = d.get("category", "")
        pri = order.index(c) if c in order else len(order)
        return (pri, d.get("difficulty", 1), d.get("name", n))
    files.sort(key=sort_key)
    json.dump([f"{asset_prefix}/{n}" for n in files],
              open(os.path.join(out_dir, "manifest.json"), "w"), indent=2)

    print(f"[{flavor}] converted {len(converted)}: {', '.join(converted) or '(none)'}")
    print(f"[{flavor}] manifest now lists {len(files)} artworks.")
    if pending:
        print(f"\nPENDING ({len(pending)}) — add tool/{flavor}_sources/<id>.png:")
        for pid in pending:
            print("  -", pid)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 tool/build_artworks.py <flavor>   (e.g. devotional | anime)")
    main(sys.argv[1])
