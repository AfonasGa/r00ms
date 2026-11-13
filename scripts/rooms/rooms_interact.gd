extends "res://scripts/rooms/rooms_flow.gd"

func _toggle_flashlight() -> void:
	if _is_action_locked():
		return
	if _active_tool == 1:
		# Shakerlight cannot be turned off while equipped
		_light_on = true
		return
	if _std_battery <= 0.0 and not _light_on:
		audio.play_flashlight_click()
		_show_toast("Фонарик разряжен! Соберите 2 батарейки и нажмите [R].", 2.2)
		return
	_light_on = not _light_on
	_reminder_dismissed = true
	audio.play_flashlight_click()
	if _is_hiding and _light_on and _darkness_phase > 0:
		if _active_tool == 0 and not _std_low_power and _std_battery > 0.5:
			_darkness_phase = 0
			_darkness_whisper_t = 0.0
			_darkness_dmg_accum = 0.0
			_hide_time = 0.0
			_darkness_quick_return = true
			_std_low_power = true
			_std_battery = minf(_std_battery, 30.0)
			_std_low_power_regen = 0.0
			(_ui["darkness_rect"] as Control).visible = false
			audio.stop_darkness()
			audio.play_flashlight_low_power()
			_show_toast("Обычный фонарик отпугнул Тьму (слабый режим)!", 2.2)


func _try_reload_flashlight() -> void:
	if _is_action_locked():
		return
	if _std_battery >= 149.9 and not _std_low_power:
		_show_toast("Обычный фонарик уже полностью заряжен", 1.8)
		return
	if _batteries < 2:
		_show_toast("Нужно 2 батарейки для зарядки (%d/2)" % _batteries, 2.2)
		return
	_batteries -= 2
	_std_battery = 150.0
	_std_low_power = false
	_std_low_power_regen = 0.0
	_std_low_flicker_t = 0.0
	audio.play_pickup()
	_show_toast("Фонарик заряжен (-2 батарейки, осталось: %d)" % _batteries, 2.4)


func _try_shake_gummy(amount: float = 10.0) -> void:
	if _is_action_locked() or _active_tool != 1 or not _has_gummy:
		return
	_light_on = true
	_gummy_battery = minf(_gummy_battery + amount, 100.0)
	_shake_amount = maxf(_shake_amount, 0.012)
	_vm_shake_time = 0.36
	audio.play_gummy_shake()


func _try_interact() -> bool:
	if _is_action_locked():
		return false
	if _is_hiding:
		call("_exit_locker", false)
		return true

	var target := _smart_reticle_target if not _smart_reticle_target.is_empty() else _find_smart_reticle_target()
	if target.is_empty():
		return false
	return _execute_interact_target(target)


func _execute_interact_target(target: Dictionary) -> bool:
	if target.is_empty():
		return false
	var kind := String(target["type"])
	if kind == "door":
		var r_idx := int(target["room_index"])
		_open_room_door(r_idx)
		return true
	elif kind == "locker":
		var r_idx := int(target["room_index"])
		var l_idx := int(target["locker_index"])
		call("_enter_locker", r_idx, l_idx)
		return true
	elif kind == "pickup":
		var node := target["node"] as Node3D
		if not is_instance_valid(node):
			return false
		var pkind := String(target["pickup_kind"])
		if pkind == "battery":
			_batteries += 1
			_show_toast("Батарейка (+1) — Всего: %d. [R] для зарядки (нужно 2)" % _batteries, 2.8)
		elif pkind == "gummy":
			_has_gummy = true
			_active_tool = 1
			_light_on = true
			_gummy_battery = 100.0
			_show_toast("Подобран Трясосвет [2]! Зажмите [ПКМ] чтобы заряжать.", 3.2)
		elif pkind == "medkit":
			_hp = mini(_hp + 45, 100)
			audio.low_hp_mode = (_hp <= 25)
			_show_toast("+45 HP восстановлено")
		audio.play_pickup()
		node.queue_free()
		return true
	return false


func _try_tap_world_interact(screen_pos: Vector2) -> void:
	if _is_action_locked():
		return
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 4.5, 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var col: Object = hit.get("collider")
			if col != null and col.has_meta("interact_type"):
				var parsed := _collider_to_interact_dict(col)
				if not parsed.is_empty():
					_execute_interact_target(parsed)
					return

	if not _smart_reticle_target.is_empty() and screen_pos.distance_to(_reticle_screen_pos) <= 115.0:
		_execute_interact_target(_smart_reticle_target)


