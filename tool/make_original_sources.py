#!/usr/bin/env python3
"""Procedural source generator for the original (Pixely) flavor.

Upgrades the launch-era 16x16 starter artworks to detailed 32x32 versions:
bold dark outlines, 2-3 tone shading, highlights and accents — same ids and
metadata, so they replace the basics in place.

Usage:
    python3 tool/make_original_sources.py           # all
    python3 tool/make_original_sources.py id1 id2   # only these
Then:
    python3 tool/build_artworks.py original
"""
import math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_diamond_sources import (  # noqa: E402
    S, circle, crystal, heart_pts, ngon, petal_pts, ring_dots, rot0,
    sparkle, star_pts, teardrop_pts)
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tool", "original_sources")

ARTS = {}


def art(aid, grid=32):
    def deco(fn):
        ARTS[aid] = (grid, fn)
        return fn
    return deco


# ---------------------------------------------------------------- shapes

@art("heart_01")
def _(im, d, C):
    c = C / 2
    d.polygon(heart_pts(c, c * 1.04, C * 0.46), fill=(150, 25, 55, 255))
    d.polygon(heart_pts(c, c * 1.03, C * 0.40), fill=(230, 55, 90, 255))
    d.polygon(heart_pts(c - C * 0.02, c * 1.00, C * 0.30), fill=(245, 95, 125, 255))
    d.ellipse([c - C * 0.26, c * 0.62, c - C * 0.10, c * 0.80],
              fill=(255, 200, 215, 255))
    sparkle(d, c + C * 0.28, c * 0.50, C * 0.06)
    sparkle(d, c - C * 0.34, c * 1.10, C * 0.045)


@art("smiley_01")
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.44, fill=(190, 130, 20, 255))
    circle(d, c, c, C * 0.40, fill=(250, 200, 60, 255))
    d.pieslice([c - C * 0.40, c - C * 0.40, c + C * 0.40, c + C * 0.40],
               200, 340, fill=(255, 225, 110, 255))
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.15 - C * 0.045, c - C * 0.16,
                   c + sx * C * 0.15 + C * 0.045, c - C * 0.02],
                  fill=(85, 50, 15, 255))
        circle(d, c + sx * C * 0.24, c + C * 0.08, C * 0.05, fill=(250, 150, 110, 255))
    d.arc([c - C * 0.18, c - C * 0.06, c + C * 0.18, c + C * 0.24],
          20, 160, fill=(85, 50, 15, 255), width=int(C * 0.030))
    circle(d, c - C * 0.14, c - C * 0.26, C * 0.04, fill=(255, 245, 190, 255))


@art("star_01")
def _(im, d, C):
    c = C / 2
    d.polygon(star_pts(c, c, C * 0.47, C * 0.20, 5), fill=(185, 120, 15, 255))
    d.polygon(star_pts(c, c, C * 0.41, C * 0.17, 5), fill=(250, 195, 55, 255))
    d.polygon(star_pts(c, c, C * 0.28, C * 0.115, 5), fill=(255, 225, 110, 255))
    circle(d, c - C * 0.08, c - C * 0.10, C * 0.045, fill=(255, 250, 210, 255))
    sparkle(d, c + C * 0.34, c - C * 0.34, C * 0.05)
    sparkle(d, c - C * 0.38, c + C * 0.28, C * 0.04)


@art("diamond_01")
def _(im, d, C):
    c = C / 2
    top, mid, bot = C * 0.24, C * 0.42, C * 0.86
    L, R = c - C * 0.42, c + C * 0.42
    outline = (10, 60, 100, 255)
    d.polygon([(L, mid), (c - C * 0.24, top), (c + C * 0.24, top), (R, mid), (c, bot)],
              fill=outline)
    e = C * 0.025
    # crown facets
    d.polygon([(c - C * 0.22, top + e), (c + C * 0.22, top + e),
               (c + C * 0.13, mid - e), (c - C * 0.13, mid - e)], fill=(150, 230, 245, 255))
    d.polygon([(L + e * 1.6, mid - e * 0.4), (c - C * 0.22, top + e),
               (c - C * 0.13, mid - e)], fill=(70, 180, 220, 255))
    d.polygon([(R - e * 1.6, mid - e * 0.4), (c + C * 0.22, top + e),
               (c + C * 0.13, mid - e)], fill=(70, 180, 220, 255))
    # pavilion facets
    d.polygon([(L + e * 1.6, mid + e * 0.6), (c - C * 0.13, mid + e * 0.6), (c, bot - e * 2)],
              fill=(35, 130, 185, 255))
    d.polygon([(R - e * 1.6, mid + e * 0.6), (c + C * 0.13, mid + e * 0.6), (c, bot - e * 2)],
              fill=(35, 130, 185, 255))
    d.polygon([(c - C * 0.13, mid + e * 0.6), (c + C * 0.13, mid + e * 0.6), (c, bot - e * 2)],
              fill=(90, 200, 230, 255))
    circle(d, c - C * 0.05, top + C * 0.075, C * 0.032, fill=(235, 250, 255, 255))
    sparkle(d, c + C * 0.30, top - C * 0.02, C * 0.05)


