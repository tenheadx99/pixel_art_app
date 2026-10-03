#!/usr/bin/env python3
"""Generate Iconic Anime Archetypes pixel art and publish to Firestore.

This creates rich, hand-crafted pixel art grids for:
1. Thunder Volt Familiar (cute electric monster familiar)
2. Ember Drake (cute baby fire dragon)
3. Shadow Ghoul (mischievous purple ghost familiar)
4. Chibi Shinobi (ninja warrior with headband & scarf)
5. Magical Star Girl (anime heroine with star wand & twintails)
6. Demon Hunter (swordsman in checkered haori with katana)
7. Super Aura Warrior (spiky golden hair warrior with energy aura)
8. Cyber Battle Mecha (futuristic Japanese robot helm with glowing visor)

Publishes to `pixel_art/anime/artworks/rmt_<id>_<timestamp>` in Firestore
and bumps `pixel_art/anime.catalogVersion`.
"""

import time
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_KEY = "/home/rameshx99/Downloads/om108-5c015-firebase-adminsdk-fbsvc-d17fdb4254.json"

def argb(a, r, g, b):
    """Return signed 32-bit ARGB int as used by Flutter Color.toARGB32()."""
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
# 1. Thunder Volt Familiar (24x24)
# -------------------------------------------------------------
def make_thunder_kit():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    # Palette:
    # 1: #1E1E24 (Outline dark)
    # 2: #FFD214 (Bright Electric Yellow)
    # 3: #F3B300 (Deep Yellow shade)
    # 4: #FF3B30 (Rosy Cheek Red)
    # 5: #FFFFFF (Eye highlight White)
    # 6: #4A3B32 (Dark Ear Tip / Stripe Brown)
    # 7: #FF8A00 (Tail highlight Orange)
    
    palette = {
        "1": hex_to_argb("#1E1E24"),
        "2": hex_to_argb("#FFD214"),
        "3": hex_to_argb("#F3B300"),
        "4": hex_to_argb("#FF3B30"),
        "5": hex_to_argb("#FFFFFF"),
        "6": hex_to_argb("#4A3B32"),
        "7": hex_to_argb("#FF8A00"),
    }
    
    # Left Ear (tipped with dark brown)
    g[1][3] = 6; g[1][4] = 6
    g[2][4] = 6; g[2][5] = 6
    g[3][5] = 2; g[3][6] = 2
    g[4][6] = 2; g[4][7] = 2
    g[5][6] = 2; g[5][7] = 2
    
    # Right Ear
    g[1][19] = 6; g[1][20] = 6
    g[2][18] = 6; g[2][19] = 6
    g[3][17] = 2; g[3][18] = 2
    g[4][16] = 2; g[4][17] = 2
    g[5][16] = 2; g[5][17] = 2
    
    # Head outline & fill (rows 6 to 14)
    for r in range(6, 15):
        for c in range(6, 18):
            g[r][c] = 2
            
    # Head shading (bottom/sides)
    for c in range(7, 17):
        g[14][c] = 3
    for r in range(8, 14):
        g[r][6] = 3
        g[r][17] = 3

    # Eyes (rows 9-10)
    g[9][8] = 1;  g[9][9] = 5;  g[10][8] = 1;  g[10][9] = 1
    g[9][14] = 5; g[9][15] = 1; g[10][14] = 1; g[10][15] = 1
    
    # Nose & cute mouth
    g[11][11] = 1; g[11][12] = 1
    g[12][10] = 1; g[12][13] = 1
    
    # Red Cheeks
    g[11][6] = 4; g[11][7] = 4; g[12][6] = 4; g[12][7] = 4
    g[11][16] = 4; g[11][17] = 4; g[12][16] = 4; g[12][17] = 4
    
    # Body (rows 15 to 21)
    for r in range(15, 21):
        for c in range(7, 17):
            g[r][c] = 2
    # Body shade
    for c in range(8, 16):
        g[20][c] = 3
    g[18][7] = 3; g[19][7] = 3; g[18][16] = 3; g[19][16] = 3
    
    # Back stripes (rows 16-17)
    g[16][10] = 6; g[16][11] = 6; g[16][12] = 6; g[16][13] = 6
    g[18][10] = 6; g[18][11] = 6; g[18][12] = 6; g[18][13] = 6
    
    # Paws
    g[16][8] = 3; g[16][15] = 3
    g[21][7] = 3; g[21][8] = 3; g[21][15] = 3; g[21][16] = 3
    
    # Lightning Tail (Z-shape)
    g[19][17] = 6; g[19][18] = 6
    g[18][18] = 2; g[18][19] = 2
    g[17][19] = 2; g[17][20] = 7
    g[16][20] = 2; g[16][21] = 7
    g[15][21] = 7; g[15][22] = 7
    g[14][22] = 7; g[14][23] = 7

    return {
        "id": "thunder_kit",
        "name": "Thunder Volt Familiar",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 1,
    }

