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
var a120_random_timer := 48.0
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

# A-085 (The Breacher / Выселитель) — Smoke Locker Breaker
var a085_active := false
var a085_phase := 0 # 0=idle, 1=warning, 2=fly_in, 3=envelop(1.5s), 4=lift_door(2.0s), 5=door_thrown_wait(1.0s), 6=post_throw, 7=evaporate
var a085_timer := 0.0
var a085_phase_elapsed := 0.0
var a085_cooldown := 48.0
var a085_node: Node3D = null
var a085_particles: CPUParticles3D = null
var a085_particles_core: CPUParticles3D = null
var a085_light: OmniLight3D = null
var a085_smoke_mat: StandardMaterial3D = null
var a085_smoke_quad: QuadMesh = null
var a085_smoke_ramp: Gradient = null
var a085_tendril_ramp: Gradient = null
var a085_path: Array[Vector3] = []
var a085_path_idx := 0
var a085_passed_player := false
var a085_target_room_idx := -1
var a085_center_pos := Vector3.ZERO
var a085_targets: Array[Dictionary] = []
var a085_tendril_nodes: Array[Node] = []
var a085_flying_doors: Array[Dictionary] = []
var a085_smoke_tex: Texture2D = null

# A-160 (The Mimic / Двойник) — Player Doppelganger
var a160_active := false
var a160_phase := 0 # 0=idle, 1=mimic_stand, 2=alert_unmasked, 3=lunge_attack, 4=despawn
var a160_timer := 0.0
var a160_phase_elapsed := 0.0
var a160_cooldown := 55.0
var a160_node: Node3D = null
var a160_avatar: DummiAvatar = null
var a160_room_idx := -1
var a160_target_name := "Player"
var a160_stare_timer := 0.0
var a160_neck_tilt := 0.0
var a160_orig_pos := Vector3.ZERO
var a160_lunge_target := Vector3.ZERO
var a160_lunge_speed := 18.5
var a160_hit_done := false
var a160_particles: CPUParticles3D = null
var a160_banished := false


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

	# A-085 (The Breacher) World Node & Volumetric Smoke Particles
	a085_node = Node3D.new()
	a085_node.name = "Entity_A085"
	a085_node.visible = false
	world_parent.add_child(a085_node)

	a085_smoke_tex = _try_load_tex("res://assets/sprites/a085/regular_smoke_black.png")
	if a085_smoke_tex == null:
		a085_smoke_tex = _try_load_tex("res://assets/sprites/a085/regular_smoke_puff.png")

	a085_smoke_mat = StandardMaterial3D.new()
	a085_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a085_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	a085_smoke_mat.vertex_color_use_as_albedo = true
	a085_smoke_mat.albedo_texture = a085_smoke_tex
	a085_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	a085_smoke_quad = QuadMesh.new()
	a085_smoke_quad.size = Vector2(1.75, 1.75)

	a085_smoke_ramp = Gradient.new()
	a085_smoke_ramp.offsets = PackedFloat32Array([0.0, 0.16, 0.72, 1.0])
	a085_smoke_ramp.colors = PackedColorArray([
		Color(0.09, 0.09, 0.11, 0.0),
		Color(0.06, 0.06, 0.08, 0.78),
		Color(0.11, 0.11, 0.13, 0.50),
		Color(0.14, 0.14, 0.16, 0.0),
	])

	a085_tendril_ramp = Gradient.new()
	a085_tendril_ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.70, 1.0])
	a085_tendril_ramp.colors = PackedColorArray([
		Color(0.11, 0.11, 0.13, 0.0),
		Color(0.08, 0.08, 0.10, 0.38),
		Color(0.12, 0.12, 0.14, 0.24),
		Color(0.15, 0.15, 0.17, 0.0),
	])

	a085_particles = CPUParticles3D.new()
	a085_particles.mesh = a085_smoke_quad
	a085_particles.material_override = a085_smoke_mat
	a085_particles.local_coords = false
	a085_particles.amount = 54
	a085_particles.lifetime = 1.25
	a085_particles.explosiveness = 0.04
	a085_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	a085_particles.emission_sphere_radius = 0.85
	a085_particles.gravity = Vector3(0.0, 0.65, 0.0)
	a085_particles.direction = Vector3(0.0, 1.0, 0.0)
	a085_particles.spread = 180.0
	a085_particles.initial_velocity_min = 0.35
	a085_particles.initial_velocity_max = 1.15
	a085_particles.angle_min = -180.0
	a085_particles.angle_max = 180.0
	a085_particles.angular_velocity_min = -32.0
	a085_particles.angular_velocity_max = 32.0
	a085_particles.scale_amount_min = 1.0
	a085_particles.scale_amount_max = 1.95
	a085_particles.color_ramp = a085_smoke_ramp
	a085_particles.emitting = false
	a085_node.add_child(a085_particles)

	a085_particles_core = CPUParticles3D.new()
	a085_particles_core.mesh = a085_smoke_quad
	a085_particles_core.material_override = a085_smoke_mat
	a085_particles_core.local_coords = false
	a085_particles_core.amount = 28
	a085_particles_core.lifetime = 0.85
	a085_particles_core.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	a085_particles_core.emission_sphere_radius = 0.45
	a085_particles_core.gravity = Vector3(0.0, 0.30, 0.0)
	a085_particles_core.scale_amount_min = 0.85
	a085_particles_core.scale_amount_max = 1.5
	a085_particles_core.color_ramp = a085_smoke_ramp
	a085_particles_core.emitting = false
	a085_node.add_child(a085_particles_core)

	a085_light = OmniLight3D.new()
	a085_light.light_color = Color(0.68, 0.74, 0.84)
	a085_light.light_energy = 1.9
	a085_light.omni_range = 11.5
	a085_light.shadow_enabled = false
	a085_node.add_child(a085_light)

	# A-160 (The Mimic / Двойник)
	a160_node = Node3D.new()
	a160_node.name = "Entity_A160"
	a160_node.visible = false
	world_parent.add_child(a160_node)

	a160_avatar = DummiAvatar.new()
	a160_avatar.name = "MimicAvatar"
	a160_node.add_child(a160_avatar)
	a160_avatar.setup(
		room_mgr.assets if room_mgr != null else null,
		player_ctrl.vm_bulb_on_mat if player_ctrl != null else null,
		player_ctrl.vm_gummy_on_mat if player_ctrl != null else null,
		true
	)

	var a160_quad := QuadMesh.new()
	a160_quad.size = Vector2(0.32, 0.32)
	var a160_pmat := StandardMaterial3D.new()
	a160_pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a160_pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	a160_pmat.albedo_color = Color(0.12, 0.12, 0.16, 0.82)
	a160_pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	var a160_ramp := Gradient.new()
	a160_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	a160_ramp.colors = PackedColorArray([
		Color(0.2, 0.2, 0.25, 0.0),
		Color(0.12, 0.12, 0.16, 0.8),
		Color(0.08, 0.08, 0.11, 0.45),
		Color(0.04, 0.04, 0.06, 0.0)
	])

	a160_particles = CPUParticles3D.new()
	a160_particles.mesh = a160_quad
	a160_particles.material_override = a160_pmat
	a160_particles.local_coords = false
	a160_particles.amount = 32
	a160_particles.lifetime = 0.85
	a160_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	a160_particles.emission_sphere_radius = 0.5
	a160_particles.gravity = Vector3(0.0, 0.75, 0.0)
	a160_particles.color_ramp = a160_ramp
	a160_particles.emitting = false
	a160_node.add_child(a160_particles)


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
	a085_flying_doors.clear()
	_reset_a085_state()
	_reset_a160_state()


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