@art("ghost_01")
def _(im, d, C):
    c = C / 2
    out = (130, 140, 175, 255)
    body = (245, 245, 252, 255)

    def ghost(fw, col):
        pts = []
        n = 24
        for i in range(n + 1):  # dome
            a = math.pi * i / n
            pts.append((c - C * fw * math.cos(a), c * 0.94 - C * fw * math.sin(a) * 1.05))
        # wavy hem: 3 scallops up
        hem_y = c * 1.58
        pts.append((c + C * fw, hem_y))
        for k in range(3):
            x1 = c + C * fw - (k * 2 + 1) * C * fw / 3
            pts.append((x1, hem_y - C * 0.09))
            pts.append((x1 - C * fw / 3, hem_y))
        d.polygon(pts, fill=col)

    ghost(0.34, out)
    ghost(0.31, body)
    d.ellipse([c - C * 0.30, c * 0.70, c - C * 0.06, c * 1.05], fill=(255, 255, 255, 255))
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.13 - C * 0.045, c * 0.82, c + sx * C * 0.13 + C * 0.045,
                   c * 1.02], fill=(40, 45, 70, 255))
        circle(d, c + sx * C * 0.115, c * 0.86, C * 0.015, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.24, c * 1.10, C * 0.045, fill=(250, 170, 185, 255))
    d.ellipse([c - C * 0.05, c * 1.06, c + C * 0.05, c * 1.16], fill=(40, 45, 70, 255))
    sparkle(d, c + C * 0.36, c * 0.55, C * 0.045)


