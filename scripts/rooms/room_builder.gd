class_name RoomBuilder
extends RefCounted

## Builds procedural 12x12m Rooms & Doors style corridors matching the RoomTypes templates.

const CELL_SIZE := 18.0
const HALF_CELL := 9.0
const HALF_W := 4.2
const CEIL_H := 3.8
const DOOR_W := 2.0
const DOOR_H := 2.75
const WALL_THICK := 0.22


class RoomInstance:
	var index: int = 0
	var room_type: String = ""
	var root: Node3D
	var exit_anchor: Node3D
	var grid_cell: Vector2i
	var in_dir: Vector3
	var out_dir: Vector3
	var center_pos: Vector3
	var exit_pos: Vector3
	var door_pivot: Node3D
	var door_collider: StaticBody3D
	var door_opened: bool = false
	var door_broken: bool = false
	var ceiling_lights: Array[OmniLight3D] = []
	var light_base_energies: Array[float] = []
	var lamp_meshes: Array[MeshInstance3D] = []
	var is_dark_room: bool = false
	var lockers: Array[Dictionary] = []
	var levers: Array[Dictionary] = []


class SharedAssets:
	var wall_mat: StandardMaterial3D
	var floor_mat: StandardMaterial3D
	var tile_floor_mat: StandardMaterial3D
	var grate_mat: StandardMaterial3D
	var ceiling_mat: StandardMaterial3D
	var metal_mat: StandardMaterial3D
	var locker_mat: StandardMaterial3D
	var locker_door_mat: StandardMaterial3D
	var door_mat: StandardMaterial3D
	var wood_mat: StandardMaterial3D
	var plank_dark_mat: StandardMaterial3D
	var plaque_yellow_mat: StandardMaterial3D
	var lamp_on_mat: StandardMaterial3D
	var lamp_off_mat: StandardMaterial3D
	var plant_pot_mat: StandardMaterial3D
	var plant_leaf_mat: StandardMaterial3D
	var cardboard_mat: StandardMaterial3D
	var glass_mat: StandardMaterial3D
	var rug_mat: StandardMaterial3D
	var mannequin_mat: StandardMaterial3D
	var counter_top_mat: StandardMaterial3D
	var fridge_mat: StandardMaterial3D
	var fabric_red_mat: StandardMaterial3D
	var battery_mat: StandardMaterial3D
	var gummy_mat: StandardMaterial3D
	var medkit_mat: StandardMaterial3D


static func create_shared_assets() -> SharedAssets:
	var a := SharedAssets.new()
	var wall_tex := RoomsTextures.make_wall_texture()
	var floor_tex := RoomsTextures.make_floor_texture()
	var tile_tex := RoomsTextures.make_tile_floor_texture()
	var grate_tex := RoomsTextures.make_metal_grate_texture()
	var wall_nrm := RoomsTextures.make_surface_normal(40401, 1.8, 0)
	var carpet_nrm := RoomsTextures.make_surface_normal(80802, 2.8, 0)
	var tile_nrm := RoomsTextures.make_surface_normal(50505, 2.4, 32)

	a.wall_mat = StandardMaterial3D.new()
	a.wall_mat.albedo_texture = wall_tex
	a.wall_mat.albedo_color = Color(0.92, 0.94, 0.98)
	a.wall_mat.normal_enabled = true
	a.wall_mat.normal_texture = wall_nrm
	a.wall_mat.normal_scale = 0.45
	a.wall_mat.roughness = 0.86
	a.wall_mat.uv1_scale = Vector3(3.0, 1.5, 3.0)

	a.floor_mat = StandardMaterial3D.new()
	a.floor_mat.albedo_texture = floor_tex
	a.floor_mat.normal_enabled = true
	a.floor_mat.normal_texture = carpet_nrm
	a.floor_mat.normal_scale = 0.65
	a.floor_mat.roughness = 0.92
	a.floor_mat.uv1_scale = Vector3(4.5, 4.5, 4.5)

	a.tile_floor_mat = StandardMaterial3D.new()
	a.tile_floor_mat.albedo_texture = tile_tex
	a.tile_floor_mat.normal_enabled = true
	a.tile_floor_mat.normal_texture = tile_nrm
	a.tile_floor_mat.normal_scale = 0.55
	a.tile_floor_mat.roughness = 0.48
	a.tile_floor_mat.uv1_scale = Vector3(4.0, 4.0, 4.0)

	a.grate_mat = StandardMaterial3D.new()
	a.grate_mat.albedo_texture = grate_tex
	a.grate_mat.metallic = 0.70
	a.grate_mat.roughness = 0.36
	a.grate_mat.uv1_scale = Vector3(3.0, 6.0, 3.0)

	a.ceiling_mat = StandardMaterial3D.new()
	a.ceiling_mat.albedo_color = Color(0.08, 0.09, 0.11)
	a.ceiling_mat.roughness = 0.95

	a.metal_mat = StandardMaterial3D.new()
	a.metal_mat.albedo_color = Color(0.24, 0.27, 0.32)
	a.metal_mat.metallic = 0.58
	a.metal_mat.roughness = 0.46

	a.locker_mat = StandardMaterial3D.new()
	a.locker_mat.albedo_color = Color(0.18, 0.21, 0.25)
	a.locker_mat.metallic = 0.48
	a.locker_mat.roughness = 0.52

	a.locker_door_mat = StandardMaterial3D.new()
	a.locker_door_mat.albedo_color = Color(0.24, 0.27, 0.32)
	a.locker_door_mat.metallic = 0.50
	a.locker_door_mat.roughness = 0.48

	a.door_mat = StandardMaterial3D.new()
	a.door_mat.albedo_color = Color(0.30, 0.24, 0.19)
	a.door_mat.roughness = 0.72

	a.wood_mat = StandardMaterial3D.new()
	a.wood_mat.albedo_color = Color(0.42, 0.29, 0.18)
	a.wood_mat.roughness = 0.74

	a.plank_dark_mat = StandardMaterial3D.new()
	a.plank_dark_mat.albedo_color = Color(0.26, 0.18, 0.12)
	a.plank_dark_mat.roughness = 0.80

	a.plaque_yellow_mat = StandardMaterial3D.new()
	a.plaque_yellow_mat.albedo_color = Color(0.84, 0.70, 0.22)
	a.plaque_yellow_mat.emission_enabled = true
	a.plaque_yellow_mat.emission = Color(0.55, 0.45, 0.12)
	a.plaque_yellow_mat.emission_energy_multiplier = 0.45
	a.plaque_yellow_mat.roughness = 0.4

	a.lamp_on_mat = StandardMaterial3D.new()
	a.lamp_on_mat.albedo_color = Color(0.92, 0.96, 1.0)
	a.lamp_on_mat.emission_enabled = true
	a.lamp_on_mat.emission = Color(0.84, 0.92, 1.0)
	a.lamp_on_mat.emission_energy_multiplier = 2.4

	a.lamp_off_mat = StandardMaterial3D.new()
	a.lamp_off_mat.albedo_color = Color(0.11, 0.12, 0.14)

	a.plant_pot_mat = StandardMaterial3D.new()
	a.plant_pot_mat.albedo_color = Color(0.56, 0.58, 0.62)
	a.plant_pot_mat.roughness = 0.78

	a.plant_leaf_mat = StandardMaterial3D.new()
	a.plant_leaf_mat.albedo_color = Color(0.12, 0.36, 0.14)
	a.plant_leaf_mat.roughness = 0.68

	a.cardboard_mat = StandardMaterial3D.new()
	a.cardboard_mat.albedo_color = Color(0.54, 0.40, 0.26)
	a.cardboard_mat.roughness = 0.88

	a.glass_mat = StandardMaterial3D.new()
	a.glass_mat.albedo_color = Color(0.42, 0.58, 0.72, 0.28)
	a.glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a.glass_mat.roughness = 0.15

	a.rug_mat = StandardMaterial3D.new()
	a.rug_mat.albedo_color = Color(0.58, 0.60, 0.64)
	a.rug_mat.roughness = 0.95

	a.mannequin_mat = StandardMaterial3D.new()
	a.mannequin_mat.albedo_color = Color(0.52, 0.54, 0.57)
	a.mannequin_mat.roughness = 0.75

	a.counter_top_mat = StandardMaterial3D.new()
	a.counter_top_mat.albedo_color = Color(0.28, 0.31, 0.36)
	a.counter_top_mat.roughness = 0.45

	a.fridge_mat = StandardMaterial3D.new()
	a.fridge_mat.albedo_color = Color(0.76, 0.79, 0.82)
	a.fridge_mat.roughness = 0.38

	a.fabric_red_mat = StandardMaterial3D.new()
	a.fabric_red_mat.albedo_color = Color(0.48, 0.12, 0.12)
	a.fabric_red_mat.roughness = 0.85

	a.battery_mat = StandardMaterial3D.new()
	a.battery_mat.albedo_color = Color(0.22, 0.85, 0.98)
	a.battery_mat.emission_enabled = true
	a.battery_mat.emission = Color(0.16, 0.75, 0.95)
	a.battery_mat.emission_energy_multiplier = 0.75
	a.battery_mat.roughness = 0.32

	a.gummy_mat = StandardMaterial3D.new()
	a.gummy_mat.albedo_color = Color(0.14, 0.72, 0.34)
	a.gummy_mat.emission_enabled = true
	a.gummy_mat.emission = Color(0.12, 0.65, 0.30)
	a.gummy_mat.emission_energy_multiplier = 0.25
	a.gummy_mat.roughness = 0.34

	a.medkit_mat = StandardMaterial3D.new()
	a.medkit_mat.albedo_color = Color(0.86, 0.08, 0.08)
	a.medkit_mat.emission_enabled = true
	a.medkit_mat.emission = Color(0.75, 0.06, 0.06)
	a.medkit_mat.emission_energy_multiplier = 0.35
	a.medkit_mat.roughness = 0.38
	return a


