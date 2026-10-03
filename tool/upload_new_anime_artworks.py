#!/usr/bin/env python3
"""Generate 8 rich, authentic Anime Artworks and publish to Firestore via Admin Catalog pipeline.

Artworks:
1. Cosmic Sailor Guardian (Heroes, 32x32, Difficulty 4, Premium)
2. Flame Alchemist (Heroes, 32x32, Difficulty 4, Premium)
3. Kawaii Hanami Dango (Kawaii, 24x24, Difficulty 2, Free)
4. Strike Wing Gundam (Mecha, 32x32, Difficulty 4, Premium)
5. Shinigami Ryuk Spirit (Monsters, 32x32, Difficulty 3, Free)
6. Armored Colossus Face (Monsters, 32x32, Difficulty 4, Premium)
7. Kawaii Taiyaki Cake (Kawaii, 24x24, Difficulty 2, Free)
8. Eternal Mangekyo Eye (Eyes, 24x24, Difficulty 3, Free)

Follows pixel_art_admin CatalogService & RemoteArtwork schema:
- Doc path: pixel_art/anime/artworks/rmt_<id>_<timestamp>
- Bumps pixel_art/anime.catalogVersion
"""

import time
import os
import sys

SERVICE_KEY = "/home/rameshx99/Downloads/om108-5c015-firebase-adminsdk-fbsvc-d17fdb4254.json"

def argb(a, r, g, b):
    """Signed 32-bit ARGB integer matching Flutter Color.toARGB32()."""
    val = (a << 24) | (r << 16) | (g << 8) | b
    if val >= 0x80000000:
        val -= 0x100000000
    return val

def hex_to_argb(hex_str):
    hex_str = hex_str.lstrip('#')
    if len(hex_str) == 6:
        r = int(hex_str[0:2], 16)
        g = int(hex_str[2:4], 16)
        b = int(hex_str[4:6], 16)
        return argb(255, r, g, b)
    elif len(hex_str) == 8:
        a = int(hex_str[0:2], 16)
        r = int(hex_str[2:4], 16)
        g = int(hex_str[4:6], 16)
        b = int(hex_str[6:8], 16)
        return argb(a, r, g, b)
    raise ValueError(f"Invalid hex color: {hex_str}")

def grid_to_string(grid):
    return ";".join(",".join(str(c) for c in row) for row in grid)