@art("house_01")
def _(im, d, C):
    wall_l, wall_r = C * 0.16, C * 0.84
    wall_t, wall_b = C * 0.46, C * 0.88
    # chimney + smoke
    d.rectangle([C * 0.66, C * 0.16, C * 0.76, C * 0.36], fill=(150, 75, 60, 255))
    circle(d, C * 0.71, C * 0.11, C * 0.035, fill=(225, 225, 235, 255))
    circle(d, C * 0.78, C * 0.05, C * 0.028, fill=(225, 225, 235, 255))
    # roof
    d.polygon([(C * 0.08, wall_t), (C * 0.5, C * 0.12), (C * 0.92, wall_t)],
              fill=(120, 45, 40, 255))
    d.polygon([(C * 0.14, wall_t - C * 0.015), (C * 0.5, C * 0.16),
               (C * 0.86, wall_t - C * 0.015)], fill=(200, 80, 65, 255))
    # walls
    d.rectangle([wall_l, wall_t, wall_r, wall_b], fill=(245, 225, 185, 255))
    d.rectangle([wall_l, wall_t, wall_r, wall_t + C * 0.02], fill=(120, 45, 40, 255))
    # door
    d.rounded_rectangle([C * 0.43, C * 0.62, C * 0.57, wall_b], radius=C * 0.035,
                        fill=(140, 85, 45, 255))
    circle(d, C * 0.54, C * 0.76, C * 0.014, fill=(250, 195, 55, 255))
    # windows
    for wx in (0.245, 0.665):
        d.rectangle([C * wx, C * 0.55, C * (wx + 0.13), C * 0.68], fill=(110, 70, 40, 255))
        d.rectangle([C * (wx + 0.012), C * 0.562, C * (wx + 0.118), C * 0.668],
                    fill=(255, 215, 120, 255))
        d.line([(C * (wx + 0.065), C * 0.562), (C * (wx + 0.065), C * 0.668)],
               fill=(110, 70, 40, 255), width=S // 2)
        d.line([(C * (wx + 0.012), C * 0.615), (C * (wx + 0.118), C * 0.615)],
               fill=(110, 70, 40, 255), width=S // 2)
    # bushes + ground
    d.rectangle([C * 0.10, C * 0.88, C * 0.90, C * 0.92], fill=(90, 140, 70, 255))
    for bx in (0.16, 0.86):
        circle(d, C * bx, C * 0.86, C * 0.065, fill=(70, 155, 80, 255))
        circle(d, C * bx - C * 0.04, C * 0.885, C * 0.05, fill=(55, 130, 65, 255))


@art("moon_01")
def _(im, d, C):
    cx, cy = C * 0.46, C * 0.52
    circle(d, cx, cy, C * 0.38, fill=(200, 145, 30, 255))
    circle(d, cx, cy, C * 0.345, fill=(250, 205, 80, 255))
    circle(d, cx + C * 0.15, cy - C * 0.08, C * 0.315, fill=(0, 0, 0, 0))
    # craters on the lit edge
    circle(d, cx - C * 0.22, cy - C * 0.05, C * 0.035, fill=(230, 175, 55, 255))
    circle(d, cx - C * 0.14, cy + C * 0.20, C * 0.028, fill=(230, 175, 55, 255))
    # sleepy face
    d.arc([cx - C * 0.28, cy - C * 0.02, cx - C * 0.16, cy + 0.09 * C],
          20, 160, fill=(120, 70, 15, 255), width=int(C * 0.022))
    d.arc([cx - C * 0.15, cy + C * 0.16, cx - C * 0.05, cy + C * 0.26],
          20, 160, fill=(120, 70, 15, 255), width=int(C * 0.020))
    circle(d, cx - C * 0.30, cy + C * 0.13, C * 0.032, fill=(250, 160, 110, 255))
    d.polygon(star_pts(C * 0.76, C * 0.22, C * 0.085, C * 0.034, 4), fill=(255, 225, 110, 255))
    d.polygon(star_pts(C * 0.85, C * 0.56, C * 0.055, C * 0.022, 4), fill=(200, 215, 245, 255))
    d.polygon(star_pts(C * 0.66, C * 0.84, C * 0.06, C * 0.024, 4), fill=(255, 225, 110, 255))


@art("rocket_01")
def _(im, d, C):
    c = C / 2
    # flame
    d.polygon(teardrop_pts(c, C * 0.86, C * 0.085, C * 1.02), fill=(235, 120, 30, 255))
    d.polygon(teardrop_pts(c, C * 0.85, C * 0.05, C * 0.965), fill=(255, 210, 90, 255))
    # fins
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.13, C * 0.52), (c + sx * C * 0.30, C * 0.78),
                   (c + sx * C * 0.13, C * 0.72)], fill=(180, 45, 55, 255))
    # body
    d.polygon([(c - C * 0.14, C * 0.78), (c - C * 0.14, C * 0.38),
               (c, C * 0.08), (c + C * 0.14, C * 0.38), (c + C * 0.14, C * 0.78)],
              fill=(230, 230, 238, 255))
    d.polygon([(c + C * 0.05, C * 0.78), (c + C * 0.05, C * 0.38), (c, C * 0.08),
               (c + C * 0.14, C * 0.38), (c + C * 0.14, C * 0.78)],
              fill=(195, 200, 212, 255))
    # nose cone
    d.polygon([(c - C * 0.14, C * 0.38), (c, C * 0.08), (c + C * 0.14, C * 0.38),
               (c + C * 0.10, C * 0.30), (c - C * 0.10, C * 0.30)],
              fill=(210, 60, 70, 255))
    d.rectangle([c - C * 0.14, C * 0.72, c + C * 0.14, C * 0.78], fill=(210, 60, 70, 255))
    # window
    circle(d, c, C * 0.46, C * 0.085, fill=(180, 185, 200, 255))
    circle(d, c, C * 0.46, C * 0.062, fill=(120, 210, 235, 255))
    circle(d, c - C * 0.025, C * 0.44, C * 0.022, fill=(215, 245, 255, 255))
    d.polygon(star_pts(C * 0.16, C * 0.24, C * 0.05, C * 0.02, 4), fill=(255, 225, 110, 255))
    d.polygon(star_pts(C * 0.84, C * 0.18, C * 0.06, C * 0.024, 4), fill=(255, 225, 110, 255))
    d.polygon(star_pts(C * 0.82, C * 0.60, C * 0.045, C * 0.018, 4), fill=(200, 215, 245, 255))


# ---------------------------------------------------------------- animals

