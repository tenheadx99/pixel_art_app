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

        // Grid lines / border fade factor
        float gridLineOpacity = clamp((uEffectiveCell - 6.0) / 6.0, 0.0, 1.0);

        // Sample cell color & fill age
        vec2 texUV = getTexUV(cellCoord);
        vec4 cellColor = texture(uTexture, texUV);
        float fillAge = texture(uFillAge, texUV).r;

        // Contact drop shadow from top & left neighbor voxel blocks
        float contactShadow = 0.0;
        if (cellCoord.y > 0.0) {
            float aTop = texture(uTexture, getTexUV(cellCoord - vec2(0.0, 1.0))).a;
            if (aTop > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.18, 0.0, cellUV.y) * 0.45);
            }
        }
        if (cellCoord.x > 0.0) {
            float aLeft = texture(uTexture, getTexUV(cellCoord - vec2(1.0, 0.0))).a;
            if (aLeft > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.18, 0.0, cellUV.x) * 0.35);
            }
        }

        // 1. Empty board background: dark blueprint / isometric grid slate
        if (cellColor.a < 0.01) {
            vec3 boardBg = vec3(0.11, 0.12, 0.15); // Tech dark slate
            // Subtle grid seam lines
            vec2 seam = step(vec2(0.96), cellUV) + step(cellUV, vec2(0.04));
            if ((seam.x + seam.y) > 0.5) {
                boardBg += vec3(0.03);
            }
            boardBg *= (1.0 - contactShadow);
            fragColor = vec4(boardBg, 1.0);
        }
        // 2. Unfilled cell: subtle preview tint with guide outline
        else if (cellColor.a < 0.75) {
            vec3 color = cellColor.rgb / max(cellColor.a, 0.001);
            float lum = dot(color, vec3(0.299, 0.587, 0.114));
            vec3 darkTone = mix(vec3(0.18, 0.19, 0.22), color * 0.35, 0.25);
            float t = clamp((uEffectiveCell - 11.0) / 7.0, 0.0, 1.0);
            vec3 cellBody = mix(color * 0.55, darkTone, t);

            // Guide border
            vec2 border = step(vec2(0.95), cellUV) + step(cellUV, vec2(0.05));
            if ((border.x + border.y) > 0.5 && gridLineOpacity > 0.1) {
                cellBody = mix(cellBody, vec3(0.32, 0.35, 0.40), gridLineOpacity * 0.6);
            }
            cellBody *= (1.0 - contactShadow);
            fragColor = vec4(cellBody, 1.0);
        }
        // 3. Filled Voxel: 3D Isometric Extruded Block
        else {
            vec3 base = cellColor.rgb;

            // Grow / pop spring animation from uFillAge + uTime
            float age = fillAge + uTime;
            float grow = clamp(age / 0.40, 0.0, 1.0);
            // Elastic spring curve: overshoot to 1.06 then settle to 1.0
            float spring = 1.0;
            if (grow < 1.0) {
                spring = 0.4 + 0.6 * sin(grow * 1.5708);
                if (grow > 0.6) {
                    spring += sin((grow - 0.6) * 3.14159 / 0.4) * 0.08;
                }
            }

            // Tilt-influenced light vector
            vec2 lightOffset = uTilt * 0.35;
            float bevel = 0.20 * clamp(spring, 0.5, 1.1);

            // Bevel facets:
            // Distance to 4 edges [left, top, right, bottom]
            float dLeft = cellUV.x;
            float dTop = cellUV.y;
            float dRight = 1.0 - cellUV.x;
            float dBottom = 1.0 - cellUV.y;

            vec3 voxelColor = base;

            // Determine which facet this fragment belongs to using 45-degree diagonals
            bool isTop = dTop < bevel && dTop <= dLeft && dTop <= dRight;
            bool isBottom = dBottom < bevel && dBottom <= dLeft && dBottom <= dRight;
            bool isLeft = dLeft < bevel && dLeft <= dTop && dLeft <= dBottom;
            bool isRight = dRight < bevel && dRight <= dTop && dRight <= dBottom;

            if (isTop) {
                // Top facet: strongly illuminated from top + dynamic tilt
                float topLight = 1.28 - lightOffset.y * 0.30;
                voxelColor = base * topLight;
            } else if (isLeft) {
                // Left facet: ambient light from left + dynamic tilt
                float leftLight = 1.12 - lightOffset.x * 0.25;
                voxelColor = base * leftLight;
            } else if (isRight) {
                // Right facet: shadow facet
                float rightDark = 0.82 + lightOffset.x * 0.20;
                voxelColor = base * rightDark;
            } else if (isBottom) {
                // Bottom facet: deep cast shadow facet
                float bottomDark = 0.68 + lightOffset.y * 0.25;
                voxelColor = base * bottomDark;
            } else {
                // Center raised plateau face
                voxelColor = base * 1.04;

                // Specular glint inside top-left corner of raised face
                vec2 innerUV = (cellUV - vec2(bevel)) / (1.0 - 2.0 * bevel);
                if (innerUV.x > 0.05 && innerUV.x < 0.40 && innerUV.y > 0.05 && innerUV.y < 0.32) {
                    float glintAlpha = smoothstep(0.40, 0.05, innerUV.x) * smoothstep(0.32, 0.05, innerUV.y);
                    voxelColor += vec3(0.24 * glintAlpha);
                }
            }

            // Specular ridge highlight along top and left outer edges
            float ridgeThresh = 0.035;
            if (cellUV.x < ridgeThresh || cellUV.y < ridgeThresh) {
                voxelColor += vec3(0.20);
            }

            // Dark seam groove along bottom and right outer edges
            if (cellUV.x > (1.0 - ridgeThresh) || cellUV.y > (1.0 - ridgeThresh)) {
                voxelColor *= 0.85;
            }

            // Impact flash sheen during early fill animation (< 120ms)
            if (age < 0.15) {
                float flash = (1.0 - age / 0.15) * 0.55;
                voxelColor += vec3(flash);
            }

            // Section completion shimmer sweep
            if (uShimmer >= 0.0 && uShimmer <= 1.0) {
                float diag = (cellCoord.x + cellCoord.y * 0.7) / max(uGrid.x + uGrid.y * 0.7, 1.0);
                float shimmerDist = abs(diag - uShimmer);
                if (shimmerDist < 0.09) {
                    float s = (1.0 - shimmerDist / 0.09);
                    voxelColor += vec3(s * s * 0.35);
                }
            }

            fragColor = vec4(clamp(voxelColor, 0.0, 1.0), 1.0);
        }
    }
}
