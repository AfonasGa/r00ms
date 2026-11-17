class_name EntityDirector
extends Node

## Manages all active horror entities: A-60, A-60' (Prime), A-90 (Paralysis),
## A-120 (Happy Scribble), and The Darkness, including multiplayer host authority sync.

var game: Node3D = null
var world_parent: Node3D = null
var cam: Camera3D = null
var player_body: CharacterBody3D = null
var player_ctrl: PlayerController = null
var room_mgr: RoomManager = null
var avatar_mgr: AvatarManager = null
var ui_mgr: UIManager = null
var audio: RoomsAudio = null
var net: RoomsNet = null
var settings: SettingsManager = null
var rng: RandomNumberGenerator = null

# Textures
var a60_frames: Array[Texture2D] = []
var a90_textures: Dictionary = {}
var a120_frames: Array[Texture2D] = []
var a075_textures: Dictionary = {}
var darkness_tex: Texture2D = null

# A-60 & A-60' (Prime)
var a60_active := false
var a60_phase := 0 # 0=idle, 2=rush, 3=sink
var a60_is_prime := false
var a60_prime_pending_timer := 0.0
var a60_prime_chains_left := 0
var a60_prime_flicker_active := false
var a60_prime_flicker_gap_t := 0.0
var a60_prime_flicker_snd_cd := 0.0
var a60_prime_table_burned := false
var a60_prime_hit_cd := 0.0
var a60_node: Node3D = null
var a60_sprite: Sprite3D = null
var a60_light: OmniLight3D = null
var a60_hint_timer := 0.0
var a60_random_timer := 28.0
var a60_door20_trigger_timer := 0.0
var a60_sink_timer := 0.0
var a60_path: Array[Vector3] = []
var a60_path_idx := 0
var a60_target_door_idx := 0
var a60_anim_timer := 0.0
var a60_frame_idx := 0
var a60_last_tex: Texture2D = null
var _net_a60_tgt := Vector3.ZERO

# A-120 (Happy Scribble)
var a120_active := false
var a120_phase := 0 # 0=idle, 1=spawn_warning, 2=attack_rebound
var a120_substage := 0 # 0=rush_to_player, 1=retreat_prev, 2=despawn_retreat
var a120_node: Node3D = null
var a120_sprite: Sprite3D = null
var a120_warn_timer := 0.0
var a120_pause_timer := 0.0
var a120_path: Array[Vector3] = []
var a120_path_idx := 0
var a120_rebounds := 0
var a120_initial_rebounds := 0
var a120_drum_bounce := 0.0
var a120_anim_timer := 0.0
var a120_frame_idx := 0
var a120_hit_cd := 0.0
var a120_warp_fx_t := 0.0
var a120_warp_fx_dur := 10.0
var _net_a120_tgt := Vector3.ZERO
var _ent_sync_accum := 0.0

# The Darkness
var darkness_phase := 0 # 0=idle, 1=whispering, 2=attacking
var darkness_whisper_t := 0.0
var darkness_dmg_accum := 0.0
var darkness_quick_return := false

# A-90 (Paralysis)
var a90_phase := 0 # 0=idle, 1=appear, 2=freeze, 3=leave
var a90_timer := 0.0
var a90_freeze_dur := 1.08
var a90_cooldown := 18.0
var a90_grace := 0.0
var a90_start_pos := Vector3.ZERO
var a90_start_yaw := 0.0
var a90_start_pitch := 0.0
var a90_scare_timer := 0.0
var a90_hits := 0

# A-075 (Shutter / Затвор) — Light & Gaze Reactive Stalker
var a075_active := false
var a075_phase := 0 # 0=idle, 1=warning(closed), 2=scan(open), 3=flash_attack, 4=despawn
var a075_timer := 0.0
var a075_cooldown := 34.0
var a075_detect_accum := 0.0
var a075_flash_fx_t := 0.0
var a075_attack_step := 0
var a075_attack_origin := Vector3.ZERO
var a075_node: Node3D = null
var a075_sprite: Sprite3D = null
var a075_omni: OmniLight3D = null
var a075_spot: SpotLight3D = null
var a075_scan_phase := 0.0


func initialize(
	p_game: Node3D,
	p_world: Node3D,
	p_cam: Camera3D,
	p_body: CharacterBody3D,
	p_player_ctrl: PlayerController,
	p_room_mgr: RoomManager,
	p_avatar_mgr: AvatarManager,
	p_ui_mgr: UIManager,
	p_audio: RoomsAudio,
	p_net: RoomsNet,
	p_settings: SettingsManager,
	p_rng: RandomNumberGenerator
) -> void:
	game = p_game
	world_parent = p_world
	cam = p_cam
	player_body = p_body
	player_ctrl = p_player_ctrl
	room_mgr = p_room_mgr
	avatar_mgr = p_avatar_mgr
	ui_mgr = p_ui_mgr
	audio = p_audio
	net = p_net
	settings = p_settings
	rng = p_rng
	_load_sprites()
	_build_world_nodes()


