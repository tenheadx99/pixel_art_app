#!/usr/bin/env python3
"""Generate 8 additional eye-catching Anime Pixel Artworks and publish to Firestore.

Artworks:
1. Mystic Kitsune (Nine-Tailed Fox spirit with cyan spirit flame) - Monsters (32x32)
2. Kawaii Neko Maid (Cute catgirl with maid frills & paw pose) - Chibi (32x32)
3. Deluxe Steaming Ramen (Iconic ramen bowl with naruto fishcake & egg) - Kawaii (32x32)
4. Aqua Splash Turtle (Cute water starter monster familiar) - Monsters (24x24)
5. Sakura Kimono Princess (Anime beauty with floral kimono & hairpin) - Heroes (32x32)
6. Cyberpunk Neon Runner (Futuristic hero with neon jacket & cyber eye) - Heroes (32x32)
7. Kawaii Cat Boba Tea (Bubble milk tea with cat ear lid & pearls) - Kawaii (24x24)
8. Crimson Mystic Eye (Iconic glowing crimson eye with tomoe runes) - Eyes (24x24)
"""

import time
import firebase_admin
from firebase_admin import credentials, firestore

SERVICE_KEY = "/home/rameshx99/Downloads/om108-5c015-firebase-adminsdk-fbsvc-d17fdb4254.json"

def argb(a, r, g, b):
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
# 1. Mystic Kitsune (32x32)
# -------------------------------------------------------------
def make_mystic_kitsune():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #1A1423 (Dark Ink Outline)
    # 2: #FFFFFF (Pure White Fur)
    # 3: #E2E8F0 (Soft Shading White/Silver)
    # 4: #FF2A55 (Crimson Red Markings & Ears)
    # 5: #F59E0B (Golden Amber Eyes)
    # 6: #00F0FF (Cyan Spirit Fire / Kitsunebi)
    # 7: #38BDF8 (Lighter Spirit Flame Glow)
    palette = {
        "1": hex_to_argb("#1A1423"),
        "2": hex_to_argb("#FFFFFF"),
        "3": hex_to_argb("#E2E8F0"),
        "4": hex_to_argb("#FF2A55"),
        "5": hex_to_argb("#F59E0B"),
        "6": hex_to_argb("#00F0FF"),
        "7": hex_to_argb("#38BDF8"),
    }
    
    # Ears (Tall, Fox-like, Crimson inside)
    # Left Ear
    g[3][10] = 4; g[4][9] = 4; g[4][10] = 4
    g[5][9] = 2; g[5][10] = 4; g[6][8] = 2; g[6][9] = 4; g[6][10] = 2
    g[7][8] = 2; g[7][9] = 2; g[7][10] = 2
    # Right Ear
    g[3][21] = 4; g[4][21] = 4; g[4][22] = 4
    g[5][21] = 4; g[5][22] = 2; g[6][21] = 2; g[6][22] = 4; g[6][23] = 2
    g[7][21] = 2; g[7][22] = 2; g[7][23] = 2
    
    # Head & Snout (rows 8 to 17)
    for r in range(8, 15):
        for c in range(10, 22):
            g[r][c] = 2
            
    # Cheeks & Whiskers
    g[12][7] = 2; g[12][8] = 2; g[12][9] = 2; g[13][8] = 2; g[13][9] = 2
    g[12][22] = 2; g[12][23] = 2; g[12][24] = 2; g[13][22] = 2; g[13][23] = 2
    
    # Crimson Cheek Markings (Anime kitsune makeup)
    g[12][10] = 4; g[12][11] = 4; g[13][11] = 4
    g[12][20] = 4; g[12][21] = 4; g[13][20] = 4
    
    # Forehead Crimson Torii / Jewel Sigil
    g[9][15] = 4; g[9][16] = 4; g[10][15] = 4; g[10][16] = 4
    g[8][14] = 4; g[8][17] = 4
    
    # Slanted Golden Eyes
    g[11][12] = 5; g[11][13] = 1; g[12][13] = 5
    g[11][18] = 1; g[11][19] = 5; g[12][18] = 5
    
    # Snout & Nose
    for r in range(15, 18):
        for c in range(14, 18):
            g[r][c] = 2
    g[17][15] = 1; g[17][16] = 1 # Nose tip
    
    # Body & Front Paws (rows 18 to 27)
    for r in range(18, 27):
        for c in range(12, 20):
            g[r][c] = 2
    # Shadow underneath
    for c in range(13, 19):
        g[26][c] = 3
    # Paws
    g[27][13] = 3; g[27][14] = 3; g[27][17] = 3; g[27][18] = 3
    
    # Multiple Fluffy Tails Spreading Left and Right!
    # Left Tail
    for r in range(17, 26):
        g[r][7] = 2; g[r][8] = 2; g[r][9] = 3
    g[16][6] = 2; g[15][5] = 2; g[14][4] = 4; g[13][4] = 4 # Red tail tip
    # Far Left Tail
    g[20][4] = 2; g[21][4] = 2; g[22][5] = 2
    
    # Right Tail
    for r in range(17, 26):
        g[r][22] = 3; g[r][23] = 2; g[r][24] = 2
    g[16][25] = 2; g[15][26] = 2; g[14][27] = 4; g[13][27] = 4 # Red tail tip
    # Far Right Tail
    g[20][27] = 2; g[21][27] = 2; g[22][26] = 2
    
    # Floating Cyan Spirit Fire (Kitsunebi)
    g[9][4] = 6; g[8][4] = 7; g[9][3] = 7; g[10][4] = 6
    g[9][27] = 6; g[8][27] = 7; g[9][28] = 7; g[10][27] = 6
    g[24][2] = 6; g[23][2] = 7; g[24][29] = 6; g[23][29] = 7

    return {
        "id": "mystic_kitsune",
        "name": "Mystic Kitsune",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 150,
        "sortOrder": 9,
    }

