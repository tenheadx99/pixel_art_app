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

// Pseudo-random noise for subtle organic cloth variation
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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
    // ARTWORK BACKGROUND (Clean pure white aida fabric)
    // ================================================================
    vec3 fabricBase = vec3(1.0, 1.0, 1.0);        // Pure clean white
    vec3 fabricDark = vec3(0.975, 0.975, 0.975);  // Subtle weave texture

    // Aida cloth weave pattern: horizontal and vertical thread crossings
    float weaveX = sin(cellUV.x * 3.14159 * 4.0) * 0.5 + 0.5;
    float weaveY = sin(cellUV.y * 3.14159 * 4.0) * 0.5 + 0.5;
    float weave = weaveX * 0.5 + weaveY * 0.5;
    float noise = hash(cellCoord) * 0.015;
    vec3 fabric = mix(fabricDark, fabricBase, weave) + vec3(noise);

    // Corner needle puncture holes (eyelets where threads enter cloth)
    vec2 cTL = vec2(0.09, 0.09);
    vec2 cTR = vec2(0.91, 0.09);
    vec2 cBL = vec2(0.09, 0.91);
    vec2 cBR = vec2(0.91, 0.91);

    float dHoleTL = length(cellUV - cTL);
    float dHoleTR = length(cellUV - cTR);
    float dHoleBL = length(cellUV - cBL);
    float dHoleBR = length(cellUV - cBR);
    float dHole = min(min(dHoleTL, dHoleTR), min(dHoleBL, dHoleBR));

    float aa = 1.5 / max(cellSize.x, cellSize.y);
    float holeRadius = 0.055;
    float holeMask = 1.0 - smoothstep(holeRadius - aa, holeRadius + aa * 1.5, dHole);
    vec3 emptyHoleColor = vec3(0.86, 0.86, 0.86); // Soft grey puncture on white cloth
    fabric = mix(fabric, emptyHoleColor, holeMask * 0.35);

    // Hairline grid: subtle boundary between cells
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
        vec3 gridFabric = isCellBorder ? vec3(0.90, 0.90, 0.90) : fabric;
        fragColor = vec4(mix(preview, gridFabric, fade), 1.0);
        return;
    }

    // ================================================================
    // FILLED CELL -> CROSS STITCH RENDERING
    // ================================================================

    // Zoomed out LOD (< 7.0): Flat colored tile
    if (uEffectiveCell < 7.0) {
        fragColor = vec4(cellColor.rgb, 1.0);
        return;
    }

    // --- Fill-animation timeline ---
    float age = texture(uFillAge, texUV).r * 1.6 + uTime;

    // Base thread colors
    vec3 threadColor = cellColor.rgb;
    vec3 threadLight = min(threadColor * 1.18 + vec3(0.08), vec3(1.0));
    vec3 threadDark = threadColor * 0.62;
    vec3 sheenColor = min(threadColor * 1.32 + vec3(0.10), vec3(1.0));

    // ================================================================
    // STITCH CELL BACKGROUND: Very light pastel tint of the stitch color
    // ================================================================
    vec3 stitchCellBg = mix(fabric, threadColor, 0.14);
    vec3 stitchHoleColor = mix(stitchCellBg * 0.76, vec3(0.65, 0.65, 0.65), 0.35);
    stitchCellBg = mix(stitchCellBg, stitchHoleColor, holeMask * 0.35);

    // ================================================================
    // ASYMMETRIC CROSS STITCH GEOMETRY & LAYER ELEVATION
    // Stroke 1: Bottom thread (\) runs from TL -> BR (tucked under)
    // Stroke 2: Top thread (/) runs from BL -> TR (arches OVER)
    // The top thread is elevated, continuous, and casts a shadow on BR!
    // ================================================================
    vec2 TL = cTL;
    vec2 BR = cBR;
    vec2 BL = cBL;
    vec2 TR = cTR;

    // Thread thickness with organic center bulge for top thread
    float baseThreadW = 0.138;
    float distToCenter = length(cellUV - vec2(0.5));
    float centerElevation = clamp(1.0 - distToCenter / 0.38, 0.0, 1.0);

    // Bottom thread stays grounded, top thread bulges slightly at crossover
    float threadW1 = baseThreadW;
    float threadW2 = baseThreadW * (1.0 + 0.08 * centerElevation);

    // Distances to stroke segments
    float d1 = sdSegment(cellUV, TL, BR);
    float d2 = sdSegment(cellUV, BL, TR);

    // ================================================================
    // FAST SLEEK STITCHING ANIMATION (~260ms total)
    // ================================================================
    float stroke1Progress = 1.0;
    float stroke2Progress = 1.0;

    if (age < 0.26) {
        // Phase 1: reveal stroke 1 (TL->BR) in 120ms
        stroke1Progress = clamp(age / 0.12, 0.0, 1.0);

        // Phase 2: reveal stroke 2 (BL->TR), starts at 60ms, finishes at 180ms
        stroke2Progress = clamp((age - 0.06) / 0.12, 0.0, 1.0);

        // Crisp settle bounce as stitches tighten into fabric holes
        if (age > 0.16) {
            float st = clamp((age - 0.16) / 0.10, 0.0, 1.0);
            float bounce = 1.0 + 0.05 * sin(st * 3.14159);
            threadW1 *= bounce;
            threadW2 *= bounce;
        }
    }

    // Reveal progression along stroke 1 (TL -> BR)
    vec2 dir1 = BR - TL;
    float len1 = length(dir1);
    vec2 udir1 = dir1 / len1;
    float prog1 = dot(cellUV - TL, udir1) / len1;
    float revealCut1 = smoothstep(stroke1Progress - 0.10, stroke1Progress, prog1);
    float stroke1 = (1.0 - smoothstep(threadW1 - aa, threadW1 + aa, d1)) * (1.0 - revealCut1);

    // Reveal progression along stroke 2 (BL -> TR)
    vec2 dir2 = TR - BL;
    float len2 = length(dir2);
    vec2 udir2 = dir2 / len2;
    float prog2 = dot(cellUV - BL, udir2) / len2;
    float revealCut2 = smoothstep(stroke2Progress - 0.10, stroke2Progress, prog2);
    float stroke2 = (1.0 - smoothstep(threadW2 - aa, threadW2 + aa, d2)) * (1.0 - revealCut2);

    float stitchMask = max(stroke1, stroke2);

    // ================================================================
    // 2-PLY MOULINÉ EMBROIDERY FLOSS TWIST TEXTURE
    // ================================================================
    float twist1 = sin(prog1 * 26.0) * 0.5 + 0.5;
    float twist2 = sin(prog2 * 26.0 + 1.4) * 0.5 + 0.5;

    // ================================================================
    // HOLE ENTRY DEPTH (Threads dip down into corner eyelets)
    // ================================================================
    float holeDip1 = min(smoothstep(0.0, 0.16, prog1), smoothstep(1.0, 0.84, prog1));
    float holeDip2 = min(smoothstep(0.0, 0.16, prog2), smoothstep(1.0, 0.84, prog2));

    // ================================================================
    // CORE HIGHLIGHT SHEEN (Twisted silk thread highlight)
    // ================================================================
    float sheenW1 = threadW1 * 0.36;
    float sheenW2 = threadW2 * 0.38;
    float sheen1 = 1.0 - smoothstep(sheenW1 - aa, sheenW1 + aa, d1);
    float sheen2 = 1.0 - smoothstep(sheenW2 - aa, sheenW2 + aa, d2);

    // Top thread catches extra sheen at the center crossover apex
    sheen2 *= (1.0 + 0.25 * centerElevation);

    // ================================================================
    // DIRECTIONAL TILT LIGHTING & ASYMMETRIC CROSSOVER SHADING
    // ================================================================
    vec2 shift = vec2(-0.5 - uTilt.x * 0.3, -0.5 + uTilt.y * 0.3);
    shift = clamp(shift, vec2(-1.0), vec2(1.0));
    vec2 lightDir = normalize(-shift);

    vec2 n1 = normalize(vec2(-(BR.y - TL.y), BR.x - TL.x));
    vec2 n2 = normalize(vec2(-(TR.y - BL.y), TR.x - BL.x));

    float light1 = dot(n1, lightDir) * 0.5 + 0.5;
    float light2 = dot(n2, lightDir) * 0.5 + 0.5;

    // Apply ply twist texturing to thread color
    vec3 thread1Color = mix(threadDark, threadLight, light1) * (0.92 + 0.08 * twist1);
    vec3 thread2Color = mix(threadDark, threadLight, light2) * (0.91 + 0.09 * twist2);

    // Darken threads as they sink into the fabric puncture holes
    thread1Color *= mix(0.72, 1.0, holeDip1);
    thread2Color *= mix(0.75, 1.0, holeDip2);

    // ================================================================
    // BREAKING TR vs BR SYMMETRY:
    // Stroke 2 (top thread, BL->TR) completely crosses OVER Stroke 1.
    // At the crossing, Stroke 2 casts a pronounced contact shadow onto
    // the Bottom-Right segment of Stroke 1!
    // ================================================================
    float brSegment = smoothstep(0.38, 0.62, prog1);
    float crossoverShadow = stroke2 * brSegment;
    thread1Color = mix(thread1Color, threadDark * 0.60, crossoverShadow * 0.70);

    // ================================================================
    // DROP SHADOWS
    // ================================================================
    vec2 shadowOffset = vec2(0.016, 0.022);
    float sd1_shadow = sdSegment(cellUV - shadowOffset, TL, BR);
    float sd2_shadow = sdSegment(cellUV - shadowOffset, BL, TR);
    float shadow1 = 1.0 - smoothstep(threadW1 - aa, threadW1 + aa * 2.2, sd1_shadow);
    float shadow2 = 1.0 - smoothstep(threadW2 - aa, threadW2 + aa * 2.2, sd2_shadow);

    // ================================================================
    // MULTI-LAYER COMPOSITING
    // 1. Stitch cell background (very light pastel tint of stitch color)
    // 2. Stroke 1 (bottom thread \) shadow onto cell background
    // 3. Stroke 1 base with ply twist & hole entry depth
    // 4. Stroke 1 core sheen
    // 5. Stroke 2 (top thread /) shadow onto cell background AND bottom thread
    // 6. Stroke 2 base with ply twist, center elevation & TR highlight
    // 7. Stroke 2 elevated core sheen & crossover luster
    // ================================================================
    vec3 result = stitchCellBg;

    // 2. Bottom thread shadow
    float s1_active = stroke1Progress > 0.05 ? 1.0 : 0.0;
    result = mix(result, result * 0.72, shadow1 * 0.38 * s1_active);

    // 3. Bottom thread (\)
    result = mix(result, thread1Color, stroke1);

    // 4. Bottom thread core sheen
    result = mix(result, sheenColor * (0.85 + 0.15 * twist1), sheen1 * stroke1 * 0.50 * holeDip1);

    // 5. Top thread shadow (casts onto fabric and onto stroke 1 below it)
    float s2_active = stroke2Progress > 0.05 ? 1.0 : 0.0;
    result = mix(result, result * 0.65, shadow2 * 0.48 * s2_active);

    // 6. Top thread (/) - completely covers stroke 1 at the intersection
    result = mix(result, thread2Color, stroke2);

    // 7. Top thread core sheen - enhanced along the elevated arch to TR
    result = mix(result, sheenColor * (0.88 + 0.12 * twist2), sheen2 * stroke2 * 0.70 * holeDip2);

    // ================================================================
    // THREAD FIBERS AT HIGH ZOOM (>= 18)
    // ================================================================
    if (uEffectiveCell >= 18.0 && stitchMask > 0.01) {
        float fiber1 = sin(prog1 * cellSize.x * 2.8) * 0.5 + 0.5;
        result = mix(result, result * (0.94 + 0.06 * fiber1), stroke1 * 0.5);

        float fiber2 = sin(prog2 * cellSize.x * 2.8) * 0.5 + 0.5;
        result = mix(result, result * (0.94 + 0.06 * fiber2), stroke2 * 0.5);
    }

    // ================================================================
    // SILK SPECULAR HIGHLIGHT (Glancing light on top thread crown)
    // ================================================================
    if (stroke2 > 0.01) {
        vec2 specPos = vec2(0.5) + shift * 0.10;
        float specDist = length(cellUV - specPos);
        if (specDist < 0.20) {
            float sheen = smoothstep(0.20, 0.0, specDist);
            result = mix(result, vec3(1.0), sheen * 0.20 * stroke2);
        }
    }

    // ================================================================
    // FAST AFTERGLOW & GLINT SWEEP (~260ms)
    // ================================================================
    if (age < 0.28) {
        float glow = 1.0 - clamp(age / 0.24, 0.0, 1.0);
        result = mix(result, vec3(1.0, 0.97, 0.90), glow * glow * 0.14 * stitchMask);
        // Fast thread-pull glint streak sweeping across during 0.08–0.22s
        if (age > 0.08 && age < 0.22) {
            float gt = clamp((age - 0.08) / 0.14, 0.0, 1.0);
            float gpos = (cellUV.x + cellUV.y) * 0.5;
            float sweep = mix(-0.2, 1.2, gt);
            float d = abs(gpos - sweep);
            if (d < 0.10) {
                float streak = 1.0 - d / 0.10;
                result = mix(result, vec3(1.0), streak * streak * 0.28 * (1.0 - gt) * stitchMask);
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