func _clear_a085_tendrils() -> void:
	for n in a085_tendril_nodes:
		if is_instance_valid(n):
			n.queue_free()
	a085_tendril_nodes.clear()


func _reset_a085_state() -> void:
	a085_active = false
	a085_phase = 0
	a085_timer = 0.0
	a085_phase_elapsed = 0.0
	a085_cooldown = rng.randf_range(45.0, 80.0) if rng != null else 48.0
	a085_path.clear()
	a085_path_idx = 0
	a085_passed_player = false
	a085_target_room_idx = -1
	a085_center_pos = Vector3.ZERO
	a085_targets.clear()
	_clear_a085_tendrils()
	if player_ctrl != null:
		player_ctrl.hiding_door_lifted = false
		player_ctrl.a085_grab_locked = false
	if is_instance_valid(a085_node):
		a085_node.visible = false
	if is_instance_valid(a085_particles):
		a085_particles.emitting = false
	if is_instance_valid(a085_particles_core):
		a085_particles_core.emitting = false
	audio.stop_a085_all()


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
	a085_flying_doors.clear()
	_reset_a085_state()
	_reset_a160_state()
	if broadcast and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a60_end"}, true)
		net.broadcast_entity_event({"k": "a120_end"}, true)
		net.broadcast_entity_event({"k": "a90_end"}, true)
		net.broadcast_entity_event({"k": "a075_end"}, true)
		net.broadcast_entity_event({"k": "a085_end"}, true)
		net.broadcast_entity_event({"k": "a160_end"}, true)


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
		_reset_a160_state()
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
	audio.stop_a160_all()
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
	if not is_authority() or a60_active or a120_active or a160_active:
		return
	if room_num == 120:
		spawn_a120()
	elif room_num > 120:
		var chance_120 := clampf(0.20 + float(room_num - 120) * 0.001, 0.20, 0.36)
		if rng.randf() < chance_120:
			spawn_a120()
			return

	if room_num >= 90 and not a085_active and a90_phase == 0 and not player_ctrl.is_hiding:
		# Door opening trigger for A-90 after room 90
		if rng.randf() < 0.16 and a90_cooldown < 12.0:
			a90_cooldown = 0.0
			start_a90_local()
			return

	if room_num == 160:
		spawn_a160()
	elif room_num >= 65 and not a085_active:
		var chance_160 := clampf(0.06 + float(room_num - 65) * 0.0007, 0.06, 0.13)
		if rng.randf() < chance_160:
			spawn_a160()


func process_spawners(delta: float, active_modifiers: Dictionary) -> void:
	if not is_authority():
		return
	var bad_time := bool(active_modifiers.get("bad_time", false))
	var cd_mult := 1.9 if bad_time else 1.0

	if room_mgr.highest_opened == 19 and not a60_active and not a120_active:
		if a60_door20_trigger_timer > 0.0:
			a60_door20_trigger_timer -= delta
			if a60_door20_trigger_timer <= 0.0:
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

	# Ambient spawner for A-120
	if room_mgr.highest_opened >= 120 and not a60_active and not a120_active and not a160_active:
		a120_random_timer -= delta * cd_mult
		if a120_random_timer <= 0.0:
			a120_random_timer = rng.randf_range(38.0, 72.0)
			spawn_a120()


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
	var best_pos: Vector3 = (player_ctrl.locker_eye + player_ctrl.locker_fwd * 0.95) if player_ctrl.is_hiding else player_body.global_position
	var best_exposed: bool = not player_ctrl.is_hiding
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
							a60_prime_pending_timer = 4.2
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
							a60_prime_pending_timer = 3.8
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
		a90_cooldown = rng.randf_range(16.0 if bad_time else 22.0, 30.0 if bad_time else 42.0)
		if rng.randf() > (0.95 if bad_time else 0.85):
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
	if kind == "a085_spawn":
		if is_authority():
			return true
		var t_room := int(msg.get("room", room_mgr.highest_opened))
		start_a085_local(t_room)
		return true
	if kind == "a085_break":
		var br_r := int(msg.get("r", -1))
		var br_l := int(msg.get("l", -1))
		var r_inst: RoomScene = room_mgr.room_by_idx.get(br_r) as RoomScene
		if r_inst != null and br_l >= 0 and br_l < r_inst.lockers.size():
			var ld: Dictionary = r_inst.lockers[br_l]
			if not bool(ld.get("broken", false)):
				ld["broken"] = true
				var dp := ld.get("door_pivot") as Node3D
				if is_instance_valid(dp):
					for ch in dp.get_children():
						if ch is StaticBody3D:
							(ch as StaticBody3D).collision_layer = 0
							(ch as StaticBody3D).collision_mask = 0
					dp.visible = false
		return true
	if kind == "a085_end":
		if not is_authority():
			_reset_a085_state()
		return true
	if kind == "a160_end":
		_reset_a160_state()
		return true
	if kind == "a160_spawn":
		if is_authority():
			return true
		var r_i := int(msg.get("room", room_mgr.highest_opened))
		var pa: Variant = msg.get("pos")
		var s_pos := Vector3.ZERO
		if pa is Array and (pa as Array).size() >= 3:
			s_pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		var s_rot := float(msg.get("rot", 0.0))
		var t_nm := String(msg.get("name", "Player"))
		var f_bts: PackedByteArray = msg.get("face", PackedByteArray())
		var u_gum := bool(msg.get("gummy", false))
		start_a160_local(r_i, s_pos, s_rot, t_nm, f_bts, u_gum)
		return true
	if kind == "a160_alert":
		if not is_authority():
			_a160_trigger_alert_local()
		return true
	if kind == "a160_lunge":
		if not is_authority():
			var l_target := Vector3.ZERO
			var la: Variant = msg.get("tgt")
			if la is Array and (la as Array).size() >= 3:
				l_target = Vector3(float(la[0]), float(la[1]), float(la[2]))
			_a160_trigger_lunge_local(l_target)
		return true
	if kind == "a160_banish":
		_a160_trigger_banish_local()
		if is_authority() and net != null and net.is_online():
			net.broadcast_entity_event({"k": "a160_banish"}, true)
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

	var light_exp: bool = player_ctrl.is_light_exposed()
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
	# A-075 one-shots the player with a blinding flash death animation!
	# Do not broadcast a075_end here so alive teammates finish their scan cleanly.
	game.call("damage_player", 999, "A-075", Color(1.0, 0.98, 0.90, 0.96), {})


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


