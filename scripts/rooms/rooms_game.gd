extends Node3D

## Rooms-inspired 3D procedural horror runner (A-000 -> A-200+ Endless) inside Godot 4.7.

enum State { PLAYING, PAUSED, DEAD, VICTORY }
enum RenderQuality { MOBILE_OPT, MEDIUM, HIGH }

const SETTINGS_PATH := "user://rooms_settings.cfg"
const OVERRIDE_PATH := "user://override.cfg"

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var rooms_container: Node3D = $RoomsContainer
@onready var player_body: CharacterBody3D = $PlayerBody
@onready var player_col: CollisionShape3D = $PlayerBody/CollisionShape3D
@onready var cam: Camera3D = $PlayerBody/Camera3D
@onready var flashlight: SpotLight3D = $PlayerBody/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $PlayerBody/Camera3D/InteractRay
@onready var audio: RoomsAudio = $RoomsAudio
@onready var ui_layer: CanvasLayer = $UILayer

var _assets: RoomBuilder.SharedAssets
var _rng := RandomNumberGenerator.new()

var _rooms: Array[RoomBuilder.RoomInstance] = []
var _room_by_idx: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _next_cell := Vector2i.ZERO
var _next_in_dir := Vector3(0.0, 0.0, -1.0)
var _next_room_index := 0
var _highest_opened := 0
var _current_room_idx := 0

var _state: State = State.PLAYING
var _hp := 100
var _stamina := 1.0
var _stamina_regen_delay := 0.0
var _exhausted := false
var _pant_timer := 0.0
var _pant_inhale := false
var _run_time := 0.0
var _victory_reached := false
var _checkpoint_room := 0

var _architect := RoomsArchitect.new()

# Smooth eased camera & movement
var _target_yaw := 0.0
var _target_pitch := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _cam_roll := 0.0
var _fov := 75.0
var _step_timer := 0.0
var _bob_phase := 0.0
var _shake_amount := 0.0

# Locker hiding & eased camera transition
var _is_hiding := false
var _hiding_room_idx := -1
var _hiding_locker_idx := -1
var _locker_fwd := Vector3.FORWARD
var _locker_eye := Vector3.ZERO
var _locker_exit := Vector3.ZERO
var _target_hide_yaw := 0.0
var _target_hide_pitch := 0.0
var _hide_yaw_offset := 0.0
var _hide_pitch_offset := 0.0
var _hide_time := 0.0
var _locker_blend := 0.0
var _locker_transition_t := 1.0
var _locker_transition_entering := false
var _locker_transition_duration := 1.00
var _locker_exit_face_locker := false
var _locker_exit_from_yaw := 0.0
var _locker_exit_to_yaw := 0.0
var _locker_cam_from := Vector3.ZERO
var _hiding_kind := "locker"
var _hiding_door_pivot: Node3D = null
var _hiding_eye_local_y := 1.48
var _locker_enter_from_yaw := 0.0

# Viewmodel & Power
var _power_out := false
var _vm_holder: Node3D = null
var _vm_std: Node3D = null
var _vm_gummy: Node3D = null
var _vm_std_bulb: MeshInstance3D = null
var _vm_gummy_bulb: MeshInstance3D = null
var _vm_shake_time := 0.0
var _gummy_hold_accum := 0.0
var _vm_bulb_on_mat: StandardMaterial3D
var _vm_bulb_off_mat: StandardMaterial3D
var _vm_gummy_on_mat: StandardMaterial3D
var _anim_hand: Node3D = null

# Flashlights
var _light_on := true
var _active_tool := 0 # 0 = standard, 1 = gummy
var _has_gummy := false
var _std_battery := 100.0
var _gummy_battery := 100.0
var _was_light_before_hide := true
var _std_low_power := false
var _std_low_power_regen := 0.0

# Entities
var _a60_frames: Array[Texture2D] = []
var _a90_textures: Dictionary = {}
var _a120_frames: Array[Texture2D] = []
var _darkness_tex: Texture2D = null

var _a60_active := false
var _a60_phase := 0 # 0=idle, 2=rush, 3=sink
var _a60_is_prime := false
var _a60_prime_rebounds := 0
var _a60_node: Node3D = null
var _a60_sprite: Sprite3D = null
var _a60_light: OmniLight3D = null
var _a60_hint_timer := 0.0
var _a60_random_timer := 28.0
var _a60_sink_timer := 0.0
var _a60_path: Array[Vector3] = []
var _a60_path_idx := 0
var _a60_target_door_idx := 0
var _a60_anim_timer := 0.0
var _a60_frame_idx := 0
var _a60_scare_snd_cd := 0.0
var _a60_last_tex: Texture2D = null

var _a120_active := false
var _a120_phase := 0 # 0=idle, 1=spawn_warning, 2=attack_rebound
var _a120_substage := 0 # 0=rush_to_player, 1=go_to_previous_room
var _a120_node: Node3D = null
var _a120_sprite: Sprite3D = null
var _a120_warn_timer := 0.0
var _a120_pause_timer := 0.0
var _a120_path: Array[Vector3] = []
var _a120_path_idx := 0
var _a120_rebounds := 0
var _a120_initial_rebounds := 0
var _a120_drum_bounce := 0.0
var _a120_anim_timer := 0.0
var _a120_frame_idx := 0
var _a120_hit_cd := 0.0

var _darkness_phase := 0 # 0=idle, 1=whispering, 2=attacking
var _darkness_whisper_t := 0.0
var _darkness_dmg_accum := 0.0
var _darkness_quick_return := false

var _a90_phase := 0 # 0=idle, 1=warn, 2=freeze_check, 3=despawn_flash
var _a90_timer := 0.0
var _a90_cooldown := 14.0
var _a90_start_pos := Vector3.ZERO
var _a90_start_yaw := 0.0
var _a90_start_pitch := 0.0
var _a90_pos_offset := Vector2.ZERO
var _a90_scare_timer := 0.0

# Architect dialogue playback
var _arch_lines: Array[String] = []
var _arch_line_idx := 0
var _arch_char_pos := 0.0
var _arch_blip_acc := 0

# Door swing animations
var _opening_doors: Array[Dictionary] = []

# UI refs & Smart Reticle
var _ui := {}
var _toast_timer := 0.0
var _toast_alpha := 0.0
var _prompt_alpha := 0.0
var _reminder_alpha := 0.0
var _reticle_ring: RoomsUI.ReticleRing = null
var _reticle_screen_pos := Vector2.ZERO
var _reticle_lag_offset := Vector2.ZERO
var _reticle_radius := 6.5
var _smart_reticle_target: Dictionary = {}
var _reminder_dismissed := false

# Render quality & backend selection
var _render_quality: int = RenderQuality.HIGH
var _room_vis_radius := 7
var _render_backend := "forward_plus"
var _active_render_backend := "forward_plus"

# Mobile multitouch controls
var _mobile_controls_enabled := false
var _mobile_override := 0 # 0=auto, 1=force on, -1=force off
var _joy_touch_id := -1
var _look_touch_id := -1
var _tap_touch_id := -1
var _tap_start_pos := Vector2.ZERO
var _tap_start_time_ms := 0
var _joy_origin := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _joy_sprint := false
var _mobile_sprint_held := false
var _mobile_gummy_held := false
var _joy_ring: Panel = null
var _joy_knob: Panel = null
var _mobile_btns: Array[Control] = []

# Online Multiplayer (Steam Spacewar 480 + ENet)
var _net: RoomsNet = null
var _remote_players: Dictionary = {}
var _lobby_list_box: VBoxContainer = null


func _ready() -> void:
	_assets = RoomBuilder.create_shared_assets()
	_load_entity_sprites()

	_load_render_settings()
	_setup_environment()
	_build_entity_nodes()
	_build_viewmodel()
	_build_net()
	_build_ui()
	_apply_render_quality(_render_quality, false)
	_refresh_mobile_mode()
	_reset_run()


func _build_net() -> void:
	_net = RoomsNet.new()
	_net.name = "RoomsNet"
	add_child(_net)
	_net.status_changed.connect(func(txt: String) -> void:
		if _ui.has("net_status"):
			(_ui["net_status"] as Label).text = txt
	)
	_net.lobbies_updated.connect(_on_net_lobbies_updated)
	_net.state_received.connect(_on_remote_state)
	_net.door_opened_remote.connect(_on_remote_door_opened)
	_net.peer_disconnected.connect(_on_remote_peer_disconnected)
	_net.invite_received.connect(func(inviter_name: String, _lid: int) -> void:
		_show_toast("Steam: приглашение от %s! Примите в Shift+Tab" % inviter_name, 4.0)
	)
	_net.session_synced.connect(_on_net_session_synced)


func _on_net_session_synced(seed_val: int, room_idx: int) -> void:
	if seed_val != 0 and int(_rng.seed) != seed_val and _highest_opened <= 1 and not _is_hiding:
		_reset_run(seed_val)
	if room_idx > _highest_opened:
		for idx in range(_highest_opened, room_idx):
			var r: RoomBuilder.RoomInstance = _room_by_idx.get(idx)
			if r != null and not r.door_opened:
				_open_room_door(idx, true)
	_show_toast("Синхронизация с Steam-лобби (A-%03d)" % room_idx, 2.8)


func _on_net_lobbies_updated(lobbies: Array) -> void:
	if _lobby_list_box == null:
		return
	for ch in _lobby_list_box.get_children():
		ch.queue_free()
	if lobbies.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Другие лобби не найдены. Нажмите «Пригласить (Shift+Tab)»."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
		_lobby_list_box.add_child(empty_lbl)
		return
	for raw_item in lobbies:
		var item: Dictionary = raw_item
		var lid := int(item.get("id", 0))
		var lname := String(item.get("name", "Lobby"))
		var members := int(item.get("members", 1))
		var is_friend := bool(item.get("is_friend", false))
		var is_self := bool(item.get("is_self", false))
		var btn := Button.new()
		if is_self:
			btn.text = "%s (%d чел.) [Ваше лобби]" % [lname, members]
			btn.disabled = true
			RoomsUI.style_button(btn, Color(0.60, 0.68, 0.78), 11)
		else:
			var tag := "[ДРУГ] " if is_friend else ""
			btn.text = "Войти: %s%s (%d чел.)" % [tag, lname, members]
			RoomsUI.style_button(btn, Color(0.35, 1.0, 0.62) if is_friend else Color(0.45, 0.88, 1.0), 12)
			btn.pressed.connect(func() -> void:
				if _net != null:
					_net.join_steam_lobby(lid)
			)
		_lobby_list_box.add_child(btn)


func _on_remote_door_opened(room_index: int) -> void:
	for idx in range(maxi(room_index - 1, 0), room_index + 1):
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(idx)
		if r != null and not r.door_opened:
			_open_room_door(idx, true)


func _on_remote_peer_disconnected(peer_key: String) -> void:
	if _remote_players.has(peer_key):
		var rp: Dictionary = _remote_players[peer_key]
		var node: Variant = rp.get("node")
		if node is Node3D and is_instance_valid(node):
			(node as Node3D).queue_free()
		_remote_players.erase(peer_key)


func _on_remote_state(peer_key: String, msg: Dictionary) -> void:
	var rp: Dictionary
	if _remote_players.has(peer_key):
		rp = _remote_players[peer_key]
	else:
		var root_node := Node3D.new()
		root_node.name = "Remote_" + peer_key
		add_child(root_node)
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.16, 0.45, 0.72)
		body_mat.roughness = 0.55
		var torso := RoomBuilder._add_cyl(root_node, "Torso", Vector3(0.0, 0.92, 0.0), 0.24, 1.15, body_mat)
		torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = Color(0.82, 0.72, 0.62)
		var head := RoomBuilder._add_box(root_node, "Head", Vector3(0.0, 1.66, 0.0), Vector3(0.32, 0.34, 0.32), head_mat, false)
		RoomBuilder._add_box(head, "Visor", Vector3(0.0, 0.02, -0.17), Vector3(0.24, 0.08, 0.04), _vm_bulb_on_mat, false)
		var name_lbl := Label3D.new()
		name_lbl.position = Vector3(0.0, 2.08, 0.0)
		name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_lbl.font_size = 30
		name_lbl.pixel_size = 0.004
		name_lbl.modulate = Color(0.75, 0.94, 1.0)
		name_lbl.text = String(msg.get("n", "Player"))
		root_node.add_child(name_lbl)
		var spot := SpotLight3D.new()
		spot.position = Vector3(0.22, 1.38, -0.18)
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 1.8
		spot.spot_range = 16.0
		spot.spot_angle = 36.0
		root_node.add_child(spot)
		rp = {
			"node": root_node,
			"head": head,
			"spot": spot,
			"lbl": name_lbl,
			"tgt_pos": Vector3.ZERO,
			"tgt_yaw": 0.0,
			"tgt_pitch": 0.0,
		}
		_remote_players[peer_key] = rp

	var p_arr: Variant = msg.get("p", [0.0, 0.0, 0.0])
	if p_arr is Array and (p_arr as Array).size() >= 3:
		var a: Array = p_arr
		rp["tgt_pos"] = Vector3(float(a[0]), float(a[1]), float(a[2]))
	rp["tgt_yaw"] = float(msg.get("y", 0.0))
	rp["tgt_pitch"] = float(msg.get("pt", 0.0))
	var spot_node: SpotLight3D = rp["spot"]
	spot_node.visible = bool(msg.get("l", false)) and not bool(msg.get("h", false))
	var lbl_node: Label3D = rp["lbl"]
	lbl_node.text = "%s [A-%03d]" % [String(msg.get("n", "Player")), int(msg.get("r", 0))]
	var root_n: Node3D = rp["node"]
	root_n.visible = not bool(msg.get("h", false))


func _process_remote_players(delta: float) -> void:
	var a := 1.0 - exp(-14.0 * delta)
	for pk in _remote_players.keys():
		var rp: Dictionary = _remote_players[pk]
		var n: Node3D = rp["node"]
		if not is_instance_valid(n):
			continue
		n.position = n.position.lerp(rp["tgt_pos"], a)
		n.rotation.y = lerp_angle(n.rotation.y, float(rp["tgt_yaw"]), a)
		var hd: Node3D = rp["head"]
		hd.rotation.x = lerpf(hd.rotation.x, float(rp["tgt_pitch"]), a)
		var sp: SpotLight3D = rp["spot"]
		sp.rotation.x = hd.rotation.x


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

	var ov := ConfigFile.new()
	if ov.load(OVERRIDE_PATH) == OK:
		var saved_b := String(ov.get_value("rendering", "renderer/rendering_method", ""))
		if saved_b in ["forward_plus", "mobile", "gl_compatibility"]:
			_render_backend = saved_b


