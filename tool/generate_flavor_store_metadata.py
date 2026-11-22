#!/usr/bin/env python3
"""
Generate complete Play Store metadata, feature graphics (1024x500), and icons (512x512)
for all 8 new flavor apps:
  - brick:   Brick Art: Build by Number (com.tenhead.brickart)
  - bead:    Bead Art: Color by Number (com.tenhead.beadart)
  - knit:    Knit Art: Stitch by Number (com.tenhead.knitart)
  - mosaic:  Mosaic Art: Tile by Number (com.tenhead.mosaicart)
  - glow:    Glow Art: Light by Number (com.tenhead.glowart)
  - sticker: Sticker Art: Stick by Number (com.tenhead.stickerart)
  - quilt:   Quilt Art: Sew by Number (com.tenhead.quiltart)
  - voxel:   Voxel Art: 3D Color by Number (com.tenhead.voxelart)

Structured following the crossStitch / diamond store styling.
"""

import json
import math
import os
import shutil
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FASTLANE_DIR = os.path.join(ROOT, "fastlane")
METADATA_DIR = os.path.join(FASTLANE_DIR, "metadata")
ICONS_DIR = os.path.join(ROOT, "assets", "icons")

SERIF_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SANS_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# --------------------------------------------------------------------------
# Flavor Definitions & ASO Metadata
# --------------------------------------------------------------------------
FLAVORS = {
    "brick": {
        "package_name": "com.tenhead.brickart",
        "bg_colors": ((185, 45, 30), (30, 24, 32)),      # Red terracotta to dark slate
        "accent_gold": (255, 205, 50),
        "cream": (255, 246, 230),
        "tagline_main": "Snap 3D building bricks into pixel art",
        "tagline_sub": "with realistic studs & ASMR clicks.",
        "icon_file": "brick.png",
        "palette_chips": [
            ("1", (230, 50, 40)),
            ("2", (245, 170, 30)),
            ("3", (45, 145, 240)),
            ("4", (60, 185, 80)),
            ("5", (240, 240, 245)),
            ("6", (35, 38, 48)),
        ],
        "locales": {
            "en-US": {
                "title": "Brick Art: Build by Number",
                "short_description": "Snap 3D building bricks to build pixel models. Satisfying ASMR puzzle offline!",
                "full_description": """Welcome to Brick Art: Build by Number — the most satisfying 3D building brick puzzle and construction game! Step into a colorful toy workshop where you assemble retro pixel sculptures, cute animals, vehicles, and landmark miniatures stud by stud. Tap the numbers, place your realistic 3D building bricks, and watch your creations snap together with authentic plastic clack sounds. 100% offline — build anytime, anywhere without internet!

Whether you grew up loving plastic brick building sets, construction kits, or simply want a relaxing, meditative puzzle game to unwind after a busy day, Brick Art brings the timeless joy of brick building right to your fingertips.

---

🧱 A VIBRANT WORKSHOP OF 3D BRICK MODELS

• Cute Animals & Pets: Playful puppies, curious kittens, pandas, frogs, and colorful songbirds.
• Vehicles & Space: Retro muscle cars, city buses, airplanes, rocket ships, and cute UFOs.
• Pop Culture & Pixel Icons: Classic pixel burgers, game controllers, retro arcade machines, and sweet treats.
• Architectural Landmarks: Miniature castles, cozy cottages, windmills, and oriental pagodas.
• Realistic 3D Stud Shader: Experience raised circular studs, dynamic lighting shadows, and authentic plastic shine.

✨ WHY YOU'LL LOVE BRICK ART: BUILD BY NUMBER

• 100% Offline Play: Build beautiful brick models on flights, during commutes, or on your couch — no Wi-Fi needed!
• Satisfying ASMR Snap Audio: Feel and hear the crisp, tactile snap as each brick locks securely into place.
• Zen Overdrive Mode: Build consecutive streaks to unlock radiant prismatic effects and bonus rewards!
• Time-Lapse 3D Replay: Watch your finished build assemble itself piece by piece from the base plate to the final stud.
• Pure Creative Relaxation: No timers, no pressure, and no missing pieces. Just soothing, stress-free construction.
• Regular Brick Updates: Fresh templates, weekly builds, and seasonal construction sets added regularly.

Pick your first build set, select your brick color, and start snapping your 3D gallery together. Download Brick Art: Build by Number today and build your way into creative peace!""",
                "whats_new": "Welcome to the initial release of Brick Art: Build by Number! Enjoy realistic 3D building brick sets, tactile ASMR snap clicks, satisfying Zen Overdrive streaks, and 100% offline gameplay."
            },
            "de-DE": {
                "title": "Brick Art: Bauen nach Zahlen",
                "short_description": "Bauen Sie 3D-Baustein-Modelle nach Zahlen! Entspannendes ASMR-Spiel offline.",
                "full_description": "Willkommen bei Brick Art: Bauen nach Zahlen – dem entspannenden 3D-Baustein-Spiel! Stecken Sie bunte Steine zusammen und erwecken Sie Tiere, Autos und Pixel-Modelle zum Leben. 100% offline spielbar!\n\n🧱 FUNKTIONEN\n• Hunderte 3D-Baustein-Modelle: Tiere, Fahrzeuge & Gebäude.\n• Realistischer 3D-Look mit Noppen und Kunststoff-Glanz.\n• 100% Offline: Kein WLAN oder Internet nötig.\n• Taktile ASMR-Klicks beim Platzieren der Steine.\n• Zeitraffer-Video Ihrer fertigen Bauwerke!\n\nLaden Sie Brick Art heute herunter!",
                "whats_new": "Erstveröffentlichung von Brick Art: Bauen nach Zahlen! Platzieren Sie realistische 3D-Bausteine offline."
            },
            "fr-FR": {
                "title": "Brick Art: Construire Numéro",
                "short_description": "Assemblez des briques 3D par numéro ! Jeu ASMR satisfaisant et relaxant.",
                "full_description": "Bienvenue dans Brick Art: Construire par Numéro — le jeu d'assemblage de briques 3D le plus satisfaisant ! Donnez vie à des animaux mignons, véhicules et monuments brique par brique. 100% hors ligne !\n\n🧱 CARACTÉRISTIQUES\n• Modèles 3D variés : animaux, bolides et monuments rétro.\n• Rendu réaliste des briques 3D avec ombres et reflets.\n• 100% Hors Ligne sans connexion Wi-Fi.\n• Bruitages ASMR tactiles et gratifiants.\n• Replay accéléré de vos constructions finies.\n\nTéléchargez Brick Art dès aujourd'hui !",
                "whats_new": "Lancement initial de Brick Art: Construire par Numéro ! Profitez de superbes briques 3D hors ligne."
            },
            "es-ES": {
                "title": "Brick Art: Construir Número",
                "short_description": "¡Construye bloques 3D por número! Juego ASMR relajante y 100% sin conexión.",
                "full_description": "¡Bienvenido a Brick Art: Construir por Números! Sumérgete en el taller de bloques de construcción 3D más satisfactorio. Da vida a animales, coches y esculturas píxel pieza por pieza. ¡100% sin conexión!\n\n🧱 CARACTERÍSTICAS\n• Galería de modelos 3D: animales, vehículos y castillos.\n• Textura realista de bloques con relieve y brillo plástico.\n• 100% Sin Conexión a internet.\n• Sonidos ASMR relajantes al encajar cada pieza.\n• Repetición Time-Lapse para compartir tus creaciones.\n\n¡Descarga Brick Art hoy y empieza a construir!",
                "whats_new": "¡Lanzamiento inicial de Brick Art: Construir por Números! Construye modelos 3D relajantes sin conexión."
            },
            "es-419": {
                "title": "Brick Art: Construir Número",
                "short_description": "¡Construye bloques 3D por número! Juego ASMR relajante y 100% sin conexión.",
                "full_description": "¡Bienvenido a Brick Art: Construir por Números! Sumérgete en el taller de bloques de construcción 3D más satisfactorio. Da vida a animales, coches y esculturas píxel pieza por pieza. ¡100% sin conexión!\n\n🧱 CARACTERÍSTICAS\n• Galería de modelos 3D: animales, vehículos y castillos.\n• Textura realista de bloques con relieve y brillo plástico.\n• 100% Sin Conexión a internet.\n• Sonidos ASMR relajantes al encajar cada pieza.\n• Repetición Time-Lapse para compartir tus creaciones.\n\n¡Descarga Brick Art hoy y empieza a construir!",
                "whats_new": "¡Lanzamiento inicial de Brick Art: Construir por Números! Construye modelos 3D relajantes sin conexión."
            },
            "pt-BR": {
                "title": "Brick Art: Montar por Número",
                "short_description": "Monte blocos 3D por número! Quebra-cabeça ASMR satisfatório e offline.",
                "full_description": "Bem-vindo ao Brick Art: Montar por Número! Monte peças plásticas em 3D e dê vida a animais fofos, carros e castelos peça por peça. 100% offline para jogar onde quiser!\n\n🧱 DESTAQUES\n• Incríveis modelos 3D para montar.\n• Renders realistas com encaixes perfeitos.\n• 100% Offline sem precisar de internet.\n• Cliques táteis e relaxantes de ASMR.\n• Vídeo Time-Lapse para rever sua construção.\n\nBaixe Brick Art hoje mesmo!",
                "whats_new": "Lançamento inicial de Brick Art: Montar por Número! Divirta-se montando blocos 3D offline."
            },
            "ru-RU": {
                "title": "Brick Art: Сборка по Номерам",
                "short_description": "Собирайте 3D-блоки по номерам! Приятная ASMR-игра с блоками офлайн.",
                "full_description": "Добро пожаловать в игру «Brick Art: Сборка по Номерам»! Собирайте реалистичные 3D-модели из пластиковых блоков: милых животных, ретро-автомобили и архитектуру блок за блоком. 100% офлайн!\n\n🧱 ОСОБЕННОСТИ\n• Большая коллекция 3D-моделей.\n• Реалистичный вид блоков с аутентичным глянцем.\n• 100% Офлайн без подключения к интернету.\n• Приятные щелчки ASMR при соединении деталей.\n• Таймлапс-повтор для демонстрации готовых работ.\n\nСкачайте Brick Art прямо сейчас!",
                "whats_new": "Первый релиз игры Brick Art: Сборка по Номерам! Создавайте 3D-постройки из блоков офлайн."
            }
        }
    },

    "bead": {
        "package_name": "com.tenhead.beadart",
        "bg_colors": ((135, 40, 155), (32, 18, 55)),      # Magenta to deep purple
        "accent_gold": (255, 215, 60),
        "cream": (255, 245, 235),
        "tagline_main": "Place colorful fuse beads on pegboards",
        "tagline_sub": "with satisfying ASMR clicks.",
        "icon_file": "bead.png",
        "palette_chips": [
            ("1", (255, 75, 130)),
            ("2", (165, 80, 240)),
            ("3", (40, 200, 240)),
            ("4", (255, 210, 50)),
            ("5", (60, 220, 140)),
            ("6", (45, 45, 60)),
        ],
        "locales": {
            "en-US": {
                "title": "Bead Art: Color by Number",
                "short_description": "Place colorful fuse beads on pegboards to craft pixel art. Relaxing ASMR game!",
                "full_description": """Welcome to Bead Art: Color by Number — the most soothing fuse bead crafting and pegboard puzzle game! Step into a creative craft room filled with vibrant Perler and Hama style melt beads. Place shiny cylindrical beads onto pegboards one by one to create charming anime characters, cute desserts, retro pixel sprites, and blooming floral designs. 100% offline — craft anytime, anywhere without Wi-Fi!

Whether you love handmade crafts, DIY bead pegboards, or simple color by number games, Bead Art provides a deeply satisfying and meditative pixel craft experience.

---

🟢 A DELIGHTFUL PEG BOARD CRAFT GALLERY

• Sweet Treats & Boba: Bubble tea cups, sprinkled donuts, cupcakes, and fruit slices.
• Anime & Kawaii Sprites: Chibi heroes, cute kittens, magical potions, and retro game hearts.
• Nature & Animals: Sea turtles, axolotls, garden flowers, and woodland foxes.
• 3D Cylindrical Bead Shader: Realistic center peg holes, smooth bevels, and melted bead gloss.

✨ WHY YOU'LL LOVE BEAD ART

• 100% Offline: Craft on planes, trains, or cozy afternoons with no internet needed.
• Tactile ASMR Audio: Crisp pegboard placement clicks and iron melting animations.
• Zen Overdrive: Maintain coloring streaks to enter glowing overdrive with bonus gem drops!
• Time-Lapse Replay: Watch your finished design come together from the very first bead.

Download Bead Art: Color by Number today and start placing your colorful beads!""",
                "whats_new": "Welcome to the initial release of Bead Art: Color by Number! Enjoy realistic cylindrical fuse beads, soothing pegboard crafting, and offline ASMR fun."
            },
            "de-DE": {
                "title": "Bügelperlen: Malen nach Zahl",
                "short_description": "Stecken Sie bunte Bügelperlen auf Steckplatten! Entspannendes Pixel-Spiel.",
                "full_description": "Willkommen bei Bügelperlen: Malen nach Zahlen – dem gemütlichen Perlen-Steckspiel! Stecken Sie bunte Perlen auf Platten und erstellen Sie tolle Pixel-Motive. 100% offline!\n\n🟢 FUNKTIONEN\n• Wunderschöne Perlen-Motive: Kawaii, Tiere & Deko.\n• Realistische 3D-Bügelperlen mit Steckloch.\n• 100% Offline spielbar ohne Internet.\n• Beruhigende ASMR-Klicks.\n\nJetzt Bügelperlen herunterladen!",
                "whats_new": "Erstveröffentlichung von Bügelperlen: Malen nach Zahlen! Viel Spaß beim Stecken!"
            },
            "fr-FR": {
                "title": "Perles à Repasser: Coloriage",
                "short_description": "Placez des perles sur vos grilles et créez du pixel art ! Détente hors ligne.",
                "full_description": "Bienvenue dans Perles à Repasser: Coloriage par Numéro ! Placez des perles colorées sur des plaques à picots pour concevoir d'adorables motifs pixel. 100% hors ligne !\n\n🟢 CARACTÉRISTIQUES\n• Superbes modèles variés : animaux, douceurs et kawaii.\n• Rendu 3D réaliste des perles cylindriques.\n• 100% Hors Ligne sans Wi-Fi.\n• Sons ASMR relaxants à chaque perle posée.\n\nTéléchargez dès aujourd'hui !",
                "whats_new": "Lancement initial de Perles à Repasser: Coloriage par Numéro !"
            },
            "es-ES": {
                "title": "Cuentas Hama: Colorear",
                "short_description": "¡Coloca cuentas y crea arte en pixel! Juego artesanal relajante sin conexión.",
                "full_description": "¡Bienvenido a Cuentas Hama: Colorear por Números! Coloca cuentas de plástico en plantillas para crear maravillosos diseños pixel. ¡100% sin conexión!\n\n🟢 CARACTERÍSTICAS\n• Diseños encantadores de animales, comida y fantasía.\n• Rendu 3D realista de cuentas perforadas.\n• 100% Sin Conexión a internet.\n• Efecto ASMR suave y relajante.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Cuentas Hama: Colorear por Números!"
            },
            "es-419": {
                "title": "Cuentas Hama: Colorear",
                "short_description": "¡Coloca cuentas y crea arte en pixel! Juego artesanal relajante sin conexión.",
                "full_description": "¡Bienvenido a Cuentas Hama: Colorear por Números! Coloca cuentas de plástico en plantillas para crear maravillosos diseños pixel. ¡100% sin conexión!\n\n🟢 CARACTERÍSTICAS\n• Diseños encantadores de animales, comida y fantasía.\n• Rendu 3D realista de cuentas perforadas.\n• 100% Sin Conexión a internet.\n• Efecto ASMR suave y relajante.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Cuentas Hama: Colorear por Números!"
            },
            "pt-BR": {
                "title": "Perler Beads: Pintar Número",
                "short_description": "Coloque contas coloridas nas placas e crie pixel art! Relaxante e offline.",
                "full_description": "Bem-vindo ao Perler Beads: Pintar por Número! Crie lindas artes em pixel encaixando contas coloridas. 100% offline para relaxar a qualquer hora!\n\n🟢 DESTAQUES\n• Centenas de modelos kawaii e animais.\n• Efeito 3D com textura realista de contas.\n• 100% Offline sem internet.\n• ASMR satisfatório ao encaixar.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Perler Beads: Pintar por Número!"
            },
            "ru-RU": {
                "title": "Термомозаика: По Номерам",
                "short_description": "Собирайте термомозаику из бусин по номерам! Расслабляющее творчество офлайн.",
                "full_description": "Добро пожаловать в игру «Термомозаика: По Номерам»! Выкладывайте цилиндрические бусины на поле и создавайте яркие пиксельные шедевры. 100% офлайн!\n\n🟢 ОСОБЕННОСТИ\n• Милые схемы: животные, сладости и ретро-арт.\n• Реалистичный 3D-вид бусин с отверстием.\n• 100% Офлайн без интернета.\n• Успокаивающие щелчки ASMR.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Термомозаика: По Номерам!"
            }
        }
    },

    "knit": {
        "package_name": "com.tenhead.knitart",
        "bg_colors": ((35, 95, 105), (28, 35, 45)),       # Cozy heather teal to dark charcoal
        "accent_gold": (255, 210, 120),
        "cream": (255, 245, 230),
        "tagline_main": "Weave cozy woolen yarn stitches",
        "tagline_sub": "into colorful sweaters & plushies.",
        "icon_file": "knit.png",
        "palette_chips": [
            ("1", (230, 90, 110)),
            ("2", (240, 180, 80)),
            ("3", (80, 165, 150)),
            ("4", (110, 130, 190)),
            ("5", (245, 235, 220)),
            ("6", (60, 50, 55)),
        ],
        "locales": {
            "en-US": {
                "title": "Knit Art: Stitch by Number",
                "short_description": "Weave cozy woolen yarn stitches into colorful sweaters & art. Warm & relaxing!",
                "full_description": """Welcome to Knit Art: Stitch by Number — the warmest, coziest knitting and crochet coloring game! Step into a sunny cottage filled with skeins of soft woolen yarn, wooden needles, and charming textile patterns. Bring cozy winter sweaters, woodland owls, sleeping kittens, and floral samplers to life stitch by stitch. Tap the numbers, knit your loops, and watch your tapestry weave together. 100% offline!

Whether you love knitting scarves, crocheting amigurumi plushies, or just want a cozy, mindful game to destress, Knit Art wraps you in pure creative comfort.

---

🧶 A COZY GALLERY OF WOOLEN DESIGNS

• Cottagecore & Flora: Garden lavender, autumn acorns, mushrooms, and floral wreaths.
• Cozy Animals: Sleeping cats, fluffy owls, winter bunnies, and woodland deer.
• Sweaters & Quilts: Nordic fair-isle sweaters, granny squares, and warm scarves.
• Interlocking V-Stitch Shader: Realistic woolen yarn loops with tactile fiber textures.

✨ WHY YOU'LL LOVE KNIT ART

• 100% Offline: Knit anywhere on your commute or sofa without Wi-Fi.
• Soft ASMR Tap Audio: Gentle, muffled fabric taps that soothe and relax your mind.
• Zen Overdrive: Build continuous knitting streaks for prismatic flourishes and diamond rewards.
• Time-Lapse Replay: Watch your finished knitted garment weave itself from yarn to masterpiece.

Download Knit Art: Stitch by Number today and wrap yourself in cozy creativity!""",
                "whats_new": "Welcome to the initial release of Knit Art: Stitch by Number! Experience interlocking woolen yarn stitches, cozy cottage designs, and relaxing offline knitting."
            },
            "de-DE": {
                "title": "Stricken: Malen nach Zahlen",
                "short_description": "Stricken Sie bunte Wolle nach Zahlen! Gemütliches Handarbeitsspiel offline.",
                "full_description": "Willkommen bei Stricken: Malen nach Zahlen – dem gemütlichsten Woll- und Strickspiel! Erwecken Sie Pullover, Eulen und Decken Masche für Masche zum Leben. 100% offline!\n\n🧶 FUNKTIONEN\n• Gemütliche Strickmuster: Pullover, Tiere & Blumen.\n• Realistische Wollfaden-Optik mit weicher Textur.\n• 100% Offline spielbar ohne Internet.\n• Beruhigende, sanfte ASMR-Klickgeräusche.\n\nJetzt herunterladen und einkuscheln!",
                "whats_new": "Erstveröffentlichung von Stricken: Malen nach Zahlen!"
            },
            "fr-FR": {
                "title": "Tricot Art: Points par Numéro",
                "short_description": "Tricotez de la laine douce par numéro ! Jeu créatif, doux et relaxant.",
                "full_description": "Bienvenue dans Tricot Art: Points par Numéro ! Donnez vie à des pulls chauds, hiboux et motifs d'hiver boucle par boucle. 100% hors ligne !\n\n🧶 CARACTÉRISTIQUES\n• Modèles chaleureux : tricots, animaux et fleurs.\n• Rendu réaliste des mailles de laine.\n• 100% Hors Ligne sans Wi-Fi.\n• Ambiance ASMR douce et relaxante.\n\nTéléchargez dès maintenant !",
                "whats_new": "Lancement initial de Tricot Art: Points par Numéro !"
            },
            "es-ES": {
                "title": "Tejer: Pintar por Número",
                "short_description": "¡Teje lana suave por números! Hermoso juego artesanal y relajante.",
                "full_description": "¡Bienvenido a Tejer: Pintar por Números! Sumérgete en el arte del tejido y ganchillo. Da vida a suéteres, búhos y flores puntada a puntada. ¡100% sin conexión!\n\n🧶 CARACTERÍSTICAS\n• Diseños acogedores de invierno y naturaleza.\n• Textura realista de puntos de lana.\n• 100% Sin Conexión a internet.\n• Experiencia ASMR suave y meditativa.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Tejer: Pintar por Números!"
            },
            "es-419": {
                "title": "Tejer: Pintar por Número",
                "short_description": "¡Teje lana suave por números! Hermoso juego artesanal y relajante.",
                "full_description": "¡Bienvenido a Tejer: Pintar por Números! Sumérgete en el arte del tejido y ganchillo. Da vida a suéteres, búhos y flores puntada a puntada. ¡100% sin conexión!\n\n🧶 CARACTERÍSTICAS\n• Diseños acogedores de invierno y naturaleza.\n• Textura realista de puntos de lana.\n• 100% Sin Conexión a internet.\n• Experiencia ASMR suave y meditativa.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Tejer: Pintar por Números!"
            },
            "pt-BR": {
                "title": "Tricô Art: Pintar por Número",
                "short_description": "Teça fios de lã por número! Jogo acolhedor, artesanal e offline.",
                "full_description": "Bem-vindo ao Tricô Art: Pintar por Número! Dê vida a suéteres, corujas e mantas ponto por ponto. 100% offline para relaxar a qualquer momento!\n\n🧶 DESTAQUES\n• Lindos padrões artesanais de inverno e campo.\n• Textura realista de pontos de lã e crochê.\n• 100% Offline sem internet.\n• ASMR suave e relaxante.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Tricô Art: Pintar por Número!"
            },
            "ru-RU": {
                "title": "Вязание: По Номерам",
                "short_description": "Вяжите уютные узоры шерстяной пряжей по номерам! Тёплая релакс-игра.",
                "full_description": "Добро пожаловать в игру «Вязание: По Номерам»! Создавайте тёплые свитеры, милых сов и пледы петля за петлёй. 100% офлайн!\n\n🧶 ОСОБЕННОСТИ\n• Уютные схемы: зимняя одежда, совы и цветы.\n• Реалистичная текстура шерстяных петель.\n• 100% Офлайн без интернета.\n• Мягкие, расслабляющие звуки ASMR.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Вязание: По Номерам!"
            }
        }
    },

    "mosaic": {
        "package_name": "com.tenhead.mosaicart",
        "bg_colors": ((18, 55, 115), (12, 22, 45)),       # Aegean blue to deep navy
        "accent_gold": (255, 200, 60),
        "cream": (250, 246, 238),
        "tagline_main": "Place glazed ceramic & glass tiles",
        "tagline_sub": "into beautiful mosaic mandalas.",
        "icon_file": "mosaic.png",
        "palette_chips": [
            ("1", (30, 120, 200)),
            ("2", (220, 95, 40)),
            ("3", (245, 195, 45)),
            ("4", (45, 160, 110)),
            ("5", (140, 70, 180)),
            ("6", (240, 235, 225)),
        ],
        "locales": {
            "en-US": {
                "title": "Mosaic Art: Tile by Number",
                "short_description": "Place glazed ceramic & glass tiles to craft mosaic mandalas. Relax offline!",
                "full_description": """Welcome to Mosaic Art: Tile by Number — the ultimate Mediterranean tile and glass mosaic puzzle game! Step into an artisan ceramic studio where you assemble intricate mandalas, Aztec suns, stained glass windows, and ancient mosaics tile by tile. Tap the numbers, place your glossy ceramic tesserae into mortar grout, and watch your artwork shimmer. 100% offline!

Whether you admire ancient Roman mosaics, Moroccan zellige tiles, or simply love meditative color by number games, Mosaic Art offers a timeless, peaceful puzzle experience.

---

🏺 AN INTRICATE CERAMIC MOSAIC GALLERY

• Mandalas & Sacred Geometry: Celtic knots, Persian carpets, and kaleidoscope patterns.
• Mythological & Solar Symbols: Aztec suns, celestial moons, and stained glass peacocks.
• Gemstones & Minerals: Amethyst geodes, turquoise stones, and ruby medallions.
• Glazed Ceramic Shader: Beveled tile edges, realistic mortar grout, and polished glass glaze.

✨ WHY YOU'LL LOVE MOSAIC ART

• 100% Offline: Piece together mosaics on planes, trains, or at home with zero data used.
• Crisp ASMR Tile Audio: Hear the authentic clink of ceramic tiles settling into grout.
• Zen Overdrive: Score consecutive streaks to unlock prismatic tile glows and diamond bonuses.
• Time-Lapse Replay: Watch your finished mosaic tile itself from the first tessera to the full masterpiece.

Download Mosaic Art: Tile by Number today and piece together your own museum of art!""",
                "whats_new": "Welcome to the initial release of Mosaic Art: Tile by Number! Enjoy glazed ceramic tiles, mortar grout lines, and relaxing offline mosaic crafting."
            },
            "de-DE": {
                "title": "Mosaik Art: Fliesen Legen",
                "short_description": "Legen Sie Keramikfliesen zu Mosaik-Mandalas nach Zahlen! Entspannt offline.",
                "full_description": "Willkommen bei Mosaik Art: Fliesen Legen – dem kunstvollen Keramik- und Glasmosaik-Spiel! Erschaffen Sie atemberaubende Mandalas und Muster Stein für Stein. 100% offline!\n\n🏺 FUNKTIONEN\n• Wunderschöne Mandalas, Sonnen und geometrische Muster.\n• Glasierte Keramikfliesen mit Fugenoptik.\n• 100% Offline spielbar ohne WLAN.\n• Angenehmer Klick-Sound beim Setzen der Steine.\n\nJetzt herunterladen und entspannen!",
                "whats_new": "Erstveröffentlichung von Mosaik Art: Fliesen Legen!"
            },
            "fr-FR": {
                "title": "Mosaïque Art: Peindre Numéro",
                "short_description": "Assemblez des mosaïques en céramique par numéro ! Relaxation hors ligne.",
                "full_description": "Bienvenue dans Mosaïque Art: Peindre par Numéro ! Placez des carreaux de céramique émaillée pour composer de splendides mandalas et vitraux. 100% hors ligne !\n\n🏺 CARACTÉRISTIQUES\n• Mandalas d'inspiration marocaine et romaine.\n• Carreaux brillants avec joints de ciment réalistes.\n• 100% Hors Ligne sans connexion Wi-Fi.\n• Sons ASMR relaxants à chaque carreau posé.\n\nTéléchargez dès aujourd'hui !",
                "whats_new": "Lancement initial de Mosaïque Art: Peindre par Numéro !"
            },
            "es-ES": {
                "title": "Mosaico: Pintar por Número",
                "short_description": "¡Coloca azulejos de cerámica y crea mosaicos! Juego relajante sin conexión.",
                "full_description": "¡Bienvenido a Mosaico: Pintar por Números! Diseña increíbles mosaicos de azulejos vidriados y mandalas tradicionales pieza por pieza. ¡100% sin conexión!\n\n🏺 CARACTERÍSTICAS\n• Galería de mandalas, soles aztecas y patrones geométricos.\n• Azulejos de cerámica realistas con textura y relieve.\n• 100% Sin Conexión a internet.\n• Efecto ASMR agradable al encajar las teselas.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Mosaico: Pintar por Números!"
            },
            "es-419": {
                "title": "Mosaico: Pintar por Número",
                "short_description": "¡Coloca azulejos de cerámica y crea mosaicos! Juego relajante sin conexión.",
                "full_description": "¡Bienvenido a Mosaico: Pintar por Números! Diseña increíbles mosaicos de azulejos vidriados y mandalas tradicionales pieza por pieza. ¡100% sin conexión!\n\n🏺 CARACTERÍSTICAS\n• Galería de mandalas, soles aztecas y patrones geométricos.\n• Azulejos de cerámica realistas con textura y relieve.\n• 100% Sin Conexión a internet.\n• Efecto ASMR agradable al encajar las teselas.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Mosaico: Pintar por Números!"
            },
            "pt-BR": {
                "title": "Mosaico: Pintar por Número",
                "short_description": "Monte mosaicos de azulejos cerâmicos por número! Relaxante e 100% offline.",
                "full_description": "Bem-vindo ao Mosaico: Pintar por Número! Monte azulejos brilhantes e crie mandalas deslumbrantes. 100% offline para relaxar quando quiser!\n\n🏺 DESTAQUES\n• Mandalas, sóis astecas e vitrais belíssimos.\n• Azulejos brilhantes com rejunte realista.\n• 100% Offline sem internet.\n• Som ASMR tátil e satisfatório.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Mosaico: Pintar por Número!"
            },
            "ru-RU": {
                "title": "Мозаика: По Номерам",
                "short_description": "Выкладывайте керамическую мозаику и мандалы по номерам! Релакс офлайн.",
                "full_description": "Добро пожаловать в игру «Мозаика: По Номерам»! Выкладывайте глянцевые керамические плитки и создавайте великолепные мандалы и витражи. 100% офлайн!\n\n🏺 ОСОБЕННОСТИ\n• Узоры мандал, солнца и кельтские мотивы.\n• Глянцевые плитки с реалистичными швами.\n• 100% Офлайн без интернета.\n• Приятные щелчки плитки ASMR.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Мозаика: По Номерам!"
            }
        }
    },

    "glow": {
        "package_name": "com.tenhead.glowart",
        "bg_colors": ((25, 12, 45), (10, 10, 20)),        # Dark cyber violet to void black
        "accent_gold": (255, 230, 80),
        "cream": (255, 245, 240),
        "tagline_main": "Insert glowing neon light pegs",
        "tagline_sub": "on dark boards with luminous bloom.",
        "icon_file": "glow.png",
        "palette_chips": [
            ("1", (0, 235, 255)),
            ("2", (255, 0, 130)),
            ("3", (0, 255, 100)),
            ("4", (255, 230, 0)),
            ("5", (170, 70, 255)),
            ("6", (255, 255, 255)),
        ],
        "locales": {
            "en-US": {
                "title": "Glow Art: Light by Number",
                "short_description": "Insert glowing neon light pegs on dark boards. Radiant relaxing color by number!",
                "full_description": """Welcome to Glow Art: Light by Number — the most luminous neon pegboard and Lite-Brite style coloring game! Step into a darkened room and watch your screen ignite with electric cyan, neon magenta, radioactive green, and laser gold. Insert radiant light pegs into dark grid holes to illuminate retro arcade sprites, glowing comets, cyber animals, and cosmic nebulae. 100% offline!

Whether you loved retro light pegboards as a child or want a visually striking, high-contrast dark mode coloring experience, Glow Art illuminates your world.

---

💡 A RADIANT NEON LIGHT GALLERY

• Cosmic & Celestial: Aurora skies, shooting comets, glowing crescent moons, and constellations.
• Cyber & Retro Arcade: Astro kitties, retro gamepads, neon signs, and glowing jellyfish.
• Radiant Nature: Bioluminescent mushrooms, fireflies in bottles, and glowing butterflies.
• Neon Bloom Peg Shader: Glowing translucent acrylic pegs on a dark pegboard with soft radial bloom.

✨ WHY YOU'LL LOVE GLOW ART

• 100% Offline: Light up your screen on night flights, in bed, or on the go with zero data needed.
• Popping ASMR Audio: Crisp, light pop clicks as each neon peg illuminates.
• Eye-Friendly Dark Mode: Beautiful dark contrast that is gentle on your eyes in low light.
• Zen Overdrive: Maintain streaks to trigger shimmering chromatic rainbow pulses.

Download Glow Art: Light by Number today and light up your night!""",
                "whats_new": "Welcome to the initial release of Glow Art: Light by Number! Enjoy glowing neon light pegs, radiant bloom shaders, and offline dark mode coloring."
            },
            "de-DE": {
                "title": "Glow Art: Leuchten nach Zahl",
                "short_description": "Stecken Sie leuchtende Neon-Stifte auf dunkle Tafeln! Entspannung offline.",
                "full_description": "Willkommen bei Glow Art: Leuchten nach Zahlen – dem leuchtenden Neon-Steckspiel! Stecken Sie leuchtende Stifte in dunkle Platten und lassen Sie Kunstwerke im Dunkeln strahlen. 100% offline!\n\n💡 FUNKTIONEN\n• Leuchtende Motive: Weltall, Neon-Tiere & Schilder.\n• Strahlender Neon-Glow-Shader auf dunklem Grund.\n• 100% Offline spielbar ohne Internet.\n• Angenehmer Klick-Sound beim Einstecken.\n\nJetzt Glow Art herunterladen!",
                "whats_new": "Erstveröffentlichung von Glow Art: Leuchten nach Zahlen!"
            },
            "fr-FR": {
                "title": "Glow Art: Lumière par Numéro",
                "short_description": "Insérez des pions néon lumineux sur fond sombre ! Coloriage zen et éclatant.",
                "full_description": "Bienvenue dans Glow Art: Lumière par Numéro ! Donnez vie à des comètes, méduses et animaux cybernétiques grâce à des picots néon étincelants. 100% hors ligne !\n\n💡 CARACTÉRISTIQUES\n• Magnifiques motifs cosmiques et néon.\n• Effet de lueur et halo lumineux saisissant.\n• 100% Hors Ligne sans Wi-Fi.\n• Mode sombre relaxant pour les yeux.\n\nTéléchargez dès aujourd'hui !",
                "whats_new": "Lancement initial de Glow Art: Lumière par Numéro !"
            },
            "es-ES": {
                "title": "Glow Art: Luz por Número",
                "short_description": "¡Inserta clavijas de luz neón brillante! Juego relajante con modo oscuro.",
                "full_description": "¡Bienvenido a Glow Art: Luz por Números! Ilumina tu pantalla colocando clavijas de neón brillante sobre tableros oscuros. ¡100% sin conexión!\n\n💡 CARACTERÍSTICAS\n• Diseños de galaxias, animales luminosos y estilo retro.\n• Brillo neón radiante con efectos de luz espectaculares.\n• 100% Sin Conexión a internet.\n• Modo oscuro perfecto para la noche.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Glow Art: Luz por Números!"
            },
            "es-419": {
                "title": "Glow Art: Luz por Número",
                "short_description": "¡Inserta clavijas de luz neón brillante! Juego relajante con modo oscuro.",
                "full_description": "¡Bienvenido a Glow Art: Luz por Números! Ilumina tu pantalla colocando clavijas de neón brillante sobre tableros oscuros. ¡100% sin conexión!\n\n💡 CARACTERÍSTICAS\n• Diseños de galaxias, animales luminosos y estilo retro.\n• Brillo neón radiante con efectos de luz espectaculares.\n• 100% Sin Conexión a internet.\n• Modo oscuro perfecto para la noche.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Glow Art: Luz por Números!"
            },
            "pt-BR": {
                "title": "Glow Art: Luz por Número",
                "short_description": "Encaixe pinos de luz neon em tabuleiros escuros! Brilhante, relaxante e offline.",
                "full_description": "Bem-vindo ao Glow Art: Luz por Número! Crie artes vibrantes encaixando pinos de luz neon sobre fundo escuro. 100% offline para jogar quando quiser!\n\n💡 DESTAQUES\n• Incríveis ilustrações espaciais e cyberpunk.\n• Efeito neon radiante com brilho luminoso.\n• 100% Offline sem internet.\n• Modo escuro ideal para jogar à noite.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Glow Art: Luz por Número!"
            },
            "ru-RU": {
                "title": "Glow Art: Свет по Номерам",
                "short_description": "Вставляйте светящиеся неоновые фишки в темное поле! Сияющая релакс-игра.",
                "full_description": "Добро пожаловать в игру «Glow Art: Свет по Номерам»! Зажигайте экран неоновыми светящимися фишками, создавая яркие космические картины и ретро-арт. 100% офлайн!\n\n💡 ОСОБЕННОСТИ\n• Неоновые мотивы: космос, кибер-животные и кометы.\n• Эффект мягкого неонового свечения на черном фоне.\n• 100% Офлайн без интернета.\n• Приятный темный режим для глаз.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Glow Art: Свет по Номерам!"
            }
        }
    },

    "sticker": {
        "package_name": "com.tenhead.stickerart",
        "bg_colors": ((235, 95, 95), (48, 25, 55)),       # Coral peach to plum purple
        "accent_gold": (255, 215, 65),
        "cream": (255, 246, 238),
        "tagline_main": "Place glossy vinyl die-cut stickers",
        "tagline_sub": "into charming scrapbook pages.",
        "icon_file": "sticker.png",
        "palette_chips": [
            ("1", (255, 110, 130)),
            ("2", (255, 195, 60)),
            ("3", (90, 205, 180)),
            ("4", (135, 120, 230)),
            ("5", (255, 255, 255)),
            ("6", (50, 45, 60)),
        ],
        "locales": {
            "en-US": {
                "title": "Sticker Art: Stick by Number",
                "short_description": "Place glossy vinyl stickers to complete cute scrapbooks. Satisfying ASMR art!",
                "full_description": """Welcome to Sticker Art: Stick by Number — the most aesthetic vinyl sticker book and scrapbooking puzzle game! Open your scrapbook and bring adorable stickers to life one glossy tile at a time. Tap the numbers, place your die-cut sticker badges, and watch cute avocados, friendly axolotls, boba tea cups, and retro badges pop off the page with realistic white rims and drop shadows. 100% offline!

Whether you collect stickers on your laptop, love bullet journaling, or simply want a relaxing, colorful art game, Sticker Art satisfies your inner collector.

---

🏷️ AN ADORABLE STICKER BOOK GALLERY

• Kawaii Food & Snacks: Boba milk tea, smiling avocados, glazed donuts, and iced coffees.
• Cute Animals: Axolotls, corgi dogs, sleeping bear faces, and cartoon capybaras.
• Aesthetic Badges: Retro motel keychains, holographic rainbows, and camping badges.
• Glossy Vinyl Shader: Crisp white die-cut borders, glossy plastic highlights, and subtle peel drop shadows.

✨ WHY YOU'LL LOVE STICKER ART

• 100% Offline: Complete scrapbook pages anywhere without internet connection.
• Satisfying Sticker Slap Audio: Tactile, crisp sound as each sticker presses firmly into place.
• Zen Overdrive: Chain consecutive stickers to activate prismatic sparkles and diamond awards.
• Share Finished Sheets: Export completed sticker sheets to share with friends.

Download Sticker Art: Stick by Number today and fill your scrapbook with joy!""",
                "whats_new": "Welcome to the initial release of Sticker Art: Stick by Number! Enjoy glossy vinyl die-cut stickers, crisp white border rims, and offline scrapbooking fun."
            },
            "de-DE": {
                "title": "Sticker Art: Kleben nach Zahl",
                "short_description": "Kleben Sie glänzende Sticker in Ihr Album nach Zahlen! Entspannt offline.",
                "full_description": "Willkommen bei Sticker Art: Kleben nach Zahlen – dem bunten Stickerbuch-Spiel! Füllen Sie Ihr Sammelalbum mit niedlichen Stickern: Axolotl, Boba-Tee und Tieren. 100% offline!\n\n🏷️ FUNKTIONEN\n• Niedliche Sticker-Motive: Kawaii, Tiere & Essen.\n• Hochglänzender Vinyl-Look mit weißem Rand.\n• 100% Offline spielbar ohne Internet.\n• Schmatzendes Klick-Geräusch beim Aufkleben.\n\nJetzt Sticker Art herunterladen!",
                "whats_new": "Erstveröffentlichung von Sticker Art: Kleben nach Zahlen!"
            },
            "fr-FR": {
                "title": "Sticker Art: Coller Numéro",
                "short_description": "Collez de superbes autocollants vinyle par numéro ! Jeu créatif et relaxant.",
                "full_description": "Bienvenue dans Sticker Art: Coller par Numéro ! Remplissez votre carnet d'autocollants kawaii : boba tea, animaux et badges rétro. 100% hors ligne !\n\n🏷️ CARACTÉRISTIQUES\n• Planches d'autocollants adorables et colorées.\n• Rendu vinyle brillant avec contour blanc découpé.\n• 100% Hors Ligne sans Wi-Fi.\n• Sons tactiles d'adhésif très satisfaisants.\n\nTéléchargez dès aujourd'hui !",
                "whats_new": "Lancement initial de Sticker Art: Coller par Numéro !"
            },
            "es-ES": {
                "title": "Pegatinas: Pegar por Número",
                "short_description": "¡Pega stickers de vinilo brillante por número! Álbum creativo sin conexión.",
                "full_description": "¡Bienvenido a Pegatinas: Pegar por Números! Completa álbumes de stickers adorables: axolotes, té boba y comida kawaii pieza por pieza. ¡100% sin conexión!\n\n🏷️ CARACTERÍSTICAS\n• Álbum lleno de pegatinas hermosas y coloridas.\n• Textura de vinilo brillante con borde blanco.\n• 100% Sin Conexión a internet.\n• Sonidos ASMR satisfactorios al pegar.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Pegatinas: Pegar por Números!"
            },
            "es-419": {
                "title": "Pegatinas: Pegar por Número",
                "short_description": "¡Pega stickers de vinilo brillante por número! Álbum creativo sin conexión.",
                "full_description": "¡Bienvenido a Pegatinas: Pegar por Números! Completa álbumes de stickers adorables: axolotes, té boba y comida kawaii pieza por pieza. ¡100% sin conexión!\n\n🏷️ CARACTERÍSTICAS\n• Álbum lleno de pegatinas hermosas y coloridas.\n• Textura de vinilo brillante con borde blanco.\n• 100% Sin Conexión a internet.\n• Sonidos ASMR satisfactorios al pegar.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Pegatinas: Pegar por Números!"
            },
            "pt-BR": {
                "title": "Sticker Art: Colar por Número",
                "short_description": "Cole adesivos de vinil brilhantes no álbum! Jogo adorável e 100% offline.",
                "full_description": "Bem-vindo ao Sticker Art: Colar por Número! Complete seu álbum de figurinhas com artes fofas de animais, comidas e ícones kawaii. 100% offline para se divertir onde quiser!\n\n🏷️ DESTAQUES\n• Lindas figurinhas para colecionar.\n• Textura de vinil brilhante com contorno branco.\n• 100% Offline sem internet.\n• Sons táteis e divertidos ao colar.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Sticker Art: Colar por Número!"
            },
            "ru-RU": {
                "title": "Наклейки: По Номерам",
                "short_description": "Вклеивайте яркие виниловые стикеры по номерам в альбом! Весело и офлайн.",
                "full_description": "Добро пожаловать в игру «Наклейки: По Номерам»! Заполняйте свой альбом милыми виниловыми стикерами: аниме-котиками, боба-чаем и значками. 100% офлайн!\n\n🏷️ ОСОБЕННОСТИ\n• Огромный выбор милых стикеров.\n• Глянцевый виниловый вид с белым контуром.\n• 100% Офлайн без интернета.\n• Приятный звук наклеивания стикеров.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Наклейки: По Номерам!"
            }
        }
    },

    "quilt": {
        "package_name": "com.tenhead.quiltart",
        "bg_colors": ((125, 38, 52), (38, 22, 26)),       # Rustic burgundy to dark chocolate
        "accent_gold": (255, 212, 110),
        "cream": (255, 245, 230),
        "tagline_main": "Piece together textured fabric swatches",
        "tagline_sub": "with running stitch seams into quilts.",
        "icon_file": "quilt.png",
        "palette_chips": [
            ("1", (180, 50, 70)),
            ("2", (230, 160, 60)),
            ("3", (95, 140, 95)),
            ("4", (65, 105, 155)),
            ("5", (245, 235, 215)),
            ("6", (55, 45, 45)),
        ],
        "locales": {
            "en-US": {
                "title": "Quilt Art: Sew by Number",
                "short_description": "Piece textured fabric swatches with running stitch seams. Cozy offline craft!",
                "full_description": """Welcome to Quilt Art: Sew by Number — the coziest patchwork quilt and fabric craft coloring game! Enter an heirloom sewing studio filled with calico prints, linen squares, gingham checks, and vintage embroidery threads. Piece together beautiful flower wreaths, autumn acorns, desert cacti, and argyle blankets swatch by swatch. Tap the numbers, sew your patches, and watch your quilt blossom. 100% offline!

Whether you love traditional quilting bees, textile arts, or simply want a warm, calming game to slow down and unwind, Quilt Art stitches peace into your day.

---

🧵 A TIMELESS GALLERY OF QUILT BLOCKS

• Rustic Florals & Wreaths: Blossom wreaths, lavender sprigs, and cottage roses.
• Autumn Harvest & Nature: Acorns, woodland mushrooms, maple leaves, and desert cacti.
• Classic Quilt Geometry: Argyle squares, star blocks, log cabins, and pinwheels.
• Textured Fabric Swatch Shader: Woven textile grain, calico patterns, and delicate running stitch seams.

✨ WHY YOU'LL LOVE QUILT ART

• 100% Offline: Sew cozy patchwork blankets anywhere without internet.
• Soft Fabric ASMR Audio: Gentle, soothing textile taps that relax your senses.
• Zen Overdrive: Chain consecutive stitches for radiant prismatic flourishes and diamond rewards.
• Time-Lapse Replay: Watch your finished heirloom quilt stitch itself from raw fabric to masterwork.

Download Quilt Art: Sew by Number today and stitch yourself a blanket of peace!""",
                "whats_new": "Welcome to the initial release of Quilt Art: Sew by Number! Enjoy realistic patchwork fabric swatches, running stitch seams, and cozy offline sewing."
            },
            "de-DE": {
                "title": "Patchwork: Nähen nach Zahl",
                "short_description": "Nähen Sie bunte Stoffmuster nach Zahlen zu Quilts zusammen! Gemütlich offline.",
                "full_description": "Willkommen bei Patchwork: Nähen nach Zahlen – dem traditionellen Quilt- und Stoffspiel! Nähen Sie Blumenkränze, Decken und Muster Stück für Stück zusammen. 100% offline!\n\n🧵 FUNKTIONEN\n• Wunderschöne Quilt-Muster: Blumen, Natur & Rauten.\n• Realistische Webstoff-Textur mit Nahtoptik.\n• 100% Offline spielbar ohne Internet.\n• Beruhigende, weiche ASMR-Sounds.\n\nJetzt Patchwork herunterladen!",
                "whats_new": "Erstveröffentlichung von Patchwork: Nähen nach Zahlen!"
            },
            "fr-FR": {
                "title": "Patchwork: Coudre par Numéro",
                "short_description": "Assemblez des morceaux de tissu par numéro pour créer des plaids ! Détente.",
                "full_description": "Bienvenue dans Patchwork: Coudre par Numéro ! Donnez vie à de superbes courtepointes, couronnes florales et motifs campagnards morceau par morceau. 100% hors ligne !\n\n🧵 CARACTÉRISTIQUES\n• Magnifiques blocs de courtepointe et motifs rétro.\n• Rendu réaliste de tissus avec coutures apparentes.\n• 100% Hors Ligne sans Wi-Fi.\n• Ambiance ASMR douce et chaleureuse.\n\nTéléchargez dès aujourd'hui !",
                "whats_new": "Lancement initial de Patchwork: Coudre par Numéro !"
            },
            "es-ES": {
                "title": "Patchwork: Coser por Número",
                "short_description": "¡Cose retazos de tela por número y crea colchas! Juego acogedor sin conexión.",
                "full_description": "¡Bienvenido a Patchwork: Coser por Números! Une hermosos retazos de tela para crear colchas tradicionales y tapices puntada a puntada. ¡100% sin conexión!\n\n🧵 CARACTERÍSTICAS\n• Galería de patrones florales, hojas de otoño y cuadros.\n• Textura de tela tejida con costuras realistas.\n• 100% Sin Conexión a internet.\n• Sonidos ASMR suaves y acogedores.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Patchwork: Coser por Números!"
            },
            "es-419": {
                "title": "Patchwork: Coser por Número",
                "short_description": "¡Cose retazos de tela por número y crea colchas! Juego acogedor sin conexión.",
                "full_description": "¡Bienvenido a Patchwork: Coser por Números! Une hermosos retazos de tela para crear colchas tradicionales y tapices puntada a puntada. ¡100% sin conexión!\n\n🧵 CARACTERÍSTICAS\n• Galería de patrones florales, hojas de otoño y cuadros.\n• Textura de tela tejida con costuras realistas.\n• 100% Sin Conexión a internet.\n• Sonidos ASMR suaves y acogedores.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Patchwork: Coser por Números!"
            },
            "pt-BR": {
                "title": "Patchwork: Costura por Número",
                "short_description": "Junte retalhos de tecido por número e crie colchas! Acolhedor e offline.",
                "full_description": "Bem-vindo ao Patchwork: Costura por Número! Monte retalhos de tecido estampado e crie colchas tradicionais cheias de charme. 100% offline para costurar com tranquilidade!\n\n🧵 DESTAQUES\n• Padrões florais, folhas de outono e mantas acolhedoras.\n• Textura realista de tecido de algodão com pesponto.\n• 100% Offline sem internet.\n• ASMR suave e relaxante.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Patchwork: Costura por Número!"
            },
            "ru-RU": {
                "title": "Лоскутное Шитьё: По Номерам",
                "short_description": "Сшивайте лоскутные одеяла из ткани по номерам! Тёплое рукоделие офлайн.",
                "full_description": "Добро пожаловать в игру «Лоскутное Шитьё: По Номерам»! Соединяйте кусочки хлопковой ткани со строчками и создавайте уютные пледы и цветочные венки. 100% офлайн!\n\n🧵 ОСОБЕННОСТИ\n• Узоры одеял: цветы, осенние листья и геометрия.\n• Реалистичная ткань со стежками.\n• 100% Офлайн без интернета.\n• Мягкие, умиротворяющие звуки ASMR.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Лоскутное Шитьё: По Номерам!"
            }
        }
    },

    "voxel": {
        "package_name": "com.tenhead.voxelart",
        "bg_colors": ((18, 75, 115), (14, 20, 32)),       # Isometric cyan/slate to dark void
        "accent_gold": (255, 215, 60),
        "cream": (245, 248, 255),
        "tagline_main": "Color & extrude 3D voxel blocks",
        "tagline_sub": "with dynamic lights into miniature worlds.",
        "icon_file": "voxel.png",
        "palette_chips": [
            ("1", (40, 160, 240)),
            ("2", (240, 85, 95)),
            ("3", (50, 200, 120)),
            ("4", (255, 190, 40)),
            ("5", (160, 80, 230)),
            ("6", (35, 40, 50)),
        ],
        "locales": {
            "en-US": {
                "title": "Voxel Art: 3D Color by Number",
                "short_description": "Color and extrude 3D voxel blocks with lights. Build miniature pixel worlds!",
                "full_description": """Welcome to Voxel Art: 3D Color by Number — the ultimate isometric 3D voxel coloring and block building sandbox! Step into a captivating dimensional world where you paint and extrude 3D voxel cubes cube by cube. Color delicious pixel burgers, cosmic astro kitties, cute axolotls, and glowing amethyst geodes with realistic directional lighting, ambient shading, and beveled block edges. 100% offline!

Whether you love voxel sandbox games, isometric architecture, or simply want a fresh 3D twist on color by number, Voxel Art brings your artwork to life with depth and dimension.

---

🧊 A 3D VOXEL DIORAMA GALLERY

• Miniature Worlds & Animals: Astro kitties, smiling axolotls, frogs, and Shiba dogs.
• Delicious 3D Food: Isometric stacked burgers, ice cream sundaes, and sushi platters.
• Glowing Crystals & Gems: Amethyst geode clusters, emerald prisms, and neon cubes.
• Isometric Voxel Block Shader: Extruded 3D cubes with realistic top highlights, side shading, and bevels.

✨ WHY YOU'LL LOVE VOXEL ART

• 100% Offline: Color full 3D voxel scenes anywhere on flights or commutes without Wi-Fi.
• Satisfying ASMR Audio: Crisp cube tap sound as each voxel locks into the 3D grid.
• Zen Overdrive: Maintain coloring streaks to trigger glowing chromatic edges and bonus diamond gifts.
• 3D Time-Lapse Replay: Watch your voxel world extrude and paint itself layer by layer.

Download Voxel Art: 3D Color by Number today and build your 3D pixel universe!""",
                "whats_new": "Welcome to the initial release of Voxel Art: 3D Color by Number! Enjoy extruded 3D isometric voxel blocks, dynamic lighting, and offline dimensional coloring."
            },
            "de-DE": {
                "title": "Voxel 3D: Malen nach Zahlen",
                "short_description": "Färben Sie 3D-Voxel-Blöcke nach Zahlen! Bunte dreidimensionale Welten offline.",
                "full_description": "Willkommen bei Voxel 3D: Malen nach Zahlen – dem isometrischen 3D-Färbespiel! Bauen und färben Sie Voxel-Blöcke zu 3D-Szenen: Burger, Kätzchen und Kristalle. 100% offline!\n\n🧊 FUNKTIONEN\n• Hunderte isometrische 3D-Voxel-Modelle.\n• Realistischer 3D-Shader mit Licht & Schatten.\n• 100% Offline spielbar ohne Internet.\n• Taktile ASMR-Klicks beim Platzieren der Blöcke.\n\nJetzt Voxel 3D herunterladen!",
                "whats_new": "Erstveröffentlichung von Voxel 3D: Malen nach Zahlen!"
            },
            "fr-FR": {
                "title": "Voxel 3D: Couleur par Numéro",
                "short_description": "Coloriez des cubes 3D en voxel par numéro ! Mondes miniatures hors ligne.",
                "full_description": "Bienvenue dans Voxel 3D: Couleur par Numéro ! Donnez vie à des dioramas en 3D cube par cube : animaux mignons, burgers et géodes lumineuses. 100% hors ligne !\n\n🧊 CARACTÉRISTIQUES\n• Superbes modèles isométriques 3D.\n• Rendu volumétrique avec lumières et ombres.\n• 100% Hors Ligne sans Wi-Fi.\n• Sons ASMR satisfaisants à chaque cube posé.\n\nTéléchargez dès aujourd'hui !",
                "whats_new": "Lancement initial de Voxel 3D: Couleur par Numéro !"
            },
            "es-ES": {
                "title": "Voxel 3D: Pintar por Número",
                "short_description": "¡Colorea cubos 3D voxel por número! Construye mundos en miniatura sin conexión.",
                "full_description": "¡Bienvenido a Voxel 3D: Pintar por Números! Descubre una nueva dimensión coloreando bloques voxel en 3D. Crea dioramas de animales, comida y cristales. ¡100% sin conexión!\n\n🧊 CARACTERÍSTICAS\n• Galería de increíbles modelos 3D isométricos.\n• Iluminación realista con sombras y relieve.\n• 100% Sin Conexión a internet.\n• Efecto ASMR agradable al colocar los cubos.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Voxel 3D: Pintar por Números!"
            },
            "es-419": {
                "title": "Voxel 3D: Pintar por Número",
                "short_description": "¡Colorea cubos 3D voxel por número! Construye mundos en miniatura sin conexión.",
                "full_description": "¡Bienvenido a Voxel 3D: Pintar por Números! Descubre una nueva dimensión coloreando bloques voxel en 3D. Crea dioramas de animales, comida y cristales. ¡100% sin conexión!\n\n🧊 CARACTERÍSTICAS\n• Galería de increíbles modelos 3D isométricos.\n• Iluminación realista con sombras y relieve.\n• 100% Sin Conexión a internet.\n• Efecto ASMR agradable al colocar los cubos.\n\n¡Descarga hoy!",
                "whats_new": "¡Lanzamiento inicial de Voxel 3D: Pintar por Números!"
            },
            "pt-BR": {
                "title": "Voxel 3D: Pintar por Número",
                "short_description": "Pinte blocos 3D voxel por número! Construa mundos em miniatura offline.",
                "full_description": "Bem-vindo ao Voxel 3D: Pintar por Número! Pinte e monte cubos voxel em 3D com iluminação realista. Dê vida a bichinhos fofos, hambúrgueres e cristais. 100% offline!\n\n🧊 DESTAQUES\n• Incríveis dioramas em 3D isométrico.\n• Sombras e iluminação volumétrica realista.\n• 100% Offline sem internet.\n• Sons táteis e relaxantes de ASMR.\n\nBaixe agora mesmo!",
                "whats_new": "Lançamento inicial de Voxel 3D: Pintar por Número!"
            },
            "ru-RU": {
                "title": "Voxel 3D: По Номерам",
                "short_description": "Раскрашивайте 3D-воксели по номерам! Изометрические миры и диорамы офлайн.",
                "full_description": "Добро пожаловать в игру «Voxel 3D: По Номерам»! Раскрашивайте трехмерные воксельные кубы кубик за кубиком: милых животных, бургеры и кристаллы. 100% офлайн!\n\n🧊 ОСОБЕННОСТИ\n• Увлекательные изометрические 3D-модели.\n• Реалистичное освещение и тени кубов.\n• 100% Офлайн без интернета.\n• Приятные щелчки кубиков ASMR.\n\nСкачайте прямо сейчас!",
                "whats_new": "Первый релиз игры Voxel 3D: По Номерам!"
            }
        }
    }
}

