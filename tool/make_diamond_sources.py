#!/usr/bin/env python3
"""Procedural source-image generator for the diamond (GemArt) flavor catalog.

Draws every artwork at 8x supersample with PIL vector primitives, then
NEAREST-downsamples to the exact grid size. build_artworks.py's BOX resize is
then an identity op, so colors stay flat and edges crisp — ideal input for the
top-N quantizer.

Usage:
    python3 tool/make_diamond_sources.py           # all artworks
    python3 tool/make_diamond_sources.py id1 id2   # only these ids
Then:
    python3 tool/build_artworks.py diamond
"""
import math, os, random, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tool", "diamond_sources")
S = 8  # supersample factor

random.seed(7)

# ---------------------------------------------------------------- helpers

def rot0(pts, ang):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return [(x * ca - y * sa, x * sa + y * ca) for x, y in pts]


def rot_about(pts, cx, cy, ang):
    return [(cx + x, cy + y) for x, y in rot0([(x - cx, y - cy) for x, y in pts], ang)]


def ngon(cx, cy, r, n, rot=-90):
    return [(cx + r * math.cos(math.radians(rot + i * 360 / n)),
             cy + r * math.sin(math.radians(rot + i * 360 / n))) for i in range(n)]


def star_pts(cx, cy, r_out, r_in, n, rot=-90):
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def circle(d, cx, cy, r, fill=None, outline=None, width=1):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=int(width))


def petal_pts(cx, cy, ang, r0, r1, w, n=20):
    """Teardrop petal from radius r0 to r1 pointing along ang (deg), half-width w."""
    side1, side2 = [], []
    for i in range(n + 1):
        t = i / n
        r = r0 + (r1 - r0) * t
        o = w * math.sin(math.pi * min(1.0, t * 1.15))
        side1.append((r, o))
        side2.append((r, -o))
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    pts = side1 + side2[::-1]
    return [(cx + r * ca - o * sa, cy + r * sa + o * ca) for r, o in pts]


def ring_petals(d, cx, cy, k, r0, r1, w, fill, rot=0, outline=None):
    for i in range(k):
        d.polygon(petal_pts(cx, cy, rot + i * 360 / k, r0, r1, w), fill=fill, outline=outline)


def ring_dots(d, cx, cy, k, r, dot_r, fill, rot=0):
    for i in range(k):
        a = math.radians(rot + i * 360 / k)
        circle(d, cx + r * math.cos(a), cy + r * math.sin(a), dot_r, fill=fill)


def ring_diamonds(d, cx, cy, k, r0, r1, w, fill, rot=0):
    for i in range(k):
        a = rot + i * 360 / k
        rm = (r0 + r1) / 2
        pts = [(r0, 0), (rm, w), (r1, 0), (rm, -w)]
        ar = math.radians(a)
        ca, sa = math.cos(ar), math.sin(ar)
        d.polygon([(cx + r * ca - o * sa, cy + r * sa + o * ca) for r, o in pts], fill=fill)


def sparkle(d, x, y, r, fill=(255, 255, 255, 255)):
    d.polygon([(x, y - r), (x + r * 0.22, y - r * 0.22), (x + r, y),
               (x + r * 0.22, y + r * 0.22), (x, y + r),
               (x - r * 0.22, y + r * 0.22), (x - r, y),
               (x - r * 0.22, y - r * 0.22)], fill=fill)


def crystal(d, x, y, w, h, ang, body, face, tipf=0.32):
    """Pointed hexagonal crystal standing on base center (x, y), rotated ang deg."""
    pts = [(-w / 2, 0), (-w / 2, -h * (1 - tipf)), (0, -h),
           (w / 2, -h * (1 - tipf)), (w / 2, 0)]
    d.polygon([(x + px, y + py) for px, py in rot0(pts, ang)], fill=body)
    fpts = [(-w / 2, 0), (-w / 2, -h * (1 - tipf)), (0, -h),
            (-w / 8, -h * (1 - tipf)), (-w / 8, 0)]
    d.polygon([(x + px, y + py) for px, py in rot0(fpts, ang)], fill=face)


def heart_pts(cx, cy, size, n=64):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * size / 16, cy - y * size / 16))
    return pts


def teardrop_pts(cx, cy, r, apex_y, n=40):
    """Circle of radius r centred (cx, cy) with an apex pulled up to apex_y."""
    pts = [(cx, apex_y)]
    for i in range(n + 1):
        a = math.radians(-55 + 290 * i / n)
        pts.append((cx + r * math.sin(a + math.pi), cy - r * math.cos(a + math.pi)))
    return pts


ARTS = {}


def art(aid, grid):
    def deco(fn):
        ARTS[aid] = (grid, fn)
        return fn
    return deco


# ---------------------------------------------------------------- gems