func _try_load_tex(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null


func _load_sprites() -> void:
	a60_frames.clear()
	for i in range(1, 26):
		var tex := _try_load_tex("res://assets/sprites/a60/a60_%d.png" % i)
		if tex != null:
			a60_frames.append(tex)
	if a60_frames.is_empty():
		for ft in RoomsTextures.make_a60_frames():
			a60_frames.append(ft)

	a120_frames.clear()
	for fname in ["a120smiley.png", "a120smiley1.png"]:
		var tex := _try_load_tex("res://assets/sprites/a120/%s" % fname)
		if tex != null:
			a120_frames.append(tex)
	if a120_frames.is_empty():
		for ft in RoomsTextures.make_a120_frames():
			a120_frames.append(ft)

	a90_textures = RoomsTextures.make_a90_textures()
	var spawn_tex := _try_load_tex("res://assets/sprites/paralysis/paralysis_spawn.webp")
	var pre_tex := _try_load_tex("res://assets/sprites/paralysis/paralysis-prejumpscareORdespawn.webp")
	var scare_tex := _try_load_tex("res://assets/sprites/paralysis/paralysis-jumpscare.webp")
	var stop_tex := _try_load_tex("res://assets/sprites/paralysis/stopsign.webp")
	if spawn_tex != null:
		a90_textures["warn"] = spawn_tex
	if pre_tex != null:
		a90_textures["pre"] = pre_tex
	if scare_tex != null:
		a90_textures["rage"] = scare_tex
	if stop_tex != null:
		a90_textures["stopsign"] = stop_tex
	darkness_tex = _try_load_tex("res://assets/sprites/darkness/darkness_eye.webp")
	a075_textures["closed"] = _try_load_tex("res://assets/sprites/a075/a075_closed.png")
	a075_textures["scan"] = _try_load_tex("res://assets/sprites/a075/a075_scan.png")
	a075_textures["attack"] = _try_load_tex("res://assets/sprites/a075/a075_attack.png")


func _build_world_nodes() -> void:
	a60_node = Node3D.new()
	a60_node.name = "Entity_A60"
	a60_node.visible = false
	world_parent.add_child(a60_node)

	a60_sprite = Sprite3D.new()
	a60_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a60_sprite.shaded = false
	a60_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	a60_sprite.texture = a60_frames[0]
	a60_sprite.pixel_size = 2.65 / float(maxi(a60_frames[0].get_width(), 1))
	a60_sprite.modulate = Color(1.0, 0.94, 0.94)
	a60_node.add_child(a60_sprite)

	a60_light = OmniLight3D.new()
	a60_light.light_color = Color(1.0, 0.14, 0.12)
	a60_light.light_energy = 4.8
	a60_light.omni_range = 15.0
	a60_light.shadow_enabled = false
	a60_node.add_child(a60_light)

	a120_node = Node3D.new()
	a120_node.name = "Entity_A120"
	a120_node.visible = false
	world_parent.add_child(a120_node)

	a120_sprite = Sprite3D.new()
	a120_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a120_sprite.shaded = false
	a120_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	a120_sprite.texture = a120_frames[0]
	a120_sprite.pixel_size = 2.55 / float(maxi(a120_frames[0].get_width(), 1))
	a120_node.add_child(a120_sprite)

	var a120_light := OmniLight3D.new()
	a120_light.light_color = Color(0.65, 0.90, 1.0)
	a120_light.light_energy = 3.2
	a120_light.omni_range = 11.0
	a120_light.shadow_enabled = false
	a120_node.add_child(a120_light)

	# A-075 (Shutter / Затвор) world node
	a075_node = Node3D.new()
	a075_node.name = "Entity_A075"
	a075_node.visible = false
	world_parent.add_child(a075_node)

	a075_sprite = Sprite3D.new()
	a075_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a075_sprite.shaded = false
	a075_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var closed_t: Texture2D = a075_textures.get("closed") as Texture2D
	if closed_t != null:
		a075_sprite.texture = closed_t
		a075_sprite.pixel_size = 2.45 / float(maxi(closed_t.get_width(), 1))
	a075_node.add_child(a075_sprite)

	a075_omni = OmniLight3D.new()
	a075_omni.light_color = Color(1.0, 0.72, 0.25)
	a075_omni.light_energy = 2.2
	a075_omni.omni_range = 12.0
	a075_omni.shadow_enabled = false
	a075_node.add_child(a075_omni)

	a075_spot = SpotLight3D.new()
	a075_spot.light_color = Color(1.0, 0.78, 0.34)
	a075_spot.light_energy = 5.5
	a075_spot.spot_range = 24.0
	a075_spot.spot_angle = 26.0
	a075_spot.shadow_enabled = false
	a075_spot.visible = false
	a075_node.add_child(a075_spot)


func is_authority() -> bool:
	return net == null or not net.is_online() or net.is_host


func reset_for_run() -> void:
	a60_door20_trigger_timer = 0.0
	a60_active = false
	a60_phase = 0
	a60_is_prime = false
	a60_prime_pending_timer = 0.0
	a60_prime_chains_left = 0
	a60_prime_flicker_active = false
	a60_prime_flicker_gap_t = 0.0
	a60_prime_flicker_snd_cd = 0.0
	a60_prime_table_burned = false
	a60_prime_hit_cd = 0.0
	a60_hint_timer = 0.0
	a60_random_timer = rng.randf_range(22.0, 36.0)
	if is_instance_valid(a60_node):
		a60_node.visible = false
	audio.stop_a60()

	a120_active = false
	a120_phase = 0
	a120_substage = 0
	a120_drum_bounce = 0.0
	a120_anim_timer = 0.0
	a120_hit_cd = 0.0
	a120_warp_fx_t = 0.0
	_ent_sync_accum = 0.0
	if is_instance_valid(a120_sprite):
		a120_sprite.position = Vector3.ZERO
		a120_sprite.scale = Vector3.ONE
	if is_instance_valid(a120_node):
		a120_node.visible = false
	audio.stop_a120()

	reset_darkness_state()

	a90_phase = 0
	a90_timer = 0.0
	a90_grace = 0.0
	a90_cooldown = 18.0
	a90_scare_timer = 0.0
	a90_hits = 0
	audio.a60_intensity = 0.0
	_reset_a075_state()


func _reset_a075_state() -> void:
	a075_active = false
	a075_phase = 0
	a075_timer = 0.0
	a075_cooldown = rng.randf_range(30.0, 52.0) if rng != null else 34.0
	a075_detect_accum = 0.0
	a075_flash_fx_t = 0.0
	a075_attack_step = 0
	a075_scan_phase = 0.0
	if is_instance_valid(a075_node):
		a075_node.visible = false
	if is_instance_valid(a075_spot):
		a075_spot.visible = false
	audio.stop_a075_scan()
	var fl := ui_mgr.get_node_ref("a075_flash_rect")
	if fl != null:
		fl.visible = false


func despawn_all(broadcast: bool = true) -> void:
	a60_active = false
	a60_phase = 0
	a60_prime_flicker_active = false
	a60_prime_pending_timer = 0.0
	a60_prime_chains_left = 0
	if is_instance_valid(a60_node):
		a60_node.visible = false
	audio.stop_a60()

	a120_active = false
	a120_phase = 0
	a120_substage = 0
	if is_instance_valid(a120_node):
		a120_node.visible = false
	audio.stop_a120()

	end_a90()
	_reset_a075_state()
	if broadcast and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a60_end"}, true)
		net.broadcast_entity_event({"k": "a120_end"}, true)
		net.broadcast_entity_event({"k": "a90_end"}, true)
		net.broadcast_entity_event({"k": "a075_end"}, true)


func on_local_death(keep_auth_ent: bool) -> void:
	audio.stop_a120()
	audio.stop_a60()
	audio.stop_darkness()
	darkness_phase = 0
	darkness_whisper_t = 0.0
	audio.a60_intensity = 0.0
	if not keep_auth_ent:
		a60_active = false
		a60_phase = 0
		a60_prime_pending_timer = 0.0
		a60_prime_chains_left = 0
		a120_active = false
		a120_phase = 0
		a120_substage = 0
	a60_prime_flicker_active = false
	if is_instance_valid(a60_node):
		a60_node.visible = false
	if is_instance_valid(a120_node):
		a120_node.visible = false
	if is_instance_valid(a075_node):
		a075_node.visible = false
	a075_active = false
	a075_phase = 0
	audio.stop_a075_scan()
	a90_phase = 0


func reset_darkness_state() -> void:
	darkness_phase = 0
	darkness_whisper_t = 0.0
	darkness_dmg_accum = 0.0
	darkness_quick_return = false
	audio.stop_darkness()
	var dk := ui_mgr.get_node_ref("darkness_rect")
	if dk != null:
		dk.visible = false


func repel_darkness_with_flashlight() -> void:
	darkness_phase = 0
	darkness_whisper_t = 0.0
	darkness_dmg_accum = 0.0
	darkness_quick_return = true
	audio.stop_darkness()
	var dk := ui_mgr.get_node_ref("darkness_rect")
	if dk != null:
		dk.visible = false


func maybe_spawn_door_entities(room_num: int) -> void:
	if not is_authority() or a60_active or a120_active:
		return
	if room_num == 120:
		spawn_a120()
	elif room_num > 120:
		var chance_120 := clampf(0.07 + float(room_num - 120) * 0.0006, 0.07, 0.14)
		if rng.randf() < chance_120:
			spawn_a120()


func process_spawners(delta: float, active_modifiers: Dictionary) -> void:
	if not is_authority():
		return
	var bad_time := bool(active_modifiers.get("bad_time", false))
	var cd_mult := 1.9 if bad_time else 1.0

	if room_mgr.highest_opened == 19 and not a60_active and not a120_active:
		if a60_door20_trigger_timer > 0.0:
			a60_door20_trigger_timer -= delta
			if a60_door20_trigger_timer <= 0.0:
				ui_mgr.show_toast("Дверь A-020 заблокирована! Сзади нарастает свирепый рёв A-60... Прячьтесь в шкаф!", 4.0)
				spawn_a60(false)
	elif a60_prime_pending_timer > 0.0 and not a60_active and not a120_active:
		a60_prime_pending_timer -= delta
		if a60_prime_pending_timer <= 0.0 and room_mgr.highest_opened >= 20:
			spawn_a60(true)
	elif room_mgr.highest_opened >= 20 and not a60_active and not a120_active and not a60_prime_flicker_active:
		a60_random_timer -= delta * cd_mult
		if a60_random_timer <= 0.0:
			var max_cd := maxf(24.0, 52.0 - float(room_mgr.highest_opened) * 0.12)
			var min_cd := maxf(14.0, max_cd * 0.52)
			if bad_time:
				max_cd *= 0.55
				min_cd *= 0.55
			a60_random_timer = rng.randf_range(min_cd, max_cd)
			spawn_a60(false)


func spawn_a60(force_prime: bool = false) -> void:
	if room_mgr.rooms.is_empty():
		return
	var target_r := room_mgr.find_first_closed_door_room()
	if target_r == null:
		return
	start_a60_local(target_r.index, force_prime)
	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a60_spawn", "door": target_r.index, "prime": force_prime}, true)


func start_a60_local(target_door_idx: int, is_prime: bool) -> void:
	a60_path.clear()
	if room_mgr.rooms.is_empty():
		return
	var target_r: RoomScene = room_mgr.room_by_idx.get(target_door_idx) as RoomScene
	if target_r == null:
		target_r = room_mgr.find_first_closed_door_room()
	if target_r == null:
		target_r = room_mgr.rooms[-1]
	a60_target_door_idx = target_r.index
	var start_room_idx := maxi(0, a60_target_door_idx - 3) if is_prime else 0
	var start_r: RoomScene = room_mgr.rooms[0]
	for r in room_mgr.rooms:
		if r.index == start_room_idx:
			start_r = r
			break
	a60_path.append(start_r.center_pos - start_r.in_dir * (20.0 if is_prime else 260.0) + Vector3(0.0, 1.55, 0.0))
	for r in room_mgr.rooms:
		if r.index >= start_room_idx and r.index <= a60_target_door_idx:
			a60_path.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
			if r.index < a60_target_door_idx:
				a60_path.append(r.exit_pos + Vector3(0.0, 1.55, 0.0))
	a60_path.append(target_r.exit_pos + Vector3(0.0, 1.55, 0.0))
	if a60_path.size() < 2:
		return

	a60_active = true
	a60_phase = 2
	a60_is_prime = is_prime
	a60_prime_table_burned = false
	a60_prime_hit_cd = 0.0
	a60_hint_timer = (2.4 if room_mgr.highest_opened < 100 else 0.0) if not is_prime else 0.0
	if is_prime:
		a60_prime_flicker_active = true
		a60_prime_flicker_gap_t = 0.0
		a60_light.light_color = Color(0.22, 0.84, 1.0)
		a60_sprite.modulate = Color(0.55, 0.96, 1.0)
	else:
		a60_light.light_color = Color(1.0, 0.14, 0.12)
		a60_sprite.modulate = Color(1.0, 0.94, 0.94)

	a60_path_idx = 1
	a60_node.position = a60_path[0]
	a60_node.visible = true
	room_mgr.flicker_nearby_lights(1.4)
	audio.start_a60_spawn(is_prime, room_mgr.highest_opened < 100)


func spawn_a120() -> void:
	if room_mgr.rooms.is_empty():
		return
	var spawn_idx := mini(room_mgr.highest_opened + 3, room_mgr.rooms[-1].index)
	var roll := rng.randf()
	var rb := 0
	if roll < 0.22:
		rb = 0
	elif roll < 0.52:
		rb = 1
	elif roll < 0.80:
		rb = 2
	else:
		rb = 3
	start_a120_local(spawn_idx, rb)
	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a120_spawn", "room": spawn_idx, "rb": rb}, true)


func start_a120_local(spawn_idx: int, rb: int) -> void:
	if room_mgr.rooms.is_empty():
		return
	var spawn_r: RoomScene = room_mgr.room_by_idx.get(spawn_idx) as RoomScene
	if spawn_r == null:
		spawn_r = room_mgr.rooms[-1]
	a120_active = true
	a120_phase = 1
	a120_substage = 0
	a120_warn_timer = 3.4
	a120_pause_timer = 0.0
	a120_rebounds = rb
	a120_initial_rebounds = rb
	a120_drum_bounce = 0.0
	a120_anim_timer = 0.0
	a120_hit_cd = 0.0
	a120_path.clear()
	a120_path_idx = 0
	a120_sprite.position = Vector3.ZERO
	a120_sprite.scale = Vector3.ONE
	a120_node.position = spawn_r.center_pos + Vector3(0.0, 1.55, 0.0)
	_net_a120_tgt = a120_node.position
	a120_node.visible = true
	a120_sprite.modulate = Color(1.0, 1.0, 1.0)
	room_mgr.flicker_nearby_lights(1.6)
	audio.start_a120_spawn()


func _build_a120_corridor_path(from_room_idx: int, to_room_idx: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var step := 1 if to_room_idx >= from_room_idx else -1
	var cur := from_room_idx
	while true:
		var r: RoomScene = room_mgr.room_by_idx.get(cur) as RoomScene
		if r != null:
			pts.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
		if cur == to_room_idx:
			break
		cur += step
	return pts


func _get_a120_live_target() -> Vector3:
	var best_pos := (player_ctrl.locker_eye + player_ctrl.locker_fwd * 0.95) if player_ctrl.is_hiding else player_body.global_position
	var best_exposed := not player_ctrl.is_hiding
	var best_d := a120_node.global_position.distance_squared_to(best_pos)
	for pk in avatar_mgr.remote_players.keys():
		var rp: Dictionary = avatar_mgr.remote_players[pk]
		if bool(rp.get("dead", false)):
			continue
		var r_exp := not bool(rp.get("hiding", false))
		var rp_pos: Vector3 = rp.get("tgt_pos", Vector3.ZERO)
		var d := a120_node.global_position.distance_squared_to(rp_pos)
		if (r_exp and not best_exposed) or (r_exp == best_exposed and d < best_d):
			best_exposed = r_exp
			best_pos = rp_pos
			best_d = d
	return Vector3(best_pos.x, 1.55, best_pos.z)


func process_darkness_in_hiding(delta: float) -> void:
	var dk_rect := ui_mgr.get_node_ref("darkness_rect") as TextureRect
	if room_mgr.highest_opened < 21:
		if dk_rect != null:
			dk_rect.visible = false
		if not a60_active and not a120_active:
			player_ctrl.hide_time += delta
			if player_ctrl.hide_time > 24.0:
				ui_mgr.show_toast("Пора выходить из укрытия!", 1.2)
		return

	player_ctrl.hide_time += delta
	var prog := clampf(float(room_mgr.highest_opened - 21) / 600.0, 0.0, 1.0)
	var base_delay := lerpf(24.0, 4.5, prog)
	var disturb_delay := maxf(3.0, base_delay * 0.72) if room_mgr.power_out else base_delay
	if darkness_quick_return:
		disturb_delay = 4.5 if (player_ctrl.light_on and player_ctrl.active_tool == 0) else 2.0

	if darkness_phase == 0:
		if dk_rect != null:
			dk_rect.visible = false
		audio.stop_darkness()
		if player_ctrl.hide_time >= disturb_delay:
			darkness_phase = 1
			darkness_whisper_t = 0.0
			darkness_dmg_accum = 0.0
			audio.start_darkness()
			if dk_rect != null:
				dk_rect.visible = true
				dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.05)
	elif darkness_phase == 1:
		var ramp_dur := lerpf(5.5, 2.2, prog) * (0.82 if room_mgr.power_out else 1.0)
		darkness_whisper_t = minf(darkness_whisper_t + delta / ramp_dur, 1.0)
		audio.update_darkness(darkness_whisper_t)
		if dk_rect != null:
			dk_rect.visible = true
			var s := lerpf(0.82, 1.08, darkness_whisper_t)
			dk_rect.scale = Vector2(s, s)
			dk_rect.pivot_offset = dk_rect.size * 0.5
			dk_rect.modulate = Color(1.0, 1.0, 1.0, pow(darkness_whisper_t, 1.15) * 0.94)
		if darkness_whisper_t >= 1.0:
			darkness_phase = 2
			darkness_dmg_accum = 0.45
	elif darkness_phase == 2:
		audio.update_darkness(1.0)
		if dk_rect != null:
			dk_rect.visible = true
			var pulse_s := 1.06 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.014)
			dk_rect.scale = Vector2(pulse_s, pulse_s)
			dk_rect.pivot_offset = dk_rect.size * 0.5
			dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.98)
		player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.030)
		darkness_dmg_accum += delta
		if darkness_dmg_accum >= 0.65:
			darkness_dmg_accum -= 0.65
			game.call("damage_player", 12, "The Darkness", Color(0.88, 0.04, 0.04, 0.56), {})


