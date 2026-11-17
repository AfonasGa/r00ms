class_name InteractionController
extends Node

## Manages world raycast & smart reticle targeting, per-object reach distances
## (extended door reach = 3.4m, close pickup/locker reach), pickups, and Make Haste levers.

const DOOR_INTERACT_DIST := 3.40
const LOCKER_INTERACT_DIST := 1.85
const LEVER_INTERACT_DIST := 1.75
const PICKUP_INTERACT_DIST := 1.55

var game: Node3D = null
var cam: Camera3D = null
var player_body: CharacterBody3D = null
var interact_ray: RayCast3D = null
var player_ctrl: PlayerController = null
var room_mgr: RoomManager = null
var avatar_mgr: AvatarManager = null
var entities: EntityDirector = null
var ui_mgr: UIManager = null
var audio: RoomsAudio = null

var smart_reticle_target: Dictionary = {}


func initialize(
	p_game: Node3D,
	p_cam: Camera3D,
	p_body: CharacterBody3D,
	p_ray: RayCast3D,
	p_player_ctrl: PlayerController,
	p_room_mgr: RoomManager,
	p_avatar_mgr: AvatarManager,
	p_entities: EntityDirector,
	p_ui_mgr: UIManager,
	p_audio: RoomsAudio
) -> void:
	game = p_game
	cam = p_cam
	player_body = p_body
	interact_ray = p_ray
	player_ctrl = p_player_ctrl
	room_mgr = p_room_mgr
	avatar_mgr = p_avatar_mgr
	entities = p_entities
	ui_mgr = p_ui_mgr
	audio = p_audio
	if interact_ray != null:
		# Extended ray length so doors can be reached cleanly from DOOR_INTERACT_DIST
		interact_ray.target_position = Vector3(0.0, 0.0, -(DOOR_INTERACT_DIST + 0.25))


func try_interact() -> bool:
	if player_ctrl.is_action_locked():
		return false
	if player_ctrl.is_hiding:
		player_ctrl.exit_locker(false, entities)
		return true

	var target := smart_reticle_target if not smart_reticle_target.is_empty() else find_smart_reticle_target()
	if target.is_empty():
		return false
	return execute_interact_target(target)


