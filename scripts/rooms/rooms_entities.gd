extends "res://scripts/rooms/rooms_spawn.gd"

func _physics_process(delta: float) -> void:
	if _state == State.SPECTATING:
		_process_entities(delta)
		return
	if _state == State.DEAD:
		if _is_entity_authority() and _net != null and _net.is_online() and _has_alive_remote_players():
			_process_entities(delta)
		return
	if _state != State.PLAYING:
		return

	_run_time += delta
	_process_doors(delta)
	_process_flashlight(delta)

	if _is_entity_authority():
		if _a60_prime_pending_timer > 0.0 and not _a60_active and not _a120_active:
			_a60_prime_pending_timer -= delta
			if _a60_prime_pending_timer <= 0.0:
				_spawn_a60(true)
		elif _highest_opened >= 5 and not _a60_active and not _a120_active and not _a60_prime_flicker_active:
			_a60_random_timer -= delta
			if _a60_random_timer <= 0.0:
				var max_cd := maxf(24.0, 52.0 - float(_highest_opened) * 0.12)
				var min_cd := maxf(14.0, max_cd * 0.52)
				_a60_random_timer = _rng.randf_range(min_cd, max_cd)
				_spawn_a60(false)

	_process_entities(delta)
	_process_player_movement(delta)
	_process_a90(delta)
	_update_ui(delta)


func _process_doors(delta: float) -> void:
	for i in range(_opening_doors.size() - 1, -1, -1):
		var d: Dictionary = _opening_doors[i]
		var pivot_raw: Variant = d["pivot"]
		if not is_instance_valid(pivot_raw):
			_opening_doors.remove_at(i)
			continue
		var p: float = minf(float(d["progress"]) + delta / 0.25, 1.0)
		d["progress"] = p
		var pivot := pivot_raw as Node3D
		var target_ang: float = -PI * 0.88 if bool(d.get("slam", false)) else -PI * 0.52
		pivot.rotation.y = lerpf(0.0, target_ang, 1.0 - pow(1.0 - p, 2.0))
		if p >= 1.0:
			_opening_doors.remove_at(i)


func _process_flashlight(delta: float) -> void:
	if _std_low_flicker_t > 0.0:
		_std_low_flicker_t = maxf(_std_low_flicker_t - delta, 0.0)
	if _a60_prime_flicker_gap_t > 0.0:
		_a60_prime_flicker_gap_t = maxf(_a60_prime_flicker_gap_t - delta, 0.0)
	if _a60_prime_flicker_snd_cd > 0.0:
		_a60_prime_flicker_snd_cd = maxf(_a60_prime_flicker_snd_cd - delta, 0.0)

	# Shakerlight [2] cannot be turned off while equipped
	if _active_tool == 1:
		_light_on = true

	var has_charge := (_std_battery > 0.0) if _active_tool == 0 else (_gummy_battery > 0.05)
	var is_lit := _light_on and has_charge
	if is_lit:
		var power_mult := 1.0
		if _active_tool == 0:
			# Before A-050 battery won't drain! From A-050+: 120s normal (>30s) + 30s Low Battery Mode (<=30s)
			if _highest_opened >= 50:
				var prev_bat := _std_battery
				_std_battery = maxf(_std_battery - delta, 0.0)
				if prev_bat > 30.0 and _std_battery <= 30.0 and not _std_low_power:
					_std_low_power = true
					_std_low_flicker_t = 0.85
					audio.play_flashlight_low_power()
					_show_toast("Низкий заряд фонарика! Нажмите [R] с 2 батарейками.", 2.6)
				if _std_battery <= 0.0:
					_light_on = false
					audio.play_flashlight_click()
					_show_toast("Фонарик сел! Соберите 2 батарейки и нажмите [R].", 2.8)
			if _std_low_power:
				flashlight.light_color = Color(1.0, 0.78, 0.56)
				flashlight.spot_range = 14.0
				flashlight.spot_angle = 30.0
				power_mult = 0.44
			else:
				flashlight.light_color = Color(1.0, 0.96, 0.88)
				flashlight.spot_range = 24.0
				flashlight.spot_angle = 36.0
		else:
			_gummy_battery = maxf(_gummy_battery - delta * 10.0, 0.0)
			flashlight.light_color = Color(0.35, 1.0, 0.52)
			flashlight.spot_range = 20.0
			flashlight.spot_angle = 40.0
			if _gummy_battery < 25.0:
				power_mult = clampf(0.32 + (_gummy_battery / 25.0) * 0.68, 0.32, 1.0)

		var cur_bat := _std_battery if _active_tool == 0 else _gummy_battery
		var flicker := 1.0
		if _std_low_flicker_t > 0.0 and _active_tool == 0:
			flicker = _rng.randf_range(0.05, 0.75)
		elif _a60_prime_flicker_active and _a60_prime_flicker_gap_t <= 0.0:
			# A-60' constant flashlight flicker warning (visual + auditory cue!)
			flicker = _rng.randf_range(0.04, 0.92) if _rng.randf() < 0.72 else 1.0
			if _a60_prime_flicker_snd_cd <= 0.0:
				_a60_prime_flicker_snd_cd = _rng.randf_range(0.11, 0.19)
				audio.play_flashlight_flicker()
		elif cur_bat < 8.0 and _rng.randf() < 0.22:
			flicker = _rng.randf_range(0.25, 0.85)
		flashlight.light_energy = 2.6 * power_mult * flicker
		flashlight.visible = not (_active_tool == 0 and _std_battery <= 0.0)
	else:
		flashlight.visible = false

	if _vm_std_bulb != null:
		_vm_std_bulb.material_override = _vm_bulb_on_mat if (is_lit and _active_tool == 0) else _vm_bulb_off_mat
	if _vm_gummy_bulb != null:
		_vm_gummy_bulb.material_override = _vm_gummy_on_mat if (is_lit and _active_tool == 1) else _vm_bulb_off_mat


