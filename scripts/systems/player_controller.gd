class_name PlayerController
extends Node

## Handles local player physics, stamina, wet floor, noclip, camera look/FOV/bob,
## flashlight & gummy shakerlight logic, first-person dummi hand/viewmodel, and hiding transitions.

var game: Node3D = null
var player_body: CharacterBody3D = null
var player_col: CollisionShape3D = null
var cam: Camera3D = null
var flashlight: SpotLight3D = null
var audio: RoomsAudio = null
var assets: RoomAssets = null
var settings: SettingsManager = null
var admin: AdminController = null
var room_mgr: RoomManager = null
var avatar_mgr: AvatarManager = null
var net: RoomsNet = null

# Movement & Stamina
var is_sprinting := false
var stamina := 1.0
var stamina_regen_delay := 0.0
var exhausted := false
var pant_timer := 0.0
var pant_inhale := false

# Camera & Look
var target_yaw := 0.0
var target_pitch := 0.0
var yaw := 0.0
var pitch := 0.0
var cam_roll := 0.0
var fov := 75.0
var step_timer := 0.0
var bob_phase := 0.0
var shake_amount := 0.0
var revive_heartbeat_timer := 0.0
var revive_beat_accum := 0.0
var revive_last_beat_idx := -1
var revive_cam_offset := Vector3.ZERO
var revive_cam_rot := Vector3.ZERO

# Hand & Door Animations
var door_hand_timer := 0.0
var door_hand_slam := false
var battery_inspect_timer := 0.0
var pickup_hand_timer := 0.0
var vm_equip_t := 1.0
var vm_click_jolt := 0.0
var damage_kick := 0.0
var door_tp_t := 1.0
var door_tp_from := Vector3.ZERO
var door_tp_to := Vector3.ZERO
var door_tp_dur := 0.22

# Locker / Fridge / Under-Desk Hiding
var is_hiding := false
var hiding_room_idx := -1
var hiding_locker_idx := -1
var locker_fwd := Vector3.FORWARD
var locker_eye := Vector3.ZERO
var locker_exit := Vector3.ZERO
var target_hide_yaw := 0.0
var target_hide_pitch := 0.0
var hide_yaw_offset := 0.0
var hide_pitch_offset := 0.0
var hide_time := 0.0
var locker_transition_t := 1.0
var locker_transition_entering := false
var locker_transition_duration := 1.00
var locker_exit_face_locker := false
var locker_exit_from_yaw := 0.0
var locker_exit_to_yaw := 0.0
var locker_cam_from := Vector3.ZERO
var hiding_kind := "locker"
var hiding_door_pivot: Node3D = null
var hiding_eye_local_y := 1.48
var locker_enter_from_yaw := 0.0
var hiding_door_lifted := false
var a085_grab_locked := false
var breach_knockback_t := 0.0
var breach_land_dip := 0.0

# Flashlights & Batteries
var light_on := true
var active_tool := 0 # 0 = standard, 1 = gummy
var has_gummy := false
var std_battery := 150.0
var gummy_battery := 100.0
var batteries := 0
var was_light_before_hide := true
var std_low_power := false
var std_low_power_regen := 0.0
var std_low_flicker_t := 0.0
var is_shaking_gummy := false
var is_covering_gummy := false
var cover_hand_blend := 0.0
var rmb_held := false

# Viewmodel nodes
var vm_holder: Node3D = null
var vm_std: Node3D = null
var vm_gummy: Node3D = null
var vm_std_bulb: MeshInstance3D = null
var vm_gummy_bulb: MeshInstance3D = null
var vm_shake_time := 0.0
var gummy_hold_accum := 0.0
var gummy_pump_phase := 0.0
var vm_bulb_on_mat: StandardMaterial3D
var vm_bulb_off_mat: StandardMaterial3D
var vm_gummy_on_mat: StandardMaterial3D
var anim_hand: Node3D = null
var cover_hand: Node3D = null
var held_battery: Node3D = null
var ambient_dust: CPUParticles3D = null

# Mobile input inputs fed from UI/Input
var joy_vec := Vector2.ZERO
var mobile_sprint_held := false
var mobile_gummy_held := false


func initialize(
	p_game: Node3D,
	p_body: CharacterBody3D,
	p_col: CollisionShape3D,
	p_cam: Camera3D,
	p_flash: SpotLight3D,
	p_audio: RoomsAudio,
	p_assets: RoomAssets,
	p_settings: SettingsManager,
	p_admin: AdminController,
	p_room_mgr: RoomManager,
	p_avatar_mgr: AvatarManager,
	p_net: RoomsNet
) -> void:
	game = p_game
	player_body = p_body
	player_col = p_col
	cam = p_cam
	flashlight = p_flash
	audio = p_audio
	assets = p_assets
	settings = p_settings
	admin = p_admin
	room_mgr = p_room_mgr
	avatar_mgr = p_avatar_mgr
	net = p_net
	build_viewmodel()
	_build_ambient_dust()


func _build_ambient_dust() -> void:
	if cam == null:
		return
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var dx := (float(x) + 0.5) / 16.0 - 0.5
			var dy := (float(y) + 0.5) / 16.0 - 0.5
			var d := sqrt(dx * dx + dy * dy) * 2.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(0.92, 0.95, 1.0, a))
	var dot_tex := ImageTexture.create_from_image(img)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = dot_tex
	mat.albedo_color = Color(0.85, 0.90, 0.98, 0.24)
	mat.emission_enabled = true
	mat.emission = Color(0.42, 0.48, 0.58)
	mat.emission_energy_multiplier = 0.22
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false

	var quad := QuadMesh.new()
	quad.size = Vector2(0.024, 0.024)
	quad.material = mat

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.22, 1.0))
	curve.add_point(Vector2(0.78, 1.0))
	curve.add_point(Vector2(1.0, 0.0))

	ambient_dust = CPUParticles3D.new()
	ambient_dust.name = "AmbientDust"
	ambient_dust.position = Vector3(0.0, 0.0, -2.6)
	ambient_dust.mesh = quad
	ambient_dust.amount = 44
	ambient_dust.lifetime = 5.5
	ambient_dust.preprocess = 3.0
	ambient_dust.local_coords = false
	ambient_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ambient_dust.emission_box_extents = Vector3(3.2, 1.7, 3.2)
	ambient_dust.direction = Vector3(0.0, -0.35, 0.0)
	ambient_dust.spread = 180.0
	ambient_dust.gravity = Vector3(0.0, -0.018, 0.0)
	ambient_dust.initial_velocity_min = 0.02
	ambient_dust.initial_velocity_max = 0.08
	ambient_dust.scale_amount_min = 0.65
	ambient_dust.scale_amount_max = 1.45
	ambient_dust.scale_amount_curve = curve
	ambient_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(ambient_dust)


func set_dust_enabled(en: bool) -> void:
	if ambient_dust != null:
		ambient_dust.visible = en
		ambient_dust.emitting = en


func is_action_locked() -> bool:
	return locker_transition_t < 1.0 or door_hand_timer > 0.0 or battery_inspect_timer > 0.0