static func dir_to_grid_step(d: Vector3) -> Vector2i:
	return Vector2i(int(round(d.x)), int(round(d.z)))


static func rotate_left(d: Vector3) -> Vector3:
	return Vector3(d.z, 0.0, -d.x).normalized()


static func rotate_right(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0.0, d.x).normalized()


static func _pick_room_type(room_index: int, turn_type: int, rng: RandomNumberGenerator) -> String:
	if room_index == 0:
		return "lobby"
	if turn_type != 0:
		return "l_turn"
	var pool := [
		"locker_room",
		"three_locker",
		"new_2_locker",
		"desk_room",
		"meeting_room",
		"bookshelf_room",
		"storage_room",
		"kitchen",
		"table_room",
		"closet_room",
		"w_shaped",
	]
	if room_index >= 20:
		pool.append("double_plant")
	else:
		pool.append("plant_room")
	if room_index >= 10:
		pool.append("mannequin_room")
	if room_index >= 12:
		pool.append("bridge_room")
	return pool[rng.randi_range(0, pool.size() - 1)]


static func build_room(
	parent: Node3D,
	assets: SharedAssets,
	room_index: int,
	grid_cell: Vector2i,
	in_dir: Vector3,
	out_dir: Vector3,
	rng: RandomNumberGenerator,
	force_dark: bool = false,
	haste_enabled: bool = false
) -> RoomInstance:
	var r := RoomInstance.new()
	r.index = room_index
	r.grid_cell = grid_cell
	r.in_dir = in_dir
	r.out_dir = out_dir

	var cell_center := Vector3(float(grid_cell.x) * CELL_SIZE, 0.0, float(grid_cell.y) * CELL_SIZE)
	r.center_pos = cell_center
	r.exit_pos = cell_center + out_dir * (CELL_SIZE * 0.5)

	var room_node := Node3D.new()
	room_node.name = "Room_%03d" % room_index
	room_node.position = cell_center
	var yaw := atan2(-in_dir.x, -in_dir.z)
	room_node.rotation.y = yaw
	parent.add_child(room_node)
	r.root = room_node

	var local_out := (Basis(Vector3.UP, -yaw) * out_dir).normalized()
	var turn_type := 0
	if local_out.x < -0.5:
		turn_type = -1
	elif local_out.x > 0.5:
		turn_type = 1

	var rtype := _pick_room_type(room_index, turn_type, rng)
	r.room_type = rtype
	var is_lobby := (rtype == "lobby")
	# Dark rooms strictly do not appear before room 50 (unless force_dark / lights_out is enabled)
	r.is_dark_room = force_dark or (room_index == 50) or (room_index > 50 and not is_lobby and rng.randf() < 0.30)

	# 1. Shell Floor, Ceiling & Perimeter Walls
	if turn_type == 0:
		var floor_m := assets.floor_mat
		if rtype == "kitchen":
			floor_m = assets.tile_floor_mat

		if rtype == "bridge_room":
			_build_bridge_shell(room_node, assets, r)
		else:
			var floor_body := _add_box(room_node, "Floor", Vector3(0.0, -0.1, 0.0), Vector3(HALF_W * 2.0, 0.2, CELL_SIZE), floor_m)
			if rtype == "storage_room" or rtype == "locker_room":
				var grate_strip := _add_box(room_node, "MetalWalkway", Vector3(0.0, 0.008, 0.0), Vector3(3.1, 0.025, CELL_SIZE - 0.15), assets.grate_mat)
				grate_strip.set_meta("floor_surface", "metal")
			elif rtype == "kitchen":
				floor_body.set_meta("floor_surface", "carpet")
		_add_box(room_node, "Ceiling", Vector3(0.0, CEIL_H + 0.1, 0.0), Vector3(HALF_W * 2.0, 0.2, CELL_SIZE), assets.ceiling_mat)
		_add_box(room_node, "WallLeft", Vector3(-HALF_W - WALL_THICK * 0.5, CEIL_H * 0.5, 0.0), Vector3(WALL_THICK, CEIL_H, CELL_SIZE), assets.wall_mat)
		_add_box(room_node, "WallRight", Vector3(HALF_W + WALL_THICK * 0.5, CEIL_H * 0.5, 0.0), Vector3(WALL_THICK, CEIL_H, CELL_SIZE), assets.wall_mat)
	else:
		# L-turn: non-overlapping segments covering z = +HALF_CELL -> -HALF_W and exit arm ±HALF_W -> ±HALF_CELL
		var arm_z_len := HALF_CELL + HALF_W
		var arm_z_center := HALF_CELL - arm_z_len * 0.5
		_add_box(room_node, "FloorA", Vector3(0.0, -0.1, arm_z_center), Vector3(HALF_W * 2.0, 0.2, arm_z_len), assets.floor_mat)
		_add_box(room_node, "CeilA", Vector3(0.0, CEIL_H + 0.1, arm_z_center), Vector3(HALF_W * 2.0, 0.2, arm_z_len), assets.ceiling_mat)

		var side_len := HALF_CELL - HALF_W
		var sx := -HALF_W - side_len * 0.5 if turn_type == -1 else HALF_W + side_len * 0.5
		_add_box(room_node, "FloorB", Vector3(sx, -0.1, 0.0), Vector3(side_len, 0.2, HALF_W * 2.0), assets.floor_mat)
		_add_box(room_node, "CeilB", Vector3(sx, CEIL_H + 0.1, 0.0), Vector3(side_len, 0.2, HALF_W * 2.0), assets.ceiling_mat)

		var far_x_min := -HALF_CELL if turn_type == -1 else -HALF_W
		var far_x_max := HALF_W if turn_type == -1 else HALF_CELL
		_add_box(room_node, "WallFar", Vector3((far_x_min + far_x_max) * 0.5, CEIL_H * 0.5, -HALF_W - WALL_THICK * 0.5), Vector3(far_x_max - far_x_min, CEIL_H, WALL_THICK), assets.wall_mat)

		var inner_z := HALF_CELL - side_len * 0.5
		var inner_x := HALF_CELL - side_len * 0.5
		if turn_type == -1:
			_add_box(room_node, "WallOuterR", Vector3(HALF_W + WALL_THICK * 0.5, CEIL_H * 0.5, arm_z_center), Vector3(WALL_THICK, CEIL_H, arm_z_len), assets.wall_mat)
			_add_box(room_node, "WallInnerL", Vector3(-HALF_W - WALL_THICK * 0.5, CEIL_H * 0.5, inner_z), Vector3(WALL_THICK, CEIL_H, side_len), assets.wall_mat)
			_add_box(room_node, "WallInnerTurn", Vector3(-inner_x, CEIL_H * 0.5, HALF_W + WALL_THICK * 0.5), Vector3(side_len, CEIL_H, WALL_THICK), assets.wall_mat)
		else:
			_add_box(room_node, "WallOuterL", Vector3(-HALF_W - WALL_THICK * 0.5, CEIL_H * 0.5, arm_z_center), Vector3(WALL_THICK, CEIL_H, arm_z_len), assets.wall_mat)
			_add_box(room_node, "WallInnerR", Vector3(HALF_W + WALL_THICK * 0.5, CEIL_H * 0.5, inner_z), Vector3(WALL_THICK, CEIL_H, side_len), assets.wall_mat)
			_add_box(room_node, "WallInnerTurn", Vector3(inner_x, CEIL_H * 0.5, HALF_W + WALL_THICK * 0.5), Vector3(side_len, CEIL_H, WALL_THICK), assets.wall_mat)

	if is_lobby:
		_add_box(room_node, "LobbyBackWall", Vector3(0.0, CEIL_H * 0.5, HALF_CELL + WALL_THICK * 0.5), Vector3(HALF_W * 2.0, CEIL_H, WALL_THICK), assets.wall_mat)

	# 2. Exit Doorway Wall & Door
	var exit_anchor := Node3D.new()
	exit_anchor.name = "ExitAnchor"
	if turn_type == 0:
		exit_anchor.position = Vector3(0.0, 0.0, -HALF_CELL)
	elif turn_type == -1:
		exit_anchor.position = Vector3(-HALF_CELL, 0.0, 0.0)
		exit_anchor.rotation.y = PI * 0.5
	else:
		exit_anchor.position = Vector3(HALF_CELL, 0.0, 0.0)
		exit_anchor.rotation.y = -PI * 0.5
	room_node.add_child(exit_anchor)
	r.exit_anchor = exit_anchor
	_build_exit_door(exit_anchor, assets, room_index + 1, r)

	# 3. 2x2 Recessed Fluorescent Ceiling Lights
	_build_ceiling_grid(room_node, assets, not r.is_dark_room, r)

	# 4. Props matching RoomType
	_populate_room_type(room_node, assets, rtype, room_index, turn_type, rng, r)

	# Wall lever (used for Make Haste modifier time refills - strictly only when modifier is enabled)
	if haste_enabled and room_index > 0 and turn_type == 0:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-2.0, 2.0)
		_build_wall_lever(room_node, assets, Vector3(side * (HALF_W - 0.08), 1.45, lz), -PI * 0.5 if side > 0 else PI * 0.5, r)

	return r


