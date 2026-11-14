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

	# Make Haste countdown timer HUD label (top center)
	var haste_lbl := Label.new()
	haste_lbl.name = "HasteTimerLbl"
	haste_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haste_lbl.offset_top = 22
	haste_lbl.offset_bottom = 54
	haste_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	haste_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	haste_lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	haste_lbl.add_theme_font_size_override("font_size", 20)
	haste_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	haste_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	haste_lbl.add_theme_constant_override("outline_size", 4)
	haste_lbl.visible = false
	haste_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(haste_lbl)
	_ui["haste_lbl"] = haste_lbl

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
	a90_sign_box.offset_left = -90
	a90_sign_box.offset_top = -90
	a90_sign_box.offset_right = 90
	a90_sign_box.offset_bottom = 90
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
	a90_stop_icon.custom_minimum_size = Vector2(180, 180)
	a90_stop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_stop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_stop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("stopsign"):
		a90_stop_icon.texture = _a90_textures["stopsign"]
	a90_icon_center.add_child(a90_stop_icon)
	_ui["a90_stop_icon"] = a90_stop_icon

	var a90_stop := Label.new()
	a90_stop.set_anchors_preset(Control.PRESET_CENTER)
	a90_stop.text = ""
	a90_stop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_stop.visible = false
	a90_root.add_child(a90_stop)
	_ui["a90_stop"] = a90_stop

	var a90_bar_holder := Control.new()
	a90_bar_holder.set_anchors_preset(Control.PRESET_CENTER)
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
	a90_hint.text = ""
	a90_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_hint.visible = false
	a90_root.add_child(a90_hint)
	_ui["a90_hint"] = a90_hint

	# A-90 hit flash (jumpscare face - same compact size)
	var a90_scare_rect := TextureRect.new()
	a90_scare_rect.set_anchors_preset(Control.PRESET_CENTER)
	a90_scare_rect.offset_left = -90
	a90_scare_rect.offset_top = -90
	a90_scare_rect.offset_right = 90
	a90_scare_rect.offset_bottom = 90
	a90_scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_scare_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_scare_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	a90_scare_rect.visible = false
	a90_scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("rage"):
		a90_scare_rect.texture = _a90_textures["rage"]
	root.add_child(a90_scare_rect)
	_ui["a90_scare_rect"] = a90_scare_rect

	# Main menu (drawn under the pause modal / death screen)
	call("_build_main_menu", root)

	# Pause / Victory Overlay (minimal text links + animated white noise)
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	_ui["modal"] = modal

	var pause_dim := ColorRect.new()
	pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dim.color = Color(0.014, 0.016, 0.021, 0.76)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(pause_dim)
	_ui["pause_dim"] = pause_dim

	var pause_noise := ColorRect.new()
	pause_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_noise.material = RoomsUI.make_noise_material(0.90, 1.0)
	pause_noise.color = Color(1.0, 1.0, 1.0, 1.0)
	pause_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(pause_noise)
	_ui["pause_noise"] = pause_noise

	var m_brand := Label.new()
	m_brand.text = "r00ms"
	m_brand.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	m_brand.offset_left = -380
	m_brand.offset_top = 24
	m_brand.offset_right = -60
	m_brand.offset_bottom = 94
	m_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m_brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m_brand.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	m_brand.add_theme_font_size_override("font_size", 46)
	m_brand.add_theme_color_override("font_color", Color(0.93, 0.94, 0.97, 0.90))
	m_brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(m_brand)
	_ui["m_brand"] = m_brand

	var m_main_box := VBoxContainer.new()
	m_main_box.anchor_left = 0.055
	m_main_box.anchor_right = 0.055
	m_main_box.anchor_top = 0.115
	m_main_box.anchor_bottom = 0.115
	m_main_box.offset_right = 470
	m_main_box.offset_bottom = 430
	m_main_box.add_theme_constant_override("separation", 2)
	modal.add_child(m_main_box)
	_ui["m_main_box"] = m_main_box

	var m_title := Label.new()
	m_title.text = "ПАУЗА"
	m_title.visible = false
	m_title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	m_title.add_theme_font_size_override("font_size", 22)
	m_title.add_theme_color_override("font_color", Color(0.74, 0.78, 0.86, 0.92))
	m_main_box.add_child(m_title)
	_ui["m_title"] = m_title

	var m_desc := Label.new()
	m_desc.text = ""
	m_desc.visible = false
	m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_desc.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	m_desc.add_theme_font_size_override("font_size", 14)
	m_desc.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80, 0.86))
	m_main_box.add_child(m_desc)
	_ui["m_desc"] = m_desc

	var btn_resume := Button.new()
	btn_resume.text = "continue"
	btn_resume.custom_minimum_size = Vector2(0, 56)
	RoomsUI.style_link_button(btn_resume, 34)
	btn_resume.pressed.connect(func(): call("_set_state", State.PLAYING))
	m_main_box.add_child(btn_resume)
	_ui["btn_resume"] = btn_resume

	var btn_settings := Button.new()
	btn_settings.text = "settings"
	btn_settings.custom_minimum_size = Vector2(0, 46)
	RoomsUI.style_link_button(btn_settings, 26)
	btn_settings.pressed.connect(func(): _open_settings_panel(true))
	m_main_box.add_child(btn_settings)
	_ui["btn_settings"] = btn_settings

	var btn_pause_admin := Button.new()
	btn_pause_admin.name = "BtnPauseAdmin"
	btn_pause_admin.text = "admin panel"
	btn_pause_admin.custom_minimum_size = Vector2(0, 46)
	RoomsUI.style_link_button(btn_pause_admin, 26)
	btn_pause_admin.pressed.connect(func(): _open_admin_panel(true))
	btn_pause_admin.visible = false
	m_main_box.add_child(btn_pause_admin)
	_ui["btn_pause_admin"] = btn_pause_admin

	var btn_exit := Button.new()
	btn_exit.text = "exit"
	btn_exit.custom_minimum_size = Vector2(0, 46)
	RoomsUI.style_link_button(btn_exit, 26)
	btn_exit.pressed.connect(func(): call("_exit_to_main_menu"))
	m_main_box.add_child(btn_exit)
	_ui["btn_exit"] = btn_exit

	var m_underline := ColorRect.new()
	m_underline.custom_minimum_size = Vector2(300, 1)
	m_underline.color = Color(1.0, 1.0, 1.0, 0.26)
	m_underline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	m_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_main_box.add_child(m_underline)
	_ui["m_underline"] = m_underline

	# Active modifiers list on the right side of pause menu (strictly in pause)
	var m_mods_box := VBoxContainer.new()
	m_mods_box.anchor_left = 0.65
	m_mods_box.anchor_right = 0.95
	m_mods_box.anchor_top = 0.12
	m_mods_box.anchor_bottom = 0.85
	m_mods_box.add_theme_constant_override("separation", 6)
	modal.add_child(m_mods_box)
	_ui["m_mods_box"] = m_mods_box

	var m_mods_hdr := Label.new()
	m_mods_hdr.text = "modifiers"
	m_mods_hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	m_mods_hdr.add_theme_font_size_override("font_size", 24)
	m_mods_hdr.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 0.9))
	m_mods_box.add_child(m_mods_hdr)

	var m_mods_div := ColorRect.new()
	m_mods_div.custom_minimum_size = Vector2(140, 1)
	m_mods_div.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	m_mods_div.color = Color(1.0, 1.0, 1.0, 0.25)
	m_mods_box.add_child(m_mods_div)

	var m_mods_list := Label.new()
	m_mods_list.text = "• none (default)"
	m_mods_list.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	m_mods_list.add_theme_font_size_override("font_size", 15)
	m_mods_list.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84, 0.85))
	m_mods_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_mods_box.add_child(m_mods_list)
	_ui["m_mods_list"] = m_mods_list

	# Settings panel (shares the same modal, replaces the links while open)
	var m_settings_scroll := ScrollContainer.new()
	m_settings_scroll.set_anchors_preset(Control.PRESET_CENTER)
	m_settings_scroll.offset_left = -312
	m_settings_scroll.offset_right = 312
	m_settings_scroll.offset_top = -336
	m_settings_scroll.offset_bottom = 324
	m_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m_settings_scroll.visible = false
	modal.add_child(m_settings_scroll)
	_ui["m_settings_scroll"] = m_settings_scroll

	var vsb := m_settings_scroll.get_v_scroll_bar()
	vsb.custom_minimum_size.x = 4
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(1.0, 1.0, 1.0, 0.05)
	sb_track.set_corner_radius_all(2)
	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = Color(1.0, 1.0, 1.0, 0.22)
	sb_grab.set_corner_radius_all(2)
	var sb_grab_hi := StyleBoxFlat.new()
	sb_grab_hi.bg_color = Color(1.0, 1.0, 1.0, 0.46)
	sb_grab_hi.set_corner_radius_all(2)
	vsb.add_theme_stylebox_override("scroll", sb_track)
	vsb.add_theme_stylebox_override("grabber", sb_grab)
	vsb.add_theme_stylebox_override("grabber_highlight", sb_grab_hi)
	vsb.add_theme_stylebox_override("grabber_pressed", sb_grab_hi)

	var m_settings_box := VBoxContainer.new()
	m_settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_settings_box.add_theme_constant_override("separation", 8)
	m_settings_scroll.add_child(m_settings_box)
	_ui["m_settings_box"] = m_settings_box

	var add_hdr := func(txt: String) -> void:
		var hdr := Label.new()
		hdr.text = txt
		hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
		hdr.add_theme_font_size_override("font_size", 12)
		hdr.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 0.85))
		m_settings_box.add_child(hdr)

	add_hdr.call("звук")
	var neutral := Color(0.80, 0.84, 0.90)

	var make_slider := func(title_str: String, s_key: String, l_key: String, min_v: float, max_v: float, step_v: float, init_v: float, accent: Color, on_chg: Callable) -> void:
		var row := HBoxContainer.new()
		m_settings_box.add_child(row)
		var t_lbl := Label.new()
		t_lbl.text = title_str
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.add_theme_font_size_override("font_size", 14)
		t_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94, 0.92))
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
		sld.custom_minimum_size = Vector2(0, 22)
		sld.value_changed.connect(on_chg)
		m_settings_box.add_child(sld)
		_ui[s_key] = sld
		_ui[l_key] = v_lbl

	make_slider.call("Общая громкость", "sld_master", "lbl_master", 0.0, 100.0, 1.0, _audio_master * 100.0, neutral, func(val: float) -> void:
		_audio_master = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	make_slider.call("Монстры", "sld_entities", "lbl_entities", 0.0, 100.0, 1.0, _audio_entities * 100.0, neutral, func(val: float) -> void:
		_audio_entities = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	make_slider.call("Эффекты и фонарик", "sld_sfx", "lbl_sfx", 0.0, 100.0, 1.0, _audio_sfx * 100.0, neutral, func(val: float) -> void:
		_audio_sfx = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	make_slider.call("Атмосфера", "sld_ambient", "lbl_ambient", 0.0, 100.0, 1.0, _audio_ambient * 100.0, neutral, func(val: float) -> void:
		_audio_ambient = clampf(val / 100.0, 0.0, 1.0)
		_apply_audio_settings(true)
		_sync_settings_ui()
	)

	var audio_btn_row := HBoxContainer.new()
	audio_btn_row.add_theme_constant_override("separation", 6)
	m_settings_box.add_child(audio_btn_row)

	var btn_mute_audio := Button.new()
	btn_mute_audio.text = "звук: вкл [M]"
	btn_mute_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mute_audio.custom_minimum_size = Vector2(0, 34)
	RoomsUI.style_button(btn_mute_audio, neutral, 13)
	btn_mute_audio.pressed.connect(func() -> void:
		_audio_muted = not _audio_muted
		_apply_audio_settings(true)
		_sync_settings_ui()
	)
	audio_btn_row.add_child(btn_mute_audio)
	_ui["btn_mute_audio"] = btn_mute_audio

	var btn_reset_audio := Button.new()
	btn_reset_audio.text = "сбросить звук"
	btn_reset_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset_audio.custom_minimum_size = Vector2(0, 34)
	RoomsUI.style_button(btn_reset_audio, neutral, 13)
	btn_reset_audio.pressed.connect(_reset_audio_defaults)
	audio_btn_row.add_child(btn_reset_audio)
	_ui["btn_reset_audio"] = btn_reset_audio

	# Input / Output audio devices
	var dev_out_lbl := Label.new()
	dev_out_lbl.text = "Устройство вывода"
	dev_out_lbl.add_theme_font_size_override("font_size", 13)
	dev_out_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94, 0.88))
	m_settings_box.add_child(dev_out_lbl)

	var opt_audio_out := OptionButton.new()
	opt_audio_out.custom_minimum_size = Vector2(0, 32)
	opt_audio_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(opt_audio_out, neutral, 12)
	var out_devs: PackedStringArray = AudioServer.get_output_device_list()
	var cur_out: String = AudioServer.output_device
	var out_idx_to_select := 0
	for i in range(out_devs.size()):
		var d := out_devs[i]
		opt_audio_out.add_item(d, i)
		if d == cur_out:
			out_idx_to_select = i
	if out_devs.size() > 0:
		opt_audio_out.selected = out_idx_to_select
	opt_audio_out.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < out_devs.size():
			AudioServer.output_device = out_devs[idx]
			_save_render_settings()
			_show_toast("Вывод: %s" % out_devs[idx], 1.8)
	)
	m_settings_box.add_child(opt_audio_out)
	_ui["opt_audio_out"] = opt_audio_out

	var dev_in_lbl := Label.new()
	dev_in_lbl.text = "Микрофон (Ввод)"
	dev_in_lbl.add_theme_font_size_override("font_size", 13)
	dev_in_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94, 0.88))
	m_settings_box.add_child(dev_in_lbl)

	var opt_audio_in := OptionButton.new()
	opt_audio_in.custom_minimum_size = Vector2(0, 32)
	opt_audio_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(opt_audio_in, neutral, 12)
	var in_devs: PackedStringArray = AudioServer.get_input_device_list()
	var cur_in: String = AudioServer.input_device
	var in_idx_to_select := 0
	for i in range(in_devs.size()):
		var d := in_devs[i]
		opt_audio_in.add_item(d, i)
		if d == cur_in:
			in_idx_to_select = i
	if in_devs.size() > 0:
		opt_audio_in.selected = in_idx_to_select
	opt_audio_in.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < in_devs.size():
			AudioServer.input_device = in_devs[idx]
			_save_render_settings()
			_show_toast("Микрофон: %s" % in_devs[idx], 1.8)
	)
	m_settings_box.add_child(opt_audio_in)
	_ui["opt_audio_in"] = opt_audio_in

	add_hdr.call("камера и управление")
	make_slider.call("Чувствительность обзора", "sld_sens", "lbl_sens", 0.4, 2.2, 0.05, _mouse_sens_mult, neutral, func(val: float) -> void:
		_mouse_sens_mult = clampf(val, 0.4, 2.2)
		_save_render_settings()
		_sync_settings_ui()
	)
	make_slider.call("Поле зрения (FOV)", "sld_fov", "lbl_fov", 65.0, 95.0, 1.0, _base_fov, neutral, func(val: float) -> void:
		_base_fov = clampf(val, 65.0, 95.0)
		_save_render_settings()
		_sync_settings_ui()
	)

	var btn_head_bob := Button.new()
	btn_head_bob.text = "покачивание камеры: вкл"
	btn_head_bob.custom_minimum_size = Vector2(0, 34)
	RoomsUI.style_button(btn_head_bob, neutral, 13)
	btn_head_bob.pressed.connect(func() -> void:
		_head_bob_enabled = not _head_bob_enabled
		_save_render_settings()
		_sync_settings_ui()
	)
	m_settings_box.add_child(btn_head_bob)
	_ui["btn_head_bob"] = btn_head_bob

	add_hdr.call("игра и рендер")
	var btn_restart := Button.new()
	btn_restart.text = "начать заново (A-000)"
	btn_restart.custom_minimum_size = Vector2(0, 36)
	RoomsUI.style_button(btn_restart, neutral, 13)
	btn_restart.pressed.connect(Callable(self, "_reset_run"))
	m_settings_box.add_child(btn_restart)

	var btn_mobile := Button.new()
	btn_mobile.text = "сенсорное управление: авто"
	btn_mobile.custom_minimum_size = Vector2(0, 34)
	RoomsUI.style_button(btn_mobile, neutral, 13)
	btn_mobile.pressed.connect(_cycle_mobile_mode)
	m_settings_box.add_child(btn_mobile)
	_ui["btn_mobile"] = btn_mobile

	var ren_row := HBoxContainer.new()
	ren_row.add_theme_constant_override("separation", 6)
	m_settings_box.add_child(ren_row)

	var btn_quality := Button.new()
	btn_quality.text = "графика: %s" % _quality_label(_render_quality)
	btn_quality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quality.custom_minimum_size = Vector2(0, 34)
	RoomsUI.style_button(btn_quality, neutral, 12)
	btn_quality.pressed.connect(_cycle_render_quality)
	ren_row.add_child(btn_quality)
	_ui["btn_quality"] = btn_quality

	var btn_backend := Button.new()
	btn_backend.text = "бэкенд: %s" % _backend_label(_render_backend)
	btn_backend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_backend.custom_minimum_size = Vector2(0, 34)
	RoomsUI.style_button(btn_backend, neutral, 12)
	btn_backend.pressed.connect(_cycle_render_backend)
	ren_row.add_child(btn_backend)
	_ui["btn_backend"] = btn_backend

	var btn_restart_render := Button.new()
	btn_restart_render.text = "перезапустить с новым рендером"
	btn_restart_render.custom_minimum_size = Vector2(0, 32)
	btn_restart_render.visible = (_render_backend != _active_render_backend)
	RoomsUI.style_button(btn_restart_render, Color(1.0, 0.62, 0.30), 12)
	btn_restart_render.pressed.connect(_restart_for_render)
	m_settings_box.add_child(btn_restart_render)
	_ui["btn_restart_render"] = btn_restart_render

	add_hdr.call("сеть")
	var net_status := Label.new()
	net_status.text = _net.get_summary_status() if _net != null else "offline"
	net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status.add_theme_font_size_override("font_size", 12)
	net_status.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98, 0.92))
	m_settings_box.add_child(net_status)
	_ui["net_status"] = net_status

	var steam_row := HBoxContainer.new()
	steam_row.add_theme_constant_override("separation", 6)
	m_settings_box.add_child(steam_row)

	var btn_steam_host := Button.new()
	btn_steam_host.text = "steam лобби (480)"
	btn_steam_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_steam_host, neutral, 12)
	btn_steam_host.pressed.connect(func() -> void:
		if _net != null:
			_net.host_steam_lobby(int(_rng.seed), _highest_opened)
	)
	steam_row.add_child(btn_steam_host)

	var btn_steam_find := Button.new()
	btn_steam_find.text = "найти lobbies"
	btn_steam_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_steam_find, neutral, 12)
	btn_steam_find.pressed.connect(func() -> void:
		if _net != null:
			_net.search_steam_lobbies()
	)
	steam_row.add_child(btn_steam_find)

	var enet_row := HBoxContainer.new()
	enet_row.add_theme_constant_override("separation", 6)
	m_settings_box.add_child(enet_row)

	var btn_lan_host := Button.new()
	btn_lan_host.text = "локальная сеть (host)"
	btn_lan_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_lan_host, neutral, 12)
	btn_lan_host.pressed.connect(func() -> void:
		if _net != null:
			_net.host_enet(int(_rng.seed))
	)
	enet_row.add_child(btn_lan_host)

	var btn_lan_join := Button.new()
	btn_lan_join.text = "войти 127.0.0.1"
	btn_lan_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_lan_join, neutral, 12)
	btn_lan_join.pressed.connect(func() -> void:
		if _net != null:
			_net.join_enet("127.0.0.1")
	)
	enet_row.add_child(btn_lan_join)

	var steam_act_row := HBoxContainer.new()
	steam_act_row.add_theme_constant_override("separation", 6)
	m_settings_box.add_child(steam_act_row)

	var btn_net_invite := Button.new()
	btn_net_invite.text = "пригласить друзей"
	btn_net_invite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_net_invite, neutral, 12)
	btn_net_invite.pressed.connect(func() -> void:
		if _net != null:
			_net.open_steam_invite_overlay(int(_rng.seed), _highest_opened)
	)
	steam_act_row.add_child(btn_net_invite)
	_ui["btn_net_invite"] = btn_net_invite

	var btn_net_disc := Button.new()
	btn_net_disc.text = "отключиться"
	btn_net_disc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_net_disc, Color(1.0, 0.62, 0.52), 12)
	btn_net_disc.pressed.connect(func() -> void:
		if _net != null:
			_net.disconnect_session()
	)
	steam_act_row.add_child(btn_net_disc)
	_ui["btn_net_disc"] = btn_net_disc

	_lobby_list_box = VBoxContainer.new()
	_lobby_list_box.add_theme_constant_override("separation", 4)
	m_settings_box.add_child(_lobby_list_box)

	var btn_settings_back := Button.new()
	btn_settings_back.text = "← back"
	btn_settings_back.custom_minimum_size = Vector2(0, 44)
	RoomsUI.style_link_button(btn_settings_back, 20)
	btn_settings_back.pressed.connect(func(): _open_settings_panel(false))
	m_settings_box.add_child(btn_settings_back)
	_ui["btn_settings_back"] = btn_settings_back

	# Admin panel inside Pause Modal (minimalist r00ms style)
	var m_admin_scroll := ScrollContainer.new()
	m_admin_scroll.set_anchors_preset(Control.PRESET_CENTER)
	m_admin_scroll.offset_left = -280
	m_admin_scroll.offset_right = 280
	m_admin_scroll.offset_top = -280
	m_admin_scroll.offset_bottom = 280
	m_admin_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m_admin_scroll.visible = false
	modal.add_child(m_admin_scroll)
	_ui["m_admin_scroll"] = m_admin_scroll

	var asb := m_admin_scroll.get_v_scroll_bar()
	asb.custom_minimum_size.x = 4
	asb.add_theme_stylebox_override("scroll", sb_track)
	asb.add_theme_stylebox_override("grabber", sb_grab)
	asb.add_theme_stylebox_override("grabber_highlight", sb_grab_hi)
	asb.add_theme_stylebox_override("grabber_pressed", sb_grab_hi)

	var m_admin_box := VBoxContainer.new()
	m_admin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_admin_box.add_theme_constant_override("separation", 6)
	m_admin_scroll.add_child(m_admin_box)
	_ui["m_admin_box"] = m_admin_box

	var adm_title := Label.new()
	adm_title.text = "admin console"
	adm_title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	adm_title.add_theme_font_size_override("font_size", 24)
	adm_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	m_admin_box.add_child(adm_title)

	var adm_sub := Label.new()
	adm_sub.text = "[ прогресс и рекорды аннулируются ]"
	adm_sub.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	adm_sub.add_theme_font_size_override("font_size", 12)
	adm_sub.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45, 0.85))
	m_admin_box.add_child(adm_sub)

	var adm_div := ColorRect.new()
	adm_div.custom_minimum_size = Vector2(0, 1)
	adm_div.color = Color(1.0, 1.0, 1.0, 0.22)
	m_admin_box.add_child(adm_div)

	var add_adm_cmd := func(txt: String, cb: Callable, col: Color = Color(0.85, 0.88, 0.94)) -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(0, 36)
		RoomsUI.style_link_button(b, 17, HORIZONTAL_ALIGNMENT_LEFT)
		b.add_theme_color_override("font_color", col)
		b.pressed.connect(func() -> void:
			if not _can_use_admin():
				_show_toast("Панель доступна только хосту!", 2.0)
				return
			_admin_cheats_used = true
			if cb.get_argument_count() > 0:
				cb.call(b)
			else:
				cb.call()
		)
		m_admin_box.add_child(b)
		return b

	add_adm_cmd.call("revive", func() -> void:
		_hp = 100
		_is_hiding = false
		call("_set_state", State.PLAYING)
		if _ui.has("arch_root"):
			(_ui["arch_root"] as Control).visible = false
		if _ui.has("arch_stats_win"):
			(_ui["arch_stats_win"] as Control).visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_show_toast("Возрождение выполнено!", 2.0)
	, Color(0.35, 1.0, 0.55))

	add_adm_cmd.call("kill", func() -> void:
		_open_admin_panel(false)
		call("_set_state", State.PLAYING)
		call("_trigger_death", "Команда администратора", "Админ нажал Kill в консоли управления.", {})
	, Color(1.0, 0.4, 0.4))

	add_adm_cmd.call("+50 hp", func() -> void:
		_hp = mini(_hp + 50, 100)
		_show_toast("Здоровье: %d/100" % _hp, 1.8)
	)

	var btn_god: Button = add_adm_cmd.call("god mode: off", func(b: Button) -> void:
		_admin_god_mode = not _admin_god_mode
		b.text = "god mode: %s" % ("on" if _admin_god_mode else "off")
		b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if _admin_god_mode else Color(0.85, 0.88, 0.94))
		_show_toast("Бог-режим: %s" % ("ВКЛ" if _admin_god_mode else "ВЫКЛ"), 1.8)
	)
	_ui["adm_btn_god"] = btn_god

	var btn_stam: Button = add_adm_cmd.call("infinite stamina: off", func(b: Button) -> void:
		_admin_inf_stamina = not _admin_inf_stamina
		b.text = "infinite stamina: %s" % ("on" if _admin_inf_stamina else "off")
		b.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if _admin_inf_stamina else Color(0.85, 0.88, 0.94))
		_show_toast("Беск. выносливость: %s" % ("ВКЛ" if _admin_inf_stamina else "ВЫКЛ"), 1.8)
	)
	_ui["adm_btn_stamina"] = btn_stam

	var btn_noclip: Button = add_adm_cmd.call("noclip / fly: off", func(b: Button) -> void:
		_admin_noclip = not _admin_noclip
		b.text = "noclip / fly: %s" % ("on" if _admin_noclip else "off")
		b.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8) if _admin_noclip else Color(0.85, 0.88, 0.94))
		_show_toast("Noclip (Полёт): %s [WASD + Space/Ctrl]" % ("ВКЛ" if _admin_noclip else "ВЫКЛ"), 2.2)
	)
	_ui["adm_btn_noclip"] = btn_noclip

	var btn_speed: Button = add_adm_cmd.call("speed boost: 1.0x", func(b: Button) -> void:
		if _admin_speed_mult < 1.5:
			_admin_speed_mult = 2.0
		elif _admin_speed_mult < 2.5:
			_admin_speed_mult = 3.0
		else:
			_admin_speed_mult = 1.0
		b.text = "speed boost: %.1fx" % _admin_speed_mult
		b.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if _admin_speed_mult > 1.0 else Color(0.85, 0.88, 0.94))
		_show_toast("Множитель скорости: %.1fx" % _admin_speed_mult, 1.8)
	)
	_ui["adm_btn_speed"] = btn_speed

	var btn_bat: Button = add_adm_cmd.call("infinite battery: off", func(b: Button) -> void:
		_admin_inf_battery = not _admin_inf_battery
		b.text = "infinite battery: %s" % ("on" if _admin_inf_battery else "off")
		b.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5) if _admin_inf_battery else Color(0.85, 0.88, 0.94))
		_show_toast("Бесконечный заряд: %s" % ("ВКЛ" if _admin_inf_battery else "ВЫКЛ"), 1.8)
	)
	_ui["adm_btn_battery"] = btn_bat

	add_adm_cmd.call("give gummy flashlight", func() -> void:
		_has_gummy = true
		_gummy_battery = 100.0
		call("_update_inventory_ui")
		_show_toast("Изумрудный фонарик (Gummy) получен!", 2.0)
	)

	add_adm_cmd.call("+5 batteries", func() -> void:
		_batteries = mini(_batteries + 5, 8)
		call("_update_inventory_ui")
		_show_toast("Батарейки: %d/8" % _batteries, 1.8)
	)

	add_adm_cmd.call("skip +5 rooms", func() -> void:
		for i in range(5):
			var target_r: RoomBuilder.RoomInstance = call("_find_first_closed_door_room")
			if target_r != null:
				call("_open_door", target_r, true)
		var next_r: RoomBuilder.RoomInstance = call("_find_first_closed_door_room")
		if next_r != null and is_instance_valid(next_r.root):
			player_body.global_position = next_r.root.global_position + Vector3(0.0, 0.2, 0.0)
		_show_toast("Пропущено 5 комнат!", 2.0)
		_open_admin_panel(false)
		call("_set_state", State.PLAYING)
	)

	add_adm_cmd.call("skip +10 rooms", func() -> void:
		for i in range(10):
			var target_r: RoomBuilder.RoomInstance = call("_find_first_closed_door_room")
			if target_r != null:
				call("_open_door", target_r, true)
		var next_r: RoomBuilder.RoomInstance = call("_find_first_closed_door_room")
		if next_r != null and is_instance_valid(next_r.root):
			player_body.global_position = next_r.root.global_position + Vector3(0.0, 0.2, 0.0)
		_show_toast("Пропущено 10 комнат!", 2.0)
		_open_admin_panel(false)
		call("_set_state", State.PLAYING)
	)

	add_adm_cmd.call("despawn all monsters", func() -> void:
		_a60_active = false
		_a60_phase = 0
		_a60_prime_flicker_active = false
		_a60_prime_pending_timer = 0.0
		_a60_prime_chains_left = 0
		if is_instance_valid(_a60_node):
			_a60_node.visible = false
		audio.stop_a60()
		_a120_active = false
		_a120_phase = 0
		if is_instance_valid(_a120_node):
			_a120_node.visible = false
		audio.stop_a120()
		_a90_phase = 0
		if _ui.has("a90_root"):
			(_ui["a90_root"] as Control).visible = false
		if _net != null and _net.is_online():
			_net.broadcast_entity_event({"k": "a60_end"}, true)
			_net.broadcast_entity_event({"k": "a120_end"}, true)
			_net.broadcast_entity_event({"k": "a90_end"}, true)
		_show_toast("Все монстры деспавнены!", 2.0)
	, Color(0.4, 1.0, 0.6))

	add_adm_cmd.call("toggle blackout", func() -> void:
		if not _power_out:
			call("_trigger_power_outage")
			_show_toast("Блэкаут активирован!", 2.0)
		else:
			_power_out = false
			for r in _rooms:
				if r != null and is_instance_valid(r.light):
					r.light.visible = true
					r.light.light_energy = 1.0
			_show_toast("Освещение включено!", 2.0)
	)

	var btn_time: Button = add_adm_cmd.call("game speed: 1.0x", func(b: Button) -> void:
		if Engine.time_scale >= 1.9:
			Engine.time_scale = 0.5
			b.text = "game speed: 0.5x"
		elif Engine.time_scale <= 0.6:
			Engine.time_scale = 1.0
			b.text = "game speed: 1.0x"
		else:
			Engine.time_scale = 2.0
			b.text = "game speed: 2.0x"
		_show_toast("Скорость игры: %.1fx" % Engine.time_scale, 1.8)
	)
	_ui["adm_btn_timescale"] = btn_time

	add_adm_cmd.call("revive all peers", func() -> void:
		_hp = 100
		_is_hiding = false
		call("_set_state", State.PLAYING)
		if _ui.has("arch_root"):
			(_ui["arch_root"] as Control).visible = false
		if _ui.has("arch_stats_win"):
			(_ui["arch_stats_win"] as Control).visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if _net != null and _net.is_online():
			_net.broadcast_entity_event({"k": "admin_revive"}, true)
		_show_toast("Все игроки возрождены!", 2.5)
	, Color(0.35, 1.0, 0.55))

	add_adm_cmd.call("spawn a-60", func() -> void:
		call("_spawn_a60", false)
		_show_toast("Спавн A-60 запущен!", 2.0)
	)

	add_adm_cmd.call("spawn a-60 prime", func() -> void:
		call("_spawn_a60", true)
		_show_toast("Спавн A-60 Prime запущен!", 2.0)
	)

	add_adm_cmd.call("spawn a-90", func() -> void:
		call("_start_a90_local")
		_show_toast("Тест рефлекса A-90 запущен!", 2.0)
	)

	add_adm_cmd.call("spawn a-120", func() -> void:
		call("_spawn_a120")
		_show_toast("Спавн A-120 запущен!", 2.0)
	)

	add_adm_cmd.call("tp to next door", func() -> void:
		var target_r: RoomBuilder.RoomInstance = call("_find_first_closed_door_room")
		if target_r != null and is_instance_valid(target_r.exit_anchor):
			player_body.global_position = target_r.exit_anchor.global_position - Vector3(0, 0, 1.5)
			_show_toast("Телепортация к двери A-%03d!" % (target_r.index + 1), 2.0)
			_open_admin_panel(false)
			call("_set_state", State.PLAYING)
	)

	add_adm_cmd.call("refill battery", func() -> void:
		_std_battery = 150.0
		_gummy_battery = 100.0
		_batteries = mini(_batteries + 2, 8)
		_show_toast("Фонарик и батарейки восполнены!", 2.0)
	)

	add_adm_cmd.call("grant admin to all", func() -> void:
		if _net != null and _net.is_online():
			_net.broadcast_entity_event({"k": "admin_grant"}, true)
			_show_toast("Права администратора выданы всем игрокам!", 2.5)
		else:
			_show_toast("В одиночной игре админка уже доступна", 2.0)
	)

	var adm_back_div := ColorRect.new()
	adm_back_div.custom_minimum_size = Vector2(0, 1)
	adm_back_div.color = Color(1.0, 1.0, 1.0, 0.15)
	m_admin_box.add_child(adm_back_div)

	var btn_adm_back := Button.new()
	btn_adm_back.text = "← back"
	btn_adm_back.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_link_button(btn_adm_back, 20)
	btn_adm_back.pressed.connect(func(): _open_admin_panel(false))
	m_admin_box.add_child(btn_adm_back)

	# Death screen: two cmd.exe terminal windows (minimal, mouse unlocked)
	# Architect Death Void (Full-screen CRT Matrix green terminal + ASCII Art)
	var arch_overlay := Control.new()
	arch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_overlay.visible = false
	root.add_child(arch_overlay)
	_ui["architect_overlay"] = arch_overlay

	var arch_bg := ColorRect.new()
	arch_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_bg.color = Color.WHITE
	arch_bg.material = RoomsArchitect.make_void_shader_material()
	arch_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	arch_bg.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			call("_advance_architect_dialogue")
	)
	arch_overlay.add_child(arch_bg)
	_ui["arch_bg"] = arch_bg

	var arch_mono_f := RoomsArchitect.get_terminal_font()

	# Top-left Matrix CRT terminal speech text (the old full-screen Architect speech)
	var arch_speech := Label.new()
	arch_speech.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_speech.anchor_left = 0.05
	arch_speech.anchor_right = 0.62
	arch_speech.anchor_top = 0.08
	arch_speech.anchor_bottom = 0.60
	arch_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	arch_speech.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	arch_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arch_speech.add_theme_font_override("font", arch_mono_f)
	arch_speech.add_theme_font_size_override("font_size", 22)
	arch_speech.add_theme_color_override("font_color", Color(0.28, 1.0, 0.42))
	arch_speech.add_theme_color_override("font_outline_color", Color(0.01, 0.16, 0.04, 0.95))
	arch_speech.add_theme_constant_override("outline_size", 4)
	arch_speech.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	arch_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_speech)
	_ui["arch_speech"] = arch_speech

	# Bottom-right ASCII Art Monster Portrait
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
	arch_page.offset_left = -260
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

	# --- Statistics cmd.exe Window (Opens ONLY AFTER the Architect dialogue completes!) ---
	var big := Panel.new()
	big.anchor_left = 0.5
	big.anchor_right = 0.5
	big.anchor_top = 0.5
	big.anchor_bottom = 0.5
	big.offset_left = -340
	big.offset_right = 340
	big.offset_top = -220
	big.offset_bottom = 180
	big.add_theme_stylebox_override("panel", RoomsUI.make_cmd_window_style())
	big.visible = false
	arch_overlay.add_child(big)
	_ui["arch_window_big"] = big

	var big_bar := ColorRect.new()
	big_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	big_bar.offset_left = 1
	big_bar.offset_right = -1
	big_bar.offset_top = 1
	big_bar.offset_bottom = 31
	big_bar.color = Color(0.13, 0.14, 0.17, 1.0)
	big_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.add_child(big_bar)

	var big_bar_lbl := Label.new()
	big_bar_lbl.text = "C:\\Windows\\System32\\cmd.exe - [r00ms death report]"
	big_bar_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	big_bar_lbl.offset_left = 12
	big_bar_lbl.offset_top = 1
	big_bar_lbl.offset_right = -34
	big_bar_lbl.offset_bottom = 31
	big_bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_bar_lbl.add_theme_font_override("font", arch_mono_f)
	big_bar_lbl.add_theme_font_size_override("font_size", 12)
	big_bar_lbl.add_theme_color_override("font_color", Color(0.74, 0.77, 0.82, 0.92))
	big_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.add_child(big_bar_lbl)

	var big_stats := Label.new()
	big_stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_stats.offset_left = 24
	big_stats.offset_right = -24
	big_stats.offset_top = 44
	big_stats.offset_bottom = -58
	big_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	big_stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	big_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big_stats.add_theme_font_override("font", arch_mono_f)
	big_stats.add_theme_font_size_override("font_size", 15)
	big_stats.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
	big_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.add_child(big_stats)
	_ui["arch_stats_lbl"] = big_stats

	var big_footer := HBoxContainer.new()
	big_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	big_footer.offset_left = 24
	big_footer.offset_right = -24
	big_footer.offset_top = -48
	big_footer.offset_bottom = -14
	big_footer.add_theme_constant_override("separation", 12)
	big.add_child(big_footer)

	var btn_stat_spectate := Button.new()
	btn_stat_spectate.text = "[НАБЛЮДЕНИЕ]"
	btn_stat_spectate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_stat_spectate, Color(0.45, 0.85, 1.0), 13)
	btn_stat_spectate.pressed.connect(Callable(self, "_start_spectating"))
	big_footer.add_child(btn_stat_spectate)
	_ui["btn_stat_spectate"] = btn_stat_spectate

	# Corner terminal restart prompt (replaces bulky button inside report)
	var arch_restart_hint := Label.new()
	arch_restart_hint.name = "ArchRestartHint"
	arch_restart_hint.text = "> [R] НАЧАТЬ ЗАНОВО"
	arch_restart_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	arch_restart_hint.offset_left = -340
	arch_restart_hint.offset_top = -52
	arch_restart_hint.offset_right = -28
	arch_restart_hint.offset_bottom = -20
	arch_restart_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arch_restart_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arch_restart_hint.add_theme_font_override("font", arch_mono_f)
	arch_restart_hint.add_theme_font_size_override("font_size", 16)
	arch_restart_hint.add_theme_color_override("font_color", Color(0.28, 1.0, 0.42))
	arch_restart_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	arch_restart_hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arch_restart_hint.visible = false
	arch_restart_hint.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			call("_reset_run")
	)
	arch_overlay.add_child(arch_restart_hint)
	_ui["arch_restart_hint"] = arch_restart_hint

	# --- Small terminal (bottom-center) with player tag ---
	var small := Panel.new()
	small.anchor_left = 0.5
	small.anchor_right = 0.5
	small.anchor_top = 1.0
	small.anchor_bottom = 1.0
	small.offset_left = -222
	small.offset_right = 222
	small.offset_top = -140
	small.offset_bottom = -50
	small.add_theme_stylebox_override("panel", RoomsUI.make_cmd_window_style())
	small.visible = false
	arch_overlay.add_child(small)
	_ui["arch_window_small"] = small

	var small_bar := ColorRect.new()
	small_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	small_bar.offset_left = 1
	small_bar.offset_right = -1
	small_bar.offset_top = 1
	small_bar.offset_bottom = 25
	small_bar.color = Color(0.13, 0.14, 0.17, 1.0)
	small_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	small.add_child(small_bar)

	var small_bar_lbl := Label.new()
	small_bar_lbl.text = "C:\\Windows\\System32\\cmd.exe"
	small_bar_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	small_bar_lbl.offset_left = 10
	small_bar_lbl.offset_top = 1
	small_bar_lbl.offset_right = -10
	small_bar_lbl.offset_bottom = 25
	small_bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	small_bar_lbl.add_theme_font_override("font", arch_mono_f)
	small_bar_lbl.add_theme_font_size_override("font_size", 11)
	small_bar_lbl.add_theme_color_override("font_color", Color(0.70, 0.73, 0.78, 0.9))
	small_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	small.add_child(small_bar_lbl)

	var arch_player_lbl := Label.new()
	arch_player_lbl.text = "<< player >>"
	arch_player_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_player_lbl.offset_top = 25
	arch_player_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arch_player_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arch_player_lbl.add_theme_font_override("font", arch_mono_f)
	arch_player_lbl.add_theme_font_size_override("font_size", 15)
	arch_player_lbl.add_theme_color_override("font_color", Color(0.86, 0.87, 0.90))
	arch_player_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	small.add_child(arch_player_lbl)
	_ui["arch_player_lbl"] = arch_player_lbl

	var arch_silhouette := TextureRect.new()
	arch_silhouette.visible = false
	arch_overlay.add_child(arch_silhouette)
	_ui["arch_silhouette"] = arch_silhouette

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
	btn_spec_prev.text = "<< Назад"
	RoomsUI.style_button(btn_spec_prev, Color(0.45, 0.85, 1.0), 14)
	btn_spec_prev.pressed.connect(func() -> void: call("_cycle_spectate_target", -1))
	spec_bar.add_child(btn_spec_prev)

	var btn_spec_next := Button.new()
	btn_spec_next.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_spec_next.offset_left = -60
	btn_spec_next.offset_right = 80
	btn_spec_next.offset_top = -36
	btn_spec_next.offset_bottom = 0
	btn_spec_next.text = "Вперёд >>"
	RoomsUI.style_button(btn_spec_next, Color(0.45, 0.85, 1.0), 14)
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

	# --- Text chat (bottom-left; visible in all online states, read-only when dead)
	var chat_box := VBoxContainer.new()
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.offset_left = 18.0
	chat_box.offset_top = -206.0
	chat_box.offset_right = 420.0
	chat_box.offset_bottom = -52.0
	chat_box.add_theme_constant_override("separation", 4)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chat_box)
	_ui["chat_box"] = chat_box

	var chat_log := RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_active = false
	chat_log.scroll_following = true
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 13)
	chat_log.add_theme_color_override("default_color", Color(0.86, 0.89, 0.93, 0.94))
	chat_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	chat_log.add_theme_constant_override("outline_size", 3)
	var chat_log_panel := RoomsUI.make_panel_style(Color(0.0, 0.0, 0.0, 0.45), Color(1, 1, 1, 0.08), 4, 1)
	chat_log.add_theme_stylebox_override("normal", chat_log_panel)
	chat_log.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	chat_box.add_child(chat_log)
	_ui["chat_log"] = chat_log

	var chat_edit := LineEdit.new()
	chat_edit.visible = false
	chat_edit.placeholder_text = "сообщение...  (Enter — отправить, Esc — закрыть)"
	chat_edit.caret_blink = true
	chat_edit.max_length = 128
	chat_edit.add_theme_font_size_override("font_size", 13)
	chat_edit.add_theme_stylebox_override("normal", RoomsUI.make_panel_style(Color(0.03, 0.03, 0.035, 0.85), Color(1, 1, 1, 0.22), 3, 1))
	chat_edit.add_theme_stylebox_override("focus", RoomsUI.make_panel_style(Color(0.03, 0.03, 0.035, 0.9), Color(1, 1, 1, 0.4), 3, 1))
	chat_edit.text_submitted.connect(func(_txt: String) -> void: call("_chat_submit"))
	chat_box.add_child(chat_edit)
	_ui["chat_edit"] = chat_edit

	var chat_hint := Label.new()
	chat_hint.text = "T — чат · V — голос"
	chat_hint.add_theme_font_size_override("font_size", 11)
	chat_hint.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8, 0.55))
	chat_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	chat_hint.add_theme_constant_override("outline_size", 3)
	chat_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_box.add_child(chat_hint)
	_ui["chat_hint"] = chat_hint

	call("_build_startup_splash", root)


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
	_joy_ring.offset_right = 260
	_joy_ring.offset_top = -270
	_joy_ring.offset_bottom = -50
	_joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_ring.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.04, 0.07, 0.12, 0.24), Color(1.0, 1.0, 1.0, 0.34), 110, 2))
	_joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.65)
	mobile_group.add_child(_joy_ring)

	_joy_knob = Panel.new()
	_joy_knob.size = Vector2(84, 84)
	_joy_knob.position = Vector2(68, 68)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(1.0, 1.0, 1.0, 0.40), Color(1.0, 1.0, 1.0, 0.85), 42, 2))
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


