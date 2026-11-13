extends "res://scripts/rooms/rooms_interact.gd"

func _trigger_power_outage() -> void:
	if _power_out:
		return
	_power_out = true
	audio.play_power_down()
	_show_toast("Электричество вырубилось! Дальше света больше не будет...", 3.4)
	_shake_amount = maxf(_shake_amount, 0.045)

	for r in _rooms:
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
			var wr_assets: WeakRef = weakref(_assets)
			var mtw := create_tween()
			mtw.tween_interval(0.40)
			mtw.tween_callback(func() -> void:
				var ref_m: Variant = wr_m.get_ref()
				var ref_a: Variant = wr_assets.get_ref()
				if ref_m is MeshInstance3D and is_instance_valid(ref_m) and ref_a != null:
					var mm := ref_m as MeshInstance3D
					mm.material_override = (ref_a as RoomBuilder.SharedAssets).lamp_off_mat
			)


func _break_door_by_a60(r_idx: int, is_prime: bool) -> void:
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null:
		return
	r.door_opened = true
	r.door_broken = true
	if r.door_collider != null:
		r.door_collider.collision_layer = 0
		r.door_collider.collision_mask = 0
	if is_instance_valid(r.door_pivot):
		r.door_pivot.visible = false
		var anchor := r.door_pivot.get_parent()
		if is_instance_valid(anchor):
			var broken_root := Node3D.new()
			broken_root.name = "BrokenDoorSmashed"
			anchor.add_child(broken_root)

			var leaf_w := RoomBuilder.DOOR_W - 0.20
			var slab := Node3D.new()
			slab.position = Vector3(_rng.randf_range(-0.18, 0.18), 0.06, -1.42)
			slab.rotation = Vector3(-PI * 0.5 + 0.03, _rng.randf_range(-0.22, 0.22), _rng.randf_range(-0.08, 0.08))
			broken_root.add_child(slab)
			RoomBuilder._add_box(slab, "SmashedLeaf", Vector3.ZERO, Vector3(leaf_w, RoomBuilder.DOOR_H - 0.06, 0.10), _assets.door_mat, false)
			RoomBuilder._add_box(slab, "SmashedKnob", Vector3(leaf_w * 0.5 - 0.18, -0.32, 0.075), Vector3(0.10, 0.06, 0.06), _assets.fridge_mat, false)

			var tex := _a60_last_tex if _a60_last_tex != null else _a60_frames[0]
			if tex != null:
				var imp := Sprite3D.new()
				imp.texture = tex
				imp.shaded = false
				imp.double_sided = true
				imp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				imp.pixel_size = 1.50 / float(maxi(tex.get_width(), 1))
				imp.modulate = Color(0.32, 0.92, 1.0, 0.90) if is_prime else Color(1.0, 0.22, 0.18, 0.88)
				imp.position = Vector3(0.0, 0.12, 0.062)
				slab.add_child(imp)

			for s_i in range(4):
				var sp := RoomBuilder._add_box(
					broken_root,
					"Splinter_%d" % s_i,
					Vector3(_rng.randf_range(-0.95, 0.95), 0.03, _rng.randf_range(-2.3, -0.35)),
					Vector3(_rng.randf_range(0.06, 0.14), 0.04, _rng.randf_range(0.28, 0.62)),
					_assets.plank_dark_mat,
					false
				)
				sp.rotation.y = _rng.randf_range(-PI, PI)

	audio.play_a60_door_break(is_prime)
	_shake_amount = maxf(_shake_amount, 0.09)
	_advance_door_progress(r_idx, false)


func _force_leave_hiding_for_warp() -> void:
	# Instant, animation-free teardown of the hiding state (used by the A-120 warp).
	_locker_transition_t = 1.0
	_locker_transition_entering = false
	_door_hand_timer = 0.0
	if _is_hiding and is_instance_valid(_hiding_door_pivot):
		_hiding_door_pivot.rotation.y = 0.0
	if _is_hiding and _hiding_room_idx >= 0 and _hiding_locker_idx >= 0 and _net != null and _net.is_online():
		_net.broadcast_locker_action(_hiding_room_idx, _hiding_locker_idx, false, false)
	_is_hiding = false
	_hiding_room_idx = -1
	_hiding_locker_idx = -1
	_hiding_kind = "locker"
	_hiding_door_pivot = null
	_hiding_eye_local_y = 1.48
	_hide_time = 0.0
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	audio.stop_darkness()
	var drect := _ui.get("darkness_rect") as Control
	if drect != null:
		drect.visible = false
	var mask := _ui.get("locker_mask") as ColorRect
	if mask != null:
		mask.color = Color(0.0, 0.0, 0.0, 0.0)
		mask.visible = false
	player_col.disabled = false
	if _vm_holder != null:
		_vm_holder.visible = true
	if _anim_hand != null:
		_anim_hand.visible = false
	_light_on = true if _active_tool == 1 else _was_light_before_hide


