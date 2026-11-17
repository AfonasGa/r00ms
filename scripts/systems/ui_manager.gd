class_name UIManager
extends Node

## Modular UI controller for HUD, Main Menu, Modifiers, Pause, Settings,
## Admin Panel, Architect Death Screen, Spectator Bar, Chat, Mobile Touch UI, and FaceEditor.

var game: Node3D = null
var ui_layer: CanvasLayer = null
var settings: SettingsManager = null
var admin: AdminController = null
var room_mgr: RoomManager = null
var player_ctrl: PlayerController = null
var interact_ctrl: InteractionController = null
var entities: EntityDirector = null
var avatar_mgr: AvatarManager = null
var audio: RoomsAudio = null
var net: RoomsNet = null

var ui: Dictionary = {}
var face_editor: FaceEditor = null
var lobby_list_box: VBoxContainer = null
var reticle_ring: RoomsUI.ReticleRing = null
var reticle_screen_pos := Vector2.ZERO
var reticle_lag_offset := Vector2.ZERO
var reticle_radius := 6.5

var toast_timer := 0.0
var toast_alpha := 0.0
var prompt_alpha := 0.0
var menu_view := "main"
var settings_from_menu := false
var chat_open := false
var chat_readonly := false
var disclaimer_active := false
var _disclaimer_dismiss_cb: Callable = Callable()
var lan_servers_box: VBoxContainer = null

# Mobile controls
var joy_ring: Panel = null
var joy_knob: Panel = null
var mobile_btns: Array[Control] = []

# Cached shader uniform values to avoid redundant GPU uploads every physics tick
var _last_vitals: Vector4 = Vector4(-1.0, -1.0, -1.0, -1.0)
var _last_haste_sec := -1


func initialize(
	p_game: Node3D,
	p_ui_layer: CanvasLayer,
	p_settings: SettingsManager,
	p_admin: AdminController,
	p_room_mgr: RoomManager,
	p_player_ctrl: PlayerController,
	p_interact_ctrl: InteractionController,
	p_entities: EntityDirector,
	p_avatar_mgr: AvatarManager,
	p_audio: RoomsAudio,
	p_net: RoomsNet
) -> void:
	game = p_game
	ui_layer = p_ui_layer
	settings = p_settings
	admin = p_admin
	room_mgr = p_room_mgr
	player_ctrl = p_player_ctrl
	interact_ctrl = p_interact_ctrl
	entities = p_entities
	avatar_mgr = p_avatar_mgr
	audio = p_audio
	net = p_net
	_build_all_ui()


func get_node_ref(key: String) -> Control:
	return ui.get(key) as Control


func show_toast(msg: String, duration: float = 2.8) -> void:
	var lbl := ui.get("toast_lbl") as Label
	if lbl == null:
		return
	if not lbl.visible or lbl.text != msg:
		toast_alpha = 0.0
		lbl.modulate.a = 0.0
	lbl.text = msg
	lbl.visible = true
	toast_timer = maxf(duration, 1.1)


func flash_damage(col: Color) -> void:
	var dmg := ui.get("dmg_flash") as ColorRect
	if dmg != null:
		dmg.color = col
		dmg.visible = true


func hide_locker_mask() -> void:
	var mask := ui.get("locker_mask") as ColorRect
	if mask != null:
		mask.color = Color(0.0, 0.0, 0.0, 0.0)
		mask.visible = false


func clear_all_vignettes() -> void:
	if ui.has("vitals_mat"):
		var vmat := ui["vitals_mat"] as ShaderMaterial
		for k in ["hp_loss", "stam_loss", "exhausted_amt", "darkness_amt"]:
			vmat.set_shader_parameter(k, 0.0)
	_last_vitals = Vector4.ZERO
	if ui.has("vitals_rect"):
		(ui["vitals_rect"] as Control).visible = false
	if ui.has("darkness_rect"):
		var dkr := ui["darkness_rect"] as Control
		dkr.visible = false
		dkr.modulate.a = 0.0
	if ui.has("static_mat"):
		var smat := ui["static_mat"] as ShaderMaterial
		smat.set_shader_parameter("static_amt", 0.0)
		smat.set_shader_parameter("vig_amt", 0.0)
	if ui.has("static_rect"):
		(ui["static_rect"] as Control).visible = false
	hide_locker_mask()
	if ui.has("dmg_flash"):
		var df := ui["dmg_flash"] as ColorRect
		df.color.a = 0.0
		df.visible = false
	if ui.has("a075_flash_mat"):
		var amat := ui["a075_flash_mat"] as ShaderMaterial
		amat.set_shader_parameter("flash_amt", 0.0)
		amat.set_shader_parameter("warn_amt", 0.0)
		amat.set_shader_parameter("blind_burn", 0.0)
	for vk in ["a90_root", "a90_stop_icon", "a90_scare_rect", "a60_scare_rect", "a075_flash_rect"]:
		if ui.has(vk):
			(ui[vk] as Control).visible = false


func _build_all_ui() -> void:
	var root := Control.new()
	root.name = "UIRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	_build_overlays_and_hud(root)
	_build_a90_ui(root)
	_build_main_menu(root)
	_build_pause_and_panels(root)
	_build_architect_and_spectate(root)
	_build_chat(root)

	# In-game dummi Face Editor overlay
	face_editor = FaceEditor.new()
	face_editor.name = "DummiFaceEditor"
	face_editor.face_saved.connect(func(_img: Image, png_bytes: PackedByteArray) -> void:
		if net != null:
			net.set_local_face_bytes(png_bytes)
		show_toast(RoomsI18n.t("toast_face_saved"), 2.4)
	)
	face_editor.closed.connect(func() -> void:
		if ui.has("main_menu"):
			(ui["main_menu"] as Control).visible = true
	)
	root.add_child(face_editor)
	if net != null:
		net.set_local_face_bytes(face_editor.get_current_png_bytes())

	_build_startup_splash(root)
	apply_localization()


func _build_overlays_and_hud(root: Control) -> void:
	var locker_mask := ColorRect.new()
	locker_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	locker_mask.color = Color(0.0, 0.0, 0.0, 0.0)
	locker_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locker_mask.visible = false
	root.add_child(locker_mask)
	ui["locker_mask"] = locker_mask

	var dmg_flash := ColorRect.new()
	dmg_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_flash.color = Color(0.85, 0.05, 0.05, 0.0)
	dmg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg_flash.visible = false
	root.add_child(dmg_flash)
	ui["dmg_flash"] = dmg_flash

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
	if (shrink_amt >= 0.985) { black_mask = 1.0; }
	vec3 col = mix(vec3(0.0), vec3(0.82, 0.03, 0.03), red_amt * (1.0 - black_mask * 0.65));
	COLOR = vec4(col, clamp(max(black_mask, red_amt), 0.0, 1.0));
}"""
	var iris_mat := ShaderMaterial.new()
	iris_mat.shader = iris_sh
	var death_iris := ColorRect.new()
	death_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_iris.material = iris_mat
	death_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_iris.visible = false
	root.add_child(death_iris)
	ui["death_iris"] = death_iris
	ui["death_iris_mat"] = iris_mat

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
	COLOR = vec4(col, clamp(vig * 0.82 + grain + scan * static_amt * 0.22, 0.0, 0.92));
}"""
	var static_mat := ShaderMaterial.new()
	static_mat.shader = static_sh
	var static_rect := ColorRect.new()
	static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_rect.material = static_mat
	static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_rect.visible = false
	root.add_child(static_rect)
	ui["static_rect"] = static_rect
	ui["static_mat"] = static_mat

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
	ui["a60_scare_rect"] = a60_scare_rect

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
	COLOR = vec4(col, clamp((0.34 + 0.36 * vig + 0.26 * grain + scan), 0.0, 1.0) * amt);
}"""
	var warp_mat := ShaderMaterial.new()
	warp_mat.shader = warp_sh
	var warp_rect := ColorRect.new()
	warp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	warp_rect.material = warp_mat
	warp_rect.color = Color.WHITE
	warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warp_rect.visible = false
	root.add_child(warp_rect)
	ui["warp_rect"] = warp_rect
	ui["warp_mat"] = warp_mat

	# A-075 ("Shutter") photo flash-blindness + seared negative afterimage + death blindness overlay
	var a075_sh := Shader.new()
	a075_sh.code = """shader_type canvas_item;
uniform float flash_amt : hint_range(0.0, 1.0) = 0.0;
uniform float warn_amt : hint_range(0.0, 1.0) = 0.0;
uniform float blind_burn : hint_range(0.0, 1.0) = 0.0;
float hash12(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}
void fragment() {
	vec2 uv = UV;
	vec2 c = (uv - 0.5) * vec2(1.45, 1.0);
	float r = length(c);
	float n = hash12(floor(uv * vec2(480.0, 270.0)) + fract(TIME * 43.0) * 31.0);
	float flash_core = pow(flash_amt, 1.8) * 0.98;
	float afterimage = smoothstep(0.18, 0.95, r) * flash_amt * 0.55 + n * flash_amt * 0.24;
	float warn_vig = smoothstep(0.32, 0.96, r) * warn_amt * 0.65;
	vec3 flash_col = mix(vec3(0.95, 0.80, 0.52), vec3(1.0, 0.99, 0.95), flash_amt);
	vec3 warn_col = vec3(1.0, 0.66, 0.16);
	float f_a = clamp(flash_core + afterimage, 0.0, 0.98);
	float w_a = clamp(warn_vig, 0.0, 0.75);
	vec3 col = mix(warn_col, flash_col, clamp(f_a / max(f_a + w_a, 0.001), 0.0, 1.0));
	float alpha = clamp(max(f_a, w_a), 0.0, 0.98);
	if (blind_burn > 0.001) {
		// Seared shutter aperture ring + retinal burnout fading from blinding white to dead black
		float ring = exp(-pow((r - (0.24 - blind_burn * 0.08)) / 0.042, 2.0));
		float inner_spot = smoothstep(0.26, 0.0, r) * smoothstep(0.15, 0.72, blind_burn);
		float dark_phase = smoothstep(0.42, 0.96, blind_burn);
		vec3 burn_col = mix(vec3(1.0, 0.99, 0.94), vec3(0.02, 0.015, 0.02), dark_phase);
		// Seared amber-cyan negative afterimage glows briefly against the creeping blindness
		vec3 seared_ring = mix(vec3(1.0, 0.72, 0.24), vec3(0.35, 0.85, 1.0), smoothstep(0.3, 0.8, blind_burn));
		burn_col += seared_ring * ring * (1.0 - smoothstep(0.75, 1.0, blind_burn)) * 0.85;
		burn_col *= (1.0 - inner_spot * 0.82);
		burn_col += (n - 0.5) * 0.14 * (1.0 - dark_phase * 0.8);
		col = mix(col, clamp(burn_col, 0.0, 1.0), smoothstep(0.0, 0.25, blind_burn));
		alpha = max(alpha, smoothstep(0.0, 0.12, blind_burn));
	}
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}"""
	var a075_mat := ShaderMaterial.new()
	a075_mat.shader = a075_sh
	var a075_rect := ColorRect.new()
	a075_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	a075_rect.material = a075_mat
	a075_rect.color = Color.WHITE
	a075_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a075_rect.visible = false
	root.add_child(a075_rect)
	ui["a075_flash_rect"] = a075_rect
	ui["a075_flash_mat"] = a075_mat

	var hud_group := Control.new()
	hud_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_group)
	ui["hud_group"] = hud_group

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
	float red_a = smoothstep(0.68 - red_drive * 0.36, 0.96, dist) * red_drive * 0.84;
	float st_trigger = max(clamp((stam_loss - 0.04) / 0.96, 0.0, 1.0), exhausted_amt);
	float st_a = smoothstep(0.74 - st_trigger * 0.34 - exhausted_amt * 0.06, 0.97, dist) * st_trigger * (0.68 + 0.24 * exhausted_amt);
	float total_a = clamp(red_a + st_a * 0.85, 0.0, 0.90);
	vec3 blood_col = vec3(0.88, 0.04, 0.04);
	vec3 sprint_col = mix(vec3(0.08, 0.42, 0.98), vec3(0.22, 0.65, 1.0), 0.35 + 0.65 * exhausted_amt);
	float w_red = red_a / (red_a + st_a + 0.0001);
	COLOR = vec4(mix(sprint_col, blood_col, clamp(w_red * 1.35, 0.0, 1.0)), total_a);
}"""
	var vitals_mat := ShaderMaterial.new()
	vitals_mat.shader = vitals_sh
	var vitals_rect := ColorRect.new()
	vitals_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vitals_rect.material = vitals_mat
	vitals_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_rect.visible = false
	hud_group.add_child(vitals_rect)
	ui["vitals_rect"] = vitals_rect
	ui["vitals_mat"] = vitals_mat

	var darkness_rect := TextureRect.new()
	darkness_rect.set_anchors_preset(Control.PRESET_CENTER)
	darkness_rect.offset_left = -220
	darkness_rect.offset_top = -125
	darkness_rect.offset_right = 220
	darkness_rect.offset_bottom = 125
	darkness_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	darkness_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	darkness_rect.texture = entities.darkness_tex
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	darkness_rect.material = add_mat
	darkness_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	darkness_rect.visible = false
	darkness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(darkness_rect)
	ui["darkness_rect"] = darkness_rect

	reticle_ring = RoomsUI.ReticleRing.new()
	reticle_ring.ring_radius = 6.5
	reticle_ring.stroke_width = 1.9
	reticle_screen_pos = get_viewport().get_visible_rect().size * 0.5
	reticle_ring.position = reticle_screen_pos - reticle_ring.size * 0.5
	hud_group.add_child(reticle_ring)
	ui["reticle_ring"] = reticle_ring

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
	prompt_wrap.add_child(prompt_lbl)
	ui["prompt_lbl"] = prompt_lbl

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
	toast_lbl.modulate.a = 0.0
	toast_lbl.visible = false
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(toast_lbl)
	ui["toast"] = toast_lbl
	ui["toast_lbl"] = toast_lbl

	var haste_lbl := Label.new()
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
	ui["haste_lbl"] = haste_lbl

	_build_mobile_ui(hud_group)


