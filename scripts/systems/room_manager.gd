class_name RoomManager
extends Node

## Loads, instantiates, pools, culls, and manages all RoomScene (.tscn) rooms.
## Eliminates procedural room construction in code and prevents GC frame hitches via per-type pooling.

const ROOM_SCENE_PATHS := {
	"lobby": "res://scenes/rooms/room_lobby.tscn",
	"l_turn_left": "res://scenes/rooms/room_l_turn_left.tscn",
	"l_turn_right": "res://scenes/rooms/room_l_turn_right.tscn",
	"bridge_room": "res://scenes/rooms/room_bridge_room.tscn",
	"locker_room": "res://scenes/rooms/room_locker_room.tscn",
	"three_locker": "res://scenes/rooms/room_three_locker.tscn",
	"new_2_locker": "res://scenes/rooms/room_new_2_locker.tscn",
	"desk_room": "res://scenes/rooms/room_desk_room.tscn",
	"meeting_room": "res://scenes/rooms/room_meeting_room.tscn",
	"bookshelf_room": "res://scenes/rooms/room_bookshelf_room.tscn",
	"storage_room": "res://scenes/rooms/room_storage_room.tscn",
	"kitchen": "res://scenes/rooms/room_kitchen.tscn",
	"plant_room": "res://scenes/rooms/room_plant_room.tscn",
	"double_plant": "res://scenes/rooms/room_double_plant.tscn",
	"table_room": "res://scenes/rooms/room_table_room.tscn",
	"mannequin_room": "res://scenes/rooms/room_mannequin_room.tscn",
	"w_shaped": "res://scenes/rooms/room_w_shaped.tscn",
	"closet_room": "res://scenes/rooms/room_closet_room.tscn",
}