func build_viewmodel() -> void:
	vm_bulb_on_mat = StandardMaterial3D.new()
	vm_bulb_on_mat.albedo_color = Color(1.0, 0.96, 0.86)
	vm_bulb_on_mat.emission_enabled = true
	vm_bulb_on_mat.emission = Color(1.0, 0.95, 0.82)
	vm_bulb_on_mat.emission_energy_multiplier = 2.4

	vm_bulb_off_mat = StandardMaterial3D.new()
	vm_bulb_off_mat.albedo_color = Color(0.22, 0.24, 0.28)
	vm_bulb_off_mat.roughness = 0.25

	vm_gummy_on_mat = StandardMaterial3D.new()
	vm_gummy_on_mat.albedo_color = Color(0.32, 1.0, 0.52)
	vm_gummy_on_mat.emission_enabled = true
	vm_gummy_on_mat.emission = Color(0.28, 1.0, 0.48)
	vm_gummy_on_mat.emission_energy_multiplier = 2.6

	vm_holder = Node3D.new()
	vm_holder.position = Vector3(0.24, -0.21, -0.34)
	cam.add_child(vm_holder)

	# Standard tactical metal flashlight model
	vm_std = Node3D.new()
	vm_holder.add_child(vm_std)
	var body := assets.add_cached_cyl(vm_std, "StdBody", Vector3.ZERO, 0.024, 0.22, assets.locker_mat)
	body.rotation.x = PI * 0.5
	var grip := assets.add_cached_cyl(vm_std, "StdGrip", Vector3(0.0, 0.0, 0.02), 0.026, 0.11, assets.ceiling_mat)
	grip.rotation.x = PI * 0.5
	var head := assets.add_cached_cyl(vm_std, "StdBezel", Vector3(0.0, 0.0, -0.12), 0.034, 0.055, assets.metal_mat)
	head.rotation.x = PI * 0.5
	vm_std_bulb = assets.add_cached_cyl(vm_std, "StdLens", Vector3(0.0, 0.0, -0.148), 0.028, 0.008, vm_bulb_on_mat)
	vm_std_bulb.rotation.x = PI * 0.5
	assets.add_cached_box(vm_std, "StdBtn", Vector3(0.0, 0.025, -0.04), Vector3(0.016, 0.012, 0.024), assets.medkit_mat, false)

	# Emerald Gummy / Shaker Flashlight model
	vm_gummy = Node3D.new()
	vm_gummy.visible = false
	vm_holder.add_child(vm_gummy)
	assets.add_cached_box(vm_gummy, "GumBody", Vector3.ZERO, Vector3(0.068, 0.068, 0.19), assets.gummy_mat, false)
	assets.add_cached_box(vm_gummy, "GumGrip", Vector3(0.0, -0.015, 0.02), Vector3(0.072, 0.045, 0.11), assets.locker_mat, false)
	var gum_head := assets.add_cached_cyl(vm_gummy, "GumHead", Vector3(0.0, 0.0, -0.11), 0.040, 0.05, assets.fridge_mat)
	gum_head.rotation.x = PI * 0.5
	vm_gummy_bulb = assets.add_cached_cyl(vm_gummy, "GumLens", Vector3(0.0, 0.0, -0.136), 0.032, 0.008, vm_gummy_on_mat)
	vm_gummy_bulb.rotation.x = PI * 0.5

	# Dummi-styled First-Person Right Arm (replaces old Roblox Noob arm!)
	anim_hand = Node3D.new()
	anim_hand.name = "DummiHand"
	anim_hand.visible = false
	cam.add_child(anim_hand)
	var dummi_arm_mat := StandardMaterial3D.new()
	dummi_arm_mat.albedo_color = Color(0.92, 0.90, 0.85)
	dummi_arm_mat.roughness = 0.78
	dummi_arm_mat.emission_enabled = true
	dummi_arm_mat.emission = Color(0.85, 0.83, 0.78)
	dummi_arm_mat.emission_energy_multiplier = 0.08
	var arm_cyl := assets.add_cached_cyl(anim_hand, "DummiArmR", Vector3(0.0, 0.0, -0.24), 0.055, 0.50, dummi_arm_mat)
	arm_cyl.rotation.x = PI * 0.5
	var hand_cap := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.058
	sph.height = 0.116
	sph.radial_segments = 12
	sph.rings = 8
	hand_cap.mesh = sph
	hand_cap.material_override = dummi_arm_mat
	hand_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand_cap.position = Vector3(0.0, 0.0, -0.49)
	anim_hand.add_child(hand_cap)

	held_battery = Node3D.new()
	held_battery.name = "HeldBattery"
	held_battery.visible = false
	held_battery.position = Vector3(0.02, 0.05, -0.28)
	held_battery.rotation = Vector3(0.35, 0.15, 0.45)
	anim_hand.add_child(held_battery)
	assets.add_cached_cyl(held_battery, "Cell", Vector3.ZERO, 0.032, 0.11, assets.locker_mat)
	assets.add_cached_cyl(held_battery, "GlowBand", Vector3(0.0, 0.02, 0.0), 0.034, 0.028, assets.battery_mat)
	assets.add_cached_cyl(held_battery, "TopCap", Vector3(0.0, 0.052, 0.0), 0.033, 0.016, assets.plaque_yellow_mat)
	assets.add_cached_cyl(held_battery, "Nub", Vector3(0.0, 0.065, 0.0), 0.012, 0.012, assets.fridge_mat)

	# Second (Left) Dummi Hand for covering the Gummy Shakerlight lens against A-075!
	cover_hand = Node3D.new()
	cover_hand.name = "DummiCoverHandL"
	cover_hand.visible = false
	cam.add_child(cover_hand)
	var cov_arm := assets.add_cached_cyl(cover_hand, "CoverArmL", Vector3(-0.20, -0.02, 0.04), 0.052, 0.44, dummi_arm_mat)
	cov_arm.rotation.z = PI * 0.46
	cov_arm.rotation.y = -0.15
	var cov_palm_mesh := MeshInstance3D.new()
	var cov_sph := SphereMesh.new()
	cov_sph.radius = 0.058
	cov_sph.height = 0.116
	cov_sph.radial_segments = 12
	cov_sph.rings = 8
	cov_palm_mesh.mesh = cov_sph
	cov_palm_mesh.material_override = dummi_arm_mat
	cov_palm_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cov_palm_mesh.position = Vector3(0.015, 0.0, 0.0)
	cov_palm_mesh.scale = Vector3(1.12, 0.95, 0.72)
	cover_hand.add_child(cov_palm_mesh)


func is_light_exposed() -> bool:
	if is_hiding:
		return false
	if active_tool == 0:
		return light_on and std_battery > 0.05
	if not has_gummy or gummy_battery <= 0.05:
		return false
	return not is_covering_gummy


func reset_for_run(start_room: int = 0) -> void:
	stamina = 1.0
	stamina_regen_delay = 0.0
	exhausted = false
	is_sprinting = false
	door_hand_timer = 0.0
	door_hand_slam = false
	battery_inspect_timer = 0.0
	pickup_hand_timer = 0.0
	vm_equip_t = 1.0
	vm_click_jolt = 0.0
	damage_kick = 0.0
	pant_timer = 0.0
	door_tp_t = 1.0

	is_hiding = false
	hiding_room_idx = -1
	hiding_locker_idx = -1
	hiding_kind = "locker"
	hiding_door_pivot = null
	hiding_eye_local_y = 1.48
	locker_transition_t = 1.0
	locker_transition_duration = 1.00
	target_hide_yaw = 0.0
	target_hide_pitch = 0.0
	hide_yaw_offset = 0.0
	hide_pitch_offset = 0.0
	hide_time = 0.0
	if player_col != null:
		player_col.disabled = false

	light_on = true
	active_tool = 0
	has_gummy = false
	std_battery = 150.0
	gummy_battery = 100.0
	batteries = 0
	if start_room >= 50:
		batteries = 2
	if start_room >= 150:
		batteries = 4
	std_low_power = false
	std_low_power_regen = 0.0
	std_low_flicker_t = 0.0
	vm_shake_time = 0.0
	gummy_hold_accum = 0.0
	gummy_pump_phase = 0.0
	rmb_held = false
	is_shaking_gummy = false
	is_covering_gummy = false
	cover_hand_blend = 0.0

	if vm_holder != null:
		vm_holder.visible = true
	if anim_hand != null:
		anim_hand.visible = false
	if cover_hand != null:
		cover_hand.visible = false

	if player_body != null:
		player_body.position = Vector3(0.0, 0.05, 4.0)
		player_body.velocity = Vector3.ZERO
		player_body.rotation = Vector3.ZERO
	target_yaw = 0.0
	target_pitch = 0.0
	yaw = 0.0
	pitch = 0.0
	cam_roll = 0.0
	hiding_door_lifted = false
	a085_grab_locked = false
	breach_knockback_t = 0.0
	breach_land_dip = 0.0
	fov = settings.base_fov if settings != null else 75.0
	if cam != null:
		cam.fov = fov
		cam.position = Vector3(0.0, 1.48, 0.0)
		cam.rotation = Vector3.ZERO
		apply_camera_rotation()
	if flashlight != null:
		flashlight.visible = true