func update_warp_fx(delta: float) -> void:
	if a120_warp_fx_t <= 0.0:
		return
	a120_warp_fx_t = maxf(a120_warp_fx_t - delta, 0.0)
	var rect := ui_mgr.get_node_ref("warp_rect")
	if rect == null:
		return
	var p := clampf(a120_warp_fx_t / maxf(a120_warp_fx_dur, 0.01), 0.0, 1.0)
	var amt := pow(p, 1.75)
	var mat := ui_mgr.ui.get("warp_mat") as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("amt", amt)
	rect.visible = amt > 0.003


func process_entities(delta: float, is_playing: bool, is_dead: bool) -> void:
	var static_rect := ui_mgr.get_node_ref("static_rect") as ColorRect
	var static_mat := ui_mgr.ui.get("static_mat") as ShaderMaterial
	var a60_scare_rect := ui_mgr.get_node_ref("a60_scare_rect") as TextureRect
	var is_auth := is_authority()

	if a60_prime_hit_cd > 0.0:
		a60_prime_hit_cd = maxf(a60_prime_hit_cd - delta, 0.0)

	var send_ent_sync := false
	if is_auth and (a60_active or a120_active):
		_ent_sync_accum += delta
		if _ent_sync_accum >= 0.08:
			_ent_sync_accum = 0.0
			send_ent_sync = true

	if a60_active:
		a60_node.visible = not is_dead
		a60_anim_timer += delta
		var flip_interval := 0.035 if a60_is_prime else 0.045
		if a60_anim_timer > flip_interval:
			a60_anim_timer = 0.0
			a60_frame_idx = (a60_frame_idx + rng.randi_range(1, 5)) % maxi(a60_frames.size(), 1)
			var f60 := a60_frames[a60_frame_idx]
			a60_last_tex = f60
			a60_sprite.texture = f60
			a60_sprite.pixel_size = 2.65 / float(maxi(f60.get_width(), 1))

		var d_player := a60_node.global_position.distance_to(cam.global_position)
		if not is_dead:
			audio.a60_intensity = 0.0 if a60_is_prime else clampf(16.0 / maxf(d_player, 2.0), 0.12, 1.0)
			audio.update_a60_mix(delta, d_player, a60_phase, a60_is_prime)

		var prime_col := Vector3(0.25, 0.85, 1.0) if a60_is_prime else Vector3(1.0, 0.22, 0.18)
		static_mat.set_shader_parameter("tint_col", prime_col)

		if a60_hint_timer > 0.0:
			a60_hint_timer = maxf(a60_hint_timer - delta, 0.0)

		if a60_phase == 2:
			if is_playing:
				var near_prox := clampf(1.0 - (d_player - 2.0) / 22.0, 0.0, 1.0)
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, near_prox * (0.045 if a60_is_prime else 0.11))
				var hint_static := 0.0
				if not a60_is_prime and a60_hint_timer > 0.0 and room_mgr.highest_opened < 100:
					var fade := clampf(a60_hint_timer / 0.85, 0.0, 1.0)
					hint_static = fade * (0.55 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.015))
				var total_static := maxf(hint_static, near_prox * (0.35 if a60_is_prime else 0.65))
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
				var live_closed_r: RoomScene = room_mgr.room_by_idx.get(a60_target_door_idx) as RoomScene
				if live_closed_r != null and (live_closed_r.door_opened or live_closed_r.door_broken):
					var next_closed := room_mgr.find_first_closed_door_room()
					if next_closed != null and next_closed.index > a60_target_door_idx:
						var old_idx := a60_target_door_idx
						a60_target_door_idx = next_closed.index
						for r in room_mgr.rooms:
							if r.index > old_idx and r.index <= a60_target_door_idx:
								a60_path.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
								if r.index < a60_target_door_idx:
									a60_path.append(r.exit_pos + Vector3(0.0, 1.55, 0.0))
						a60_path.append(next_closed.exit_pos + Vector3(0.0, 1.55, 0.0))

				var rush_speed := 140.0 if a60_is_prime else 60.0
				if a60_path_idx < a60_path.size():
					var tgt := a60_path[a60_path_idx]
					var to_t := tgt - a60_node.position
					if to_t.length() <= rush_speed * delta:
						a60_node.position = tgt
						a60_path_idx += 1
					else:
						a60_node.position += to_t.normalized() * rush_speed * delta
				else:
					var smash_r: RoomScene = room_mgr.room_by_idx.get(a60_target_door_idx) as RoomScene
					if smash_r != null and not smash_r.door_opened and not smash_r.door_broken:
						var tex := a60_last_tex if a60_last_tex != null else a60_frames[0]
						room_mgr.break_door_by_a60(a60_target_door_idx, a60_is_prime, tex, rng, audio)
						player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.09)
						game.call("advance_door_progress", a60_target_door_idx, false)
						if net != null and net.is_online():
							net.broadcast_entity_event({"k": "a60_brk", "door": a60_target_door_idx, "prime": a60_is_prime}, true)
					a60_phase = 3
					a60_sink_timer = 0.42
					a60_scare_rect.visible = false
					if net != null and net.is_online():
						net.broadcast_entity_event({"k": "a60_end"}, true)

				if send_ent_sync and net != null and net.is_online():
					var p60 := a60_node.position
					net.broadcast_entity_event({
						"k": "a60_pos",
						"p": [p60.x, p60.y, p60.z],
						"ph": a60_phase,
						"door": a60_target_door_idx,
						"prime": a60_is_prime,
					}, false)
			else:
				var rush_speed_c := 140.0 if a60_is_prime else 60.0
				a60_node.position = a60_node.position.move_toward(_net_a60_tgt, rush_speed_c * delta * 1.25)

			if is_playing and a60_phase == 2 and a60_is_prime and player_ctrl.is_hiding and player_ctrl.hiding_kind == "under_desk" and d_player <= 11.5 and not a60_prime_table_burned:
				a60_prime_table_burned = true
				if rng.randf() < 0.90:
					player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.06)
					ui_mgr.show_toast("Ожог от A-60' под столом (-20 HP!)", 2.2)
					game.call("damage_player", 20, "A-60'", Color(0.95, 0.32, 0.14, 0.62), {"distance": d_player, "table_burn": true})
					return

			if is_playing and a60_phase == 2 and d_player <= 11.5 and not player_ctrl.is_hiding:
				var space := player_body.get_world_3d().direct_space_state
				var q := PhysicsRayQueryParameters3D.create(a60_node.global_position, cam.global_position)
				q.exclude = [player_body.get_rid()]
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					if a60_is_prime:
						if a60_prime_hit_cd <= 0.0:
							a60_prime_hit_cd = 1.2
							player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.08)
							ui_mgr.show_toast("A-60' (Prime) нанёс 35 урона!", 2.4)
							game.call("damage_player", 35, "A-60'", Color(0.35, 0.90, 1.0, 0.65), {"distance": d_player})
							return
					else:
						a60_scare_rect.visible = true
						a60_scare_rect.texture = a60_sprite.texture
						a60_scare_rect.modulate = Color(1.0, 0.92, 0.92, 0.96)
						var vp := get_viewport().get_visible_rect().size
						a60_scare_rect.position = vp * 0.5 - Vector2(270, 270)
						audio.play_a60_jumpscare(false)
						game.call("damage_player", 999, "A-60", Color(0.92, 0.08, 0.08, 0.78), {"distance": d_player})
						return
				else:
					a60_scare_rect.visible = false
			else:
				a60_scare_rect.visible = false
		elif a60_phase == 3:
			a60_scare_rect.visible = false
			static_rect.visible = false
			a60_sink_timer -= delta
			var sink_p := 1.0 - clampf(a60_sink_timer / 0.42, 0.0, 1.0)
			a60_node.position.y = lerpf(1.55, -1.85, ease(sink_p, 2.0))
			a60_sprite.modulate.a = 1.0 - sink_p
			if a60_sink_timer <= 0.0:
				var was_prime := a60_is_prime
				a60_active = false
				a60_phase = 0
				a60_node.visible = false
				a60_sprite.modulate.a = 1.0
				audio.stop_a60()

				if is_auth:
					if not was_prime and room_mgr.highest_opened >= 50:
						var p_prog := clampf(float(room_mgr.highest_opened - 50) / 850.0, 0.0, 1.0)
						if rng.randf() < lerpf(0.45, 0.90, p_prog):
							var max_chains := mini(1 + int(floor(p_prog * 3.0)), 4)
							var chains := 1
							for _c in range(max_chains - 1):
								if rng.randf() < lerpf(0.25, 0.72, p_prog):
									chains += 1
							a60_prime_pending_timer = 1.8
							a60_prime_chains_left = chains - 1
							a60_prime_flicker_active = true
							a60_prime_flicker_gap_t = 0.0
							if net != null and net.is_online():
								net.broadcast_entity_event({"k": "a60p_warn", "gap": 0.0}, true)
					elif was_prime:
						if a60_prime_chains_left > 0:
							a60_prime_chains_left -= 1
							a60_prime_flicker_active = true
							a60_prime_flicker_gap_t = 0.35
							a60_prime_pending_timer = 1.8
							if net != null and net.is_online():
								net.broadcast_entity_event({"k": "a60p_warn", "gap": 0.5}, true)
						else:
							a60_prime_flicker_active = false
							if net != null and net.is_online():
								net.broadcast_entity_event({"k": "a60p_end"}, true)
	else:
		audio.a60_intensity = lerpf(audio.a60_intensity, 0.0, minf(delta * 4.0, 1.0))
		if static_rect != null and static_rect.visible:
			static_rect.visible = false
		if a60_scare_rect != null and a60_scare_rect.visible:
			a60_scare_rect.visible = false
		if a60_node.visible:
			a60_node.visible = false

	# --- A-120 (Happy Scribble) ---
	if a120_hit_cd > 0.0:
		a120_hit_cd = maxf(a120_hit_cd - delta, 0.0)

	if a120_active:
		a120_node.visible = not is_dead
		var d120 := a120_node.global_position.distance_to(cam.global_position)
		var drum_hit := audio.update_a120_mix(delta, d120, a120_phase) if not is_dead else false
		a120_anim_timer += delta
		if a120_anim_timer >= 0.50:
			a120_anim_timer -= 0.50
			a120_frame_idx = (a120_frame_idx + 1) % maxi(a120_frames.size(), 1)
			var f120 := a120_frames[a120_frame_idx] if not a120_frames.is_empty() else null
			if f120 != null:
				a120_sprite.texture = f120
				a120_sprite.pixel_size = 2.55 / float(maxi(f120.get_width(), 1))
		if drum_hit:
			a120_drum_bounce = 1.0
		if a120_drum_bounce > 0.0:
			a120_drum_bounce = maxf(a120_drum_bounce - delta * 4.4, 0.0)
			var b := a120_drum_bounce
			a120_sprite.position.y = sin(b * PI) * 0.34
			a120_sprite.scale = Vector3(1.0 + sin(b * PI) * 0.16, 1.0 - sin(b * PI) * 0.10 + (1.0 - cos(b * PI)) * 0.06, 1.0)
		else:
			a120_sprite.position.y = 0.0
			a120_sprite.scale = Vector3.ONE

		if not is_auth:
			a120_node.position = a120_node.position.lerp(_net_a120_tgt, clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0))
		elif a120_phase == 1:
			a120_warn_timer -= delta
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.012)
			if a120_warn_timer <= 0.0:
				a120_phase = 2
				a120_substage = 0
				a120_path = _build_a120_corridor_path(room_mgr.get_room_idx_near(a120_node.position), room_mgr.current_room_idx)
				a120_path_idx = 0
		elif a120_phase == 2:
			if a120_pause_timer > 0.0:
				a120_pause_timer -= delta
			else:
				var spd120 := 15.0
				if a120_substage == 0:
					var live_tgt := _get_a120_live_target()
					var tgt_room := room_mgr.get_room_idx_near(live_tgt)
					var move_tgt := live_tgt
					if a120_path_idx < a120_path.size() and room_mgr.get_room_idx_near(a120_node.position) != tgt_room:
						move_tgt = a120_path[a120_path_idx]
					var to_m := move_tgt - a120_node.position
					if to_m.length() <= spd120 * delta:
						a120_node.position = move_tgt
						if move_tgt.distance_to(live_tgt) < 1.25:
							var min_room := room_mgr.rooms[0].index if not room_mgr.rooms.is_empty() else 0
							var prev_idx := maxi(min_room, tgt_room - rng.randi_range(2, 4))
							if prev_idx == tgt_room and min_room < tgt_room:
								prev_idx = tgt_room - 1
							a120_substage = 1
							a120_path = _build_a120_corridor_path(tgt_room, prev_idx)
							if prev_idx == tgt_room and room_mgr.room_by_idx.has(tgt_room):
								var cr: RoomScene = room_mgr.room_by_idx[tgt_room] as RoomScene
								a120_path = [cr.center_pos - cr.in_dir * 4.5 + Vector3(0.0, 1.55, 0.0)]
							a120_path_idx = 0
						else:
							a120_path_idx += 1
					else:
						a120_node.position += to_m.normalized() * spd120 * delta
				elif a120_substage == 1:
					if a120_path_idx < a120_path.size():
						var tgt := a120_path[a120_path_idx]
						var to_t := tgt - a120_node.position
						if to_t.length() <= spd120 * delta:
							a120_node.position = tgt
							a120_path_idx += 1
						else:
							a120_node.position += to_t.normalized() * spd120 * delta
					else:
						if a120_rebounds > 0:
							a120_rebounds -= 1
							a120_pause_timer = 0.38
							a120_substage = 0
							var tgt_room2 := room_mgr.get_room_idx_near(_get_a120_live_target())
							a120_path = _build_a120_corridor_path(room_mgr.get_room_idx_near(a120_node.position), tgt_room2)
							a120_path_idx = 0
						else:
							a120_substage = 2
							var min_idx := room_mgr.rooms[0].index if not room_mgr.rooms.is_empty() else 0
							a120_path = _build_a120_corridor_path(room_mgr.get_room_idx_near(a120_node.position), min_idx)
							if not room_mgr.rooms.is_empty():
								var first_r := room_mgr.rooms[0]
								a120_path.append(first_r.center_pos - first_r.in_dir * 185.0 + Vector3(0.0, 1.55, 0.0))
							a120_path_idx = 0
				elif a120_substage == 2:
					if a120_path_idx < a120_path.size():
						var tgt := a120_path[a120_path_idx]
						var to_t := tgt - a120_node.position
						if to_t.length() <= spd120 * delta:
							a120_node.position = tgt
							a120_path_idx += 1
						else:
							a120_node.position += to_t.normalized() * spd120 * delta
					if d120 >= 165.0 or a120_path_idx >= a120_path.size():
						a120_active = false
						a120_phase = 0
						a120_substage = 0
						a120_node.visible = false
						audio.stop_a120()
						if net != null and net.is_online():
							net.broadcast_entity_event({"k": "a120_end"}, true)

		if is_auth and send_ent_sync and a120_active and net != null and net.is_online():
			var p120 := a120_node.position
			net.broadcast_entity_event({
				"k": "a120_pos",
				"p": [p120.x, p120.y, p120.z],
				"ph": a120_phase,
				"ss": a120_substage,
				"room": room_mgr.current_room_idx,
			}, false)

		if is_playing and a120_active and a120_phase == 2 and a120_node.global_position.distance_to(cam.global_position) < 2.15 and not player_ctrl.is_hiding and a120_hit_cd <= 0.0:
			_handle_a120_hit()
			return
	elif a120_node.visible:
		a120_node.visible = false


