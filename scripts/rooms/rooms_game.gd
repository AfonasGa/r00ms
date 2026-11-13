extends Node3D

## Rooms-inspired 3D procedural horror runner (A-000 -> A-200+ Endless) inside Godot 4.7.

enum State { PLAYING, PAUSED, DEAD, VICTORY, SPECTATING }
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
var _world_seed := 0
var _is_sprinting := false
var _door_hand_timer := 0.0
var _door_hand_slam := false

# Death transition phases (0=red flash, 1=shrink to center, 2=architect fade & talk) + spectator
var _death_phase := 0
var _death_phase_t := 0.0
var _spectate_key := ""
var _spectate_yaw := 0.0
var _spectate_pitch := 0.28
var _spectate_last_hiding := false
var _spectate_user_orbited := false

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
var _gummy_pump_phase := 0.0
var _rmb_held := false
var _vm_bulb_on_mat: StandardMaterial3D
var _vm_bulb_off_mat: StandardMaterial3D
var _vm_gummy_on_mat: StandardMaterial3D
var _anim_hand: Node3D = null

# Flashlights & Batteries
var _light_on := true
var _active_tool := 0 # 0 = standard, 1 = gummy
var _has_gummy := false
var _std_battery := 150.0 # 120s normal + 30s Low Battery Mode
var _gummy_battery := 100.0
var _batteries := 0
var _was_light_before_hide := true
var _std_low_power := false
var _std_low_power_regen := 0.0
var _std_low_flicker_t := 0.0

# Entities
var _a60_frames: Array[Texture2D] = []
var _a90_textures: Dictionary = {}
var _a120_frames: Array[Texture2D] = []
var _darkness_tex: Texture2D = null

var _a60_active := false
var _a60_phase := 0 # 0=idle, 2=rush, 3=sink
var _a60_is_prime := false
var _a60_prime_rebounds := 0
var _a60_prime_pending_timer := 0.0
var _a60_prime_chains_left := 0
var _a60_prime_flicker_active := false
var _a60_prime_flicker_gap_t := 0.0
var _a60_prime_flicker_snd_cd := 0.0
var _a60_prime_table_burned := false
var _a60_prime_hit_cd := 0.0
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
var _ent_sync_accum := 0.0
var _net_a60_tgt := Vector3.ZERO
var _net_a120_tgt := Vector3.ZERO

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

# Architect dialogue playback (inspired by test.py with glitch transitions & memory)
var _arch_lines: Array[String] = []
var _arch_line_idx := 0
var _arch_char_pos := 0.0
var _arch_blip_acc := 0
var _arch_glitch_step := -1
var _arch_glitch_timer := 0.0
var _arch_prev_text := "hello"
var _arch_auto_advance_timer := 0.0

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

# Audio & gameplay settings (persisted in user://rooms_settings.cfg)
var _audio_master := 0.75
var _audio_entities := 1.0
var _audio_sfx := 1.0
var _audio_ambient := 1.0
var _audio_muted := false
var _mouse_sens_mult := 1.0
var _base_fov := 75.0
var _head_bob_enabled := true
var _is_shaking_gummy := false

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
var _noob_scene: PackedScene = null
var _noob_parts: Dictionary = {}


func _ready() -> void:
	_assets = RoomBuilder.create_shared_assets()
	_load_entity_sprites()

	_load_render_settings()
	_apply_audio_settings(false)
	_setup_environment()
	_build_entity_nodes()
	_build_viewmodel()
	_build_net()
	_build_ui()
	_sync_settings_ui()
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
	_net.locker_action_received.connect(_on_remote_locker_action)
	_net.entity_event_received.connect(_on_remote_entity_event)
	_net.peer_disconnected.connect(_on_remote_peer_disconnected)
	_net.invite_received.connect(func(inviter_name: String, _lid: int) -> void:
		_show_toast("Steam: приглашение от %s! Примите в Shift+Tab" % inviter_name, 4.0)
	)
	_net.session_synced.connect(_on_net_session_synced)


func _on_net_session_synced(seed_val: int, room_idx: int) -> void:
	if seed_val > 0 and _world_seed != seed_val and (_net == null or not _net.is_host):
		_reset_run(seed_val)
	if room_idx > _highest_opened:
		for idx in range(_highest_opened, room_idx):
			var r: RoomBuilder.RoomInstance = _room_by_idx.get(idx)
			if r != null and not r.door_opened:
				_open_room_door(idx, false, true)
	_show_toast("Синхронизация с лобби (A-%03d)" % room_idx, 2.8)


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


func _is_action_locked() -> bool:
	return _locker_transition_t < 1.0 or _door_hand_timer > 0.0


func _has_alive_remote_players() -> bool:
	for rp_v in _remote_players.values():
		if rp_v is Dictionary and not bool((rp_v as Dictionary).get("dead", false)):
			return true
	return false


func _get_remote_hiding_kind(rp: Dictionary) -> String:
	if not bool(rp.get("hiding", false)):
		return ""
	var hr := int(rp.get("hide_room", -1))
	var hl := int(rp.get("hide_locker", -1))
	var r_inst: RoomBuilder.RoomInstance = _room_by_idx.get(hr)
	if r_inst != null and hl >= 0 and hl < r_inst.lockers.size():
		return String(r_inst.lockers[hl].get("kind", "locker"))
	return "locker"


func _is_entity_authority() -> bool:
	return _net == null or not _net.is_online() or _net.is_host


func _on_remote_entity_event(msg: Dictionary) -> void:
	var kind := String(msg.get("k", ""))
	# If ANY peer gets hit/warped by A-120, despawn it across both host & clients cleanly
	if kind == "a120_end":
		_a120_active = false
		_a120_phase = 0
		_a120_substage = 0
		_a120_node.visible = false
		audio.stop_a120()
		if _is_entity_authority() and _net != null and _net.is_online() and bool(msg.get("from_client", false)):
			_net.broadcast_entity_event({"k": "a120_end"}, true)
		return
	if kind == "a60_end":
		_a60_active = false
		_a60_phase = 0
		_a60_node.visible = false
		if _ui.has("a60_scare_rect"):
			(_ui["a60_scare_rect"] as Control).visible = false
		audio.stop_a60()
		return

	if _is_entity_authority():
		return
	elif kind == "a60p_warn":
		var gap := float(msg.get("gap", 0.0))
		_a60_prime_flicker_active = true
		_a60_prime_flicker_gap_t = gap
		_a60_prime_flicker_snd_cd = 0.0
		return
	elif kind == "a60p_end":
		_a60_prime_flicker_active = false
		_a60_prime_flicker_gap_t = 0.0
		return

	# Do not spawn or resurrect visual entities onto a dead player's death/Architect screen
	if _state == State.DEAD:
		return

	if kind == "a60_spawn":
		var door_idx := int(msg.get("door", 0))
		var is_prime := bool(msg.get("prime", false))
		_start_a60_local(door_idx, is_prime)
	elif kind == "a60_pos":
		var p_arr: Variant = msg.get("p")
		if p_arr is Array and (p_arr as Array).size() >= 3:
			var a: Array = p_arr
			_net_a60_tgt = Vector3(float(a[0]), float(a[1]), float(a[2]))
			if _a60_active:
				_a60_phase = int(msg.get("ph", 2))
	elif kind == "a60_brk":
		var b_idx := int(msg.get("door", -1))
		var b_prime := bool(msg.get("prime", false))
		var r_brk: RoomBuilder.RoomInstance = _room_by_idx.get(b_idx)
		if r_brk != null and not r_brk.door_opened and not r_brk.door_broken:
			_break_door_by_a60(b_idx, b_prime)
	elif kind == "a120_spawn":
		if _a120_hit_cd <= 0.0:
			var sp_r := int(msg.get("room", 0))
			var rb := int(msg.get("rb", 0))
			_start_a120_local(sp_r, rb)
	elif kind == "a120_pos":
		if _a120_hit_cd > 0.0:
			return
		var p120: Variant = msg.get("p")
		if p120 is Array and (p120 as Array).size() >= 3:
			var a2: Array = p120
			_net_a120_tgt = Vector3(float(a2[0]), float(a2[1]), float(a2[2]))
			if _a120_active:
				_a120_phase = int(msg.get("ph", 1))
				_a120_substage = int(msg.get("ss", 0))


func _on_remote_door_opened(room_index: int, slam: bool = false) -> void:
	for idx in range(maxi(room_index - 1, 0), room_index + 1):
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(idx)
		if r != null and not r.door_opened:
			var before_high := _highest_opened
			_open_room_door(idx, slam and (idx == room_index), true)
			if _net != null and _net.is_online() and _net.is_host and _highest_opened > before_high:
				_maybe_spawn_door_entities(_highest_opened)


func _on_remote_locker_action(peer_key: String, room_idx: int, locker_idx: int, entering: bool, face_locker: bool) -> void:
	if _remote_players.has(peer_key):
		var rp: Dictionary = _remote_players[peer_key]
		rp["hiding"] = entering
		rp["hide_room"] = room_idx if entering else -1
		rp["hide_locker"] = locker_idx if entering else -1
		rp["interact_t"] = 0.85

	var r: RoomBuilder.RoomInstance = _room_by_idx.get(room_idx)
	if r == null or locker_idx < 0 or locker_idx >= r.lockers.size():
		return
	var ld: Dictionary = r.lockers[locker_idx]
	var dp := ld.get("door_pivot") as Node3D
	if is_instance_valid(dp):
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		if entering:
			tw.tween_property(dp, "rotation:y", -PI * 0.64, 0.28)
			tw.tween_interval(0.40)
			tw.tween_property(dp, "rotation:y", -0.05, 0.32)
		elif face_locker:
			tw.tween_property(dp, "rotation:y", -PI * 0.62, 0.21)
			tw.tween_interval(0.21)
			tw.tween_property(dp, "rotation:y", 0.0, 0.28)
		else:
			tw.tween_property(dp, "rotation:y", -PI * 0.64, 0.30)
			tw.tween_interval(0.32)
			tw.tween_property(dp, "rotation:y", 0.0, 0.38)


func _on_remote_peer_disconnected(peer_key: String) -> void:
	if _remote_players.has(peer_key):
		var rp: Dictionary = _remote_players[peer_key]
		var node: Variant = rp.get("node")
		if node is Node3D and is_instance_valid(node):
			(node as Node3D).queue_free()
		_remote_players.erase(peer_key)