static func _build_bridge_shell(room_node: Node3D, assets: SharedAssets, r: RoomInstance) -> void:
	# Entry & exit solid ledges + deep pit below + elevated steel grate bridge with railings
	_add_box(room_node, "PitFloor", Vector3(0.0, -2.5, 0.0), Vector3(HALF_W * 2.0, 0.2, CELL_SIZE), assets.floor_mat)
	_add_box(room_node, "LedgeEntry", Vector3(0.0, -1.2, 4.4), Vector3(HALF_W * 2.0, 2.4, 3.2), assets.wall_mat)
	_add_box(room_node, "LedgeExit", Vector3(0.0, -1.2, -4.7), Vector3(HALF_W * 2.0, 2.4, 2.6), assets.wall_mat)
	_add_box(room_node, "EntryCarpet", Vector3(0.0, -0.04, 4.4), Vector3(HALF_W * 2.0, 0.08, 3.2), assets.floor_mat, false)
	_add_box(room_node, "ExitCarpet", Vector3(0.0, -0.04, -4.7), Vector3(HALF_W * 2.0, 0.08, 2.6), assets.floor_mat, false)

	_add_box(room_node, "BridgeDeck", Vector3(0.0, -0.08, -0.3), Vector3(2.8, 0.16, 6.4), assets.grate_mat).set_meta("floor_surface", "metal")
	# Steel safety rails on bridge
	for side_s in [-1.0, 1.0]:
		var rx: float = side_s * 1.32
		_add_box(room_node, "RailTop", Vector3(rx, 0.92, -0.3), Vector3(0.08, 0.08, 6.4), assets.metal_mat)
		for pz in [-3.1, -1.0, 1.0, 2.6]:
			_add_box(room_node, "RailPost", Vector3(rx, 0.45, pz), Vector3(0.08, 0.92, 0.08), assets.metal_mat, false)
	# Locker cleanly on entry landing so player can always hide!
	_build_locker(room_node, assets, Vector3(HALF_W - 0.55, 0.0, 4.1), -PI * 0.5, r)
	_build_desk(room_node, assets, Vector3(-2.4, -2.4, 0.2), 0.2)