func _build_startup_splash(root: Control) -> void:
	var splash := ColorRect.new()
	splash.name = "StartupSplash"
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.color = Color(0.0, 0.0, 0.0, 1.0)
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(splash)
	_ui["startup_splash"] = splash

	var lbl := Label.new()
	lbl.name = "SplashTitle"
	lbl.text = "r00ms"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 96)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0))
	lbl.modulate.a = 0.0
	splash.add_child(lbl)
	_ui["splash_title"] = lbl

	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(lbl, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(splash, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		splash.visible = false
		splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)

	splash.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if is_instance_valid(tw) and tw.is_running():
				tw.kill()
			splash.visible = false
			splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


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
	b_sprint.ring_color = Color(0.28, 0.62, 1.0, 1.0) if _mobile_sprint_held else Color(0.14, 0.44, 1.0, 0.95)
	b_sprint.queue_redraw()
	if _has_gummy:
		b_gummy.ring_color = Color(0.32, 1.0, 0.56, 1.0) if _active_tool == 1 else Color(0.22, 0.78, 0.44, 0.68)
		b_gummy.queue_redraw()


func _build_main_menu(root: Control) -> void:
	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu)
	_ui["main_menu"] = menu

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.008, 0.009, 0.013, 0.90)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(bg)
	_ui["menu_bg"] = bg

	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.material = RoomsUI.make_noise_material(0.55, 1.0)
	noise.color = Color(1.0, 1.0, 1.0, 1.0)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(noise)

	var head := Control.new()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.anchor_left = 0.0
	head.anchor_right = 1.0
	head.anchor_top = 0.0
	head.anchor_bottom = 0.0
	head.offset_top = 54
	head.offset_bottom = 238
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(head)

	var title := Label.new()
	title.text = "r00ms"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	_ui["menu_title"] = title

	var rule := ColorRect.new()
	rule.anchor_left = 0.33
	rule.anchor_right = 0.67
	rule.anchor_top = 1.0
	rule.anchor_bottom = 1.0
	rule.offset_left = 0
	rule.offset_right = 0
	rule.offset_top = -12
	rule.offset_bottom = -11
	rule.color = Color(1.0, 1.0, 1.0, 0.45)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	_ui["menu_rule"] = rule

	var slot := Control.new()
	slot.set_anchors_preset(Control.PRESET_CENTER)
	slot.offset_left = -260
	slot.offset_right = 260
	slot.offset_top = -20
	slot.offset_bottom = 300
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(slot)

	var make_view := func() -> VBoxContainer:
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(v)
		return v

	var make_item := func(parent: VBoxContainer, txt: String, cb: Callable, sz: int = 30) -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(0, 50)
		RoomsUI.style_link_button(b, sz, HORIZONTAL_ALIGNMENT_CENTER)
		b.pressed.connect(cb)
		parent.add_child(b)
		return b

	var v_main: VBoxContainer = make_view.call()
	var v_play: VBoxContainer = make_view.call()
	var v_multi: VBoxContainer = make_view.call()
	var v_credits: VBoxContainer = make_view.call()
	_ui["menu_view_main"] = v_main
	_ui["menu_view_play"] = v_play
	_ui["menu_view_multi"] = v_multi
	_ui["menu_view_credits"] = v_credits

	make_item.call(v_main, "start", func() -> void: _set_menu_view("play"), 34)
	make_item.call(v_main, "credits", func() -> void: _set_menu_view("credits"), 28)
	make_item.call(v_main, "settings", func() -> void: _open_menu_settings(), 28)

	make_item.call(v_play, "solo", func() -> void: _menu_begin_game(false, ""), 34)
	make_item.call(v_play, "multiplayer", func() -> void: _set_menu_view("multi"), 30)
	make_item.call(v_play, "back", func() -> void: _set_menu_view("main"), 22)

	make_item.call(v_multi, "invite steam friends", func() -> void: _menu_steam_invite(), 30)

	var btn_start_multi: Button = make_item.call(v_multi, "start", func() -> void: _menu_start_multiplayer(), 34)
	_ui["btn_start_multi"] = btn_start_multi

	var lbl_waiting_host := Label.new()
	lbl_waiting_host.text = "Waiting for host..."
	lbl_waiting_host.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_waiting_host.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lbl_waiting_host.add_theme_font_size_override("font_size", 20)
	lbl_waiting_host.add_theme_color_override("font_color", Color(0.80, 0.84, 0.92, 0.85))
	lbl_waiting_host.visible = false
	v_multi.add_child(lbl_waiting_host)
	_ui["lbl_waiting_host"] = lbl_waiting_host

	make_item.call(v_multi, "local network (host)", func() -> void:
		if _net != null:
			_net.host_enet(int(_rng.seed))
		call("_update_menu_players_list")
		var host_ip := _get_local_ip()
		var host_port := _net.ENET_PORT if _net != null else 27480
		_show_toast("Сервер запущен! Друг вводит адрес: %s:%d" % [host_ip, host_port], 5.0)
	, 30)

	# LAN IP display & Copy button
	var my_ip := _get_local_ip()
	var my_port := _net.ENET_PORT if _net != null else 27480
	var lan_info_lbl := Label.new()
	lan_info_lbl.text = "Ваш IP: %s:%d" % [my_ip, my_port]
	lan_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_info_lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lan_info_lbl.add_theme_font_size_override("font_size", 14)
	lan_info_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0, 0.95))
	v_multi.add_child(lan_info_lbl)

	var btn_copy_ip := Button.new()
	btn_copy_ip.text = "скопировать свой IP"
	btn_copy_ip.custom_minimum_size = Vector2(0, 32)
	RoomsUI.style_link_button(btn_copy_ip, 14, HORIZONTAL_ALIGNMENT_CENTER)
	btn_copy_ip.pressed.connect(func() -> void:
		DisplayServer.clipboard_set("%s:%d" % [_get_local_ip(), _net.ENET_PORT if _net != null else 27480])
		_show_toast("IP скопирован в буфер обмена!", 2.5)
	)
	v_multi.add_child(btn_copy_ip)

	# LAN join row: IP field + button
	var lan_join_row := HBoxContainer.new()
	lan_join_row.add_theme_constant_override("separation", 6)
	v_multi.add_child(lan_join_row)
	var lan_ip_edit := LineEdit.new()
	lan_ip_edit.placeholder_text = "%s:%d" % [my_ip, my_port]
	lan_ip_edit.text = ""
	lan_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_ip_edit.custom_minimum_size = Vector2(0, 44)
	lan_ip_edit.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lan_ip_edit.add_theme_font_size_override("font_size", 16)
	lan_join_row.add_child(lan_ip_edit)
	_ui["lan_ip_edit"] = lan_ip_edit
	var btn_lan_join_go := Button.new()
	btn_lan_join_go.text = "войти"
	btn_lan_join_go.custom_minimum_size = Vector2(80, 44)
	RoomsUI.style_link_button(btn_lan_join_go, 20)
	btn_lan_join_go.pressed.connect(func() -> void:
		var raw := lan_ip_edit.text.strip_edges()
		if raw.is_empty():
			raw = _get_local_ip()
		var ip := raw
		var port := _net.ENET_PORT if _net != null else 27480
		if ":" in raw:
			var parts := raw.split(":", false, 1)
			ip = parts[0]
			if parts.size() > 1 and parts[1].is_valid_int():
				port = int(parts[1])
		if _net != null:
			_net.join_enet(ip, port)
		call("_update_menu_players_list")
		_show_toast("Подключение к хосту...", 3.0)
	)
	lan_join_row.add_child(btn_lan_join_go)

	make_item.call(v_multi, "back", func() -> void: _set_menu_view("play"), 22)

	var menu_status := Label.new()
	menu_status.text = ""
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	menu_status.add_theme_font_size_override("font_size", 13)
	menu_status.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.9))
	v_multi.add_child(menu_status)
	_ui["menu_status"] = menu_status

	# Left: Modifiers panel (strictly visible only in multiplayer view)
	var menu_multi_mods := VBoxContainer.new()
	menu_multi_mods.name = "MenuMultiModifiers"
	menu_multi_mods.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	menu_multi_mods.offset_left = 60
	menu_multi_mods.offset_right = 360
	menu_multi_mods.offset_top = -140
	menu_multi_mods.offset_bottom = 260
	menu_multi_mods.add_theme_constant_override("separation", 8)
	menu_multi_mods.visible = false
	menu.add_child(menu_multi_mods)
	_ui["menu_multi_modifiers"] = menu_multi_mods

	var mods_hdr := Label.new()
	mods_hdr.text = "Modifiers"
	mods_hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	mods_hdr.add_theme_font_size_override("font_size", 30)
	mods_hdr.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	menu_multi_mods.add_child(mods_hdr)

	var mods_div := ColorRect.new()
	mods_div.custom_minimum_size = Vector2(140, 1)
	mods_div.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mods_div.color = Color(1.0, 1.0, 1.0, 0.3)
	menu_multi_mods.add_child(mods_div)

	var mod_defs := [
		{"key": "admin_panel", "name": "Admin Panel"},
		{"key": "wet_floor", "name": "Wet Floor"},
		{"key": "bad_time", "name": "Bad Time"},
		{"key": "make_haste", "name": "Make Haste"},
		{"key": "lights_out", "name": "Lights Out"},
		{"key": "sprint_fatigue", "name": "Sprint Fatigue"},
	]

	for m in mod_defs:
		var m_key: String = m["key"]
		var m_name: String = m["name"]
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_NONE

		var update_btn_text := func() -> void:
			var active: bool = bool(_active_modifiers.get(m_key, false))
			var check_mark := "[X] " if active else "[ ] "
			btn.text = check_mark + m_name
			if active:
				btn.add_theme_color_override("font_color", Color(0.28, 1.0, 0.42))
				btn.add_theme_color_override("font_hover_color", Color(0.45, 1.0, 0.58))
			else:
				btn.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
				btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

		btn.set_meta("mod_name", m_name)
		btn.set_meta("mod_update_fn", update_btn_text)
		_ui["menu_mod_btn_" + m_key] = btn
		update_btn_text.call()
		RoomsUI.style_link_button(btn, 18, HORIZONTAL_ALIGNMENT_LEFT)
		btn.pressed.connect(func() -> void:
			if _state != State.MENU:
				_show_toast("Модификаторы настраиваются только до начала игры!", 2.0)
				return
			if _net != null and _net.is_online() and not _net.is_host:
				_show_toast("Модификаторы может изменять только хост!", 2.0)
				return
			var cur_v: bool = bool(_active_modifiers.get(m_key, false))
			_active_modifiers[m_key] = not cur_v
			update_btn_text.call()
			if m_key == "admin_panel" and cur_v:
				_reset_admin_cheats()
			if _net != null and _net.is_online() and _net.is_host:
				_net.broadcast_entity_event({"k": "mods_update", "mods": _active_modifiers})
			var status_str := "ВКЛЮЧЕН" if not cur_v else "ВЫКЛЮЧЕН"
			_show_toast("%s: %s" % [m_name, status_str], 1.8)
		)
		menu_multi_mods.add_child(btn)

	# Right: Lobby Players List (strictly visible only in multiplayer view)
	var menu_multi_players := VBoxContainer.new()
	menu_multi_players.name = "MenuMultiPlayers"
	menu_multi_players.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu_multi_players.offset_left = -360
	menu_multi_players.offset_right = -60
	menu_multi_players.offset_top = -140
	menu_multi_players.offset_bottom = 260
	menu_multi_players.add_theme_constant_override("separation", 8)
	menu_multi_players.visible = false
	menu.add_child(menu_multi_players)
	_ui["menu_multi_players"] = menu_multi_players

	var plyr_hdr := Label.new()
	plyr_hdr.text = "Players"
	plyr_hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	plyr_hdr.add_theme_font_size_override("font_size", 30)
	plyr_hdr.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	menu_multi_players.add_child(plyr_hdr)

	var plyr_div := ColorRect.new()
	plyr_div.custom_minimum_size = Vector2(140, 1)
	plyr_div.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plyr_div.color = Color(1.0, 1.0, 1.0, 0.3)
	menu_multi_players.add_child(plyr_div)

	var menu_players := Label.new()
	menu_players.text = "• вы (ожидание подключения)"
	menu_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	menu_players.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_players.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	menu_players.add_theme_font_size_override("font_size", 16)
	menu_players.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86, 0.9))
	menu_multi_players.add_child(menu_players)
	_ui["menu_players"] = menu_players
	if _net != null:
		_net.members_changed.connect(func() -> void: call("_update_menu_players_list"))

	var cred_lbl := Label.new()
	cred_lbl.text = "r00ms\n\nminimal horror, section A\n\nMonsters: A-60 · A-90 · A-120\nThe Darkness\n\nmade by the r00ms team\n\nsprites, sounds and caffeine"
	cred_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cred_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cred_lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	cred_lbl.add_theme_font_size_override("font_size", 16)
	cred_lbl.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90, 0.92))
	v_credits.add_child(cred_lbl)
	make_item.call(v_credits, "back", func() -> void: _set_menu_view("main"), 22)

	var btn_quit := Button.new()
	btn_quit.text = "exit"
	btn_quit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_quit.offset_left = -140
	btn_quit.offset_right = 140
	btn_quit.offset_top = -104
	btn_quit.offset_bottom = -52
	RoomsUI.style_link_button(btn_quit, 26, HORIZONTAL_ALIGNMENT_CENTER)
	btn_quit.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(btn_quit)
	_ui["menu_exit"] = btn_quit

	_set_menu_view("main", false)