func _handle_a120_hit() -> void:
	if player_ctrl.is_hiding:
		return
	a120_hit_cd = 1.5
	a120_active = false
	a120_phase = 0
	a120_substage = 0
	a120_node.visible = false
	audio.stop_a120()
	audio.play_a120_scream()
	if net != null and net.is_online():
		net.broadcast_entity_event({"k": "a120_end", "from_client": not is_authority()}, true)

	player_ctrl.shake_amount = 0.12
	var rebounded := a120_rebounds < a120_initial_rebounds
	var survived: bool = bool(game.call("handle_a120_damage_and_warp", rebounded))
	if survived:
		a120_warp_fx_t = a120_warp_fx_dur
		update_warp_fx(0.0)


func process_a90(delta: float, active_modifiers: Dictionary) -> void:
	var scare_rect := ui_mgr.get_node_ref("a90_scare_rect") as TextureRect
	if a90_scare_timer > 0.0:
		a90_scare_timer = maxf(a90_scare_timer - delta, 0.0)
		if scare_rect != null:
			scare_rect.modulate.a = clampf(a90_scare_timer / 0.40, 0.0, 1.0)
			if a90_scare_timer <= 0.0:
				scare_rect.visible = false

	var a90_root := ui_mgr.get_node_ref("a90_root")
	var a90_mat := ui_mgr.ui.get("a90_mat") as ShaderMaterial
	var a90_rect := ui_mgr.get_node_ref("a90_rect") as TextureRect
	var a90_stop_icon := ui_mgr.get_node_ref("a90_stop_icon") as TextureRect
	var a90_shake := ui_mgr.get_node_ref("a90_shake")

	if a90_phase == 0:
		if a90_root != null and a90_root.visible:
			a90_root.visible = false
		if not is_authority():
			return
		if room_mgr.highest_opened < 90 or player_ctrl.is_hiding or a60_active or a120_active or room_mgr.power_out:
			return
		var bad_time := bool(active_modifiers.get("bad_time", false))
		a90_cooldown -= delta * (1.75 if bad_time else 1.0)
		if a90_cooldown > 0.0:
			return
		a90_cooldown = rng.randf_range(18.0 if bad_time else 35.0, 38.0 if bad_time else 70.0)
		if rng.randf() > (0.85 if bad_time else 0.65):
			return
		start_a90_local()
		return

	if player_ctrl.is_hiding:
		end_a90()
		return

	if a90_phase == 1:
		a90_timer -= delta
		var p1 := clampf(1.0 - a90_timer / 0.35, 0.0, 1.0)
		a90_root.visible = true
		a90_root.modulate.a = p1 * 0.88
		a90_stop_icon.visible = false
		a90_mat.set_shader_parameter("red_amt", 0.0)
		a90_mat.set_shader_parameter("static_amt", 0.25)
		if a90_timer <= 0.0:
			a90_phase = 2
			a90_timer = a90_freeze_dur
			a90_grace = 0.12
			a90_start_pos = player_body.position
			a90_start_yaw = player_ctrl.target_yaw
			a90_start_pitch = player_ctrl.target_pitch
			player_body.velocity.x = 0.0
			player_body.velocity.z = 0.0
			a90_root.visible = true
			a90_root.modulate.a = 1.0
			a90_shake.position = Vector2.ZERO
			a90_rect.texture = a90_textures.get("pre", a90_textures.get("warn"))
			a90_stop_icon.visible = true
			a90_mat.set_shader_parameter("red_amt", 0.75)
			a90_mat.set_shader_parameter("static_amt", 0.50)
			audio.play_a90_warn()
	elif a90_phase == 2:
		a90_timer -= delta
		if a90_grace > 0.0:
			a90_grace = maxf(a90_grace - delta, 0.0)
			a90_start_pos = player_body.position
			a90_start_yaw = player_ctrl.target_yaw
			a90_start_pitch = player_ctrl.target_pitch
		var jit := rng.randf_range(-3.0, 3.0)
		a90_shake.position = Vector2(jit, jit * 0.5)

		var moved := player_body.position.distance_to(a90_start_pos) > 0.04 or player_body.velocity.length() > 0.10
		var turned := absf(wrapf(player_ctrl.target_yaw - a90_start_yaw, -PI, PI)) > 0.024 or absf(player_ctrl.target_pitch - a90_start_pitch) > 0.024
		var key_press := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if a90_grace <= 0.0 and (moved or turned or key_press):
			a90_phase = 0
			a90_hits += 1
			a90_root.visible = false
			a90_stop_icon.visible = false
			a90_cooldown = rng.randf_range(30.0, 60.0)
			audio.play_a90_hit()
			player_ctrl.shake_amount = 0.25
			a90_scare_timer = 0.55
			if scare_rect != null:
				scare_rect.texture = a90_textures.get("rage")
				scare_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
				scare_rect.visible = true
			ui_mgr.show_toast("A-90 (Paralysis) нанёс 90 урона! Не двигайтесь вообще!", 2.6)
			game.call("damage_player", 90, "A-90", Color(0.95, 0.04, 0.04, 0.85), {"a90_moved": moved, "a90_turned": turned, "key": key_press})
			return
		elif a90_timer <= 0.0:
			a90_phase = 3
			a90_timer = 0.22
			a90_stop_icon.visible = false
			a90_rect.texture = a90_textures.get("pre", a90_textures.get("warn"))
			if is_authority() and net != null and net.is_online():
				net.broadcast_entity_event({"k": "a90_end"}, true)
	elif a90_phase == 3:
		a90_timer -= delta
		var t2 := clampf(a90_timer / 0.22, 0.0, 1.0)
		a90_root.modulate.a = t2
		a90_mat.set_shader_parameter("red_amt", t2 * 0.35)
		a90_mat.set_shader_parameter("static_amt", t2 * 0.25)
		if a90_timer <= 0.0:
			end_a90()