func _find_first_mesh_in_tree(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for ch in n.get_children():
		var found := _find_first_mesh_in_tree(ch)
		if found != null:
			return found
	return null


func _rel_xform_to(n: Node, ancestor: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _prepare_noob_parts() -> void:
	_noob_parts.clear()
	if _noob_scene == null:
		return
	var inst := _noob_scene.instantiate() as Node3D
	if inst == null:
		return
	var mi := _find_first_mesh_in_tree(inst)
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		inst.queue_free()
		return

	var mdt := MeshDataTool.new()
	if mdt.create_from_surface(mi.mesh, 0) != OK:
		inst.queue_free()
		return

	var sc := 1.72 / 5.101215
	var bottom_center := Vector3(-6.639172, -2.109478, 2.7993965)
	var rot_only := Basis(Vector3.UP, -PI * 0.5)
	var rot_xf := Transform3D(rot_only.scaled(Vector3.ONE * sc), Vector3.ZERO)
	var rel_xf := _rel_xform_to(mi, inst)
	var to_avatar := rot_xf * Transform3D(Basis.IDENTITY, -bottom_center) * rel_xf
	var norm_basis := (rot_only * rel_xf.basis).orthonormalized()

	var part_origins := {
		"head": Vector3(0.0, 1.348, 0.0),
		"torso": Vector3(0.0, 0.674, 0.0),
		"arm_l": Vector3(-0.505, 1.295, 0.0),
		"arm_r": Vector3(0.505, 1.295, 0.0),
		"leg_l": Vector3(-0.168, 0.674, 0.0),
		"leg_r": Vector3(0.168, 0.674, 0.0),
	}
	var sts := {}
	for k in part_origins.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[k] = st

	for f in range(mdt.get_face_count()):
		var v_idx := [mdt.get_face_vertex(f, 0), mdt.get_face_vertex(f, 1), mdt.get_face_vertex(f, 2)]
		var p0 := to_avatar * mdt.get_vertex(v_idx[0])
		var p1 := to_avatar * mdt.get_vertex(v_idx[1])
		var p2 := to_avatar * mdt.get_vertex(v_idx[2])
		var cx := (p0.x + p1.x + p2.x) / 3.0
		var mn_x := minf(p0.x, minf(p1.x, p2.x))
		var mx_x := maxf(p0.x, maxf(p1.x, p2.x))
		var mn_y := minf(p0.y, minf(p1.y, p2.y))
		var mx_y := maxf(p0.y, maxf(p1.y, p2.y))

		var target := "torso"
		if mn_y > 1.31 and mx_x < 0.25 and mn_x > -0.25:
			target = "head"
		elif mx_y < 0.674 or (mn_y + mx_y) * 0.5 < 0.670:
			target = "leg_l" if cx < 0.0 else "leg_r"
		elif mx_x < -0.330 or cx < -0.340:
			target = "arm_l"
		elif mn_x > 0.330 or cx > 0.340:
			target = "arm_r"

		var origin: Vector3 = part_origins[target]
		var st_t: SurfaceTool = sts[target]
		var pts := [p0, p1, p2]
		for j in range(3):
			var vi: int = v_idx[j]
			var nrm := (norm_basis * mdt.get_vertex_normal(vi)).normalized()
			st_t.set_normal(nrm)
			st_t.set_uv(mdt.get_vertex_uv(vi))
			st_t.add_vertex(pts[j] - origin)

	var base_mat := mi.get_active_material(0)
	if base_mat == null and mi.mesh.get_surface_count() > 0:
		base_mat = mi.mesh.surface_get_material(0)
	var hand_mat: Material = null
	if base_mat is StandardMaterial3D:
		var sm := (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.emission_enabled = true
		sm.emission = Color(1.0, 0.94, 0.68)
		sm.emission_energy_multiplier = 0.12
		if sm.albedo_texture != null:
			sm.emission_texture = sm.albedo_texture
		hand_mat = sm
	else:
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.96, 0.80, 0.22)
		hm.emission_enabled = true
		hm.emission = Color(0.96, 0.80, 0.22)
		hm.emission_energy_multiplier = 0.12
		hand_mat = hm

	var meshes_out := {}
	for k in sts.keys():
		var st_k: SurfaceTool = sts[k]
		var am := st_k.commit()
		if am != null and am.get_surface_count() > 0 and base_mat != null:
			am.surface_set_material(0, base_mat)
		meshes_out[k] = am

	_noob_parts = {
		"ready": true,
		"mat": base_mat,
		"hand_mat": hand_mat,
		"meshes": meshes_out,
	}
	inst.queue_free()


func _build_remote_avatar_mesh(parent: Node3D) -> Dictionary:
	var model_root := Node3D.new()
	model_root.name = "NoobAvatar"
	parent.add_child(model_root)

	var torso_pivot := Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position = Vector3(0.0, 0.674, 0.0)
	model_root.add_child(torso_pivot)

	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.674, 0.0)
	torso_pivot.add_child(head_pivot)

	var arm_l_pivot := Node3D.new()
	arm_l_pivot.name = "ArmLPivot"
	arm_l_pivot.position = Vector3(-0.505, 0.621, 0.0)
	torso_pivot.add_child(arm_l_pivot)

	var arm_r_pivot := Node3D.new()
	arm_r_pivot.name = "ArmRPivot"
	arm_r_pivot.position = Vector3(0.505, 0.621, 0.0)
	torso_pivot.add_child(arm_r_pivot)

	var leg_l_pivot := Node3D.new()
	leg_l_pivot.name = "LegLPivot"
	leg_l_pivot.position = Vector3(-0.168, 0.674, 0.0)
	model_root.add_child(leg_l_pivot)

	var leg_r_pivot := Node3D.new()
	leg_r_pivot.name = "LegRPivot"
	leg_r_pivot.position = Vector3(0.168, 0.674, 0.0)
	model_root.add_child(leg_r_pivot)

	if bool(_noob_parts.get("ready", false)):
		var meshes: Dictionary = _noob_parts["meshes"]
		var part_map := {
			"head": head_pivot,
			"torso": torso_pivot,
			"arm_l": arm_l_pivot,
			"arm_r": arm_r_pivot,
			"leg_l": leg_l_pivot,
			"leg_r": leg_r_pivot,
		}
		for pk in part_map.keys():
			var mi := MeshInstance3D.new()
			mi.name = "Noob_" + String(pk)
			mi.mesh = meshes.get(pk) as ArrayMesh
			(part_map[pk] as Node3D).add_child(mi)
	else:
		# Stylized R6 Roblox Noob fallback if glTF unavailable
		var skin_mat := StandardMaterial3D.new()
		skin_mat.albedo_color = Color(0.96, 0.80, 0.22)
		skin_mat.roughness = 0.55
		var torso_mat := StandardMaterial3D.new()
		torso_mat.albedo_color = Color(0.11, 0.44, 0.82)
		torso_mat.roughness = 0.60
		var leg_mat := StandardMaterial3D.new()
		leg_mat.albedo_color = Color(0.45, 0.72, 0.18)
		leg_mat.roughness = 0.65
		RoomBuilder._add_box(leg_l_pivot, "LegL", Vector3(0.0, -0.337, 0.0), Vector3(0.32, 0.674, 0.337), leg_mat, false)
		RoomBuilder._add_box(leg_r_pivot, "LegR", Vector3(0.0, -0.337, 0.0), Vector3(0.32, 0.674, 0.337), leg_mat, false)
		RoomBuilder._add_box(torso_pivot, "Torso", Vector3(0.0, 0.337, 0.0), Vector3(0.674, 0.674, 0.337), torso_mat, false)
		RoomBuilder._add_box(arm_l_pivot, "ArmL", Vector3(0.0, -0.284, 0.0), Vector3(0.337, 0.674, 0.337), skin_mat, false)
		RoomBuilder._add_box(arm_r_pivot, "ArmR", Vector3(0.0, -0.284, 0.0), Vector3(0.337, 0.674, 0.337), skin_mat, false)
		RoomBuilder._add_box(head_pivot, "Head", Vector3(0.0, 0.186, 0.0), Vector3(0.40, 0.40, 0.40), skin_mat, false)

	_prep_avatar_meshes(model_root)
	return {
		"root": model_root,
		"torso": torso_pivot,
		"head": head_pivot,
		"arm_l": arm_l_pivot,
		"arm_r": arm_r_pivot,
		"leg_l": leg_l_pivot,
		"leg_r": leg_r_pivot,
	}


func _prep_avatar_meshes(n: Node) -> void:
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Large extra_cull_margin prevents false frustum culling on transformed glTF bounds
			mi.extra_cull_margin = 16384.0
			mi.visible = true


func _on_remote_state(peer_key: String, msg: Dictionary) -> void:
	var rp: Dictionary
	var newly_created := false
	if _remote_players.has(peer_key):
		rp = _remote_players[peer_key]
	else:
		newly_created = true
		var root_node := Node3D.new()
		root_node.name = "Remote_" + peer_key
		root_node.visible = true
		add_child(root_node)

		var rig := _build_remote_avatar_mesh(root_node)
		var avatar: Node3D = rig["root"]
		var head: Node3D = rig["head"]
		var arm_r: Node3D = rig["arm_r"]

		var spot := SpotLight3D.new()
		spot.position = Vector3(0.0, -0.62, -0.05)
		spot.rotation.x = -PI * 0.5
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 1.9
		spot.spot_range = 17.0
		spot.spot_angle = 38.0
		arm_r.add_child(spot)

		var name_lbl := Label3D.new()
		name_lbl.position = Vector3(0.0, 2.02, 0.0)
		name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_lbl.no_depth_test = true
		name_lbl.font_size = 30
		name_lbl.pixel_size = 0.004
		name_lbl.modulate = Color(0.85, 0.96, 1.0)
		name_lbl.text = String(msg.get("n", "Player"))
		root_node.add_child(name_lbl)

		rp = {
			"node": root_node,
			"avatar": avatar,
			"rig": rig,
			"head": head,
			"spot": spot,
			"lbl": name_lbl,
			"tgt_pos": Vector3.ZERO,
			"tgt_yaw": 0.0,
			"tgt_pitch": 0.0,
			"light_on": false,
			"hiding": false,
			"hide_room": -1,
			"hide_locker": -1,
			"dead": false,
			"room": 0,
			"name": String(msg.get("n", "Player")),
			"sprint": false,
			"interact_t": 0.0,
			"net_spd": 0.0,
			"move_hold": 0.0,
			"last_pkt_ms": Time.get_ticks_msec(),
			"walk_phase": 0.0,
			"walk_blend": 0.0,
			"idle_phase": float(abs(hash(peer_key)) % 628) * 0.01,
		}
		_remote_players[peer_key] = rp

	var prev_tgt: Vector3 = rp.get("tgt_pos", Vector3.ZERO)
	var p_arr: Variant = msg.get("p", [0.0, 0.0, 0.0])
	if p_arr is Array and (p_arr as Array).size() >= 3:
		var a: Array = p_arr
		var next_tgt := Vector3(float(a[0]), float(a[1]), float(a[2]))
		rp["tgt_pos"] = next_tgt
		if not newly_created:
			var now_ms := Time.get_ticks_msec()
			var dt_pkt := clampf(float(now_ms - int(rp.get("last_pkt_ms", now_ms))) * 0.001, 0.016, 0.25)
			rp["last_pkt_ms"] = now_ms
			var d_horiz := Vector2(next_tgt.x - prev_tgt.x, next_tgt.z - prev_tgt.z).length()
			var inst_spd := d_horiz / dt_pkt
			rp["net_spd"] = lerpf(float(rp.get("net_spd", 0.0)), inst_spd, 0.55)
			if inst_spd > 0.35:
				rp["move_hold"] = 0.16
	rp["tgt_yaw"] = float(msg.get("y", 0.0))
	rp["tgt_pitch"] = float(msg.get("pt", 0.0))
	var next_light := bool(msg.get("l", false))
	var prev_hide := bool(rp.get("hiding", false))
	var next_hide := bool(msg.get("h", false))
	if prev_hide != next_hide and not newly_created:
		rp["interact_t"] = maxf(float(rp.get("interact_t", 0.0)), 0.85)
	rp["light_on"] = next_light
	rp["hiding"] = next_hide
	rp["hide_room"] = int(msg.get("hr", -1)) if next_hide else -1
	rp["hide_locker"] = int(msg.get("hl", -1)) if next_hide else -1
	rp["dead"] = bool(msg.get("d", false))
	rp["room"] = int(msg.get("r", 0))
	rp["name"] = String(msg.get("n", "Player"))
	rp["sprint"] = bool(msg.get("sp", false))
	var spot_node: SpotLight3D = rp["spot"]
	spot_node.visible = next_light and not bool(rp["dead"])
	var lbl_node: Label3D = rp["lbl"]
	lbl_node.text = "%s [МЁРТВ]" % String(rp["name"]) if bool(rp["dead"]) else "%s [A-%03d]" % [String(rp["name"]), int(rp["room"])]
	var root_n: Node3D = rp["node"]
	# Remote players must stay visible at all times while alive (or show fallen/ghosted only on own spectate)
	root_n.visible = not bool(rp["dead"])
	if newly_created:
		root_n.position = rp["tgt_pos"]
		root_n.rotation.y = float(rp["tgt_yaw"])


func _process_remote_players(delta: float) -> void:
	var a := clampf(1.0 - exp(-14.0 * delta), 0.0, 1.0)
	var anim_a := clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0)
	for pk in _remote_players.keys():
		var rp: Dictionary = _remote_players[pk]
		var n: Node3D = rp["node"]
		if not is_instance_valid(n):
			continue
		if bool(rp.get("dead", false)):
			n.visible = false
			continue
		n.visible = true
		var prev_pos := n.position
		n.position = n.position.lerp(rp["tgt_pos"], a)
		n.rotation.y = lerp_angle(n.rotation.y, float(rp["tgt_yaw"]), a)

		var hold := maxf(float(rp.get("move_hold", 0.0)) - delta, 0.0)
		rp["move_hold"] = hold
		var lerp_spd := Vector2(n.position.x - prev_pos.x, n.position.z - prev_pos.z).length() / maxf(delta, 0.001)
		var net_spd := float(rp.get("net_spd", 0.0)) if hold > 0.0 else 0.0
		var move_spd := maxf(lerp_spd, net_spd)
		var is_moving := move_spd > 0.28 or hold > 0.0
		var is_sprinting := bool(rp.get("sprint", false)) or move_spd > 4.6
		var target_blend := clampf(move_spd / 3.4, 0.0, 1.0) if is_moving else 0.0
		var wb := lerpf(float(rp.get("walk_blend", 0.0)), target_blend, 1.0 - exp(-12.0 * delta))
		rp["walk_blend"] = wb

		var idle_t := float(rp.get("idle_phase", 0.0)) + delta
		rp["idle_phase"] = idle_t
		var wp := float(rp.get("walk_phase", 0.0))
		if is_moving:
			wp += delta * clampf(move_spd * (2.5 if is_sprinting else 2.2), 4.0, 15.0)
			rp["walk_phase"] = wp

		var inter_t := maxf(float(rp.get("interact_t", 0.0)) - delta, 0.0)
		rp["interact_t"] = inter_t

		var is_hiding := bool(rp.get("hiding", false))
		var is_under_desk := (_get_remote_hiding_kind(rp) == "under_desk")
		var light_on := bool(rp.get("light_on", false))
		var pitch := clampf(float(rp.get("tgt_pitch", 0.0)), -0.95, 0.95)
		var run_amt := 1.0 if is_sprinting else clampf((move_spd - 3.0) / 3.0, 0.0, 1.0)
		var leg_amp := lerpf(0.56, 0.90, run_amt) * wb
		var arm_amp := lerpf(0.50, 0.94, run_amt) * wb
		var sw := sin(wp)
		var cw := cos(wp)

		var av_val: Variant = rp.get("avatar")
		var av: Node3D = av_val as Node3D if (av_val is Object) else null
		if is_instance_valid(av):
			av.visible = true
		var rig: Dictionary = rp.get("rig", {})
		if rig.is_empty():
			continue

		var torso: Node3D = rig["torso"]
		var head: Node3D = rig["head"]
		var arm_l: Node3D = rig["arm_l"]
		var arm_r: Node3D = rig["arm_r"]
		var leg_l: Node3D = rig["leg_l"]
		var leg_r: Node3D = rig["leg_r"]

		# Torso: breathing in idle, energetic stride bob + forward sprint lean + twist, crouch lower when hiding / under desk
		var hide_drop := (-0.34 if is_under_desk else -0.14) if is_hiding else 0.0
		var torso_y := 0.674 + hide_drop + sin(idle_t * 2.1) * 0.012 * (1.0 - wb * 0.6) + absf(sw) * 0.055 * wb
		var torso_rx := ((-0.36 if is_under_desk else -0.20) if is_hiding else (-0.04 - 0.11 * run_amt) * wb + sin(idle_t * 1.4) * 0.015 * (1.0 - wb))
		var torso_ry := cw * 0.09 * wb
		var torso_rz := sw * 0.032 * wb
		torso.position.y = lerpf(torso.position.y, torso_y, anim_a)
		torso.rotation = torso.rotation.lerp(Vector3(torso_rx, torso_ry, torso_rz), anim_a)

		# Head: tracks pitch + subtle idle look-around + stride bob
		var head_rx := pitch * 0.72 + sin(idle_t * 1.6) * 0.025 * (1.0 - wb) - torso_rx * 0.35
		var head_ry := sin(idle_t * 0.85) * 0.05 * (1.0 - wb) - torso_ry * 0.5
		head.rotation = head.rotation.lerp(Vector3(head_rx, head_ry, 0.0), anim_a)

		# Legs: alternate stride in opposition, slight brace bend while hiding
		var leg_l_rx := (0.28 if is_hiding else sw * leg_amp)
		var leg_r_rx := (-0.22 if is_hiding else -sw * leg_amp)
		leg_l.rotation = leg_l.rotation.lerp(Vector3(leg_l_rx, 0.0, -0.02), anim_a)
		leg_r.rotation = leg_r.rotation.lerp(Vector3(leg_r_rx, 0.0, 0.02), anim_a)

		# Left Arm: relaxed idle sway / opposite swing to Left Leg / raised guard in locker
		var arm_l_rx := (0.45 if is_hiding else (-sw * arm_amp + sin(idle_t * 1.5) * 0.055 * (1.0 - wb)))
		var arm_l_rz := -0.075 - 0.03 * sin(idle_t * 1.8) * (1.0 - wb) + (0.12 if is_hiding else 0.0)
		arm_l.rotation = arm_l.rotation.lerp(Vector3(arm_l_rx, 0.0, arm_l_rz), anim_a)

		# Right Arm: locker reach gesture > flashlight aim > opposite walk/run swing > idle sway
		var arm_r_rx := +sw * arm_amp + cos(idle_t * 1.5) * 0.055 * (1.0 - wb)
		var arm_r_ry := 0.0
		var arm_r_rz := 0.075 + 0.03 * sin(idle_t * 1.8) * (1.0 - wb)
		if inter_t > 0.0:
			var reach := sin(clampf(inter_t / 0.85, 0.0, 1.0) * PI)
			arm_r_rx = lerpf(arm_r_rx, 1.48, reach)
			arm_r_ry = reach * 0.34
			arm_r_rz = -0.16 * reach
		elif light_on:
			arm_r_rx = 1.42 + clampf(pitch * 0.78, -0.68, 0.68) + sw * 0.05 * wb
			arm_r_rz = 0.04
		elif is_hiding:
			arm_r_rx = 0.52
			arm_r_rz = -0.12
		arm_r.rotation = arm_r.rotation.lerp(Vector3(arm_r_rx, arm_r_ry, arm_r_rz), anim_a)


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
	if _ui.has("m_main_box") and _ui.has("m_settings_box"):
		(_ui["m_main_box"] as Control).visible = not open
		(_ui["m_settings_box"] as Control).visible = open
	if _ui.has("m_title") and _ui.has("m_desc") and _state == State.PAUSED:
		var title: Label = _ui["m_title"]
		var desc: Label = _ui["m_desc"]
		if open:
			title.text = "НАСТРОЙКИ"
			title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
			desc.text = "Звук, чувствительность и камера сохраняются автоматически."
		else:
			title.text = "ПАУЗА  (A-%03d)" % _highest_opened
			title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
			desc.text = "Секция A. Переживите A-60, A-90 и A-120 до комнаты A-200!"


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

	# Minimalist borderless battery counter (bottom-left)
	var bat_lbl := Label.new()
	bat_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bat_lbl.offset_left = 20
	bat_lbl.offset_right = 340
	bat_lbl.offset_top = -42
	bat_lbl.offset_bottom = -14
	bat_lbl.add_theme_font_size_override("font_size", 15)
	bat_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.88))
	bat_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	bat_lbl.add_theme_constant_override("outline_size", 4)
	bat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bat_lbl.visible = false
	hud_group.add_child(bat_lbl)
	_ui["bat_lbl"] = bat_lbl

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

	var m_main_box := VBoxContainer.new()
	m_main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_main_box.add_theme_constant_override("separation", 9)
	m_box.add_child(m_main_box)
	_ui["m_main_box"] = m_main_box

	var btn_resume := Button.new()
	btn_resume.text = "Продолжить"
	btn_resume.custom_minimum_size = Vector2(0, 42)
	RoomsUI.style_button(btn_resume, Color(0.35, 0.95, 0.68), 15)
	btn_resume.pressed.connect(func(): _set_state(State.PLAYING))
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
	btn_restart.pressed.connect(_reset_run)
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
			_advance_architect_dialogue()
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
	btn_arch_next.pressed.connect(_advance_architect_dialogue)
	arch_overlay.add_child(btn_arch_next)
	_ui["btn_arch_next"] = btn_arch_next

	var btn_arch_retry := Button.new()
	btn_arch_retry.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn_arch_retry.pressed.connect(_reset_run)
	arch_overlay.add_child(btn_arch_retry)
	_ui["btn_arch_retry"] = btn_arch_retry

	_style_arch_terminal_buttons()

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
	btn_spec_prev.pressed.connect(func() -> void: _cycle_spectate_target(-1))
	spec_bar.add_child(btn_spec_prev)

	var btn_spec_next := Button.new()
	btn_spec_next.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_spec_next.offset_left = -60
	btn_spec_next.offset_right = 80
	btn_spec_next.offset_top = -36
	btn_spec_next.offset_bottom = 0
	btn_spec_next.text = "Игрок >"
	RoomsUI.style_button(btn_spec_next, Color(0.45, 0.85, 1.0), 13)
	btn_spec_next.pressed.connect(func() -> void: _cycle_spectate_target(1))
	spec_bar.add_child(btn_spec_next)

	var btn_spec_restart := Button.new()
	btn_spec_restart.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_spec_restart.offset_left = 94
	btn_spec_restart.offset_right = 230
	btn_spec_restart.offset_top = -36
	btn_spec_restart.offset_bottom = 0
	btn_spec_restart.text = "Рестарт [R]"
	RoomsUI.style_button(btn_spec_restart, Color(1.0, 0.72, 0.25), 13)
	btn_spec_restart.pressed.connect(_reset_run)
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

	# Brutal Large WHITE hollow circle -> Flashlight toggle (std) / Hold to shake (Gummy)
	var btn_light := _make_ring_btn(mobile_group, Color(1.0, 1.0, 1.0, 0.96), 7.5, -24, -22, 126)
	btn_light.button_down.connect(func() -> void:
		if _is_action_locked():
			return
		if _active_tool == 1:
			_mobile_gummy_held = true
		else:
			_toggle_flashlight()
	)
	btn_light.button_up.connect(func() -> void:
		_mobile_gummy_held = false
	)
	_ui["m_btn_light"] = btn_light

	# Compact amber ring button to reload flashlight with 2 batteries when needed on mobile
	var btn_reload := _make_ring_btn(mobile_group, Color(1.0, 0.82, 0.25, 0.95), 4.5, -168, -124, 54, Control.PRESET_BOTTOM_RIGHT, "R")
	btn_reload.pressed.connect(func() -> void:
		if not _is_action_locked():
			_try_reload_flashlight()
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
				_try_shake_gummy()
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
			_exit_locker(false)
	)
	_ui["m_btn_exit_fwd"] = btn_exit_fwd

	var btn_exit_back := _make_ring_btn(mobile_group, Color(1.0, 0.68, 0.24, 0.95), 5.5, -26, -26, 72, Control.PRESET_BOTTOM_RIGHT, "S")
	btn_exit_back.pressed.connect(func() -> void:
		if _is_hiding and not _is_action_locked():
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
	if _ui.has("btn_arch_next"):
		_style_arch_terminal_buttons()
		if _state == State.DEAD:
			_refresh_architect_controls()


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

	if forced_seed > 0:
		_world_seed = forced_seed & 0x7FFFFFFF
	else:
		var tmp_rng := RandomNumberGenerator.new()
		tmp_rng.randomize()
		_world_seed = maxi(int(tmp_rng.randi() & 0x3FFFFFFF), 1)
	_rng.seed = _world_seed
	_next_cell = Vector2i.ZERO
	_next_in_dir = Vector3(0.0, 0.0, -1.0)
	_next_room_index = 0
	_highest_opened = 0
	_current_room_idx = 0

	_hp = 100
	_stamina = 1.0
	_stamina_regen_delay = 0.0
	_exhausted = false
	_is_sprinting = false
	_door_hand_timer = 0.0
	_door_hand_slam = false
	_death_phase = 0
	_death_phase_t = 0.0
	_spectate_key = ""
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
	_door_hand_timer = 0.0
	_spectate_last_hiding = false
	_spectate_user_orbited = false
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	player_col.disabled = false
	_power_out = false
	_light_on = true
	_active_tool = 0
	_has_gummy = false
	_std_battery = 150.0
	_gummy_battery = 100.0
	_batteries = 0
	_std_low_power = false
	_std_low_power_regen = 0.0
	_std_low_flicker_t = 0.0
	_vm_shake_time = 0.0
	_gummy_hold_accum = 0.0
	_gummy_pump_phase = 0.0
	_rmb_held = false
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
	_a60_prime_pending_timer = 0.0
	_a60_prime_chains_left = 0
	_a60_prime_flicker_active = false
	_a60_prime_flicker_gap_t = 0.0
	_a60_prime_flicker_snd_cd = 0.0
	_a60_prime_table_burned = false
	_a60_prime_hit_cd = 0.0
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
	_ent_sync_accum = 0.0
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
	player_body.rotation = Vector3.ZERO
	_target_yaw = 0.0
	_target_pitch = 0.0
	_yaw = 0.0
	_pitch = 0.0
	_cam_roll = 0.0
	_spectate_yaw = 0.0
	_spectate_pitch = 0.25
	_fov = 75.0
	cam.fov = 75.0
	cam.position = Vector3(0.0, 1.48, 0.0)
	cam.rotation = Vector3.ZERO
	_apply_camera_rotation()
	flashlight.visible = true
	(_ui["architect_overlay"] as Control).visible = false
	if _ui.has("death_iris"):
		(_ui["death_iris"] as Control).visible = false
	if _ui.has("spectate_bar"):
		(_ui["spectate_bar"] as Control).visible = false
	_clear_all_vignettes()
	_reset_touch_state()
	if _net != null:
		_net.update_lobby_progress(_world_seed, 0)
		if _net.is_online() and _net.is_host and forced_seed <= 0:
			_net.broadcast_session_sync(_world_seed, 0)
	_set_state(State.PLAYING)
	_show_toast("Вы в Секции A. Откройте дверь A-001, чтобы начать.", 3.5)


func _spawn_next_room() -> void:
	var idx := _next_room_index
	_next_room_index += 1
	var cell := _next_cell
	var in_dir := _next_in_dir
	_occupied_cells[cell] = true

	# Strictly deterministic per-room RNG derived ONLY from (_world_seed, idx)
	# so gameplay events (A-60/A-120/flicker) NEVER desync room generation between friends!
	var room_rng := RandomNumberGenerator.new()
	var mixed_seed := (((_world_seed * 1103515245) + ((idx + 1) * 2654435761)) ^ (idx * 747796405)) & 0x7FFFFFFF
	if mixed_seed <= 0:
		mixed_seed = idx + 1
	room_rng.seed = mixed_seed

	var out_dir := in_dir
	if idx >= 2:
		var roll := room_rng.randf()
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

	var r := RoomBuilder.build_room(rooms_container, _assets, idx, cell, in_dir, out_dir, room_rng, idx >= 50)
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
	(_ui["hud_group"] as Control).visible = (_state != State.DEAD and _state != State.SPECTATING)
	if _ui.has("spectate_bar"):
		(_ui["spectate_bar"] as Control).visible = (_state == State.SPECTATING)
	if _ui.has("mobile_group"):
		(_ui["mobile_group"] as Control).visible = _mobile_controls_enabled and (_state == State.PLAYING)
	if _ui.has("btn_arch_next"):
		_style_arch_terminal_buttons()
		if _state == State.DEAD:
			_refresh_architect_controls()

	if _state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
		(_ui["modal"] as Control).visible = false
		(_ui["architect_overlay"] as Control).visible = false
		if _ui.has("death_iris"):
			(_ui["death_iris"] as Control).visible = false
	elif _state == State.SPECTATING:
		_reset_touch_state()
		_clear_all_vignettes()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
		(_ui["modal"] as Control).visible = false
		(_ui["architect_overlay"] as Control).visible = false
		if _ui.has("death_iris"):
			(_ui["death_iris"] as Control).visible = false
		if _vm_holder != null:
			_vm_holder.visible = false
		if _anim_hand != null:
			_anim_hand.visible = false
		flashlight.visible = false
	else:
		_reset_touch_state()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var modal: Control = _ui["modal"]
		modal.visible = (_state == State.PAUSED or _state == State.VICTORY)
		var title: Label = _ui["m_title"]
		var desc: Label = _ui["m_desc"]
		var btn_res: Button = _ui["btn_resume"]
		if _state == State.PAUSED:
			_open_settings_panel(false)
			title.text = "ПАУЗА  (A-%03d)" % _highest_opened
			title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
			desc.text = "Секция A. Переживите A-60, A-90 и A-120 до комнаты A-200!"
			btn_res.text = "Продолжить"
			btn_res.visible = true
		elif _state == State.VICTORY:
			_open_settings_panel(false)
			title.text = "ВЫ ПРОШЛИ СЕКЦИЮ A!"
			title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
			var mins := int(_run_time) / 60
			var secs := int(_run_time) % 60
			desc.text = "Архитектор приветствует тебя: ты достиг двери A-200 за %02d:%02d!\nМожно продолжить бесконечный забег дальше или начать заново." % [mins, secs]
			btn_res.text = "Продолжить дальше (A-201+)"
			btn_res.visible = true


func _clear_all_vignettes() -> void:
	if _ui.has("vitals_mat"):
		var vmat := _ui["vitals_mat"] as ShaderMaterial
		for k in ["hp_loss", "stam_loss", "exhausted_amt", "darkness_amt"]:
			vmat.set_shader_parameter(k, 0.0)
	if _ui.has("vitals_rect"):
		(_ui["vitals_rect"] as Control).visible = false
	if _ui.has("darkness_rect"):
		var dkr := _ui["darkness_rect"] as Control
		dkr.visible = false
		dkr.modulate.a = 0.0
	if _ui.has("static_mat"):
		var smat := _ui["static_mat"] as ShaderMaterial
		smat.set_shader_parameter("static_amt", 0.0)
		smat.set_shader_parameter("vig_amt", 0.0)
	if _ui.has("static_rect"):
		(_ui["static_rect"] as Control).visible = false
	if _ui.has("locker_mask"):
		var lm := _ui["locker_mask"] as ColorRect
		lm.color = Color(0.0, 0.0, 0.0, 0.0)
		lm.visible = false
	if _ui.has("dmg_flash"):
		var df := _ui["dmg_flash"] as ColorRect
		df.color.a = 0.0
		df.visible = false
	for vk in ["a90_rect", "a90_stop_icon", "a90_stop", "a90_scare_rect", "a60_scare_rect"]:
		if _ui.has(vk):
			(_ui[vk] as Control).visible = false


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
	audio.a60_intensity = 0.0
	var keep_auth_ent := _is_entity_authority() and _net != null and _net.is_online() and _has_alive_remote_players()
	if not keep_auth_ent:
		_a60_active = false
		_a60_phase = 0
		_a60_prime_pending_timer = 0.0
		_a60_prime_chains_left = 0
		_a120_active = false
		_a120_phase = 0
		_a120_substage = 0
	_a60_prime_flicker_active = false
	_a60_node.visible = false
	_a120_node.visible = false
	_a90_phase = 0
	_door_hand_timer = 0.0
	_locker_transition_t = 1.0
	_rmb_held = false
	_clear_all_vignettes()
	(_ui["modal"] as Control).visible = false

	_state = State.DEAD
	_death_phase = 0
	_death_phase_t = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_ui["hud_group"] as Control).visible = false

	if _ui.has("death_iris"):
		var iris := _ui["death_iris"] as Control
		var imat := _ui.get("death_iris_mat") as ShaderMaterial
		iris.visible = true
		if imat != null:
			imat.set_shader_parameter("red_amt", 0.92)
			imat.set_shader_parameter("shrink_amt", 0.0)

	var cur_room: RoomBuilder.RoomInstance = _room_by_idx.get(_current_room_idx)
	var cur_bat := _std_battery if _active_tool == 0 else _gummy_battery
	var ctx := {
		"room_lockers_count": cur_room.lockers.size() if cur_room != null else 0,
		"battery": cur_bat,
		"has_gummy": _has_gummy,
	}
	for k in extra_ctx.keys():
		ctx[k] = extra_ctx[k]

	var u_name := _get_local_username()
	var seq := _architect.build_death_sequence(cause, _highest_opened, u_name, ctx)
	_arch_lines.clear()
	var seq_lines: Array = seq["lines"]
	for line_item in seq_lines:
		_arch_lines.append(String(line_item))
	if _arch_lines.is_empty():
		_arch_lines.append("Be careful in Section A.")

	_arch_line_idx = 0
	_arch_char_pos = 0.0
	_arch_blip_acc = 0
	_arch_glitch_step = 0
	_arch_glitch_timer = 0.0
	_arch_prev_text = "hello"
	_arch_auto_advance_timer = 0.0

	(_ui["arch_title"] as Label).text = String(seq["title"])
	(_ui["arch_meta"] as Label).text = "ENTITY: %s  |  DEATHS: #%d  |  BEST ROOM: A-%03d" % [
		cause, int(seq["deaths_total"]), _architect.best_room
	]
	(_ui["arch_tip"] as Label).text = "TIP: %s" % String(seq["summary"])
	if _ui.has("arch_ascii"):
		(_ui["arch_ascii"] as RichTextLabel).text = String(seq.get("art_bbcode", ""))
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

	# Keep Architect hidden during red flash & center-shrink; fades in smoothly once _death_phase reaches 2
	var arch_overlay: Control = _ui["architect_overlay"]
	arch_overlay.visible = false
	arch_overlay.modulate.a = 0.0