func _enter_locker(r_idx: int, l_idx: int) -> void:
	if _is_action_locked() or _is_hiding:
		return
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null or l_idx < 0 or l_idx >= r.lockers.size():
		return
	if _is_locker_occupied(r_idx, l_idx):
		_show_toast("Спот занят!", 1.8)
		return
	var locker_data: Dictionary = r.lockers[l_idx]
	var lnode: Node3D = locker_data["node"]

	_is_hiding = true
	_hiding_room_idx = r_idx
	_hiding_locker_idx = l_idx
	_hiding_kind = String(locker_data.get("kind", "locker"))
	_hiding_door_pivot = locker_data.get("door_pivot") as Node3D
	_hide_time = 0.0
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	_target_pitch = 0.0
	_pitch = 0.0
	_was_light_before_hide = _light_on
	if _hiding_kind == "under_desk":
		_light_on = false
	player_col.disabled = true
	if _vm_holder != null:
		_vm_holder.visible = false

	_locker_cam_from = cam.global_position
	_locker_transition_t = 0.0
	_locker_transition_entering = true
	_locker_transition_duration = 1.00

	var eye_loc: Vector3 = locker_data.get("eye_local", Vector3(0.0, 1.48, 0.05))
	var exit_loc: Vector3 = locker_data.get("exit_local", Vector3(0.0, 0.05, 1.05))
	_hiding_eye_local_y = eye_loc.y

	var gt := lnode.global_transform
	_locker_fwd = gt.basis.z.normalized()
	_locker_enter_from_yaw = atan2(_locker_fwd.x, _locker_fwd.z)
	_locker_eye = gt * eye_loc
	_locker_exit = gt * exit_loc

	if is_instance_valid(_hiding_door_pivot):
		var dp := _hiding_door_pivot
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(dp, "rotation:y", -PI * 0.64, 0.28)
		tw.tween_interval(0.40)
		tw.tween_property(dp, "rotation:y", -0.05, 0.32)

	if _hiding_kind == "under_desk":
		audio.play_desk_crawl(true)
	else:
		audio.play_locker_toggle(true)
	if _net != null and _net.is_online():
		_net.broadcast_locker_action(r_idx, l_idx, true, false)


func _exit_locker(face_locker: bool = false) -> void:
	if _is_action_locked() or not _is_hiding:
		return
	var prev_kind := _hiding_kind
	var prev_door_pivot := _hiding_door_pivot
	var prev_room_idx := _hiding_room_idx
	var prev_locker_idx := _hiding_locker_idx
	_locker_cam_from = cam.global_position
	_locker_transition_t = 0.0
	_locker_transition_entering = false
	_locker_exit_face_locker = face_locker
	_locker_transition_duration = 0.70 if face_locker else 1.00

	_is_hiding = false
	_hiding_room_idx = -1
	_hiding_locker_idx = -1
	_hiding_kind = "locker"
	_hiding_door_pivot = null
	_hiding_eye_local_y = 1.48
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	audio.stop_darkness()
	(_ui["darkness_rect"] as Control).visible = false
	player_body.position = _locker_exit
	player_body.velocity = Vector3.ZERO
	player_col.disabled = false

	var exit_yaw := atan2(_locker_fwd.x, _locker_fwd.z) if face_locker else atan2(-_locker_fwd.x, -_locker_fwd.z)
	_locker_exit_from_yaw = player_body.rotation.y
	_locker_exit_to_yaw = exit_yaw + (0.0 if face_locker else _hide_yaw_offset)
	_target_yaw = _locker_exit_to_yaw
	_target_pitch = 0.0 if face_locker else _hide_pitch_offset
	_yaw = _locker_exit_from_yaw
	_pitch = cam.rotation.x
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	_light_on = true if _active_tool == 1 else _was_light_before_hide
	if _vm_holder != null:
		_vm_holder.visible = true

	if is_instance_valid(prev_door_pivot):
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
	if _net != null and _net.is_online() and prev_room_idx >= 0 and prev_locker_idx >= 0:
		_net.broadcast_locker_action(prev_room_idx, prev_locker_idx, false, face_locker)