# -------------------------------------------------------------
# 2. Ember Drake (24x24)
# -------------------------------------------------------------
def make_ember_drake():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    # 1: #1B1B1E (Dark Outline)
    # 2: #FF6B35 (Ember Orange Body)
    # 3: #D94814 (Shadow Rust Orange)
    # 4: #FFE699 (Cream Belly)
    # 5: #00D2D3 (Cyan Eyes)
    # 6: #FFFFFF (White Highlight)
    # 7: #FF2E00 (Flame Red)
    # 8: #FFD000 (Flame Yellow Core)
    palette = {
        "1": hex_to_argb("#1B1B1E"),
        "2": hex_to_argb("#FF6B35"),
        "3": hex_to_argb("#D94814"),
        "4": hex_to_argb("#FFE699"),
        "5": hex_to_argb("#00D2D3"),
        "6": hex_to_argb("#FFFFFF"),
        "7": hex_to_argb("#FF2E00"),
        "8": hex_to_argb("#FFD000"),
    }
    
    # Head & Snout (rows 5 to 13)
    for r in range(5, 14):
        for c in range(6, 17):
            g[r][c] = 2
    # Horn bumps on head
    g[4][7] = 3; g[4][8] = 2; g[4][14] = 2; g[4][15] = 3
    
    # Big Cute Cyan Anime Eye (rows 8-10)
    g[8][12] = 6; g[8][13] = 5; g[8][14] = 5
    g[9][12] = 5; g[9][13] = 5; g[9][14] = 1
    g[10][13] = 1; g[10][14] = 1
    # Cute smile
    g[11][15] = 1; g[12][14] = 1
    
    # Neck & Body (rows 14 to 20)
    for r in range(14, 21):
        for c in range(7, 16):
            g[r][c] = 2
            
    # Cream Belly
    for r in range(14, 20):
        g[r][12] = 4; g[r][13] = 4; g[r][14] = 4
        
    # Feet
    g[21][8] = 3; g[21][9] = 3; g[21][13] = 3; g[21][14] = 3
    
    # Tail curving out to right
    g[19][6] = 2; g[19][5] = 2
    g[18][4] = 2; g[18][3] = 3
    g[17][3] = 2; g[16][3] = 2
    
    # Flame on tail tip (Red & Yellow fire)
    g[15][2] = 7; g[15][3] = 8; g[15][4] = 7
    g[14][1] = 7; g[14][2] = 8; g[14][3] = 8; g[14][4] = 7
    g[13][2] = 7; g[13][3] = 8; g[13][4] = 7
    g[12][3] = 7; g[11][3] = 7

    return {
        "id": "ember_drake",
        "name": "Ember Drake",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 2,
    }