func _set_menu_view(view: String, fade: bool = true) -> void:
	if not _ui.has("main_menu"):
		return
	_menu_view = view
	var views := {
		"main": _ui.get("menu_view_main"),
		"play": _ui.get("menu_view_play"),
		"multi": _ui.get("menu_view_multi"),
		"credits": _ui.get("menu_view_credits"),
	}
	for k in views.keys():
		var c := views[k] as Control
		if c != null:
			c.visible = (String(k) == view)
	var cur := views.get(view) as Control
	if cur != null and fade:
		cur.modulate.a = 0.0
		create_tween().tween_property(cur, "modulate:a", 1.0, 0.22)

	var is_multi := (view == "multi")
	var show_mods := (view == "multi" or view == "play")

	if _ui.has("menu_exit"):
		var exit_btn := _ui["menu_exit"] as Control
		exit_btn.visible = (view == "main")

	if _ui.has("menu_multi_modifiers"):
		var mm := _ui["menu_multi_modifiers"] as Control
		mm.visible = show_mods
		if show_mods and fade:
			mm.modulate.a = 0.0
			create_tween().tween_property(mm, "modulate:a", 1.0, 0.22)
	if _ui.has("menu_multi_players"):
		var mp := _ui["menu_multi_players"] as Control
		mp.visible = is_multi
		if is_multi and fade:
			mp.modulate.a = 0.0
			create_tween().tween_property(mp, "modulate:a", 1.0, 0.22)

	if is_multi:
		call("_update_menu_players_list")