# -------------------------------------------------------------
# 1. Cosmic Sailor Guardian (32x32)
# -------------------------------------------------------------
def make_sailor_guardian():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#0F172A"),  # Dark Outline
        "2": hex_to_argb("#FDE047"),  # Bright Golden Blonde Hair
        "3": hex_to_argb("#EAB308"),  # Blonde Shadow
        "4": hex_to_argb("#FEF3C7"),  # Fair Skin Tone
        "5": hex_to_argb("#FDE68A"),  # Skin Shadow
        "6": hex_to_argb("#FB7185"),  # Pink Blushing Cheeks
        "7": hex_to_argb("#38BDF8"),  # Bright Cyan Anime Eyes
        "8": hex_to_argb("#0284C7"),  # Deep Cyan Eye Pupil
        "9": hex_to_argb("#FFFFFF"),  # Sparkle White
        "10": hex_to_argb("#E11D48"), # Ruby Red Ribbon / Bow
        "11": hex_to_argb("#9F1239"), # Dark Red Bow Shadow
        "12": hex_to_argb("#1E3A8A"), # Royal Sailor Blue Collar
        "13": hex_to_argb("#F59E0B"), # Golden Tiara & Brooch
    }

    # Odango buns (left & right top)
    for r in range(4, 9):
        for c in range(4, 9):
            g[r][c] = 2
    g[5][5] = 10; g[5][6] = 10; g[6][5] = 10; g[6][6] = 10
    g[6][6] = 9

    for r in range(4, 9):
        for c in range(23, 28):
            g[r][c] = 2
    g[5][25] = 10; g[5][26] = 10; g[6][25] = 10; g[6][26] = 10
    g[6][25] = 9

    # Golden Tiara arch
    for c in range(12, 20):
        g[7][c] = 13
    g[7][15] = 10; g[7][16] = 10
    g[6][15] = 13; g[6][16] = 13

    # Hair crown and fringe bangs
    for r in range(7, 12):
        for c in range(9, 23):
            if g[r][c] == 0:
                g[r][c] = 2
    for c in range(11, 21):
        g[10][c] = 3

    # Long flowing twintails
    for r in range(9, 27):
        g[r][3] = 2; g[r][4] = 2; g[r][5] = 3
        g[r][26] = 3; g[r][27] = 2; g[r][28] = 2
    g[27][4] = 2; g[27][5] = 2; g[28][5] = 2; g[28][6] = 2
    g[27][26] = 2; g[27][27] = 2; g[28][25] = 2; g[28][26] = 2

    # Face area
    for r in range(11, 20):
        for c in range(11, 21):
            g[r][c] = 4
    g[19][11] = 0; g[19][20] = 0
    g[20][13] = 4; g[20][14] = 4; g[20][15] = 4; g[20][16] = 4; g[20][17] = 4; g[20][18] = 4
    g[21][15] = 4; g[21][16] = 4

    # Anime Eyes
    g[13][12] = 1; g[13][13] = 1; g[13][14] = 1
    g[14][12] = 8; g[14][13] = 7; g[14][14] = 9
    g[15][12] = 8; g[15][13] = 7; g[15][14] = 8

    g[13][17] = 1; g[13][18] = 1; g[13][19] = 1
    g[14][17] = 9; g[14][18] = 7; g[14][19] = 8
    g[15][17] = 8; g[15][18] = 7; g[15][19] = 8

    # Blush
    g[16][12] = 6; g[16][13] = 6
    g[16][18] = 6; g[16][19] = 6

    # Nose & smile
    g[16][15] = 5
    g[18][15] = 10; g[18][16] = 10

    # Choker necklace
    g[22][14] = 10; g[22][15] = 13; g[22][16] = 13; g[22][17] = 10

    # Sailor Collar
    for c in range(8, 24):
        g[23][c] = 12
        g[24][c] = 12
    g[24][9] = 9; g[24][10] = 9; g[24][21] = 9; g[24][22] = 9

    # Chest front
    for r in range(25, 31):
        for c in range(12, 20):
            g[r][c] = 9

    # Ruby Ribbon Bow
    for r in range(25, 29):
        for c in range(9, 13):
            g[r][c] = 10
        for c in range(19, 23):
            g[r][c] = 10
    g[26][10] = 11; g[27][10] = 11
    g[26][21] = 11; g[27][21] = 11
    g[25][15] = 13; g[25][16] = 13
    g[26][15] = 13; g[26][16] = 13
    g[26][15] = 10

    # Ribbon tails
    g[29][13] = 10; g[29][14] = 10; g[30][13] = 10
    g[29][17] = 10; g[29][18] = 10; g[30][18] = 10

    return {
        "id": "cosmic_sailor_guardian",
        "name": "Cosmic Sailor Guardian",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 100,
        "sortOrder": 1,
    }