# ==============================================================================
# A-085 (The Breacher / Выселитель) — Smoke Locker Breaker
# ==============================================================================

func _make_a085_smoke_emitter(parent_node: Node, pos: Vector3, amount: int, lifetime: float, radius: float, scale_min: float, scale_max: float, dir: Vector3 = Vector3.UP, spread: float = 180.0, spd_min: float = 0.4, spd_max: float = 1.2, use_soft_ramp: bool = true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = a085_smoke_quad
	p.material_override = a085_smoke_mat
	p.local_coords = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.04
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector3(0.0, 0.45, 0.0)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = spd_min
	p.initial_velocity_max = spd_max
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -35.0
	p.angular_velocity_max = 35.0
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color_ramp = a085_tendril_ramp if use_soft_ramp else a085_smoke_ramp
	p.position = pos
	p.emitting = true
	parent_node.add_child(p)
	a085_tendril_nodes.append(p)
	return p


func _is_locker_occupied_by_anyone(r_idx: int, l_idx: int) -> bool:
	var local_here: bool = (
		player_ctrl != null
		and player_ctrl.is_hiding
		and player_ctrl.hiding_kind == "locker"
		and player_ctrl.hiding_room_idx == r_idx
		and player_ctrl.hiding_locker_idx == l_idx
	)
	var remote_here := (avatar_mgr != null and avatar_mgr.is_locker_occupied(r_idx, l_idx))
	return local_here or remote_here


func spawn_a085() -> void:
	if a085_active or room_mgr.rooms.is_empty():
		return
	var last_idx := room_mgr.highest_opened
	start_a085_local(last_idx)
	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({"k": "a085_spawn", "room": a085_target_room_idx}, true)


func start_a085_local(target_idx: int) -> void:
	if a085_active or room_mgr.rooms.is_empty():
		return

	# Always targets the LAST opened room (counterplay: hide in the second-to-last room!)
	var last_idx := target_idx
	var target_r: RoomScene = room_mgr.room_by_idx.get(last_idx) as RoomScene
	if target_r == null:
		target_r = room_mgr.rooms[-1]
		last_idx = target_r.index

	var min_room_idx := room_mgr.rooms[0].index
	var start_idx := maxi(min_room_idx, last_idx - 4)
	var start_r: RoomScene = room_mgr.room_by_idx.get(start_idx) as RoomScene
	if start_r == null:
		start_r = room_mgr.rooms[0]
		start_idx = start_r.index

	a085_target_room_idx = last_idx
	a085_center_pos = target_r.center_pos + Vector3(0.0, 1.35, 0.0)

	a085_path.clear()
	a085_path.append(start_r.center_pos - start_r.in_dir * 16.0 + Vector3(0.0, 1.35, 0.0))
	for r in room_mgr.rooms:
		if r.index >= start_idx and r.index <= last_idx:
			a085_path.append(r.center_pos + Vector3(0.0, 1.35, 0.0))
			if r.index < last_idx:
				a085_path.append(r.exit_pos + Vector3(0.0, 1.35, 0.0))

	if a085_path.size() < 2:
		return

	a085_active = true
	a085_phase = 1 # warning rumble before flying in
	a085_timer = 2.0
	a085_phase_elapsed = 0.0
	a085_path_idx = 0
	a085_passed_player = false
	a085_targets.clear()
	_clear_a085_tendrils()

	a085_node.position = a085_path[0]
	a085_node.visible = true
	if is_instance_valid(a085_particles):
		a085_particles.emitting = true
	if is_instance_valid(a085_particles_core):
		a085_particles_core.emitting = true
	if is_instance_valid(a085_light):
		a085_light.light_energy = 1.9

	audio.play_a085_warning()


func _a085_begin_envelop_last_room() -> void:
	a085_phase = 3
	a085_phase_elapsed = 0.0
	a085_targets.clear()
	_clear_a085_tendrils()

	var target_r: RoomScene = room_mgr.room_by_idx.get(a085_target_room_idx) as RoomScene
	if target_r == null:
		_a085_begin_evaporate()
		return

	# Scan ONLY occupied lockers in the LAST room
	for li in range(target_r.lockers.size()):
		var ld: Dictionary = target_r.lockers[li]
		if String(ld.get("kind", "")) != "locker":
			continue
		if bool(ld.get("broken", false)):
			continue
		if not _is_locker_occupied_by_anyone(target_r.index, li):
			continue
		var lnode := ld.get("node") as Node3D
		var dp := ld.get("door_pivot") as Node3D
		if not is_instance_valid(lnode):
			continue
		var locker_world_center := lnode.global_transform * Vector3(0.0, 1.05, 0.95)
		var to_locker := (locker_world_center - a085_center_pos)
		var stream_dir := to_locker.normalized() if to_locker.length() > 0.05 else Vector3.FORWARD

		# 1. Smoke stream stretching from center of room toward this occupied locker
		var mid_pos := a085_center_pos.lerp(locker_world_center, 0.42)
		var stream_em := _make_a085_smoke_emitter(world_parent, mid_pos, 26, 0.85, 0.40, 0.65, 1.25, stream_dir, 20.0, 2.2, 4.2, true)
		# 2. Wispy enveloping smoke coiling around the locker edges (without blinding the player camera!)
		var wrap_left := _make_a085_smoke_emitter(world_parent, lnode.global_transform * Vector3(-0.55, 0.95, 0.62), 18, 0.95, 0.32, 0.48, 0.92, Vector3.UP, 140.0, 0.18, 0.65, true)
		var wrap_right := _make_a085_smoke_emitter(world_parent, lnode.global_transform * Vector3(0.55, 0.95, 0.62), 18, 0.95, 0.32, 0.48, 0.92, Vector3.UP, 140.0, 0.18, 0.65, true)

		# Trap local player inside once A-085 envelops their occupied locker so they can't freely walk out and dodge damage!
		if player_ctrl != null and player_ctrl.is_hiding and player_ctrl.hiding_room_idx == target_r.index and player_ctrl.hiding_locker_idx == li:
			player_ctrl.a085_grab_locked = true

		a085_targets.append({
			"room_idx": target_r.index,
			"locker_idx": li,
			"node": lnode,
			"door_pivot": dp,
			"locker_dict": ld,
			"door_orig_pos": ld.get("door_orig_pos", dp.position if is_instance_valid(dp) else Vector3.ZERO),
			"lift_pos": (ld.get("door_orig_pos", dp.position) + Vector3(0.18, 0.92, 1.55)) if is_instance_valid(dp) else Vector3.ZERO,
			"door_smoke": null,
			"wrap_emitters": [stream_em, wrap_left, wrap_right],
		})

	if a085_targets.is_empty():
		# Nobody hiding in a locker in the last room -> swirl briefly then evaporate!
		a085_timer = 1.25
	else:
		# Envelop occupied locker(s) for 1.5 seconds before grabbing & lifting the door
		a085_timer = 1.5


func _a085_begin_lift_doors() -> void:
	a085_phase = 4
	a085_phase_elapsed = 0.0
	a085_timer = 2.0 # Holds door lifted for 2.0 seconds before checking if player is still inside
	audio.play_door_open()

	for t in a085_targets:
		var dp := t.get("door_pivot") as Node3D
		var r_idx := int(t.get("room_idx", -1))
		var l_idx := int(t.get("locker_idx", -1))
		if is_instance_valid(dp):
			# Disable door StaticBody colliders cleanly before moving/lifting
			for ch in dp.get_children():
				if ch is StaticBody3D:
					var sb := ch as StaticBody3D
					sb.collision_layer = 0
					sb.collision_mask = 0
			var lift_pos: Vector3 = t["lift_pos"]
			var tw := dp.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(dp, "position", lift_pos, 0.65)
			tw.tween_property(dp, "rotation", Vector3(-0.34, 0.45, 0.14), 0.65)
			# Attach wispy smoke coiling around the levitating door's edges so the door remains clearly visible!
			var door_smoke := _make_a085_smoke_emitter(dp, Vector3(0.42, 1.15, 0.15), 14, 0.70, 0.38, 0.35, 0.68, Vector3.UP, 160.0, 0.15, 0.50, true)
			t["door_smoke"] = door_smoke

		# Fade away dark locker mask so the player inside clearly sees the door lift up & A-085 hovering in front!
		if player_ctrl != null and player_ctrl.is_hiding and player_ctrl.hiding_room_idx == r_idx and player_ctrl.hiding_locker_idx == l_idx:
			player_ctrl.hiding_door_lifted = true
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.05)