func _update_menu_players_list() -> void:
	if not _ui.has("menu_players"):
		return
	var is_client := (_net != null and _net.is_online() and not _net.is_host)
	if _ui.has("btn_start_multi"):
		(_ui["btn_start_multi"] as Control).visible = not is_client
	if _ui.has("lbl_waiting_host"):
		(_ui["lbl_waiting_host"] as Control).visible = is_client

	var lbl := _ui["menu_players"] as Label
	if _net == null or not _net.is_online():
		lbl.text = "• вы (ожидание подключения)"
		return
	var names: Array[String] = _net.get_member_names()
	if names.is_empty():
		lbl.text = "• вы"
	else:
		var lines: Array[String] = []
		for n in names:
			lines.append("• " + n)
		lbl.text = "\n".join(lines)


# --- Text chat ---------------------------------------------------------------
func _chat_toggle(open: bool) -> void:
	_chat_open = open
	var edit := _ui.get("chat_edit") as LineEdit
	if edit != null:
		edit.visible = open
		edit.editable = not _chat_readonly
		if open:
			edit.clear()
			edit.grab_focus()
		else:
			edit.clear()
			edit.release_focus()


func _chat_submit() -> void:
	if not _chat_open:
		return
	var edit := _ui.get("chat_edit") as LineEdit
	var txt := edit.text.strip_edges() if edit != null else ""
	call("_chat_toggle", false)
	if txt.is_empty() or _chat_readonly or _net == null or not _net.is_online():
		return
	call("_chat_append", String(call("_get_local_username")), txt)
	_net.send_chat(txt)