func execute_interact_target(target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var kind := String(target["type"])
	if kind == "door":
		var r_idx := int(target["room_index"])
		game.call("open_room_door", r_idx, false, false)
		return true
	elif kind == "locker":
		var r_idx := int(target["room_index"])
		var l_idx := int(target["locker_index"])
		player_ctrl.enter_locker(r_idx, l_idx, entities, ui_mgr)
		return true
	elif kind == "lever":
		var r_idx := int(target["room_index"])
		var l_idx := int(target["lever_index"])
		pull_wall_lever(r_idx, l_idx)
		return true
	elif kind == "pickup":
		var node := target["node"] as Node3D
		if not is_instance_valid(node) or bool(node.get_meta("picked_up", false)):
			return false
		node.set_meta("picked_up", true)
		var pkind := String(target["pickup_kind"])
		if pkind == "battery":
			player_ctrl.batteries += 1
			player_ctrl.battery_inspect_timer = 2.0
			ui_mgr.show_toast(RoomsI18n.t("toast_battery_got", [player_ctrl.batteries]), 2.8)
		elif pkind == "gummy":
			player_ctrl.has_gummy = true
			player_ctrl.set_active_tool(1)
			player_ctrl.gummy_battery = 100.0
			player_ctrl.trigger_pickup_anim()
			ui_mgr.show_toast(RoomsI18n.t("toast_gummy_got"), 3.2)
		elif pkind == "medkit":
			game.call("heal_player", 45)
			player_ctrl.trigger_pickup_anim()
			ui_mgr.show_toast(RoomsI18n.t("toast_medkit_got"))
		audio.play_pickup()
		# Smooth pickup swoop-toward-hand animation before freeing
		if node is CollisionObject3D:
			(node as CollisionObject3D).collision_layer = 0
			(node as CollisionObject3D).collision_mask = 0
		var hand_target := cam.global_position + cam.global_transform.basis.x * 0.24 - cam.global_transform.basis.y * 0.22 - cam.global_transform.basis.z * 0.28
		var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(node, "global_position", hand_target, 0.14)
		tw.tween_property(node, "scale", Vector3.ONE * 0.15, 0.14)
		tw.chain().tween_callback(node.queue_free)
		return true
	return false


func pull_wall_lever(r_idx: int, l_idx: int) -> void:
	var r_inst: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
	if r_inst == null or l_idx < 0 or l_idx >= r_inst.levers.size():
		return
	var ld: Dictionary = r_inst.levers[l_idx]
	if bool(ld.get("used", false)):
		ui_mgr.show_toast(RoomsI18n.t("toast_lever_done"), 1.5)
		return
	ld["used"] = true
	player_ctrl.trigger_pickup_anim()

	var pivot: Node3D = ld.get("pivot") as Node3D
	if is_instance_valid(pivot):
		var tw := create_tween()
		tw.tween_property(pivot, "rotation:x", 0.55, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	audio.play_door_open()
	var bonus: float = float(game.call("add_haste_lever_time"))
	ui_mgr.show_toast(RoomsI18n.t("toast_lever_bonus", [int(bonus)]), 2.8)


func try_tap_world_interact(screen_pos: Vector2, reticle_screen_pos: Vector2) -> void:
	if player_ctrl.is_action_locked():
		return
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var space_state := player_body.get_world_3d().direct_space_state
	if space_state != null:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 5.5, 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var col: Object = hit.get("collider")
			if col != null and col.has_meta("interact_type"):
				var parsed := collider_to_interact_dict(col)
				if not parsed.is_empty():
					execute_interact_target(parsed)
					return

	if not smart_reticle_target.is_empty() and screen_pos.distance_to(reticle_screen_pos) <= 115.0:
		execute_interact_target(smart_reticle_target)


func _localize_hider_label(kind: String) -> String:
	if kind == "under_desk":
		return RoomsI18n.t("prompt_hide_desk")
	if kind == "fridge":
		return RoomsI18n.t("prompt_hide_fridge")
	return RoomsI18n.t("prompt_hide_locker")


func _localize_pickup_name(pkind: String, fallback: String) -> String:
	if pkind == "battery":
		return RoomsI18n.t("item_battery")
	if pkind == "gummy":
		return RoomsI18n.t("item_gummy")
	if pkind == "medkit":
		return RoomsI18n.t("item_medkit")
	return fallback


func collider_to_interact_dict(col: Object) -> Dictionary:
	if col == null or not col.has_meta("interact_type"):
		return {}
	if player_ctrl.is_action_locked():
		return {}
	var cam_pos := cam.global_position if is_instance_valid(cam) else player_body.global_position
	var itype := String(col.get_meta("interact_type"))
	if itype == "door":
		var r_idx := int(col.get_meta("room_index"))
		var room_inst: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
		if room_inst != null and not room_inst.door_opened:
			if is_instance_valid(room_inst.exit_anchor):
				var door_center := room_inst.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
				if cam_pos.distance_to(door_center) > DOOR_INTERACT_DIST:
					return {}
			if r_idx == 19 and not room_inst.door_broken:
				return {"type": "door", "room_index": r_idx, "label": RoomsI18n.t("prompt_door_locked")}
			return {"type": "door", "room_index": r_idx, "label": RoomsI18n.t("prompt_door_open", [r_idx + 1])}
	elif itype == "locker":
		var r_idx := int(col.get_meta("room_index"))
		var l_idx := int(col.get_meta("locker_index"))
		var r_inst: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
		var lkind := "locker"
		if r_inst != null and l_idx >= 0 and l_idx < r_inst.lockers.size():
			var ln: Node3D = r_inst.lockers[l_idx].get("node")
			lkind = String(r_inst.lockers[l_idx].get("kind", "locker"))
			if is_instance_valid(ln) and cam_pos.distance_to(ln.global_position) > LOCKER_INTERACT_DIST:
				return {}
		var lbl := RoomsI18n.t("prompt_occupied") if avatar_mgr.is_locker_occupied(r_idx, l_idx) else _localize_hider_label(lkind)
		return {
			"type": "locker",
			"room_index": r_idx,
			"locker_index": l_idx,
			"label": lbl,
		}
	elif itype == "lever":
		var r_idx := int(col.get_meta("room_index"))
		var l_idx := int(col.get_meta("lever_index"))
		var r_inst: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
		if r_inst != null and l_idx >= 0 and l_idx < r_inst.levers.size():
			var ld: Dictionary = r_inst.levers[l_idx]
			var root_node: Node3D = ld.get("root") as Node3D
			if is_instance_valid(root_node) and cam_pos.distance_to(root_node.global_position) > LEVER_INTERACT_DIST:
				return {}
			if bool(ld.get("used", false)):
				return {"type": "lever", "room_index": r_idx, "lever_index": l_idx, "label": RoomsI18n.t("prompt_lever_used")}
			return {"type": "lever", "room_index": r_idx, "lever_index": l_idx, "label": RoomsI18n.t("prompt_lever_pull")}
	elif itype == "pickup":
		var node3d := col as Node3D
		if node3d != null and (bool(node3d.get_meta("picked_up", false)) or cam_pos.distance_to(node3d.global_position) > PICKUP_INTERACT_DIST):
			return {}
		var pk := String(col.get_meta("pickup_kind"))
		var pname := _localize_pickup_name(pk, String(col.get_meta("pickup_prompt")))
		return {
			"type": "pickup",
			"node": col,
			"pickup_kind": pk,
			"label": RoomsI18n.t("prompt_pickup", [pname]),
		}
	return {}


func _find_direct_interact_target() -> Dictionary:
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		return collider_to_interact_dict(interact_ray.get_collider())
	return {}


func _target_anchor_world_pos(tgt: Dictionary) -> Vector3:
	var kind := String(tgt.get("type", ""))
	if kind == "locker":
		var r: RoomScene = room_mgr.room_by_idx.get(int(tgt["room_index"])) as RoomScene
		var li := int(tgt["locker_index"])
		if r != null and li >= 0 and li < r.lockers.size():
			var ld: Dictionary = r.lockers[li]
			var ln: Node3D = ld["node"]
			var lk := String(ld.get("kind", "locker"))
			var loc := Vector3(0.0, 0.56, 0.22) if lk == "under_desk" else Vector3(0.0, 1.16, 0.34)
			return ln.global_transform * loc
	elif kind == "door":
		var r: RoomScene = room_mgr.room_by_idx.get(int(tgt["room_index"])) as RoomScene
		if r != null and is_instance_valid(r.exit_anchor):
			return r.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
	elif kind == "lever":
		var r: RoomScene = room_mgr.room_by_idx.get(int(tgt["room_index"])) as RoomScene
		var li := int(tgt.get("lever_index", 0))
		if r != null and li >= 0 and li < r.levers.size():
			var root_node: Node3D = r.levers[li].get("root") as Node3D
			if is_instance_valid(root_node):
				return root_node.global_position
	elif kind == "pickup":
		var n := tgt.get("node") as Node3D
		if is_instance_valid(n):
			return n.global_position
	return cam.global_position - cam.global_transform.basis.z * 2.0


func find_smart_reticle_target() -> Dictionary:
	if player_ctrl.is_action_locked():
		return {}
	var direct := _find_direct_interact_target()
	if not direct.is_empty():
		var wp := _target_anchor_world_pos(direct)
		if not cam.is_position_behind(wp):
			direct["screen_pos"] = cam.unproject_position(wp)
			direct["world_pos"] = wp
			return direct

	var best_tgt: Dictionary = {}
	var best_angle := 0.24
	var space_state := player_body.get_world_3d().direct_space_state
	var cam_pos := cam.global_position
	var cam_fwd := -cam.global_transform.basis.z

	for r in room_mgr.rooms:
		if absi(r.index - room_mgr.current_room_idx) > 1:
			continue
		for li in range(r.lockers.size()):
			var ld: Dictionary = r.lockers[li]
			var ln: Node3D = ld["node"]
			if not is_instance_valid(ln):
				continue
			var lk := String(ld.get("kind", "locker"))
			var loc := Vector3(0.0, 0.56, 0.22) if lk == "under_desk" else Vector3(0.0, 1.16, 0.34)
			var wp := ln.global_transform * loc
			if cam_pos.distance_to(wp) > LOCKER_INTERACT_DIST or cam.is_position_behind(wp):
				continue
			var ang := cam_fwd.angle_to((wp - cam_pos).normalized())
			if ang < best_angle and _has_los_to_interact(space_state, cam_pos, wp):
				best_angle = ang
				var occupied := avatar_mgr.is_locker_occupied(r.index, li)
				var raw_lbl := String(ld.get("label", ""))
				best_tgt = {
					"type": "locker",
					"room_index": r.index,
					"locker_index": li,
					"label": RoomsI18n.t("prompt_occupied") if occupied else _localize_hider_label(lk),
					"screen_pos": cam.unproject_position(wp),
					"world_pos": wp,
				}
		if not r.door_opened and is_instance_valid(r.exit_anchor):
			var dwp := r.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
			if cam_pos.distance_to(dwp) <= DOOR_INTERACT_DIST and not cam.is_position_behind(dwp):
				var dang := cam_fwd.angle_to((dwp - cam_pos).normalized())
				if dang < best_angle and _has_los_to_interact(space_state, cam_pos, dwp):
					best_angle = dang
					best_tgt = {
						"type": "door",
						"room_index": r.index,
						"label": (RoomsI18n.t("prompt_door_locked") if (r.index == 19 and not r.door_broken) else RoomsI18n.t("prompt_door_open", [r.index + 1])),
						"screen_pos": cam.unproject_position(dwp),
						"world_pos": dwp,
					}
	return best_tgt


func _has_los_to_interact(space_state: PhysicsDirectSpaceState3D, from_pos: Vector3, to_pos: Vector3) -> bool:
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
	return hp.distance_to(to_pos) < 1.0