func _a085_check_and_throw_doors() -> void:
	var any_player_caught := false
	var target_r: RoomScene = room_mgr.room_by_idx.get(a085_target_room_idx) as RoomScene
	var room_center := target_r.center_pos if target_r != null else a085_center_pos

	for t in a085_targets:
		var r_idx := int(t.get("room_idx", -1))
		var l_idx := int(t.get("locker_idx", -1))
		var ld: Dictionary = t["locker_dict"]
		var dp := t.get("door_pivot") as Node3D
		var lnode := t.get("node") as Node3D
		var still_here := _is_locker_occupied_by_anyone(r_idx, l_idx)
		t["caught"] = still_here

		var door_smoke := t.get("door_smoke") as CPUParticles3D
		if is_instance_valid(door_smoke):
			door_smoke.emitting = false

		if still_here:
			any_player_caught = true
			ld["broken"] = true
			if is_authority() and net != null and net.is_online():
				net.broadcast_entity_event({"k": "a085_break", "r": r_idx, "l": l_idx}, true)
			if is_instance_valid(dp) and is_instance_valid(lnode):
				# Throw the door violently sideways & across the room!
				var fwd := lnode.global_transform.basis.z.normalized()
				var side := lnode.global_transform.basis.x.normalized() * (1.0 if (rng != null and rng.randf() < 0.5) else -1.0)
				var throw_dir := (fwd * 0.72 + side * 0.78).normalized()
				var vel := throw_dir * (rng.randf_range(9.0, 12.5) if rng != null else 10.5) + Vector3(0.0, 3.2, 0.0)
				var ang_vel := Vector3(
					rng.randf_range(5.0, 8.5) if rng != null else 6.5,
					rng.randf_range(-7.5, 7.5) if rng != null else 5.0,
					rng.randf_range(-6.0, 6.0) if rng != null else -4.5
				)
				a085_flying_doors.append({
					"door_pivot": dp,
					"vel": vel,
					"ang_vel": ang_vel,
					"room_center": room_center,
					"bounces": 0,
					"active": true,
				})
			# Lock local player during the 1.0s pause before launching them
			if player_ctrl != null and player_ctrl.is_hiding and player_ctrl.hiding_room_idx == r_idx and player_ctrl.hiding_locker_idx == l_idx:
				player_ctrl.a085_grab_locked = true
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.14)
		else:
			# Player escaped in time -> drop the lifted door down to the floor
			ld["broken"] = true
			if is_instance_valid(dp) and is_instance_valid(lnode):
				var fwd := lnode.global_transform.basis.z.normalized()
				a085_flying_doors.append({
					"door_pivot": dp,
					"vel": fwd * 1.4 + Vector3(0.0, -0.5, 0.0),
					"ang_vel": Vector3(2.8, 0.6, 0.4),
					"room_center": room_center,
					"bounces": 1,
					"active": true,
				})

	if any_player_caught:
		audio.play_a085_door_slam()
		a085_phase = 5
		a085_phase_elapsed = 0.0
		a085_timer = 1.0 # 1.0 second after throwing the door -> throw the player!
		if net != null and net.is_online():
			net.broadcast_entity_event({"k": "a085_door_throw"}, true)
	else:
		_a085_begin_evaporate()