func _save_render_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("graphics", "quality", _render_quality)
	cfg.save(SETTINGS_PATH)


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
			cam.far = 42.0
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

	# Stylized First-Person Hand / Arm for opening & closing lockers and fridges
	_anim_hand = Node3D.new()
	_anim_hand.name = "LockerHand"
	_anim_hand.visible = false
	cam.add_child(_anim_hand)
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.76, 0.64, 0.55)
	skin_mat.roughness = 0.62
	var sleeve := RoomBuilder._add_box(_anim_hand, "Sleeve", Vector3(0.0, 0.0, 0.16), Vector3(0.095, 0.085, 0.34), _assets.wall_mat, false)
	sleeve.rotation.x = 0.08
	RoomBuilder._add_box(_anim_hand, "Cuff", Vector3(0.0, 0.0, -0.015), Vector3(0.10, 0.09, 0.03), _assets.fridge_mat, false)
	RoomBuilder._add_box(_anim_hand, "Palm", Vector3(0.0, 0.0, -0.075), Vector3(0.082, 0.048, 0.11), skin_mat, false)
	RoomBuilder._add_box(_anim_hand, "Fingers", Vector3(0.0, -0.012, -0.145), Vector3(0.078, 0.038, 0.055), skin_mat, false)
	RoomBuilder._add_box(_anim_hand, "Thumb", Vector3(-0.048, 0.005, -0.08), Vector3(0.026, 0.032, 0.065), skin_mat, false)


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

	# Diegetic crisp reminder (PC [F] / Mobile [WHITE]) matching screenshots
	var reminder_lbl := Label.new()
	reminder_lbl.set_anchors_preset(Control.PRESET_CENTER)
	reminder_lbl.offset_left = -320
	reminder_lbl.offset_right = 320
	reminder_lbl.offset_top = 104
	reminder_lbl.offset_bottom = 140
	reminder_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reminder_lbl.add_theme_font_size_override("font_size", 20)
	reminder_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 0.94))
	reminder_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	reminder_lbl.add_theme_constant_override("outline_size", 4)
	reminder_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	reminder_lbl.add_theme_constant_override("shadow_offset_y", 2)
	reminder_lbl.modulate.a = 0.0
	reminder_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_group.add_child(reminder_lbl)
	_ui["reminder_lbl"] = reminder_lbl

	var prompt_lbl := Label.new()
	prompt_lbl.set_anchors_preset(Control.PRESET_CENTER)
	prompt_lbl.offset_left = -280
	prompt_lbl.offset_right = 280
	prompt_lbl.offset_top = 60
	prompt_lbl.offset_bottom = 94
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 16)
	prompt_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 0.94))
	prompt_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	prompt_lbl.add_theme_constant_override("outline_size", 4)
	prompt_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	prompt_lbl.add_theme_constant_override("shadow_offset_y", 2)
	prompt_lbl.modulate.a = 0.0
	prompt_lbl.visible = false
	hud_group.add_child(prompt_lbl)
	_ui["prompt_lbl"] = prompt_lbl

	# Clean floating hint (same minimalist typography as Reminder — no green box)
	var toast_lbl := Label.new()
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.offset_left = -420
	toast_lbl.offset_right = 420
	toast_lbl.offset_top = 28
	toast_lbl.offset_bottom = 96
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_font_size_override("font_size", 19)
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

	# A-90 (Paralysis) Screen Overlay + Stop Sign + Jumpscare Flash
	var a90_rect := TextureRect.new()
	a90_rect.custom_minimum_size = Vector2(310, 310)
	a90_rect.size = Vector2(310, 310)
	a90_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_rect.visible = false
	a90_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(a90_rect)
	_ui["a90_rect"] = a90_rect

	var a90_stop_icon := TextureRect.new()
	a90_stop_icon.set_anchors_preset(Control.PRESET_CENTER)
	a90_stop_icon.offset_left = -82
	a90_stop_icon.offset_top = -82
	a90_stop_icon.offset_right = 82
	a90_stop_icon.offset_bottom = 82
	a90_stop_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_stop_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_stop_icon.visible = false
	a90_stop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("stopsign"):
		a90_stop_icon.texture = _a90_textures["stopsign"]
	root.add_child(a90_stop_icon)
	_ui["a90_stop_icon"] = a90_stop_icon

	var a90_scare_rect := TextureRect.new()
	a90_scare_rect.set_anchors_preset(Control.PRESET_CENTER)
	a90_scare_rect.offset_left = -290
	a90_scare_rect.offset_top = -290
	a90_scare_rect.offset_right = 290
	a90_scare_rect.offset_bottom = 290
	a90_scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a90_scare_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	a90_scare_rect.visible = false
	a90_scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _a90_textures.has("rage"):
		a90_scare_rect.texture = _a90_textures["rage"]
	root.add_child(a90_scare_rect)
	_ui["a90_scare_rect"] = a90_scare_rect

	var a90_stop := Label.new()
	a90_stop.set_anchors_preset(Control.PRESET_CENTER)
	a90_stop.offset_left = -180
	a90_stop.offset_right = 180
	a90_stop.offset_top = 158
	a90_stop.offset_bottom = 208
	a90_stop.text = "НЕ ДВИГАЙТЕСЬ!"
	a90_stop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a90_stop.add_theme_font_size_override("font_size", 28)
	a90_stop.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	a90_stop.visible = false
	root.add_child(a90_stop)
	_ui["a90_stop"] = a90_stop

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
	m_scroll.custom_minimum_size = Vector2(452, 520)
	m_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m_card.add_child(m_scroll)

	var m_box := VBoxContainer.new()
	m_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_box.add_theme_constant_override("separation", 9)
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

	var btn_resume := Button.new()
	btn_resume.text = "Продолжить"
	btn_resume.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_button(btn_resume, Color(0.35, 0.95, 0.68), 15)
	btn_resume.pressed.connect(func(): _set_state(State.PLAYING))
	m_box.add_child(btn_resume)
	_ui["btn_resume"] = btn_resume

	var btn_restart := Button.new()
	btn_restart.text = "Начать заново (A-000)"
	btn_restart.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_button(btn_restart, Color(1.0, 0.75, 0.28), 15)
	btn_restart.pressed.connect(_reset_run)
	m_box.add_child(btn_restart)

	var btn_mobile := Button.new()
	btn_mobile.text = "Сенсорное управление: АВТО"
	btn_mobile.custom_minimum_size = Vector2(0, 38)
	RoomsUI.style_button(btn_mobile, Color(0.55, 0.78, 1.0), 14)
	btn_mobile.pressed.connect(_cycle_mobile_mode)
	m_box.add_child(btn_mobile)
	_ui["btn_mobile"] = btn_mobile

	var ren_row := HBoxContainer.new()
	ren_row.add_theme_constant_override("separation", 6)
	m_box.add_child(ren_row)

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
	m_box.add_child(btn_restart_render)
	_ui["btn_restart_render"] = btn_restart_render

	# Online Test Panel (Steam Spacewar 480 + ENet LAN)
	var net_sep := Label.new()
	net_sep.text = "── ОНЛАЙН ТЕСТ (STEAM SPACEWAR 480) ──"
	net_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_sep.add_theme_font_size_override("font_size", 13)
	net_sep.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0))
	m_box.add_child(net_sep)

	var net_status := Label.new()
	net_status.text = _net.get_summary_status() if _net != null else "Offline"
	net_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status.add_theme_font_size_override("font_size", 13)
	net_status.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	m_box.add_child(net_status)
	_ui["net_status"] = net_status

	var steam_row := HBoxContainer.new()
	steam_row.add_theme_constant_override("separation", 6)
	m_box.add_child(steam_row)

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
	m_box.add_child(enet_row)

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
	m_box.add_child(steam_act_row)

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
	m_box.add_child(_lobby_list_box)

	# Architect Death Void (Curious Light gold star, god-rays, rim-lit silhouette & floating text)
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
			_advance_architect_dialogue()
	)
	arch_overlay.add_child(arch_bg)
	_ui["arch_bg"] = arch_bg

	var arch_silhouette := TextureRect.new()
	arch_silhouette.texture = RoomsArchitect.make_silhouette_texture(560, 270)
	arch_silhouette.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	arch_silhouette.offset_left = -260
	arch_silhouette.offset_top = -245
	arch_silhouette.offset_right = 260
	arch_silhouette.offset_bottom = 0
	arch_silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arch_silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arch_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_silhouette)
	_ui["arch_silhouette"] = arch_silhouette

	# Floating golden centered text directly under the glowing star
	var arch_speech := Label.new()
	arch_speech.set_anchors_preset(Control.PRESET_FULL_RECT)
	arch_speech.anchor_left = 0.16
	arch_speech.anchor_right = 0.84
	arch_speech.anchor_top = 0.34
	arch_speech.anchor_bottom = 0.56
	arch_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arch_speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arch_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arch_speech.add_theme_font_size_override("font_size", 26)
	arch_speech.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72))
	arch_speech.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 0.92))
	arch_speech.add_theme_constant_override("outline_size", 5)
	arch_speech.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	arch_speech.add_theme_constant_override("shadow_offset_x", 0)
	arch_speech.add_theme_constant_override("shadow_offset_y", 3)
	arch_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_speech)
	_ui["arch_speech"] = arch_speech

	# Quiet non-intrusive bottom bar & metadata
	var arch_title := Label.new()
	arch_title.visible = false
	arch_overlay.add_child(arch_title)
	_ui["arch_title"] = arch_title

	var arch_meta := Label.new()
	arch_meta.set_anchors_preset(Control.PRESET_TOP_LEFT)
	arch_meta.offset_left = 20
	arch_meta.offset_top = 16
	arch_meta.offset_right = 560
	arch_meta.add_theme_font_size_override("font_size", 12)
	arch_meta.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 0.55))
	arch_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_meta)
	_ui["arch_meta"] = arch_meta

	var arch_tip := Label.new()
	arch_tip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	arch_tip.offset_left = 24
	arch_tip.offset_right = -24
	arch_tip.offset_top = -78
	arch_tip.offset_bottom = -52
	arch_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arch_tip.add_theme_font_size_override("font_size", 13)
	arch_tip.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 0.80))
	arch_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_tip)
	_ui["arch_tip"] = arch_tip

	var arch_page := Label.new()
	arch_page.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	arch_page.offset_left = -220
	arch_page.offset_top = 16
	arch_page.offset_right = -20
	arch_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arch_page.add_theme_font_size_override("font_size", 12)
	arch_page.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 0.65))
	arch_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arch_overlay.add_child(arch_page)
	_ui["arch_page"] = arch_page

	var btn_arch_next := Button.new()
	btn_arch_next.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn_arch_next.offset_left = 24
	btn_arch_next.offset_top = -46
	btn_arch_next.offset_right = 260
	btn_arch_next.offset_bottom = -14
	btn_arch_next.text = "Далее [Пробел / ЛКМ]"
	RoomsUI.style_button(btn_arch_next, Color(1.0, 0.84, 0.34), 13)
	btn_arch_next.pressed.connect(_advance_architect_dialogue)
	arch_overlay.add_child(btn_arch_next)
	_ui["btn_arch_next"] = btn_arch_next

	var btn_arch_retry := Button.new()
	btn_arch_retry.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_arch_retry.offset_left = -260
	btn_arch_retry.offset_top = -46
	btn_arch_retry.offset_right = -24
	btn_arch_retry.offset_bottom = -14
	btn_arch_retry.text = "Заново [R]"
	RoomsUI.style_button(btn_arch_retry, Color(1.0, 0.72, 0.25), 13)
	btn_arch_retry.pressed.connect(_reset_run)
	arch_overlay.add_child(btn_arch_retry)
	_ui["btn_arch_retry"] = btn_arch_retry


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
	_joy_ring.size = Vector2(156, 156)
	_joy_ring.position = Vector2(46, 520)
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
			_set_state(State.PAUSED)
	)
	_ui["m_btn_pause"] = btn_pause

	# Brutal Large WHITE hollow circle -> Flashlight (bottom-right)
	var btn_light := _make_ring_btn(mobile_group, Color(1.0, 1.0, 1.0, 0.96), 7.5, -24, -22, 126)
	btn_light.pressed.connect(_toggle_flashlight)
	_ui["m_btn_light"] = btn_light

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
		if _has_gummy:
			if _active_tool != 1:
				_active_tool = 1
				audio.play_flashlight_click()
			else:
				_mobile_gummy_held = true
				_try_shake_gummy()
	)
	btn_gummy.button_up.connect(func() -> void:
		_mobile_gummy_held = false
	)
	btn_gummy.visible = false
	_ui["m_btn_gummy"] = btn_gummy

	# Clean exit directional rings ONLY when hiding (W outward 0.5s, S facing locker 0.3s)
	var btn_exit_fwd := _make_ring_btn(mobile_group, Color(0.32, 0.98, 0.58, 0.95), 5.5, -26, -158, 72, Control.PRESET_BOTTOM_RIGHT, "W")
	btn_exit_fwd.pressed.connect(func() -> void:
		if _is_hiding:
			_exit_locker(false)
	)
	_ui["m_btn_exit_fwd"] = btn_exit_fwd

	var btn_exit_back := _make_ring_btn(mobile_group, Color(1.0, 0.68, 0.24, 0.95), 5.5, -26, -26, 72, Control.PRESET_BOTTOM_RIGHT, "S")
	btn_exit_back.pressed.connect(func() -> void:
		if _is_hiding:
			_exit_locker(true)
	)
	_ui["m_btn_exit_back"] = btn_exit_back


func _refresh_mobile_mode() -> void:
	if _mobile_override == 1:
		_mobile_controls_enabled = true
	elif _mobile_override == -1:
		_mobile_controls_enabled = false
	else:
		_mobile_controls_enabled = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()

	if _ui.has("mobile_group"):
		(_ui["mobile_group"] as Control).visible = _mobile_controls_enabled and (_state == State.PLAYING)
	if _ui.has("btn_mobile"):
		var lbl := "Сенсорное управление: АВТО"
		if _mobile_override == 1:
			lbl = "Сенсорное управление: ВКЛ"
		elif _mobile_override == -1:
			lbl = "Сенсорное управление: ВЫКЛ"
		(_ui["btn_mobile"] as Button).text = lbl
	if _state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED


func _cycle_mobile_mode() -> void:
	if _mobile_override == 0:
		_mobile_override = 1
	elif _mobile_override == 1:
		_mobile_override = -1
	else:
		_mobile_override = 0
	_refresh_mobile_mode()


