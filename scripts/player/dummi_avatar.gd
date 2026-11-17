class_name DummiAvatar
extends Node3D

## Controls a dummi.glb character avatar (remote multiplayer peer OR live 3D face preview).
## Replaces the old Roblox Noob model with Skeleton3D bone animation and custom drawable Face texture.

const DUMMI_SCENE_PATH := "res://assets/models/player/dummi/dummi.glb"
const DUMMI_SCALE := 1.72 / 5.33 # Normalizes 5.33 model height to 1.72m player height

static var _cached_dummi_scene: PackedScene = null

var model_root: Node3D = null
var skeleton: Skeleton3D = null
var body_mesh: MeshInstance3D = null
var face_mat: StandardMaterial3D = null

var _b_torso := -1
var _b_head := -1
var _b_arm_l := -1
var _b_arm_r := -1
var _b_leg_l := -1
var _b_leg_r := -1

var _torso_rest := Vector3(0.0, 2.0, 0.0)

var arm_r_attach: BoneAttachment3D = null
var spot_light: SpotLight3D = null
var held_flash: Node3D = null
var held_gummy: Node3D = null
var held_battery: Node3D = null
var name_label: Label3D = null

var _torso_rot := Vector3.ZERO
var _torso_y := 2.0
var _head_rot := Vector3.ZERO
var _arm_l_rot := Vector3.ZERO
var _arm_r_rot := Vector3.ZERO
var _leg_l_rot := Vector3.ZERO
var _leg_r_rot := Vector3.ZERO


static func get_dummi_scene() -> PackedScene:
	if _cached_dummi_scene == null and ResourceLoader.exists(DUMMI_SCENE_PATH):
		_cached_dummi_scene = load(DUMMI_SCENE_PATH) as PackedScene
	return _cached_dummi_scene