# --------------------------------------------------------------------------
# Image Generation Helpers
# --------------------------------------------------------------------------
def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

def create_radial_gradient(size, center_color, edge_color, cx=0.28, cy=0.50, power=0.9):
    w, h = size
    img = Image.new("RGB", size)
    pixels = img.load()
    max_dist = math.hypot(max(cx, 1 - cx) * w, max(cy, 1 - cy) * h)
    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx * w, y - cy * h) / max_dist
            factor = min(1.0, max(0.0, dist)) ** power
            pixels[x, y] = lerp_color(center_color, edge_color, factor)
    return img

def draw_sunburst(draw, cx, cy, radius, rays=48, color=(255, 255, 255, 14)):
    step = 2 * math.pi / rays
    for i in range(0, rays, 2):
        a1 = i * step
        a2 = (i + 1) * step
        p1 = (cx, cy)
        p2 = (cx + math.cos(a1) * radius, cy + math.sin(a1) * radius)
        p3 = (cx + math.cos(a2) * radius, cy + math.sin(a2) * radius)
        draw.polygon([p1, p2, p3], fill=color)

def draw_shadowed_text(draw, pos, text, font, fill, shadow_color=(0, 0, 0, 180), offset=(2, 3)):
    x, y = pos
    draw.text((x + offset[0], y + offset[1]), text, font=font, fill=shadow_color)
    draw.text((x, y), text, font=font, fill=fill)