func _reset_run(forced_seed: int = -1) -> void:
	for child in rooms_container.get_children():
		child.queue_free()
	_rooms.clear()
	_room_by_idx.clear()
	_occupied_cells.clear()
	_opening_doors.clear()

	if forced_seed >= 0:
		_rng.seed = forced_seed
	else:
		_rng.randomize()
	_next_cell = Vector2i.ZERO
	_next_in_dir = Vector3(0.0, 0.0, -1.0)
	_next_room_index = 0
	_highest_opened = 0
	_current_room_idx = 0

	_hp = 100
	_stamina = 1.0
	_stamina_regen_delay = 0.0
	_exhausted = false
	_pant_timer = 0.0
	_run_time = 0.0
	_victory_reached = false
	_checkpoint_room = 0

	_is_hiding = false
	_hiding_room_idx = -1
	_hiding_locker_idx = -1
	_hiding_kind = "locker"
	_hiding_door_pivot = null
	_hiding_eye_local_y = 1.48
	_locker_blend = 0.0
	_locker_transition_t = 1.0
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	player_col.disabled = false
	_power_out = false
	_light_on = true
	_active_tool = 0
	_has_gummy = false
	_std_battery = 100.0
	_gummy_battery = 100.0
	_std_low_power = false
	_std_low_power_regen = 0.0
	_vm_shake_time = 0.0
	_gummy_hold_accum = 0.0
	_reminder_dismissed = false
	_toast_timer = 0.0
	_toast_alpha = 0.0
	_prompt_alpha = 0.0
	_reminder_alpha = 0.0
	_reticle_lag_offset = Vector2.ZERO
	_reticle_screen_pos = Vector2.ZERO
	_locker_transition_duration = 1.00
	if _vm_holder != null:
		_vm_holder.visible = true
	if _anim_hand != null:
		_anim_hand.visible = false

	_a60_active = false
	_a60_phase = 0
	_a60_is_prime = false
	_a60_prime_rebounds = 0
	_a60_hint_timer = 0.0
	_a60_random_timer = _rng.randf_range(22.0, 36.0)
	_a60_scare_snd_cd = 0.0
	_a60_node.visible = false
	audio.stop_a60()
	_a120_active = false
	_a120_phase = 0
	_a120_substage = 0
	_a120_drum_bounce = 0.0
	_a120_anim_timer = 0.0
	_a120_hit_cd = 0.0
	_a120_sprite.position = Vector3.ZERO
	_a120_sprite.scale = Vector3.ONE
	_a120_node.visible = false
	audio.stop_a120()
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	audio.stop_darkness()
	(_ui["darkness_rect"] as Control).visible = false
	_a90_phase = 0
	_a90_cooldown = 16.0
	_a90_scare_timer = 0.0
	audio.a60_intensity = 0.0
	audio.low_hp_mode = false

	for _i in range(5 if _render_quality == RenderQuality.MOBILE_OPT else 7):
		_spawn_next_room()
	_update_room_visibility()

	player_body.position = Vector3(0.0, 0.05, 4.0)
	player_body.velocity = Vector3.ZERO
	_target_yaw = 0.0
	_target_pitch = 0.0
	_yaw = 0.0
	_pitch = 0.0
	_cam_roll = 0.0
	_fov = 75.0
	cam.fov = 75.0
	cam.position = Vector3(0.0, 1.48, 0.0)
	_apply_camera_rotation()
	(_ui["architect_overlay"] as Control).visible = false
	(_ui["a90_scare_rect"] as Control).visible = false
	(_ui["a90_stop_icon"] as Control).visible = false
	(_ui["a60_scare_rect"] as Control).visible = false
	(_ui["static_rect"] as Control).visible = false
	_reset_touch_state()
	if _net != null:
		_net.update_lobby_progress(int(_rng.seed), 0)
	_set_state(State.PLAYING)
	_show_toast("Вы в Секции A. Откройте дверь A-001, чтобы начать.", 3.5)


func _spawn_next_room() -> void:
	var idx := _next_room_index
	_next_room_index += 1
	var cell := _next_cell
	var in_dir := _next_in_dir
	_occupied_cells[cell] = true

	var out_dir := in_dir
	if idx >= 2:
		var roll := _rng.randf()
		var cand := in_dir
		if roll < 0.17:
			cand = RoomBuilder.rotate_left(in_dir)
		elif roll < 0.34:
			cand = RoomBuilder.rotate_right(in_dir)

		# Ensure we don't loop back (+Z) or collide with existing rooms
		if cand.z <= 0.1:
			var step1 := cell + RoomBuilder.dir_to_grid_step(cand)
			var step2 := step1 + RoomBuilder.dir_to_grid_step(cand)
			if not _occupied_cells.has(step1) and not _occupied_cells.has(step2):
				out_dir = cand

	var r := RoomBuilder.build_room(rooms_container, _assets, idx, cell, in_dir, out_dir, _rng, _power_out or (idx >= 50))
	_rooms.append(r)
	_room_by_idx[idx] = r

	_next_cell = cell + RoomBuilder.dir_to_grid_step(out_dir)
	_next_in_dir = out_dir

	# Prune rooms far behind to keep FPS steady (tighter on Mobile FPS preset)
	var max_keep := 10 if _render_quality == RenderQuality.MOBILE_OPT else 16
	var back_keep := 4 if _render_quality == RenderQuality.MOBILE_OPT else 7
	while _rooms.size() > max_keep and _rooms[0].index < _current_room_idx - back_keep:
		var old_r: RoomBuilder.RoomInstance = _rooms.pop_front()
		_room_by_idx.erase(old_r.index)
		old_r.root.queue_free()
	_update_room_visibility()


func _set_state(new_state: State) -> void:
	_state = new_state
	(_ui["hud_group"] as Control).visible = (_state != State.DEAD)
	if _ui.has("mobile_group"):
		(_ui["mobile_group"] as Control).visible = _mobile_controls_enabled and (_state == State.PLAYING)
	if _state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
		(_ui["modal"] as Control).visible = false
		(_ui["architect_overlay"] as Control).visible = false
	else:
		_reset_touch_state()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var modal: Control = _ui["modal"]
		modal.visible = (_state == State.PAUSED or _state == State.VICTORY)
		var title: Label = _ui["m_title"]
		var desc: Label = _ui["m_desc"]
		var btn_res: Button = _ui["btn_resume"]
		if _state == State.PAUSED:
			title.text = "ПАУЗА  (A-%03d)" % _highest_opened
			title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
			desc.text = "Секция A. Переживите A-60, A-90 и A-120 до комнаты A-200!"
			btn_res.text = "Продолжить"
			btn_res.visible = true
		elif _state == State.VICTORY:
			title.text = "ВЫ ПРОШЛИ СЕКЦИЮ A!"
			title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
			var mins := int(_run_time) / 60
			var secs := int(_run_time) % 60
			desc.text = "Архитектор приветствует тебя: ты достиг двери A-200 за %02d:%02d!\nМожно продолжить бесконечный забег дальше или начать заново." % [mins, secs]
			btn_res.text = "Продолжить дальше (A-201+)"
			btn_res.visible = true


func _trigger_death(cause: String, _tip: String = "", extra_ctx: Dictionary = {}) -> void:
	if _state != State.PLAYING:
		return
	audio.play_death_sound()
	if cause != "A-120" and cause != "A-60" and cause != "A-60'":
		audio.play_jumpscare()
	audio.stop_a120()
	audio.stop_a60()
	audio.stop_darkness()
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	(_ui["darkness_rect"] as Control).visible = false
	audio.play_architect_appear()
	audio.a60_intensity = 0.0
	_a60_active = false
	_a60_phase = 0
	_a60_node.visible = false
	_a120_active = false
	_a120_phase = 0
	_a120_node.visible = false
	_a90_phase = 0
	(_ui["a90_rect"] as Control).visible = false
	(_ui["a90_stop_icon"] as Control).visible = false
	(_ui["a90_stop"] as Control).visible = false
	(_ui["a60_scare_rect"] as Control).visible = false
	(_ui["static_rect"] as Control).visible = false
	(_ui["modal"] as Control).visible = false

	_state = State.DEAD
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_ui["hud_group"] as Control).visible = false

	var cur_room: RoomBuilder.RoomInstance = _room_by_idx.get(_current_room_idx)
	var cur_bat := _std_battery if _active_tool == 0 else _gummy_battery
	var ctx := {
		"room_lockers_count": cur_room.lockers.size() if cur_room != null else 0,
		"battery": cur_bat,
		"has_gummy": _has_gummy,
	}
	for k in extra_ctx.keys():
		ctx[k] = extra_ctx[k]

	var seq := _architect.build_death_sequence(cause, _highest_opened, ctx)
	_arch_lines.clear()
	var seq_lines: Array = seq["lines"]
	for line_item in seq_lines:
		_arch_lines.append(String(line_item))
	if _arch_lines.is_empty():
		_arch_lines.append("Будь осторожен в коридорах Секции A.")

	_arch_line_idx = 0
	_arch_char_pos = 0.0
	_arch_blip_acc = 0

	(_ui["arch_title"] as Label).text = String(seq["title"])
	(_ui["arch_meta"] as Label).text = "Причина: %s  |  Попытка #%d  |  Рекорд: A-%03d" % [
		cause, int(seq["deaths_total"]), _architect.best_room
	]
	(_ui["arch_tip"] as Label).text = "Совет Архитектора: %s" % String(seq["summary"])
	(_ui["arch_speech"] as Label).text = ""
	_refresh_architect_controls()

	if cause == "A-90" and _a90_textures.has("rage"):
		_a90_scare_timer = 0.45
		var scare_rect: TextureRect = _ui["a90_scare_rect"]
		scare_rect.texture = _a90_textures["rage"]
		scare_rect.modulate = Color(1.0, 1.0, 1.0, 0.92)
		scare_rect.visible = true
	else:
		_a90_scare_timer = 0.0
		(_ui["a90_scare_rect"] as Control).visible = false

	var arch_overlay: Control = _ui["architect_overlay"]
	arch_overlay.visible = true
	arch_overlay.modulate.a = 0.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(arch_overlay, "modulate:a", 1.0, 0.45)


func _refresh_architect_controls() -> void:
	var total := maxi(_arch_lines.size(), 1)
	(_ui["arch_page"] as Label).text = "Реплика %d / %d" % [_arch_line_idx + 1, total]
	var btn_next: Button = _ui["btn_arch_next"]
	if _arch_line_idx + 1 < total:
		btn_next.text = "Далее [Пробел]"
		btn_next.disabled = false
	else:
		var line_len := _arch_lines[_arch_line_idx].length() if not _arch_lines.is_empty() else 0
		if int(_arch_char_pos) < line_len:
			btn_next.text = "Пропустить текст [Пробел]"
		else:
			btn_next.text = "Понятно (жмите снова — заново)"
		btn_next.disabled = false


func _advance_architect_dialogue() -> void:
	if _state != State.DEAD or _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if int(_arch_char_pos) < cur_line.length():
		_arch_char_pos = float(cur_line.length())
		(_ui["arch_speech"] as Label).text = cur_line
		_refresh_architect_controls()
		return
	if _arch_line_idx + 1 < _arch_lines.size():
		_arch_line_idx += 1
		_arch_char_pos = 0.0
		_arch_blip_acc = 0
		(_ui["arch_speech"] as Label).text = ""
		_refresh_architect_controls()
	else:
		_reset_run()


func _reset_touch_state() -> void:
	_joy_touch_id = -1
	_look_touch_id = -1
	_tap_touch_id = -1
	_joy_vec = Vector2.ZERO
	_joy_sprint = false
	_mobile_sprint_held = false
	_mobile_gummy_held = false
	if _joy_ring != null and _joy_knob != null:
		var vp_sz := get_viewport().get_visible_rect().size
		_joy_ring.position = Vector2(46.0, maxf(vp_sz.y - 202.0, 80.0))
		_joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.72)
		_joy_knob.position = Vector2(46.0, 46.0)


func _point_hits_mobile_btn(pos: Vector2) -> bool:
	for b in _mobile_btns:
		if is_instance_valid(b) and b.visible and b.get_global_rect().grow(10.0).has_point(pos):
			return true
	return false