func equip_gummy() -> void:
	has_gummy = true
	gummy_battery = 100.0
	if active_tool != 1:
		active_tool = 1
		vm_equip_t = 0.0
		rmb_held = false
		light_on = true
		audio.play_flashlight_click()


func set_active_tool(tool_idx: int) -> void:
	if tool_idx == 1 and has_gummy:
		equip_gummy()


func trigger_pickup_anim() -> void:
	pickup_hand_timer = 0.28


func trigger_damage_kick(amount: float = 0.14) -> void:
	damage_kick = maxf(damage_kick, amount)


func trigger_revive_heartbeat() -> void:
	revive_heartbeat_timer = 2.4
	revive_beat_accum = 0.0
	revive_last_beat_idx = -1


func process_a075_blind_death_pose(delta: float, prog: float) -> void:
	# Both Dummi hands fly up across the screen to shield the player's blinded eyes while camera recoils!
	var recoil := ease(clampf(prog * 1.45, 0.0, 1.0), 0.32)
	var fall := ease(clampf((prog - 0.35) / 0.65, 0.0, 1.0), 1.6)
	cam.fov = lerpf(cam.fov, 104.0 - 16.0 * fall, clampf(1.0 - exp(-10.0 * delta), 0.0, 1.0))
	cam.rotation.x = lerpf(cam.rotation.x, clampf(pitch + 0.34 * recoil - 0.42 * fall, -1.35, 1.35), clampf(1.0 - exp(-11.0 * delta), 0.0, 1.0))
	cam.rotation.z = lerpf(cam.rotation.z, 0.42 * recoil + 0.32 * fall, clampf(1.0 - exp(-9.0 * delta), 0.0, 1.0))
	cam.position.y = lerpf(cam.position.y, 1.48 - 0.62 * fall, clampf(1.0 - exp(-7.0 * delta), 0.0, 1.0))
	if vm_holder != null:
		vm_holder.position = vm_holder.position.lerp(Vector3(0.42, -0.58, -0.18), clampf(1.0 - exp(-10.0 * delta), 0.0, 1.0))
	if anim_hand != null:
		anim_hand.visible = true
		anim_hand.position = anim_hand.position.lerp(Vector3(0.10, -0.02, -0.22), clampf(1.0 - exp(-14.0 * delta), 0.0, 1.0))
		anim_hand.rotation = anim_hand.rotation.lerp(Vector3(0.32, 0.58, -0.45), clampf(1.0 - exp(-14.0 * delta), 0.0, 1.0))
	if cover_hand != null:
		cover_hand.visible = true
		cover_hand.position = cover_hand.position.lerp(Vector3(-0.08, 0.02, -0.24), clampf(1.0 - exp(-14.0 * delta), 0.0, 1.0))
		cover_hand.rotation = cover_hand.rotation.lerp(Vector3(0.24, -0.42, 0.38), clampf(1.0 - exp(-14.0 * delta), 0.0, 1.0))


func apply_camera_rotation() -> void:
	player_body.rotation = Vector3(0.0, yaw, 0.0)
	var inspect_pitch := 0.0
	if battery_inspect_timer > 0.0:
		var prog := 2.0 - battery_inspect_timer
		if prog < 0.6:
			inspect_pitch = ease(prog / 0.6, 0.4) * 0.28
		elif prog < 1.4:
			inspect_pitch = 0.28
		else:
			inspect_pitch = ease((2.0 - prog) / 0.6, 0.4) * 0.28
	cam.rotation = Vector3(pitch + inspect_pitch + damage_kick * 0.65 + revive_cam_rot.x, 0.0, cam_roll + damage_kick * 0.85 + revive_cam_rot.z)
	cam.position = Vector3(0.0, 1.48 + revive_cam_offset.y, 0.0)


func begin_door_teleport(r: RoomScene) -> void:
	if r == null or not is_instance_valid(r.exit_anchor):
		return
	var door_pos := r.exit_anchor.global_position
	var flat := door_pos - player_body.global_position
	flat.y = 0.0
	var dist := flat.length()
	# Only micro-glide when reasonably close so opening from far (~3.4m) doesn't teleport abruptly across the room
	if dist < 0.30 or dist > 2.35:
		return
	var target := door_pos - flat.normalized() * 0.95
	target.y = player_body.global_position.y
	door_tp_from = player_body.global_position
	door_tp_to = target
	door_tp_t = 0.0
	door_tp_dur = 0.22 if dist > 1.6 else 0.16
	shake_amount = maxf(shake_amount, 0.009)


func toggle_flashlight(entities: EntityDirector, ui_mgr: UIManager) -> void:
	if is_action_locked():
		return
	if active_tool == 1:
		light_on = true
		return
	if std_battery <= 0.0 and not light_on:
		audio.play_flashlight_click()
		vm_click_jolt = 1.0
		return
	light_on = not light_on
	vm_click_jolt = 1.0
	audio.play_flashlight_click()
	if is_hiding and light_on and entities.darkness_phase > 0:
		if active_tool == 0 and not std_low_power and std_battery > 0.5:
			entities.repel_darkness_with_flashlight()
			hide_time = 0.0
			std_low_power = true
			std_battery = minf(std_battery, 30.0)
			std_low_power_regen = 0.0
			audio.play_flashlight_low_power()


func try_reload_flashlight(ui_mgr: UIManager) -> void:
	if is_action_locked() or active_tool != 0:
		return
	if std_battery >= 149.9 and not std_low_power:
		return
	if batteries < 2:
		return
	batteries -= 2
	std_battery = 150.0
	std_low_power = false
	std_low_power_regen = 0.0
	std_low_flicker_t = 0.0
	vm_equip_t = 0.0
	audio.play_pickup()


func try_shake_gummy(amount: float = 10.0) -> void:
	if is_action_locked() or active_tool != 1 or not has_gummy:
		return
	light_on = true
	gummy_battery = minf(gummy_battery + amount, 100.0)
	shake_amount = maxf(shake_amount, 0.012)
	vm_shake_time = 0.36
	audio.play_gummy_shake()