func _a085_throw_caught_players() -> void:
	var target_r: RoomScene = room_mgr.room_by_idx.get(a085_target_room_idx) as RoomScene
	var room_center := target_r.center_pos if target_r != null else a085_center_pos

	for t in a085_targets:
		if not bool(t.get("caught", false)):
			continue
		var r_idx := int(t.get("room_idx", -1))
		var l_idx := int(t.get("locker_idx", -1))
		if player_ctrl != null and player_ctrl.is_hiding and player_ctrl.hiding_room_idx == r_idx and player_ctrl.hiding_locker_idx == l_idx:
			# Pick a random destination spot across the room!
			var exit_origin: Vector3 = player_ctrl.locker_exit
			var fwd: Vector3 = player_ctrl.locker_fwd.normalized()
			var rand_target := room_center
			for _attempt in range(8):
				var cand := room_center + Vector3(
					rng.randf_range(-2.8, 2.8) if rng != null else 1.8,
					0.0,
					rng.randf_range(-2.8, 2.8) if rng != null else -1.8
				)
				var to_cand := Vector3(cand.x - exit_origin.x, 0.0, cand.z - exit_origin.z)
				if to_cand.length() > 2.4 and to_cand.normalized().dot(fwd) > 0.35:
					rand_target = cand
					break
			var horiz := Vector3(rand_target.x - exit_origin.x, 0.0, rand_target.z - exit_origin.z)
			if horiz.length() < 1.5 or horiz.normalized().dot(fwd) < 0.35:
				horiz = (fwd + Vector3(rng.randf_range(-0.55, 0.55) if rng != null else 0.35, 0.0, rng.randf_range(-0.55, 0.55) if rng != null else -0.35)).normalized() * 4.5
			var launch_spd := clampf(horiz.length() * 2.55, 10.5, 14.5)
			var launch_vel := horiz.normalized() * launch_spd + Vector3(0.0, 5.2, 0.0)

			audio.play_a085_pass()
			player_ctrl.force_eject_from_locker_breach(launch_vel, ui_mgr, self)
			game.call("damage_player", 90, "A-085", Color(0.92, 0.12, 0.12, 0.88), {"a85_locker_breach": true})
			if net != null and net.is_online():
				net.broadcast_entity_event({"k": "a085_slam"}, true)

	a085_phase = 6
	a085_phase_elapsed = 0.0
	a085_timer = 0.55


func _a085_begin_evaporate() -> void:
	a085_phase = 7
	a085_phase_elapsed = 0.0
	a085_timer = 1.85
	if is_instance_valid(a085_particles):
		a085_particles.emitting = false
	if is_instance_valid(a085_particles_core):
		a085_particles_core.emitting = false
	for n in a085_tendril_nodes:
		if is_instance_valid(n) and n is CPUParticles3D:
			(n as CPUParticles3D).emitting = false
	if player_ctrl != null:
		player_ctrl.hiding_door_lifted = false
		player_ctrl.a085_grab_locked = false


func _update_a085_flying_doors(delta: float) -> void:
	if a085_flying_doors.is_empty():
		return
	var keep: Array[Dictionary] = []
	for d in a085_flying_doors:
		var dp := d.get("door_pivot") as Node3D
		if not is_instance_valid(dp) or not bool(d.get("active", false)):
			continue
		var vel: Vector3 = d["vel"]
		var ang_vel: Vector3 = d["ang_vel"]
		var r_center: Vector3 = d["room_center"]

		vel.y -= 17.5 * delta
		var next_pos := dp.global_position + vel * delta

		# Bounce gently off room walls so the door stays inside the room
		var dx := next_pos.x - r_center.x
		var dz := next_pos.z - r_center.z
		if absf(dx) > 3.25:
			next_pos.x = r_center.x + signf(dx) * 3.25
			vel.x = -vel.x * 0.42
			vel.z *= 0.72
		if absf(dz) > 3.25:
			next_pos.z = r_center.z + signf(dz) * 3.25
			vel.z = -vel.z * 0.42
			vel.x *= 0.72

		if next_pos.y <= 0.08:
			next_pos.y = 0.08
			var bounces := int(d["bounces"])
			if bounces < 1 and absf(vel.y) > 2.2:
				vel.y = absf(vel.y) * 0.34
				vel.x *= 0.55
				vel.z *= 0.55
				ang_vel *= 0.45
				d["bounces"] = bounces + 1
			else:
				# Settle flat onto the room floor
				dp.global_position = next_pos
				dp.rotation = Vector3(PI * 0.5, dp.rotation.y, 0.0)
				d["active"] = false
				continue

		dp.global_position = next_pos
		dp.rotation += ang_vel * delta
		d["vel"] = vel
		d["ang_vel"] = ang_vel
		keep.append(d)
	a085_flying_doors = keep