# -------------------------------------------------------------
# 2. Flame Alchemist (32x32)
# -------------------------------------------------------------
def make_flame_alchemist():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#0F172A"),  # Deep Slate / Dark Outlines
        "2": hex_to_argb("#1E293B"),  # Black Anime Hair
        "3": hex_to_argb("#334155"),  # Hair Highlights
        "4": hex_to_argb("#FED7AA"),  # Skin Tone
        "5": hex_to_argb("#FDBA74"),  # Skin Shadow
        "6": hex_to_argb("#1E40AF"),  # State Alchemist Blue Uniform Coat
        "7": hex_to_argb("#1D4ED8"),  # Bright Blue Coat Accent
        "8": hex_to_argb("#F59E0B"),  # Gold Military Trim / Cords
        "9": hex_to_argb("#FFFFFF"),  # Ignition Cloth Glove / Spark White
        "10": hex_to_argb("#EF4444"), # Red Transmutation Array Crest & Fire
        "11": hex_to_argb("#F97316"), # Bright Orange Flame Burst
        "12": hex_to_argb("#FACC15"), # Vivid Yellow Fire Core
    }

    # Spiky Dark Anime Hair
    for c in range(10, 22):
        g[4][c] = 2; g[5][c] = 2; g[6][c] = 2
    g[3][12] = 2; g[3][13] = 2; g[3][18] = 2; g[3][19] = 2
    g[2][13] = 2; g[2][18] = 2
    g[5][14] = 3; g[5][15] = 3; g[5][16] = 3

    for r in range(7, 10):
        for c in range(9, 23):
            g[r][c] = 2
    g[9][11] = 2; g[10][11] = 2; g[9][15] = 2; g[10][15] = 2; g[9][20] = 2

    # Face
    for r in range(9, 18):
        for c in range(12, 20):
            if g[r][c] == 0:
                g[r][c] = 4
    g[17][12] = 0; g[17][19] = 0
    g[18][14] = 4; g[18][15] = 4; g[18][16] = 4; g[18][17] = 4
    g[19][15] = 4; g[19][16] = 4

    # Eyes & Eyebrows
    g[11][12] = 1; g[11][13] = 1; g[11][14] = 1
    g[11][17] = 1; g[11][18] = 1; g[11][19] = 1
    g[12][13] = 1; g[13][13] = 1; g[13][14] = 9
    g[12][18] = 1; g[13][18] = 1; g[13][17] = 9

    # Smirk
    g[16][15] = 1; g[16][16] = 1; g[15][17] = 1

    # Military Collar & Gold Cord
    for c in range(12, 20):
        g[20][c] = 6
        g[21][c] = 6
    g[20][15] = 8; g[20][16] = 8
    g[21][13] = 8; g[21][14] = 8; g[21][17] = 8; g[21][18] = 8

    # Blue Jacket
    for r in range(22, 31):
        for c in range(10, 22):
            g[r][c] = 6
    g[22][8] = 6; g[22][9] = 6; g[23][8] = 8; g[23][9] = 8
    g[22][22] = 6; g[22][23] = 6; g[23][22] = 8; g[23][22] = 8
    g[24][16] = 8; g[26][16] = 8; g[28][16] = 8
    for c in range(10, 22):
        g[30][c] = 1

    # Right Hand: White Ignition Glove with Red Crest
    for r in range(22, 27):
        for c in range(23, 28):
            g[r][c] = 9
    g[23][25] = 10; g[24][24] = 10; g[24][25] = 10; g[24][26] = 10; g[25][25] = 10

    # Flame Burst from Snap
    flame_coords = [
        (16, 26, 12), (16, 27, 11), (17, 25, 12), (17, 26, 12), (17, 27, 11),
        (18, 25, 12), (18, 26, 12), (18, 27, 11), (18, 28, 10),
        (19, 26, 11), (19, 27, 11), (19, 28, 10),
        (15, 27, 11), (14, 27, 11), (14, 28, 10), (13, 28, 11), (12, 28, 12),
        (15, 29, 10), (16, 29, 11), (17, 29, 10), (16, 30, 10),
        (20, 28, 11), (20, 29, 10), (21, 29, 10),
        (11, 27, 12), (13, 30, 11), (18, 30, 11), (19, 31, 10)
    ]
    for r, c, col in flame_coords:
        if 0 <= r < h and 0 <= c < w:
            g[r][c] = col

    return {
        "id": "flame_alchemist",
        "name": "Flame Alchemist",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 100,
        "sortOrder": 2,
    }

