#!/usr/bin/env python3
"""Batch 2 of procedural artworks for the original (Pixely) flavor: 100 pieces
across animals, food, nature, ocean, celestial, mandalas, patterns and objects.

Shares the drawing toolkit with make_diamond_sources; writes into the same
tool/original_sources folder, so `python3 tool/build_artworks.py original`
converts both batches.

Usage:
    python3 tool/make_original_batch2.py           # all
    python3 tool/make_original_batch2.py id1 id2   # only these
"""
import math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_diamond_sources import (  # noqa: E402
    S, circle, crystal, heart_pts, ngon, petal_pts, ring_diamonds, ring_dots,
    ring_petals, rot0, sparkle, star_pts, teardrop_pts)
from PIL import Image, ImageDraw  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tool", "original_sources")

INK = (30, 30, 45, 255)
BLUSH = (250, 170, 185, 255)

ARTS = {}


def art(aid, grid=32):
    def deco(fn):
        ARTS[aid] = (grid, fn)
        return fn
    return deco


def eye(d, x, y, r):
    circle(d, x, y, r, fill=INK)
    circle(d, x - r * 0.35, y - r * 0.35, r * 0.40, fill=(255, 255, 255, 255))


def blush2(d, c, dx, y, r):
    for sx in (-1, 1):
        circle(d, c + sx * dx, y, r, fill=BLUSH)


def smile(d, x, y, w, h, col=INK, lw=None):
    d.arc([x - w, y - h, x + w, y + h], 20, 160, fill=col, width=lw or S)


def cloud(d, x, y, r, col=(248, 248, 252, 255)):
    for ddx, ddy, rr in ((0, 0, 1), (-0.95, 0.28, 0.68), (0.95, 0.28, 0.68)):
        circle(d, x + ddx * r, y + ddy * r, r * rr, fill=col)


def mandala(d, C, bg, layers):
    """Data-driven mandala: list of ('p'|'d'|'c'|'s'|'n', ...) layers, radii as
    fractions of C."""
    c = C / 2
    if bg:
        circle(d, c, c, C * 0.475, fill=bg)
    for L in layers:
        k = L[0]
        if k == 'p':
            _, n, r0, r1, w, col, *rot = L
            ring_petals(d, c, c, n, C * r0, C * r1, C * w, col, rot=rot[0] if rot else 0)
        elif k == 'd':
            _, n, r, dr, col, *rot = L
            ring_dots(d, c, c, n, C * r, C * dr, col, rot=rot[0] if rot else 0)
        elif k == 'c':
            _, r, col = L
            circle(d, c, c, C * r, fill=col)
        elif k == 's':
            _, ro, ri, n, col, *rot = L
            d.polygon(star_pts(c, c, C * ro, C * ri, n, rot=rot[0] if rot else -90), fill=col)
        elif k == 'n':
            _, r, n, col, *rot = L
            d.polygon(ngon(c, c, C * r, n, rot=rot[0] if rot else -90), fill=col)


# ================================================================ animals

@art("bear_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.30, C * 0.22, C * 0.12, fill=(150, 95, 55, 255))
        circle(d, c + sx * C * 0.30, C * 0.22, C * 0.06, fill=(225, 180, 140, 255))
    d.ellipse([c - C * 0.40, C * 0.18, c + C * 0.40, C * 0.90], fill=(150, 95, 55, 255))
    d.ellipse([c - C * 0.17, C * 0.56, c + C * 0.17, C * 0.82], fill=(225, 180, 140, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.17, C * 0.47, C * 0.042)
    blush2(d, c, C * 0.31, C * 0.58, C * 0.045)
    d.ellipse([c - C * 0.045, C * 0.60, c + C * 0.045, C * 0.67], fill=INK)
    smile(d, c, C * 0.68, C * 0.06, C * 0.055)


@art("koala_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.37, C * 0.30, C * 0.155, fill=(140, 145, 160, 255))
        circle(d, c + sx * C * 0.37, C * 0.30, C * 0.085, fill=(235, 190, 200, 255))
    d.ellipse([c - C * 0.36, C * 0.22, c + C * 0.36, C * 0.88], fill=(170, 175, 190, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.155, C * 0.46, C * 0.040)
    d.ellipse([c - C * 0.065, C * 0.52, c + C * 0.065, C * 0.70], fill=(60, 60, 75, 255))
    blush2(d, c, C * 0.27, C * 0.62, C * 0.045)
    smile(d, c, C * 0.73, C * 0.05, C * 0.045)


@art("bunny_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.20 - C * 0.085, C * 0.02, c + sx * C * 0.20 + C * 0.085,
                   C * 0.44], fill=(245, 242, 240, 255))
        d.ellipse([c + sx * C * 0.20 - C * 0.045, C * 0.08, c + sx * C * 0.20 + C * 0.045,
                   C * 0.38], fill=(250, 200, 210, 255))
    d.ellipse([c - C * 0.36, C * 0.34, c + C * 0.36, C * 0.92], fill=(245, 242, 240, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.16, C * 0.56, C * 0.040)
    blush2(d, c, C * 0.28, C * 0.68, C * 0.045)
    d.polygon([(c - C * 0.03, C * 0.65), (c + C * 0.03, C * 0.65), (c, C * 0.695)],
              fill=(240, 130, 150, 255))
    smile(d, c - C * 0.035, C * 0.71, C * 0.035, C * 0.03)
    smile(d, c + C * 0.035, C * 0.71, C * 0.035, C * 0.03)


@art("pig_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.14, C * 0.26), (c + sx * C * 0.38, C * 0.10),
                   (c + sx * C * 0.42, C * 0.36)], fill=(240, 150, 165, 255))
    d.ellipse([c - C * 0.40, C * 0.20, c + C * 0.40, C * 0.90], fill=(250, 180, 190, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.19, C * 0.44, C * 0.040)
    d.ellipse([c - C * 0.135, C * 0.52, c + C * 0.135, C * 0.72], fill=(235, 140, 155, 255))
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.05 - C * 0.02, C * 0.58, c + sx * C * 0.05 + C * 0.02,
                   C * 0.66], fill=(150, 70, 85, 255))
    blush2(d, c, C * 0.31, C * 0.56, C * 0.04)


@art("frog_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.20, C * 0.26, C * 0.135, fill=(95, 175, 90, 255))
        circle(d, c + sx * C * 0.20, C * 0.25, C * 0.085, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.19, C * 0.26, C * 0.045, fill=INK)
    d.ellipse([c - C * 0.40, C * 0.28, c + C * 0.40, C * 0.90], fill=(95, 175, 90, 255))
    smile(d, c, C * 0.60, C * 0.16, C * 0.10, lw=int(C * 0.025))
    blush2(d, c, C * 0.28, C * 0.62, C * 0.045)
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.045, C * 0.52, C * 0.014, fill=(60, 130, 65, 255))


@art("tiger_face")
def _(im, d, C):
    c = C / 2
    coat = (245, 150, 60, 255)
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.30, C * 0.24, C * 0.115, fill=coat)
        circle(d, c + sx * C * 0.30, C * 0.24, C * 0.06, fill=(255, 235, 210, 255))
    d.ellipse([c - C * 0.40, C * 0.20, c + C * 0.40, C * 0.90], fill=coat)
    for dx in (-0.13, 0.0, 0.13):
        d.polygon(petal_pts(c + C * dx, C * 0.20, 90, 0, C * 0.10, C * 0.024), fill=INK)
    for sx in (-1, 1):
        d.polygon(petal_pts(c + sx * C * 0.40, C * 0.48, 90 - sx * 90, 0, C * 0.10,
                            C * 0.024), fill=INK)
        eye(d, c + sx * C * 0.17, C * 0.45, C * 0.040)
    d.ellipse([c - C * 0.16, C * 0.56, c + C * 0.16, C * 0.82], fill=(255, 235, 210, 255))
    d.polygon([(c - C * 0.035, C * 0.62), (c + C * 0.035, C * 0.62), (c, C * 0.665)],
              fill=(200, 90, 100, 255))
    smile(d, c - C * 0.04, C * 0.665, C * 0.04, C * 0.035)
    smile(d, c + C * 0.04, C * 0.665, C * 0.04, C * 0.035)


@art("lion_face")
def _(im, d, C):
    c = C / 2
    ring_petals(d, c, c, 14, C * 0.28, C * 0.48, C * 0.075, (200, 120, 40, 255),
                rot=180 / 14)
    circle(d, c, c, C * 0.335, fill=(245, 190, 100, 255))
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.24, C * 0.28, C * 0.07, fill=(245, 190, 100, 255))
        circle(d, c + sx * C * 0.24, C * 0.28, C * 0.035, fill=(200, 120, 40, 255))
        eye(d, c + sx * C * 0.14, C * 0.44, C * 0.038)
    d.ellipse([c - C * 0.13, C * 0.53, c + C * 0.13, C * 0.74], fill=(255, 230, 185, 255))
    d.polygon([(c - C * 0.035, C * 0.56), (c + C * 0.035, C * 0.56), (c, C * 0.61)],
              fill=(150, 85, 45, 255))
    smile(d, c - C * 0.04, C * 0.615, C * 0.04, C * 0.035)
    smile(d, c + C * 0.04, C * 0.615, C * 0.04, C * 0.035)
    blush2(d, c, C * 0.25, C * 0.55, C * 0.038)


@art("mouse_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.30, C * 0.26, C * 0.165, fill=(165, 170, 185, 255))
        circle(d, c + sx * C * 0.30, C * 0.26, C * 0.10, fill=(250, 200, 210, 255))
    d.ellipse([c - C * 0.33, C * 0.32, c + C * 0.33, C * 0.90], fill=(190, 195, 210, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.14, C * 0.55, C * 0.040)
    blush2(d, c, C * 0.24, C * 0.67, C * 0.042)
    circle(d, c, C * 0.68, C * 0.032, fill=(240, 130, 150, 255))
    for sx in (-1, 1):
        d.line([(c + sx * C * 0.06, C * 0.68), (c + sx * C * 0.22, C * 0.66)],
               fill=(120, 125, 140, 255), width=S // 2)
        d.line([(c + sx * C * 0.06, C * 0.71), (c + sx * C * 0.21, C * 0.74)],
               fill=(120, 125, 140, 255), width=S // 2)


@art("hamster_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.26, C * 0.20, C * 0.085, fill=(225, 165, 100, 255))
        circle(d, c + sx * C * 0.26, C * 0.20, C * 0.045, fill=(250, 210, 170, 255))
    d.ellipse([c - C * 0.40, C * 0.18, c + C * 0.40, C * 0.92], fill=(235, 180, 115, 255))
    for sx in (-1, 1):  # white cheeks
        circle(d, c + sx * C * 0.20, C * 0.64, C * 0.155, fill=(252, 240, 225, 255))
        eye(d, c + sx * C * 0.17, C * 0.42, C * 0.042)
    d.ellipse([c - C * 0.03, C * 0.53, c + C * 0.03, C * 0.585], fill=(240, 130, 150, 255))
    smile(d, c - C * 0.035, C * 0.585, C * 0.035, C * 0.03)
    smile(d, c + C * 0.035, C * 0.585, C * 0.035, C * 0.03)
    blush2(d, c, C * 0.31, C * 0.50, C * 0.038)


@art("owl_branch", 48)
def _(im, d, C):
    c = C / 2
    d.line([(C * 0.10, C * 0.87), (C * 0.90, C * 0.83)], fill=(120, 80, 50, 255),
           width=int(C * 0.04))
    for sx in (-1, 1):  # ear tufts
        d.polygon([(c + sx * C * 0.10, C * 0.16), (c + sx * C * 0.26, C * 0.04),
                   (c + sx * C * 0.28, C * 0.22)], fill=(150, 100, 60, 255))
    d.ellipse([c - C * 0.28, C * 0.10, c + C * 0.28, C * 0.84], fill=(175, 120, 70, 255))
    d.pieslice([c - C * 0.20, C * 0.38, c + C * 0.20, C * 0.82], 0, 180,
               fill=(235, 205, 165, 255))
    for k in range(3):  # belly scallops
        y = C * (0.52 + k * 0.09)
        for i in range(3 - (k % 2)):
            x = c + (i - (2 - k % 2) / 2) * C * 0.10
            d.arc([x - C * 0.05, y, x + C * 0.05, y + C * 0.06], 180, 360,
                  fill=(175, 120, 70, 255), width=S // 2)
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.13, C * 0.30, C * 0.115, fill=(255, 250, 240, 255))
        circle(d, c + sx * C * 0.13, C * 0.30, C * 0.06, fill=(245, 160, 40, 255))
        circle(d, c + sx * C * 0.125, C * 0.30, C * 0.032, fill=INK)
    d.polygon([(c - C * 0.035, C * 0.38), (c + C * 0.035, C * 0.38), (c, C * 0.45)],
              fill=(245, 160, 40, 255))
    for fx in (-0.08, 0.08):
        d.line([(c + C * fx, C * 0.82), (c + C * fx, C * 0.87)],
               fill=(245, 160, 40, 255), width=int(C * 0.02))
    sparkle(d, C * 0.85, C * 0.14, C * 0.035)


@art("penguin")
def _(im, d, C):
    c = C / 2
    d.ellipse([c - C * 0.30, C * 0.10, c + C * 0.30, C * 0.88], fill=(45, 50, 70, 255))
    d.ellipse([c - C * 0.21, C * 0.30, c + C * 0.21, C * 0.86], fill=(248, 248, 252, 255))
    for sx in (-1, 1):  # flippers
        d.polygon(petal_pts(c + sx * C * 0.28, C * 0.42, 90 + sx * 35, 0, C * 0.26,
                            C * 0.055), fill=(45, 50, 70, 255))
        eye(d, c + sx * C * 0.11, C * 0.30, C * 0.038)
    d.polygon([(c - C * 0.05, C * 0.38), (c + C * 0.05, C * 0.38), (c, C * 0.46)],
              fill=(245, 160, 40, 255))
    blush2(d, c, C * 0.20, C * 0.40, C * 0.038)
    for sx in (-1, 1):
        d.pieslice([c + sx * C * 0.10 - C * 0.075, C * 0.84, c + sx * C * 0.10 + C * 0.075,
                    C * 0.94], 180, 360, fill=(245, 160, 40, 255))
    circle(d, C * 0.14, C * 0.16, C * 0.022, fill=(200, 225, 250, 255))
    circle(d, C * 0.85, C * 0.24, C * 0.018, fill=(200, 225, 250, 255))


@art("chick_hatch")
def _(im, d, C):
    c = C / 2
    circle(d, c, C * 0.42, C * 0.28, fill=(255, 215, 80, 255))
    for sx in (-1, 1):
        d.polygon(petal_pts(c + sx * C * 0.26, C * 0.44, 90 + sx * 55, 0, C * 0.14,
                            C * 0.045), fill=(240, 185, 50, 255))
        eye(d, c + sx * C * 0.11, C * 0.38, C * 0.036)
    d.polygon([(c - C * 0.04, C * 0.45), (c + C * 0.04, C * 0.45), (c, C * 0.51)],
              fill=(245, 140, 50, 255))
    blush2(d, c, C * 0.19, C * 0.47, C * 0.035)
    circle(d, c - C * 0.10, C * 0.24, C * 0.04, fill=(255, 240, 160, 255))
    # egg shell cup with zigzag rim
    shell_t = C * 0.58
    pts = [(c - C * 0.30, shell_t)]
    for i in range(6):
        x0 = c - C * 0.30 + (i + 0.5) * C * 0.10
        pts.append((x0, shell_t + (C * 0.07 if i % 2 == 0 else 0)))
    pts += [(c + C * 0.30, shell_t), (c + C * 0.26, C * 0.90), (c - C * 0.26, C * 0.90)]
    d.polygon(pts, fill=(248, 244, 235, 255))
    d.arc([c - C * 0.26, C * 0.74, c + C * 0.26, C * 1.02], 200, 340,
          fill=(225, 215, 200, 255), width=S // 2)
    sparkle(d, C * 0.83, C * 0.20, C * 0.04)


@art("cow_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.22, C * 0.20), (c + sx * C * 0.33, C * 0.06),
                   (c + sx * C * 0.40, C * 0.20)], fill=(230, 220, 210, 255))
        d.ellipse([c + sx * C * 0.44 - C * 0.10, C * 0.30, c + sx * C * 0.44 + C * 0.10,
                   C * 0.44], fill=(240, 200, 205, 255))
    d.ellipse([c - C * 0.38, C * 0.16, c + C * 0.38, C * 0.88], fill=(250, 248, 245, 255))
    d.ellipse([c - C * 0.33, C * 0.20, c - C * 0.02, C * 0.46], fill=(60, 60, 75, 255))
    circle(d, c + C * 0.26, C * 0.62, C * 0.09, fill=(60, 60, 75, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.16, C * 0.42, C * 0.038)
    d.ellipse([c - C * 0.19, C * 0.58, c + C * 0.19, C * 0.84], fill=(250, 190, 200, 255))
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.08 - C * 0.025, C * 0.66, c + sx * C * 0.08 + C * 0.025,
                   C * 0.74], fill=(200, 120, 140, 255))


@art("sheep_fluffy")
def _(im, d, C):
    c = C / 2
    for i in range(10):  # wool ring
        a = math.radians(i * 36)
        circle(d, c + C * 0.28 * math.cos(a), C * 0.50 + C * 0.28 * math.sin(a),
               C * 0.135, fill=(248, 246, 242, 255))
    circle(d, c, C * 0.50, C * 0.30, fill=(248, 246, 242, 255))
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.30 - C * 0.09, C * 0.44, c + sx * C * 0.30 + C * 0.09,
                   C * 0.56], fill=(200, 160, 140, 255))
    d.ellipse([c - C * 0.19, C * 0.34, c + C * 0.19, C * 0.68], fill=(225, 190, 165, 255))
    for sx in (-1, 1):
        smile(d, c + sx * C * 0.085 - C * 0.035, C * 0.46, C * 0.035, C * 0.035,
              lw=int(C * 0.02))
    blush2(d, c, C * 0.14, C * 0.55, C * 0.032)
    d.ellipse([c - C * 0.025, C * 0.55, c + C * 0.025, C * 0.595], fill=(150, 110, 90, 255))
    tuft_y = C * 0.245
    circle(d, c - C * 0.05, tuft_y, C * 0.06, fill=(255, 255, 255, 255))
    circle(d, c + C * 0.05, tuft_y, C * 0.05, fill=(255, 255, 255, 255))


@art("monkey_face")
def _(im, d, C):
    c = C / 2
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.40, C * 0.48, C * 0.105, fill=(150, 100, 60, 255))
        circle(d, c + sx * C * 0.40, C * 0.48, C * 0.055, fill=(235, 195, 160, 255))
    d.ellipse([c - C * 0.36, C * 0.18, c + C * 0.36, C * 0.88], fill=(150, 100, 60, 255))
    for sx in (-1, 1):  # tan face patch (two lobes + muzzle)
        circle(d, c + sx * C * 0.13, C * 0.42, C * 0.155, fill=(235, 195, 160, 255))
    d.ellipse([c - C * 0.20, C * 0.48, c + C * 0.20, C * 0.80], fill=(235, 195, 160, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.13, C * 0.42, C * 0.038)
        d.ellipse([c + sx * C * 0.05 - C * 0.018, C * 0.60, c + sx * C * 0.05 + C * 0.018,
                   C * 0.66], fill=(120, 75, 45, 255))
    smile(d, c, C * 0.66, C * 0.09, C * 0.06, col=(120, 75, 45, 255), lw=int(C * 0.02))
    blush2(d, c, C * 0.26, C * 0.56, C * 0.035)


@art("raccoon_face")
def _(im, d, C):
    c = C / 2
    grey = (160, 165, 180, 255)
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.10, C * 0.26), (c + sx * C * 0.34, C * 0.08),
                   (c + sx * C * 0.40, C * 0.34)], fill=grey)
        d.polygon([(c + sx * C * 0.18, C * 0.26), (c + sx * C * 0.31, C * 0.15),
                   (c + sx * C * 0.34, C * 0.29)], fill=(90, 95, 110, 255))
    d.ellipse([c - C * 0.40, C * 0.20, c + C * 0.40, C * 0.88], fill=grey)
    for sx in (-1, 1):  # dark mask
        d.ellipse([c + sx * C * 0.20 - C * 0.15, C * 0.36, c + sx * C * 0.20 + C * 0.15,
                   C * 0.58], fill=(75, 80, 95, 255))
        eye(d, c + sx * C * 0.18, C * 0.47, C * 0.040)
    d.ellipse([c - C * 0.15, C * 0.56, c + C * 0.15, C * 0.82], fill=(240, 240, 245, 255))
    d.ellipse([c - C * 0.04, C * 0.60, c + C * 0.04, C * 0.665], fill=INK)
    smile(d, c, C * 0.68, C * 0.05, C * 0.04)
    blush2(d, c, C * 0.31, C * 0.60, C * 0.038)


