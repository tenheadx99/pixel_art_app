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

        // Distance from center of current peg
        float dist = length(cellUV - center);

        // 1. Clean Pegboard Canvas Background
        if (cellColor.a < 0.01) {
            vec3 canvasBg = vec3(0.965, 0.968, 0.972);
            if (dist < 0.36) {
                canvasBg = mix(canvasBg, vec3(0.88, 0.89, 0.91), 0.5);
            }
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
            if (dist < 0.36) {
                cellBody = mix(cellBody, vec3(0.72, 0.74, 0.78), 0.25);
            }
            fragColor = vec4(cellBody, 1.0);
            return;
        }
        // 3. Filled Cell: Luminous Neon Lite-Brite Peg with Optical Bloom
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

            float pegRadius = 0.42 * clamp(spring, 0.5, 1.15);

            // Tilt-responsive light vector
            vec2 lightOffset = uTilt * 0.20;

            // Dark board background base
            vec3 glowColor = vec3(0.06, 0.065, 0.08);

            // 1. Wide ambient diffuse neon aura (bloom bleeding onto dark pegboard)
            float aura = exp(-dist * 3.2) * 0.50;
            glowColor += base * aura;

            // 2. Acrylic translucent cylinder body
            if (dist < pegRadius) {
                float normDist = dist / pegRadius;

                // Acrylic body color
                vec3 pegBody = base * 0.90;

                // Saturated luminous corona
                float corona = smoothstep(1.0, 0.4, normDist);
                pegBody += base * (corona * 0.45);

                // Hot luminous core (light shining directly through translucent peg center)
                float coreDist = dist / (pegRadius * 0.65);
                if (coreDist < 1.0) {
                    float core = smoothstep(1.0, 0.0, coreDist);
                    vec3 coreColor = mix(base, vec3(1.0), 0.70);
                    pegBody = mix(pegBody, coreColor, core * 0.85);
                }

                // White-hot center focal filament
                float focalDist = dist / (pegRadius * 0.32);
                if (focalDist < 1.0) {
                    float focal = smoothstep(1.0, 0.0, focalDist);
                    pegBody = mix(pegBody, vec3(1.0), focal * 0.95);
                }

                // Acrylic surface specular reflection glint (shifts with phone tilt)
                vec2 glintCenter = center - vec2(pegRadius * 0.35, pegRadius * 0.35) + lightOffset * 0.04;
                float glintDist = length(cellUV - glintCenter);
                if (glintDist < pegRadius * 0.18) {
                    float glint = smoothstep(pegRadius * 0.18, 0.01, glintDist);
                    pegBody += vec3(0.80 * glint);
                }

                glowColor = pegBody;
            }

            // Impact neon pulse flash during early fill animation (< 120ms)
            if (age < 0.14) {
                float flash = (1.0 - age / 0.14) * 0.70;
                glowColor += vec3(flash);
            }

            // Section completion shimmer sweep
            if (uShimmer >= 0.0 && uShimmer <= 1.0) {
                float diag = (cellCoord.x + cellCoord.y * 0.7) / max(uGrid.x + uGrid.y * 0.7, 1.0);
                float shimmerDist = abs(diag - uShimmer);
                if (shimmerDist < 0.09) {
                    float s = (1.0 - shimmerDist / 0.09);
                    glowColor += vec3(s * s * 0.45);
                }
            }

            fragColor = vec4(clamp(glowColor, 0.0, 1.0), 1.0);
        }
    }
}