# -------------------------------------------------------------
# 3. Kawaii Hanami Dango (24x24)
# -------------------------------------------------------------
def make_hanami_dango():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#1E293B"),  # Ink Details
        "2": hex_to_argb("#F472B6"),  # Sakura Pink Dango
        "3": hex_to_argb("#FB7185"),  # Pink Shadow / Cheeks
        "4": hex_to_argb("#F8FAFC"),  # Snowy White Dango
        "5": hex_to_argb("#E2E8F0"),  # White Mochi Shadow
        "6": hex_to_argb("#84CC16"),  # Matcha Green Dango
        "7": hex_to_argb("#65A30D"),  # Matcha Shadow
        "8": hex_to_argb("#D97706"),  # Bamboo Skewer Wood
        "9": hex_to_argb("#B45309"),  # Skewer Shadow
        "10": hex_to_argb("#FFFFFF"), # Gloss / Specular Highlights
        "11": hex_to_argb("#FDE047"), # Kawaii Sparkles
    }

    # Bamboo Skewer
    g[2][11] = 8; g[2][12] = 8
    g[3][11] = 8; g[3][12] = 8
    for r in range(19, 23):
        g[r][11] = 8; g[r][12] = 9

    # 1. Pink Dango
    for r in range(4, 9):
        for c in range(8, 16):
            g[r][c] = 2
    g[4][8] = 0; g[4][15] = 0; g[8][8] = 0; g[8][15] = 0
    g[5][9] = 10; g[5][10] = 10
    g[7][9] = 3; g[7][14] = 3
    g[6][10] = 1; g[6][13] = 1
    g[7][11] = 1; g[7][12] = 1

    # 2. White Dango
    for r in range(9, 14):
        for c in range(8, 16):
            g[r][c] = 4
    g[9][8] = 0; g[9][15] = 0; g[13][8] = 0; g[13][15] = 0
    g[10][9] = 10; g[10][10] = 10
    g[12][9] = 3; g[12][14] = 3
    g[11][10] = 1; g[11][13] = 1
    g[12][11] = 1; g[12][12] = 1

    # 3. Matcha Dango
    for r in range(14, 19):
        for c in range(8, 16):
            g[r][c] = 6
    g[14][8] = 0; g[14][15] = 0; g[18][8] = 0; g[18][15] = 0
    g[15][9] = 10; g[15][10] = 10
    g[17][9] = 7; g[17][14] = 7
    g[16][10] = 1; g[16][13] = 1
    g[17][11] = 1; g[17][12] = 1

    # Sparkles
    g[3][5] = 11; g[4][4] = 11; g[4][5] = 10; g[4][6] = 11; g[5][5] = 11
    g[10][19] = 11; g[11][18] = 11; g[11][19] = 10; g[11][20] = 11; g[12][19] = 11
    g[17][4] = 11; g[18][3] = 11; g[18][4] = 10; g[18][5] = 11; g[19][4] = 11

    return {
        "id": "kawaii_hanami_dango",
        "name": "Kawaii Hanami Dango",
        "category": "Kawaii",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 3,
    }

# -------------------------------------------------------------
# 4. Strike Wing Gundam (32x32)
# -------------------------------------------------------------
def make_gundam_mecha():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#0F172A"),  # Mechanical Panel Line Ink
        "2": hex_to_argb("#F8FAFC"),  # Titanium White Armor
        "3": hex_to_argb("#CBD5E1"),  # Armor Shading
        "4": hex_to_argb("#FACC15"),  # Golden V-Fin Crest Antenna
        "5": hex_to_argb("#CA8A04"),  # V-Fin Gold Shadow
        "6": hex_to_argb("#EF4444"),  # Crimson Head Sensor & Chin Guard
        "7": hex_to_argb("#B91C1C"),  # Dark Crimson Shadow
        "8": hex_to_argb("#10B981"),  # Glowing Green Optic Dual Eyes
        "9": hex_to_argb("#047857"),  # Dark Green Eye Socket
        "10": hex_to_argb("#2563EB"), # Cobalt Blue Torso Armor
        "11": hex_to_argb("#1D4ED8"), # Deep Blue Shading
        "12": hex_to_argb("#475569"), # Gunmetal Face & Neck Vents
    }

    # Left V-Fin
    g[3][6] = 4; g[4][7] = 4; g[5][8] = 4; g[6][9] = 4; g[7][10] = 4; g[8][11] = 4; g[9][12] = 4
    g[4][6] = 5; g[5][7] = 5; g[6][8] = 5; g[7][9] = 5; g[8][10] = 5; g[9][11] = 5
    # Right V-Fin
    g[3][25] = 4; g[4][24] = 4; g[5][23] = 4; g[6][22] = 4; g[7][21] = 4; g[8][20] = 4; g[9][19] = 4
    g[4][25] = 5; g[5][24] = 5; g[6][23] = 5; g[7][22] = 5; g[8][21] = 5; g[9][20] = 5

    # Center Red Sensor
    for r in range(7, 11):
        for c in range(14, 18):
            g[r][c] = 6
    g[8][15] = 7; g[8][16] = 7

    # V-Fin Base Mount
    g[10][13] = 4; g[10][14] = 4; g[10][17] = 4; g[10][18] = 4
    g[11][14] = 4; g[11][15] = 6; g[11][16] = 6; g[11][17] = 4

    # White Helmet Crown & Sides
    for r in range(9, 14):
        for c in range(10, 22):
            if g[r][c] == 0:
                g[r][c] = 2
    g[12][8] = 12; g[12][9] = 12; g[13][8] = 12; g[13][9] = 12
    g[12][22] = 12; g[12][23] = 12; g[13][22] = 12; g[13][23] = 12

    # Face Mask Plate
    for r in range(14, 20):
        for c in range(11, 21):
            g[r][c] = 2

    # Glowing Green Optic Eyes
    g[14][12] = 9; g[14][13] = 9; g[14][14] = 9
    g[14][17] = 9; g[14][18] = 9; g[14][19] = 9
    g[15][12] = 8; g[15][13] = 8; g[15][14] = 9
    g[15][17] = 9; g[15][18] = 8; g[15][19] = 8

    # Faceplate Vents
    g[17][14] = 12; g[17][17] = 12
    g[18][14] = 12; g[18][17] = 12

    # Crimson Chin Guard
    for r in range(19, 22):
        for c in range(14, 18):
            g[r][c] = 6
    g[21][14] = 7; g[21][17] = 7

    # Neck
    for c in range(12, 20):
        g[22][c] = 12

    # Blue Chest Armor & Vents
    for r in range(23, 31):
        for c in range(8, 24):
            g[r][c] = 10
    for r in range(23, 28):
        for c in range(14, 18):
            g[r][c] = 2
    g[27][15] = 6; g[27][16] = 6

    g[24][10] = 4; g[24][11] = 4; g[25][10] = 4; g[25][11] = 4
    g[24][20] = 4; g[24][21] = 4; g[25][20] = 4; g[25][21] = 4

    return {
        "id": "strike_wing_gundam",
        "name": "Strike Wing Gundam",
        "category": "Mecha",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 120,
        "sortOrder": 4,
    }