# -------------------------------------------------------------
# 3. Shadow Ghoul (24x24)
# -------------------------------------------------------------
def make_shadow_ghoul():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    # 1: #120A2A (Midnight Dark Outline)
    # 2: #5F27CD (Shadow Purple Body)
    # 3: #341F97 (Deep Indigo Shade)
    # 4: #FF3838 (Glowing Crimson Eyes)
    # 5: #FFFFFF (White Grin)
    # 6: #9B59B6 (Lavender Edge Highlight)
    palette = {
        "1": hex_to_argb("#120A2A"),
        "2": hex_to_argb("#5F27CD"),
        "3": hex_to_argb("#341F97"),
        "4": hex_to_argb("#FF3838"),
        "5": hex_to_argb("#FFFFFF"),
        "6": hex_to_argb("#9B59B6"),
    }
    
    # Spiky Ears/Horns
    g[3][5] = 2; g[3][6] = 2; g[4][6] = 2; g[4][7] = 2
    g[3][17] = 2; g[3][18] = 2; g[4][16] = 2; g[4][17] = 2
    
    # Head & Spikes
    for r in range(5, 19):
        for c in range(5, 19):
            g[r][c] = 2
            
    # Shadow shading on bottom
    for c in range(6, 18):
        g[18][c] = 3
        g[17][c] = 3
    for r in range(8, 18):
        g[r][5] = 3; g[r][18] = 3
        
    # Top highlight
    for c in range(8, 16):
        g[5][c] = 6
        
    # Wicked Red Eyes
    g[9][7] = 4; g[9][8] = 4; g[10][7] = 4; g[10][8] = 4
    g[9][15] = 4; g[9][16] = 4; g[10][15] = 4; g[10][16] = 4
    
    # Huge Jagged White Grin
    g[13][6] = 5; g[13][17] = 5
    for c in range(7, 17):
        g[14][c] = 5
        g[15][c] = 5
    # Teeth separation
    g[14][8] = 1; g[14][11] = 1; g[14][14] = 1
    g[15][9] = 1; g[15][12] = 1; g[15][15] = 1
    
    # Ghostly trail feet (wisps)
    g[19][6] = 3; g[20][6] = 3
    g[19][11] = 3; g[20][11] = 3; g[21][11] = 3
    g[19][17] = 3; g[20][17] = 3

    return {
        "id": "shadow_ghoul",
        "name": "Shadow Ghoul",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 3,
    }

# -------------------------------------------------------------
# 4. Chibi Shinobi (32x32)
# -------------------------------------------------------------
def make_chibi_shinobi():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #1A1A24 (Dark Outline)
    # 2: #FFA500 (Vibrant Orange Spiky Hair)
    # 3: #D97706 (Amber Hair Shade)
    # 4: #FFDFBA (Warm Anime Skin)
    # 5: #2563EB (Sapphire Blue Headband & Eyes)
    # 6: #94A3B8 (Silver Metal Plate)
    # 7: #FFFFFF (White Plate Highlight / Eye Spec)
    # 8: #EF4444 (Crimson Ninja Scarf)
    # 9: #1E293B (Navy Dark Shinobi Gi)
    palette = {
        "1": hex_to_argb("#1A1A24"),
        "2": hex_to_argb("#FFA500"),
        "3": hex_to_argb("#D97706"),
        "4": hex_to_argb("#FFDFBA"),
        "5": hex_to_argb("#2563EB"),
        "6": hex_to_argb("#94A3B8"),
        "7": hex_to_argb("#FFFFFF"),
        "8": hex_to_argb("#EF4444"),
        "9": hex_to_argb("#1E293B"),
    }
    
    # Spiky Orange Hair at top (rows 2 to 9)
    for c in range(10, 22):
        g[4][c] = 2; g[5][c] = 2; g[6][c] = 2
    # Spikes
    g[2][12] = 2; g[3][11] = 2; g[3][12] = 2; g[3][13] = 2
    g[1][16] = 2; g[2][15] = 2; g[2][16] = 2; g[3][16] = 2
    g[2][20] = 2; g[3][19] = 2; g[3][20] = 2
    g[4][8] = 2; g[5][9] = 2; g[4][23] = 2; g[5][22] = 2
    
    # Blue Headband (rows 7 to 10)
    for r in range(7, 11):
        for c in range(8, 24):
            g[r][c] = 5
    # Metal Forehead Plate (rows 8-9, cols 12-19)
    for r in range(8, 10):
        for c in range(12, 20):
            g[r][c] = 6
    g[8][13] = 7; g[8][14] = 7 # Reflection shine
    
    # Face (rows 11 to 18, cols 9 to 23)
    for r in range(11, 19):
        for c in range(9, 23):
            g[r][c] = 4
    # Hair bangs framing face
    g[11][9] = 2; g[12][9] = 2; g[11][22] = 2; g[12][22] = 2
    g[11][15] = 2; g[11][16] = 2
    
    # Expressive Blue Eyes (rows 13-14)
    g[13][11] = 7; g[13][12] = 5; g[14][11] = 5; g[14][12] = 1
    g[13][19] = 7; g[13][20] = 5; g[14][19] = 5; g[14][20] = 1
    
    # Whisker face markings & nose
    g[15][15] = 3; g[15][16] = 3
    g[15][10] = 3; g[16][10] = 3; g[15][21] = 3; g[16][21] = 3
    # Determined mouth
    g[17][14] = 1; g[17][15] = 1; g[17][16] = 1; g[17][17] = 1
    
    # Red Ninja Scarf (rows 19 to 21)
    for r in range(19, 22):
        for c in range(10, 22):
            g[r][c] = 8
    # Scarf tail blowing left
    g[20][6] = 8; g[20][7] = 8; g[20][8] = 8; g[20][9] = 8
    g[21][5] = 8; g[21][6] = 8; g[21][7] = 8
    
    # Navy Shinobi Body (rows 22 to 28)
    for r in range(22, 29):
        for c in range(11, 21):
            g[r][c] = 9
    # Orange belt / trim
    for c in range(12, 20):
        g[25][c] = 2
    
    # Legs (rows 29 to 31)
    g[29][12] = 9; g[29][13] = 9; g[30][12] = 6; g[30][13] = 6; g[31][12] = 1; g[31][13] = 1
    g[29][18] = 9; g[29][19] = 9; g[30][18] = 6; g[30][19] = 6; g[31][18] = 1; g[31][19] = 1

    return {
        "id": "chibi_shinobi",
        "name": "Chibi Shinobi",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 4,
    }

