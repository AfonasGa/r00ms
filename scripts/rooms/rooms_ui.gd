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