# -------------------------------------------------------------
# 5. Shinigami Ryuk Spirit (32x32)
# -------------------------------------------------------------
def make_shinigami_spirit():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#090D16"),  # Void Black Ink / Feathers
        "2": hex_to_argb("#1E293B"),  # Deep Navy Hair & Wing Shade
        "3": hex_to_argb("#94A3B8"),  # Ash Gray Spirit Skin
        "4": hex_to_argb("#E2E8F0"),  # Pale Ghost Highlight
        "5": hex_to_argb("#FACC15"),  # Glowing Yellow Sclera / Eyes
        "6": hex_to_argb("#EF4444"),  # Piercing Red Pupil / Apple
        "7": hex_to_argb("#B91C1C"),  # Dark Apple Crimson
        "8": hex_to_argb("#22C55E"),  # Apple Leaf Green
        "9": hex_to_argb("#FFFFFF"),  # Sharp White Teeth Grin & Highlights
        "10": hex_to_argb("#334155"), # Spiky Hair Highlight
    }

    # Spiky Wild Shinigami Hair
    hair_spikes = [
        (3, 11), (3, 15), (2, 16), (3, 20), (4, 10), (4, 21),
        (5, 8), (5, 9), (5, 22), (5, 23), (6, 7), (6, 24)
    ]
    for r, c in hair_spikes:
        g[r][c] = 1
    for r in range(4, 9):
        for c in range(10, 22):
            g[r][c] = 1
    g[6][13] = 2; g[6][14] = 2; g[6][17] = 2; g[6][18] = 2

    # Ash Gray Face
    for r in range(9, 19):
        for c in range(10, 22):
            g[r][c] = 3
    g[18][10] = 0; g[18][21] = 0
    g[19][12] = 3; g[19][13] = 3; g[19][18] = 3; g[19][19] = 3
    for c in range(14, 18):
        g[20][c] = 3

    # Glowing Yellow/Red Eyes
    for r in range(11, 14):
        for c in range(11, 15):
            g[r][c] = 5
    g[12][13] = 6; g[12][14] = 6

    for r in range(11, 14):
        for c in range(17, 21):
            g[r][c] = 5
    g[12][17] = 6; g[12][18] = 6

    for c in range(11, 15):
        g[10][c] = 1; g[14][c] = 1
    for c in range(17, 21):
        g[10][c] = 1; g[14][c] = 1

    g[15][15] = 1; g[15][16] = 1

    # Stitched Teeth Grin
    for c in range(11, 21):
        g[16][c] = 1
        g[17][c] = 9
        g[18][c] = 1
    g[17][12] = 1; g[17][14] = 1; g[17][16] = 1; g[17][18] = 1; g[17][20] = 1

    # Feathered Shoulders & Wing Silhouette
    for r in range(21, 31):
        for c in range(6, 26):
            if g[r][c] == 0:
                g[r][c] = 1
    for r in range(22, 28):
        g[r][8] = 2; g[r][23] = 2

    # Glossy Red Apple
    for r in range(24, 29):
        for c in range(13, 19):
            g[r][c] = 6
    g[24][13] = 0; g[24][18] = 0; g[28][13] = 0; g[28][18] = 0
    g[25][14] = 9
    g[27][16] = 7; g[27][17] = 7; g[28][15] = 7; g[28][16] = 7
    g[23][15] = 1
    g[23][16] = 8

    # Clawed hands
    g[26][11] = 3; g[26][12] = 3; g[27][12] = 3
    g[26][19] = 3; g[26][20] = 3; g[27][19] = 3

    return {
        "id": "shinigami_spirit",
        "name": "Shinigami Ryuk Spirit",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 5,
    }

