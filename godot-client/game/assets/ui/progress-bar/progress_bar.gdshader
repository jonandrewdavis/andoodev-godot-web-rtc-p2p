shader_type canvas_item;

// - PROGRESS BAR SHADER – GODOT 4.4 (CanvasItem).
// - How to use: Add a ColorRect in your scene and attach this shader to it. Then choose the modes and effects you like.
//   That's it! This shader was designed to quickly add a cool progress/health/loading bar.
// - You can also choose to use a custom frame texture. Note that you will need to adjust the according custom frame
//   parameters to fit the progress bar in it correctly.
// - Feel free to use this shader as you like. I use it for prototyping, but it's probably good enough for a final product.
//   If you use this shader and release a game, let me know (if you want of course!) I am curious to see how it works!
//   If you have any questions, contact me at:
// - Twitter/X, YouTube, Instagram, Discord: @LesusX

// ============================================================================
// UNIFORMS
// ============================================================================

group_uniforms GeneralSettings;
//** Premade bar options: Solid, RGB segments, Health Bar (red-yellow-green), Rainbow Wave */
uniform int bar_mode : hint_enum("Solid", "RGB", "Health Bar", "Rainbow Wave", "Fluid") = 0;
//** How the progress bar fills: Discrete (segments), Fade (fade in and out), Pour (fluid-like) */
uniform int fill_mode : hint_enum("Discrete", "Fade", "Pour") = 0;
//** Number of segments in the progress bar */
uniform int segment_count : hint_range(1, 50) = 12;
//** Fill amount for discrete mode (number of segments filled) */
uniform int discrete_fill_amount : hint_range(0, 100) = 12;
//** Fill amount for fade mode (0.0 to 1.0) */
uniform float fade_fill_amount : hint_range(0.0, 1.0) = 1.0;
//** Fill amount for pour mode (0.0 to 1.0) */
uniform float pour_fill_amount : hint_range(0.0, 1.0) = 1.0;
//** Animation speed for Rainbow Wave mode */
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;

// Flash effects
uniform int flash_type : hint_enum("None", "Segment Flash", "Single Segment Flash", "Drain Flash", "Drain Solid Flash", "Multi Segment Flash") = 0;
//** Which segment to flash (0-based index)
// NOTE: This parameter can't be used directly from the inspector. They are meant to be used by a script */
uniform int flash_segment : hint_range(0, 100) = 0;
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float single_segment_previous_fill : hint_range(0.0, 1.0) = 1.0;
uniform float single_segment_current_fill : hint_range(0.0, 1.0) = 1.0;
uniform float single_segment_flash_intensity : hint_range(0.0, 1.0) = 0.8;
uniform int flash_from_segment : hint_range(0, 100) = 0;
uniform int flash_to_segment : hint_range(0, 100) = 0;

// Single segment fade transition
uniform float single_segment_fade_from : hint_range(0.0, 1.0) = 1.0;
uniform float single_segment_fade_to : hint_range(0.0, 1.0) = 1.0;
uniform float single_segment_fade_progress : hint_range(0.0, 1.0) = 0.0;

// Drain effects
uniform float drain_previous_fill : hint_range(0.0, 1.0) = 1.0;
uniform float drain_current_fill : hint_range(0.0, 1.0) = 1.0;
uniform float drain_time_progress : hint_range(0.0, 1.0) = 0.0;

// Colors
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 filled_color : source_color = vec4(1.0, 0.85, 0.0, 1.0);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 drain_flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Frame
group_uniforms CustomFrame;
uniform bool custom_frame = false;
//** Frame texture used to contain the progress bar
// NOTE 1: This texture is used to generate a mask which later is used for the progress bar to be placed in. For best results use a good quality frame
// NOTE 2: Blurry textures may require higher scan steps.
// NOTE 3: Pixel perfect textures dot always work well */
uniform sampler2D frame_texture : source_color;
//** Trimming factor (0.0 = no trim, 0.05 = trims 5% on all sides) used to trim the mask produced by the provided frame texture*/
uniform float frame_trim : hint_range(0.0, 0.1) = 0.0;
//** Alpha threshold to distinguish opaque vs transparent areas arround the in frame. In case of bleeding pixels increase this value
// NOTE: Depending on the frame texture high values may remove the frame. Lower values are recomended if possible */
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.69;
//** Scanning precision for frame mask detection (higher = more accurate but less efficient for older devices)
// NOTE: Values between 15-35 work best. Above 100 may provide slightly more accuracy at the cost of efficiency */
uniform int scan_steps : hint_range(5, 60) = 15;
//** Smooths out the outline of the texture frame */
uniform float edge_smoothness : hint_range(0.0, 0.1) = 0.02;
//** Expand/contract the mask area slightly. Default value of 0 works best but can be adjusted to fit smaller/complex textures */
uniform float mask_expansion : hint_range(-0.3, 0.3) = 0.0;
//** Boost opacity of frame edges to prevent bleed-through
// NOTE: Adjust this value if the texture is of low quality with inconsistent border opacity */
uniform float frame_edge_opacity : hint_range(0.5, 3.0) = 0.9;