func start_a90_local() -> void:
	a90_freeze_dur = rng.randf_range(1.0, 1.15)
	a90_phase = 1
	a90_timer = 0.35
	a90_grace = 0.0
	var a90_root := ui_mgr.get_node_ref("a90_root")
	var a90_rect := ui_mgr.get_node_ref("a90_rect") as TextureRect
	var a90_stop_icon := ui_mgr.get_node_ref("a90_stop_icon")
	var a90_mat := ui_mgr.ui.get("a90_mat") as ShaderMaterial
	var a90_shake := ui_mgr.get_node_ref("a90_shake")
	a90_root.visible = true
	a90_root.modulate.a = 0.0
	a90_rect.texture = a90_textures.get("warn")
	var side_x := 240.0 if rng.randf() < 0.5 else -240.0
	a90_shake.position = Vector2(side_x, rng.randf_range(-120.0, 120.0))
	a90_stop_icon.visible = false
	a90_mat.set_shader_parameter("red_amt", 0.0)
	a90_mat.set_shader_parameter("static_amt", 0.25)
	audio.play_a90_warn()
	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a90_spawn", "dur": a90_freeze_dur}, true)


func end_a90() -> void:
	a90_phase = 0
	a90_timer = 0.0
	a90_grace = 0.0
	a90_cooldown = rng.randf_range(26.0, 44.0)
	var a90_root := ui_mgr.get_node_ref("a90_root")
	if a90_root != null:
		a90_root.visible = false
		a90_root.modulate.a = 1.0
	var icon := ui_mgr.get_node_ref("a90_stop_icon")
	if icon != null:
		icon.visible = false


