extends "res://scripts/rooms/rooms_screens.gd"

func _reset_run(forced_seed: int = -1) -> void:
	for child in rooms_container.get_children():
		child.queue_free()
	_rooms.clear()
	_room_by_idx.clear()
	_occupied_cells.clear()
	_opening_doors.clear()

	if forced_seed > 0:
		_world_seed = forced_seed & 0x7FFFFFFF
	else:
		var tmp_rng := RandomNumberGenerator.new()
		tmp_rng.randomize()
		_world_seed = maxi(int(tmp_rng.randi() & 0x3FFFFFFF), 1)
	_rng.seed = _world_seed
	_next_cell = Vector2i.ZERO
	_next_in_dir = Vector3(0.0, 0.0, -1.0)
	_next_room_index = 0
	_highest_opened = 0
	_current_room_idx = 0

	_hp = 100
	_stamina = 1.0
	_stamina_regen_delay = 0.0
	_exhausted = false
	_is_sprinting = false
	_door_hand_timer = 0.0
	_door_hand_slam = false
	_death_phase = 0
	_death_phase_t = 0.0
	_spectate_key = ""
	_pant_timer = 0.0
	_run_time = 0.0
	_victory_reached = false
	_checkpoint_room = 0

	_is_hiding = false
	_hiding_room_idx = -1
	_hiding_locker_idx = -1
	_hiding_kind = "locker"
	_hiding_door_pivot = null
	_hiding_eye_local_y = 1.48
	_locker_blend = 0.0
	_locker_transition_t = 1.0
	_door_hand_timer = 0.0
	_spectate_last_hiding = false
	_spectate_user_orbited = false
	_target_hide_yaw = 0.0
	_target_hide_pitch = 0.0
	_hide_yaw_offset = 0.0
	_hide_pitch_offset = 0.0
	player_col.disabled = false
	_power_out = false
	_light_on = true
	_active_tool = 0
	_has_gummy = false
	_std_battery = 150.0
	_gummy_battery = 100.0
	_batteries = 0
	_std_low_power = false
	_std_low_power_regen = 0.0
	_std_low_flicker_t = 0.0
	_vm_shake_time = 0.0
	_gummy_hold_accum = 0.0
	_gummy_pump_phase = 0.0
	_rmb_held = false
	_reminder_dismissed = false
	_toast_timer = 0.0
	_toast_alpha = 0.0
	_prompt_alpha = 0.0
	_reminder_alpha = 0.0
	var hint := "ПКМ — фонарик · Shift — бег · E — взаимодействие · ESC — пауза"
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		hint = "Кнопки справа — фонарик и бег · тап — взаимодействие · пауза сверху"
	_show_toast(hint, 5.5)
	_reminder_dismissed = true
	_reticle_lag_offset = Vector2.ZERO
	_reticle_screen_pos = Vector2.ZERO
	_locker_transition_duration = 1.00
	if _vm_holder != null:
		_vm_holder.visible = true
	if _anim_hand != null:
		_anim_hand.visible = false

	_a60_active = false
	_a60_phase = 0
	_a60_is_prime = false
	_a60_prime_rebounds = 0
	_a60_prime_pending_timer = 0.0
	_a60_prime_chains_left = 0
	_a60_prime_flicker_active = false
	_a60_prime_flicker_gap_t = 0.0
	_a60_prime_flicker_snd_cd = 0.0
	_a60_prime_table_burned = false
	_a60_prime_hit_cd = 0.0
	_a60_hint_timer = 0.0
	_a60_random_timer = _rng.randf_range(22.0, 36.0)
	_a60_scare_snd_cd = 0.0
	_a60_node.visible = false
	audio.stop_a60()
	_a120_active = false
	_a120_phase = 0
	_a120_substage = 0
	_a120_drum_bounce = 0.0
	_a120_anim_timer = 0.0
	_a120_hit_cd = 0.0
	_ent_sync_accum = 0.0
	_a120_sprite.position = Vector3.ZERO
	_a120_sprite.scale = Vector3.ONE
	_a120_node.visible = false
	audio.stop_a120()
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	_darkness_dmg_accum = 0.0
	_darkness_quick_return = false
	audio.stop_darkness()
	(_ui["darkness_rect"] as Control).visible = false
	_a90_phase = 0
	_a90_timer = 0.0
	_a90_grace = 0.0
	_a90_cooldown = 18.0
	_a90_scare_timer = 0.0
	_a90_hits = 0
	for vk in ["a90_root", "a90_hint", "a90_bar_holder"]:
		if _ui.has(vk):
			(_ui[vk] as Control).visible = false
	audio.a60_intensity = 0.0
	audio.low_hp_mode = false

	for _i in range(5 if _render_quality == RenderQuality.MOBILE_OPT else 7):
		_spawn_next_room()
	_update_room_visibility()

	player_body.position = Vector3(0.0, 0.05, 4.0)
	player_body.velocity = Vector3.ZERO
	player_body.rotation = Vector3.ZERO
	_target_yaw = 0.0
	_target_pitch = 0.0
	_yaw = 0.0
	_pitch = 0.0
	_cam_roll = 0.0
	_spectate_yaw = 0.0
	_spectate_pitch = 0.25
	_fov = 75.0
	cam.fov = 75.0
	cam.position = Vector3(0.0, 1.48, 0.0)
	cam.rotation = Vector3.ZERO
	_apply_camera_rotation()
	flashlight.visible = true
	(_ui["architect_overlay"] as Control).visible = false
	if _ui.has("death_iris"):
		(_ui["death_iris"] as Control).visible = false
	if _ui.has("spectate_bar"):
		(_ui["spectate_bar"] as Control).visible = false
	_clear_all_vignettes()
	_reset_touch_state()
	if _net != null:
		_net.update_lobby_progress(_world_seed, 0)
		if _net.is_online() and _net.is_host and forced_seed <= 0:
			_net.broadcast_session_sync(_world_seed, 0)
	_set_state(State.PLAYING)
	_show_toast("Вы в Секции A. Откройте дверь A-001, чтобы начать.", 3.5)


func _spawn_next_room() -> void:
	var idx := _next_room_index
	_next_room_index += 1
	var cell := _next_cell
	var in_dir := _next_in_dir
	_occupied_cells[cell] = true

	# Strictly deterministic per-room RNG derived ONLY from (_world_seed, idx)
	# so gameplay events (A-60/A-120/flicker) NEVER desync room generation between friends!
	var room_rng := RandomNumberGenerator.new()
	var mixed_seed := (((_world_seed * 1103515245) + ((idx + 1) * 2654435761)) ^ (idx * 747796405)) & 0x7FFFFFFF
	if mixed_seed <= 0:
		mixed_seed = idx + 1
	room_rng.seed = mixed_seed

	var out_dir := in_dir
	if idx >= 2:
		var roll := room_rng.randf()
		var cand := in_dir
		if roll < 0.17:
			cand = RoomBuilder.rotate_left(in_dir)
		elif roll < 0.34:
			cand = RoomBuilder.rotate_right(in_dir)

		# Ensure we don't loop back (+Z) or collide with existing rooms
		if cand.z <= 0.1:
			var step1 := cell + RoomBuilder.dir_to_grid_step(cand)
			var step2 := step1 + RoomBuilder.dir_to_grid_step(cand)
			if not _occupied_cells.has(step1) and not _occupied_cells.has(step2):
				out_dir = cand

	var r := RoomBuilder.build_room(rooms_container, _assets, idx, cell, in_dir, out_dir, room_rng, idx >= 50)
	_rooms.append(r)
	_room_by_idx[idx] = r

	_next_cell = cell + RoomBuilder.dir_to_grid_step(out_dir)
	_next_in_dir = out_dir

	# Prune rooms far behind to keep FPS steady (tighter on Mobile FPS preset)
	var max_keep := 10 if _render_quality == RenderQuality.MOBILE_OPT else 16
	var back_keep := 4 if _render_quality == RenderQuality.MOBILE_OPT else 7
	while _rooms.size() > max_keep and _rooms[0].index < _current_room_idx - back_keep:
		var old_r: RoomBuilder.RoomInstance = _rooms.pop_front()
		_room_by_idx.erase(old_r.index)
		old_r.root.queue_free()
	_update_room_visibility()


