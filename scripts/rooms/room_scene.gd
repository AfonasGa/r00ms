class_name RoomScene
extends Node3D

## Base component script attached to every room .tscn under res://scenes/rooms/.
## Supports zero-allocation room pooling, shared material binding, light culling, and dynamic loot/lever markers.

const CELL_SIZE := 18.0
const HALF_CELL := 9.0
const HALF_W := 4.2
const CEIL_H := 3.8
const DOOR_W := 2.0
const DOOR_H := 2.75
const WALL_THICK := 0.22

@export var room_type: String = "closet_room"
@export var turn_type: int = 0 # 0=straight, -1=left, 1=right

var index: int = 0
var grid_cell: Vector2i = Vector2i.ZERO
var in_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var out_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var center_pos: Vector3 = Vector3.ZERO
var exit_pos: Vector3 = Vector3.ZERO

var door_opened: bool = false
var door_broken: bool = false
var is_dark_room: bool = false

var exit_anchor: Node3D = null
var door_pivot: Node3D = null
var door_collider: StaticBody3D = null
var door_col_shape: CollisionShape3D = null
var door_plaque_label: Label3D = null

var ceiling_lights: Array[OmniLight3D] = []
var light_base_energies: Array[float] = []
var lamp_meshes: Array[MeshInstance3D] = []
var lockers: Array[Dictionary] = []
var levers: Array[Dictionary] = []

var _loot_spawns: Array[Marker3D] = []
var _dynamic_nodes: Array[Node] = []
var _bound: bool = false


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func bind_scene_nodes(assets: RoomAssets) -> void:
	if _bound:
		return
	_bound = true
	assets.apply_materials_recursive(self)

	exit_anchor = get_node_or_null("ExitAnchor") as Node3D
	if exit_anchor != null:
		door_pivot = exit_anchor.get_node_or_null("DoorPivot") as Node3D
		if door_pivot != null:
			door_collider = door_pivot.get_node_or_null("DoorLeaf") as StaticBody3D
			if door_collider != null:
				door_col_shape = door_collider.get_node_or_null("Col") as CollisionShape3D
		door_plaque_label = exit_anchor.get_node_or_null("ExitSign") as Label3D

	ceiling_lights.clear()
	light_base_energies.clear()
	lamp_meshes.clear()
	lockers.clear()
	_loot_spawns.clear()

	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is OmniLight3D:
			var om := cur as OmniLight3D
			om.shadow_enabled = false
			om.light_color = Color(0.91, 0.95, 1.0)
			om.omni_attenuation = 1.08
			om.distance_fade_enabled = true
			om.distance_fade_begin = 26.0
			om.distance_fade_length = 10.0
			ceiling_lights.append(om)
			var base_e := om.light_energy if om.light_energy > 0.01 else 1.15
			light_base_energies.append(base_e * 1.25)
		elif cur is MeshInstance3D and cur.has_meta("is_troffer"):
			lamp_meshes.append(cur as MeshInstance3D)
		elif cur is Marker3D and cur.has_meta("loot_spawn"):
			_loot_spawns.append(cur as Marker3D)
		elif cur is Node3D and cur.has_meta("hiding_kind"):
			_register_hiding_node(cur as Node3D)


