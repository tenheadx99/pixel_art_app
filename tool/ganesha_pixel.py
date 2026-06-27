#!/usr/bin/env python3
"""Hand-authored pixel-art Lord Ganesha (face) grid for store assets.
Exposes ganesha_grid() -> (w, h, rows, cmap_rgb)."""

PAL = {
    "1": (255, 193, 37),   # crown gold
    "2": (214, 40, 40),    # red (jewel / tilak)
    "3": (247, 182, 167),  # face skin (warm pink)
    "4": (231, 147, 132),  # skin shade / ear inner
    "5": (255, 251, 245),  # tusk / eye white
    "6": (74, 40, 33),     # dark outline / pupils
    "7": (255, 214, 92),   # crown highlight
}

W = H = 24

def _blank():
    return [["0"] * W for _ in range(H)]

def _ellipse(g, cx, cy, rx, ry, val, where=None):
    for y in range(H):
        for x in range(W):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                if where is None or where(x, y):
                    g[y][x] = val

def _ellipse_outlined(g, cx, cy, rx, ry, fill, outline, t=0.7):
    _ellipse(g, cx, cy, rx, ry, outline)
    _ellipse(g, cx, cy, rx - t, ry - t, fill)

def _rect(g, x0, y0, x1, y1, val):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < W and 0 <= y < H:
                g[y][x] = val

def _set(g, pts, val):
    for x, y in pts:
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = val

def _outline_silhouette(g):
    """Wrap the whole figure in a 1px dark border on empty neighbours."""
    out = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if g[y][x] == "0":
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < W and 0 <= ny < H and g[ny][nx] not in ("0", "6"):
                        out[y][x] = "6"
                        break
    return out

def ganesha_grid():
    g = _blank()
    cx = 11.5

    # ---- ears (outlined, behind face) ----
    _ellipse_outlined(g, 4.0, 12, 4.0, 4.9, "3", "6")
    _ellipse_outlined(g, 19.0, 12, 4.0, 4.9, "3", "6")
    _ellipse(g, 4.0, 12, 2.2, 3.0, "4")     # inner ear
    _ellipse(g, 19.0, 12, 2.2, 3.0, "4")

    # ---- face / head dome (outlined, on top -> rims separate it from ears) ----
    _ellipse_outlined(g, cx, 11, 5.2, 4.6, "3", "6")

    # ---- trunk: bold, emerges from face, hangs down and curls (drawn over face) ----
    trunk = [(10,12),(11,12),(12,12),(13,12),
             (10,13),(11,13),(12,13),(13,13),
             (10,14),(11,14),(12,14),(13,14),
             (11,15),(12,15),(13,15),(14,15),
             (12,16),(13,16),(14,16),
             (12,17),(13,17),(14,17),(15,17),
             (13,18),(14,18),(15,18),
             (13,19),(14,19),(15,19),
             (14,20),(15,20)]            # tip curls right
    _set(g, trunk, "3")
    _set(g, [(13,14),(13,15),(14,16),(14,17),(15,18),(15,19)], "4")  # trunk shade edge

    # ---- crown (mukut) seated on the head ----
    _rect(g, 8, 4, 15, 6, "1")               # gold band
    _rect(g, 8, 4, 15, 4, "7")               # band highlight
    _set(g, [(11,1),(12,1),(11,2),(12,2),(11,3),(12,3)], "1")  # centre spire
    _set(g, [(7,4),(7,5),(7,6)], "1")        # left point
    _set(g, [(16,4),(16,5),(16,6)], "1")     # right point
    _set(g, [(11,2),(12,2)], "2")            # crown jewel
    _set(g, [(11,5),(12,5)], "2")            # band gem

    # ---- tilak on forehead ----
    _set(g, [(11,8),(12,8),(11,9)], "2")

    # ---- eyes (high on face, clearly above the trunk) ----
    _set(g, [(8,10),(9,10),(8,11)], "5")
    _set(g, [(14,10),(15,10),(15,11)], "5")
    _set(g, [(9,10),(14,10)], "6")           # pupils

    # ---- tusks: short white nubs at the trunk base, pointing down ----
    _set(g, [(9,16),(9,17),(10,17)], "5")
    _set(g, [(16,16),(16,17),(15,17)], "5")
    _set(g, [(9,15),(16,15)], "6")           # tusk roots

    g = _outline_silhouette(g)
    rows = [",".join(r) for r in g]
    return W, H, [r.split(",") for r in rows], dict(PAL)


if __name__ == "__main__":
    from PIL import Image, ImageDraw
    import os
    w, h, rows, cmap = ganesha_grid()
    cell = 28
    img = Image.new("RGB", (w * cell, h * cell), (58, 13, 13))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, v in enumerate(row):
            if v != "0":
                d.rectangle([x*cell, y*cell, (x+1)*cell-1, (y+1)*cell-1], fill=cmap[v])
    out = os.path.join(os.path.dirname(__file__), "..",
        "fastlane/metadata/devotional/android/en-US/images/_ganesha_preview.png")
    img.save(out)
    print("preview ->", out)
