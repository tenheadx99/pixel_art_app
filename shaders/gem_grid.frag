#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uGrid;
uniform vec2 uTilt;
uniform float uEffectiveCell;
// Seconds elapsed since the fill-age texture was last baked; added to each
// cell's encoded age so animations advance without texture rebuilds.
uniform float uTime;
// Section-complete shimmer progress: 0..1 sweeps one bright band across the
// board; values at/outside the ends mean inactive.
uniform float uShimmer;
uniform sampler2D uTexture;
// Per-cell fill age at bake time, encoded in the red channel over a 1.6s
// window (1.0 = long since finished animating).
uniform sampler2D uFillAge;

out vec4 fragColor;

void main() {
    vec2 pos = FlutterFragCoord().xy;
    
    // Cell size in canvas pixels
    vec2 cellSize = uSize / uGrid;
    
    // Grid cell coordinate (column, row)
    vec2 cellCoord = floor(pos / cellSize);
    
    // Bounds check
    if (cellCoord.x < 0.0 || cellCoord.x >= uGrid.x || cellCoord.y < 0.0 || cellCoord.y >= uGrid.y) {
        fragColor = vec4(0.0);
        return;
    }

    // Normalized UV inside current cell [0, 1]
    vec2 cellUV = fract(pos / cellSize);
    
    // Hairline Cell Outline Border (0.18 threshold = ultra-thin 0.36px grid line)
    vec2 borderThresh = vec2(0.18 / cellSize.x, 0.18 / cellSize.y);
    bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                        cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);


    // Sample the grid texture at the texel center for this cell. The image is
    // built with toImageSync and sampled top-left-origin, matching
    // FlutterFragCoord — no orientation fixup needed. (A previous "Y-flip
    // fallback" here re-sampled the mirrored texel for empty cells, which
    // painted every fill onto its vertically mirrored cell as well.)
    vec2 texUV = (cellCoord + vec2(0.5)) / uGrid;
#ifdef IMPELLER_TARGET_OPENGLES
    // On Impeller's OpenGLES backend sampled images are vertically flipped
    // (see the texture-sampling note in Flutter's fragment-shader docs), so
    // flip the row lookup only for that backend. Never "detect" the flip at
    // runtime by re-sampling the mirrored texel: that renders every fill at
    // both its real and mirrored cell.
    texUV.y = 1.0 - texUV.y;