// Fluid
group_uniforms FluidModeSettings;
uniform vec4 fluid_base_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 fluid_highlight_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 fluid_shadow_color : source_color = vec4(0.1, 0.3, 0.6, 1.0);
uniform float fluid_flow_speed : hint_range(0.1, 5.0) = 1.5;
uniform float fluid_turbulence : hint_range(0.1, 3.0) = 1.0;
uniform float fluid_noise_scale : hint_range(1.0, 20.0) = 6.0;
//** Gas mode (makes it more ethereal and wispy)
// Usually gas mode gives a nicer look */
uniform bool gas_mode = false;
uniform float gas_intensity : hint_range(0.1, 6.0) = 0.8;

// Visual effects
group_uniforms EffectSettings;
uniform int effect_mode : hint_enum("None", "Wave", "Bubbles", "Glitch", "Static", "Pixel Static") = 0;
uniform float effect_strength : hint_range(0.0, 3.0) = 0.3;
uniform float effect_speed : hint_range(0.1, 5.0) = 1.5;
//** Influences the thickness of the wave effect.
// NOTE: Can't influence any other effect. */
uniform float wave_thickness : hint_range(0.01, 0.5) = 0.1;
//** Aspect ratio correction for the bubble effect.
// NOTE: Can't influence any other effect. */
uniform float bubbles_aspect_ratio = 1.0;
uniform bool vertical_gradient = true;
uniform float V_gradient_strength : hint_range(0.0, 1.0) = 0.6;
uniform bool horizontal_gradient = false;
uniform float H_gradient_strength : hint_range(0.0, 1.0) = 0.75;

// Segment layout
group_uniforms SegmentSettings;
//** Gap between segments (0.0 = no gap, 0.1 = 10% gap).
// NOTE: Values above 0.5 usually are not needed but in case more than 1.0 is required change the range of this parameter at line 119*/
uniform float segment_gap : hint_range(0.0, 1.0) = 0.05;
//** Universal thickness of segment borders. When adjusted all four sizes scale equally.
// NOTE: For better acuracy use the parameters bellow. */
uniform float universal_border_size : hint_range(0.0, 0.3) = 0.1;
uniform float horizontal_border_size = 1.0;
uniform float inner_border_thickness_multiplier = 1.0;
uniform float outer_border_size = 3.0;
//** Amount of slant/skew applied to segments (0.0 = rectangular).
// TIP: For non rectangular segments set the margin parameter value to the same value as the slant amount but always negative.
// EX: Slant: 0.1 = Margin -0.1. Slant: -0.04 = Margin: -0.04 */
uniform float slant_amount : hint_range(-0.5, 0.5) = 0.0;
//** Generally scale down/up the entire progressbar */
uniform float scale : hint_range(-1.0, 1.0) = 0.0;
//** Adjust clipping margin for slanted segments if corners are cut off */
uniform float slant_clip_margin : hint_range(-0.1, 0.1) = 0.0;

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/// Hash function for pixel static effect
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