def generate_feature_graphic(flavor_name, cfg, out_path):
    W, H = 1024, 500
    c_inner, c_outer = cfg["bg_colors"]
    img = create_radial_gradient((W, H), c_inner, c_outer, cx=0.27, cy=0.50, power=0.88).convert("RGBA")
    draw = ImageDraw.Draw(img, "RGBA")

    # Subtle ambient rays
    draw_sunburst(draw, W * 0.25, H * 0.50, W * 0.70, rays=56, color=(255, 255, 255, 12))

    # --- Left Panel: Framed Canvas with Icon & Numbered Palette Strip ---
    icon_src = os.path.join(ICONS_DIR, cfg["icon_file"])
    if os.path.exists(icon_src):
        icon_orig = Image.open(icon_src).convert("RGBA")
    else:
        icon_orig = Image.new("RGBA", (320, 320), cfg["accent_gold"] + (255,))

    board_size = 280
    board_img = icon_orig.resize((board_size, board_size), Image.Resampling.LANCZOS)

    pad = 22
    panel_w = board_size + pad * 2
    panel_h = board_size + pad * 2 + 50
    px, py = 46, (H - panel_h) // 2

    # Panel glow shadow
    glow_box = Image.new("RGBA", (panel_w + 50, panel_h + 50), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_box)
    glow_draw.rounded_rectangle([15, 15, panel_w + 35, panel_h + 35], radius=24, fill=(0, 0, 0, 130))
    glow_box = glow_box.filter(ImageFilter.GaussianBlur(14))
    img.alpha_composite(glow_box, (px - 25, py - 25))

    # Panel background
    panel = Image.new("RGBA", (panel_w, panel_h), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(panel)
    p_draw.rounded_rectangle([0, 0, panel_w - 1, panel_h - 1], radius=22,
                             fill=(250, 248, 244, 255), outline=(255, 255, 255, 90), width=2)
    img.alpha_composite(panel, (px, py))

    # Paste board
    img.alpha_composite(board_img, (px + pad, py + pad))

    # Palette strip under board
    chips = cfg["palette_chips"]
    chip_w, chip_h = 36, 32
    gap = 8
    total_chips_w = len(chips) * chip_w + (len(chips) - 1) * gap
    sx = px + (panel_w - total_chips_w) // 2
    sy = py + pad + board_size + 10

    chip_font = ImageFont.truetype(SANS_BOLD, 15)
    for i, (num_str, chip_rgb) in enumerate(chips):
        cx = sx + i * (chip_w + gap)
        draw.rounded_rectangle([cx, sy, cx + chip_w, sy + chip_h], radius=7,
                               fill=chip_rgb + (255,), outline=(0, 0, 0, 50), width=1)
        tw = draw.textlength(num_str, font=chip_font)
        bb = chip_font.getbbox(num_str)
        th = bb[3] - bb[1]
        lum = 0.299 * chip_rgb[0] + 0.587 * chip_rgb[1] + 0.114 * chip_rgb[2]
        t_col = (30, 30, 30, 255) if lum > 140 else (255, 255, 255, 240)
        draw.text((cx + (chip_w - tw) / 2, sy + (chip_h - th) / 2 - bb[1]),
                  num_str, font=chip_font, fill=t_col)

    # --- Right Side: Brand Titles & Taglines ---
    tx = 440
    title_text = cfg["locales"]["en-US"]["title"]
    # Parse title parts: e.g. "Brick Art" and ": Build by Number"
    parts = title_text.split(":", 1)
    brand_name = parts[0].strip()
    tag_suffix = parts[1].strip() if len(parts) > 1 else "Color by Number"

    title_font = ImageFont.truetype(SERIF_BOLD, 50)
    draw_shadowed_text(draw, (tx, 88), brand_name, title_font, cfg["accent_gold"], offset=(3, 4))

    sub_font = ImageFont.truetype(SANS_BOLD, 30)
    draw_shadowed_text(draw, (tx, 154), tag_suffix, sub_font, cfg["cream"], offset=(2, 3))

    div_y = 208
    draw.line([(tx, div_y), (W - 50, div_y)], fill=(255, 255, 255, 60), width=2)

    body_font = ImageFont.truetype(SANS_REG, 23)
    draw_shadowed_text(draw, (tx, 230), cfg["tagline_main"], body_font, (245, 240, 230), offset=(1, 2))
    draw_shadowed_text(draw, (tx, 264), cfg["tagline_sub"], body_font, (245, 240, 230), offset=(1, 2))

    # Feature badges
    badge_y = 330
    badges = ["100% Offline", "Satisfying ASMR", "Zen Overdrive"]
    bx = tx
    badge_font = ImageFont.truetype(SANS_BOLD, 15)
    for b_text in badges:
        bw = draw.textlength(b_text, font=badge_font) + 24
        draw.rounded_rectangle([bx, badge_y, bx + bw, badge_y + 36], radius=18,
                               fill=(0, 0, 0, 90), outline=cfg["accent_gold"] + (180,), width=1)
        draw.text((bx + 12, badge_y + 9), b_text, font=badge_font, fill=cfg["accent_gold"])
        bx += bw + 12

    # Save 1024x500 RGB PNG
    img.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"Generated feature graphic: {out_path} (1024x500)")