func _chat_append(who: String, text: String) -> void:
	var log := _ui.get("chat_log") as RichTextLabel
	if log == null:
		return
	log.append_text("[color=#7fd4ff]%s[/color]: %s\n" % [who, text])
	if log.text.length() > 6000:
		log.text = log.text.substr(log.text.length() - 3000)


func _chat_set_readonly(ro: bool) -> void:
	_chat_readonly = ro
	var edit := _ui.get("chat_edit") as LineEdit
	if edit != null:
		edit.editable = not ro
	if ro and _chat_open:
		call("_chat_toggle", false)
	var hint := _ui.get("chat_hint") as Label
	if hint != null:
		hint.text = "режим наблюдателя: чат только для чтения" if ro else "T — чат · V — голос"


func _show_main_menu(fresh: bool = false) -> void:
	if not _ui.has("main_menu"):
		return
	var menu := _ui["main_menu"] as Control
	menu.visible = true
	menu.modulate.a = 1.0
	_set_menu_view("main", false)
	if not fresh:
		for k in ["menu_view_main", "menu_view_play", "menu_view_multi", "menu_view_credits"]:
			var c := _ui.get(k) as Control
			if c != null:
				c.modulate.a = 0.0 if String(k) != "menu_view_main" else 1.0
		return
	# Launch sequence: darkness -> title -> links glow in
	var bg := _ui["menu_bg"] as ColorRect
	var title := _ui["menu_title"] as Control
	var rule := _ui["menu_rule"] as Control
	var v_main := _ui["menu_view_main"] as Control
	var exit_btn := _ui.get("menu_exit") as Control
	var v_other: Array[Control] = []
	for k in ["menu_view_play", "menu_view_multi", "menu_view_credits"]:
		var c := _ui.get(k) as Control
		if c != null:
			c.modulate.a = 0.0
			v_other.append(c)
	bg.color.a = 0.0
	title.modulate.a = 0.0
	rule.modulate.a = 0.0
	v_main.modulate.a = 0.0
	if exit_btn != null:
		exit_btn.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg, "color:a", 0.90, 0.95)
	tw.tween_property(title, "modulate:a", 1.0, 0.90).set_delay(0.18)
	tw.tween_property(rule, "modulate:a", 1.0, 0.70).set_delay(0.80)
	tw.tween_property(v_main, "modulate:a", 1.0, 0.70).set_delay(1.10)
	if exit_btn != null:
		tw.tween_property(exit_btn, "modulate:a", 1.0, 0.60).set_delay(1.30)