func _update_joystick_from_pos(pos: Vector2) -> void:
	var max_r := 58.0
	var delta_v := pos - _joy_origin
	var dist := delta_v.length()
	var clamped := delta_v.normalized() * minf(dist, max_r) if dist > 0.001 else Vector2.ZERO
	_joy_vec = clamped / max_r
	if _joy_vec.length() < 0.14:
		_joy_vec = Vector2.ZERO
	_joy_sprint = (dist > max_r * 0.84)
	if _joy_ring != null and _joy_knob != null:
		_joy_knob.position = Vector2(78.0, 78.0) - _joy_knob.size * 0.5 + clamped


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if not _mobile_controls_enabled and te.pressed and _mobile_override == 0:
			_mobile_controls_enabled = true
			_refresh_mobile_mode()
		if _state == State.DEAD and te.pressed:
			_advance_architect_dialogue()
			get_viewport().set_input_as_handled()
			return
		if _state != State.PLAYING or not _mobile_controls_enabled:
			return
		var vp_sz := get_viewport().get_visible_rect().size
		if te.pressed:
			if _point_hits_mobile_btn(te.position):
				return
			if _tap_touch_id == -1:
				_tap_touch_id = te.index
				_tap_start_pos = te.position
				_tap_start_time_ms = Time.get_ticks_msec()
			if te.position.x < vp_sz.x * 0.44 and _joy_touch_id == -1:
				_joy_touch_id = te.index
				var half := Vector2(78.0, 78.0)
				_joy_origin = Vector2(
					clampf(te.position.x, 96.0, vp_sz.x * 0.40),
					clampf(te.position.y, 120.0, vp_sz.y - 96.0)
				)
				if _joy_ring != null:
					_joy_ring.position = _joy_origin - half
					_joy_ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_update_joystick_from_pos(te.position)
			elif _look_touch_id == -1:
				_look_touch_id = te.index
		else:
			if te.index == _tap_touch_id:
				var dt_ms := Time.get_ticks_msec() - _tap_start_time_ms
				var dist_px := te.position.distance_to(_tap_start_pos)
				_tap_touch_id = -1
				if dt_ms <= 300 and dist_px <= 20.0 and not _is_hiding and not _point_hits_mobile_btn(te.position):
					_try_tap_world_interact(te.position)
			if te.index == _joy_touch_id:
				_joy_touch_id = -1
				_joy_vec = Vector2.ZERO
				_joy_sprint = false
				if _joy_ring != null and _joy_knob != null:
					_joy_ring.position = Vector2(46.0, maxf(vp_sz.y - 202.0, 80.0))
					_joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.72)
					_joy_knob.position = Vector2(46.0, 46.0)
			elif te.index == _look_touch_id:
				_look_touch_id = -1
		return

	elif event is InputEventScreenDrag:
		if _state != State.PLAYING or not _mobile_controls_enabled:
			return
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch_id:
			_update_joystick_from_pos(sd.position)
		elif sd.index == _look_touch_id:
			var sens := 0.0044
			if _is_hiding:
				_target_hide_yaw = clampf(_target_hide_yaw - sd.relative.x * sens, -0.58, 0.58)
				_target_hide_pitch = clampf(_target_hide_pitch - sd.relative.y * sens, -0.38, 0.38)
			else:
				_target_yaw -= sd.relative.x * sens
				_target_pitch = clampf(_target_pitch - sd.relative.y * sens, -1.42, 1.42)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		if _state == State.DEAD:
			if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				_advance_architect_dialogue()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_R:
				_reset_run()
				get_viewport().set_input_as_handled()
				return

		if ke.keycode == KEY_TAB or ke.keycode == KEY_ESCAPE:
			if _state == State.PLAYING:
				_set_state(State.PAUSED)
				get_viewport().set_input_as_handled()
				return
			elif _state == State.PAUSED:
				_set_state(State.PLAYING)
				get_viewport().set_input_as_handled()
				return

		if _state == State.PLAYING:
			if ke.keycode == KEY_E:
				_try_interact()
			elif _is_hiding and ke.keycode == KEY_W:
				_exit_locker(false)
			elif _is_hiding and ke.keycode == KEY_S:
				_exit_locker(true)
			elif ke.keycode == KEY_F:
				_toggle_flashlight()
			elif ke.keycode == KEY_1:
				_active_tool = 0
				audio.play_flashlight_click()
			elif ke.keycode == KEY_2 and _has_gummy:
				_active_tool = 1
				audio.play_flashlight_click()
			elif ke.keycode == KEY_R:
				_try_shake_gummy()
			elif ke.keycode == KEY_M:
				audio.muted = not audio.muted

	elif event is InputEventMouseMotion and _state == State.PLAYING:
		if (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
			return
		if not _mobile_controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var rel := (event as InputEventMouseMotion).relative
			if _is_hiding:
				_target_hide_yaw = clampf(_target_hide_yaw - rel.x * 0.0022, -0.58, 0.58)
				_target_hide_pitch = clampf(_target_hide_pitch - rel.y * 0.0022, -0.38, 0.38)
			else:
				_target_yaw -= rel.x * 0.0024
				_target_pitch = clampf(_target_pitch - rel.y * 0.0024, -1.42, 1.42)

	elif event is InputEventMouseButton and _state == State.PLAYING:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION or _mobile_controls_enabled:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif _try_interact():
				pass
			elif _active_tool == 1:
				_try_shake_gummy()


func _apply_camera_rotation() -> void:
	player_body.rotation.y = _yaw
	cam.rotation.x = _pitch
	cam.rotation.z = _cam_roll


func _process(delta: float) -> void:
	if _state == State.DEAD:
		_process_architect_and_scare(delta)
		return
	if _state != State.PLAYING:
		return

	var look_alpha := 1.0 - exp(-18.0 * delta)
	_yaw = lerpf(_yaw, _target_yaw, look_alpha)
	_pitch = lerpf(_pitch, _target_pitch, look_alpha)
	_hide_yaw_offset = lerpf(_hide_yaw_offset, _target_hide_yaw, look_alpha)
	_hide_pitch_offset = lerpf(_hide_pitch_offset, _target_hide_pitch, look_alpha)

	var target_fov := 66.0 if _is_hiding else 75.0
	if not _is_hiding:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		if hspd > 4.6:
			target_fov = 81.0
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-10.0 * delta))
	cam.fov = _fov

	if _locker_transition_t < 1.0:
		var dur := maxf(_locker_transition_duration, 0.05)
		_locker_transition_t = minf(_locker_transition_t + delta / dur, 1.0)

	if (_mobile_gummy_held or Input.is_key_pressed(KEY_R)) and _active_tool == 1 and _has_gummy and not _is_hiding:
		_gummy_hold_accum += delta
		if _gummy_hold_accum >= 0.28:
			_gummy_hold_accum -= 0.28
			_try_shake_gummy(4.7)
	else:
		_gummy_hold_accum = 0.0

	var lock_mask: ColorRect = _ui["locker_mask"]
	if _is_hiding:
		if _locker_transition_t < 1.0:
			var prev_t := maxf(_locker_transition_t - delta / maxf(_locker_transition_duration, 0.05), 0.0)
			if _locker_transition_t >= 0.72 and prev_t < 0.72:
				_light_on = false
		if _anim_hand != null:
			if _hiding_kind != "under_desk" and _locker_transition_t < 0.98:
				_anim_hand.visible = true
				var p := _locker_transition_t
				if p < 0.30:
					var rp := ease(p / 0.30, 0.35)
					_anim_hand.position = Vector3(0.22, -0.12, -0.22).lerp(Vector3(-0.05, -0.02, -0.45), rp)
					_anim_hand.rotation = Vector3(0.08, 0.16 * rp, -0.18 * rp)
				elif p < 0.68:
					var sp := (p - 0.30) / 0.38
					_anim_hand.position = Vector3(-0.05, -0.02, -0.45).lerp(Vector3(-0.22, -0.05, -0.34), sin(sp * PI * 0.5))
					_anim_hand.rotation = Vector3(0.0, 0.44 * sp, -0.10)
				else:
					var cp := (p - 0.68) / 0.32
					_anim_hand.position = Vector3(-0.22, -0.05, -0.34).lerp(Vector3(0.20, -0.18, -0.18), cp)
					_anim_hand.rotation = Vector3(-0.12 * cp, -0.15 * cp, 0.0)
			else:
				_anim_hand.visible = false
		if _vm_holder != null:
			_vm_holder.visible = (_locker_transition_t >= 0.96 and _light_on)
			if _vm_holder.visible:
				_vm_holder.position = Vector3(0.18, -0.19, -0.28)
		var t_ease := ease(_locker_transition_t, 0.26)
		var base_yaw := atan2(-_locker_fwd.x, -_locker_fwd.z)
		player_body.global_position = _locker_eye - Vector3(0.0, _hiding_eye_local_y, 0.0)
		if _locker_transition_t < 1.0 and _hiding_kind != "under_desk":
			var turn_p := ease(clampf((_locker_transition_t - 0.26) / 0.58, 0.0, 1.0), -2.0)
			player_body.rotation.y = lerp_angle(_locker_enter_from_yaw, base_yaw + _hide_yaw_offset, turn_p)
		else:
			player_body.rotation.y = lerp_angle(player_body.rotation.y, base_yaw + _hide_yaw_offset, clampf(1.0 - exp(-14.0 * delta) + t_ease * 0.25, 0.0, 1.0))
		cam.rotation.x = lerpf(cam.rotation.x, _hide_pitch_offset, 1.0 - exp(-16.0 * delta))
		var crawl_roll := sin(_locker_transition_t * PI) * (0.07 if _hiding_kind == "under_desk" else 0.03) if _locker_transition_t < 1.0 else 0.0
		cam.rotation.z = lerpf(cam.rotation.z, crawl_roll, 1.0 - exp(-12.0 * delta))
		var tgt_eye := _locker_eye
		var max_mask := 0.20 if _hiding_kind == "under_desk" else 0.36
		if _locker_transition_t < 1.0:
			if _hiding_kind == "under_desk":
				var t_xz := ease(_locker_transition_t, 0.32)
				var t_y := ease(_locker_transition_t, 0.55)
				cam.global_position = Vector3(
					lerpf(_locker_cam_from.x, tgt_eye.x, t_xz),
					lerpf(_locker_cam_from.y, tgt_eye.y, t_y),
					lerpf(_locker_cam_from.z, tgt_eye.z, t_xz)
				)
			else:
				var move_p := clampf((_locker_transition_t - 0.14) / 0.72, 0.0, 1.0)
				cam.global_position = _locker_cam_from.lerp(tgt_eye, ease(move_p, 0.28))
			lock_mask.color = Color(0.0, 0.0, 0.0, lerpf(0.0, max_mask, t_ease))
			lock_mask.visible = (lock_mask.color.a > 0.004)
		else:
			cam.global_position = tgt_eye
			lock_mask.color = Color(0.0, 0.0, 0.0, max_mask)
			lock_mask.visible = (max_mask > 0.004)
	else:
		if _locker_transition_t < 1.0 and not _locker_transition_entering:
			var exit_turn_p := ease(clampf(_locker_transition_t, 0.0, 1.0), -1.8)
			_yaw = lerp_angle(_locker_exit_from_yaw, _locker_exit_to_yaw, exit_turn_p)
			_target_yaw = _locker_exit_to_yaw
		_apply_camera_rotation()
		var fl_lag_x := clampf((_target_pitch - _pitch) * 0.45, -0.14, 0.14)
		var fl_lag_y := clampf((_target_yaw - _yaw) * 0.45, -0.18, 0.18)
		flashlight.rotation.x = lerpf(flashlight.rotation.x, fl_lag_x, 1.0 - exp(-14.0 * delta))
		flashlight.rotation.y = lerpf(flashlight.rotation.y, fl_lag_y, 1.0 - exp(-14.0 * delta))

		if _anim_hand != null:
			if _locker_transition_t < 0.96 and not _locker_transition_entering:
				_anim_hand.visible = true
				var p_out := _locker_transition_t
				if _locker_exit_face_locker:
					# Fast 0.3s S exit animation: push door wide while twisting back toward locker
					var s_p := sin(p_out * PI)
					_anim_hand.position = Vector3(-0.08, -0.05, -0.45).lerp(Vector3(0.24, -0.22, -0.20), p_out) + Vector3(-0.14 * s_p, 0.04 * s_p, 0.0)
					_anim_hand.rotation = Vector3(0.06, 0.38 * s_p - 0.25 * p_out, -0.16 * s_p)
				else:
					# Full 0.5s W exit animation: reach door latch -> swing open -> step out & lower hand
					if p_out < 0.32:
						var r_p := ease(p_out / 0.32, 0.35)
						_anim_hand.position = Vector3(0.20, -0.20, -0.20).lerp(Vector3(-0.05, -0.04, -0.46), r_p)
						_anim_hand.rotation = Vector3(0.08 * r_p, 0.16 * r_p, -0.15 * r_p)
					elif p_out < 0.68:
						var o_p := (p_out - 0.32) / 0.36
						_anim_hand.position = Vector3(-0.05, -0.04, -0.46).lerp(Vector3(-0.26, -0.08, -0.32), sin(o_p * PI * 0.5))
						_anim_hand.rotation = Vector3(0.0, 0.48 * o_p, -0.10)
					else:
						var d_p := (p_out - 0.68) / 0.32
						_anim_hand.position = Vector3(-0.26, -0.08, -0.32).lerp(Vector3(0.24, -0.26, -0.16), d_p)
						_anim_hand.rotation = Vector3(-0.10 * d_p, -0.18 * d_p, 0.0)
			else:
				_anim_hand.visible = false

		if _vm_holder != null:
			_vm_holder.visible = true
			_vm_std.visible = (_active_tool == 0)
			_vm_gummy.visible = (_active_tool == 1)
			var hspd_vm := Vector2(player_body.velocity.x, player_body.velocity.z).length()
			var t_sec_vm := float(Time.get_ticks_msec()) * 0.001
			var bob_amp := clampf(hspd_vm / 5.5, 0.0, 1.0)
			var bx := cos(t_sec_vm * 7.2) * 0.011 * bob_amp + sin(t_sec_vm * 1.4) * 0.0025
			var by := absf(sin(t_sec_vm * 7.2)) * -0.014 * bob_amp + cos(t_sec_vm * 1.8) * 0.0025
			_vm_holder.position = _vm_holder.position.lerp(Vector3(0.24 + bx, -0.21 + by, -0.34), 1.0 - exp(-14.0 * delta))
			_vm_holder.rotation.x = lerpf(_vm_holder.rotation.x, fl_lag_x * 0.75, 1.0 - exp(-14.0 * delta))
			_vm_holder.rotation.y = lerpf(_vm_holder.rotation.y, fl_lag_y * 0.75, 1.0 - exp(-14.0 * delta))
			if _vm_shake_time > 0.0:
				_vm_shake_time = maxf(_vm_shake_time - delta, 0.0)
				var s_env := clampf(_vm_shake_time / 0.30, 0.0, 1.0)
				_vm_gummy.position = Vector3(sin(t_sec_vm * 46.0) * 0.018 * s_env, cos(t_sec_vm * 62.0) * 0.032 * s_env, 0.0)
				_vm_gummy.rotation = Vector3(sin(t_sec_vm * 58.0) * 0.28 * s_env, 0.0, cos(t_sec_vm * 48.0) * 0.22 * s_env)
			else:
				_vm_gummy.position = _vm_gummy.position.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
				_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))

		if _locker_transition_t < 1.0:
			var t_out := ease(_locker_transition_t, 0.26)
			var tgt_pos := player_body.global_position + Vector3(0.0, 1.48, 0.0)
			cam.global_position = _locker_cam_from.lerp(tgt_pos, t_out)
			cam.rotation.z = lerpf(cam.rotation.z, sin(_locker_transition_t * PI) * (-0.05 if _locker_exit_face_locker else 0.03), 1.0 - exp(-14.0 * delta))
			lock_mask.color = Color(0.0, 0.0, 0.0, lerpf(0.32, 0.0, t_out))
			lock_mask.visible = (lock_mask.color.a > 0.004)
		else:
			lock_mask.color = Color(0.0, 0.0, 0.0, 0.0)
			lock_mask.visible = false

	if _net != null and _net.is_online():
		var gp := player_body.global_position
		_net.update_local_state({
			"pos": [gp.x, gp.y, gp.z],
			"yaw": _yaw,
			"pitch": _pitch,
			"light": _light_on and (_active_tool == 0 and _std_battery > 0.05 or _active_tool == 1 and _gummy_battery > 0.05),
			"hide": _is_hiding,
			"room": _highest_opened,
			"hp": _hp,
		})
	_process_remote_players(delta)