func enter_locker(r_idx: int, l_idx: int, entities: EntityDirector, ui_mgr: UIManager) -> void:
	if is_action_locked() or is_hiding:
		return
	if entities != null and entities.a075_active and entities.a075_phase == 3:
		return
	var r: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
	if r == null or l_idx < 0 or l_idx >= r.lockers.size():
		return
	if avatar_mgr.is_locker_occupied(r_idx, l_idx):
		return
	var locker_data: Dictionary = r.lockers[l_idx]
	if locker_data.get("broken", false):
		return
	var lnode: Node3D = locker_data["node"]

	is_hiding = true
	hiding_room_idx = r_idx
	hiding_locker_idx = l_idx
	hiding_kind = String(locker_data.get("kind", "locker"))
	hiding_door_pivot = locker_data.get("door_pivot") as Node3D
	hiding_door_lifted = false
	a085_grab_locked = false
	hide_time = 0.0
	entities.reset_darkness_state()
	target_hide_yaw = 0.0
	target_hide_pitch = 0.0
	hide_yaw_offset = 0.0
	hide_pitch_offset = 0.0
	target_pitch = 0.0
	pitch = 0.0
	was_light_before_hide = light_on
	if hiding_kind == "under_desk":
		light_on = false
	player_col.disabled = true
	if vm_holder != null:
		vm_holder.visible = false

	locker_cam_from = cam.global_position
	locker_transition_t = 0.0
	locker_transition_entering = true
	locker_transition_duration = 1.00

	var eye_loc: Vector3 = locker_data.get("eye_local", Vector3(0.0, 1.48, 0.05))
	var exit_loc: Vector3 = locker_data.get("exit_local", Vector3(0.0, 0.05, 1.05))
	hiding_eye_local_y = eye_loc.y

	var gt := lnode.global_transform
	locker_fwd = gt.basis.z.normalized()
	locker_enter_from_yaw = atan2(locker_fwd.x, locker_fwd.z)
	locker_eye = gt * eye_loc
	locker_exit = gt * exit_loc

	if is_instance_valid(hiding_door_pivot):
		var dp := hiding_door_pivot
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(dp, "rotation:y", -PI * 0.64, 0.28)
		tw.tween_interval(0.40)
		tw.tween_property(dp, "rotation:y", -0.05, 0.32)

	if hiding_kind == "under_desk":
		audio.play_desk_crawl(true)
	else:
		audio.play_locker_toggle(true)
	if net != null and net.is_online():
		net.broadcast_locker_action(r_idx, l_idx, true, false)


func exit_locker(face_locker: bool, entities: EntityDirector) -> void:
	if is_action_locked() or not is_hiding or a085_grab_locked:
		return
	if entities != null and entities.a075_active and entities.a075_phase == 3:
		return
	var prev_kind := hiding_kind
	var prev_door_pivot := hiding_door_pivot
	var was_door_lifted := hiding_door_lifted
	var prev_room_idx := hiding_room_idx
	var prev_locker_idx := hiding_locker_idx
	locker_cam_from = cam.global_position
	locker_transition_t = 0.0
	locker_transition_entering = false
	locker_exit_face_locker = face_locker
	locker_transition_duration = 0.70 if face_locker else 1.00

	is_hiding = false
	hiding_room_idx = -1
	hiding_locker_idx = -1
	hiding_kind = "locker"
	hiding_door_pivot = null
	hiding_door_lifted = false
	a085_grab_locked = false
	hiding_eye_local_y = 1.48
	entities.reset_darkness_state()

	player_body.position = locker_exit
	player_body.velocity = Vector3.ZERO
	player_col.disabled = false

	var exit_yaw := atan2(locker_fwd.x, locker_fwd.z) if face_locker else atan2(-locker_fwd.x, -locker_fwd.z)
	locker_exit_from_yaw = player_body.rotation.y
	locker_exit_to_yaw = exit_yaw + (0.0 if face_locker else hide_yaw_offset)
	target_yaw = locker_exit_to_yaw
	target_pitch = 0.0 if face_locker else hide_pitch_offset
	yaw = locker_exit_from_yaw
	pitch = cam.rotation.x
	target_hide_yaw = 0.0
	target_hide_pitch = 0.0
	hide_yaw_offset = 0.0
	hide_pitch_offset = 0.0
	light_on = true if active_tool == 1 else was_light_before_hide
	if vm_holder != null:
		vm_holder.visible = true

	if is_instance_valid(prev_door_pivot) and not was_door_lifted:
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
	if net != null and net.is_online() and prev_room_idx >= 0 and prev_locker_idx >= 0:
		net.broadcast_locker_action(prev_room_idx, prev_locker_idx, false, face_locker)


func force_leave_hiding_for_warp(entities: EntityDirector, ui_mgr: UIManager) -> void:
	locker_transition_t = 1.0
	locker_transition_entering = false
	door_hand_timer = 0.0
	if is_hiding and is_instance_valid(hiding_door_pivot):
		hiding_door_pivot.rotation.y = 0.0
	if is_hiding and hiding_room_idx >= 0 and hiding_locker_idx >= 0 and net != null and net.is_online():
		net.broadcast_locker_action(hiding_room_idx, hiding_locker_idx, false, false)
	is_hiding = false
	hiding_room_idx = -1
	hiding_locker_idx = -1
	hiding_kind = "locker"
	hiding_door_pivot = null
	hiding_eye_local_y = 1.48
	hide_time = 0.0
	entities.reset_darkness_state()
	hide_yaw_offset = 0.0
	hide_pitch_offset = 0.0
	target_hide_yaw = 0.0
	target_hide_pitch = 0.0
	ui_mgr.hide_locker_mask()
	player_col.disabled = false
	if vm_holder != null:
		vm_holder.visible = true
	if anim_hand != null:
		anim_hand.visible = false
	light_on = true if active_tool == 1 else was_light_before_hide


func force_eject_from_locker_breach(launch_vel: Vector3, ui_mgr: UIManager, entities: EntityDirector) -> void:
	locker_transition_t = 1.0
	locker_transition_entering = false

	var exit_pos := locker_exit + Vector3(0.0, 0.25, 0.0)
	if player_body != null:
		player_body.global_position = exit_pos
	if cam != null:
		cam.global_position = exit_pos + Vector3(0.0, 1.48, 0.0)

	var horiz_launch := Vector3(launch_vel.x, 0.0, launch_vel.z)
	var away_dir := horiz_launch.normalized() if horiz_launch.length() > 0.1 else locker_fwd
	var away_yaw := atan2(-away_dir.x, -away_dir.z)
	yaw = away_yaw
	target_yaw = away_yaw
	pitch = -0.08
	target_pitch = -0.08
	cam_roll = 0.28 if (randi() % 2 == 0) else -0.28
	if player_body != null:
		player_body.rotation.y = away_yaw
		player_body.velocity = launch_vel

	breach_knockback_t = 0.85
	breach_land_dip = 0.0
	trigger_damage_kick(0.45)
	shake_amount = 0.42

	if is_hiding and hiding_room_idx >= 0 and hiding_locker_idx >= 0 and net != null and net.is_online():
		net.broadcast_locker_action(hiding_room_idx, hiding_locker_idx, false, false)

	is_hiding = false
	hiding_room_idx = -1
	hiding_locker_idx = -1
	hiding_kind = "locker"
	hiding_door_pivot = null
	hiding_door_lifted = false
	a085_grab_locked = false
	hiding_eye_local_y = 1.48
	hide_time = 0.0
	entities.reset_darkness_state()
	hide_yaw_offset = 0.0
	hide_pitch_offset = 0.0
	target_hide_yaw = 0.0
	target_hide_pitch = 0.0
	ui_mgr.hide_locker_mask()
	if player_col != null:
		player_col.disabled = false
	if vm_holder != null:
		vm_holder.visible = true
	if anim_hand != null:
		anim_hand.visible = false
	light_on = true if active_tool == 1 else was_light_before_hide