func setup(assets: RoomAssets = null, bulb_on_mat: Material = null, gummy_on_mat: Material = null, with_gameplay_props: bool = true) -> void:
	var ps := get_dummi_scene()
	if ps != null:
		model_root = ps.instantiate() as Node3D
		model_root.name = "DummiModel"
		model_root.scale = Vector3.ONE * DUMMI_SCALE
		# dummi.glb faces +Z; Godot forward is -Z
		model_root.rotation.y = PI
		add_child(model_root)

		skeleton = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
		var anim_p := model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_p != null:
			anim_p.stop()

		body_mesh = model_root.find_child("Body", true, false) as MeshInstance3D
		if body_mesh != null:
			body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body_mesh.extra_cull_margin = 16384.0
			# Duplicate surface 1 (Face) material so each player has an independent custom face texture
			if body_mesh.mesh != null and body_mesh.mesh.get_surface_count() > 1:
				var src_mat := body_mesh.get_active_material(1)
				if src_mat == null:
					src_mat = body_mesh.mesh.surface_get_material(1)
				if src_mat is StandardMaterial3D:
					face_mat = (src_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					face_mat = StandardMaterial3D.new()
				face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				face_mat.roughness = 0.9
				face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				body_mesh.set_surface_override_material(1, face_mat)

		if skeleton != null:
			_b_torso = skeleton.find_bone("Torso")
			_b_head = skeleton.find_bone("Head")
			_b_arm_l = skeleton.find_bone("ArmL")
			_b_arm_r = skeleton.find_bone("ArmR")
			_b_leg_l = skeleton.find_bone("LegL")
			_b_leg_r = skeleton.find_bone("LegR")
			if _b_torso >= 0:
				_torso_rest = skeleton.get_bone_rest(_b_torso).origin
				_torso_y = _torso_rest.y

	if with_gameplay_props and assets != null:
		_build_gameplay_attachments(assets, bulb_on_mat, gummy_on_mat)


func _build_gameplay_attachments(assets: RoomAssets, bulb_on_mat: Material, gummy_on_mat: Material) -> void:
	var attach_parent: Node3D = self
	var inv_sc := 1.0
	if skeleton != null and _b_arm_r >= 0:
		arm_r_attach = BoneAttachment3D.new()
		arm_r_attach.name = "ArmRAttach"
		arm_r_attach.bone_name = "ArmR"
		skeleton.add_child(arm_r_attach)
		attach_parent = arm_r_attach
		inv_sc = 1.0 / DUMMI_SCALE

	var held := Node3D.new()
	held.name = "HeldTool"
	# Hand tip is at -Y along ArmR in dummi space; align tool forward along +Z (which rotates to -Z when arm raises)
	held.position = Vector3(0.0, -1.72, 0.22) if arm_r_attach != null else Vector3(0.42, 1.05, -0.35)
	held.rotation.y = PI if arm_r_attach != null else 0.0
	held.scale = Vector3.ONE * inv_sc
	attach_parent.add_child(held)

	spot_light = SpotLight3D.new()
	spot_light.position = Vector3(0.0, 0.0, -0.16)
	spot_light.light_color = Color(1.0, 0.96, 0.88)
	spot_light.light_energy = 1.9
	spot_light.spot_range = 17.0
	spot_light.spot_angle = 38.0
	spot_light.shadow_enabled = false
	held.add_child(spot_light)

	held_flash = Node3D.new()
	held_flash.name = "HeldFlashlight"
	held.add_child(held_flash)
	var hf_body := assets.add_cached_cyl(held_flash, "StdBody", Vector3.ZERO, 0.024, 0.22, assets.locker_mat)
	hf_body.rotation.x = PI * 0.5
	var hf_bezel := assets.add_cached_cyl(held_flash, "StdBezel", Vector3(0.0, 0.0, -0.12), 0.034, 0.055, assets.metal_mat)
	hf_bezel.rotation.x = PI * 0.5
	var hf_lens := assets.add_cached_cyl(held_flash, "StdLens", Vector3(0.0, 0.0, -0.148), 0.028, 0.008, bulb_on_mat if bulb_on_mat != null else assets.lamp_on_mat)
	hf_lens.rotation.x = PI * 0.5

	held_gummy = Node3D.new()
	held_gummy.name = "HeldGummy"
	held_gummy.visible = false
	held.add_child(held_gummy)
	assets.add_cached_box(held_gummy, "GumBody", Vector3.ZERO, Vector3(0.068, 0.068, 0.19), assets.gummy_mat, false)
	assets.add_cached_box(held_gummy, "GumGrip", Vector3(0.0, -0.015, 0.02), Vector3(0.072, 0.045, 0.11), assets.locker_mat, false)
	var hg_head := assets.add_cached_cyl(held_gummy, "GumHead", Vector3(0.0, 0.0, -0.11), 0.040, 0.05, assets.fridge_mat)
	hg_head.rotation.x = PI * 0.5
	var hg_lens := assets.add_cached_cyl(held_gummy, "GumLens", Vector3(0.0, 0.0, -0.136), 0.032, 0.008, gummy_on_mat if gummy_on_mat != null else assets.gummy_mat)
	hg_lens.rotation.x = PI * 0.5

	held_battery = Node3D.new()
	held_battery.name = "HeldBattery"
	held_battery.visible = false
	held.add_child(held_battery)
	var hb := assets.add_cached_cyl(held_battery, "Cell", Vector3.ZERO, 0.03, 0.12, assets.battery_mat)
	hb.rotation.x = PI * 0.5

	name_label = Label3D.new()
	name_label.position = Vector3(0.0, 2.02, 0.0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.font_size = 30
	name_label.pixel_size = 0.004
	name_label.modulate = Color(0.85, 0.96, 1.0)
	name_label.text = "Player"
	add_child(name_label)


func set_face_texture(tex: Texture2D) -> void:
	if face_mat != null and tex != null:
		face_mat.albedo_texture = tex


func update_pose(
	delta: float,
	idle_t: float,
	wp: float,
	wb: float,
	run_amt: float,
	pitch: float,
	is_hiding: bool,
	is_under_desk: bool,
	light_on: bool,
	is_inspecting: bool,
	is_door_hand: bool,
	inter_t: float,
	show_gummy: bool,
	is_covering: bool = false
) -> void:
	if is_instance_valid(held_battery):
		held_battery.visible = is_inspecting
	if is_inspecting:
		if is_instance_valid(held_flash):
			held_flash.visible = false
		if is_instance_valid(held_gummy):
			held_gummy.visible = false
	else:
		if is_instance_valid(held_flash):
			held_flash.visible = not show_gummy
		if is_instance_valid(held_gummy):
			held_gummy.visible = show_gummy

	if skeleton == null:
		return

	var anim_a := clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0)
	var leg_amp := lerpf(0.56, 0.90, run_amt) * wb
	var arm_amp := lerpf(0.50, 0.94, run_amt) * wb
	var sw := sin(wp)
	var cw := cos(wp)

	# Note: in dummi.glb model space (+Z forward), negative X rotation tilts forward / raises limb forward!
	var hide_drop := (-1.05 if is_under_desk else -0.45) if is_hiding else 0.0
	var tgt_torso_y := _torso_rest.y + hide_drop + sin(idle_t * 2.1) * 0.036 * (1.0 - wb * 0.6) + absf(sw) * 0.16 * wb
	var tgt_torso_rx := ((0.36 if is_under_desk else 0.20) if is_hiding else (0.04 + 0.11 * run_amt) * wb - sin(idle_t * 1.4) * 0.015 * (1.0 - wb))
	var tgt_torso_ry := cw * 0.09 * wb
	var tgt_torso_rz := sw * 0.032 * wb
	_torso_y = lerpf(_torso_y, tgt_torso_y, anim_a)
	_torso_rot = _torso_rot.lerp(Vector3(tgt_torso_rx, tgt_torso_ry, tgt_torso_rz), anim_a)

	var head_rx := -pitch * 0.72 - sin(idle_t * 1.6) * 0.025 * (1.0 - wb) - tgt_torso_rx * 0.35
	if is_inspecting:
		head_rx = minf(head_rx, -0.45)
	var head_ry := sin(idle_t * 0.85) * 0.05 * (1.0 - wb) - tgt_torso_ry * 0.5
	_head_rot = _head_rot.lerp(Vector3(head_rx, head_ry, 0.0), anim_a)

	var leg_l_rx := (-0.28 if is_hiding else -sw * leg_amp)
	var leg_r_rx := (0.22 if is_hiding else sw * leg_amp)
	_leg_l_rot = _leg_l_rot.lerp(Vector3(leg_l_rx, 0.0, 0.02), anim_a)
	_leg_r_rot = _leg_r_rot.lerp(Vector3(leg_r_rx, 0.0, -0.02), anim_a)

	var arm_l_rx := (-0.45 if is_hiding else (sw * arm_amp - sin(idle_t * 1.5) * 0.055 * (1.0 - wb)))
	var arm_l_ry := 0.0
	var arm_l_rz := 0.075 + 0.03 * sin(idle_t * 1.8) * (1.0 - wb) - (0.12 if is_hiding else 0.0)
	if is_covering and not is_hiding:
		# Reach left arm across chest to cover the Gummy flashlight lens!
		arm_l_rx = -1.48 - clampf(pitch * 0.65, -0.55, 0.55)
		arm_l_ry = -0.58
		arm_l_rz = -0.22
	_arm_l_rot = _arm_l_rot.lerp(Vector3(arm_l_rx, arm_l_ry, arm_l_rz), anim_a)

	var arm_r_rx := -sw * arm_amp - cos(idle_t * 1.5) * 0.055 * (1.0 - wb)
	var arm_r_ry := 0.0
	var arm_r_rz := -0.075 - 0.03 * sin(idle_t * 1.8) * (1.0 - wb)
	if is_inspecting:
		arm_r_rx = -2.15
		arm_r_ry = 0.22
		arm_r_rz = -0.35
	elif is_door_hand or inter_t > 0.0:
		var reach := 1.0 if is_door_hand else sin(clampf(inter_t / 0.85, 0.0, 1.0) * PI)
		arm_r_rx = lerpf(arm_r_rx, -1.48, reach)
		arm_r_ry = -reach * 0.34
		arm_r_rz = 0.16 * reach
	elif light_on:
		arm_r_rx = -1.42 - clampf(pitch * 0.78, -0.68, 0.68) - sw * 0.05 * wb
		arm_r_rz = -0.04
	elif is_hiding:
		arm_r_rx = -0.52
		arm_r_rz = 0.12
	_arm_r_rot = _arm_r_rot.lerp(Vector3(arm_r_rx, arm_r_ry, arm_r_rz), anim_a)

	if _b_torso >= 0:
		skeleton.set_bone_pose_position(_b_torso, Vector3(_torso_rest.x, _torso_y, _torso_rest.z))
		skeleton.set_bone_pose_rotation(_b_torso, Quaternion.from_euler(_torso_rot))
	if _b_head >= 0:
		skeleton.set_bone_pose_rotation(_b_head, Quaternion.from_euler(_head_rot))
	if _b_arm_l >= 0:
		skeleton.set_bone_pose_rotation(_b_arm_l, Quaternion.from_euler(_arm_l_rot))
	if _b_arm_r >= 0:
		skeleton.set_bone_pose_rotation(_b_arm_r, Quaternion.from_euler(_arm_r_rot))
	if _b_leg_l >= 0:
		skeleton.set_bone_pose_rotation(_b_leg_l, Quaternion.from_euler(_leg_l_rot))
	if _b_leg_r >= 0:
		skeleton.set_bone_pose_rotation(_b_leg_r, Quaternion.from_euler(_leg_r_rot))