func _process_architect_and_scare(delta: float) -> void:
	if _a90_scare_timer > 0.0:
		_a90_scare_timer -= delta
		var scare_rect: TextureRect = _ui["a90_scare_rect"]
		scare_rect.modulate.a = clampf(_a90_scare_timer / 0.45, 0.0, 1.0)
		if _a90_scare_timer <= 0.0:
			scare_rect.visible = false

	if _ui.has("arch_silhouette"):
		var sil: TextureRect = _ui["arch_silhouette"]
		var t_sec := float(Time.get_ticks_msec()) * 0.001
		sil.offset_top = -245.0 + sin(t_sec * 1.4) * 3.0

	if _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	var prev_chars := int(_arch_char_pos)
	if prev_chars < cur_line.length():
		_arch_char_pos = minf(_arch_char_pos + delta * 48.0, float(cur_line.length()))
		var now_chars := int(_arch_char_pos)
		if now_chars > prev_chars:
			(_ui["arch_speech"] as Label).text = cur_line.substr(0, now_chars)
			_arch_blip_acc += now_chars - prev_chars
			if _arch_blip_acc >= 3:
				_arch_blip_acc = 0
				var last_ch := cur_line.substr(now_chars - 1, 1)
				if last_ch != " " and last_ch != "\n":
					audio.play_architect_blip(_rng.randf_range(0.92, 1.10))
			if now_chars >= cur_line.length():
				_refresh_architect_controls()


func _toggle_flashlight() -> void:
	_light_on = not _light_on
	_reminder_dismissed = true
	audio.play_flashlight_click()
	if _is_hiding and _light_on and _darkness_phase > 0:
		if _active_tool == 0 and not _std_low_power and _std_battery > 0.5:
			_darkness_phase = 0
			_darkness_whisper_t = 0.0
			_darkness_dmg_accum = 0.0
			_hide_time = 0.0
			_darkness_quick_return = true
			_std_low_power = true
			_std_low_power_regen = 0.0
			(_ui["darkness_rect"] as Control).visible = false
			audio.stop_darkness()
			audio.play_flashlight_low_power()
			_show_toast("Обычный фонарик отпугнул Тьму (слабый режим)!", 2.2)


func _try_shake_gummy(amount: float = 10.0) -> void:
	if _active_tool != 1 or not _has_gummy or _is_hiding:
		return
	_gummy_battery = minf(_gummy_battery + amount, 100.0)
	_shake_amount = maxf(_shake_amount, 0.022)
	_vm_shake_time = 0.34
	audio.play_gummy_shake()


func _try_interact() -> bool:
	if _is_hiding:
		_exit_locker(false)
		return true

	var target := _smart_reticle_target if not _smart_reticle_target.is_empty() else _find_smart_reticle_target()
	if target.is_empty():
		return false
	return _execute_interact_target(target)


func _execute_interact_target(target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var kind := String(target["type"])
	if kind == "door":
		var r_idx := int(target["room_index"])
		_open_room_door(r_idx)
		return true
	elif kind == "locker":
		var r_idx := int(target["room_index"])
		var l_idx := int(target["locker_index"])
		_enter_locker(r_idx, l_idx)
		return true
	elif kind == "pickup":
		var node := target["node"] as Node3D
		if not is_instance_valid(node):
			return false
		var pkind := String(target["pickup_kind"])
		if pkind == "battery":
			_std_battery = minf(_std_battery + 35.0, 100.0)
			_std_low_power = false
			_std_low_power_regen = 0.0
			_show_toast("+35% заряда фонарика")
		elif pkind == "gummy":
			_has_gummy = true
			_active_tool = 1
			_gummy_battery = 100.0
			_show_toast("Подобран Зелёный фонарик [2]! Зажмите [R] чтобы потрясти.", 3.2)
		elif pkind == "medkit":
			_hp = mini(_hp + 45, 100)
			audio.low_hp_mode = (_hp <= 25)
			_show_toast("+45 HP восстановлено")
		audio.play_pickup()
		node.queue_free()
		return true
	return false


func _try_tap_world_interact(screen_pos: Vector2) -> void:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 4.5, 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var col: Object = hit.get("collider")
			if col != null and col.has_meta("interact_type"):
				var parsed := _collider_to_interact_dict(col)
				if not parsed.is_empty():
					_execute_interact_target(parsed)
					return

	if not _smart_reticle_target.is_empty() and screen_pos.distance_to(_reticle_screen_pos) <= 115.0:
		_execute_interact_target(_smart_reticle_target)


func _collider_to_interact_dict(col: Object) -> Dictionary:
	if col == null or not col.has_meta("interact_type"):
		return {}
	var itype := String(col.get_meta("interact_type"))
	if itype == "door":
		var r_idx := int(col.get_meta("room_index"))
		var room_inst: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
		if room_inst != null and not room_inst.door_opened:
			return {"type": "door", "room_index": r_idx, "label": "Открыть дверь A-%03d" % (r_idx + 1)}
	elif itype == "locker":
		var r_idx := int(col.get_meta("room_index"))
		var l_idx := int(col.get_meta("locker_index"))
		var r_inst: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
		var lbl := "Спрятаться"
		if r_inst != null and l_idx >= 0 and l_idx < r_inst.lockers.size():
			lbl = String(r_inst.lockers[l_idx].get("label", lbl))
		return {
			"type": "locker",
			"room_index": r_idx,
			"locker_index": l_idx,
			"label": lbl,
		}
	elif itype == "pickup":
		return {
			"type": "pickup",
			"node": col,
			"pickup_kind": String(col.get_meta("pickup_kind")),
			"label": "Взять: %s" % String(col.get_meta("pickup_prompt")),
		}
	return {}


func _find_interact_target() -> Dictionary:
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		return _collider_to_interact_dict(interact_ray.get_collider())
	return {}


func _target_anchor_world_pos(tgt: Dictionary) -> Vector3:
	var kind := String(tgt.get("type", ""))
	if kind == "locker":
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(int(tgt["room_index"]))
		var li := int(tgt["locker_index"])
		if r != null and li >= 0 and li < r.lockers.size():
			var ld: Dictionary = r.lockers[li]
			var ln: Node3D = ld["node"]
			var lk := String(ld.get("kind", "locker"))
			var loc := Vector3(0.0, 0.56, 0.22) if lk == "under_desk" else Vector3(0.0, 1.16, 0.34)
			return ln.global_transform * loc
	elif kind == "door":
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(int(tgt["room_index"]))
		if r != null and is_instance_valid(r.exit_anchor):
			return r.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
	elif kind == "pickup":
		var n := tgt.get("node") as Node3D
		if is_instance_valid(n):
			return n.global_position
	return cam.global_position - cam.global_transform.basis.z * 2.0


func _find_smart_reticle_target() -> Dictionary:
	var vp_sz := get_viewport().get_visible_rect().size
	var vp_center := vp_sz * 0.5
	var direct := _find_interact_target()
	if not direct.is_empty():
		var wp := _target_anchor_world_pos(direct)
		if not cam.is_position_behind(wp):
			direct["screen_pos"] = cam.unproject_position(wp)
			direct["world_pos"] = wp
			return direct

	# Smart cone scan around center: snaps reticle UI ring onto nearby locker/door/item even when aiming slightly beside it
	var best_tgt: Dictionary = {}
	var best_screen_d := minf(vp_sz.x, vp_sz.y) * 0.24
	var space_state := get_world_3d().direct_space_state
	var cam_pos := cam.global_position

	for r in _rooms:
		if abs(r.index - _current_room_idx) > 1:
			continue
		for li in range(r.lockers.size()):
			var ld: Dictionary = r.lockers[li]
			var ln: Node3D = ld["node"]
			if not is_instance_valid(ln):
				continue
			var lk := String(ld.get("kind", "locker"))
			var loc := Vector3(0.0, 0.56, 0.22) if lk == "under_desk" else Vector3(0.0, 1.16, 0.34)
			var wp := ln.global_transform * loc
			if cam_pos.distance_to(wp) > 3.85 or cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var sd := sp.distance_to(vp_center)
			if sd < best_screen_d and _has_los_to_interact(space_state, cam_pos, wp, r.index):
				best_screen_d = sd
				best_tgt = {
					"type": "locker",
					"room_index": r.index,
					"locker_index": li,
					"label": String(ld.get("label", "Спрятаться")),
					"screen_pos": sp,
					"world_pos": wp,
				}
		if not r.door_opened and is_instance_valid(r.exit_anchor):
			var dwp := r.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
			if cam_pos.distance_to(dwp) <= 3.85 and not cam.is_position_behind(dwp):
				var dsp := cam.unproject_position(dwp)
				var dsd := dsp.distance_to(vp_center)
				if dsd < best_screen_d and _has_los_to_interact(space_state, cam_pos, dwp, r.index):
					best_screen_d = dsd
					best_tgt = {
						"type": "door",
						"room_index": r.index,
						"label": "Открыть дверь A-%03d" % (r.index + 1),
						"screen_pos": dsp,
						"world_pos": dwp,
					}
	return best_tgt


func _has_los_to_interact(space_state: PhysicsDirectSpaceState3D, from_pos: Vector3, to_pos: Vector3, _room_idx: int) -> bool:
	if space_state == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from_pos, to_pos, 0xFFFFFFFF, [player_body.get_rid()])
	var hit := space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var col: Object = hit.get("collider")
	if col != null and col.has_meta("interact_type"):
		return true
	var hp: Vector3 = hit.get("position", from_pos)
	return hp.distance_to(to_pos) < 0.65


func _open_room_door(r_idx: int, from_remote: bool = false) -> void:
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null or r.door_opened:
		return
	r.door_opened = true
	if r.door_collider != null:
		r.door_collider.collision_layer = 0
		r.door_collider.collision_mask = 0
	_opening_doors.append({"pivot": r.door_pivot, "progress": 0.0})
	audio.play_door_open()
	if not from_remote and _net != null and _net.is_online():
		_net.broadcast_door_opened(r_idx)
	_advance_door_progress(r_idx, not from_remote)


func _advance_door_progress(r_idx: int, allow_spawn: bool) -> void:
	var opened_num := r_idx + 1
	if opened_num > _highest_opened:
		_highest_opened = opened_num
		_current_room_idx = opened_num
		if _net != null:
			_net.update_lobby_progress(int(_rng.seed), _highest_opened)
		if opened_num >= 50 and not _power_out:
			_trigger_power_outage()
		var min_keep := 9 if _render_quality == RenderQuality.MOBILE_OPT else 14
		var ahead_keep := 4 if _render_quality == RenderQuality.MOBILE_OPT else 6
		while _rooms.size() < min_keep or _rooms[-1].index < _highest_opened + ahead_keep:
			_spawn_next_room()
		_update_room_visibility()

		if opened_num == 100:
			_checkpoint_room = 100
			_show_toast("Контрольная точка A-100 достигнута! Половина пути к выходу...", 3.5)
		elif opened_num >= 200 and not _victory_reached:
			_victory_reached = true
			_set_state(State.VICTORY)
			return

		if allow_spawn:
			_maybe_spawn_door_entities(opened_num)


func _trigger_power_outage() -> void:
	if _power_out:
		return
	_power_out = true
	audio.play_power_down()
	_show_toast("Электричество вырубилось! Дальше света больше не будет...", 3.4)
	_shake_amount = maxf(_shake_amount, 0.045)

	for r in _rooms:
		r.is_dark_room = true
		for i in range(r.ceiling_lights.size()):
			var omni := r.ceiling_lights[i]
			var base_e := r.light_base_energies[i]
			r.light_base_energies[i] = 0.0
			if not is_instance_valid(omni):
				continue
			var wr_omni: WeakRef = weakref(omni)
			var tw := create_tween()
			tw.tween_property(omni, "light_energy", base_e * 1.45, 0.04)
			tw.tween_property(omni, "light_energy", 0.02, 0.06)
			tw.tween_property(omni, "light_energy", base_e * 1.25, 0.05)
			tw.tween_property(omni, "light_energy", 0.0, 0.05)
			tw.tween_property(omni, "light_energy", base_e * 0.85, 0.06)
			tw.tween_property(omni, "light_energy", 0.0, 0.14)
			tw.tween_callback(func() -> void:
				var ref_om: Variant = wr_omni.get_ref()
				if ref_om is OmniLight3D and is_instance_valid(ref_om):
					var om := ref_om as OmniLight3D
					om.light_energy = 0.0
					om.visible = false
			)
		for m in r.lamp_meshes:
			if not is_instance_valid(m):
				continue
			var wr_m: WeakRef = weakref(m)
			var wr_assets: WeakRef = weakref(_assets)
			var mtw := create_tween()
			mtw.tween_interval(0.40)
			mtw.tween_callback(func() -> void:
				var ref_m: Variant = wr_m.get_ref()
				var ref_a: Variant = wr_assets.get_ref()
				if ref_m is MeshInstance3D and is_instance_valid(ref_m) and ref_a != null:
					var mm := ref_m as MeshInstance3D
					mm.material_override = (ref_a as RoomBuilder.SharedAssets).lamp_off_mat
			)


func _break_door_by_a60(r_idx: int, is_prime: bool) -> void:
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null:
		return
	r.door_opened = true
	r.door_broken = true
	if r.door_collider != null:
		r.door_collider.collision_layer = 0
		r.door_collider.collision_mask = 0
	if is_instance_valid(r.door_pivot):
		r.door_pivot.visible = false
		var anchor := r.door_pivot.get_parent()
		if is_instance_valid(anchor):
			var broken_root := Node3D.new()
			broken_root.name = "BrokenDoorSmashed"
			anchor.add_child(broken_root)

			var leaf_w := RoomBuilder.DOOR_W - 0.20
			var slab := Node3D.new()
			slab.position = Vector3(_rng.randf_range(-0.18, 0.18), 0.06, -1.42)
			slab.rotation = Vector3(-PI * 0.5 + 0.03, _rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.08, 0.08))
			broken_root.add_child(slab)
			RoomBuilder._add_box(slab, "SmashedLeaf", Vector3.ZERO, Vector3(leaf_w, RoomBuilder.DOOR_H - 0.06, 0.10), _assets.door_mat, false)
			RoomBuilder._add_box(slab, "SmashedKnob", Vector3(leaf_w * 0.5 - 0.18, -0.32, 0.075), Vector3(0.10, 0.06, 0.06), _assets.fridge_mat, false)

			var tex := _a60_last_tex if _a60_last_tex != null else _a60_frames[0]
			if tex != null:
				var imp := Sprite3D.new()
				imp.texture = tex
				imp.shaded = false
				imp.double_sided = true
				imp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				imp.pixel_size = 1.50 / float(maxi(tex.get_width(), 1))
				imp.modulate = Color(0.32, 0.92, 1.0, 0.90) if is_prime else Color(1.0, 0.22, 0.18, 0.88)
				imp.position = Vector3(0.0, 0.12, 0.062)
				slab.add_child(imp)

			for s_i in range(4):
				var sp := RoomBuilder._add_box(
					broken_root,
					"Splinter_%d" % s_i,
					Vector3(_rng.randf_range(-0.95, 0.95), 0.03, _rng.randf_range(-2.3, -0.35)),
					Vector3(_rng.randf_range(0.06, 0.14), 0.04, _rng.randf_range(0.28, 0.62)),
					_assets.plank_dark_mat,
					false
				)
				sp.rotation.y = _rng.randf_range(-PI, PI)

	audio.play_a60_door_break(is_prime)
	_shake_amount = maxf(_shake_amount, 0.09)
	_advance_door_progress(r_idx, false)