# -------------------------------------------------------------
# 6. Armored Colossus Face (32x32)
# -------------------------------------------------------------
def make_colossus_titan():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#0F172A"),  # Deep Shading / Cavities
        "2": hex_to_argb("#DC2626"),  # Bright Red Muscle Tissue
        "3": hex_to_argb("#991B1B"),  # Deep Muscle Crimson
        "4": hex_to_argb("#7F1D1D"),  # Dark Striation Shadow
        "5": hex_to_argb("#F8FAFC"),  # Bone-White Face Armor / Steam
        "6": hex_to_argb("#CBD5E1"),  # Bone Plate Shading
        "7": hex_to_argb("#F59E0B"),  # Glowing Amber Hollow Eyes
        "8": hex_to_argb("#E2E8F0"),  # Boiling Steam Vapor
    }

    # Crown & Forehead muscle
    for r in range(4, 11):
        for c in range(10, 22):
            g[r][c] = 2 if (r + c) % 2 == 0 else 3
    for c in range(11, 21):
        g[6][c] = 5
        g[7][c] = 6

    # Cheek muscle striations
    for r in range(11, 20):
        for c in range(8, 24):
            if (c < 13 or c > 18):
                g[r][c] = 2 if r % 2 == 0 else 3
            else:
                g[r][c] = 3

    # White Bone Armor Cheek Plates
    for r in range(12, 17):
        g[r][9] = 5; g[r][10] = 5; g[r][21] = 5; g[r][22] = 5
    for r in range(12, 16):
        g[r][15] = 5; g[r][16] = 5

    # Glowing Hollow Amber Titan Eyes
    g[12][12] = 1; g[12][13] = 1; g[12][14] = 1
    g[12][17] = 1; g[12][18] = 1; g[12][19] = 1
    g[13][13] = 7; g[13][18] = 7

    # Teeth Jaw & Bone Mandible
    for c in range(11, 21):
        g[18][c] = 5
        g[19][c] = 1
        g[20][c] = 5
    for r in range(18, 23):
        g[r][8] = 5; g[r][9] = 6
        g[r][22] = 6; g[r][23] = 5

    # Chin & Neck Muscle
    for r in range(21, 27):
        for c in range(12, 20):
            g[r][c] = 2 if (r+c)%2 == 0 else 3
    for r in range(27, 31):
        for c in range(9, 23):
            g[r][c] = 3 if c % 3 == 0 else 4

    # Boiling Hot Steam Vapor
    steam_clouds = [
        (16, 5, 8), (17, 4, 8), (17, 5, 5), (18, 4, 8), (19, 5, 8),
        (16, 26, 8), (17, 26, 5), (17, 27, 8), (18, 27, 8), (19, 26, 8),
        (22, 6, 8), (23, 5, 8), (24, 6, 8),
        (22, 25, 8), (23, 26, 8), (24, 25, 8),
        (21, 10, 8), (21, 21, 8)
    ]
    for r, c, col in steam_clouds:
        g[r][c] = col

    return {
        "id": "colossus_titan",
        "name": "Armored Colossus Face",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 100,
        "sortOrder": 6,
    }