func _set_state(new_state: State) -> void:
	_state = new_state
	var hud_on := (_state == State.PLAYING or _state == State.PAUSED or _state == State.VICTORY)
	(_ui["hud_group"] as Control).visible = hud_on
	# Chat log is visible in every online state (menu hides it); dead/spectators are read-only
	if _ui.has("chat_box"):
		var chat_online := _net != null and _net.is_online() and _state != State.MENU
		var chat_box := _ui["chat_box"] as Control
		chat_box.visible = chat_online
		if not chat_online and _chat_open:
			call("_chat_toggle", false)
		call("_chat_set_readonly", _state == State.DEAD or _state == State.SPECTATING)
	if _ui.has("main_menu"):
		(_ui["main_menu"] as Control).visible = (_state == State.MENU)
	if _ui.has("spectate_bar"):
		(_ui["spectate_bar"] as Control).visible = (_state == State.SPECTATING)
	if _ui.has("mobile_group"):
		(_ui["mobile_group"] as Control).visible = _mobile_controls_enabled and (_state == State.PLAYING)
	if _ui.has("btn_arch_next"):
		_style_arch_terminal_buttons()
		if _state == State.DEAD:
			_refresh_architect_controls()

	if _state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
		(_ui["modal"] as Control).visible = false
		(_ui["architect_overlay"] as Control).visible = false
		if _ui.has("death_iris"):
			(_ui["death_iris"] as Control).visible = false
	elif _state == State.SPECTATING:
		_reset_touch_state()
		_clear_all_vignettes()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
		(_ui["modal"] as Control).visible = false
		(_ui["architect_overlay"] as Control).visible = false
		if _ui.has("death_iris"):
			(_ui["death_iris"] as Control).visible = false
		if _vm_holder != null:
			_vm_holder.visible = false
		if _anim_hand != null:
			_anim_hand.visible = false
		flashlight.visible = false
	elif _state == State.MENU:
		_reset_touch_state()
		_clear_all_vignettes()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		(_ui["modal"] as Control).visible = false
		(_ui["architect_overlay"] as Control).visible = false
		if _ui.has("death_iris"):
			(_ui["death_iris"] as Control).visible = false
		if _ui.has("spectate_bar"):
			(_ui["spectate_bar"] as Control).visible = false
		player_body.velocity = Vector3.ZERO
		_show_main_menu(false)
	else:
		_reset_touch_state()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var modal: Control = _ui["modal"]
		modal.visible = (_state == State.PAUSED or _state == State.VICTORY)
		if modal.visible:
			modal.modulate.a = 0.0
			create_tween().tween_property(modal, "modulate:a", 1.0, 0.18)
		var title: Label = _ui["m_title"]
		var desc: Label = _ui["m_desc"]
		var btn_res: Button = _ui["btn_resume"]
		if _state == State.PAUSED:
			_open_settings_panel(false)
			title.visible = false
			desc.visible = false
			btn_res.text = "continue"
			btn_res.visible = true
		elif _state == State.VICTORY:
			_open_settings_panel(false)
			title.visible = true
			desc.visible = true
			title.text = "A-200"
			title.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
			var mins := int(_run_time) / 60
			var secs := int(_run_time) % 60
			desc.text = "section A cleared in %02d:%02d\ncontinue into the endless run, or exit." % [mins, secs]
			btn_res.text = "continue"
			btn_res.visible = true


func _exit_to_main_menu() -> void:
	_reset_run()
	_set_state(State.MENU)


func _clear_all_vignettes() -> void:
	if _ui.has("vitals_mat"):
		var vmat := _ui["vitals_mat"] as ShaderMaterial
		for k in ["hp_loss", "stam_loss", "exhausted_amt", "darkness_amt"]:
			vmat.set_shader_parameter(k, 0.0)
	if _ui.has("vitals_rect"):
		(_ui["vitals_rect"] as Control).visible = false
	if _ui.has("darkness_rect"):
		var dkr := _ui["darkness_rect"] as Control
		dkr.visible = false
		dkr.modulate.a = 0.0
	if _ui.has("static_mat"):
		var smat := _ui["static_mat"] as ShaderMaterial
		smat.set_shader_parameter("static_amt", 0.0)
		smat.set_shader_parameter("vig_amt", 0.0)
	if _ui.has("static_rect"):
		(_ui["static_rect"] as Control).visible = false
	if _ui.has("locker_mask"):
		var lm := _ui["locker_mask"] as ColorRect
		lm.color = Color(0.0, 0.0, 0.0, 0.0)
		lm.visible = false
	if _ui.has("dmg_flash"):
		var df := _ui["dmg_flash"] as ColorRect
		df.color.a = 0.0
		df.visible = false
	for vk in ["a90_root", "a90_rect", "a90_stop_icon", "a90_stop", "a90_hint", "a90_bar_holder", "a90_scare_rect", "a60_scare_rect"]:
		if _ui.has(vk):
			(_ui[vk] as Control).visible = false


