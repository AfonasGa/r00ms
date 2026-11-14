extends "res://scripts/rooms/rooms_doors.gd"

func _maybe_spawn_door_entities(room_num: int) -> void:
	if not _is_entity_authority():
		return
	if _a60_active or _a120_active:
		return
	# In the first 20 rooms NO monsters appear. A-120 starts appearing after room A-020!
	if room_num > 20:
		var chance_120 := clampf(0.06 + float(room_num - 20) * 0.0007, 0.06, 0.13)
		if _rng.randf() < chance_120:
			_spawn_a120()


func _find_first_closed_door_room() -> RoomBuilder.RoomInstance:
	for r in _rooms:
		if not r.door_opened and not r.door_broken:
			return r
	return null


func _spawn_a60(force_prime: bool = false) -> void:
	if _rooms.is_empty():
		return
	var target_r := _find_first_closed_door_room()
	if target_r == null:
		return
	_start_a60_local(target_r.index, force_prime)
	if _is_entity_authority() and _net != null and _net.is_online():
		_net.broadcast_entity_event({
			"k": "a60_spawn",
			"door": target_r.index,
			"prime": force_prime,
		}, true)


func _start_a60_local(target_door_idx: int, is_prime: bool) -> void:
	_a60_path.clear()
	if _rooms.is_empty():
		return
	var target_r: RoomBuilder.RoomInstance = _room_by_idx.get(target_door_idx)
	if target_r == null:
		target_r = _find_first_closed_door_room()
	if target_r == null:
		target_r = _rooms[-1]
	_a60_target_door_idx = target_r.index
	var start_entry_dir: Vector3 = _rooms[0].in_dir
	_a60_path.append(_rooms[0].center_pos - start_entry_dir * 260.0 + Vector3(0.0, 1.55, 0.0))
	for r in _rooms:
		if r.index <= _a60_target_door_idx:
			_a60_path.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
			if r.index < _a60_target_door_idx:
				_a60_path.append(r.exit_pos + Vector3(0.0, 1.55, 0.0))
	_a60_path.append(target_r.exit_pos + Vector3(0.0, 1.55, 0.0))
	if _a60_path.size() < 2:
		return

	_a60_active = true
	_a60_phase = 2
	_a60_is_prime = is_prime
	_a60_prime_rebounds = 0
	_a60_prime_table_burned = false
	_a60_prime_hit_cd = 0.0
	_a60_scare_snd_cd = 0.0
	_a60_hint_timer = (2.4 if _highest_opened < 100 else 0.0) if not is_prime else 0.0
	if is_prime:
		_a60_prime_flicker_active = true
		_a60_prime_flicker_gap_t = 0.0

	if is_prime:
		_a60_light.light_color = Color(0.22, 0.84, 1.0)
		_a60_sprite.modulate = Color(0.55, 0.96, 1.0)
	else:
		_a60_light.light_color = Color(1.0, 0.14, 0.12)
		_a60_sprite.modulate = Color(1.0, 0.94, 0.94)

	_a60_path_idx = 1
	_a60_node.position = _a60_path[0]
	_a60_node.visible = true
	_flicker_nearby_lights(1.4)
	audio.start_a60_spawn(is_prime, _highest_opened < 100)


func _spawn_a120() -> void:
	if _rooms.is_empty():
		return
	var spawn_idx := mini(_highest_opened + 3, _rooms[-1].index)
	var roll := _rng.randf()
	var rb := 0
	if roll < 0.22:
		rb = 0
	elif roll < 0.52:
		rb = 1
	elif roll < 0.80:
		rb = 2
	else:
		rb = 3
	_start_a120_local(spawn_idx, rb)
	if _is_entity_authority() and _net != null and _net.is_online():
		_net.broadcast_entity_event({
			"k": "a120_spawn",
			"room": spawn_idx,
			"rb": rb,
		}, true)


func _start_a120_local(spawn_idx: int, rb: int) -> void:
	if _rooms.is_empty():
		return
	var spawn_r: RoomBuilder.RoomInstance = _room_by_idx.get(spawn_idx)
	if spawn_r == null:
		spawn_r = _rooms[-1]

	_a120_active = true
	_a120_phase = 1
	_a120_substage = 0
	_a120_warn_timer = 3.4
	_a120_pause_timer = 0.0
	_a120_rebounds = rb
	_a120_initial_rebounds = rb
	_a120_drum_bounce = 0.0
	_a120_anim_timer = 0.0
	_a120_hit_cd = 0.0
	_a120_path.clear()
	_a120_path_idx = 0
	_a120_sprite.position = Vector3.ZERO
	_a120_sprite.scale = Vector3.ONE
	_a120_node.position = spawn_r.center_pos + Vector3(0.0, 1.55, 0.0)
	_net_a120_tgt = _a120_node.position
	_a120_node.visible = true
	_a120_sprite.modulate = Color(1.0, 1.0, 1.0)
	_flicker_nearby_lights(1.6)
	audio.start_a120_spawn()


