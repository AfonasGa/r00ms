extends "res://scripts/rooms/rooms_core.gd"

func _load_entity_sprites() -> void:
	_a60_frames.clear()
	for i in range(1, 26):
		var path := "res://assets/sprites/a60/a60_%d.png" % i
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_a60_frames.append(tex)
	if _a60_frames.is_empty():
		var fallback60 := RoomsTextures.make_a60_frames()
		for ft in fallback60:
			_a60_frames.append(ft)

	_a120_frames.clear()
	for fname in ["a120smiley.png", "a120smiley1.png"]:
		var path := "res://assets/sprites/a120/%s" % fname
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_a120_frames.append(tex)
	if _a120_frames.is_empty():
		var fallback120 := RoomsTextures.make_a120_frames()
		for ft in fallback120:
			_a120_frames.append(ft)

	_a90_textures = RoomsTextures.make_a90_textures()
	var spawn_tex := _try_load_tex("res://assets/sprites/paralysis/paralysis_spawn.webp")
	var pre_tex := _try_load_tex("res://assets/sprites/paralysis/paralysis-prejumpscareORdespawn.webp")
	var scare_tex := _try_load_tex("res://assets/sprites/paralysis/paralysis-jumpscare.webp")
	var stop_tex := _try_load_tex("res://assets/sprites/paralysis/stopsign.webp")
	if spawn_tex != null:
		_a90_textures["warn"] = spawn_tex
	if pre_tex != null:
		_a90_textures["pre"] = pre_tex
	if scare_tex != null:
		_a90_textures["rage"] = scare_tex
	if stop_tex != null:
		_a90_textures["stopsign"] = stop_tex
	_darkness_tex = _try_load_tex("res://assets/sprites/darkness/darkness_eye.webp")
	if ResourceLoader.exists("res://assets/models/player/roblox_noob/roblox_noob.gltf"):
		_noob_scene = load("res://assets/models/player/roblox_noob/roblox_noob.gltf") as PackedScene
	_prepare_noob_parts()


func _try_load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null


func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.get_name() in ["Android", "iOS"]


func _detect_active_render_backend() -> String:
	var rs := RenderingServer
	if rs != null and rs.has_method("get_current_rendering_method"):
		var cur := String(rs.call("get_current_rendering_method"))
		if not cur.is_empty():
			return cur
	if _is_mobile_platform():
		return String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "mobile"))
	return String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))


func _load_render_settings() -> void:
	_active_render_backend = _detect_active_render_backend()
	_render_backend = _active_render_backend
	_render_quality = RenderQuality.MOBILE_OPT if _is_mobile_platform() else RenderQuality.HIGH

	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_render_quality = clampi(int(cfg.get_value("graphics", "quality", _render_quality)), RenderQuality.MOBILE_OPT, RenderQuality.HIGH)
		_audio_master = clampf(float(cfg.get_value("audio", "master", 0.75)), 0.0, 1.0)
		_audio_entities = clampf(float(cfg.get_value("audio", "entities", 1.0)), 0.0, 1.0)
		_audio_sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
		_audio_ambient = clampf(float(cfg.get_value("audio", "ambient", 1.0)), 0.0, 1.0)
		_audio_muted = bool(cfg.get_value("audio", "muted", false))
		_mouse_sens_mult = clampf(float(cfg.get_value("controls", "sensitivity", 1.0)), 0.4, 2.2)
		_base_fov = clampf(float(cfg.get_value("controls", "fov", 75.0)), 65.0, 95.0)
		_head_bob_enabled = bool(cfg.get_value("controls", "head_bob", true))

	var ov := ConfigFile.new()
	if ov.load(OVERRIDE_PATH) == OK:
		var saved_b := String(ov.get_value("rendering", "renderer/rendering_method", ""))
		if saved_b in ["forward_plus", "mobile", "gl_compatibility"]:
			_render_backend = saved_b


func _save_render_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("graphics", "quality", _render_quality)
	cfg.set_value("audio", "master", _audio_master)
	cfg.set_value("audio", "entities", _audio_entities)
	cfg.set_value("audio", "sfx", _audio_sfx)
	cfg.set_value("audio", "ambient", _audio_ambient)
	cfg.set_value("audio", "muted", _audio_muted)
	cfg.set_value("controls", "sensitivity", _mouse_sens_mult)
	cfg.set_value("controls", "fov", _base_fov)
	cfg.set_value("controls", "head_bob", _head_bob_enabled)
	cfg.save(SETTINGS_PATH)


