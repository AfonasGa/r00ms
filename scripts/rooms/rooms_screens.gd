extends "res://scripts/rooms/rooms_setup.gd"

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# Dark subtle vignette + locker slit mask
	var locker_mask := ColorRect.new()
	locker_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	locker_mask.color = Color(0.0, 0.0, 0.0, 0.0)
	locker_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(locker_mask)
	_ui["locker_mask"] = locker_mask

	# Damage / Blood flash
	var dmg_flash := ColorRect.new()
	dmg_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_flash.color = Color(0.85, 0.05, 0.05, 0.0)
	dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dmg_flash)
	_ui["dmg_flash"] = dmg_flash

	# Death center-shrink iris shader (Red flash -> compresses & fades inward to black before Architect)
	var iris_sh := Shader.new()
	iris_sh.code = """shader_type canvas_item;
uniform float shrink_amt : hint_range(0.0, 1.0) = 0.0;
uniform float red_amt : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float rx = max(mix(1.25, 0.001, pow(shrink_amt, 0.72)), 0.001);
	float ry = max(mix(1.25, 0.001, pow(shrink_amt, 0.92)), 0.001);
	float ell = length(vec2(d.x / rx, d.y / ry));
	float black_mask = smoothstep(0.72, 1.05, ell) * smoothstep(0.02, 0.25, shrink_amt);
	if (shrink_amt >= 0.985) {
		black_mask = 1.0;
	}
	vec3 col = mix(vec3(0.0), vec3(0.82, 0.03, 0.03), red_amt * (1.0 - black_mask * 0.65));
	float alpha = max(black_mask, red_amt);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
"""
	var iris_mat := ShaderMaterial.new()
	iris_mat.shader = iris_sh
	var death_iris := ColorRect.new()
	death_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_iris.material = iris_mat
	death_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_iris.visible = false
	root.add_child(death_iris)
	_ui["death_iris"] = death_iris
	_ui["death_iris_mat"] = iris_mat

	# Static Noise & Dark Vignette (A-60 arrival < A-100 & proximity effect)
	var static_sh := Shader.new()
	static_sh.code = """shader_type canvas_item;
uniform float static_amt : hint_range(0.0, 1.0) = 0.0;
uniform float vig_amt : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint_col = vec3(1.0, 0.22, 0.18);

float hash12(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float r = length((uv - 0.5) * vec2(1.4, 1.0));
	float vig = smoothstep(0.28, 0.92, r) * vig_amt;
	float n = hash12(floor(uv * vec2(420.0, 240.0)) + fract(TIME * 37.0) * 19.0);
	float scan = step(0.82, fract(uv.y * 90.0 + TIME * 12.0)) * 0.25;
	float grain = n * static_amt * 0.45;
	vec3 col = mix(vec3(0.02, 0.0, 0.0), tint_col, 0.35 * (grain + scan * static_amt));
	float a = clamp(vig * 0.82 + grain + scan * static_amt * 0.22, 0.0, 0.92);
	COLOR = vec4(col, a);
}
"""
	var static_mat := ShaderMaterial.new()
	static_mat.shader = static_sh
	var static_rect := ColorRect.new()
	static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_rect.material = static_mat
	static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_rect.visible = false
	root.add_child(static_rect)
	_ui["static_rect"] = static_rect
	_ui["static_mat"] = static_mat

	# A-60 Raycast Screen Jumpscare Face
	var a60_scare_rect := TextureRect.new()
	a60_scare_rect.set_anchors_preset(Control.PRESET_CENTER)
	a60_scare_rect.offset_left = -270
	a60_scare_rect.offset_top = -270
	a60_scare_rect.offset_right = 270
	a60_scare_rect.offset_bottom = 270
	a60_scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a60_scare_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a60_scare_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a60_scare_rect.visible = false
	a60_scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(a60_scare_rect)
	_ui["a60_scare_rect"] = a60_scare_rect

	# A-120 warp overlay: white noise + white vignette, fades over ~10s
	var warp_sh := Shader.new()
	warp_sh.code = """shader_type canvas_item;
uniform float amt : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	float n = hash12(floor(uv * vec2(540.0, 300.0)) + fract(TIME * 61.0) * 97.0);
	float n2 = hash12(floor(uv * vec2(170.0, 96.0)) + fract(TIME * 23.0) * 41.0);
	float grain = mix(n, n2, 0.35);
	float scan = step(0.88, fract(uv.y * 96.0 + TIME * 22.0)) * 0.35;

	float r = length((uv - 0.5) * vec2(1.42, 1.0));
	float vig = smoothstep(0.26, 0.99, r);

	vec3 col = mix(vec3(mix(0.58, 1.0, grain)), vec3(1.0), clamp(vig * 0.95 + scan, 0.0, 1.0));
	float a = clamp((0.34 + 0.36 * vig + 0.26 * grain + scan), 0.0, 1.0) * amt;
	COLOR = vec4(col, a);
}
"""
	var warp_mat := ShaderMaterial.new()
	warp_mat.shader = warp_sh
	warp_mat.set_shader_parameter("amt", 0.0)
	var warp_rect := ColorRect.new()
	warp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	warp_rect.material = warp_mat
	warp_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warp_rect.visible = false
	root.add_child(warp_rect)
	_ui["warp_rect"] = warp_rect
	_ui["warp_mat"] = warp_mat

	# HUD group (hidden during Curious-Light / Architect void on death)
	var hud_group := Control.new()
	hud_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_group)
	_ui["hud_group"] = hud_group

	# Diegetic Static Vitals Vignette (NO heartbeat oscillation: static steady crimson HP/Darkness + vivid blue sprint/exhaustion)
	var vitals_sh := Shader.new()
	vitals_sh.code = """shader_type canvas_item;
uniform float hp_loss : hint_range(0.0, 1.0) = 0.0;
uniform float stam_loss : hint_range(0.0, 1.0) = 0.0;
uniform float exhausted_amt : hint_range(0.0, 1.0) = 0.0;
uniform float darkness_amt : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.45, 1.05);
	float dist = length(p);

	float red_drive = max(clamp((hp_loss - 0.12) / 0.88, 0.0, 1.0), darkness_amt);
	float red_edge = smoothstep(0.68 - red_drive * 0.36, 0.96, dist);
	float red_a = red_edge * red_drive * 0.84;

	float st_trigger = max(clamp((stam_loss - 0.04) / 0.96, 0.0, 1.0), exhausted_amt);
	float st_edge = smoothstep(0.74 - st_trigger * 0.34 - exhausted_amt * 0.06, 0.97, dist);
	float st_a = st_edge * st_trigger * (0.68 + 0.24 * exhausted_amt);

	float total_a = clamp(red_a + st_a * 0.85, 0.0, 0.90);
	vec3 blood_col = vec3(0.88, 0.04, 0.04);
	vec3 sprint_col = mix(vec3(0.08, 0.42, 0.98), vec3(0.22, 0.65, 1.0), 0.35 + 0.65 * exhausted_amt);
	float w_red = red_a / (red_a + st_a + 0.0001);
	vec3 col = mix(sprint_col, blood_col, clamp(w_red * 1.35, 0.0, 1.0));
	COLOR = vec4(col, total_a);
}
"""
	var vitals_mat := ShaderMaterial.new()
	vitals_mat.shader = vitals_sh
	vitals_mat.set_shader_parameter("hp_loss", 0.0)
	vitals_mat.set_shader_parameter("stam_loss", 0.0)
	vitals_mat.set_shader_parameter("exhausted_amt", 0.0)
	vitals_mat.set_shader_parameter("darkness_amt", 0.0)
	var vitals_rect := ColorRect.new()
	vitals_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vitals_rect.material = vitals_mat
	vitals_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(vitals_rect)
	_ui["vitals_rect"] = vitals_rect
	_ui["vitals_mat"] = vitals_mat

	# The Darkness Eye Overlay (additive blend removes pure black margins while glowing deep red)
	var darkness_rect := TextureRect.new()
	darkness_rect.set_anchors_preset(Control.PRESET_CENTER)
	darkness_rect.offset_left = -220
	darkness_rect.offset_top = -125
	darkness_rect.offset_right = 220
	darkness_rect.offset_bottom = 125
	darkness_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	darkness_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	darkness_rect.texture = _darkness_tex
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	darkness_rect.material = add_mat
	darkness_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	darkness_rect.visible = false
	darkness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(darkness_rect)
	_ui["darkness_rect"] = darkness_rect

	# Smart Hollow Ring Reticle (small normally, expands & glides to interactable center)
	_reticle_ring = RoomsUI.ReticleRing.new()
	_reticle_ring.ring_radius = 6.5
	_reticle_ring.stroke_width = 1.9
	var init_vp := get_viewport().get_visible_rect().size
	_reticle_screen_pos = init_vp * 0.5
	_reticle_ring.position = _reticle_screen_pos - _reticle_ring.size * 0.5
	hud_group.add_child(_reticle_ring)
	_ui["reticle_ring"] = _reticle_ring

	# Bare interaction prompt (no frame/panel, Montserrat)
	var prompt_wrap := CenterContainer.new()
	prompt_wrap.set_anchors_preset(Control.PRESET_CENTER)
	prompt_wrap.offset_left = -360
	prompt_wrap.offset_right = 360
	prompt_wrap.offset_top = 58
	prompt_wrap.offset_bottom = 104
	prompt_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(prompt_wrap)

	var prompt_lbl := Label.new()
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	prompt_lbl.add_theme_font_size_override("font_size", 18)
	prompt_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 0.96))
	prompt_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
	prompt_lbl.add_theme_constant_override("outline_size", 5)
	prompt_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.70))
	prompt_lbl.add_theme_constant_override("shadow_offset_y", 2)
	prompt_wrap.add_child(prompt_lbl)
	_ui["prompt_lbl"] = prompt_lbl

	# Clean floating hint (same minimalist typography as Reminder — no green box)
	var toast_lbl := Label.new()
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_lbl.offset_left = -430
	toast_lbl.offset_right = 430
	toast_lbl.offset_top = -158
	toast_lbl.offset_bottom = -106
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_font_size_override("font_size", 17)
	toast_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 0.95))
	toast_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	toast_lbl.add_theme_constant_override("outline_size", 4)
	toast_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	toast_lbl.add_theme_constant_override("shadow_offset_y", 2)
	toast_lbl.modulate.a = 0.0
	toast_lbl.visible = false
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(toast_lbl)
	_ui["toast"] = toast_lbl
	_ui["toast_lbl"] = toast_lbl

	_build_mobile_ui(hud_group)

	# --- A-90 "Stop Sign" (screen-space entity) ---
	var a90_root := Control.new()
	a90_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_root.visible = false
	root.add_child(a90_root)
	_ui["a90_root"] = a90_root

	var a90_sh := Shader.new()
	a90_sh.code = """shader_type canvas_item;
uniform float red_amt : hint_range(0.0, 1.0) = 0.0;
uniform float static_amt : hint_range(0.0, 1.0) = 0.0;

float hash12(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float r = length((uv - 0.5) * vec2(1.55, 1.0));
	float vig = smoothstep(0.20, 0.95, r) * red_amt;
	float n = hash12(floor(uv * vec2(460.0, 260.0)) + fract(TIME * 41.0) * 23.0);
	float scan = step(0.88, fract(uv.y * 120.0 + TIME * 20.0));
	float grain = n * static_amt * 0.30;
	vec3 col = mix(vec3(0.16, 0.0, 0.0), vec3(1.0, 0.10, 0.06), vig * 0.55);
	float a = clamp(vig * 0.72 + grain + scan * static_amt * 0.10, 0.0, 0.86);
	COLOR = vec4(col, a);
}
"""
	var a90_mat := ShaderMaterial.new()
	a90_mat.shader = a90_sh
	var a90_bg := ColorRect.new()
	a90_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_bg.material = a90_mat
	a90_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_root.add_child(a90_bg)
	_ui["a90_mat"] = a90_mat

	var a90_sign_box := Control.new()
	a90_sign_box.set_anchors_preset(Control.PRESET_CENTER)
	a90_sign_box.offset_left = -175
	a90_sign_box.offset_top = -258
	a90_sign_box.offset_right = 175
	a90_sign_box.offset_bottom = 92
	a90_sign_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_root.add_child(a90_sign_box)
	_ui["a90_sign_box"] = a90_sign_box

	var a90_shake := Control.new()
	a90_shake.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_shake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_sign_box.add_child(a90_shake)
	_ui["a90_shake"] = a90_shake

	var a90_rect := TextureRect.new()
	a90_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	a90_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("warn"):
		a90_rect.texture = _a90_textures["warn"]
	a90_shake.add_child(a90_rect)
	_ui["a90_rect"] = a90_rect

	var a90_icon_center := CenterContainer.new()
	a90_icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_shake.add_child(a90_icon_center)

	var a90_stop_icon := TextureRect.new()
	a90_stop_icon.custom_minimum_size = Vector2(215, 215)
	a90_stop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_stop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_stop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("stopsign"):
		a90_stop_icon.texture = _a90_textures["stopsign"]
	a90_icon_center.add_child(a90_stop_icon)
	_ui["a90_stop_icon"] = a90_stop_icon

	var a90_stop := Label.new()
	a90_stop.set_anchors_preset(Control.PRESET_CENTER)
	a90_stop.offset_left = -300
	a90_stop.offset_right = 300
	a90_stop.offset_top = 100
	a90_stop.offset_bottom = 158
	a90_stop.text = "НЕ ДВИГАЙТЕСЬ!"
	a90_stop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a90_stop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a90_stop.add_theme_font_size_override("font_size", 42)
	a90_stop.add_theme_color_override("font_color", Color(1.0, 0.16, 0.14))
	a90_stop.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	a90_stop.add_theme_constant_override("outline_size", 10)
	a90_stop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_stop.visible = false
	a90_root.add_child(a90_stop)
	_ui["a90_stop"] = a90_stop

	var a90_bar_holder := Control.new()
	a90_bar_holder.set_anchors_preset(Control.PRESET_CENTER)
	a90_bar_holder.offset_left = -180
	a90_bar_holder.offset_right = 180
	a90_bar_holder.offset_top = 168
	a90_bar_holder.offset_bottom = 175
	a90_bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_bar_holder.visible = false
	a90_root.add_child(a90_bar_holder)
	_ui["a90_bar_holder"] = a90_bar_holder

	var a90_bar_bg := ColorRect.new()
	a90_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_bar_bg.color = Color(0.10, 0.02, 0.02, 0.72)
	a90_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_bar_holder.add_child(a90_bar_bg)

	var a90_bar_fill := ColorRect.new()
	a90_bar_fill.position = Vector2.ZERO
	a90_bar_fill.size = Vector2(360, 7)
	a90_bar_fill.color = Color(1.0, 0.20, 0.16, 0.95)
	a90_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_bar_holder.add_child(a90_bar_fill)
	_ui["a90_bar_fill"] = a90_bar_fill

	var a90_hint := Label.new()
	a90_hint.set_anchors_preset(Control.PRESET_CENTER)
	a90_hint.offset_left = -330
	a90_hint.offset_right = 330
	a90_hint.offset_top = 185
	a90_hint.offset_bottom = 213
	a90_hint.text = "ОТПУСТИ КЛАВИШИ  ·  НЕ ДВИГАЙ МЫШЬЮ  ·  ЖДИ"
	a90_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a90_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a90_hint.add_theme_font_size_override("font_size", 15)
	a90_hint.add_theme_color_override("font_color", Color(0.95, 0.80, 0.72, 0.90))
	a90_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	a90_hint.add_theme_constant_override("outline_size", 4)
	a90_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_hint.visible = false
	a90_root.add_child(a90_hint)
	_ui["a90_hint"] = a90_hint

	# A-90 hit flash (jumpscare face)
	var a90_scare_rect := TextureRect.new()
	a90_scare_rect.set_anchors_preset(Control.PRESET_CENTER)
	a90_scare_rect.offset_left = -290
	a90_scare_rect.offset_top = -290
	a90_scare_rect.offset_right = 290
	a90_scare_rect.offset_bottom = 290
	a90_scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_scare_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_scare_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	a90_scare_rect.visible = false
	a90_scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("rage"):
		a90_scare_rect.texture = _a90_textures["rage"]
	root.add_child(a90_scare_rect)
	_ui["a90_scare_rect"] = a90_scare_rect

	# Pause / Victory Overlay
	var modal := CenterContainer.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	root.add_child(modal)
	_ui["modal"] = modal

	var m_card := PanelContainer.new()
	m_card.custom_minimum_size = Vector2(468, 0)
	m_card.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.04, 0.05, 0.08, 0.94), Color(0.45, 0.85, 1.0, 0.72), 16, 2))
	modal.add_child(m_card)

	var m_scroll := ScrollContainer.new()
	m_scroll.custom_minimum_size = Vector2(452, 545)
	m_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m_card.add_child(m_scroll)

	# Slim translucent scrollbar instead of the default chunky one
	var vsb := m_scroll.get_v_scroll_bar()
	vsb.custom_minimum_size.x = 6
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	sb_track.set_corner_radius_all(3)
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color(0.45, 0.85, 1.0, 0.40)
	sb_grab.set_corner_radius_all(3)
	var sb_grab_hi := StyleBoxFlat.new()
	sb_grab_hi.bg_color = Color(0.58, 0.92, 1.0, 0.72)
	sb_grab_hi.set_corner_radius_all(3)
	vsb.add_theme_stylebox_override("scroll", sb_track)
	vsb.add_theme_stylebox_override("grabber", sb_grab)
	vsb.add_theme_stylebox_override("grabber_highlight", sb_grab_hi)
	vsb.add_theme_stylebox_override("grabber_pressed", sb_grab_hi)

	var m_box := VBoxContainer.new()
	m_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_box.add_theme_constant_override("separation", 8)
	m_scroll.add_child(m_box)

	var m_title := Label.new()
	m_title.text = "ПАУЗА"
	m_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_title.add_theme_font_size_override("font_size", 28)
	m_box.add_child(m_title)
	_ui["m_title"] = m_title

	var m_desc := Label.new()
	m_desc.text = ""
	m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_desc.add_theme_font_size_override("font_size", 14)
	m_box.add_child(m_desc)
	_ui["m_desc"] = m_desc

	var m_main_box := VBoxContainer.new()
	m_main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_main_box.add_theme_constant_override("separation", 9)
	m_box.add_child(m_main_box)
	_ui["m_main_box"] = m_main_box

	var btn_resume := Button.new()
	btn_resume.text = "Продолжить"
	btn_resume.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_button(btn_resume, Color(0.35, 0.95, 0.68), 15)
	btn_resume.pressed.connect(func(): call("_set_state", State.PLAYING))
	m_main_box.add_child(btn_resume)
	_ui["btn_resume"] = btn_resume

	var btn_settings := Button.new()
	btn_settings.text = "Настройки (Звук и Игра)"
	btn_settings.custom_minimum_size = Vector2(0, 40)
	RoomsUI.style_button(btn_settings, Color(0.55, 0.88, 1.0), 15)
	btn_settings.pressed.connect(func(): _open_settings_panel(true))
	m_main_box.add_child(btn_settings)
	_ui["btn_settings"] = btn_settings

	var btn_restart := Button.new()
	btn_restart.text = "Начать заново (A-000)"
	btn_restart.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_button(btn_restart, Color(1.0, 0.75, 0.28), 15)
	btn_restart.pressed.connect(Callable(self, "_reset_run"))
	m_main_box.add_child(btn_restart)

	var btn_mobile := Button.new()
	btn_mobile.text = "Сенсорное управление: АВТО"
	btn_mobile.custom_minimum_size = Vector2(0, 38)
	RoomsUI.style_button(btn_mobile, Color(0.55, 0.78, 1.0), 14)
	btn_mobile.pressed.connect(_cycle_mobile_mode)
	m_main_box.add_child(btn_mobile)
	_ui["btn_mobile"] = btn_mobile

	var ren_row := HBoxContainer.new()
	ren_row.add_theme_constant_override("separation", 6)
	m_main_box.add_child(ren_row)

	var btn_quality := Button.new()
	btn_quality.text = "Рендер / Графика: %s" % _quality_label(_render_quality)
	btn_quality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quality.custom_minimum_size = Vector2(0, 36)
	RoomsUI.style_button(btn_quality, Color(0.45, 0.94, 0.78), 13)
	btn_quality.pressed.connect(_cycle_render_quality)
	ren_row.add_child(btn_quality)
	_ui["btn_quality"] = btn_quality

	var btn_backend := Button.new()
	btn_backend.text = "Бэкенд: %s" % _backend_label(_render_backend)
	btn_backend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_backend.custom_minimum_size = Vector2(0, 36)
	RoomsUI.style_button(btn_backend, Color(0.96, 0.80, 0.36), 12)
	btn_backend.pressed.connect(_cycle_render_backend)
	ren_row.add_child(btn_backend)
	_ui["btn_backend"] = btn_backend

	var btn_restart_render := Button.new()
	btn_restart_render.text = "Перезапустить с новым рендером"
	btn_restart_render.custom_minimum_size = Vector2(0, 34)
	btn_restart_render.visible = (_render_backend != _active_render_backend)
	RoomsUI.style_button(btn_restart_render, Color(1.0, 0.56, 0.25), 13)
	btn_restart_render.pressed.connect(_restart_for_render)
	m_main_box.add_child(btn_restart_render)
	_ui["btn_restart_render"] = btn_restart_render

	# Online Test Panel (Steam Spacewar 480 + ENet LAN)
	var net_sep := Label.new()
	net_sep.text = "── ОНЛАЙН ТЕСТ (STEAM SPACEWAR 480) ──"
	net_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_sep.add_theme_font_size_override("font_size", 13)
	net_sep.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0))
	m_main_box.add_child(net_sep)

	var net_status := Label.new()
	net_status.text = _net.get_summary_status() if _net != null else "Offline"
	net_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status.add_theme_font_size_override("font_size", 13)
	net_status.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	m_main_box.add_child(net_status)
	_ui["net_status"] = net_status

	var steam_row := HBoxContainer.new()
	steam_row.add_theme_constant_override("separation", 6)
	m_main_box.add_child(steam_row)

	var btn_steam_host := Button.new()
	btn_steam_host.text = "Steam Лобби (480)"
	btn_steam_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_steam_host, Color(0.40, 0.80, 1.0), 13)
	btn_steam_host.pressed.connect(func() -> void:
		if _net != null:
			_net.host_steam_lobby(int(_rng.seed), _highest_opened)
	)
	steam_row.add_child(btn_steam_host)

	var btn_steam_find := Button.new()
	btn_steam_find.text = "Найти Steam лобби"
	btn_steam_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_steam_find, Color(0.45, 0.92, 0.72), 13)
	btn_steam_find.pressed.connect(func() -> void:
		if _net != null:
			_net.search_steam_lobbies()
	)
	steam_row.add_child(btn_steam_find)

	var enet_row := HBoxContainer.new()
	enet_row.add_theme_constant_override("separation", 6)
	m_main_box.add_child(enet_row)

	var btn_lan_host := Button.new()
	btn_lan_host.text = "Тест Хост (27480)"
	btn_lan_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_lan_host, Color(0.75, 0.85, 1.0), 12)
	btn_lan_host.pressed.connect(func() -> void:
		if _net != null:
			_net.host_enet(int(_rng.seed))
	)
	enet_row.add_child(btn_lan_host)

	var btn_lan_join := Button.new()
	btn_lan_join.text = "Войти 127.0.0.1"
	btn_lan_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_lan_join, Color(0.75, 0.95, 0.80), 12)
	btn_lan_join.pressed.connect(func() -> void:
		if _net != null:
			_net.join_enet("127.0.0.1")
	)
	enet_row.add_child(btn_lan_join)

	var steam_act_row := HBoxContainer.new()
	steam_act_row.add_theme_constant_override("separation", 6)
	m_main_box.add_child(steam_act_row)

	var btn_net_invite := Button.new()
	btn_net_invite.text = "Пригласить (Shift+Tab)"
	btn_net_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_net_invite, Color(0.55, 0.86, 1.0), 12)
	btn_net_invite.pressed.connect(func() -> void:
		if _net != null:
			_net.open_steam_invite_overlay(int(_rng.seed), _highest_opened)
	)
	steam_act_row.add_child(btn_net_invite)
	_ui["btn_net_invite"] = btn_net_invite

	var btn_net_disc := Button.new()
	btn_net_disc.text = "Отключиться"
	btn_net_disc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_net_disc, Color(1.0, 0.55, 0.45), 12)
	btn_net_disc.pressed.connect(func() -> void:
		if _net != null:
			_net.disconnect_session()
	)
	steam_act_row.add_child(btn_net_disc)
	_ui["btn_net_disc"] = btn_net_disc

	_lobby_list_box = VBoxContainer.new()
	_lobby_list_box.add_theme_constant_override("separation", 4)
	m_main_box.add_child(_lobby_list_box)

	# Sub-panel: Audio & Gameplay Settings
	var m_settings_box := VBoxContainer.new()
	m_settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_settings_box.add_theme_constant_override("separation", 8)
	m_settings_box.visible = false
	m_box.add_child(m_settings_box)
	_ui["m_settings_box"] = m_settings_box

	var audio_hdr := Label.new()
	audio_hdr.text = "── ЗВУК ──"
	audio_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_hdr.add_theme_font_size_override("font_size", 13)
	audio_hdr.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	m_settings_box.add_child(audio_hdr)

	var make_slider := func(title_str: String, s_key: String, l_key: String, min_v: float, max_v: float, step_v: float, init_v: float, accent: Color, on_chg: Callable) -> void:
		var row := HBoxContainer.new()
		m_settings_box.add_child(row)
		var t_lbl := Label.new()
		t_lbl.text = title_str
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(t_lbl)
		var v_lbl := Label.new()
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", accent)
		row.add_child(v_lbl)
		var sld := HSlider.new()
		sld.min_value = min_v
		sld.max_value = max_v
		sld.step = step_v
		sld.value = init_v
		sld.custom_minimum_size = Vector2(0, 24)
		sld.value_changed.connect(on_chg)
		m_settings_box.add_child(sld)
		_ui[s_key] = sld
		_ui[l_key] = v_lbl

	make_slider.call("Общая громкость", "sld_master", "lbl_master", 0.0, 100.0, 1.0, _audio_master * 100.0, Color(0.55, 0.95, 1.0), func(val: float) -> void:
		_audio_master = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	make_slider.call("Монстры (A-60 / A-90 / A-120 / Darkness)", "sld_entities", "lbl_entities", 0.0, 100.0, 1.0, _audio_entities * 100.0, Color(1.0, 0.58, 0.45), func(val: float) -> void:
		_audio_entities = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	make_slider.call("Эффекты, фонарик и шаги", "sld_sfx", "lbl_sfx", 0.0, 100.0, 1.0, _audio_sfx * 100.0, Color(0.45, 0.94, 0.72), func(val: float) -> void:
		_audio_sfx = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	make_slider.call("Атмосфера и сердцебиение", "sld_ambient", "lbl_ambient", 0.0, 100.0, 1.0, _audio_ambient * 100.0, Color(0.75, 0.85, 1.0), func(val: float) -> void:
		_audio_ambient = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)

	var audio_btn_row := HBoxContainer.new()
	audio_btn_row.add_theme_constant_override("separation", 6)
	m_settings_box.add_child(audio_btn_row)

	var btn_mute_audio := Button.new()
	btn_mute_audio.text = "Звук: ВКЛ [M]"
	btn_mute_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mute_audio.custom_minimum_size = Vector2(0, 36)
	RoomsUI.style_button(btn_mute_audio, Color(1.0, 0.78, 0.35), 13)
	btn_mute_audio.pressed.connect(func() -> void:
		_audio_muted = not _audio_muted
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	audio_btn_row.add_child(btn_mute_audio)
	_ui["btn_mute_audio"] = btn_mute_audio

	var btn_reset_audio := Button.new()
	btn_reset_audio.text = "Сбросить звук"
	btn_reset_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset_audio.custom_minimum_size = Vector2(0, 36)
	RoomsUI.style_button(btn_reset_audio, Color(0.75, 0.82, 0.95), 13)
	btn_reset_audio.pressed.connect(_reset_audio_defaults)
	audio_btn_row.add_child(btn_reset_audio)
	_ui["btn_reset_audio"] = btn_reset_audio

	var cam_hdr := Label.new()
	cam_hdr.text = "── КАМЕРА И УПРАВЛЕНИЕ ──"
	cam_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cam_hdr.add_theme_font_size_override("font_size", 13)
	cam_hdr.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	m_settings_box.add_child(cam_hdr)

	make_slider.call("Чувствительность обзора", "sld_sens", "lbl_sens", 0.4, 2.2, 0.05, _mouse_sens_mult, Color(0.55, 0.92, 1.0), func(val: float) -> void:
		_mouse_sens_mult = clampf(val, 0.4, 2.2)
		_save_render_settings()
		_sync_settings_ui()
	)
	make_slider.call("Поле зрения (FOV)", "sld_fov", "lbl_fov", 65.0, 95.0, 1.0, _base_fov, Color(0.55, 0.92, 1.0), func(val: float) -> void:
		_base_fov = clampf(val, 65.0, 95.0)
		_save_render_settings()
		_sync_settings_ui()
	)

	var btn_head_bob := Button.new()
	btn_head_bob.text = "Покачивание камеры: ВКЛ"
	btn_head_bob.custom_minimum_size = Vector2(0, 36)
	RoomsUI.style_button(btn_head_bob, Color(0.45, 0.92, 0.78), 13)
	btn_head_bob.pressed.connect(func() -> void:
		_head_bob_enabled = not _head_bob_enabled
		_save_render_settings()
		_sync_settings_ui()
	)
	m_settings_box.add_child(btn_head_bob)
	_ui["btn_head_bob"] = btn_head_bob

	var btn_settings_back := Button.new()
	btn_settings_back.text = "← Назад в паузу"
	btn_settings_back.custom_minimum_size = Vector2(0, 40)
	RoomsUI.style_button(btn_settings_back, Color(0.35, 0.95, 0.68), 15)
	btn_settings_back.pressed.connect(func(): _open_settings_panel(false))
	m_settings_box.add_child(btn_settings_back)
	_ui["btn_settings_back"] = btn_settings_back

	# Architect Death Void (Terminal Matrix / test.py CRT green void + ASCII Art in bottom right)
	var arch_overlay := Control.new()
	arch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_overlay.visible = false
	root.add_child(arch_overlay)
	_ui["architect_overlay"] = arch_overlay

	var arch_bg := ColorRect.new()
	arch_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_bg.color = Color.WHITE
	arch_bg.material = RoomsArchitect.make_void_shader_material()
	arch_bg.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			call("_advance_architect_dialogue")
	)
	arch_overlay.add_child(arch_bg)
	_ui["arch_bg"] = arch_bg

	var arch_silhouette := TextureRect.new()
	arch_silhouette.visible = false
	arch_overlay.add_child(arch_silhouette)
	_ui["arch_silhouette"] = arch_silhouette

	# Top-left Matrix CRT terminal speech text (inspired by test.py print_top_left_replace)
	var arch_speech := Label.new()
	arch_speech.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_speech.anchor_left = 0.05
	arch_speech.anchor_right = 0.62
	arch_speech.anchor_top = 0.08
	arch_speech.anchor_bottom = 0.52
	var arch_mono_f := RoomsArchitect.get_terminal_font()
	arch_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	arch_speech.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	arch_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arch_speech.add_theme_font_override("font", arch_mono_f)
	arch_speech.add_theme_font_size_override("font_size", 22)
	arch_speech.add_theme_color_override("font_color", Color(0.28, 1.0, 0.42))
	arch_speech.add_theme_color_override("font_outline_color", Color(0.01, 0.16, 0.04, 0.95))
	arch_speech.add_theme_constant_override("outline_size", 4)
	arch_speech.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	arch_speech.add_theme_constant_override("shadow_offset_x", 0)
	arch_speech.add_theme_constant_override("shadow_offset_y", 2)
	arch_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_speech)
	_ui["arch_speech"] = arch_speech

	# Bottom-right ASCII Art Monster Portrait (inspired by test.py draw_art_bottom_right)
	var arch_ascii := RichTextLabel.new()
	arch_ascii.bbcode_enabled = true
	arch_ascii.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	arch_ascii.offset_left = -460
	arch_ascii.offset_top = -290
	arch_ascii.offset_right = -24
	arch_ascii.offset_bottom = -24
	arch_ascii.fit_content = false
	arch_ascii.scroll_active = false
	arch_ascii.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_ascii.add_theme_font_override("normal_font", arch_mono_f)
	arch_ascii.add_theme_font_override("mono_font", arch_mono_f)
	arch_ascii.add_theme_font_size_override("normal_font_size", 13)
	arch_ascii.add_theme_font_size_override("mono_font_size", 13)
	arch_overlay.add_child(arch_ascii)
	_ui["arch_ascii"] = arch_ascii

	# Quiet non-intrusive bottom bar & metadata
	var arch_title := Label.new()
	arch_title.visible = false
	arch_overlay.add_child(arch_title)
	_ui["arch_title"] = arch_title

	var arch_meta := Label.new()
	arch_meta.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	arch_meta.offset_left = 24
	arch_meta.offset_top = -78
	arch_meta.offset_right = 520
	arch_meta.offset_bottom = -52
	arch_meta.add_theme_font_override("font", arch_mono_f)
	arch_meta.add_theme_font_size_override("font_size", 12)
	arch_meta.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45, 0.75))
	arch_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_meta)
	_ui["arch_meta"] = arch_meta

	var arch_tip := Label.new()
	arch_tip.visible = false
	arch_overlay.add_child(arch_tip)
	_ui["arch_tip"] = arch_tip

	var arch_page := Label.new()
	arch_page.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	arch_page.offset_left = -220
	arch_page.offset_top = 16
	arch_page.offset_right = -20
	arch_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arch_page.add_theme_font_override("font", arch_mono_f)
	arch_page.add_theme_font_size_override("font_size", 12)
	arch_page.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45, 0.75))
	arch_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_page)
	_ui["arch_page"] = arch_page

	var btn_arch_next := Button.new()
	btn_arch_next.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn_arch_next.pressed.connect(Callable(self, "_advance_architect_dialogue"))
	arch_overlay.add_child(btn_arch_next)
	_ui["btn_arch_next"] = btn_arch_next

	var btn_arch_retry := Button.new()
	btn_arch_retry.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn_arch_retry.pressed.connect(Callable(self, "_reset_run"))
	arch_overlay.add_child(btn_arch_retry)
	_ui["btn_arch_retry"] = btn_arch_retry

	call("_style_arch_terminal_buttons")

	# Online Spectator Bar (shown after Architect when observing teammates)
	var spec_bar := Control.new()
	spec_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	spec_bar.offset_top = -90
	spec_bar.offset_bottom = -16
	spec_bar.visible = false
	spec_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(spec_bar)
	_ui["spectate_bar"] = spec_bar

	var spec_lbl := Label.new()
	spec_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	spec_lbl.offset_top = 0
	spec_lbl.offset_bottom = 30
	spec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spec_lbl.add_theme_font_size_override("font_size", 18)
	spec_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.96))
	spec_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	spec_lbl.add_theme_constant_override("outline_size", 4)
	spec_lbl.text = "Наблюдение"
	spec_bar.add_child(spec_lbl)
	_ui["spectate_lbl"] = spec_lbl

	var btn_spec_prev := Button.new()
	btn_spec_prev.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_spec_prev.offset_left = -210
	btn_spec_prev.offset_right = -70
	btn_spec_prev.offset_top = -36
	btn_spec_prev.offset_bottom = 0
	btn_spec_prev.text = "< Игрок"
	RoomsUI.style_button(btn_spec_prev, Color(0.45, 0.85, 1.0), 13)
	btn_spec_prev.pressed.connect(func() -> void: call("_cycle_spectate_target", -1))
	spec_bar.add_child(btn_spec_prev)

	var btn_spec_next := Button.new()
	btn_spec_next.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_spec_next.offset_left = -60
	btn_spec_next.offset_right = 80
	btn_spec_next.offset_top = -36
	btn_spec_next.offset_bottom = 0
	btn_spec_next.text = "Игрок >"
	RoomsUI.style_button(btn_spec_next, Color(0.45, 0.85, 1.0), 13)
	btn_spec_next.pressed.connect(func() -> void: call("_cycle_spectate_target", 1))
	spec_bar.add_child(btn_spec_next)

	var btn_spec_restart := Button.new()
	btn_spec_restart.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_spec_restart.offset_left = 94
	btn_spec_restart.offset_right = 230
	btn_spec_restart.offset_top = -36
	btn_spec_restart.offset_bottom = 0
	btn_spec_restart.text = "Рестарт [R]"
	RoomsUI.style_button(btn_spec_restart, Color(1.0, 0.72, 0.25), 13)
	btn_spec_restart.pressed.connect(Callable(self, "_reset_run"))
	spec_bar.add_child(btn_spec_restart)