func _build_a120_corridor_path(from_room_idx: int, to_room_idx: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var step := 1 if to_room_idx >= from_room_idx else -1
	var cur := from_room_idx
	while true:
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(cur)
		if r != null:
			pts.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
		if cur == to_room_idx:
			break
		cur += step
	return pts


func _get_room_idx_near(pos: Vector3) -> int:
	var best_idx := _current_room_idx
	var best_dist := 1e9
	for r in _rooms:
		var d := r.center_pos.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best_idx = r.index
	return best_idx


func _get_a120_live_target() -> Vector3:
	var best_pos := (_locker_eye + _locker_fwd * 0.95) if _is_hiding else player_body.global_position
	var best_exposed := not _is_hiding
	var best_d := _a120_node.global_position.distance_squared_to(best_pos)
	for pk in _remote_players.keys():
		var rp: Dictionary = _remote_players[pk]
		if bool(rp.get("dead", false)):
			continue
		var r_exp := not bool(rp.get("hiding", false))
		var rp_pos: Vector3 = rp.get("tgt_pos", Vector3.ZERO)
		var d := _a120_node.global_position.distance_squared_to(rp_pos)
		if (r_exp and not best_exposed) or (r_exp == best_exposed and d < best_d):
			best_exposed = r_exp
			best_pos = rp_pos
			best_d = d
	return Vector3(best_pos.x, 1.55, best_pos.z)


func _handle_a120_hit() -> void:
	if _is_hiding:
		return
	_a120_hit_cd = 1.5
	_a120_active = false
	_a120_phase = 0
	_a120_substage = 0
	_a120_node.visible = false
	audio.stop_a120()
	audio.play_a120_scream()
	if _net != null and _net.is_online():
		_net.broadcast_entity_event({"k": "a120_end", "from_client": not _is_entity_authority()}, true)

	_hp -= 90
	audio.low_hp_mode = (_hp <= 25 and _hp > 0)
	_shake_amount = 0.12

	if _hp <= 0:
		_trigger_death("A-120", "", {"a120_rebounded": _a120_rebounds < _a120_initial_rebounds})
		return

	var warp_safe_min := _checkpoint_room + 4
	var back_steps := _rng.randi_range(3, 4)
	var target_idx := _current_room_idx - back_steps
	if _current_room_idx >= warp_safe_min and target_idx > _checkpoint_room and _room_by_idx.has(target_idx):
		_warp_player_to_room(target_idx, back_steps)
	else:
		(_ui["dmg_flash"] as ColorRect).color = Color(0.85, 0.08, 0.08, 0.65)
		_show_toast("Happy Scribble (A-120) нанёс 90 урона! (%d HP)" % _hp, 2.6)


func _warp_player_to_room(target_idx: int, back_steps: int) -> void:
	if _is_hiding:
		return
	var target_r: RoomBuilder.RoomInstance = _room_by_idx.get(target_idx)
	if target_r == null:
		return
	# A warp must always land. Break out of any locker/hiding state first, otherwise
	# the hide camera keeps snapping the player straight back into the locker.
	_force_leave_hiding_for_warp()

	player_body.position = target_r.center_pos + Vector3(0.0, 0.05, 0.0)
	player_body.velocity = Vector3.ZERO
	_current_room_idx = target_idx
	_update_room_visibility()

	var dir := target_r.out_dir
	var face_yaw := atan2(-dir.x, -dir.z)
	_target_yaw = face_yaw
	_yaw = face_yaw
	_target_pitch = 0.0
	_pitch = 0.0
	_apply_camera_rotation()
	_fov = 104.0
	cam.fov = 104.0

	# White noise + white vignette that fades away over ~10 seconds
	_a120_warp_fx_t = _a120_warp_fx_dur
	_update_warp_fx(0.0)

	(_ui["dmg_flash"] as ColorRect).color = Color(0.85, 0.96, 1.0, 0.78)
	_show_toast("ВАРП! Happy Scribble отбросил вас на %d комн. назад (A-%03d) [-90 HP]" % [back_steps, target_idx], 3.4)


func _flicker_nearby_lights(duration: float) -> void:
	if _power_out:
		return
	# Subtle momentary dip via tweening lights on active rooms
	for r in _rooms:
		if r.is_dark_room:
			continue
		for i in range(r.ceiling_lights.size()):
			var omni := r.ceiling_lights[i]
			var base_e := r.light_base_energies[i]
			var tw := create_tween()
			tw.tween_property(omni, "light_energy", base_e * 0.12, 0.08)
			tw.tween_property(omni, "light_energy", base_e, 0.12)
			tw.tween_property(omni, "light_energy", base_e * 0.05, 0.09)
			tw.tween_property(omni, "light_energy", base_e, duration * 0.25)