func process_flashlight(delta: float, active_modifiers: Dictionary, entities: EntityDirector, ui_mgr: UIManager, rng: RandomNumberGenerator) -> void:
	if admin.inf_battery and admin.is_active(active_modifiers, net):
		std_battery = 150.0
		gummy_battery = 100.0
	if std_low_flicker_t > 0.0:
		std_low_flicker_t = maxf(std_low_flicker_t - delta, 0.0)
	if entities.a60_prime_flicker_gap_t > 0.0:
		entities.a60_prime_flicker_gap_t = maxf(entities.a60_prime_flicker_gap_t - delta, 0.0)
	if entities.a60_prime_flicker_snd_cd > 0.0:
		entities.a60_prime_flicker_snd_cd = maxf(entities.a60_prime_flicker_snd_cd - delta, 0.0)

	if active_tool == 1:
		light_on = true

	var has_charge := (std_battery > 0.0) if active_tool == 0 else (gummy_battery > 0.05)
	var is_lit := light_on and has_charge
	if is_lit:
		var power_mult := 1.0
		if active_tool == 0:
			if room_mgr.highest_opened >= 50:
				var prev_bat := std_battery
				std_battery = maxf(std_battery - delta, 0.0)
				if prev_bat > 30.0 and std_battery <= 30.0 and not std_low_power:
					std_low_power = true
					std_low_flicker_t = 0.85
					audio.play_flashlight_low_power()
				if std_battery <= 0.0:
					light_on = false
					audio.play_flashlight_click()
			if std_low_power:
				flashlight.light_color = Color(1.0, 0.78, 0.56)
				flashlight.spot_range = 14.0
				flashlight.spot_angle = 30.0
				power_mult = 0.44
			else:
				flashlight.light_color = Color(1.0, 0.96, 0.88)
				flashlight.spot_range = 24.0
				flashlight.spot_angle = 36.0
		else:
			gummy_battery = maxf(gummy_battery - delta * 10.0, 0.0)
			flashlight.light_color = Color(0.35, 1.0, 0.52)
			if is_covering_gummy:
				# Left hand covers the Gummy emitter: light is muffled to a faint glow around the fingers
				flashlight.spot_range = 2.0
				flashlight.spot_angle = 52.0
				power_mult = 0.04
			else:
				flashlight.spot_range = 20.0
				flashlight.spot_angle = 40.0
				if gummy_battery < 25.0:
					power_mult = clampf(0.32 + (gummy_battery / 25.0) * 0.68, 0.32, 1.0)

		var cur_bat := std_battery if active_tool == 0 else gummy_battery
		var flicker := 1.0
		if std_low_flicker_t > 0.0 and active_tool == 0:
			flicker = rng.randf_range(0.05, 0.75)
		elif entities.a60_prime_flicker_active and entities.a60_prime_flicker_gap_t <= 0.0:
			flicker = rng.randf_range(0.04, 0.92) if rng.randf() < 0.72 else 1.0
			if entities.a60_prime_flicker_snd_cd <= 0.0:
				entities.a60_prime_flicker_snd_cd = rng.randf_range(0.11, 0.19)
				audio.play_flashlight_flicker()
		elif cur_bat < 8.0 and rng.randf() < 0.22:
			flicker = rng.randf_range(0.25, 0.85)
		flashlight.light_energy = 2.6 * power_mult * flicker
		flashlight.visible = not (active_tool == 0 and std_battery <= 0.0)
	else:
		flashlight.visible = false

	if vm_std_bulb != null:
		vm_std_bulb.material_override = vm_bulb_on_mat if (is_lit and active_tool == 0) else vm_bulb_off_mat
	if vm_gummy_bulb != null:
		vm_gummy_bulb.material_override = vm_gummy_on_mat if (is_lit and active_tool == 1) else vm_bulb_off_mat


func process_movement(delta: float, active_modifiers: Dictionary, chat_open: bool, entities: EntityDirector, rng: RandomNumberGenerator) -> void:
	if door_tp_t < 1.0:
		door_tp_t = minf(door_tp_t + delta / maxf(door_tp_dur, 0.01), 1.0)
		var tp_p := ease(door_tp_t, 0.38)
		player_body.global_position = door_tp_from.lerp(door_tp_to, tp_p)
		player_body.velocity = Vector3.ZERO
		cam_roll = sin(tp_p * PI) * 0.055
		if door_tp_t >= 1.0:
			cam_roll = 0.0
		return

	if is_action_locked() or chat_open:
		player_body.velocity.x = 0.0
		player_body.velocity.z = 0.0
		player_body.move_and_slide()
		return

	if is_hiding:
		entities.process_darkness_in_hiding(delta)
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
	if joy_vec.length_squared() > 0.01:
		inp += joy_vec
	if inp.length_squared() > 1.0:
		inp = inp.normalized()

	var adm_on := admin.is_active(active_modifiers, net)
	if admin.noclip and adm_on:
		var cam_b: Basis = cam.global_transform.basis
		var fly_dir: Vector3 = (-cam_b.z) * -inp.y + cam_b.x * inp.x
		if Input.is_key_pressed(KEY_SPACE):
			fly_dir += Vector3.UP
		if Input.is_key_pressed(KEY_CTRL):
			fly_dir += Vector3.DOWN
		var fly_spd: float = 11.0 * admin.speed_mult
		if Input.is_key_pressed(KEY_SHIFT):
			fly_spd *= 2.2
		player_body.global_position += fly_dir * fly_spd * delta
		player_body.velocity = Vector3.ZERO
		return

	var moving := inp.length_squared() > 0.01
	var inf_stam := admin.inf_stamina and adm_on
	var wants_sprint := (Input.is_key_pressed(KEY_SHIFT) or mobile_sprint_held) and moving and (not exhausted) and (stamina > 0.01 or inf_stam)
	is_sprinting = wants_sprint
	if inf_stam:
		stamina = 1.0
		exhausted = false
	elif wants_sprint:
		var drain_rate := 0.75 if bool(active_modifiers.get("sprint_fatigue", false)) else 0.34
		stamina = maxf(stamina - delta * drain_rate, 0.0)
		stamina_regen_delay = 0.65
		if stamina <= 0.01:
			exhausted = true
			pant_timer = 0.08
	else:
		if stamina_regen_delay > 0.0:
			stamina_regen_delay = maxf(stamina_regen_delay - delta, 0.0)
		else:
			var rec_rate := 0.12 if exhausted else 0.22
			stamina = minf(stamina + delta * rec_rate, 1.0)
		if exhausted and stamina >= 0.35:
			exhausted = false

	if exhausted:
		pant_timer -= delta
		if pant_timer <= 0.0:
			pant_timer = 0.44
			audio.play_pant(pant_inhale)
			pant_inhale = not pant_inhale

	cam_roll = lerpf(cam_roll, -inp.x * 0.020, 1.0 - exp(-10.0 * delta))

	var speed := 3.7
	if wants_sprint:
		speed = 6.2
	elif exhausted:
		speed = 2.8
	if is_shaking_gummy:
		speed *= 0.5
	if adm_on:
		speed *= admin.speed_mult
	var dir := (player_body.transform.basis * Vector3(inp.x, 0.0, inp.y)).normalized()

	if breach_knockback_t > 0.0:
		breach_knockback_t = maxf(breach_knockback_t - delta, 0.0)
		var kb_drag := 1.15 if not player_body.is_on_floor() else 4.2
		player_body.velocity.x = lerpf(player_body.velocity.x, 0.0, minf(delta * kb_drag, 1.0))
		player_body.velocity.z = lerpf(player_body.velocity.z, 0.0, minf(delta * kb_drag, 1.0))
		if not player_body.is_on_floor() or player_body.velocity.y > 0.0:
			player_body.velocity.y -= 18.0 * delta
		else:
			if breach_land_dip < 0.05 and breach_knockback_t > 0.15:
				breach_land_dip = 0.58
				shake_amount = maxf(shake_amount, 0.24)
			player_body.velocity.y = 0.0
	else:
		var accel_factor := 1.65 if bool(active_modifiers.get("wet_floor", false)) else 11.0
		player_body.velocity.x = lerpf(player_body.velocity.x, dir.x * speed, minf(delta * accel_factor, 1.0))
		player_body.velocity.z = lerpf(player_body.velocity.z, dir.z * speed, minf(delta * accel_factor, 1.0))
		if not player_body.is_on_floor():
			player_body.velocity.y -= 18.0 * delta
		else:
			player_body.velocity.y = 0.0

	breach_land_dip = lerpf(breach_land_dip, 0.0, clampf(1.0 - exp(-5.5 * delta), 0.0, 1.0))
	player_body.move_and_slide()

	var horiz_spd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
	if horiz_spd > 0.7:
		bob_phase += delta * (10.5 if wants_sprint else 6.8) * (0.65 if is_shaking_gummy else 1.0)
		step_timer -= delta * (1.42 if wants_sprint else 0.90) * (0.55 if is_shaking_gummy else 1.0)
		if step_timer <= 0.0:
			step_timer = 0.48
			audio.play_step(wants_sprint, _detect_floor_surface())
	else:
		bob_phase = lerpf(bob_phase, 0.0, delta * 5.0)

	shake_amount = maxf(shake_amount - delta * 0.14, 0.0)
	var shake_off := Vector3(
		rng.randf_range(-shake_amount, shake_amount),
		rng.randf_range(-shake_amount, shake_amount),
		0.0
	)
	var bob_y := (sin(bob_phase) * 0.032) if settings.head_bob_enabled else 0.0
	var breath_bob := sin(float(Time.get_ticks_msec()) * 0.0055) * (0.022 if exhausted else 0.0)
	if locker_transition_t >= 1.0:
		cam.position = Vector3(0.0, 1.48 - breach_land_dip + bob_y + breath_bob, 0.0) + shake_off

	room_mgr.update_player_current_room(player_body.position, settings.room_vis_radius)