# -------------------------------------------------------------
# 7. Kawaii Taiyaki Cake (24x24)
# -------------------------------------------------------------
def make_taiyaki_cake():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#1E293B"),  # Ink Line details
        "2": hex_to_argb("#F59E0B"),  # Golden Toasted Waffle
        "3": hex_to_argb("#D97706"),  # Waffle Scale Shade
        "4": hex_to_argb("#B45309"),  # Crispy Dark Brown Edge
        "5": hex_to_argb("#881337"),  # Sweet Red Bean Adzuki Filling
        "6": hex_to_argb("#FB7185"),  # Cute Rosy Cheeks
        "7": hex_to_argb("#FFFFFF"),  # Sparkle White
        "8": hex_to_argb("#E0E7FF"),  # Sweet Warm Steam Puffs
    }

    # Fish Body
    for r in range(8, 17):
        for c in range(6, 17):
            g[r][c] = 2
    g[9][5] = 2; g[10][4] = 2; g[11][4] = 2; g[12][4] = 2; g[13][4] = 2; g[14][5] = 2
    g[10][5] = 2; g[11][5] = 2; g[12][5] = 2; g[13][5] = 2

    # Fins
    g[7][9] = 3; g[7][10] = 2; g[7][11] = 2; g[7][12] = 3
    g[17][9] = 3; g[17][10] = 2; g[17][11] = 2; g[17][12] = 3

    # Tail Fin
    for r in range(9, 16):
        g[r][17] = 2
    g[8][18] = 2; g[7][19] = 2; g[7][20] = 2; g[8][20] = 2; g[9][19] = 2; g[10][18] = 2
    g[16][18] = 2; g[17][19] = 2; g[17][20] = 2; g[16][20] = 2; g[15][19] = 2; g[14][18] = 2

    # Waffle Scale Pattern
    scale_pts = [
        (9, 12), (9, 15),
        (11, 11), (11, 14),
        (13, 12), (13, 15),
        (15, 11), (15, 14)
    ]
    for r, c in scale_pts:
        g[r][c] = 3

    # Red Bean Filling
    g[11][3] = 5; g[12][3] = 5; g[13][3] = 5
    g[12][2] = 5

    # Cute Face
    g[10][7] = 1; g[11][7] = 1
    g[10][8] = 1; g[11][8] = 1
    g[10][7] = 7
    g[12][7] = 6; g[12][8] = 6
    g[13][6] = 1; g[13][7] = 1

    # Steam puffs
    g[3][8] = 8; g[4][7] = 8; g[4][9] = 8; g[5][8] = 8
    g[2][14] = 8; g[3][13] = 8; g[3][15] = 8; g[4][14] = 8

    return {
        "id": "taiyaki_waffle",
        "name": "Kawaii Taiyaki Cake",
        "category": "Kawaii",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 7,
    }