# -------------------------------------------------------------
# 5. Magical Star Girl (32x32)
# -------------------------------------------------------------
def make_magical_stargirl():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #2B1055 (Outline Violet)
    # 2: #FF70A6 (Cotton Candy Pink Twintails)
    # 3: #E03F78 (Deep Magenta Shade)
    # 4: #FFE3D8 (Soft Anime Peach Skin)
    # 5: #845EC2 (Mystic Purple Eyes)
    # 6: #FFFFFF (Pure White Sailor Dress)
    # 7: #FFD166 (Golden Star Wand & Brooch)
    # 8: #06D6A0 (Emerald Gem Accent)
    # 9: #FF3366 (Red Bow Ribbon)
    palette = {
        "1": hex_to_argb("#2B1055"),
        "2": hex_to_argb("#FF70A6"),
        "3": hex_to_argb("#E03F78"),
        "4": hex_to_argb("#FFE3D8"),
        "5": hex_to_argb("#845EC2"),
        "6": hex_to_argb("#FFFFFF"),
        "7": hex_to_argb("#FFD166"),
        "8": hex_to_argb("#06D6A0"),
        "9": hex_to_argb("#FF3366"),
    }
    
    # Golden Tiara with Star
    g[4][15] = 7; g[4][16] = 7
    g[5][14] = 7; g[5][15] = 8; g[5][16] = 8; g[5][17] = 7
    
    # Pink Twintails (Left bun & tail)
    for r in range(5, 10):
        for c in range(6, 11):
            g[r][c] = 2
    for r in range(10, 24):
        g[r][5] = 2; g[r][6] = 2; g[r][7] = 3
        
    # Right Twintail
    for r in range(5, 10):
        for c in range(21, 26):
            g[r][c] = 2
    for r in range(10, 24):
        g[r][25] = 3; g[r][26] = 2; g[r][27] = 2
        
    # Hair Top & Bangs (rows 5 to 11)
    for r in range(6, 11):
        for c in range(11, 21):
            g[r][c] = 2
    g[11][12] = 2; g[11][15] = 2; g[11][16] = 2; g[11][19] = 2
    
    # Face (rows 10 to 18, cols 11 to 21)
    for r in range(11, 18):
        for c in range(11, 21):
            g[r][c] = 4
            
    # Sparkling Big Anime Eyes
    g[13][12] = 6; g[13][13] = 5; g[14][12] = 5; g[14][13] = 1
    g[13][18] = 6; g[13][19] = 5; g[14][18] = 5; g[14][19] = 1
    # Blush
    g[15][11] = 9; g[15][20] = 9
    # Smile
    g[16][15] = 9; g[16][16] = 9
    
    # Sailor Collar & Big Red Bow (rows 18-20)
    for c in range(13, 19):
        g[18][c] = 6
    g[19][14] = 9; g[19][15] = 7; g[19][16] = 7; g[19][17] = 9
    g[20][13] = 9; g[20][15] = 9; g[20][16] = 9; g[20][18] = 9
    
    # White Magical Dress (rows 21 to 27)
    for r in range(21, 28):
        for c in range(12, 20):
            g[r][c] = 6
    # Gold trim at hem
    for c in range(11, 21):
        g[27][c] = 7
        
    # Legs (rows 28 to 31)
    g[28][14] = 4; g[29][14] = 4; g[30][14] = 9; g[31][14] = 9
    g[28][17] = 4; g[29][17] = 4; g[30][17] = 9; g[31][17] = 9
    
    # Star Wand held on right hand
    for r in range(16, 26):
        g[r][23] = 7 # Wand staff
    # Star top
    g[13][23] = 7
    g[14][22] = 7; g[14][23] = 8; g[14][24] = 7
    g[15][21] = 7; g[15][22] = 7; g[15][23] = 7; g[15][24] = 7; g[15][25] = 7
    g[16][22] = 7; g[16][24] = 7

    return {
        "id": "magical_stargirl",
        "name": "Magical Star Girl",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 5,
    }