@art("bird_01")
def _(im, d, C):
    c = C / 2
    # branch
    d.line([(C * 0.10, C * 0.88), (C * 0.90, C * 0.84)], fill=(120, 80, 50, 255),
           width=int(C * 0.045))
    # tail
    d.polygon(petal_pts(C * 0.30, C * 0.56, 155, C * 0.05, C * 0.30, C * 0.05),
              fill=(35, 100, 180, 255))
    # body
    circle(d, c, C * 0.52, C * 0.30, fill=(60, 140, 220, 255))
    d.pieslice([c - C * 0.30, C * 0.30, c + C * 0.30, C * 0.82], 20, 160,
               fill=(250, 235, 200, 255))
    # wing
    d.polygon(petal_pts(c + C * 0.06, C * 0.50, 40, C * 0.02, C * 0.26, C * 0.075),
              fill=(35, 100, 180, 255))
    # head shine + eye + beak + blush
    circle(d, c - C * 0.10, C * 0.40, C * 0.05, fill=(140, 195, 245, 255))
    circle(d, c - C * 0.115, C * 0.47, C * 0.035, fill=(25, 25, 40, 255))
    circle(d, c - C * 0.125, C * 0.458, C * 0.012, fill=(255, 255, 255, 255))
    d.polygon([(c - C * 0.30, C * 0.50), (c - C * 0.42, C * 0.55), (c - C * 0.28, C * 0.585)],
              fill=(245, 160, 40, 255))
    circle(d, c - C * 0.20, C * 0.575, C * 0.038, fill=(250, 170, 185, 255))
    # feet
    for fx in (-0.07, 0.07):
        d.line([(c + C * fx, C * 0.80), (c + C * fx, C * 0.87)], fill=(245, 160, 40, 255),
               width=int(C * 0.018))
    sparkle(d, C * 0.82, C * 0.24, C * 0.04)