func _get_local_username() -> String:
	if _net != null:
		var n: String = _net.persona_name
		if n != "" and n != "Player":
			return n
	var env_user := OS.get_environment("USERNAME")
	if env_user != "":
		return env_user
	env_user = OS.get_environment("USER")
	if env_user != "":
		return env_user
	return "Player"


func _style_arch_terminal_buttons() -> void:
	if not _ui.has("btn_arch_next") or not _ui.has("btn_arch_retry"):
		return
	var btn_next := _ui["btn_arch_next"] as Button
	var btn_retry := _ui["btn_arch_retry"] as Button
	var mono_f := RoomsArchitect.get_terminal_font()

	if _mobile_controls_enabled:
		btn_next.flat = false
		btn_retry.flat = false
		btn_next.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_retry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_next.offset_left = 24
		btn_next.offset_top = -54
		btn_next.offset_right = 230
		btn_next.offset_bottom = -14
		btn_retry.offset_left = 244
		btn_retry.offset_top = -54
		btn_retry.offset_right = 400
		btn_retry.offset_bottom = -14
		RoomsUI.style_button(btn_next, Color(0.28, 1.0, 0.42), 14)
		RoomsUI.style_button(btn_retry, Color(0.85, 0.75, 0.35), 14)
		btn_next.add_theme_font_override("font", mono_f)
		btn_retry.add_theme_font_override("font", mono_f)
	else:
		btn_next.flat = true
		btn_retry.flat = true
		btn_next.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_retry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_next.offset_left = 24
		btn_next.offset_top = -46
		btn_next.offset_right = 320
		btn_next.offset_bottom = -16
		btn_retry.offset_left = 330
		btn_retry.offset_top = -46
		btn_retry.offset_right = 500
		btn_retry.offset_bottom = -16

		var empty_sb := StyleBoxEmpty.new()
		for sb in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn_next.add_theme_stylebox_override(sb, empty_sb)
			btn_retry.add_theme_stylebox_override(sb, empty_sb)

		btn_next.add_theme_font_override("font", mono_f)
		btn_next.add_theme_font_size_override("font_size", 13)
		btn_next.add_theme_color_override("font_color", Color(0.60, 0.72, 0.65, 0.85))
		btn_next.add_theme_color_override("font_hover_color", Color(0.28, 1.0, 0.42, 1.0))
		btn_next.add_theme_color_override("font_pressed_color", Color(0.95, 1.0, 0.95, 1.0))

		btn_retry.add_theme_font_override("font", mono_f)
		btn_retry.add_theme_font_size_override("font_size", 13)
		btn_retry.add_theme_color_override("font_color", Color(0.60, 0.72, 0.65, 0.85))
		btn_retry.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.35, 1.0))
		btn_retry.add_theme_color_override("font_pressed_color", Color(0.95, 1.0, 0.95, 1.0))


