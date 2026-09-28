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

// Signed distance to a line segment from A to B
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

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

    // Corner needle puncture holes (eyelets where threads enter cloth)
    vec2 cTL = vec2(0.10, 0.10);
    vec2 cTR = vec2(0.90, 0.10);
    vec2 cBL = vec2(0.10, 0.90);
    vec2 cBR = vec2(0.90, 0.90);

    float dHoleTL = length(cellUV - cTL);
    float dHoleTR = length(cellUV - cTR);
    float dHoleBL = length(cellUV - cBL);
    float dHoleBR = length(cellUV - cBR);
    float dHole = min(min(dHoleTL, dHoleTR), min(dHoleBL, dHoleBR));

    float holeRadius = 0.040;
    float holeMask = 1.0 - smoothstep(holeRadius - aa, holeRadius + aa, dHole);
    vec3 emptyHoleColor = vec3(0.90, 0.90, 0.90); // Delicate eyelet on white cloth
    fabric = mix(fabric, emptyHoleColor, holeMask * 0.35);

    // Hairline grid border between cells
    vec2 borderThresh = vec2(0.12 / cellSize.x, 0.12 / cellSize.y);
    bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                        cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);

    // ================================================================
    // CELL STATE ROUTING
    // ================================================================

    // Empty cell -> clean white fabric with subtle needle holes
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
        vec3 gridFabric = isCellBorder ? vec3(0.92, 0.92, 0.92) : fabric;
        fragColor = vec4(mix(preview, gridFabric, fade), 1.0);
        return;
    }

    // ================================================================
    // FILLED CELL -> CRISP 3D CROSS STITCH RENDERING
    // ================================================================

    // Zoomed out LOD (< 7.0): Flat colored tile
    if (uEffectiveCell < 7.0) {
        fragColor = vec4(cellColor.rgb, 1.0);
        return;
    }

    // --- Fill-animation timeline ---
    float age = texture(uFillAge, texUV).r * 1.6 + uTime;

    // Vibrant, rich thread colors
    vec3 threadColor = cellColor.rgb;
    vec3 threadLight = min(threadColor * 1.25 + vec3(0.06), vec3(1.0));
    vec3 threadDark = threadColor * 0.58;
    vec3 sheenColor = min(threadColor * 1.40 + vec3(0.15), vec3(1.0));

    // ================================================================
    // STITCH CELL BACKGROUND: Very light pastel tint of the stitch color
    // ================================================================
    vec3 stitchCellBg = mix(fabric, threadColor, 0.10);
    vec3 stitchHoleColor = mix(stitchCellBg * 0.80, vec3(0.70, 0.70, 0.70), 0.30);
    stitchCellBg = mix(stitchCellBg, stitchHoleColor, holeMask * 0.30);

    // Anchor endpoints (centered in corner eyelets)
    vec2 TL = cTL;
    vec2 BR = cBR;
    vec2 BL = cBL;
    vec2 TR = cTR;

    // Thread thickness with subtle center bulge for top thread
    float baseThreadW = 0.135;
    float distToCenter = length(cellUV - vec2(0.5));
    float centerElevation = clamp(1.0 - distToCenter / 0.35, 0.0, 1.0);

    float threadW1 = baseThreadW;
    float threadW2 = baseThreadW * (1.0 + 0.06 * centerElevation);

    // Distance to diagonal line segments
    float d1 = sdSegment(cellUV, TL, BR);
    float d2 = sdSegment(cellUV, BL, TR);

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
            float bounce = 1.0 + 0.05 * sin(st * 3.14159);
            threadW1 *= bounce;
            threadW2 *= bounce;
        }
    }

    // Razor-sharp stroke masks (1 screen pixel anti-aliasing)
    vec2 dir1 = BR - TL;
    float len1 = length(dir1);
    float prog1 = dot(cellUV - TL, dir1 / len1) / len1;
    float revealCut1 = smoothstep(stroke1Progress - 0.06, stroke1Progress, prog1);
    float stroke1 = (1.0 - smoothstep(threadW1 - aa, threadW1 + aa, d1)) * (1.0 - revealCut1);

    vec2 dir2 = TR - BL;
    float len2 = length(dir2);
    float prog2 = dot(cellUV - BL, dir2 / len2) / len2;
    float revealCut2 = smoothstep(stroke2Progress - 0.06, stroke2Progress, prog2);
    float stroke2 = (1.0 - smoothstep(threadW2 - aa, threadW2 + aa, d2)) * (1.0 - revealCut2);

    float stitchMask = max(stroke1, stroke2);

    // ================================================================
    // TRUE 3D CYLINDRICAL THREAD SHADING & DIRECTIONAL LIGHT
    // ================================================================
    vec2 shift = vec2(-0.5 - uTilt.x * 0.3, -0.5 + uTilt.y * 0.3);
    shift = clamp(shift, vec2(-1.0), vec2(1.0));
    vec2 lightDir = normalize(-shift);

    // --- Stroke 1 (Bottom thread \) ---
    float r1 = clamp(d1 / max(threadW1, 0.001), 0.0, 1.0);
    float dome1 = sqrt(max(0.0, 1.0 - r1 * r1)); // 3D cylinder dome
    vec2 n1_flat = normalize(vec2(-(BR.y - TL.y), BR.x - TL.x));
    vec2 p1_cross = (cellUV - TL) - dot(cellUV - TL, dir1 / len1) * (dir1 / len1);
    float side1 = sign(dot(p1_cross, n1_flat));
    float light1 = clamp(dot(n1_flat * (side1 * r1), lightDir) * 0.40 + dome1 * 0.60 + 0.15, 0.0, 1.0);

    float twist1 = sin(prog1 * 28.0) * 0.5 + 0.5;
    vec3 thread1Base = mix(threadDark, threadLight, light1) * (0.93 + 0.07 * twist1);
    float sheen1 = pow(clamp(1.0 - d1 / (threadW1 * 0.45), 0.0, 1.0), 2.2);

    // --- Stroke 2 (Top thread /) ---
    float r2 = clamp(d2 / max(threadW2, 0.001), 0.0, 1.0);
    float dome2 = sqrt(max(0.0, 1.0 - r2 * r2)); // 3D cylinder dome
    vec2 n2_flat = normalize(vec2(-(TR.y - BL.y), TR.x - BL.x));
    vec2 p2_cross = (cellUV - BL) - dot(cellUV - BL, dir2 / len2) * (dir2 / len2);
    float side2 = sign(dot(p2_cross, n2_flat));
    float light2 = clamp(dot(n2_flat * (side2 * r2), lightDir) * 0.40 + dome2 * 0.60 + 0.20, 0.0, 1.0);

    float twist2 = sin(prog2 * 28.0 + 1.4) * 0.5 + 0.5;
    vec3 thread2Base = mix(threadDark, threadLight, light2) * (0.93 + 0.07 * twist2);
    float sheen2 = pow(clamp(1.0 - d2 / (threadW2 * 0.45), 0.0, 1.0), 2.2);
    sheen2 *= (1.0 + 0.30 * centerElevation);

    // --- Asymmetric Crossover Contact Shadow on Bottom-Right segment ---
    float crossoverContact = stroke2 * smoothstep(0.35, 0.65, prog1);
    thread1Base = mix(thread1Base, threadDark * 0.55, crossoverContact * 0.70);

    // --- Depth dipping into corner eyelets ---
    float holeDip1 = min(smoothstep(0.0, 0.10, prog1), smoothstep(1.0, 0.90, prog1));
    float holeDip2 = min(smoothstep(0.0, 0.10, prog2), smoothstep(1.0, 0.90, prog2));
    thread1Base *= mix(0.78, 1.0, holeDip1);
    thread2Base *= mix(0.80, 1.0, holeDip2);

    // ================================================================
    // CRISP TIGHT CONTACT DROP SHADOWS (2.5 screen pixels penumbra)
    // ================================================================
    vec2 shadowOffset = vec2(0.010, 0.014);
    float sd1_shadow = sdSegment(cellUV - shadowOffset, TL, BR);
    float sd2_shadow = sdSegment(cellUV - shadowOffset, BL, TR);

    float shadowPenumbra = aa * 2.5;
    float shadow1 = 1.0 - smoothstep(threadW1, threadW1 + shadowPenumbra, sd1_shadow);
    float shadow2 = 1.0 - smoothstep(threadW2, threadW2 + shadowPenumbra, sd2_shadow);

    // ================================================================
    // MULTI-LAYER COMPOSITING
    // Clean vector layering without muddy halos
    // ================================================================
    vec3 result = stitchCellBg;

    // 1. Bottom thread drop shadow (only outside the thread itself)
    float s1_active = stroke1Progress > 0.05 ? 1.0 : 0.0;
    result = mix(result, result * 0.68, shadow1 * 0.40 * s1_active * (1.0 - stroke1));

    // 2. Bottom thread (\) solid 3D cylinder
    result = mix(result, thread1Base, stroke1);

    // 3. Bottom thread core silk sheen
    result = mix(result, sheenColor, sheen1 * stroke1 * 0.45 * holeDip1);

    // 4. Top thread drop shadow (casts onto background and onto stroke 1)
    float s2_active = stroke2Progress > 0.05 ? 1.0 : 0.0;
    result = mix(result, result * 0.62, shadow2 * 0.45 * s2_active * (1.0 - stroke2));

    // 5. Top thread (/) solid 3D cylinder (completely covers stroke 1 at crossing)
    result = mix(result, thread2Base, stroke2);

    // 6. Top thread core silk sheen (vibrant all the way to TR)
    result = mix(result, sheenColor, sheen2 * stroke2 * 0.55 * holeDip2);

    // ================================================================
    // GLANCING SPECULAR GLINT ON TOP THREAD CROWN
    // ================================================================
    if (stroke2 > 0.01) {
        vec2 specPos = vec2(0.5) + shift * 0.08;
        float specDist = length(cellUV - specPos);
        if (specDist < 0.16) {
            float glint = smoothstep(0.16, 0.0, specDist);
            result = mix(result, vec3(1.0), glint * 0.22 * stroke2);
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