func handle_remote_event(msg: Dictionary, is_playing: bool, is_dead: bool) -> bool:
	var kind := String(msg.get("k", ""))
	if kind == "a120_end":
		a120_active = false
		a120_phase = 0
		a120_substage = 0
		a120_node.visible = false
		audio.stop_a120()
		if is_authority() and net != null and net.is_online() and bool(msg.get("from_client", false)):
			net.broadcast_entity_event({"k": "a120_end"}, true)
		return true
	if kind == "a60_end":
		a60_active = false
		a60_phase = 0
		a60_node.visible = false
		var sc := ui_mgr.get_node_ref("a60_scare_rect")
		if sc != null:
			sc.visible = false
		audio.stop_a60()
		return true
	if kind == "a90_spawn":
		if is_authority() or not is_playing or player_ctrl.is_hiding or a90_phase != 0:
			return true
		a90_freeze_dur = clampf(float(msg.get("dur", 1.08)), 0.9, 3.0)
		start_a90_local()
		return true
	if kind == "a90_end":
		if a90_phase != 0:
			end_a90()
		return true
	if kind == "a075_end":
		_reset_a075_state()
		return true
	if kind == "a075_spawn":
		if is_authority() or is_dead:
			return true
		var pa: Variant = msg.get("p")
		if pa is Array and (pa as Array).size() >= 3:
			var arr: Array = pa
			start_a075_local(Vector3(float(arr[0]), float(arr[1]), float(arr[2])))
		return true
	if is_authority():
		return false
	if kind == "a60p_warn":
		a60_prime_flicker_active = true
		a60_prime_flicker_gap_t = float(msg.get("gap", 0.0))
		a60_prime_flicker_snd_cd = 0.0
		return true
	if kind == "a60p_end":
		a60_prime_flicker_active = false
		a60_prime_flicker_gap_t = 0.0
		return true
	if is_dead:
		return true
	if kind == "a60_spawn":
		start_a60_local(int(msg.get("door", 0)), bool(msg.get("prime", false)))
		return true
	if kind == "a60_pos":
		var p_arr: Variant = msg.get("p")
		if p_arr is Array and (p_arr as Array).size() >= 3:
			var a: Array = p_arr
			_net_a60_tgt = Vector3(float(a[0]), float(a[1]), float(a[2]))
			if a60_active:
				a60_phase = int(msg.get("ph", 2))
		return true
	if kind == "a60_brk":
		var b_idx := int(msg.get("door", -1))
		var b_prime := bool(msg.get("prime", false))
		var r_brk: RoomScene = room_mgr.room_by_idx.get(b_idx) as RoomScene
		if r_brk != null and not r_brk.door_opened and not r_brk.door_broken:
			var tex := a60_last_tex if a60_last_tex != null else a60_frames[0]
			room_mgr.break_door_by_a60(b_idx, b_prime, tex, rng, audio)
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.09)
			game.call("advance_door_progress", b_idx, false)
		return true
	if kind == "a120_spawn":
		if a120_hit_cd <= 0.0:
			start_a120_local(int(msg.get("room", 0)), int(msg.get("rb", 0)))
		return true
	if kind == "a120_pos":
		if a120_hit_cd > 0.0:
			return true
		var p120: Variant = msg.get("p")
		if p120 is Array and (p120 as Array).size() >= 3:
			var a2: Array = p120
			_net_a120_tgt = Vector3(float(a2[0]), float(a2[1]), float(a2[2]))
			if a120_active:
				a120_phase = int(msg.get("ph", 1))
				a120_substage = int(msg.get("ss", 0))
		return true
	return false