static func _build_exit_door(anchor: Node3D, assets: SharedAssets, next_room_num: int, r: RoomInstance) -> void:
	var side_w := (HALF_W * 2.0 - DOOR_W) * 0.5
	_add_box(anchor, "DoorWallL", Vector3(-DOOR_W * 0.5 - side_w * 0.5, CEIL_H * 0.5, 0.0), Vector3(side_w, CEIL_H, WALL_THICK), assets.wall_mat)
	_add_box(anchor, "DoorWallR", Vector3(DOOR_W * 0.5 + side_w * 0.5, CEIL_H * 0.5, 0.0), Vector3(side_w, CEIL_H, WALL_THICK), assets.wall_mat)
	_add_box(anchor, "DoorHeader", Vector3(0.0, DOOR_H + (CEIL_H - DOOR_H) * 0.5, 0.0), Vector3(DOOR_W, CEIL_H - DOOR_H, WALL_THICK), assets.wall_mat)

	# Door frame trim
	_add_box(anchor, "FrameL", Vector3(-DOOR_W * 0.5 + 0.05, DOOR_H * 0.5, 0.0), Vector3(0.10, DOOR_H, WALL_THICK + 0.06), assets.plank_dark_mat)
	_add_box(anchor, "FrameR", Vector3(DOOR_W * 0.5 - 0.05, DOOR_H * 0.5, 0.0), Vector3(0.10, DOOR_H, WALL_THICK + 0.06), assets.plank_dark_mat)

	# Signature yellow plaque above door (from all RoomTypes images)
	_add_box(anchor, "YellowPlaqueBg", Vector3(0.0, DOOR_H + 0.26, WALL_THICK * 0.5 + 0.015), Vector3(1.15, 0.34, 0.03), assets.plaque_yellow_mat, false)
	var exit_sign := Label3D.new()
	exit_sign.text = "A-%03d" % next_room_num
	exit_sign.font_size = 44
	exit_sign.pixel_size = 0.0046
	exit_sign.position = Vector3(0.0, DOOR_H + 0.26, WALL_THICK * 0.5 + 0.04)
	exit_sign.modulate = Color(0.08, 0.08, 0.08)
	anchor.add_child(exit_sign)

	var pivot := Node3D.new()
	pivot.name = "DoorPivot"
	# Hinged on the RIGHT (+X) so negative Y rotation swings the door AWAY (-Z) and RIGHT (+X)
	pivot.position = Vector3(DOOR_W * 0.5 - 0.10, 0.0, 0.0)
	anchor.add_child(pivot)
	r.door_pivot = pivot

	var leaf_w := DOOR_W - 0.20
	var door_body := _add_box(pivot, "DoorLeaf", Vector3(-leaf_w * 0.5, (DOOR_H - 0.04) * 0.5, 0.0), Vector3(leaf_w, DOOR_H - 0.04, 0.10), assets.door_mat)
	door_body.set_meta("interact_type", "door")
	door_body.set_meta("room_index", r.index)
	r.door_collider = door_body as StaticBody3D

	# Small silver handle on left side of door leaf (both sides)
	_add_box(pivot, "DoorKnob", Vector3(-leaf_w + 0.18, 1.05, 0.075), Vector3(0.10, 0.06, 0.06), assets.fridge_mat, false)
	_add_box(pivot, "DoorKnobBack", Vector3(-leaf_w + 0.18, 1.05, -0.075), Vector3(0.10, 0.06, 0.06), assets.fridge_mat, false)


static func _build_ceiling_grid(room_node: Node3D, assets: SharedAssets, light_on: bool, r: RoomInstance) -> void:
	var mat := assets.lamp_on_mat if light_on else assets.lamp_off_mat
	for lx in [-1.95, 1.95]:
		for lz in [-5.2, 0.0, 5.2]:
			var m := _add_box(room_node, "Troffer", Vector3(lx, CEIL_H - 0.03, lz), Vector3(1.15, 0.06, 0.65), mat, false) as MeshInstance3D
			if m != null:
				r.lamp_meshes.append(m)
	if light_on:
		for lz in [-4.5, 4.5]:
			var omni := OmniLight3D.new()
			omni.position = Vector3(0.0, CEIL_H - 0.35, lz)
			omni.light_color = Color(0.86, 0.92, 1.0)
			omni.light_energy = 1.15
			omni.omni_range = 13.5
			omni.omni_attenuation = 1.25
			room_node.add_child(omni)
			r.ceiling_lights.append(omni)
			r.light_base_energies.append(omni.light_energy)


