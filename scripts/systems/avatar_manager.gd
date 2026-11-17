class_name AvatarManager
extends Node

## Manages remote multiplayer player avatars using dummi.glb (DummiAvatar)
## and synchronizes custom player-drawn faces across peers.

var world_parent: Node3D = null
var assets: RoomAssets = null
var room_mgr: RoomManager = null
var bulb_on_mat: Material = null
var gummy_on_mat: Material = null

var remote_players: Dictionary = {} # peer_key -> Dictionary
var peer_faces: Dictionary = {}     # peer_key -> ImageTexture


func initialize(p_world: Node3D, p_assets: RoomAssets, p_room_mgr: RoomManager, p_bulb_mat: Material, p_gummy_mat: Material) -> void:
	world_parent = p_world
	assets = p_assets
	room_mgr = p_room_mgr
	bulb_on_mat = p_bulb_mat
	gummy_on_mat = p_gummy_mat


func has_alive_remote_players() -> bool:
	for rp_v in remote_players.values():
		if rp_v is Dictionary and not bool((rp_v as Dictionary).get("dead", false)):
			return true
	return false


func is_locker_occupied(r_idx: int, l_idx: int) -> bool:
	for pk in remote_players.keys():
		var rp: Dictionary = remote_players[pk]
		if bool(rp.get("dead", false)) or not bool(rp.get("hiding", false)):
			continue
		if int(rp.get("hide_room", -1)) == r_idx and int(rp.get("hide_locker", -1)) == l_idx:
			return true
	return false


func get_remote_hiding_kind(rp: Dictionary) -> String:
	if not bool(rp.get("hiding", false)) or room_mgr == null:
		return ""
	var hr := int(rp.get("hide_room", -1))
	var hl := int(rp.get("hide_locker", -1))
	var r_inst: RoomScene = room_mgr.room_by_idx.get(hr) as RoomScene
	if r_inst != null and hl >= 0 and hl < r_inst.lockers.size():
		return String(r_inst.lockers[hl].get("kind", "locker"))
	return "locker"


func on_remote_face(peer_key: String, png_bytes: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_png_from_buffer(png_bytes) != OK:
		return
	img.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	peer_faces[peer_key] = tex
	if remote_players.has(peer_key):
		var rp: Dictionary = remote_players[peer_key]
		var av := rp.get("avatar") as DummiAvatar
		if is_instance_valid(av):
			av.set_face_texture(tex)


func on_remote_peer_disconnected(peer_key: String) -> void:
	peer_faces.erase(peer_key)
	if remote_players.has(peer_key):
		var rp: Dictionary = remote_players[peer_key]
		var node: Variant = rp.get("node")
		if node is Node3D and is_instance_valid(node):
			(node as Node3D).queue_free()
		remote_players.erase(peer_key)


func on_remote_locker_action(peer_key: String, room_idx: int, locker_idx: int, entering: bool, face_locker: bool) -> void:
	if remote_players.has(peer_key):
		var rp: Dictionary = remote_players[peer_key]
		rp["hiding"] = entering
		rp["hide_room"] = room_idx if entering else -1
		rp["hide_locker"] = locker_idx if entering else -1
		rp["interact_t"] = 0.85

	if room_mgr == null:
		return
	var r: RoomScene = room_mgr.room_by_idx.get(room_idx) as RoomScene
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


func on_remote_state(peer_key: String, msg: Dictionary) -> void:
	var rp: Dictionary
	var newly_created := false
	if remote_players.has(peer_key):
		rp = remote_players[peer_key]
	else:
		newly_created = true
		var avatar := DummiAvatar.new()
		avatar.name = "Remote_" + peer_key
		avatar.visible = true
		if world_parent != null:
			world_parent.add_child(avatar)
		avatar.setup(assets, bulb_on_mat, gummy_on_mat, true)
		if peer_faces.has(peer_key):
			avatar.set_face_texture(peer_faces[peer_key] as Texture2D)

		rp = {
			"node": avatar,
			"avatar": avatar,
			"spot": avatar.spot_light,
			"lbl": avatar.name_label,
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
			"insp": false,
			"dh": false,
			"interact_t": 0.0,
			"net_spd": 0.0,
			"move_hold": 0.0,
			"last_pkt_ms": Time.get_ticks_msec(),
			"walk_phase": 0.0,
			"walk_blend": 0.0,
			"idle_phase": float(abs(hash(peer_key)) % 628) * 0.01,
		}
		remote_players[peer_key] = rp

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
	rp["insp"] = bool(msg.get("insp", false))
	rp["dh"] = bool(msg.get("dh", false))
	rp["cov"] = bool(msg.get("cov", false))
	var tool_i := int(msg.get("tool", 0))
	var has_gum := bool(msg.get("gum", false))
	rp["tool"] = tool_i
	rp["gummy"] = has_gum
	var show_gummy := has_gum and tool_i == 1

	var spot_node := rp.get("spot") as SpotLight3D
	if is_instance_valid(spot_node):
		spot_node.visible = next_light and (not bool(rp["dead"])) and (not bool(rp["cov"]))
		spot_node.light_color = Color(0.44, 1.0, 0.58) if show_gummy else Color(1.0, 0.96, 0.88)
	var lbl_node := rp.get("lbl") as Label3D
	if is_instance_valid(lbl_node):
		lbl_node.text = "%s [МЁРТВ]" % String(rp["name"]) if bool(rp["dead"]) else "%s [A-%03d]" % [String(rp["name"]), int(rp["room"])]
	var root_n := rp.get("node") as Node3D
	if is_instance_valid(root_n):
		root_n.visible = not bool(rp["dead"])
		if newly_created:
			root_n.position = rp["tgt_pos"]
			root_n.rotation.y = float(rp["tgt_yaw"])


func process_remote_players(delta: float) -> void:
	if remote_players.is_empty():
		return
	var a := clampf(1.0 - exp(-14.0 * delta), 0.0, 1.0)
	for pk in remote_players.keys():
		var rp: Dictionary = remote_players[pk]
		var av := rp.get("avatar") as DummiAvatar
		if not is_instance_valid(av):
			continue
		if bool(rp.get("dead", false)):
			av.visible = false
			continue
		av.visible = true
		var prev_pos := av.position
		av.position = av.position.lerp(rp["tgt_pos"], a)
		av.rotation.y = lerp_angle(av.rotation.y, float(rp["tgt_yaw"]), a)

		var hold := maxf(float(rp.get("move_hold", 0.0)) - delta, 0.0)
		rp["move_hold"] = hold
		var lerp_spd := Vector2(av.position.x - prev_pos.x, av.position.z - prev_pos.z).length() / maxf(delta, 0.001)
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
		var is_under_desk := (get_remote_hiding_kind(rp) == "under_desk")
		var light_on := bool(rp.get("light_on", false))
		var pitch := clampf(float(rp.get("tgt_pitch", 0.0)), -0.95, 0.95)
		var run_amt := 1.0 if is_sprinting else clampf((move_spd - 3.0) / 3.0, 0.0, 1.0)
		var is_inspecting := bool(rp.get("insp", false))
		var is_door_hand := bool(rp.get("dh", false))
		var show_gummy := bool(rp.get("gummy", false)) and int(rp.get("tool", 0)) == 1
		var is_covering := bool(rp.get("cov", false))

		av.update_pose(delta, idle_t, wp, wb, run_amt, pitch, is_hiding, is_under_desk, light_on, is_inspecting, is_door_hand, inter_t, show_gummy, is_covering)
