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

        // Grid lines / border fade factor
        float gridLineOpacity = clamp((uEffectiveCell - 6.0) / 6.0, 0.0, 1.0);

        // Sample cell color & fill age
        vec2 texUV = getTexUV(cellCoord);
        vec4 cellColor = texture(uTexture, texUV);
        float fillAge = texture(uFillAge, texUV).r;

        // Contact drop shadow from top & left neighbor stickers
        float contactShadow = 0.0;
        if (cellCoord.y > 0.0) {
            float aTop = texture(uTexture, getTexUV(cellCoord - vec2(0.0, 1.0))).a;
            if (aTop > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.18, 0.0, cellUV.y) * 0.35);
            }
        }
        if (cellCoord.x > 0.0) {
            float aLeft = texture(uTexture, getTexUV(cellCoord - vec2(1.0, 0.0))).a;
            if (aLeft > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.18, 0.0, cellUV.x) * 0.30);
            }
        }

        // 1. Notebook Paper Background
        if (cellColor.a < 0.01) {
            vec3 paperBg = vec3(0.97, 0.965, 0.95); // Warm sketchbook paper
            // Subtle faint grid guide line
            vec2 seam = step(vec2(0.98), cellUV) + step(cellUV, vec2(0.02));
            if ((seam.x + seam.y) > 0.5) {
                paperBg -= vec3(0.035);
            }
            paperBg *= (1.0 - contactShadow);
            fragColor = vec4(paperBg, 1.0);
        }
        // 2. Unfilled cell: subtle preview tint with sticker peel guide
        else if (cellColor.a < 0.75) {
            vec3 color = cellColor.rgb / max(cellColor.a, 0.001);
            float lum = dot(color, vec3(0.299, 0.587, 0.114));
            vec3 lightTone = mix(vec3(0.92, 0.92, 0.91), color * 0.65, 0.35);
            float t = clamp((uEffectiveCell - 11.0) / 7.0, 0.0, 1.0);
            vec3 cellBody = mix(color * 0.75, lightTone, t);

            // White die-cut guide border
            vec3 pixelColor = vec3(0.97, 0.965, 0.95);
            if (cellUV.x > 0.05 && cellUV.x < 0.95 && cellUV.y > 0.05 && cellUV.y < 0.95) {
                pixelColor = vec3(0.99, 0.99, 0.99); // Crisp white rim
                if (cellUV.x > 0.15 && cellUV.x < 0.85 && cellUV.y > 0.15 && cellUV.y < 0.85) {
                    pixelColor = cellBody;
                }
            }
            pixelColor *= (1.0 - contactShadow);
            fragColor = vec4(pixelColor, 1.0);
        }
        // 3. Filled Cell: Die-Cut Vinyl Sticker Badge
        else {
            vec3 base = cellColor.rgb;

            // Grow / pop spring animation from uFillAge + uTime
            float age = fillAge + uTime;
            float grow = clamp(age / 0.35, 0.0, 1.0);
            float spring = 1.0;
            if (grow < 1.0) {
                spring = 0.4 + 0.6 * sin(grow * 1.5708);
                if (grow > 0.6) {
                    spring += sin((grow - 0.6) * 3.14159 / 0.4) * 0.10;
                }
            }

            // Tilt-responsive light vector
            vec2 lightOffset = uTilt * 0.25;

            // Paper background behind sticker
            vec3 stickerColor = vec3(0.97, 0.965, 0.95);

            // Soft peel drop shadow cast onto paper (offset down-right)
            vec2 shadowCenter = center + vec2(0.04, 0.07);
            vec2 shadowDist = abs(cellUV - shadowCenter);
            float shadowBox = max(shadowDist.x, shadowDist.y);
            if (shadowBox < 0.46) {
                float s = smoothstep(0.46, 0.38, shadowBox);
                stickerColor *= (1.0 - s * 0.32);
            }

            // Outer white vinyl die-cut border
            vec2 normBox = abs(cellUV - center);
            float outerBox = max(normBox.x, normBox.y);
            float stickerRadius = 0.45 * clamp(spring, 0.5, 1.1);

            if (outerBox < stickerRadius) {
                // Crisp white die-cut vinyl rim
                stickerColor = vec3(0.99, 0.99, 1.0);

                // Subtle rim bevel
                if (cellUV.y < 0.10 || cellUV.x < 0.10) {
                    stickerColor += vec3(0.03);
                } else if (cellUV.y > 0.90 || cellUV.x > 0.90) {
                    stickerColor -= vec3(0.06);
                }

                // Inner colored vinyl badge
                float innerRadius = stickerRadius - 0.10;
                if (outerBox < innerRadius) {
                    vec2 innerUV = (cellUV - vec2(center - innerRadius)) / (innerRadius * 2.0);

                    // Saturated vinyl body
                    stickerColor = base;

                    // Glossy vinyl diagonal light sheen across the top-left
                    if (innerUV.x + innerUV.y < 0.9) {
                        float gloss = smoothstep(0.9, 0.1, innerUV.x + innerUV.y);
                        stickerColor += vec3(0.22 * gloss);
                    }

                    // Specular glint spot shifting with phone tilt
                    vec2 glintCenter = vec2(0.30, 0.30) - lightOffset * 0.05;
                    float glintDist = length(innerUV - glintCenter);
                    if (glintDist < 0.20) {
                        float g = smoothstep(0.20, 0.03, glintDist);
                        stickerColor += vec3(0.35 * g);
                    }
                }
            }

            // Impact snap flash during early fill animation (< 100ms)
            if (age < 0.12) {
                float flash = (1.0 - age / 0.12) * 0.55;
                stickerColor += vec3(flash);
            }

            // Section completion shimmer sweep
            if (uShimmer >= 0.0 && uShimmer <= 1.0) {
                float diag = (cellCoord.x + cellCoord.y * 0.75) / max(uGrid.x + uGrid.y * 0.75, 1.0);
                float shimmerDist = abs(diag - uShimmer);
                if (shimmerDist < 0.09) {
                    float s = (1.0 - shimmerDist / 0.09);
                    stickerColor += vec3(s * s * 0.35);
                }
            }

            fragColor = vec4(clamp(stickerColor, 0.0, 1.0), 1.0);
        }
    }
}