#endif
    vec4 cellColor = texture(uTexture, texUV);

    // The grid texture encodes each cell's state in alpha:
    //   a == 0.0  -> empty cell (no number in the artwork)
    //   a ~= 0.5  -> unfilled numbered cell; rgb holds the grayscale preview
    //   a == 1.0  -> filled cell; rgb holds the fill color
    // This lets the shader render every zoom level (including the zoomed-out
    // "ghost" preview), so the CPU never re-bakes the grid on fills.

    // Empty cell -> plain background, no border.
    if (cellColor.a < 0.01) {
        fragColor = vec4(1.0);
        return;
    }

    // Unfilled numbered cell -> preview ghost, fading to white grid at zoom.
    if (cellColor.a < 0.75) {
        // Texture samples are premultiplied; recover the straight color.
        vec3 preview = cellColor.rgb / max(cellColor.a, 0.001);
        // Zoomed Out LOD (< 10.0): complete artwork ghost preview
        if (uEffectiveCell < 10.0) {
            fragColor = vec4(preview, 1.0);
            return;
        }
        // Zoomed In LOD (>= 10.0): fade to clean white with hairline grid
        float fade = clamp((uEffectiveCell - 10.0) / 6.0, 0.0, 1.0);
        vec3 bgWhite = isCellBorder ? vec3(0.82, 0.82, 0.82) : vec3(1.0, 1.0, 1.0);
        fragColor = vec4(mix(preview, bgWhite, fade), 1.0);
        return;
    }

    // Hairline Grid Border between filled gems
    if (isCellBorder) {
        fragColor = vec4(0.82, 0.82, 0.82, 1.0);
        return;
    }

    // Filled Gem -> Full 3D Faceted Cushion Diamond Drill
    vec2 center = vec2(0.5);

    // Low LOD (< 10.0): Flat Square Tile (no animation while zoomed out —
    // cells are a handful of pixels, so the timeline would read as noise).
    if (uEffectiveCell < 10.0) {
        fragColor = vec4(cellColor.rgb, 1.0);
        return;
    }

    // --- Fill-animation timeline -------------------------------------------
    // Seconds since this cell was filled. Cells filled long ago read >= 1.6
    // and skip every animation branch. Swiped cells carry naturally staggered
    // ages, so a stroke blooms in as a wave behind the finger for free.
    float age = texture(uFillAge, texUV).r * 1.6 + uTime;

    // Settle pop: the gem scales 0.68 -> ~1.04 -> 1.0 (ease-out-back) over
    // 240ms. Implemented by expanding the local UV around the cell center;
    // fragments that fall outside the shrunken gem show the clean canvas.
    vec2 uv = cellUV;
    if (age < 0.24) {
        float t0 = clamp(age / 0.24, 0.0, 1.0);
        float u = t0 - 1.0;
        float ease = 1.0 + 2.70158 * u * u * u + 1.70158 * u * u;
        float scale = mix(0.68, 1.0, ease);
        uv = center + (cellUV - center) / max(scale, 0.01);
        vec2 od = abs(uv - center);
        if (max(od.x, od.y) > 0.5) {
            fragColor = vec4(isCellBorder ? vec3(0.82, 0.82, 0.82) : vec3(1.0), 1.0);
            return;
        }
    }

    vec2 dir = uv - center;
    float dist = length(dir);
    vec2 absDir = abs(dir);

    // Light Direction vector with Accelerometer Tilt
    vec2 shift = vec2(-0.707 - uTilt.x * 0.40, -0.707 + uTilt.y * 0.40);
    shift = clamp(shift, vec2(-1.20), vec2(1.20));
    vec2 lightDir = normalize(-shift);

    vec3 lightShade = min(cellColor.rgb + vec3(0.42), vec3(1.0));
    vec3 darkShade = cellColor.rgb * 0.50;

    // --- 1. Octagonal Table Cut & 8 Facet Sector Geometry ---
    // Octagonal distance from center for real diamond drill shape
    float octDist = max(max(absDir.x, absDir.y), (absDir.x + absDir.y) * 0.7071);
    bool isTable = octDist < 0.165;

    // Angle of current fragment (-PI to PI)
    float angle = atan(dir.y, dir.x);
    
    // 8 Facet Sectors (0..7) around 360 degrees
    float sectorIndex = floor((angle + 3.14159265 + 0.392699) / 0.785398);
    float sectorAngle = (sectorIndex + 0.5) * 0.785398 - 3.14159265;
    vec2 facetNormal = vec2(cos(sectorAngle), sin(sectorAngle));

    // Per-facet lighting dot product (creates sharp light/shade steps between facets)
    float lightDot = dot(facetNormal, lightDir);
    float facetIntensity = mix(0.70, 1.28, lightDot * 0.5 + 0.5);

    vec3 baseColor;
    if (isTable) {
        // Flat Table Facet (Top center octagonal cut)
        float tableLight = clamp(dot(vec2(0.0, 0.0), lightDir) * 0.2 + 1.15, 1.0, 1.30);
        baseColor = min(cellColor.rgb * tableLight, vec3(1.0));
    } else {
        // Crown Facet Body with stepped lighting contrast
        baseColor = clamp(cellColor.rgb * facetIntensity, darkShade, lightShade);
    }

    // --- 2. Crisp Facet Seams & Octagonal Table Border ---
    if (uEffectiveCell >= 14.0) {
        // Octagonal Table Border Line
        float tableBorderDist = abs(octDist - 0.165);
        if (tableBorderDist < 0.015) {
            float bGlint = clamp(lightDot * 0.5 + 0.5, 0.3, 1.0);
            baseColor = mix(baseColor, vec3(1.0), 0.35 * bGlint);
        }

        // Radial Facet Seams (Lines between 8 crown facets)
        float facetEdge = abs(fract((angle + 3.14159265) / 0.785398) - 0.5);
        if (facetEdge < 0.035 && octDist >= 0.165 && max(absDir.x, absDir.y) < 0.44) {
            // Bright seam on light-facing side, shadow seam on dark side
            if (lightDot > 0.0) {
                baseColor = mix(baseColor, vec3(1.0), 0.28);
            } else {
                baseColor = mix(baseColor, darkShade * 0.4, 0.35);
            }
        }
    }

    // --- 3. 3D Cushion Outer Bevel & Edge Shadows ---
    float maxEdge = max(absDir.x, absDir.y);
    if (maxEdge > 0.38) {
        float bevelT = smoothstep(0.38, 0.48, maxEdge);
        // Top-left facing edges get crisp rim highlight; bottom-right get deep shadow
        float edgeDirDot = dot(normalize(dir), lightDir);
        if (edgeDirDot > 0.2) {
            baseColor = mix(baseColor, lightShade, bevelT * 0.45);
        } else {
            baseColor = mix(baseColor, darkShade * 0.35, bevelT * 0.65);
        }
    }

    // --- 4. Refractive Specular Sparkle & Pinpoint Star Glints ---
    vec2 specPos = center + shift * 0.16;
    float specDist = length(uv - specPos);

    // Sharp Primary Specular Glint on Top Facet Edge
    if (specDist < 0.18) {
        float halo = smoothstep(0.18, 0.0, specDist);
        baseColor = mix(baseColor, vec3(1.0), halo * 0.50);
    }
    if (specDist < 0.07) {
        float core = smoothstep(0.07, 0.0, specDist);
        baseColor = mix(baseColor, vec3(1.0), core * 0.90);
    }

    // 4-Point Micro Star Flare Glint (Zoom >= 20.0)
    if (uEffectiveCell >= 20.0 && specDist < 0.22) {
        vec2 specDir = abs(uv - specPos);
        if ((specDir.x < 0.015 && specDir.y < 0.16) || (specDir.y < 0.015 && specDir.x < 0.16)) {
            float crossIntensity = smoothstep(0.16, 0.0, max(specDir.x, specDir.y));
            baseColor = mix(baseColor, vec3(1.0), crossIntensity * 0.85);
        }
    }

    // Afterglow + glint sweep: a warm landing flash that fades over 450ms,
    // and one bright diagonal streak crossing the face between 150-500ms.
    if (age < 0.55) {
        float glow = 1.0 - clamp(age / 0.45, 0.0, 1.0);
        baseColor = mix(baseColor, vec3(1.0, 0.97, 0.88), glow * glow * 0.30);
        if (age > 0.15) {
            float gt = clamp((age - 0.15) / 0.35, 0.0, 1.0);
            float gpos = (uv.x + uv.y) * 0.5;
            float sweep = mix(-0.25, 1.25, gt);
            float d = abs(gpos - sweep);
            if (d < 0.14) {
                float streak = 1.0 - d / 0.14;
                baseColor = mix(baseColor, vec3(1.0), streak * streak * 0.6 * (1.0 - gt));
            }
        }
    }

    // Section-complete shimmer: one skewed bright band sweeping every placed
    // gem, driven by a 0..1 progress uniform (inactive at the ends).
    if (uShimmer > 0.001 && uShimmer < 0.999) {
        float q = (pos.x + pos.y * 0.35) / (uSize.x + uSize.y * 0.35);
        float band = mix(-0.2, 1.2, uShimmer);
        float bd = abs(q - band);
        if (bd < 0.09) {
            float s = 1.0 - bd / 0.09;
            baseColor = mix(baseColor, vec3(1.0), s * s * 0.45);
        }
    }

    fragColor = vec4(baseColor, 1.0);
}
