class_name RoomsUI
extends RefCounted

## UI styling helpers for the Rooms HUD, pause menu, and Architect death overlay.


static func make_panel_style(bg: Color, border: Color, radius: int = 12, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make_button_theme_styles(accent: Color) -> Dictionary:
	var normal := make_panel_style(Color(0.06, 0.08, 0.12, 0.90), Color(accent.r, accent.g, accent.b, 0.45), 8, 1)
	var hover := make_panel_style(Color(0.11, 0.16, 0.25, 0.96), Color(accent.r, accent.g, accent.b, 0.95), 8, 2)
	var pressed := make_panel_style(Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.4, 0.98), Color(1.0, 1.0, 1.0, 0.95), 8, 2)
	return {"normal": normal, "hover": hover, "pressed": pressed}


static func style_button(btn: Button, accent: Color, font_size: int = 15) -> void:
	var styles := make_button_theme_styles(accent)
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("focus", styles["hover"])
	btn.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Flat text-only menu link (minimal aesthetic: no frame, subtle hover).
static func style_link_button(btn: Button, font_size: int = 30, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var empty := StyleBoxEmpty.new()
	for sb in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(sb, empty)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = align
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", load("res://assets/fonts/Montserrat-Medium.ttf"))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.90, 0.91, 0.94, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))


## Fine animated film-grain / white-noise overlay material.
static func make_noise_material(amount: float = 1.0, coarse: float = 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float amt : hint_range(0.0, 1.0) = 1.0;
uniform float coarse : hint_range(0.0, 3.0) = 1.0;

float hash12(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = vec2(520.0, 300.0) * coarse;
	float n = hash12(floor(uv * px) + fract(TIME * 61.0) * 97.0);
	float n2 = hash12(floor(uv * px * 0.34) + fract(TIME * 19.0) * 41.0);
	float grain = mix(n, n2, 0.40);
	float scan = step(0.975, fract(uv.y * 210.0 + TIME * 9.0)) * 0.20;
	float a = (grain * 0.20 + scan) * amt;
	COLOR = vec4(vec3(grain), a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("amt", amount)
	mat.set_shader_parameter("coarse", coarse)
	return mat


## Square, flat "cmd.exe" window frame for the death screen.
static func make_cmd_window_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.058, 0.066, 0.97)
	sb.border_color = Color(0.46, 0.48, 0.53, 0.80)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	return sb


class RingButton extends Button:
	var ring_color := Color(1.0, 1.0, 1.0, 0.95)
	var stroke_width := 5.5
	var held_down := false

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)
		add_theme_stylebox_override("disabled", empty)
		button_down.connect(func() -> void:
			held_down = true
			queue_redraw()
		)
		button_up.connect(func() -> void:
			held_down = false
			queue_redraw()
		)
		mouse_exited.connect(func() -> void:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				held_down = false
				queue_redraw()
		)

	func _draw() -> void:
		var c := size * 0.5
		var r := maxf(minf(size.x, size.y) * 0.5 - stroke_width * 0.65 - 2.0, 6.0)
		draw_arc(c, r, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.42), stroke_width + 3.0, true)
		if held_down:
			draw_circle(c, r - stroke_width * 0.45, Color(ring_color.r, ring_color.g, ring_color.b, 0.22))
		var draw_col := ring_color if not held_down else ring_color.lightened(0.20)
		draw_arc(c, r, 0.0, TAU, 64, draw_col, stroke_width, true)


class ReticleRing extends Control:
	var ring_radius := 6.5
	var ring_color := Color(1.0, 1.0, 1.0, 0.92)
	var stroke_width := 2.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(72, 72)

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, ring_radius, 0.0, TAU, 52, Color(0.0, 0.0, 0.0, 0.52), stroke_width + 2.0, true)
		draw_arc(c, ring_radius, 0.0, TAU, 52, ring_color, stroke_width, true)