static func _populate_room_type(
	room_node: Node3D,
	assets: SharedAssets,
	rtype: String,
	room_index: int,
	turn_type: int,
	rng: RandomNumberGenerator,
	r: RoomInstance
) -> void:
	if rtype == "lobby":
		_build_desk(room_node, assets, Vector3(-2.7, 0.0, 0.8), PI * 0.5, r)
		_build_pickup(room_node, assets, Vector3(-2.55, 0.78, 0.45), "battery", "Батарейка (+1)")
		_build_pickup(room_node, assets, Vector3(-2.75, 0.78, 1.10), "gummy", "Трясосвет [2]")
		_build_cardboard_box(room_node, assets, Vector3(-3.3, 0.42, -2.5), 0.84)
		_build_cardboard_box(room_node, assets, Vector3(-3.2, 1.15, -2.4), 0.62)
		_build_potted_plant(room_node, assets, Vector3(3.3, 0.0, -4.5))
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, -0.5), -PI * 0.5, r)
		return

	if rtype == "l_turn":
		if turn_type == -1:
			_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, 0.4), -PI * 0.5, r)
			_build_desk(room_node, assets, Vector3(2.5, 0.0, -2.7), 0.0, r)
			_build_potted_plant(room_node, assets, Vector3(2.5, 0.78, -2.7))
		else:
			_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, 0.4), PI * 0.5, r)
			_build_desk(room_node, assets, Vector3(-2.5, 0.0, -2.7), 0.0, r)
			_build_potted_plant(room_node, assets, Vector3(-2.5, 0.78, -2.7))
		return

	if rtype == "bridge_room":
		return # Lockers & pit props already built inside bridge shell

	if rtype == "locker_room":
		# Locker banks on both sides + iconic wooden bench down center!
		for lz in [-3.4, -1.2, 1.0, 3.2]:
			_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, lz), PI * 0.5, r)
			_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, lz), -PI * 0.5, r)
		_add_box(room_node, "BenchSeat", Vector3(0.0, 0.46, 0.0), Vector3(0.55, 0.08, 4.8), assets.wood_mat)
		_add_box(room_node, "BenchLegA", Vector3(0.0, 0.22, -1.7), Vector3(0.16, 0.44, 0.16), assets.metal_mat)
		_add_box(room_node, "BenchLegB", Vector3(0.0, 0.22, 1.7), Vector3(0.16, 0.44, 0.16), assets.metal_mat)
		return

	if rtype == "three_locker":
		# 3 lockers grouped along far-left wall + clear main hall
		for lx in [-3.4, -2.2, 2.8]:
			_build_locker(room_node, assets, Vector3(lx, 0.0, -5.2), 0.0, r)
		_build_desk(room_node, assets, Vector3(3.0, 0.0, 1.2), -PI * 0.5, r)
		_maybe_spawn_loot(room_node, assets, Vector3(3.0, 0.78, 1.2), room_index, rng)
		return

	if rtype == "new_2_locker":
		_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, -1.2), PI * 0.5, r)
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, 1.5), -PI * 0.5, r)
		_build_potted_plant(room_node, assets, Vector3(-3.3, 0.0, 3.6))
		_build_desk(room_node, assets, Vector3(2.9, 0.0, -2.2), -PI * 0.5, r)
		_maybe_spawn_loot(room_node, assets, Vector3(2.9, 0.78, -2.2), room_index, rng)
		return

	if rtype == "desk_room":
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, -4.5), -PI * 0.5, r)
		_build_desk(room_node, assets, Vector3(-2.7, 0.0, 1.0), PI * 0.5, r)
		_build_potted_plant(room_node, assets, Vector3(-2.7, 0.78, 0.5))
		_build_potted_plant(room_node, assets, Vector3(-2.7, 0.78, 1.5))
		# Office cubicle divider on right
		_add_box(room_node, "CubicleWall", Vector3(2.5, 0.65, 1.2), Vector3(1.8, 1.3, 0.14), assets.wall_mat)
		_build_desk(room_node, assets, Vector3(2.6, 0.0, 2.0), 0.0, r)
		_maybe_spawn_loot(room_node, assets, Vector3(2.6, 0.78, 2.0), room_index, rng)
		return

	if rtype == "meeting_room":
		_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, 4.0), PI * 0.5, r)
		# Glass office divider walls
		_add_box(room_node, "GlassL", Vector3(-2.6, 1.4, -2.8), Vector3(2.6, 2.8, 0.08), assets.glass_mat, false)
		_add_box(room_node, "GlassR", Vector3(2.6, 1.4, -2.8), Vector3(2.6, 2.8, 0.08), assets.glass_mat, false)
		# Whiteboard on left wall
		_add_box(room_node, "Whiteboard", Vector3(-HALF_W + 0.06, 1.7, 0.0), Vector3(0.08, 1.4, 2.6), assets.fridge_mat, false)
		# Long conference table & chairs off-center-right so lane remains clear
		_add_box(room_node, "MeetingTop", Vector3(1.4, 0.76, 0.0), Vector3(1.3, 0.08, 3.4), assets.wood_mat)
		_add_box(room_node, "MeetingBase", Vector3(1.4, 0.36, 0.0), Vector3(0.6, 0.72, 2.2), assets.metal_mat)
		_build_potted_plant(room_node, assets, Vector3(1.4, 0.80, 0.0))
		_build_chair(room_node, assets, Vector3(0.4, 0.0, -0.7), PI * 0.5)
		_build_chair(room_node, assets, Vector3(0.4, 0.0, 0.7), PI * 0.5)
		_build_chair(room_node, assets, Vector3(2.4, 0.0, 0.0), -PI * 0.5)
		_maybe_spawn_loot(room_node, assets, Vector3(1.4, 0.86, 1.1), room_index, rng)
		return

	if rtype == "bookshelf_room":
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, 0.8), -PI * 0.5, r)
		_build_cardboard_box(room_node, assets, Vector3(-3.3, 0.44, 3.2), 0.88)
		_build_cardboard_box(room_node, assets, Vector3(-3.2, 1.24, 3.1), 0.72)
		_build_bookshelf(room_node, assets, Vector3(3.4, 0.0, -2.4), -PI * 0.5)
		_build_bookshelf(room_node, assets, Vector3(-3.4, 0.0, -2.6), PI * 0.5)
		_build_potted_plant(room_node, assets, Vector3(3.3, 2.15, -2.4))
		_build_desk(room_node, assets, Vector3(-2.4, 0.0, -0.2), PI * 0.5, r)
		_maybe_spawn_loot(room_node, assets, Vector3(-2.4, 0.78, -0.2), room_index, rng)
		return

	if rtype == "storage_room":
		_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, 2.6), PI * 0.5, r)
		for rz in [-2.6, 0.0, 2.6]:
			_build_shelf_rack(room_node, assets, Vector3(3.3, 0.0, rz), -PI * 0.5)
			_build_cardboard_box(room_node, assets, Vector3(3.3, 1.25, rz), 0.55)
		_build_desk(room_node, assets, Vector3(-2.6, 0.0, -1.8), PI * 0.5, r)
		_build_potted_plant(room_node, assets, Vector3(-2.6, 0.78, -2.2))
		_maybe_spawn_loot(room_node, assets, Vector3(-2.4, 0.78, -1.6), room_index, rng)
		return

	if rtype == "kitchen":
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, 4.4), -PI * 0.5, r)
		# Hideable white Refrigerator on left entry!
		_build_fridge_hider(room_node, assets, Vector3(-HALF_W + 0.52, 0.0, 3.4), PI * 0.5, r)
		# Left & right kitchen counters
		_add_box(room_node, "CounterL", Vector3(-3.45, 0.45, -1.0), Vector3(0.95, 0.90, 5.4), assets.wood_mat)
		_add_box(room_node, "CounterTopL", Vector3(-3.45, 0.93, -1.0), Vector3(1.0, 0.08, 5.45), assets.counter_top_mat, false)
		_add_box(room_node, "CounterR", Vector3(3.45, 0.45, -0.8), Vector3(0.95, 0.90, 5.2), assets.wood_mat)
		_add_box(room_node, "CounterTopR", Vector3(3.45, 0.93, -0.8), Vector3(1.0, 0.08, 5.25), assets.counter_top_mat, false)
		_add_box(room_node, "WallCabinetR", Vector3(3.7, 2.35, -0.8), Vector3(0.50, 0.80, 4.4), assets.wood_mat, false)
		_add_box(room_node, "Microwave", Vector3(3.45, 1.15, -1.8), Vector3(0.45, 0.34, 0.65), assets.locker_mat, false)
		# Center-offset dining table
		_add_box(room_node, "KitchenTable", Vector3(1.5, 0.74, 0.4), Vector3(1.2, 0.08, 1.2), assets.wood_mat)
		_add_box(room_node, "KitchenTablePed", Vector3(1.5, 0.36, 0.4), Vector3(0.24, 0.72, 0.24), assets.metal_mat)
		_build_chair(room_node, assets, Vector3(0.6, 0.0, 0.4), PI * 0.5)
		_maybe_spawn_loot(room_node, assets, Vector3(-3.4, 1.05, -0.5), room_index, rng)
		return

	if rtype == "double_plant" or rtype == "plant_room":
		_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, -3.0), PI * 0.5, r)
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, -3.0), -PI * 0.5, r)
		_build_potted_plant(room_node, assets, Vector3(-3.1, 0.0, 1.5))
		if rtype == "double_plant":
			_build_potted_plant(room_node, assets, Vector3(3.1, 0.0, 1.5))
			# Wood wall trim strips matching DoublePlantRoomAfter20.webp
			_add_box(room_node, "TrimL", Vector3(-HALF_W + 0.04, CEIL_H * 0.5, 0.0), Vector3(0.08, CEIL_H, 0.16), assets.wood_mat, false)
			_add_box(room_node, "TrimR", Vector3(HALF_W - 0.04, CEIL_H * 0.5, 0.0), Vector3(0.08, CEIL_H, 0.16), assets.wood_mat, false)
		_maybe_spawn_loot(room_node, assets, Vector3(2.8, 0.14, 3.0), room_index, rng)
		return

	if rtype == "table_room":
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, -3.8), -PI * 0.5, r)
		# Area rug + ornate dark curtain & portrait frame on left wall
		_add_box(room_node, "AreaRug", Vector3(0.6, 0.01, 0.0), Vector3(4.2, 0.02, 5.2), assets.rug_mat, false)
		_add_box(room_node, "Portrait", Vector3(-HALF_W + 0.05, 1.85, 0.2), Vector3(0.06, 1.6, 1.3), assets.plank_dark_mat, false)
		_add_box(room_node, "CurtainL", Vector3(-HALF_W + 0.08, 1.8, -0.7), Vector3(0.12, 2.3, 0.38), assets.fabric_red_mat, false)
		_add_box(room_node, "CurtainR", Vector3(-HALF_W + 0.08, 1.8, 1.1), Vector3(0.12, 2.3, 0.38), assets.fabric_red_mat, false)
		_add_box(room_node, "Sofa", Vector3(-3.3, 0.42, -2.5), Vector3(0.85, 0.84, 2.0), assets.fabric_red_mat)
		_add_box(room_node, "BanquetTable", Vector3(1.5, 0.76, 0.0), Vector3(1.2, 0.08, 3.0), assets.plank_dark_mat)
		_build_potted_plant(room_node, assets, Vector3(1.5, 0.80, 0.0))
		_build_chair(room_node, assets, Vector3(0.55, 0.0, -0.8), PI * 0.5)
		_build_chair(room_node, assets, Vector3(0.55, 0.0, 0.8), PI * 0.5)
		_maybe_spawn_loot(room_node, assets, Vector3(1.5, 0.88, 1.0), room_index, rng)
		return

	if rtype == "mannequin_room":
		_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, -3.2), PI * 0.5, r)
		_build_shelf_rack(room_node, assets, Vector3(3.3, 0.0, -2.0), -PI * 0.5)
		_build_mannequin(room_node, assets, Vector3(-2.6, 0.0, 2.6), 0.4)
		_build_mannequin(room_node, assets, Vector3(2.4, 0.0, 2.0), -0.5)
		_build_mannequin(room_node, assets, Vector3(2.5, 0.0, -3.8), -0.3)
		_build_desk(room_node, assets, Vector3(-2.6, 0.0, -0.4), PI * 0.5, r)
		_maybe_spawn_loot(room_node, assets, Vector3(-2.6, 0.78, -0.4), room_index, rng)
		return

	if rtype == "w_shaped":
		# Classic W-Room twin parallel sightline partitions + outer lockers!
		_build_locker(room_node, assets, Vector3(-HALF_W + 0.48, 0.0, 0.0), PI * 0.5, r)
		_build_locker(room_node, assets, Vector3(HALF_W - 0.48, 0.0, 0.0), -PI * 0.5, r)
		_add_box(room_node, "WDividerL", Vector3(-1.45, CEIL_H * 0.5, 0.3), Vector3(0.32, CEIL_H, 5.8), assets.wall_mat)
		_add_box(room_node, "WDividerR", Vector3(1.45, CEIL_H * 0.5, 0.3), Vector3(0.32, CEIL_H, 5.8), assets.wall_mat)
		_maybe_spawn_loot(room_node, assets, Vector3(-2.8, 0.14, -1.8), room_index, rng)
		return

	# "closet_room" fallback: circular floor pattern & lockers flanking exit door
	_build_locker(room_node, assets, Vector3(-2.5, 0.0, -5.2), 0.0, r)
	_build_locker(room_node, assets, Vector3(2.5, 0.0, -5.2), 0.0, r)
	_add_box(room_node, "CenterMat", Vector3(0.0, 0.01, 0.0), Vector3(4.2, 0.02, 4.2), assets.plaque_yellow_mat if false else assets.locker_mat, false)


