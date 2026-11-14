extends Node3D

## Rooms-inspired 3D procedural horror runner (A-000 -> A-200+ Endless) inside Godot 4.7.

enum State { PLAYING, PAUSED, DEAD, VICTORY, SPECTATING, MENU }
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
var _battery_inspect_timer := 0.0
var _held_battery: Node3D = null
var _a60_door20_trigger_timer := 0.0

# Modifiers & Admin System
var _active_modifiers: Dictionary = {
	"admin_panel": false,
	"wet_floor": false,
	"bad_time": false,
	"make_haste": false,
	"lights_out": false,
	"sprint_fatigue": false,
}
var _admin_cheats_used := false
var _admin_god_mode := false
var _admin_inf_stamina := false
var _admin_granted_to_all := false
var _admin_granted_by_host := false
var _haste_timer := 60.0
var _door50_flicker_active := false
var _door50_flicker_t := 0.0

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

var _state: State = State.MENU
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
var _a120_warp_fx_t := 0.0
var _a120_warp_fx_dur := 10.0
var _a60_entry_hit_cd := 0.0
var _ent_sync_accum := 0.0
var _net_a60_tgt := Vector3.ZERO
var _net_a120_tgt := Vector3.ZERO

var _darkness_phase := 0 # 0=idle, 1=whispering, 2=attacking
var _darkness_whisper_t := 0.0
var _darkness_dmg_accum := 0.0
var _darkness_quick_return := false

var _a90_phase := 0 # 0=idle, 1=appear, 2=freeze, 3=leave
var _a90_timer := 0.0
var _a90_freeze_dur := 2.6
var _a90_cooldown := 18.0
var _a90_grace := 0.0
var _a90_depth := 0.0
var _a90_start_pos := Vector3.ZERO
var _a90_start_yaw := 0.0
var _a90_start_pitch := 0.0
var _a90_scare_timer := 0.0
var _a90_hits := 0

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

# Main menu state
var _menu_view := "main"
var _settings_from_menu := false
var _death_hidden := false

# Door open micro-teleport (fast eased glide to the door)
var _door_tp_t := 1.0
var _door_tp_from := Vector3.ZERO
var _door_tp_to := Vector3.ZERO
var _door_tp_dur := 0.22

# Text chat / voice chat UI state
var _chat_open := false
var _chat_readonly := false

# Online Multiplayer (Steam Spacewar 480 + ENet)
var _net: RoomsNet = null
var _remote_players: Dictionary = {}
var _lobby_list_box: VBoxContainer = null
var _noob_scene: PackedScene = null
var _noob_parts: Dictionary = {}


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
	_net.chat_received.connect(func(who: String, text: String) -> void: call("_chat_append", who, text))
	_net.members_changed.connect(func() -> void: call("_update_menu_players_list"))


func _on_net_session_synced(seed_val: int, room_idx: int) -> void:
	if seed_val > 0 and _world_seed != seed_val and (_net == null or not _net.is_host):
		call("_reset_run", seed_val)
	if room_idx > _highest_opened:
		for idx in range(_highest_opened, room_idx):
			var r: RoomBuilder.RoomInstance = _room_by_idx.get(idx)
			if r != null and not r.door_opened:
				call("_open_room_door", idx, false, true)
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


func _is_locker_entry_anim() -> bool:
	# True only while the "climb into the locker" animation is still playing.
	return _is_hiding and _locker_transition_entering and _locker_transition_t < 1.0


