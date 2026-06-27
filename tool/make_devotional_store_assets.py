#!/usr/bin/env python3
"""Generate Play Store icon (512x512) and feature graphic (1024x500) for the
devotional ("Bhakti Rang") flavor, built from the in-app diya pixel art so the
store assets stay true to the app's look."""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ganesha_pixel import ganesha_grid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "fastlane/metadata/devotional/android/en-US/images")
os.makedirs(OUT, exist_ok=True)

SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS  = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANSB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# ---- devotional palette ----
GOLD   = (255, 196, 64)
DEEP   = (58, 13, 13)     # deep maroon
MID    = (138, 30, 16)    # warm red
SAFF   = (255, 138, 0)    # saffron
CREAM  = (255, 244, 214)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def radial_bg(size, inner, outer, cx=0.5, cy=0.42, power=1.15):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    maxd = math.hypot(max(cx, 1 - cx) * w, max(cy, 1 - cy) * h)
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - cx * w, y - cy * h) / maxd
            px[x, y] = lerp(inner, outer, min(1, d) ** power)
    return img

def load_grid(name):
    if name == "ganesha":
        return ganesha_grid()
    d = json.load(open(os.path.join(ROOT, "assets/pixel_art_devotional", name + ".json")))
    rows = [r.split(",") for r in d["grid"].split(";")]
    cmap = {k: ((v >> 16) & 255, (v >> 8) & 255, v & 255) for k, v in d["colorMap"].items()}
    return d["gridWidth"], d["gridHeight"], rows, cmap