func _make_ring_btn(parent: Control, accent: Color, stroke_w: float, right_off: float, top_off: float, diameter: float, anchor_preset: Control.LayoutPreset = Control.PRESET_BOTTOM_RIGHT, label_txt: String = "") -> RoomsUI.RingButton:
	var b := RoomsUI.RingButton.new()
	b.ring_color = accent
	b.stroke_width = stroke_w
	b.text = label_txt
	b.set_anchors_preset(anchor_preset)
	b.offset_left = right_off - diameter
	b.offset_right = right_off
	b.offset_top = top_off - diameter
	b.offset_bottom = top_off
	if not label_txt.is_empty():
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	parent.add_child(b)
	_mobile_btns.append(b)
	return b






func _build_mobile_ui(hud_group: Control) -> void:
	var mobile_group := Control.new()
	mobile_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	mobile_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mobile_group.visible = false
	hud_group.add_child(mobile_group)
	_ui["mobile_group"] = mobile_group

	# Left Floating Virtual Joystick Ring & Knob
	_joy_ring = Panel.new()
	_joy_ring.anchor_left = 0.0
	_joy_ring.anchor_right = 0.0
	_joy_ring.anchor_top = 1.0
	_joy_ring.anchor_bottom = 1.0
	_joy_ring.offset_left = 40
	_joy_ring.offset_right = 196
	_joy_ring.offset_top = -200
	_joy_ring.offset_bottom = -44
	_joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_ring.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.04, 0.07, 0.12, 0.28), Color(1.0, 1.0, 1.0, 0.36), 78, 2))
	_joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.65)
	mobile_group.add_child(_joy_ring)

	_joy_knob = Panel.new()
	_joy_knob.size = Vector2(58, 58)
	_joy_knob.position = Vector2(49, 49)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(1.0, 1.0, 1.0, 0.42), Color(1.0, 1.0, 1.0, 0.85), 29, 2))
	_joy_ring.add_child(_joy_knob)

	# Brutal minimal top-right pause ring
	var btn_pause := _make_ring_btn(mobile_group, Color(0.85, 0.90, 0.96, 0.85), 3.0, -24, 72, 48, Control.PRESET_TOP_RIGHT, "||")
	btn_pause.pressed.connect(func() -> void:
		if _state == State.PLAYING:
			call("_set_state", State.PAUSED)
	)
	_ui["m_btn_pause"] = btn_pause

	# Brutal Large WHITE hollow circle -> Flashlight toggle (std) / Hold to shake (Gummy)
	var btn_light := _make_ring_btn(mobile_group, Color(1.0, 1.0, 1.0, 0.96), 7.5, -24, -22, 126)
	btn_light.button_down.connect(func() -> void:
		if _is_action_locked():
			return
		if _active_tool == 1:
			_mobile_gummy_held = true
		else:
			call("_toggle_flashlight")
	)
	btn_light.button_up.connect(func() -> void:
		_mobile_gummy_held = false
	)
	_ui["m_btn_light"] = btn_light

	# Compact amber ring button to reload flashlight with 2 batteries when needed on mobile
	var btn_reload := _make_ring_btn(mobile_group, Color(1.0, 0.82, 0.25, 0.95), 4.5, -168, -124, 54, Control.PRESET_BOTTOM_RIGHT, "R")
	btn_reload.pressed.connect(func() -> void:
		if not _is_action_locked():
			call("_try_reload_flashlight")
	)
	btn_reload.visible = false
	_ui["m_btn_reload"] = btn_reload

	# Brutal smaller BLUE hollow circle -> HOLD TO SPRINT (above-right of white ring)
	var btn_sprint := _make_ring_btn(mobile_group, Color(0.14, 0.44, 1.0, 0.98), 6.0, -22, -162, 68)
	btn_sprint.button_down.connect(func() -> void:
		_mobile_sprint_held = true
	)
	btn_sprint.button_up.connect(func() -> void:
		_mobile_sprint_held = false
	)
	_ui["m_btn_sprint"] = btn_sprint

	# Optional emerald hollow circle when Gummy [2] is picked up (tap switches, hold shakes!)
	var btn_gummy := _make_ring_btn(mobile_group, Color(0.24, 0.98, 0.48, 0.95), 5.5, -168, -42, 68)
	btn_gummy.button_down.connect(func() -> void:
		if _is_action_locked():
			return
		if _has_gummy:
			if _active_tool != 1:
				_active_tool = 1
				audio.play_flashlight_click()
			else:
				_mobile_gummy_held = true
				call("_try_shake_gummy")
	)
	btn_gummy.button_up.connect(func() -> void:
		_mobile_gummy_held = false
	)
	btn_gummy.visible = false
	_ui["m_btn_gummy"] = btn_gummy

	# Clean exit directional rings ONLY when hiding (W outward 1.0s, S facing locker 0.7s)
	var btn_exit_fwd := _make_ring_btn(mobile_group, Color(0.32, 0.98, 0.58, 0.95), 5.5, -26, -158, 72, Control.PRESET_BOTTOM_RIGHT, "W")
	btn_exit_fwd.pressed.connect(func() -> void:
		if _is_hiding and not _is_action_locked():
			call("_exit_locker", false)
	)
	_ui["m_btn_exit_fwd"] = btn_exit_fwd

	var btn_exit_back := _make_ring_btn(mobile_group, Color(1.0, 0.68, 0.24, 0.95), 5.5, -26, -26, 72, Control.PRESET_BOTTOM_RIGHT, "S")
	btn_exit_back.pressed.connect(func() -> void:
		if _is_hiding and not _is_action_locked():
			call("_exit_locker", true)
	)
	_ui["m_btn_exit_back"] = btn_exit_back