/// 2D noise function for somewhat organic effect patterns
float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise2D(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec2 domain_warp(vec2 p, float time) {
    float warp_strength = fluid_turbulence * 0.3;
    vec2 q = vec2(fbm(p, 4), fbm(p + vec2(5.2, 1.3), 4));
    vec2 r = vec2(
        fbm(p + 4.0 * q + vec2(1.7 - time * 0.15, 9.2), 4),
        fbm(p + 4.0 * q + vec2(8.3 - time * 0.126, 2.8), 4)
    );
    return p + warp_strength * r;
}

vec4 generate_fluid_color(vec2 uv, float segment_index, float fill_ratio) {
    float time_offset = TIME * fluid_flow_speed;
    vec2 noise_uv = uv * fluid_noise_scale;
    noise_uv.x -= time_offset;

    vec2 warped_uv = domain_warp(noise_uv, time_offset);
    float flow_noise = fbm(warped_uv, 5);
    float turbulence = fbm(warped_uv * 2.0 + vec2(time_offset * 0.7, -time_offset * 0.3), 3) * 0.5;
    float combined_noise = flow_noise + turbulence * fluid_turbulence;

    float depth_factor = gas_mode ? 1.0 - uv.y : uv.y;

    vec2 bubble_uv = uv * 8.0;
    bubble_uv.x -= time_offset * 1.5;
    bubble_uv.y += sin(uv.x * 6.0 + time_offset) * 0.2;

    float bubble_pattern = 0.0;
    for (int i = 0; i < 3; i++) {
        float bubble_scale = pow(2.0, float(i));
        bubble_pattern += noise2D(bubble_uv * bubble_scale) / bubble_scale;
    }

    float wisp_factor = 1.0;
    if (gas_mode) {
        wisp_factor = smoothstep(0.2, 0.8, combined_noise) * gas_intensity;
        bubble_pattern *= 0.3;
        float wisp_flow = fbm(vec2(uv.x * 3.0, uv.y * 2.0 - time_offset * 0.5), 4);
        combined_noise = mix(combined_noise, wisp_flow, 0.4);
    }

    float highlight_factor = smoothstep(0.6, 1.0, combined_noise + bubble_pattern * 0.3);
    float shadow_factor = smoothstep(0.4, 0.0, combined_noise);

    vec3 final_color = fluid_base_color.rgb;
    final_color = mix(fluid_shadow_color.rgb, final_color, depth_factor * 0.7 + 0.3);
    final_color = mix(final_color, fluid_highlight_color.rgb, highlight_factor * 0.8);
    final_color = mix(final_color, fluid_shadow_color.rgb, shadow_factor * 0.4);

    if (gas_mode) {
        final_color = mix(final_color, fluid_highlight_color.rgb, (1.0 - wisp_factor) * 0.3);
        return vec4(final_color, fluid_base_color.a * (0.7 + wisp_factor * 0.3));
    }

    float surface_flow = sin(uv.x * 4.0 - TIME * fluid_flow_speed * 2.0) * 0.1 + 0.9;
    final_color *= surface_flow;
    return vec4(final_color, fluid_base_color.a);
}

vec4 apply_effect(vec4 base_color, vec2 uv, float segment_index, float fill_ratio) {
    float t = TIME * effect_speed;

    if (effect_mode == 1) { // Wave
        float wave_pos = fract(-uv.x + t);
        float dist = abs(wave_pos - 0.5);
        float wave = exp(-pow(dist / wave_thickness, 2.0));
        base_color.rgb = mix(base_color.rgb, vec3(1.0), wave * effect_strength);
    }
      // TODO: Make bubbles more random and organic
      else if (effect_mode == 2) { // Bubbles
        float bubbles = 0.0;
        vec2 uv_corrected = vec2(uv.x, uv.y * bubbles_aspect_ratio);
        for (float i = 0.0; i < 4.0; i++) {
            float y = (i + 1.0) / 5.0;
            float x = fract(t * 0.3 + i * 0.25);
            float dist = distance(vec2(x, y * bubbles_aspect_ratio), uv_corrected);
            bubbles += smoothstep(0.05, 0.0, dist);
        }
        base_color.rgb += vec3(bubbles * effect_strength);
    } else if (effect_mode == 3) { // Glitch
        float noise = hash(vec2(floor(uv.y * 50.0), floor(t * 20.0)));
        float glitch = step(1.0 - effect_strength, noise);
        base_color.rgb = mix(base_color.rgb, vec3(1.0), glitch * 0.2);
        base_color.rgb *= 1.0 - glitch * 0.3;
    } else if (effect_mode == 4) { // Static
        float noise1 = hash(uv * 100.0 + t);
        float noise2 = hash(uv * 50.0 - t * 0.5);
        float static_amount = (noise1 * noise2) * effect_strength;
        base_color.r *= mix(1.0, noise1, static_amount * 0.8);
        base_color.g *= mix(1.0, noise2, static_amount * 0.9);
        base_color.b *= mix(1.0, (noise1 + noise2) * 0.5, static_amount);
        float brightness = 0.8 + 0.2 * hash(uv * 10.0 + t * 2.0);
        base_color.rgb *= brightness;
    } else if (effect_mode == 5) { // Pixel Static
        float pixelSize = mix(50.0, 10.0, effect_strength);
        vec2 pixelatedUV = floor(uv * pixelSize) / pixelSize;
        float seed = hash(pixelatedUV + floor(TIME * effect_speed * 10.0));
        float threshold = mix(0.7, 0.3, effect_strength);
        float pixelActive = step(threshold, seed);

        vec3 pixelColor = base_color.rgb;
        if (pixelActive > 0.5) {
            float colorVar = hash(pixelatedUV * 2.0);
            pixelColor.r *= 0.8 + 0.4 * colorVar;
            pixelColor.g *= 0.7 + 0.5 * hash(pixelatedUV * 3.0);
            pixelColor.b *= 0.9 + 0.3 * hash(pixelatedUV * 5.0);
        } else {
            pixelColor *= 0.3 + 0.2 * hash(pixelatedUV);
        }
        base_color.rgb = mix(base_color.rgb, pixelColor, effect_strength * 1.5);
    }

    return base_color;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

void fragment() {
    // Frame processing
    vec4 frame_color = texture(frame_texture, UV);
    bool draw_frame = custom_frame && frame_color.a > alpha_threshold;

    if (draw_frame && frame_color.a < 1.0) {
        frame_color.a = max(frame_color.a, frame_edge_opacity);
    }

    // If 'custom_frame' is enabled, the progress bar will only render
    // inside the visible (transparent) area of the given 'frame_texture'.

    // HOW IT WORKS:
    // - The shader takes the 'frame_texture' and reads the alpha channel
    //   in order to determine which vertical regions are transparent.
    // - For each horizontal UV column, it scans from top to bottom and bottom
    //   to top to find the first transparent pixels. The frame is then found.
    // - The progress bar is then only rendered between these two bounds per column.
    // - The user can later scale properly the texture to fit exactly in as needed.

    // PARAMETERS:
    // - frame_texture: the texture with transparent interior and opaque border
    // - alpha_threshold: pixels with alpha below this value are considered transparent
    // - frame_trim: trims the top and bottom bounds inward slightly to prevent
    //   visual bleed into the frame’s border (especially for anti-aliased edges)
    // This lets you create progress bars in any shape defined by a custom frame.
    // NOTE:
    // - Best results with solid opaque borders and fully transparent interiors

    vec4 bar_color = vec4(0.0);
    bool render_bar = true;
    float mask_alpha = 1.0;

    // Frame-based clipping
    if (custom_frame) {
        vec2 trim_uv = mix(vec2(frame_trim), vec2(1.0 - frame_trim), UV);
        float step_size = 1.0 / float(scan_steps);
        float top_limit = 0.0;
        float bottom_limit = 1.0;

        // Find frame boundaries
        for (int i = 0; i < scan_steps; i++) {
            float y = float(i) * step_size;
            if (texture(frame_texture, vec2(trim_uv.x, y)).a > alpha_threshold) {
                top_limit = y;
                break;
            }
        }

        for (int i = 0; i < scan_steps; i++) {
            float y = 1.0 - float(i) * step_size;
            if (texture(frame_texture, vec2(trim_uv.x, y)).a > alpha_threshold) {
                bottom_limit = y;
                break;
            }
        }

        top_limit = clamp(top_limit - mask_expansion, 0.0, 1.0);
        bottom_limit = clamp(bottom_limit + mask_expansion, 0.0, 1.0);

        if (trim_uv.y < top_limit || trim_uv.y > bottom_limit) {
            render_bar = false;
        } else {
            float top_fade = smoothstep(top_limit, top_limit + edge_smoothness, trim_uv.y);
            float bottom_fade = smoothstep(bottom_limit, bottom_limit - edge_smoothness, trim_uv.y);
            mask_alpha = min(top_fade, bottom_fade);
            if (mask_alpha < 0.1) render_bar = false;
        }
    }

    // Progress bar rendering
    if (render_bar) {
        vec2 uv = mix(vec2(scale), vec2(1.0 - scale), UV);
        vec2 slanted_uv = uv;
        slanted_uv.x += slant_amount * (0.5 - uv.y) * 2.0;

        if (slanted_uv.x < -slant_clip_margin || slanted_uv.x > 1.0 + slant_clip_margin) {
            render_bar = false;
        } else {
            float segment_width = 1.0 / float(segment_count);
            float current_segment = floor(slanted_uv.x / segment_width);
            float segment_pos = fract(slanted_uv.x / segment_width);
            float half_gap = segment_gap * 0.5;

            if (segment_pos < half_gap || segment_pos > (1.0 - half_gap)) {
                render_bar = false;
            } else {
                // Fill calculation
                vec4 base_color;
                float fill_ratio = 0.0;
                float segment_fill = 0.0;
                bool is_filled = false;

                if (fill_mode == 0) { // Discrete
                    is_filled = current_segment < float(discrete_fill_amount);
                    fill_ratio = float(discrete_fill_amount) / float(segment_count);
                } else if (fill_mode == 1) { // Fade
                    fill_ratio = fade_fill_amount;
                    if (segment_count == 1) {
                        segment_fill = pour_fill_amount;
                        is_filled = segment_fill > 0.0;
                    } else {
                        float progress = fade_fill_amount * float(segment_count);
                        segment_fill = clamp(progress - current_segment, 0.0, 1.0);
                        is_filled = segment_fill > 0.0;
                    }
                } else { // Pour
                    fill_ratio = pour_fill_amount;
                    float progress = pour_fill_amount * float(segment_count);
                    segment_fill = clamp(progress - current_segment, 0.0, 1.0);

                    if (bar_mode == 3) { // Rainbow Wave
                        float wave_influence = sin((slanted_uv.x - TIME * animation_speed) * 10.0) * 0.05;
                        segment_fill = clamp(segment_fill + wave_influence, 0.0, 1.0);
                    }
                    is_filled = segment_fill > 0.0;
                }

                // Color calculation
                if (is_filled) {
                    if (bar_mode == 2) { // Health Bar
                        vec3 color = mix(
                            mix(vec3(1.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0), clamp(fill_ratio * 2.0, 0.0, 1.0)),
                            vec3(0.0, 1.0, 0.0),
                            clamp((fill_ratio - 0.5) * 2.0, 0.0, 1.0));
                        base_color = vec4(color, 1.0);
                    } else if (bar_mode == 1 || bar_mode == 3) { // RGB or Rainbow Wave
                        float hue;
                        if (segment_count == 1) {
                            // For single segment, we create a rainbow across the segment width
                            hue = slanted_uv.x;
                            if (bar_mode == 3) {
                                // Time-based animation for wave effect
                                hue = fract(hue + TIME * animation_speed * 0.1);
                            }
                        } else {
                            // For multiple segments, each segment gets its own color
                            hue = current_segment / float(segment_count);
                            if (bar_mode == 3) {
                                hue = fract(hue + TIME * animation_speed * 0.1);
                            }
                        }
                        base_color = vec4(hsv2rgb(vec3(hue, 1.0, 1.0)), 1.0);
                    } else if (bar_mode == 4) { // Fluid
                        base_color = generate_fluid_color(slanted_uv, current_segment, fill_ratio);
                    } else { // Solid
                        base_color = filled_color;
                    }


                    // Apply gradients
                    if (horizontal_gradient) {
                        float gradient_factor;
                        if (segment_count == 1) {
                            // For single segment, use the position within the segment (0.0 to 1.0)
                            gradient_factor = segment_pos;
                        } else {
                            // For multiple segments, use the segment index
                            gradient_factor = float(current_segment) / float(segment_count - 1);
                        }
                        float brightness = mix(1.0 - H_gradient_strength, 1.0, gradient_factor);
                        base_color.rgb *= brightness;
                    }

                    if (vertical_gradient) {
                        float y_dist = abs(uv.y - 0.5) * 2.0;
                        float brightness = mix(1.0, 1.0 - V_gradient_strength, y_dist);
                        base_color.rgb *= brightness;
                    }

                    // Apply effects
                    base_color = apply_effect(base_color, slanted_uv, current_segment, fill_ratio);

                    // Fill mode blending
                    if (fill_mode == 1) { // Fade
                        if (segment_count == 1) {
                            float segment_local_pos = segment_pos;

                            if (single_segment_fade_progress < 1.0) {
                                if (single_segment_fade_from > single_segment_fade_to) {
                                    // Fade-out
                                    if (segment_local_pos > single_segment_fade_to && segment_local_pos <= single_segment_fade_from) {
                                        float fade_alpha = 1.0 - single_segment_fade_progress;
                                        base_color = mix(background_color, base_color, fade_alpha);
                                    } else if (segment_local_pos > single_segment_fade_from) {
                                        base_color = background_color;
                                    }
                                } else {
                                    // Fade-in
                                    if (segment_local_pos <= single_segment_fade_to && segment_local_pos > single_segment_fade_from) {
                                        float fade_alpha = single_segment_fade_progress;
                                        base_color = mix(background_color, base_color, fade_alpha);
                                    } else if (segment_local_pos > single_segment_fade_to) {
                                        base_color = background_color;
                                    }
                                }
                            } else {
                                if (segment_local_pos > fade_fill_amount) {
                                    base_color = background_color;
                                }
                            }
                        } else {
                            base_color = mix(background_color, base_color, segment_fill);
                        }
                    } else if (fill_mode == 2) { // Pour
                        float segment_local_pos = segment_pos;
                        float fill_cutoff = segment_fill;

                        if (bar_mode == 3) { // Rainbow Wave smooth blending
                            float edge_width = 0.05;
                            float fill_amount = smoothstep(fill_cutoff - edge_width, fill_cutoff + edge_width, segment_local_pos);
                            base_color = mix(base_color, background_color, fill_amount);
                        } else {
                            if (segment_local_pos > fill_cutoff) {
                                base_color = background_color;
                            }
                        }
                    }
                } else {
                    base_color = background_color;
                }

                // Flash effects
                if (flash_type == 1 && int(current_segment) == flash_segment) {
                    base_color.rgb = mix(base_color.rgb, flash_color.rgb, flash_intensity);
                } else if (flash_type == 2 && segment_count == 1 && fill_mode == 2) {
                    float left = single_segment_current_fill;
                    float right = single_segment_previous_fill;
                    if (slanted_uv.x >= left && slanted_uv.x <= right && right > left) {
                        base_color.rgb = mix(base_color.rgb, flash_color.rgb, single_segment_flash_intensity);
                    }
                } else if ((flash_type == 3 || flash_type == 4) && fill_mode == 2) {
                    float left = drain_current_fill;
                    float right = mix(drain_previous_fill, drain_current_fill, drain_time_progress);
                    if (slanted_uv.x >= left && slanted_uv.x <= right) {
                        float flash_strength = (flash_type == 4) ? 1.0 : smoothstep(1.0, 0.0, (slanted_uv.x - left) / max(right - left, 0.001));
                        base_color.rgb = mix(base_color.rgb, drain_flash_color.rgb, flash_strength);
                    }
                } else if (flash_type == 5) {
                    int current_seg = int(current_segment);
                    if (current_seg >= flash_from_segment && current_seg <= flash_to_segment) {
                        base_color.rgb = mix(base_color.rgb, flash_color.rgb, flash_intensity);
                    }
                }

                // Border rendering
                float horizontal_border_thickness = universal_border_size * horizontal_border_size;
                float inner_border_thickness = universal_border_size * inner_border_thickness_multiplier;

                bool is_horizontal_border = universal_border_size > 0.0 && (
                    uv.y < (scale + horizontal_border_thickness) ||
                    uv.y > (1.0 - scale - horizontal_border_thickness)
                );

                bool is_inner_vertical_border = false;
                bool is_at_left_gap = segment_pos < (half_gap + inner_border_thickness);
                bool is_at_right_gap = segment_pos > (1.0 - half_gap - inner_border_thickness);
                bool is_between_segments = (current_segment > 0.0 && is_at_left_gap) ||
                                          (current_segment < float(segment_count - 1) && is_at_right_gap);
                if (is_between_segments) is_inner_vertical_border = true;

                bool is_outer_border = false;
                if (universal_border_size > 0.0) {
                    const float EPSILON = 0.001;
                    if (abs(current_segment) < EPSILON && segment_pos < (half_gap + universal_border_size * outer_border_size)) {
                        is_outer_border = true;
                    }
                    if (abs(current_segment - float(segment_count - 1)) < EPSILON &&
                        segment_pos > (1.0 - half_gap - universal_border_size * outer_border_size)) {
                        is_outer_border = true;
                    }
                }

                bool is_border = is_horizontal_border || is_inner_vertical_border || is_outer_border;
                bar_color = is_border ? border_color : base_color;
                bar_color.a *= mask_alpha;
            }
        }
    }

    // Final output
    if (draw_frame) {
        COLOR = render_bar ? mix(bar_color, frame_color, frame_color.a) : frame_color;
    } else if (render_bar) {
        COLOR = bar_color;
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
