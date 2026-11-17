class_name RoomAssets
extends RefCounted

## Shared material & cached geometry registry for all RoomScene (.tscn) instances.
## Created once per session so every room shares the exact same GPU materials and textures.

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

var materials_by_slot: Dictionary = {}

# Cached pickup & lever PackedScenes (loaded once, zero disk I/O during gameplay)
var pickup_battery_scene: PackedScene
var pickup_medkit_scene: PackedScene
var pickup_gummy_scene: PackedScene
var wall_lever_scene: PackedScene

# Cached primitive meshes for dynamic broken door debris & held props
var _box_mesh_cache: Dictionary = {}
var _cyl_mesh_cache: Dictionary = {}


static func create_shared() -> RoomAssets:
	var a := RoomAssets.new()
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
	a.wall_mat.normal_scale = 0.15
	a.wall_mat.roughness = 0.84
	a.wall_mat.uv1_triplanar = true
	a.wall_mat.uv1_world_triplanar = true
	a.wall_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)

	a.floor_mat = StandardMaterial3D.new()
	a.floor_mat.albedo_texture = floor_tex
	a.floor_mat.normal_enabled = true
	a.floor_mat.normal_texture = carpet_nrm
	a.floor_mat.normal_scale = 0.70
	a.floor_mat.roughness = 0.90
	a.floor_mat.uv1_triplanar = true
	a.floor_mat.uv1_world_triplanar = true
	a.floor_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)

	a.tile_floor_mat = StandardMaterial3D.new()
	a.tile_floor_mat.albedo_texture = tile_tex
	a.tile_floor_mat.normal_enabled = true
	a.tile_floor_mat.normal_texture = tile_nrm
	a.tile_floor_mat.normal_scale = 0.60
	a.tile_floor_mat.roughness = 0.42
	a.tile_floor_mat.uv1_triplanar = true
	a.tile_floor_mat.uv1_world_triplanar = true
	a.tile_floor_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)

	a.grate_mat = StandardMaterial3D.new()
	a.grate_mat.albedo_texture = grate_tex
	a.grate_mat.metallic = 0.70
	a.grate_mat.roughness = 0.36
	a.grate_mat.uv1_scale = Vector3(3.0, 6.0, 3.0)

	a.ceiling_mat = StandardMaterial3D.new()
	a.ceiling_mat.albedo_color = Color(0.08, 0.09, 0.11)
	a.ceiling_mat.roughness = 0.88

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

	a.materials_by_slot = {
		"wall": a.wall_mat,
		"floor": a.floor_mat,
		"tile_floor": a.tile_floor_mat,
		"grate": a.grate_mat,
		"ceiling": a.ceiling_mat,
		"metal": a.metal_mat,
		"locker": a.locker_mat,
		"locker_door": a.locker_door_mat,
		"door": a.door_mat,
		"wood": a.wood_mat,
		"plank_dark": a.plank_dark_mat,
		"plaque_yellow": a.plaque_yellow_mat,
		"lamp_on": a.lamp_on_mat,
		"lamp_off": a.lamp_off_mat,
		"plant_pot": a.plant_pot_mat,
		"plant_leaf": a.plant_leaf_mat,
		"cardboard": a.cardboard_mat,
		"glass": a.glass_mat,
		"rug": a.rug_mat,
		"mannequin": a.mannequin_mat,
		"counter_top": a.counter_top_mat,
		"fridge": a.fridge_mat,
		"fabric_red": a.fabric_red_mat,
		"battery": a.battery_mat,
		"gummy": a.gummy_mat,
		"medkit": a.medkit_mat,
	}

	if ResourceLoader.exists("res://scenes/props/pickup_battery.tscn"):
		a.pickup_battery_scene = load("res://scenes/props/pickup_battery.tscn") as PackedScene
	if ResourceLoader.exists("res://scenes/props/pickup_medkit.tscn"):
		a.pickup_medkit_scene = load("res://scenes/props/pickup_medkit.tscn") as PackedScene
	if ResourceLoader.exists("res://scenes/props/pickup_gummy.tscn"):
		a.pickup_gummy_scene = load("res://scenes/props/pickup_gummy.tscn") as PackedScene
	if ResourceLoader.exists("res://scenes/props/wall_lever.tscn"):
		a.wall_lever_scene = load("res://scenes/props/wall_lever.tscn") as PackedScene

	return a


func get_material(slot: String) -> StandardMaterial3D:
	return materials_by_slot.get(slot, wall_mat) as StandardMaterial3D


func get_box_mesh(sz: Vector3) -> BoxMesh:
	var key := "%d_%d_%d" % [int(round(sz.x * 100.0)), int(round(sz.y * 100.0)), int(round(sz.z * 100.0))]
	if _box_mesh_cache.has(key):
		return _box_mesh_cache[key] as BoxMesh
	var bm := BoxMesh.new()
	bm.size = sz
	_box_mesh_cache[key] = bm
	return bm


func get_cyl_mesh(radius: float, height: float, segs: int = 12) -> CylinderMesh:
	var key := "%d_%d_%d" % [int(round(radius * 1000.0)), int(round(height * 1000.0)), segs]
	if _cyl_mesh_cache.has(key):
		return _cyl_mesh_cache[key] as CylinderMesh
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segs
	_cyl_mesh_cache[key] = cm
	return cm


func apply_materials_recursive(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mi.has_meta("mat_slot"):
				var slot := String(mi.get_meta("mat_slot"))
				var mat := get_material(slot)
				if mat != null:
					mi.material_override = mat


func add_cached_box(parent: Node3D, box_name: String, pos: Vector3, box_size: Vector3, mat: Material, with_collision: bool = false) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = get_box_mesh(box_size)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not with_collision:
		mi.name = box_name
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	parent.add_child(body)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box_size
	col.shape = sh
	body.add_child(col)
	return body


func add_cached_cyl(parent: Node3D, cyl_name: String, pos: Vector3, radius: float, height: float, mat: Material, segs: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = cyl_name
	mi.position = pos
	mi.mesh = get_cyl_mesh(radius, height, segs)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