func _register_hiding_node(hnode: Node3D) -> void:
	var hkind := String(hnode.get_meta("hiding_kind"))
	var dp: Node3D = null
	var eye_loc := Vector3(0.0, 1.48, 0.05)
	var exit_loc := Vector3(0.0, 0.05, 1.05)
	var lbl := ""
	if hkind == "locker":
		dp = hnode.get_node_or_null("LockerDoorPivot") as Node3D
	elif hkind == "fridge":
		dp = hnode.get_node_or_null("FridgeDoorPivot") as Node3D
		eye_loc = Vector3(0.0, 1.44, 0.08)
		exit_loc = Vector3(0.0, 0.05, 1.15)
	elif hkind == "under_desk":
		eye_loc = Vector3(0.0, 0.46, 0.0)
		exit_loc = Vector3(0.0, 0.05, 1.02)
		lbl = "[ЛКМ] Залезть под тумбочку"

	var colliders: Array[StaticBody3D] = []
	var st: Array[Node] = [hnode]
	while not st.is_empty():
		var c: Node = st.pop_back()
		for ch in c.get_children():
			st.append(ch)
		if c is StaticBody3D and c.has_meta("hiding_interact"):
			colliders.append(c as StaticBody3D)

	lockers.append({
		"kind": hkind,
		"node": hnode,
		"door_pivot": dp,
		"door_orig_pos": dp.position if dp != null else Vector3.ZERO,
		"eye_local": eye_loc,
		"exit_local": exit_loc,
		"label": lbl,
		"colliders": colliders,
		"broken": false,
	})


func configure_room(
	room_idx: int,
	p_grid_cell: Vector2i,
	p_in_dir: Vector3,
	p_out_dir: Vector3,
	dark: bool,
	assets: RoomAssets,
	rng: RandomNumberGenerator,
	haste_enabled: bool
) -> void:
	bind_scene_nodes(assets)
	_clear_dynamic_nodes()

	index = room_idx
	grid_cell = p_grid_cell
	in_dir = p_in_dir
	out_dir = p_out_dir
	center_pos = Vector3(float(grid_cell.x) * CELL_SIZE, 0.0, float(grid_cell.y) * CELL_SIZE)
	exit_pos = center_pos + out_dir * (CELL_SIZE * 0.5)
	name = "Room_%03d" % room_idx

	position = center_pos
	rotation = Vector3(0.0, atan2(-in_dir.x, -in_dir.z), 0.0)

	door_opened = false
	door_broken = false
	if door_pivot != null:
		door_pivot.visible = true
		door_pivot.rotation = Vector3.ZERO
	if door_collider != null:
		door_collider.collision_layer = 1
		door_collider.collision_mask = 1
		door_collider.set_meta("interact_type", "door")
		door_collider.set_meta("room_index", index)
	if door_col_shape != null:
		door_col_shape.disabled = false
	if door_plaque_label != null:
		door_plaque_label.text = "A-%03d" % (index + 1)

	for li in range(lockers.size()):
		var ld: Dictionary = lockers[li]
		ld["broken"] = false
		var dp: Node3D = ld.get("door_pivot") as Node3D
		if is_instance_valid(dp):
			dp.position = ld.get("door_orig_pos", dp.position)
			dp.rotation = Vector3.ZERO
			dp.scale = Vector3.ONE
			dp.visible = true
			for ch in dp.get_children():
				if ch is StaticBody3D:
					var dsb := ch as StaticBody3D
					dsb.collision_layer = 1
					dsb.collision_mask = 1
		var cols: Array = ld.get("colliders", [])
		for c_raw in cols:
			if c_raw is StaticBody3D and is_instance_valid(c_raw):
				var sb := c_raw as StaticBody3D
				sb.set_meta("interact_type", "locker")
				sb.set_meta("room_index", index)
				sb.set_meta("locker_index", li)

	is_dark_room = dark
	set_lights_active(not is_dark_room, assets)

	# Spawn dynamic pickups from scene markers
	if room_type == "lobby":
		_spawn_pickup_at(assets, Vector3(-2.55, 0.78, 0.45), "battery", "Батарейка (+1)")
		_spawn_pickup_at(assets, Vector3(-2.75, 0.78, 1.10), "gummy", "Трясосвет")
	else:
		for m in _loot_spawns:
			_maybe_spawn_loot(assets, m.position, index, rng)

	# Spawn Make Haste wall lever ONLY when modifier is enabled
	levers.clear()
	if haste_enabled and index > 0 and turn_type == 0 and assets.wall_lever_scene != null:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-2.0, 2.0)
		var lv := assets.wall_lever_scene.instantiate() as Node3D
		if lv != null:
			lv.name = "Lever_0"
			lv.position = Vector3(side * (HALF_W - 0.08), 1.45, lz)
			lv.rotation.y = -PI * 0.5 if side > 0.0 else PI * 0.5
			add_child(lv)
			assets.apply_materials_recursive(lv)
			_dynamic_nodes.append(lv)
			var body := lv.get_node_or_null("LeverBody") as StaticBody3D
			if body != null:
				body.set_meta("interact_type", "lever")
				body.set_meta("room_index", index)
				body.set_meta("lever_index", 0)
			var pivot := lv.get_node_or_null("HandlePivot") as Node3D
			levers.append({
				"root": lv,
				"pivot": pivot,
				"used": false,
			})