func _refresh_architect_controls() -> void:
	var total := maxi(_arch_lines.size(), 1)
	if _ui.has("arch_page"):
		(_ui["arch_page"] as Label).text = "LINE %02d / %02d" % [_arch_line_idx + 1, total]
	_style_arch_terminal_buttons()
	var btn_next: Button = _ui.get("btn_arch_next")
	var btn_retry: Button = _ui.get("btn_arch_retry")
	if btn_next == null:
		return
	var can_spectate := (_net != null and _net.is_online() and not _remote_players.is_empty())
	if _mobile_controls_enabled:
		if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
			btn_next.text = "Пропустить >"
		elif _arch_line_idx + 1 < total:
			btn_next.text = "Далее >"
		elif can_spectate:
			btn_next.text = "Наблюдать >"
		else:
			btn_next.text = "Завершить >"
		if btn_retry != null:
			btn_retry.text = "Заново"
	else:
		if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] ПРОПУСТИТЬ"
		elif _arch_line_idx + 1 < total:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] ДАЛЕЕ"
		elif can_spectate:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] НАБЛЮДЕНИЕ"
		else:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] ЗАВЕРШИТЬ"
		if btn_retry != null:
			btn_retry.text = "> [R] ЗАНОВО"
	btn_next.disabled = false


func _advance_architect_dialogue() -> void:
	if _state != State.DEAD or _death_phase < 2 or _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if _arch_glitch_step < 12:
		# Immediately finish glitch animation
		_arch_glitch_step = 12
		var sp_lbl: Label = _ui["arch_speech"]
		sp_lbl.text = cur_line
		sp_lbl.add_theme_color_override("font_color", Color(0.28, 1.0, 0.42))
		_arch_prev_text = cur_line
		_arch_char_pos = float(cur_line.length())
		_arch_auto_advance_timer = 0.0
		_refresh_architect_controls()
		return
	if _arch_line_idx + 1 < _arch_lines.size():
		_arch_line_idx += 1
		_arch_glitch_step = 0
		_arch_glitch_timer = 0.0
		_arch_char_pos = 0.0
		_arch_blip_acc = 0
		_arch_auto_advance_timer = 0.0
		_refresh_architect_controls()
	else:
		if _net != null and _net.is_online() and not _remote_players.is_empty():
			_start_spectating()
		else:
			_reset_run()
		(_ui["arch_speech"] as Label).text = ""
		_refresh_architect_controls()


func _start_spectating() -> void:
	_set_state(State.SPECTATING)
	_spectate_pitch = 0.25
	_cycle_spectate_target(0)


func _cycle_spectate_target(step: int) -> void:
	var keys := _remote_players.keys()
	if keys.is_empty():
		_spectate_key = ""
		if _ui.has("spectate_lbl"):
			(_ui["spectate_lbl"] as Label).text = "Нет активных игроков — нажмите [R] для рестарта"
		return
	keys.sort()
	# Prefer alive teammates first
	var alive_keys := []
	for k in keys:
		var rp: Dictionary = _remote_players[k]
		if not bool(rp.get("dead", false)):
			alive_keys.append(k)
	var pool: Array = alive_keys if not alive_keys.is_empty() else keys
	var cur_idx := pool.find(_spectate_key)
	if cur_idx < 0:
		cur_idx = 0
	elif step != 0:
		cur_idx = posmod(cur_idx + step, pool.size())
	_spectate_key = String(pool[cur_idx])
	var rp_sel: Dictionary = _remote_players.get(_spectate_key, {})
	var rp_sel_yaw := float(rp_sel.get("tgt_yaw", 0.0))
	_spectate_last_hiding = bool(rp_sel.get("hiding", false))
	_spectate_user_orbited = false
	_spectate_yaw = wrapf(rp_sel_yaw + PI * 0.88, -PI, PI) if _spectate_last_hiding else rp_sel_yaw