const STRAIGHT_POOL: Array[String] = [
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

var rooms_container: Node3D = null
var assets: RoomAssets = null

var rooms: Array[RoomScene] = []
var room_by_idx: Dictionary = {}
var occupied_cells: Dictionary = {}
var opening_doors: Array[Dictionary] = []

var world_seed := 0
var next_cell := Vector2i.ZERO
var next_in_dir := Vector3(0.0, 0.0, -1.0)
var next_room_index := 0
var highest_opened := 0
var current_room_idx := 0

var power_out := false
var door50_flicker_active := false
var door50_flicker_t := 0.0

var _room_scenes: Dictionary = {}
var _room_pool: Dictionary = {} # room_type -> Array[RoomScene]


func initialize(container: Node3D, shared_assets: RoomAssets) -> void:
	rooms_container = container
	assets = shared_assets
	_room_scenes.clear()
	for rtype in ROOM_SCENE_PATHS.keys():
		var path: String = ROOM_SCENE_PATHS[rtype]
		if ResourceLoader.exists(path):
			_room_scenes[rtype] = load(path) as PackedScene


static func dir_to_grid_step(d: Vector3) -> Vector2i:
	return Vector2i(int(round(d.x)), int(round(d.z)))


static func rotate_left(d: Vector3) -> Vector3:
	return Vector3(d.z, 0.0, -d.x).normalized()


static func rotate_right(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0.0, d.x).normalized()


func _pick_room_type(room_index: int, turn_type: int, rng: RandomNumberGenerator) -> String:
	if room_index == 0 or (room_index % 50 == 0 and turn_type == 0):
		return "lobby"
	if turn_type == -1:
		return "l_turn_left"
	if turn_type == 1:
		return "l_turn_right"
	var pool: Array[String] = STRAIGHT_POOL.duplicate()
	if room_index >= 20:
		pool.append("double_plant")
	else:
		pool.append("plant_room")
	if room_index >= 10:
		pool.append("mannequin_room")
	if room_index >= 12:
		pool.append("bridge_room")
	return pool[rng.randi_range(0, pool.size() - 1)]


func _exit_tree() -> void:
	for arr_v in _room_pool.values():
		if arr_v is Array:
			for r_v in arr_v:
				if r_v is Node and is_instance_valid(r_v):
					(r_v as Node).free()
	_room_pool.clear()


func _acquire_room_scene(rtype: String) -> RoomScene:
	if _room_pool.has(rtype):
		var arr: Array = _room_pool[rtype]
		if not arr.is_empty():
			var recycled: RoomScene = arr.pop_back() as RoomScene
			if is_instance_valid(recycled):
				if recycled.get_parent() == null and rooms_container != null:
					rooms_container.add_child(recycled)
				return recycled
	var ps: PackedScene = _room_scenes.get(rtype, _room_scenes.get("closet_room")) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate() as RoomScene
	if inst != null and rooms_container != null:
		rooms_container.add_child(inst)
		inst.bind_scene_nodes(assets)
	return inst


func _release_room_scene(r: RoomScene) -> void:
	if not is_instance_valid(r):
		return
	var rtype := r.room_type
	r.reset_for_pool(assets)
	# CRITICAL: detach from SceneTree while pooled so physics StaticBody3Ds never remain as invisible walls!
	if r.get_parent() != null:
		r.get_parent().remove_child(r)
	if not _room_pool.has(rtype):
		_room_pool[rtype] = []
	var arr: Array = _room_pool[rtype]
	if arr.size() < 3:
		arr.append(r)
	else:
		r.queue_free()


func reset_world(forced_seed: int, render_quality: int, lights_out_mod: bool, haste_enabled: bool, vis_radius: int, start_room_idx: int = 0) -> void:
	for r in rooms:
		_release_room_scene(r)
	rooms.clear()
	room_by_idx.clear()
	occupied_cells.clear()
	opening_doors.clear()

	if forced_seed > 0:
		world_seed = forced_seed & 0x7FFFFFFF
	else:
		var tmp_rng := RandomNumberGenerator.new()
		tmp_rng.randomize()
		world_seed = maxi(int(tmp_rng.randi() & 0x3FFFFFFF), 1)

	next_cell = Vector2i.ZERO
	next_in_dir = Vector3(0.0, 0.0, -1.0)
	next_room_index = start_room_idx
	highest_opened = start_room_idx
	current_room_idx = start_room_idx
	power_out = lights_out_mod
	door50_flicker_active = false
	door50_flicker_t = 0.0

	var init_count := 5 if render_quality == SettingsManager.RenderQuality.MOBILE_OPT else 7
	for _i in range(init_count):
		spawn_next_room(render_quality, haste_enabled, vis_radius)
	update_room_visibility(vis_radius)


func spawn_next_room(render_quality: int, haste_enabled: bool, vis_radius: int) -> RoomScene:
	var idx := next_room_index
	next_room_index += 1
	var cell := next_cell
	var in_dir := next_in_dir
	occupied_cells[cell] = true

	# Strictly deterministic per-room RNG derived ONLY from (world_seed, idx)
	var room_rng := RandomNumberGenerator.new()
	var mixed_seed := (((world_seed * 1103515245) + ((idx + 1) * 2654435761)) ^ (idx * 747796405)) & 0x7FFFFFFF
	if mixed_seed <= 0:
		mixed_seed = idx + 1
	room_rng.seed = mixed_seed

	var out_dir := in_dir
	if idx >= 2:
		var roll := room_rng.randf()
		var cand := in_dir
		if roll < 0.17:
			cand = rotate_left(in_dir)
		elif roll < 0.34:
			cand = rotate_right(in_dir)
		if cand.z <= 0.1:
			var step1 := cell + dir_to_grid_step(cand)
			var step2 := step1 + dir_to_grid_step(cand)
			if not occupied_cells.has(step1) and not occupied_cells.has(step2):
				out_dir = cand

	var yaw := atan2(-in_dir.x, -in_dir.z)
	var local_out := (Basis(Vector3.UP, -yaw) * out_dir).normalized()
	var ttype := 0
	if local_out.x < -0.5:
		ttype = -1
	elif local_out.x > 0.5:
		ttype = 1

	var rtype := _pick_room_type(idx, ttype, room_rng)
	var r := _acquire_room_scene(rtype)
	if r == null:
		return null

	# Dark rooms never appear before room 50 unless lights_out / power_out is active
	var is_dark := power_out or (idx == 50) or (idx > 50 and rtype != "lobby" and room_rng.randf() < 0.30)
	r.configure_room(idx, cell, in_dir, out_dir, is_dark, assets, room_rng, haste_enabled)
	rooms.append(r)
	room_by_idx[idx] = r

	next_cell = cell + dir_to_grid_step(out_dir)
	next_in_dir = out_dir

	# Recycle old rooms far behind to keep FPS steady with zero GC spikes
	var max_keep := 10 if render_quality == SettingsManager.RenderQuality.MOBILE_OPT else 16
	var back_keep := 4 if render_quality == SettingsManager.RenderQuality.MOBILE_OPT else 7
	while rooms.size() > max_keep and rooms[0].index < current_room_idx - back_keep:
		var old_r: RoomScene = rooms.pop_front()
		room_by_idx.erase(old_r.index)
		_release_room_scene(old_r)
	update_room_visibility(vis_radius)
	return r


func ensure_ahead_rooms(render_quality: int, haste_enabled: bool, vis_radius: int) -> void:
	var min_keep := 9 if render_quality == SettingsManager.RenderQuality.MOBILE_OPT else 14
	var ahead_keep := 4 if render_quality == SettingsManager.RenderQuality.MOBILE_OPT else 6
	while rooms.size() < min_keep or rooms[-1].index < highest_opened + ahead_keep:
		spawn_next_room(render_quality, haste_enabled, vis_radius)
	update_room_visibility(vis_radius)


func update_room_visibility(vis_radius: int) -> void:
	for r in rooms:
		if is_instance_valid(r):
			r.set_culled_visible(absi(r.index - current_room_idx) <= vis_radius)


func process_doors(delta: float) -> void:
	for i in range(opening_doors.size() - 1, -1, -1):
		var d: Dictionary = opening_doors[i]
		var pivot_raw: Variant = d["pivot"]
		if not is_instance_valid(pivot_raw):
			opening_doors.remove_at(i)
			continue
		var is_slam := bool(d.get("slam", false))
		var dur := 0.34 if is_slam else 0.42
		var p: float = minf(float(d["progress"]) + delta / dur, 1.0)
		d["progress"] = p
		var pivot := pivot_raw as Node3D
		var target_ang: float = -PI * 0.88 if is_slam else -PI * 0.56
		var curve := 1.0 - pow(1.0 - p, 3.0)
		var bounce := sin(maxf(p - 0.55, 0.0) / 0.45 * PI * 2.0) * (0.09 if is_slam else 0.035) * (1.0 - p)
		pivot.rotation.y = target_ang * (curve + bounce)
		if p >= 1.0:
			pivot.rotation.y = target_ang
			opening_doors.remove_at(i)


func process_door50_flicker(delta: float) -> bool:
	if not door50_flicker_active:
		return false
	door50_flicker_t -= delta
	var f_val := randf()
	for r in rooms:
		if not is_instance_valid(r) or not r.visible:
			continue
		for om in r.ceiling_lights:
			if is_instance_valid(om):
				om.visible = (f_val > 0.35)
				om.light_energy = 0.15 if f_val <= 0.35 else (1.8 if f_val > 0.85 else 0.8)
	if door50_flicker_t <= 0.0:
		door50_flicker_active = false
		return true # Signal caller to trigger full power outage
	return false


func trigger_power_outage(audio: RoomsAudio) -> bool:
	if power_out:
		return false
	power_out = true
	if audio != null:
		audio.play_power_down()

	for r in rooms:
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
			var wr_assets: WeakRef = weakref(assets)
			var mtw := create_tween()
			mtw.tween_interval(0.40)
			mtw.tween_callback(func() -> void:
				var ref_m: Variant = wr_m.get_ref()
				var ref_a: Variant = wr_assets.get_ref()
				if ref_m is MeshInstance3D and is_instance_valid(ref_m) and ref_a != null:
					(ref_m as MeshInstance3D).material_override = (ref_a as RoomAssets).lamp_off_mat
			)
	return true


func restore_power() -> void:
	power_out = false
	for r in rooms:
		if is_instance_valid(r):
			r.is_dark_room = false
			r.set_lights_active(true, assets)


func flicker_nearby_lights(duration: float) -> void:
	if power_out:
		return
	for r in rooms:
		if not is_instance_valid(r) or r.is_dark_room or not r.visible:
			continue
		for i in range(r.ceiling_lights.size()):
			var omni := r.ceiling_lights[i]
			if not is_instance_valid(omni):
				continue
			var base_e := r.light_base_energies[i]
			var tw := create_tween()
			tw.tween_property(omni, "light_energy", base_e * 0.12, 0.08)
			tw.tween_property(omni, "light_energy", base_e, 0.12)
			tw.tween_property(omni, "light_energy", base_e * 0.05, 0.09)
			tw.tween_property(omni, "light_energy", base_e, duration * 0.25)


func break_door_by_a60(r_idx: int, is_prime: bool, imprint_tex: Texture2D, rng: RandomNumberGenerator, audio: RoomsAudio) -> bool:
	var r: RoomScene = room_by_idx.get(r_idx) as RoomScene
	if r == null:
		return false
	r.door_opened = true
	r.door_broken = true
	r.disable_door_collision()
	if is_instance_valid(r.door_pivot):
		r.door_pivot.visible = false
		var anchor := r.door_pivot.get_parent() as Node3D
		if is_instance_valid(anchor):
			var broken_root := Node3D.new()
			broken_root.name = "BrokenDoorSmashed"
			anchor.add_child(broken_root)
			r.register_dynamic_node(broken_root)

			var leaf_w := RoomScene.DOOR_W - 0.20
			var slab := Node3D.new()
			slab.position = Vector3(rng.randf_range(-0.18, 0.18), 0.06, -1.42)
			slab.rotation = Vector3(-PI * 0.5 + 0.03, rng.randf_range(-0.22, 0.22), rng.randf_range(-0.08, 0.08))
			broken_root.add_child(slab)
			assets.add_cached_box(slab, "SmashedLeaf", Vector3.ZERO, Vector3(leaf_w, RoomScene.DOOR_H - 0.06, 0.10), assets.door_mat, false)
			assets.add_cached_box(slab, "SmashedKnob", Vector3(leaf_w * 0.5 - 0.18, -0.32, 0.075), Vector3(0.10, 0.06, 0.06), assets.fridge_mat, false)

			if imprint_tex != null:
				var imp := Sprite3D.new()
				imp.texture = imprint_tex
				imp.shaded = false
				imp.double_sided = true
				imp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				imp.pixel_size = 1.50 / float(maxi(imprint_tex.get_width(), 1))
				imp.modulate = Color(0.32, 0.92, 1.0, 0.90) if is_prime else Color(1.0, 0.22, 0.18, 0.88)
				imp.position = Vector3(0.0, 0.12, 0.062)
				slab.add_child(imp)

			for s_i in range(4):
				var sp := assets.add_cached_box(
					broken_root,
					"Splinter_%d" % s_i,
					Vector3(rng.randf_range(-0.95, 0.95), 0.03, rng.randf_range(-2.3, -0.35)),
					Vector3(rng.randf_range(0.06, 0.14), 0.04, rng.randf_range(0.28, 0.62)),
					assets.plank_dark_mat,
					false
				)
				sp.rotation.y = rng.randf_range(-PI, PI)

	if audio != null:
		audio.play_a60_door_break(is_prime)
	return true


func find_first_closed_door_room() -> RoomScene:
	for r in rooms:
		if not r.door_opened and not r.door_broken:
			return r
	return null


func get_room_idx_near(pos: Vector3) -> int:
	var best_idx := current_room_idx
	var best_dist := 1e9
	for r in rooms:
		var d := r.center_pos.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best_idx = r.index
	return best_idx


func update_player_current_room(player_pos: Vector3, vis_radius: int) -> bool:
	var prev_room := current_room_idx
	var max_d_sq := (RoomScene.CELL_SIZE * 0.52) * (RoomScene.CELL_SIZE * 0.52)
	for r in rooms:
		if r.center_pos.distance_squared_to(player_pos) < max_d_sq:
			current_room_idx = r.index
			break
	if current_room_idx != prev_room:
		update_room_visibility(vis_radius)
		return true
	return false