func _detect_floor_surface() -> String:
	for i in range(player_body.get_slide_collision_count()):
		var kc := player_body.get_slide_collision(i)
		if kc != null and kc.get_normal().y > 0.5:
			var col := kc.get_collider()
			if col != null and col.has_meta("floor_surface"):
				return String(col.get_meta("floor_surface"))
	var space_state := player_body.get_world_3d().direct_space_state
	if space_state != null:
		var p := player_body.global_position
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.35, 0), p - Vector3(0, 0.55, 0), 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var c: Object = hit.get("collider")
			if c != null and c.has_meta("floor_surface"):
				return String(c.get_meta("floor_surface"))
	return "carpet"


func process_camera_and_viewmodel(delta: float, lock_mask: ColorRect, a075_threat: bool = false) -> void:
	if revive_heartbeat_timer > 0.0:
		revive_heartbeat_timer = maxf(revive_heartbeat_timer - delta, 0.0)
		revive_beat_accum += delta
		var beat_cycle := 0.68
		var beat_idx := int(revive_beat_accum / beat_cycle)
		var beat_t := fmod(revive_beat_accum, beat_cycle)
		if beat_idx != revive_last_beat_idx:
			revive_last_beat_idx = beat_idx
			if audio != null:
				audio.play_heartbeat(lerpf(-1.0, 5.0, revive_heartbeat_timer / 2.4))
			if ui_mgr != null:
				ui_mgr.pulse_damage(0.50 * (revive_heartbeat_timer / 2.4))
		var pulse := 0.0
		if beat_t < 0.12:
			pulse = sin((beat_t / 0.12) * PI) * 0.10
		elif beat_t > 0.15 and beat_t < 0.25:
			pulse = sin(((beat_t - 0.15) / 0.10) * PI) * 0.06
		var weight := clampf(revive_heartbeat_timer / 2.4, 0.0, 1.0)
		revive_cam_offset.y = pulse * 0.85 * weight
		revive_cam_rot.x = -pulse * 0.75 * weight
		revive_cam_rot.z = pulse * 0.35 * weight
	else:
		revive_cam_offset = Vector3.ZERO
		revive_cam_rot = Vector3.ZERO

	var look_alpha := 1.0 - exp(-18.0 * delta)
	yaw = lerpf(yaw, target_yaw, look_alpha)
	pitch = lerpf(pitch, target_pitch, look_alpha)
	hide_yaw_offset = lerpf(hide_yaw_offset, target_hide_yaw, look_alpha)
	hide_pitch_offset = lerpf(hide_pitch_offset, target_hide_pitch, look_alpha)

	var target_fov := (settings.base_fov - 9.0) if is_hiding else settings.base_fov
	if not is_hiding:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		if hspd > 4.6:
			target_fov = settings.base_fov + 6.0
	fov = lerpf(fov, target_fov, 1.0 - exp(-10.0 * delta))
	cam.fov = fov

	if locker_transition_t < 1.0:
		var dur := maxf(locker_transition_duration, 0.05)
		locker_transition_t = minf(locker_transition_t + delta / dur, 1.0)

	if is_action_locked():
		mobile_gummy_held = false

	# Holding RMB with Gummy Shakerlight [2] during A-075 (or holding F anytime) covers the lens with the left hand!
	var rmb_active := mobile_gummy_held or (rmb_held and not settings.mobile_controls_enabled)
	var wants_cover := (not is_action_locked()) and (not is_hiding) and active_tool == 1 and has_gummy and ((a075_threat and rmb_active) or Input.is_key_pressed(KEY_F))
	is_covering_gummy = wants_cover
	cover_hand_blend = lerpf(cover_hand_blend, 1.0 if is_covering_gummy else 0.0, clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0))

	if cover_hand != null:
		var in_playing_state := (game == null or int(game.get("state")) == 0)
		cover_hand.visible = (cover_hand_blend > 0.02) and (not is_hiding) and in_playing_state
		if cover_hand.visible:
			var cb := ease(cover_hand_blend, 0.35)
			cover_hand.position = Vector3(-0.34, -0.44, -0.14).lerp(Vector3(0.18, -0.17, -0.46), cb)
			cover_hand.rotation = Vector3(-0.35, 0.25, 0.55).lerp(Vector3(0.10, -0.34, -0.12), cb)

	var shaking_gummy := (not is_action_locked()) and (not is_covering_gummy) and rmb_active and active_tool == 1 and has_gummy
	is_shaking_gummy = shaking_gummy
	if shaking_gummy:
		light_on = true
		gummy_battery = minf(gummy_battery + delta * 26.7, 100.0)
		gummy_pump_phase += delta * 15.0
		vm_shake_time = 0.14
		gummy_hold_accum += delta
		if gummy_hold_accum >= 0.36:
			gummy_hold_accum -= 0.36
			audio.play_gummy_shake()
	else:
		gummy_hold_accum = 0.0

	if is_hiding:
		if locker_transition_t < 1.0:
			var prev_t := maxf(locker_transition_t - delta / maxf(locker_transition_duration, 0.05), 0.0)
			if locker_transition_t >= 0.72 and prev_t < 0.72 and active_tool == 0:
				light_on = false
		if anim_hand != null:
			if hiding_kind != "under_desk" and locker_transition_t < 0.98:
				anim_hand.visible = true
				var p := locker_transition_t
				if p < 0.30:
					var rp := ease(p / 0.30, 0.35)
					anim_hand.position = Vector3(0.36, -0.26, -0.02).lerp(Vector3(0.14, -0.14, -0.16), rp)
					anim_hand.rotation = Vector3(0.05, 0.18 * rp, -0.14 * rp)
				elif p < 0.65:
					var sp := (p - 0.30) / 0.35
					anim_hand.position = Vector3(0.14, -0.14, -0.16).lerp(Vector3(-0.08, -0.12, -0.12), sin(sp * PI * 0.5))
					anim_hand.rotation = Vector3(0.0, 0.36 * sp, -0.10)
				else:
					var cp := (p - 0.65) / 0.35
					var swing := sin(cp * PI)
					anim_hand.position = Vector3(0.22, -0.16, -0.04).lerp(Vector3(0.34, -0.30, 0.04), cp) + Vector3(-0.18 * swing, 0.04 * swing, -0.12 * swing)
					anim_hand.rotation = Vector3(0.06 * swing, 0.26 * swing - 0.12 * cp, -0.10 * swing)
			else:
				anim_hand.visible = false
		if vm_holder != null:
			vm_holder.visible = (locker_transition_t >= 0.94 and (light_on or shaking_gummy))
			if vm_holder.visible:
				vm_std.visible = (active_tool == 0)
				vm_gummy.visible = (active_tool == 1)
				vm_holder.position = Vector3(0.18, -0.19, -0.28)
				_update_gummy_pump(delta, shaking_gummy)
		var t_ease := ease(locker_transition_t, 0.26)
		var base_yaw := atan2(-locker_fwd.x, -locker_fwd.z)
		player_body.global_position = locker_eye - Vector3(0.0, hiding_eye_local_y, 0.0)
		if locker_transition_t < 1.0 and hiding_kind != "under_desk":
			var turn_p := ease(clampf((locker_transition_t - 0.26) / 0.58, 0.0, 1.0), -2.0)
			player_body.rotation.y = lerp_angle(locker_enter_from_yaw, base_yaw + hide_yaw_offset, turn_p)
		else:
			player_body.rotation.y = lerp_angle(player_body.rotation.y, base_yaw + hide_yaw_offset, clampf(1.0 - exp(-14.0 * delta) + t_ease * 0.25, 0.0, 1.0))
		yaw = player_body.rotation.y
		target_yaw = yaw
		cam.rotation.x = lerpf(cam.rotation.x, hide_pitch_offset, 1.0 - exp(-16.0 * delta))
		var crawl_roll := sin(locker_transition_t * PI) * (0.07 if hiding_kind == "under_desk" else 0.03) if locker_transition_t < 1.0 else 0.0
		cam.rotation.z = lerpf(cam.rotation.z, crawl_roll, 1.0 - exp(-12.0 * delta))
		var max_mask := 0.0 if hiding_door_lifted else (0.20 if hiding_kind == "under_desk" else 0.36)
		shake_amount = maxf(shake_amount - delta * 0.14, 0.0)
		var hide_shake := Vector3(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
			0.0
		) if shake_amount > 0.001 else Vector3.ZERO
		if locker_transition_t < 1.0:
			if hiding_kind == "under_desk":
				var t_xz := ease(locker_transition_t, 0.32)
				var t_y := ease(locker_transition_t, 0.55)
				cam.global_position = Vector3(
					lerpf(locker_cam_from.x, locker_eye.x, t_xz),
					lerpf(locker_cam_from.y, locker_eye.y, t_y),
					lerpf(locker_cam_from.z, locker_eye.z, t_xz)
				) + hide_shake
			else:
				var move_p := clampf((locker_transition_t - 0.14) / 0.72, 0.0, 1.0)
				cam.global_position = locker_cam_from.lerp(locker_eye, ease(move_p, 0.28)) + hide_shake
			lock_mask.color = Color(0.0, 0.0, 0.0, lerpf(0.0, max_mask, t_ease))
			lock_mask.visible = (lock_mask.color.a > 0.004)
		else:
			cam.global_position = locker_eye + hide_shake
			var cur_a := lerpf(lock_mask.color.a, max_mask, clampf(1.0 - exp(-9.0 * delta), 0.0, 1.0))
			lock_mask.color = Color(0.0, 0.0, 0.0, cur_a)
			lock_mask.visible = (cur_a > 0.004)
	else:
		if locker_transition_t < 1.0 and not locker_transition_entering:
			var exit_turn_p := ease(clampf(locker_transition_t, 0.0, 1.0), -1.8)
			yaw = lerp_angle(locker_exit_from_yaw, locker_exit_to_yaw, exit_turn_p)
			target_yaw = locker_exit_to_yaw
		apply_camera_rotation()
		var fl_lag_x := clampf((target_pitch - pitch) * 0.45, -0.14, 0.14)
		var fl_lag_y := clampf((target_yaw - yaw) * 0.45, -0.18, 0.18)
		flashlight.rotation.x = lerpf(flashlight.rotation.x, fl_lag_x, 1.0 - exp(-14.0 * delta))
		flashlight.rotation.y = lerpf(flashlight.rotation.y, fl_lag_y, 1.0 - exp(-14.0 * delta))

		if door_hand_timer > 0.0:
			door_hand_timer = maxf(door_hand_timer - delta, 0.0)
		if pickup_hand_timer > 0.0:
			pickup_hand_timer = maxf(pickup_hand_timer - delta, 0.0)
		if vm_equip_t < 1.0:
			vm_equip_t = minf(vm_equip_t + delta / 0.24, 1.0)
		if vm_click_jolt > 0.0:
			vm_click_jolt = maxf(vm_click_jolt - delta * 6.5, 0.0)
		if damage_kick > 0.0:
			damage_kick = maxf(damage_kick - delta * 1.4, 0.0)

		_process_fp_hand(delta)

		if vm_holder != null:
			vm_holder.visible = true
			vm_std.visible = (active_tool == 0)
			vm_gummy.visible = (active_tool == 1)
			var hspd_vm := Vector2(player_body.velocity.x, player_body.velocity.z).length()
			var t_sec_vm := float(Time.get_ticks_msec()) * 0.001
			var bob_amp := clampf(hspd_vm / 5.5, 0.0, 1.0)
			var sprint_amt := 1.0 if is_sprinting else 0.0
			var bx := cos(t_sec_vm * (9.6 if is_sprinting else 7.2)) * (0.017 if is_sprinting else 0.011) * bob_amp + sin(t_sec_vm * 1.4) * 0.003
			var by := absf(sin(t_sec_vm * (9.6 if is_sprinting else 7.2))) * (-0.022 if is_sprinting else -0.014) * bob_amp + cos(t_sec_vm * 1.8) * 0.003
			var equip_dip := (1.0 - ease(vm_equip_t, 0.35)) * -0.22
			var click_kick := sin(vm_click_jolt * PI) * 0.018
			var dip_y := (-0.14 if (door_hand_timer > 0.0 or battery_inspect_timer > 0.0 or pickup_hand_timer > 0.0) else 0.0) + equip_dip
			var cov_x := -0.05 * cover_hand_blend
			var cov_y := 0.03 * cover_hand_blend
			vm_holder.position = vm_holder.position.lerp(Vector3(0.24 + bx + cov_x - 0.015 * sprint_amt, -0.21 + by + dip_y + cov_y - 0.012 * click_kick, -0.34 + 0.02 * click_kick), 1.0 - exp(-15.0 * delta))
			vm_holder.rotation.x = lerpf(vm_holder.rotation.x, fl_lag_x * 0.75 + 0.08 * cover_hand_blend - 0.10 * sprint_amt - 0.14 * click_kick + equip_dip * 2.4, 1.0 - exp(-15.0 * delta))
			vm_holder.rotation.y = lerpf(vm_holder.rotation.y, fl_lag_y * 0.75 + 0.16 * cover_hand_blend + 0.08 * sprint_amt, 1.0 - exp(-15.0 * delta))
			vm_holder.rotation.z = lerpf(vm_holder.rotation.z, -0.08 * sprint_amt + sin(t_sec_vm * 7.2) * 0.03 * bob_amp, 1.0 - exp(-14.0 * delta))
			_update_gummy_pump(delta, shaking_gummy)

		if locker_transition_t < 1.0:
			var t_out := ease(locker_transition_t, 0.26)
			var tgt_pos := player_body.global_position + Vector3(0.0, 1.48, 0.0)
			cam.global_position = locker_cam_from.lerp(tgt_pos, t_out)
			cam.rotation.z = lerpf(cam.rotation.z, sin(locker_transition_t * PI) * (-0.05 if locker_exit_face_locker else 0.03), 1.0 - exp(-14.0 * delta))
			lock_mask.color = Color(0.0, 0.0, 0.0, lerpf(0.32, 0.0, t_out))
			lock_mask.visible = (lock_mask.color.a > 0.004)
		else:
			lock_mask.color = Color(0.0, 0.0, 0.0, 0.0)
			lock_mask.visible = false