@art("cat_01")
def _(im, d, C):
    c = C / 2
    fur = (240, 155, 60, 255)
    dark = (200, 110, 35, 255)
    # ears
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.12, C * 0.30), (c + sx * C * 0.38, C * 0.10),
                   (c + sx * C * 0.40, C * 0.38)], fill=fur)
        d.polygon([(c + sx * C * 0.20, C * 0.29), (c + sx * C * 0.34, C * 0.17),
                   (c + sx * C * 0.35, C * 0.33)], fill=(250, 190, 200, 255))
    # head
    d.ellipse([c - C * 0.40, C * 0.24, c + C * 0.40, C * 0.90], fill=fur)
    # forehead stripes
    for dx in (-0.10, 0.0, 0.10):
        d.polygon(petal_pts(c + C * dx, C * 0.24, 90, 0, C * 0.10, C * 0.022), fill=dark)
    # muzzle
    d.ellipse([c - C * 0.20, C * 0.58, c + C * 0.20, C * 0.84], fill=(255, 235, 210, 255))
    # eyes
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.18 - C * 0.055, C * 0.44, c + sx * C * 0.18 + C * 0.055,
                   C * 0.58], fill=(70, 160, 90, 255))
        circle(d, c + sx * C * 0.18, C * 0.51, C * 0.028, fill=(25, 25, 40, 255))
        circle(d, c + sx * C * 0.165, C * 0.48, C * 0.012, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.33, C * 0.62, C * 0.045, fill=(250, 170, 185, 255))
    # nose + mouth
    d.polygon([(c - C * 0.035, C * 0.63), (c + C * 0.035, C * 0.63), (c, C * 0.68)],
              fill=(220, 100, 120, 255))
    d.arc([c - C * 0.07, C * 0.65, c, C * 0.73], 20, 160, fill=dark, width=S // 2)
    d.arc([c, C * 0.65, c + C * 0.07, C * 0.73], 20, 160, fill=dark, width=S // 2)
    # whiskers
    for sx in (-1, 1):
        for wy, wa in ((0.62, -6), (0.68, 4)):
            x0 = c + sx * C * 0.36
            d.line([(x0, C * wy), (x0 + sx * C * 0.16, C * (wy + wa / 100))],
                   fill=dark, width=S // 2)


@art("dog_01")
def _(im, d, C):
    c = C / 2
    coat = (240, 215, 170, 255)
    brown = (160, 105, 55, 255)
    # ears
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.42 - C * 0.13, C * 0.22, c + sx * C * 0.42 + C * 0.13,
                   C * 0.62], fill=brown)
    # head
    d.ellipse([c - C * 0.38, C * 0.20, c + C * 0.38, C * 0.88], fill=coat)
    # eye patch
    d.ellipse([c + C * 0.06, C * 0.34, c + C * 0.30, C * 0.58], fill=brown)
    # eyes
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.17, C * 0.46, C * 0.055, fill=(25, 25, 40, 255))
        circle(d, c + sx * C * 0.15, C * 0.44, C * 0.020, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.31, C * 0.58, C * 0.042, fill=(250, 170, 185, 255))
    # muzzle + nose + tongue
    d.ellipse([c - C * 0.17, C * 0.56, c + C * 0.17, C * 0.82], fill=(255, 240, 220, 255))
    d.ellipse([c - C * 0.05, C * 0.60, c + C * 0.05, C * 0.68], fill=(35, 30, 40, 255))
    d.arc([c - C * 0.08, C * 0.64, c + C * 0.08, C * 0.76], 20, 160,
          fill=(120, 80, 50, 255), width=S // 2)
    d.pieslice([c - C * 0.045, C * 0.70, c + C * 0.045, C * 0.80], 0, 180,
               fill=(240, 120, 140, 255))
    sparkle(d, C * 0.82, C * 0.20, C * 0.04)


@art("fish_01")
def _(im, d, C):
    c = C / 2
    body = (245, 140, 50, 255)
    dark = (200, 95, 25, 255)
    # tail
    d.polygon([(C * 0.78, C * 0.50), (C * 0.95, C * 0.32), (C * 0.92, C * 0.50),
               (C * 0.95, C * 0.68)], fill=dark)
    # fins
    d.polygon(petal_pts(C * 0.48, C * 0.34, -115, 0, C * 0.16, C * 0.05), fill=dark)
    d.polygon(petal_pts(C * 0.50, C * 0.66, 115, 0, C * 0.13, C * 0.04), fill=dark)
    # body
    d.ellipse([C * 0.14, C * 0.32, C * 0.82, C * 0.68], fill=body)
    # stripes
    for fx, w in ((0.42, 0.05), (0.58, 0.045)):
        d.ellipse([C * fx - C * w, C * 0.33, C * fx + C * w, C * 0.67],
                  fill=(255, 235, 205, 255))
    # face
    circle(d, C * 0.27, C * 0.46, C * 0.038, fill=(25, 25, 40, 255))
    circle(d, C * 0.258, C * 0.448, C * 0.013, fill=(255, 255, 255, 255))
    d.pieslice([C * 0.13, C * 0.50, C * 0.23, C * 0.60], 0, 180, fill=(230, 90, 90, 255))
    # bubbles
    for bx, by, br in ((0.10, 0.24, 0.030), (0.16, 0.14, 0.022), (0.07, 0.36, 0.018)):
        circle(d, C * bx, C * by, C * br, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("fox_01")
def _(im, d, C):
    c = C / 2
    coat = (240, 125, 45, 255)
    # ears
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.10, C * 0.28), (c + sx * C * 0.36, C * 0.06),
                   (c + sx * C * 0.42, C * 0.36)], fill=coat)
        d.polygon([(c + sx * C * 0.20, C * 0.26), (c + sx * C * 0.33, C * 0.14),
                   (c + sx * C * 0.36, C * 0.30)], fill=(70, 50, 45, 255))
    # head
    d.ellipse([c - C * 0.42, C * 0.22, c + C * 0.42, C * 0.86], fill=coat)
    # white cheeks + chin
    for sx in (-1, 1):
        d.pieslice([c + sx * C * 0.24 - C * 0.22, C * 0.42, c + sx * C * 0.24 + C * 0.22,
                    C * 0.90], 180 if sx < 0 else 270, 360 if sx < 0 else 90,
                   fill=(255, 240, 225, 255))
    d.polygon([(c - C * 0.26, C * 0.60), (c + C * 0.26, C * 0.60), (c, C * 0.88)],
              fill=(255, 240, 225, 255))
    # eyes (happy closed)
    for sx in (-1, 1):
        d.arc([c + sx * C * 0.19 - C * 0.06, C * 0.44, c + sx * C * 0.19 + C * 0.06,
               C * 0.56], 200, 340, fill=(70, 50, 45, 255), width=int(C * 0.025))
    # nose
    d.polygon([(c - C * 0.04, C * 0.66), (c + C * 0.04, C * 0.66), (c, C * 0.715)],
              fill=(70, 50, 45, 255))
    sparkle(d, C * 0.83, C * 0.22, C * 0.04)


@art("panda_01")
def _(im, d, C):
    c = C / 2
    ink = (45, 45, 55, 255)
    # ears
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.30, C * 0.24, C * 0.115, fill=ink)
    # head
    d.ellipse([c - C * 0.40, C * 0.20, c + C * 0.40, C * 0.88], fill=(250, 248, 245, 255))
    # eye patches
    for sx in (-1, 1):
        pts = [(c + sx * C * 0.19 + x, C * 0.50 + y) for x, y in
               rot0([(-C * 0.085, -C * 0.115), (C * 0.085, -C * 0.115),
                     (C * 0.085, C * 0.115), (-C * 0.085, C * 0.115)], sx * -18)]
        d.ellipse([min(p[0] for p in pts), min(p[1] for p in pts),
                   max(p[0] for p in pts), max(p[1] for p in pts)], fill=ink)
        circle(d, c + sx * C * 0.17, C * 0.49, C * 0.032, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.17, C * 0.49, C * 0.018, fill=ink)
    # nose + mouth + blush
    d.ellipse([c - C * 0.045, C * 0.63, c + C * 0.045, C * 0.70], fill=ink)
    d.arc([c - C * 0.06, C * 0.68, c + C * 0.06, C * 0.78], 20, 160, fill=ink, width=S // 2)
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.32, C * 0.64, C * 0.04, fill=(250, 170, 185, 255))
    # bamboo leaf
    d.polygon(petal_pts(c + C * 0.34, C * 0.16, -35, 0, C * 0.14, C * 0.035),
              fill=(90, 170, 90, 255))
    d.polygon(petal_pts(c + C * 0.34, C * 0.16, 15, 0, C * 0.12, C * 0.030),
              fill=(70, 150, 75, 255))