# --- A-075 ("Shutter" / Затвор): Light & Gaze Reactive Entity ---
func spawn_a075() -> void:
	if room_mgr.rooms.is_empty():
		return
	var cur_r: RoomScene = room_mgr.room_by_idx.get(room_mgr.current_room_idx) as RoomScene
	if cur_r == null:
		cur_r = room_mgr.rooms[0]
	var spawn_pos: Vector3 = cur_r.exit_pos - cur_r.out_dir * 2.2 + Vector3(0.0, 1.65, 0.0)
	if spawn_pos.distance_to(player_body.global_position) < 5.0:
		spawn_pos = cur_r.center_pos - cur_r.in_dir * 6.5 + Vector3(0.0, 1.65, 0.0)
	start_a075_local(spawn_pos)
	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a075_spawn", "p": [spawn_pos.x, spawn_pos.y, spawn_pos.z]}, true)


func start_a075_local(spawn_pos: Vector3) -> void:
	a075_active = true
	a075_phase = 1
	a075_timer = 2.2
	a075_detect_accum = 0.0
	a075_attack_step = 0
	a075_scan_phase = 0.0
	a075_node.position = spawn_pos
	a075_node.visible = true
	a075_node.scale = Vector3.ONE
	var t_closed := a075_textures.get("closed") as Texture2D
	if t_closed != null:
		a075_sprite.texture = t_closed
		a075_sprite.pixel_size = 2.45 / float(maxi(t_closed.get_width(), 1))
	a075_sprite.modulate = Color(1.0, 1.0, 1.0, 0.96)
	a075_omni.light_color = Color(1.0, 0.68, 0.22)
	a075_omni.light_energy = 1.6
	a075_spot.visible = false
	room_mgr.flicker_nearby_lights(0.8)
	audio.play_a075_warning()