func _process_darkness_in_hiding(delta: float) -> void:
	var dk_rect: TextureRect = _ui["darkness_rect"]
	if _highest_opened < 21:
		dk_rect.visible = false
		if not _a60_active and not _a120_active:
			_hide_time += delta
			if _hide_time > 24.0:
				_show_toast("Пора выходить из укрытия!", 1.2)
		return

	_hide_time += delta
	# Very gradual Darkness progression (A-021 = ~24s, slowing gently down to ~4.5s / ~3s in late power-out rooms)
	var prog := clampf(float(_highest_opened - 21) / 600.0, 0.0, 1.0)
	var base_delay := lerpf(24.0, 4.5, prog)
	var disturb_delay := maxf(3.0, base_delay * 0.72) if _power_out else base_delay
	if _darkness_quick_return:
		disturb_delay = 4.5 if (_light_on and _active_tool == 0) else 2.0

	if _darkness_phase == 0:
		dk_rect.visible = false
		audio.stop_darkness()
		if _hide_time >= disturb_delay:
			_darkness_phase = 1
			_darkness_whisper_t = 0.0
			_darkness_dmg_accum = 0.0
			audio.start_darkness()
			dk_rect.visible = true
			dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.05)
	elif _darkness_phase == 1:
		var ramp_dur := lerpf(5.5, 2.2, prog) * (0.82 if _power_out else 1.0)
		_darkness_whisper_t = minf(_darkness_whisper_t + delta / ramp_dur, 1.0)
		audio.update_darkness(_darkness_whisper_t)
		dk_rect.visible = true
		var s := lerpf(0.82, 1.08, _darkness_whisper_t)
		dk_rect.scale = Vector2(s, s)
		dk_rect.pivot_offset = dk_rect.size * 0.5
		dk_rect.modulate = Color(1.0, 1.0, 1.0, pow(_darkness_whisper_t, 1.15) * 0.94)
		if _darkness_whisper_t >= 1.0:
			_darkness_phase = 2
			_darkness_dmg_accum = 0.45
	elif _darkness_phase == 2:
		audio.update_darkness(1.0)
		dk_rect.visible = true
		var pulse_s := 1.06 + 0.06 * sin(float(Time.get_ticks_msec()) * 0.014)
		dk_rect.scale = Vector2(pulse_s, pulse_s)
		dk_rect.pivot_offset = dk_rect.size * 0.5
		dk_rect.modulate = Color(1.0, 1.0, 1.0, 0.98)
		_shake_amount = maxf(_shake_amount, 0.030)
		_darkness_dmg_accum += delta
		if _darkness_dmg_accum >= 0.65:
			_darkness_dmg_accum -= 0.65
			_hp -= 12
			audio.low_hp_mode = (_hp <= 25 and _hp > 0)
			(_ui["dmg_flash"] as ColorRect).color = Color(0.88, 0.04, 0.04, 0.56)
			if _hp <= 0:
				_trigger_death("The Darkness")
				return