@art("deer_face")
def _(im, d, C):
    c = C / 2
    antler = (150, 110, 75, 255)
    for sx in (-1, 1):
        x0 = c + sx * C * 0.22
        d.line([(x0, C * 0.24), (x0 + sx * C * 0.06, C * 0.06)], fill=antler,
               width=int(C * 0.028))
        d.line([(x0 + sx * C * 0.03, C * 0.15), (x0 + sx * C * 0.14, C * 0.09)],
               fill=antler, width=int(C * 0.024))
        d.ellipse([c + sx * C * 0.40 - C * 0.10, C * 0.28, c + sx * C * 0.40 + C * 0.10,
                   C * 0.42], fill=(200, 150, 105, 255))
        d.ellipse([c + sx * C * 0.40 - C * 0.05, C * 0.315, c + sx * C * 0.40 + C * 0.05,
                   C * 0.395], fill=(245, 215, 190, 255))
    d.ellipse([c - C * 0.36, C * 0.22, c + C * 0.36, C * 0.88], fill=(215, 165, 115, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.16, C * 0.46, C * 0.040)
        circle(d, c + sx * C * 0.24, C * 0.32, C * 0.020, fill=(245, 215, 190, 255))
        circle(d, c + sx * C * 0.31, C * 0.40, C * 0.016, fill=(245, 215, 190, 255))
    d.ellipse([c - C * 0.14, C * 0.60, c + C * 0.14, C * 0.84], fill=(245, 215, 190, 255))
    d.ellipse([c - C * 0.045, C * 0.63, c + C * 0.045, C * 0.70], fill=(90, 60, 45, 255))
    smile(d, c, C * 0.71, C * 0.05, C * 0.04, col=(90, 60, 45, 255))
    blush2(d, c, C * 0.28, C * 0.58, C * 0.038)


@art("duckling")
def _(im, d, C):
    c = C / 2
    d.rectangle([0, C * 0.76, C, C * 0.88], fill=(150, 210, 240, 255))
    for wx in (0.14, 0.5, 0.84):
        d.arc([C * wx - C * 0.08, C * 0.76, C * wx + C * 0.08, C * 0.84], 180, 360,
              fill=(110, 180, 225, 255), width=S // 2)
    body = (255, 215, 80, 255)
    d.ellipse([c - C * 0.26, C * 0.42, c + C * 0.26, C * 0.80], fill=body)
    d.polygon(petal_pts(c + C * 0.20, C * 0.56, -20, 0, C * 0.16, C * 0.05),
              fill=(240, 185, 50, 255))
    circle(d, c - C * 0.13, C * 0.34, C * 0.165, fill=body)
    circle(d, c - C * 0.19, C * 0.26, C * 0.05, fill=(255, 240, 160, 255))
    eye(d, c - C * 0.19, C * 0.32, C * 0.036)
    d.pieslice([c - C * 0.40, C * 0.335, c - C * 0.24, C * 0.425], -30, 150,
               fill=(245, 140, 50, 255))
    circle(d, c - C * 0.065, C * 0.40, C * 0.038, fill=BLUSH)
    d.polygon(petal_pts(c + C * 0.02, C * 0.58, 205, 0, C * 0.14, C * 0.05),
              fill=(240, 185, 50, 255))


@art("ladybug")
def _(im, d, C):
    c = C / 2
    # antennae + head
    for sx in (-1, 1):
        d.line([(c + sx * C * 0.06, C * 0.20), (c + sx * C * 0.14, C * 0.08)],
               fill=INK, width=S // 2)
        circle(d, c + sx * C * 0.14, C * 0.08, C * 0.020, fill=INK)
    circle(d, c, C * 0.28, C * 0.14, fill=(45, 45, 60, 255))
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.06, C * 0.25, C * 0.028, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.055, C * 0.255, C * 0.014, fill=INK)
    # dome
    d.ellipse([c - C * 0.34, C * 0.24, c + C * 0.34, C * 0.92], fill=(220, 60, 60, 255))
    d.line([(c, C * 0.26), (c, C * 0.92)], fill=(45, 45, 60, 255), width=int(C * 0.022))
    for x, y, r in ((-0.17, 0.42, 0.05), (0.17, 0.42, 0.05), (-0.20, 0.64, 0.042),
                    (0.20, 0.64, 0.042), (-0.10, 0.80, 0.036), (0.10, 0.80, 0.036)):
        circle(d, c + C * x, C * y, C * r, fill=(45, 45, 60, 255))
    circle(d, c - C * 0.16, C * 0.32, C * 0.028, fill=(245, 130, 120, 255))


@art("bumble_bee")
def _(im, d, C):
    c = C / 2
    # dotted flight path
    for i, (x, y) in enumerate([(0.10, 0.80), (0.18, 0.68), (0.14, 0.55), (0.22, 0.44)]):
        circle(d, C * x, C * y, C * 0.014, fill=(180, 190, 210, 255))
    # wings
    for sx, dy in ((-1, 0), (1, 0)):
        d.ellipse([c + sx * C * 0.02 - C * 0.13, C * 0.10, c + sx * C * 0.02 + C * 0.13 + sx * C * 0.10,
                   C * 0.34], fill=(210, 230, 250, 255))
    # body
    d.ellipse([c - C * 0.30, C * 0.30, c + C * 0.34, C * 0.74], fill=(255, 205, 60, 255))
    for fx in (0.045, -0.15):
        d.ellipse([c - C * fx - C * 0.045, C * 0.315, c - C * fx + C * 0.045, C * 0.725],
                  fill=(45, 45, 60, 255))
    d.polygon([(c + C * 0.33, C * 0.46), (c + C * 0.44, C * 0.52), (c + C * 0.33, C * 0.58)],
              fill=(45, 45, 60, 255))
    eye(d, c - C * 0.20, C * 0.46, C * 0.036)
    circle(d, c - C * 0.13, C * 0.57, C * 0.032, fill=(250, 150, 110, 255))
    smile(d, c - C * 0.20, C * 0.55, C * 0.035, C * 0.03)


@art("garden_snail")
def _(im, d, C):
    c = C / 2
    # body
    d.rounded_rectangle([C * 0.10, C * 0.62, C * 0.86, C * 0.80], radius=C * 0.09,
                        fill=(235, 200, 150, 255))
    d.ellipse([C * 0.10, C * 0.42, C * 0.30, C * 0.72], fill=(235, 200, 150, 255))
    for sx in (0.14, 0.24):
        d.line([(C * sx, C * 0.44), (C * (sx - 0.02), C * 0.30)],
               fill=(235, 200, 150, 255), width=int(C * 0.026))
        circle(d, C * (sx - 0.02), C * 0.30, C * 0.026, fill=(200, 160, 110, 255))
    eye(d, C * 0.17, C * 0.52, C * 0.030)
    circle(d, C * 0.14, C * 0.60, C * 0.026, fill=BLUSH)
    # spiral shell
    sx, sy = C * 0.58, C * 0.46
    circle(d, sx, sy, C * 0.26, fill=(210, 120, 70, 255))
    for r, a0, a1 in ((0.20, -90, 180), (0.14, -90, 140), (0.08, -90, 100)):
        d.arc([sx - C * r, sy - C * r, sx + C * r, sy + C * r], a0, a1,
              fill=(150, 80, 45, 255), width=int(C * 0.030))
    circle(d, sx - C * 0.08, sy - C * 0.14, C * 0.045, fill=(240, 170, 120, 255))


@art("hedgehog")
def _(im, d, C):
    c = C / 2
    bx, by = c + C * 0.08, C * 0.54  # spiky back centre
    # spikes fan over the back (up and right)
    for i in range(8):
        a = -150 + i * 24
        d.polygon(petal_pts(bx, by, a, C * 0.12, C * 0.40, C * 0.05),
                  fill=(140, 95, 60, 255))
    circle(d, bx, by, C * 0.28, fill=(170, 120, 75, 255))
    # face pointing left
    d.ellipse([c - C * 0.42, C * 0.42, c + C * 0.10, C * 0.80], fill=(245, 220, 190, 255))
    d.polygon([(c - C * 0.28, C * 0.52), (c - C * 0.46, C * 0.66), (c - C * 0.24, C * 0.72)],
              fill=(245, 220, 190, 255))
    circle(d, c - C * 0.43, C * 0.655, C * 0.038, fill=(90, 60, 45, 255))  # nose
    eye(d, c - C * 0.16, C * 0.56, C * 0.038)
    circle(d, c - C * 0.06, C * 0.68, C * 0.036, fill=BLUSH)
    # ear
    circle(d, c - C * 0.06, C * 0.44, C * 0.045, fill=(225, 190, 155, 255))
    # feet
    for fx in (-0.10, 0.14):
        d.ellipse([c + C * fx, C * 0.78, c + C * fx + C * 0.10, C * 0.86],
                  fill=(140, 95, 60, 255))
    sparkle(d, C * 0.84, C * 0.20, C * 0.04)


@art("sloth_face")
def _(im, d, C):
    c = C / 2
    d.ellipse([c - C * 0.40, C * 0.22, c + C * 0.40, C * 0.86], fill=(200, 175, 140, 255))
    d.ellipse([c - C * 0.30, C * 0.34, c + C * 0.30, C * 0.80], fill=(240, 225, 200, 255))
    for sx in (-1, 1):  # eye patches
        d.polygon(petal_pts(c + sx * C * 0.17, C * 0.47, 90 - sx * 40, -C * 0.10,
                            C * 0.13, C * 0.055), fill=(150, 120, 90, 255))
        eye(d, c + sx * C * 0.15, C * 0.48, C * 0.036)
    d.ellipse([c - C * 0.05, C * 0.58, c + C * 0.05, C * 0.65], fill=(90, 70, 55, 255))
    smile(d, c, C * 0.66, C * 0.09, C * 0.06, col=(120, 95, 70, 255), lw=int(C * 0.02))
    blush2(d, c, C * 0.28, C * 0.60, C * 0.035)


@art("unicorn", 48)
def _(im, d, C):
    c = C / 2
    mane = [(220, 60, 60, 255), (245, 140, 50, 255), (250, 205, 70, 255),
            (95, 175, 90, 255), (60, 140, 220, 255), (150, 90, 220, 255)]
    # rainbow mane framing the head (both sides)
    for i, col in enumerate(mane):
        r = C * (0.44 - i * 0.032)
        d.arc([c - r, C * 0.52 - r, c + r, C * 0.52 + r], 150, 390,
              fill=col, width=int(C * 0.036))
    # ears
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.10, C * 0.30), (c + sx * C * 0.22, C * 0.16),
                   (c + sx * C * 0.26, C * 0.34)], fill=(248, 246, 250, 255))
        d.polygon([(c + sx * C * 0.145, C * 0.29), (c + sx * C * 0.205, C * 0.21),
                   (c + sx * C * 0.225, C * 0.30)], fill=(250, 200, 210, 255))
    # golden horn
    d.polygon([(c - C * 0.045, C * 0.30), (c + C * 0.045, C * 0.30), (c, C * 0.045)],
              fill=(250, 205, 80, 255))
    for f in (0.13, 0.20):
        d.line([(c - C * 0.030, C * (f + 0.045)), (c + C * 0.030, C * f)],
               fill=(215, 160, 40, 255), width=S // 2)
    # head
    d.ellipse([c - C * 0.30, C * 0.30, c + C * 0.30, C * 0.82], fill=(248, 246, 250, 255))
    # closed happy eyes with lashes
    for sx in (-1, 1):
        ex = c + sx * C * 0.125
        d.arc([ex - C * 0.05, C * 0.50, ex + C * 0.05, C * 0.60], 200, 340, fill=INK,
              width=int(C * 0.018))
        d.line([(ex + sx * C * 0.05, C * 0.525), (ex + sx * C * 0.085, C * 0.50)],
               fill=INK, width=S // 2)
    blush2(d, c, C * 0.21, C * 0.63, C * 0.032)
    d.ellipse([c - C * 0.022, C * 0.645, c + C * 0.022, C * 0.685], fill=(220, 150, 170, 255))
    smile(d, c, C * 0.685, C * 0.035, C * 0.03, lw=int(C * 0.016))
    d.polygon(star_pts(C * 0.12, C * 0.16, C * 0.042, C * 0.017, 4), fill=(250, 205, 80, 255))
    d.polygon(star_pts(C * 0.87, C * 0.13, C * 0.036, C * 0.014, 4), fill=(200, 160, 250, 255))
    sparkle(d, C * 0.88, C * 0.72, C * 0.032)


# ================================================================ food & sweets

@art("cupcake", 48)
def _(im, d, C):
    c = C / 2
    # wrapper
    d.polygon([(c - C * 0.26, C * 0.56), (c + C * 0.26, C * 0.56),
               (c + C * 0.19, C * 0.90), (c - C * 0.19, C * 0.90)],
              fill=(240, 150, 165, 255))
    for i in range(5):
        x = c - C * 0.20 + i * C * 0.10
        d.line([(x, C * 0.58), (x * 0.25 + c * 0.75 + (x - c) * 0.5, C * 0.89)],
               fill=(215, 110, 130, 255), width=S // 2)
    # frosting swirl (stacked blobs)
    for y, w in ((0.52, 0.28), (0.42, 0.22), (0.33, 0.15)):
        d.ellipse([c - C * w, C * (y - 0.075), c + C * w, C * (y + 0.075)],
                  fill=(250, 235, 215, 255))
    d.pieslice([c - C * 0.085, C * 0.20, c + C * 0.085, C * 0.34], 0, 360,
               fill=(250, 235, 215, 255))
    # cherry
    circle(d, c, C * 0.185, C * 0.055, fill=(210, 45, 65, 255))
    circle(d, c - C * 0.018, C * 0.17, C * 0.016, fill=(245, 130, 140, 255))
    # sprinkles
    rnd = random.Random(8)
    cols = [(220, 60, 60, 255), (60, 140, 220, 255), (250, 165, 60, 255),
            (95, 175, 90, 255), (200, 90, 220, 255)]
    for i in range(10):
        x = c + C * rnd.uniform(-0.22, 0.22)
        y = C * rnd.uniform(0.34, 0.52)
        d.line([(x, y), (x + C * 0.025, y - C * 0.015)], fill=cols[i % 5],
               width=int(S * 0.75))


@art("donut_sprinkles")
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.42, fill=(225, 170, 110, 255))
    circle(d, c, c, C * 0.40, fill=(240, 130, 160, 255))
    # wavy glaze edge
    for i in range(10):
        a = math.radians(i * 36 + 18)
        circle(d, c + C * 0.36 * math.cos(a), c + C * 0.36 * math.sin(a), C * 0.075,
               fill=(240, 130, 160, 255))
    circle(d, c, c, C * 0.13, fill=(225, 170, 110, 255))
    circle(d, c, c, C * 0.095, fill=(0, 0, 0, 0))
    rnd = random.Random(5)
    cols = [(255, 240, 130, 255), (120, 220, 200, 255), (255, 255, 255, 255),
            (140, 100, 240, 255), (250, 165, 60, 255)]
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        rr = C * rnd.uniform(0.18, 0.34)
        x, y = c + rr * math.cos(a), c + rr * math.sin(a)
        d.line([(x, y), (x + C * 0.035 * math.cos(a + 1), y + C * 0.035 * math.sin(a + 1))],
               fill=cols[i % 5], width=int(S * 0.9))


@art("strawberry")
def _(im, d, C):
    c = C / 2
    # berry
    d.polygon(heart_pts(c, c * 1.16, C * 0.42), fill=(225, 55, 70, 255))
    d.ellipse([c - C * 0.36, C * 0.26, c + C * 0.36, C * 0.62], fill=(225, 55, 70, 255))
    d.ellipse([c - C * 0.30, C * 0.30, c - C * 0.02, C * 0.50], fill=(245, 105, 110, 255))
    # seeds
    for x, y in ((-0.18, 0.48), (0.0, 0.42), (0.18, 0.48), (-0.20, 0.64), (0.02, 0.60),
                 (0.20, 0.64), (-0.10, 0.76), (0.10, 0.76), (0.0, 0.87)):
        d.ellipse([c + C * x - C * 0.016, C * y, c + C * x + C * 0.016, C * (y + 0.045)],
                  fill=(255, 225, 150, 255))
    # calyx + stem
    for i in range(5):
        d.polygon(petal_pts(c, C * 0.27, i * 36 + 18, 0, C * 0.14, C * 0.035),
                  fill=(80, 160, 80, 255))
    d.line([(c, C * 0.24), (c + C * 0.03, C * 0.10)], fill=(60, 130, 65, 255),
           width=int(C * 0.03))
    sparkle(d, C * 0.80, C * 0.28, C * 0.04)


@art("watermelon_slice")
def _(im, d, C):
    c = C / 2
    base = C * 0.74
    R = C * 0.42
    d.pieslice([c - R, base - R, c + R, base + R], 180, 360, fill=(70, 150, 80, 255))
    d.pieslice([c - R * 0.93, base - R * 0.93, c + R * 0.93, base + R * 0.93], 180, 360,
               fill=(200, 240, 190, 255))
    d.pieslice([c - R * 0.84, base - R * 0.84, c + R * 0.84, base + R * 0.84], 180, 360,
               fill=(240, 90, 100, 255))
    for x, y in ((-0.22, 0.56), (0.0, 0.44), (0.22, 0.56), (-0.11, 0.64), (0.11, 0.64),
                 (0.0, 0.68)):
        d.ellipse([c + C * x - C * 0.018, C * y, c + C * x + C * 0.018, C * (y + 0.05)],
                  fill=(45, 45, 60, 255))
    circle(d, c - C * 0.20, C * 0.44, C * 0.035, fill=(250, 150, 155, 255))


@art("avocado")
def _(im, d, C):
    c = C / 2
    def avo(fw, col):
        d.ellipse([c - C * fw, C * 0.30, c + C * fw, C * 0.92], fill=col)
        circle(d, c, C * 0.34 + C * fw * 0.3, C * fw * 0.82, fill=col)
    avo(0.30, (70, 120, 55, 255))
    avo(0.26, (200, 225, 140, 255))
    circle(d, c, C * 0.62, C * 0.15, fill=(160, 110, 60, 255))
    circle(d, c - C * 0.05, C * 0.57, C * 0.05, fill=(200, 155, 100, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.14, C * 0.40, C * 0.030)
    smile(d, c, C * 0.44, C * 0.05, C * 0.04)
    blush2(d, c, C * 0.21, C * 0.47, C * 0.030)


@art("boba_tea", 48)
def _(im, d, C):
    c = C / 2
    # straw
    d.polygon([(c + C * 0.02, C * 0.04), (c + C * 0.10, C * 0.06), (c + C * 0.04, C * 0.50),
               (c - C * 0.04, C * 0.50)], fill=(240, 120, 150, 255))
    # cup
    d.polygon([(c - C * 0.24, C * 0.20), (c + C * 0.24, C * 0.20),
               (c + C * 0.185, C * 0.90), (c - C * 0.185, C * 0.90)],
              fill=(245, 225, 205, 255))
    # milk tea gradient band
    d.polygon([(c - C * 0.225, C * 0.30), (c + C * 0.225, C * 0.30),
               (c + C * 0.19, C * 0.86), (c - C * 0.19, C * 0.86)],
              fill=(230, 190, 150, 255))
    d.polygon([(c - C * 0.21, C * 0.42), (c + C * 0.21, C * 0.42),
               (c + C * 0.19, C * 0.60), (c - C * 0.19, C * 0.60)],
              fill=(215, 170, 125, 255))
    # pearls
    for i in range(4):
        circle(d, c - C * 0.135 + i * C * 0.09, C * 0.82, C * 0.038, fill=(70, 50, 45, 255))
    for i in range(3):
        circle(d, c - C * 0.09 + i * C * 0.09, C * 0.745, C * 0.038, fill=(70, 50, 45, 255))
    # lid + face
    d.rectangle([c - C * 0.26, C * 0.185, c + C * 0.26, C * 0.24], fill=(250, 245, 240, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.09, C * 0.52, C * 0.028)
    smile(d, c, C * 0.56, C * 0.04, C * 0.035)
    blush2(d, c, C * 0.15, C * 0.58, C * 0.026)
    sparkle(d, C * 0.80, C * 0.30, C * 0.035)


@art("sushi_roll")
def _(im, d, C):
    c = C / 2
    # plate shadow
    d.ellipse([C * 0.10, C * 0.74, C * 0.90, C * 0.92], fill=(150, 210, 240, 255))
    # nori circle
    circle(d, c, C * 0.48, C * 0.32, fill=(45, 60, 55, 255))
    circle(d, c, C * 0.48, C * 0.26, fill=(245, 245, 235, 255))
    # filling
    circle(d, c - C * 0.06, C * 0.44, C * 0.085, fill=(240, 110, 90, 255))   # salmon
    circle(d, c + C * 0.08, C * 0.50, C * 0.065, fill=(130, 200, 120, 255))  # avocado
    circle(d, c + C * 0.01, C * 0.57, C * 0.05, fill=(250, 205, 95, 255))    # tamago
    # rice texture
    for a in range(8):
        ar = math.radians(a * 45 + 22)
        circle(d, c + C * 0.21 * math.cos(ar), C * 0.48 + C * 0.21 * math.sin(ar),
               C * 0.020, fill=(255, 255, 255, 255))
    sparkle(d, C * 0.80, C * 0.22, C * 0.04)


@art("burger", 48)
def _(im, d, C):
    c = C / 2
    # bun top
    d.pieslice([c - C * 0.34, C * 0.10, c + C * 0.34, C * 0.62], 180, 360,
               fill=(230, 165, 90, 255))
    for x, y in ((-0.16, 0.24), (0.0, 0.19), (0.16, 0.24), (-0.08, 0.30), (0.08, 0.30)):
        d.ellipse([c + C * x - C * 0.016, C * y, c + C * x + C * 0.016, C * (y + 0.035)],
                  fill=(250, 235, 200, 255))
    # lettuce
    for i in range(7):
        circle(d, c - C * 0.30 + i * C * 0.10, C * 0.40, C * 0.05, fill=(120, 195, 90, 255))
    # cheese
    d.polygon([(c - C * 0.30, C * 0.42), (c + C * 0.30, C * 0.42), (c + C * 0.24, C * 0.52),
               (c + C * 0.10, C * 0.44), (c - C * 0.05, C * 0.53), (c - C * 0.20, C * 0.45)],
              fill=(250, 200, 60, 255))
    # patty
    d.rounded_rectangle([c - C * 0.30, C * 0.47, c + C * 0.30, C * 0.58], radius=C * 0.05,
                        fill=(140, 85, 55, 255))
    # tomato
    d.rounded_rectangle([c - C * 0.27, C * 0.57, c + C * 0.27, C * 0.63], radius=C * 0.03,
                        fill=(225, 80, 70, 255))
    # bun bottom
    d.rounded_rectangle([c - C * 0.32, C * 0.62, c + C * 0.32, C * 0.76], radius=C * 0.06,
                        fill=(230, 165, 90, 255))
    sparkle(d, C * 0.82, C * 0.16, C * 0.04)


@art("taco", 48)
def _(im, d, C):
    c = C / 2
    # shell
    d.pieslice([c - C * 0.38, C * 0.22, c + C * 0.38, C * 0.98], 180, 360,
               fill=(245, 195, 95, 255))
    d.pieslice([c - C * 0.31, C * 0.30, c + C * 0.31, C * 0.92], 180, 360,
               fill=(230, 165, 75, 255))
    # fillings peeking over the fold
    rnd = random.Random(12)
    for i in range(9):  # lettuce ruffle
        x = c - C * 0.28 + i * C * 0.07
        circle(d, x, C * 0.56 - C * 0.05 * math.sin(i * 1.1), C * 0.055,
               fill=(120, 195, 90, 255))
    for i in range(5):  # meat
        x = c - C * 0.22 + i * C * 0.11
        circle(d, x, C * 0.60, C * 0.045, fill=(140, 85, 55, 255))
    for x, y in ((-0.18, 0.50), (0.0, 0.47), (0.17, 0.50)):  # tomato dice
        d.rectangle([c + C * x, C * y, c + C * x + C * 0.05, C * (y + 0.05)],
                    fill=(225, 80, 70, 255))
    for x in (-0.10, 0.08):  # cheese shreds
        d.line([(c + C * x, C * 0.47), (c + C * x + C * 0.03, C * 0.56)],
               fill=(250, 220, 90, 255), width=int(S * 0.9))
    sparkle(d, C * 0.14, C * 0.26, C * 0.04)


@art("choc_chip_cookie")
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.42, fill=(200, 140, 75, 255))
    circle(d, c - C * 0.04, c - C * 0.04, C * 0.37, fill=(225, 170, 100, 255))
    for x, y, r in ((-0.16, -0.14, 0.055), (0.14, -0.18, 0.05), (0.20, 0.10, 0.055),
                    (-0.20, 0.14, 0.05), (0.0, 0.02, 0.06), (-0.02, 0.26, 0.045),
                    (0.10, -0.02, 0.035)):
        circle(d, c + C * x, c + C * y, C * r, fill=(90, 55, 35, 255))
    circle(d, c - C * 0.26, c - C * 0.26, C * 0.035, fill=(245, 205, 150, 255))
    sparkle(d, C * 0.82, C * 0.20, C * 0.04)


@art("wrapped_candy")
def _(im, d, C):
    c = C / 2
    # wrapper twists
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.24, c), (c + sx * C * 0.44, c - C * 0.14),
                   (c + sx * C * 0.40, c), (c + sx * C * 0.44, c + C * 0.14)],
                  fill=(240, 120, 150, 255))
    circle(d, c, c, C * 0.26, fill=(250, 160, 185, 255))
    # swirl stripes
    for a in (-60, 0, 60):
        d.arc([c - C * 0.26, c - C * 0.26, c + C * 0.26, c + C * 0.26],
              a + 190, a + 245, fill=(255, 255, 255, 255), width=int(C * 0.045))
    circle(d, c - C * 0.09, c - C * 0.09, C * 0.045, fill=(255, 220, 230, 255))
    sparkle(d, C * 0.80, C * 0.24, C * 0.045)
    sparkle(d, C * 0.18, C * 0.76, C * 0.035)