func _open_menu_settings() -> void:
	_settings_from_menu = true
	if _ui.has("main_menu"):
		(_ui["main_menu"] as Control).visible = false
	if _ui.has("modal"):
		var modal := _ui["modal"] as Control
		modal.visible = true
		modal.modulate.a = 0.0
		create_tween().tween_property(modal, "modulate:a", 1.0, 0.24)
	_open_settings_panel(true)


func _menu_start_multiplayer() -> void:
	if _net != null and _net.is_online():
		if not _net.is_host:
			_show_toast("Только хост может запустить игру!", 2.0)
			return
		_net.broadcast_entity_event({
			"k": "start_game",
			"seed": _world_seed,
			"mods": _active_modifiers
		})
	_menu_begin_game(true, "")


func _update_menu_modifiers_ui() -> void:
	var mod_keys: Array[String] = ["admin_panel", "wet_floor", "bad_time", "make_haste", "lights_out", "sprint_fatigue"]
	for k in mod_keys:
		var b_key: String = "menu_mod_btn_" + k
		if _ui.has(b_key):
			var b := _ui[b_key] as Button
			var upd_fn = b.get_meta("mod_update_fn", null)
			if upd_fn is Callable and (upd_fn as Callable).is_valid():
				(upd_fn as Callable).call()