func _process_player_movement(delta: float) -> void:
	if _is_action_locked():
		player_body.velocity.x = 0.0
		player_body.velocity.z = 0.0
		player_body.move_and_slide()
		return

	if _is_hiding:
		_process_darkness_in_hiding(delta)
		return

	var inp := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		inp.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		inp.y += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		inp.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		inp.x -= 1.0
	if _joy_vec.length_squared() > 0.01:
		inp += _joy_vec
	if inp.length_squared() > 1.0:
		inp = inp.normalized()

	var moving := inp.length_squared() > 0.01
	var wants_sprint := (Input.is_key_pressed(KEY_SHIFT) or _joy_sprint or _mobile_sprint_held) and moving and (not _exhausted) and _stamina > 0.01
	_is_sprinting = wants_sprint
	if wants_sprint:
		_stamina = maxf(_stamina - delta * 0.34, 0.0)
		_stamina_regen_delay = 0.65
		if _stamina <= 0.01:
			_exhausted = true
			_pant_timer = 0.08
	else:
		if _stamina_regen_delay > 0.0:
			_stamina_regen_delay = maxf(_stamina_regen_delay - delta, 0.0)
		else:
			var rec_rate := 0.12 if _exhausted else 0.22
			_stamina = minf(_stamina + delta * rec_rate, 1.0)
		if _exhausted and _stamina >= 0.35:
			_exhausted = false

	if _exhausted:
		_pant_timer -= delta
		if _pant_timer <= 0.0:
			_pant_timer = 0.44
			audio.play_pant(_pant_inhale)
			_pant_inhale = not _pant_inhale

	_cam_roll = lerpf(_cam_roll, -inp.x * 0.020, 1.0 - exp(-10.0 * delta))

	var speed := 3.7
	if wants_sprint:
		speed = 6.2
	elif _exhausted:
		speed = 2.8
	if _is_shaking_gummy:
		speed *= 0.5
	var dir := (player_body.transform.basis * Vector3(inp.x, 0.0, inp.y)).normalized()

	player_body.velocity.x = lerpf(player_body.velocity.x, dir.x * speed, minf(delta * 11.0, 1.0))
	player_body.velocity.z = lerpf(player_body.velocity.z, dir.z * speed, minf(delta * 11.0, 1.0))
	if not player_body.is_on_floor():
		player_body.velocity.y -= 18.0 * delta
	else:
		player_body.velocity.y = 0.0

	player_body.move_and_slide()

	# Footsteps & camera bobbing (surface-aware: metal grate floors play louder iron footsteps!)
	var horiz_spd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
	if horiz_spd > 0.7:
		_bob_phase += delta * (10.5 if wants_sprint else 6.8) * (0.65 if _is_shaking_gummy else 1.0)
		_step_timer -= delta * (1.42 if wants_sprint else 0.90) * (0.55 if _is_shaking_gummy else 1.0)
		if _step_timer <= 0.0:
			_step_timer = 0.48
			audio.play_step(wants_sprint, _detect_floor_surface())
	else:
		_bob_phase = lerpf(_bob_phase, 0.0, delta * 5.0)

	_shake_amount = maxf(_shake_amount - delta * 0.14, 0.0)
	var shake_off := Vector3(
		_rng.randf_range(-_shake_amount, _shake_amount),
		_rng.randf_range(-_shake_amount, _shake_amount),
		0.0
	)
	var bob_y := (sin(_bob_phase) * 0.032) if _head_bob_enabled else 0.0
	var breath_bob := sin(float(Time.get_ticks_msec()) * 0.0055) * (0.022 if _exhausted else 0.0)
	if _locker_transition_t >= 1.0:
		cam.position = Vector3(0.0, 1.48 + bob_y + breath_bob, 0.0) + shake_off

	# Track current room closest to player (adapted for 12m room grid)
	var prev_room := _current_room_idx
	for r in _rooms:
		if r.center_pos.distance_to(player_body.position) < RoomBuilder.CELL_SIZE * 0.52:
			_current_room_idx = r.index
			break
	if _current_room_idx != prev_room:
		_update_room_visibility()


func _detect_floor_surface() -> String:
	for i in range(player_body.get_slide_collision_count()):
		var kc := player_body.get_slide_collision(i)
		if kc != null and kc.get_normal().y > 0.5:
			var col := kc.get_collider()
			if col != null and col.has_meta("floor_surface"):
				return String(col.get_meta("floor_surface"))
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var p := player_body.global_position
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.35, 0), p - Vector3(0, 0.55, 0), 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			var c: Object = hit.get("collider")
			if c != null and c.has_meta("floor_surface"):
				return String(c.get_meta("floor_surface"))
	return "carpet"