func _collider_to_interact_dict(col: Object) -> Dictionary:
	if col == null or not col.has_meta("interact_type"):
		return {}
	var itype := String(col.get_meta("interact_type"))
	if itype == "door":
		var r_idx := int(col.get_meta("room_index"))
		var room_inst: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
		if room_inst != null and not room_inst.door_opened:
			return {"type": "door", "room_index": r_idx, "label": "Открыть дверь A-%03d" % (r_idx + 1)}
	elif itype == "locker":
		var r_idx := int(col.get_meta("room_index"))
		var l_idx := int(col.get_meta("locker_index"))
		var r_inst: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
		var lbl := "Занято" if _is_locker_occupied(r_idx, l_idx) else "Спрятаться"
		if lbl != "Занято" and r_inst != null and l_idx >= 0 and l_idx < r_inst.lockers.size():
			lbl = String(r_inst.lockers[l_idx].get("label", lbl))
		return {
			"type": "locker",
			"room_index": r_idx,
			"locker_index": l_idx,
			"label": lbl,
		}
	elif itype == "pickup":
		return {
			"type": "pickup",
			"node": col,
			"pickup_kind": String(col.get_meta("pickup_kind")),
			"label": "Взять: %s" % String(col.get_meta("pickup_prompt")),
		}
	return {}


func _find_interact_target() -> Dictionary:
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		return _collider_to_interact_dict(interact_ray.get_collider())
	return {}


func _target_anchor_world_pos(tgt: Dictionary) -> Vector3:
	var kind := String(tgt.get("type", ""))
	if kind == "locker":
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(int(tgt["room_index"]))
		var li := int(tgt["locker_index"])
		if r != null and li >= 0 and li < r.lockers.size():
			var ld: Dictionary = r.lockers[li]
			var ln: Node3D = ld["node"]
			var lk := String(ld.get("kind", "locker"))
			var loc := Vector3(0.0, 0.56, 0.22) if lk == "under_desk" else Vector3(0.0, 1.16, 0.34)
			return ln.global_transform * loc
	elif kind == "door":
		var r: RoomBuilder.RoomInstance = _room_by_idx.get(int(tgt["room_index"]))
		if r != null and is_instance_valid(r.exit_anchor):
			return r.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
	elif kind == "pickup":
		var n := tgt.get("node") as Node3D
		if is_instance_valid(n):
			return n.global_position
	return cam.global_position - cam.global_transform.basis.z * 2.0


func _find_smart_reticle_target() -> Dictionary:
	var vp_sz := get_viewport().get_visible_rect().size
	var vp_center := vp_sz * 0.5
	var direct := _find_interact_target()
	if not direct.is_empty():
		var wp := _target_anchor_world_pos(direct)
		if not cam.is_position_behind(wp):
			direct["screen_pos"] = cam.unproject_position(wp)
			direct["world_pos"] = wp
			return direct

	# Smart cone scan around center: snaps reticle UI ring onto nearby locker/door/item even when aiming slightly beside it
	var best_tgt: Dictionary = {}
	var best_screen_d := minf(vp_sz.x, vp_sz.y) * 0.24
	var space_state := get_world_3d().direct_space_state
	var cam_pos := cam.global_position

	for r in _rooms:
		if abs(r.index - _current_room_idx) > 1:
			continue
		for li in range(r.lockers.size()):
			var ld: Dictionary = r.lockers[li]
			var ln: Node3D = ld["node"]
			if not is_instance_valid(ln):
				continue
			var lk := String(ld.get("kind", "locker"))
			var loc := Vector3(0.0, 0.56, 0.22) if lk == "under_desk" else Vector3(0.0, 1.16, 0.34)
			var wp := ln.global_transform * loc
			if cam_pos.distance_to(wp) > 3.85 or cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var sd := sp.distance_to(vp_center)
			if sd < best_screen_d and _has_los_to_interact(space_state, cam_pos, wp, r.index):
				best_screen_d = sd
				var occupied := _is_locker_occupied(r.index, li)
				best_tgt = {
					"type": "locker",
					"room_index": r.index,
					"locker_index": li,
					"label": "Занято" if occupied else String(ld.get("label", "Спрятаться")),
					"screen_pos": sp,
					"world_pos": wp,
				}
		if not r.door_opened and is_instance_valid(r.exit_anchor):
			var dwp := r.exit_anchor.global_position + Vector3(0.0, 1.15, 0.0)
			if cam_pos.distance_to(dwp) <= 3.85 and not cam.is_position_behind(dwp):
				var dsp := cam.unproject_position(dwp)
				var dsd := dsp.distance_to(vp_center)
				if dsd < best_screen_d and _has_los_to_interact(space_state, cam_pos, dwp, r.index):
					best_screen_d = dsd
					best_tgt = {
						"type": "door",
						"room_index": r.index,
						"label": "Открыть дверь A-%03d" % (r.index + 1),
						"screen_pos": dsp,
						"world_pos": dwp,
					}
	return best_tgt