func _trigger_death(cause: String, _tip: String = "", extra_ctx: Dictionary = {}) -> void:
	if _state != State.PLAYING:
		return
	audio.play_death_sound()
	if cause != "A-120" and cause != "A-60" and cause != "A-60'":
		audio.play_jumpscare()
	audio.stop_a120()
	audio.stop_a60()
	audio.stop_darkness()
	_darkness_phase = 0
	_darkness_whisper_t = 0.0
	audio.a60_intensity = 0.0
	var keep_auth_ent := _is_entity_authority() and _net != null and _net.is_online() and _has_alive_remote_players()
	if not keep_auth_ent:
		_a60_active = false
		_a60_phase = 0
		_a60_prime_pending_timer = 0.0
		_a60_prime_chains_left = 0
		_a120_active = false
		_a120_phase = 0
		_a120_substage = 0
	_a60_prime_flicker_active = false
	_a60_node.visible = false
	_a120_node.visible = false
	_a90_phase = 0
	_door_hand_timer = 0.0
	_locker_transition_t = 1.0
	_rmb_held = false
	_clear_all_vignettes()
	(_ui["modal"] as Control).visible = false

	_state = State.DEAD
	_death_phase = 0
	_death_phase_t = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(_ui["hud_group"] as Control).visible = false
	if _net != null:
		_net.voice_talking = false
	if _chat_open:
		call("_chat_toggle", false)

	if _ui.has("death_iris"):
		var iris := _ui["death_iris"] as Control
		var imat := _ui.get("death_iris_mat") as ShaderMaterial
		iris.visible = true
		if imat != null:
			imat.set_shader_parameter("red_amt", 0.92)
			imat.set_shader_parameter("shrink_amt", 0.0)

	var cur_room: RoomBuilder.RoomInstance = _room_by_idx.get(_current_room_idx)
	var cur_bat := _std_battery if _active_tool == 0 else _gummy_battery
	var ctx := {
		"room_lockers_count": cur_room.lockers.size() if cur_room != null else 0,
		"battery": cur_bat,
		"has_gummy": _has_gummy,
	}
	for k in extra_ctx.keys():
		ctx[k] = extra_ctx[k]

	var u_name := _get_local_username()
	var seq := _architect.build_death_sequence(cause, _highest_opened, u_name, ctx)
	_arch_lines.clear()
	_arch_lines.append("Died cause of %s" % cause)
	_arch_lines.append("Did it to A-%03d" % _highest_opened)

	_death_hidden = false
	_arch_line_idx = 0
	_arch_char_pos = 0.0
	_arch_blip_acc = 0
	_arch_glitch_step = 0
	_arch_glitch_timer = 0.0
	_arch_prev_text = "hello"
	_arch_auto_advance_timer = 0.0

	(_ui["arch_title"] as Label).text = String(seq["title"])
	(_ui["arch_meta"] as Label).text = "ENTITY: %s  |  DEATHS: #%d  |  BEST ROOM: A-%03d" % [
		cause, int(seq["deaths_total"]), _architect.best_room
	]
	(_ui["arch_tip"] as Label).text = "TIP: %s" % String(seq["summary"])
	if _ui.has("arch_ascii"):
		(_ui["arch_ascii"] as RichTextLabel).text = String(seq.get("art_bbcode", ""))
	(_ui["arch_speech"] as Label).text = ""
	if _ui.has("arch_player_lbl"):
		(_ui["arch_player_lbl"] as Label).text = "<< %s >>" % u_name
	_set_death_windows_visible(true)
	_refresh_architect_controls()

	if cause == "A-90" and _a90_textures.has("rage"):
		_a90_phase = 0
		_a90_scare_timer = 0.45
		var scare_rect: TextureRect = _ui["a90_scare_rect"]
		scare_rect.texture = _a90_textures["rage"]
		scare_rect.modulate = Color(1.0, 1.0, 1.0, 0.92)
		scare_rect.visible = true
	else:
		_a90_scare_timer = 0.0
		(_ui["a90_scare_rect"] as Control).visible = false

	# Keep Architect hidden during red flash & center-shrink; fades in smoothly once _death_phase reaches 2
	var arch_overlay: Control = _ui["architect_overlay"]
	arch_overlay.visible = false
	arch_overlay.modulate.a = 0.0


func _set_death_windows_visible(vis: bool) -> void:
	for k in ["arch_window_big", "arch_window_small"]:
		if _ui.has(k):
			(_ui[k] as Control).visible = vis


func _get_local_username() -> String:
	if _net != null:
		var n: String = _net.persona_name
		if n != "" and n != "Player":
			return n
	var env_user := OS.get_environment("USERNAME")
	if env_user != "":
		return env_user
	env_user = OS.get_environment("USER")
	if env_user != "":
		return env_user
	return "Player"


func _style_arch_terminal_buttons() -> void:
	if not _ui.has("btn_arch_next") or not _ui.has("btn_arch_retry"):
		return
	var btn_next := _ui["btn_arch_next"] as Button
	var btn_retry := _ui["btn_arch_retry"] as Button
	var mono_f := RoomsArchitect.get_terminal_font()

	if _mobile_controls_enabled:
		btn_next.visible = true
		btn_retry.visible = true
		btn_next.flat = false
		btn_retry.flat = false
		btn_next.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_retry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_next.offset_left = 24
		btn_next.offset_top = -54
		btn_next.offset_right = 230
		btn_next.offset_bottom = -14
		btn_retry.offset_left = 244
		btn_retry.offset_top = -54
		btn_retry.offset_right = 400
		btn_retry.offset_bottom = -14
		RoomsUI.style_button(btn_next, Color(0.28, 1.0, 0.42), 14)
		RoomsUI.style_button(btn_retry, Color(0.85, 0.75, 0.35), 14)
		btn_next.add_theme_font_override("font", mono_f)
		btn_retry.add_theme_font_override("font", mono_f)
	else:
		btn_next.visible = false
		btn_retry.visible = false
		btn_next.flat = true
		btn_retry.flat = true
		btn_next.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_retry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_retry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_next.offset_left = 24
		btn_next.offset_top = -46
		btn_next.offset_right = 320
		btn_next.offset_bottom = -16
		btn_retry.offset_left = 330
		btn_retry.offset_top = -46
		btn_retry.offset_right = 500
		btn_retry.offset_bottom = -16

		var empty_sb := StyleBoxEmpty.new()
		for sb in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn_next.add_theme_stylebox_override(sb, empty_sb)
			btn_retry.add_theme_stylebox_override(sb, empty_sb)

		btn_next.add_theme_font_override("font", mono_f)
		btn_next.add_theme_font_size_override("font_size", 13)
		btn_next.add_theme_color_override("font_color", Color(0.60, 0.72, 0.65, 0.85))
		btn_next.add_theme_color_override("font_hover_color", Color(0.28, 1.0, 0.42, 1.0))
		btn_next.add_theme_color_override("font_pressed_color", Color(0.95, 1.0, 0.95, 1.0))

		btn_retry.add_theme_font_override("font", mono_f)
		btn_retry.add_theme_font_size_override("font_size", 13)
		btn_retry.add_theme_color_override("font_color", Color(0.60, 0.72, 0.65, 0.85))
		btn_retry.add_theme_color_override("font_hover_color", Color(1.0, 0.82, 0.35, 1.0))
		btn_retry.add_theme_color_override("font_pressed_color", Color(0.95, 1.0, 0.95, 1.0))


func _refresh_architect_controls() -> void:
	var total := maxi(_arch_lines.size(), 1)
	if _ui.has("arch_page"):
		(_ui["arch_page"] as Label).text = "LINE %02d / %02d" % [_arch_line_idx + 1, total]
	_style_arch_terminal_buttons()
	var btn_next: Button = _ui.get("btn_arch_next")
	var btn_retry: Button = _ui.get("btn_arch_retry")
	if btn_next == null:
		return
	var can_spectate := (_net != null and _net.is_online() and not _remote_players.is_empty())
	if _mobile_controls_enabled:
		if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
			btn_next.text = "Пропустить >"
		elif _arch_line_idx + 1 < total:
			btn_next.text = "Далее >"
		elif can_spectate:
			btn_next.text = "Наблюдать >"
		else:
			btn_next.text = "Завершить >"
		if btn_retry != null:
			btn_retry.text = "Заново"
	else:
		if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] ПРОПУСТИТЬ"
		elif _arch_line_idx + 1 < total:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] ДАЛЕЕ"
		elif can_spectate:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] НАБЛЮДЕНИЕ"
		else:
			btn_next.text = "> [ПРОБЕЛ / ЛКМ] ЗАВЕРШИТЬ"
		if btn_retry != null:
			btn_retry.text = "> [R] ЗАНОВО"
	btn_next.disabled = false