func _menu_quick_multiplayer() -> void:
	if _net == null:
		return
	var status := _ui.get("menu_status") as Label
	if status != null:
		status.text = "searching rooms..."
	var res: Dictionary = await _net.quick_join_or_host()
	if not bool(res.get("ok", false)):
		if status != null:
			status.text = String(res.get("msg", ""))
		return
	if status != null:
		status.text = ""
	_show_toast(String(res.get("msg", "")), 3.5)
	_menu_begin_game(true, "")


## Returns the LAN IP of this machine, prioritizing real adapters (Wi-Fi/Ethernet) and filtering out virtual ones.
func _get_local_ip() -> String:
	var fallback := "127.0.0.1"
	for iface in IP.get_local_interfaces():
		var friendly: String = String(iface.get("friendly", "")).to_lower()
		if "vmware" in friendly or "virtual" in friendly or "vbox" in friendly or "bluetooth" in friendly or "loopback" in friendly:
			continue
		var addrs: Array = iface.get("addresses", [])
		for a in addrs:
			var addr := String(a)
			if addr.contains(".") and not addr.begins_with("127.") and not addr.begins_with("169.254."):
				if "wi-fi" in friendly or "беспроводная" in friendly or "ethernet" in friendly or "сеть" in friendly:
					return addr
				if fallback == "127.0.0.1":
					fallback = addr
	if fallback != "127.0.0.1":
		return fallback
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168."):
			return addr
	for addr in IP.get_local_addresses():
		if addr.begins_with("10.") or addr.begins_with("172.") or addr.begins_with("26.") or addr.begins_with("25."):
			return addr
	return "127.0.0.1"