# -------------------------------------------------------------
# 2. Kawaii Neko Maid (32x32)
# -------------------------------------------------------------
def make_neko_maid():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #1E1B2E (Ink Outline)
    # 2: #5B487A (Plum Brown Hair)
    # 3: #FFE0D3 (Chibi Anime Skin)
    # 4: #10B981 (Sparkling Emerald Eyes)
    # 5: #FFFFFF (White Frill Headband / Apron)
    # 6: #FF4D80 (Pink Inner Ears & Ribbon Bow)
    # 7: #262135 (Black Maid Dress)
    # 8: #FFB3C6 (Rosy Cheeks)
    palette = {
        "1": hex_to_argb("#1E1B2E"),
        "2": hex_to_argb("#5B487A"),
        "3": hex_to_argb("#FFE0D3"),
        "4": hex_to_argb("#10B981"),
        "5": hex_to_argb("#FFFFFF"),
        "6": hex_to_argb("#FF4D80"),
        "7": hex_to_argb("#262135"),
        "8": hex_to_argb("#FFB3C6"),
    }
    
    # Cat Ears with Pink Inner Fluff
    g[4][7] = 2; g[4][8] = 2; g[5][6] = 2; g[5][7] = 6; g[5][8] = 6; g[6][6] = 2; g[6][7] = 6; g[7][6] = 2
    g[4][23] = 2; g[4][24] = 2; g[5][23] = 6; g[5][24] = 6; g[5][25] = 2; g[6][24] = 6; g[6][25] = 2; g[7][25] = 2
    
    # White Maid Lace Headband (rows 6 to 8)
    for c in range(9, 23):
        g[6][c] = 5
        g[7][c] = 5
    g[6][8] = 6; g[6][23] = 6 # Pink side ribbon bows
    
    # Hair Top & Bangs (rows 8 to 14)
    for r in range(8, 12):
        for c in range(9, 23):
            g[r][c] = 2
    # Bangs framing face
    g[12][9] = 2; g[13][9] = 2; g[12][22] = 2; g[13][22] = 2
    g[12][14] = 2; g[12][17] = 2
    
    # Face (rows 12 to 18, cols 10 to 21)
    for r in range(12, 19):
        for c in range(10, 22):
            if g[r][c] == 0:
                g[r][c] = 3
                
    # Big Emerald Cat Eyes
    g[14][11] = 5; g[14][12] = 4; g[15][11] = 4; g[15][12] = 1
    g[14][19] = 5; g[14][20] = 4; g[15][19] = 4; g[15][20] = 1
    
    # Pink Blushing Cheeks & Cat Smile
    g[16][10] = 8; g[16][21] = 8
    g[17][15] = 6; g[17][16] = 6 # Cute kitty mouth (3-shape)
    
    # Red Ribbon Bow at Collar
    g[19][15] = 6; g[19][16] = 6; g[20][14] = 6; g[20][17] = 6
    
    # White Maid Apron & Black Dress (rows 20 to 28)
    for r in range(21, 28):
        for c in range(11, 21):
            g[r][c] = 5 # White apron
    # Black dress sides
    for r in range(21, 28):
        g[r][9] = 7; g[r][10] = 7; g[r][21] = 7; g[r][22] = 7
        
    # Cat Paw Pose (Left & Right cute paws up!)
    g[18][8] = 5; g[19][7] = 5; g[19][8] = 5; g[20][8] = 3 # Left paw
    g[18][23] = 5; g[19][23] = 5; g[19][24] = 5; g[20][23] = 3 # Right paw
    
    # Legs (rows 28 to 31)
    g[28][13] = 7; g[29][13] = 7; g[30][13] = 5; g[31][13] = 5
    g[28][18] = 7; g[29][18] = 7; g[30][18] = 5; g[31][18] = 5

    return {
        "id": "neko_maid",
        "name": "Kawaii Neko Maid",
        "category": "Chibi",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 10,
    }