func _maybe_spawn_loot(assets: RoomAssets, pos: Vector3, room_idx: int, rng: RandomNumberGenerator) -> void:
	if room_idx <= 20:
		var early_battery_rooms: Array[int] = [2, 5, 8, 11, 14, 17, 20]
		if room_idx in early_battery_rooms or rng.randf() < 0.35:
			_spawn_pickup_at(assets, pos, "battery", "Батарейка (+1)")
			return
	if rng.randf() < 0.34:
		_spawn_pickup_at(assets, pos, "battery", "Батарейка (+1)")
	elif room_idx > 8 and rng.randf() < 0.14:
		_spawn_pickup_at(assets, pos, "medkit", "Аптечка (+45 HP)")


func _spawn_pickup_at(assets: RoomAssets, pos: Vector3, kind: String, prompt: String) -> void:
	var ps: PackedScene = null
	if kind == "battery":
		ps = assets.pickup_battery_scene
	elif kind == "medkit":
		ps = assets.pickup_medkit_scene
	else:
		ps = assets.pickup_gummy_scene
	if ps == null:
		return
	var node := ps.instantiate() as Node3D
	if node == null:
		return
	node.position = pos
	node.set_meta("interact_type", "pickup")
	node.set_meta("pickup_kind", kind)
	node.set_meta("pickup_prompt", prompt)
	add_child(node)
	assets.apply_materials_recursive(node)
	_dynamic_nodes.append(node)


func set_lights_active(lit: bool, assets: RoomAssets) -> void:
	var mat := assets.lamp_on_mat if lit else assets.lamp_off_mat
	for m in lamp_meshes:
		if is_instance_valid(m):
			m.material_override = mat
	for i in range(ceiling_lights.size()):
		var om := ceiling_lights[i]
		if is_instance_valid(om):
			var base_e := 1.15
			if i < light_base_energies.size():
				light_base_energies[i] = 1.15 if lit else 0.0
				base_e = light_base_energies[i]
			om.light_energy = base_e if lit else 0.0
			om.visible = lit and visible


func set_culled_visible(vis: bool) -> void:
	visible = vis
	for i in range(ceiling_lights.size()):
		var om := ceiling_lights[i]
		if is_instance_valid(om):
			var has_e := (i < light_base_energies.size() and light_base_energies[i] > 0.01)
			om.visible = vis and (not is_dark_room) and has_e


func register_dynamic_node(n: Node) -> void:
	_dynamic_nodes.append(n)


func _clear_dynamic_nodes() -> void:
	for n in _dynamic_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_dynamic_nodes.clear()
	levers.clear()


func disable_door_collision() -> void:
	if door_collider != null:
		door_collider.collision_layer = 0
		door_collider.collision_mask = 0
	if door_col_shape != null:
		door_col_shape.disabled = true


func reset_for_pool(assets: RoomAssets) -> void:
	_clear_dynamic_nodes()
	door_opened = false
	door_broken = false
	if door_pivot != null:
		door_pivot.visible = true
		door_pivot.rotation = Vector3.ZERO
	if door_collider != null:
		door_collider.collision_layer = 1
		door_collider.collision_mask = 1
	set_culled_visible(false)
	set_lights_active(false, assets)