func _layout_toast() -> void:
	var toast: Label = _ui.get("toast") as Label
	if toast == null:
		return
	if _mobile_controls_enabled:
		toast.anchor_left = 0.5
		toast.anchor_right = 0.5
		toast.anchor_top = 0.0
		toast.anchor_bottom = 0.0
		toast.offset_left = -330
		toast.offset_right = 330
		toast.offset_top = 150
		toast.offset_bottom = 234
		toast.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		toast.anchor_left = 0.5
		toast.anchor_right = 0.5
		toast.anchor_top = 1.0
		toast.anchor_bottom = 1.0
		toast.offset_left = -430
		toast.offset_right = 430
		toast.offset_top = -196
		toast.offset_bottom = -136
		toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


func _refresh_mobile_mode() -> void:
	if _mobile_override == 1:
		_mobile_controls_enabled = true
	elif _mobile_override == -1:
		_mobile_controls_enabled = false
	else:
		_mobile_controls_enabled = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()

	if _ui.has("mobile_group"):
		(_ui["mobile_group"] as Control).visible = _mobile_controls_enabled and (_state == State.PLAYING)
	_layout_toast()
	if _ui.has("btn_mobile"):
		var lbl := "Сенсорное управление: АВТО"
		if _mobile_override == 1:
			lbl = "Сенсорное управление: ВКЛ"
		elif _mobile_override == -1:
			lbl = "Сенсорное управление: ВЫКЛ"
		(_ui["btn_mobile"] as Button).text = lbl
	if _state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
	if _ui.has("btn_arch_next"):
		call("_style_arch_terminal_buttons")
		if _state == State.DEAD:
			call("_refresh_architect_controls")