@art("lollipop_swirl")
def _(im, d, C):
    c = C / 2
    cy = C * 0.38
    d.rectangle([c - C * 0.022, cy, c + C * 0.022, C * 0.94], fill=(245, 240, 235, 255))
    circle(d, c, cy, C * 0.30, fill=(240, 90, 120, 255))
    # swirl: shrinking arcs
    for i, r in enumerate((0.26, 0.19, 0.12, 0.06)):
        d.arc([c - C * r, cy - C * r, c + C * r, cy + C * r],
              i * 70, i * 70 + 260, fill=(255, 250, 245, 255), width=int(C * 0.045))
    circle(d, c, cy, C * 0.025, fill=(255, 250, 245, 255))
    sparkle(d, c + C * 0.24, cy - C * 0.28, C * 0.05)
    d.polygon(star_pts(C * 0.16, C * 0.72, C * 0.04, C * 0.016, 4), fill=(250, 205, 80, 255))


@art("cherry_pair")
def _(im, d, C):
    c = C / 2
    # stems meeting at top
    d.line([(c - C * 0.16, C * 0.62), (c, C * 0.14)], fill=(90, 140, 60, 255),
           width=int(C * 0.028))
    d.line([(c + C * 0.20, C * 0.56), (c, C * 0.14)], fill=(90, 140, 60, 255),
           width=int(C * 0.028))
    d.polygon(petal_pts(c + C * 0.02, C * 0.14, -35, 0, C * 0.20, C * 0.06),
              fill=(95, 175, 90, 255))
    for dx, dy, r in ((-0.16, 0.72, 0.185), (0.20, 0.66, 0.165)):
        circle(d, c + C * dx, C * dy, C * r, fill=(200, 35, 55, 255))
        circle(d, c + C * dx, C * dy, C * r * 0.82, fill=(230, 60, 80, 255))
        circle(d, c + C * dx - C * r * 0.35, C * dy - C * r * 0.35, C * r * 0.25,
               fill=(250, 140, 150, 255))
    sparkle(d, C * 0.80, C * 0.30, C * 0.04)