# ---------------------------------------------------------------- nature & food

@art("cactus_01")
def _(im, d, C):
    c = C / 2
    green = (85, 165, 85, 255)
    dark = (60, 130, 65, 255)
    # arms
    for sx, ay in ((-1, 0.42), (1, 0.34)):
        d.rounded_rectangle([c + sx * C * 0.30 - C * 0.06, C * ay,
                             c + sx * C * 0.30 + C * 0.06, C * ay + C * 0.16],
                            radius=C * 0.06, fill=dark)
        d.rectangle([min(c + sx * C * 0.30, c + sx * C * 0.13),
                     C * (ay + 0.09), max(c + sx * C * 0.30, c + sx * C * 0.13),
                     C * (ay + 0.16)], fill=dark)
    # trunk
    d.rounded_rectangle([c - C * 0.13, C * 0.20, c + C * 0.13, C * 0.72],
                        radius=C * 0.12, fill=green)
    d.rounded_rectangle([c + C * 0.02, C * 0.22, c + C * 0.11, C * 0.72],
                        radius=C * 0.05, fill=(120, 190, 110, 255))
    # spines
    for y in (0.30, 0.42, 0.54, 0.64):
        for dx in (-0.09, 0.0):
            circle(d, c + C * dx, C * y, C * 0.012, fill=(235, 240, 220, 255))
    # flower
    for i in range(5):
        d.polygon(petal_pts(c, C * 0.165, i * 72 - 90, 0, C * 0.075, C * 0.032),
                  fill=(245, 120, 160, 255))
    circle(d, c, C * 0.165, C * 0.028, fill=(255, 215, 110, 255))
    # pot
    d.polygon([(c - C * 0.20, C * 0.76), (c + C * 0.20, C * 0.76),
               (c + C * 0.15, C * 0.94), (c - C * 0.15, C * 0.94)], fill=(200, 110, 70, 255))
    d.rectangle([c - C * 0.23, C * 0.72, c + C * 0.23, C * 0.80], fill=(225, 135, 85, 255))


@art("tree_01")
def _(im, d, C):
    c = C / 2
    # trunk
    d.polygon([(c - C * 0.05, C * 0.52), (c + C * 0.05, C * 0.52),
               (c + C * 0.09, C * 0.90), (c - C * 0.09, C * 0.90)], fill=(130, 85, 50, 255))
    d.line([(c, C * 0.62), (c - C * 0.12, C * 0.50)], fill=(130, 85, 50, 255),
           width=int(C * 0.035))
    # canopy: layered blobs
    for x, y, r, col in [(0.50, 0.30, 0.30, (60, 140, 70, 255)),
                         (0.28, 0.40, 0.20, (60, 140, 70, 255)),
                         (0.72, 0.40, 0.20, (60, 140, 70, 255)),
                         (0.42, 0.26, 0.20, (95, 175, 90, 255)),
                         (0.62, 0.32, 0.17, (95, 175, 90, 255)),
                         (0.33, 0.33, 0.13, (130, 200, 110, 255))]:
        circle(d, C * x, C * y, C * r, fill=col)
    # apples
    for x, y in ((0.34, 0.44), (0.56, 0.22), (0.68, 0.46), (0.48, 0.38)):
        circle(d, C * x, C * y, C * 0.038, fill=(220, 60, 60, 255))
        circle(d, C * x - C * 0.012, C * y - C * 0.012, C * 0.012, fill=(250, 140, 130, 255))
    # grass
    d.ellipse([C * 0.14, C * 0.86, C * 0.86, C * 0.96], fill=(90, 165, 80, 255))