func process_a075(delta: float, is_playing: bool, is_dead: bool, active_modifiers: Dictionary) -> void:
	update_a075_flash_fx(delta)

	if not a075_active:
		if not is_playing or not is_authority():
			return
		if room_mgr.highest_opened < 40 or player_ctrl.is_hiding or a60_active or a120_active or a90_phase != 0:
			return
		var bad_time := bool(active_modifiers.get("bad_time", false))
		a075_cooldown -= delta * (1.75 if bad_time else 1.0)
		if a075_cooldown > 0.0:
			return
		a075_cooldown = rng.randf_range(18.0 if bad_time else 32.0, 36.0 if bad_time else 62.0)
		if rng.randf() > (0.80 if bad_time else 0.58):
			return
		spawn_a075()
		return

	a075_node.visible = not is_dead
	a075_scan_phase += delta
	# Subtle eerie hover bob
	a075_sprite.position.y = sin(a075_scan_phase * 2.4) * 0.08

	if a075_phase == 1:
		# Phase 1 (2.2s): Closed shutter charging flash capacitor
		a075_timer -= delta
		a075_omni.light_energy = 1.2 + (1.0 - clampf(a075_timer / 2.2, 0.0, 1.0)) * 2.2
		if a075_timer <= 0.0:
			a075_phase = 2
			a075_timer = 4.0
			a075_detect_accum = 0.0
			var t_scan := a075_textures.get("scan") as Texture2D
			if t_scan != null:
				a075_sprite.texture = t_scan
				a075_sprite.pixel_size = 2.45 / float(maxi(t_scan.get_width(), 1))
			a075_omni.light_color = Color(1.0, 0.78, 0.30)
			a075_omni.light_energy = 3.2
			a075_spot.visible = true
			audio.start_a075_scan()

	elif a075_phase == 2:
		# Phase 2 (4.0s): Open aperture scanning for flashlight beam or direct gaze
		a075_timer -= delta
		var to_player := cam.global_position - a075_node.global_position
		if to_player.length_squared() > 0.01:
			var base_yaw := atan2(-to_player.x, -to_player.z)
			a075_spot.rotation = Vector3(-0.08, base_yaw + sin(a075_scan_phase * 2.8) * 0.38, 0.0)

		if is_playing and not player_ctrl.is_hiding:
			var exposed := _check_a075_player_exposed()
			if exposed > 0.0:
				a075_detect_accum += delta * exposed
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, clampf(a075_detect_accum / 0.55, 0.0, 1.0) * 0.025)
				if a075_detect_accum >= 0.55:
					_trigger_a075_flash_attack()
					return
			else:
				a075_detect_accum = maxf(a075_detect_accum - delta * 1.8, 0.0)
		else:
			a075_detect_accum = maxf(a075_detect_accum - delta * 2.5, 0.0)

		if a075_timer <= 0.0:
			# Survived cleanly! Close shutter and despawn
			a075_phase = 4
			a075_timer = 0.65
			a075_detect_accum = 0.0
			a075_spot.visible = false
			var t_closed := a075_textures.get("closed") as Texture2D
			if t_closed != null:
				a075_sprite.texture = t_closed
			audio.play_a075_despawn()

	elif a075_phase == 3:
		# Phase 3 (0.60s): 3-frame strobe Flash-Dash attack toward the player!
		a075_timer -= delta
		var prog := 1.0 - clampf(a075_timer / 0.60, 0.0, 1.0)
		var step_i := 1 if prog < 0.35 else (2 if prog < 0.72 else 3)
		if step_i != a075_attack_step:
			a075_attack_step = step_i
			var tgt_stop := cam.global_position + (-cam.global_transform.basis.z) * 1.35
			tgt_stop.y = cam.global_position.y
			var frac := 0.36 if step_i == 1 else (0.72 if step_i == 2 else 1.0)
			a075_node.position = a075_attack_origin.lerp(tgt_stop, frac)
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.12)
			a075_flash_fx_t = maxf(a075_flash_fx_t, 4.0)
		if a075_timer <= 0.0:
			_finish_a075_attack()

	elif a075_phase == 4:
		a075_timer -= delta
		var fade := clampf(a075_timer / 0.65, 0.0, 1.0)
		a075_sprite.modulate.a = fade
		a075_omni.light_energy = 1.6 * fade
		if a075_timer <= 0.0:
			a075_active = false
			a075_phase = 0
			a075_node.visible = false
			a075_sprite.modulate.a = 1.0
			if is_authority() and net != null and net.is_online():
				net.broadcast_entity_event({"k": "a075_end"}, true)


func _check_a075_player_exposed() -> float:
	var to_ent := a075_node.global_position - cam.global_position
	var dist := to_ent.length()
	if dist > 26.0 or dist < 0.1:
		return 0.0
	var space := player_body.get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(a075_node.global_position, cam.global_position)
		q.exclude = [player_body.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return 0.0 # Protected behind wall/obstacle!

	var light_exp := player_ctrl.is_light_exposed()
	var cam_fwd := -cam.global_transform.basis.z
	var look_dot := cam_fwd.dot(to_ent / dist)
	var gaze_exp := (look_dot > 0.615) # Within ~52 deg cone of staring at A-075

	if light_exp and gaze_exp:
		return 1.65
	if light_exp or gaze_exp:
		return 1.0
	return 0.0


func _trigger_a075_flash_attack() -> void:
	a075_phase = 3
	a075_timer = 0.60
	a075_attack_step = 0
	a075_attack_origin = a075_node.position
	a075_spot.visible = false
	var t_atk := a075_textures.get("attack") as Texture2D
	if t_atk != null:
		a075_sprite.texture = t_atk
		a075_sprite.pixel_size = 2.75 / float(maxi(t_atk.get_width(), 1))
	a075_omni.light_color = Color(1.0, 0.96, 0.85)
	a075_omni.light_energy = 11.0
	a075_flash_fx_t = 4.0
	audio.play_a075_attack()


func _finish_a075_attack() -> void:
	a075_active = false
	a075_phase = 0
	a075_detect_accum = 0.0
	a075_node.visible = false
	a075_spot.visible = false
	# Drain 25% of standard flashlight battery (37.5 out of 150s)
	player_ctrl.std_battery = maxf(player_ctrl.std_battery - 37.5, 0.0)
	player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.22)
	ui_mgr.show_toast(RoomsI18n.t("toast_a075_blind"), 3.0)
	# A-075 one-shots the player with a blinding flash death animation!
	game.call("damage_player", 999, "A-075", Color(1.0, 0.98, 0.90, 0.96), {})
	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a075_end"}, true)


func update_a075_flash_fx(delta: float) -> void:
	var rect := ui_mgr.get_node_ref("a075_flash_rect")
	var mat := ui_mgr.ui.get("a075_flash_mat") as ShaderMaterial
	if rect == null or mat == null:
		return
	if a075_flash_fx_t > 0.0:
		a075_flash_fx_t = maxf(a075_flash_fx_t - delta, 0.0)
	var flash_p := clampf(a075_flash_fx_t / 4.0, 0.0, 1.0)
	var warn_p := clampf(a075_detect_accum / 0.55, 0.0, 1.0) if (a075_active and a075_phase == 2) else 0.0
	if flash_p > 0.004 or warn_p > 0.01:
		rect.visible = true
		mat.set_shader_parameter("flash_amt", flash_p)
		mat.set_shader_parameter("warn_amt", warn_p)
	elif rect.visible:
		rect.visible = false
