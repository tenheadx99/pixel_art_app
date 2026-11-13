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
    return (coord + vec2(0.5)) / uGrid;
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
    
    // Hairline Cell Outline Border (0.18 threshold = ultra-thin 0.36px grid line)
    vec2 borderThresh = vec2(0.18 / cellSize.x, 0.18 / cellSize.y);
    bool isCellBorder = cellUV.x < borderThresh.x || cellUV.x > (1.0 - borderThresh.x) ||
                        cellUV.y < borderThresh.y || cellUV.y > (1.0 - borderThresh.y);

    // Sample the grid texture at the texel center for this cell.
    vec2 texUV = getTexUV(cellCoord);
    vec4 cellColor = texture(uTexture, texUV);

    // --- 2.5D Drop Shadow from top-left neighbor gems ---
    // Physical diamonds have height above the canvas bed, casting soft shadows.
    float contactShadow = 0.0;
    if (cellCoord.y > 0.0) {
        float aTop = texture(uTexture, getTexUV(cellCoord - vec2(0.0, 1.0))).a;
        if (aTop > 0.8) {
            contactShadow = max(contactShadow, smoothstep(0.24, 0.0, cellUV.y) * 0.38);
        }
    }
    if (cellCoord.x > 0.0) {
        float aLeft = texture(uTexture, getTexUV(cellCoord - vec2(1.0, 0.0))).a;
        if (aLeft > 0.8) {
            contactShadow = max(contactShadow, smoothstep(0.24, 0.0, cellUV.x) * 0.38);
        }
    }
    if (cellCoord.x > 0.0 && cellCoord.y > 0.0) {
        float aDiag = texture(uTexture, getTexUV(cellCoord - vec2(1.0, 1.0))).a;
        if (aDiag > 0.8) {
            contactShadow = max(contactShadow, smoothstep(0.32, 0.0, length(cellUV)) * 0.44);
        }
    }

    // Empty cell -> subtle canvas fabric weave with contact shadow from placed gems
    if (cellColor.a < 0.01) {
        vec3 canvasBg = vec3(0.965, 0.968, 0.972);
        float weave = sin(pos.x * 0.8) * cos(pos.y * 0.8) * 0.015;
        canvasBg += weave;
        canvasBg *= (1.0 - contactShadow);
        fragColor = vec4(canvasBg, 1.0);
        return;
    }

    // Unfilled numbered cell -> direct transition from color to grey-out with contact shadow
    if (cellColor.a < 0.75) {
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

    // Filled Gem -> Full 2.5D Faceted Cushion Diamond Drill
    vec2 center = vec2(0.5);

    // Low LOD (< 10.0): Flat Square Tile
    if (uEffectiveCell < 10.0) {
        fragColor = vec4(cellColor.rgb, 1.0);
        return;
    }

    // --- Fill-animation timeline -------------------------------------------
    float age = texture(uFillAge, texUV).r * 1.6 + uTime;

    // Settle pop: the gem scales 0.68 -> ~1.04 -> 1.0 (ease-out-back) over 240ms
    vec2 uv = cellUV;
    if (age < 0.24) {
        float t0 = clamp(age / 0.24, 0.0, 1.0);
        float u = t0 - 1.0;
        float ease = 1.0 + 2.70158 * u * u * u + 1.70158 * u * u;
        float scale = mix(0.68, 1.0, ease);
        uv = center + (cellUV - center) / max(scale, 0.01);
        vec2 od = abs(uv - center);
        if (max(od.x, od.y) > 0.5) {
            vec3 canvasBg = vec3(0.965, 0.968, 0.972);
            fragColor = vec4(canvasBg, 1.0);
            return;
        }
    }

    vec2 dir = uv - center;
    float dist = length(dir);
    vec2 absDir = abs(dir);

    // Light Direction vector with Accelerometer Tilt
    vec2 shift = vec2(-0.707 - uTilt.x * 0.40, -0.707 + uTilt.y * 0.40);
    shift = clamp(shift, vec2(-1.20), vec2(1.20));
    vec2 lightDir = normalize(-shift);

    // Jewel color palette: rich saturation with dynamic 2.5D jewel contrast
    vec3 baseCol = cellColor.rgb;
    vec3 brightColor = min(baseCol * 1.08 + vec3(0.04), vec3(1.0));
    vec3 lightShade = min(brightColor + vec3(0.28), vec3(1.0));
    vec3 darkShade = brightColor * 0.60;

    // --- 1. Octagonal Table Cut & 8 Facet Sector Geometry ---
    float octDist = max(max(absDir.x, absDir.y), (absDir.x + absDir.y) * 0.7071);
    bool isTable = octDist < 0.165;

    // Angle of current fragment (-PI to PI)
    float angle = atan(dir.y, dir.x);
    
    // 8 Facet Sectors (0..7) around 360 degrees
    float sectorIndex = floor((angle + 3.14159265 + 0.392699) / 0.785398);
    float sectorAngle = (sectorIndex + 0.5) * 0.785398 - 3.14159265;
    vec2 facetNormal = vec2(cos(sectorAngle), sin(sectorAngle));

    // Per-facet lighting dot product with enhanced 2.5D jewel contrast
    float lightDot = dot(facetNormal, lightDir);
    float facetLighting = lightDot * 0.5 + 0.5;
    float facetIntensity = mix(0.70, 1.30, pow(facetLighting, 1.25));

    vec3 baseColor;
    if (isTable) {
        // Flat Table Facet (Raised top center octagonal plateau) with crystal glass sheen
        vec3 tableBase = min(brightColor * 1.12 + vec3(0.06), vec3(1.0));
        float crystalGlassSheen = smoothstep(0.165, 0.0, octDist);
        float tableLight = dot(lightDir, vec2(-0.707, -0.707));
        baseColor = mix(tableBase, lightShade, 0.28 * crystalGlassSheen + clamp(tableLight * 0.15, 0.0, 0.20));
    } else {
        // Crown Facet Body with dramatic stepped crystal refraction
        baseColor = clamp(brightColor * facetIntensity, darkShade, lightShade);
        // Crystal refraction highlights on light-facing crown facets
        if (lightDot > 0.0) {
            baseColor = mix(baseColor, lightShade * 1.15, lightDot * 0.28);
        } else {
            baseColor = mix(baseColor, darkShade * 0.85, (-lightDot) * 0.35);
        }
    }

    // --- 2. Crystal Facet Seams & Octagonal Table Border ---
    if (uEffectiveCell >= 14.0) {
        // Octagonal Table Border Line (Crystal Cut Edge)
        float tableBorderDist = abs(octDist - 0.165);
        if (tableBorderDist < 0.018) {
            if (lightDot > -0.1) {
                // Top-left table edge catches sharp specular brilliance
                baseColor = mix(baseColor, vec3(1.0), 0.55);
            } else {
                // Bottom-right table edge has crisp facet step shadow
                baseColor = mix(baseColor, darkShade * 0.60, 0.45);
            }
        }

        // Radial Facet Seams (Subtle crystal ridge lines)
        float facetEdge = abs(fract((angle + 3.14159265) / 0.785398) - 0.5);
        if (facetEdge < 0.038 && octDist >= 0.165 && max(absDir.x, absDir.y) < 0.44) {
            if (lightDot > -0.2) {
                baseColor = mix(baseColor, vec3(1.0), 0.30);
            } else {
                baseColor = mix(baseColor, darkShade * 0.65, 0.35);
            }
        }
    }

    // --- 3. 2.5D Cushion Outer Bevel & Inter-Drill Crevice ---
    float maxEdge = max(absDir.x, absDir.y);
    if (maxEdge > 0.38) {
        float bevelT = smoothstep(0.38, 0.48, maxEdge);
        float edgeDirDot = dot(normalize(dir), lightDir);
        if (edgeDirDot > 0.1) {
            // Top/left rim highlight
            baseColor = mix(baseColor, lightShade * 1.15, bevelT * 0.45);
        } else {
            // Bottom/right rim shadow
            baseColor = mix(baseColor, darkShade * 0.60, bevelT * 0.50);
        }

        // Inter-drill micro crevice seam (drills meet with tactile physical depth)
        if (maxEdge > 0.46) {
            float seam = smoothstep(0.46, 0.50, maxEdge);
            baseColor = mix(baseColor, darkShade * 0.35, seam * 0.65);
        }
    }

    // --- 4. Refined Crystal Specular Sparkle & 4-Point Star Glints ---
    vec2 specPos = center + shift * 0.15;
    float specDist = length(uv - specPos);

    // Soft Wide Crystal Halo
    if (specDist < 0.20) {
        float halo = smoothstep(0.20, 0.0, specDist);
        baseColor = mix(baseColor, vec3(1.0), halo * 0.35);
    }

    // White Crystal Pinpoint Specular Glint
    if (specDist < 0.07) {
        float core = smoothstep(0.07, 0.0, specDist);
        baseColor = mix(baseColor, vec3(1.0), core * 0.85);
    }

    // 4-Point Crisp Star Flare Glint (Zoom >= 16.0)
    if (uEffectiveCell >= 16.0 && specDist < 0.22) {
        vec2 specDir = abs(uv - specPos);
        if ((specDir.x < 0.015 && specDir.y < 0.16) || (specDir.y < 0.015 && specDir.x < 0.16)) {
            float crossIntensity = smoothstep(0.16, 0.0, max(specDir.x, specDir.y));
            baseColor = mix(baseColor, vec3(1.0), crossIntensity * 0.65);
        }
    }

    // Afterglow + glint sweep: a warm landing flash that fades over 450ms
    if (age < 0.55) {
        float glow = 1.0 - clamp(age / 0.45, 0.0, 1.0);
        baseColor = mix(baseColor, vec3(1.0, 0.97, 0.88), glow * glow * 0.18);
        if (age > 0.15) {
            float gt = clamp((age - 0.15) / 0.35, 0.0, 1.0);
            float gpos = (uv.x + uv.y) * 0.5;
            float sweep = mix(-0.25, 1.25, gt);
            float d = abs(gpos - sweep);
            if (d < 0.14) {
                float streak = 1.0 - d / 0.14;
                baseColor = mix(baseColor, vec3(1.0), streak * streak * 0.35 * (1.0 - gt));
            }
        }
    }

    // Section-complete shimmer: one skewed bright band sweeping every placed gem
    if (uShimmer > 0.001 && uShimmer < 0.999) {
        float q = (pos.x + pos.y * 0.35) / (uSize.x + uSize.y * 0.35);
        float band = mix(-0.2, 1.2, uShimmer);
        float bd = abs(q - band);
        if (bd < 0.09) {
            float s = 1.0 - bd / 0.09;
            baseColor = mix(baseColor, vec3(1.0), s * s * 0.45);
        }
    }

    fragColor = vec4(baseColor, 1.0);
}