func process_a085(delta: float, is_playing: bool, is_dead: bool, active_modifiers: Dictionary) -> void:
	_update_a085_flying_doors(delta)

	if not a085_active:
		# Only host/authority triggers random A-085 spawns so all peers stay 100% synced!
		if not is_authority():
			return
		# Allow A-085 to coexist with A-60 / A-120 so second-to-last room counterplay applies!
		if room_mgr.highest_opened < 85 or a90_phase != 0 or a075_active:
			return
		a085_cooldown -= delta
		if a085_cooldown <= 0.0:
			a085_cooldown = rng.randf_range(45.0, 80.0) if rng != null else 55.0
			spawn_a085()
		return

	a085_node.visible = not is_dead
	a085_phase_elapsed += delta

	if a085_phase == 1:
		# Phase 1: Sub-bass warning rumble approaching from behind
		a085_timer -= delta
		var rumble_shake := clampf(1.0 - a085_timer / 2.0, 0.0, 1.0) * 0.032
		player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, rumble_shake)
		if a085_timer <= 0.0:
			a085_phase = 2
			a085_phase_elapsed = 0.0
			a085_path_idx = 1

	elif a085_phase == 2:
		# Phase 2: Flies down the hallway & stops in the center of the LAST room
		var dist_to_final := a085_node.position.distance_to(a085_center_pos)
		var speed := clampf(dist_to_final * 4.5, 6.5, 34.0)
		if a085_path_idx < a085_path.size():
			var tgt := a085_path[a085_path_idx]
			var to_tgt := tgt - a085_node.position
			var dist := to_tgt.length()
			var step := speed * delta
			if dist <= step or dist < 0.2:
				a085_node.position = tgt
				a085_path_idx += 1
				if a085_path_idx >= a085_path.size():
					a085_node.position = a085_center_pos
					_a085_begin_envelop_last_room()
			else:
				a085_node.position += to_tgt.normalized() * step

		var dist_to_player := a085_node.global_position.distance_to(cam.global_position)
		if dist_to_player < 6.5 and not a085_passed_player:
			a085_passed_player = true
			audio.play_a085_pass()
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.08)

	elif a085_phase == 3:
		# Phase 3: Hovering at center of last room, enveloping occupied lockers (1.5s)
		a085_node.position = a085_center_pos + Vector3(0.0, sin(a085_phase_elapsed * 2.8) * 0.14, 0.0)
		if not a085_targets.is_empty() and player_ctrl.is_hiding and player_ctrl.hiding_room_idx == a085_target_room_idx:
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.024)
		a085_timer -= delta
		if a085_timer <= 0.0:
			if a085_targets.is_empty():
				_a085_begin_evaporate()
			else:
				_a085_begin_lift_doors()

	elif a085_phase == 4:
		# Phase 4: Holds the locker door(s) lifted in mid-air (2.0s)
		a085_node.position = a085_center_pos + Vector3(0.0, sin(a085_phase_elapsed * 3.5) * 0.16, 0.0)
		if a085_phase_elapsed > 0.65:
			for t in a085_targets:
				var dp := t.get("door_pivot") as Node3D
				if is_instance_valid(dp):
					var base_lift: Vector3 = t["lift_pos"]
					dp.position.y = base_lift.y + sin(a085_phase_elapsed * 7.5) * 0.045
					dp.rotation.z = 0.08 + cos(a085_phase_elapsed * 6.0) * 0.035
		if player_ctrl.is_hiding and player_ctrl.hiding_room_idx == a085_target_room_idx:
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.032)
		a085_timer -= delta
		if a085_timer <= 0.0:
			_a085_check_and_throw_doors()

	elif a085_phase == 5:
		# Phase 5: Door thrown! Smoke surges toward the exposed player for 1.0s before throwing them
		if not a085_targets.is_empty():
			var first_lnode := a085_targets[0].get("node") as Node3D
			if is_instance_valid(first_lnode):
				var surge_tgt := a085_center_pos.lerp(first_lnode.global_transform * Vector3(0.0, 1.35, 1.25), clampf(a085_phase_elapsed / 0.85, 0.0, 1.0))
				a085_node.position = a085_node.position.lerp(surge_tgt, minf(delta * 5.5, 1.0))
		if player_ctrl.is_hiding and player_ctrl.hiding_room_idx == a085_target_room_idx:
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.085)
		a085_timer -= delta
		if a085_timer <= 0.0:
			_a085_throw_caught_players()

	elif a085_phase == 6:
		# Phase 6: Brief recoil back to center after throwing player, then evaporate
		a085_node.position = a085_node.position.lerp(a085_center_pos + Vector3(0.0, 0.35, 0.0), minf(delta * 3.0, 1.0))
		a085_timer -= delta
		if a085_timer <= 0.0:
			_a085_begin_evaporate()

	elif a085_phase == 7:
		# Phase 7: Simply evaporates cleanly into thin air
		a085_timer -= delta
		var fade := clampf(a085_timer / 1.85, 0.0, 1.0)
		if is_instance_valid(a085_light):
			a085_light.light_energy = 1.15 * fade * fade
		if a085_timer <= 0.0:
			_reset_a085_state()
			if is_authority() and net != null and net.is_online():
				net.broadcast_entity_event({"k": "a085_end"}, true)


# ==============================================================================
# A-160 (The Mimic / Двойник) Implementation
# ==============================================================================

func _reset_a160_state() -> void:
	a160_active = false
	a160_phase = 0
	a160_timer = 0.0
	a160_phase_elapsed = 0.0
	a160_cooldown = rng.randf_range(50.0, 95.0) if rng != null else 55.0
	a160_room_idx = -1
	a160_stare_timer = 0.0
	a160_neck_tilt = 0.0
	a160_orig_pos = Vector3.ZERO
	a160_lunge_target = Vector3.ZERO
	a160_hit_done = false
	a160_banished = false
	if is_instance_valid(a160_node):
		a160_node.visible = false
	if is_instance_valid(a160_avatar):
		if is_instance_valid(a160_avatar.body_mesh):
			a160_avatar.body_mesh.transparency = 0.0
		if is_instance_valid(a160_avatar.spot_light):
			a160_avatar.spot_light.visible = false
	if is_instance_valid(a160_particles):
		a160_particles.emitting = false
	audio.stop_a160_all()