func _advance_architect_dialogue() -> void:
	if _state != State.DEAD or _death_phase < 2 or _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if _arch_glitch_step < 12:
		# Immediately finish glitch animation
		_arch_glitch_step = 12
		var sp_lbl: Label = _ui["arch_speech"]
		var reveal := ""
		for i in range(_arch_line_idx + 1):
			if i > 0:
				reveal += "\n"
			reveal += "> " + String(_arch_lines[i])
		sp_lbl.text = reveal
		sp_lbl.add_theme_color_override("font_color", Color(0.88, 0.89, 0.92))
		_arch_prev_text = cur_line
		_arch_char_pos = float(cur_line.length())
		_arch_auto_advance_timer = 0.0
		_refresh_architect_controls()
		return
	if _arch_line_idx + 1 < _arch_lines.size():
		_arch_line_idx += 1
		_arch_glitch_step = 0
		_arch_glitch_timer = 0.0
		_arch_char_pos = 0.0
		_arch_blip_acc = 0
		_arch_auto_advance_timer = 0.0
		_refresh_architect_controls()
	else:
		if _net != null and _net.is_online() and not _remote_players.is_empty():
			_start_spectating()
		_refresh_architect_controls()


func _start_spectating() -> void:
	_set_state(State.SPECTATING)
	_spectate_pitch = 0.25
	_cycle_spectate_target(0)


func _cycle_spectate_target(step: int) -> void:
	var keys := _remote_players.keys()
	if keys.is_empty():
		_spectate_key = ""
		if _ui.has("spectate_lbl"):
			(_ui["spectate_lbl"] as Label).text = "Нет активных игроков — нажмите [R] для рестарта"
		return
	keys.sort()
	# Prefer alive teammates first
	var alive_keys := []
	for k in keys:
		var rp: Dictionary = _remote_players[k]
		if not bool(rp.get("dead", false)):
			alive_keys.append(k)
	var pool: Array = alive_keys if not alive_keys.is_empty() else keys
	var cur_idx := pool.find(_spectate_key)
	if cur_idx < 0:
		cur_idx = 0
	elif step != 0:
		cur_idx = posmod(cur_idx + step, pool.size())
	_spectate_key = String(pool[cur_idx])
	var rp_sel: Dictionary = _remote_players.get(_spectate_key, {})
	var rp_sel_yaw := float(rp_sel.get("tgt_yaw", 0.0))
	_spectate_last_hiding = bool(rp_sel.get("hiding", false))
	_spectate_user_orbited = false
	_spectate_yaw = wrapf(rp_sel_yaw + PI * 0.88, -PI, PI) if _spectate_last_hiding else rp_sel_yaw


func _process_spectating(delta: float) -> void:
	if _spectate_key.is_empty() or not _remote_players.has(_spectate_key):
		_cycle_spectate_target(0)
	if _spectate_key.is_empty() or not _remote_players.has(_spectate_key):
		return
	var rp: Dictionary = _remote_players[_spectate_key]
	var tgt_node: Node3D = rp.get("node")
	if not is_instance_valid(tgt_node):
		return

	var r_num := int(rp.get("room", 0))
	if r_num != _current_room_idx:
		_current_room_idx = r_num
		_update_room_visibility()

	var is_dead_t := bool(rp.get("dead", false))
	if _ui.has("spectate_lbl"):
		var s_txt := "Наблюдение: %s [A-%03d]" % [String(rp.get("name", "Player")), r_num]
		if is_dead_t:
			s_txt += " (МЁРТВ — [R] Рестарт)"
		else:
			s_txt += "   |   ЛКМ / A-D — Сменить   |   [R] — Рестарт"
		(_ui["spectate_lbl"] as Label).text = s_txt

	var rp_hiding := bool(rp.get("hiding", false))
	var rp_under_desk := (_get_remote_hiding_kind(rp) == "under_desk")
	var rp_yaw := float(rp.get("tgt_yaw", 0.0))
	if rp_hiding != _spectate_last_hiding:
		_spectate_last_hiding = rp_hiding
		_spectate_user_orbited = false

	if not _spectate_user_orbited:
		var auto_yaw := wrapf(rp_yaw + PI * 0.88, -PI, PI) if rp_hiding else rp_yaw
		_spectate_yaw = lerp_angle(_spectate_yaw, auto_yaw, 1.0 - exp(-10.0 * delta))

	var pivot: Vector3
	var desired: Vector3
	if rp_hiding:
		var hr_idx := int(rp.get("hide_room", -1))
		var hl_idx := int(rp.get("hide_locker", -1))
		var hide_node: Node3D = null
		if hr_idx >= 0 and _room_by_idx.has(hr_idx):
			var hr_inst: RoomBuilder.RoomInstance = _room_by_idx[hr_idx]
			if hl_idx >= 0 and hl_idx < hr_inst.lockers.size():
				hide_node = hr_inst.lockers[hl_idx].get("node") as Node3D

		if hide_node != null:
			var fwd := hide_node.global_transform.basis.z.normalized()
			var h_pos := hide_node.global_position
			pivot = h_pos + Vector3(0.0, 0.45 if rp_under_desk else 1.35, 0.0)
			var view_fwd := (Basis(Vector3.UP, _spectate_yaw) * Vector3(0.0, 0.0, 1.0)).normalized() if _spectate_user_orbited else fwd
			desired = pivot + view_fwd * (2.1 if rp_under_desk else 2.5) + Vector3(0.0, 0.60 if rp_under_desk else 0.20, 0.0)
		else:
			pivot = tgt_node.global_position + Vector3(0.0, 0.58 if rp_under_desk else 1.36, 0.0)
			var back_dir := (Basis(Vector3.UP, _spectate_yaw) * Basis(Vector3.RIGHT, -_spectate_pitch) * Vector3(0.0, 0.0, 1.0)).normalized()
			desired = pivot + back_dir * 2.2
	else:
		if not _spectate_user_orbited:
			_spectate_yaw = lerp_angle(_spectate_yaw, rp_yaw, 1.0 - exp(-10.0 * delta))
		pivot = tgt_node.global_position + Vector3(0.0, 1.48, 0.0)
		var back_dir := (Basis(Vector3.UP, _spectate_yaw) * Basis(Vector3.RIGHT, -_spectate_pitch) * Vector3(0.0, 0.0, 1.0)).normalized()
		desired = pivot + back_dir * 2.55
		var space_state := get_world_3d().direct_space_state
		if space_state != null:
			var q := PhysicsRayQueryParameters3D.create(pivot, desired, 0xFFFFFFFF, [player_body.get_rid()])
			var hit := space_state.intersect_ray(q)
			if not hit.is_empty():
				desired = hit.get("position", desired) - back_dir * 0.22

	cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
	cam.look_at(pivot, Vector3.UP)
	cam.fov = lerpf(cam.fov, 76.0, 1.0 - exp(-10.0 * delta))