static func _maybe_spawn_loot(room_node: Node3D, assets: SharedAssets, pos: Vector3, room_index: int, rng: RandomNumberGenerator) -> void:
	if room_index <= 20:
		# Early calm rooms (1-20): guaranteed batteries in 7 distinct rooms (up to 7 batteries total)
		var early_battery_rooms := [2, 5, 8, 11, 14, 17, 20]
		if room_index in early_battery_rooms:
			_build_pickup(room_node, assets, pos, "battery", "Батарейка (+1)")
			return
		elif rng.randf() < 0.35:
			_build_pickup(room_node, assets, pos, "battery", "Батарейка (+1)")
			return
	if rng.randf() < 0.34:
		_build_pickup(room_node, assets, pos, "battery", "Батарейка (+1)")
	elif room_index > 8 and rng.randf() < 0.14:
		_build_pickup(room_node, assets, pos, "medkit", "Аптечка (+45 HP)")



static func _build_locker(room_node: Node3D, assets: SharedAssets, local_pos: Vector3, local_yaw: float, r: RoomInstance) -> void:
	var locker := Node3D.new()
	locker.name = "Locker_%d" % r.lockers.size()
	locker.position = local_pos
	locker.rotation.y = local_yaw
	room_node.add_child(locker)

	var back := _add_box(locker, "Back", Vector3(0.0, 1.05, -0.34), Vector3(0.92, 2.1, 0.05), assets.locker_mat)
	var left := _add_box(locker, "Left", Vector3(-0.44, 1.05, 0.0), Vector3(0.05, 2.1, 0.72), assets.locker_mat)
	var right := _add_box(locker, "Right", Vector3(0.44, 1.05, 0.0), Vector3(0.05, 2.1, 0.72), assets.locker_mat)
	var top := _add_box(locker, "Top", Vector3(0.0, 2.08, 0.0), Vector3(0.92, 0.05, 0.72), assets.locker_mat)

	var door_pivot := Node3D.new()
	door_pivot.name = "LockerDoorPivot"
	door_pivot.position = Vector3(-0.42, 0.0, 0.34)
	locker.add_child(door_pivot)

	var door_bot := _add_box(door_pivot, "DoorLower", Vector3(0.42, 0.68, 0.0), Vector3(0.84, 1.36, 0.05), assets.locker_door_mat)
	var door_mid := _add_box(door_pivot, "DoorSlitBar", Vector3(0.42, 1.50, 0.0), Vector3(0.84, 0.05, 0.05), assets.locker_door_mat)
	var door_top := _add_box(door_pivot, "DoorUpper", Vector3(0.42, 1.85, 0.0), Vector3(0.84, 0.44, 0.05), assets.locker_door_mat)
	_add_box(door_pivot, "Handle", Vector3(0.72, 1.05, 0.035), Vector3(0.04, 0.16, 0.03), assets.fridge_mat, false)

	var l_idx := r.lockers.size()
	for part in [back, left, right, top, door_bot, door_mid, door_top]:
		part.set_meta("interact_type", "locker")
		part.set_meta("room_index", r.index)
		part.set_meta("locker_index", l_idx)

	r.lockers.append({
		"kind": "locker",
		"node": locker,
		"door_pivot": door_pivot,
		"eye_local": Vector3(0.0, 1.48, 0.05),
		"exit_local": Vector3(0.0, 0.05, 1.05),
		"label": "",
	})