func _process_spectating(delta: float) -> void:
	if _spectate_key.is_empty() or not _remote_players.has(_spectate_key):
		_cycle_spectate_target(0)
	if _spectate_key.is_empty() or not _remote_players.has(_spectate_key):
		return
	var rp: Dictionary = _remote_players[_spectate_key]
	var tgt_node: Node3D = rp.get("node")
	if not is_instance_valid(tgt_node):
		return

	var r_num := int(rp.get("room", 0))
	if r_num != _current_room_idx:
		_current_room_idx = r_num
		_update_room_visibility()

	var is_dead_t := bool(rp.get("dead", false))
	if _ui.has("spectate_lbl"):
		var s_txt := "Наблюдение: %s [A-%03d]" % [String(rp.get("name", "Player")), r_num]
		if is_dead_t:
			s_txt += " (МЁРТВ — [R] Рестарт)"
		else:
			s_txt += "   |   ЛКМ / A-D — Сменить   |   [R] — Рестарт"
		(_ui["spectate_lbl"] as Label).text = s_txt

	var rp_hiding := bool(rp.get("hiding", false))
	var rp_under_desk := (_get_remote_hiding_kind(rp) == "under_desk")
	var rp_yaw := float(rp.get("tgt_yaw", 0.0))
	if rp_hiding != _spectate_last_hiding:
		_spectate_last_hiding = rp_hiding
		_spectate_user_orbited = false

	if not _spectate_user_orbited:
		var auto_yaw := wrapf(rp_yaw + PI * 0.88, -PI, PI) if rp_hiding else rp_yaw
		_spectate_yaw = lerp_angle(_spectate_yaw, auto_yaw, 1.0 - exp(-10.0 * delta))

	var pivot: Vector3
	var desired: Vector3
	if rp_hiding:
		var hr_idx := int(rp.get("hide_room", -1))
		var hl_idx := int(rp.get("hide_locker", -1))
		var hide_node: Node3D = null
		if hr_idx >= 0 and _room_by_idx.has(hr_idx):
			var hr_inst: RoomBuilder.RoomInstance = _room_by_idx[hr_idx]
			if hl_idx >= 0 and hl_idx < hr_inst.lockers.size():
				hide_node = hr_inst.lockers[hl_idx].get("node") as Node3D

		if hide_node != null:
			var fwd := hide_node.global_transform.basis.z.normalized()
			var h_pos := hide_node.global_position
			pivot = h_pos + Vector3(0.0, 0.45 if rp_under_desk else 1.35, 0.0)
			var view_fwd := (Basis(Vector3.UP, _spectate_yaw) * Vector3(0.0, 0.0, 1.0)).normalized() if _spectate_user_orbited else fwd
			desired = pivot + view_fwd * (2.1 if rp_under_desk else 2.5) + Vector3(0.0, 0.60 if rp_under_desk else 0.20, 0.0)
		else:
			pivot = tgt_node.global_position + Vector3(0.0, 0.58 if rp_under_desk else 1.36, 0.0)
			var back_dir := (Basis(Vector3.UP, _spectate_yaw) * Basis(Vector3.RIGHT, -_spectate_pitch) * Vector3(0.0, 0.0, 1.0)).normalized()
			desired = pivot + back_dir * 2.2
	else:
		if not _spectate_user_orbited:
			_spectate_yaw = lerp_angle(_spectate_yaw, rp_yaw, 1.0 - exp(-10.0 * delta))
		pivot = tgt_node.global_position + Vector3(0.0, 1.48, 0.0)
		var back_dir := (Basis(Vector3.UP, _spectate_yaw) * Basis(Vector3.RIGHT, -_spectate_pitch) * Vector3(0.0, 0.0, 1.0)).normalized()
		desired = pivot + back_dir * 2.55
		var space_state := get_world_3d().direct_space_state
		if space_state != null:
			var q := PhysicsRayQueryParameters3D.create(pivot, desired, 0xFFFFFFFF, [player_body.get_rid()])
			var hit := space_state.intersect_ray(q)
			if not hit.is_empty():
				desired = hit.get("position", desired) - back_dir * 0.22

	cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
	cam.look_at(pivot, Vector3.UP)
	cam.fov = lerpf(cam.fov, 76.0, 1.0 - exp(-10.0 * delta))


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
			var sens := 0.0044 * _mouse_sens_mult
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

		if _state == State.SPECTATING:
			if ke.keycode == KEY_A or ke.keycode == KEY_LEFT:
				_cycle_spectate_target(-1)
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_D or ke.keycode == KEY_RIGHT:
				_cycle_spectate_target(1)
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
				if _ui.has("m_settings_box") and (_ui["m_settings_box"] as Control).visible:
					_open_settings_panel(false)
				else:
					_set_state(State.PLAYING)
				get_viewport().set_input_as_handled()
				return

		if _state == State.PLAYING:
			if _is_action_locked():
				if ke.keycode in [KEY_W, KEY_S, KEY_1, KEY_2, KEY_R]:
					get_viewport().set_input_as_handled()
					return
			if _is_hiding and ke.keycode == KEY_W:
				_exit_locker(false)
			elif _is_hiding and ke.keycode == KEY_S:
				_exit_locker(true)
			elif ke.keycode == KEY_1:
				_active_tool = 0
				_rmb_held = false
				audio.play_flashlight_click()
			elif ke.keycode == KEY_2 and _has_gummy:
				_active_tool = 1
				_light_on = true
				audio.play_flashlight_click()
			elif ke.keycode == KEY_R:
				_try_reload_flashlight()
			elif ke.keycode == KEY_M:
				_audio_muted = not _audio_muted
				_apply_audio_settings(true)
				_sync_settings_ui()
				_show_toast("Звук выключен" if _audio_muted else "Звук включён", 1.5)

	elif event is InputEventMouseMotion and (_state == State.PLAYING or _state == State.SPECTATING):
		if (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _state == State.SPECTATING:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				var rel_s := (event as InputEventMouseMotion).relative
				_spectate_yaw -= rel_s.x * 0.004 * _mouse_sens_mult
				_spectate_pitch = clampf(_spectate_pitch - rel_s.y * 0.004 * _mouse_sens_mult, -1.15, 0.85)
				_spectate_user_orbited = true
			return
		if not _mobile_controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if _locker_transition_t < 1.0:
				return
			var rel := (event as InputEventMouseMotion).relative
			if _is_hiding:
				_target_hide_yaw = clampf(_target_hide_yaw - rel.x * 0.0022 * _mouse_sens_mult, -0.58, 0.58)
				_target_hide_pitch = clampf(_target_hide_pitch - rel.y * 0.0022 * _mouse_sens_mult, -0.38, 0.38)
			else:
				_target_yaw -= rel.x * 0.0024 * _mouse_sens_mult
				_target_pitch = clampf(_target_pitch - rel.y * 0.0024 * _mouse_sens_mult, -1.42, 1.42)

	elif event is InputEventMouseButton and (_state == State.PLAYING or _state == State.SPECTATING):
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _state == State.SPECTATING:
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_cycle_spectate_target(1)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				_cycle_spectate_target(-1)
			return
		if _mobile_controls_enabled:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif not _is_action_locked():
				_try_interact()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				if _is_action_locked():
					return
				if _active_tool == 1:
					_rmb_held = true
					_reminder_dismissed = true
					_try_shake_gummy(3.5)
				else:
					_toggle_flashlight()
			else:
				_rmb_held = false


func _apply_camera_rotation() -> void:
	player_body.rotation = Vector3(0.0, _yaw, 0.0)
	cam.rotation = Vector3(_pitch, 0.0, _cam_roll)


func _sync_net_local_state() -> void:
	if _net != null and _net.is_online():
		var gp := player_body.global_position
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		var synced_yaw := player_body.rotation.y if _is_hiding else _yaw
		var synced_pitch := _hide_pitch_offset if _is_hiding else _pitch
		_net.update_local_state({
			"pos": [gp.x, gp.y, gp.z],
			"yaw": synced_yaw,
			"pitch": synced_pitch,
			"light": _light_on and (_active_tool == 0 and _std_battery > 0.05 or _active_tool == 1 and _gummy_battery > 0.05),
			"hide": _is_hiding,
			"hr": _hiding_room_idx if _is_hiding else -1,
			"hl": _hiding_locker_idx if _is_hiding else -1,
			"dead": (_state == State.DEAD or _state == State.SPECTATING),
			"sprint": hspd > 4.6,
			"room": _highest_opened,
			"hp": _hp,
		})


func _process(delta: float) -> void:
	_sync_net_local_state()
	_process_remote_players(delta)
	if _state == State.DEAD:
		_process_architect_and_scare(delta)
		return
	if _state == State.SPECTATING:
		_process_doors(delta)
		_process_spectating(delta)
		return
	if _state != State.PLAYING:
		return

	var look_alpha := 1.0 - exp(-18.0 * delta)
	_yaw = lerpf(_yaw, _target_yaw, look_alpha)
	_pitch = lerpf(_pitch, _target_pitch, look_alpha)
	_hide_yaw_offset = lerpf(_hide_yaw_offset, _target_hide_yaw, look_alpha)
	_hide_pitch_offset = lerpf(_hide_pitch_offset, _target_hide_pitch, look_alpha)

	var target_fov := (_base_fov - 9.0) if _is_hiding else _base_fov
	if not _is_hiding:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		if hspd > 4.6:
			target_fov = _base_fov + 6.0
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-10.0 * delta))
	cam.fov = _fov

	if _locker_transition_t < 1.0:
		var dur := maxf(_locker_transition_duration, 0.05)
		_locker_transition_t = minf(_locker_transition_t + delta / dur, 1.0)

	if _is_action_locked():
		_mobile_gummy_held = false
	var shaking_gummy := (not _is_action_locked()) and (_mobile_gummy_held or (_rmb_held and not _mobile_controls_enabled)) and _active_tool == 1 and _has_gummy
	_is_shaking_gummy = shaking_gummy
	if shaking_gummy:
		_light_on = true
		_gummy_battery = minf(_gummy_battery + delta * 26.7, 100.0)
		_gummy_pump_phase += delta * 15.0
		_vm_shake_time = 0.14
		_gummy_hold_accum += delta
		if _gummy_hold_accum >= 0.36:
			_gummy_hold_accum -= 0.36
			audio.play_gummy_shake()
	else:
		_gummy_hold_accum = 0.0

	var lock_mask: ColorRect = _ui["locker_mask"]
	if _is_hiding:
		if _locker_transition_t < 1.0:
			var prev_t := maxf(_locker_transition_t - delta / maxf(_locker_transition_duration, 0.05), 0.0)
			if _locker_transition_t >= 0.72 and prev_t < 0.72 and _active_tool == 0:
				_light_on = false
		if _anim_hand != null:
			if _hiding_kind != "under_desk" and _locker_transition_t < 0.98:
				_anim_hand.visible = true
				var p := _locker_transition_t
				if p < 0.30:
					var rp := ease(p / 0.30, 0.35)
					_anim_hand.position = Vector3(0.36, -0.26, -0.02).lerp(Vector3(0.14, -0.14, -0.16), rp)
					_anim_hand.rotation = Vector3(0.05, 0.18 * rp, -0.14 * rp)
				elif p < 0.65:
					var sp := (p - 0.30) / 0.35
					_anim_hand.position = Vector3(0.14, -0.14, -0.16).lerp(Vector3(-0.08, -0.12, -0.12), sin(sp * PI * 0.5))
					_anim_hand.rotation = Vector3(0.0, 0.36 * sp, -0.10)
				else:
					var cp := (p - 0.65) / 0.35
					var swing := sin(cp * PI)
					_anim_hand.position = Vector3(0.22, -0.16, -0.04).lerp(Vector3(0.34, -0.30, 0.04), cp) + Vector3(-0.18 * swing, 0.04 * swing, -0.12 * swing)
					_anim_hand.rotation = Vector3(0.06 * swing, 0.26 * swing - 0.12 * cp, -0.10 * swing)
			else:
				_anim_hand.visible = false
		if _vm_holder != null:
			_vm_holder.visible = (_locker_transition_t >= 0.94 and (_light_on or shaking_gummy))
			if _vm_holder.visible:
				_vm_std.visible = (_active_tool == 0)
				_vm_gummy.visible = (_active_tool == 1)
				_vm_holder.position = Vector3(0.18, -0.19, -0.28)
				if _vm_shake_time > 0.0 or shaking_gummy:
					if not shaking_gummy:
						_vm_shake_time = maxf(_vm_shake_time - delta, 0.0)
						_gummy_pump_phase += delta * 15.0
					var pump := sin(_gummy_pump_phase)
					_vm_gummy.position = _vm_gummy.position.lerp(Vector3(0.0, pump * 0.085, -0.012 * cos(_gummy_pump_phase)), 1.0 - exp(-22.0 * delta))
					_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3(pump * 0.24, 0.0, 0.0), 1.0 - exp(-22.0 * delta))
				else:
					_vm_gummy.position = _vm_gummy.position.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
					_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
		var t_ease := ease(_locker_transition_t, 0.26)
		var base_yaw := atan2(-_locker_fwd.x, -_locker_fwd.z)
		player_body.global_position = _locker_eye - Vector3(0.0, _hiding_eye_local_y, 0.0)
		if _locker_transition_t < 1.0 and _hiding_kind != "under_desk":
			var turn_p := ease(clampf((_locker_transition_t - 0.26) / 0.58, 0.0, 1.0), -2.0)
			player_body.rotation.y = lerp_angle(_locker_enter_from_yaw, base_yaw + _hide_yaw_offset, turn_p)
		else:
			player_body.rotation.y = lerp_angle(player_body.rotation.y, base_yaw + _hide_yaw_offset, clampf(1.0 - exp(-14.0 * delta) + t_ease * 0.25, 0.0, 1.0))
		_yaw = player_body.rotation.y
		_target_yaw = _yaw
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

		if _door_hand_timer > 0.0:
			_door_hand_timer = maxf(_door_hand_timer - delta, 0.0)

		if _anim_hand != null:
			if _locker_transition_t < 0.96 and not _locker_transition_entering:
				_anim_hand.visible = true
				var p_out := _locker_transition_t
				if _locker_exit_face_locker:
					# Fast 0.7s S exit animation: push door wide while twisting back toward locker
					var s_p := sin(p_out * PI)
					_anim_hand.position = Vector3(0.04, -0.12, -0.16).lerp(Vector3(0.32, -0.26, 0.02), p_out) + Vector3(-0.14 * s_p, 0.04 * s_p, -0.06 * s_p)
					_anim_hand.rotation = Vector3(0.06, 0.36 * s_p - 0.20 * p_out, -0.14 * s_p)
				else:
					# Full 1.0s W exit animation: reach door latch -> swing open -> step out & lower hand
					if p_out < 0.32:
						var r_p := ease(p_out / 0.32, 0.35)
						_anim_hand.position = Vector3(0.30, -0.24, -0.02).lerp(Vector3(0.04, -0.09, -0.18), r_p)
						_anim_hand.rotation = Vector3(0.06 * r_p, 0.16 * r_p, -0.14 * r_p)
					elif p_out < 0.68:
						var o_p := (p_out - 0.32) / 0.36
						_anim_hand.position = Vector3(0.04, -0.09, -0.18).lerp(Vector3(-0.20, -0.10, -0.10), sin(o_p * PI * 0.5))
						_anim_hand.rotation = Vector3(0.0, 0.42 * o_p, -0.10)
					else:
						var d_p := (p_out - 0.68) / 0.32
						_anim_hand.position = Vector3(-0.20, -0.10, -0.10).lerp(Vector3(0.30, -0.28, 0.04), d_p)
						_anim_hand.rotation = Vector3(-0.10 * d_p, -0.16 * d_p, 0.0)
			elif _door_hand_timer > 0.0:
				# Snappy 0.25s hand animation pushing room door forward & right (wider & harder if sprinting/stamina)
				_anim_hand.visible = true
				var pd := 1.0 - clampf(_door_hand_timer / 0.25, 0.0, 1.0)
				var reach_mul := 1.32 if _door_hand_slam else 1.0
				if pd < 0.45:
					var rp_d := ease(pd / 0.45, 0.4)
					_anim_hand.position = Vector3(0.32, -0.28, 0.02).lerp(Vector3(-0.04, -0.12, -0.24 * reach_mul), rp_d)
					_anim_hand.rotation = Vector3(0.06 * rp_d, 0.24 * rp_d * reach_mul, -0.14 * rp_d)
				else:
					var sp_d := (pd - 0.45) / 0.55
					var push_arc := sin(sp_d * PI * 0.5)
					_anim_hand.position = Vector3(-0.04, -0.12, -0.24 * reach_mul).lerp(Vector3(0.34, -0.30, 0.02), sp_d) + Vector3(0.18 * push_arc * reach_mul, 0.03 * push_arc, -0.08 * push_arc)
					_anim_hand.rotation = Vector3(0.04, lerpf(0.24 * reach_mul, -0.45 * reach_mul, sp_d), -0.12 * (1.0 - sp_d))
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
			var dip_y := -0.11 if _door_hand_timer > 0.0 else 0.0
			_vm_holder.position = _vm_holder.position.lerp(Vector3(0.24 + bx, -0.21 + by + dip_y, -0.34), 1.0 - exp(-14.0 * delta))
			_vm_holder.rotation.x = lerpf(_vm_holder.rotation.x, fl_lag_x * 0.75, 1.0 - exp(-14.0 * delta))
			_vm_holder.rotation.y = lerpf(_vm_holder.rotation.y, fl_lag_y * 0.75, 1.0 - exp(-14.0 * delta))
			if _vm_shake_time > 0.0 or shaking_gummy:
				if not shaking_gummy:
					_vm_shake_time = maxf(_vm_shake_time - delta, 0.0)
					_gummy_pump_phase += delta * 15.0
				var pump := sin(_gummy_pump_phase)
				_vm_gummy.position = _vm_gummy.position.lerp(Vector3(0.0, pump * 0.085, -0.012 * cos(_gummy_pump_phase)), 1.0 - exp(-22.0 * delta))
				_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3(pump * 0.24, 0.0, 0.0), 1.0 - exp(-22.0 * delta))
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