func _reset_touch_state() -> void:
	_joy_touch_id = -1
	_look_touch_id = -1
	_tap_touch_id = -1
	_joy_vec = Vector2.ZERO
	_joy_sprint = false
	_mobile_sprint_held = false
	_mobile_gummy_held = false
	if _joy_ring != null and _joy_knob != null:
		var vp_sz := get_viewport().get_visible_rect().size
		_joy_ring.position = Vector2(40.0, maxf(vp_sz.y - 270.0, 60.0))
		_joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.72)
		_joy_knob.position = Vector2(68.0, 68.0)


func _point_hits_mobile_btn(pos: Vector2) -> bool:
	for b in _mobile_btns:
		if is_instance_valid(b) and b.visible and b.get_global_rect().grow(10.0).has_point(pos):
			return true
	return false


func _update_joystick_from_pos(pos: Vector2) -> void:
	var max_r := 92.0
	var delta_v := pos - _joy_origin
	var dist := delta_v.length()
	var clamped := delta_v.normalized() * minf(dist, max_r) if dist > 0.001 else Vector2.ZERO
	_joy_vec = clamped / max_r
	if _joy_vec.length() < 0.14:
		_joy_vec = Vector2.ZERO
	_joy_sprint = false
	if _joy_ring != null and _joy_knob != null:
		_joy_knob.position = Vector2(110.0, 110.0) - _joy_knob.size * 0.5 + clamped


