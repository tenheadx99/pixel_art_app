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

vec2 getTexUV(vec2 coord) {
    vec2 uv = (coord + vec2(0.5)) / uGrid;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif
    return uv;
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
    vec2 texUV = getTexUV(cellCoord);
    vec4 cellColor = texture(uTexture, texUV);

    // Screen pixel size relative to cell UV
    float pixSize = 1.0 / max(uEffectiveCell, 4.0);
    float borderThresh = pixSize * 0.45;
    bool isBorder = cellUV.x < borderThresh || cellUV.x > (1.0 - borderThresh) ||
                    cellUV.y < borderThresh || cellUV.y > (1.0 - borderThresh);

    // Grid lines fade out when zoomed far out (< 8px per cell) to prevent dark moiré patterns
    float gridLineOpacity = clamp((uEffectiveCell - 6.0) / 6.0, 0.0, 1.0);

    // 1. Empty / transparent background cell
    if (cellColor.a < 0.01) {
        vec3 emptyBg = vec3(0.970, 0.972, 0.976);
        if (isBorder && gridLineOpacity > 0.05) {
            emptyBg = mix(emptyBg, vec3(0.88, 0.89, 0.91), gridLineOpacity * 0.6);
        }
        fragColor = vec4(emptyBg, 1.0);
        return;
    }

    // 2. Unfilled numbered cell: preview tint when zoomed out, or clean neutral gray when zoomed in
    if (cellColor.a < 0.75) {
        vec3 color = cellColor.rgb / max(cellColor.a, 0.001);
        float lum = dot(color, vec3(0.299, 0.587, 0.114));
        vec3 gray = vec3(clamp(0.65 + lum * 0.30, 0.65, 0.94));
        float t = clamp((uEffectiveCell - 11.0) / 7.0, 0.0, 1.0);
        vec3 cellBody = mix(color, gray, t);
        if (isBorder && gridLineOpacity > 0.05) {
            cellBody = mix(cellBody, vec3(0.82, 0.83, 0.85), gridLineOpacity * 0.8);
        }
        fragColor = vec4(cellBody, 1.0);
        return;
    }

    // 3. Filled cell: solid vibrant color with authentic pixel gloss
    vec3 baseColor = cellColor.rgb;

    // Subtle top gloss highlight (authentic polished pixel art feel)
    if (cellUV.y < 0.30) {
        float gloss = smoothstep(0.30, 0.05, cellUV.y) * 0.08;
        baseColor += vec3(gloss);
    }

    // Section completion shimmer wave sweep
    if (uShimmer >= 0.0 && uShimmer <= 1.0) {
        float diag = (cellCoord.x + cellCoord.y) / max(uGrid.x + uGrid.y, 1.0);
        float shimmerDist = abs(diag - uShimmer);
        if (shimmerDist < 0.08) {
            float shimmerIntensity = (1.0 - shimmerDist / 0.08) * 0.30;
            baseColor += vec3(shimmerIntensity);
        }
    }

    // Hairline border separation between filled cells
    if (isBorder && gridLineOpacity > 0.05) {
        baseColor *= (1.0 - 0.12 * gridLineOpacity);
    }

    fragColor = vec4(clamp(baseColor, 0.0, 1.0), 1.0);
}