@art("rainbow_01")
def _(im, d, C):
    c = C / 2
    base = C * 0.82
    bands = [(220, 60, 60, 255), (245, 140, 50, 255), (250, 205, 70, 255),
             (95, 175, 90, 255), (60, 140, 220, 255), (150, 90, 220, 255)]
    R0 = C * 0.44
    bw = C * 0.055
    for i, col in enumerate(bands):
        r = R0 - i * bw
        d.pieslice([c - r, base - r, c + r, base + r], 180, 360, fill=col)
    d.pieslice([c - (R0 - 6 * bw), base - (R0 - 6 * bw), c + (R0 - 6 * bw),
                base + (R0 - 6 * bw)], 180, 360, fill=(0, 0, 0, 0))
    d.rectangle([0, base, C, C], fill=(0, 0, 0, 0))
    # clouds
    for cx in (0.14, 0.86):
        for dx, dy, r in ((0, 0, 0.085), (-0.075, 0.03, 0.062), (0.075, 0.03, 0.062)):
            circle(d, C * (cx + dx), base - C * 0.02 + C * dy, C * r,
                   fill=(248, 248, 252, 255))
    sparkle(d, C * 0.30, C * 0.24, C * 0.045)
    sparkle(d, C * 0.72, C * 0.30, C * 0.04)