func spawn_a160(target_room: int = -1) -> void:
	if a160_active or room_mgr.rooms.is_empty():
		return
	var r_idx := target_room if target_room >= 0 else room_mgr.highest_opened
	var r: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
	if r == null:
		return

	var t_name := "Player"
	var face_bytes := PackedByteArray()
	var uses_gummy := false

	var remote_ids: Array = avatar_mgr.remote_players.keys() if avatar_mgr != null else []
	if not remote_ids.is_empty() and (rng == null or rng.randf() < 0.75):
		var pick_id: Variant = remote_ids[(rng.randi() if rng != null else 0) % remote_ids.size()]
		var rp: Dictionary = avatar_mgr.remote_players.get(pick_id, {})
		var lbl: Label3D = rp.get("lbl") as Label3D
		if lbl != null and not lbl.text.is_empty():
			t_name = lbl.text
		face_bytes = avatar_mgr.peer_face_bytes.get(pick_id, PackedByteArray())
	else:
		t_name = net.persona_name if (net != null and not net.persona_name.is_empty()) else "Player"
		if ui_mgr != null and ui_mgr.face_editor != null:
			face_bytes = ui_mgr.face_editor.get_current_png_bytes()
		uses_gummy = (player_ctrl != null and player_ctrl.has_gummy)

	var spawn_pos: Vector3
	var side_dir := Vector3(-r.out_dir.z, 0.0, r.out_dir.x)
	var side_offset := side_dir * (2.2 if rng.randf() < 0.5 else -2.2)
	if is_instance_valid(r.exit_anchor):
		spawn_pos = (r.exit_anchor.global_position - r.out_dir * 3.2) + side_offset + Vector3.UP * 0.02
	else:
		spawn_pos = (r.center_pos + r.out_dir * 2.8) + side_offset + Vector3.UP * 0.02
	var rot_y := atan2(r.out_dir.x, r.out_dir.z)

	start_a160_local(r_idx, spawn_pos, rot_y, t_name, face_bytes, uses_gummy)

	if is_authority() and net != null and net.is_online():
		net.broadcast_entity_event({
			"k": "a160_spawn",
			"room": r_idx,
			"pos": [spawn_pos.x, spawn_pos.y, spawn_pos.z],
			"rot": rot_y,
			"name": t_name,
			"face": face_bytes,
			"gummy": uses_gummy
		}, true)


func start_a160_local(r_idx: int, spawn_pos: Vector3, rot_y: float, t_name: String, face_bytes: PackedByteArray, uses_gummy: bool) -> void:
	a160_active = true
	a160_room_idx = r_idx
	a160_phase = 1
	a160_timer = 0.0
	a160_phase_elapsed = 0.0
	a160_stare_timer = 0.0
	a160_neck_tilt = 0.0
	a160_orig_pos = spawn_pos
	a160_target_name = t_name
	a160_hit_done = false
	a160_banished = false

	if is_instance_valid(a160_node):
		a160_node.global_position = spawn_pos
		a160_node.rotation.y = rot_y
		a160_node.visible = true

	if is_instance_valid(a160_avatar):
		if is_instance_valid(a160_avatar.body_mesh):
			a160_avatar.body_mesh.transparency = 0.0
		if is_instance_valid(a160_avatar.name_label):
			a160_avatar.name_label.text = t_name
			a160_avatar.name_label.visible = true
			a160_avatar.name_label.modulate = Color(0.88, 0.94, 1.0)

		if face_bytes.size() > 0:
			var img := Image.new()
			if img.load_png_from_buffer(face_bytes) == OK:
				var tex := ImageTexture.create_from_image(img)
				a160_avatar.set_face_texture(tex)
		elif ui_mgr != null and ui_mgr.face_editor != null:
			var tex := ui_mgr.face_editor.get_current_texture()
			a160_avatar.set_face_texture(tex)

		if is_instance_valid(a160_avatar.spot_light):
			a160_avatar.spot_light.visible = true
			if uses_gummy:
				a160_avatar.spot_light.light_color = Color(0.35, 1.0, 0.52)
			else:
				a160_avatar.spot_light.light_color = Color(1.0, 0.96, 0.88)
			a160_avatar.spot_light.light_energy = 2.4

		a160_avatar.update_pose(0.016, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, true, false, false, 0.0, uses_gummy)

	if is_instance_valid(a160_particles):
		a160_particles.emitting = false


func _a160_trigger_alert_local() -> void:
	if not a160_active or a160_phase != 1:
		return
	a160_phase = 2
	a160_timer = 1.25
	a160_phase_elapsed = 0.0
	audio.play_a160_alert()
	player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.045)
	if is_instance_valid(a160_particles):
		a160_particles.emitting = true
	if is_instance_valid(a160_avatar) and is_instance_valid(a160_avatar.name_label):
		a160_avatar.name_label.modulate = Color(0.9, 0.2, 0.2)


func _a160_trigger_lunge_local(target_pos: Vector3) -> void:
	if not a160_active or (a160_phase != 1 and a160_phase != 2):
		return
	a160_phase = 3
	a160_lunge_target = target_pos
	a160_timer = 1.35
	a160_phase_elapsed = 0.0
	audio.play_a160_lunge()


func _a160_trigger_banish_local() -> void:
	if not a160_active or a160_banished or a160_phase == 4:
		return
	a160_banished = true
	a160_phase = 4
	a160_timer = 0.95
	audio.play_a160_banish()
	if is_instance_valid(a160_particles):
		a160_particles.emitting = true
	if is_instance_valid(a160_avatar) and is_instance_valid(a160_avatar.spot_light):
		a160_avatar.spot_light.visible = false
	player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.035)


func _a160_dissolve() -> void:
	if not a160_active or a160_phase == 4:
		return
	a160_phase = 4
	a160_timer = 0.75
	if is_instance_valid(a160_particles):
		a160_particles.emitting = true