func _enter_locker(r_idx: int, l_idx: int) -> void:
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null or l_idx < 0 or l_idx >= r.lockers.size():
		return
	var locker_data: Dictionary = r.lockers[l_idx]
	var lnode: Node3D = locker_data["node"]

	_is_hiding = true
	_hiding_room_idx = r_idx
	_hiding_locker_idx = l_idx
	_hiding_kind = String(locker_data.get("kind", "locker"))
	_hiding_door_pivot = locker_data.get("door_pivot") as Node3D
	_hide_time = 0.0
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	_was_light_before_hide = _light_on
	if _hiding_kind == "under_desk":
		_light_on = false
	player_col.disabled = true
	if _vm_holder != null:
		_vm_holder.visible = false

	_locker_cam_from = cam.global_position
	_locker_transition_t = 0.0
	_locker_transition_entering = true
	_locker_transition_duration = 1.00

	var eye_loc: Vector3 = locker_data.get("eye_local", Vector3(0.0, 1.48, 0.05))
	var exit_loc: Vector3 = locker_data.get("exit_local", Vector3(0.0, 0.05, 1.05))
	_hiding_eye_local_y = eye_loc.y

	var gt := lnode.global_transform
	_locker_fwd = gt.basis.z.normalized()
	_locker_enter_from_yaw = atan2(_locker_fwd.x, _locker_fwd.z)
	_locker_eye = gt * eye_loc
	_locker_exit = gt * exit_loc

	if is_instance_valid(_hiding_door_pivot):
		var dp := _hiding_door_pivot
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(dp, "rotation:y", -PI * 0.64, 0.28)
		tw.tween_interval(0.40)
		tw.tween_property(dp, "rotation:y", -0.05, 0.32)

	if _hiding_kind == "under_desk":
		audio.play_desk_crawl(true)
	else:
		audio.play_locker_toggle(true)


func _exit_locker(face_locker: bool = false) -> void:
	var prev_kind := _hiding_kind
	var prev_door_pivot := _hiding_door_pivot
	_locker_cam_from = cam.global_position
	_locker_transition_t = 0.0
	_locker_transition_entering = false
	_locker_exit_face_locker = face_locker
	_locker_transition_duration = 0.70 if face_locker else 1.00

	_is_hiding = false
	_hiding_room_idx = -1
	_hiding_locker_idx = -1
	_hiding_kind = "locker"
	_hiding_door_pivot = null
	_hiding_eye_local_y = 1.48
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	audio.stop_darkness()
	(_ui["darkness_rect"] as Control).visible = false
	player_body.position = _locker_exit
	player_body.velocity = Vector3.ZERO
	player_col.disabled = false

	var exit_yaw := atan2(_locker_fwd.x, _locker_fwd.z) if face_locker else atan2(-_locker_fwd.x, -_locker_fwd.z)
	_locker_exit_from_yaw = player_body.rotation.y
	_locker_exit_to_yaw = exit_yaw + (0.0 if face_locker else _hide_yaw_offset)
	_target_yaw = _locker_exit_to_yaw
	_target_pitch = 0.0 if face_locker else _hide_pitch_offset
	_yaw = _locker_exit_from_yaw
	_pitch = cam.rotation.x
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	_light_on = _was_light_before_hide
	if _vm_holder != null:
		_vm_holder.visible = true

	if is_instance_valid(prev_door_pivot):
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		if face_locker:
			tw.tween_property(prev_door_pivot, "rotation:y", -PI * 0.62, 0.21)
			tw.tween_interval(0.21)
			tw.tween_property(prev_door_pivot, "rotation:y", 0.0, 0.28)
		else:
			tw.tween_property(prev_door_pivot, "rotation:y", -PI * 0.64, 0.30)
			tw.tween_interval(0.32)
			tw.tween_property(prev_door_pivot, "rotation:y", 0.0, 0.38)

	if prev_kind == "under_desk":
		audio.play_desk_crawl(false)
	else:
		audio.play_locker_toggle(false)


func _maybe_spawn_door_entities(room_num: int) -> void:
	if _a60_active or _a120_active:
		return
	# A-120 starts appearing after room A-015; A-60 spawns anytime via its independent timer!
	if room_num >= 15:
		var chance_120 := clampf(0.06 + float(room_num - 15) * 0.0007, 0.06, 0.13)
		if _rng.randf() < chance_120:
			_spawn_a120()


func _find_first_closed_door_room() -> RoomBuilder.RoomInstance:
	for r in _rooms:
		if not r.door_opened and not r.door_broken:
			return r
	return null


func _spawn_a60(force_prime: bool = false) -> void:
	_a60_path.clear()
	if _rooms.is_empty():
		return
	var target_r := _find_first_closed_door_room()
	if target_r == null:
		return
	_a60_target_door_idx = target_r.index
	var start_entry_dir: Vector3 = _rooms[0].in_dir
	_a60_path.append(_rooms[0].center_pos - start_entry_dir * 260.0 + Vector3(0.0, 1.55, 0.0))
	for r in _rooms:
		if r.index <= _a60_target_door_idx:
			_a60_path.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
			if r.index < _a60_target_door_idx:
				_a60_path.append(r.exit_pos + Vector3(0.0, 1.55, 0.0))
	_a60_path.append(target_r.exit_pos + Vector3(0.0, 1.55, 0.0))
	if _a60_path.size() < 2:
		return

	var is_prime := force_prime or (_highest_opened >= 50 and _rng.randf() < 0.30)
	_a60_active = true
	_a60_phase = 2
	_a60_is_prime = is_prime
	_a60_prime_rebounds = (1 if _rng.randf() < 0.65 else 0) if is_prime else 0
	_a60_scare_snd_cd = 0.0
	_a60_hint_timer = 2.4 if _highest_opened < 100 else 0.0

	if is_prime:
		_a60_light.light_color = Color(0.22, 0.84, 1.0)
		_a60_sprite.modulate = Color(0.55, 0.96, 1.0)
	else:
		_a60_light.light_color = Color(1.0, 0.14, 0.12)
		_a60_sprite.modulate = Color(1.0, 0.94, 0.94)

	_a60_path_idx = 1
	_a60_node.position = _a60_path[0]
	_a60_node.visible = true
	_flicker_nearby_lights(1.4)
	audio.start_a60_spawn(is_prime, _highest_opened < 100)


func _spawn_a120() -> void:
	if _rooms.is_empty():
		return
	var spawn_idx := mini(_highest_opened + 3, _rooms[-1].index)
	var spawn_r: RoomBuilder.RoomInstance = _room_by_idx.get(spawn_idx)
	if spawn_r == null:
		spawn_r = _rooms[-1]

	var roll := _rng.randf()
	var rb := 0
	if roll < 0.22:
		rb = 0
	elif roll < 0.52:
		rb = 1
	elif roll < 0.80:
		rb = 2
	else:
		rb = 3

	_a120_active = true
	_a120_phase = 1
	_a120_substage = 0
	_a120_warn_timer = 3.4
	_a120_pause_timer = 0.0
	_a120_rebounds = rb
	_a120_initial_rebounds = rb
	_a120_drum_bounce = 0.0
	_a120_anim_timer = 0.0
	_a120_hit_cd = 0.0
	_a120_path.clear()
	_a120_path_idx = 0
	_a120_sprite.position = Vector3.ZERO
	_a120_sprite.scale = Vector3.ONE
	_a120_node.position = spawn_r.center_pos + Vector3(0.0, 1.55, 0.0)
	_a120_node.visible = true
	_flicker_nearby_lights(1.6)
	audio.start_a120_spawn()


func _build_a120_corridor_path(from_room_idx: int, to_room_idx: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var step := 1 if to_room_idx >= from_room_idx else -1
	var cur := from_room_idx
	while true:
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(cur)
		if r != null:
			pts.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
		if cur == to_room_idx:
			break
		cur += step
	return pts


func _get_room_idx_near(pos: Vector3) -> int:
	var best_idx := _current_room_idx
	var best_dist := 1e9
	for r in _rooms:
		var d := r.center_pos.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best_idx = r.index
	return best_idx


func _get_a120_live_target() -> Vector3:
	if _is_hiding:
		var front := _locker_eye + _locker_fwd * 0.95
		return Vector3(front.x, 1.55, front.z)
	return Vector3(player_body.global_position.x, 1.55, player_body.global_position.z)


func _handle_a120_hit() -> void:
	_a120_hit_cd = 1.0
	_a120_active = false
	_a120_phase = 0
	_a120_node.visible = false
	audio.play_a120_scream()

	_hp -= 40
	audio.low_hp_mode = (_hp <= 25 and _hp > 0)
	_shake_amount = 0.12

	if _hp <= 0:
		_trigger_death("A-120", "", {"a120_rebounded": _a120_rebounds < _a120_initial_rebounds})
		return

	var warp_safe_min := _checkpoint_room + 4
	var back_steps := _rng.randi_range(3, 4)
	var target_idx := _current_room_idx - back_steps
	if _current_room_idx >= warp_safe_min and target_idx > _checkpoint_room and _room_by_idx.has(target_idx):
		_warp_player_to_room(target_idx, back_steps)
	else:
		(_ui["dmg_flash"] as ColorRect).color = Color(0.85, 0.08, 0.08, 0.65)
		_show_toast("Happy Scribble (A-120) нанёс 40 урона! (%d HP)" % _hp, 2.6)


func _warp_player_to_room(target_idx: int, back_steps: int) -> void:
	var target_r: RoomBuilder.RoomInstance = _room_by_idx.get(target_idx)
	if target_r == null:
		return
	player_body.position = target_r.center_pos + Vector3(0.0, 0.05, 0.0)
	player_body.velocity = Vector3.ZERO
	_current_room_idx = target_idx
	_update_room_visibility()

	var dir := target_r.out_dir
	var face_yaw := atan2(-dir.x, -dir.z)
	_target_yaw = face_yaw
	_yaw = face_yaw
	_target_pitch = 0.0
	_pitch = 0.0
	_apply_camera_rotation()
	_fov = 104.0
	cam.fov = 104.0

	(_ui["dmg_flash"] as ColorRect).color = Color(0.85, 0.96, 1.0, 0.78)
	_show_toast("ВАРП! Happy Scribble отбросил вас на %d комн. назад (A-%03d) [-40 HP]" % [back_steps, target_idx], 3.4)


func _flicker_nearby_lights(duration: float) -> void:
	if _power_out:
		return
	# Subtle momentary dip via tweening lights on active rooms
	for r in _rooms:
		if r.is_dark_room:
			continue
		for i in range(r.ceiling_lights.size()):
			var omni := r.ceiling_lights[i]
			var base_e := r.light_base_energies[i]
			var tw := create_tween()
			tw.tween_property(omni, "light_energy", base_e * 0.12, 0.08)
			tw.tween_property(omni, "light_energy", base_e, 0.12)
			tw.tween_property(omni, "light_energy", base_e * 0.05, 0.09)
			tw.tween_property(omni, "light_energy", base_e, duration * 0.25)


func _physics_process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	_run_time += delta
	_process_doors(delta)
	_process_flashlight(delta)

	if _highest_opened >= 5 and not _a60_active and not _a120_active:
		_a60_random_timer -= delta
		if _a60_random_timer <= 0.0:
			var max_cd := maxf(24.0, 52.0 - float(_highest_opened) * 0.12)
			var min_cd := maxf(14.0, max_cd * 0.52)
			_a60_random_timer = _rng.randf_range(min_cd, max_cd)
			_spawn_a60()

	_process_entities(delta)
	_process_player_movement(delta)
	_update_ui(delta)


func _process_doors(delta: float) -> void:
	for i in range(_opening_doors.size() - 1, -1, -1):
		var d: Dictionary = _opening_doors[i]
		var pivot_raw: Variant = d["pivot"]
		if not is_instance_valid(pivot_raw):
			_opening_doors.remove_at(i)
			continue
		var p: float = minf(float(d["progress"]) + delta * 3.8, 1.0)
		d["progress"] = p
		var pivot := pivot_raw as Node3D
		pivot.rotation.y = lerpf(0.0, -PI * 0.56, 1.0 - pow(1.0 - p, 2.0))
		if p >= 1.0:
			_opening_doors.remove_at(i)


func _process_flashlight(delta: float) -> void:
	if not _is_hiding and _std_low_power and (not _light_on or _active_tool != 0):
		_std_low_power_regen += delta
		if _std_low_power_regen >= 14.0:
			_std_low_power = false
			_std_low_power_regen = 0.0

	var has_charge := (_std_battery > 0.05) if _active_tool == 0 else (_gummy_battery > 0.05)
	var is_lit := _light_on and has_charge
	if is_lit:
		var power_mult := 1.0
		if _active_tool == 0:
			_std_battery = maxf(_std_battery - delta * 1.45, 0.0)
			if _std_low_power:
				flashlight.light_color = Color(1.0, 0.78, 0.56)
				flashlight.spot_range = 14.0
				flashlight.spot_angle = 30.0
				power_mult = 0.44
			else:
				flashlight.light_color = Color(1.0, 0.96, 0.88)
				flashlight.spot_range = 24.0
				flashlight.spot_angle = 36.0
		else:
			_gummy_battery = maxf(_gummy_battery - delta * 10.0, 0.0)
			flashlight.light_color = Color(0.35, 1.0, 0.52)
			flashlight.spot_range = 20.0
			flashlight.spot_angle = 40.0

		var cur_bat := _std_battery if _active_tool == 0 else _gummy_battery
		var flicker := 1.0
		if cur_bat < 16.0 and _rng.randf() < 0.22:
			flicker = _rng.randf_range(0.25, 0.85)
		flashlight.light_energy = 2.6 * power_mult * flicker
		flashlight.visible = true
	else:
		flashlight.visible = false

	if _vm_std_bulb != null:
		_vm_std_bulb.material_override = _vm_bulb_on_mat if (is_lit and _active_tool == 0) else _vm_bulb_off_mat
	if _vm_gummy_bulb != null:
		_vm_gummy_bulb.material_override = _vm_gummy_on_mat if (is_lit and _active_tool == 1) else _vm_bulb_off_mat


func _process_darkness_in_hiding(delta: float) -> void:
	var dk_rect: TextureRect = _ui["darkness_rect"]
	if _highest_opened < 21:
		dk_rect.visible = false
		if not _a60_active and not _a120_active:
			_hide_time += delta
			if _hide_time > 18.0:
				_show_toast("Пора выходить из укрытия!", 1.2)
		return

	_hide_time += delta
	var prog := clampf(float(_highest_opened - 21) / 29.0, 0.0, 1.0)
	var disturb_delay := 1.2 if _power_out else lerpf(7.5, 1.4, prog)
	if _darkness_quick_return:
		disturb_delay = 2.0 if (_light_on and _active_tool == 0) else 0.6

	if _darkness_phase == 0:
		dk_rect.visible = false
		audio.stop_darkness()
		if _hide_time >= disturb_delay:
			_darkness_phase = 1
			_darkness_whisper_t = 0.0
			_darkness_dmg_accum = 0.0
			audio.start_darkness()
			dk_rect.visible = true
			dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.05)
	elif _darkness_phase == 1:
		var ramp_dur := 1.2 if _power_out else 2.0
		_darkness_whisper_t = minf(_darkness_whisper_t + delta / ramp_dur, 1.0)
		audio.update_darkness(_darkness_whisper_t)
		dk_rect.visible = true
		var s := lerpf(0.82, 1.08, _darkness_whisper_t)
		dk_rect.scale = Vector2(s, s)
		dk_rect.pivot_offset = dk_rect.size * 0.5
		dk_rect.modulate = Color(1.0, 1.0, 1.0, pow(_darkness_whisper_t, 1.15) * 0.94)
		if _darkness_whisper_t >= 1.0:
			_darkness_phase = 2
			_darkness_dmg_accum = 0.36
	elif _darkness_phase == 2:
		audio.update_darkness(1.0)
		dk_rect.visible = true
		var pulse_s := 1.06 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.014)
		dk_rect.scale = Vector2(pulse_s, pulse_s)
		dk_rect.pivot_offset = dk_rect.size * 0.5
		dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.98)
		_shake_amount = maxf(_shake_amount, 0.038)
		_darkness_dmg_accum += delta
		if _darkness_dmg_accum >= 0.42:
			_darkness_dmg_accum -= 0.42
			_hp -= 18
			audio.low_hp_mode = (_hp <= 25 and _hp > 0)
			(_ui["dmg_flash"] as ColorRect).color = Color(0.88, 0.04, 0.04, 0.56)
			if _hp <= 0:
				_trigger_death("The Darkness")
				return