func _process_entities(delta: float) -> void:
	# --- A-60 / MultiMonster & Prime Variant (A-60') ---
	var static_rect: ColorRect = _ui["static_rect"]
	var static_mat: ShaderMaterial = _ui["static_mat"]
	var a60_scare_rect: TextureRect = _ui["a60_scare_rect"]
	var is_auth := _is_entity_authority()
	var can_harm_local := (_state == State.PLAYING)
	if _a60_scare_snd_cd > 0.0:
		_a60_scare_snd_cd = maxf(_a60_scare_snd_cd - delta, 0.0)
	if _a60_prime_hit_cd > 0.0:
		_a60_prime_hit_cd = maxf(_a60_prime_hit_cd - delta, 0.0)
	if _a60_entry_hit_cd > 0.0:
		_a60_entry_hit_cd = maxf(_a60_entry_hit_cd - delta, 0.0)

	var send_ent_sync := false
	if is_auth and (_a60_active or _a120_active):
		_ent_sync_accum += delta
		if _ent_sync_accum >= 0.08:
			_ent_sync_accum = 0.0
			send_ent_sync = true

	if _a60_active:
		_a60_node.visible = (_state != State.DEAD)
		_a60_anim_timer += delta
		var flip_interval := 0.035 if _a60_is_prime else 0.045
		if _a60_anim_timer > flip_interval:
			_a60_anim_timer = 0.0
			_a60_frame_idx = (_a60_frame_idx + _rng.randi_range(1, 5)) % maxi(_a60_frames.size(), 1)
			var f60 := _a60_frames[_a60_frame_idx]
			_a60_last_tex = f60
			_a60_sprite.texture = f60
			_a60_sprite.pixel_size = 2.65 / float(maxi(f60.get_width(), 1))

		var d_player := _a60_node.global_position.distance_to(cam.global_position)
		if _state != State.DEAD:
			audio.a60_intensity = 0.0 if _a60_is_prime else clampf(16.0 / maxf(d_player, 2.0), 0.12, 1.0)
			audio.update_a60_mix(delta, d_player, _a60_phase, _a60_is_prime)

		var prime_col := Vector3(0.25, 0.85, 1.0) if _a60_is_prime else Vector3(1.0, 0.22, 0.18)
		static_mat.set_shader_parameter("tint_col", prime_col)

		if _a60_hint_timer > 0.0:
			_a60_hint_timer = maxf(_a60_hint_timer - delta, 0.0)

		if _a60_phase == 2:
			if can_harm_local:
				var near_prox := clampf(1.0 - (d_player - 2.0) / 22.0, 0.0, 1.0)
				if not _a60_is_prime:
					_shake_amount = maxf(_shake_amount, near_prox * 0.11)
				else:
					_shake_amount = maxf(_shake_amount, near_prox * 0.045)

				var hint_static := 0.0
				if not _a60_is_prime and _a60_hint_timer > 0.0 and _highest_opened < 100:
					var fade := clampf(_a60_hint_timer / 0.85, 0.0, 1.0)
					hint_static = fade * (0.55 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.015))

				var total_static := maxf(hint_static, near_prox * (0.35 if _a60_is_prime else 0.65))
				if total_static > 0.03:
					static_rect.visible = true
					static_mat.set_shader_parameter("static_amt", total_static)
					static_mat.set_shader_parameter("vig_amt", 0.0)
				else:
					static_rect.visible = false
			else:
				static_rect.visible = false
				a60_scare_rect.visible = false

			if is_auth:
				# Keep tracking the FIRST still-closed door in case any player opened target mid-rush
				var live_closed_r: RoomBuilder.RoomInstance = _room_by_idx.get(_a60_target_door_idx)
				if live_closed_r != null and (live_closed_r.door_opened or live_closed_r.door_broken):
					var next_closed := _find_first_closed_door_room()
					if next_closed != null and next_closed.index > _a60_target_door_idx:
						var old_idx := _a60_target_door_idx
						_a60_target_door_idx = next_closed.index
						for r in _rooms:
							if r.index > old_idx and r.index <= _a60_target_door_idx:
								_a60_path.append(r.center_pos + Vector3(0.0, 1.55, 0.0))
								if r.index < _a60_target_door_idx:
									_a60_path.append(r.exit_pos + Vector3(0.0, 1.55, 0.0))
						_a60_path.append(next_closed.exit_pos + Vector3(0.0, 1.55, 0.0))

				var rush_speed := 72.0 if _a60_is_prime else 60.0
				if _a60_path_idx < _a60_path.size():
					var tgt := _a60_path[_a60_path_idx]
					var to_t := tgt - _a60_node.position
					if to_t.length() <= rush_speed * delta:
						_a60_node.position = tgt
						_a60_path_idx += 1
					else:
						_a60_node.position += to_t.normalized() * rush_speed * delta
				else:
					var smash_r: RoomBuilder.RoomInstance = _room_by_idx.get(_a60_target_door_idx)
					if smash_r != null and not smash_r.door_opened and not smash_r.door_broken:
						_break_door_by_a60(_a60_target_door_idx, _a60_is_prime)
						if _net != null and _net.is_online():
							_net.broadcast_entity_event({"k": "a60_brk", "door": _a60_target_door_idx, "prime": _a60_is_prime}, true)
					_a60_phase = 3
					_a60_sink_timer = 0.42
					a60_scare_rect.visible = false
					if _net != null and _net.is_online():
						_net.broadcast_entity_event({"k": "a60_end"}, true)

				if send_ent_sync and _net != null and _net.is_online():
					var p60 := _a60_node.position
					_net.broadcast_entity_event({
						"k": "a60_pos",
						"p": [p60.x, p60.y, p60.z],
						"ph": _a60_phase,
						"door": _a60_target_door_idx,
						"prime": _a60_is_prime,
					}, false)
			else:
				var rush_speed_c := 72.0 if _a60_is_prime else 60.0
				_a60_node.position = _a60_node.position.move_toward(_net_a60_tgt, rush_speed_c * delta * 1.25)

			# Table Burn from A-60' (90% chance to deal 20 damage when hiding under a table!)
			if can_harm_local and _a60_phase == 2 and _a60_is_prime and _is_hiding and _hiding_kind == "under_desk" and d_player <= 11.5 and not _a60_prime_table_burned:
				_a60_prime_table_burned = true
				if _rng.randf() < 0.90:
					_hp -= 20
					audio.low_hp_mode = (_hp <= 25 and _hp > 0)
					(_ui["dmg_flash"] as ColorRect).color = Color(0.95, 0.32, 0.14, 0.62)
					_shake_amount = maxf(_shake_amount, 0.06)
					_show_toast("Ожог от A-60' под столом (-20 HP!)", 2.2)
					if _hp <= 0:
						_trigger_death("A-60'", "", {"distance": d_player, "table_burn": true})
						return

			# Raycast line-of-sight attack if player is exposed and not hiding
			var in_entry := _is_locker_entry_anim()
			if can_harm_local and _a60_phase == 2 and d_player <= 11.5 and (not _is_hiding or in_entry):
				var space := get_world_3d().direct_space_state
				var q := PhysicsRayQueryParameters3D.create(_a60_node.global_position, cam.global_position)
				q.exclude = [player_body.get_rid()]
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					if in_entry:
						# Caught mid-climb: scares you and rips 50 HP, but you still get inside.
						if _a60_entry_hit_cd <= 0.0:
							_a60_entry_hit_cd = 1.0
							a60_scare_rect.visible = true
							a60_scare_rect.texture = _a60_sprite.texture
							a60_scare_rect.modulate = Color(0.72, 0.96, 1.0, 0.96) if _a60_is_prime else Color(1.0, 0.92, 0.92, 0.96)
							var vp_e := get_viewport().get_visible_rect().size
							a60_scare_rect.position = vp_e * 0.5 - Vector2(270, 270)
							audio.play_a60_jumpscare(_a60_is_prime)
							_hp -= 50
							audio.low_hp_mode = (_hp <= 25 and _hp > 0)
							(_ui["dmg_flash"] as ColorRect).color = Color(0.35, 0.90, 1.0, 0.70) if _a60_is_prime else Color(0.92, 0.08, 0.08, 0.72)
							_shake_amount = maxf(_shake_amount, 0.14)
							_show_toast("%s зацепил вас на входе в укрытие (-50 HP!)" % ("A-60'" if _a60_is_prime else "A-60"), 2.6)
							if _hp <= 0:
								_trigger_death("A-60'" if _a60_is_prime else "A-60", "", {"distance": d_player, "locker_entry": true})
								return
					elif _a60_is_prime:
						if _a60_prime_hit_cd <= 0.0:
							_a60_prime_hit_cd = 1.2
							_hp -= 35
							audio.low_hp_mode = (_hp <= 25 and _hp > 0)
							(_ui["dmg_flash"] as ColorRect).color = Color(0.35, 0.90, 1.0, 0.65)
							_shake_amount = maxf(_shake_amount, 0.08)
							_show_toast("A-60' (Prime) нанёс 35 урона! Прячьтесь в шкаф!", 2.4)
							if _hp <= 0:
								_trigger_death("A-60'", "", {"distance": d_player})
								return
					else:
						a60_scare_rect.visible = true
						a60_scare_rect.texture = _a60_sprite.texture
						a60_scare_rect.modulate = Color(1.0, 0.92, 0.92, 0.96)
						var vp := get_viewport().get_visible_rect().size
						a60_scare_rect.position = vp * 0.5 - Vector2(270, 270)
						audio.play_a60_jumpscare(false)
						_hp = 0
						audio.low_hp_mode = false
						(_ui["dmg_flash"] as ColorRect).color = Color(0.92, 0.08, 0.08, 0.78)
						_trigger_death("A-60", "", {"distance": d_player})
						return
				else:
					a60_scare_rect.visible = false
			else:
				a60_scare_rect.visible = false
		elif _a60_phase == 3:
			a60_scare_rect.visible = false
			static_rect.visible = false
			_a60_sink_timer -= delta
			var sink_p := 1.0 - clampf(_a60_sink_timer / 0.42, 0.0, 1.0)
			_a60_node.position.y = lerpf(1.55, -1.85, ease(sink_p, 2.0))
			_a60_sprite.modulate.a = 1.0 - sink_p
			if _a60_sink_timer <= 0.0:
				var was_prime := _a60_is_prime
				_a60_active = false
				_a60_phase = 0
				_a60_node.visible = false
				_a60_sprite.modulate.a = 1.0
				audio.stop_a60()

				# MultiMonster Prime (A-60') follows regular A-60 starting after A-049 (A-50+)!
				if is_auth:
					if not was_prime and _highest_opened >= 50:
						var p_prog := clampf(float(_highest_opened - 50) / 850.0, 0.0, 1.0)
						var spawn_ch := lerpf(0.45, 0.90, p_prog)
						if _rng.randf() < spawn_ch:
							var max_chains := mini(1 + int(floor(p_prog * 3.0)), 4)
							var chains := 1
							for _c in range(max_chains - 1):
								if _rng.randf() < lerpf(0.25, 0.72, p_prog):
									chains += 1
							var delay := lerpf(5.0, 3.0, p_prog)
							_a60_prime_pending_timer = delay
							_a60_prime_chains_left = chains - 1
							_a60_prime_flicker_active = true
							_a60_prime_flicker_gap_t = 0.0
							if _net != null and _net.is_online():
								_net.broadcast_entity_event({"k": "a60p_warn", "gap": 0.0}, true)
					elif was_prime:
						if _a60_prime_chains_left > 0:
							_a60_prime_chains_left -= 1
							var p_prog2 := clampf(float(_highest_opened - 50) / 850.0, 0.0, 1.0)
							_a60_prime_flicker_active = true
							_a60_prime_flicker_gap_t = 0.5
							_a60_prime_pending_timer = lerpf(3.6, 2.6, p_prog2)
							if _net != null and _net.is_online():
								_net.broadcast_entity_event({"k": "a60p_warn", "gap": 0.5}, true)
						else:
							_a60_prime_flicker_active = false
							if _net != null and _net.is_online():
								_net.broadcast_entity_event({"k": "a60p_end"}, true)
	else:
		audio.a60_intensity = lerpf(audio.a60_intensity, 0.0, minf(delta * 4.0, 1.0))
		static_rect.visible = false
		a60_scare_rect.visible = false
		_a60_node.visible = false

	# --- A-120 (Happy Scribble) ---
	if _a120_hit_cd > 0.0:
		_a120_hit_cd = maxf(_a120_hit_cd - delta, 0.0)

	if _a120_active:
		_a120_node.visible = (_state != State.DEAD)
		var d120 := _a120_node.global_position.distance_to(cam.global_position)
		var drum_hit := audio.update_a120_mix(delta, d120, _a120_phase) if _state != State.DEAD else false
		_a120_anim_timer += delta
		if _a120_anim_timer >= 0.50:
			_a120_anim_timer -= 0.50
			_a120_frame_idx = (_a120_frame_idx + 1) % maxi(_a120_frames.size(), 1)
			var f120 := _a120_frames[_a120_frame_idx] if not _a120_frames.is_empty() else null
			if f120 != null:
				_a120_sprite.texture = f120
				_a120_sprite.pixel_size = 2.55 / float(maxi(f120.get_width(), 1))
		if drum_hit:
			_a120_drum_bounce = 1.0

		if _a120_drum_bounce > 0.0:
			_a120_drum_bounce = maxf(_a120_drum_bounce - delta * 4.4, 0.0)
			var b := _a120_drum_bounce
			_a120_sprite.position.y = sin(b * PI) * 0.34
			_a120_sprite.scale = Vector3(1.0 + sin(b * PI) * 0.16, 1.0 - sin(b * PI) * 0.10 + (1.0 - cos(b * PI)) * 0.06, 1.0)
		else:
			_a120_sprite.position.y = 0.0
			_a120_sprite.scale = Vector3.ONE

		if not is_auth:
			_a120_node.position = _a120_node.position.lerp(_net_a120_tgt, clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0))
		elif _a120_phase == 1:
			_a120_warn_timer -= delta
			_shake_amount = maxf(_shake_amount, 0.012)
			if _a120_warn_timer <= 0.0:
				_a120_phase = 2
				_a120_substage = 0
				_a120_path = _build_a120_corridor_path(_get_room_idx_near(_a120_node.position), _current_room_idx)
				_a120_path_idx = 0
		elif _a120_phase == 2:
			if _a120_pause_timer > 0.0:
				_a120_pause_timer -= delta
			else:
				var spd120 := 15.0
				if _a120_substage == 0:
					var live_tgt := _get_a120_live_target()
					var tgt_room := _get_room_idx_near(live_tgt)
					var move_tgt := live_tgt
					if _a120_path_idx < _a120_path.size() and _get_room_idx_near(_a120_node.position) != tgt_room:
						move_tgt = _a120_path[_a120_path_idx]
					var to_m := move_tgt - _a120_node.position
					if to_m.length() <= spd120 * delta:
						_a120_node.position = move_tgt
						if move_tgt.distance_to(live_tgt) < 1.25:
							var min_room := _rooms[0].index if not _rooms.is_empty() else 0
							var prev_idx := maxi(min_room, tgt_room - _rng.randi_range(2, 4))
							if prev_idx == tgt_room and min_room < tgt_room:
								prev_idx = tgt_room - 1
							_a120_substage = 1
							_a120_path = _build_a120_corridor_path(tgt_room, prev_idx)
							if prev_idx == tgt_room and _room_by_idx.has(tgt_room):
								var cr: RoomBuilder.RoomInstance = _room_by_idx[tgt_room]
								_a120_path = [cr.center_pos - cr.in_dir * 4.5 + Vector3(0.0, 1.55, 0.0)]
							_a120_path_idx = 0
						else:
							_a120_path_idx += 1
					else:
						_a120_node.position += to_m.normalized() * spd120 * delta
				elif _a120_substage == 1:
					if _a120_path_idx < _a120_path.size():
						var tgt := _a120_path[_a120_path_idx]
						var to_t := tgt - _a120_node.position
						if to_t.length() <= spd120 * delta:
							_a120_node.position = tgt
							_a120_path_idx += 1
						else:
							_a120_node.position += to_t.normalized() * spd120 * delta
					else:
						if _a120_rebounds > 0:
							_a120_rebounds -= 1
							_a120_pause_timer = 0.38
							_a120_substage = 0
							var tgt_room2 := _get_room_idx_near(_get_a120_live_target())
							_a120_path = _build_a120_corridor_path(_get_room_idx_near(_a120_node.position), tgt_room2)
							_a120_path_idx = 0
						else:
							# Smooth retreat backwards into the far distance until completely inaudible
							_a120_substage = 2
							var min_idx := _rooms[0].index if not _rooms.is_empty() else 0
							var cur_near := _get_room_idx_near(_a120_node.position)
							_a120_path = _build_a120_corridor_path(cur_near, min_idx)
							if not _rooms.is_empty():
								var first_r := _rooms[0]
								_a120_path.append(first_r.center_pos - first_r.in_dir * 185.0 + Vector3(0.0, 1.55, 0.0))
							_a120_path_idx = 0
				elif _a120_substage == 2:
					if _a120_path_idx < _a120_path.size():
						var tgt := _a120_path[_a120_path_idx]
						var to_t := tgt - _a120_node.position
						if to_t.length() <= spd120 * delta:
							_a120_node.position = tgt
							_a120_path_idx += 1
						else:
							_a120_node.position += to_t.normalized() * spd120 * delta
					if d120 >= 165.0 or _a120_path_idx >= _a120_path.size():
						_a120_active = false
						_a120_phase = 0
						_a120_substage = 0
						_a120_node.visible = false
						audio.stop_a120()
						if _net != null and _net.is_online():
							_net.broadcast_entity_event({"k": "a120_end"}, true)

		if is_auth and send_ent_sync and _a120_active and _net != null and _net.is_online():
			var p120 := _a120_node.position
			_net.broadcast_entity_event({
				"k": "a120_pos",
				"p": [p120.x, p120.y, p120.z],
				"ph": _a120_phase,
				"ss": _a120_substage,
				"room": _current_room_idx,
			}, false)

		if can_harm_local and _a120_active and _a120_phase == 2 and _a120_node.global_position.distance_to(cam.global_position) < 2.15 and (not _is_hiding or _is_locker_entry_anim()) and _a120_hit_cd <= 0.0:
			_handle_a120_hit()
			return
	else:
		_a120_node.visible = false