func _apply_audio_settings(save_cfg: bool = true) -> void:
	if audio != null:
		audio.muted = _audio_muted
		audio.master_volume = _audio_master
		audio.entity_volume = _audio_entities
		audio.sfx_volume = _audio_sfx
		audio.ambient_volume = _audio_ambient
		audio.apply_volume_settings()
	if save_cfg:
		_save_render_settings()


func _reset_audio_defaults() -> void:
	_audio_master = 0.75
	_audio_entities = 1.0
	_audio_sfx = 1.0
	_audio_ambient = 1.0
	_audio_muted = false
	_apply_audio_settings(true)
	_sync_settings_ui()
	_show_toast("Громкость сброшена по умолчанию", 1.8)


func _open_settings_panel(open: bool) -> void:
	if _ui.has("m_main_box"):
		(_ui["m_main_box"] as Control).visible = not open
	if _ui.has("m_settings_scroll"):
		(_ui["m_settings_scroll"] as Control).visible = open
	if _ui.has("m_brand"):
		(_ui["m_brand"] as Control).visible = not open
	if not open and _settings_from_menu:
		_settings_from_menu = false
		if _ui.has("modal"):
			(_ui["modal"] as Control).visible = false
		if _ui.has("m_title"):
			(_ui["m_title"] as Control).visible = false
		if _ui.has("m_desc"):
			(_ui["m_desc"] as Control).visible = false
		if _ui.has("main_menu"):
			(_ui["main_menu"] as Control).visible = true
		return
	if _ui.has("m_title") and _ui.has("m_desc") and (_state == State.PAUSED or _state == State.MENU):
		var title: Label = _ui["m_title"]
		var desc: Label = _ui["m_desc"]
		title.visible = false
		desc.visible = false


func _pause_summary_text() -> String:
	var mins := int(_run_time) / 60
	var secs := int(_run_time) % 60
	var deaths := 0
	if _architect != null:
		deaths = _architect.deaths_total
	return "A-%03d  ·  %02d:%02d  ·  смертей: %d\nПереживите A-60, A-90 и A-120 до комнаты A-200." % [
		_highest_opened, mins, secs, deaths
	]


func _sync_settings_ui() -> void:
	if _ui.has("sld_master"):
		(_ui["sld_master"] as HSlider).set_value_no_signal(_audio_master * 100.0)
	if _ui.has("lbl_master"):
		(_ui["lbl_master"] as Label).text = "%d%%" % int(round(_audio_master * 100.0))
	if _ui.has("sld_entities"):
		(_ui["sld_entities"] as HSlider).set_value_no_signal(_audio_entities * 100.0)
	if _ui.has("lbl_entities"):
		(_ui["lbl_entities"] as Label).text = "%d%%" % int(round(_audio_entities * 100.0))
	if _ui.has("sld_sfx"):
		(_ui["sld_sfx"] as HSlider).set_value_no_signal(_audio_sfx * 100.0)
	if _ui.has("lbl_sfx"):
		(_ui["lbl_sfx"] as Label).text = "%d%%" % int(round(_audio_sfx * 100.0))
	if _ui.has("sld_ambient"):
		(_ui["sld_ambient"] as HSlider).set_value_no_signal(_audio_ambient * 100.0)
	if _ui.has("lbl_ambient"):
		(_ui["lbl_ambient"] as Label).text = "%d%%" % int(round(_audio_ambient * 100.0))
	if _ui.has("btn_mute_audio"):
		(_ui["btn_mute_audio"] as Button).text = "Звук: ВЫКЛ [M]" if _audio_muted else "Звук: ВКЛ [M]"
	if _ui.has("sld_sens"):
		(_ui["sld_sens"] as HSlider).set_value_no_signal(_mouse_sens_mult)
	if _ui.has("lbl_sens"):
		(_ui["lbl_sens"] as Label).text = "%.2fx" % _mouse_sens_mult
	if _ui.has("sld_fov"):
		(_ui["sld_fov"] as HSlider).set_value_no_signal(_base_fov)
	if _ui.has("lbl_fov"):
		(_ui["lbl_fov"] as Label).text = "%d°" % int(round(_base_fov))
	if _ui.has("btn_head_bob"):
		(_ui["btn_head_bob"] as Button).text = "Покачивание камеры: %s" % ("ВКЛ" if _head_bob_enabled else "ВЫКЛ")