func _process_architect_and_scare(delta: float) -> void:
	if _a90_scare_timer > 0.0:
		_a90_scare_timer -= delta
		var scare_rect: TextureRect = _ui["a90_scare_rect"]
		scare_rect.modulate.a = clampf(_a90_scare_timer / 0.45, 0.0, 1.0)
		if _a90_scare_timer <= 0.0:
			scare_rect.visible = false

	_death_phase_t += delta
	var iris := _ui.get("death_iris") as Control
	var imat := _ui.get("death_iris_mat") as ShaderMaterial
	if _death_phase == 0:
		# Phase 0: Red death flash (0.48s)
		if imat != null:
			imat.set_shader_parameter("red_amt", lerpf(0.92, 0.78, clampf(_death_phase_t / 0.48, 0.0, 1.0)))
			imat.set_shader_parameter("shrink_amt", 0.0)
		if _death_phase_t >= 0.48:
			_death_phase = 1
			_death_phase_t = 0.0
		return
	elif _death_phase == 1:
		# Phase 1: Screen compresses & fades inward to center into darkness (0.80s)
		var sp := clampf(_death_phase_t / 0.80, 0.0, 1.0)
		if imat != null:
			imat.set_shader_parameter("shrink_amt", sp)
			imat.set_shader_parameter("red_amt", lerpf(0.78, 0.0, ease(sp, 0.55)))
		if sp >= 1.0:
			_death_phase = 2
			_death_phase_t = 0.0
			audio.play_architect_appear()
			var arch_overlay: Control = _ui["architect_overlay"]
			arch_overlay.visible = true
			arch_overlay.modulate.a = 0.0
			var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(arch_overlay, "modulate:a", 1.0, 0.75)
		return

	if iris != null and _ui.has("architect_overlay"):
		iris.visible = (_ui["architect_overlay"] as Control).modulate.a < 0.99

	if _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
		_arch_glitch_timer += delta
		if _arch_glitch_timer >= 0.045:
			_arch_glitch_timer = 0.0
			_arch_glitch_step += 1
			if _arch_glitch_step < 12:
				var frame_txt := RoomsArchitect.generate_glitch_frame(_arch_prev_text, cur_line, _arch_glitch_step, 12)
				(_ui["arch_speech"] as Label).text = frame_txt
				var shade := Color(0.28, 1.0, 0.42) if _arch_glitch_step % 2 == 0 else Color(0.12, 0.70, 0.22)
				(_ui["arch_speech"] as Label).add_theme_color_override("font_color", shade)
				audio.play_architect_blip(_rng.randf_range(0.92, 1.10))
			else:
				(_ui["arch_speech"] as Label).text = cur_line
				(_ui["arch_speech"] as Label).add_theme_color_override("font_color", Color(0.28, 1.0, 0.42))
				_arch_prev_text = cur_line
				_arch_char_pos = float(cur_line.length())
				_arch_auto_advance_timer = 0.0
				_refresh_architect_controls()
	elif _arch_glitch_step >= 12:
		_arch_auto_advance_timer += delta
		if _arch_auto_advance_timer >= 3.0:
			_arch_auto_advance_timer = 0.0
			_advance_architect_dialogue()


func _toggle_flashlight() -> void:
	if _is_action_locked():
		return
	if _active_tool == 1:
		# Shakerlight cannot be turned off while equipped
		_light_on = true
		return
	if _std_battery <= 0.0 and not _light_on:
		audio.play_flashlight_click()
		_show_toast("Фонарик разряжен! Соберите 2 батарейки и нажмите [R].", 2.2)
		return
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
			_std_battery = minf(_std_battery, 30.0)
			_std_low_power_regen = 0.0
			(_ui["darkness_rect"] as Control).visible = false
			audio.stop_darkness()
			audio.play_flashlight_low_power()
			_show_toast("Обычный фонарик отпугнул Тьму (слабый режим)!", 2.2)


func _try_reload_flashlight() -> void:
	if _is_action_locked():
		return
	if _std_battery >= 149.9 and not _std_low_power:
		_show_toast("Обычный фонарик уже полностью заряжен", 1.8)
		return
	if _batteries < 2:
		_show_toast("Нужно 2 батарейки для зарядки (%d/2)" % _batteries, 2.2)
		return
	_batteries -= 2
	_std_battery = 150.0
	_std_low_power = false
	_std_low_power_regen = 0.0
	_std_low_flicker_t = 0.0
	audio.play_pickup()
	_show_toast("Фонарик заряжен (-2 батарейки, осталось: %d)" % _batteries, 2.4)


func _try_shake_gummy(amount: float = 10.0) -> void:
	if _is_action_locked() or _active_tool != 1 or not _has_gummy:
		return
	_light_on = true
	_gummy_battery = minf(_gummy_battery + amount, 100.0)
	_shake_amount = maxf(_shake_amount, 0.012)
	_vm_shake_time = 0.36
	audio.play_gummy_shake()


func _try_interact() -> bool:
	if _is_action_locked():
		return false
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
			_batteries += 1
			_show_toast("Батарейка (+1) — Всего: %d. [R] для зарядки (нужно 2)" % _batteries, 2.8)
		elif pkind == "gummy":
			_has_gummy = true
			_active_tool = 1
			_light_on = true
			_gummy_battery = 100.0
			_show_toast("Подобран Трясосвет [2]! Зажмите [ПКМ] чтобы заряжать.", 3.2)
		elif pkind == "medkit":
			_hp = mini(_hp + 45, 100)
			audio.low_hp_mode = (_hp <= 25)
			_show_toast("+45 HP восстановлено")
		audio.play_pickup()
		node.queue_free()
		return true
	return false