func _process_player_movement(delta: float) -> void:
	if _is_hiding:
		_process_darkness_in_hiding(delta)
		return

	var inp := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		inp.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		inp.y += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		inp.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		inp.x -= 1.0
	if _joy_vec.length_squared() > 0.01:
		inp += _joy_vec
	if inp.length_squared() > 1.0:
		inp = inp.normalized()

	var moving := inp.length_squared() > 0.01
	var wants_sprint := (Input.is_key_pressed(KEY_SHIFT) or _joy_sprint or _mobile_sprint_held) and moving and (not _exhausted) and _stamina > 0.01
	if wants_sprint:
		_stamina = maxf(_stamina - delta * 0.34, 0.0)
		_stamina_regen_delay = 0.65
		if _stamina <= 0.01:
			_exhausted = true
			_pant_timer = 0.08
	else:
		if _stamina_regen_delay > 0.0:
			_stamina_regen_delay = maxf(_stamina_regen_delay - delta, 0.0)
		else:
			var rec_rate := 0.12 if _exhausted else 0.22
			_stamina = minf(_stamina + delta * rec_rate, 1.0)
		if _exhausted and _stamina >= 0.35:
			_exhausted = false

	if _exhausted:
		_pant_timer -= delta
		if _pant_timer <= 0.0:
			_pant_timer = 0.44
			audio.play_pant(_pant_inhale)
			_pant_inhale = not _pant_inhale

	_cam_roll = lerpf(_cam_roll, -inp.x * 0.020, 1.0 - exp(-10.0 * delta))

	var speed := 3.7
	if wants_sprint:
		speed = 6.2
	elif _exhausted:
		speed = 2.8
	var dir := (player_body.transform.basis * Vector3(inp.x, 0.0, inp.y)).normalized()

	player_body.velocity.x = lerpf(player_body.velocity.x, dir.x * speed, minf(delta * 11.0, 1.0))
	player_body.velocity.z = lerpf(player_body.velocity.z, dir.z * speed, minf(delta * 11.0, 1.0))
	if not player_body.is_on_floor():
		player_body.velocity.y -= 18.0 * delta
	else:
		player_body.velocity.y = 0.0

	player_body.move_and_slide()

	# Footsteps & camera bobbing (surface-aware: metal grate floors play louder iron footsteps!)
	var horiz_spd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
	if horiz_spd > 0.7:
		_bob_phase += delta * (10.5 if wants_sprint else 6.8)
		_step_timer -= delta * (1.42 if wants_sprint else 0.90)
		if _step_timer <= 0.0:
			_step_timer = 0.48
			audio.play_step(wants_sprint, _detect_floor_surface())
	else:
		_bob_phase = lerpf(_bob_phase, 0.0, delta * 5.0)

	_shake_amount = maxf(_shake_amount - delta * 0.14, 0.0)
	var shake_off := Vector3(
		_rng.randf_range(-_shake_amount, _shake_amount),
		_rng.randf_range(-_shake_amount, _shake_amount),
		0.0
	)
	var breath_bob := sin(float(Time.get_ticks_msec()) * 0.0055) * (0.022 if _exhausted else 0.0)
	if _locker_transition_t >= 1.0:
		cam.position = Vector3(0.0, 1.48 + sin(_bob_phase) * 0.032 + breath_bob, 0.0) + shake_off

	# Track current room closest to player (adapted for 12m room grid)
	var prev_room := _current_room_idx
	for r in _rooms:
		if r.center_pos.distance_to(player_body.position) < RoomBuilder.CELL_SIZE * 0.52:
			_current_room_idx = r.index
			break
	if _current_room_idx != prev_room:
		_update_room_visibility()


func _detect_floor_surface() -> String:
	for i in range(player_body.get_slide_collision_count()):
		var kc := player_body.get_slide_collision(i)
		if kc != null and kc.get_normal().y > 0.5:
			var col := kc.get_collider()
			if col != null and col.has_meta("floor_surface"):
				return String(col.get_meta("floor_surface"))
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var p := player_body.global_position
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.35, 0), p - Vector3(0, 0.55, 0), 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var c: Object = hit.get("collider")
			if c != null and c.has_meta("floor_surface"):
				return String(c.get_meta("floor_surface"))
	return "carpet"


func _process_entities(delta: float) -> void:
	# --- A-60 / MultiMonster & Prime Variant (A-60') ---
	var static_rect: ColorRect = _ui["static_rect"]
	var static_mat: ShaderMaterial = _ui["static_mat"]
	var a60_scare_rect: TextureRect = _ui["a60_scare_rect"]
	if _a60_scare_snd_cd > 0.0:
		_a60_scare_snd_cd = maxf(_a60_scare_snd_cd - delta, 0.0)

	if _a60_active:
		_a60_anim_timer += delta
		var flip_interval := 0.035 if _a60_is_prime else 0.045
		if _a60_anim_timer > flip_interval:
			_a60_anim_timer = 0.0
			_a60_frame_idx = (_a60_frame_idx + _rng.randi_range(1, 5)) % _a60_frames.size()
			var f60 := _a60_frames[_a60_frame_idx]
			_a60_last_tex = f60
			_a60_sprite.texture = f60
			_a60_sprite.pixel_size = 2.65 / float(maxi(f60.get_width(), 1))

		var d_player := _a60_node.global_position.distance_to(cam.global_position)
		audio.a60_intensity = clampf(16.0 / maxf(d_player, 2.0), 0.12, 1.0)
		audio.update_a60_mix(delta, d_player, _a60_phase, _a60_is_prime)

		var prime_col := Vector3(0.25, 0.85, 1.0) if _a60_is_prime else Vector3(1.0, 0.22, 0.18)
		static_mat.set_shader_parameter("tint_col", prime_col)

		if _a60_hint_timer > 0.0:
			_a60_hint_timer = maxf(_a60_hint_timer - delta, 0.0)

		if _a60_phase == 2:
			# Before A-100 arrival hint static & near static (NO red/dark vignette per user request)
			var near_prox := clampf(1.0 - (d_player - 2.0) / 22.0, 0.0, 1.0)
			_shake_amount = maxf(_shake_amount, near_prox * (0.14 if _a60_is_prime else 0.11))

			var hint_static := 0.0
			if _a60_hint_timer > 0.0 and _highest_opened < 100:
				var fade := clampf(_a60_hint_timer / 0.85, 0.0, 1.0)
				hint_static = fade * (0.55 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.015))

			var total_static := maxf(hint_static, near_prox * 0.65)
			if total_static > 0.03:
				static_rect.visible = true
				static_mat.set_shader_parameter("static_amt", total_static)
				static_mat.set_shader_parameter("vig_amt", 0.0)
			else:
				static_rect.visible = false

			# Keep tracking the FIRST still-closed door in case player opened target mid-rush
			var live_closed_r: RoomBuilder.RoomInstance = _room_by_idx.get(_a60_target_door_idx)
			if live_closed_r != null and (live_closed_r.door_opened or live_closed_r.door_broken):
				var next_closed := _find_first_closed_door_room()
				if next_closed != null and next_closed.index > _a60_target_door_idx:
					var old_idx := _a60_target_door_idx
					_a60_target_door_idx = next_closed.index
					for r in _rooms:
						if r.index > old_idx and r.index <= _a60_target_door_idx:
							_a60_path.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
							if r.index < _a60_target_door_idx:
								_a60_path.append(r.exit_pos + Vector3(0.0, 1.55, 0.0))
					_a60_path.append(next_closed.exit_pos + Vector3(0.0, 1.55, 0.0))

			var rush_speed := 78.0 if _a60_is_prime else 60.0
			if _a60_path_idx < _a60_path.size():
				var tgt := _a60_path[_a60_path_idx]
				var to_t := tgt - _a60_node.position
				if to_t.length() <= rush_speed * delta:
					_a60_node.position = tgt
					_a60_path_idx += 1
				else:
					_a60_node.position += to_t.normalized() * rush_speed * delta
			else:
				if _a60_is_prime and _a60_prime_rebounds > 0:
					_a60_prime_rebounds -= 1
					audio.play_a60_door_break(true)
					_a60_path_idx = maxi(1, _a60_path.size() - 5)
				else:
					var smash_r: RoomBuilder.RoomInstance = _room_by_idx.get(_a60_target_door_idx)
					if smash_r != null and not smash_r.door_opened and not smash_r.door_broken:
						_break_door_by_a60(_a60_target_door_idx, _a60_is_prime)
					_a60_phase = 3
					_a60_sink_timer = 0.42
					a60_scare_rect.visible = false

			# Raycast line-of-sight ONE-SHOT kill if player is exposed and not hiding
			if _a60_phase == 2 and d_player <= 11.5 and not _is_hiding:
				var space := get_world_3d().direct_space_state
				var q := PhysicsRayQueryParameters3D.create(_a60_node.global_position, cam.global_position)
				q.exclude = [player_body.get_rid()]
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					a60_scare_rect.visible = true
					a60_scare_rect.texture = _a60_sprite.texture
					a60_scare_rect.modulate = Color(0.55, 0.95, 1.0, 0.96) if _a60_is_prime else Color(1.0, 0.92, 0.92, 0.96)
					var vp := get_viewport().get_visible_rect().size
					a60_scare_rect.position = vp * 0.5 - Vector2(270, 270)
					audio.play_a60_jumpscare(_a60_is_prime)
					_hp = 0
					audio.low_hp_mode = false
					(_ui["dmg_flash"] as ColorRect).color = Color(0.35, 0.90, 1.0, 0.72) if _a60_is_prime else Color(0.92, 0.08, 0.08, 0.78)
					_trigger_death("A-60'" if _a60_is_prime else "A-60", "", {"distance": d_player})
					return
				else:
					a60_scare_rect.visible = false
			else:
				a60_scare_rect.visible = false
		elif _a60_phase == 3:
			a60_scare_rect.visible = false
			static_rect.visible = false
			_a60_sink_timer -= delta
			var sink_p := 1.0 - clampf(_a60_sink_timer / 0.42, 0.0, 1.0)
			_a60_node.position.y = lerpf(1.55, -1.85, ease(sink_p, 2.0))
			_a60_sprite.modulate.a = 1.0 - sink_p
			if _a60_sink_timer <= 0.0:
				_a60_active = false
				_a60_phase = 0
				_a60_node.visible = false
				_a60_sprite.modulate.a = 1.0
				audio.stop_a60()
	else:
		audio.a60_intensity = lerpf(audio.a60_intensity, 0.0, minf(delta * 4.0, 1.0))
		static_rect.visible = false
		a60_scare_rect.visible = false

	# --- A-120 (Happy Scribble) ---
	if _a120_hit_cd > 0.0:
		_a120_hit_cd = maxf(_a120_hit_cd - delta, 0.0)

	if _a120_active:
		var d120 := _a120_node.global_position.distance_to(cam.global_position)
		var drum_hit := audio.update_a120_mix(delta, d120, _a120_phase)
		_a120_anim_timer += delta
		if _a120_anim_timer >= 0.50:
			_a120_anim_timer -= 0.50
			_a120_frame_idx = (_a120_frame_idx + 1) % _a120_frames.size()
			var f120 := _a120_frames[_a120_frame_idx]
			_a120_sprite.texture = f120
			_a120_sprite.pixel_size = 2.55 / float(maxi(f120.get_width(), 1))
		if drum_hit:
			_a120_drum_bounce = 1.0

		if _a120_drum_bounce > 0.0:
			_a120_drum_bounce = maxf(_a120_drum_bounce - delta * 4.4, 0.0)
			var b := _a120_drum_bounce
			_a120_sprite.position.y = sin(b * PI) * 0.34
			_a120_sprite.scale = Vector3(1.0 + sin(b * PI) * 0.16, 1.0 - sin(b * PI) * 0.10 + (1.0 - cos(b * PI)) * 0.06, 1.0)
		else:
			_a120_sprite.position.y = 0.0
			_a120_sprite.scale = Vector3.ONE

		if _a120_phase == 1:
			_a120_warn_timer -= delta
			_shake_amount = maxf(_shake_amount, 0.012)
			if _a120_warn_timer <= 0.0:
				_a120_phase = 2
				_a120_substage = 0
				_a120_path = _build_a120_corridor_path(_get_room_idx_near(_a120_node.position), _current_room_idx)
				_a120_path_idx = 0
		elif _a120_phase == 2:
			if _a120_pause_timer > 0.0:
				_a120_pause_timer -= delta
			else:
				var spd120 := 15.0
				if _a120_substage == 0:
					var live_tgt := _get_a120_live_target()
					var move_tgt := live_tgt
					if _a120_path_idx < _a120_path.size() and _get_room_idx_near(_a120_node.position) != _current_room_idx:
						move_tgt = _a120_path[_a120_path_idx]
					var to_m := move_tgt - _a120_node.position
					if to_m.length() <= spd120 * delta:
						_a120_node.position = move_tgt
						if move_tgt.distance_to(live_tgt) < 1.25:
							var min_room := _rooms[0].index if not _rooms.is_empty() else 0
							var prev_idx := maxi(min_room, _current_room_idx - _rng.randi_range(2, 4))
							if prev_idx == _current_room_idx and min_room < _current_room_idx:
								prev_idx = _current_room_idx - 1
							_a120_substage = 1
							_a120_path = _build_a120_corridor_path(_current_room_idx, prev_idx)
							if prev_idx == _current_room_idx and _room_by_idx.has(_current_room_idx):
								var cr: RoomBuilder.RoomInstance = _room_by_idx[_current_room_idx]
								_a120_path = [cr.center_pos - cr.in_dir * 4.5 + Vector3(0.0, 1.55, 0.0)]
							_a120_path_idx = 0
						else:
							_a120_path_idx += 1
					else:
						_a120_node.position += to_m.normalized() * spd120 * delta
				elif _a120_substage == 1:
					if _a120_path_idx < _a120_path.size():
						var tgt := _a120_path[_a120_path_idx]
						var to_t := tgt - _a120_node.position
						if to_t.length() <= spd120 * delta:
							_a120_node.position = tgt
							_a120_path_idx += 1
						else:
							_a120_node.position += to_t.normalized() * spd120 * delta
					else:
						if _a120_rebounds > 0:
							_a120_rebounds -= 1
							_a120_pause_timer = 0.38
							_a120_substage = 0
							_a120_path = _build_a120_corridor_path(_get_room_idx_near(_a120_node.position), _current_room_idx)
							_a120_path_idx = 0
						else:
							# Smooth retreat backwards into the far distance until completely inaudible
							_a120_substage = 2
							var min_idx := _rooms[0].index if not _rooms.is_empty() else 0
							var cur_near := _get_room_idx_near(_a120_node.position)
							_a120_path = _build_a120_corridor_path(cur_near, min_idx)
							if not _rooms.is_empty():
								var first_r := _rooms[0]
								_a120_path.append(first_r.center_pos - first_r.in_dir * 185.0 + Vector3(0.0, 1.55, 0.0))
							_a120_path_idx = 0
				elif _a120_substage == 2:
					if _a120_path_idx < _a120_path.size():
						var tgt := _a120_path[_a120_path_idx]
						var to_t := tgt - _a120_node.position
						if to_t.length() <= spd120 * delta:
							_a120_node.position = tgt
							_a120_path_idx += 1
						else:
							_a120_node.position += to_t.normalized() * spd120 * delta
					if d120 >= 165.0 or _a120_path_idx >= _a120_path.size():
						_a120_active = false
						_a120_phase = 0
						_a120_substage = 0
						_a120_node.visible = false
						audio.stop_a120()

			if _a120_active and _a120_node.global_position.distance_to(cam.global_position) < 2.15 and not _is_hiding and _a120_hit_cd <= 0.0:
				_handle_a120_hit()
				return

	# --- A-90 / Paralysis (Freeze check, starts around A-009+) ---
	if _a90_scare_timer > 0.0:
		_a90_scare_timer -= delta
		var scare_rect: TextureRect = _ui["a90_scare_rect"]
		scare_rect.modulate.a = clampf(_a90_scare_timer / 0.45, 0.0, 1.0)
		if _a90_scare_timer <= 0.0:
			scare_rect.visible = false

	var a90_rect: TextureRect = _ui["a90_rect"]
	var a90_stop_icon: TextureRect = _ui["a90_stop_icon"]
	var a90_stop: Label = _ui["a90_stop"]
	if _a90_phase == 0:
		a90_rect.visible = false
		a90_stop_icon.visible = false
		a90_stop.visible = false
		if _highest_opened >= 9 and not _is_hiding:
			_a90_cooldown -= delta
			if _a90_cooldown <= 0.0:
				_a90_cooldown = _rng.randf_range(20.0, 34.0)
				if _rng.randf() < 0.72:
					_a90_phase = 1
					_a90_timer = 1.05
					var vp_sz := get_viewport().get_visible_rect().size
					_a90_pos_offset = vp_sz * 0.5 - Vector2(155, 155) + Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-70, 70))
					a90_rect.position = _a90_pos_offset
					a90_rect.texture = _a90_textures["warn"]
					a90_rect.visible = true
					audio.play_a90_warn()
	elif _a90_phase == 1:
		_a90_timer -= delta
		a90_rect.position = _a90_pos_offset + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
		if _a90_timer <= 0.0:
			_a90_phase = 2
			_a90_timer = 0.72
			player_body.velocity.x *= 0.20
			player_body.velocity.z *= 0.20
			_a90_start_pos = player_body.position
			_a90_start_yaw = _target_yaw
			_a90_start_pitch = _target_pitch
			a90_rect.position = get_viewport().get_visible_rect().size * 0.5 - Vector2(155, 155)
			a90_rect.texture = _a90_textures.get("warn")
			a90_stop_icon.visible = true
			a90_stop.visible = true
	elif _a90_phase == 2:
		_a90_timer -= delta
		var center_pos := get_viewport().get_visible_rect().size * 0.5 - Vector2(155, 155)
		a90_rect.position = center_pos + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		var moved := player_body.position.distance_to(_a90_start_pos) > 0.18
		var turned := absf(_target_yaw - _a90_start_yaw) > 0.085 or absf(_target_pitch - _a90_start_pitch) > 0.085
		if moved or turned:
			_a90_phase = 0
			a90_rect.visible = false
			a90_stop_icon.visible = false
			a90_stop.visible = false
			_hp -= 90
			audio.play_a90_hit()
			audio.low_hp_mode = (_hp <= 25 and _hp > 0)
			(_ui["dmg_flash"] as ColorRect).color = Color(0.85, 0.05, 0.05, 0.72)
			_shake_amount = 0.09
			if _hp <= 0:
				_trigger_death("A-90", "", {"a90_moved": moved, "a90_turned": turned})
				return
			_a90_scare_timer = 0.45
			var scare_rect: TextureRect = _ui["a90_scare_rect"]
			scare_rect.texture = _a90_textures["rage"]
			scare_rect.modulate.a = 0.95
			scare_rect.visible = true
			_show_toast("A-90 нанёс 90 урона! Замирайте полностью!", 2.5)
		elif _a90_timer <= 0.0:
			_a90_phase = 3
			_a90_timer = 0.14
			a90_stop_icon.visible = false
			a90_stop.visible = false
			a90_rect.position = center_pos
			a90_rect.texture = _a90_textures.get("pre", _a90_textures["warn"])
	elif _a90_phase == 3:
		_a90_timer -= delta
		if _a90_timer <= 0.0:
			_a90_phase = 0
			a90_rect.visible = false
			a90_stop_icon.visible = false
			a90_stop.visible = false