func _quality_label(q: int) -> String:
	if q == RenderQuality.MOBILE_OPT:
		return "Мобильный FPS"
	if q == RenderQuality.MEDIUM:
		return "Средний"
	return "Высокий"


func _backend_label(b: String) -> String:
	if b == "mobile":
		return "Mobile (Vulkan/Metal)"
	if b == "gl_compatibility":
		return "Compatibility (OpenGL)"
	return "Forward+ (PC)"


func _apply_render_quality(q: int, save_cfg: bool = true) -> void:
	_render_quality = clampi(q, RenderQuality.MOBILE_OPT, RenderQuality.HIGH)
	var vp := get_viewport()
	var env := world_env.environment
	if _render_quality == RenderQuality.MOBILE_OPT:
		_room_vis_radius = 3
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.72
		if flashlight != null:
			flashlight.shadow_enabled = false
		if cam != null:
			cam.far = 78.0
		if env != null:
			env.ssao_enabled = false
			env.glow_enabled = false
			env.fog_enabled = false
	elif _render_quality == RenderQuality.MEDIUM:
		_room_vis_radius = 5
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.88
		if flashlight != null:
			flashlight.shadow_enabled = true
		if cam != null:
			cam.far = 65.0
		if env != null:
			env.ssao_enabled = false
			env.glow_enabled = true
			env.fog_enabled = true
	else:
		_room_vis_radius = 7
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
		if flashlight != null:
			flashlight.shadow_enabled = true
		if cam != null:
			cam.far = 85.0
		if env != null:
			env.ssao_enabled = true
			env.glow_enabled = true
			env.fog_enabled = true

	_update_room_visibility()
	if save_cfg:
		_save_render_settings()
	_refresh_render_buttons()


func _cycle_render_quality() -> void:
	var nxt := (_render_quality + 1) % 3
	_apply_render_quality(nxt, true)
	_show_toast("Качество рендера: %s" % _quality_label(_render_quality), 2.2)


func _set_render_backend(backend: String) -> void:
	if not (backend in ["forward_plus", "mobile", "gl_compatibility"]):
		return
	_render_backend = backend
	var ov := ConfigFile.new()
	ov.load(OVERRIDE_PATH)
	ov.set_value("rendering", "renderer/rendering_method", backend)
	ov.set_value("rendering", "renderer/rendering_method.mobile", backend)
	ov.save(OVERRIDE_PATH)
	_refresh_render_buttons()
	if backend != _active_render_backend:
		_show_toast("Бэкенд: %s — перезапустите игру для применения" % _backend_label(backend), 3.0)
	else:
		_show_toast("Активный бэкенд: %s" % _backend_label(backend), 2.0)


func _cycle_render_backend() -> void:
	var order: Array[String] = ["forward_plus", "mobile", "gl_compatibility"]
	var idx := order.find(_render_backend)
	var nxt: String = order[(idx + 1) % order.size()]
	_set_render_backend(nxt)


func _restart_for_render() -> void:
	if _is_mobile_platform():
		_show_toast("Закройте и откройте приложение заново", 3.0)
	else:
		# Tear Steam down cleanly first: leaving rich presence / an invite dialog
		# alive while relaunching makes the overlay pop up on the next boot.
		if _net != null:
			_net.disconnect_session()
			_net.shutdown_steam()
		OS.set_restart_on_exit(true)
		get_tree().quit()


func _refresh_render_buttons() -> void:
	if _ui.has("btn_quality"):
		(_ui["btn_quality"] as Button).text = "Рендер / Графика: %s" % _quality_label(_render_quality)
	if _ui.has("btn_backend"):
		var suffix := " (*)" if _render_backend != _active_render_backend else ""
		(_ui["btn_backend"] as Button).text = "Бэкенд: %s%s" % [_backend_label(_render_backend), suffix]
	if _ui.has("btn_restart_render"):
		(_ui["btn_restart_render"] as Control).visible = (_render_backend != _active_render_backend)