@art("pineapple", 48)
def _(im, d, C):
    c = C / 2
    # crown
    for a, ln in ((-90, 0.24), (-60, 0.20), (-120, 0.20), (-35, 0.16), (-145, 0.16)):
        d.polygon(petal_pts(c, C * 0.30, a, 0, C * ln, C * 0.045),
                  fill=(80, 160, 80, 255))
    # body
    d.ellipse([c - C * 0.27, C * 0.28, c + C * 0.27, C * 0.94], fill=(245, 185, 60, 255))
    # crosshatch
    for i in range(-3, 4):
        d.line([(c + i * C * 0.11 - C * 0.20, C * 0.32), (c + i * C * 0.11 + C * 0.14, C * 0.92)],
               fill=(215, 150, 40, 255), width=S // 2)
        d.line([(c + i * C * 0.11 + C * 0.20, C * 0.32), (c + i * C * 0.11 - C * 0.14, C * 0.92)],
               fill=(215, 150, 40, 255), width=S // 2)
    # face
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.10, C * 0.54, C * 0.030)
    smile(d, c, C * 0.60, C * 0.05, C * 0.04)
    blush2(d, c, C * 0.17, C * 0.63, C * 0.028)
    sparkle(d, C * 0.82, C * 0.24, C * 0.04)

# ================================================================ nature

@art("rose_bloom", 48)
def _(im, d, C):
    c = C / 2
    # leaves
    for a in (150, 30):
        d.polygon(petal_pts(c, C * 0.72, a, C * 0.05, C * 0.34, C * 0.075),
                  fill=(70, 150, 80, 255))
    d.line([(c, C * 0.70), (c, C * 0.96)], fill=(60, 130, 65, 255), width=int(C * 0.035))
    # outer petals
    ring_petals(d, c, C * 0.44, 8, C * 0.12, C * 0.36, C * 0.10, (200, 45, 80, 255))
    ring_petals(d, c, C * 0.44, 8, C * 0.10, C * 0.28, C * 0.08, (230, 75, 110, 255), rot=22.5)
    # inner spiral bud
    circle(d, c, C * 0.44, C * 0.15, fill=(245, 110, 140, 255))
    d.arc([c - C * 0.15, C * 0.29, c + C * 0.15, C * 0.59], -60, 180,
          fill=(200, 45, 80, 255), width=int(C * 0.028))
    d.arc([c - C * 0.085, C * 0.36, c + C * 0.085, C * 0.53], 90, 330,
          fill=(200, 45, 80, 255), width=int(C * 0.024))
    circle(d, c + C * 0.02, C * 0.435, C * 0.030, fill=(250, 160, 185, 255))
    sparkle(d, C * 0.82, C * 0.20, C * 0.04)


@art("tulip_single")
def _(im, d, C):
    c = C / 2
    d.line([(c, C * 0.50), (c, C * 0.94)], fill=(60, 130, 65, 255), width=int(C * 0.032))
    for a in (155, 25):
        d.polygon(petal_pts(c, C * 0.80, a, C * 0.02, C * 0.30, C * 0.06),
                  fill=(80, 160, 80, 255))
    # cup: rounded base + three pointed tips
    d.pieslice([c - C * 0.24, C * 0.22, c + C * 0.24, C * 0.62], 0, 180,
               fill=(230, 70, 100, 255))
    d.polygon([(c - C * 0.24, C * 0.42), (c - C * 0.24, C * 0.30), (c - C * 0.12, C * 0.14),
               (c - C * 0.005, C * 0.34), (c, C * 0.12), (c + C * 0.055, C * 0.34),
               (c + C * 0.12, C * 0.14), (c + C * 0.24, C * 0.30), (c + C * 0.24, C * 0.42)],
              fill=(230, 70, 100, 255))
    # lighter middle petal
    d.polygon([(c - C * 0.055, C * 0.34), (c, C * 0.135), (c + C * 0.055, C * 0.34),
               (c + C * 0.075, C * 0.55), (c - C * 0.075, C * 0.55)],
              fill=(250, 120, 145, 255))
    circle(d, c - C * 0.14, C * 0.30, C * 0.04, fill=(250, 140, 160, 255))
    sparkle(d, C * 0.80, C * 0.18, C * 0.04)


@art("daisy")
def _(im, d, C):
    c = C / 2
    ring_petals(d, c, c, 12, C * 0.10, C * 0.46, C * 0.075, (240, 240, 248, 255))
    ring_petals(d, c, c, 12, C * 0.10, C * 0.38, C * 0.055, (255, 255, 255, 255), rot=15)
    circle(d, c, c, C * 0.15, fill=(215, 160, 40, 255))
    circle(d, c, c, C * 0.115, fill=(250, 200, 70, 255))
    circle(d, c - C * 0.04, c - C * 0.04, C * 0.035, fill=(255, 230, 140, 255))
    sparkle(d, C * 0.82, C * 0.20, C * 0.04)


@art("sunflower_face", 48)
def _(im, d, C):
    c = C / 2
    ring_petals(d, c, c, 14, C * 0.16, C * 0.48, C * 0.06, (235, 160, 40, 255))
    ring_petals(d, c, c, 14, C * 0.16, C * 0.42, C * 0.05, (250, 200, 60, 255),
                rot=180 / 14)
    circle(d, c, c, C * 0.21, fill=(120, 80, 45, 255))
    circle(d, c, c, C * 0.17, fill=(150, 100, 55, 255))
    ring_dots(d, c, c, 8, C * 0.115, C * 0.020, (100, 65, 40, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.07, c - C * 0.03, C * 0.026)
    smile(d, c, c + C * 0.02, C * 0.045, C * 0.04, col=(80, 50, 30, 255), lw=int(C * 0.018))
    blush2(d, c, C * 0.12, c + C * 0.03, C * 0.024)


@art("toadstool")
def _(im, d, C):
    c = C / 2
    # stem
    d.rounded_rectangle([c - C * 0.10, C * 0.46, c + C * 0.10, C * 0.88], radius=C * 0.06,
                        fill=(245, 235, 220, 255))
    d.ellipse([c - C * 0.14, C * 0.82, c + C * 0.14, C * 0.92], fill=(230, 215, 195, 255))
    # cap
    d.pieslice([c - C * 0.40, C * 0.08, c + C * 0.40, C * 0.72], 180, 360,
               fill=(215, 55, 65, 255))
    d.ellipse([c - C * 0.40, C * 0.36, c + C * 0.40, C * 0.44], fill=(190, 40, 50, 255))
    for x, y, r in ((-0.22, 0.24, 0.055), (0.05, 0.15, 0.06), (0.26, 0.28, 0.045),
                    (-0.05, 0.32, 0.035)):
        circle(d, c + C * x, C * y, C * r, fill=(250, 240, 230, 255))
    # grass
    for gx in (0.18, 0.30, 0.72, 0.84):
        d.polygon(petal_pts(C * gx, C * 0.92, -90 + (10 if gx > 0.5 else -10), 0,
                            C * 0.10, C * 0.022), fill=(90, 165, 80, 255))
    sparkle(d, C * 0.82, C * 0.14, C * 0.04)


@art("lucky_clover")
def _(im, d, C):
    c = C / 2
    d.line([(c, c), (c + C * 0.10, C * 0.92)], fill=(60, 130, 65, 255), width=int(C * 0.03))
    for i in range(4):
        a = i * 90 - 45
        ar = math.radians(a)
        hx, hy = c + C * 0.20 * math.cos(ar), c * 0.92 + C * 0.20 * math.sin(ar)
        d.polygon(heart_pts(hx, hy + C * 0.05, C * 0.15, n=48), fill=(85, 170, 90, 255))
    for i in range(4):
        a = i * 90 - 45
        ar = math.radians(a)
        hx, hy = c + C * 0.145 * math.cos(ar), c * 0.92 + C * 0.145 * math.sin(ar)
        circle(d, hx, hy, C * 0.035, fill=(140, 210, 120, 255))
    sparkle(d, C * 0.80, C * 0.20, C * 0.045)
    sparkle(d, C * 0.18, C * 0.74, C * 0.035)


@art("maple_leaf")
def _(im, d, C):
    c = C / 2
    d.line([(c, c), (c - C * 0.06, C * 0.94)], fill=(140, 80, 40, 255), width=int(C * 0.028))
    # five lobes
    for a, ln, w in ((-90, 0.42, 0.085), (-40, 0.36, 0.075), (-140, 0.36, 0.075),
                     (5, 0.28, 0.065), (-185, 0.28, 0.065)):
        d.polygon(petal_pts(c, c * 1.04, a, 0, C * ln, C * w), fill=(230, 110, 45, 255))
    circle(d, c, c * 0.98, C * 0.17, fill=(230, 110, 45, 255))
    for a, ln in ((-90, 0.38), (-40, 0.32), (-140, 0.32)):
        ar = math.radians(a)
        d.line([(c, c * 1.04), (c + C * ln * 0.85 * math.cos(ar),
                c * 1.04 + C * ln * 0.85 * math.sin(ar))],
               fill=(190, 80, 30, 255), width=S // 2)
    circle(d, c - C * 0.12, c * 0.78, C * 0.04, fill=(250, 160, 90, 255))
    sparkle(d, C * 0.80, C * 0.76, C * 0.035)


@art("palm_island", 48)
def _(im, d, C):
    c = C / 2
    d.ellipse([C * 0.10, C * 0.66, C * 0.90, C * 0.92], fill=(90, 170, 210, 255))
    d.ellipse([C * 0.18, C * 0.62, C * 0.82, C * 0.84], fill=(245, 220, 165, 255))
    # trunk
    d.arc([c - C * 0.30, C * 0.16, c + C * 0.16, C * 0.72], -20, 95,
          fill=(160, 110, 65, 255), width=int(C * 0.045))
    # fronds
    for a in (-160, -120, -80, -40, -5):
        d.polygon(petal_pts(c + C * 0.14, C * 0.20, a, 0, C * 0.26, C * 0.05),
                  fill=(70, 155, 80, 255))
    # coconuts
    circle(d, c + C * 0.08, C * 0.24, C * 0.035, fill=(130, 85, 50, 255))
    circle(d, c + C * 0.17, C * 0.27, C * 0.035, fill=(130, 85, 50, 255))
    # sun + foam arcs
    circle(d, C * 0.82, C * 0.14, C * 0.075, fill=(255, 210, 90, 255))
    d.arc([C * 0.30, C * 0.80, C * 0.46, C * 0.86], 180, 360,
          fill=(255, 255, 255, 255), width=S // 2)
    d.arc([C * 0.54, C * 0.84, C * 0.68, C * 0.90], 180, 360,
          fill=(255, 255, 255, 255), width=S // 2)


@art("mountain_lake", 64)
def _(im, d, C):
    # sky bands
    d.rectangle([0, 0, C, C * 0.55], fill=(250, 205, 150, 255))
    d.rectangle([0, 0, C, C * 0.38], fill=(245, 170, 130, 255))
    d.rectangle([0, 0, C, C * 0.22], fill=(225, 130, 130, 255))
    circle(d, C * 0.68, C * 0.30, C * 0.09, fill=(255, 240, 200, 255))
    # mountains
    d.polygon([(0, C * 0.55), (C * 0.30, C * 0.20), (C * 0.58, C * 0.55)],
              fill=(110, 90, 130, 255))
    d.polygon([(C * 0.38, C * 0.55), (C * 0.72, C * 0.28), (C, C * 0.55)],
              fill=(140, 110, 150, 255))
    d.polygon([(C * 0.30, C * 0.20), (C * 0.385, C * 0.30), (C * 0.30, C * 0.33),
               (C * 0.24, C * 0.28), (C * 0.215, C * 0.30)], fill=(250, 245, 245, 255))
    d.polygon([(C * 0.72, C * 0.28), (C * 0.79, C * 0.36), (C * 0.72, C * 0.385),
               (C * 0.66, C * 0.35)], fill=(250, 245, 245, 255))
    # lake with reflections
    d.rectangle([0, C * 0.55, C, C], fill=(80, 130, 180, 255))
    d.polygon([(C * 0.14, C * 0.55), (C * 0.30, C * 0.72), (C * 0.46, C * 0.55)],
              fill=(110, 90, 130, 255))
    d.polygon([(C * 0.52, C * 0.55), (C * 0.72, C * 0.70), (C * 0.92, C * 0.55)],
              fill=(120, 100, 140, 255))
    for y, x0, x1 in ((0.78, 0.10, 0.34), (0.85, 0.50, 0.78), (0.92, 0.22, 0.48),
                      (0.66, 0.60, 0.80)):
        d.line([(C * x0, C * y), (C * x1, C * y)], fill=(160, 200, 230, 255),
               width=int(C * 0.014))
    # pines on shore
    for px, s in ((0.08, 1.0), (0.16, 0.8), (0.90, 0.9)):
        for k in range(3):
            w = C * 0.055 * s * (1 - k * 0.22)
            y0 = C * (0.46 - k * 0.045 * s)
            d.polygon([(C * px - w, y0), (C * px + w, y0), (C * px, y0 - C * 0.055 * s)],
                      fill=(40, 90, 70, 255))


@art("snowman", 48)
def _(im, d, C):
    c = C / 2
    d.ellipse([C * 0.08, C * 0.82, C * 0.92, C * 0.96], fill=(230, 240, 250, 255))
    circle(d, c, C * 0.68, C * 0.235, fill=(250, 250, 253, 255))
    circle(d, c, C * 0.38, C * 0.175, fill=(250, 250, 253, 255))
    # hat
    d.rectangle([c - C * 0.155, C * 0.185, c + C * 0.155, C * 0.225], fill=(45, 45, 60, 255))
    d.rounded_rectangle([c - C * 0.105, C * 0.06, c + C * 0.105, C * 0.21],
                        radius=C * 0.02, fill=(45, 45, 60, 255))
    d.rectangle([c - C * 0.105, C * 0.155, c + C * 0.105, C * 0.195],
                fill=(220, 60, 60, 255))
    # face
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.065, C * 0.34, C * 0.026)
    d.polygon([(c, C * 0.385), (c + C * 0.13, C * 0.415), (c, C * 0.44)],
              fill=(245, 140, 50, 255))
    blush2(d, c, C * 0.12, C * 0.42, C * 0.026)
    # scarf
    d.rounded_rectangle([c - C * 0.14, C * 0.50, c + C * 0.14, C * 0.56],
                        radius=C * 0.025, fill=(220, 60, 60, 255))
    d.rectangle([c + C * 0.03, C * 0.55, c + C * 0.10, C * 0.68], fill=(220, 60, 60, 255))
    for y in (0.62, 0.70):
        circle(d, c, C * y, C * 0.020, fill=(45, 45, 60, 255))
    for sx in (-1, 1):
        d.line([(c + sx * C * 0.20, C * 0.62), (c + sx * C * 0.38, C * 0.52)],
               fill=(140, 95, 55, 255), width=int(C * 0.02))
    for x, y in ((0.14, 0.16), (0.82, 0.10), (0.88, 0.40), (0.10, 0.50), (0.76, 0.66)):
        circle(d, C * x, C * y, C * 0.016, fill=(220, 235, 250, 255))


@art("blossom_wreath", 48)
def _(im, d, C):
    c = C / 2
    # leafy ring
    for i in range(12):
        a = i * 30
        ar = math.radians(a)
        x, y = c + C * 0.34 * math.cos(ar), c + C * 0.34 * math.sin(ar)
        d.polygon(petal_pts(x, y, a + 65, 0, C * 0.13, C * 0.035), fill=(85, 165, 90, 255))
        d.polygon(petal_pts(x, y, a + 115, 0, C * 0.13, C * 0.035), fill=(60, 135, 70, 255))
    # blossoms alternate pink / gold
    for i in range(6):
        a = math.radians(i * 60 - 90)
        x, y = c + C * 0.34 * math.cos(a), c + C * 0.34 * math.sin(a)
        for k in range(5):
            d.polygon(petal_pts(x, y, k * 72 - 90, 0, C * 0.085, C * 0.038),
                      fill=(250, 165, 190, 255) if i % 2 == 0 else (245, 205, 90, 255))
        circle(d, x, y, C * 0.028, fill=(200, 90, 120, 255) if i % 2 == 0
               else (215, 150, 40, 255))
    sparkle(d, c, c, C * 0.05)
    sparkle(d, c - C * 0.10, c + C * 0.08, C * 0.03)


@art("acorn_autumn")
def _(im, d, C):
    c = C / 2
    # cap
    d.pieslice([c - C * 0.26, C * 0.14, c + C * 0.26, C * 0.58], 180, 360,
               fill=(150, 100, 60, 255))
    for i in range(3):
        d.arc([c - C * 0.26, C * 0.18 + i * C * 0.055, c + C * 0.26, C * 0.44 + i * C * 0.055],
              200, 340, fill=(120, 80, 45, 255), width=S // 2)
    d.line([(c, C * 0.14), (c + C * 0.04, C * 0.045)], fill=(120, 80, 45, 255),
           width=int(C * 0.03))
    # nut
    d.ellipse([c - C * 0.22, C * 0.34, c + C * 0.22, C * 0.88], fill=(215, 155, 90, 255))
    d.ellipse([c - C * 0.13, C * 0.40, c - C * 0.005, C * 0.72], fill=(235, 185, 120, 255))
    # tiny leaves
    d.polygon(petal_pts(C * 0.20, C * 0.70, 150, 0, C * 0.16, C * 0.05),
              fill=(230, 110, 45, 255))
    d.polygon(petal_pts(C * 0.82, C * 0.62, 20, 0, C * 0.14, C * 0.045),
              fill=(245, 170, 60, 255))
    sparkle(d, C * 0.80, C * 0.22, C * 0.04)


@art("potted_monstera", 48)
def _(im, d, C):
    c = C / 2
    # pot
    d.polygon([(c - C * 0.19, C * 0.68), (c + C * 0.19, C * 0.68),
               (c + C * 0.14, C * 0.92), (c - C * 0.14, C * 0.92)],
              fill=(225, 135, 85, 255))
    d.rectangle([c - C * 0.22, C * 0.64, c + C * 0.22, C * 0.71], fill=(200, 110, 70, 255))
    # three big split leaves
    for a, ln in ((-125, 0.42), (-90, 0.48), (-50, 0.40)):
        d.polygon(petal_pts(c, C * 0.66, a, C * 0.06, C * ln, C * 0.10),
                  fill=(60, 140, 75, 255))
        ar = math.radians(a)
        tipx = c + C * ln * 0.75 * math.cos(ar)
        tipy = C * 0.66 + C * ln * 0.75 * math.sin(ar)
        for t in (0.35, 0.6):  # leaf splits punched transparent
            nx = c + C * ln * t * math.cos(ar)
            ny = C * 0.66 + C * ln * t * math.sin(ar)
            d.polygon(petal_pts(nx, ny, a + 90, 0, C * 0.09, C * 0.018),
                      fill=(0, 0, 0, 0))
            d.polygon(petal_pts(nx, ny, a - 90, 0, C * 0.09, C * 0.018),
                      fill=(0, 0, 0, 0))
        d.line([(c, C * 0.66), (tipx, tipy)], fill=(40, 110, 60, 255), width=S // 2)
    sparkle(d, C * 0.82, C * 0.20, C * 0.04)


@art("rainbow_butterfly", 48)
def _(im, d, C):
    c = C / 2
    wing_cols = [(220, 60, 60, 255), (245, 140, 50, 255), (250, 205, 70, 255),
                 (95, 175, 90, 255), (60, 140, 220, 255), (150, 90, 220, 255)]
    for sx in (-1, 1):
        up, lo = 90 - sx * 128, 90 - sx * 38
        for i, f in enumerate((0.47, 0.40, 0.33, 0.26, 0.19, 0.12)):
            d.polygon(petal_pts(c, c * 0.94, up, C * 0.01, C * f, C * f * 0.34),
                      fill=wing_cols[i])
        d.polygon(petal_pts(c, c * 1.06, lo, 0, C * 0.34, C * 0.12),
                  fill=(150, 90, 220, 255))
        d.polygon(petal_pts(c, c * 1.06, lo, C * 0.02, C * 0.27, C * 0.085),
                  fill=(200, 150, 245, 255))
        a = math.radians(up)
        circle(d, c + C * 0.36 * math.cos(a), c * 0.94 + C * 0.36 * math.sin(a),
               C * 0.022, fill=(255, 255, 255, 255))
    d.ellipse([c - C * 0.032, c * 0.60, c + C * 0.032, c * 1.38], fill=INK)
    circle(d, c, c * 0.56, C * 0.045, fill=INK)
    for sx in (-1, 1):
        d.line([(c, c * 0.54), (c + sx * C * 0.08, c * 0.36)], fill=INK, width=S // 2)
        circle(d, c + sx * C * 0.08, c * 0.36, C * 0.013, fill=(250, 205, 70, 255))
    sparkle(d, C * 0.85, C * 0.75, C * 0.035)


# ================================================================ ocean

@art("happy_whale", 48)
def _(im, d, C):
    c = C / 2
    # spout
    for a in (-115, -90, -65):
        d.polygon(petal_pts(c - C * 0.10, C * 0.26, a, C * 0.02, C * 0.17, C * 0.028),
                  fill=(150, 210, 240, 255))
    # body
    d.ellipse([C * 0.10, C * 0.30, C * 0.78, C * 0.78], fill=(80, 140, 200, 255))
    # tail
    d.polygon(petal_pts(C * 0.78, C * 0.48, -35, 0, C * 0.20, C * 0.055),
              fill=(80, 140, 200, 255))
    d.polygon(petal_pts(C * 0.78, C * 0.52, 35, 0, C * 0.18, C * 0.05),
              fill=(80, 140, 200, 255))
    # belly
    d.pieslice([C * 0.10, C * 0.44, C * 0.78, C * 0.82], 20, 160,
               fill=(200, 230, 245, 255))
    for i in range(4):
        d.line([(C * (0.20 + i * 0.04), C * 0.62), (C * (0.20 + i * 0.04), C * 0.74)],
               fill=(160, 205, 235, 255), width=S // 2)
    eye(d, C * 0.26, C * 0.48, C * 0.036)
    circle(d, C * 0.33, C * 0.58, C * 0.032, fill=BLUSH)
    smile(d, C * 0.26, C * 0.55, C * 0.04, C * 0.03)
    # fin
    d.polygon(petal_pts(C * 0.48, C * 0.62, 40, 0, C * 0.14, C * 0.05),
              fill=(60, 115, 175, 255))
    # waves
    for wx in (0.14, 0.46, 0.78):
        d.arc([C * wx - C * 0.10, C * 0.84, C * wx + C * 0.10, C * 0.94], 180, 360,
              fill=(110, 180, 225, 255), width=int(C * 0.02))


@art("octopus", 48)
def _(im, d, C):
    c = C / 2
    body = (230, 110, 160, 255)
    # tentacles: curled arcs along the bottom
    for x, flip in ((0.16, 1), (0.32, -1), (0.5, 1), (0.68, -1), (0.84, 1)):
        y0 = C * 0.66
        d.line([(C * x, C * 0.56), (C * x, y0)], fill=body, width=int(C * 0.055))
        d.arc([C * x - C * 0.055, y0 - C * 0.02, C * x + C * 0.055, y0 + C * 0.09],
              0 if flip > 0 else 180, 180 if flip > 0 else 360, fill=body,
              width=int(C * 0.05))
    # head
    d.ellipse([c - C * 0.28, C * 0.10, c + C * 0.28, C * 0.62], fill=body)
    circle(d, c - C * 0.10, C * 0.22, C * 0.06, fill=(245, 160, 195, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.11, C * 0.38, C * 0.038)
    smile(d, c, C * 0.44, C * 0.05, C * 0.04)
    blush2(d, c, C * 0.20, C * 0.46, C * 0.032)
    for x, y, r in ((0.12, 0.20, 0.028), (0.86, 0.14, 0.022), (0.90, 0.34, 0.018)):
        circle(d, C * x, C * y, C * r, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("jellyfish", 48)
def _(im, d, C):
    c = C / 2
    bell = (185, 140, 235, 255)
    d.pieslice([c - C * 0.28, C * 0.10, c + C * 0.28, C * 0.62], 180, 360, fill=bell)
    d.rectangle([c - C * 0.28, C * 0.355, c + C * 0.28, C * 0.42], fill=bell)
    # scalloped bell rim
    for i in range(5):
        x = c - C * 0.224 + i * C * 0.112
        d.arc([x - C * 0.056, C * 0.38, x + C * 0.056, C * 0.46], 180, 360,
              fill=(150, 105, 210, 255), width=int(C * 0.02))
    circle(d, c - C * 0.11, C * 0.24, C * 0.055, fill=(215, 185, 250, 255))
    # tentacles: wavy lines
    for i, x in enumerate((-0.18, -0.06, 0.06, 0.18)):
        pts = []
        for k in range(9):
            t = k / 8
            pts.append((c + C * x + C * 0.035 * math.sin(t * 6 + i * 1.8),
                        C * (0.44 + 0.46 * t)))
        d.line(pts, fill=(210, 160, 245, 255), width=int(C * 0.022), joint="curve")
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.10, C * 0.30, C * 0.032)
    smile(d, c, C * 0.34, C * 0.04, C * 0.035)
    blush2(d, c, C * 0.18, C * 0.35, C * 0.028)
    circle(d, C * 0.14, C * 0.60, C * 0.024, outline=(150, 210, 240, 255), width=int(S * 0.75))
    circle(d, C * 0.86, C * 0.70, C * 0.020, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("seahorse", 48)
def _(im, d, C):
    c = C / 2
    body = (245, 170, 70, 255)
    # tail curl
    d.arc([c - C * 0.16, C * 0.62, c + C * 0.16, C * 0.94], -30, 220,
          fill=body, width=int(C * 0.075))
    # body S-curve
    d.arc([c - C * 0.22, C * 0.26, c + C * 0.22, C * 0.74], 250, 435,
          fill=body, width=int(C * 0.105))
    # head + snout
    circle(d, c - C * 0.045, C * 0.245, C * 0.115, fill=body)
    d.polygon([(c - C * 0.15, C * 0.20), (c - C * 0.34, C * 0.245), (c - C * 0.15, C * 0.30)],
              fill=body)
    # crest fins
    for a in (-60, -25, 10):
        d.polygon(petal_pts(c + C * 0.065, C * 0.22, a, 0, C * 0.13, C * 0.032),
                  fill=(230, 130, 45, 255))
    d.polygon(petal_pts(c + C * 0.16, C * 0.48, 20, 0, C * 0.14, C * 0.045),
              fill=(230, 130, 45, 255))
    # belly ridges
    for i in range(4):
        y = C * (0.38 + i * 0.09)
        d.line([(c - C * 0.115, y), (c - C * 0.02, y + C * 0.02)],
               fill=(230, 130, 45, 255), width=S // 2)
    eye(d, c - C * 0.075, C * 0.235, C * 0.030)
    circle(d, c - C * 0.01, C * 0.30, C * 0.026, fill=BLUSH)
    for x, y, r in ((0.14, 0.14, 0.024), (0.82, 0.18, 0.02)):
        circle(d, C * x, C * y, C * r, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("beach_crab")
def _(im, d, C):
    c = C / 2
    body = (235, 90, 70, 255)
    # legs
    for sx in (-1, 1):
        for a in (25, 45, 65):
            d.line([(c + sx * C * 0.24, C * 0.58),
                    (c + sx * C * 0.42 * abs(math.cos(math.radians(a))),
                     C * 0.58 + C * 0.26 * math.sin(math.radians(a)))],
                   fill=body, width=int(C * 0.028))
    # claws
    for sx in (-1, 1):
        d.line([(c + sx * C * 0.22, C * 0.46), (c + sx * C * 0.38, C * 0.28)],
               fill=body, width=int(C * 0.032))
        circle(d, c + sx * C * 0.40, C * 0.24, C * 0.075, fill=body)
    # shell
    d.ellipse([c - C * 0.26, C * 0.38, c + C * 0.26, C * 0.74], fill=body)
    d.ellipse([c - C * 0.19, C * 0.43, c - C * 0.02, C * 0.55], fill=(250, 140, 115, 255))
    for sx in (-1, 1):
        d.line([(c + sx * C * 0.09, C * 0.38), (c + sx * C * 0.12, C * 0.28)],
               fill=body, width=S // 2)
        circle(d, c + sx * C * 0.13, C * 0.26, C * 0.045, fill=(255, 255, 255, 255))
        circle(d, c + sx * C * 0.125, C * 0.265, C * 0.022, fill=INK)
    smile(d, c, C * 0.56, C * 0.05, C * 0.04)
    blush2(d, c, C * 0.17, C * 0.58, C * 0.028)


@art("seashell")
def _(im, d, C):
    c = C / 2
    shell = (245, 180, 160, 255)
    d.pieslice([c - C * 0.40, C * 0.10, c + C * 0.40, C * 0.90], 200, 340, fill=shell)
    d.polygon([(c - C * 0.375, C * 0.365), (c + C * 0.375, C * 0.365), (c, C * 0.78)],
              fill=shell)
    # ribs
    for a in (210, 235, 270, 305, 330):
        ar = math.radians(a)
        d.line([(c, C * 0.76), (c + C * 0.37 * math.cos(ar), C * 0.50 + C * 0.37 * math.sin(ar))],
               fill=(220, 140, 120, 255), width=int(C * 0.022))
    d.arc([c - C * 0.40, C * 0.10, c + C * 0.40, C * 0.90], 200, 340,
          fill=(220, 140, 120, 255), width=int(C * 0.025))
    # hinge
    d.rounded_rectangle([c - C * 0.10, C * 0.74, c + C * 0.10, C * 0.86], radius=C * 0.03,
                        fill=(220, 140, 120, 255))
    circle(d, c - C * 0.14, C * 0.36, C * 0.04, fill=(255, 220, 205, 255))
    sparkle(d, C * 0.80, C * 0.24, C * 0.045)
    circle(d, C * 0.16, C * 0.20, C * 0.022, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("starfish")
def _(im, d, C):
    c = C / 2
    d.polygon(star_pts(c, c, C * 0.46, C * 0.20, 5), fill=(230, 130, 60, 255))
    d.polygon(star_pts(c, c, C * 0.38, C * 0.165, 5), fill=(245, 160, 80, 255))
    for i in range(5):
        a = math.radians(-90 + i * 72)
        for f in (0.22, 0.30):
            circle(d, c + C * f * math.cos(a), c + C * f * math.sin(a), C * 0.022,
                   fill=(200, 100, 45, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.07, c - C * 0.03, C * 0.028)
    smile(d, c, c + C * 0.02, C * 0.04, C * 0.035)
    blush2(d, c, C * 0.13, c + C * 0.01, C * 0.026)
    circle(d, C * 0.82, C * 0.18, C * 0.022, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("dolphin", 48)
def _(im, d, C):
    body = (110, 165, 215, 255)
    # solid diagonal body (rotated ellipse), nose lower-left → tail upper-right
    cx, cy, ang = C * 0.48, C * 0.50, -28
    pts = [(C * 0.30 * math.cos(2 * math.pi * i / 40), C * 0.145 * math.sin(2 * math.pi * i / 40))
           for i in range(40)]
    d.polygon([(cx + x, cy + y) for x, y in rot0(pts, ang)], fill=body)
    # belly
    bpts = [(C * 0.26 * math.cos(math.pi * i / 20), C * 0.115 * math.sin(math.pi * i / 20))
            for i in range(21)]
    d.polygon([(cx + x, cy + y + C * 0.02) for x, y in rot0(bpts, ang)],
              fill=(200, 230, 245, 255))
    # snout
    d.polygon([(C * 0.225, C * 0.585), (C * 0.10, C * 0.70), (C * 0.26, C * 0.665)],
              fill=body)
    # dorsal fin
    d.polygon([(C * 0.42, C * 0.36), (C * 0.50, C * 0.14), (C * 0.58, C * 0.34)],
              fill=(80, 130, 185, 255))
    # tail flukes
    d.polygon(petal_pts(C * 0.76, C * 0.345, -70, 0, C * 0.17, C * 0.05), fill=body)
    d.polygon(petal_pts(C * 0.78, C * 0.36, 5, 0, C * 0.15, C * 0.045), fill=body)
    eye(d, C * 0.29, C * 0.55, C * 0.028)
    circle(d, C * 0.345, C * 0.625, C * 0.026, fill=BLUSH)
    # splash
    for wx in (0.22, 0.50, 0.78):
        d.arc([C * wx - C * 0.09, C * 0.86, C * wx + C * 0.09, C * 0.95], 180, 360,
              fill=(110, 180, 225, 255), width=int(C * 0.018))
    circle(d, C * 0.80, C * 0.14, C * 0.022, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("axolotl", 48)
def _(im, d, C):
    c = C / 2
    pink = (250, 185, 200, 255)
    # gills: three feathery stalks fanning out from each side of the head
    for sx in (-1, 1):
        base_x = c + sx * C * 0.22
        for da in (-38, 0, 38):
            aa = (0 if sx > 0 else 180) + sx * da
            d.polygon(petal_pts(base_x, C * 0.33, aa, 0, C * 0.20, C * 0.038),
                      fill=(240, 110, 140, 255))
            ar = math.radians(aa)
            circle(d, base_x + C * 0.18 * math.cos(ar), C * 0.33 + C * 0.18 * math.sin(ar),
                   C * 0.028, fill=(250, 150, 175, 255))
    # head + body
    d.ellipse([c - C * 0.26, C * 0.16, c + C * 0.26, C * 0.58], fill=pink)
    d.ellipse([c - C * 0.16, C * 0.48, c + C * 0.16, C * 0.86], fill=pink)
    # tail curl
    d.polygon(petal_pts(c + C * 0.06, C * 0.80, 30, 0, C * 0.24, C * 0.06),
              fill=(245, 150, 175, 255))
    # face
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.115, C * 0.36, C * 0.034)
    smile(d, c, C * 0.42, C * 0.05, C * 0.04)
    blush2(d, c, C * 0.20, C * 0.43, C * 0.030)
    # feet
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.16 - C * 0.045, C * 0.60, c + sx * C * 0.16 + C * 0.045,
                   C * 0.68], fill=pink)
    circle(d, C * 0.16, C * 0.14, C * 0.024, outline=(150, 210, 240, 255), width=int(S * 0.75))
    circle(d, C * 0.86, C * 0.20, C * 0.020, outline=(150, 210, 240, 255), width=int(S * 0.75))


@art("coral_reef", 64)
def _(im, d, C):
    # water backdrop
    d.rectangle([0, 0, C, C], fill=(35, 110, 160, 255))
    d.rectangle([0, 0, C, C * 0.30], fill=(55, 140, 190, 255))
    # light rays
    for x in (0.22, 0.5, 0.78):
        d.polygon([(C * (x - 0.03), 0), (C * (x + 0.03), 0), (C * (x + 0.10), C * 0.42),
                   (C * (x - 0.10), C * 0.42)], fill=(75, 160, 205, 255))
    # sea floor
    d.ellipse([-C * 0.10, C * 0.80, C * 1.10, C * 1.10], fill=(230, 205, 155, 255))
    # branching coral (left, pink)
    bx = C * 0.18
    for a, ln in ((-90, 0.28), (-130, 0.20), (-55, 0.22), (-105, 0.14)):
        ar = math.radians(a)
        d.line([(bx, C * 0.86), (bx + C * ln * math.cos(ar), C * 0.86 + C * ln * math.sin(ar))],
               fill=(240, 110, 140, 255), width=int(C * 0.035))
        circle(d, bx + C * ln * math.cos(ar), C * 0.86 + C * ln * math.sin(ar),
               C * 0.024, fill=(250, 150, 175, 255))
    # brain coral (center, orange dome)
    d.pieslice([C * 0.36, C * 0.68, C * 0.64, C * 0.96], 180, 360, fill=(245, 160, 80, 255))
    for i in range(3):
        d.arc([C * 0.39 + i * C * 0.02, C * 0.72 + i * C * 0.045, C * 0.61 - i * C * 0.02,
               C * 0.96], 180, 360, fill=(220, 120, 55, 255), width=S // 2)
    # anemone (right, purple)
    ax = C * 0.82
    for a in range(-160, 1, 20):
        d.polygon(petal_pts(ax, C * 0.88, a, 0, C * 0.16, C * 0.020),
                  fill=(185, 140, 235, 255))
    # seaweed
    for wx, ph in ((0.30, 0), (0.70, 2)):
        pts = [(C * wx + C * 0.03 * math.sin(k / 8 * 5 + ph), C * (0.88 - 0.30 * k / 8))
               for k in range(9)]
        d.line(pts, fill=(60, 160, 110, 255), width=int(C * 0.022), joint="curve")
    # small fish trio
    for fx, fy, col in ((0.34, 0.34, (250, 205, 70, 255)), (0.52, 0.24, (240, 110, 90, 255)),
                        (0.66, 0.40, (120, 200, 230, 255))):
        d.ellipse([C * fx - C * 0.05, C * fy - C * 0.032, C * fx + C * 0.05,
                   C * fy + C * 0.032], fill=col)
        d.polygon([(C * fx + C * 0.045, C * fy), (C * fx + 0.085 * C, C * fy - C * 0.03),
                   (C * fx + 0.085 * C, C * fy + C * 0.03)], fill=col)
        circle(d, C * fx - C * 0.022, C * fy - C * 0.006, C * 0.008, fill=INK)
    # bubbles
    for x, y, r in ((0.14, 0.20, 0.020), (0.88, 0.12, 0.016), (0.46, 0.12, 0.014)):
        circle(d, C * x, C * y, C * r, outline=(150, 210, 240, 255), width=int(S * 0.75))

# ================================================================ celestial

@art("ringed_planet", 48)
def _(im, d, C):
    c = C / 2
    # ring behind
    d.ellipse([c - C * 0.46, c - C * 0.15, c + C * 0.46, c + C * 0.15],
              outline=(245, 190, 90, 255), width=int(C * 0.05))
    circle(d, c, c, C * 0.27, fill=(230, 140, 100, 255))
    # bands
    d.pieslice([c - C * 0.27, c - C * 0.27, c + C * 0.27, c + C * 0.27], 200, 340,
               fill=(245, 180, 130, 255))
    d.pieslice([c - C * 0.27, c - C * 0.27, c + C * 0.27, c + C * 0.27], 20, 120,
               fill=(200, 110, 80, 255))
    circle(d, c - C * 0.09, c - C * 0.10, C * 0.05, fill=(250, 210, 170, 255))
    # ring in front (lower half)
    d.arc([c - C * 0.46, c - C * 0.15, c + C * 0.46, c + C * 0.15], 10, 170,
          fill=(250, 210, 120, 255), width=int(C * 0.05))
    d.polygon(star_pts(C * 0.16, C * 0.20, C * 0.045, C * 0.018, 4), fill=(200, 215, 245, 255))
    d.polygon(star_pts(C * 0.84, C * 0.76, C * 0.04, C * 0.016, 4), fill=(200, 215, 245, 255))
    sparkle(d, C * 0.82, C * 0.16, C * 0.035)


@art("cute_ufo", 48)
def _(im, d, C):
    c = C / 2
    # beam
    d.polygon([(c - C * 0.10, C * 0.52), (c + C * 0.10, C * 0.52),
               (c + C * 0.22, C * 0.94), (c - C * 0.22, C * 0.94)],
              fill=(250, 235, 150, 255))
    # dome
    d.pieslice([c - C * 0.17, C * 0.10, c + C * 0.17, C * 0.44], 180, 360,
               fill=(150, 220, 240, 255))
    circle(d, c - C * 0.06, C * 0.22, C * 0.035, fill=(220, 245, 252, 255))
    # alien peeking
    circle(d, c, C * 0.26, C * 0.075, fill=(130, 200, 110, 255))
    for sx in (-1, 1):
        circle(d, c + sx * C * 0.032, C * 0.25, C * 0.018, fill=INK)
    # saucer
    d.ellipse([c - C * 0.36, C * 0.26, c + C * 0.36, C * 0.52], fill=(160, 165, 185, 255))
    d.ellipse([c - C * 0.36, C * 0.26, c + C * 0.36, C * 0.42], fill=(200, 205, 220, 255))
    for i, x in enumerate((-0.24, -0.08, 0.08, 0.24)):
        circle(d, c + C * x, C * 0.44, C * 0.028,
               fill=(250, 205, 70, 255) if i % 2 == 0 else (240, 110, 130, 255))
    d.polygon(star_pts(C * 0.14, C * 0.14, C * 0.04, C * 0.016, 4), fill=(250, 220, 120, 255))
    d.polygon(star_pts(C * 0.86, C * 0.20, C * 0.035, C * 0.014, 4), fill=(200, 215, 245, 255))


@art("hot_air_balloon", 48)
def _(im, d, C):
    c = C / 2
    # envelope
    circle(d, c, C * 0.32, C * 0.28, fill=(220, 70, 80, 255))
    for i, (fw, col) in enumerate([(0.20, (250, 205, 70, 255)), (0.11, (240, 130, 90, 255))]):
        d.ellipse([c - C * fw, C * 0.045, c + C * fw, C * 0.595], fill=col)
    d.ellipse([c - C * 0.045, C * 0.045, c + C * 0.045, C * 0.595], fill=(250, 240, 220, 255))
    # skirt + ropes
    d.polygon([(c - C * 0.13, C * 0.56), (c + C * 0.13, C * 0.56), (c + C * 0.07, C * 0.66),
               (c - C * 0.07, C * 0.66)], fill=(180, 55, 65, 255))
    for sx in (-1, 1):
        d.line([(c + sx * C * 0.07, C * 0.66), (c + sx * C * 0.055, C * 0.74)],
               fill=(140, 95, 55, 255), width=S // 2)
    # basket
    d.rounded_rectangle([c - C * 0.085, C * 0.74, c + C * 0.085, C * 0.86],
                        radius=C * 0.02, fill=(190, 130, 70, 255))
    d.line([(c - C * 0.085, C * 0.78), (c + C * 0.085, C * 0.78)], fill=(150, 100, 55, 255),
           width=S // 2)
    d.line([(c - C * 0.028, C * 0.74), (c - C * 0.028, C * 0.86)], fill=(150, 100, 55, 255),
           width=S // 2)
    d.line([(c + C * 0.028, C * 0.74), (c + C * 0.028, C * 0.86)], fill=(150, 100, 55, 255),
           width=S // 2)
    cloud(d, C * 0.16, C * 0.30, C * 0.05)
    cloud(d, C * 0.84, C * 0.62, C * 0.045)
    circle(d, c - C * 0.12, C * 0.16, C * 0.04, fill=(250, 140, 150, 255))


@art("astro_kitty", 48)
def _(im, d, C):
    c = C / 2
    # helmet
    circle(d, c, C * 0.40, C * 0.28, fill=(210, 230, 250, 255))
    circle(d, c, C * 0.40, C * 0.235, fill=(240, 248, 255, 255))
    # cat head inside
    for sx in (-1, 1):
        d.polygon([(c + sx * C * 0.05, C * 0.28), (c + sx * C * 0.14, C * 0.20),
                   (c + sx * C * 0.16, C * 0.31)], fill=(240, 155, 60, 255))
    d.ellipse([c - C * 0.16, C * 0.28, c + C * 0.16, C * 0.53], fill=(240, 155, 60, 255))
    for sx in (-1, 1):
        eye(d, c + sx * C * 0.065, C * 0.38, C * 0.024)
    d.polygon([(c - C * 0.018, C * 0.435), (c + C * 0.018, C * 0.435), (c, C * 0.46)],
              fill=(220, 100, 120, 255))
    blush2(d, c, C * 0.115, C * 0.43, C * 0.020)
    circle(d, c - C * 0.16, C * 0.24, C * 0.045, fill=(255, 255, 255, 255))
    # suit
    d.rounded_rectangle([c - C * 0.19, C * 0.62, c + C * 0.19, C * 0.90],
                        radius=C * 0.06, fill=(240, 245, 250, 255))
    d.rectangle([c - C * 0.19, C * 0.62, c + C * 0.19, C * 0.68], fill=(200, 210, 225, 255))
    circle(d, c, C * 0.76, C * 0.05, fill=(220, 70, 80, 255))
    for sx in (-1, 1):  # arms
        x0, x1 = sorted((c + sx * C * 0.19, c + sx * C * 0.30))
        d.rounded_rectangle([x0, C * 0.64, x1, C * 0.80],
                            radius=C * 0.04, fill=(240, 245, 250, 255))
    d.polygon(star_pts(C * 0.14, C * 0.18, C * 0.045, C * 0.018, 4), fill=(250, 220, 120, 255))
    d.polygon(star_pts(C * 0.85, C * 0.28, C * 0.035, C * 0.014, 4), fill=(200, 215, 245, 255))
    d.polygon(star_pts(C * 0.82, C * 0.72, C * 0.04, C * 0.016, 4), fill=(250, 220, 120, 255))


@art("comet_trail")
def _(im, d, C):
    # icy comet with sweeping tail (wide at head, tapering to lower-left)
    hx, hy = C * 0.66, C * 0.34
    for w, tf, col in ((0.19, 1.0, (90, 140, 220, 255)), (0.13, 0.92, (140, 190, 240, 255)),
                       (0.07, 0.82, (210, 235, 252, 255))):
        a = math.radians(135)  # tail direction
        px, py = -math.sin(a), math.cos(a)  # perpendicular
        tip = (hx + C * 0.78 * tf * math.cos(a), hy + C * 0.78 * tf * math.sin(a))
        d.polygon([(hx + C * w * px, hy + C * w * py), tip,
                   (hx - C * w * px, hy - C * w * py)], fill=col)
    circle(d, hx, hy, C * 0.185, fill=(180, 215, 245, 255))
    circle(d, hx, hy, C * 0.145, fill=(230, 245, 255, 255))
    circle(d, hx - C * 0.05, hy - C * 0.05, C * 0.045, fill=(255, 255, 255, 255))
    circle(d, hx + C * 0.06, hy + C * 0.04, C * 0.028, fill=(180, 215, 245, 255))
    d.polygon(star_pts(C * 0.86, C * 0.14, C * 0.05, C * 0.02, 4), fill=(250, 220, 120, 255))
    d.polygon(star_pts(C * 0.24, C * 0.24, C * 0.04, C * 0.016, 4), fill=(200, 215, 245, 255))
    d.polygon(star_pts(C * 0.84, C * 0.62, C * 0.035, C * 0.014, 4), fill=(200, 215, 245, 255))


@art("sunny_cloud")
def _(im, d, C):
    c = C / 2
    # sun peeking
    sx, sy = C * 0.60, C * 0.36
    for i in range(10):
        a = i * 36
        d.polygon(petal_pts(sx, sy, a, C * 0.20, C * 0.34, C * 0.035),
                  fill=(250, 190, 60, 255))
    circle(d, sx, sy, C * 0.21, fill=(255, 215, 90, 255))
    circle(d, sx - C * 0.06, sy - C * 0.06, C * 0.05, fill=(255, 240, 160, 255))
    # cloud in front
    cx, cy = C * 0.38, C * 0.62
    for ddx, ddy, rr in ((0, 0, 0.155), (-0.14, 0.04, 0.115), (0.15, 0.03, 0.125),
                         (-0.26, 0.07, 0.08), (0.28, 0.07, 0.08)):
        circle(d, cx + C * ddx, cy + C * ddy, C * rr, fill=(248, 250, 253, 255))
    d.rectangle([cx - C * 0.335, cy + C * 0.04, cx + C * 0.35, cy + C * 0.145],
                fill=(248, 250, 253, 255))
    circle(d, cx - C * 0.10, cy - C * 0.05, C * 0.05, fill=(255, 255, 255, 255))
    for ex in (-1, 1):
        circle(d, cx + ex * C * 0.07, cy + C * 0.02, C * 0.020, fill=INK)
    smile(d, cx, cy + C * 0.045, C * 0.032, C * 0.028)
    blush2(d, cx, C * 0.13, cy + C * 0.045, C * 0.022)


@art("starry_hills", 64)
def _(im, d, C):
    # night sky
    d.rectangle([0, 0, C, C], fill=(25, 25, 70, 255))
    d.rectangle([0, 0, C, C * 0.30], fill=(16, 16, 50, 255))
    # moon
    circle(d, C * 0.72, C * 0.22, C * 0.115, fill=(250, 230, 150, 255))
    circle(d, C * 0.685, C * 0.205, C * 0.028, fill=(230, 205, 120, 255))
    circle(d, C * 0.745, C * 0.26, C * 0.020, fill=(230, 205, 120, 255))
    # stars
    rnd = random.Random(3)
    for i in range(18):
        x, y = C * rnd.uniform(0.04, 0.96), C * rnd.uniform(0.04, 0.50)
        if abs(x - C * 0.72) < C * 0.15 and y < C * 0.35:
            continue
        circle(d, x, y, C * rnd.uniform(0.006, 0.012), fill=(220, 230, 250, 255))
    d.polygon(star_pts(C * 0.20, C * 0.16, C * 0.035, C * 0.014, 4), fill=(250, 220, 120, 255))
    # rolling hills
    d.pieslice([-C * 0.35, C * 0.52, C * 0.55, C * 1.30], 180, 360, fill=(40, 70, 105, 255))
    d.pieslice([C * 0.35, C * 0.58, C * 1.40, C * 1.45], 180, 360, fill=(30, 55, 90, 255))
    d.pieslice([-C * 0.10, C * 0.72, C * 1.10, C * 1.60], 180, 360, fill=(22, 42, 72, 255))
    # tiny house with lit window
    hx, hy = C * 0.28, C * 0.66
    d.rectangle([hx - C * 0.06, hy - C * 0.05, hx + C * 0.06, hy + C * 0.05],
                fill=(60, 50, 55, 255))
    d.polygon([(hx - C * 0.075, hy - C * 0.05), (hx, hy - C * 0.115),
               (hx + C * 0.075, hy - C * 0.05)], fill=(85, 60, 55, 255))
    d.rectangle([hx - C * 0.018, hy - C * 0.025, hx + C * 0.018, hy + C * 0.01],
                fill=(255, 215, 120, 255))
    # pines
    for px, s in ((0.10, 0.9), (0.86, 1.0), (0.94, 0.7)):
        for k in range(3):
            w = C * 0.05 * s * (1 - k * 0.22)
            y0 = C * (0.72 - k * 0.04 * s)
            d.polygon([(C * px - w, y0), (C * px + w, y0), (C * px, y0 - C * 0.05 * s)],
                      fill=(18, 60, 50, 255))


@art("planet_earth")
def _(im, d, C):
    c = C / 2
    circle(d, c, c, C * 0.42, fill=(60, 130, 200, 255))
    # continents
    d.polygon([(c - C * 0.30, c - C * 0.14), (c - C * 0.10, c - C * 0.30),
               (c + C * 0.06, c - C * 0.18), (c - C * 0.06, c - C * 0.02),
               (c - C * 0.24, c + C * 0.04)], fill=(95, 175, 90, 255))
    d.polygon([(c + C * 0.10, c + C * 0.02), (c + C * 0.30, c - C * 0.06),
               (c + C * 0.34, c + C * 0.14), (c + C * 0.16, c + C * 0.26),
               (c + C * 0.04, c + C * 0.16)], fill=(95, 175, 90, 255))
    circle(d, c - C * 0.14, c + C * 0.24, C * 0.075, fill=(95, 175, 90, 255))
    # cloud swirls
    d.arc([c - C * 0.34, c - C * 0.34, c + C * 0.34, c + C * 0.34], -40, 40,
          fill=(240, 248, 255, 255), width=int(C * 0.035))
    d.arc([c - C * 0.30, c - C * 0.30, c + C * 0.30, c + C * 0.30], 150, 220,
          fill=(240, 248, 255, 255), width=int(C * 0.030))
    circle(d, c - C * 0.14, c - C * 0.16, C * 0.05, fill=(140, 195, 235, 255))
    d.polygon(star_pts(C * 0.84, C * 0.18, C * 0.04, C * 0.016, 4), fill=(250, 220, 120, 255))
    sparkle(d, C * 0.16, C * 0.78, C * 0.035)


# ================================================================ mandalas

@art("citrus_mandala", 48)
def _(im, d, C):
    mandala(d, C, (150, 60, 10, 255), [
        ('p', 12, 0.20, 0.46, 0.065, (240, 130, 40, 255)),
        ('p', 12, 0.18, 0.38, 0.05, (250, 180, 60, 255), 15),
        ('d', 12, 0.43, 0.020, (255, 230, 150, 255), 15),
        ('c', 0.21, (250, 205, 80, 255)),
        ('p', 8, 0.04, 0.18, 0.045, (255, 240, 190, 255)),
        ('c', 0.055, (240, 130, 40, 255))])


@art("berry_mandala", 48)
def _(im, d, C):
    mandala(d, C, (70, 20, 60, 255), [
        ('s', 0.465, 0.30, 10, (150, 60, 140, 255)),
        ('p', 10, 0.16, 0.42, 0.06, (215, 90, 160, 255), 18),
        ('d', 10, 0.40, 0.022, (250, 190, 220, 255)),
        ('c', 0.20, (240, 130, 190, 255)),
        ('n', 0.16, 6, (250, 190, 220, 255)),
        ('c', 0.075, (110, 40, 95, 255)),
        ('d', 6, 0.115, 0.018, (250, 190, 220, 255), 30)])


@art("forest_mandala", 48)
def _(im, d, C):
    mandala(d, C, (20, 60, 40, 255), [
        ('p', 14, 0.24, 0.47, 0.05, (45, 130, 80, 255)),
        ('p', 14, 0.22, 0.40, 0.04, (90, 175, 100, 255), 180 / 14),
        ('d', 14, 0.44, 0.016, (200, 230, 150, 255), 180 / 14),
        ('c', 0.235, (35, 100, 60, 255)),
        ('p', 8, 0.06, 0.22, 0.05, (140, 200, 110, 255), 22.5),
        ('c', 0.075, (200, 230, 150, 255)),
        ('c', 0.038, (35, 100, 60, 255))])


@art("sunset_mandala", 64)
def _(im, d, C):
    mandala(d, C, (60, 25, 70, 255), [
        ('s', 0.47, 0.32, 12, (150, 55, 100, 255)),
        ('p', 12, 0.22, 0.44, 0.06, (225, 90, 90, 255)),
        ('p', 12, 0.20, 0.37, 0.05, (245, 140, 60, 255), 15),
        ('d', 12, 0.42, 0.018, (255, 210, 130, 255), 15),
        ('c', 0.215, (245, 170, 80, 255)),
        ('p', 8, 0.05, 0.19, 0.05, (255, 215, 130, 255)),
        ('c', 0.075, (225, 90, 90, 255)),
        ('c', 0.035, (255, 230, 170, 255))])


@art("candy_mandala", 48)
def _(im, d, C):
    mandala(d, C, (245, 205, 220, 255), [
        ('p', 12, 0.22, 0.46, 0.06, (240, 130, 170, 255)),
        ('p', 12, 0.20, 0.38, 0.05, (170, 200, 245, 255), 15),
        ('d', 12, 0.43, 0.020, (255, 255, 255, 255), 15),
        ('c', 0.215, (200, 170, 235, 255)),
        ('p', 6, 0.05, 0.19, 0.055, (255, 245, 200, 255)),
        ('c', 0.07, (240, 130, 170, 255)),
        ('d', 6, 0.13, 0.02, (255, 255, 255, 255), 30)])


@art("midnight_mandala", 64)
def _(im, d, C):
    mandala(d, C, (15, 15, 45, 255), [
        ('p', 16, 0.26, 0.475, 0.045, (55, 60, 130, 255)),
        ('p', 16, 0.24, 0.41, 0.035, (100, 110, 190, 255), 180 / 16),
        ('d', 16, 0.45, 0.014, (220, 225, 250, 255), 180 / 16),
        ('c', 0.255, (30, 30, 80, 255)),
        ('s', 0.24, 0.15, 8, (170, 180, 235, 255)),
        ('n', 0.115, 8, (220, 225, 250, 255), -67.5),
        ('c', 0.055, (55, 60, 130, 255)),
        ('d', 8, 0.325, 0.012, (220, 225, 250, 255), 22.5)])


@art("flamingo_mandala", 48)
def _(im, d, C):
    mandala(d, C, (110, 30, 60, 255), [
        ('p', 10, 0.18, 0.46, 0.075, (230, 90, 120, 255)),
        ('p', 10, 0.16, 0.38, 0.06, (250, 140, 160, 255), 18),
        ('d', 10, 0.43, 0.020, (255, 205, 215, 255), 18),
        ('c', 0.20, (245, 115, 140, 255)),
        ('p', 6, 0.04, 0.175, 0.05, (255, 205, 215, 255), 30),
        ('c', 0.065, (150, 45, 80, 255)),
        ('c', 0.030, (255, 205, 215, 255))])


@art("lagoon_mandala", 48)
def _(im, d, C):
    mandala(d, C, (10, 60, 75, 255), [
        ('s', 0.465, 0.31, 8, (25, 110, 130, 255)),
        ('p', 8, 0.18, 0.42, 0.07, (35, 160, 170, 255), 22.5),
        ('d', 8, 0.41, 0.022, (170, 235, 230, 255)),
        ('c', 0.21, (60, 195, 190, 255)),
        ('n', 0.17, 8, (150, 230, 220, 255), -67.5),
        ('c', 0.085, (15, 85, 100, 255)),
        ('d', 8, 0.125, 0.016, (170, 235, 230, 255), 22.5)])


@art("terracotta_mandala", 48)
def _(im, d, C):
    mandala(d, C, (95, 45, 30, 255), [
        ('p', 12, 0.22, 0.46, 0.06, (185, 95, 55, 255)),
        ('p', 12, 0.20, 0.38, 0.05, (225, 145, 90, 255), 15),
        ('d', 12, 0.43, 0.018, (245, 210, 160, 255), 15),
        ('c', 0.21, (205, 120, 70, 255)),
        ('s', 0.19, 0.12, 8, (245, 210, 160, 255)),
        ('c', 0.075, (140, 65, 40, 255)),
        ('c', 0.035, (245, 210, 160, 255))])


@art("orchid_mandala", 64)
def _(im, d, C):
    mandala(d, C, (55, 15, 70, 255), [
        ('p', 14, 0.24, 0.475, 0.05, (140, 60, 170, 255)),
        ('p', 14, 0.22, 0.40, 0.042, (190, 100, 220, 255), 180 / 14),
        ('d', 14, 0.445, 0.016, (245, 200, 250, 255), 180 / 14),
        ('c', 0.235, (105, 40, 130, 255)),
        ('p', 7, 0.05, 0.21, 0.055, (225, 150, 240, 255), 180 / 14),
        ('c', 0.085, (245, 200, 250, 255)),
        ('c', 0.042, (140, 60, 170, 255)),
        ('d', 14, 0.29, 0.012, (245, 200, 250, 255))])


@art("golden_hour_mandala", 48)
def _(im, d, C):
    mandala(d, C, (110, 60, 15, 255), [
        ('s', 0.465, 0.33, 12, (180, 110, 30, 255)),
        ('p', 12, 0.20, 0.43, 0.055, (235, 165, 50, 255), 15),
        ('d', 12, 0.41, 0.018, (255, 235, 170, 255), 15),
        ('c', 0.20, (250, 195, 85, 255)),
        ('s', 0.18, 0.11, 8, (255, 235, 170, 255)),
        ('c', 0.07, (180, 110, 30, 255)),
        ('c', 0.032, (255, 235, 170, 255))])


@art("arctic_mandala", 48)
def _(im, d, C):
    mandala(d, C, (25, 55, 100, 255), [
        ('p', 8, 0.22, 0.47, 0.055, (90, 150, 210, 255)),
        ('p', 8, 0.20, 0.40, 0.045, (160, 205, 245, 255), 22.5),
        ('d', 8, 0.44, 0.020, (235, 245, 255, 255), 22.5),
        ('c', 0.215, (60, 110, 175, 255)),
        ('s', 0.20, 0.10, 6, (215, 235, 252, 255)),
        ('n', 0.085, 6, (140, 190, 240, 255)),
        ('c', 0.038, (235, 245, 255, 255))])

# ================================================================ patterns

@art("polka_hearts")
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(250, 225, 235, 255))
    step = C / 4
    for gy in range(5):
        for gx in range(5):
            x = gx * step + (step / 2 if gy % 2 else 0)
            y = gy * step
            col = (230, 70, 100, 255) if (gx + gy) % 2 == 0 else (245, 140, 165, 255)
            d.polygon(heart_pts(x, y + step * 0.06, step * 0.30, n=48), fill=col)
    for gy in range(4):
        for gx in range(4):
            circle(d, gx * step + (0 if gy % 2 else step / 2) + step / 2,
                   (gy + 0.5) * step, C * 0.018, fill=(255, 255, 255, 255))


@art("seigaiha_waves", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(20, 60, 100, 255))
    step = C / 4
    for row in range(9):
        y = row * step / 2
        off = step / 2 if row % 2 else 0.0
        x = -step / 2 + off
        while x < C + step:
            for r, col in ((0.52, (35, 100, 150, 255)), (0.40, (240, 245, 248, 255)),
                           (0.28, (35, 100, 150, 255)), (0.16, (240, 245, 248, 255))):
                d.pieslice([x - step * r, y - step * r, x + step * r, y + step * r],
                           0, 180, fill=col)
            x += step
    d.rectangle([0, 0, C, S], fill=(20, 60, 100, 255))


@art("argyle", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(40, 80, 60, 255))
    step = C / 3
    for gy in range(-1, 4):
        for gx in range(-1, 4):
            x = (gx + 0.5) * step + (step / 2 if gy % 2 else 0)
            y = (gy + 0.5) * step
            col = (200, 60, 70, 255) if (gx + gy) % 2 == 0 else (240, 235, 225, 255)
            d.polygon([(x, y - step * 0.52), (x + step * 0.52, y), (x, y + step * 0.52),
                       (x - step * 0.52, y)], fill=col)
    for k in range(-3, 5):
        d.line([(k * step - step, 0 - step * 0.0 + 0), (k * step + C, C)],
               fill=(250, 205, 90, 255), width=S // 2)
        d.line([(k * step + step, 0), (k * step - C, C)],
               fill=(250, 205, 90, 255), width=S // 2)


@art("honeycomb", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(180, 110, 30, 255))
    r = C / 5.2
    h = r * math.sqrt(3) / 2
    row = 0
    y = 0.0
    while y < C + r:
        off = 0 if row % 2 == 0 else r * 1.5
        x = off
        while x < C + r:
            col = (250, 195, 60, 255) if (row + int(x / (3 * r))) % 2 == 0 \
                else (240, 165, 45, 255)
            d.polygon(ngon(x, y, r * 0.92, 6, rot=0), fill=col)
            circle(d, x - r * 0.25, y - r * 0.25, r * 0.16, fill=(255, 225, 130, 255))
            x += 3 * r
        y += h
        row += 1
    # honey drips
    for dx, ln in ((0.28, 0.14), (0.62, 0.20)):
        d.line([(C * dx, 0), (C * dx, C * ln)], fill=(200, 130, 30, 255),
               width=int(C * 0.045))
        circle(d, C * dx, C * ln, C * 0.030, fill=(200, 130, 30, 255))


@art("gingham_picnic")
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(250, 245, 240, 255))
    step = C / 6
    for i in range(0, 6, 2):
        d.rectangle([i * step, 0, (i + 1) * step, C], fill=(240, 130, 140, 128))
        d.rectangle([0, i * step, C, (i + 1) * step], fill=(240, 130, 140, 128))
    # overlap squares darker
    for gx in range(0, 6, 2):
        for gy in range(0, 6, 2):
            d.rectangle([gx * step, gy * step, (gx + 1) * step, (gy + 1) * step],
                        fill=(225, 85, 100, 255))


@art("quilt_stars", 48)
def _(im, d, C):
    step = C / 2
    cols = [((60, 90, 140, 255), (240, 200, 90, 255), (225, 235, 245, 255)),
            ((150, 70, 90, 255), (235, 150, 170, 255), (250, 240, 230, 255)),
            ((70, 120, 90, 255), (170, 210, 150, 255), (250, 240, 220, 255)),
            ((190, 120, 50, 255), (245, 190, 110, 255), (250, 240, 225, 255))]
    for gy in range(2):
        for gx in range(2):
            bg, star, dot = cols[gy * 2 + gx]
            x0, y0 = gx * step, gy * step
            d.rectangle([x0, y0, x0 + step, y0 + step], fill=bg)
            cxx, cyy = x0 + step / 2, y0 + step / 2
            d.polygon(star_pts(cxx, cyy, step * 0.44, step * 0.18, 8), fill=star)
            d.polygon(ngon(cxx, cyy, step * 0.15, 4, rot=-45), fill=dot)
            for corner in ((x0, y0), (x0 + step, y0), (x0, y0 + step),
                           (x0 + step, y0 + step)):
                circle(d, corner[0], corner[1], step * 0.10, fill=dot)
    # stitch lines
    for f in (0, 0.5, 1.0):
        d.line([(C * f, 0), (C * f, C)], fill=(90, 70, 60, 255), width=S // 2)
        d.line([(0, C * f), (C, C * f)], fill=(90, 70, 60, 255), width=S // 2)


@art("chevron_sunset")
def _(im, d, C):
    cols = [(225, 60, 90, 255), (240, 110, 70, 255), (250, 165, 60, 255),
            (250, 210, 90, 255), (170, 90, 160, 255), (100, 70, 150, 255)]
    zig = C / 4
    hband = C / 4.2
    for row in range(8):
        col = cols[row % 6]
        y0 = row * hband - hband
        pts = []
        for i in range(6):
            x = i * zig
            pts.append((x, y0 + (0 if i % 2 == 0 else zig * 0.6)))
        poly = pts + [(p[0], p[1] + hband) for p in pts[::-1]]
        d.polygon(poly, fill=col)


@art("terrazzo", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(240, 235, 228, 255))
    rnd = random.Random(21)
    cols = [(230, 110, 90, 255), (60, 130, 130, 255), (245, 190, 90, 255),
            (150, 110, 170, 255), (90, 90, 110, 255), (240, 160, 170, 255)]
    for i in range(26):
        x, y = C * rnd.random(), C * rnd.random()
        r = C * rnd.uniform(0.035, 0.10)
        n = rnd.choice([3, 4, 5])
        rot = rnd.uniform(0, 360)
        pts = [(x + r * math.cos(math.radians(rot + k * 360 / n + rnd.uniform(-18, 18))),
                y + r * math.sin(math.radians(rot + k * 360 / n + rnd.uniform(-18, 18))))
               for k in range(n)]
        d.polygon(pts, fill=cols[i % 6])
    for i in range(14):
        circle(d, C * rnd.random(), C * rnd.random(), C * rnd.uniform(0.008, 0.018),
               fill=cols[(i + 3) % 6])


@art("tartan_cozy", 48)
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(140, 40, 50, 255))
    # wide bands
    for f in (0.12, 0.62):
        d.rectangle([C * f, 0, C * (f + 0.18), C], fill=(60, 80, 60, 128))
        d.rectangle([0, C * f, C, C * (f + 0.18)], fill=(60, 80, 60, 128))
    # thin gold + white lines
    for f in (0.06, 0.48, 0.90):
        d.rectangle([C * f, 0, C * f + C * 0.025, C], fill=(245, 200, 90, 255))
        d.rectangle([0, C * f, C, C * f + C * 0.025], fill=(245, 200, 90, 255))
    for f in (0.30, 0.76):
        d.rectangle([C * f, 0, C * f + C * 0.018, C], fill=(245, 240, 235, 255))
        d.rectangle([0, C * f, C, C * f + C * 0.018], fill=(245, 240, 235, 255))


@art("bubble_pop")
def _(im, d, C):
    d.rectangle([0, 0, C, C], fill=(140, 205, 235, 255))
    rnd = random.Random(14)
    cols = [(240, 130, 170, 255), (250, 205, 90, 255), (150, 110, 210, 255),
            (90, 180, 160, 255), (245, 245, 250, 255)]
    for i in range(16):
        x, y = C * rnd.random(), C * rnd.random()
        r = C * rnd.uniform(0.05, 0.16)
        col = cols[i % 5]
        circle(d, x, y, r, fill=col)
        circle(d, x - r * 0.35, y - r * 0.35, r * 0.28, fill=(255, 255, 255, 255))
    for i in range(8):
        circle(d, C * rnd.random(), C * rnd.random(), C * rnd.uniform(0.012, 0.024),
               fill=(255, 255, 255, 255))


# ================================================================ objects

@art("royal_crown")
def _(im, d, C):
    c = C / 2
    gold = (240, 190, 60, 255)
    dark = (200, 145, 30, 255)
    # band
    d.rounded_rectangle([c - C * 0.36, C * 0.62, c + C * 0.36, C * 0.80],
                        radius=C * 0.03, fill=gold)
    d.rectangle([c - C * 0.36, C * 0.62, c + C * 0.36, C * 0.665], fill=dark)
    # points with ball tips
    for i, (dx, h) in enumerate([(-0.28, 0.34), (0.0, 0.22), (0.28, 0.34)]):
        d.polygon([(c + C * dx - C * 0.10, C * 0.64), (c + C * dx, C * h),
                   (c + C * dx + C * 0.10, C * 0.64)], fill=gold)
        circle(d, c + C * dx, C * h, C * 0.038, fill=(250, 220, 120, 255))
    # jewels
    circle(d, c, C * 0.71, C * 0.048, fill=(220, 60, 80, 255))
    for sx in (-1, 1):
        d.polygon(ngon(c + sx * C * 0.22, C * 0.71, C * 0.038, 4, rot=-45),
                  fill=(60, 140, 220, 255))
    circle(d, c - C * 0.02, C * 0.695, C * 0.016, fill=(250, 150, 165, 255))
    sparkle(d, C * 0.80, C * 0.26, C * 0.045)
    sparkle(d, C * 0.20, C * 0.34, C * 0.035)


@art("vintage_key")
def _(im, d, C):
    gold = (215, 170, 60, 255)
    dark = (170, 125, 35, 255)
    # bow (ornate ring at top-left, diagonal composition)
    bx, by = C * 0.30, C * 0.30
    circle(d, bx, by, C * 0.17, fill=gold)
    circle(d, bx, by, C * 0.09, fill=(0, 0, 0, 0))
    for i in range(3):
        a = math.radians(-150 + i * 120)
        circle(d, bx + C * 0.19 * math.cos(a), by + C * 0.19 * math.sin(a),
               C * 0.045, fill=dark)
    circle(d, bx + C * 0.12, by - C * 0.12, C * 0.035, fill=(250, 220, 130, 255))
    # shaft
    d.line([(bx + C * 0.12, by + C * 0.12), (C * 0.76, C * 0.76)], fill=gold,
           width=int(C * 0.06))
    # teeth
    d.line([(C * 0.76, C * 0.76), (C * 0.84, C * 0.68)], fill=gold, width=int(C * 0.055))
    d.line([(C * 0.66, C * 0.66), (C * 0.745, C * 0.585)], fill=gold, width=int(C * 0.05))
    sparkle(d, C * 0.80, C * 0.24, C * 0.045)
    sparkle(d, C * 0.18, C * 0.72, C * 0.035)


@art("party_balloons", 48)
def _(im, d, C):
    cols = [((225, 70, 90, 255), 0.30, 0.30, 0.155), ((250, 190, 60, 255), 0.62, 0.22, 0.135),
            ((90, 150, 220, 255), 0.76, 0.46, 0.125)]
    for col, x, y, r in cols:
        # string
        pts = [(C * x + C * 0.02 * math.sin(k * 1.4), C * (y + r) + (C * 0.72 - C * (y + r)) * k / 6)
               for k in range(7)]
        d.line(pts, fill=(120, 120, 140, 255), width=S // 2, joint="curve")
        d.ellipse([C * x - C * r, C * (y - r * 1.15), C * x + C * r, C * (y + r * 1.15)],
                  fill=col)
        d.polygon([(C * x - C * 0.025, C * (y + r * 1.15)), (C * x + C * 0.025, C * (y + r * 1.15)),
                   (C * x, C * (y + r * 1.15) + C * 0.03)], fill=col)
        circle(d, C * x - C * r * 0.35, C * (y - r * 0.45), C * r * 0.26,
               fill=(255, 255, 255, 200))
    # confetti
    rnd = random.Random(17)
    ccols = [(240, 130, 170, 255), (250, 205, 90, 255), (120, 200, 170, 255),
             (150, 110, 210, 255)]
    for i in range(12):
        x, y = C * rnd.random(), C * rnd.uniform(0.55, 0.95)
        d.line([(x, y), (x + C * 0.025, y - C * 0.02)], fill=ccols[i % 4],
               width=int(S * 0.9))


@art("gift_box")
def _(im, d, C):
    c = C / 2
    box = (220, 70, 90, 255)
    ribbon = (250, 205, 80, 255)
    # lid
    d.rectangle([c - C * 0.34, C * 0.34, c + C * 0.34, C * 0.48], fill=(200, 55, 75, 255))
    # box
    d.rectangle([c - C * 0.28, C * 0.48, c + C * 0.28, C * 0.88], fill=box)
    # ribbon
    d.rectangle([c - C * 0.045, C * 0.34, c + C * 0.045, C * 0.88], fill=ribbon)
    d.rectangle([c - C * 0.34, C * 0.385, c + C * 0.34, C * 0.44], fill=ribbon)
    # bow
    for sx in (-1, 1):
        d.polygon(petal_pts(c, C * 0.30, 90 + sx * 90 + sx * 40 - 90 * sx, 0, 1, 1)
                  if False else
                  [(c, C * 0.31), (c + sx * C * 0.16, C * 0.18),
                   (c + sx * C * 0.19, C * 0.30)], fill=ribbon)
        circle(d, c + sx * C * 0.11, C * 0.255, C * 0.035, fill=(255, 230, 150, 255))
    circle(d, c, C * 0.31, C * 0.045, fill=(255, 230, 150, 255))
    circle(d, c - C * 0.19, C * 0.58, C * 0.035, fill=(245, 130, 150, 255))
    sparkle(d, C * 0.82, C * 0.22, C * 0.045)
    sparkle(d, C * 0.16, C * 0.20, C * 0.035)


@art("umbrella_rain", 48)
def _(im, d, C):
    c = C / 2
    # canopy
    d.pieslice([c - C * 0.38, C * 0.10, c + C * 0.38, C * 0.86], 180, 360,
               fill=(230, 80, 100, 255))
    for i in range(4):  # panels
        x0 = c - C * 0.38 + i * C * 0.19
        d.arc([x0, C * 0.40, x0 + C * 0.19, C * 0.56], 180, 360,
              fill=(190, 55, 80, 255), width=S // 2)
    for i in (1, 3):  # alternate panels lighter
        d.pieslice([c - C * 0.38, C * 0.10, c + C * 0.38, C * 0.86],
                   180 + i * 45, 180 + (i + 1) * 45, fill=(245, 130, 145, 255))
    circle(d, c, C * 0.135, C * 0.035, fill=(190, 55, 80, 255))
    # handle
    d.line([(c, C * 0.48), (c, C * 0.82)], fill=(140, 95, 55, 255), width=int(C * 0.032))
    d.arc([c - C * 0.09, C * 0.76, c + C * 0.09, C * 0.92], 0, 180,
          fill=(140, 95, 55, 255), width=int(C * 0.032))
    # raindrops
    rnd = random.Random(9)
    for i in range(8):
        x = C * rnd.uniform(0.05, 0.95)
        y = C * rnd.uniform(0.05, 0.30) if abs(x - c) < C * 0.4 else C * rnd.uniform(0.05, 0.85)
        d.polygon(teardrop_pts(x, y, C * 0.022, y - C * 0.05), fill=(120, 180, 235, 255))


@art("teacup", 48)
def _(im, d, C):
    c = C / 2
    # steam
    for dx in (-0.06, 0.08):
        pts = [(c + C * dx + C * 0.025 * math.sin(k * 1.6), C * (0.08 + 0.04 * k))
               for k in range(5)]
        d.line(pts, fill=(200, 210, 225, 255), width=int(C * 0.022), joint="curve")
    # saucer
    d.ellipse([c - C * 0.36, C * 0.74, c + C * 0.36, C * 0.90], fill=(240, 235, 245, 255))
    d.ellipse([c - C * 0.24, C * 0.77, c + C * 0.24, C * 0.87], fill=(215, 205, 230, 255))
    # cup
    d.pieslice([c - C * 0.28, C * 0.10, c + C * 0.28, C * 0.90], 0, 180,
               fill=(250, 248, 252, 255))
    d.rectangle([c - C * 0.28, C * 0.36, c + C * 0.28, C * 0.50], fill=(250, 248, 252, 255))
    d.ellipse([c - C * 0.28, C * 0.30, c + C * 0.28, C * 0.42], fill=(240, 235, 245, 255))
    d.ellipse([c - C * 0.24, C * 0.325, c + C * 0.24, C * 0.415], fill=(180, 120, 70, 255))
    circle(d, c - C * 0.08, C * 0.355, C * 0.028, fill=(215, 160, 110, 255))
    # handle
    d.arc([c + C * 0.24, C * 0.42, c + C * 0.42, C * 0.62], -80, 100,
          fill=(240, 235, 245, 255), width=int(C * 0.035))
    # cup pattern
    for sx in (-1, 0, 1):
        d.polygon(heart_pts(c + sx * C * 0.14, C * 0.60, C * 0.045, n=40),
                  fill=(240, 130, 160, 255))
    sparkle(d, C * 0.82, C * 0.18, C * 0.04)


@art("game_controller", 48)
def _(im, d, C):
    c = C / 2
    body = (110, 115, 200, 255)
    # grips
    for sx in (-1, 1):
        d.ellipse([c + sx * C * 0.36 - C * 0.14, C * 0.36, c + sx * C * 0.36 + C * 0.14,
                   C * 0.72], fill=body)
    d.rounded_rectangle([c - C * 0.38, C * 0.34, c + C * 0.38, C * 0.62],
                        radius=C * 0.10, fill=(135, 140, 220, 255))
    # d-pad
    px, py = c - C * 0.22, C * 0.48
    d.rectangle([px - C * 0.095, py - C * 0.032, px + C * 0.095, py + C * 0.032],
                fill=(45, 45, 60, 255))
    d.rectangle([px - C * 0.032, py - C * 0.095, px + C * 0.032, py + C * 0.095],
                fill=(45, 45, 60, 255))
    # buttons
    for a, col in ((0, (220, 70, 90, 255)), (90, (250, 205, 80, 255)),
                   (180, (95, 190, 120, 255)), (270, (90, 170, 235, 255))):
        ar = math.radians(a)
        circle(d, c + C * 0.22 + C * 0.07 * math.cos(ar), C * 0.48 + C * 0.07 * math.sin(ar),
               C * 0.036, fill=col)
    # start/select
    for sx in (-1, 1):
        d.rounded_rectangle([c + sx * C * 0.05 - C * 0.03, C * 0.545,
                             c + sx * C * 0.05 + C * 0.03, C * 0.575],
                            radius=C * 0.01, fill=(45, 45, 60, 255))
    circle(d, c - C * 0.30, C * 0.40, C * 0.030, fill=(170, 175, 240, 255))
    sparkle(d, C * 0.84, C * 0.24, C * 0.04)


@art("music_notes")
def _(im, d, C):
    # beamed pair + single note, bouncy composition
    n1x, n2x = C * 0.30, C * 0.56
    ny = C * 0.62
    for x, dy in ((n1x, 0), (n2x, -C * 0.06)):
        d.ellipse([x - C * 0.085, ny + dy - C * 0.06, x + C * 0.085, ny + dy + C * 0.06],
                  fill=(70, 80, 160, 255))
        d.line([(x + C * 0.075, ny + dy), (x + C * 0.075, ny + dy - C * 0.34)],
               fill=(70, 80, 160, 255), width=int(C * 0.030))
    d.polygon([(n1x + C * 0.06, ny - C * 0.34), (n2x + C * 0.09, ny - C * 0.40),
               (n2x + C * 0.09, ny - C * 0.31), (n1x + C * 0.06, ny - C * 0.25)],
              fill=(70, 80, 160, 255))
    # single eighth note
    sx0, sy0 = C * 0.80, C * 0.36
    d.ellipse([sx0 - C * 0.07, sy0 - C * 0.05, sx0 + C * 0.07, sy0 + C * 0.05],
              fill=(220, 70, 110, 255))
    d.line([(sx0 + C * 0.06, sy0), (sx0 + C * 0.06, sy0 - C * 0.26)],
           fill=(220, 70, 110, 255), width=int(C * 0.026))
    d.polygon(petal_pts(sx0 + C * 0.06, sy0 - C * 0.26, 55, 0, C * 0.14, C * 0.045),
              fill=(220, 70, 110, 255))
    sparkle(d, C * 0.16, C * 0.24, C * 0.045)
    sparkle(d, C * 0.70, C * 0.80, C * 0.035)
    circle(d, C * 0.14, C * 0.80, C * 0.022, fill=(250, 205, 90, 255))

# ================================================================ main

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
