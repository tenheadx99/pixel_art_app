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

        // Distance from center
        float dist = length(cellUV - center);

        // Contact drop shadow from top & left neighbor beads
        float contactShadow = 0.0;
        if (cellCoord.y > 0.0) {
            float aTop = texture(uTexture, getTexUV(cellCoord - vec2(0.0, 1.0))).a;
            if (aTop > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.16, 0.0, cellUV.y) * 0.38);
            }
        }
        if (cellCoord.x > 0.0) {
            float aLeft = texture(uTexture, getTexUV(cellCoord - vec2(1.0, 0.0))).a;
            if (aLeft > 0.8) {
                contactShadow = max(contactShadow, smoothstep(0.16, 0.0, cellUV.x) * 0.32);
            }
        }

        // 1. Empty pegboard background: clean pegboard light slate with center peg pin
        if (cellColor.a < 0.01) {
            vec3 pegBg = vec3(0.945, 0.952, 0.960);
            // Peg socket guide ring
            float ring = abs(dist - 0.44);
            if (ring < 0.02) {
                pegBg -= vec3(0.04);
            }
            // Center peg pin
            if (dist < 0.10) {
                pegBg = mix(vec3(0.55, 0.58, 0.62), pegBg, dist / 0.10);
            }
            pegBg *= (1.0 - contactShadow);
            fragColor = vec4(pegBg, 1.0);
        }
        // 2. Unfilled cell: subtle preview tint with guide socket ring & center pin
        else if (cellColor.a < 0.75) {
            vec3 color = cellColor.rgb / max(cellColor.a, 0.001);
            float lum = dot(color, vec3(0.299, 0.587, 0.114));
            vec3 gray = vec3(clamp(0.70 + lum * 0.25, 0.70, 0.95));
            float t = clamp((uEffectiveCell - 11.0) / 7.0, 0.0, 1.0);
            vec3 cellBody = mix(color * 0.75, gray, t);

            // Guide ring
            float ring = abs(dist - 0.44);
            if (ring < 0.025 && gridLineOpacity > 0.1) {
                cellBody -= vec3(0.08 * gridLineOpacity);
            }
            // Center pin guide
            if (dist < 0.10 && gridLineOpacity > 0.1) {
                cellBody = mix(vec3(0.50, 0.52, 0.56), cellBody, dist / 0.10);
            }
            cellBody *= (1.0 - contactShadow);
            fragColor = vec4(cellBody, 1.0);
        }
        // 3. Filled Bead: 3D Cylindrical Fuse Bead (Perler / Hama Style)
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

            float outerRadius = 0.46 * clamp(spring, 0.5, 1.1);
            float holeRadius = outerRadius * 0.42;

            // Tilt-influenced light vector
            vec2 lightOffset = uTilt * 0.25;

            // Ground drop shadow onto pegboard
            vec2 shadowCenter = center + vec2(0.04, 0.07);
            float shadowDist = length(cellUV - shadowCenter);
            vec3 beadColor = vec3(0.945, 0.952, 0.960); // Pegboard background behind bead
            if (shadowDist < outerRadius * 1.08) {
                float s = smoothstep(outerRadius * 1.08, outerRadius * 0.75, shadowDist);
                beadColor *= (1.0 - s * 0.32);
            }

            // Lower cylinder depth extrusion (shaded underside)
            vec2 depthCenter = center + vec2(0.0, 0.05);
            if (length(cellUV - depthCenter) < outerRadius) {
                beadColor = base * 0.76;
            }

            // Main plastic cylinder body
            if (dist < outerRadius) {
                vec2 norm = (cellUV - center) / outerRadius;
                float bodyLight = dot(norm, normalize(vec2(-0.7, -0.7) + lightOffset));
                beadColor = base * (1.0 + bodyLight * 0.14);

                // Top-left rim bevel highlight
                float rimDist = abs(dist - (outerRadius - 0.035));
                if (rimDist < 0.032 && norm.x + norm.y < 0.0) {
                    float h = smoothstep(0.032, 0.0, rimDist) * smoothstep(0.5, -0.5, norm.x + norm.y);
                    beadColor += vec3(0.32 * h);
                }

                // Bottom-right rim bevel shadow
                if (rimDist < 0.032 && norm.x + norm.y > 0.0) {
                    float sh = smoothstep(0.032, 0.0, rimDist) * smoothstep(-0.5, 0.5, norm.x + norm.y);
                    beadColor *= (1.0 - sh * 0.26);
                }

                // Specular curved acrylic glint along top-left shoulder
                float glintRing = abs(dist - (outerRadius + holeRadius) * 0.5);
                if (glintRing < 0.03 && norm.x < -0.15 && norm.y < -0.15) {
                    float g = smoothstep(0.03, 0.0, glintRing);
                    beadColor += vec3(0.40 * g);
                }

                // Center hollow peg hole
                if (dist < holeRadius) {
                    // Deep cylindrical bore shadow
                    beadColor = base * 0.38;

                    // Peg pin visible at bottom of hole
                    if (dist < holeRadius * 0.55) {
                        beadColor = vec3(0.30, 0.32, 0.36);
                    }

                    // Far inner bore wall catches light at bottom-right
                    if (norm.x + norm.y > 0.0) {
                        float innerLight = smoothstep(0.0, holeRadius, dist) * smoothstep(-0.2, 0.5, norm.x + norm.y);
                        beadColor += base * (0.28 * innerLight);
                    }
                    // Near inner bore lip casts shadow at top-left
                    if (norm.x + norm.y < 0.0) {
                        float innerShadow = smoothstep(0.0, holeRadius, dist);
                        beadColor *= (1.0 - innerShadow * 0.35);
                    }
                }
            }

            // Impact snap flash during early fill animation (< 100ms)
            if (age < 0.12) {
                float flash = (1.0 - age / 0.12) * 0.55;
                beadColor += vec3(flash);
            }

            // Section completion shimmer sweep
            if (uShimmer >= 0.0 && uShimmer <= 1.0) {
                float diag = (cellCoord.x + cellCoord.y * 0.75) / max(uGrid.x + uGrid.y * 0.75, 1.0);
                float shimmerDist = abs(diag - uShimmer);
                if (shimmerDist < 0.09) {
                    float s = (1.0 - shimmerDist / 0.09);
                    beadColor += vec3(s * s * 0.35);
                }
            }

            fragColor = vec4(clamp(beadColor, 0.0, 1.0), 1.0);
        }
    }
}