func _update_gummy_pump(delta: float, shaking_gummy: bool) -> void:
	if vm_shake_time > 0.0 or shaking_gummy:
		if not shaking_gummy:
			vm_shake_time = maxf(vm_shake_time - delta, 0.0)
			gummy_pump_phase += delta * 15.0
		var pump := sin(gummy_pump_phase)
		vm_gummy.position = vm_gummy.position.lerp(Vector3(0.0, pump * 0.085, -0.012 * cos(gummy_pump_phase)), 1.0 - exp(-22.0 * delta))
		vm_gummy.rotation = vm_gummy.rotation.lerp(Vector3(pump * 0.24, 0.0, 0.0), 1.0 - exp(-22.0 * delta))
	else:
		vm_gummy.position = vm_gummy.position.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
		vm_gummy.rotation = vm_gummy.rotation.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))


func _process_fp_hand(delta: float) -> void:
	if anim_hand == null:
		return
	if locker_transition_t < 0.96 and not locker_transition_entering:
		anim_hand.visible = true
		var p_out := locker_transition_t
		if locker_exit_face_locker:
			var s_p := sin(p_out * PI)
			anim_hand.position = Vector3(0.04, -0.12, -0.16).lerp(Vector3(0.32, -0.26, 0.02), p_out) + Vector3(-0.14 * s_p, 0.04 * s_p, -0.06 * s_p)
			anim_hand.rotation = Vector3(0.06, 0.36 * s_p - 0.20 * p_out, -0.14 * s_p)
		else:
			if p_out < 0.32:
				var r_p := ease(p_out / 0.32, 0.35)
				anim_hand.position = Vector3(0.30, -0.24, -0.02).lerp(Vector3(0.04, -0.09, -0.18), r_p)
				anim_hand.rotation = Vector3(0.06 * r_p, 0.16 * r_p, -0.14 * r_p)
			elif p_out < 0.68:
				var o_p := (p_out - 0.32) / 0.36
				anim_hand.position = Vector3(0.04, -0.09, -0.18).lerp(Vector3(-0.20, -0.10, -0.10), sin(o_p * PI * 0.5))
				anim_hand.rotation = Vector3(0.0, 0.42 * o_p, -0.10)
			else:
				var d_p := (p_out - 0.68) / 0.32
				anim_hand.position = Vector3(-0.20, -0.10, -0.10).lerp(Vector3(0.30, -0.28, 0.04), d_p)
				anim_hand.rotation = Vector3(-0.10 * d_p, -0.16 * d_p, 0.0)
	elif door_hand_timer > 0.0:
		anim_hand.visible = true
		var pd := 1.0 - clampf(door_hand_timer / 0.25, 0.0, 1.0)
		var reach_mul := 1.32 if door_hand_slam else 1.0
		if pd < 0.45:
			var rp_d := ease(pd / 0.45, 0.4)
			anim_hand.position = Vector3(0.32, -0.28, 0.02).lerp(Vector3(-0.04, -0.12, -0.24 * reach_mul), rp_d)
			anim_hand.rotation = Vector3(0.06 * rp_d, 0.24 * rp_d * reach_mul, -0.14 * rp_d)
		else:
			var sp_d := (pd - 0.45) / 0.55
			var push_arc := sin(sp_d * PI * 0.5)
			anim_hand.position = Vector3(-0.04, -0.12, -0.24 * reach_mul).lerp(Vector3(0.34, -0.30, 0.02), sp_d) + Vector3(0.18 * push_arc * reach_mul, 0.03 * push_arc, -0.08 * push_arc)
			anim_hand.rotation = Vector3(0.04, lerpf(0.24 * reach_mul, -0.45 * reach_mul, sp_d), -0.12 * (1.0 - sp_d))
	elif pickup_hand_timer > 0.0:
		anim_hand.visible = true
		if held_battery != null:
			held_battery.visible = false
		var pp := 1.0 - clampf(pickup_hand_timer / 0.28, 0.0, 1.0)
		var grab_arc := sin(pp * PI)
		anim_hand.position = Vector3(0.30, -0.32, 0.02).lerp(Vector3(0.06, -0.14, -0.26), grab_arc)
		anim_hand.rotation = Vector3(-0.18 * grab_arc, 0.22 * grab_arc, -0.16 * grab_arc)
	elif battery_inspect_timer > 0.0:
		battery_inspect_timer = maxf(battery_inspect_timer - delta, 0.0)
		anim_hand.visible = true
		if held_battery != null:
			held_battery.visible = true
		var prog := 2.0 - battery_inspect_timer
		if prog < 0.6:
			var t1 := ease(prog / 0.6, 0.4)
			anim_hand.position = Vector3(0.28, -0.36, -0.05).lerp(Vector3(0.11, -0.03, -0.25), t1)
			anim_hand.rotation = Vector3(-0.12, 0.22, 0.28).lerp(Vector3(0.26, -0.14, -0.18), t1)
		elif prog < 1.4:
			var t2 := (prog - 0.6) / 0.8
			var bob := sin(t2 * PI * 2.0) * 0.015
			anim_hand.position = Vector3(0.11, -0.03 + bob, -0.25)
			anim_hand.rotation = Vector3(0.26 + bob * 0.5, -0.14, -0.18)
		else:
			var t3 := ease((prog - 1.4) / 0.6, 1.8)
			anim_hand.position = Vector3(0.11, -0.03, -0.25).lerp(Vector3(0.32, -0.44, 0.02), t3)
			anim_hand.rotation = Vector3(0.26, -0.14, -0.18).lerp(Vector3(-0.15, 0.32, 0.12), t3)
		if battery_inspect_timer <= 0.0:
			if held_battery != null:
				held_battery.visible = false
			anim_hand.visible = false
	else:
		if held_battery != null:
			held_battery.visible = false
		anim_hand.visible = false
