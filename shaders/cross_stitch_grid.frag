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

    // Cell square border (clean frame)
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

    // Unfilled numbered cell -> direct transition from color to grey-out (no white gap)
    if (cellColor.a < 0.75) {
        vec3 color = cellColor.rgb / max(cellColor.a, 0.001);
        float luminance = dot(color, vec3(0.299, 0.587, 0.114));
        vec3 gray = vec3(clamp(0.62 + luminance * 0.32, 0.62, 0.94));
        float t = clamp((uEffectiveCell - 7.0) / 7.0, 0.0, 1.0);
        vec3 cellBody = mix(color, gray, t);
        if (isCellBorder && t > 0.1) {
            cellBody = mix(cellBody, vec3(0.82, 0.82, 0.82), t);
        }
        fragColor = vec4(cellBody, 1.0);
        return;
    }

    // ================================================================
    // FILLED CELL -> REALISTIC PLUMP EMBROIDERY FLOSS STITCH
    // Matches the reference: thick plump spindle shape,
    // fully rounded symmetrical ends reaching corners (never cut off!),
    // 5 fine twisted thread fibers with 3D cylindrical volume,
    // top strand (\, TL->BR) crossing continuous over bottom strand (/, BL->TR)
    // with contact drop shadows and satin silk luster.
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
    vec3 threadLight = min(threadColor * 1.28 + vec3(0.06), vec3(1.0));
    vec3 threadDark = threadColor * 0.48;
    vec3 sheenColor = min(threadColor * 1.38 + vec3(0.14), vec3(1.0));

    // Stitch cell background: very light pastel tint of the stitch color
    vec3 stitchCellBg = mix(fabric, threadColor, 0.10);

    // ================================================================
    // ================================================================
    // FULL CORNER-TO-CORNER ANCHORS
    // Ensures all four ends (TL, TR, BL, BR) extend fully into the corners
    // ================================================================
    vec2 TL = vec2(0.05, 0.05);
    vec2 BR = vec2(0.95, 0.95);
    vec2 BL = vec2(0.05, 0.95);
    vec2 TR = vec2(0.95, 0.05);

    float maxRadius = 0.178; // Plump strand width (~0.36 of cell at middle)

    // Corner eyelets on fabric (subtle punctures where threads anchor)
    float cornerHole = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 hpos = vec2(i == 1 || i == 3 ? 0.95 : 0.05, i >= 2 ? 0.95 : 0.05);
        float hdist = length(cellUV - hpos);
        if (hdist < 0.07) {
            cornerHole = max(cornerHole, smoothstep(0.07, 0.02, hdist) * 0.22);
        }
    }
    stitchCellBg = mix(stitchCellBg, vec3(0.12, 0.12, 0.12), cornerHole);

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

    // Taper profile: swells smoothly to 1.0 at center, tapers to 0.66 at ends
    float taper1 = 0.66 + 0.34 * sin(t1 * 3.14159265);
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

    float taper2 = 0.68 + 0.32 * sin(t2 * 3.14159265);
    float rad2 = maxRadius * taper2;

    // ================================================================
    // ANIMATION & REVEAL (Never cuts off finished threads!)
    // When age >= 0.26 (normal settled state), revealCut is strictly 0.0!
    // ================================================================
    float revealCut1 = 0.0;
    float revealCut2 = 0.0;
    float s1_active = 1.0;
    float s2_active = 1.0;

    if (age < 0.26) {
        float p1 = clamp(age / 0.12, 0.0, 1.0);
        float p2 = clamp((age - 0.06) / 0.12, 0.0, 1.0);

        s1_active = p1 > 0.05 ? 1.0 : 0.0;
        s2_active = p2 > 0.05 ? 1.0 : 0.0;

        // Animate reveal leading edge; sweeps past 1.0 to 1.25 so at 100%
        // the tips at TR and BR are never chopped!
        float edge1 = p1 * 1.25;
        if (edge1 < 1.15) {
            revealCut1 = smoothstep(edge1 - 0.08, edge1, t1);
        }

        float edge2 = p2 * 1.25;
        if (edge2 < 1.15) {
            revealCut2 = smoothstep(edge2 - 0.08, edge2, t2);
        }

        if (age > 0.16) {
            float st = clamp((age - 0.16) / 0.10, 0.0, 1.0);
            float bounce = 1.0 + 0.04 * sin(st * 3.14159265);
            rad1 *= bounce;
            rad2 *= bounce;
        }
    }

    // Strand silhouettes with razor-sharp 1-pixel anti-aliasing
    float stroke1 = (1.0 - smoothstep(rad1 - aa, rad1 + aa, d1)) * (1.0 - revealCut1);
    float stroke2 = (1.0 - smoothstep(rad2 - aa, rad2 + aa, d2)) * (1.0 - revealCut2);

    float stitchMask = max(stroke1, stroke2);

    // ================================================================
    // TACTILE MULTI-STRAND EMBROIDERY FIBERS (Helical Stranded Floss)
    // Curving twisted filaments along each plump strand!
    // ================================================================
    float normS1 = s1 / max(rad1, 0.001);
    float twist1 = normS1 * 3.2 + (t1 - 0.5) * 1.8;
    float filament1 = sin(twist1 * 6.2831853);
    float fiberShade1 = 0.84 + 0.16 * filament1;

    float normS2 = s2 / max(rad2, 0.001);
    float twist2 = normS2 * 3.2 - (t2 - 0.5) * 1.8;
    float filament2 = sin(twist2 * 6.2831853);
    float fiberShade2 = 0.84 + 0.16 * filament2;

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
    float light1 = clamp(lightDot1 * 0.35 + dome1 * 0.65 + 0.18, 0.0, 1.0);
    vec3 color1 = mix(threadDark, threadLight, light1) * fiberShade1;
    float sheen1 = pow(clamp(1.0 - abs(normS1) / 0.55, 0.0, 1.0), 2.5);
    sheen1 *= (0.70 + 0.30 * clamp(filament1 * 0.5 + 0.5, 0.0, 1.0));

    // Corner eyelet depth dipping (soft tuck into hole)
    float dip1 = min(smoothstep(0.0, 0.12, t1), smoothstep(1.0, 0.88, t1));
    color1 *= (0.84 + 0.16 * dip1);

    // --- Strand 2 (Top, \) ---
    float r2 = clamp(d2 / max(rad2, 0.001), 0.0, 1.0);
    float dome2 = sqrt(max(0.0, 1.0 - r2 * r2)); // 3D rounded dome
    float lightDot2 = dot(unorm2 * normS2, lightDir);
    float light2 = clamp(lightDot2 * 0.35 + dome2 * 0.65 + 0.22, 0.0, 1.0);
    vec3 color2 = mix(threadDark, threadLight, light2) * fiberShade2;
    float sheen2 = pow(clamp(1.0 - abs(normS2) / 0.55, 0.0, 1.0), 2.5);
    sheen2 *= (0.70 + 0.30 * clamp(filament2 * 0.5 + 0.5, 0.0, 1.0));
    // Center crown highlight on top strand
    float centerT2 = clamp(1.0 - abs(t2 - 0.5) / 0.28, 0.0, 1.0);
    sheen2 *= (1.0 + 0.35 * centerT2);

    float dip2 = min(smoothstep(0.0, 0.12, t2), smoothstep(1.0, 0.88, t2));
    color2 *= (0.84 + 0.16 * dip2);

    // ================================================================
    // REALISTIC CONTACT DROP SHADOWS
    // Top strand (\) casts a distinct contact shadow onto bottom strand (/)!
    // ================================================================
    vec2 shadowOffset = vec2(0.012, 0.016);

    // Shadow from Strand 1 onto background:
    vec2 pt1_sh = BL + clamp(dot(cellUV - shadowOffset - BL, udir1) / len1, 0.0, 1.0) * dir1;
    float d1_sh = length(cellUV - shadowOffset - pt1_sh);
    float rad1_sh = maxRadius * (0.66 + 0.34 * sin(clamp(dot(cellUV - shadowOffset - BL, udir1) / len1, 0.0, 1.0) * 3.14159265));
    float shadow1 = 1.0 - smoothstep(rad1_sh, rad1_sh + aa * 2.5, d1_sh);

    // Shadow from Strand 2 onto background AND onto Strand 1 below it:
    vec2 pt2_sh = TL + clamp(dot(cellUV - shadowOffset - TL, udir2) / len2, 0.0, 1.0) * dir2;
    float d2_sh = length(cellUV - shadowOffset - pt2_sh);
    float rad2_sh = maxRadius * (0.68 + 0.32 * sin(clamp(dot(cellUV - shadowOffset - TL, udir2) / len2, 0.0, 1.0) * 3.14159265));
    float shadow2 = 1.0 - smoothstep(rad2_sh, rad2_sh + aa * 2.5, d2_sh);

    // Contact shadow where Strand 1 ducks under Strand 2:
    float crossoverContact = stroke2 * smoothstep(0.32, 0.68, t1);
    color1 = mix(color1, threadDark * 0.45, crossoverContact * 0.80);

    // ================================================================
    // MULTI-LAYER COMPOSITING
    // ================================================================
    vec3 result = stitchCellBg;

    // 1. Bottom strand shadow onto background
    result = mix(result, result * 0.65, shadow1 * 0.40 * s1_active * (1.0 - stroke1));

    // 2. Bottom strand (/, BL to TR)
    result = mix(result, color1, stroke1);

    // 3. Bottom strand core silk sheen
    result = mix(result, sheenColor, sheen1 * stroke1 * 0.42);

    // 4. Top strand shadow (onto background AND onto bottom strand!)
    result = mix(result, result * 0.55, shadow2 * 0.48 * s2_active * (1.0 - stroke2));

    // 5. Top strand (\, TL to BR) - completely passes over bottom strand!
    result = mix(result, color2, stroke2);

    // 6. Top strand core silk sheen
    result = mix(result, sheenColor, sheen2 * stroke2 * 0.48);

    // 7. Subtle cell frame border (like the reference screenshot)
    if (isCellBorder) {
        result = mix(result, vec3(0.18, 0.18, 0.18), 0.22);
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