func _try_tap_world_interact(screen_pos: Vector2) -> void:
	if _is_action_locked():
		return
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
		var lbl := "Занято" if _is_locker_occupied(r_idx, l_idx) else "Спрятаться"
		if lbl != "Занято" and r_inst != null and l_idx >= 0 and l_idx < r_inst.lockers.size():
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
				var occupied := _is_locker_occupied(r.index, li)
				best_tgt = {
					"type": "locker",
					"room_index": r.index,
					"locker_index": li,
					"label": "Занято" if occupied else String(ld.get("label", "Спрятаться")),
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


func _is_locker_occupied(r_idx: int, l_idx: int) -> bool:
	for pk in _remote_players.keys():
		var rp: Dictionary = _remote_players[pk]
		if bool(rp.get("dead", false)) or not bool(rp.get("hiding", false)):
			continue
		if int(rp.get("hide_room", -1)) == r_idx and int(rp.get("hide_locker", -1)) == l_idx:
			return true
	return false


func _open_room_door(r_idx: int, slam: bool = false, from_remote: bool = false) -> void:
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null or r.door_opened:
		return
	var is_slam := slam
	if not from_remote and not is_slam:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		is_slam = _is_sprinting or hspd > 4.4
	r.door_opened = true
	if r.door_collider != null:
		r.door_collider.collision_layer = 0
		r.door_collider.collision_mask = 0
	_opening_doors.append({"pivot": r.door_pivot, "progress": 0.0, "slam": is_slam})
	if not from_remote and not _is_hiding:
		_door_hand_timer = 0.25
		_door_hand_slam = is_slam
		if is_slam:
			_shake_amount = maxf(_shake_amount, 0.016)
	audio.play_door_open()
	if not from_remote and _net != null and _net.is_online():
		_net.broadcast_door_opened(r_idx, is_slam)
	_advance_door_progress(r_idx, not from_remote)


func _advance_door_progress(r_idx: int, allow_spawn: bool) -> void:
	var opened_num := r_idx + 1
	if opened_num > _highest_opened:
		_highest_opened = opened_num
		_current_room_idx = opened_num
		if _net != null:
			_net.update_lobby_progress(_world_seed, _highest_opened)
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
	if _is_action_locked() or _is_hiding:
		return
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null or l_idx < 0 or l_idx >= r.lockers.size():
		return
	if _is_locker_occupied(r_idx, l_idx):
		_show_toast("Спот занят!", 1.8)
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
	_target_pitch = 0.0
	_pitch = 0.0
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
	if _net != null and _net.is_online():
		_net.broadcast_locker_action(r_idx, l_idx, true, false)


func _exit_locker(face_locker: bool = false) -> void:
	if _is_action_locked() or not _is_hiding:
		return
	var prev_kind := _hiding_kind
	var prev_door_pivot := _hiding_door_pivot
	var prev_room_idx := _hiding_room_idx
	var prev_locker_idx := _hiding_locker_idx
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
	_light_on = true if _active_tool == 1 else _was_light_before_hide
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
	if _net != null and _net.is_online() and prev_room_idx >= 0 and prev_locker_idx >= 0:
		_net.broadcast_locker_action(prev_room_idx, prev_locker_idx, false, face_locker)


func _maybe_spawn_door_entities(room_num: int) -> void:
	if not _is_entity_authority():
		return
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
	if _rooms.is_empty():
		return
	var target_r := _find_first_closed_door_room()
	if target_r == null:
		return
	_start_a60_local(target_r.index, force_prime)
	if _is_entity_authority() and _net != null and _net.is_online():
		_net.broadcast_entity_event({
			"k": "a60_spawn",
			"door": target_r.index,
			"prime": force_prime,
		}, true)


func _start_a60_local(target_door_idx: int, is_prime: bool) -> void:
	_a60_path.clear()
	if _rooms.is_empty():
		return
	var target_r: RoomBuilder.RoomInstance = _room_by_idx.get(target_door_idx)
	if target_r == null:
		target_r = _find_first_closed_door_room()
	if target_r == null:
		target_r = _rooms[-1]
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

	_a60_active = true
	_a60_phase = 2
	_a60_is_prime = is_prime
	_a60_prime_rebounds = 0
	_a60_prime_table_burned = false
	_a60_prime_hit_cd = 0.0
	_a60_scare_snd_cd = 0.0
	_a60_hint_timer = (2.4 if _highest_opened < 100 else 0.0) if not is_prime else 0.0
	if is_prime:
		_a60_prime_flicker_active = true
		_a60_prime_flicker_gap_t = 0.0

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
	_start_a120_local(spawn_idx, rb)
	if _is_entity_authority() and _net != null and _net.is_online():
		_net.broadcast_entity_event({
			"k": "a120_spawn",
			"room": spawn_idx,
			"rb": rb,
		}, true)


func _start_a120_local(spawn_idx: int, rb: int) -> void:
	if _rooms.is_empty():
		return
	var spawn_r: RoomBuilder.RoomInstance = _room_by_idx.get(spawn_idx)
	if spawn_r == null:
		spawn_r = _rooms[-1]

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
	_net_a120_tgt = _a120_node.position
	_a120_node.visible = true
	_a120_sprite.modulate = Color(1.0, 1.0, 1.0)
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
	var best_pos := (_locker_eye + _locker_fwd * 0.95) if _is_hiding else player_body.global_position
	var best_exposed := not _is_hiding
	var best_d := _a120_node.global_position.distance_squared_to(best_pos)
	for pk in _remote_players.keys():
		var rp: Dictionary = _remote_players[pk]
		if bool(rp.get("dead", false)):
			continue
		var r_exp := not bool(rp.get("hiding", false))
		var rp_pos: Vector3 = rp.get("tgt_pos", Vector3.ZERO)
		var d := _a120_node.global_position.distance_squared_to(rp_pos)
		if (r_exp and not best_exposed) or (r_exp == best_exposed and d < best_d):
			best_exposed = r_exp
			best_pos = rp_pos
			best_d = d
	return Vector3(best_pos.x, 1.55, best_pos.z)


func _handle_a120_hit() -> void:
	_a120_hit_cd = 1.5
	_a120_active = false
	_a120_phase = 0
	_a120_substage = 0
	_a120_node.visible = false
	audio.stop_a120()
	audio.play_a120_scream()
	if _net != null and _net.is_online():
		_net.broadcast_entity_event({"k": "a120_end", "from_client": not _is_entity_authority()}, true)

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
	if _state == State.SPECTATING:
		_process_entities(delta)
		return
	if _state == State.DEAD:
		if _is_entity_authority() and _net != null and _net.is_online() and _has_alive_remote_players():
			_process_entities(delta)
		return
	if _state != State.PLAYING:
		return

	_run_time += delta
	_process_doors(delta)
	_process_flashlight(delta)

	if _is_entity_authority():
		if _a60_prime_pending_timer > 0.0 and not _a60_active and not _a120_active:
			_a60_prime_pending_timer -= delta
			if _a60_prime_pending_timer <= 0.0:
				_spawn_a60(true)
		elif _highest_opened >= 5 and not _a60_active and not _a120_active and not _a60_prime_flicker_active:
			_a60_random_timer -= delta
			if _a60_random_timer <= 0.0:
				var max_cd := maxf(24.0, 52.0 - float(_highest_opened) * 0.12)
				var min_cd := maxf(14.0, max_cd * 0.52)
				_a60_random_timer = _rng.randf_range(min_cd, max_cd)
				_spawn_a60(false)

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
		var p: float = minf(float(d["progress"]) + delta / 0.25, 1.0)
		d["progress"] = p
		var pivot := pivot_raw as Node3D
		var target_ang: float = -PI * 0.88 if bool(d.get("slam", false)) else -PI * 0.52
		pivot.rotation.y = lerpf(0.0, target_ang, 1.0 - pow(1.0 - p, 2.0))
		if p >= 1.0:
			_opening_doors.remove_at(i)


func _process_flashlight(delta: float) -> void:
	if _std_low_flicker_t > 0.0:
		_std_low_flicker_t = maxf(_std_low_flicker_t - delta, 0.0)
	if _a60_prime_flicker_gap_t > 0.0:
		_a60_prime_flicker_gap_t = maxf(_a60_prime_flicker_gap_t - delta, 0.0)
	if _a60_prime_flicker_snd_cd > 0.0:
		_a60_prime_flicker_snd_cd = maxf(_a60_prime_flicker_snd_cd - delta, 0.0)

	# Shakerlight [2] cannot be turned off while equipped
	if _active_tool == 1:
		_light_on = true

	var has_charge := (_std_battery > 0.0) if _active_tool == 0 else (_gummy_battery > 0.05)
	var is_lit := _light_on and has_charge
	if is_lit:
		var power_mult := 1.0
		if _active_tool == 0:
			# Before A-050 battery won't drain! From A-050+: 120s normal (>30s) + 30s Low Battery Mode (<=30s)
			if _highest_opened >= 50:
				var prev_bat := _std_battery
				_std_battery = maxf(_std_battery - delta, 0.0)
				if prev_bat > 30.0 and _std_battery <= 30.0 and not _std_low_power:
					_std_low_power = true
					_std_low_flicker_t = 0.85
					audio.play_flashlight_low_power()
					_show_toast("Низкий заряд фонарика! Нажмите [R] с 2 батарейками.", 2.6)
				if _std_battery <= 0.0:
					_light_on = false
					audio.play_flashlight_click()
					_show_toast("Фонарик сел! Соберите 2 батарейки и нажмите [R].", 2.8)
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
			if _gummy_battery < 25.0:
				power_mult = clampf(0.32 + (_gummy_battery / 25.0) * 0.68, 0.32, 1.0)

		var cur_bat := _std_battery if _active_tool == 0 else _gummy_battery
		var flicker := 1.0
		if _std_low_flicker_t > 0.0 and _active_tool == 0:
			flicker = _rng.randf_range(0.05, 0.75)
		elif _a60_prime_flicker_active and _a60_prime_flicker_gap_t <= 0.0:
			# A-60' constant flashlight flicker warning (visual + auditory cue!)
			flicker = _rng.randf_range(0.04, 0.92) if _rng.randf() < 0.72 else 1.0
			if _a60_prime_flicker_snd_cd <= 0.0:
				_a60_prime_flicker_snd_cd = _rng.randf_range(0.11, 0.19)
				audio.play_flashlight_flicker()
		elif cur_bat < 8.0 and _rng.randf() < 0.22:
			flicker = _rng.randf_range(0.25, 0.85)
		flashlight.light_energy = 2.6 * power_mult * flicker
		flashlight.visible = not (_active_tool == 0 and _std_battery <= 0.0)
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
			if _hide_time > 24.0:
				_show_toast("Пора выходить из укрытия!", 1.2)
		return

	_hide_time += delta
	# Very gradual Darkness progression (A-021 = ~24s, slowing gently down to ~4.5s / ~3s in late power-out rooms)
	var prog := clampf(float(_highest_opened - 21) / 600.0, 0.0, 1.0)
	var base_delay := lerpf(24.0, 4.5, prog)
	var disturb_delay := maxf(3.0, base_delay * 0.72) if _power_out else base_delay
	if _darkness_quick_return:
		disturb_delay = 4.5 if (_light_on and _active_tool == 0) else 2.0

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
		var ramp_dur := lerpf(5.5, 2.2, prog) * (0.82 if _power_out else 1.0)
		_darkness_whisper_t = minf(_darkness_whisper_t + delta / ramp_dur, 1.0)
		audio.update_darkness(_darkness_whisper_t)
		dk_rect.visible = true
		var s := lerpf(0.82, 1.08, _darkness_whisper_t)
		dk_rect.scale = Vector2(s, s)
		dk_rect.pivot_offset = dk_rect.size * 0.5
		dk_rect.modulate = Color(1.0, 1.0, 1.0, pow(_darkness_whisper_t, 1.15) * 0.94)
		if _darkness_whisper_t >= 1.0:
			_darkness_phase = 2
			_darkness_dmg_accum = 0.45
	elif _darkness_phase == 2:
		audio.update_darkness(1.0)
		dk_rect.visible = true
		var pulse_s := 1.06 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.014)
		dk_rect.scale = Vector2(pulse_s, pulse_s)
		dk_rect.pivot_offset = dk_rect.size * 0.5
		dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.98)
		_shake_amount = maxf(_shake_amount, 0.030)
		_darkness_dmg_accum += delta
		if _darkness_dmg_accum >= 0.65:
			_darkness_dmg_accum -= 0.65
			_hp -= 12
			audio.low_hp_mode = (_hp <= 25 and _hp > 0)
			(_ui["dmg_flash"] as ColorRect).color = Color(0.88, 0.04, 0.04, 0.56)
			if _hp <= 0:
				_trigger_death("The Darkness")
				return