# --------------------------------------------------------------------------
# Main Execution
# --------------------------------------------------------------------------
def main():
    print("=" * 65)
    print("Generating Store Metadata & Store Assets for 8 New Flavors")
    print("=" * 65)

    for flavor, cfg in FLAVORS.items():
        print(f"\nProcessing flavor: {flavor} ({cfg['package_name']})...")

        # 1. Write fastlane/Metadata.<flavor>.json
        json_path = os.path.join(FASTLANE_DIR, f"Metadata.{flavor}.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(cfg["locales"], f, indent=2, ensure_ascii=False)
        print(f"  -> Saved {json_path}")

        # 2. Sync text files into fastlane/metadata/<flavor>/android/<locale>/
        for locale, l_data in cfg["locales"].items():
            loc_dir = os.path.join(METADATA_DIR, flavor, "android", locale)
            os.makedirs(loc_dir, exist_ok=True)

            mapping = {
                "title.txt": l_data.get("title", ""),
                "short_description.txt": l_data.get("short_description", ""),
                "full_description.txt": l_data.get("full_description", ""),
                "whats_new.txt": l_data.get("whats_new", ""),
            }
            for filename, content in mapping.items():
                if content:
                    with open(os.path.join(loc_dir, filename), "w", encoding="utf-8") as tf:
                        tf.write(content.strip())

        print(f"  -> Synced {len(cfg['locales'])} locales to {os.path.join(METADATA_DIR, flavor, 'android')}")

        # 3. Store assets in fastlane/metadata/<flavor>/android/en-US/images/
        img_dir = os.path.join(METADATA_DIR, flavor, "android", "en-US", "images")
        os.makedirs(img_dir, exist_ok=True)

        # Copy 512x512 icon
        icon_src = os.path.join(ICONS_DIR, cfg["icon_file"])
        icon_dst = os.path.join(img_dir, "icon.png")
        if os.path.exists(icon_src):
            shutil.copyfile(icon_src, icon_dst)
            print(f"  -> Copied 512x512 icon: {icon_dst}")

        # Generate 1024x500 feature graphic
        fg_dst = os.path.join(img_dir, "featureGraphic.png")
        generate_feature_graphic(flavor, cfg, fg_dst)

    print("\n" + "=" * 65)
    print("All 8 flavor metadata JSONs, text files, and graphics created successfully!")
    print("=" * 65)

if __name__ == "__main__":
    main()