func _has_los_to_interact(space_state: PhysicsDirectSpaceState3D, from_pos: Vector3, to_pos: Vector3, _room_idx: int) -> bool:
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
	return hp.distance_to(to_pos) < 0.65


func _is_locker_occupied(r_idx: int, l_idx: int) -> bool:
	for pk in _remote_players.keys():
		var rp: Dictionary = _remote_players[pk]
		if bool(rp.get("dead", false)) or not bool(rp.get("hiding", false)):
			continue
		if int(rp.get("hide_room", -1)) == r_idx and int(rp.get("hide_locker", -1)) == l_idx:
			return true
	return false


func _open_room_door(r_idx: int, slam: bool = false, from_remote: bool = false) -> void:
	var r: RoomBuilder.RoomInstance = _room_by_idx.get(r_idx)
	if r == null or r.door_opened:
		return
	var is_slam := slam
	if not from_remote and not is_slam:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		is_slam = _is_sprinting or hspd > 4.4
	r.door_opened = true
	if r.door_collider != null:
		r.door_collider.collision_layer = 0
		r.door_collider.collision_mask = 0
	_opening_doors.append({"pivot": r.door_pivot, "progress": 0.0, "slam": is_slam})
	if not from_remote and not _is_hiding:
		_door_hand_timer = 0.25
		_door_hand_slam = is_slam
		if is_slam:
			_shake_amount = maxf(_shake_amount, 0.016)
	audio.play_door_open()
	if not from_remote and _net != null and _net.is_online():
		_net.broadcast_door_opened(r_idx, is_slam)
	_advance_door_progress(r_idx, not from_remote)


func _advance_door_progress(r_idx: int, allow_spawn: bool) -> void:
	var opened_num := r_idx + 1
	if opened_num > _highest_opened:
		_highest_opened = opened_num
		_current_room_idx = opened_num
		if _net != null:
			_net.update_lobby_progress(_world_seed, _highest_opened)
		if opened_num >= 50 and not _power_out:
			call("_trigger_power_outage")
		var min_keep := 9 if _render_quality == RenderQuality.MOBILE_OPT else 14
		var ahead_keep := 4 if _render_quality == RenderQuality.MOBILE_OPT else 6
		while _rooms.size() < min_keep or _rooms[-1].index < _highest_opened + ahead_keep:
			_spawn_next_room()
		_update_room_visibility()

		if opened_num == 100:
			_checkpoint_room = 100
			_show_toast("Контрольная точка A-100 достигнута! Половина пути к выходу...", 3.5)
		elif opened_num >= 200 and not _victory_reached:
			_victory_reached = true
			_set_state(State.VICTORY)
			return

		if allow_spawn:
			call("_maybe_spawn_door_entities", opened_num)