@art("diamond_heart", 32)
def _(im, d, C):
    c = C / 2
    d.polygon(heart_pts(c, c * 1.02, C * 0.44), fill=(155, 25, 60, 255))
    d.polygon(heart_pts(c, c * 1.02, C * 0.38), fill=(220, 45, 90, 255))
    d.polygon(heart_pts(c, c * 1.0, C * 0.24), fill=(245, 105, 145, 255))
    # facet chords
    for ang in (-50, 0, 50):
        a = math.radians(ang)
        d.line([(c, c * 0.72), (c + C * 0.30 * math.sin(a), c * 0.72 + C * 0.34 * math.cos(a))],
               fill=(155, 25, 60, 255), width=S // 2)
    circle(d, c - C * 0.16, c * 0.68, C * 0.045, fill=(255, 230, 240, 255))
    sparkle(d, c + C * 0.26, c * 0.52, C * 0.07)


@art("ruby_gem", 32)
def _(im, d, C):
    c = C / 2
    R = C * 0.46
    circle(d, c, c, R, fill=(120, 10, 40, 255))
    # kite facets between table and girdle
    tab = ngon(c, c, R * 0.52, 8, rot=-90)
    gir = ngon(c, c, R * 0.94, 8, rot=-67.5)
    for i in range(8):
        col = (200, 30, 70, 255) if i % 2 == 0 else (160, 15, 55, 255)
        d.polygon([tab[i], gir[i], tab[(i + 1) % 8]], fill=col)
    d.polygon(tab, fill=(235, 70, 110, 255))
    d.polygon(ngon(c, c, R * 0.30, 8, rot=-90), fill=(250, 130, 160, 255))
    sparkle(d, c - R * 0.28, c - R * 0.35, C * 0.06)


@art("emerald_cut", 32)
def _(im, d, C):
    c = C / 2
    w, h = C * 0.36, C * 0.46

    def oct_rect(fw, fh, cut):
        return [(c - fw + cut, c - fh), (c + fw - cut, c - fh), (c + fw, c - fh + cut),
                (c + fw, c + fh - cut), (c + fw - cut, c + fh), (c - fw + cut, c + fh),
                (c - fw, c + fh - cut), (c - fw, c - fh + cut)]

    steps = [(1.0, (6, 95, 70, 255)), (0.78, (16, 140, 96, 255)),
             (0.56, (40, 185, 125, 255)), (0.34, (110, 225, 170, 255))]
    outer = oct_rect(w, h, C * 0.09)
    for f, col in steps:
        d.polygon(oct_rect(w * f, h * f, C * 0.09 * f), fill=col)
    inner = oct_rect(w * 0.34, h * 0.34, C * 0.09 * 0.34)
    for o, i2 in zip(outer, inner):
        d.line([o, i2], fill=(6, 95, 70, 255), width=S // 2)
    sparkle(d, c + w * 0.55, c - h * 0.62, C * 0.055)


@art("sapphire_teardrop", 32)
def _(im, d, C):
    c = C / 2
    d.polygon(teardrop_pts(c, C * 0.60, C * 0.335, C * 0.05), fill=(15, 40, 110, 255))
    d.polygon(teardrop_pts(c, C * 0.61, C * 0.27, C * 0.14), fill=(30, 80, 180, 255))
    d.polygon(teardrop_pts(c, C * 0.63, C * 0.185, C * 0.30), fill=(70, 130, 230, 255))
    circle(d, c - C * 0.09, C * 0.55, C * 0.05, fill=(180, 215, 255, 255))
    sparkle(d, c + C * 0.20, C * 0.42, C * 0.07)


@art("sapphire_star", 48)
def _(im, d, C):
    c = C / 2
    R = C * 0.44
    d.polygon(ngon(c, c, R, 6), fill=(10, 30, 90, 255))
    d.polygon(ngon(c, c, R * 0.80, 6), fill=(25, 65, 160, 255))
    d.polygon(ngon(c, c, R * 0.52, 6), fill=(55, 110, 215, 255))
    # 6-ray asterism
    for i in range(6):
        a = i * 60 - 90
        d.polygon(petal_pts(c, c, a, 0, R * 0.88, C * 0.028), fill=(215, 235, 255, 255))
    circle(d, c, c, C * 0.05, fill=(255, 255, 255, 255))
    sparkle(d, c + R * 0.5, c - R * 0.55, C * 0.05)


@art("crystal_cluster", 48)
def _(im, d, C):
    base_y = C * 0.88
    d.ellipse([C * 0.10, base_y - C * 0.07, C * 0.90, base_y + C * 0.07],
              fill=(70, 60, 95, 255))
    crystal(d, C * 0.28, base_y, C * 0.15, C * 0.42, 24, (120, 70, 200, 255), (175, 130, 240, 255))
    crystal(d, C * 0.72, base_y, C * 0.15, C * 0.40, -22, (35, 140, 170, 255), (95, 200, 220, 255))
    crystal(d, C * 0.50, base_y, C * 0.20, C * 0.66, 0, (150, 90, 230, 255), (200, 160, 250, 255))
    crystal(d, C * 0.38, base_y, C * 0.11, C * 0.26, 10, (60, 175, 200, 255), (130, 225, 240, 255))
    crystal(d, C * 0.62, base_y, C * 0.11, C * 0.24, -10, (185, 120, 245, 255), (225, 180, 255, 255))
    sparkle(d, C * 0.50, C * 0.16, C * 0.045)
    sparkle(d, C * 0.22, C * 0.38, C * 0.035)
    sparkle(d, C * 0.80, C * 0.42, C * 0.035)


@art("opal_cluster", 48)
def _(im, d, C):
    c = C / 2
    rx, ry = C * 0.42, C * 0.34
    d.ellipse([c - rx - C * 0.03, c - ry - C * 0.03, c + rx + C * 0.03, c + ry + C * 0.03],
              fill=(200, 175, 140, 255))  # warm rim
    d.ellipse([c - rx, c - ry, c + rx, c + ry], fill=(240, 235, 225, 255))
    cols = [(90, 200, 210, 255), (245, 150, 180, 255), (150, 220, 130, 255),
            (170, 140, 235, 255), (250, 190, 110, 255), (120, 170, 240, 255)]
    rnd = random.Random(11)
    for i in range(16):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0, 0.72)
        x = c + rx * rr * math.cos(a)
        y = c + ry * rr * math.sin(a)
        pr = C * rnd.uniform(0.045, 0.085)
        circle(d, x, y, pr, fill=cols[i % len(cols)])
    circle(d, c - rx * 0.45, c - ry * 0.5, C * 0.05, fill=(255, 255, 255, 255))


@art("ruby_ring", 48)
def _(im, d, C):
    c = C / 2
    ring_c = C * 0.60
    circle(d, c, ring_c, C * 0.30, fill=(215, 170, 40, 255))
    circle(d, c, ring_c, C * 0.21, fill=(0, 0, 0, 0))
    d.arc([c - C * 0.30, ring_c - C * 0.30, c + C * 0.30, ring_c + C * 0.30],
          40, 140, fill=(160, 115, 20, 255), width=int(C * 0.045))
    # prongs
    for dx in (-0.10, 0.10):
        d.polygon([(c + C * dx - C * 0.03, C * 0.33), (c + C * dx + C * 0.03, C * 0.33),
                   (c + C * dx, C * 0.24)], fill=(235, 195, 70, 255))
    # ruby
    R = C * 0.155
    gc = C * 0.21
    d.polygon(ngon(c, gc, R, 6, rot=-90), fill=(140, 10, 45, 255))
    d.polygon(ngon(c, gc, R * 0.68, 6, rot=-90), fill=(210, 35, 80, 255))
    d.polygon(ngon(c, gc, R * 0.36, 6, rot=-90), fill=(245, 110, 145, 255))
    sparkle(d, c + R * 1.15, gc - R * 1.05, C * 0.045)
    sparkle(d, c - C * 0.30, ring_c + C * 0.12, C * 0.035)


@art("amethyst_geode", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(95, 90, 105, 255))       # rock
    circle(d, c, c, C * 0.415, fill=(150, 145, 165, 255))    # rind
    circle(d, c, c, C * 0.365, fill=(235, 230, 245, 255))    # quartz band
    circle(d, c, c, C * 0.31, fill=(55, 25, 95, 255))        # cavity
    rnd = random.Random(5)
    for i in range(16):
        a = i * 360 / 16 + rnd.uniform(-6, 6)
        depth = rnd.uniform(0.13, 0.22)
        base_r = C * 0.31
        half = math.radians(360 / 16 / 2 * 0.9)
        ar = math.radians(a)
        p1 = (c + base_r * math.cos(ar - half), c + base_r * math.sin(ar - half))
        p2 = (c + base_r * math.cos(ar + half), c + base_r * math.sin(ar + half))
        tip_r = base_r - C * depth
        tip = (c + tip_r * math.cos(ar), c + tip_r * math.sin(ar))
        col = (150, 90, 220, 255) if i % 2 == 0 else (115, 60, 190, 255)
        d.polygon([p1, p2, tip], fill=col)
    ring_dots(d, c, c, 8, C * 0.135, C * 0.028, (190, 150, 245, 255), rot=11)
    circle(d, c, c, C * 0.055, fill=(220, 195, 255, 255))
    sparkle(d, c - C * 0.10, c - C * 0.14, C * 0.035)


@art("treasure_chest", 64)
def _(im, d, C):
    # open lid
    d.polygon([(C * 0.14, C * 0.38), (C * 0.50, C * 0.10), (C * 0.86, C * 0.38)],
              fill=(96, 60, 30, 255))
    d.polygon([(C * 0.20, C * 0.375), (C * 0.50, C * 0.15), (C * 0.80, C * 0.375)],
              fill=(130, 85, 45, 255))
    # coin heap
    d.ellipse([C * 0.16, C * 0.30, C * 0.84, C * 0.56], fill=(235, 185, 60, 255))
    rnd = random.Random(3)
    for i in range(10):
        x = C * rnd.uniform(0.24, 0.76)
        y = C * rnd.uniform(0.33, 0.48)
        circle(d, x, y, C * 0.035, fill=(255, 215, 100, 255), outline=(190, 140, 30, 255), width=S // 2)
    # gems on heap
    d.polygon(ngon(C * 0.32, C * 0.36, C * 0.055, 6), fill=(60, 190, 110, 255))
    d.polygon(star_pts(C * 0.68, C * 0.35, C * 0.06, C * 0.03, 5), fill=(70, 130, 235, 255))
    d.polygon([(C * 0.50, C * 0.26), (C * 0.56, C * 0.32), (C * 0.50, C * 0.38), (C * 0.44, C * 0.32)],
              fill=(225, 50, 90, 255))
    # chest body
    d.rounded_rectangle([C * 0.14, C * 0.44, C * 0.86, C * 0.86], radius=C * 0.04,
                        fill=(130, 85, 45, 255))
    d.rectangle([C * 0.14, C * 0.44, C * 0.86, C * 0.50], fill=(96, 60, 30, 255))
    for fx in (0.17, 0.80):
        d.rectangle([C * fx, C * 0.44, C * (fx + 0.05), C * 0.86], fill=(215, 170, 40, 255))
    d.rectangle([C * 0.45, C * 0.44, C * 0.55, C * 0.86], fill=(215, 170, 40, 255))
    # lock
    d.rounded_rectangle([C * 0.44, C * 0.54, C * 0.56, C * 0.68], radius=C * 0.02,
                        fill=(255, 215, 100, 255))
    circle(d, C * 0.50, C * 0.60, C * 0.022, fill=(96, 60, 30, 255))
    sparkle(d, C * 0.24, C * 0.22, C * 0.05)
    sparkle(d, C * 0.78, C * 0.18, C * 0.04)


# ---------------------------------------------------------------- mandalas

@art("rose_mandala", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(90, 20, 55, 255))
    ring_petals(d, c, c, 12, C * 0.20, C * 0.46, C * 0.075, (200, 55, 110, 255))
    ring_petals(d, c, c, 12, C * 0.14, C * 0.36, C * 0.065, (235, 100, 150, 255), rot=15)
    ring_petals(d, c, c, 8, C * 0.06, C * 0.24, C * 0.06, (250, 155, 190, 255))
    circle(d, c, c, C * 0.10, fill=(255, 210, 225, 255))
    circle(d, c, c, C * 0.05, fill=(215, 170, 40, 255))
    ring_dots(d, c, c, 12, C * 0.44, C * 0.02, (255, 210, 225, 255), rot=15)


@art("lotus_jewel", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(10, 60, 75, 255))
    ring_petals(d, c, c, 10, C * 0.18, C * 0.46, C * 0.085, (25, 140, 150, 255))
    ring_petals(d, c, c, 10, C * 0.12, C * 0.35, C * 0.075, (60, 195, 190, 255), rot=18)
    ring_petals(d, c, c, 8, C * 0.05, C * 0.22, C * 0.06, (150, 230, 220, 255))
    # gem center
    R = C * 0.105
    d.polygon(ngon(c, c, R, 6), fill=(215, 170, 40, 255))
    d.polygon(ngon(c, c, R * 0.62, 6), fill=(255, 215, 100, 255))
    circle(d, c, c, R * 0.28, fill=(255, 245, 200, 255))
    ring_dots(d, c, c, 10, C * 0.43, C * 0.022, (255, 215, 100, 255), rot=18)


@art("sapphire_star_mandala", 48)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(12, 22, 60, 255))
    d.polygon(star_pts(c, c, C * 0.46, C * 0.26, 8), fill=(30, 70, 165, 255))
    d.polygon(star_pts(c, c, C * 0.36, C * 0.20, 8, rot=-90 + 22.5), fill=(70, 125, 220, 255))
    d.polygon(star_pts(c, c, C * 0.25, C * 0.14, 8), fill=(150, 190, 245, 255))
    d.polygon(ngon(c, c, C * 0.12, 8), fill=(220, 235, 255, 255))
    circle(d, c, c, C * 0.055, fill=(30, 70, 165, 255))
    ring_dots(d, c, c, 8, C * 0.42, C * 0.022, (220, 235, 255, 255), rot=22.5)


@art("sun_moon_mandala", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(35, 30, 75, 255))
    # sun rays left half, moon dots right half
    for i in range(16):
        a = i * 22.5
        if 90 < a < 270:  # left side rays (pointing left)
            d.polygon(petal_pts(c, c, a, C * 0.30, C * 0.46, C * 0.035),
                      fill=(250, 180, 60, 255))
        else:
            ar = math.radians(a)
            circle(d, c + C * 0.39 * math.cos(ar), c + C * 0.39 * math.sin(ar),
                   C * 0.022, fill=(200, 215, 245, 255))
    circle(d, c, c, C * 0.30, fill=(90, 80, 150, 255))
    # face disc: left sun gold, right moon silver (split by chord)
    R = C * 0.26
    d.pieslice([c - R, c - R, c + R, c + R], 90, 270, fill=(250, 200, 90, 255))
    d.pieslice([c - R, c - R, c + R, c + R], -90, 90, fill=(205, 215, 235, 255))
    d.pieslice([c - R * 0.82, c - R * 0.82, c + R * 0.82, c + R * 0.82], 90, 270,
               fill=(255, 225, 140, 255))
    # crescent on moon side
    circle(d, c + R * 0.45, c, R * 0.42, fill=(240, 245, 252, 255))
    circle(d, c + R * 0.62, c - R * 0.10, R * 0.34, fill=(205, 215, 235, 255))
    circle(d, c + R * 0.30, c - R * 0.55, C * 0.014, fill=(240, 245, 252, 255))
    circle(d, c + R * 0.75, c + R * 0.60, C * 0.014, fill=(240, 245, 252, 255))
    # sun eye + cheek
    circle(d, c - R * 0.45, c - R * 0.15, C * 0.016, fill=(140, 80, 20, 255))
    d.arc([c - R * 0.62, c + R * 0.18, c - R * 0.28, c + R * 0.45], 20, 160,
          fill=(140, 80, 20, 255), width=S // 2)


@art("snowflake_mandala", 48)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(20, 45, 95, 255))
    circle(d, c, c, C * 0.42, fill=(45, 90, 160, 255))
    for i in range(6):
        a = i * 60
        # main arm
        d.polygon(petal_pts(c, c, a, 0, C * 0.42, C * 0.030), fill=(235, 245, 255, 255))
        # side branches
        for f, br in ((0.22, 0.12), (0.32, 0.09)):
            ar = math.radians(a)
            bx, by = c + C * f * math.cos(ar), c + C * f * math.sin(ar)
            for da in (-55, 55):
                d.polygon(petal_pts(bx, by, a + da, 0, C * br, C * 0.018),
                          fill=(170, 210, 250, 255))
    d.polygon(ngon(c, c, C * 0.10, 6), fill=(170, 210, 250, 255))
    d.polygon(ngon(c, c, C * 0.055, 6), fill=(235, 245, 255, 255))
    ring_dots(d, c, c, 6, C * 0.45, C * 0.02, (170, 210, 250, 255), rot=30)


@art("ocean_wave_mandala", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(10, 45, 80, 255))
    # scalloped wave rings
    for r, k, col in [(0.44, 14, (20, 110, 150, 255)), (0.35, 12, (35, 160, 185, 255)),
                      (0.26, 10, (80, 200, 210, 255)), (0.17, 8, (150, 230, 230, 255))]:
        for i in range(k):
            a = math.radians(i * 360 / k)
            x, y = c + C * r * 0.82 * math.cos(a), c + C * r * 0.82 * math.sin(a)
            circle(d, x, y, C * r * 0.30, fill=col)
    # pearls
    ring_dots(d, c, c, 12, C * 0.41, C * 0.020, (240, 245, 250, 255), rot=15)
    circle(d, c, c, C * 0.085, fill=(240, 245, 250, 255))
    circle(d, c - C * 0.025, c - C * 0.025, C * 0.030, fill=(255, 255, 255, 255))
    circle(d, c, c, C * 0.085, outline=(20, 110, 150, 255), width=S // 2)


@art("diwali_diya_mandala", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.47, fill=(80, 20, 60, 255))
    ring_petals(d, c, c, 14, C * 0.30, C * 0.46, C * 0.055, (235, 120, 40, 255))
    ring_petals(d, c, c, 14, C * 0.26, C * 0.38, C * 0.045, (250, 180, 60, 255), rot=180 / 14)
    ring_dots(d, c, c, 14, C * 0.43, C * 0.018, (255, 230, 150, 255), rot=180 / 14)
    circle(d, c, c, C * 0.26, fill=(150, 40, 90, 255))
    circle(d, c, c, C * 0.22, fill=(105, 25, 70, 255))
    # diya bowl
    d.pieslice([c - C * 0.16, c - C * 0.04, c + C * 0.16, c + C * 0.28], 0, 180,
               fill=(190, 85, 35, 255))
    d.pieslice([c - C * 0.12, c - C * 0.01, c + C * 0.12, c + C * 0.22], 0, 180,
               fill=(230, 130, 60, 255))
    # flame
    d.polygon(teardrop_pts(c, c - C * 0.115, C * 0.055, c - C * 0.24),
              fill=(250, 180, 60, 255))
    d.polygon(teardrop_pts(c, c - C * 0.105, C * 0.032, c - C * 0.185),
              fill=(255, 235, 160, 255))
    ring_dots(d, c, c, 8, C * 0.245, C * 0.014, (250, 180, 60, 255), rot=22.5)


# ---------------------------------------------------------------- nature

@art("peony_bloom", 48)
def _(im, d, C):
    c = C / 2
    ring_petals(d, c, c, 10, C * 0.10, C * 0.47, C * 0.10, (215, 70, 120, 255))
    ring_petals(d, c, c, 10, C * 0.08, C * 0.38, C * 0.09, (240, 110, 155, 255), rot=18)
    ring_petals(d, c, c, 8, C * 0.05, C * 0.28, C * 0.08, (250, 150, 185, 255))
    ring_petals(d, c, c, 6, C * 0.02, C * 0.17, C * 0.06, (255, 195, 215, 255), rot=30)
    circle(d, c, c, C * 0.065, fill=(250, 205, 90, 255))
    ring_dots(d, c, c, 6, C * 0.045, C * 0.017, (215, 150, 40, 255))


@art("tulip_field", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C * 0.42], fill=(165, 215, 245, 255))     # sky
    circle(d, C * 0.80, C * 0.14, C * 0.09, fill=(255, 225, 130, 255))  # sun
    d.rectangle([0, C * 0.42, C, C], fill=(90, 165, 80, 255))       # field
    rows = [(0.50, 0.11, (225, 60, 70, 255)), (0.66, 0.13, (250, 180, 60, 255)),
            (0.84, 0.15, (220, 80, 160, 255))]
    for yc, size, col in rows:
        n = 4
        for i in range(n):
            x = C * (0.14 + 0.24 * i + (0.10 if yc == 0.66 else 0))
            y = C * yc
            sz = C * size
            # stem + leaves
            d.line([(x, y), (x, y + sz * 1.1)], fill=(45, 110, 50, 255), width=int(C * 0.018))
            d.polygon(petal_pts(x, y + sz * 0.8, -160, 0, sz * 0.6, sz * 0.16),
                      fill=(45, 110, 50, 255))
            # tulip cup: three tips
            d.polygon([(x - sz * 0.42, y - sz * 0.42), (x - sz * 0.42, y + sz * 0.25),
                       (x + sz * 0.42, y + sz * 0.25), (x + sz * 0.42, y - sz * 0.42),
                       (x + sz * 0.21, y - sz * 0.10), (x, y - sz * 0.45),
                       (x - sz * 0.21, y - sz * 0.10)], fill=col)
    d.ellipse([C * 0.10, C * 0.06, C * 0.34, C * 0.14], fill=(255, 255, 255, 255))
    d.ellipse([C * 0.42, C * 0.16, C * 0.62, C * 0.23], fill=(255, 255, 255, 255))


@art("butterfly_wing", 48)
def _(im, d, C):
    # full stained-glass butterfly
    c = C / 2
    lead = (35, 25, 45, 255)
    for sx in (-1, 1):
        up, lo = 90 - sx * 128, 90 - sx * 38
        # upper wing: nested colored petals
        d.polygon(petal_pts(c, c * 0.94, up, 0, C * 0.47, C * 0.155), fill=lead)
        d.polygon(petal_pts(c, c * 0.94, up, C * 0.02, C * 0.44, C * 0.125),
                  fill=(120, 70, 200, 255))
        d.polygon(petal_pts(c, c * 0.94, up, C * 0.10, C * 0.40, C * 0.085),
                  fill=(60, 190, 210, 255))
        d.polygon(petal_pts(c, c * 0.94, up, C * 0.20, C * 0.36, C * 0.05),
                  fill=(250, 180, 60, 255))
        # lower wing
        d.polygon(petal_pts(c, c * 1.06, lo, 0, C * 0.36, C * 0.13), fill=lead)
        d.polygon(petal_pts(c, c * 1.06, lo, C * 0.02, C * 0.33, C * 0.10),
                  fill=(225, 90, 180, 255))
        d.polygon(petal_pts(c, c * 1.06, lo, C * 0.09, C * 0.28, C * 0.06),
                  fill=(250, 130, 90, 255))
        # eye-dot on upper wing
        a = math.radians(up)
        circle(d, c + C * 0.34 * math.cos(a), c * 0.94 + C * 0.34 * math.sin(a),
               C * 0.026, fill=(255, 255, 255, 255))
    # body + antennae
    d.ellipse([c - C * 0.035, c * 0.62, c + C * 0.035, c * 1.40], fill=lead)
    circle(d, c, c * 0.58, C * 0.05, fill=lead)
    for sx in (-1, 1):
        d.line([(c, c * 0.56), (c + sx * C * 0.09, c * 0.38)], fill=lead, width=S // 2)
        circle(d, c + sx * C * 0.09, c * 0.38, C * 0.014, fill=(250, 180, 60, 255))


@art("peacock_jewel", 64)
def _(im, d, C):
    c = C / 2
    cy = C * 0.58
    # feather fan
    for i in range(9):
        a = -180 + i * 22.5
        d.polygon(petal_pts(c, cy, a, C * 0.10, C * 0.52, C * 0.085),
                  fill=(15, 105, 90, 255))
        d.polygon(petal_pts(c, cy, a, C * 0.12, C * 0.48, C * 0.062),
                  fill=(30, 160, 130, 255))
        ar = math.radians(a)
        ex, ey = c + C * 0.375 * math.cos(ar), cy + C * 0.375 * math.sin(ar)
        circle(d, ex, ey, C * 0.052, fill=(250, 180, 60, 255))
        circle(d, ex, ey, C * 0.036, fill=(25, 65, 160, 255))
        circle(d, ex, ey, C * 0.018, fill=(120, 210, 230, 255))
    # body
    d.ellipse([c - C * 0.085, cy - C * 0.10, c + C * 0.085, cy + C * 0.26],
              fill=(25, 65, 160, 255))
    circle(d, c, cy - C * 0.13, C * 0.062, fill=(35, 90, 200, 255))
    # beak + crest
    d.polygon([(c + C * 0.05, cy - C * 0.145), (c + C * 0.105, cy - C * 0.125),
               (c + C * 0.05, cy - C * 0.105)], fill=(250, 180, 60, 255))
    for da in (-25, 0, 25):
        ar = math.radians(-90 + da)
        tx, ty = c + C * 0.115 * math.cos(ar), cy - C * 0.13 + C * 0.115 * math.sin(ar)
        d.line([(c, cy - C * 0.13), (tx, ty)], fill=(30, 160, 130, 255), width=S // 2)
        circle(d, tx, ty, C * 0.014, fill=(120, 210, 230, 255))
    circle(d, c + C * 0.022, cy - C * 0.145, C * 0.010, fill=(10, 10, 20, 255))


@art("hummingbird_hibiscus", 48)
def _(im, d, C):
    # hibiscus lower-left
    fx, fy = C * 0.30, C * 0.68
    for i in range(5):
        d.polygon(petal_pts(fx, fy, i * 72 - 90, C * 0.03, C * 0.24, C * 0.085),
                  fill=(235, 80, 130, 255))
    for i in range(5):
        d.polygon(petal_pts(fx, fy, i * 72 - 90, C * 0.02, C * 0.15, C * 0.05),
                  fill=(250, 140, 175, 255))
    circle(d, fx, fy, C * 0.045, fill=(150, 30, 70, 255))
    d.line([(fx, fy), (fx + C * 0.13, fy - C * 0.16)], fill=(250, 200, 90, 255),
           width=int(C * 0.022))
    circle(d, fx + C * 0.13, fy - C * 0.16, C * 0.025, fill=(250, 200, 90, 255))
    # hummingbird upper-right, angled down toward flower
    bx, by = C * 0.68, C * 0.30
    # tail up-right
    d.polygon(petal_pts(bx + C * 0.08, by - C * 0.06, -40, 0, C * 0.26, C * 0.055),
              fill=(35, 90, 130, 255))
    # body tilted toward flower
    d.polygon(petal_pts(bx, by, 140, -C * 0.14, C * 0.14, C * 0.085),
              fill=(40, 165, 120, 255))
    # head
    hx, hy = bx - C * 0.115, by + C * 0.085
    circle(d, hx, hy, C * 0.075, fill=(30, 140, 105, 255))
    # ruby throat
    d.pieslice([hx - C * 0.075, hy - C * 0.045, hx + C * 0.045, hy + C * 0.075],
               60, 200, fill=(220, 40, 80, 255))
    # beak from head toward flower center
    d.polygon([(hx - C * 0.045, hy + C * 0.035), (fx + C * 0.02, fy - C * 0.03),
               (hx + C * 0.005, hy + C * 0.065)], fill=(40, 35, 45, 255))
    # wing swept up
    d.polygon(petal_pts(bx - C * 0.01, by + C * 0.01, -100, C * 0.02, C * 0.26, C * 0.065),
              fill=(60, 200, 160, 255))
    circle(d, hx - C * 0.025, hy - C * 0.025, C * 0.014, fill=(10, 10, 20, 255))
    sparkle(d, C * 0.86, C * 0.72, C * 0.03)


@art("koi_pond", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.48, fill=(15, 65, 90, 255))
    circle(d, c, c, C * 0.44, fill=(25, 95, 120, 255))
    # ripples
    for r in (0.36, 0.25):
        circle(d, c, c, C * r, outline=(60, 140, 160, 255), width=S // 2)

    def koi(cx, cy, ang, body, patch):
        ar = math.radians(ang)
        ca, sa = math.cos(ar), math.sin(ar)

        def at(f, o=0.0):
            return (cx + C * f * ca - C * o * sa, cy + C * f * sa + C * o * ca)

        # tail fin (two lobes), then tapering body over it
        for da in (-28, 28):
            d.polygon(petal_pts(*at(-0.15), ang + 180 + da, 0, C * 0.13, C * 0.045),
                      fill=patch)
        body_pts = ([at(f, w) for f, w in [(-0.16, 0.015), (-0.08, 0.055), (0.04, 0.075),
                                           (0.14, 0.060), (0.20, 0.030)]] +
                    [at(f, -w) for f, w in [(0.20, 0.030), (0.14, 0.060), (0.04, 0.075),
                                            (-0.08, 0.055), (-0.16, 0.015)]])
        d.polygon(body_pts, fill=body)
        # head cap + back patch
        circle(d, *at(0.155), C * 0.048, fill=patch)
        circle(d, *at(-0.01, 0.02), C * 0.042, fill=patch)
        # side fins + eyes
        for so in (-1, 1):
            d.polygon(petal_pts(*at(0.09, so * 0.06), ang + so * 115, 0, C * 0.07, C * 0.028),
                      fill=body)
            circle(d, *at(0.175, so * 0.028), C * 0.010, fill=(20, 25, 35, 255))

    koi(c - C * 0.18, c - C * 0.14, 230, (245, 245, 240, 255), (230, 100, 40, 255))
    koi(c + C * 0.19, c + C * 0.16, 50, (235, 120, 45, 255), (245, 245, 240, 255))
    # lily pads
    for px, py, r in [(0.72, 0.28, 0.10), (0.30, 0.74, 0.085), (0.24, 0.30, 0.06)]:
        d.pieslice([C * (px - r), C * (py - r), C * (px + r), C * (py + r)],
                   25, 335, fill=(60, 150, 80, 255))
    circle(d, C * 0.72, C * 0.28, C * 0.028, fill=(240, 150, 190, 255))


@art("crystal_rose", 32)
def _(im, d, C):
    c = C / 2
    # faceted petals: rotated squares shrinking inward
    layers = [(0.46, 0, (140, 20, 70, 255)), (0.38, 22.5, (190, 45, 100, 255)),
              (0.30, 45, (225, 80, 130, 255)), (0.22, 67.5, (245, 120, 160, 255)),
              (0.14, 90, (250, 165, 195, 255))]
    for r, rot, col in layers:
        d.polygon(ngon(c, c, C * r, 8, rot=-90 + rot), fill=col)
    d.polygon(ngon(c, c, C * 0.075, 8), fill=(255, 210, 225, 255))
    sparkle(d, c + C * 0.28, c - C * 0.30, C * 0.05)


@art("dragonfly_wings", 48)
def _(im, d, C):
    c = C / 2
    # 4 wings with paneled cells
    wings = [(-38, (150, 200, 245, 255), (190, 225, 250, 255)),
             (-142, (150, 200, 245, 255), (190, 225, 250, 255)),
             (22, (185, 160, 240, 255), (215, 195, 250, 255)),
             (158, (185, 160, 240, 255), (215, 195, 250, 255))]
    for ang, col_a, col_b in wings:
        d.polygon(petal_pts(c, C * 0.40, ang, C * 0.04, C * 0.44, C * 0.075), fill=col_a)
        d.polygon(petal_pts(c, C * 0.40, ang, C * 0.10, C * 0.40, C * 0.045), fill=col_b)
        ar = math.radians(ang)
        for f in (0.18, 0.28):
            circle(d, c + C * f * math.cos(ar), C * 0.40 + C * f * math.sin(ar),
                   C * 0.016, fill=col_a)
    # body
    circle(d, c, C * 0.24, C * 0.062, fill=(50, 170, 150, 255))          # head
    circle(d, c - C * 0.035, C * 0.225, C * 0.018, fill=(20, 40, 60, 255))
    circle(d, c + C * 0.035, C * 0.225, C * 0.018, fill=(20, 40, 60, 255))
    d.ellipse([c - C * 0.05, C * 0.29, c + C * 0.05, C * 0.44], fill=(35, 140, 125, 255))
    for i in range(5):
        y = C * (0.46 + i * 0.085)
        d.ellipse([c - C * 0.032, y, c + C * 0.032, y + C * 0.07],
                  fill=(50, 170, 150, 255) if i % 2 == 0 else (35, 140, 125, 255))


@art("cherry_blossom", 48)
def _(im, d, C):
    # branch
    d.line([(C * 0.02, C * 0.88), (C * 0.45, C * 0.55), (C * 0.95, C * 0.30)],
           fill=(105, 70, 50, 255), width=int(C * 0.045), joint="curve")
    d.line([(C * 0.45, C * 0.55), (C * 0.60, C * 0.75)], fill=(105, 70, 50, 255),
           width=int(C * 0.032))
    d.line([(C * 0.68, C * 0.43), (C * 0.80, C * 0.62)], fill=(105, 70, 50, 255),
           width=int(C * 0.028))

    def blossom(x, y, r):
        for i in range(5):
            d.polygon(petal_pts(C * x, C * y, i * 72 - 90, C * 0.01, r, r * 0.42),
                      fill=(250, 190, 210, 255))
        circle(d, C * x, C * y, r * 0.22, fill=(230, 90, 130, 255))
        ring_dots(d, C * x, C * y, 5, r * 0.42, r * 0.07, (250, 220, 120, 255))

    blossom(0.22, 0.62, C * 0.115)
    blossom(0.48, 0.38, C * 0.135)
    blossom(0.78, 0.20, C * 0.115)
    blossom(0.62, 0.78, C * 0.10)
    blossom(0.85, 0.55, C * 0.095)
    for x, y in [(0.34, 0.46), (0.60, 0.30), (0.72, 0.66)]:
        circle(d, C * x, C * y, C * 0.030, fill=(240, 140, 170, 255))


@art("sea_turtle_shell", 64)
def _(im, d, C):
    c = C / 2
    d.ellipse([c - C * 0.38, C * 0.06, c + C * 0.38, C * 0.94], fill=(70, 110, 60, 255))
    d.ellipse([c - C * 0.33, C * 0.11, c + C * 0.33, C * 0.89], fill=(110, 160, 80, 255))
    # central scute column + side plates as hex grid
    hexes = [(0.5, 0.24, 0.105, (200, 215, 110, 255)), (0.5, 0.46, 0.12, (170, 200, 90, 255)),
             (0.5, 0.70, 0.105, (200, 215, 110, 255)),
             (0.335, 0.33, 0.095, (45, 140, 110, 255)), (0.665, 0.33, 0.095, (45, 140, 110, 255)),
             (0.325, 0.58, 0.10, (35, 115, 130, 255)), (0.675, 0.58, 0.10, (35, 115, 130, 255)),
             (0.40, 0.80, 0.08, (45, 140, 110, 255)), (0.60, 0.80, 0.08, (45, 140, 110, 255))]
    for x, y, r, col in hexes:
        d.polygon(ngon(C * x, C * y, C * r, 6, rot=-90), fill=col)
        d.polygon(ngon(C * x, C * y, C * r * 0.55, 6, rot=-90),
                  fill=tuple(min(255, v + 45) for v in col[:3]) + (255,))
    # rim scutes
    for i in range(12):
        a = math.radians(i * 30 + 15)
        x = c + C * 0.355 * math.cos(a)
        y = c + C * 0.44 * math.sin(a)
        circle(d, x, y, C * 0.032, fill=(200, 215, 110, 255))


@art("monarch_butterfly", 32)
def _(im, d, C):
    c = C / 2
    # wings: two upper, two lower
    for sx in (-1, 1):
        d.polygon(petal_pts(c, c * 0.92, 90 + sx * -125, C * 0.02, C * 0.46, C * 0.16),
                  fill=(30, 22, 25, 255))
        d.polygon(petal_pts(c, c * 0.92, 90 + sx * -125, C * 0.05, C * 0.42, C * 0.115),
                  fill=(240, 130, 40, 255))
        d.polygon(petal_pts(c, c * 1.10, 90 + sx * -35, C * 0.02, C * 0.36, C * 0.13),
                  fill=(30, 22, 25, 255))
        d.polygon(petal_pts(c, c * 1.10, 90 + sx * -35, C * 0.04, C * 0.32, C * 0.09),
                  fill=(250, 165, 60, 255))
        # veins on upper wing
        for f in (0.16, 0.28):
            ar = math.radians(-35 * sx - 90 + (0 if sx > 0 else 180))
        # white dots on dark edges
        aw = math.radians(90 + sx * -125)
        for f in (0.34, 0.42):
            circle(d, c + C * f * math.cos(aw), c * 0.92 + C * f * math.sin(aw) - C * 0.06,
                   C * 0.022, fill=(255, 255, 255, 255))
    # body
    d.ellipse([c - C * 0.035, c * 0.55, c + C * 0.035, c * 1.45], fill=(30, 22, 25, 255))
    circle(d, c, c * 0.52, C * 0.05, fill=(30, 22, 25, 255))
    d.line([(c, c * 0.50), (c - C * 0.09, c * 0.32)], fill=(30, 22, 25, 255), width=S // 2)
    d.line([(c, c * 0.50), (c + C * 0.09, c * 0.32)], fill=(30, 22, 25, 255), width=S // 2)


@art("tropical_parrot", 64)
def _(im, d, C):
    # branch
    d.line([(C * 0.08, C * 0.80), (C * 0.92, C * 0.72)], fill=(105, 70, 50, 255),
           width=int(C * 0.05))
    # tail feathers sweeping down-left
    for da, col in [(-14, (35, 80, 190, 255)), (0, (60, 190, 110, 255)),
                    (14, (250, 180, 60, 255))]:
        d.polygon(petal_pts(C * 0.46, C * 0.52, 118 + da, C * 0.05, C * 0.42, C * 0.045),
                  fill=col)
    # body
    d.ellipse([C * 0.38, C * 0.30, C * 0.66, C * 0.72], fill=(220, 45, 60, 255))
    # wing
    d.polygon(petal_pts(C * 0.56, C * 0.42, 75, C * 0.03, C * 0.30, C * 0.075),
              fill=(35, 80, 190, 255))
    d.polygon(petal_pts(C * 0.56, C * 0.42, 75, C * 0.05, C * 0.22, C * 0.045),
              fill=(250, 180, 60, 255))
    # head
    circle(d, C * 0.475, C * 0.26, C * 0.105, fill=(230, 55, 70, 255))
    # white face patch
    circle(d, C * 0.43, C * 0.255, C * 0.055, fill=(245, 240, 235, 255))
    circle(d, C * 0.435, C * 0.245, C * 0.016, fill=(20, 15, 20, 255))
    # beak
    d.pieslice([C * 0.30, C * 0.21, C * 0.42, C * 0.33], 90, 270, fill=(45, 40, 45, 255))
    d.polygon([(C * 0.36, C * 0.30), (C * 0.42, C * 0.30), (C * 0.39, C * 0.35)],
              fill=(80, 70, 75, 255))
    # feet
    for fx in (0.48, 0.56):
        d.line([(C * fx, C * 0.70), (C * fx, C * 0.78)], fill=(90, 80, 70, 255),
               width=int(C * 0.02))
    sparkle(d, C * 0.82, C * 0.20, C * 0.035)

# ---------------------------------------------------------------- celestial

@art("crescent_moon_stars", 32)
def _(im, d, C):
    cx, cy = C * 0.46, C * 0.52
    circle(d, cx, cy, C * 0.34, fill=(235, 195, 70, 255))
    circle(d, cx + C * 0.14, cy - C * 0.07, C * 0.30, fill=(0, 0, 0, 0))
    circle(d, cx - C * 0.16, cy - C * 0.02, C * 0.035, fill=(255, 230, 150, 255))
    circle(d, cx - C * 0.10, cy + C * 0.18, C * 0.025, fill=(255, 230, 150, 255))
    d.polygon(star_pts(C * 0.72, C * 0.20, C * 0.10, C * 0.04, 4), fill=(250, 220, 120, 255))
    d.polygon(star_pts(C * 0.82, C * 0.55, C * 0.065, C * 0.026, 4), fill=(200, 215, 245, 255))
    d.polygon(star_pts(C * 0.60, C * 0.82, C * 0.075, C * 0.03, 4), fill=(250, 220, 120, 255))
    d.polygon(star_pts(C * 0.18, C * 0.18, C * 0.055, C * 0.022, 4), fill=(200, 215, 245, 255))


@art("aurora_sky", 64)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(14, 16, 44, 255))
    # aurora curtains: smooth column-swept bands, back to front
    bands = [(0.10, 0.34, 2.6, 0.0, (60, 40, 120, 255)),
             (0.08, 0.40, 3.4, 1.8, (30, 140, 110, 255)),
             (0.12, 0.30, 4.2, 3.6, (50, 200, 150, 255)),
             (0.16, 0.20, 5.0, 5.2, (170, 90, 220, 255)),
             (0.20, 0.14, 5.8, 0.9, (120, 235, 190, 255))]
    n = 80
    for top, height, freq, ph, col in bands:
        for i in range(n):
            t = i / (n - 1)
            x0, x1 = C * t, C * (t + 1.2 / n)
            y0 = C * (top + 0.10 * math.sin(t * freq + ph) + 0.06 * math.sin(t * 9 + ph * 2))
            d.rectangle([x0, y0, x1, y0 + C * height], fill=col)
    # stars
    rnd = random.Random(4)
    for i in range(16):
        circle(d, C * rnd.uniform(0.03, 0.97), C * rnd.uniform(0.02, 0.40),
               C * rnd.uniform(0.005, 0.011), fill=(230, 235, 250, 255))
    # mountains
    d.polygon([(0, C), (0, C * 0.78), (C * 0.24, C * 0.60), (C * 0.44, C * 0.80),
               (C * 0.62, C * 0.64), (C * 0.82, C * 0.84), (C, C * 0.72), (C, C)],
              fill=(45, 40, 85, 255))
    d.polygon([(C * 0.24, C * 0.60), (C * 0.315, C * 0.675), (C * 0.165, C * 0.675)],
              fill=(225, 235, 250, 255))
    d.polygon([(C * 0.62, C * 0.64), (C * 0.695, C * 0.705), (C * 0.545, C * 0.705)],
              fill=(225, 235, 250, 255))
    d.polygon([(C, C * 0.72), (C, C * 0.785), (C * 0.93, C * 0.775)],
              fill=(225, 235, 250, 255))


@art("sun_face", 48)
def _(im, d, C):
    c = C / 2
    # alternating triangle / wavy rays
    for i in range(12):
        a = i * 30
        if i % 2 == 0:
            d.polygon(petal_pts(c, c, a, C * 0.24, C * 0.48, C * 0.05),
                      fill=(235, 140, 40, 255))
        else:
            d.polygon(petal_pts(c, c, a, C * 0.26, C * 0.40, C * 0.035),
                      fill=(250, 180, 60, 255))
    circle(d, c, c, C * 0.285, fill=(235, 140, 40, 255))
    circle(d, c, c, C * 0.25, fill=(250, 200, 90, 255))
    circle(d, c, c, C * 0.195, fill=(255, 225, 130, 255))
    # closed eyes (arcs) + smile + cheeks
    for sx in (-1, 1):
        ex = c + sx * C * 0.085
        d.arc([ex - C * 0.045, c - C * 0.075, ex + C * 0.045, c - C * 0.005],
              200, 340, fill=(140, 80, 20, 255), width=int(C * 0.016))
        circle(d, c + sx * C * 0.135, c + C * 0.045, C * 0.028, fill=(250, 170, 110, 255))
    d.arc([c - C * 0.06, c + C * 0.01, c + C * 0.06, c + C * 0.10],
          20, 160, fill=(140, 80, 20, 255), width=int(C * 0.016))
    circle(d, c - C * 0.06, c - C * 0.13, C * 0.022, fill=(255, 245, 200, 255))


@art("shooting_star", 32)
def _(im, d, C):
    # rainbow trail sweeping from bottom-left to the star at upper-right
    trail = [((250, 100, 90, 255), 0.00), ((250, 180, 60, 255), 0.045),
             ((250, 220, 120, 255), 0.09), ((90, 200, 140, 255), 0.135),
             ((90, 150, 235, 255), 0.18)]
    sx, sy = C * 0.68, C * 0.32
    for col, off in trail:
        d.line([(C * 0.06, C * 0.94 - C * off * 1.4), (sx - C * 0.02, sy + C * off * 0.4)],
               fill=col, width=int(C * 0.05))
    d.polygon(star_pts(sx, sy, C * 0.26, C * 0.105, 5, rot=-90), fill=(235, 195, 70, 255))
    d.polygon(star_pts(sx, sy, C * 0.16, C * 0.065, 5, rot=-90), fill=(255, 230, 150, 255))
    circle(d, sx, sy, C * 0.045, fill=(255, 250, 220, 255))
    d.polygon(star_pts(C * 0.16, C * 0.24, C * 0.055, C * 0.022, 4), fill=(200, 215, 245, 255))
    d.polygon(star_pts(C * 0.30, C * 0.52, C * 0.045, C * 0.018, 4), fill=(200, 215, 245, 255))


@art("nebula_heart", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.48, fill=(16, 12, 40, 255))
    d.polygon(heart_pts(c, c * 1.04, C * 0.40), fill=(70, 35, 130, 255))
    d.polygon(heart_pts(c - C * 0.02, c * 1.02, C * 0.33), fill=(140, 60, 190, 255))
    d.polygon(heart_pts(c + C * 0.02, c * 1.00, C * 0.26), fill=(210, 80, 170, 255))
    d.polygon(heart_pts(c, c * 0.99, C * 0.18), fill=(245, 130, 190, 255))
    d.polygon(heart_pts(c - C * 0.01, c * 0.97, C * 0.10), fill=(255, 200, 225, 255))
    rnd = random.Random(6)
    for i in range(18):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.10, 0.45)
        circle(d, c + C * rr * math.cos(a), c + C * rr * math.sin(a),
               C * rnd.uniform(0.005, 0.010), fill=(230, 235, 250, 255))
    sparkle(d, c + C * 0.26, c - C * 0.24, C * 0.035)
    sparkle(d, c - C * 0.30, c + C * 0.14, C * 0.028)


# ---------------------------------------------------------------- patterns

@art("moroccan_tile", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(18, 60, 90, 255))
    step = C / 3

    def star8(x, y, r):
        d.polygon(star_pts(x, y, r, r * 0.62, 8, rot=-90), fill=(235, 230, 215, 255))
        d.polygon(star_pts(x, y, r * 0.72, r * 0.45, 8, rot=-90), fill=(40, 150, 160, 255))
        d.polygon(ngon(x, y, r * 0.30, 8, rot=-67.5), fill=(215, 170, 40, 255))
        circle(d, x, y, r * 0.12, fill=(150, 40, 60, 255))

    for gy in range(4):
        for gx in range(4):
            star8(gx * step, gy * step, step * 0.52)
    # cross accents at cell centers
    for gy in range(3):
        for gx in range(3):
            x, y = (gx + 0.5) * step, (gy + 0.5) * step
            d.polygon([(x, y - step * 0.16), (x + step * 0.16, y), (x, y + step * 0.16),
                       (x - step * 0.16, y)], fill=(150, 40, 60, 255))
            d.polygon([(x, y - step * 0.09), (x + step * 0.09, y), (x, y + step * 0.09),
                       (x - step * 0.09, y)], fill=(235, 230, 215, 255))


@art("art_deco_fan", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(20, 55, 50, 255))
    rows = 4
    rh = C / rows
    fw = C / 3
    for row in range(rows + 1):
        y = (row + 1) * rh
        off = -fw / 2 if row % 2 else 0.0
        x = off
        while x < C + fw:
            # fan: nested arcs
            d.pieslice([x - fw / 2, y - rh * 2, x + fw / 2, y], 180, 360,
                       fill=(30, 130 - row * 8, 110, 255))
            d.pieslice([x - fw * 0.38, y - rh * 1.55, x + fw * 0.38, y], 180, 360,
                       fill=(215, 170, 40, 255))
            d.pieslice([x - fw * 0.27, y - rh * 1.1, x + fw * 0.27, y], 180, 360,
                       fill=(240, 225, 185, 255))
            d.pieslice([x - fw * 0.14, y - rh * 0.6, x + fw * 0.14, y], 180, 360,
                       fill=(30, 130 - row * 8, 110, 255))
            # ray lines
            for a in (210, 240, 270, 300, 330):
                ar = math.radians(a)
                d.line([(x, y), (x + fw * 0.5 * math.cos(ar), y + rh * 1.0 * math.sin(ar))],
                       fill=(20, 55, 50, 255), width=S // 2)
            x += fw
    d.rectangle([0, 0, C, S], fill=(215, 170, 40, 255))
    d.rectangle([0, C - S, C, C], fill=(215, 170, 40, 255))


@art("mermaid_scales", 32)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(15, 60, 90, 255))
    rows = 6
    rh = C / rows
    sw = C / 4
    palette = [(35, 160, 185, 255), (60, 200, 190, 255), (120, 220, 200, 255),
               (190, 225, 210, 255), (245, 185, 205, 255), (235, 130, 170, 255)]
    r = sw * 0.62
    for row in range(rows + 2):
        col = palette[min(row, rows - 1)]
        edge = tuple(max(0, v - 55) for v in col[:3]) + (255,)
        y = row * rh
        off = -sw / 2 if row % 2 else 0.0
        x = off
        while x < C + sw:
            circle(d, x, y, r, fill=col, outline=edge, width=int(S * 0.75))
            x += sw
    sparkle(d, C * 0.28, C * 0.30, C * 0.05)
    sparkle(d, C * 0.72, C * 0.62, C * 0.045)


@art("evil_eye", 32)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.46, fill=(20, 45, 130, 255))
    circle(d, c, c, C * 0.40, fill=(35, 80, 190, 255))
    circle(d, c, c, C * 0.30, fill=(240, 245, 250, 255))
    circle(d, c, c, C * 0.185, fill=(110, 190, 230, 255))
    circle(d, c, c, C * 0.095, fill=(20, 25, 45, 255))
    circle(d, c - C * 0.035, c - C * 0.035, C * 0.030, fill=(240, 245, 250, 255))
    # rim ticks
    ring_dots(d, c, c, 12, C * 0.43, C * 0.018, (110, 190, 230, 255), rot=15)


@art("faberge_egg", 64)
def _(im, d, C):
    cx = C / 2
    top, bot = C * 0.06, C * 0.86
    # egg silhouette: wider at bottom
    pts = []
    for i in range(61):
        t = i / 60 * math.pi  # 0..pi, right side top->bottom
        y = top + (bot - top) * (1 - math.cos(t)) / 2
        w = C * 0.335 * math.sin(t) * (0.80 + 0.35 * (1 - math.cos(t)) / 2)
        pts.append((cx + w, y))
    for i in range(61):
        t = (60 - i) / 60 * math.pi
        y = top + (bot - top) * (1 - math.cos(t)) / 2
        w = C * 0.335 * math.sin(t) * (0.80 + 0.35 * (1 - math.cos(t)) / 2)
        pts.append((cx - w, y))
    d.polygon(pts, fill=(45, 160, 165, 255))
    # horizontal gold bands
    for fy, bw in [(0.30, 0.030), (0.62, 0.035)]:
        y = C * fy
        d.rectangle([cx - C * 0.40, y - C * bw / 2, cx + C * 0.40, y + C * bw / 2],
                    fill=(215, 170, 40, 255))
    # lattice on middle panel
    for i in range(-3, 4):
        x0 = cx + i * C * 0.11
        d.line([(x0 - C * 0.12, C * 0.62), (x0 + C * 0.12, C * 0.30)],
               fill=(240, 225, 185, 255), width=S // 2)
        d.line([(x0 + C * 0.12, C * 0.62), (x0 - C * 0.12, C * 0.30)],
               fill=(240, 225, 185, 255), width=S // 2)
    # jewels at lattice crossings
    for i in (-2, -1, 0, 1, 2):
        circle(d, cx + i * C * 0.11, C * 0.46, C * 0.020, fill=(220, 40, 80, 255))
    # top panel dots + bottom scallops
    ring_dots(d, cx, C * 0.19, 5, C * 0.10, C * 0.018, (255, 230, 150, 255), rot=-90)
    circle(d, cx, C * 0.175, C * 0.028, fill=(220, 40, 80, 255))
    for i in range(5):
        x = cx + (i - 2) * C * 0.115
        circle(d, x, C * 0.72, C * 0.032, fill=(215, 170, 40, 255))
        circle(d, x, C * 0.72, C * 0.017, fill=(150, 90, 220, 255))
    # egg mask redraw of outline shine + finial and base
    circle(d, cx, top - C * 0.005, C * 0.030, fill=(215, 170, 40, 255))
    d.polygon([(cx - C * 0.13, C * 0.965), (cx + C * 0.13, C * 0.965),
               (cx + C * 0.09, C * 0.875), (cx - C * 0.09, C * 0.875)],
              fill=(215, 170, 40, 255))
    circle(d, cx - C * 0.14, C * 0.22, C * 0.024, fill=(150, 230, 230, 255))


@art("rangoli_burst", 64)
def _(im, d, C):
    c = C / 2
    d.polygon(star_pts(c, c, C * 0.48, C * 0.34, 8), fill=(150, 40, 90, 255))
    d.polygon(star_pts(c, c, C * 0.44, C * 0.31, 8), fill=(235, 120, 40, 255))
    ring_petals(d, c, c, 8, C * 0.16, C * 0.40, C * 0.075, (250, 180, 60, 255), rot=22.5)
    ring_petals(d, c, c, 8, C * 0.14, C * 0.33, C * 0.055, (60, 190, 170, 255), rot=22.5)
    ring_dots(d, c, c, 8, C * 0.40, C * 0.022, (240, 240, 250, 255))
    circle(d, c, c, C * 0.185, fill=(150, 40, 90, 255))
    d.polygon(star_pts(c, c, C * 0.165, C * 0.10, 8, rot=-67.5), fill=(220, 60, 130, 255))
    d.polygon(ngon(c, c, C * 0.085, 8), fill=(250, 180, 60, 255))
    circle(d, c, c, C * 0.042, fill=(255, 235, 160, 255))
    ring_dots(d, c, c, 16, C * 0.475, C * 0.014, (255, 235, 160, 255), rot=11.25)


# -------------------------------------------------- former 96/128 pieces, at 64

@art("crystal_cave", 64)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(18, 14, 40, 255))
    d.rectangle([0, 0, C, C * 0.35], fill=(28, 20, 58, 255))
    circle(d, C * 0.5, C * 0.55, C * 0.42, fill=(40, 28, 80, 255))   # glow
    circle(d, C * 0.5, C * 0.60, C * 0.30, fill=(58, 40, 110, 255))
    # floor
    d.polygon([(0, C * 0.86), (C, C * 0.80), (C, C), (0, C)], fill=(30, 24, 55, 255))
    # stalactites (hanging crystals, drawn with negative height)
    for x, w, h, cols in [(0.16, 0.09, 0.26, ((70, 190, 210, 255), (130, 230, 240, 255))),
                          (0.34, 0.06, 0.16, ((150, 90, 230, 255), (200, 160, 250, 255))),
                          (0.66, 0.07, 0.20, ((150, 90, 230, 255), (200, 160, 250, 255))),
                          (0.85, 0.09, 0.28, ((70, 190, 210, 255), (130, 230, 240, 255)))]:
        crystal(d, C * x, 0, C * w, -C * h, 0, cols[0], cols[1])
    # floor clusters
    crystal(d, C * 0.20, C * 0.88, C * 0.10, C * 0.34, 14, (120, 70, 200, 255), (175, 130, 240, 255))
    crystal(d, C * 0.12, C * 0.90, C * 0.07, C * 0.20, -8, (35, 140, 170, 255), (95, 200, 220, 255))
    crystal(d, C * 0.50, C * 0.84, C * 0.13, C * 0.46, 0, (225, 90, 180, 255), (250, 150, 215, 255))
    crystal(d, C * 0.42, C * 0.86, C * 0.07, C * 0.22, 12, (150, 90, 230, 255), (200, 160, 250, 255))
    crystal(d, C * 0.60, C * 0.86, C * 0.08, C * 0.26, -14, (70, 190, 210, 255), (130, 230, 240, 255))
    crystal(d, C * 0.82, C * 0.90, C * 0.10, C * 0.32, -10, (120, 70, 200, 255), (175, 130, 240, 255))
    crystal(d, C * 0.90, C * 0.92, C * 0.06, C * 0.18, 8, (225, 90, 180, 255), (250, 150, 215, 255))
    for x, y in [(0.28, 0.30), (0.55, 0.22), (0.75, 0.35), (0.40, 0.45), (0.65, 0.55)]:
        sparkle(d, C * x, C * y, C * 0.028)


@art("birthstone_wheel", 64)
def _(im, d, C):
    c = C / 2
    stones = [(150, 30, 50), (150, 90, 220), (140, 210, 230), (240, 240, 250),
              (30, 160, 90), (245, 230, 205), (220, 40, 80), (170, 210, 70),
              (35, 80, 190), (250, 180, 200), (250, 160, 60), (90, 100, 220)]
    circle(d, c, c, C * 0.425, outline=(215, 170, 40, 255), width=int(C * 0.035))
    for i, (r, g, b) in enumerate(stones):
        a = math.radians(i * 30 - 90)
        x, y = c + C * 0.425 * math.cos(a), c + C * 0.425 * math.sin(a)
        R = C * 0.075
        circle(d, x, y, R, fill=(max(0, r - 60), max(0, g - 60), max(0, b - 60), 255))
        circle(d, x, y, R * 0.72, fill=(r, g, b, 255))
        d.polygon(ngon(x, y, R * 0.45, 6), fill=(min(255, r + 55), min(255, g + 55), min(255, b + 55), 255))
    # center diamond
    R = C * 0.17
    circle(d, c, c, R, fill=(120, 140, 170, 255))
    tab = ngon(c, c, R * 0.52, 8)
    gir = ngon(c, c, R * 0.95, 8, rot=-67.5)
    for i in range(8):
        col = (200, 215, 235, 255) if i % 2 == 0 else (160, 180, 205, 255)
        d.polygon([tab[i], gir[i], tab[(i + 1) % 8]], fill=col)
    d.polygon(tab, fill=(240, 245, 252, 255))
    sparkle(d, c + R * 0.65, c - R * 0.75, C * 0.032)
    ring_diamonds(d, c, c, 12, C * 0.26, C * 0.335, C * 0.024, (215, 170, 40, 255), rot=15)


@art("chakra_mandala", 64)
def _(im, d, C):
    c = C / 2
    chakra = [(150, 60, 200, 255), (70, 90, 220, 255), (60, 160, 230, 255),
              (60, 190, 120, 255), (245, 210, 70, 255), (245, 140, 60, 255),
              (225, 60, 80, 255)]
    circle(d, c, c, C * 0.475, fill=(28, 20, 55, 255))
    radii = [0.46, 0.40, 0.34, 0.28, 0.22, 0.16, 0.10]
    counts = [18, 16, 14, 12, 10, 8, 6]
    for col, r, k in zip(chakra, radii, counts):
        ring_petals(d, c, c, k, C * (r - 0.068), C * r, C * 0.036, col,
                    rot=180 / k)
    circle(d, c, c, C * 0.055, fill=(255, 240, 200, 255))
    circle(d, c, c, C * 0.028, fill=(150, 60, 200, 255))


@art("royal_sapphire_mandala", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.485, fill=(10, 18, 50, 255))
    ring_petals(d, c, c, 14, C * 0.30, C * 0.48, C * 0.060, (25, 60, 150, 255))
    ring_petals(d, c, c, 14, C * 0.28, C * 0.42, C * 0.048, (55, 105, 205, 255), rot=180 / 14)
    ring_dots(d, c, c, 14, C * 0.45, C * 0.018, (215, 170, 40, 255), rot=180 / 14)
    circle(d, c, c, C * 0.285, fill=(16, 32, 90, 255))
    d.polygon(star_pts(c, c, C * 0.275, C * 0.165, 10), fill=(215, 170, 40, 255))
    d.polygon(star_pts(c, c, C * 0.235, C * 0.145, 10), fill=(120, 165, 235, 255))
    circle(d, c, c, C * 0.145, fill=(25, 60, 150, 255))
    # faceted sapphire core
    R = C * 0.125
    d.polygon(ngon(c, c, R, 8), fill=(15, 40, 110, 255))
    tab = ngon(c, c, R * 0.52, 8)
    gir = ngon(c, c, R * 0.94, 8, rot=-67.5)
    for i in range(8):
        col = (70, 125, 220, 255) if i % 2 == 0 else (35, 80, 180, 255)
        d.polygon([tab[i], gir[i], tab[(i + 1) % 8]], fill=col)
    d.polygon(tab, fill=(150, 190, 245, 255))
    sparkle(d, c + R * 0.5, c - R * 0.6, C * 0.028)


@art("zodiac_wheel", 64)
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.48, fill=(20, 16, 50, 255))
    circle(d, c, c, C * 0.48, outline=(215, 170, 40, 255), width=int(C * 0.025))
    circle(d, c, c, C * 0.33, outline=(215, 170, 40, 255), width=int(C * 0.014))
    stones = [(220, 40, 80), (150, 90, 220), (140, 210, 230), (240, 240, 250),
              (30, 160, 90), (245, 230, 205), (250, 160, 60), (170, 210, 70),
              (35, 80, 190), (250, 180, 200), (90, 100, 220), (60, 190, 110)]
    for i in range(12):
        a = math.radians(i * 30 - 90 + 15)
        d.line([(c + C * 0.33 * math.cos(a - math.radians(15)), c + C * 0.33 * math.sin(a - math.radians(15))),
                (c + C * 0.47 * math.cos(a - math.radians(15)), c + C * 0.47 * math.sin(a - math.radians(15)))],
               fill=(215, 170, 40, 255), width=int(C * 0.010))
        x, y = c + C * 0.405 * math.cos(a), c + C * 0.405 * math.sin(a)
        r, g, b = stones[i]
        d.polygon(ngon(x, y, C * 0.050, 6, rot=math.degrees(a)), fill=(r, g, b, 255))
        d.polygon(ngon(x, y, C * 0.028, 6, rot=math.degrees(a)),
                  fill=(min(255, r + 60), min(255, g + 60), min(255, b + 60), 255))
    # inner star field
    rnd = random.Random(9)
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.10, 0.28)
        circle(d, c + C * rr * math.cos(a), c + C * rr * math.sin(a),
               C * rnd.uniform(0.008, 0.013), fill=(200, 215, 245, 255))
    # center sun/moon
    circle(d, c, c, C * 0.13, fill=(250, 200, 90, 255))
    circle(d, c + C * 0.040, c, C * 0.107, fill=(20, 16, 50, 255))
    circle(d, c - C * 0.012, c, C * 0.093, fill=(205, 215, 235, 255))
    d.polygon(star_pts(c + C * 0.21, c - C * 0.17, C * 0.034, C * 0.014, 4),
              fill=(250, 220, 120, 255))


@art("stained_glass_peacock", 64)
def _(im, d, C):
    c = C / 2
    cy = C * 0.62
    lead = (30, 25, 40, 255)
    circle(d, c, c, C * 0.49, fill=lead)
    # background glass wedges
    for i in range(12):
        a0 = i * 30
        col = (25, 60, 90, 255) if i % 2 == 0 else (35, 80, 115, 255)
        d.pieslice([c - C * 0.475, c - C * 0.475, c + C * 0.475, c + C * 0.475],
                   a0 + 2, a0 + 28, fill=col)
    # tail feathers: 9 across the top fan
    for i in range(9):
        a = -180 + i * 22.5
        d.polygon(petal_pts(c, cy, a, C * 0.08, C * 0.46, C * 0.062), fill=lead)
        d.polygon(petal_pts(c, cy, a, C * 0.095, C * 0.445, C * 0.048),
                  fill=(20, 130, 110, 255) if i % 2 == 0 else (30, 160, 130, 255))
        ar = math.radians(a)
        ex, ey = c + C * 0.345 * math.cos(ar), cy + C * 0.345 * math.sin(ar)
        circle(d, ex, ey, C * 0.046, fill=lead)
        circle(d, ex, ey, C * 0.038, fill=(250, 180, 60, 255))
        circle(d, ex, ey, C * 0.024, fill=(25, 65, 160, 255))
        circle(d, ex, ey, C * 0.012, fill=(120, 210, 230, 255))
    # body
    d.ellipse([c - C * 0.075, cy - C * 0.10, c + C * 0.075, cy + C * 0.24], fill=lead)
    d.ellipse([c - C * 0.062, cy - C * 0.085, c + C * 0.062, cy + C * 0.225],
              fill=(35, 90, 200, 255))
    d.ellipse([c - C * 0.038, cy - C * 0.05, c + C * 0.038, cy + C * 0.19],
              fill=(70, 130, 230, 255))
    # head + crest
    circle(d, c, cy - C * 0.135, C * 0.052, fill=lead)
    circle(d, c, cy - C * 0.135, C * 0.043, fill=(35, 90, 200, 255))
    for da in (-28, 0, 28):
        ar = math.radians(-90 + da)
        tx = c + C * 0.10 * math.cos(ar)
        ty = cy - C * 0.135 + C * 0.10 * math.sin(ar)
        d.line([(c, cy - C * 0.135), (tx, ty)], fill=lead, width=S // 2)
        circle(d, tx, ty, C * 0.015, fill=(250, 180, 60, 255))
    d.polygon([(c + C * 0.04, cy - C * 0.148), (c + C * 0.09, cy - C * 0.128),
               (c + C * 0.04, cy - C * 0.108)], fill=(250, 180, 60, 255))
    circle(d, c + C * 0.018, cy - C * 0.148, C * 0.010, fill=(255, 255, 255, 255))
    # base perch
    d.rectangle([c - C * 0.16, cy + C * 0.24, c + C * 0.16, cy + C * 0.27],
                fill=(215, 170, 40, 255))
    circle(d, c, c, C * 0.49, outline=lead, width=int(C * 0.012))


# ---------------------------------------------------------------- main

def main(only=None):
    os.makedirs(OUT, exist_ok=True)
    for aid, (g, fn) in ARTS.items():
        if only and aid not in only:
            continue
        C = g * S
        im = Image.new("RGBA", (C, C), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        fn(im, d, C)
        im.resize((g, g), Image.Resampling.NEAREST).save(os.path.join(OUT, aid + ".png"))
        print(f"  drew {aid} ({g}x{g})")
    print(f"done: {len(only) if only else len(ARTS)} sources in {OUT}")


if __name__ == "__main__":
    main(set(sys.argv[1:]) or None)