def render_pixel_art(name, cell):
    w, h, rows, cmap = load_grid(name)
    img = Image.new("RGBA", (w * cell, h * cell), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for y, row in enumerate(rows):
        for x, v in enumerate(row):
            if v != "0" and v in cmap:
                r, g, b = cmap[v]
                dr.rectangle([x * cell, y * cell, (x + 1) * cell - 1, (y + 1) * cell - 1],
                             fill=(r, g, b, 255))
    return img

def render_color_by_number(name, cell, mode="bottom", filled_frac=0.55):
    """Render the pixel art as a color-by-number board: part already painted,
    the rest shown as numbered white cells to be filled.
    mode: 'bottom' (paint bottom filled_frac) or 'left' (paint left half)."""
    w, h, rows, cmap = load_grid(name)
    img = Image.new("RGBA", (w * cell, h * cell), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    # stable per-color number labels (1..n) for the legend
    keys = sorted(cmap.keys(), key=int)
    label = {k: str(i + 1) for i, k in enumerate(keys)}
    nfont = ImageFont.truetype(SANSB, max(8, int(cell * 0.55)))
    fill_line = h * (1 - filled_frac)

    def is_painted(x, y):
        return x < w / 2 if mode == "left" else y >= fill_line

    for y, row in enumerate(rows):
        for x, v in enumerate(row):
            if v == "0" or v not in cmap:
                continue
            x0, y0 = x * cell, y * cell
            x1, y1 = x0 + cell - 1, y0 + cell - 1
            if is_painted(x, y):                      # already painted
                r, g, b = cmap[v]
                dr.rectangle([x0, y0, x1, y1], fill=(r, g, b, 255),
                             outline=(0, 0, 0, 30))
            else:                                     # to-fill: white cell + number
                dr.rectangle([x0, y0, x1, y1], fill=(255, 255, 255, 255),
                             outline=(205, 205, 205, 255))
                t = label[v]
                tw = dr.textlength(t, font=nfont)
                bb = nfont.getbbox(t)
                dr.text((x0 + (cell - tw) / 2, y0 + (cell - (bb[3] - bb[1])) / 2 - bb[1]),
                        t, font=nfont, fill=(120, 120, 120, 255))
    return img, [(label[k], cmap[k]) for k in keys]

def glow(size, color, blur):
    # blur an alpha MASK (not RGBA) so transparent-black doesn't bleed dark edges;
    # pad the ellipse inside the canvas so the blur fades to 0 (no square halo).
    r, g, b, a = color
    pad = int(blur * 1.6)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).ellipse([pad, pad, size[0] - pad, size[1] - pad], fill=a)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", size, (r, g, b, 0))
    out.putalpha(mask)
    return out

def sunburst(draw, cx, cy, r, n, color):
    for i in range(n):
        a = (2 * math.pi / n) * i
        x2, y2 = cx + r * math.cos(a), cy + r * math.sin(a)
        draw.line([cx, cy, x2, y2], fill=color, width=2)

# ---------- ICON 512x512 ----------
def build_icon():
    S = 512
    img = radial_bg((S, S), lerp(SAFF, GOLD, 0.25), DEEP, cy=0.45, power=1.05).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    # faint rays
    sunburst(d, S * 0.5, S * 0.45, S * 0.7, 48, (255, 210, 120, 22))
    # warm glow behind the deity
    gl = glow((int(S * 0.86), int(S * 0.86)), (255, 165, 35, 150), 90)
    img.alpha_composite(gl, ((S - gl.size[0]) // 2, int(S * 0.07)))
    # pixelated Lord Ganesha as a color-by-number board: left painted, right to-fill
    art, _ = render_color_by_number("ganesha", 17, mode="left")   # 24*17 = 408
    aw, ah = art.size
    img.alpha_composite(art, ((S - aw) // 2, (S - ah) // 2))
    # subtle vignette ring
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([8, 8, S - 8, S - 8], outline=(255, 205, 110, 70), width=6)
    img.alpha_composite(ring)
    img.save(os.path.join(OUT, "icon.png"), "PNG", optimize=True)  # 32-bit RGBA
    print("icon.png  512x512 (32-bit)")
    return img

# ---------- FEATURE GRAPHIC 1024x500 ----------
def fit_font(path, text, target_w, lo=10, hi=200):
    while lo < hi:
        mid = (lo + hi + 1) // 2
        f = ImageFont.truetype(path, mid)
        if f.getlength(text) <= target_w:
            lo = mid
        else:
            hi = mid - 1
    return ImageFont.truetype(path, lo)

def text_shadow(d, xy, text, font, fill, shadow=(0, 0, 0, 160), off=3):
    d.text((xy[0] + off, xy[1] + off), text, font=font, fill=shadow)
    d.text(xy, text, font=font, fill=fill)

def rounded_panel(size, radius, fill):
    p = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(p).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                        radius=radius, fill=fill)
    return p

def build_feature(icon_img):
    W, H = 1024, 500
    img = radial_bg((W, H), MID, DEEP, cx=0.27, cy=0.5, power=0.9).convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    sunburst(d, W * 0.26, H * 0.5, W * 0.62, 60, (255, 200, 110, 18))

    # ---- left: color-by-number board on a light "canvas" panel ----
    cell = 19                                     # 16*19 = 304 board
    board, legend = render_color_by_number("diya", cell, filled_frac=0.5)
    bw, bh = board.size
    pad = 26
    panel = rounded_panel((bw + pad * 2, bh + pad * 2 + 44), 28, (250, 248, 242, 255))
    pgl = glow((panel.size[0] + 80, panel.size[1] + 80), (255, 170, 45, 130), 55)
    px, py = 46, (H - panel.size[1]) // 2
    img.alpha_composite(pgl, (px - 40, py - 40))
    img.alpha_composite(panel, (px, py))
    img.alpha_composite(board, (px + pad, py + pad))
    # numbered color palette strip under the board (the "by number" key)
    chip = 30
    n = len(legend)
    strip_w = n * (chip + 8) - 8
    sx = px + (panel.size[0] - strip_w) // 2
    sy = py + pad + bh + 8
    cf = ImageFont.truetype(SANSB, 15)
    pd = ImageDraw.Draw(img, "RGBA")
    for i, (lab, (r, g, b)) in enumerate(legend):
        cx0 = sx + i * (chip + 8)
        pd.rounded_rectangle([cx0, sy, cx0 + chip, sy + chip], radius=7,
                             fill=(r, g, b, 255), outline=(0, 0, 0, 40))
        tw = pd.textlength(lab, font=cf)
        bb = cf.getbbox(lab)
        # contrast-aware label colour
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        col = (40, 40, 40, 255) if lum > 150 else (255, 255, 255, 235)
        pd.text((cx0 + (chip - tw) / 2, sy + (chip - (bb[3] - bb[1])) / 2 - bb[1]),
                lab, font=cf, fill=col)

    # ---- right: title + taglines ----
    tx = 470
    title_f = fit_font(SERIF, "Bhakti Rang", W - tx - 36)
    text_shadow(d, (tx, 96), "Bhakti Rang", title_f, GOLD)
    sub_f = ImageFont.truetype(SANSB, 34)
    text_shadow(d, (tx, 208), "Color by Number", sub_f, CREAM, off=2)
    tag_f = ImageFont.truetype(SANS, 27)
    text_shadow(d, (tx, 256), "Tap the numbers to paint Hindu gods", tag_f, (255, 226, 172), off=2)
    text_shadow(d, (tx, 292), "& goddesses, pixel by pixel.", tag_f, (255, 226, 172), off=2)
    star_f = ImageFont.truetype(SANSB, 28)
    d.text((tx, 352), "★ ★ ★ ★ ★    100% Offline", font=star_f, fill=GOLD)

    img.convert("RGB").save(os.path.join(OUT, "featureGraphic.png"), "PNG", optimize=True)
    print("featureGraphic.png  1024x500 (color-by-number)")

if __name__ == "__main__":
    # Safety check for premium manually optimized store assets
    if len(sys.argv) < 2 or sys.argv[1] != "--force":
        print("WARNING: Premium, high-quality generated store assets are currently active in the metadata folder.")
        print("Running this script will overwrite them with programmatic pixel art.")
        print("If you really want to overwrite and regenerate programmatic assets, run:")
        print("  python3 tool/make_devotional_store_assets.py --force")
        sys.exit(0)

    icon = build_icon()
    build_feature(icon)
    print("done ->", OUT)