func _process_a90(delta: float) -> void:
	var scare_rect: TextureRect = _ui["a90_scare_rect"]
	if _a90_scare_timer > 0.0:
		_a90_scare_timer = maxf(_a90_scare_timer - delta, 0.0)
		scare_rect.modulate.a = clampf(_a90_scare_timer / 0.45, 0.0, 1.0)
		if _a90_scare_timer <= 0.0:
			scare_rect.visible = false

	var a90_root: Control = _ui["a90_root"]
	var a90_mat: ShaderMaterial = _ui["a90_mat"]
	var a90_rect: TextureRect = _ui["a90_rect"]
	var a90_stop_icon: TextureRect = _ui["a90_stop_icon"]
	var a90_stop: Label = _ui["a90_stop"]
	var a90_hint: Label = _ui["a90_hint"]
	var a90_bar_holder: Control = _ui["a90_bar_holder"]
	var a90_bar_fill: ColorRect = _ui["a90_bar_fill"]
	var a90_shake: Control = _ui["a90_shake"]

	if _a90_phase == 0:
		a90_root.visible = false
		if not _is_entity_authority():
			return
		if _highest_opened < 9 or _is_hiding or _a60_active or _a120_active or _power_out:
			return
		_a90_cooldown -= delta
		if _a90_cooldown > 0.0:
			return
		_a90_cooldown = _rng.randf_range(24.0, 40.0)
		if _rng.randf() > 0.76:
			return
		_start_a90_local()
		return

	# Cancel cleanly if the player is no longer vulnerable
	if _is_hiding:
		_end_a90()
		return

	if _a90_phase == 1:
		_a90_timer -= delta
		var t := clampf(1.0 - _a90_timer / 0.55, 0.0, 1.0)
		a90_root.visible = true
		a90_root.modulate.a = t
		a90_mat.set_shader_parameter("red_amt", t * 0.62)
		a90_mat.set_shader_parameter("static_amt", t * 0.55)
		var wob := lerpf(34.0, 4.0, t)
		a90_shake.position = Vector2(_rng.randf_range(-wob, wob), _rng.randf_range(-wob, wob))
		if _a90_timer <= 0.0:
			_a90_phase = 2
			_a90_timer = _a90_freeze_dur
			_a90_grace = 0.18
			_a90_start_pos = player_body.position
			_a90_start_yaw = _target_yaw
			_a90_start_pitch = _target_pitch
			player_body.velocity.x *= 0.12
			player_body.velocity.z *= 0.12
			a90_root.visible = true
			a90_root.modulate.a = 1.0
			a90_shake.position = Vector2.ZERO
			a90_rect.texture = _a90_textures.get("pre", _a90_textures.get("warn"))
			a90_stop_icon.visible = true
			a90_stop.visible = true
			a90_hint.visible = true
			a90_bar_holder.visible = true
			a90_mat.set_shader_parameter("red_amt", 0.62)
			a90_mat.set_shader_parameter("static_amt", 0.38)
			audio.play_a90_warn()
	elif _a90_phase == 2:
		_a90_timer -= delta
		if _a90_grace > 0.0:
			_a90_grace = maxf(_a90_grace - delta, 0.0)
			_a90_start_pos = player_body.position
			_a90_start_yaw = _target_yaw
			_a90_start_pitch = _target_pitch
		var ratio := clampf(_a90_timer / maxf(_a90_freeze_dur, 0.01), 0.0, 1.0)
		a90_bar_fill.size = Vector2(360.0 * ratio, 7.0)
		a90_bar_fill.color = Color(1.0, 0.20, 0.16, 0.95) if ratio > 0.34 else Color(1.0, 0.72, 0.18, 0.98)
		var jit := lerpf(2.0, 9.0, 1.0 - ratio)
		a90_shake.position = Vector2(_rng.randf_range(-jit, jit), _rng.randf_range(-jit, jit))
		a90_mat.set_shader_parameter("red_amt", 0.55 + 0.20 * (1.0 - ratio))
		a90_mat.set_shader_parameter("static_amt", 0.34 + 0.30 * (1.0 - ratio))

		var moved := player_body.position.distance_to(_a90_start_pos) > 0.09
		var turned := absf(wrapf(_target_yaw - _a90_start_yaw, -PI, PI)) > 0.045 or absf(_target_pitch - _a90_start_pitch) > 0.045
		if _a90_grace <= 0.0 and (moved or turned):
			_a90_phase = 0
			_a90_hits += 1
			a90_root.visible = false
			a90_stop_icon.visible = false
			a90_stop.visible = false
			a90_hint.visible = false
			a90_bar_holder.visible = false
			_a90_cooldown = _rng.randf_range(26.0, 44.0)
			_hp -= 90
			audio.play_a90_hit()
			audio.low_hp_mode = (_hp <= 25 and _hp > 0)
			(_ui["dmg_flash"] as ColorRect).color = Color(0.85, 0.05, 0.05, 0.72)
			_shake_amount = 0.10
			if _hp <= 0:
				_trigger_death("A-90", "", {"a90_moved": moved, "a90_turned": turned})
				return
			_a90_scare_timer = 0.45
			scare_rect.texture = _a90_textures["rage"]
			scare_rect.modulate = Color(1.0, 1.0, 1.0, 0.95)
			scare_rect.visible = true
			_show_toast("A-90 нанёс 90 урона! Замирайте полностью!", 2.5)
		elif _a90_timer <= 0.0:
			_a90_phase = 3
			_a90_timer = 0.30
			a90_stop_icon.visible = false
			a90_stop.visible = false
			a90_hint.visible = false
			a90_bar_holder.visible = false
			a90_rect.texture = _a90_textures.get("pre", _a90_textures.get("warn"))
			_end_a90_broadcast()
	elif _a90_phase == 3:
		_a90_timer -= delta
		var t2 := clampf(_a90_timer / 0.30, 0.0, 1.0)
		a90_root.modulate.a = t2
		a90_mat.set_shader_parameter("red_amt", t2 * 0.50)
		a90_mat.set_shader_parameter("static_amt", t2 * 0.30)
		a90_shake.position = Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
		if _a90_timer <= 0.0:
			_end_a90()