func _input(event: InputEvent) -> void:
	# Voice: releasing V always stops transmission
	if event is InputEventKey and not (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var kv := event as InputEventKey
		if kv.keycode == KEY_V and _net != null:
			_net.voice_talking = false

	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if not _mobile_controls_enabled and te.pressed and _mobile_override == 0:
			_mobile_controls_enabled = true
			_refresh_mobile_mode()
		if _state == State.DEAD and te.pressed:
			_advance_architect_dialogue()
			get_viewport().set_input_as_handled()
			return
		if _state != State.PLAYING or not _mobile_controls_enabled:
			return
		var vp_sz := get_viewport().get_visible_rect().size
		if te.pressed:
			if _point_hits_mobile_btn(te.position):
				return
			if _tap_touch_id == -1:
				_tap_touch_id = te.index
				_tap_start_pos = te.position
				_tap_start_time_ms = Time.get_ticks_msec()
			if te.position.x < vp_sz.x * 0.44 and _joy_touch_id == -1:
				_joy_touch_id = te.index
				var half := Vector2(110.0, 110.0)
				_joy_origin = Vector2(
					clampf(te.position.x, 116.0, vp_sz.x * 0.40),
					clampf(te.position.y, 140.0, vp_sz.y - 116.0)
				)
				if _joy_ring != null:
					_joy_ring.position = _joy_origin - half
					_joy_ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_update_joystick_from_pos(te.position)
			elif _look_touch_id == -1:
				_look_touch_id = te.index
		else:
			if te.index == _tap_touch_id:
				var dt_ms := Time.get_ticks_msec() - _tap_start_time_ms
				var dist_px := te.position.distance_to(_tap_start_pos)
				_tap_touch_id = -1
				if dt_ms <= 300 and dist_px <= 20.0 and not _is_hiding and not _point_hits_mobile_btn(te.position):
					call("_try_tap_world_interact", te.position)
			if te.index == _joy_touch_id:
				_joy_touch_id = -1
				_joy_vec = Vector2.ZERO
				_joy_sprint = false
				if _joy_ring != null and _joy_knob != null:
					_joy_ring.position = Vector2(40.0, maxf(vp_sz.y - 270.0, 60.0))
					_joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.72)
					_joy_knob.position = Vector2(68.0, 68.0)
			elif te.index == _look_touch_id:
				_look_touch_id = -1
		return

	elif event is InputEventScreenDrag:
		if _state != State.PLAYING or not _mobile_controls_enabled:
			return
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_touch_id:
			_update_joystick_from_pos(sd.position)
		elif sd.index == _look_touch_id:
			var sens := 0.0044 * _mouse_sens_mult
			if _is_hiding:
				_target_hide_yaw = clampf(_target_hide_yaw - sd.relative.x * sens, -0.58, 0.58)
				_target_hide_pitch = clampf(_target_hide_pitch - sd.relative.y * sens, -0.38, 0.38)
			else:
				_target_yaw -= sd.relative.x * sens
				_target_pitch = clampf(_target_pitch - sd.relative.y * sens, -1.42, 1.42)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		# While typing in chat: ESC closes, ENTER sends, everything else flows to the LineEdit
		if _chat_open:
			if ke.keycode == KEY_ESCAPE:
				call("_chat_toggle", false)
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
				call("_chat_submit")
				get_viewport().set_input_as_handled()
			return

		if _state == State.DEAD:
			if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				_advance_architect_dialogue()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_R:
				_reset_run()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_M:
				_death_hidden = not _death_hidden
				_set_death_windows_visible(not _death_hidden)
				get_viewport().set_input_as_handled()
				return

		if _state == State.MENU:
			if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_BACKSPACE:
				if _settings_from_menu:
					_open_settings_panel(false)
				elif _menu_view != "main":
					_set_menu_view("main")
				get_viewport().set_input_as_handled()
			return

		if _state == State.SPECTATING:
			if ke.keycode == KEY_A or ke.keycode == KEY_LEFT:
				_cycle_spectate_target(-1)
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_D or ke.keycode == KEY_RIGHT:
				_cycle_spectate_target(1)
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_R:
				_reset_run()
				get_viewport().set_input_as_handled()
				return

		# F11 — toggle fullscreen (works in any state)
		if ke.keycode == KEY_F11:
			var win := get_window()
			if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
				win.mode = Window.MODE_WINDOWED
			else:
				win.mode = Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
			return

		if ke.keycode == KEY_TAB or ke.keycode == KEY_ESCAPE:
			if _state == State.PLAYING:
				_set_state(State.PAUSED)
				get_viewport().set_input_as_handled()
				return
			elif _state == State.PAUSED:
				if _ui.has("m_settings_scroll") and (_ui["m_settings_scroll"] as Control).visible:
					_open_settings_panel(false)
				else:
					_set_state(State.PLAYING)
				get_viewport().set_input_as_handled()
				return

		if _state == State.PLAYING:
			if not _mobile_controls_enabled and ke.keycode == KEY_T and _net != null and _net.is_online():
				call("_chat_toggle", true)
				get_viewport().set_input_as_handled()
				return
			if ke.keycode == KEY_V and _net != null:
				_net.voice_talking = _net.is_online() and not _mobile_controls_enabled
				get_viewport().set_input_as_handled()
				return
			if _is_action_locked():
				if ke.keycode in [KEY_W, KEY_S, KEY_1, KEY_2, KEY_R]:
					get_viewport().set_input_as_handled()
					return
			if _is_hiding and ke.keycode == KEY_W:
				call("_exit_locker", false)
			elif _is_hiding and ke.keycode == KEY_S:
				call("_exit_locker", true)
			elif ke.keycode == KEY_1:
				_active_tool = 0
				_rmb_held = false
				audio.play_flashlight_click()
			elif ke.keycode == KEY_2 and _has_gummy:
				_active_tool = 1
				_light_on = true
				audio.play_flashlight_click()
			elif ke.keycode == KEY_R:
				call("_try_reload_flashlight")
			elif ke.keycode == KEY_M:
				_audio_muted = not _audio_muted
				_apply_audio_settings(true)
				_sync_settings_ui()
				_show_toast("Звук выключен" if _audio_muted else "Звук включён", 1.5)

	elif event is InputEventMouseMotion and (_state == State.PLAYING or _state == State.SPECTATING):
		if (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _chat_open:
			return
		if _state == State.SPECTATING:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				var rel_s := (event as InputEventMouseMotion).relative
				_spectate_yaw -= rel_s.x * 0.004 * _mouse_sens_mult
				_spectate_pitch = clampf(_spectate_pitch - rel_s.y * 0.004 * _mouse_sens_mult, -1.15, 0.85)
				_spectate_user_orbited = true
			return
		if not _mobile_controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if _locker_transition_t < 1.0:
				return
			var rel := (event as InputEventMouseMotion).relative
			if _is_hiding:
				_target_hide_yaw = clampf(_target_hide_yaw - rel.x * 0.0022 * _mouse_sens_mult, -0.58, 0.58)
				_target_hide_pitch = clampf(_target_hide_pitch - rel.y * 0.0022 * _mouse_sens_mult, -0.38, 0.38)
			else:
				_target_yaw -= rel.x * 0.0024 * _mouse_sens_mult
				_target_pitch = clampf(_target_pitch - rel.y * 0.0024 * _mouse_sens_mult, -1.42, 1.42)

	elif event is InputEventMouseButton and (_state == State.PLAYING or _state == State.SPECTATING):
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _state == State.SPECTATING:
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_cycle_spectate_target(1)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				_cycle_spectate_target(-1)
			return
		if _chat_open:
			return
		if _mobile_controls_enabled:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif not _is_action_locked():
				call("_try_interact")
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				if _is_action_locked():
					return
				if _active_tool == 1:
					_rmb_held = true
					_reminder_dismissed = true
					call("_try_shake_gummy", 3.5)
				else:
					call("_toggle_flashlight")
			else:
				_rmb_held = false


func _apply_camera_rotation() -> void:
	player_body.rotation = Vector3(0.0, _yaw, 0.0)
	cam.rotation = Vector3(_pitch, 0.0, _cam_roll)


func _sync_net_local_state() -> void:
	if _net != null and _net.is_online():
		var gp := player_body.global_position
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		var synced_yaw := player_body.rotation.y if _is_hiding else _yaw
		var synced_pitch := _hide_pitch_offset if _is_hiding else _pitch
		_net.update_local_state({
			"pos": [gp.x, gp.y, gp.z],
			"yaw": synced_yaw,
			"pitch": synced_pitch,
			"light": _light_on and (_active_tool == 0 and _std_battery > 0.05 or _active_tool == 1 and _gummy_battery > 0.05),
			"hide": _is_hiding,
			"hr": _hiding_room_idx if _is_hiding else -1,
			"hl": _hiding_locker_idx if _is_hiding else -1,
			"dead": (_state == State.DEAD or _state == State.SPECTATING),
			"sprint": hspd > 4.6,
			"room": _highest_opened,
			"hp": _hp,
			"tool": _active_tool,
			"gum": _has_gummy,
		})
		# Steam rich presence: current room + how many players are still alive
		var alive_now := 1 if _state == State.PLAYING else 0
		for rp in _remote_players.values():
			var rpv: Dictionary = rp
			if not bool(rpv.get("dead", false)):
				alive_now += 1
		_net.update_presence(_highest_opened, alive_now, 1 + _remote_players.size())


func _process(delta: float) -> void:
	_sync_net_local_state()
	_process_remote_players(delta)
	_update_warp_fx(delta)
	if _state == State.DEAD:
		_process_architect_and_scare(delta)
		return
	if _state == State.SPECTATING:
		call("_process_doors", delta)
		_process_spectating(delta)
		return
	if _state != State.PLAYING:
		return

	var look_alpha := 1.0 - exp(-18.0 * delta)
	_yaw = lerpf(_yaw, _target_yaw, look_alpha)
	_pitch = lerpf(_pitch, _target_pitch, look_alpha)
	_hide_yaw_offset = lerpf(_hide_yaw_offset, _target_hide_yaw, look_alpha)
	_hide_pitch_offset = lerpf(_hide_pitch_offset, _target_hide_pitch, look_alpha)

	var target_fov := (_base_fov - 9.0) if _is_hiding else _base_fov
	if not _is_hiding:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		if hspd > 4.6:
			target_fov = _base_fov + 6.0
	_fov = lerpf(_fov, target_fov, 1.0 - exp(-10.0 * delta))
	cam.fov = _fov

	if _locker_transition_t < 1.0:
		var dur := maxf(_locker_transition_duration, 0.05)
		_locker_transition_t = minf(_locker_transition_t + delta / dur, 1.0)

	if _is_action_locked():
		_mobile_gummy_held = false
	var shaking_gummy := (not _is_action_locked()) and (_mobile_gummy_held or (_rmb_held and not _mobile_controls_enabled)) and _active_tool == 1 and _has_gummy
	_is_shaking_gummy = shaking_gummy
	if shaking_gummy:
		_light_on = true
		_gummy_battery = minf(_gummy_battery + delta * 26.7, 100.0)
		_gummy_pump_phase += delta * 15.0
		_vm_shake_time = 0.14
		_gummy_hold_accum += delta
		if _gummy_hold_accum >= 0.36:
			_gummy_hold_accum -= 0.36
			audio.play_gummy_shake()
	else:
		_gummy_hold_accum = 0.0

	var lock_mask: ColorRect = _ui["locker_mask"]
	if _is_hiding:
		if _locker_transition_t < 1.0:
			var prev_t := maxf(_locker_transition_t - delta / maxf(_locker_transition_duration, 0.05), 0.0)
			if _locker_transition_t >= 0.72 and prev_t < 0.72 and _active_tool == 0:
				_light_on = false
		if _anim_hand != null:
			if _hiding_kind != "under_desk" and _locker_transition_t < 0.98:
				_anim_hand.visible = true
				var p := _locker_transition_t
				if p < 0.30:
					var rp := ease(p / 0.30, 0.35)
					_anim_hand.position = Vector3(0.36, -0.26, -0.02).lerp(Vector3(0.14, -0.14, -0.16), rp)
					_anim_hand.rotation = Vector3(0.05, 0.18 * rp, -0.14 * rp)
				elif p < 0.65:
					var sp := (p - 0.30) / 0.35
					_anim_hand.position = Vector3(0.14, -0.14, -0.16).lerp(Vector3(-0.08, -0.12, -0.12), sin(sp * PI * 0.5))
					_anim_hand.rotation = Vector3(0.0, 0.36 * sp, -0.10)
				else:
					var cp := (p - 0.65) / 0.35
					var swing := sin(cp * PI)
					_anim_hand.position = Vector3(0.22, -0.16, -0.04).lerp(Vector3(0.34, -0.30, 0.04), cp) + Vector3(-0.18 * swing, 0.04 * swing, -0.12 * swing)
					_anim_hand.rotation = Vector3(0.06 * swing, 0.26 * swing - 0.12 * cp, -0.10 * swing)
			else:
				_anim_hand.visible = false
		if _vm_holder != null:
			_vm_holder.visible = (_locker_transition_t >= 0.94 and (_light_on or shaking_gummy))
			if _vm_holder.visible:
				_vm_std.visible = (_active_tool == 0)
				_vm_gummy.visible = (_active_tool == 1)
				_vm_holder.position = Vector3(0.18, -0.19, -0.28)
				if _vm_shake_time > 0.0 or shaking_gummy:
					if not shaking_gummy:
						_vm_shake_time = maxf(_vm_shake_time - delta, 0.0)
						_gummy_pump_phase += delta * 15.0
					var pump := sin(_gummy_pump_phase)
					_vm_gummy.position = _vm_gummy.position.lerp(Vector3(0.0, pump * 0.085, -0.012 * cos(_gummy_pump_phase)), 1.0 - exp(-22.0 * delta))
					_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3(pump * 0.24, 0.0, 0.0), 1.0 - exp(-22.0 * delta))
				else:
					_vm_gummy.position = _vm_gummy.position.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
					_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
		var t_ease := ease(_locker_transition_t, 0.26)
		var base_yaw := atan2(-_locker_fwd.x, -_locker_fwd.z)
		player_body.global_position = _locker_eye - Vector3(0.0, _hiding_eye_local_y, 0.0)
		if _locker_transition_t < 1.0 and _hiding_kind != "under_desk":
			var turn_p := ease(clampf((_locker_transition_t - 0.26) / 0.58, 0.0, 1.0), -2.0)
			player_body.rotation.y = lerp_angle(_locker_enter_from_yaw, base_yaw + _hide_yaw_offset, turn_p)
		else:
			player_body.rotation.y = lerp_angle(player_body.rotation.y, base_yaw + _hide_yaw_offset, clampf(1.0 - exp(-14.0 * delta) + t_ease * 0.25, 0.0, 1.0))
		_yaw = player_body.rotation.y
		_target_yaw = _yaw
		cam.rotation.x = lerpf(cam.rotation.x, _hide_pitch_offset, 1.0 - exp(-16.0 * delta))
		var crawl_roll := sin(_locker_transition_t * PI) * (0.07 if _hiding_kind == "under_desk" else 0.03) if _locker_transition_t < 1.0 else 0.0
		cam.rotation.z = lerpf(cam.rotation.z, crawl_roll, 1.0 - exp(-12.0 * delta))
		var tgt_eye := _locker_eye
		var max_mask := 0.20 if _hiding_kind == "under_desk" else 0.36
		if _locker_transition_t < 1.0:
			if _hiding_kind == "under_desk":
				var t_xz := ease(_locker_transition_t, 0.32)
				var t_y := ease(_locker_transition_t, 0.55)
				cam.global_position = Vector3(
					lerpf(_locker_cam_from.x, tgt_eye.x, t_xz),
					lerpf(_locker_cam_from.y, tgt_eye.y, t_y),
					lerpf(_locker_cam_from.z, tgt_eye.z, t_xz)
				)
			else:
				var move_p := clampf((_locker_transition_t - 0.14) / 0.72, 0.0, 1.0)
				cam.global_position = _locker_cam_from.lerp(tgt_eye, ease(move_p, 0.28))
			lock_mask.color = Color(0.0, 0.0, 0.0, lerpf(0.0, max_mask, t_ease))
			lock_mask.visible = (lock_mask.color.a > 0.004)
		else:
			cam.global_position = tgt_eye
			lock_mask.color = Color(0.0, 0.0, 0.0, max_mask)
			lock_mask.visible = (max_mask > 0.004)
	else:
		if _locker_transition_t < 1.0 and not _locker_transition_entering:
			var exit_turn_p := ease(clampf(_locker_transition_t, 0.0, 1.0), -1.8)
			_yaw = lerp_angle(_locker_exit_from_yaw, _locker_exit_to_yaw, exit_turn_p)
			_target_yaw = _locker_exit_to_yaw
		_apply_camera_rotation()
		var fl_lag_x := clampf((_target_pitch - _pitch) * 0.45, -0.14, 0.14)
		var fl_lag_y := clampf((_target_yaw - _yaw) * 0.45, -0.18, 0.18)
		flashlight.rotation.x = lerpf(flashlight.rotation.x, fl_lag_x, 1.0 - exp(-14.0 * delta))
		flashlight.rotation.y = lerpf(flashlight.rotation.y, fl_lag_y, 1.0 - exp(-14.0 * delta))

		if _door_hand_timer > 0.0:
			_door_hand_timer = maxf(_door_hand_timer - delta, 0.0)

		if _anim_hand != null:
			if _locker_transition_t < 0.96 and not _locker_transition_entering:
				_anim_hand.visible = true
				var p_out := _locker_transition_t
				if _locker_exit_face_locker:
					# Fast 0.7s S exit animation: push door wide while twisting back toward locker
					var s_p := sin(p_out * PI)
					_anim_hand.position = Vector3(0.04, -0.12, -0.16).lerp(Vector3(0.32, -0.26, 0.02), p_out) + Vector3(-0.14 * s_p, 0.04 * s_p, -0.06 * s_p)
					_anim_hand.rotation = Vector3(0.06, 0.36 * s_p - 0.20 * p_out, -0.14 * s_p)
				else:
					# Full 1.0s W exit animation: reach door latch -> swing open -> step out & lower hand
					if p_out < 0.32:
						var r_p := ease(p_out / 0.32, 0.35)
						_anim_hand.position = Vector3(0.30, -0.24, -0.02).lerp(Vector3(0.04, -0.09, -0.18), r_p)
						_anim_hand.rotation = Vector3(0.06 * r_p, 0.16 * r_p, -0.14 * r_p)
					elif p_out < 0.68:
						var o_p := (p_out - 0.32) / 0.36
						_anim_hand.position = Vector3(0.04, -0.09, -0.18).lerp(Vector3(-0.20, -0.10, -0.10), sin(o_p * PI * 0.5))
						_anim_hand.rotation = Vector3(0.0, 0.42 * o_p, -0.10)
					else:
						var d_p := (p_out - 0.68) / 0.32
						_anim_hand.position = Vector3(-0.20, -0.10, -0.10).lerp(Vector3(0.30, -0.28, 0.04), d_p)
						_anim_hand.rotation = Vector3(-0.10 * d_p, -0.16 * d_p, 0.0)
			elif _door_hand_timer > 0.0:
				# Snappy 0.25s hand animation pushing room door forward & right (wider & harder if sprinting/stamina)
				_anim_hand.visible = true
				var pd := 1.0 - clampf(_door_hand_timer / 0.25, 0.0, 1.0)
				var reach_mul := 1.32 if _door_hand_slam else 1.0
				if pd < 0.45:
					var rp_d := ease(pd / 0.45, 0.4)
					_anim_hand.position = Vector3(0.32, -0.28, 0.02).lerp(Vector3(-0.04, -0.12, -0.24 * reach_mul), rp_d)
					_anim_hand.rotation = Vector3(0.06 * rp_d, 0.24 * rp_d * reach_mul, -0.14 * rp_d)
				else:
					var sp_d := (pd - 0.45) / 0.55
					var push_arc := sin(sp_d * PI * 0.5)
					_anim_hand.position = Vector3(-0.04, -0.12, -0.24 * reach_mul).lerp(Vector3(0.34, -0.30, 0.02), sp_d) + Vector3(0.18 * push_arc * reach_mul, 0.03 * push_arc, -0.08 * push_arc)
					_anim_hand.rotation = Vector3(0.04, lerpf(0.24 * reach_mul, -0.45 * reach_mul, sp_d), -0.12 * (1.0 - sp_d))
			else:
				_anim_hand.visible = false

		if _vm_holder != null:
			_vm_holder.visible = true
			_vm_std.visible = (_active_tool == 0)
			_vm_gummy.visible = (_active_tool == 1)
			var hspd_vm := Vector2(player_body.velocity.x, player_body.velocity.z).length()
			var t_sec_vm := float(Time.get_ticks_msec()) * 0.001
			var bob_amp := clampf(hspd_vm / 5.5, 0.0, 1.0)
			var bx := cos(t_sec_vm * 7.2) * 0.011 * bob_amp + sin(t_sec_vm * 1.4) * 0.0025
			var by := absf(sin(t_sec_vm * 7.2)) * -0.014 * bob_amp + cos(t_sec_vm * 1.8) * 0.0025
			var dip_y := -0.11 if _door_hand_timer > 0.0 else 0.0
			_vm_holder.position = _vm_holder.position.lerp(Vector3(0.24 + bx, -0.21 + by + dip_y, -0.34), 1.0 - exp(-14.0 * delta))
			_vm_holder.rotation.x = lerpf(_vm_holder.rotation.x, fl_lag_x * 0.75, 1.0 - exp(-14.0 * delta))
			_vm_holder.rotation.y = lerpf(_vm_holder.rotation.y, fl_lag_y * 0.75, 1.0 - exp(-14.0 * delta))
			if _vm_shake_time > 0.0 or shaking_gummy:
				if not shaking_gummy:
					_vm_shake_time = maxf(_vm_shake_time - delta, 0.0)
					_gummy_pump_phase += delta * 15.0
				var pump := sin(_gummy_pump_phase)
				_vm_gummy.position = _vm_gummy.position.lerp(Vector3(0.0, pump * 0.085, -0.012 * cos(_gummy_pump_phase)), 1.0 - exp(-22.0 * delta))
				_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3(pump * 0.24, 0.0, 0.0), 1.0 - exp(-22.0 * delta))
			else:
				_vm_gummy.position = _vm_gummy.position.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))
				_vm_gummy.rotation = _vm_gummy.rotation.lerp(Vector3.ZERO, 1.0 - exp(-16.0 * delta))

		if _locker_transition_t < 1.0:
			var t_out := ease(_locker_transition_t, 0.26)
			var tgt_pos := player_body.global_position + Vector3(0.0, 1.48, 0.0)
			cam.global_position = _locker_cam_from.lerp(tgt_pos, t_out)
			cam.rotation.z = lerpf(cam.rotation.z, sin(_locker_transition_t * PI) * (-0.05 if _locker_exit_face_locker else 0.03), 1.0 - exp(-14.0 * delta))
			lock_mask.color = Color(0.0, 0.0, 0.0, lerpf(0.32, 0.0, t_out))
			lock_mask.visible = (lock_mask.color.a > 0.004)
		else:
			lock_mask.color = Color(0.0, 0.0, 0.0, 0.0)
			lock_mask.visible = false