func _build_a90_ui(root: Control) -> void:
	var a90_root := Control.new()
	a90_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_root.visible = false
	root.add_child(a90_root)
	ui["a90_root"] = a90_root

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
	vec3 col = mix(vec3(0.16, 0.0, 0.0), vec3(1.0, 0.10, 0.06), vig * 0.55);
	COLOR = vec4(col, clamp(vig * 0.72 + n * static_amt * 0.30 + scan * static_amt * 0.10, 0.0, 0.86));
}"""
	var a90_mat := ShaderMaterial.new()
	a90_mat.shader = a90_sh
	var a90_bg := ColorRect.new()
	a90_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_bg.material = a90_mat
	a90_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_root.add_child(a90_bg)
	ui["a90_mat"] = a90_mat

	var a90_sign_box := Control.new()
	a90_sign_box.set_anchors_preset(Control.PRESET_CENTER)
	a90_sign_box.offset_left = -90
	a90_sign_box.offset_top = -90
	a90_sign_box.offset_right = 90
	a90_sign_box.offset_bottom = 90
	a90_sign_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_root.add_child(a90_sign_box)

	var a90_shake := Control.new()
	a90_shake.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_shake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_sign_box.add_child(a90_shake)
	ui["a90_shake"] = a90_shake

	var a90_rect := TextureRect.new()
	a90_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_rect.texture = entities.a90_textures.get("warn")
	a90_shake.add_child(a90_rect)
	ui["a90_rect"] = a90_rect

	var a90_icon_center := CenterContainer.new()
	a90_icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	a90_icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_shake.add_child(a90_icon_center)

	var a90_stop_icon := TextureRect.new()
	a90_stop_icon.custom_minimum_size = Vector2(180, 180)
	a90_stop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_stop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_stop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_stop_icon.texture = entities.a90_textures.get("stopsign")
	a90_icon_center.add_child(a90_stop_icon)
	ui["a90_stop_icon"] = a90_stop_icon

	var a90_scare_rect := TextureRect.new()
	a90_scare_rect.set_anchors_preset(Control.PRESET_CENTER)
	a90_scare_rect.offset_left = -90
	a90_scare_rect.offset_top = -90
	a90_scare_rect.offset_right = 90
	a90_scare_rect.offset_bottom = 90
	a90_scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_scare_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_scare_rect.visible = false
	a90_scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a90_scare_rect.texture = entities.a90_textures.get("rage")
	root.add_child(a90_scare_rect)
	ui["a90_scare_rect"] = a90_scare_rect


func _build_main_menu(root: Control) -> void:
	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu)
	ui["main_menu"] = menu

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.008, 0.009, 0.013, 0.90)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(bg)
	ui["menu_bg"] = bg

	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.material = RoomsUI.make_noise_material(0.55, 1.0)
	noise.color = Color.WHITE
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(noise)

	var head := Control.new()
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
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
	ui["menu_title"] = title

	var rule := ColorRect.new()
	rule.anchor_left = 0.33
	rule.anchor_right = 0.67
	rule.anchor_top = 1.0
	rule.anchor_bottom = 1.0
	rule.offset_top = -12
	rule.offset_bottom = -11
	rule.color = Color(1.0, 1.0, 1.0, 0.45)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	ui["menu_rule"] = rule

	var slot := Control.new()
	slot.set_anchors_preset(Control.PRESET_CENTER)
	slot.offset_left = -260
	slot.offset_right = 260
	slot.offset_top = -20
	slot.offset_bottom = 320
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(slot)

	var make_view := func() -> VBoxContainer:
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 4)
		slot.add_child(v)
		return v

	var make_item := func(parent: VBoxContainer, txt: String, cb: Callable, sz: int = 30, ui_key: String = "") -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(0, 46)
		RoomsUI.style_link_button(b, sz, HORIZONTAL_ALIGNMENT_CENTER)
		b.pressed.connect(cb)
		b.mouse_entered.connect(func() -> void:
			var tw := create_tween()
			tw.tween_property(b, "modulate", Color(1.12, 1.14, 1.20, 1.0), 0.12)
		)
		b.mouse_exited.connect(func() -> void:
			var tw := create_tween()
			tw.tween_property(b, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.14)
		)
		parent.add_child(b)
		if not ui_key.is_empty():
			ui[ui_key] = b
		return b

	# Top-right quick language switcher (RU / EN)
	var btn_lang_top := Button.new()
	btn_lang_top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_lang_top.offset_left = -150
	btn_lang_top.offset_right = -28
	btn_lang_top.offset_top = 24
	btn_lang_top.offset_bottom = 62
	RoomsUI.style_button(btn_lang_top, Color(0.84, 0.88, 0.96), 14)
	btn_lang_top.pressed.connect(func() -> void: toggle_language())
	menu.add_child(btn_lang_top)
	ui["btn_lang_menu"] = btn_lang_top

	var v_main: VBoxContainer = make_view.call()
	var v_play: VBoxContainer = make_view.call()
	var v_multi: VBoxContainer = make_view.call()
	var v_credits: VBoxContainer = make_view.call()
	ui["menu_view_main"] = v_main
	ui["menu_view_play"] = v_play
	ui["menu_view_multi"] = v_multi
	ui["menu_view_credits"] = v_credits

	make_item.call(v_main, "start", func() -> void: set_menu_view("play"), 34, "m_btn_start")
	make_item.call(v_main, "dummi face", func() -> void: open_face_editor(), 28, "m_btn_face")
	make_item.call(v_main, "credits", func() -> void: set_menu_view("credits"), 28, "m_btn_credits")
	make_item.call(v_main, "settings", func() -> void: open_menu_settings(), 28, "m_btn_settings")

	make_item.call(v_play, "solo", func() -> void: game.call("menu_begin_game", false, ""), 34, "m_btn_solo")

	var cp_row := HBoxContainer.new()
	cp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cp_row.add_theme_constant_override("separation", 8)
	v_play.add_child(cp_row)
	ui["cp_row"] = cp_row

	var btn_cp_prev := Button.new()
	btn_cp_prev.text = " < "
	btn_cp_prev.flat = true
	btn_cp_prev.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	btn_cp_prev.add_theme_font_size_override("font_size", 22)
	btn_cp_prev.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	btn_cp_prev.pressed.connect(func() -> void: _cycle_checkpoint(-1))
	cp_row.add_child(btn_cp_prev)
	ui["btn_cp_prev"] = btn_cp_prev

	var btn_cp_val := Button.new()
	btn_cp_val.flat = true
	btn_cp_val.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	btn_cp_val.add_theme_font_size_override("font_size", 22)
	btn_cp_val.add_theme_color_override("font_color", Color(0.40, 0.95, 0.65))
	btn_cp_val.pressed.connect(func() -> void: _cycle_checkpoint(1))
	cp_row.add_child(btn_cp_val)
	ui["btn_cp_val"] = btn_cp_val

	var btn_cp_next := Button.new()
	btn_cp_next.text = " > "
	btn_cp_next.flat = true
	btn_cp_next.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	btn_cp_next.add_theme_font_size_override("font_size", 22)
	btn_cp_next.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	btn_cp_next.pressed.connect(func() -> void: _cycle_checkpoint(1))
	cp_row.add_child(btn_cp_next)
	ui["btn_cp_next"] = btn_cp_next

	make_item.call(v_play, "multiplayer", func() -> void: set_menu_view("multi"), 30, "m_btn_multi")
	make_item.call(v_play, "back", func() -> void: set_menu_view("main"), 22, "m_btn_play_back")

	var btn_steam_inv: Button = make_item.call(v_multi, "invite steam friends", func() -> void: game.call("menu_steam_invite"), 26, "m_btn_steam_inv")
	btn_steam_inv.visible = not settings.is_mobile_platform()
	var btn_start_multi: Button = make_item.call(v_multi, "start", func() -> void: game.call("menu_start_multiplayer"), 32, "btn_start_multi")

	var lbl_waiting := Label.new()
	lbl_waiting.text = "Waiting for host..."
	lbl_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_waiting.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lbl_waiting.add_theme_font_size_override("font_size", 20)
	lbl_waiting.add_theme_color_override("font_color", Color(0.80, 0.84, 0.92, 0.85))
	lbl_waiting.visible = false
	v_multi.add_child(lbl_waiting)
	ui["lbl_waiting_host"] = lbl_waiting

	make_item.call(v_multi, "dummi face", func() -> void: open_face_editor(), 22, "m_btn_multi_face")

	make_item.call(v_multi, "local network (host)", func() -> void:
		if net != null:
			net.host_enet(room_mgr.world_seed)
		update_menu_players_list()
		var host_ip: String = net._get_local_lan_ip() if net != null else "127.0.0.1"
		show_toast(RoomsI18n.t("toast_lan_started", [host_ip, RoomsNet.ENET_PORT]), 5.0)
	, 24, "m_btn_lan_host")

	var my_ip := net._get_local_lan_ip() if net != null else "127.0.0.1"
	var lan_info := Label.new()
	lan_info.text = RoomsI18n.t("menu_your_ip", [my_ip, RoomsNet.ENET_PORT])
	lan_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_info.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lan_info.add_theme_font_size_override("font_size", 14)
	lan_info.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0, 0.95))
	v_multi.add_child(lan_info)
	ui["lan_info_lbl"] = lan_info

	var btn_copy := Button.new()
	btn_copy.text = RoomsI18n.t("menu_copy_ip")
	btn_copy.custom_minimum_size = Vector2(0, 28)
	RoomsUI.style_link_button(btn_copy, 14, HORIZONTAL_ALIGNMENT_CENTER)
	btn_copy.pressed.connect(func() -> void:
		var cur_ip := net._get_local_lan_ip() if net != null else "127.0.0.1"
		DisplayServer.clipboard_set("%s:%d" % [cur_ip, RoomsNet.ENET_PORT])
		show_toast(RoomsI18n.t("toast_ip_copied"), 2.5)
	)
	v_multi.add_child(btn_copy)
	ui["m_btn_copy_ip"] = btn_copy

	var lan_row := HBoxContainer.new()
	lan_row.add_theme_constant_override("separation", 6)
	v_multi.add_child(lan_row)
	var lan_edit := LineEdit.new()
	lan_edit.placeholder_text = "%s:%d" % [my_ip, RoomsNet.ENET_PORT]
	lan_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_edit.custom_minimum_size = Vector2(0, 40)
	lan_row.add_child(lan_edit)
	ui["lan_ip_edit"] = lan_edit
	var btn_join := Button.new()
	btn_join.text = RoomsI18n.t("menu_join")
	btn_join.custom_minimum_size = Vector2(84, 40)
	RoomsUI.style_link_button(btn_join, 20)
	btn_join.pressed.connect(func() -> void:
		var raw := lan_edit.text.strip_edges().replace(" ", "")
		if raw.is_empty():
			raw = net._get_local_lan_ip() if net != null else my_ip
		var ip := raw
		var port := RoomsNet.ENET_PORT
		if ":" in raw:
			var parts := raw.split(":", false, 1)
			ip = parts[0]
			if parts.size() > 1 and parts[1].is_valid_int():
				port = int(parts[1])
		if net != null:
			var err := net.join_enet(ip, port)
			if err != OK:
				show_toast(RoomsI18n.t("toast_lan_bad_ip"), 3.0)
				return
		update_menu_players_list()
		show_toast(RoomsI18n.t("toast_lan_joining", [ip, port]), 3.0)
	)
	lan_row.add_child(btn_join)
	ui["m_btn_lan_join"] = btn_join

	# Auto-discovered LAN servers (essential for easy one-tap mobile Wi-Fi play!)
	var lan_found_hdr := Label.new()
	lan_found_hdr.text = RoomsI18n.t("menu_lan_searching")
	lan_found_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_found_hdr.add_theme_font_size_override("font_size", 12)
	lan_found_hdr.add_theme_color_override("font_color", Color(0.62, 0.78, 0.92, 0.85))
	v_multi.add_child(lan_found_hdr)
	ui["lan_found_hdr"] = lan_found_hdr

	lan_servers_box = VBoxContainer.new()
	lan_servers_box.add_theme_constant_override("separation", 4)
	v_multi.add_child(lan_servers_box)

	make_item.call(v_multi, "back", func() -> void: set_menu_view("play"), 22, "m_btn_multi_back")

	var menu_status := Label.new()
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.add_theme_font_size_override("font_size", 13)
	menu_status.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 0.9))
	v_multi.add_child(menu_status)
	ui["menu_status"] = menu_status

	# Left: Modifiers panel (visible in both solo 'play' and 'multi')
	var menu_mods := VBoxContainer.new()
	menu_mods.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	menu_mods.offset_left = 60
	menu_mods.offset_right = 360
	menu_mods.offset_top = -140
	menu_mods.offset_bottom = 260
	menu_mods.add_theme_constant_override("separation", 8)
	menu_mods.visible = false
	menu.add_child(menu_mods)
	ui["menu_multi_modifiers"] = menu_mods

	var mods_hdr := Label.new()
	mods_hdr.text = "Modifiers"
	mods_hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	mods_hdr.add_theme_font_size_override("font_size", 30)
	mods_hdr.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	menu_mods.add_child(mods_hdr)
	ui["mods_hdr"] = mods_hdr

	var mods_div := ColorRect.new()
	mods_div.custom_minimum_size = Vector2(140, 1)
	mods_div.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mods_div.color = Color(1.0, 1.0, 1.0, 0.3)
	menu_mods.add_child(mods_div)

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
		RoomsUI.style_link_button(btn, 18, HORIZONTAL_ALIGNMENT_LEFT)
		btn.set_meta("mod_name", m_name)
		ui["menu_mod_btn_" + m_key] = btn
		btn.pressed.connect(func() -> void: game.call("toggle_modifier", m_key, m_name))
		menu_mods.add_child(btn)
	update_menu_modifiers_ui()

	# Right: Lobby Players List (visible in 'multi')
	var menu_players_box := VBoxContainer.new()
	menu_players_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu_players_box.offset_left = -360
	menu_players_box.offset_right = -60
	menu_players_box.offset_top = -140
	menu_players_box.offset_bottom = 260
	menu_players_box.add_theme_constant_override("separation", 8)
	menu_players_box.visible = false
	menu.add_child(menu_players_box)
	ui["menu_multi_players"] = menu_players_box

	var plyr_hdr := Label.new()
	plyr_hdr.text = "Players"
	plyr_hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	plyr_hdr.add_theme_font_size_override("font_size", 30)
	plyr_hdr.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	menu_players_box.add_child(plyr_hdr)
	ui["plyr_hdr"] = plyr_hdr

	var plyr_div := ColorRect.new()
	plyr_div.custom_minimum_size = Vector2(140, 1)
	plyr_div.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plyr_div.color = Color(1.0, 1.0, 1.0, 0.3)
	menu_players_box.add_child(plyr_div)

	var menu_players := Label.new()
	menu_players.text = "• вы (ожидание подключения)"
	menu_players.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_players.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	menu_players.add_theme_font_size_override("font_size", 16)
	menu_players.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86, 0.9))
	menu_players_box.add_child(menu_players)
	ui["menu_players"] = menu_players

	var cred_lbl := Label.new()
	cred_lbl.text = RoomsI18n.t("menu_credits_body")
	cred_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cred_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cred_lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	cred_lbl.add_theme_font_size_override("font_size", 16)
	cred_lbl.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90, 0.92))
	v_credits.add_child(cred_lbl)
	ui["cred_lbl"] = cred_lbl
	make_item.call(v_credits, "back", func() -> void: set_menu_view("main"), 22, "m_btn_cred_back")

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
	ui["menu_exit"] = btn_quit

	set_menu_view("main", false)


func open_face_editor() -> void:
	if face_editor == null:
		return
	if ui.has("main_menu"):
		(ui["main_menu"] as Control).visible = false
	face_editor.open_editor()


func _build_pause_and_panels(root: Control) -> void:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	ui["modal"] = modal

	var pause_dim := ColorRect.new()
	pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dim.color = Color(0.014, 0.016, 0.021, 0.76)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(pause_dim)

	var pause_noise := ColorRect.new()
	pause_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_noise.material = RoomsUI.make_noise_material(0.90, 1.0)
	pause_noise.color = Color.WHITE
	pause_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(pause_noise)

	var m_brand := Label.new()
	m_brand.text = "r00ms"
	m_brand.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	m_brand.offset_left = -380
	m_brand.offset_top = 24
	m_brand.offset_right = -60
	m_brand.offset_bottom = 94
	m_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m_brand.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	m_brand.add_theme_font_size_override("font_size", 46)
	m_brand.add_theme_color_override("font_color", Color(0.93, 0.94, 0.97, 0.90))
	modal.add_child(m_brand)
	ui["m_brand"] = m_brand

	var m_main_box := VBoxContainer.new()
	m_main_box.anchor_left = 0.055
	m_main_box.anchor_right = 0.055
	m_main_box.anchor_top = 0.115
	m_main_box.anchor_bottom = 0.115
	m_main_box.offset_right = 470
	m_main_box.offset_bottom = 430
	m_main_box.add_theme_constant_override("separation", 2)
	modal.add_child(m_main_box)
	ui["m_main_box"] = m_main_box

	var m_title := Label.new()
	m_title.visible = false
	m_title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	m_title.add_theme_font_size_override("font_size", 22)
	m_main_box.add_child(m_title)
	ui["m_title"] = m_title

	var m_desc := Label.new()
	m_desc.visible = false
	m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_desc.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	m_desc.add_theme_font_size_override("font_size", 14)
	m_main_box.add_child(m_desc)
	ui["m_desc"] = m_desc

	var btn_resume := Button.new()
	btn_resume.text = "continue"
	btn_resume.custom_minimum_size = Vector2(0, 56)
	RoomsUI.style_link_button(btn_resume, 34)
	btn_resume.pressed.connect(func() -> void: game.call("set_state", 0)) # State.PLAYING
	m_main_box.add_child(btn_resume)
	ui["btn_resume"] = btn_resume

	var btn_settings := Button.new()
	btn_settings.text = "settings"
	btn_settings.custom_minimum_size = Vector2(0, 46)
	RoomsUI.style_link_button(btn_settings, 26)
	btn_settings.pressed.connect(func() -> void: open_settings_panel(true))
	m_main_box.add_child(btn_settings)
	ui["btn_pause_settings"] = btn_settings

	var btn_pause_admin := Button.new()
	btn_pause_admin.text = "admin panel"
	btn_pause_admin.custom_minimum_size = Vector2(0, 46)
	RoomsUI.style_link_button(btn_pause_admin, 26)
	btn_pause_admin.pressed.connect(func() -> void: open_admin_panel(true))
	btn_pause_admin.visible = false
	m_main_box.add_child(btn_pause_admin)
	ui["btn_pause_admin"] = btn_pause_admin

	var btn_exit := Button.new()
	btn_exit.text = "exit"
	btn_exit.custom_minimum_size = Vector2(0, 46)
	RoomsUI.style_link_button(btn_exit, 26)
	btn_exit.pressed.connect(func() -> void: game.call("exit_to_main_menu"))
	m_main_box.add_child(btn_exit)
	ui["btn_pause_exit"] = btn_exit

	var m_mods_box := VBoxContainer.new()
	m_mods_box.anchor_left = 0.65
	m_mods_box.anchor_right = 0.95
	m_mods_box.anchor_top = 0.12
	m_mods_box.anchor_bottom = 0.85
	m_mods_box.add_theme_constant_override("separation", 6)
	modal.add_child(m_mods_box)
	ui["m_mods_box"] = m_mods_box

	var m_mods_hdr := Label.new()
	m_mods_hdr.text = "modifiers"
	m_mods_hdr.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	m_mods_hdr.add_theme_font_size_override("font_size", 24)
	m_mods_box.add_child(m_mods_hdr)
	ui["m_mods_hdr"] = m_mods_hdr

	var m_mods_list := Label.new()
	m_mods_list.text = "• none (default)"
	m_mods_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_mods_list.add_theme_font_size_override("font_size", 15)
	m_mods_list.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84, 0.85))
	m_mods_box.add_child(m_mods_list)
	ui["m_mods_list"] = m_mods_list

	_build_settings_scroll(modal)
	_build_admin_scroll(modal)


func _build_settings_scroll(modal: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.offset_left = -312
	scroll.offset_right = 312
	scroll.offset_top = -336
	scroll.offset_bottom = 324
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	modal.add_child(scroll)
	ui["m_settings_scroll"] = scroll

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var neutral := Color(0.80, 0.84, 0.90)
	var add_hdr := func(txt: String, ui_key: String = "") -> void:
		var h := Label.new()
		h.text = txt
		h.add_theme_font_size_override("font_size", 12)
		h.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 0.85))
		box.add_child(h)
		if not ui_key.is_empty():
			ui[ui_key] = h

	var make_slider := func(title_str: String, s_key: String, l_key: String, min_v: float, max_v: float, step_v: float, init_v: float, on_chg: Callable, t_key: String = "") -> void:
		var row := HBoxContainer.new()
		box.add_child(row)
		var t_lbl := Label.new()
		t_lbl.text = title_str
		t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(t_lbl)
		if not t_key.is_empty():
			ui[t_key] = t_lbl
		var v_lbl := Label.new()
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", neutral)
		row.add_child(v_lbl)
		var sld := HSlider.new()
		sld.min_value = min_v
		sld.max_value = max_v
		sld.step = step_v
		sld.value = init_v
		sld.value_changed.connect(on_chg)
		box.add_child(sld)
		ui[s_key] = sld
		ui[l_key] = v_lbl

	add_hdr.call("звук", "set_hdr_audio")
	make_slider.call("Общая громкость", "sld_master", "lbl_master", 0.0, 100.0, 1.0, settings.audio_master * 100.0, func(v: float) -> void:
		settings.audio_master = clampf(v / 100.0, 0.0, 1.0)
		settings.apply_audio_settings(audio, true)
		sync_settings_ui()
	, "set_t_master")
	make_slider.call("Монстры", "sld_entities", "lbl_entities", 0.0, 100.0, 1.0, settings.audio_entities * 100.0, func(v: float) -> void:
		settings.audio_entities = clampf(v / 100.0, 0.0, 1.0)
		settings.apply_audio_settings(audio, true)
		sync_settings_ui()
	, "set_t_entities")
	make_slider.call("Эффекты и фонарик", "sld_sfx", "lbl_sfx", 0.0, 100.0, 1.0, settings.audio_sfx * 100.0, func(v: float) -> void:
		settings.audio_sfx = clampf(v / 100.0, 0.0, 1.0)
		settings.apply_audio_settings(audio, true)
		sync_settings_ui()
	, "set_t_sfx")
	make_slider.call("Атмосфера", "sld_ambient", "lbl_ambient", 0.0, 100.0, 1.0, settings.audio_ambient * 100.0, func(v: float) -> void:
		settings.audio_ambient = clampf(v / 100.0, 0.0, 1.0)
		settings.apply_audio_settings(audio, true)
		sync_settings_ui()
	, "set_t_ambient")

	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 6)
	box.add_child(audio_row)
	var btn_mute := Button.new()
	btn_mute.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_mute, neutral, 13)
	btn_mute.pressed.connect(func() -> void:
		settings.audio_muted = not settings.audio_muted
		settings.apply_audio_settings(audio, true)
		sync_settings_ui()
	)
	audio_row.add_child(btn_mute)
	ui["btn_mute_audio"] = btn_mute

	var btn_res_a := Button.new()
	btn_res_a.text = "сбросить звук"
	btn_res_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_res_a, neutral, 13)
	btn_res_a.pressed.connect(func() -> void:
		settings.reset_audio_defaults(audio)
		sync_settings_ui()
		show_toast(RoomsI18n.t("toast_audio_reset"), 1.8)
	)
	audio_row.add_child(btn_res_a)
	ui["btn_reset_audio"] = btn_res_a

	# Output & Input Audio Device selectors
	var out_devs := AudioServer.get_output_device_list()
	var opt_out := OptionButton.new()
	RoomsUI.style_button(opt_out, neutral, 12)
	for i in range(out_devs.size()):
		opt_out.add_item(RoomsI18n.t("set_output_prefix") + out_devs[i], i)
		if out_devs[i] == AudioServer.output_device:
			opt_out.selected = i
	opt_out.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < out_devs.size():
			AudioServer.output_device = out_devs[idx]
			settings.save_settings()
	)
	box.add_child(opt_out)

	var in_devs := AudioServer.get_input_device_list()
	var opt_in := OptionButton.new()
	RoomsUI.style_button(opt_in, neutral, 12)
	for i in range(in_devs.size()):
		opt_in.add_item(RoomsI18n.t("set_input_prefix") + in_devs[i], i)
		if in_devs[i] == AudioServer.input_device:
			opt_in.selected = i
	opt_in.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < in_devs.size():
			AudioServer.input_device = in_devs[idx]
			settings.save_settings()
	)
	box.add_child(opt_in)

	add_hdr.call("камера и управление", "set_hdr_controls")
	make_slider.call("Чувствительность", "sld_sens", "lbl_sens", 0.4, 2.2, 0.05, settings.mouse_sens_mult, func(v: float) -> void:
		settings.mouse_sens_mult = clampf(v, 0.4, 2.2)
		settings.save_settings()
		sync_settings_ui()
	, "set_t_sens")
	make_slider.call("Поле зрения (FOV)", "sld_fov", "lbl_fov", 65.0, 95.0, 1.0, settings.base_fov, func(v: float) -> void:
		settings.base_fov = clampf(v, 65.0, 95.0)
		settings.save_settings()
		sync_settings_ui()
	, "set_t_fov")

	var btn_bob := Button.new()
	RoomsUI.style_button(btn_bob, neutral, 13)
	btn_bob.pressed.connect(func() -> void:
		settings.head_bob_enabled = not settings.head_bob_enabled
		settings.save_settings()
		sync_settings_ui()
	)
	box.add_child(btn_bob)
	ui["btn_head_bob"] = btn_bob

	add_hdr.call("игра и рендер", "set_hdr_game")
	var btn_lang := Button.new()
	RoomsUI.style_button(btn_lang, Color(0.75, 0.90, 1.0), 13)
	btn_lang.pressed.connect(func() -> void: toggle_language())
	box.add_child(btn_lang)
	ui["btn_lang_settings"] = btn_lang

	var btn_restart := Button.new()
	btn_restart.text = "начать заново (A-000)"
	RoomsUI.style_button(btn_restart, neutral, 13)
	btn_restart.pressed.connect(func() -> void: game.call("reset_run", -1))
	box.add_child(btn_restart)
	ui["btn_set_restart"] = btn_restart

	var btn_mobile := Button.new()
	RoomsUI.style_button(btn_mobile, neutral, 13)
	btn_mobile.pressed.connect(func() -> void: game.call("cycle_mobile_mode"))
	box.add_child(btn_mobile)
	ui["btn_mobile"] = btn_mobile

	var ren_row := HBoxContainer.new()
	ren_row.add_theme_constant_override("separation", 6)
	box.add_child(ren_row)
	var btn_q := Button.new()
	btn_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_q, neutral, 12)
	btn_q.pressed.connect(func() -> void: game.call("cycle_render_quality"))
	ren_row.add_child(btn_q)
	ui["btn_quality"] = btn_q

	var btn_b := Button.new()
	btn_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_b, neutral, 12)
	btn_b.pressed.connect(func() -> void:
		var msg := settings.cycle_render_backend()
		refresh_render_buttons()
		if not msg.is_empty():
			show_toast(msg, 2.8)
	)
	ren_row.add_child(btn_b)
	ui["btn_backend"] = btn_b

	var btn_rr := Button.new()
	btn_rr.text = "перезапустить с новым рендером"
	btn_rr.visible = false
	RoomsUI.style_button(btn_rr, Color(1.0, 0.62, 0.30), 12)
	btn_rr.pressed.connect(func() -> void: game.call("restart_for_render"))
	box.add_child(btn_rr)
	ui["btn_restart_render"] = btn_rr

	var net_status := Label.new()
	net_status.text = net.get_summary_status() if net != null else "offline"
	net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status.add_theme_font_size_override("font_size", 12)
	box.add_child(net_status)
	ui["net_status"] = net_status

	lobby_list_box = VBoxContainer.new()
	box.add_child(lobby_list_box)

	var btn_back := Button.new()
	btn_back.text = "← back"
	btn_back.custom_minimum_size = Vector2(0, 44)
	RoomsUI.style_link_button(btn_back, 20)
	btn_back.pressed.connect(func() -> void: open_settings_panel(false))
	box.add_child(btn_back)
	ui["btn_set_back"] = btn_back


func _build_admin_scroll(modal: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.offset_left = -280
	scroll.offset_right = 280
	scroll.offset_top = -280
	scroll.offset_bottom = 280
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	modal.add_child(scroll)
	ui["m_admin_scroll"] = scroll

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "admin console"
	title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	ui["adm_title"] = title

	var sub := Label.new()
	sub.text = "[ прогресс и рекорды аннулируются ]"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45, 0.85))
	box.add_child(sub)
	ui["adm_sub"] = sub

	var add_cmd := func(txt: String, cb: Callable, col: Color = Color(0.85, 0.88, 0.94), loc_key: String = "") -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(0, 36)
		RoomsUI.style_link_button(b, 17, HORIZONTAL_ALIGNMENT_LEFT)
		b.add_theme_color_override("font_color", col)
		if not loc_key.is_empty():
			ui["adm_cmd_" + loc_key] = b
		b.pressed.connect(func() -> void:
			if not bool(game.call("can_use_admin")):
				show_toast(RoomsI18n.t("adm_host_only"), 2.0)
				return
			admin.cheats_used = true
			if cb.get_argument_count() > 0:
				cb.call(b)
			else:
				cb.call()
		)
		box.add_child(b)
		return b

	add_cmd.call("revive", func() -> void: game.call("admin_revive_self"), Color(0.35, 1.0, 0.55), "adm_revive")
	add_cmd.call("kill", func() -> void:
		open_admin_panel(false)
		game.call("set_state", 0)
		game.call("trigger_death", "Admin", "", {})
	, Color(1.0, 0.4, 0.4), "adm_kill")
	add_cmd.call("+50 hp", func() -> void:
		game.call("heal_player", 50)
		show_toast("HP: %d/100" % int(game.get("hp")), 1.8)
	, Color(0.85, 0.88, 0.94), "adm_heal")

	var b_god: Button = add_cmd.call("god mode: off", func(_b: Button) -> void:
		admin.god_mode = not admin.god_mode
		update_admin_buttons_ui()
		show_toast(RoomsI18n.t("adm_god", [RoomsI18n.t("on") if admin.god_mode else RoomsI18n.t("off")]), 1.8)
	)
	ui["adm_btn_god"] = b_god

	var b_stam: Button = add_cmd.call("infinite stamina: off", func(_b: Button) -> void:
		admin.inf_stamina = not admin.inf_stamina
		update_admin_buttons_ui()
		show_toast(RoomsI18n.t("adm_stam", [RoomsI18n.t("on") if admin.inf_stamina else RoomsI18n.t("off")]), 1.8)
	)
	ui["adm_btn_stamina"] = b_stam

	var b_nc: Button = add_cmd.call("noclip / fly: off", func(_b: Button) -> void:
		admin.noclip = not admin.noclip
		update_admin_buttons_ui()
		show_toast(RoomsI18n.t("adm_noclip", [RoomsI18n.t("on") if admin.noclip else RoomsI18n.t("off")]) + " [WASD + Space/Ctrl]", 2.2)
	)
	ui["adm_btn_noclip"] = b_nc

	var b_spd: Button = add_cmd.call("speed boost: 1.0x", func(_b: Button) -> void:
		admin.speed_mult = 2.0 if admin.speed_mult < 1.5 else (3.0 if admin.speed_mult < 2.5 else 1.0)
		update_admin_buttons_ui()
		show_toast(RoomsI18n.t("adm_speed", [admin.speed_mult]), 1.8)
	)
	ui["adm_btn_speed"] = b_spd

	var b_bat: Button = add_cmd.call("infinite battery: off", func(_b: Button) -> void:
		admin.inf_battery = not admin.inf_battery
		update_admin_buttons_ui()
		show_toast(RoomsI18n.t("adm_bat", [RoomsI18n.t("on") if admin.inf_battery else RoomsI18n.t("off")]), 1.8)
	)
	ui["adm_btn_battery"] = b_bat

	add_cmd.call("give gummy flashlight", func() -> void:
		player_ctrl.has_gummy = true
		player_ctrl.gummy_battery = 100.0
		show_toast(RoomsI18n.t("toast_gummy_got"), 2.0)
	, Color(0.85, 0.88, 0.94), "adm_gummy")
	add_cmd.call("+5 batteries", func() -> void:
		player_ctrl.batteries = mini(player_ctrl.batteries + 5, 8)
		show_toast("%s: %d/8" % [RoomsI18n.t("item_battery"), player_ctrl.batteries], 1.8)
	, Color(0.85, 0.88, 0.94), "adm_bats5")
	add_cmd.call("skip +5 rooms", func() -> void: game.call("admin_skip_rooms", 5), Color(0.85, 0.88, 0.94), "adm_skip5")
	add_cmd.call("skip +10 rooms", func() -> void: game.call("admin_skip_rooms", 10), Color(0.85, 0.88, 0.94), "adm_skip10")
	add_cmd.call("despawn all monsters", func() -> void:
		entities.despawn_all(true)
		show_toast(RoomsI18n.t("toast_despawned"), 2.0)
	, Color(0.4, 1.0, 0.6), "adm_despawn")
	add_cmd.call("toggle blackout", func() -> void:
		if not room_mgr.power_out:
			room_mgr.trigger_power_outage(audio)
			show_toast(RoomsI18n.t("toast_blackout_on"), 2.0)
		else:
			room_mgr.restore_power()
			show_toast(RoomsI18n.t("toast_blackout_off"), 2.0)
	, Color(0.85, 0.88, 0.94), "adm_blackout")

	var b_ts: Button = add_cmd.call("game speed: 1.0x", func(_b: Button) -> void:
		Engine.time_scale = 0.5 if Engine.time_scale >= 1.9 else (1.0 if Engine.time_scale <= 0.6 else 2.0)
		update_admin_buttons_ui()
		show_toast(RoomsI18n.t("adm_timescale", [Engine.time_scale]), 1.8)
	)
	ui["adm_btn_timescale"] = b_ts

	add_cmd.call("revive all peers", func() -> void:
		game.call("admin_revive_self")
		if net != null and net.is_online():
			net.broadcast_entity_event({"k": "admin_revive"}, true)
		show_toast(RoomsI18n.t("toast_revived"), 2.5)
	, Color(0.35, 1.0, 0.55), "adm_revive_all")
	add_cmd.call("spawn a-60", func() -> void: entities.spawn_a60(false), Color(0.85, 0.88, 0.94), "adm_spawn_a60")
	add_cmd.call("spawn a-60 prime", func() -> void: entities.spawn_a60(true), Color(0.85, 0.88, 0.94), "adm_spawn_a60p")
	add_cmd.call("spawn a-075 (shutter)", func() -> void:
		entities.spawn_a075()
		open_admin_panel(false)
		game.call("set_state", 0)
		show_toast(RoomsI18n.t("toast_a075_spawn"), 3.5)
	, Color(1.0, 0.80, 0.35), "adm_spawn_a075")
	add_cmd.call("spawn a-90", func() -> void: entities.start_a90_local(), Color(0.85, 0.88, 0.94), "adm_spawn_a90")
	add_cmd.call("spawn a-120", func() -> void: entities.spawn_a120(), Color(0.85, 0.88, 0.94), "adm_spawn_a120")
	add_cmd.call("tp to next door", func() -> void:
		var r := room_mgr.find_first_closed_door_room()
		if r != null and is_instance_valid(r.exit_anchor):
			player_ctrl.player_body.global_position = r.exit_anchor.global_position - r.out_dir * 1.5
			open_admin_panel(false)
			game.call("set_state", 0)
	, Color(0.85, 0.88, 0.94), "adm_tp_door")
	add_cmd.call("refill battery", func() -> void:
		player_ctrl.std_battery = 150.0
		player_ctrl.gummy_battery = 100.0
		player_ctrl.batteries = mini(player_ctrl.batteries + 2, 8)
		show_toast(RoomsI18n.t("toast_flash_reloaded", [player_ctrl.batteries]), 2.0)
	, Color(0.85, 0.88, 0.94), "adm_refill")
	add_cmd.call("grant admin to all", func() -> void:
		if net != null and net.is_online():
			net.broadcast_entity_event({"k": "admin_grant"}, true)
			show_toast(RoomsI18n.t("toast_admin_granted"), 2.5)
	, Color(0.85, 0.88, 0.94), "adm_grant_all")

	var btn_back := Button.new()
	btn_back.text = "← back"
	btn_back.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_link_button(btn_back, 20)
	btn_back.pressed.connect(func() -> void: open_admin_panel(false))
	box.add_child(btn_back)
	ui["btn_adm_back"] = btn_back


func _build_architect_and_spectate(root: Control) -> void:
	var arch_overlay := Control.new()
	arch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_overlay.visible = false
	root.add_child(arch_overlay)
	ui["architect_overlay"] = arch_overlay

	var arch_bg := ColorRect.new()
	arch_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_bg.color = Color.WHITE
	arch_bg.material = RoomsArchitect.make_void_shader_material()
	arch_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	arch_bg.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			game.call("advance_architect_dialogue")
	)
	arch_overlay.add_child(arch_bg)

	var mono_f := RoomsArchitect.get_terminal_font()
	# Centered pure-white Architect speech text (requested: moved from top-left to center & recolored white)
	var arch_speech := Label.new()
	arch_speech.anchor_left = 0.10
	arch_speech.anchor_right = 0.90
	arch_speech.anchor_top = 0.16
	arch_speech.anchor_bottom = 0.78
	arch_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arch_speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arch_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arch_speech.add_theme_font_override("font", mono_f)
	arch_speech.add_theme_font_size_override("font_size", 26)
	arch_speech.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	arch_speech.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.22))
	arch_speech.add_theme_constant_override("shadow_offset_x", 0)
	arch_speech.add_theme_constant_override("shadow_offset_y", 0)
	arch_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_speech)
	ui["arch_speech"] = arch_speech

	# Bottom-right ASCII art removed as requested; keep invisible dummy node ref for backwards safety
	var arch_ascii := RichTextLabel.new()
	arch_ascii.visible = false
	arch_ascii.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_ascii)
	ui["arch_ascii"] = arch_ascii

	var arch_meta := Label.new()
	arch_meta.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	arch_meta.offset_left = 24
	arch_meta.offset_top = -52
	arch_meta.offset_right = 560
	arch_meta.offset_bottom = -22
	arch_meta.add_theme_font_override("font", mono_f)
	arch_meta.add_theme_font_size_override("font_size", 12)
	arch_meta.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 0.72))
	arch_overlay.add_child(arch_meta)
	ui["arch_meta"] = arch_meta

	var arch_page := Label.new()
	arch_page.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	arch_page.offset_left = -260
	arch_page.offset_top = 16
	arch_page.offset_right = -20
	arch_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arch_page.add_theme_font_override("font", mono_f)
	arch_page.add_theme_font_size_override("font_size", 12)
	arch_page.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 0.72))
	arch_overlay.add_child(arch_page)
	ui["arch_page"] = arch_page

	var big := Panel.new()
	big.set_anchors_preset(Control.PRESET_CENTER)
	big.offset_left = -340
	big.offset_right = 340
	big.offset_top = -220
	big.offset_bottom = 180
	big.add_theme_stylebox_override("panel", RoomsUI.make_cmd_window_style())
	big.visible = false
	arch_overlay.add_child(big)
	ui["arch_window_big"] = big

	var big_bar := ColorRect.new()
	big_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	big_bar.offset_bottom = 31
	big_bar.color = Color(0.13, 0.14, 0.17)
	big.add_child(big_bar)
	var big_title := Label.new()
	big_title.text = "C:\\Windows\\System32\\cmd.exe - [r00ms death report]"
	big_title.offset_left = 12
	big_title.offset_top = 6
	big_title.add_theme_font_override("font", mono_f)
	big_title.add_theme_font_size_override("font_size", 12)
	big.add_child(big_title)

	var big_stats := Label.new()
	big_stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_stats.offset_left = 24
	big_stats.offset_right = -24
	big_stats.offset_top = 44
	big_stats.offset_bottom = -58
	big_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big_stats.add_theme_font_override("font", mono_f)
	big_stats.add_theme_font_size_override("font_size", 15)
	big.add_child(big_stats)
	ui["arch_stats_lbl"] = big_stats

	var btn_spec := Button.new()
	btn_spec.text = "[НАБЛЮДЕНИЕ]"
	btn_spec.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn_spec.offset_left = 24
	btn_spec.offset_right = -24
	btn_spec.offset_top = -48
	btn_spec.offset_bottom = -14
	RoomsUI.style_button(btn_spec, Color(0.45, 0.85, 1.0), 13)
	btn_spec.pressed.connect(func() -> void: game.call("start_spectating"))
	big.add_child(btn_spec)
	ui["btn_stat_spectate"] = btn_spec

	var arch_restart := Label.new()
	arch_restart.text = "> [R] НАЧАТЬ ЗАНОВО"
	arch_restart.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	arch_restart.offset_left = -200
	arch_restart.offset_top = -56
	arch_restart.offset_right = 200
	arch_restart.offset_bottom = -22
	arch_restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arch_restart.add_theme_font_override("font", mono_f)
	arch_restart.add_theme_font_size_override("font_size", 17)
	arch_restart.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.96))
	arch_restart.mouse_filter = Control.MOUSE_FILTER_STOP
	arch_restart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arch_restart.visible = false
	arch_restart.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			game.call("reset_run", -1)
	)
	arch_overlay.add_child(arch_restart)
	ui["arch_restart_hint"] = arch_restart

	# Spectate bar
	var spec_bar := Control.new()
	spec_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	spec_bar.offset_top = -90
	spec_bar.offset_bottom = -16
	spec_bar.visible = false
	root.add_child(spec_bar)
	ui["spectate_bar"] = spec_bar

	var spec_lbl := Label.new()
	spec_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	spec_lbl.offset_bottom = 30
	spec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spec_lbl.add_theme_font_size_override("font_size", 18)
	spec_bar.add_child(spec_lbl)
	ui["spectate_lbl"] = spec_lbl

	var b_sp_p := Button.new()
	b_sp_p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b_sp_p.offset_left = -210
	b_sp_p.offset_right = -70
	b_sp_p.offset_top = -36
	b_sp_p.text = "<< Назад"
	RoomsUI.style_button(b_sp_p, Color(0.45, 0.85, 1.0), 14)
	b_sp_p.pressed.connect(func() -> void: game.call("cycle_spectate_target", -1))
	spec_bar.add_child(b_sp_p)
	ui["b_sp_p"] = b_sp_p

	var b_sp_n := Button.new()
	b_sp_n.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b_sp_n.offset_left = -60
	b_sp_n.offset_right = 80
	b_sp_n.offset_top = -36
	b_sp_n.text = "Вперёд >>"
	RoomsUI.style_button(b_sp_n, Color(0.45, 0.85, 1.0), 14)
	b_sp_n.pressed.connect(func() -> void: game.call("cycle_spectate_target", 1))
	spec_bar.add_child(b_sp_n)
	ui["b_sp_n"] = b_sp_n

	var b_sp_r := Button.new()
	b_sp_r.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b_sp_r.offset_left = 94
	b_sp_r.offset_right = 230
	b_sp_r.offset_top = -36
	b_sp_r.text = "Рестарт [R]"
	RoomsUI.style_button(b_sp_r, Color(1.0, 0.72, 0.25), 13)
	b_sp_r.pressed.connect(func() -> void: game.call("reset_run", -1))
	spec_bar.add_child(b_sp_r)
	ui["b_sp_r"] = b_sp_r


func _build_chat(root: Control) -> void:
	var chat_box := VBoxContainer.new()
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.offset_left = 18.0
	chat_box.offset_top = -206.0
	chat_box.offset_right = 420.0
	chat_box.offset_bottom = -52.0
	chat_box.add_theme_constant_override("separation", 4)
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_box.visible = false
	root.add_child(chat_box)
	ui["chat_box"] = chat_box

	var chat_log := RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_active = false
	chat_log.scroll_following = true
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 13)
	chat_log.add_theme_stylebox_override("normal", RoomsUI.make_panel_style(Color(0.0, 0.0, 0.0, 0.45), Color(1, 1, 1, 0.08), 4, 1))
	chat_box.add_child(chat_log)
	ui["chat_log"] = chat_log

	var chat_edit := LineEdit.new()
	chat_edit.visible = false
	chat_edit.placeholder_text = "сообщение... (Enter — отправить, Esc — закрыть)"
	chat_edit.max_length = 128
	chat_edit.text_submitted.connect(func(_t: String) -> void: chat_submit())
	chat_box.add_child(chat_edit)
	ui["chat_edit"] = chat_edit

	var chat_hint := Label.new()
	chat_hint.text = "T — чат · V — голос"
	chat_hint.add_theme_font_size_override("font_size", 11)
	chat_hint.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8, 0.55))
	chat_box.add_child(chat_hint)
	ui["chat_hint"] = chat_hint


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
	parent.add_child(b)
	mobile_btns.append(b)
	return b


func _build_mobile_ui(hud_group: Control) -> void:
	var mg := Control.new()
	mg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.visible = false
	hud_group.add_child(mg)
	ui["mobile_group"] = mg

	joy_ring = Panel.new()
	joy_ring.anchor_top = 1.0
	joy_ring.anchor_bottom = 1.0
	joy_ring.offset_left = 40
	joy_ring.offset_right = 260
	joy_ring.offset_top = -270
	joy_ring.offset_bottom = -50
	joy_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ring.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.04, 0.07, 0.12, 0.24), Color(1.0, 1.0, 1.0, 0.34), 110, 2))
	mg.add_child(joy_ring)

	joy_knob = Panel.new()
	joy_knob.size = Vector2(84, 84)
	joy_knob.position = Vector2(68, 68)
	joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_knob.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(1.0, 1.0, 1.0, 0.40), Color(1.0, 1.0, 1.0, 0.85), 42, 2))
	joy_ring.add_child(joy_knob)

	var btn_pause := _make_ring_btn(mg, Color(0.85, 0.90, 0.96, 0.85), 3.0, -24, 72, 48, Control.PRESET_TOP_RIGHT, "||")
	btn_pause.pressed.connect(func() -> void: game.call("set_state", 1)) # State.PAUSED

	var btn_light := _make_ring_btn(mg, Color(1.0, 1.0, 1.0, 0.96), 7.5, -24, -22, 126)
	btn_light.button_down.connect(func() -> void:
		if player_ctrl.active_tool == 1:
			player_ctrl.mobile_gummy_held = true
		else:
			player_ctrl.toggle_flashlight(entities, self)
	)
	btn_light.button_up.connect(func() -> void: player_ctrl.mobile_gummy_held = false)
	ui["m_btn_light"] = btn_light

	var btn_sprint := _make_ring_btn(mg, Color(0.14, 0.44, 1.0, 0.98), 6.0, -22, -162, 68)
	btn_sprint.button_down.connect(func() -> void: player_ctrl.mobile_sprint_held = true)
	btn_sprint.button_up.connect(func() -> void: player_ctrl.mobile_sprint_held = false)
	ui["m_btn_sprint"] = btn_sprint

	var btn_reload := _make_ring_btn(mg, Color(1.0, 0.82, 0.25, 0.95), 4.5, -168, -124, 54, Control.PRESET_BOTTOM_RIGHT, "R")
	btn_reload.pressed.connect(func() -> void: player_ctrl.try_reload_flashlight(self))
	btn_reload.visible = false
	ui["m_btn_reload"] = btn_reload

	var btn_gummy := _make_ring_btn(mg, Color(0.24, 0.98, 0.48, 0.95), 5.5, -168, -42, 68)
	btn_gummy.button_down.connect(func() -> void:
		if player_ctrl.has_gummy:
			if player_ctrl.active_tool != 1:
				player_ctrl.active_tool = 1
				audio.play_flashlight_click()
			else:
				player_ctrl.mobile_gummy_held = true
				player_ctrl.try_shake_gummy()
	)
	btn_gummy.button_up.connect(func() -> void: player_ctrl.mobile_gummy_held = false)
	btn_gummy.visible = false
	ui["m_btn_gummy"] = btn_gummy

	var btn_fwd := _make_ring_btn(mg, Color(0.32, 0.98, 0.58, 0.95), 5.5, -26, -158, 72, Control.PRESET_BOTTOM_RIGHT, "W")
	btn_fwd.pressed.connect(func() -> void: player_ctrl.exit_locker(false, entities))
	ui["m_btn_exit_fwd"] = btn_fwd

	var btn_back := _make_ring_btn(mg, Color(1.0, 0.68, 0.24, 0.95), 5.5, -26, -26, 72, Control.PRESET_BOTTOM_RIGHT, "S")
	btn_back.pressed.connect(func() -> void: player_ctrl.exit_locker(true, entities))
	ui["m_btn_exit_back"] = btn_back


func _build_startup_splash(root: Control) -> void:
	var splash := ColorRect.new()
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.color = Color(0.01, 0.011, 0.015, 1.0)
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(splash)
	ui["startup_splash"] = splash

	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.material = RoomsUI.make_noise_material(0.35, 1.0)
	noise.color = Color.WHITE
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(noise)

	# Quick RU / EN switcher right on the disclaimer screen
	var btn_lang_disc := Button.new()
	btn_lang_disc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_lang_disc.offset_left = -150
	btn_lang_disc.offset_right = -28
	btn_lang_disc.offset_top = 24
	btn_lang_disc.offset_bottom = 62
	RoomsUI.style_button(btn_lang_disc, Color(0.84, 0.88, 0.96), 14)
	btn_lang_disc.pressed.connect(func() -> void: toggle_language())
	splash.add_child(btn_lang_disc)
	ui["btn_lang_disc"] = btn_lang_disc

	# Centered Epilepsy / Photosensitivity Disclaimer Card
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(center)
	ui["disclaimer_center"] = center

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 0)
	card.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.025, 0.028, 0.036, 0.94), Color(1.0, 0.84, 0.42, 0.35), 8, 1))
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var d_title := Label.new()
	d_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	d_title.add_theme_font_size_override("font_size", 22)
	d_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	box.add_child(d_title)
	ui["disc_title"] = d_title

	var d_rule := ColorRect.new()
	d_rule.custom_minimum_size = Vector2(0, 1)
	d_rule.color = Color(1.0, 1.0, 1.0, 0.16)
	box.add_child(d_rule)

	var d_body := Label.new()
	d_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_body.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	d_body.add_theme_font_size_override("font_size", 16)
	d_body.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97, 0.94))
	box.add_child(d_body)
	ui["disc_body"] = d_body

	var btn_cont := Button.new()
	btn_cont.custom_minimum_size = Vector2(240, 44)
	btn_cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	RoomsUI.style_button(btn_cont, Color(1.0, 0.92, 0.72), 16)
	box.add_child(btn_cont)
	ui["disc_continue"] = btn_cont

	var d_hint := Label.new()
	d_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_hint.add_theme_font_size_override("font_size", 12)
	d_hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74, 0.75))
	box.add_child(d_hint)
	ui["disc_hint"] = d_hint

	# Title logo revealed smoothly right after accepting the disclaimer
	var lbl := Label.new()
	lbl.text = "r00ms"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 96)
	lbl.modulate.a = 0.0
	lbl.visible = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.add_child(lbl)

	# Animate disclaimer card entrance
	card.modulate.a = 0.0
	var tw_in := create_tween()
	tw_in.tween_property(card, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	disclaimer_active = true
	var dismiss := func() -> void:
		if not disclaimer_active:
			return
		disclaimer_active = false
		btn_lang_disc.visible = false
		var tw := create_tween()
		tw.tween_property(center, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			center.visible = false
			lbl.visible = true
			lbl.modulate.a = 0.0
		)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(splash, "modulate:a", 0.0, 0.65)
		tw.tween_callback(func() -> void:
			splash.visible = false
			splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		)

	_disclaimer_dismiss_cb = dismiss
	btn_cont.pressed.connect(dismiss)
	splash.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			if disclaimer_active:
				dismiss.call()
			else:
				splash.visible = false
				splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


func dismiss_disclaimer() -> void:
	if disclaimer_active and _disclaimer_dismiss_cb.is_valid():
		_disclaimer_dismiss_cb.call()


func toggle_language() -> void:
	var new_lang := RoomsI18n.toggle_lang()
	if settings != null:
		settings.language = new_lang
		settings.save_settings()
	apply_localization()


func apply_localization() -> void:
	var set_txt := func(ui_key: String, loc_key: String, args: Array = []) -> void:
		var n: Variant = ui.get(ui_key)
		if n is Button:
			(n as Button).text = RoomsI18n.t(loc_key, args)
		elif n is Label:
			(n as Label).text = RoomsI18n.t(loc_key, args)

	var lang_tag := "🌐 RU / EN" if RoomsI18n.lang == "ru" else "🌐 EN / RU"
	if ui.has("btn_lang_menu"):
		(ui["btn_lang_menu"] as Button).text = lang_tag
	if ui.has("btn_lang_disc"):
		(ui["btn_lang_disc"] as Button).text = lang_tag
	set_txt.call("btn_lang_settings", "lang_btn")

	# Disclaimer
	set_txt.call("disc_title", "epilepsy_title")
	set_txt.call("disc_body", "epilepsy_body")
	set_txt.call("disc_continue", "epilepsy_continue")
	set_txt.call("disc_hint", "epilepsy_hint")

	# Main menu
	set_txt.call("m_btn_start", "menu_start")
	set_txt.call("m_btn_face", "menu_dummi_face")
	set_txt.call("m_btn_credits", "menu_credits")
	set_txt.call("m_btn_settings", "menu_settings")
	set_txt.call("m_btn_solo", "menu_solo")
	set_txt.call("m_btn_multi", "menu_multi")
	set_txt.call("m_btn_play_back", "menu_back")
	set_txt.call("m_btn_steam_inv", "menu_invite_steam")
	set_txt.call("btn_start_multi", "menu_start")
	set_txt.call("lbl_waiting_host", "menu_waiting_host")
	set_txt.call("m_btn_multi_face", "menu_dummi_face")
	set_txt.call("m_btn_lan_host", "menu_lan_host")
	set_txt.call("m_btn_copy_ip", "menu_copy_ip")
	set_txt.call("m_btn_lan_join", "menu_join")
	set_txt.call("m_btn_multi_back", "menu_back")
	set_txt.call("mods_hdr", "menu_modifiers")
	set_txt.call("plyr_hdr", "menu_players")
	set_txt.call("cred_lbl", "menu_credits_body")
	set_txt.call("m_btn_cred_back", "menu_back")
	set_txt.call("menu_exit", "menu_exit")
	if ui.has("lan_info_lbl"):
		var cur_ip := net._get_local_lan_ip() if net != null else "127.0.0.1"
		(ui["lan_info_lbl"] as Label).text = RoomsI18n.t("menu_your_ip", [cur_ip, RoomsNet.ENET_PORT])
	if ui.has("lan_found_hdr") and (lan_servers_box == null or lan_servers_box.get_child_count() == 0):
		(ui["lan_found_hdr"] as Label).text = RoomsI18n.t("menu_lan_searching")

	# Pause
	set_txt.call("btn_resume", "pause_continue")
	set_txt.call("btn_pause_settings", "pause_settings")
	set_txt.call("btn_pause_admin", "pause_admin")
	set_txt.call("btn_pause_exit", "pause_exit")
	set_txt.call("m_mods_hdr", "pause_modifiers")

	# Settings
	set_txt.call("set_hdr_audio", "set_hdr_audio")
	set_txt.call("set_t_master", "set_master")
	set_txt.call("set_t_entities", "set_entities")
	set_txt.call("set_t_sfx", "set_sfx")
	set_txt.call("set_t_ambient", "set_ambient")
	set_txt.call("btn_reset_audio", "set_reset_audio")
	set_txt.call("set_hdr_controls", "set_hdr_controls")
	set_txt.call("set_t_sens", "set_sens")
	set_txt.call("set_t_fov", "set_fov")
	set_txt.call("set_hdr_game", "set_hdr_game")
	set_txt.call("btn_set_restart", "set_restart")
	set_txt.call("btn_restart_render", "set_restart_render")
	set_txt.call("btn_set_back", "menu_back_arrow")

	# Admin
	set_txt.call("adm_title", "adm_title")
	set_txt.call("adm_sub", "adm_sub")
	set_txt.call("btn_adm_back", "menu_back_arrow")
	for lk in ["adm_revive", "adm_kill", "adm_heal", "adm_gummy", "adm_bats5", "adm_skip5", "adm_skip10", "adm_despawn", "adm_blackout", "adm_revive_all", "adm_spawn_a60", "adm_spawn_a60p", "adm_spawn_a075", "adm_spawn_a90", "adm_spawn_a120", "adm_tp_door", "adm_refill", "adm_grant_all"]:
		set_txt.call("adm_cmd_" + lk, lk)

	# Architect & Spectate & Chat
	set_txt.call("btn_stat_spectate", "spec_btn")
	set_txt.call("arch_restart_hint", "arch_restart")
	set_txt.call("b_sp_p", "spec_prev")
	set_txt.call("b_sp_n", "spec_next")
	set_txt.call("b_sp_r", "spec_restart")
	if ui.has("chat_edit"):
		(ui["chat_edit"] as LineEdit).placeholder_text = RoomsI18n.t("chat_placeholder")
	chat_set_readonly(chat_readonly)

	# Refresh dynamic sections
	update_menu_modifiers_ui()
	update_pause_modifiers_ui()
	update_admin_buttons_ui()
	update_menu_players_list()
	sync_settings_ui()
	refresh_render_buttons()
	if game != null and game.has_method("refresh_mobile_mode"):
		game.call("refresh_mobile_mode")
	if face_editor != null:
		face_editor.apply_localization()
	update_checkpoint_ui()


func update_lan_servers_list(servers: Array) -> void:
	if lan_servers_box == null:
		return
	for ch in lan_servers_box.get_children():
		ch.queue_free()
	var hdr := ui.get("lan_found_hdr") as Label
	if servers.is_empty():
		if hdr != null:
			hdr.text = RoomsI18n.t("menu_lan_searching")
		return
	if hdr != null:
		hdr.text = RoomsI18n.t("menu_lan_found_hdr")
	for srv_v in servers:
		if not (srv_v is Dictionary):
			continue
		var srv: Dictionary = srv_v
		var ip := String(srv.get("ip", ""))
		var port := int(srv.get("port", RoomsNet.ENET_PORT))
		var hname := String(srv.get("name", "Host"))
		var pl := int(srv.get("players", 1))
		var b := Button.new()
		b.text = RoomsI18n.t("menu_lan_join_entry", [hname, ip, pl])
		b.custom_minimum_size = Vector2(0, 34)
		RoomsUI.style_button(b, Color(0.35, 0.92, 1.0), 13)
		b.pressed.connect(func() -> void:
			if ui.has("lan_ip_edit"):
				(ui["lan_ip_edit"] as LineEdit).text = "%s:%d" % [ip, port]
			if net != null:
				net.join_enet(ip, port)
			update_menu_players_list()
			show_toast(RoomsI18n.t("toast_lan_joining", [ip, port]), 3.0)
		)
		lan_servers_box.add_child(b)


func open_settings_panel(open: bool) -> void:
	if ui.has("m_main_box"):
		(ui["m_main_box"] as Control).visible = not open
	if ui.has("m_mods_box"):
		(ui["m_mods_box"] as Control).visible = not open
	if ui.has("m_settings_scroll"):
		var sc := ui["m_settings_scroll"] as Control
		sc.visible = open
		if open:
			sc.modulate.a = 0.0
			create_tween().tween_property(sc, "modulate:a", 1.0, 0.18)
	if ui.has("m_admin_scroll"):
		(ui["m_admin_scroll"] as Control).visible = false
	if ui.has("m_brand"):
		(ui["m_brand"] as Control).visible = not open
	if not open and settings_from_menu:
		settings_from_menu = false
		if ui.has("modal"):
			(ui["modal"] as Control).visible = false
		if ui.has("main_menu"):
			(ui["main_menu"] as Control).visible = true


func open_admin_panel(open: bool) -> void:
	if ui.has("m_main_box"):
		(ui["m_main_box"] as Control).visible = not open
	if ui.has("m_mods_box"):
		(ui["m_mods_box"] as Control).visible = not open
	if ui.has("m_admin_scroll"):
		var sc := ui["m_admin_scroll"] as Control
		sc.visible = open
		if open:
			sc.modulate.a = 0.0
			create_tween().tween_property(sc, "modulate:a", 1.0, 0.18)
	if ui.has("m_settings_scroll"):
		(ui["m_settings_scroll"] as Control).visible = false
	if ui.has("m_brand"):
		(ui["m_brand"] as Control).visible = not open


func open_menu_settings() -> void:
	settings_from_menu = true
	if ui.has("main_menu"):
		(ui["main_menu"] as Control).visible = false
	if ui.has("modal"):
		var modal := ui["modal"] as Control
		modal.visible = true
		modal.modulate.a = 0.0
		create_tween().tween_property(modal, "modulate:a", 1.0, 0.20)
	open_settings_panel(true)


func set_menu_view(view: String, fade: bool = true) -> void:
	menu_view = view
	var views := {
		"main": ui.get("menu_view_main"),
		"play": ui.get("menu_view_play"),
		"multi": ui.get("menu_view_multi"),
		"credits": ui.get("menu_view_credits"),
	}
	for k in views.keys():
		var c := views[k] as Control
		if c != null:
			c.visible = (String(k) == view)
	var cur := views.get(view) as Control
	if cur != null and fade:
		cur.modulate.a = 0.0
		create_tween().tween_property(cur, "modulate:a", 1.0, 0.20)

	var is_multi := (view == "multi")
	var show_mods := (view == "multi" or view == "play")
	if ui.has("menu_exit"):
		(ui["menu_exit"] as Control).visible = (view == "main")
	if ui.has("menu_multi_modifiers"):
		(ui["menu_multi_modifiers"] as Control).visible = show_mods
	if ui.has("menu_multi_players"):
		(ui["menu_multi_players"] as Control).visible = is_multi
	if net != null:
		if is_multi:
			net.start_lan_discovery()
			if ui.has("lan_info_lbl"):
				var cur_ip := net._get_local_lan_ip()
				(ui["lan_info_lbl"] as Label).text = RoomsI18n.t("menu_your_ip", [cur_ip, RoomsNet.ENET_PORT])
			update_menu_players_list()
		else:
			net.stop_lan_discovery()


func _cycle_checkpoint(dir: int) -> void:
	if settings == null:
		return
	var list: Array[int] = settings.get_unlocked_checkpoints()
	if list.is_empty():
		return
	var cur_idx := list.find(settings.selected_start_room)
	if cur_idx < 0:
		cur_idx = 0
	var next_idx := (cur_idx + dir) % list.size()
	if next_idx < 0:
		next_idx = list.size() - 1
	var new_room := list[next_idx]
	game.call("set_selected_checkpoint", new_room)
	update_checkpoint_ui()


func update_checkpoint_ui() -> void:
	if not ui.has("btn_cp_val"):
		return
	var btn := ui["btn_cp_val"] as Button
	var cur_room: int = settings.selected_start_room if settings != null else 0
	btn.text = RoomsI18n.t("menu_checkpoint", [cur_room])
	var list: Array[int] = settings.get_unlocked_checkpoints() if settings != null else [0]
	var can_cycle := (list.size() > 1)
	if ui.has("btn_cp_prev"):
		(ui["btn_cp_prev"] as Button).disabled = not can_cycle
	if ui.has("btn_cp_next"):
		(ui["btn_cp_next"] as Button).disabled = not can_cycle


func show_main_menu(fresh: bool = false) -> void:
	var menu := ui.get("main_menu") as Control
	if menu == null:
		return
	menu.visible = true
	menu.modulate.a = 1.0
	set_menu_view("main", false)
	update_checkpoint_ui()
	if fresh:
		menu.modulate.a = 0.0
		create_tween().tween_property(menu, "modulate:a", 1.0, 0.55)


func update_menu_modifiers_ui() -> void:
	var mods: Dictionary = game.get("active_modifiers")
	for k in ["admin_panel", "wet_floor", "bad_time", "make_haste", "lights_out", "sprint_fatigue"]:
		var b := ui.get("menu_mod_btn_" + k) as Button
		if b == null:
			continue
		var active := bool(mods.get(k, false))
		var m_name := RoomsI18n.t("mod_" + k)
		b.set_meta("mod_name", m_name)
		b.text = ("[X] " if active else "[ ] ") + m_name
		b.add_theme_color_override("font_color", Color(0.28, 1.0, 0.42) if active else Color(0.72, 0.76, 0.82))


func update_pause_modifiers_ui() -> void:
	if ui.has("btn_pause_admin"):
		(ui["btn_pause_admin"] as Control).visible = bool(game.call("can_use_admin"))
	var lbl := ui.get("m_mods_list") as Label
	if lbl == null:
		return
	var mods: Dictionary = game.get("active_modifiers")
	var lines: Array[String] = []
	for k in ["admin_panel", "wet_floor", "bad_time", "make_haste", "lights_out", "sprint_fatigue"]:
		if bool(mods.get(k, false)):
			lines.append("• " + RoomsI18n.t("mod_" + k))
	lbl.text = RoomsI18n.t("mod_none") if lines.is_empty() else "\n".join(lines)


func update_admin_buttons_ui() -> void:
	var on_s := RoomsI18n.t("on")
	var off_s := RoomsI18n.t("off")
	if ui.has("adm_btn_god"):
		var b := ui["adm_btn_god"] as Button
		b.text = RoomsI18n.t("adm_god", [on_s if admin.god_mode else off_s])
		b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if admin.god_mode else Color(0.85, 0.88, 0.94))
	if ui.has("adm_btn_stamina"):
		var b := ui["adm_btn_stamina"] as Button
		b.text = RoomsI18n.t("adm_stam", [on_s if admin.inf_stamina else off_s])
		b.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if admin.inf_stamina else Color(0.85, 0.88, 0.94))
	if ui.has("adm_btn_noclip"):
		var b := ui["adm_btn_noclip"] as Button
		b.text = RoomsI18n.t("adm_noclip", [on_s if admin.noclip else off_s])
		b.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8) if admin.noclip else Color(0.85, 0.88, 0.94))
	if ui.has("adm_btn_speed"):
		var b := ui["adm_btn_speed"] as Button
		b.text = RoomsI18n.t("adm_speed", [admin.speed_mult])
		b.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if admin.speed_mult > 1.0 else Color(0.85, 0.88, 0.94))
	if ui.has("adm_btn_battery"):
		var b := ui["adm_btn_battery"] as Button
		b.text = RoomsI18n.t("adm_bat", [on_s if admin.inf_battery else off_s])
		b.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5) if admin.inf_battery else Color(0.85, 0.88, 0.94))
	if ui.has("adm_btn_timescale"):
		(ui["adm_btn_timescale"] as Button).text = RoomsI18n.t("adm_timescale", [Engine.time_scale])


func update_menu_players_list() -> void:
	var is_client := (net != null and net.is_online() and not net.is_host)
	if ui.has("btn_start_multi"):
		(ui["btn_start_multi"] as Control).visible = not is_client
	if ui.has("lbl_waiting_host"):
		(ui["lbl_waiting_host"] as Control).visible = is_client
	var lbl := ui.get("menu_players") as Label
	if lbl == null:
		return
	if net == null or not net.is_online():
		lbl.text = RoomsI18n.t("menu_you_waiting")
		return
	var names := net.get_member_names()
	if names.is_empty():
		lbl.text = RoomsI18n.t("menu_you")
	else:
		var lines: Array[String] = []
		for n in names:
			lines.append("• " + n)
		lbl.text = "\n".join(lines)


func sync_settings_ui() -> void:
	if ui.has("sld_master"):
		(ui["sld_master"] as HSlider).set_value_no_signal(settings.audio_master * 100.0)
	if ui.has("lbl_master"):
		(ui["lbl_master"] as Label).text = "%d%%" % int(round(settings.audio_master * 100.0))
	if ui.has("sld_entities"):
		(ui["sld_entities"] as HSlider).set_value_no_signal(settings.audio_entities * 100.0)
	if ui.has("lbl_entities"):
		(ui["lbl_entities"] as Label).text = "%d%%" % int(round(settings.audio_entities * 100.0))
	if ui.has("sld_sfx"):
		(ui["sld_sfx"] as HSlider).set_value_no_signal(settings.audio_sfx * 100.0)
	if ui.has("lbl_sfx"):
		(ui["lbl_sfx"] as Label).text = "%d%%" % int(round(settings.audio_sfx * 100.0))
	if ui.has("sld_ambient"):
		(ui["sld_ambient"] as HSlider).set_value_no_signal(settings.audio_ambient * 100.0)
	if ui.has("lbl_ambient"):
		(ui["lbl_ambient"] as Label).text = "%d%%" % int(round(settings.audio_ambient * 100.0))
	if ui.has("btn_mute_audio"):
		(ui["btn_mute_audio"] as Button).text = RoomsI18n.t("set_mute_on" if settings.audio_muted else "set_mute_off")
	if ui.has("sld_sens"):
		(ui["sld_sens"] as HSlider).set_value_no_signal(settings.mouse_sens_mult)
	if ui.has("lbl_sens"):
		(ui["lbl_sens"] as Label).text = "%.2fx" % settings.mouse_sens_mult
	if ui.has("sld_fov"):
		(ui["sld_fov"] as HSlider).set_value_no_signal(settings.base_fov)
	if ui.has("lbl_fov"):
		(ui["lbl_fov"] as Label).text = "%d°" % int(round(settings.base_fov))
	if ui.has("btn_head_bob"):
		(ui["btn_head_bob"] as Button).text = RoomsI18n.t("set_head_bob", [RoomsI18n.t("on" if settings.head_bob_enabled else "off")])


func refresh_render_buttons() -> void:
	if ui.has("btn_quality"):
		(ui["btn_quality"] as Button).text = RoomsI18n.t("set_quality", [settings.quality_label()])
	if ui.has("btn_backend"):
		var suf := " (*)" if settings.render_backend != settings.active_render_backend else ""
		(ui["btn_backend"] as Button).text = RoomsI18n.t("set_backend", [settings.backend_label(), suf])
	if ui.has("btn_restart_render"):
		(ui["btn_restart_render"] as Control).visible = (settings.render_backend != settings.active_render_backend)


func chat_toggle(open: bool) -> void:
	chat_open = open
	var edit := ui.get("chat_edit") as LineEdit
	if edit != null:
		edit.visible = open
		edit.editable = not chat_readonly
		edit.clear()
		if open:
			edit.grab_focus()
		else:
			edit.release_focus()


func chat_submit() -> void:
	if not chat_open:
		return
	var edit := ui.get("chat_edit") as LineEdit
	var txt := edit.text.strip_edges() if edit != null else ""
	chat_toggle(false)
	if txt.is_empty() or chat_readonly or net == null or not net.is_online():
		return
	chat_append(String(game.call("get_local_username")), txt)
	net.send_chat(txt)


func chat_append(who: String, text: String) -> void:
	var log := ui.get("chat_log") as RichTextLabel
	if log == null:
		return
	log.append_text("[color=#7fd4ff]%s[/color]: %s\n" % [who, text])
	if log.text.length() > 6000:
		log.text = log.text.substr(log.text.length() - 3000)


func chat_set_readonly(ro: bool) -> void:
	chat_readonly = ro
	var edit := ui.get("chat_edit") as LineEdit
	if edit != null:
		edit.editable = not ro
	if ro and chat_open:
		chat_toggle(false)
	var hint := ui.get("chat_hint") as Label
	if hint != null:
		hint.text = RoomsI18n.t("chat_readonly" if ro else "chat_hint")


func update_playing_hud(delta: float, hp: int, haste_timer: float, active_modifiers: Dictionary) -> void:
	var dmg := ui["dmg_flash"] as ColorRect
	if dmg.visible:
		dmg.color.a = maxf(dmg.color.a - delta * 1.4, 0.0)
		if dmg.color.a <= 0.004:
			dmg.visible = false

	var toast_ctrl := ui["toast"] as Control
	if toast_timer > 0.0:
		toast_timer = maxf(toast_timer - delta, 0.0)
	var want_toast := toast_timer > 0.45
	if want_toast or toast_alpha > 0.01:
		var rate := 8.5 if want_toast else 5.2
		toast_alpha = lerpf(toast_alpha, 1.0 if want_toast else 0.0, clampf(1.0 - exp(-rate * delta), 0.0, 1.0))
		toast_ctrl.modulate.a = toast_alpha
		toast_ctrl.offset_top = lerpf(-142.0, -158.0, toast_alpha)
		toast_ctrl.visible = (toast_alpha > 0.01 or toast_timer > 0.0)

	# Optimized vitals shader updates (zero per-frame array allocations, dirty-checked)
	var vitals_rect := ui["vitals_rect"] as ColorRect
	var vitals_mat := ui["vitals_mat"] as ShaderMaterial
	var smooth := clampf(delta * 6.0, 0.0, 1.0)
	var hp_t := 1.0 - clampf(float(hp) / 100.0, 0.0, 1.0)
	var st_t := 1.0 - clampf(player_ctrl.stamina, 0.0, 1.0)
	var ex_t := 1.0 if player_ctrl.exhausted else 0.0
	var dk_t := clampf(entities.darkness_whisper_t * 0.90 if entities.darkness_phase == 1 else (1.0 if entities.darkness_phase == 2 else 0.0), 0.0, 1.0)
	var next_v := Vector4(
		lerpf(maxf(_last_vitals.x, 0.0), hp_t, smooth),
		lerpf(maxf(_last_vitals.y, 0.0), st_t, smooth),
		lerpf(maxf(_last_vitals.z, 0.0), ex_t, smooth),
		lerpf(maxf(_last_vitals.w, 0.0), dk_t, smooth)
	)
	if (next_v - _last_vitals).length_squared() > 0.000004:
		_last_vitals = next_v
		vitals_mat.set_shader_parameter("hp_loss", next_v.x)
		vitals_mat.set_shader_parameter("stam_loss", next_v.y)
		vitals_mat.set_shader_parameter("exhausted_amt", next_v.z)
		vitals_mat.set_shader_parameter("darkness_amt", next_v.w)
	vitals_rect.visible = (maxf(maxf(next_v.x, next_v.y), maxf(next_v.z, next_v.w)) > 0.004)

	var haste_lbl := ui["haste_lbl"] as Label
	if bool(active_modifiers.get("make_haste", false)):
		haste_lbl.visible = true
		var t_sec := maxi(int(haste_timer), 0)
		if t_sec != _last_haste_sec:
			_last_haste_sec = t_sec
			haste_lbl.text = RoomsI18n.t("haste_time", [t_sec / 60, t_sec % 60])
			var col := Color(1.0, 0.22, 0.22) if haste_timer <= 15.0 else (Color(1.0, 0.75, 0.2) if haste_timer <= 30.0 else Color(0.9, 0.95, 1.0))
			haste_lbl.add_theme_color_override("font_color", col)
	elif haste_lbl.visible:
		haste_lbl.visible = false

	# Reticle & interaction prompt
	var prompt := ui["prompt_lbl"] as Label
	var want_prompt := false
	var vp_center := get_viewport().get_visible_rect().size * 0.5
	var cam := player_ctrl.cam

	if player_ctrl.is_hiding:
		interact_ctrl.smart_reticle_target = {}
		if reticle_ring != null:
			reticle_ring.visible = false
		if not player_ctrl.is_action_locked():
			if player_ctrl.hiding_kind == "under_desk":
				prompt.text = RoomsI18n.t("prompt_exit_desk")
			elif player_ctrl.hiding_kind == "fridge":
				prompt.text = RoomsI18n.t("prompt_exit_fridge")
			else:
				prompt.text = RoomsI18n.t("prompt_exit_locker")
			want_prompt = true
	else:
		var interact_tgt := {} if player_ctrl.is_action_locked() else interact_ctrl.find_smart_reticle_target()
		interact_ctrl.smart_reticle_target = interact_tgt
		var yaw_lag := wrapf(player_ctrl.target_yaw - player_ctrl.yaw, -PI, PI)
		var pitch_lag := player_ctrl.target_pitch - player_ctrl.pitch
		var desired_lag := Vector2(clampf(yaw_lag * 360.0, -48.0, 48.0), clampf(pitch_lag * 300.0, -36.0, 36.0))
		reticle_lag_offset = reticle_lag_offset.lerp(desired_lag, clampf(1.0 - exp(-12.5 * delta), 0.0, 1.0))

		var tgt_r := 6.5
		var tgt_stroke := 1.9
		var tgt_pos := vp_center + reticle_lag_offset
		if not interact_tgt.is_empty():
			tgt_r = 19.5
			tgt_stroke = 2.8
			if interact_tgt.has("world_pos"):
				var wp: Vector3 = interact_tgt["world_pos"]
				if not cam.is_position_behind(wp):
					tgt_pos = cam.unproject_position(wp)
			prompt.text = String(interact_tgt["label"])
			want_prompt = (not settings.mobile_controls_enabled) and not String(interact_tgt["label"]).is_empty()

		if reticle_ring != null:
			reticle_ring.visible = true
			if reticle_screen_pos == Vector2.ZERO:
				reticle_screen_pos = tgt_pos
			reticle_screen_pos = reticle_screen_pos.lerp(tgt_pos, clampf(1.0 - exp(-10.5 * delta), 0.0, 1.0))
			var prev_r := reticle_radius
			reticle_radius = lerpf(reticle_radius, tgt_r, clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			reticle_ring.ring_radius = reticle_radius
			reticle_ring.stroke_width = lerpf(reticle_ring.stroke_width, tgt_stroke, clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			reticle_ring.position = reticle_screen_pos - reticle_ring.size * 0.5
			if absf(reticle_radius - prev_r) > 0.02:
				reticle_ring.queue_redraw()

	var pr_rate := 12.0 if want_prompt else 8.5
	if want_prompt or prompt_alpha > 0.005:
		prompt_alpha = lerpf(prompt_alpha, 1.0 if want_prompt else 0.0, clampf(1.0 - exp(-pr_rate * delta), 0.0, 1.0))
		prompt.modulate.a = prompt_alpha

	_update_mobile_ui()


func _update_mobile_ui() -> void:
	if not settings.mobile_controls_enabled:
		return
	var b_fwd := ui["m_btn_exit_fwd"] as RoomsUI.RingButton
	var b_back := ui["m_btn_exit_back"] as RoomsUI.RingButton
	var b_sprint := ui["m_btn_sprint"] as RoomsUI.RingButton
	var b_light := ui["m_btn_light"] as RoomsUI.RingButton
	var b_gummy := ui["m_btn_gummy"] as RoomsUI.RingButton
	var b_reload := ui["m_btn_reload"] as Control
	if player_ctrl.is_hiding:
		b_light.visible = (player_ctrl.active_tool == 1)
		b_sprint.visible = false
		b_gummy.visible = false
		b_reload.visible = false
		b_fwd.visible = true
		b_back.visible = (player_ctrl.hiding_kind != "under_desk")
	else:
		b_fwd.visible = false
		b_back.visible = false
		b_light.visible = true
		b_sprint.visible = true
		b_gummy.visible = player_ctrl.has_gummy
		b_reload.visible = (player_ctrl.batteries >= 2 and player_ctrl.std_battery < 149.9)