func _update_room_visibility() -> void:
	for r in _rooms:
		if is_instance_valid(r.root):
			r.root.visible = (abs(r.index - _current_room_idx) <= _room_vis_radius)


func _setup_environment() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if _render_quality != RenderQuality.HIGH else Viewport.MSAA_2X
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.007, 0.011)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.065, 0.095)
	env.ambient_light_energy = 0.11
	env.fog_enabled = (_render_quality != RenderQuality.MOBILE_OPT)
	env.fog_light_color = Color(0.008, 0.011, 0.018)
	env.fog_density = 0.032
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = (_render_quality == RenderQuality.HIGH)
	env.ssao_radius = 0.85
	env.ssao_intensity = 1.65
	env.ssao_power = 1.6
	env.glow_enabled = (_render_quality != RenderQuality.MOBILE_OPT)
	env.glow_intensity = 0.62
	env.glow_bloom = 0.24
	env.glow_hdr_threshold = 0.90
	world_env.environment = env


func _build_viewmodel() -> void:
	_vm_bulb_on_mat = StandardMaterial3D.new()
	_vm_bulb_on_mat.albedo_color = Color(1.0, 0.96, 0.86)
	_vm_bulb_on_mat.emission_enabled = true
	_vm_bulb_on_mat.emission = Color(1.0, 0.95, 0.82)
	_vm_bulb_on_mat.emission_energy_multiplier = 2.4

	_vm_bulb_off_mat = StandardMaterial3D.new()
	_vm_bulb_off_mat.albedo_color = Color(0.22, 0.24, 0.28)
	_vm_bulb_off_mat.roughness = 0.25

	_vm_gummy_on_mat = StandardMaterial3D.new()
	_vm_gummy_on_mat.albedo_color = Color(0.32, 1.0, 0.52)
	_vm_gummy_on_mat.emission_enabled = true
	_vm_gummy_on_mat.emission = Color(0.28, 1.0, 0.48)
	_vm_gummy_on_mat.emission_energy_multiplier = 2.6

	_vm_holder = Node3D.new()
	_vm_holder.position = Vector3(0.24, -0.21, -0.34)
	cam.add_child(_vm_holder)

	# Standard tactical metal flashlight model
	_vm_std = Node3D.new()
	_vm_holder.add_child(_vm_std)
	var body := RoomBuilder._add_cyl(_vm_std, "StdBody", Vector3.ZERO, 0.024, 0.22, _assets.locker_mat)
	body.rotation.x = PI * 0.5
	var grip := RoomBuilder._add_cyl(_vm_std, "StdGrip", Vector3(0.0, 0.0, 0.02), 0.026, 0.11, _assets.ceiling_mat)
	grip.rotation.x = PI * 0.5
	var head := RoomBuilder._add_cyl(_vm_std, "StdBezel", Vector3(0.0, 0.0, -0.12), 0.034, 0.055, _assets.metal_mat)
	head.rotation.x = PI * 0.5
	_vm_std_bulb = RoomBuilder._add_cyl(_vm_std, "StdLens", Vector3(0.0, 0.0, -0.148), 0.028, 0.008, _vm_bulb_on_mat)
	_vm_std_bulb.rotation.x = PI * 0.5
	RoomBuilder._add_box(_vm_std, "StdBtn", Vector3(0.0, 0.025, -0.04), Vector3(0.016, 0.012, 0.024), _assets.medkit_mat, false)

	# Emerald Gummy / Shaker Flashlight model (no crank, shaken directly)
	_vm_gummy = Node3D.new()
	_vm_gummy.visible = false
	_vm_holder.add_child(_vm_gummy)
	RoomBuilder._add_box(_vm_gummy, "GumBody", Vector3.ZERO, Vector3(0.068, 0.068, 0.19), _assets.gummy_mat, false)
	RoomBuilder._add_box(_vm_gummy, "GumGrip", Vector3(0.0, -0.015, 0.02), Vector3(0.072, 0.045, 0.11), _assets.locker_mat, false)
	var gum_head := RoomBuilder._add_cyl(_vm_gummy, "GumHead", Vector3(0.0, 0.0, -0.11), 0.040, 0.05, _assets.fridge_mat)
	gum_head.rotation.x = PI * 0.5
	_vm_gummy_bulb = RoomBuilder._add_cyl(_vm_gummy, "GumLens", Vector3(0.0, 0.0, -0.136), 0.032, 0.008, _vm_gummy_on_mat)
	_vm_gummy_bulb.rotation.x = PI * 0.5

	# Roblox Noob R6 First-Person Right Arm for opening & closing lockers and fridges
	_anim_hand = Node3D.new()
	_anim_hand.name = "LockerHand"
	_anim_hand.visible = false
	cam.add_child(_anim_hand)
	if bool(_noob_parts.get("ready", false)):
		var meshes: Dictionary = _noob_parts["meshes"]
		var arm_mesh := meshes.get("arm_r") as ArrayMesh
		if arm_mesh != null:
			var mi_arm := MeshInstance3D.new()
			mi_arm.name = "NoobArmR"
			mi_arm.mesh = arm_mesh
			mi_arm.material_override = _noob_parts.get("hand_mat") as Material
			mi_arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi_arm.extra_cull_margin = 16384.0
			mi_arm.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			mi_arm.scale = Vector3(0.32, 0.80, 0.32)
			_anim_hand.add_child(mi_arm)
	if _anim_hand.get_child_count() == 0:
		var noob_arm_mat := StandardMaterial3D.new()
		noob_arm_mat.albedo_color = Color(0.96, 0.80, 0.22)
		noob_arm_mat.roughness = 0.52
		noob_arm_mat.emission_enabled = true
		noob_arm_mat.emission = Color(0.96, 0.80, 0.22)
		noob_arm_mat.emission_energy_multiplier = 0.12
		RoomBuilder._add_box(_anim_hand, "NoobArmR", Vector3(0.0, 0.0, -0.24), Vector3(0.11, 0.11, 0.52), noob_arm_mat, false)

	_held_battery = Node3D.new()
	_held_battery.name = "HeldBattery"
	_held_battery.visible = false
	_held_battery.position = Vector3(0.02, 0.05, -0.28)
	_held_battery.rotation = Vector3(0.35, 0.15, 0.45)
	_anim_hand.add_child(_held_battery)
	RoomBuilder._add_cyl(_held_battery, "Cell", Vector3.ZERO, 0.032, 0.11, _assets.locker_mat)
	RoomBuilder._add_cyl(_held_battery, "GlowBand", Vector3(0.0, 0.02, 0.0), 0.034, 0.028, _assets.battery_mat)
	RoomBuilder._add_cyl(_held_battery, "TopCap", Vector3(0.0, 0.052, 0.0), 0.033, 0.016, _assets.plaque_yellow_mat)
	RoomBuilder._add_cyl(_held_battery, "Nub", Vector3(0.0, 0.065, 0.0), 0.012, 0.012, _assets.fridge_mat)