func _process_architect_and_scare(delta: float) -> void:
	if _a90_scare_timer > 0.0:
		_a90_scare_timer -= delta
		var scare_rect: TextureRect = _ui["a90_scare_rect"]
		scare_rect.modulate.a = clampf(_a90_scare_timer / 0.45, 0.0, 1.0)
		if _a90_scare_timer <= 0.0:
			scare_rect.visible = false

	_death_phase_t += delta
	var iris := _ui.get("death_iris") as Control
	var imat := _ui.get("death_iris_mat") as ShaderMaterial
	if _death_phase == 0:
		# Phase 0: Red death flash (0.48s)
		if imat != null:
			imat.set_shader_parameter("red_amt", lerpf(0.92, 0.78, clampf(_death_phase_t / 0.48, 0.0, 1.0)))
			imat.set_shader_parameter("shrink_amt", 0.0)
		if _death_phase_t >= 0.48:
			_death_phase = 1
			_death_phase_t = 0.0
		return
	elif _death_phase == 1:
		# Phase 1: Screen compresses & fades inward to center into darkness (0.80s)
		var sp := clampf(_death_phase_t / 0.80, 0.0, 1.0)
		if imat != null:
			imat.set_shader_parameter("shrink_amt", sp)
			imat.set_shader_parameter("red_amt", lerpf(0.78, 0.0, ease(sp, 0.55)))
		if sp >= 1.0:
			_death_phase = 2
			_death_phase_t = 0.0
			audio.play_architect_appear()
			var arch_overlay: Control = _ui["architect_overlay"]
			arch_overlay.visible = true
			arch_overlay.modulate.a = 0.0
			var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(arch_overlay, "modulate:a", 1.0, 0.75)
		return

	if iris != null and _ui.has("architect_overlay"):
		iris.visible = (_ui["architect_overlay"] as Control).modulate.a < 0.99

	if _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
		_arch_glitch_timer += delta
		if _arch_glitch_timer >= 0.045:
			_arch_glitch_timer = 0.0
			_arch_glitch_step += 1
			if _arch_glitch_step < 12:
				var frame_txt := RoomsArchitect.generate_glitch_frame(_arch_prev_text, cur_line, _arch_glitch_step, 12)
				(_ui["arch_speech"] as Label).text = frame_txt
				var shade := Color(0.88, 0.89, 0.92) if _arch_glitch_step % 2 == 0 else Color(0.52, 0.56, 0.62)
				(_ui["arch_speech"] as Label).add_theme_color_override("font_color", shade)
				audio.play_architect_blip(_rng.randf_range(0.92, 1.10))
			else:
				var reveal := ""
				for i in range(_arch_line_idx + 1):
					if i > 0:
						reveal += "\n"
					reveal += "> " + String(_arch_lines[i])
				(_ui["arch_speech"] as Label).text = reveal
				(_ui["arch_speech"] as Label).add_theme_color_override("font_color", Color(0.88, 0.89, 0.92))
				_arch_prev_text = cur_line
				_arch_char_pos = float(cur_line.length())
				_arch_auto_advance_timer = 0.0
				_refresh_architect_controls()
	elif _arch_glitch_step >= 12:
		_arch_auto_advance_timer += delta
		if _arch_line_idx + 1 < _arch_lines.size() and _arch_auto_advance_timer >= 0.45:
			_advance_architect_dialogue()