func process_a160(delta: float, is_playing: bool, is_dead: bool, _active_modifiers: Dictionary) -> void:
	if not a160_active:
		if not is_authority():
			return
		if room_mgr.highest_opened < 65 or a60_active or a120_active or a085_active or a90_phase != 0 or a075_active:
			return
		a160_cooldown -= delta
		if a160_cooldown <= 0.0:
			a160_cooldown = rng.randf_range(50.0, 95.0) if rng != null else 60.0
			spawn_a160()
		return

	a160_node.visible = not is_dead and a160_phase > 0
	a160_phase_elapsed += delta

	if is_playing and not is_dead and player_ctrl != null and player_ctrl.has_gummy and player_ctrl.active_tool == 1 and not player_ctrl.is_covering_gummy:
		var is_shaking: bool = (player_ctrl.vm_shake_time > 0.01) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or bool(player_ctrl.shaking_gummy)
		if is_shaking and a160_phase in [1, 2, 3]:
			var to_ent := (a160_node.global_position + Vector3.UP * 1.0) - cam.global_position
			var dist := to_ent.length()
			if dist < 14.0:
				var fwd := -cam.global_transform.basis.z
				if fwd.dot(to_ent.normalized()) > 0.38:
					_a160_trigger_banish_local()
					if is_authority() and net != null and net.is_online():
						net.broadcast_entity_event({"k": "a160_banish"}, true)
					elif not is_authority() and net != null and net.is_online():
						net.send_entity_event({"k": "a160_banish"}, true)
					return

	if a160_phase == 1:
		if is_instance_valid(a160_avatar):
			a160_avatar.update_pose(delta, a160_phase_elapsed, 0.0, 0.0, 0.0, 0.0, false, false, true, false, false, 0.0, false)
			if a160_avatar.skeleton != null and a160_avatar._b_head >= 0:
				var local_to_cam := a160_node.to_local(cam.global_position)
				var target_yaw := clampf(atan2(-local_to_cam.x, -local_to_cam.z), -1.35, 1.35)
				var dist_xz := Vector2(local_to_cam.x, local_to_cam.z).length()
				var target_pitch := clampf(atan2(local_to_cam.y - 1.48, maxf(dist_xz, 0.1)), -0.6, 0.6)
				var q_track := Quaternion.from_euler(Vector3(target_pitch, target_yaw, 0.0))
				a160_avatar.skeleton.set_bone_pose_rotation(a160_avatar._b_head, q_track)

		if room_mgr.current_room_idx > a160_room_idx:
			_a160_dissolve()
			return

		if is_authority():
			var p_pos := player_body.global_position
			var ent_pos := a160_node.global_position
			var dist := p_pos.distance_to(ent_pos)

			# Fair proximity aggro radius: 1.55m (down from 3.0m so corridor can be traversed)
			if dist < 1.55:
				_a160_trigger_alert_local()
				if net != null and net.is_online():
					net.broadcast_entity_event({"k": "a160_alert"}, true)
				return

			var to_ent := (ent_pos + Vector3.UP * 1.0) - cam.global_position
			var fwd := -cam.global_transform.basis.z
			if player_ctrl.light_on and dist < 16.0 and fwd.dot(to_ent.normalized()) > 0.88:
				a160_stare_timer += delta
				if a160_stare_timer >= 2.2:
					_a160_trigger_alert_local()
					if net != null and net.is_online():
						net.broadcast_entity_event({"k": "a160_alert"}, true)
					return
			else:
				a160_stare_timer = maxf(a160_stare_timer - delta * 0.8, 0.0)

	elif a160_phase == 2:
		a160_timer -= delta
		a160_neck_tilt = lerpf(a160_neck_tilt, 0.85, minf(delta * 20.0, 1.0))
		if is_instance_valid(a160_avatar) and a160_avatar.skeleton != null and a160_avatar._b_head >= 0:
			var head_q := Quaternion.from_euler(Vector3(0.0, 0.0, a160_neck_tilt))
			a160_avatar.skeleton.set_bone_pose_rotation(a160_avatar._b_head, head_q)

		if is_instance_valid(a160_avatar) and is_instance_valid(a160_avatar.spot_light):
			a160_avatar.spot_light.light_energy = 3.2 if randf() < 0.6 else 0.0
			a160_avatar.spot_light.light_color = Color(0.95, 0.15, 0.15)

		player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.04)

		if a160_timer <= 0.0:
			if is_authority():
				var l_target := player_body.global_position
				_a160_trigger_lunge_local(l_target)
				if net != null and net.is_online():
					net.broadcast_entity_event({"k": "a160_lunge", "tgt": [l_target.x, l_target.y, l_target.z]}, true)

	elif a160_phase == 3:
		a160_timer -= delta
		var to_tgt := (a160_lunge_target - a160_node.global_position)
		to_tgt.y = 0.0
		var dist := to_tgt.length()
		if dist > 0.12:
			var move_step := to_tgt.normalized() * a160_lunge_speed * delta
			if move_step.length() > dist:
				move_step = to_tgt
			a160_node.global_position += move_step
			a160_node.rotation.y = atan2(-to_tgt.x, -to_tgt.z)

		if is_instance_valid(a160_avatar):
			a160_avatar.update_pose(delta, a160_phase_elapsed * 4.0, a160_phase_elapsed * 16.0, 1.0, 1.0, 0.0, false, false, false, false, false, 0.0, false)
			if a160_avatar.skeleton != null:
				if a160_avatar._b_arm_l >= 0:
					a160_avatar.skeleton.set_bone_pose_rotation(a160_avatar._b_arm_l, Quaternion.from_euler(Vector3(-1.75, -0.3, 0.1)))
				if a160_avatar._b_arm_r >= 0:
					a160_avatar.skeleton.set_bone_pose_rotation(a160_avatar._b_arm_r, Quaternion.from_euler(Vector3(-1.75, 0.3, -0.1)))

		var p_dist := a160_node.global_position.distance_to(player_body.global_position)
		if p_dist < 1.35 and not a160_hit_done:
			a160_hit_done = true
			if player_ctrl.is_hiding:
				audio.play_a085_door_slam()
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.075)
				_a160_dissolve()
			else:
				game.damage_player(65, "A-160", Color(0.85, 0.1, 0.1, 0.8), {"a160_mimic": true})
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.12)
				_a160_dissolve()
			return

		if a160_timer <= 0.0:
			_a160_dissolve()

	elif a160_phase == 4:
		a160_timer -= delta
		var alpha := clampf(a160_timer / 0.75, 0.0, 1.0)
		if is_instance_valid(a160_avatar) and is_instance_valid(a160_avatar.body_mesh):
			a160_avatar.body_mesh.transparency = 1.0 - alpha
		if is_instance_valid(a160_avatar) and is_instance_valid(a160_avatar.spot_light):
			a160_avatar.spot_light.light_energy = alpha * 1.5
		if a160_timer <= 0.0:
			_reset_a160_state()
			if is_authority() and net != null and net.is_online():
				net.broadcast_entity_event({"k": "a160_end"}, true)