# -------------------------------------------------------------
# 3. Deluxe Steaming Ramen (32x32)
# -------------------------------------------------------------
def make_deluxe_ramen():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #1E1B18 (Dark Outline)
    # 2: #E11D48 (Vibrant Crimson Bowl)
    # 3: #F59E0B (Rich Golden Broth & Egg Yolk)
    # 4: #FDE68A (Tangled Ramen Noodles)
    # 5: #FFFFFF (White Egg / Naruto swirl base)
    # 6: #EC4899 (Pink Naruto spiral swirl)
    # 7: #10B981 (Fresh Green Scallions)
    # 8: #854D0E (Bamboo Chopsticks)
    # 9: #0F172A (Crisp Nori Seaweed Sheet)
    palette = {
        "1": hex_to_argb("#1E1B18"),
        "2": hex_to_argb("#E11D48"),
        "3": hex_to_argb("#F59E0B"),
        "4": hex_to_argb("#FDE68A"),
        "5": hex_to_argb("#FFFFFF"),
        "6": hex_to_argb("#EC4899"),
        "7": hex_to_argb("#10B981"),
        "8": hex_to_argb("#854D0E"),
        "9": hex_to_argb("#0F172A"),
    }
    
    # Wisps of Steaming Heat at top
    g[2][13] = 5; g[3][13] = 5; g[4][14] = 5; g[5][14] = 5; g[6][13] = 5
    g[3][18] = 5; g[4][19] = 5; g[5][18] = 5; g[6][18] = 5
    
    # Chopsticks picking up noodles
    for i in range(12):
        c = 15 + i
        r = 6 + (i // 2)
        if c < 30 and r < 32:
            g[r][c] = 8
            
    # Lifted Noodles dangling from chopsticks
    for r in range(9, 15):
        g[r][16] = 4; g[r][17] = 4
        
    # Nori Seaweed Sheet sticking out on left
    for r in range(10, 16):
        g[r][8] = 9; g[r][9] = 9; g[r][10] = 9
        
    # Bowl Rim (rows 14-16, cols 6 to 26)
    for c in range(6, 26):
        g[15][c] = 2
        g[16][c] = 2
    # White ceramic wave line on rim
    for c in range(7, 25, 2):
        g[15][c] = 5
        
    # Golden Broth & Noodles inside bowl (rows 16 to 20)
    for r in range(17, 21):
        for c in range(8, 24):
            g[r][c] = 3
    # Tangled noodles texture
    g[17][12] = 4; g[17][13] = 4; g[17][18] = 4; g[18][11] = 4; g[18][15] = 4; g[19][13] = 4; g[19][17] = 4
    
    # Naruto Fishcake (Pink swirl on white circle)
    g[17][20] = 5; g[17][21] = 5; g[18][20] = 6; g[18][21] = 6; g[19][20] = 5; g[19][21] = 5
    
    # Soft-boiled Ramen Egg (White egg half with gooey golden yolk)
    g[18][9] = 5; g[18][10] = 5; g[19][9] = 3; g[19][10] = 3
    
    # Chopped Green Scallions
    g[17][14] = 7; g[18][13] = 7; g[18][17] = 7; g[19][15] = 7
    
    # Ceramic Bowl Body (rows 21 to 29)
    for r in range(21, 29):
        span = 29 - r
        for c in range(6 + (28-r)//2, 26 - (28-r)//2):
            g[r][c] = 2
            
    # Bowl Foot / Base (rows 29 to 31)
    for c in range(11, 21):
        g[29][c] = 2
        g[30][c] = 1

    return {
        "id": "deluxe_ramen",
        "name": "Deluxe Anime Ramen",
        "category": "Kawaii",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 11,
    }

# -------------------------------------------------------------
# 4. Aqua Splash Turtle (24x24)
# -------------------------------------------------------------
def make_aqua_turtle():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    # 1: #0F172A (Navy Outline)
    # 2: #38BDF8 (Aqua Sky Blue Body)
    # 3: #0284C7 (Deeper Blue Shade)
    # 4: #92400E (Turtle Shell Brown)
    # 5: #FDE68A (Cream Shell Rim / Belly)
    # 6: #9333EA (Mystic Purple Eyes)
    # 7: #FFFFFF (Eye Highlight & Water Bubble)
    palette = {
        "1": hex_to_argb("#0F172A"),
        "2": hex_to_argb("#38BDF8"),
        "3": hex_to_argb("#0284C7"),
        "4": hex_to_argb("#92400E"),
        "5": hex_to_argb("#FDE68A"),
        "6": hex_to_argb("#9333EA"),
        "7": hex_to_argb("#FFFFFF"),
    }
    
    # Cute Round Head (rows 5 to 12, cols 7 to 17)
    for r in range(5, 13):
        for c in range(7, 17):
            g[r][c] = 2
    # Shadow under chin
    g[12][8] = 3; g[12][9] = 3; g[12][10] = 3; g[12][14] = 3; g[12][15] = 3
    
    # Big Cute Eyes
    g[7][8] = 7; g[7][9] = 6; g[8][8] = 6; g[8][9] = 1
    g[7][14] = 7; g[7][15] = 6; g[8][14] = 6; g[8][15] = 1
    
    # Cute Cheerful Mouth
    g[10][11] = 1; g[10][12] = 1
    
    # Turtle Shell (rows 13 to 20)
    for r in range(13, 21):
        for c in range(8, 18):
            g[r][c] = 4 # Brown shell
    # Cream Belly Plate
    for r in range(14, 19):
        g[r][9] = 5; g[r][10] = 5; g[r][11] = 5
        
    # Little Turtle Flippers/Paws
    g[15][6] = 2; g[16][5] = 2; g[16][6] = 2 # Left flipper
    g[15][19] = 2; g[16][19] = 2; g[16][20] = 2 # Right flipper
    g[20][8] = 3; g[21][8] = 3; g[20][16] = 3; g[21][16] = 3 # Back feet
    
    # Curly Splash Tail
    g[18][18] = 2; g[19][19] = 2; g[18][20] = 2; g[17][20] = 2
    
    # Floating Water Bubbles around it
    g[4][19] = 7; g[4][20] = 2; g[5][20] = 7
    g[11][4] = 7; g[11][5] = 2; g[12][5] = 7

    return {
        "id": "aqua_turtle",
        "name": "Aqua Splash Turtle",
        "category": "Monsters",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 12,
    }

# -------------------------------------------------------------
# 5. Sakura Kimono Princess (32x32)
# -------------------------------------------------------------
def make_sakura_princess():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #1E102E (Dark Violet Hair/Line)
    # 2: #3B1C54 (Deep Violet Hair)
    # 3: #FFE8DF (Porcelain Skin)
    # 4: #F43F5E (Ruby Eyes & Floral Hairpin)
    # 5: #FBCFE8 (Soft Pastel Pink Kimono)
    # 6: #BE185D (Deep Magenta Kimono Trim / Obi)
    # 7: #F59E0B (Golden Obi Cord)
    # 8: #FFFFFF (White Cherry Blossom Petals)
    palette = {
        "1": hex_to_argb("#1E102E"),
        "2": hex_to_argb("#3B1C54"),
        "3": hex_to_argb("#FFE8DF"),
        "4": hex_to_argb("#F43F5E"),
        "5": hex_to_argb("#FBCFE8"),
        "6": hex_to_argb("#BE185D"),
        "7": hex_to_argb("#F59E0B"),
        "8": hex_to_argb("#FFFFFF"),
    }
    
    # Flowing Dark Hair with Traditional Bun (rows 2 to 14)
    for r in range(4, 11):
        for c in range(10, 22):
            g[r][c] = 2
    g[2][15] = 2; g[2][16] = 2; g[3][14] = 2; g[3][15] = 2; g[3][16] = 2; g[3][17] = 2 # Hair bun
    
    # Sakura Hairpin on Right Side (Flower)
    g[4][21] = 4; g[4][22] = 8; g[4][23] = 4; g[5][22] = 7; g[6][22] = 4
    
    # Long flowing side hair locks
    for r in range(11, 24):
        g[r][8] = 2; g[r][9] = 2
        g[r][22] = 2; g[r][23] = 2
        
    # Face (rows 10 to 17, cols 10 to 21)
    for r in range(10, 18):
        for c in range(10, 22):
            if g[r][c] == 0:
                g[r][c] = 3
                
    # Elegant Ruby Eyes
    g[12][12] = 8; g[12][13] = 4; g[13][12] = 4; g[13][13] = 1
    g[12][18] = 8; g[12][19] = 4; g[13][18] = 4; g[13][19] = 1
    # Dainty pink blush & lips
    g[15][11] = 4; g[15][20] = 4
    g[16][15] = 4; g[16][16] = 4
    
    # Kimono Collar crossover (White inner & Pink outer)
    g[18][15] = 8; g[18][16] = 8; g[19][14] = 8; g[19][17] = 8
    
    # Pastel Pink Kimono Body (rows 19 to 31)
    for r in range(20, 32):
        for c in range(10, 22):
            if g[r][c] == 0:
                g[r][c] = 5
                
    # Wide Sleeves on sides
    for r in range(20, 28):
        g[r][6] = 5; g[r][7] = 5; g[r][8] = 5; g[r][9] = 5
        g[r][22] = 5; g[r][23] = 5; g[r][24] = 5; g[r][25] = 5
        
    # Magenta Obi Sash & Gold Cord (rows 22-25)
    for r in range(22, 26):
        for c in range(11, 21):
            g[r][c] = 6
    for c in range(11, 21):
        g[23][c] = 7 # Gold cord
        
    # Cherry Blossom Petal accents on Kimono
    g[27][13] = 8; g[28][14] = 4; g[29][17] = 8; g[30][18] = 4
    
    # Floating Sakura Petals in the air
    g[7][5] = 8; g[8][6] = 4; g[14][27] = 8; g[15][28] = 4; g[26][4] = 8

    return {
        "id": "sakura_princess",
        "name": "Sakura Kimono Princess",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 4,
        "isPremium": True,
        "diamondCost": 150,
        "sortOrder": 13,
    }

# -------------------------------------------------------------
# 6. Cyberpunk Neon Runner (32x32)
# -------------------------------------------------------------
def make_cyberpunk_runner():
    w, h = 32, 32
    g = [[0]*w for _ in range(h)]
    
    # 1: #0A0A10 (Dark Carbon)
    # 2: #00F0FF (Neon Cyan Cyber Eye & Trims)
    # 3: #FFE033 (Bright Neon Yellow Jacket)
    # 4: #252836 (Dark Slate Undershirt)
    # 5: #FFDFBA (Anime Skin)
    # 6: #9333EA (Neon Violet Spiky Hair)
    # 7: #FFFFFF (Visor Glare / White Accents)
    palette = {
        "1": hex_to_argb("#0A0A10"),
        "2": hex_to_argb("#00F0FF"),
        "3": hex_to_argb("#FFE033"),
        "4": hex_to_argb("#252836"),
        "5": hex_to_argb("#FFDFBA"),
        "6": hex_to_argb("#9333EA"),
        "7": hex_to_argb("#FFFFFF"),
    }
    
    # Spiky Purple Hair with Cyan Streaks (rows 2 to 9)
    for r in range(4, 9):
        for c in range(10, 22):
            g[r][c] = 6
    # Hair Spikes
    g[2][12] = 6; g[3][11] = 6; g[3][12] = 2 # Cyan streak
    g[1][16] = 6; g[2][15] = 6; g[2][16] = 6; g[3][16] = 2
    g[2][20] = 6; g[3][19] = 6; g[3][20] = 6
    
    # Face (rows 9 to 16, cols 11 to 21)
    for r in range(9, 17):
        for c in range(11, 21):
            g[r][c] = 5
            
    # Normal Right Eye vs Glowing Cyan Cybernetic Left Eye!
    # Left eye (Normal dark)
    g[12][13] = 1; g[12][14] = 1; g[13][13] = 1; g[13][14] = 7
    # Right eye (Cybernetic Glowing Cyan Optic Eye)
    g[12][18] = 2; g[12][19] = 2; g[13][18] = 2; g[13][19] = 7
    # Cybernetic wire line on cheek
    g[14][19] = 2; g[15][20] = 2; g[16][20] = 2
    
    # Smirk Mouth
    g[15][14] = 1; g[15][15] = 1; g[15][16] = 1
    
    # High-Collar Neon Yellow Jacket (rows 17 to 28)
    for r in range(17, 28):
        for c in range(8, 24):
            g[r][c] = 3 # Yellow jacket
            
    # Dark Undershirt in center
    for r in range(18, 28):
        g[r][15] = 4; g[r][16] = 4
    # Cyan LED jacket lapels
    for r in range(18, 28):
        g[r][14] = 2; g[r][17] = 2
        
    # High Collar framing jaw
    g[17][11] = 3; g[17][12] = 3; g[17][19] = 3; g[17][20] = 3
    
    # Legs / Pants (rows 28 to 31)
    for r in range(28, 32):
        g[r][12] = 1; g[r][13] = 1; g[r][18] = 1; g[r][19] = 1
    # Cybernetic boot lights
    g[31][12] = 2; g[31][19] = 2

    return {
        "id": "cyberpunk_runner",
        "name": "Cyberpunk Neon Runner",
        "category": "Heroes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": True,
        "diamondCost": 120,
        "sortOrder": 14,
    }

# -------------------------------------------------------------
# 7. Kawaii Cat Boba Tea (24x24)
# -------------------------------------------------------------
def make_cat_boba():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    # 1: #2D1A12 (Dark Brown Outline / Tapioca Pearls)
    # 2: #E8B47E (Milk Tea Tan/Peach)
    # 3: #FFFFFF (White Cream Cap & Cat Face)
    # 4: #FF6B8B (Pink Cheeks & Striped Straw)
    # 5: #A0C4FF (Pastel Blue Dome Lid)
    palette = {
        "1": hex_to_argb("#2D1A12"),
        "2": hex_to_argb("#E8B47E"),
        "3": hex_to_argb("#FFFFFF"),
        "4": hex_to_argb("#FF6B8B"),
        "5": hex_to_argb("#A0C4FF"),
    }
    
    # Pink Striped Straw sticking out
    g[1][12] = 4; g[2][12] = 3; g[3][13] = 4; g[4][13] = 3
    
    # Dome Lid with Cat Ears (rows 4 to 8)
    # Cat Ears on lid
    g[5][7] = 5; g[5][8] = 4; g[6][7] = 5; g[6][8] = 5
    g[5][15] = 4; g[5][16] = 5; g[6][15] = 5; g[6][16] = 5
    # Dome curved glass
    for r in range(6, 9):
        for c in range(8, 16):
            g[r][c] = 5
            
    # White Whipped Cream Layer (rows 8-10)
    for c in range(7, 17):
        g[9][c] = 3
        g[10][c] = 3
        
    # Milk Tea Cup Body (rows 11 to 21)
    for r in range(11, 21):
        for c in range(7, 17):
            g[r][c] = 2
            
    # Cute Kawaii Face on the Cup
    g[13][9] = 1; g[13][14] = 1 # Closed happy winking eyes
    g[14][8] = 4; g[14][15] = 4 # Blushing pink cheeks
    g[14][11] = 1; g[14][12] = 1 # Kitty mouth :3
    
    # Tapioca Boba Pearls at the bottom (rows 18 to 21)
    g[18][8] = 1; g[18][10] = 1; g[18][13] = 1; g[18][15] = 1
    g[19][9] = 1; g[19][11] = 1; g[19][14] = 1
    g[20][8] = 1; g[20][10] = 1; g[20][12] = 1; g[20][15] = 1
    
    # Cup Base rim
    for c in range(8, 16):
        g[21][c] = 1

    return {
        "id": "cat_boba",
        "name": "Kawaii Cat Boba Tea",
        "category": "Kawaii",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 2,
        "isPremium": False,
        "sortOrder": 15,
    }

# -------------------------------------------------------------
# 8. Crimson Mystic Eye (24x24)
# -------------------------------------------------------------
def make_crimson_eye():
    w, h = 24, 24
    g = [[0]*w for _ in range(h)]
    
    # 1: #0A0A0E (Pitch Black Pupil & Tomoe)
    # 2: #E11D48 (Glowing Crimson Red Iris)
    # 3: #9F1239 (Deep Maroon Iris Shadow)
    # 4: #FFFFFF (White Sclera & Eye Highlights)
    # 5: #FDA4AF (Pastel Eyelid Skin)
    palette = {
        "1": hex_to_argb("#0A0A0E"),
        "2": hex_to_argb("#E11D48"),
        "3": hex_to_argb("#9F1239"),
        "4": hex_to_argb("#FFFFFF"),
        "5": hex_to_argb("#FDA4AF"),
    }
    
    # Eyelashes & Upper Lid Curve (rows 6 to 9)
    for c in range(6, 18):
        g[7][c] = 1
    g[6][10] = 1; g[6][11] = 1; g[6][12] = 1; g[6][13] = 1; g[6][14] = 1
    
    # Lower Lid Curve (rows 16-17)
    for c in range(7, 17):
        g[16][c] = 1
        
    # Eye Shape (White Sclera)
    for r in range(8, 16):
        for c in range(5, 19):
            if g[r][c] == 0:
                g[r][c] = 4
                
    # Crimson Glowing Iris (Center 8x8 circle)
    for r in range(8, 16):
        for c in range(8, 16):
            g[r][c] = 2
    # Outer dark ring of iris
    for c in range(9, 15):
        g[8][c] = 3; g[15][c] = 3
    for r in range(9, 15):
        g[r][8] = 3; g[r][15] = 3
        
    # Center Black Pupil
    g[11][11] = 1; g[11][12] = 1; g[12][11] = 1; g[12][12] = 1
    
    # 3 Curved Tomoe / Magatama comma marks around pupil!
    # Top Tomoe
    g[9][11] = 1; g[9][12] = 1; g[10][13] = 1
    # Bottom Left Tomoe
    g[13][9] = 1; g[14][9] = 1; g[13][10] = 1
    # Bottom Right Tomoe
    g[13][14] = 1; g[14][14] = 1; g[14][13] = 1
    
    # Sparkling Glare Highlight
    g[9][9] = 4; g[10][9] = 4

    return {
        "id": "crimson_mystic_eye",
        "name": "Crimson Mystic Eye",
        "category": "Eyes",
        "gridWidth": w,
        "gridHeight": h,
        "grid": grid_to_string(g),
        "colorMap": palette,
        "difficulty": 3,
        "isPremium": False,
        "sortOrder": 16,
    }

def main():
    print("Generating 8 new Eye-Catching Anime Artworks...")
    artworks = [
        make_mystic_kitsune(),
        make_neko_maid(),
        make_deluxe_ramen(),
        make_aqua_turtle(),
        make_sakura_princess(),
        make_cyberpunk_runner(),
        make_cat_boba(),
        make_crimson_eye(),
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
    print("Successfully published all 8 new Eye-Catching Anime Artworks to pixel_art/anime!")
    
    updated_flavor = flavor_ref.get().to_dict()
    print("New anime catalogVersion:", updated_flavor.get("catalogVersion"))

if __name__ == "__main__":
    main()