func _cycle_mobile_mode() -> void:
	if _mobile_override == 0:
		_mobile_override = 1
	elif _mobile_override == 1:
		_mobile_override = -1
	else:
		_mobile_override = 0
	_refresh_mobile_mode()



func _update_mobile_ui(_interact_tgt: Dictionary) -> void:
	if not _mobile_controls_enabled or not _ui.has("mobile_group"):
		return
	var mg: Control = _ui["mobile_group"]
	mg.visible = (_state == State.PLAYING)
	if not mg.visible:
		return

	var b_fwd: RoomsUI.RingButton = _ui["m_btn_exit_fwd"]
	var b_back: RoomsUI.RingButton = _ui["m_btn_exit_back"]
	var b_sprint: RoomsUI.RingButton = _ui["m_btn_sprint"]
	var b_light: RoomsUI.RingButton = _ui["m_btn_light"]
	var b_gummy: RoomsUI.RingButton = _ui["m_btn_gummy"]
	var b_reload := _ui.get("m_btn_reload") as Control

	if _is_hiding:
		b_light.visible = (_active_tool == 1)
		b_sprint.visible = false
		b_gummy.visible = false
		if b_reload != null:
			b_reload.visible = false
		b_fwd.visible = true
		b_back.visible = (_hiding_kind != "under_desk")
	else:
		b_fwd.visible = false
		b_back.visible = false
		b_light.visible = true
		b_sprint.visible = true
		b_gummy.visible = _has_gummy
		if b_reload != null:
			b_reload.visible = (_batteries >= 2 and _std_battery < 149.9)

	b_light.ring_color = Color(1.0, 1.0, 1.0, 0.96) if _light_on else Color(0.88, 0.90, 0.94, 0.65)
	b_light.queue_redraw()
	b_sprint.ring_color = Color(0.28, 0.62, 1.0, 1.0) if (_mobile_sprint_held or _joy_sprint) else Color(0.14, 0.44, 1.0, 0.95)
	b_sprint.queue_redraw()
	if _has_gummy:
		b_gummy.ring_color = Color(0.32, 1.0, 0.56, 1.0) if _active_tool == 1 else Color(0.22, 0.78, 0.44, 0.68)
		b_gummy.queue_redraw()
