#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uGrid;
uniform vec2 uTilt;
uniform float uEffectiveCell;
uniform sampler2D uTexture;

out vec4 fragColor;

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
    
    // Hairline Cell Outline Border (0.18 threshold = ultra-thin 0.36px grid line)
    vec2 borderThresh = vec2(0.18 / cellSize.x, 0.18 / cellSize.y);
    bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                        cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);

    // Sample texture for cell color & preview
    vec2 texUV = (cellCoord + vec2(0.5)) / uGrid;
    vec4 cellColor = texture(uTexture, texUV);
    
    // Unfilled cell -> cellColor.a == 0.0 (RGB contains grayscale artwork preview!)
    if (cellColor.a < 0.01) {
        // Zoomed Out LOD (< 10.0): Display complete grayscale artwork preview (Image 1)
        if (uEffectiveCell < 10.0) {
            fragColor = vec4(cellColor.rgb, 1.0);
            return;
        }
        
        // Zoomed In LOD (>= 10.0): Transition background to clean white #FFFFFF with hairline #CCCCCC grid lines (Image 2)
        float fade = clamp((uEffectiveCell - 10.0) / 6.0, 0.0, 1.0);
        vec3 bgWhite = isCellBorder ? vec3(0.86, 0.86, 0.86) : vec3(1.0, 1.0, 1.0);
        vec3 finalBg = mix(cellColor.rgb, bgWhite, fade);
        fragColor = vec4(finalBg, 1.0);
        return;
    }

    // Filled Gem -> cellColor.a > 0.01
    vec2 center = vec2(0.5);
    float r = 0.45;
    float dist = length(cellUV - center);

    // Outside round gem -> render cell background + grid line
    if (dist > r) {
        vec3 bgWhite = isCellBorder ? vec3(0.86, 0.86, 0.86) : vec3(1.0, 1.0, 1.0);
        fragColor = vec4(bgWhite, 1.0);
        return;
    }

    // Low LOD: Flat Circle
    if (uEffectiveCell < 10.0) {
        vec3 col = (dist > (r - 0.03)) ? cellColor.rgb * 0.70 : cellColor.rgb;
        fragColor = vec4(col, 1.0);
        return;
    }

    // 3D Dome Shading with Light Source + Accelerometer Tilt
    vec2 shift = vec2(-0.707 - uTilt.x * 0.40, -0.707 + uTilt.y * 0.40);
    shift = clamp(shift, vec2(-1.20), vec2(1.20));

    // Light source center offset
    vec2 lightCenter = center + shift * 0.14;
    float lightDist = length(cellUV - lightCenter);
    float t = clamp(lightDist / 0.65, 0.0, 1.0);

    vec3 lightShade = min(cellColor.rgb + vec3(0.38), vec3(1.0));
    vec3 darkShade = cellColor.rgb * 0.58;
    vec3 baseColor = mix(lightShade, darkShade, t);

    // Bevel Outer Ring for crisp gem edge definition
    if (dist > (r * 0.82)) {
        baseColor = mix(baseColor, darkShade * 0.60, 0.60);
    }

    // Tier 3 High Detail: 8 Crown Facet Lines & Table Facet (uEffectiveCell >= 18.0)
    if (uEffectiveCell >= 18.0) {
        vec2 dir = cellUV - center;
        float angle = atan(dir.y, dir.x);
        float facetLine = abs(sin(angle * 4.0));
        if (facetLine < 0.08 && dist > 0.18 && dist < (r * 0.86)) {
            baseColor = mix(baseColor, vec3(1.0), 0.18);
        }
        // Table Facet (Flat top cut)
        if (dist < 0.18) {
            baseColor = mix(baseColor, lightShade, 0.22);
        }
    }

    // Dynamic Specular Highlight & Glint Halo (Smooth spherical dome reflection)
    vec2 specPos = center + shift * 0.20;
    float specDist = length(cellUV - specPos);
    
    // Soft Specular Halo
    if (specDist < 0.18) {
        float halo = smoothstep(0.18, 0.0, specDist);
        baseColor = mix(baseColor, vec3(1.0), halo * 0.50);
    }
    
    // Sharp Core Specular Highlight
    if (specDist < 0.08) {
        float core = smoothstep(0.08, 0.0, specDist);
        baseColor = mix(baseColor, vec3(1.0), core * 0.80);
    }

    fragColor = vec4(baseColor, 1.0);
}