func _build_entity_nodes() -> void:
	_a60_node = Node3D.new()
	_a60_node.visible = false
	add_child(_a60_node)

	_a60_sprite = Sprite3D.new()
	_a60_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_a60_sprite.shaded = false
	_a60_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_a60_sprite.texture = _a60_frames[0]
	_a60_sprite.pixel_size = 2.65 / float(maxi(_a60_frames[0].get_width(), 1))
	_a60_sprite.modulate = Color(1.0, 0.94, 0.94)
	_a60_node.add_child(_a60_sprite)

	_a60_light = OmniLight3D.new()
	_a60_light.light_color = Color(1.0, 0.14, 0.12)
	_a60_light.light_energy = 4.8
	_a60_light.omni_range = 15.0
	_a60_node.add_child(_a60_light)

	_a120_node = Node3D.new()
	_a120_node.visible = false
	add_child(_a120_node)

	_a120_sprite = Sprite3D.new()
	_a120_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_a120_sprite.shaded = false
	_a120_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_a120_sprite.texture = _a120_frames[0]
	_a120_sprite.pixel_size = 2.55 / float(maxi(_a120_frames[0].get_width(), 1))
	_a120_node.add_child(_a120_sprite)

	var a120_light := OmniLight3D.new()
	a120_light.light_color = Color(0.65, 0.90, 1.0)
	a120_light.light_energy = 3.2
	a120_light.omni_range = 11.0
	_a120_node.add_child(a120_light)
