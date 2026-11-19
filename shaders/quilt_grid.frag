#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform vec2 u_grid_size;
uniform vec2 u_tilt;
uniform float u_cell_size;
uniform float u_time;
uniform float u_shimmer;
uniform sampler2D u_texture;
uniform sampler2D u_age_texture;

out vec4 fragColor;

void main() {
    vec2 frag_coord = FlutterFragCoord().xy;
    vec2 grid_px = u_grid_size * u_cell_size;
    vec2 offset = (u_resolution - grid_px) * 0.5;
    vec2 pos = frag_coord - offset;

    vec4 out_col = vec4(0.0);

    if (pos.x < 0.0 || pos.y < 0.0 || pos.x >= grid_px.x || pos.y >= grid_px.y) {
        // Out of bounds - warm antique linen background
        vec2 linen_uv = frag_coord * 0.15;
        float linen_noise = sin(linen_uv.x * 20.0) * sin(linen_uv.y * 20.0) * 0.03;
        out_col = vec4(vec3(0.925, 0.898, 0.847) + linen_noise, 1.0);
    } else {
        vec2 cell_coord = pos / u_cell_size;
        vec2 cell_index = floor(cell_coord);
        vec2 in_cell = fract(cell_coord);

        vec2 uv = (cell_index + 0.5) / u_grid_size;
        vec4 sample_col = texture(u_texture, uv);
        vec4 age_data = texture(u_age_texture, uv);

        bool is_revealed = sample_col.a > 0.5;
        vec3 base_color = sample_col.rgb;

        float fill_time = age_data.r * 255.0 + age_data.g * 255.0 * 256.0 + age_data.b * 255.0 * 65536.0;
        float age = u_time - fill_time;

        float grow = 1.0;
        float flash = 0.0;
        if (fill_time > 0.0 && age >= 0.0 && age < 0.6) {
            float t = clamp(age / 0.42, 0.0, 1.0);
            float c1 = 1.70158;
            float c3 = c1 + 1.0;
            grow = 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0);
            flash = clamp(1.0 - (age / 0.28), 0.0, 1.0);
        }

        vec2 p = in_cell - 0.5;

        // Linen fabric background for unrevealed cells and cell gaps
        vec2 weave_coord = frag_coord * 0.5;
        float weave = sin(weave_coord.x) * cos(weave_coord.y) * 0.035;
        vec3 linen_bg = vec3(0.925, 0.898, 0.847) + weave;

        if (!is_revealed) {
            // Unfilled cell with faint basting guide stitches
            vec2 d_edge = abs(p);
            float max_d = max(d_edge.x, d_edge.y);
            float basting_seam = abs(max_d - 0.46);
            float stitch_pattern = sin(frag_coord.x * 0.8 + frag_coord.y * 0.8);
            vec3 cell_base = linen_bg * 0.96;
            if (basting_seam < 0.02 && stitch_pattern > 0.1) {
                cell_base = mix(cell_base, vec3(0.54, 0.50, 0.43), 0.45);
            }
            out_col = vec4(cell_base, 1.0);
        } else {
            // Patchwork swatch fabric
            float scale = max(0.01, grow);
            vec2 p_scaled = p / scale;

            float d_patch = max(abs(p_scaled.x), abs(p_scaled.y));

            if (d_patch > 0.48) {
                // Beyond patch bounds (inter-patch linen groove/seam)
                float seam_shadow = smoothstep(0.48, 0.52, d_patch);
                vec3 seam_col = mix(linen_bg * 0.75, linen_bg, seam_shadow);
                out_col = vec4(seam_col, 1.0);
            } else {
                // Inside quilt patch
                // 1. Pillow cushion depth (center puffy elevation, edge dip)
                float r2 = dot(p_scaled, p_scaled);
                float cushion = 1.0 - r2 * 0.7;

                // 2. Fine textile fabric woven texture
                float fine_weave = (sin(p_scaled.x * u_cell_size * 2.5) * cos(p_scaled.y * u_cell_size * 2.5)) * 0.045;

                // 3. Directional lighting with soft cushion gradient
                vec2 light_dir = normalize(vec2(-0.4, -0.6) + u_tilt * 0.35);
                float light_grad = dot(-p_scaled, light_dir) * 0.18;

                vec3 fabric_rgb = base_color * (0.92 + fine_weave + light_grad) * cushion;

                // 4. Quilted perimeter running stitch (dashed seam)
                // Seam line runs around an inset box at distance ~0.38
                vec2 seam_d = abs(abs(p_scaled) - 0.38);
                bool on_seam_box = (seam_d.x < 0.018 && abs(p_scaled.y) <= 0.38) ||
                                  (seam_d.y < 0.018 && abs(p_scaled.x) <= 0.38);

                if (on_seam_box) {
                    // Running stitch dashes: periodic along perimeter
                    float stitch_coord = (seam_d.x < seam_d.y) ? p_scaled.y : p_scaled.x;
                    float dash_cycle = fract(stitch_coord * 12.0);
                    if (dash_cycle < 0.55) {
                        // Thread highlight & stitch puncture hole shadow
                        float thread_core = 1.0 - abs(dash_cycle - 0.275) / 0.275;
                        vec3 thread_col = mix(vec3(0.95, 0.94, 0.88), vec3(0.25, 0.18, 0.12), 0.35);
                        fabric_rgb = mix(fabric_rgb, thread_col * (0.8 + 0.4 * thread_core), 0.85);
                    } else {
                        // Needle puncture indentation shadow
                        fabric_rgb *= 0.65;
                    }
                }

                // 5. Satin fabric sheen reflection tilted with device
                vec2 tilt_norm = u_tilt * 0.45;
                float dist_sheen = length(p_scaled - tilt_norm);
                float fabric_sheen = exp(-dist_sheen * dist_sheen * 9.0) * 0.16;
                fabric_rgb += vec3(fabric_sheen);

                // 6. Section shimmer celebration wave
                if (u_shimmer < 1.0) {
                    float shimmer_diag = (cell_coord.x + cell_coord.y * 0.35) / (u_grid_size.x + u_grid_size.y * 0.35);
                    float shimmer_band = u_shimmer * 1.4 - 0.2;
                    float dist = abs(shimmer_diag - shimmer_band);
                    if (dist < 0.08) {
                        float s = (1.0 - dist / 0.08);
                        fabric_rgb += vec3(0.35 * s * s);
                    }
                }

                // 7. Impact spring flash
                if (flash > 0.0) {
                    fabric_rgb = mix(fabric_rgb, vec3(1.0, 0.97, 0.9), flash * 0.55);
                }

                out_col = vec4(fabric_rgb, 1.0);
            }
        }
    }

    fragColor = out_col;
}