@art("ice_cream_01")
def _(im, d, C):
    c = C / 2
    # cone
    d.polygon([(c - C * 0.20, C * 0.52), (c + C * 0.20, C * 0.52), (c, C * 0.94)],
              fill=(225, 165, 90, 255))
    for i in range(3):  # waffle lattice
        f = 0.52 + i * 0.115
        w = 0.20 * (1 - i * 0.27)
        d.line([(c - C * w, C * f), (c + C * w * 0.4, C * (f + 0.14))],
               fill=(185, 125, 60, 255), width=S // 2)
        d.line([(c + C * w, C * f), (c - C * w * 0.4, C * (f + 0.14))],
               fill=(185, 125, 60, 255), width=S // 2)
    # scoops
    circle(d, c, C * 0.44, C * 0.215, fill=(250, 235, 215, 255))   # vanilla
    circle(d, c, C * 0.27, C * 0.185, fill=(245, 150, 170, 255))   # strawberry
    d.pieslice([c - C * 0.185, C * 0.085, c + C * 0.185, C * 0.455], 180, 300,
               fill=(250, 180, 195, 255))
    # drip
    d.pieslice([c - C * 0.06, C * 0.40, c + C * 0.02, C * 0.52], 0, 180,
               fill=(250, 235, 215, 255))
    # cherry + sprinkles
    circle(d, c, C * 0.075, C * 0.045, fill=(200, 40, 60, 255))
    circle(d, c - C * 0.015, C * 0.062, C * 0.014, fill=(245, 130, 140, 255))
    rnd = random.Random(2)
    cols = [(220, 60, 60, 255), (60, 140, 220, 255), (250, 205, 70, 255), (95, 175, 90, 255)]
    for i in range(9):
        a = rnd.uniform(math.pi, 2 * math.pi)
        rr = C * 0.16 * math.sqrt(rnd.uniform(0.2, 1))
        x, y = c + rr * math.cos(a) * 1.1, C * 0.27 + rr * math.sin(a)
        d.line([(x, y), (x + C * 0.02, y - C * 0.012)], fill=cols[i % 4], width=int(S * 0.75))


@art("pizza_01")
def _(im, d, C):
    c = C / 2
    # crust arc
    d.pieslice([c - C * 0.46, C * 0.02, c + C * 0.46, C * 0.94], 244, 296,
               fill=(200, 130, 60, 255))
    # cheese triangle
    d.polygon([(c - C * 0.35, C * 0.185), (c + C * 0.35, C * 0.185), (c, C * 0.92)],
              fill=(250, 205, 95, 255))
    # cheese drips over crust line
    for dx, r in ((-0.20, 0.045), (0.0, 0.055), (0.18, 0.04)):
        d.pieslice([c + C * dx - C * r, C * 0.16, c + C * dx + C * r, C * 0.16 + C * 2 * r],
                   0, 180, fill=(250, 205, 95, 255))
    # pepperoni
    for x, y, r in ((-0.13, 0.30, 0.065), (0.14, 0.32, 0.06), (0.0, 0.50, 0.062),
                    (-0.06, 0.68, 0.045)):
        circle(d, c + C * x, C * y, C * r, fill=(205, 70, 55, 255))
        circle(d, c + C * x - C * 0.015, C * y - C * 0.015, C * r * 0.3,
               fill=(230, 110, 90, 255))
    # herbs
    for x, y in ((0.10, 0.44), (-0.14, 0.52), (0.05, 0.62), (-0.02, 0.38)):
        d.line([(c + C * x, C * y), (c + C * x + C * 0.03, C * y - C * 0.02)],
               fill=(80, 140, 60, 255), width=int(S * 0.75))


# ---------------------------------------------------------------- themed

@art("cosmic_tarot")
def _(im, d, C):
    # card
    d.rounded_rectangle([C * 0.10, C * 0.03, C * 0.90, C * 0.97], radius=C * 0.05,
                        fill=(215, 170, 40, 255))
    d.rounded_rectangle([C * 0.13, C * 0.06, C * 0.87, C * 0.94], radius=C * 0.04,
                        fill=(25, 20, 60, 255))
    d.rounded_rectangle([C * 0.17, C * 0.10, C * 0.83, C * 0.90], radius=C * 0.03,
                        outline=(215, 170, 40, 255), width=S // 2)
    cx, cy = C / 2, C * 0.40
    # radiant moon
    for i in range(8):
        a = i * 45 + 22.5
        d.polygon(petal_pts(cx, cy, a, C * 0.17, C * 0.26, C * 0.020),
                  fill=(250, 205, 80, 255))
    circle(d, cx, cy, C * 0.155, fill=(250, 205, 80, 255))
    circle(d, cx + C * 0.055, cy - C * 0.02, C * 0.125, fill=(25, 20, 60, 255))
    circle(d, cx + C * 0.02, cy, C * 0.105, fill=(240, 240, 250, 255))
    # stars
    d.polygon(star_pts(C * 0.28, C * 0.20, C * 0.035, C * 0.014, 4), fill=(240, 240, 250, 255))
    d.polygon(star_pts(C * 0.73, C * 0.24, C * 0.028, C * 0.011, 4), fill=(250, 205, 80, 255))
    d.polygon(star_pts(C * 0.30, C * 0.60, C * 0.025, C * 0.010, 4), fill=(250, 205, 80, 255))
    d.polygon(star_pts(C * 0.72, C * 0.58, C * 0.032, C * 0.013, 4), fill=(240, 240, 250, 255))
    # mystic waves at card foot
    for k in range(3):
        y = C * (0.72 + k * 0.055)
        for i in range(6):
            x = C * (0.22 + i * 0.095)
            d.arc([x, y, x + C * 0.095, y + C * 0.05], 180, 360,
                  fill=(120, 100, 220, 255), width=S // 2)
    ring_dots(d, cx, cy, 6, C * 0.30, C * 0.012, (120, 100, 220, 255), rot=-90)


@art("cyberpunk_neon")
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(16, 10, 40, 255))
    # banded synth sun
    cx, sy = C / 2, C * 0.38
    for i, col in enumerate([(250, 205, 80, 255), (250, 160, 60, 255),
                             (245, 110, 90, 255), (235, 70, 130, 255)]):
        r = C * (0.30 - i * 0.055)
        d.pieslice([cx - r, sy - r, cx + r, sy + r], 180, 360, fill=col)
    for i in range(3):  # scanline gaps
        y = sy - C * (0.06 + i * 0.08)
        d.rectangle([cx - C * 0.32, y, cx + C * 0.32, y + C * 0.018], fill=(16, 10, 40, 255))
    # grid floor
    d.rectangle([0, sy, C, C], fill=(28, 16, 60, 255))
    for i in range(-4, 5):  # verticals converging
        d.line([(cx + i * C * 0.30, C), (cx + i * C * 0.075, sy)],
               fill=(235, 70, 200, 255), width=S // 2)
    for f in (0.44, 0.54, 0.68, 0.85):  # horizontals
        d.line([(0, C * f), (C, C * f)], fill=(235, 70, 200, 255), width=S // 2)
    # neon pyramid
    d.polygon([(cx - C * 0.26, C * 0.66), (cx, C * 0.24), (cx + C * 0.26, C * 0.66)],
              fill=(16, 10, 40, 255))
    d.line([(cx - C * 0.26, C * 0.66), (cx, C * 0.24)], fill=(80, 240, 235, 255),
           width=int(C * 0.022))
    d.line([(cx + C * 0.26, C * 0.66), (cx, C * 0.24)], fill=(80, 240, 235, 255),
           width=int(C * 0.022))
    d.line([(cx - C * 0.26, C * 0.66), (cx + C * 0.26, C * 0.66)],
           fill=(80, 240, 235, 255), width=int(C * 0.022))
    d.line([(cx + C * 0.06, C * 0.335), (cx + C * 0.13, C * 0.66)],
           fill=(140, 250, 245, 255), width=S // 2)
    # stars
    for x, y in ((0.12, 0.10), (0.30, 0.06), (0.72, 0.08), (0.88, 0.16), (0.08, 0.26)):
        circle(d, C * x, C * y, C * 0.012, fill=(200, 215, 245, 255))


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
