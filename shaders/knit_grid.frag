#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uGrid;
uniform vec2 uTilt;
uniform float uEffectiveCell;
uniform float uTime;
uniform float uShimmer;
uniform sampler2D uTexture;
uniform sampler2D uFillAge;

out vec4 fragColor;

vec2 getTexUV(vec2 coord) {
    return (coord + vec2(0.5)) / uGrid;
}

// Distance from point p to line segment A-B, returning vec2(dist, h_t)
vec2 dist_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 cellSize = uSize / uGrid;
    vec2 cellCoord = floor(pos / cellSize);

    vec4 out_col = vec4(0.0);

    if (cellCoord.x < 0.0 || cellCoord.y < 0.0 || cellCoord.x >= uGrid.x || cellCoord.y >= uGrid.y) {
        // Out of bounds - cozy oatmeal fleece backing
        vec2 fleece_uv = pos * 0.2;
        float noise = sin(fleece_uv.x * 12.0) * cos(fleece_uv.y * 12.0) * 0.025;
        out_col = vec4(vec3(0.91, 0.88, 0.83) + noise, 1.0);
    } else {
        vec2 in_cell = fract(pos / cellSize);

        vec2 uv = getTexUV(cellCoord);
        vec4 sample_col = texture(uTexture, uv);
        float fillAge = texture(uFillAge, uv).r;

        bool is_revealed = sample_col.a > 0.75;
        vec3 base_color = sample_col.rgb;

        float age = fillAge * 1.6 + uTime;

        float grow = 1.0;
        float flash = 0.0;
        if (age >= 0.0 && age < 0.6) {
            float t = clamp(age / 0.42, 0.0, 1.0);
            float c1 = 1.70158;
            float c3 = c1 + 1.0;
            grow = 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0);
            flash = clamp(1.0 - (age / 0.28), 0.0, 1.0);
        }

        vec2 p = in_cell - 0.5;

        // Oatmeal heather yarn backing
        vec3 yarn_bg = vec3(0.88, 0.85, 0.80);

        if (!is_revealed) {
            // Unfilled cell with subtle guide V-loop
            vec2 seg_l = dist_segment(p, vec2(-0.35, -0.38), vec2(0.0, 0.38));
            vec2 seg_r = dist_segment(p, vec2(0.0, 0.38), vec2(0.35, -0.38));
            float d_v = min(seg_l.x, seg_r.x);
            vec3 cell_bg = yarn_bg * 0.95;
            if (d_v < 0.06) {
                cell_bg = mix(cell_bg, vec3(0.55, 0.52, 0.48), 0.35);
            }
            // Fine cell edge seam
            vec2 d_edge = abs(p);
            if (max(d_edge.x, d_edge.y) > 0.48) {
                cell_bg *= 0.88;
            }
            out_col = vec4(cell_bg, 1.0);
        } else {
            // Interlocking 3D V-stitch woolen yarn
            float scale = max(0.01, grow);
            vec2 p_scaled = p / scale;

            // Deep background yarn shadow behind loops
            vec3 dark_base = base_color * 0.32;

            // Left strand: (-0.36, -0.40) to (0.0, 0.38)
            vec2 pt_tl = vec2(-0.36, -0.40);
            vec2 pt_tr = vec2(0.36, -0.40);
            vec2 pt_bc = vec2(0.0, 0.38);

            vec2 l_data = dist_segment(p_scaled, pt_tl, pt_bc);
            vec2 r_data = dist_segment(p_scaled, pt_tr, pt_bc);

            float radius = 0.17;

            // Right strand overlaps over left strand slightly near bottom V crossover
            bool right_on_top = (r_data.x < radius) && ((l_data.x >= radius) || (p_scaled.y > 0.1));

            float dist = right_on_top ? r_data.x : l_data.x;
            float h_pos = right_on_top ? r_data.y : l_data.y;
            bool on_strand = dist < radius;

            if (!on_strand) {
                // Check if inside the other strand
                float other_dist = right_on_top ? l_data.x : r_data.x;
                if (other_dist < radius) {
                    on_strand = true;
                    dist = other_dist;
                    h_pos = right_on_top ? l_data.y : r_data.y;
                }
            }

            if (!on_strand) {
                // Background gap between knit strands with cast shadow
                float min_d = min(l_data.x, r_data.x);
                float shadow = smoothstep(radius, radius + 0.12, min_d);
                vec3 gap_color = mix(dark_base, yarn_bg * 0.55, shadow);
                out_col = vec4(gap_color, 1.0);
            } else {
                // Inside 3D cylindrical yarn strand
                float norm_d = dist / radius;
                float normal_z = sqrt(max(0.0, 1.0 - norm_d * norm_d));

                // 1. Cylindrical lighting: diffuse 3D cylinder curve
                vec2 strand_dir = right_on_top ? normalize(pt_tr - pt_bc) : normalize(pt_bc - pt_tl);
                vec2 strand_norm = vec2(-strand_dir.y, strand_dir.x);
                float lateral = dot(p_scaled - (right_on_top ? (pt_bc + (pt_tr - pt_bc) * h_pos) : (pt_tl + (pt_bc - pt_tl) * h_pos)), strand_norm) / radius;

                vec3 light_dir = normalize(vec3(-0.4 + uTilt.x * 0.35, -0.6 - uTilt.y * 0.35, 0.7));
                vec3 surf_norm = normalize(vec3(strand_norm * lateral, normal_z));
                float diff = max(0.0, dot(surf_norm, light_dir));

                // 2. Twisted woolen yarn fibers (sinusoidal twist along strand length)
                float twist = sin(h_pos * 32.0 + lateral * 6.0) * 0.08;

                vec3 yarn_rgb = base_color * (0.65 + 0.45 * diff + twist);

                // 3. Soft specular sheen reflecting along the curved fiber
                vec3 view_dir = vec3(0.0, 0.0, 1.0);
                vec3 half_vec = normalize(light_dir + view_dir);
                float spec = pow(max(0.0, dot(surf_norm, half_vec)), 14.0);
                yarn_rgb += vec3(spec * 0.28);

                // 4. Overlap crossover shadow where right strand casts shadow on left strand
                if (!right_on_top && r_data.x < radius * 1.5 && p_scaled.y > 0.05) {
                    float crossover_shadow = smoothstep(radius * 0.7, radius * 1.5, r_data.x);
                    yarn_rgb *= mix(0.55, 1.0, crossover_shadow);
                }

                // 5. Section complete shimmer celebration wave
                if (uShimmer < 1.0) {
                    float shimmer_diag = (cellCoord.x + cellCoord.y * 0.35) / (uGrid.x + uGrid.y * 0.35);
                    float shimmer_band = uShimmer * 1.4 - 0.2;
                    float s_dist = abs(shimmer_diag - shimmer_band);
                    if (s_dist < 0.08) {
                        float s = (1.0 - s_dist / 0.08);
                        yarn_rgb += vec3(0.4 * s * s);
                    }
                }

                // 6. Impact spring flash
                if (flash > 0.0) {
                    yarn_rgb = mix(yarn_rgb, vec3(1.0, 0.98, 0.92), flash * 0.6);
                }

                out_col = vec4(yarn_rgb, 1.0);
            }
        }
    }

    fragColor = out_col;
}