# -------------------------------------------------------------
# 8. Eternal Mangekyo Eye (24x24)
# -------------------------------------------------------------
def make_mangekyo_eye():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    palette = {
        "1": hex_to_argb("#0A0A10"),  # Void Black Eyelashes & Tomoe Pinwheel
        "2": hex_to_argb("#EF4444"),  # Radiant Crimson Iris
        "3": hex_to_argb("#B91C1C"),  # Dark Crimson Iris Shadow
        "4": hex_to_argb("#7F1D1D"),  # Deep Outer Sclera Shadow
        "5": hex_to_argb("#F8FAFC"),  # White Sclera / Specular Highlight
        "6": hex_to_argb("#CBD5E1"),  # Sclera Shading
        "7": hex_to_argb("#6366F1"),  # Violet Occult Chakra Aura
        "8": hex_to_argb("#4338CA"),  # Deep Violet Aura Edge
    }

    # Eyelids and lashes
    for c in range(6, 18):
        g[6][c] = 1; g[7][c] = 1
    g[8][4] = 1; g[8][5] = 1; g[7][18] = 1; g[8][19] = 1; g[9][20] = 1
    for c in range(7, 17):
        g[17][c] = 1
    g[16][5] = 1; g[16][6] = 1; g[16][17] = 1; g[15][18] = 1

    # White Sclera
    for r in range(8, 17):
        for c in range(5, 19):
            g[r][c] = 5
    g[9][5] = 6; g[10][5] = 6; g[11][5] = 6
    g[9][18] = 6; g[10][18] = 6; g[11][18] = 6

    # Crimson Iris
    for r in range(8, 17):
        for c in range(7, 16):
            dr = r - 12
            dc = c - 11
            if dr*dr + dc*dc <= 24:
                g[r][c] = 2
            elif dr*dr + dc*dc <= 28:
                g[r][c] = 3

    # Void Black Triple Pinwheel Tomoe Sigil
    g[12][11] = 1
    g[11][11] = 1; g[10][11] = 1; g[9][12] = 1; g[9][13] = 1
    g[13][10] = 1; g[14][10] = 1; g[14][9] = 1; g[13][8] = 1
    g[13][12] = 1; g[14][13] = 1; g[15][13] = 1; g[15][14] = 1

    # Specular shine
    g[9][9] = 5; g[10][9] = 5

    # Violet Aura
    aura_pts = [
        (4, 11), (5, 12), (4, 15), (5, 16),
        (8, 21), (9, 22), (10, 22),
        (18, 6), (19, 7), (18, 16), (19, 15)
    ]
    for r, c in aura_pts:
        g[r][c] = 7

    return {
        "id": "eternal_mangekyo_eye",
        "name": "Eternal Mangekyo Eye",
        "category": "Eyes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 8,
    }

def main():
    artworks = [
        make_sailor_guardian(),
        make_flame_alchemist(),
        make_hanami_dango(),
        make_gundam_mecha(),
        make_shinigami_spirit(),
        make_colossus_titan(),
        make_taiyaki_cake(),
        make_mangekyo_eye(),
    ]

    print(f"Validating {len(artworks)} new anime artworks...")
    for a in artworks:
        rows = a["grid"].split(";")
        assert len(rows) == a["gridHeight"], f"{a['id']} row count mismatch"
        for r in rows:
            cols = r.split(",")
            assert len(cols) == a["gridWidth"], f"{a['id']} col count mismatch"
            for c in cols:
                if c != "0":
                    assert c in a["colorMap"], f"{a['id']} invalid color index {c}"
        print(f" [OK] {a['id']}: {a['name']} ({a['category']}, {a['gridWidth']}x{a['gridHeight']}, diff {a['difficulty']}, premium: {a['isPremium']})")

    if "--dry-run" in sys.argv:
        print("Dry run complete. No Firestore writes performed.")
        return

    import firebase_admin
    from firebase_admin import credentials, firestore

    print("\nConnecting to Firestore with service account...")
    cred = credentials.Certificate(SERVICE_KEY)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    batch = db.batch()
    now_ms = int(time.time() * 1000)

    for art in artworks:
        doc_id = f"rmt_{art['id']}_{now_ms}"
        doc_ref = (
            db.collection("pixel_art")
            .document("anime")
            .collection("artworks")
            .document(doc_id)
        )
        data = {
            "id": doc_id,
            "name": art["name"],
            "category": art["category"],
            "gridWidth": art["gridWidth"],
            "gridHeight": art["gridHeight"],
            "grid": art["grid"],
            "colorMap": art["colorMap"],
            "difficulty": art["difficulty"],
            "isPremium": art["isPremium"],
            "visible": True,
            "sortOrder": art["sortOrder"],
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if "diamondCost" in art and art["diamondCost"]:
            data["diamondCost"] = art["diamondCost"]

        batch.set(doc_ref, data)
        print(f"Queued doc: pixel_art/anime/artworks/{doc_id}")

    flavor_ref = db.collection("pixel_art").document("anime")
    batch.set(
        flavor_ref,
        {
            "catalogVersion": firestore.Increment(1),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    print("Committing batch to Firestore...")
    batch.commit()
    print("\nSuccessfully published all 8 new Anime Artworks to pixel_art/anime catalog!")

    updated = flavor_ref.get().to_dict()
    print("New anime catalogVersion:", updated.get("catalogVersion"))

if __name__ == "__main__":
    main()