func _process_player_movement(delta: float) -> void:
	if _is_action_locked():
		player_body.velocity.x = 0.0
		player_body.velocity.z = 0.0
		player_body.move_and_slide()
		return

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
	_is_sprinting = wants_sprint
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
	if _is_shaking_gummy:
		speed *= 0.5
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
		_bob_phase += delta * (10.5 if wants_sprint else 6.8) * (0.65 if _is_shaking_gummy else 1.0)
		_step_timer -= delta * (1.42 if wants_sprint else 0.90) * (0.55 if _is_shaking_gummy else 1.0)
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
	var bob_y := (sin(_bob_phase) * 0.032) if _head_bob_enabled else 0.0
	var breath_bob := sin(float(Time.get_ticks_msec()) * 0.0055) * (0.022 if _exhausted else 0.0)
	if _locker_transition_t >= 1.0:
		cam.position = Vector3(0.0, 1.48 + bob_y + breath_bob, 0.0) + shake_off

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
	var is_auth := _is_entity_authority()
	var can_harm_local := (_state == State.PLAYING)
	if _a60_scare_snd_cd > 0.0:
		_a60_scare_snd_cd = maxf(_a60_scare_snd_cd - delta, 0.0)
	if _a60_prime_hit_cd > 0.0:
		_a60_prime_hit_cd = maxf(_a60_prime_hit_cd - delta, 0.0)

	var send_ent_sync := false
	if is_auth and (_a60_active or _a120_active):
		_ent_sync_accum += delta
		if _ent_sync_accum >= 0.08:
			_ent_sync_accum = 0.0
			send_ent_sync = true

	if _a60_active:
		_a60_node.visible = (_state != State.DEAD)
		_a60_anim_timer += delta
		var flip_interval := 0.035 if _a60_is_prime else 0.045
		if _a60_anim_timer > flip_interval:
			_a60_anim_timer = 0.0
			_a60_frame_idx = (_a60_frame_idx + _rng.randi_range(1, 5)) % maxi(_a60_frames.size(), 1)
			var f60 := _a60_frames[_a60_frame_idx]
			_a60_last_tex = f60
			_a60_sprite.texture = f60
			_a60_sprite.pixel_size = 2.65 / float(maxi(f60.get_width(), 1))

		var d_player := _a60_node.global_position.distance_to(cam.global_position)
		if _state != State.DEAD:
			audio.a60_intensity = 0.0 if _a60_is_prime else clampf(16.0 / maxf(d_player, 2.0), 0.12, 1.0)
			audio.update_a60_mix(delta, d_player, _a60_phase, _a60_is_prime)

		var prime_col := Vector3(0.25, 0.85, 1.0) if _a60_is_prime else Vector3(1.0, 0.22, 0.18)
		static_mat.set_shader_parameter("tint_col", prime_col)

		if _a60_hint_timer > 0.0:
			_a60_hint_timer = maxf(_a60_hint_timer - delta, 0.0)

		if _a60_phase == 2:
			if can_harm_local:
				var near_prox := clampf(1.0 - (d_player - 2.0) / 22.0, 0.0, 1.0)
				if not _a60_is_prime:
					_shake_amount = maxf(_shake_amount, near_prox * 0.11)
				else:
					_shake_amount = maxf(_shake_amount, near_prox * 0.045)

				var hint_static := 0.0
				if not _a60_is_prime and _a60_hint_timer > 0.0 and _highest_opened < 100:
					var fade := clampf(_a60_hint_timer / 0.85, 0.0, 1.0)
					hint_static = fade * (0.55 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.015))

				var total_static := maxf(hint_static, near_prox * (0.35 if _a60_is_prime else 0.65))
				if total_static > 0.03:
					static_rect.visible = true
					static_mat.set_shader_parameter("static_amt", total_static)
					static_mat.set_shader_parameter("vig_amt", 0.0)
				else:
					static_rect.visible = false
			else:
				static_rect.visible = false
				a60_scare_rect.visible = false

			if is_auth:
				# Keep tracking the FIRST still-closed door in case any player opened target mid-rush
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

				var rush_speed := 72.0 if _a60_is_prime else 60.0
				if _a60_path_idx < _a60_path.size():
					var tgt := _a60_path[_a60_path_idx]
					var to_t := tgt - _a60_node.position
					if to_t.length() <= rush_speed * delta:
						_a60_node.position = tgt
						_a60_path_idx += 1
					else:
						_a60_node.position += to_t.normalized() * rush_speed * delta
				else:
					var smash_r: RoomBuilder.RoomInstance = _room_by_idx.get(_a60_target_door_idx)
					if smash_r != null and not smash_r.door_opened and not smash_r.door_broken:
						_break_door_by_a60(_a60_target_door_idx, _a60_is_prime)
						if _net != null and _net.is_online():
							_net.broadcast_entity_event({"k": "a60_brk", "door": _a60_target_door_idx, "prime": _a60_is_prime}, true)
					_a60_phase = 3
					_a60_sink_timer = 0.42
					a60_scare_rect.visible = false
					if _net != null and _net.is_online():
						_net.broadcast_entity_event({"k": "a60_end"}, true)

				if send_ent_sync and _net != null and _net.is_online():
					var p60 := _a60_node.position
					_net.broadcast_entity_event({
						"k": "a60_pos",
						"p": [p60.x, p60.y, p60.z],
						"ph": _a60_phase,
						"door": _a60_target_door_idx,
						"prime": _a60_is_prime,
					}, false)
			else:
				var rush_speed_c := 72.0 if _a60_is_prime else 60.0
				_a60_node.position = _a60_node.position.move_toward(_net_a60_tgt, rush_speed_c * delta * 1.25)

			# Table Burn from A-60' (90% chance to deal 20 damage when hiding under a table!)
			if can_harm_local and _a60_phase == 2 and _a60_is_prime and _is_hiding and _hiding_kind == "under_desk" and d_player <= 11.5 and not _a60_prime_table_burned:
				_a60_prime_table_burned = true
				if _rng.randf() < 0.90:
					_hp -= 20
					audio.low_hp_mode = (_hp <= 25 and _hp > 0)
					(_ui["dmg_flash"] as ColorRect).color = Color(0.95, 0.32, 0.14, 0.62)
					_shake_amount = maxf(_shake_amount, 0.06)
					_show_toast("Ожог от A-60' под столом (-20 HP!)", 2.2)
					if _hp <= 0:
						_trigger_death("A-60'", "", {"distance": d_player, "table_burn": true})
						return

			# Raycast line-of-sight attack if player is exposed and not hiding
			if can_harm_local and _a60_phase == 2 and d_player <= 11.5 and not _is_hiding:
				var space := get_world_3d().direct_space_state
				var q := PhysicsRayQueryParameters3D.create(_a60_node.global_position, cam.global_position)
				q.exclude = [player_body.get_rid()]
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					if _a60_is_prime:
						if _a60_prime_hit_cd <= 0.0:
							_a60_prime_hit_cd = 1.2
							_hp -= 35
							audio.low_hp_mode = (_hp <= 25 and _hp > 0)
							(_ui["dmg_flash"] as ColorRect).color = Color(0.35, 0.90, 1.0, 0.65)
							_shake_amount = maxf(_shake_amount, 0.08)
							_show_toast("A-60' (Prime) нанёс 35 урона! Прячьтесь в шкаф!", 2.4)
							if _hp <= 0:
								_trigger_death("A-60'", "", {"distance": d_player})
								return
					else:
						a60_scare_rect.visible = true
						a60_scare_rect.texture = _a60_sprite.texture
						a60_scare_rect.modulate = Color(1.0, 0.92, 0.92, 0.96)
						var vp := get_viewport().get_visible_rect().size
						a60_scare_rect.position = vp * 0.5 - Vector2(270, 270)
						audio.play_a60_jumpscare(false)
						_hp = 0
						audio.low_hp_mode = false
						(_ui["dmg_flash"] as ColorRect).color = Color(0.92, 0.08, 0.08, 0.78)
						_trigger_death("A-60", "", {"distance": d_player})
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
				var was_prime := _a60_is_prime
				_a60_active = false
				_a60_phase = 0
				_a60_node.visible = false
				_a60_sprite.modulate.a = 1.0
				audio.stop_a60()

				# MultiMonster Prime (A-60') follows regular A-60 starting after A-049 (A-50+)!
				if is_auth:
					if not was_prime and _highest_opened >= 50:
						var p_prog := clampf(float(_highest_opened - 50) / 850.0, 0.0, 1.0)
						var spawn_ch := lerpf(0.45, 0.90, p_prog)
						if _rng.randf() < spawn_ch:
							var max_chains := mini(1 + int(floor(p_prog * 3.0)), 4)
							var chains := 1
							for _c in range(max_chains - 1):
								if _rng.randf() < lerpf(0.25, 0.72, p_prog):
									chains += 1
							var delay := lerpf(5.0, 3.0, p_prog)
							_a60_prime_pending_timer = delay
							_a60_prime_chains_left = chains - 1
							_a60_prime_flicker_active = true
							_a60_prime_flicker_gap_t = 0.0
							if _net != null and _net.is_online():
								_net.broadcast_entity_event({"k": "a60p_warn", "gap": 0.0}, true)
					elif was_prime:
						if _a60_prime_chains_left > 0:
							_a60_prime_chains_left -= 1
							var p_prog2 := clampf(float(_highest_opened - 50) / 850.0, 0.0, 1.0)
							_a60_prime_flicker_active = true
							_a60_prime_flicker_gap_t = 0.5
							_a60_prime_pending_timer = lerpf(3.6, 2.6, p_prog2)
							if _net != null and _net.is_online():
								_net.broadcast_entity_event({"k": "a60p_warn", "gap": 0.5}, true)
						else:
							_a60_prime_flicker_active = false
							if _net != null and _net.is_online():
								_net.broadcast_entity_event({"k": "a60p_end"}, true)
	else:
		audio.a60_intensity = lerpf(audio.a60_intensity, 0.0, minf(delta * 4.0, 1.0))
		static_rect.visible = false
		a60_scare_rect.visible = false
		_a60_node.visible = false

	# --- A-120 (Happy Scribble) ---
	if _a120_hit_cd > 0.0:
		_a120_hit_cd = maxf(_a120_hit_cd - delta, 0.0)

	if _a120_active:
		_a120_node.visible = (_state != State.DEAD)
		var d120 := _a120_node.global_position.distance_to(cam.global_position)
		var drum_hit := audio.update_a120_mix(delta, d120, _a120_phase) if _state != State.DEAD else false
		_a120_anim_timer += delta
		if _a120_anim_timer >= 0.50:
			_a120_anim_timer -= 0.50
			_a120_frame_idx = (_a120_frame_idx + 1) % maxi(_a120_frames.size(), 1)
			var f120 := _a120_frames[_a120_frame_idx] if not _a120_frames.is_empty() else null
			if f120 != null:
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

		if not is_auth:
			_a120_node.position = _a120_node.position.lerp(_net_a120_tgt, clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0))
		elif _a120_phase == 1:
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
					var tgt_room := _get_room_idx_near(live_tgt)
					var move_tgt := live_tgt
					if _a120_path_idx < _a120_path.size() and _get_room_idx_near(_a120_node.position) != tgt_room:
						move_tgt = _a120_path[_a120_path_idx]
					var to_m := move_tgt - _a120_node.position
					if to_m.length() <= spd120 * delta:
						_a120_node.position = move_tgt
						if move_tgt.distance_to(live_tgt) < 1.25:
							var min_room := _rooms[0].index if not _rooms.is_empty() else 0
							var prev_idx := maxi(min_room, tgt_room - _rng.randi_range(2, 4))
							if prev_idx == tgt_room and min_room < tgt_room:
								prev_idx = tgt_room - 1
							_a120_substage = 1
							_a120_path = _build_a120_corridor_path(tgt_room, prev_idx)
							if prev_idx == tgt_room and _room_by_idx.has(tgt_room):
								var cr: RoomBuilder.RoomInstance = _room_by_idx[tgt_room]
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
							var tgt_room2 := _get_room_idx_near(_get_a120_live_target())
							_a120_path = _build_a120_corridor_path(_get_room_idx_near(_a120_node.position), tgt_room2)
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
						if _net != null and _net.is_online():
							_net.broadcast_entity_event({"k": "a120_end"}, true)

		if is_auth and send_ent_sync and _a120_active and _net != null and _net.is_online():
			var p120 := _a120_node.position
			_net.broadcast_entity_event({
				"k": "a120_pos",
				"p": [p120.x, p120.y, p120.z],
				"ph": _a120_phase,
				"ss": _a120_substage,
				"room": _current_room_idx,
			}, false)

		if can_harm_local and _a120_active and _a120_phase == 2 and _a120_node.global_position.distance_to(cam.global_position) < 2.15 and not _is_hiding and _a120_hit_cd <= 0.0:
			_handle_a120_hit()
			return
	else:
		_a120_node.visible = false

	# --- A-90 / Paralysis (Freeze check, starts around A-009+) ---
	if not can_harm_local:
		_a90_phase = 0
		(_ui["a90_rect"] as Control).visible = false
		(_ui["a90_stop_icon"] as Control).visible = false
		(_ui["a90_stop"] as Control).visible = false
		(_ui["a90_scare_rect"] as Control).visible = false
		return
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
	if _state != State.PLAYING:
		return
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
		if not _is_action_locked():
			if _hiding_kind == "under_desk":
				prompt.text = "[W / S] Вылезти из-под тумбочки"
			elif _hiding_kind == "fridge":
				prompt.text = "[W] Выйти вперёд  |  [S] Выйти лицом к холодильнику"
			else:
				prompt.text = "[W] Выйти вперёд  |  [S] Выйти лицом к шкафу"
			want_prompt = true
	else:
		interact_tgt = {} if _is_action_locked() else _find_smart_reticle_target()
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
			rem.text = "Reminder: [WHITE] to turn flashlight." if _mobile_controls_enabled else "Reminder: [RMB] to turn flashlight."
		var rem_rate := 6.5 if want_rem else 5.5
		_reminder_alpha = lerpf(_reminder_alpha, 1.0 if want_rem else 0.0, clampf(1.0 - exp(-rem_rate * delta), 0.0, 1.0))
		rem.modulate.a = _reminder_alpha
		rem.visible = (_reminder_alpha > 0.01)

	if _ui.has("bat_lbl"):
		var bat_lbl: Label = _ui["bat_lbl"]
		var show_bat := (_batteries > 0 or _std_low_power or _std_battery <= 30.0)
		bat_lbl.visible = show_bat
		if show_bat:
			var b_txt := "Батарейки: %d" % _batteries
			if _std_battery <= 0.05:
				b_txt += "  |  Фонарик разряжен [R]"
			elif _std_low_power or _std_battery <= 30.0:
				b_txt += "  |  Слабый заряд [R]"
			elif _batteries >= 2 and _std_battery < 149.9:
				b_txt += "  |  [R] Зарядить"
			bat_lbl.text = b_txt

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


func _show_toast(msg: String, duration: float = 2.8) -> void:
	var lbl := _ui["toast_lbl"] as Label
	if not lbl.visible or lbl.text != msg:
		_toast_alpha = 0.0
		lbl.modulate.a = 0.0
	lbl.text = msg
	lbl.visible = true
	_toast_timer = maxf(duration, 1.1)