static func _build_fridge_hider(room_node: Node3D, assets: SharedAssets, local_pos: Vector3, local_yaw: float, r: RoomInstance) -> void:
	var fridge := Node3D.new()
	fridge.name = "Fridge_%d" % r.lockers.size()
	fridge.position = local_pos
	fridge.rotation.y = local_yaw
	room_node.add_child(fridge)

	var back := _add_box(fridge, "Back", Vector3(0.0, 1.05, -0.40), Vector3(0.96, 2.1, 0.06), assets.fridge_mat)
	var left := _add_box(fridge, "Left", Vector3(-0.46, 1.05, 0.0), Vector3(0.06, 2.1, 0.84), assets.fridge_mat)
	var right := _add_box(fridge, "Right", Vector3(0.46, 1.05, 0.0), Vector3(0.06, 2.1, 0.84), assets.fridge_mat)
	var top := _add_box(fridge, "Top", Vector3(0.0, 2.08, 0.0), Vector3(0.96, 0.06, 0.84), assets.fridge_mat)
	_add_box(fridge, "InnerBackLiner", Vector3(0.0, 1.05, -0.35), Vector3(0.84, 1.98, 0.04), assets.locker_mat, false)
	_add_box(fridge, "InnerLeftLiner", Vector3(-0.41, 1.05, 0.0), Vector3(0.03, 1.98, 0.74), assets.locker_mat, false)
	_add_box(fridge, "InnerRightLiner", Vector3(0.41, 1.05, 0.0), Vector3(0.03, 1.98, 0.74), assets.locker_mat, false)
	_add_box(fridge, "Shelf", Vector3(0.0, 0.45, -0.10), Vector3(0.84, 0.04, 0.56), assets.glass_mat, false)

	var door_pivot := Node3D.new()
	door_pivot.name = "FridgeDoorPivot"
	door_pivot.position = Vector3(-0.44, 0.0, 0.41)
	fridge.add_child(door_pivot)

	var door_bot := _add_box(door_pivot, "FridgeDoorBot", Vector3(0.44, 0.65, 0.0), Vector3(0.88, 1.30, 0.06), assets.fridge_mat)
	var door_top := _add_box(door_pivot, "FridgeDoorTop", Vector3(0.44, 1.84, 0.0), Vector3(0.88, 0.44, 0.06), assets.fridge_mat)
	var door_side_l := _add_box(door_pivot, "FridgeDoorSideL", Vector3(0.09, 1.46, 0.0), Vector3(0.18, 0.32, 0.06), assets.fridge_mat)
	var door_side_r := _add_box(door_pivot, "FridgeDoorSideR", Vector3(0.79, 1.46, 0.0), Vector3(0.18, 0.32, 0.06), assets.fridge_mat)
	# Punched / torn jagged metal frame around the eye-level peephole (x: 0.18..0.70, y: 1.30..1.62)
	_add_box(door_pivot, "HoleRimBot", Vector3(0.44, 1.30, 0.018), Vector3(0.54, 0.035, 0.08), assets.locker_mat, false)
	_add_box(door_pivot, "HoleRimTop", Vector3(0.44, 1.62, 0.018), Vector3(0.54, 0.035, 0.08), assets.locker_mat, false)
	var tear_l := _add_box(door_pivot, "HoleTearL", Vector3(0.20, 1.46, 0.036), Vector3(0.06, 0.32, 0.025), assets.metal_mat, false)
	tear_l.rotation.z = 0.12
	tear_l.rotation.y = -0.25
	var tear_r := _add_box(door_pivot, "HoleTearR", Vector3(0.68, 1.46, 0.036), Vector3(0.06, 0.32, 0.025), assets.metal_mat, false)
	tear_r.rotation.z = -0.10
	tear_r.rotation.y = 0.25
	_add_box(door_pivot, "FreezerSeam", Vector3(0.44, 1.24, 0.036), Vector3(0.86, 0.03, 0.02), assets.locker_mat, false)
	_add_box(door_pivot, "FridgeHandleU", Vector3(0.78, 1.82, 0.05), Vector3(0.03, 0.26, 0.04), assets.metal_mat, false)
	_add_box(door_pivot, "FridgeHandleL", Vector3(0.78, 0.96, 0.05), Vector3(0.03, 0.42, 0.04), assets.metal_mat, false)

	var l_idx := r.lockers.size()
	for part in [back, left, right, top, door_bot, door_top, door_side_l, door_side_r]:
		part.set_meta("interact_type", "locker")
		part.set_meta("room_index", r.index)
		part.set_meta("locker_index", l_idx)

	r.lockers.append({
		"kind": "fridge",
		"node": fridge,
		"door_pivot": door_pivot,
		"eye_local": Vector3(0.0, 1.44, 0.08),
		"exit_local": Vector3(0.0, 0.05, 1.15),
		"label": "",
	})


static func _build_desk(room_node: Node3D, assets: SharedAssets, local_pos: Vector3, local_yaw: float, r: RoomInstance = null) -> void:
	var desk := Node3D.new()
	desk.position = local_pos
	desk.rotation.y = local_yaw
	room_node.add_child(desk)
	var top := _add_box(desk, "Top", Vector3(0.0, 0.76, 0.0), Vector3(1.38, 0.07, 0.78), assets.wood_mat)
	_add_box(desk, "LegFL", Vector3(-0.62, 0.37, 0.32), Vector3(0.07, 0.74, 0.07), assets.metal_mat, false)
	_add_box(desk, "LegFR", Vector3(0.62, 0.37, 0.32), Vector3(0.07, 0.74, 0.07), assets.metal_mat, false)
	_add_box(desk, "LegBL", Vector3(-0.62, 0.37, -0.32), Vector3(0.07, 0.74, 0.07), assets.metal_mat, false)
	_add_box(desk, "LegBR", Vector3(0.62, 0.37, -0.32), Vector3(0.07, 0.74, 0.07), assets.metal_mat, false)
	if r != null:
		var l_idx := r.lockers.size()
		top.set_meta("interact_type", "locker")
		top.set_meta("room_index", r.index)
		top.set_meta("locker_index", l_idx)
		r.lockers.append({
			"kind": "under_desk",
			"node": desk,
			"door_pivot": null,
			"eye_local": Vector3(0.0, 0.46, 0.0),
			"exit_local": Vector3(0.0, 0.05, 1.02),
			"label": "[ЛКМ] Залезть под тумбочку",
		})


static func _build_potted_plant(room_node: Node3D, assets: SharedAssets, local_pos: Vector3) -> void:
	var p := Node3D.new()
	p.position = local_pos
	room_node.add_child(p)
	_add_box(p, "Pot", Vector3(0.0, 0.18, 0.0), Vector3(0.36, 0.36, 0.36), assets.plant_pot_mat, false)
	for i in range(4):
		var leaf := _add_box(p, "Leaf%d" % i, Vector3(0.0, 0.50, 0.0), Vector3(0.55, 0.06, 0.22), assets.plant_leaf_mat, false)
		leaf.rotation.y = float(i) * 0.78
		leaf.rotation.z = 0.28 if i % 2 == 0 else -0.28


static func _build_cardboard_box(room_node: Node3D, assets: SharedAssets, pos: Vector3, sz: float) -> void:
	_add_box(room_node, "CardboardBox", pos, Vector3(sz, sz, sz), assets.cardboard_mat)