func _update_ui(delta: float) -> void:
	var dmg: ColorRect = _ui["dmg_flash"]
	if dmg.color.a > 0.005:
		dmg.color.a = maxf(dmg.color.a - delta * 1.4, 0.0)
	dmg.visible = (dmg.color.a > 0.004)

	var toast_ctrl: Control = _ui["toast"]
	if _toast_timer > 0.0:
		_toast_timer = maxf(_toast_timer - delta, 0.0)
	var want_toast := _toast_timer > 0.45
	var toast_rate := 8.5 if want_toast else 5.2
	_toast_alpha = lerpf(_toast_alpha, 1.0 if want_toast else 0.0, clampf(1.0 - exp(-toast_rate * delta), 0.0, 1.0))
	toast_ctrl.modulate.a = _toast_alpha
	toast_ctrl.visible = (_toast_alpha > 0.01 or _toast_timer > 0.0)

	var vitals_rect: ColorRect = _ui["vitals_rect"]
	var vitals_mat: ShaderMaterial = _ui["vitals_mat"]
	var hp_target := 1.0 - clampf(float(_hp) / 100.0, 0.0, 1.0)
	var stam_target := 1.0 - clampf(_stamina, 0.0, 1.0)
	var ex_target := 1.0 if _exhausted else 0.0
	var dk_target := clampf(_darkness_whisper_t * 0.90 if _darkness_phase == 1 else (1.0 if _darkness_phase == 2 else 0.0), 0.0, 1.0)
	var smooth := clampf(delta * 6.0, 0.0, 1.0)
	var max_vital := 0.0
	for pair in [["hp_loss", hp_target], ["stam_loss", stam_target], ["exhausted_amt", ex_target], ["darkness_amt", dk_target]]:
		var k: String = String(pair[0])
		var tgt_v: float = float(pair[1])
		var raw_v: Variant = vitals_mat.get_shader_parameter(k)
		var prev_v: float = float(raw_v) if raw_v != null else 0.0
		var next_v := lerpf(prev_v, tgt_v, smooth)
		vitals_mat.set_shader_parameter(k, next_v)
		max_vital = maxf(max_vital, next_v)
	vitals_rect.visible = (max_vital > 0.004)

	var interact_tgt := {}
	var prompt: Label = _ui["prompt_lbl"]
	var want_prompt := false
	var vp_sz := get_viewport().get_visible_rect().size
	var vp_center := vp_sz * 0.5

	if _is_hiding:
		_smart_reticle_target = {}
		if _reticle_ring != null:
			_reticle_ring.visible = false
		if _hiding_kind == "under_desk":
			prompt.text = "[W / S / E] Вылезти из-под тумбочки"
		elif _hiding_kind == "fridge":
			prompt.text = "[W / E] Выйти вперёд  |  [S] Выйти лицом к холодильнику"
		else:
			prompt.text = "[W / E] Выйти вперёд  |  [S] Выйти лицом к шкафу"
		want_prompt = true
	else:
		interact_tgt = _find_smart_reticle_target()
		_smart_reticle_target = interact_tgt
		var yaw_lag := wrapf(_target_yaw - _yaw, -PI, PI)
		var pitch_lag := _target_pitch - _pitch
		var desired_lag := Vector2(clampf(yaw_lag * 360.0, -48.0, 48.0), clampf(pitch_lag * 300.0, -36.0, 36.0))
		var lag_in_a := clampf(1.0 - exp(-12.5 * delta), 0.0, 1.0)
		_reticle_lag_offset = _reticle_lag_offset.lerp(desired_lag, lag_in_a)

		var tgt_r := 6.5
		var tgt_stroke := 1.9
		var tgt_pos := vp_center + _reticle_lag_offset
		if not interact_tgt.is_empty():
			tgt_r = 19.5
			tgt_stroke = 2.8
			if interact_tgt.has("world_pos"):
				var wp: Vector3 = interact_tgt["world_pos"]
				if not cam.is_position_behind(wp):
					tgt_pos = cam.unproject_position(wp)
			prompt.text = String(interact_tgt["label"])
			want_prompt = not _mobile_controls_enabled

		if _reticle_ring != null:
			_reticle_ring.visible = true
			var ret_a := clampf(1.0 - exp(-10.5 * delta), 0.0, 1.0)
			if _reticle_screen_pos == Vector2.ZERO:
				_reticle_screen_pos = tgt_pos
			_reticle_screen_pos = _reticle_screen_pos.lerp(tgt_pos, ret_a)
			_reticle_radius = lerpf(_reticle_radius, tgt_r, clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			_reticle_ring.ring_radius = _reticle_radius
			_reticle_ring.stroke_width = lerpf(_reticle_ring.stroke_width, tgt_stroke, clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			_reticle_ring.position = _reticle_screen_pos - _reticle_ring.size * 0.5
			_reticle_ring.queue_redraw()

	var pr_rate := 12.0 if want_prompt else 8.5
	_prompt_alpha = lerpf(_prompt_alpha, 1.0 if want_prompt else 0.0, clampf(1.0 - exp(-pr_rate * delta), 0.0, 1.0))
	prompt.modulate.a = _prompt_alpha
	prompt.visible = (_prompt_alpha > 0.01)

	if _ui.has("reminder_lbl"):
		var rem: Label = _ui["reminder_lbl"]
		var want_rem := (not _reminder_dismissed and not _is_hiding)
		if want_rem:
			rem.text = "Reminder: [WHITE] to turn flashlight." if _mobile_controls_enabled else "Reminder: [F] to turn flashlight."
		var rem_rate := 6.5 if want_rem else 5.5
		_reminder_alpha = lerpf(_reminder_alpha, 1.0 if want_rem else 0.0, clampf(1.0 - exp(-rem_rate * delta), 0.0, 1.0))
		rem.modulate.a = _reminder_alpha
		rem.visible = (_reminder_alpha > 0.01)

	_update_mobile_ui(interact_tgt)


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

	if _is_hiding:
		b_light.visible = false
		b_sprint.visible = false
		b_gummy.visible = false
		b_fwd.visible = true
		b_back.visible = (_hiding_kind != "under_desk")
	else:
		b_fwd.visible = false
		b_back.visible = false
		b_light.visible = true
		b_sprint.visible = true
		b_gummy.visible = _has_gummy

	b_light.ring_color = Color(1.0, 1.0, 1.0, 0.96) if _light_on else Color(0.88, 0.90, 0.94, 0.65)
	b_light.queue_redraw()
	b_sprint.ring_color = Color(0.28, 0.62, 1.0, 1.0) if (_mobile_sprint_held or _joy_sprint) else Color(0.14, 0.44, 1.0, 0.95)
	b_sprint.queue_redraw()
	if _has_gummy:
		b_gummy.ring_color = Color(0.32, 1.0, 0.56, 1.0) if _active_tool == 1 else Color(0.22, 0.78, 0.44, 0.68)
		b_gummy.queue_redraw()


func _show_toast(msg: String, duration: float = 2.8) -> void:
	var lbl := _ui["toast_lbl"] as Label
	if not lbl.visible or lbl.text != msg:
		_toast_alpha = 0.0
		lbl.modulate.a = 0.0
	lbl.text = msg
	lbl.visible = true
	_toast_timer = maxf(duration, 1.1)