func _start_a90_local() -> void:
	_a90_depth = clampf(float(_highest_opened - 9) / 91.0, 0.0, 1.0)
	_a90_freeze_dur = lerpf(2.3, 3.4, _a90_depth) + _rng.randf_range(-0.15, 0.15)
	_a90_phase = 1
	_a90_timer = 0.55
	_a90_grace = 0.0
	var a90_root: Control = _ui["a90_root"]
	var a90_rect: TextureRect = _ui["a90_rect"]
	var a90_stop_icon: TextureRect = _ui["a90_stop_icon"]
	var a90_stop: Label = _ui["a90_stop"]
	var a90_hint: Label = _ui["a90_hint"]
	var a90_bar_holder: Control = _ui["a90_bar_holder"]
	var a90_mat: ShaderMaterial = _ui["a90_mat"]
	a90_root.visible = true
	a90_root.modulate.a = 0.0
	a90_rect.texture = _a90_textures.get("warn")
	a90_stop_icon.visible = false
	a90_stop.visible = false
	a90_hint.visible = false
	a90_bar_holder.visible = false
	a90_mat.set_shader_parameter("red_amt", 0.0)
	a90_mat.set_shader_parameter("static_amt", 0.0)
	audio.play_a90_warn()
	if _is_entity_authority() and _net != null and _net.is_online():
		_net.broadcast_entity_event({"k": "a90_spawn", "dur": _a90_freeze_dur}, true)


func _end_a90_broadcast() -> void:
	if _is_entity_authority() and _net != null and _net.is_online():
		_net.broadcast_entity_event({"k": "a90_end"}, true)


func _end_a90() -> void:
	_a90_phase = 0
	_a90_timer = 0.0
	_a90_grace = 0.0
	_a90_cooldown = _rng.randf_range(26.0, 44.0)
	if not _ui.has("a90_root"):
		return
	var a90_root: Control = _ui["a90_root"]
	a90_root.visible = false
	a90_root.modulate.a = 1.0
	for vk in ["a90_stop_icon", "a90_stop", "a90_hint", "a90_bar_holder"]:
		if _ui.has(vk):
			(_ui[vk] as Control).visible = false