func _update_ui(delta: float) -> void:
	if _state != State.PLAYING:
		return
	var dmg: ColorRect = _ui["dmg_flash"]
	if dmg.color.a > 0.005:
		dmg.color.a = maxf(dmg.color.a - delta * 1.4, 0.0)
	dmg.visible = (dmg.color.a > 0.004)

	var toast_ctrl: Control = _ui["toast"]
	if _toast_timer > 0.0:
		_toast_timer = maxf(_toast_timer - delta, 0.0)
	var want_toast := _toast_timer > 0.45
	var toast_rate := 8.5 if want_toast else 5.2
	_toast_alpha = lerpf(_toast_alpha, 1.0 if want_toast else 0.0, clampf(1.0 - exp(-toast_rate * delta), 0.0, 1.0))
	toast_ctrl.modulate.a = _toast_alpha
	toast_ctrl.visible = (_toast_alpha > 0.01 or _toast_timer > 0.0)

	var vitals_rect: ColorRect = _ui["vitals_rect"]
	var vitals_mat: ShaderMaterial = _ui["vitals_mat"]
	var hp_target := 1.0 - clampf(float(_hp) / 100.0, 0.0, 1.0)
	var stam_target := 1.0 - clampf(_stamina, 0.0, 1.0)
	var ex_target := 1.0 if _exhausted else 0.0
	var dk_target := clampf(_darkness_whisper_t * 0.90 if _darkness_phase == 1 else (1.0 if _darkness_phase == 2 else 0.0), 0.0, 1.0)
	var smooth := clampf(delta * 6.0, 0.0, 1.0)
	var max_vital := 0.0
	for pair in [["hp_loss", hp_target], ["stam_loss", stam_target], ["exhausted_amt", ex_target], ["darkness_amt", dk_target]]:
		var k: String = String(pair[0])
		var tgt_v: float = float(pair[1])
		var raw_v: Variant = vitals_mat.get_shader_parameter(k)
		var prev_v: float = float(raw_v) if raw_v != null else 0.0
		var next_v := lerpf(prev_v, tgt_v, smooth)
		vitals_mat.set_shader_parameter(k, next_v)
		max_vital = maxf(max_vital, next_v)
	vitals_rect.visible = (max_vital > 0.004)

	var interact_tgt := {}
	var prompt: Label = _ui["prompt_lbl"]
	var want_prompt := false
	var vp_sz := get_viewport().get_visible_rect().size
	var vp_center := vp_sz * 0.5

	if _is_hiding:
		_smart_reticle_target = {}
		if _reticle_ring != null:
			_reticle_ring.visible = false
		if not _is_action_locked():
			if _hiding_kind == "under_desk":
				prompt.text = "[W / S] Вылезти из-под тумбочки"
			elif _hiding_kind == "fridge":
				prompt.text = "[W] Выйти вперёд  |  [S] Выйти лицом к холодильнику"
			else:
				prompt.text = "[W] Выйти вперёд  |  [S] Выйти лицом к шкафу"
			want_prompt = true
	else:
		interact_tgt = {} if _is_action_locked() else _find_smart_reticle_target()
		_smart_reticle_target = interact_tgt
		var yaw_lag := wrapf(_target_yaw - _yaw, -PI, PI)
		var pitch_lag := _target_pitch - _pitch
		var desired_lag := Vector2(clampf(yaw_lag * 360.0, -48.0, 48.0), clampf(pitch_lag * 300.0, -36.0, 36.0))
		var lag_in_a := clampf(1.0 - exp(-12.5 * delta), 0.0, 1.0)
		_reticle_lag_offset = _reticle_lag_offset.lerp(desired_lag, lag_in_a)

		var tgt_r := 6.5
		var tgt_stroke := 1.9
		var tgt_pos := vp_center + _reticle_lag_offset
		if not interact_tgt.is_empty():
			tgt_r = 19.5
			tgt_stroke = 2.8
			if interact_tgt.has("world_pos"):
				var wp: Vector3 = interact_tgt["world_pos"]
				if not cam.is_position_behind(wp):
					tgt_pos = cam.unproject_position(wp)
			prompt.text = String(interact_tgt["label"])
			want_prompt = not _mobile_controls_enabled

		if _reticle_ring != null:
			_reticle_ring.visible = true
			var ret_a := clampf(1.0 - exp(-10.5 * delta), 0.0, 1.0)
			if _reticle_screen_pos == Vector2.ZERO:
				_reticle_screen_pos = tgt_pos
			_reticle_screen_pos = _reticle_screen_pos.lerp(tgt_pos, ret_a)
			_reticle_radius = lerpf(_reticle_radius, tgt_r, clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			_reticle_ring.ring_radius = _reticle_radius
			_reticle_ring.stroke_width = lerpf(_reticle_ring.stroke_width, tgt_stroke, clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0))
			_reticle_ring.position = _reticle_screen_pos - _reticle_ring.size * 0.5
			_reticle_ring.queue_redraw()

	var pr_rate := 12.0 if want_prompt else 8.5
	_prompt_alpha = lerpf(_prompt_alpha, 1.0 if want_prompt else 0.0, clampf(1.0 - exp(-pr_rate * delta), 0.0, 1.0))
	prompt.modulate.a = _prompt_alpha
	var prompt_card: Control = _ui["prompt_card"]
	prompt_card.modulate.a = _prompt_alpha
	prompt_card.visible = (_prompt_alpha > 0.01)

	_update_hud(delta)

	_update_mobile_ui(interact_tgt)