## Invite Steam friends: creates lobby, opens overlay — does NOT start the game.
## The host starts the game by pressing Solo/Start separately.
func _menu_steam_invite() -> void:
	if _net == null:
		return
	var mstatus := _ui.get("menu_status") as Label
	if mstatus != null:
		mstatus.text = "создаём лобби..."
	var res: Dictionary = await _net.ensure_steam_lobby(int(_rng.seed), _highest_opened)
	if not bool(res.get("ok", false)):
		if mstatus != null:
			mstatus.text = String(res.get("msg", "Не удалось создать лобби"))
		return
	_net.open_invite_overlay_now()
	if mstatus != null:
		mstatus.text = "лобби создано — пригласи друзей (Shift+Tab)"
	_show_toast("Лобби создано. Нажми «start» когда все зайдут, чтобы начать.", 4.0)


func _menu_begin_game(multiplayer: bool = false, mode: String = "") -> void:
	if not bool(_active_modifiers.get("admin_panel", false)):
		_reset_admin_cheats()
	if multiplayer and _net != null:
		if mode == "lan":
			_net.host_enet(int(_rng.seed))
	if bool(_active_modifiers.get("make_haste", false)):
		_haste_timer = 60.0
	if bool(_active_modifiers.get("lights_out", false)):
		call("_trigger_power_outage")

	var menu := _ui.get("main_menu") as Control
	if menu == null:
		call("_set_state", State.PLAYING)
		return
	if not menu.visible:
		call("_set_state", State.PLAYING)
		return
	var tw := create_tween()
	tw.tween_property(menu, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func() -> void:
		menu.visible = false
		menu.modulate.a = 1.0
		call("_set_state", State.PLAYING)
	)


func _can_use_admin() -> bool:
	if not bool(_active_modifiers.get("admin_panel", false)):
		return false
	if _net == null or not _net.is_online():
		return true
	return _net.is_host or _admin_granted_by_host


func _toggle_admin_panel() -> void:
	if not _can_use_admin():
		_show_toast("Панель администратора доступна только хосту!", 2.0)
		return
	if _state == State.PLAYING:
		call("_set_state", State.PAUSED)
		_open_admin_panel(true)
	elif _state == State.PAUSED:
		var adm_vis: bool = _ui.has("m_admin_scroll") and (_ui["m_admin_scroll"] as Control).visible
		_open_admin_panel(not adm_vis)


func _update_pause_modifiers_ui() -> void:
	if _ui.has("btn_pause_admin"):
		var can_adm: bool = bool(_active_modifiers.get("admin_panel", false)) and _can_use_admin()
		(_ui["btn_pause_admin"] as Control).visible = can_adm
	if _ui.has("m_mods_list"):
		var lines: Array[String] = []
		var mod_names := {
			"admin_panel": "admin panel",
			"wet_floor": "wet floor",
			"bad_time": "bad time",
			"make_haste": "make haste",
			"lights_out": "lights out",
			"sprint_fatigue": "sprint fatigue",
		}
		for k in mod_names.keys():
			if bool(_active_modifiers.get(k, false)):
				lines.append("• " + mod_names[k])
		var lbl := _ui["m_mods_list"] as Label
		if lines.is_empty():
			lbl.text = "• none (default)"
		else:
			lbl.text = "\n".join(lines)


func _update_admin_buttons_ui() -> void:
	if _ui.has("adm_btn_god"):
		var b := _ui["adm_btn_god"] as Button
		b.text = "god mode: %s" % ("on" if _admin_god_mode else "off")
		b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if _admin_god_mode else Color(0.85, 0.88, 0.94))
	if _ui.has("adm_btn_stamina"):
		var b := _ui["adm_btn_stamina"] as Button
		b.text = "infinite stamina: %s" % ("on" if _admin_inf_stamina else "off")
		b.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if _admin_inf_stamina else Color(0.85, 0.88, 0.94))
	if _ui.has("adm_btn_noclip"):
		var b := _ui["adm_btn_noclip"] as Button
		b.text = "noclip / fly: %s" % ("on" if _admin_noclip else "off")
		b.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8) if _admin_noclip else Color(0.85, 0.88, 0.94))
	if _ui.has("adm_btn_speed"):
		var b := _ui["adm_btn_speed"] as Button
		b.text = "speed boost: %.1fx" % _admin_speed_mult
		b.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if _admin_speed_mult > 1.0 else Color(0.85, 0.88, 0.94))
	if _ui.has("adm_btn_battery"):
		var b := _ui["adm_btn_battery"] as Button
		b.text = "infinite battery: %s" % ("on" if _admin_inf_battery else "off")
		b.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5) if _admin_inf_battery else Color(0.85, 0.88, 0.94))
	if _ui.has("adm_btn_timescale"):
		var b := _ui["adm_btn_timescale"] as Button
		b.text = "game speed: %.1fx" % Engine.time_scale
		b.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))


func _reset_admin_cheats() -> void:
	_admin_god_mode = false
	_admin_inf_stamina = false
	_admin_noclip = false
	_admin_speed_mult = 1.0
	_admin_inf_battery = false
	_admin_cheats_used = false
	Engine.time_scale = 1.0
	if is_instance_valid(player_col):
		player_col.disabled = false
	_update_admin_buttons_ui()