# -------------------------------------------------------------
# 6. Demon Hunter Samurai (32x32)
# -------------------------------------------------------------
def make_demon_hunter():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #111827 (Night Black)
    # 2: #059669 (Checkered Jade Green)
    # 3: #7C2D12 (Burgundy Spiky Hair)
    # 4: #FFDFBA (Anime Skin)
    # 5: #991B1B (Crimson Earrings / Scars / Eyes)
    # 6: #E2E8F0 (Silver Katana Blade)
    # 7: #D97706 (Gold Hilt Guard)
    # 8: #FFFFFF (White Haori Trim & Collar)
    palette = {
        "1": hex_to_argb("#111827"),
        "2": hex_to_argb("#059669"),
        "3": hex_to_argb("#7C2D12"),
        "4": hex_to_argb("#FFDFBA"),
        "5": hex_to_argb("#991B1B"),
        "6": hex_to_argb("#E2E8F0"),
        "7": hex_to_argb("#D97706"),
        "8": hex_to_argb("#FFFFFF"),
    }
    
    # Dark Burgundy Spiky Hair (rows 2 to 10)
    for r in range(4, 9):
        for c in range(10, 22):
            g[r][c] = 3
    # Spikes
    g[2][13] = 3; g[3][12] = 3; g[3][13] = 3
    g[1][17] = 3; g[2][16] = 3; g[2][17] = 3; g[3][17] = 3
    g[2][21] = 3; g[3][20] = 3; g[3][21] = 3
    
    # Face (rows 9 to 16, cols 11 to 21)
    for r in range(9, 17):
        for c in range(11, 21):
            g[r][c] = 4
    # Forehead Scar mark
    g[9][13] = 5; g[10][13] = 5; g[10][14] = 5; g[11][14] = 5
    
    # Eyes (Deep Crimson)
    g[12][13] = 5; g[12][14] = 1; g[13][13] = 5; g[13][14] = 1
    g[12][18] = 1; g[12][19] = 5; g[13][18] = 1; g[13][19] = 5
    
    # Hanafuda Style Earring on Left
    g[13][9] = 8; g[14][9] = 5; g[15][9] = 8
    
    # White Collar
    g[17][15] = 8; g[17][16] = 8
    
    # Checkered Haori Pattern (Green & Black alternate blocks!)
    for r in range(18, 28):
        for c in range(8, 24):
            # 2x2 grid checker
            is_green = ((r // 2) + (c // 2)) % 2 == 0
            g[r][c] = 2 if is_green else 1
            
    # Katana held diagonally on right
    for i in range(12):
        r = 17 + i
        c = 22 + (i // 2)
        if r < 32 and c < 32:
            g[r][c] = 6 # Blade
    # Katana guard (Gold)
    g[24][24] = 7; g[24][25] = 7; g[25][24] = 7
    # Katana hilt (Black/Red wrap)
    g[26][25] = 1; g[27][26] = 5; g[28][26] = 1
    
    # Legs (rows 28 to 31)
    g[28][13] = 1; g[29][13] = 8; g[30][13] = 8; g[31][13] = 7
    g[28][18] = 1; g[29][18] = 8; g[30][18] = 8; g[31][18] = 7

    return {
        "id": "demon_hunter",
        "name": "Demon Hunter Samurai",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 150,
        "sortOrder": 6,
    }

# -------------------------------------------------------------
# 7. Super Aura Warrior (32x32)
# -------------------------------------------------------------
def make_aura_warrior():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #1E293B (Dark Outline / Shadows)
    # 2: #FACC15 (Blazing Golden Super Saiyan Hair)
    # 3: #EAB308 (Amber Hair Shading)
    # 4: #FFDFBA (Warrior Skin)
    # 5: #06B6D4 (Cyan Piercing Eyes & Crackling Lightning)
    # 6: #EA580C (Orange Martial Arts Gi)
    # 7: #1D4ED8 (Deep Blue Undershirt & Wristbands)
    # 8: #38BDF8 (Aura Blast Light Cyan)
    palette = {
        "1": hex_to_argb("#1E293B"),
        "2": hex_to_argb("#FACC15"),
        "3": hex_to_argb("#EAB308"),
        "4": hex_to_argb("#FFDFBA"),
        "5": hex_to_argb("#06B6D4"),
        "6": hex_to_argb("#EA580C"),
        "7": hex_to_argb("#1D4ED8"),
        "8": hex_to_argb("#38BDF8"),
    }
    
    # Cyan Energy Aura Flares surrounding silhouette
    aura_coords = [
        (4,6), (3,7), (7,4), (12,3), (18,4), (24,5),
        (4,25), (3,24), (7,27), (12,28), (18,27), (24,26),
        (28,8), (29,9), (28,23), (29,22)
    ]
    for r, c in aura_coords:
        g[r][c] = 8
        
    # Giant Spiky Golden Hair (rows 2 to 12)
    for r in range(5, 11):
        for c in range(9, 23):
            g[r][c] = 2
    # Massive vertical spikes
    g[1][15] = 2; g[1][16] = 2
    g[2][14] = 2; g[2][15] = 2; g[2][16] = 2; g[2][17] = 2
    g[3][13] = 2; g[3][14] = 3; g[3][17] = 3; g[3][18] = 2
    # Left & Right diagonal massive spikes
    g[2][10] = 2; g[3][9] = 2; g[4][8] = 2; g[5][8] = 3
    g[2][21] = 2; g[3][22] = 2; g[4][23] = 2; g[5][23] = 3
    
    # Face (rows 11 to 18, cols 11 to 21)
    for r in range(11, 18):
        for c in range(11, 21):
            g[r][c] = 4
    # Bangs over forehead
    g[11][13] = 2; g[12][13] = 2; g[11][18] = 2; g[12][18] = 2
    
    # Fierce Cyan Eyes with black brow
    g[13][12] = 1; g[13][13] = 1; g[14][12] = 5; g[14][13] = 5
    g[13][18] = 1; g[13][19] = 1; g[14][18] = 5; g[14][19] = 5
    # Gritting teeth
    g[16][14] = 1; g[16][15] = 1; g[16][16] = 1; g[16][17] = 1
    
    # Blue Undershirt (rows 18 to 20)
    for r in range(18, 21):
        for c in range(14, 18):
            g[r][c] = 7
            
    # Orange Martial Gi (rows 19 to 27)
    for r in range(19, 28):
        for c in range(10, 22):
            if g[r][c] == 0:
                g[r][c] = 6
    # Blue Belt sash
    for c in range(12, 20):
        g[25][c] = 7
        
    # Blue Wristbands on clenched fists
    g[23][8] = 7; g[24][8] = 7; g[23][23] = 7; g[24][23] = 7
    g[25][8] = 4; g[25][23] = 4 # Hands
    
    # Boots (rows 28 to 31)
    for r in range(28, 32):
        g[r][12] = 7; g[r][13] = 7; g[r][18] = 7; g[r][19] = 7
    g[30][12] = 6; g[30][19] = 6 # Boot laces

    return {
        "id": "aura_warrior",
        "name": "Super Aura Warrior",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 150,
        "sortOrder": 7,
    }

# -------------------------------------------------------------
# 8. Cyber Battle Mecha (32x32)
# -------------------------------------------------------------
def make_cyber_mecha():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #0F172A (Carbon Dark Outline)
    # 2: #F8FAFC (Pure Armor White)
    # 3: #94A3B8 (Chassis Steel Gray)
    # 4: #2563EB (Gundam Navy Blue)
    # 5: #EF4444 (Crimson Optic Visor / Sensor)
    # 6: #FACC15 (Golden V-Fin Crest)
    # 7: #38BDF8 (Cyan Thruster Exhaust / Glow)
    palette = {
        "1": hex_to_argb("#0F172A"),
        "2": hex_to_argb("#F8FAFC"),
        "3": hex_to_argb("#94A3B8"),
        "4": hex_to_argb("#2563EB"),
        "5": hex_to_argb("#EF4444"),
        "6": hex_to_argb("#FACC15"),
        "7": hex_to_argb("#38BDF8"),
    }
    
    # Golden V-Fin Antenna Crest (rows 2 to 8)
    g[2][6] = 6; g[3][7] = 6; g[4][8] = 6; g[5][9] = 6; g[6][10] = 6
    g[2][25] = 6; g[3][24] = 6; g[4][23] = 6; g[5][22] = 6; g[6][21] = 6
    # Center jewel
    g[6][15] = 5; g[6][16] = 5
    g[7][15] = 6; g[7][16] = 6
    
    # Head Helmet (rows 7 to 17)
    for r in range(7, 18):
        for c in range(11, 21):
            g[r][c] = 2
            
    # Blue Helmet Crown
    for c in range(13, 19):
        g[7][c] = 4; g[8][c] = 4
        
    # Glowing Crimson Optic Visor (rows 12-13)
    for c in range(12, 20):
        g[12][c] = 5; g[13][c] = 5
    g[12][14] = 7; g[12][17] = 7 # Visor lens flare
    
    # Face Plate & Vents (rows 14-16)
    g[14][15] = 3; g[14][16] = 3
    g[15][14] = 1; g[15][15] = 3; g[15][16] = 3; g[15][17] = 1
    # Red Chin piece
    g[17][15] = 5; g[17][16] = 5
    
    # Mecha Torso & Shoulders (rows 18 to 29)
    # Blue Chest Plates
    for r in range(18, 25):
        for c in range(10, 22):
            g[r][c] = 4
    # Center Cockpit Hatch (Red)
    g[20][15] = 5; g[20][16] = 5
    g[21][15] = 5; g[21][16] = 5
    g[22][15] = 5; g[22][16] = 5
    
    # White Shoulder Pauldrons
    for r in range(18, 26):
        for c in range(5, 10):
            g[r][c] = 2
        for c in range(22, 27):
            g[r][c] = 2
    # Yellow intake vents on shoulders
    g[20][7] = 6; g[20][8] = 6
    g[20][23] = 6; g[20][24] = 6
    
    # Waist / Skirt Armor (rows 25 to 30)
    for r in range(25, 30):
        for c in range(11, 21):
            g[r][c] = 2
    g[26][15] = 6; g[26][16] = 6 # Gold buckle
    
    # Thruster Glow underneath
    g[30][13] = 7; g[30][14] = 7; g[30][17] = 7; g[30][18] = 7
    g[31][13] = 7; g[31][18] = 7

    return {
        "id": "cyber_mecha",
        "name": "Cyber Battle Mecha",
        "category": "Mecha",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": True,
        "diamondCost": 120,
        "sortOrder": 8,
    }

def main():
    print("Generating 8 Iconic Anime Archetypes...")
    artworks = [
        make_thunder_kit(),
        make_ember_drake(),
        make_shadow_ghoul(),
        make_chibi_shinobi(),
        make_magical_stargirl(),
        make_demon_hunter(),
        make_aura_warrior(),
        make_cyber_mecha(),
    ]
    
    print(f"Generated {len(artworks)} artworks.")
    for a in artworks:
        rows = a["grid"].split(";")
        assert len(rows) == a["gridHeight"], f"{a['id']} row count mismatch"
        for r in rows:
            assert len(r.split(",")) == a["gridWidth"], f"{a['id']} col count mismatch"
        print(f" - {a['id']}: {a['name']} ({a['category']}, {a['gridWidth']}x{a['gridHeight']}, diff {a['difficulty']}, premium: {a['isPremium']})")
        
    print("\nConnecting to Firestore via service account...")
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
        
    # Bump catalogVersion on pixel_art/anime root doc
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
    print("Successfully published all 8 Iconic Anime Archetypes to pixel_art/anime!")
    
    # Verify new version
    updated_flavor = flavor_ref.get().to_dict()
    print("New anime catalogVersion:", updated_flavor.get("catalogVersion"))

if __name__ == "__main__":
    main()