func _update_warp_fx(delta: float) -> void:
	if _a120_warp_fx_t <= 0.0:
		return
	_a120_warp_fx_t = maxf(_a120_warp_fx_t - delta, 0.0)
	var rect := _ui.get("warp_rect") as Control
	if rect == null:
		return
	var p := clampf(_a120_warp_fx_t / maxf(_a120_warp_fx_dur, 0.01), 0.0, 1.0)
	var amt := pow(p, 1.75)
	var mat := _ui.get("warp_mat") as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("amt", amt)
	rect.visible = amt > 0.003


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
	if kind == "admin_grant":
		_admin_granted_by_host = true
		if _ui.has("btn_pause_admin"):
			(_ui["btn_pause_admin"] as Control).visible = true
		_show_toast("Хост предоставил вам доступ к панели администратора!", 3.0)
		return
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
	# --- A-90 (Stop Sign): authority spawns, every client freezes independently ---
	if kind == "a90_spawn":
		if _is_entity_authority() or _state != State.PLAYING or _is_hiding:
			return
		if _a90_phase != 0:
			return
		_a90_phase = 1
		_a90_timer = 0.55
		_a90_grace = 0.0
		_a90_depth = clampf(float(_highest_opened - 9) / 91.0, 0.0, 1.0)
		_a90_freeze_dur = clampf(float(msg.get("dur", 2.6)), 1.2, 6.0)
		var r90: Control = _ui["a90_root"]
		r90.visible = true
		r90.modulate.a = 0.0
		(_ui["a90_mat"] as ShaderMaterial).set_shader_parameter("red_amt", 0.0)
		(_ui["a90_mat"] as ShaderMaterial).set_shader_parameter("static_amt", 0.0)
		(_ui["a90_stop_icon"] as Control).visible = false
		(_ui["a90_stop"] as Control).visible = false
		(_ui["a90_hint"] as Control).visible = false
		(_ui["a90_bar_holder"] as Control).visible = false
		audio.play_a90_warn()
		return
	if kind == "a90_end":
		if _a90_phase != 0:
			call("_end_a90")
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
		call("_start_a60_local", door_idx, is_prime)
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
			call("_break_door_by_a60", b_idx, b_prime)
	elif kind == "a120_spawn":
		if _a120_hit_cd <= 0.0:
			var sp_r := int(msg.get("room", 0))
			var rb := int(msg.get("rb", 0))
			call("_start_a120_local", sp_r, rb)
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
			call("_open_room_door", idx, slam and (idx == room_index), true)
			if _net != null and _net.is_online() and _net.is_host and _highest_opened > before_high:
				call("_maybe_spawn_door_entities", _highest_opened)


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

		# Held tool models so other players can actually see what you are carrying
		var held := Node3D.new()
		held.name = "HeldTool"
		held.position = Vector3(0.0, -0.60, -0.10)
		arm_r.add_child(held)

		var held_flash := Node3D.new()
		held_flash.name = "HeldFlashlight"
		held.add_child(held_flash)
		var hf_body := RoomBuilder._add_cyl(held_flash, "StdBody", Vector3.ZERO, 0.024, 0.22, _assets.locker_mat)
		hf_body.rotation.x = PI * 0.5
		var hf_bezel := RoomBuilder._add_cyl(held_flash, "StdBezel", Vector3(0.0, 0.0, -0.12), 0.034, 0.055, _assets.metal_mat)
		hf_bezel.rotation.x = PI * 0.5
		var hf_lens := RoomBuilder._add_cyl(held_flash, "StdLens", Vector3(0.0, 0.0, -0.148), 0.028, 0.008, _vm_bulb_on_mat)
		hf_lens.rotation.x = PI * 0.5

		var held_gummy := Node3D.new()
		held_gummy.name = "HeldGummy"
		held_gummy.visible = false
		held.add_child(held_gummy)
		RoomBuilder._add_box(held_gummy, "GumBody", Vector3.ZERO, Vector3(0.068, 0.068, 0.19), _assets.gummy_mat, false)
		RoomBuilder._add_box(held_gummy, "GumGrip", Vector3(0.0, -0.015, 0.02), Vector3(0.072, 0.045, 0.11), _assets.locker_mat, false)
		var hg_head := RoomBuilder._add_cyl(held_gummy, "GumHead", Vector3(0.0, 0.0, -0.11), 0.040, 0.05, _assets.fridge_mat)
		hg_head.rotation.x = PI * 0.5
		var hg_lens := RoomBuilder._add_cyl(held_gummy, "GumLens", Vector3(0.0, 0.0, -0.136), 0.032, 0.008, _vm_gummy_on_mat)
		hg_lens.rotation.x = PI * 0.5
		_prep_avatar_meshes(held)

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
			"held_gummy": held_gummy,
			"held_flash": held_flash,
			"lbl": name_lbl,
			"tgt_pos": Vector3.ZERO,
			"tgt_yaw": 0.0,
			"tgt_pitch": 0.0,
			"light_on": false,
			"tool": 0,
			"gummy": false,
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
	var tool_i := int(msg.get("tool", 0))
	var has_gum := bool(msg.get("gum", false))
	rp["tool"] = tool_i
	rp["gummy"] = has_gum
	var show_gummy := has_gum and tool_i == 1
	var held_g := rp.get("held_gummy") as Node3D
	var held_f := rp.get("held_flash") as Node3D
	if held_g != null and is_instance_valid(held_g):
		held_g.visible = show_gummy
	if held_f != null and is_instance_valid(held_f):
		held_f.visible = not show_gummy
	var spot_node: SpotLight3D = rp["spot"]
	spot_node.visible = next_light and not bool(rp["dead"])
	spot_node.light_color = Color(0.44, 1.0, 0.58) if show_gummy else Color(1.0, 0.96, 0.88)
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

func _show_toast(msg: String, duration: float = 2.8) -> void:
	var lbl := _ui["toast_lbl"] as Label
	if not lbl.visible or lbl.text != msg:
		_toast_alpha = 0.0
		lbl.modulate.a = 0.0
	lbl.text = msg
	lbl.visible = true
	_toast_timer = maxf(duration, 1.1)