static func _build_chair(room_node: Node3D, assets: SharedAssets, pos: Vector3, yaw: float) -> void:
	var ch := Node3D.new()
	ch.position = pos
	ch.rotation.y = yaw
	room_node.add_child(ch)
	_add_box(ch, "Seat", Vector3(0.0, 0.45, 0.0), Vector3(0.46, 0.06, 0.46), assets.plank_dark_mat, false)
	_add_box(ch, "Back", Vector3(0.0, 0.78, -0.20), Vector3(0.46, 0.62, 0.06), assets.plank_dark_mat, false)
	_add_box(ch, "Ped", Vector3(0.0, 0.22, 0.0), Vector3(0.10, 0.44, 0.10), assets.metal_mat, false)


static func _build_shelf_rack(room_node: Node3D, assets: SharedAssets, pos: Vector3, yaw: float) -> void:
	var sh := Node3D.new()
	sh.position = pos
	sh.rotation.y = yaw
	room_node.add_child(sh)
	for py in [0.15, 0.85, 1.55, 2.15]:
		_add_box(sh, "Shelf", Vector3(0.0, py, 0.0), Vector3(1.8, 0.05, 0.65), assets.metal_mat)
	for px in [-0.85, 0.85]:
		for pz in [-0.28, 0.28]:
			_add_box(sh, "Post", Vector3(px, 1.1, pz), Vector3(0.06, 2.2, 0.06), assets.metal_mat, false)


static func _build_bookshelf(room_node: Node3D, assets: SharedAssets, pos: Vector3, yaw: float) -> void:
	var bs := Node3D.new()
	bs.position = pos
	bs.rotation.y = yaw
	room_node.add_child(bs)
	_add_box(bs, "Frame", Vector3(0.0, 1.05, 0.0), Vector3(1.5, 2.1, 0.55), assets.plank_dark_mat)


static func _build_mannequin(room_node: Node3D, assets: SharedAssets, pos: Vector3, yaw: float) -> void:
	var m := Node3D.new()
	m.position = pos
	m.rotation.y = yaw
	room_node.add_child(m)
	_add_box(m, "Base", Vector3(0.0, 0.03, 0.0), Vector3(0.52, 0.06, 0.52), assets.mannequin_mat, false)
	_add_box(m, "Legs", Vector3(0.0, 0.45, 0.0), Vector3(0.36, 0.80, 0.22), assets.mannequin_mat)
	_add_box(m, "Torso", Vector3(0.0, 1.15, 0.0), Vector3(0.42, 0.62, 0.24), assets.mannequin_mat)
	_add_box(m, "ArmL", Vector3(-0.30, 1.15, 0.0), Vector3(0.14, 0.56, 0.16), assets.mannequin_mat, false)
	_add_box(m, "ArmR", Vector3(0.30, 1.15, 0.0), Vector3(0.14, 0.56, 0.16), assets.mannequin_mat, false)
	_add_box(m, "Head", Vector3(0.0, 1.66, 0.0), Vector3(0.28, 0.30, 0.28), assets.mannequin_mat, false)


static func _build_pickup(room_node: Node3D, assets: SharedAssets, local_pos: Vector3, kind: String, prompt: String) -> void:
	var body := StaticBody3D.new()
	body.name = "Pickup_" + kind
	body.position = local_pos
	room_node.add_child(body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.32, 0.28, 0.36)
	col.shape = shape
	body.add_child(col)

	if kind == "battery":
		# Detailed cylindrical Battery model (dark shell + glowing cyan ring + brass positive cap)
		_add_cyl(body, "Cell", Vector3.ZERO, 0.068, 0.21, assets.locker_mat)
		_add_cyl(body, "GlowBand", Vector3(0.0, 0.04, 0.0), 0.070, 0.055, assets.battery_mat)
		_add_cyl(body, "TopCap", Vector3(0.0, 0.095, 0.0), 0.069, 0.032, assets.plaque_yellow_mat)
		_add_cyl(body, "Nub", Vector3(0.0, 0.122, 0.0), 0.025, 0.024, assets.fridge_mat)
	elif kind == "medkit":
		# White medical case + raised red 3D cross + carry handle
		_add_box(body, "Case", Vector3.ZERO, Vector3(0.34, 0.13, 0.25), assets.fridge_mat, false)
		_add_box(body, "CrossH", Vector3(0.0, 0.072, 0.0), Vector3(0.16, 0.02, 0.05), assets.medkit_mat, false)
		_add_box(body, "CrossV", Vector3(0.0, 0.072, 0.0), Vector3(0.05, 0.02, 0.16), assets.medkit_mat, false)
		_add_box(body, "Handle", Vector3(0.0, 0.03, 0.14), Vector3(0.14, 0.04, 0.04), assets.locker_mat, false)
	else:
		# Emerald Gummy / Shaker Flashlight (no crank handle!)
		_add_box(body, "Chassis", Vector3.ZERO, Vector3(0.11, 0.11, 0.26), assets.gummy_mat, false)
		_add_box(body, "Grip", Vector3(0.0, -0.02, -0.04), Vector3(0.12, 0.08, 0.14), assets.locker_mat, false)
		var lens := _add_cyl(body, "Head", Vector3(0.0, 0.0, 0.14), 0.062, 0.06, assets.fridge_mat)
		lens.rotation.x = PI * 0.5

	body.set_meta("interact_type", "pickup")
	body.set_meta("pickup_kind", kind)
	body.set_meta("pickup_prompt", prompt)


static func _build_wall_lever(room_node: Node3D, assets: SharedAssets, pos: Vector3, yaw: float, r: RoomInstance) -> void:
	var l_root := Node3D.new()
	l_root.name = "Lever_%d" % r.levers.size()
	l_root.position = pos
	l_root.rotation.y = yaw
	room_node.add_child(l_root)

	_add_box(l_root, "BasePlate", Vector3.ZERO, Vector3(0.24, 0.40, 0.08), assets.locker_mat, false)
	_add_box(l_root, "Trim", Vector3(0.0, 0.0, 0.045), Vector3(0.20, 0.36, 0.02), assets.plaque_yellow_mat, false)

	var pivot := Node3D.new()
	pivot.name = "HandlePivot"
	pivot.position = Vector3(0.0, -0.06, 0.05)
	pivot.rotation.x = -0.55
	l_root.add_child(pivot)

	_add_box(pivot, "Rod", Vector3(0.0, 0.12, 0.0), Vector3(0.04, 0.24, 0.04), assets.fridge_mat, false)
	_add_box(pivot, "Knob", Vector3(0.0, 0.24, 0.0), Vector3(0.08, 0.08, 0.08), assets.medkit_mat, false)

	var body := StaticBody3D.new()
	body.name = "LeverBody"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.40, 0.50, 0.35)
	col.shape = shape
	body.add_child(col)
	body.set_meta("interact_type", "lever")
	body.set_meta("room_index", r.index)
	body.set_meta("lever_index", r.levers.size())
	l_root.add_child(body)

	r.levers.append({
		"root": l_root,
		"pivot": pivot,
		"used": false
	})


static func _add_cyl(parent: Node3D, cyl_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = cyl_name
	mi.position = pos
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _add_box(parent: Node3D, box_name: String, pos: Vector3, box_size: Vector3, mat: Material, with_collision: bool = true) -> Node3D:
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat

	if not with_collision:
		mesh_inst.name = box_name
		mesh_inst.position = pos
		parent.add_child(mesh_inst)
		return mesh_inst

	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	parent.add_child(body)
	body.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)
	return body
