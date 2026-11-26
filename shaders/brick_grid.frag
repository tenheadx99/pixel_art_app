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

        // Contact drop shadow from top & left neighbor bricks
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

        // Distance from cell center for the round stud socket
        float distToCenter = length(cellUV - center);

        // 1. Clean Canvas / Baseplate Background
        if (cellColor.a < 0.01) {
            vec3 plateBg = vec3(0.965, 0.968, 0.972);
            plateBg *= (1.0 - contactShadow);
            fragColor = vec4(plateBg, 1.0);
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

        // 3. Filled Brick: 3D Plastic Studded Building Brick
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

            // Outer perimeter bevels:
            // Top-left highlight, bottom-right shadow rim
            float rim = 0.045;
            vec3 brickColor = base;
            if (cellUV.x < rim || cellUV.y < rim) {
                brickColor += vec3(0.22); // Bevel highlight
            } else if (cellUV.x > (1.0 - rim) || cellUV.y > (1.0 - rim)) {
                brickColor *= 0.82; // Bevel shadow
            }

            // Tilt-responsive light vector
            vec2 lightOffset = uTilt * 0.25;

            // --- Raised Circular Lego Stud ---
            float studRadius = 0.28 * clamp(spring, 0.5, 1.1);
            vec2 studCenter = center - vec2(0.0, 0.04) + lightOffset * 0.03;

            // Stud drop shadow onto the brick body (offset down-right)
            vec2 shadowCenter = studCenter + vec2(0.04, 0.08);
            float shadowDist = length(cellUV - shadowCenter);
            if (shadowDist < studRadius * 1.06) {
                float shadowSoftness = smoothstep(studRadius * 1.06, studRadius * 0.7, shadowDist);
                brickColor *= (1.0 - shadowSoftness * 0.40);
            }

            // Stud cylindrical sidewall (depth extrusion)
            vec2 wallCenter = studCenter + vec2(0.0, 0.035);
            float wallDist = length(cellUV - wallCenter);
            if (wallDist < studRadius) {
                brickColor = base * 0.78; // Darker shaded cylinder wall
            }

            // Stud top raised face
            float studDist = length(cellUV - studCenter);
            if (studDist < studRadius) {
                // Stud cap with subtle dome gradient + tilt highlight
                vec2 normStud = (cellUV - studCenter) / studRadius;
                float studLight = dot(normStud, normalize(vec2(-0.7, -0.7) + lightOffset));
                brickColor = base * (1.06 + studLight * 0.18);

                // Top-left circular rim specular arc
                float rimDist = abs(studDist - (studRadius - 0.03));
                if (rimDist < 0.025 && normStud.x < 0.2 && normStud.y < 0.2) {
                    float arcIntensity = smoothstep(0.025, 0.0, rimDist) * smoothstep(0.5, -0.5, normStud.x + normStud.y);
                    brickColor += vec3(0.35 * arcIntensity);
                }

                // Crisp specular glint inside top-left of stud
                vec2 glintOffset = normStud - vec2(-0.35, -0.35);
                if (length(glintOffset) < 0.22) {
                    float glint = smoothstep(0.22, 0.02, length(glintOffset));
                    brickColor += vec3(0.38 * glint);
                }
            }

            // Impact snap flash during early fill animation (< 100ms)
            if (age < 0.12) {
                float flash = (1.0 - age / 0.12) * 0.55;
                brickColor += vec3(flash);
            }

            // Section completion shimmer sweep
            if (uShimmer >= 0.0 && uShimmer <= 1.0) {
                float diag = (cellCoord.x + cellCoord.y * 0.75) / max(uGrid.x + uGrid.y * 0.75, 1.0);
                float shimmerDist = abs(diag - uShimmer);
                if (shimmerDist < 0.09) {
                    float s = (1.0 - shimmerDist / 0.09);
                    brickColor += vec3(s * s * 0.35);
                }
            }

            fragColor = vec4(clamp(brickColor, 0.0, 1.0), 1.0);
        }
    }
}
