#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uGrid;
uniform vec2 uTilt;
uniform float uEffectiveCell;
// Seconds elapsed since fill-age texture was baked; clocks fill animations.
uniform float uTime;
// Section-complete shimmer progress (0..1 sweeps diagonal bright band).
uniform float uShimmer;
uniform sampler2D uTexture;
// Per-cell fill age in red channel over a 1.6s window.
uniform sampler2D uFillAge;

out vec4 fragColor;

vec2 getTexUV(vec2 coord) {
    return (coord + vec2(0.5)) / uGrid;
}

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 cellSize = uSize / uGrid;
    vec2 cellCoord = floor(pos / cellSize);

    // Bounds check
    if (cellCoord.x < 0.0 || cellCoord.x >= uGrid.x || cellCoord.y < 0.0 || cellCoord.y >= uGrid.y) {
        fragColor = vec4(0.0);
    } else {
        // Normalized UV inside current cell [0, 1]
        vec2 cellUV = fract(pos / cellSize);
        vec2 center = vec2(0.5);

        // Hairline Cell Outline Border (0.18 threshold = ultra-thin 0.36px grid line)
        vec2 borderThresh = vec2(0.18 / cellSize.x, 0.18 / cellSize.y);
        bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                            cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);

        // Grid lines / border fade factor
        float gridLineOpacity = clamp((uEffectiveCell - 6.0) / 6.0, 0.0, 1.0);

        // Sample cell color & fill age
        vec2 texUV = getTexUV(cellCoord);
        vec4 cellColor = texture(uTexture, texUV);
        float fillAge = texture(uFillAge, texUV).r;

        // Inset for mortar grout seam around each ceramic tile
        float groutInset = 0.08;

        // Contact drop shadow from top & left neighbor tiles onto mortar
        float contactShadow = 0.0;
        if (cellCoord.y > 0.0) {
            float aTop = texture(uTexture, getTexUV(cellCoord - vec2(0.0, 1.0))).a;
            if (aTop > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.18, 0.0, cellUV.y) * 0.40);
            }
        }
        if (cellCoord.x > 0.0) {
            float aLeft = texture(uTexture, getTexUV(cellCoord - vec2(1.0, 0.0))).a;
            if (aLeft > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.18, 0.0, cellUV.x) * 0.35);
            }
        }

        // 1. Clean Canvas Background
        if (cellColor.a < 0.01) {
            vec3 canvasBg = vec3(0.965, 0.968, 0.972);
            canvasBg *= (1.0 - contactShadow);
            fragColor = vec4(canvasBg, 1.0);
            return;
        }
        // 2. Unfilled cell: direct transition from color to grey-out (just like Gem flavor)
        else if (cellColor.a < 0.75) {
            vec3 color = cellColor.rgb / max(cellColor.a, 0.001);
            float luminance = dot(color, vec3(0.299, 0.587, 0.114));
            vec3 gray = vec3(clamp(0.62 + luminance * 0.32, 0.62, 0.94));
            float t = clamp((uEffectiveCell - 8.0) / 8.0, 0.0, 1.0);
            vec3 cellBody = mix(color, gray, t);
            if (isCellBorder && t > 0.1) {
                cellBody = mix(cellBody, vec3(0.80, 0.80, 0.80), t);
            }
            cellBody *= (1.0 - contactShadow);
            fragColor = vec4(cellBody, 1.0);
            return;
        }
        // 3. Filled Cell: Glazed Ceramic Mosaic Tile
        else {
            vec3 base = cellColor.rgb;

            // Grow / pop spring animation from uFillAge + uTime
            float age = fillAge + uTime;
            float grow = clamp(age / 0.35, 0.0, 1.0);
            float spring = 1.0;
            if (grow < 1.0) {
                spring = 0.4 + 0.6 * sin(grow * 1.5708);
                if (grow > 0.6) {
                    spring += sin((grow - 0.6) * 3.14159 / 0.4) * 0.09;
                }
            }

            float currentInset = groutInset * (2.0 - clamp(spring, 0.5, 1.1));

            // Mortar background outside tile
            vec3 tileColor = vec3(0.23, 0.21, 0.19) * (1.0 - contactShadow);

            if (cellUV.x >= currentInset && cellUV.x <= (1.0 - currentInset) &&
                cellUV.y >= currentInset && cellUV.y <= (1.0 - currentInset)) {

                // Tile local UV [0, 1] inside tile
                vec2 tUV = (cellUV - vec2(currentInset)) / (1.0 - 2.0 * currentInset);

                // Ceramic body with subtle depth
                tileColor = base;

                // Tilt-responsive light vector
                vec2 lightOffset = uTilt * 0.30;

                // Beveled glazed edge lighting:
                // Top-left catches light, bottom-right drops into mortar shadow
                float bevelSize = 0.14;
                if (tUV.y < bevelSize && tUV.x > tUV.y && (1.0 - tUV.x) > tUV.y) {
                    // Top beveled glaze
                    tileColor = base * (1.22 - lightOffset.y * 0.25);
                } else if (tUV.x < bevelSize && tUV.y > tUV.x && (1.0 - tUV.y) > tUV.x) {
                    // Left beveled glaze
                    tileColor = base * (1.14 - lightOffset.x * 0.20);
                } else if (tUV.x > (1.0 - bevelSize) && tUV.y > (1.0 - tUV.x) && (1.0 - tUV.y) > (1.0 - tUV.x)) {
                    // Right shadow bevel
                    tileColor = base * (0.84 + lightOffset.x * 0.18);
                } else if (tUV.y > (1.0 - bevelSize)) {
                    // Bottom shadow bevel
                    tileColor = base * (0.74 + lightOffset.y * 0.22);
                } else {
                    // Center tile face: glassy ceramic glaze sheen
                    if (tUV.x < 0.60 && tUV.y < 0.50) {
                        float glaze = smoothstep(0.60, 0.05, tUV.x) * smoothstep(0.50, 0.05, tUV.y);
                        tileColor += vec3(0.26 * glaze);
                    }
                }

                // Crisp top-left corner glint
                vec2 glintOffset = tUV - vec2(0.20, 0.20) + lightOffset * 0.05;
                if (length(glintOffset) < 0.15) {
                    float g = smoothstep(0.15, 0.02, length(glintOffset));
                    tileColor += vec3(0.35 * g);
                }
            }

            // Impact snap flash during early fill animation (< 100ms)
            if (age < 0.12) {
                float flash = (1.0 - age / 0.12) * 0.55;
                tileColor += vec3(flash);
            }

            // Section completion shimmer sweep
            if (uShimmer >= 0.0 && uShimmer <= 1.0) {
                float diag = (cellCoord.x + cellCoord.y * 0.75) / max(uGrid.x + uGrid.y * 0.75, 1.0);
                float shimmerDist = abs(diag - uShimmer);
                if (shimmerDist < 0.09) {
                    float s = (1.0 - shimmerDist / 0.09);
                    tileColor += vec3(s * s * 0.35);
                }
            }

            fragColor = vec4(clamp(tileColor, 0.0, 1.0), 1.0);
        }
    }
}
