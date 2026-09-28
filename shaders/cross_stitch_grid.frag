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

    // Sample the grid texture at the texel center for this cell
    vec2 texUV = (cellCoord + vec2(0.5)) / uGrid;
#ifdef IMPELLER_TARGET_OPENGLES
    texUV.y = 1.0 - texUV.y;
#endif
    vec4 cellColor = texture(uTexture, texUV);

    // ================================================================
    // RESOLUTION-INDEPENDENT CRISP PIXEL MATH
    // Uses uEffectiveCell (actual screen pixel size of each cell) so
    // anti-aliasing edges are exactly 1 screen pixel wide — never blurry!
    // ================================================================
    float pixSize = 1.0 / max(uEffectiveCell, 8.0);
    float aa = clamp(pixSize * 1.0, 0.0015, 0.015);

    // ================================================================
    // ARTWORK BACKGROUND (Clean pure white fabric with subtle weave)
    // ================================================================
    vec3 fabricBase = vec3(1.0, 1.0, 1.0);        // Pure clean white
    vec3 fabricDark = vec3(0.980, 0.980, 0.980);  // Subtle clean weave
    float weaveX = sin(cellUV.x * 3.14159 * 4.0) * 0.5 + 0.5;
    float weaveY = sin(cellUV.y * 3.14159 * 4.0) * 0.5 + 0.5;
    float weave = weaveX * 0.5 + weaveY * 0.5;
    vec3 fabric = mix(fabricDark, fabricBase, weave);

    // Cell square border (matching reference screenshot square frame)
    vec2 borderThresh = vec2(0.35 / cellSize.x, 0.35 / cellSize.y);
    bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                        cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);

    // ================================================================
    // CELL STATE ROUTING
    // ================================================================

    // Empty cell -> clean white fabric
    if (cellColor.a < 0.01) {
        fragColor = vec4(fabric, 1.0);
        return;
    }

    // Unfilled numbered cell -> soft preview fading to clean white grid at zoom
    if (cellColor.a < 0.75) {
        vec3 preview = cellColor.rgb / max(cellColor.a, 0.001);
        if (uEffectiveCell < 7.0) {
            vec3 ghostOnFabric = mix(vec3(1.0), preview, 0.35);
            fragColor = vec4(ghostOnFabric, 1.0);
            return;
        }
        float fade = clamp((uEffectiveCell - 7.0) / 6.0, 0.0, 1.0);
        vec3 gridFabric = isCellBorder ? vec3(0.85, 0.85, 0.85) : fabric;
        fragColor = vec4(mix(preview, gridFabric, fade), 1.0);
        return;
    }

    // ================================================================
    // FILLED CELL -> REALISTIC PLUMP EMBROIDERY FLOSS STITCH
    // Matches the reference: thick plump spindle shape (radius ~0.175),
    // tapered rounded ends, 4-5 fine twisted thread fibers,
    // top strand (\, TL->BR) crossing continuous over bottom strand (/, BL->TR)
    // with contact drop shadows and 3D cylindrical lighting.
    // ================================================================

    // Zoomed out LOD (< 7.0): Flat colored tile
    if (uEffectiveCell < 7.0) {
        fragColor = vec4(cellColor.rgb, 1.0);
        return;
    }

    // --- Fill-animation timeline ---
    float age = texture(uFillAge, texUV).r * 1.6 + uTime;

    // Rich thread colors
    vec3 threadColor = cellColor.rgb;
    vec3 threadLight = min(threadColor * 1.25 + vec3(0.06), vec3(1.0));
    vec3 threadDark = threadColor * 0.52;
    vec3 sheenColor = min(threadColor * 1.35 + vec3(0.12), vec3(1.0));

    // Stitch cell background: very light pastel tint of the stitch color
    vec3 stitchCellBg = mix(fabric, threadColor, 0.10);

    // ================================================================
    // PLUMP TAPERED EMBROIDERY STRAND GEOMETRY
    // ================================================================
    vec2 TL = vec2(0.11, 0.11);
    vec2 BR = vec2(0.89, 0.89);
    vec2 BL = vec2(0.11, 0.89);
    vec2 TR = vec2(0.89, 0.11);

    float maxRadius = 0.175; // Plump strand width (~0.35 of cell at middle)

    // --- Strand 1: Bottom Strand (/, BL to TR) ---
    vec2 dir1 = TR - BL;
    float len1 = length(dir1);
    vec2 udir1 = dir1 / len1;
    vec2 unorm1 = vec2(-udir1.y, udir1.x);

    float t1_raw = dot(cellUV - BL, udir1) / len1;
    float t1 = clamp(t1_raw, 0.0, 1.0);
    vec2 pt1 = BL + t1 * dir1;
    float d1 = length(cellUV - pt1);
    float s1 = dot(cellUV - pt1, unorm1);

    // Taper profile: swells to 1.0 at center, tapers to 0.65 at ends
    float taper1 = 0.65 + 0.35 * sin(t1 * 3.14159);
    float rad1 = maxRadius * taper1;

    // --- Strand 2: Top Strand (\, TL to BR) ---
    vec2 dir2 = BR - TL;
    float len2 = length(dir2);
    vec2 udir2 = dir2 / len2;
    vec2 unorm2 = vec2(-udir2.y, udir2.x);

    float t2_raw = dot(cellUV - TL, udir2) / len2;
    float t2 = clamp(t2_raw, 0.0, 1.0);
    vec2 pt2 = TL + t2 * dir2;
    float d2 = length(cellUV - pt2);
    float s2 = dot(cellUV - pt2, unorm2);

    float taper2 = 0.68 + 0.32 * sin(t2 * 3.14159);
    float rad2 = maxRadius * taper2;

    // ================================================================
    // FAST REVEAL ANIMATION (~260ms total)
    // ================================================================
    float stroke1Progress = 1.0;
    float stroke2Progress = 1.0;

    if (age < 0.26) {
        stroke1Progress = clamp(age / 0.12, 0.0, 1.0);
        stroke2Progress = clamp((age - 0.06) / 0.12, 0.0, 1.0);

        if (age > 0.16) {
            float st = clamp((age - 0.16) / 0.10, 0.0, 1.0);
            float bounce = 1.0 + 0.04 * sin(st * 3.14159);
            rad1 *= bounce;
            rad2 *= bounce;
        }
    }

    float revealCut1 = smoothstep(stroke1Progress - 0.06, stroke1Progress, t1);
    float stroke1 = (1.0 - smoothstep(rad1 - aa, rad1 + aa, d1)) * (1.0 - revealCut1);

    float revealCut2 = smoothstep(stroke2Progress - 0.06, stroke2Progress, t2);
    float stroke2 = (1.0 - smoothstep(rad2 - aa, rad2 + aa, d2)) * (1.0 - revealCut2);

    float stitchMask = max(stroke1, stroke2);

    // ================================================================
    // MULTI-STRAND TWISTED FLOSS FIBER TEXTURE (4-5 Parallel Strands)
    // Matches the reference: multiple fine parallel thread lines
    // curving gently along the length of each plump strand.
    // ================================================================
    float normS1 = s1 / max(rad1, 0.001);
    float fiberCoord1 = normS1 * 2.4 + (t1 - 0.5) * 0.45;
    float fiberWave1 = sin(fiberCoord1 * 3.14159 * 2.0);
    float fiberShade1 = 0.90 + 0.10 * fiberWave1;

    float normS2 = s2 / max(rad2, 0.001);
    float fiberCoord2 = normS2 * 2.4 - (t2 - 0.5) * 0.45;
    float fiberWave2 = sin(fiberCoord2 * 3.14159 * 2.0);
    float fiberShade2 = 0.90 + 0.10 * fiberWave2;

    // ================================================================
    // 3D CYLINDRICAL CUSHION SHADING & DIRECTIONAL LIGHT
    // ================================================================
    vec2 shift = vec2(-0.5 - uTilt.x * 0.3, -0.5 + uTilt.y * 0.3);
    shift = clamp(shift, vec2(-1.0), vec2(1.0));
    vec2 lightDir = normalize(-shift);

    // --- Strand 1 (Bottom, /) ---
    float r1 = clamp(d1 / max(rad1, 0.001), 0.0, 1.0);
    float dome1 = sqrt(max(0.0, 1.0 - r1 * r1)); // 3D rounded dome
    float lightDot1 = dot(unorm1 * normS1, lightDir);
    float light1 = clamp(lightDot1 * 0.35 + dome1 * 0.65 + 0.15, 0.0, 1.0);
    vec3 color1 = mix(threadDark, threadLight, light1) * fiberShade1;
    float sheen1 = pow(clamp(1.0 - abs(normS1) / 0.55, 0.0, 1.0), 2.2);
    sheen1 *= (0.75 + 0.25 * clamp(fiberWave1 * 0.5 + 0.5, 0.0, 1.0));

    // --- Strand 2 (Top, \) ---
    float r2 = clamp(d2 / max(rad2, 0.001), 0.0, 1.0);
    float dome2 = sqrt(max(0.0, 1.0 - r2 * r2)); // 3D rounded dome
    float lightDot2 = dot(unorm2 * normS2, lightDir);
    float light2 = clamp(lightDot2 * 0.35 + dome2 * 0.65 + 0.20, 0.0, 1.0);
    vec3 color2 = mix(threadDark, threadLight, light2) * fiberShade2;
    float sheen2 = pow(clamp(1.0 - abs(normS2) / 0.55, 0.0, 1.0), 2.2);
    sheen2 *= (0.75 + 0.25 * clamp(fiberWave2 * 0.5 + 0.5, 0.0, 1.0));
    // Center crown highlight on top strand
    float centerT2 = clamp(1.0 - abs(t2 - 0.5) / 0.30, 0.0, 1.0);
    sheen2 *= (1.0 + 0.25 * centerT2);

    // ================================================================
    // REALISTIC CONTACT DROP SHADOWS
    // Strand 2 (top) casts a distinct contact shadow onto Strand 1 (bottom)!
    // ================================================================
    vec2 shadowOffset = vec2(0.012, 0.016);

    // Shadow from Strand 1 onto background:
    vec2 pt1_sh = BL + clamp(dot(cellUV - shadowOffset - BL, udir1) / len1, 0.0, 1.0) * dir1;
    float d1_sh = length(cellUV - shadowOffset - pt1_sh);
    float rad1_sh = maxRadius * (0.65 + 0.35 * sin(clamp(dot(cellUV - shadowOffset - BL, udir1) / len1, 0.0, 1.0) * 3.14159));
    float shadow1 = 1.0 - smoothstep(rad1_sh, rad1_sh + aa * 2.5, d1_sh);

    // Shadow from Strand 2 onto background AND onto Strand 1 below it:
    vec2 pt2_sh = TL + clamp(dot(cellUV - shadowOffset - TL, udir2) / len2, 0.0, 1.0) * dir2;
    float d2_sh = length(cellUV - shadowOffset - pt2_sh);
    float rad2_sh = maxRadius * (0.68 + 0.32 * sin(clamp(dot(cellUV - shadowOffset - TL, udir2) / len2, 0.0, 1.0) * 3.14159));
    float shadow2 = 1.0 - smoothstep(rad2_sh, rad2_sh + aa * 2.5, d2_sh);

    // Contact shadow where Strand 1 ducks under Strand 2:
    float crossoverContact = stroke2 * smoothstep(0.35, 0.65, t1);
    color1 = mix(color1, threadDark * 0.50, crossoverContact * 0.75);

    // ================================================================
    // MULTI-LAYER COMPOSITING
    // ================================================================
    vec3 result = stitchCellBg;

    // 1. Bottom strand shadow onto background
    float s1_active = stroke1Progress > 0.05 ? 1.0 : 0.0;
    result = mix(result, result * 0.68, shadow1 * 0.40 * s1_active * (1.0 - stroke1));

    // 2. Bottom strand (/, BL to TR)
    result = mix(result, color1, stroke1);

    // 3. Bottom strand core silk sheen
    result = mix(result, sheenColor, sheen1 * stroke1 * 0.40);

    // 4. Top strand shadow (onto background AND onto bottom strand!)
    float s2_active = stroke2Progress > 0.05 ? 1.0 : 0.0;
    result = mix(result, result * 0.58, shadow2 * 0.48 * s2_active * (1.0 - stroke2));

    // 5. Top strand (\, TL to BR) - completely passes over bottom strand!
    result = mix(result, color2, stroke2);

    // 6. Top strand core silk sheen
    result = mix(result, sheenColor, sheen2 * stroke2 * 0.52);

    // 7. Subtle cell frame border (like the reference screenshot)
    if (isCellBorder) {
        result = mix(result, vec3(0.18, 0.18, 0.18), 0.25);
    }

    // ================================================================
    // GLANCING SPECULAR GLINT ON TOP THREAD CROWN
    // ================================================================
    if (stroke2 > 0.01) {
        vec2 specPos = vec2(0.5) + shift * 0.08;
        float specDist = length(cellUV - specPos);
        if (specDist < 0.16) {
            float glint = smoothstep(0.16, 0.0, specDist);
            result = mix(result, vec3(1.0), glint * 0.20 * stroke2);
        }
    }

    // ================================================================
    // FAST AFTERGLOW & GLINT SWEEP (~260ms)
    // ================================================================
    if (age < 0.28) {
        float glow = 1.0 - clamp(age / 0.24, 0.0, 1.0);
        result = mix(result, vec3(1.0, 0.98, 0.92), glow * glow * 0.15 * stitchMask);

        if (age > 0.08 && age < 0.22) {
            float gt = clamp((age - 0.08) / 0.14, 0.0, 1.0);
            float gpos = (cellUV.x + cellUV.y) * 0.5;
            float sweep = mix(-0.2, 1.2, gt);
            float d = abs(gpos - sweep);
            if (d < 0.08) {
                float streak = 1.0 - d / 0.08;
                result = mix(result, vec3(1.0), streak * streak * 0.30 * (1.0 - gt) * stitchMask);
            }
        }
    }

    // ================================================================
    // SECTION-COMPLETE SHIMMER (golden thread sweep)
    // ================================================================
    if (uShimmer > 0.001 && uShimmer < 0.999) {
        float q = (pos.x + pos.y * 0.35) / (uSize.x + uSize.y * 0.35);
        float band = mix(-0.2, 1.2, uShimmer);
        float bd = abs(q - band);
        if (bd < 0.09) {
            float s = 1.0 - bd / 0.09;
            vec3 shimmerColor = mix(vec3(1.0), vec3(1.0, 0.92, 0.7), 0.5);
            result = mix(result, shimmerColor, s * s * 0.40 * stitchMask);
        }
    }

    fragColor = vec4(result, 1.0);
}
