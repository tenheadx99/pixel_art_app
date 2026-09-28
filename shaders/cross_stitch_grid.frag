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

// --- Fabric weave noise (cheap pseudo-random for linen texture) ---
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
    // FABRIC CANVAS BACKGROUND (linen/aida cloth texture)
    // ================================================================
    // Warm linen base
    vec3 fabricBase = vec3(0.96, 0.93, 0.88);   // Warm cream
    vec3 fabricDark = vec3(0.88, 0.84, 0.78);    // Warp thread shadow

    // Aida cloth weave pattern: horizontal and vertical thread crossings
    float weaveX = sin(cellUV.x * 3.14159 * 4.0) * 0.5 + 0.5;
    float weaveY = sin(cellUV.y * 3.14159 * 4.0) * 0.5 + 0.5;
    float weave = weaveX * 0.5 + weaveY * 0.5;
    // Add subtle per-cell variation for organic feel
    float noise = hash(cellCoord) * 0.04;
    vec3 fabric = mix(fabricDark, fabricBase, weave) + vec3(noise);

    // Hairline grid: fabric hole pattern (aida grid squares)
    vec2 borderThresh = vec2(0.12 / cellSize.x, 0.12 / cellSize.y);
    bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                        cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);

    // ================================================================
    // CELL STATE ROUTING
    // ================================================================

    // Empty cell -> plain fabric, no stitch
    if (cellColor.a < 0.01) {
        fragColor = vec4(fabric, 1.0);
        return;
    }

    // Unfilled numbered cell -> ghost preview fading to fabric grid at zoom
    if (cellColor.a < 0.75) {
        vec3 preview = cellColor.rgb / max(cellColor.a, 0.001);
        if (uEffectiveCell < 10.0) {
            // Zoomed out: soft ghost of target color on fabric
            vec3 ghostOnFabric = mix(fabric, preview, 0.5);
            fragColor = vec4(ghostOnFabric, 1.0);
            return;
        }
        // Zoomed in: clean fabric with subtle grid holes
        float fade = clamp((uEffectiveCell - 10.0) / 6.0, 0.0, 1.0);
        vec3 gridFabric = isCellBorder ? vec3(0.82, 0.79, 0.74) : fabric;
        fragColor = vec4(mix(preview, gridFabric, fade), 1.0);
        return;
    }

    // ================================================================
    // FILLED CELL -> CROSS STITCH RENDERING
    // ================================================================

    // Zoomed out LOD (< 10.0): Flat colored tile (stitches too small to see)
    if (uEffectiveCell < 10.0) {
        fragColor = vec4(cellColor.rgb, 1.0);
        return;
    }

    // --- Fill-animation timeline ---
    float age = texture(uFillAge, texUV).r * 1.6 + uTime;

    // Thread color from the cell's fill color
    vec3 threadColor = cellColor.rgb;
    // Brighter highlight and darker shadow for thread 3D illusion
    vec3 threadLight = min(threadColor * 1.15 + vec3(0.08), vec3(1.0));
    vec3 threadDark = threadColor * 0.65;

    // ================================================================
    // CROSS STITCH GEOMETRY: Two diagonal thread strokes forming an "X"
    // ================================================================
    // Margin around cell edge (fabric shows around the stitch)
    float margin = 0.10;
    // Thread half-width (thickness of each stitch leg)
    float threadW = 0.10;

    // Stitch corners (with margin)
    vec2 TL = vec2(margin, margin);           // top-left
    vec2 TR = vec2(1.0 - margin, margin);     // top-right
    vec2 BL = vec2(margin, 1.0 - margin);     // bottom-left
    vec2 BR = vec2(1.0 - margin, 1.0 - margin); // bottom-right

    // First stroke: bottom-left to top-right (\)
    float d1 = sdSegment(cellUV, BL, TR);
    // Second stroke: top-left to bottom-right (/)
    float d2 = sdSegment(cellUV, TL, BR);

    // Anti-aliased thread mask
    float aa = 1.5 / max(cellSize.x, cellSize.y);  // sub-pixel smoothing
    float stroke1 = 1.0 - smoothstep(threadW - aa, threadW + aa, d1);
    float stroke2 = 1.0 - smoothstep(threadW - aa, threadW + aa, d2);

    // ================================================================
    // STITCHING ANIMATION (thread-pull reveal)
    // ================================================================
    // The animation reveals the stitch in two phases:
    //   Phase 1 (0–0.40s): First diagonal stroke draws from BL to TR
    //   Phase 2 (0.25–0.65s): Second stroke draws from TL to BR (overlaps)
    // Then a settle/tighten phase 0.5–0.8s pulls the threads snug.

    if (age < 0.80) {
        // Phase 1: reveal stroke 1 along its length (BL→TR)
        float revealT1 = clamp(age / 0.40, 0.0, 1.0);
        // Progress along the diagonal (0 = BL corner, 1 = TR corner)
        vec2 dir1 = TR - BL;
        float prog1 = dot(cellUV - BL, normalize(dir1)) / length(dir1);
        // Smooth leading edge of reveal
        float mask1 = smoothstep(revealT1 - 0.15, revealT1, prog1);
        stroke1 *= (1.0 - mask1);

        // Phase 2: reveal stroke 2 (TL→BR), starts at 0.25s
        float revealT2 = clamp((age - 0.25) / 0.40, 0.0, 1.0);
        vec2 dir2 = BR - TL;
        float prog2 = dot(cellUV - TL, normalize(dir2)) / length(dir2);
        float mask2 = smoothstep(revealT2 - 0.15, revealT2, prog2);
        stroke2 *= (1.0 - mask2);

        // Settle pop: slight scale bounce at the end (0.55–0.80s)
        if (age > 0.55) {
            float st = clamp((age - 0.55) / 0.25, 0.0, 1.0);
            float bounce = 1.0 + 0.06 * sin(st * 3.14159);
            // Widen threads slightly during settle
            threadW *= bounce;
        }
    }

    // Combined stitch mask (second stroke overlaps first at center)
    // Stroke 2 is "on top" at the intersection
    float stitchMask = max(stroke1, stroke2);
    float topStroke = stroke2;  // the over-crossing thread

    // ================================================================
    // THREAD SHADING (3D thread illusion with light direction)
    // ================================================================
    vec2 shift = vec2(-0.5 - uTilt.x * 0.3, -0.5 + uTilt.y * 0.3);
    shift = clamp(shift, vec2(-1.0), vec2(1.0));
    vec2 lightDir = normalize(-shift);

    // Per-stroke normal approximation (perpendicular to thread direction)
    vec2 n1 = normalize(vec2(-(TR.y - BL.y), TR.x - BL.x)); // normal to stroke 1
    vec2 n2 = normalize(vec2(-(BR.y - TL.y), BR.x - TL.x)); // normal to stroke 2

    float light1 = dot(n1, lightDir) * 0.5 + 0.5;
    float light2 = dot(n2, lightDir) * 0.5 + 0.5;

    // Thread color with directional lighting
    vec3 thread1Color = mix(threadDark, threadLight, light1);
    vec3 thread2Color = mix(threadDark, threadLight, light2);

    // Cross-over shadow: where stroke 2 crosses stroke 1, darken stroke 1
    float intersection = stroke1 * stroke2;
    thread1Color = mix(thread1Color, threadDark * 0.8, intersection * 0.4);

    // Composite: fabric background + stroke 1 (under) + stroke 2 (over)
    vec3 result = fabric;

    // Fabric hole shadow under stitch (gives depth)
    if (stitchMask > 0.01 && uEffectiveCell >= 14.0) {
        vec2 shadowUV = cellUV + shift * 0.02;
        float sd1 = sdSegment(shadowUV, BL, TR);
        float sd2 = sdSegment(shadowUV, TL, BR);
        float shadowMask = max(
            1.0 - smoothstep(threadW * 0.8, threadW * 1.3, sd1),
            1.0 - smoothstep(threadW * 0.8, threadW * 1.3, sd2)
        );
        result = mix(result, result * 0.75, shadowMask * 0.25);
    }

    // Layer stroke 1 (bottom thread)
    result = mix(result, thread1Color, stroke1);
    // Layer stroke 2 (top thread, overwrites at intersection)
    result = mix(result, thread2Color, stroke2);

    // ================================================================
    // THREAD TEXTURE DETAIL (zoom >= 18): fine thread lines
    // ================================================================
    if (uEffectiveCell >= 18.0 && stitchMask > 0.01) {
        // Simulate individual thread fibers along each diagonal
        vec2 fiberDir1 = normalize(TR - BL);
        float fiberCoord1 = dot(cellUV - BL, vec2(-fiberDir1.y, fiberDir1.x));
        float fibers1 = sin(fiberCoord1 * cellSize.x * 2.5) * 0.5 + 0.5;
        result = mix(result, result * (0.92 + 0.08 * fibers1), stroke1 * 0.6);

        vec2 fiberDir2 = normalize(BR - TL);
        float fiberCoord2 = dot(cellUV - TL, vec2(-fiberDir2.y, fiberDir2.x));
        float fibers2 = sin(fiberCoord2 * cellSize.x * 2.5) * 0.5 + 0.5;
        result = mix(result, result * (0.92 + 0.08 * fibers2), stroke2 * 0.6);
    }

    // ================================================================
    // THREAD SPECULAR HIGHLIGHT (sheen along stitch)
    // ================================================================
    if (stitchMask > 0.01) {
        // Silk sheen: bright line along the thread where light catches
        vec2 specPos = vec2(0.5) + shift * 0.12;
        float specDist = length(cellUV - specPos);
        if (specDist < 0.22) {
            float sheen = smoothstep(0.22, 0.0, specDist);
            result = mix(result, vec3(1.0), sheen * 0.18 * stitchMask);
        }
    }

    // ================================================================
    // AFTERGLOW & GLINT SWEEP (post-fill warmth)
    // ================================================================
    if (age < 0.95) {
        float glow = 1.0 - clamp(age / 0.85, 0.0, 1.0);
        result = mix(result, vec3(1.0, 0.97, 0.90), glow * glow * 0.15 * stitchMask);
        // Thread-pull glint: a diagonal streak crossing during 0.3–0.7s
        if (age > 0.30) {
            float gt = clamp((age - 0.30) / 0.40, 0.0, 1.0);
            float gpos = (cellUV.x + cellUV.y) * 0.5;
            float sweep = mix(-0.2, 1.2, gt);
            float d = abs(gpos - sweep);
            if (d < 0.12) {
                float streak = 1.0 - d / 0.12;
                result = mix(result, vec3(1.0), streak * streak * 0.30 * (1.0 - gt) * stitchMask);
            }
        }
    }

    // ================================================================
    // SECTION-COMPLETE SHIMMER (golden thread sheen sweep)
    // ================================================================
    if (uShimmer > 0.001 && uShimmer < 0.999) {
        float q = (pos.x + pos.y * 0.35) / (uSize.x + uSize.y * 0.35);
        float band = mix(-0.2, 1.2, uShimmer);
        float bd = abs(q - band);
        if (bd < 0.09) {
            float s = 1.0 - bd / 0.09;
            // Golden thread shimmer
            vec3 shimmerColor = mix(vec3(1.0), vec3(1.0, 0.92, 0.7), 0.5);
            result = mix(result, shimmerColor, s * s * 0.40 * stitchMask);
        }
    }

    fragColor = vec4(result, 1.0);
}
