class_name RoomsGame
extends Node3D

## Slim top-level game coordinator for r00ms.
## Delegates rooms, player, interaction, entities, avatars, settings, admin, and UI
## to dedicated modular child component nodes under $Systems.

enum State { PLAYING, PAUSED, DEAD, VICTORY, SPECTATING, MENU }

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var rooms_container: Node3D = $RoomsContainer
@onready var player_body: CharacterBody3D = $PlayerBody
@onready var player_col: CollisionShape3D = $PlayerBody/CollisionShape3D
@onready var cam: Camera3D = $PlayerBody/Camera3D
@onready var flashlight: SpotLight3D = $PlayerBody/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $PlayerBody/Camera3D/InteractRay
@onready var audio: RoomsAudio = $RoomsAudio
@onready var ui_layer: CanvasLayer = $UILayer

@onready var settings_mgr: SettingsManager = $Systems/SettingsManager
@onready var admin_ctrl: AdminController = $Systems/AdminController
@onready var room_mgr: RoomManager = $Systems/RoomManager
@onready var avatar_mgr: AvatarManager = $Systems/AvatarManager
@onready var player_ctrl: PlayerController = $Systems/PlayerController
@onready var interact_ctrl: InteractionController = $Systems/InteractionController
@onready var entity_dir: EntityDirector = $Systems/EntityDirector
@onready var ui_mgr: UIManager = $Systems/UIManager
@onready var net: RoomsNet = $RoomsNet

var assets: RoomAssets = null
var rng := RandomNumberGenerator.new()
var architect := RoomsArchitect.new()

var state: State = State.MENU
var hp := 100
var run_time := 0.0
var victory_reached := false
var checkpoint_room := 0
var haste_timer := 60.0

var active_modifiers: Dictionary = {
	"admin_panel": false,
	"wet_floor": false,
	"bad_time": false,
	"make_haste": false,
	"lights_out": false,
	"sprint_fatigue": false,
}
var run_used_admin := false

# Death / Architect / Spectator state
var revives_left := 1
var _death_cause := ""
var _death_phase := 0
var _death_phase_t := 0.0
var _arch_lines: Array[String] = []
var _arch_line_idx := 0
var _arch_glitch_step := -1
var _arch_glitch_timer := 0.0
var _arch_prev_text := "hello"
var _arch_auto_advance_timer := 0.0
var _spectate_key := ""
var _spectate_yaw := 0.0
var _spectate_pitch := 0.28
var _spectate_last_hiding := false
var _spectate_user_orbited := false

# Mobile touch tracking
var _joy_touch_id := -1
var _look_touch_id := -1
var _tap_touch_id := -1
var _tap_start_pos := Vector2.ZERO
var _tap_start_time_ms := 0
var _joy_origin := Vector2.ZERO


func _ready() -> void:
	assets = RoomAssets.create_shared()
	settings_mgr.load_settings()
	settings_mgr.apply_audio_settings(audio, false)
	settings_mgr.setup_environment(world_env, flashlight)

	room_mgr.initialize(rooms_container, assets)
	player_ctrl.initialize(self, player_body, player_col, cam, flashlight, audio, assets, settings_mgr, admin_ctrl, room_mgr, avatar_mgr, net)
	avatar_mgr.initialize(self, assets, room_mgr, player_ctrl.vm_bulb_on_mat, player_ctrl.vm_gummy_on_mat)
	entity_dir.initialize(self, self, cam, player_body, player_ctrl, room_mgr, avatar_mgr, ui_mgr, audio, net, settings_mgr, rng)
	interact_ctrl.initialize(self, cam, player_body, interact_ray, player_ctrl, room_mgr, avatar_mgr, entity_dir, ui_mgr, audio)
	ui_mgr.initialize(self, ui_layer, settings_mgr, admin_ctrl, room_mgr, player_ctrl, interact_ctrl, entity_dir, avatar_mgr, audio, net)

	_connect_net_signals()
	ui_mgr.sync_settings_ui()
	settings_mgr.apply_render_quality(settings_mgr.render_quality, world_env, flashlight, cam, false)
	var fx_on := settings_mgr.render_quality != SettingsManager.RenderQuality.MOBILE_OPT
	player_ctrl.set_dust_enabled(fx_on)
	ui_mgr.set_cinema_fx_enabled(fx_on)
	ui_mgr.refresh_render_buttons()
	refresh_mobile_mode()

	reset_run(-1)
	set_state(State.MENU)
	ui_mgr.show_main_menu(true)


func is_playing_active() -> bool:
	return state == State.PLAYING and not player_ctrl.is_hiding


func _connect_net_signals() -> void:
	net.status_changed.connect(func(txt: String) -> void:
		var lbl := ui_mgr.get_node_ref("net_status") as Label
		if lbl != null:
			lbl.text = txt
	)
	net.state_received.connect(avatar_mgr.on_remote_state)
	net.face_received.connect(avatar_mgr.on_remote_face)
	net.door_opened_remote.connect(_on_remote_door_opened)
	net.locker_action_received.connect(avatar_mgr.on_remote_locker_action)
	net.entity_event_received.connect(_on_remote_entity_event)
	net.peer_disconnected.connect(avatar_mgr.on_remote_peer_disconnected)
	net.invite_received.connect(func(inviter_name: String, _lid: int) -> void:
		ui_mgr.show_toast(RoomsI18n.t("toast_steam_invite", [inviter_name]), 4.0)
	)
	net.session_synced.connect(_on_net_session_synced)
	net.chat_received.connect(ui_mgr.chat_append)
	net.lan_servers_updated.connect(ui_mgr.update_lan_servers_list)
	net.members_changed.connect(func() -> void:
		ui_mgr.update_menu_players_list()
		if net.is_online() and net.is_host:
			net.broadcast_entity_event({"k": "mods_update", "mods": active_modifiers}, true)
		elif net.is_online() and not net.is_host:
			if state == State.MENU:
				active_modifiers["admin_panel"] = false
				admin_ctrl.reset_all(player_col, true)
				ui_mgr.update_menu_modifiers_ui()
				ui_mgr.update_admin_buttons_ui()
				ui_mgr.set_menu_view("multi")
	)


func reset_run(forced_seed: int = -1, start_room: int = -1) -> void:
	admin_ctrl.reset_all(player_col, false)
	if net != null and net.is_online() and not net.is_host and not bool(active_modifiers.get("admin_panel", false)):
		admin_ctrl.revoke_host_grant()
	run_used_admin = bool(active_modifiers.get("admin_panel", false)) or admin_ctrl.is_active(active_modifiers, net)
	ui_mgr.update_admin_buttons_ui()

	var actual_start: int = start_room if start_room >= 0 else settings_mgr.selected_start_room
	if actual_start < 0 or (actual_start % 50 != 0):
		actual_start = 0

	var haste_on := bool(active_modifiers.get("make_haste", false))
	var lights_out_on := bool(active_modifiers.get("lights_out", false))
	room_mgr.reset_world(forced_seed, settings_mgr.render_quality, lights_out_on, haste_on, settings_mgr.room_vis_radius, actual_start)
	rng.seed = room_mgr.world_seed

	hp = 100
	revives_left = 1
	run_time = 0.0
	victory_reached = false
	checkpoint_room = actual_start
	haste_timer = 60.0
	_death_phase = 0
	_death_phase_t = 0.0
	_spectate_key = ""
	_spectate_yaw = 0.0
	_spectate_pitch = 0.25
	_spectate_last_hiding = false
	_spectate_user_orbited = false

	player_ctrl.reset_for_run(actual_start)
	entity_dir.reset_for_run()
	audio.low_hp_mode = false

	player_body.position = Vector3(0.0, 0.05, 4.0)
	player_body.velocity = Vector3.ZERO
	player_ctrl.yaw = 0.0
	player_ctrl.pitch = 0.0
	player_ctrl.target_yaw = 0.0
	player_ctrl.target_pitch = 0.0
	player_ctrl.apply_camera_rotation()

	ui_mgr.reticle_lag_offset = Vector2.ZERO
	ui_mgr.reticle_screen_pos = Vector2.ZERO
	ui_mgr.clear_all_vignettes()
	var arch_ov := ui_mgr.get_node_ref("architect_overlay")
	if arch_ov != null:
		arch_ov.visible = false
	var iris := ui_mgr.get_node_ref("death_iris")
	if iris != null:
		iris.visible = false
	var sb := ui_mgr.get_node_ref("spectate_bar")
	if sb != null:
		sb.visible = false
	_reset_touch_state()

	net.update_lobby_progress(room_mgr.world_seed, actual_start, actual_start)
	if net.is_online() and net.is_host and forced_seed <= 0:
		net.broadcast_session_sync(room_mgr.world_seed, actual_start, actual_start)
		net.broadcast_entity_event({"k": "mods_update", "mods": active_modifiers}, true)

	set_state(State.PLAYING)


func set_state(new_state: int) -> void:
	state = new_state as State
	var hud_on := (state == State.PLAYING or state == State.PAUSED or state == State.VICTORY)
	var hg := ui_mgr.get_node_ref("hud_group")
	if hg != null:
		hg.visible = hud_on

	var chat_box := ui_mgr.get_node_ref("chat_box")
	if chat_box != null:
		var chat_online := net.is_online() and state != State.MENU
		chat_box.visible = chat_online
		if not chat_online and ui_mgr.chat_open:
			ui_mgr.chat_toggle(false)
		ui_mgr.chat_set_readonly(state == State.DEAD or state == State.SPECTATING)

	var mm := ui_mgr.get_node_ref("main_menu")
	if mm != null:
		mm.visible = (state == State.MENU) and (ui_mgr.face_editor == null or not ui_mgr.face_editor.visible)
	var sb := ui_mgr.get_node_ref("spectate_bar")
	if sb != null:
		sb.visible = (state == State.SPECTATING)
	var mg := ui_mgr.get_node_ref("mobile_group")
	if mg != null:
		mg.visible = settings_mgr.mobile_controls_enabled and (state == State.PLAYING)

	if state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if settings_mgr.mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED
		ui_mgr.get_node_ref("modal").visible = false
		ui_mgr.get_node_ref("architect_overlay").visible = false
		ui_mgr.get_node_ref("death_iris").visible = false
		player_ctrl.set_spectating(false)
		if flashlight != null:
			flashlight.visible = player_ctrl.light_on
	elif state == State.SPECTATING:
		_reset_touch_state()
		ui_mgr.clear_all_vignettes()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui_mgr.get_node_ref("modal").visible = false
		ui_mgr.get_node_ref("architect_overlay").visible = false
		ui_mgr.get_node_ref("death_iris").visible = false
		player_ctrl.set_spectating(true)
		if flashlight != null:
			flashlight.visible = false
	elif state == State.DEAD:
		player_ctrl.set_spectating(true)
		if flashlight != null:
			flashlight.visible = false
	elif state == State.MENU:
		_reset_touch_state()
		ui_mgr.clear_all_vignettes()
		admin_ctrl.reset_all(player_col, true)
		run_used_admin = false
		ui_mgr.update_admin_buttons_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui_mgr.get_node_ref("modal").visible = false
		ui_mgr.get_node_ref("architect_overlay").visible = false
		ui_mgr.get_node_ref("death_iris").visible = false
		player_ctrl.set_spectating(true)
		if flashlight != null:
			flashlight.visible = false
		if player_ctrl.cover_hand != null:
			player_ctrl.cover_hand.visible = false
		player_body.velocity = Vector3.ZERO
		ui_mgr.show_main_menu(false)
	else:
		_reset_touch_state()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var modal := ui_mgr.get_node_ref("modal")
		modal.visible = (state == State.PAUSED or state == State.VICTORY)
		if modal.visible:
			modal.modulate.a = 0.0
			create_tween().tween_property(modal, "modulate:a", 1.0, 0.16)
		var title := ui_mgr.get_node_ref("m_title") as Label
		var desc := ui_mgr.get_node_ref("m_desc") as Label
		if state == State.PAUSED:
			ui_mgr.open_settings_panel(false)
			ui_mgr.open_admin_panel(false)
			ui_mgr.update_pause_modifiers_ui()
			title.visible = false
			desc.visible = false
		elif state == State.VICTORY:
			ui_mgr.open_settings_panel(false)
			title.visible = true
			desc.visible = true
			title.text = "A-300"
			var mins := int(run_time) / 60
			var secs := int(run_time) % 60
			desc.text = RoomsI18n.t("victory_desc", [mins, secs])


func exit_to_main_menu() -> void:
	reset_run(-1, settings_mgr.selected_start_room)
	set_state(State.MENU)


func set_selected_checkpoint(room_num: int) -> void:
	if room_num % 50 != 0:
		return
	settings_mgr.selected_start_room = room_num
	checkpoint_room = room_num
	settings_mgr.save_settings()
	if state == State.MENU:
		reset_run(-1, room_num)


func can_use_admin() -> bool:
	return admin_ctrl.can_use_admin(active_modifiers, net)


func toggle_modifier(m_key: String, _m_name: String) -> void:
	if state != State.MENU:
		ui_mgr.show_toast(RoomsI18n.t("toast_mods_menu_only"), 2.0)
		return
	if net.is_online() and not net.is_host:
		ui_mgr.show_toast(RoomsI18n.t("toast_mods_host_only"), 2.0)
		return
	var cur_v := bool(active_modifiers.get(m_key, false))
	active_modifiers[m_key] = not cur_v
	ui_mgr.update_menu_modifiers_ui()
	if m_key == "admin_panel" and cur_v:
		admin_ctrl.reset_all(player_col)
		ui_mgr.update_admin_buttons_ui()
	if net.is_online() and net.is_host:
		net.broadcast_entity_event({"k": "mods_update", "mods": active_modifiers})
	ui_mgr.show_toast("%s: %s" % [RoomsI18n.t("mod_" + m_key), RoomsI18n.t("enabled" if not cur_v else "disabled")], 1.8)


func menu_steam_invite() -> void:
	var mstatus := ui_mgr.get_node_ref("menu_status") as Label
	if mstatus != null:
		mstatus.text = "..."
	var res: Dictionary = await net.ensure_steam_lobby(room_mgr.world_seed, room_mgr.highest_opened)
	if not bool(res.get("ok", false)):
		if mstatus != null:
			mstatus.text = String(res.get("msg", "Error"))
		return
	net.open_invite_overlay_now()
	if mstatus != null:
		mstatus.text = net.get_summary_status()
	ui_mgr.show_toast(RoomsI18n.t("toast_lobby_ready"), 4.0)


func menu_start_multiplayer() -> void:
	if net.is_online():
		if not net.is_host:
			ui_mgr.show_toast(RoomsI18n.t("toast_host_start_only"), 2.0)
			return
		var start_r := settings_mgr.selected_start_room
		if room_mgr.highest_opened != start_r:
			reset_run(-1, start_r)
		net.broadcast_entity_event({
			"k": "start_game",
			"seed": room_mgr.world_seed,
			"start_room": start_r,
			"mods": active_modifiers,
		}, true)
	menu_begin_game(true, "")


func menu_begin_game(is_multi: bool = false, mode: String = "") -> void:
	if not bool(active_modifiers.get("admin_panel", false)):
		admin_ctrl.reset_all(player_col)
		ui_mgr.update_admin_buttons_ui()
	if is_multi and mode == "lan":
		net.host_enet(room_mgr.world_seed)
	if bool(active_modifiers.get("make_haste", false)):
		haste_timer = 60.0
	if bool(active_modifiers.get("lights_out", false)):
		room_mgr.trigger_power_outage(audio)
	var menu := ui_mgr.get_node_ref("main_menu")
	if menu == null or not menu.visible:
		set_state(State.PLAYING)
		return
	var tw := create_tween()
	tw.tween_property(menu, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		menu.visible = false
		menu.modulate.a = 1.0
		set_state(State.PLAYING)
	)


func open_room_door(r_idx: int, slam: bool = false, from_remote: bool = false) -> void:
	var r: RoomScene = room_mgr.room_by_idx.get(r_idx) as RoomScene
	if r == null or r.door_opened:
		return
	if r_idx == 19 and not r.door_broken:
		if not from_remote:
			audio.play_flashlight_click()
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.04)
			if entity_dir.is_authority() and not entity_dir.a60_active and not entity_dir.a120_active:
				entity_dir.spawn_a60(false)
		return

	var is_slam := slam
	if not from_remote and not is_slam:
		var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
		is_slam = player_ctrl.is_sprinting or hspd > 4.4
	r.door_opened = true
	r.disable_door_collision()
	room_mgr.opening_doors.append({"pivot": r.door_pivot, "progress": 0.0, "slam": is_slam})
	if not from_remote and not player_ctrl.is_hiding:
		player_ctrl.door_hand_timer = 0.25
		player_ctrl.door_hand_slam = is_slam
		if is_slam:
			player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.016)
		player_ctrl.begin_door_teleport(r)
	audio.play_door_open()
	if not from_remote and net.is_online():
		net.broadcast_door_opened(r_idx, is_slam)
	advance_door_progress(r_idx, not from_remote)


func advance_door_progress(r_idx: int, allow_spawn: bool) -> void:
	var opened_num := r_idx + 1
	if opened_num > room_mgr.highest_opened:
		room_mgr.highest_opened = opened_num
		room_mgr.current_room_idx = opened_num
		net.update_lobby_progress(room_mgr.world_seed, opened_num)
		if opened_num >= 50 and not room_mgr.power_out and not room_mgr.door50_flicker_active:
			room_mgr.door50_flicker_active = true
			room_mgr.door50_flicker_t = 3.0
		if bool(active_modifiers.get("make_haste", false)):
			haste_timer = maxf(haste_timer, 60.0)
		room_mgr.ensure_ahead_rooms(settings_mgr.render_quality, bool(active_modifiers.get("make_haste", false)), settings_mgr.room_vis_radius)

		if opened_num == 19:
			entity_dir.a60_door20_trigger_timer = 5.0
		if opened_num % 50 == 0:
			checkpoint_room = opened_num
			var used_adm := run_used_admin or admin_ctrl.cheats_used or bool(active_modifiers.get("admin_panel", false)) or admin_ctrl.is_active(active_modifiers, net)
			if not used_adm:
				settings_mgr.unlock_checkpoint(opened_num)
				ui_mgr.update_checkpoint_ui()
			audio.play_architect_blip()
		if opened_num >= 300 and not victory_reached:
			victory_reached = true
			set_state(State.VICTORY)
			return

		if allow_spawn:
			entity_dir.maybe_spawn_door_entities(opened_num)


func add_haste_lever_time() -> float:
	var bonus := 15.0
	if haste_timer <= 20.0:
		bonus = 90.0
	elif haste_timer <= 40.0:
		bonus = 60.0
	elif haste_timer <= 50.0:
		bonus = 30.0
	haste_timer += bonus
	return bonus


func heal_player(amount: int) -> void:
	hp = mini(hp + amount, 100)
	audio.low_hp_mode = (hp <= 25 and hp > 0)


func damage_player(amount: int, cause: String, flash_col: Color, extra_ctx: Dictionary) -> void:
	if state != State.PLAYING:
		return
	if admin_ctrl.god_mode and admin_ctrl.is_active(active_modifiers, net):
		hp = 100
		ui_mgr.show_toast(RoomsI18n.t("toast_god_dmg", [cause]), 2.0)
		return
	hp -= amount
	audio.low_hp_mode = (hp <= 25 and hp > 0)
	player_ctrl.trigger_damage_kick(0.14)
	ui_mgr.flash_damage(flash_col)
	if hp <= 0:
		trigger_death(cause, "", extra_ctx)


func handle_a120_damage_and_warp(rebounded: bool) -> bool:
	if admin_ctrl.god_mode and admin_ctrl.is_active(active_modifiers, net):
		hp = 100
		return false
	hp -= 90
	audio.low_hp_mode = (hp <= 25 and hp > 0)
	if hp <= 0:
		trigger_death("A-120", "", {"a120_rebounded": rebounded})
		return false
	var warp_safe_min := checkpoint_room + 4
	var back_steps := rng.randi_range(3, 4)
	var target_idx := room_mgr.current_room_idx - back_steps
	if room_mgr.current_room_idx >= warp_safe_min and target_idx > checkpoint_room and room_mgr.room_by_idx.has(target_idx):
		var target_r: RoomScene = room_mgr.room_by_idx[target_idx] as RoomScene
		player_ctrl.force_leave_hiding_for_warp(entity_dir, ui_mgr)
		player_body.position = target_r.center_pos + Vector3(0.0, 0.05, 0.0)
		player_body.velocity = Vector3.ZERO
		room_mgr.current_room_idx = target_idx
		room_mgr.update_room_visibility(settings_mgr.room_vis_radius)
		var face_yaw := atan2(-target_r.out_dir.x, -target_r.out_dir.z)
		player_ctrl.target_yaw = face_yaw
		player_ctrl.yaw = face_yaw
		player_ctrl.target_pitch = 0.0
		player_ctrl.pitch = 0.0
		player_ctrl.apply_camera_rotation()
		player_ctrl.fov = 104.0
		cam.fov = 104.0
		ui_mgr.flash_damage(Color(0.85, 0.96, 1.0, 0.78))
		return true
	ui_mgr.flash_damage(Color(0.85, 0.08, 0.08, 0.65))
	return false


func can_revive() -> bool:
	return can_use_admin() or revives_left > 0


func try_revive_player() -> void:
	if not can_revive():
		ui_mgr.show_toast(RoomsI18n.t("toast_revive_none"), 2.0)
		return
	if not can_use_admin():
		revives_left = maxi(revives_left - 1, 0)
	else:
		run_used_admin = true
		admin_ctrl.cheats_used = true

	# Architect says "попробую..."
	var arch_speech := ui_mgr.get_node_ref("arch_speech") as Label
	if arch_speech != null and is_instance_valid(arch_speech):
		arch_speech.text = RoomsI18n.t("arch_trying")
		arch_speech.visible = true
	audio.play_architect_blip(0.74)

	var big := ui_mgr.get_node_ref("arch_window_big") as Control
	if big != null:
		big.visible = false
	var arch_restart := ui_mgr.get_node_ref("arch_restart") as Control
	if arch_restart != null:
		arch_restart.visible = false

	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(func() -> void:
		_execute_revive()
	)


func _execute_revive() -> void:
	hp = 100
	audio.low_hp_mode = false
	player_ctrl.is_hiding = false
	player_ctrl.hiding_door_lifted = false
	player_ctrl.a085_grab_locked = false
	_death_phase_t = 0.0
	_death_phase = 0

	if player_col != null:
		player_col.disabled = false
	if player_ctrl.vm_holder != null:
		player_ctrl.vm_holder.visible = true
	if flashlight != null:
		flashlight.visible = player_ctrl.light_on

	ui_mgr.clear_all_vignettes()
	var arch_ov := ui_mgr.get_node_ref("architect_overlay")
	if arch_ov != null:
		arch_ov.visible = false
	var iris := ui_mgr.get_node_ref("death_iris")
	if iris != null:
		iris.visible = false
	var modal := ui_mgr.get_node_ref("modal")
	if modal != null:
		modal.visible = false

	set_state(State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if settings_mgr.mobile_controls_enabled else Input.MOUSE_MODE_CAPTURED

	# Jumping heartbeat camera adrenaline animation!
	player_ctrl.trigger_revive_heartbeat()

	# Sync over network
	_sync_net_local_state()
	if net != null and net.is_online():
		net.broadcast_entity_event({"k": "player_revived", "peer": net.local_peer_key}, true)

	ui_mgr.show_toast(RoomsI18n.t("toast_revived"), 2.0)


func admin_revive_self(from_host_event: bool = false) -> void:
	if not from_host_event and not can_use_admin():
		return
	try_revive_player()


func admin_skip_rooms(count: int) -> void:
	if not can_use_admin():
		return
	run_used_admin = true
	admin_ctrl.cheats_used = true
	for _i in range(count):
		var target_r := room_mgr.find_first_closed_door_room()
		if target_r != null:
			open_room_door(target_r.index, true, false)
	var next_r := room_mgr.find_first_closed_door_room()
	if next_r != null and is_instance_valid(next_r):
		player_body.global_position = next_r.center_pos + Vector3(0.0, 0.2, 0.0)
	ui_mgr.show_toast(RoomsI18n.t("toast_skipped", [count]), 2.0)
	ui_mgr.open_admin_panel(false)
	set_state(State.PLAYING)


func trigger_death(cause: String, _tip: String = "", extra_ctx: Dictionary = {}) -> void:
	if state != State.PLAYING:
		return
	if admin_ctrl.god_mode and admin_ctrl.is_active(active_modifiers, net):
		hp = 100
		ui_mgr.show_toast(RoomsI18n.t("toast_god_death", [cause]), 2.5)
		return
	_death_cause = cause
	audio.play_death_sound()
	if cause != "A-120" and cause != "A-60" and cause != "A-60'" and cause != "A-075":
		audio.play_jumpscare()
	var keep_auth := entity_dir.is_authority() and net.is_online() and avatar_mgr.has_alive_remote_players()
	entity_dir.on_local_death(keep_auth)
	player_ctrl.door_hand_timer = 0.0
	player_ctrl.locker_transition_t = 1.0
	player_ctrl.rmb_held = false
	ui_mgr.clear_all_vignettes()
	ui_mgr.get_node_ref("modal").visible = false

	state = State.DEAD
	_death_phase = 0
	_death_phase_t = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui_mgr.get_node_ref("hud_group").visible = false
	net.voice_talking = false
	if ui_mgr.chat_open:
		ui_mgr.chat_toggle(false)

	var iris := ui_mgr.get_node_ref("death_iris")
	var imat := ui_mgr.ui.get("death_iris_mat") as ShaderMaterial
	if cause == "A-075":
		# Custom A-075 blinding flash-burn death sequence instead of standard red iris!
		if iris != null:
			iris.visible = false
		var a_rect := ui_mgr.get_node_ref("a075_flash_rect")
		var a_mat := ui_mgr.ui.get("a075_flash_mat") as ShaderMaterial
		if a_rect != null and a_mat != null:
			a_rect.visible = true
			a_mat.set_shader_parameter("flash_amt", 1.0)
			a_mat.set_shader_parameter("warn_amt", 0.0)
			a_mat.set_shader_parameter("blind_burn", 0.05)
	elif iris != null and imat != null:
		iris.visible = true
		imat.set_shader_parameter("red_amt", 0.92)
		imat.set_shader_parameter("shrink_amt", 0.0)

	var cur_room: RoomScene = room_mgr.room_by_idx.get(room_mgr.current_room_idx) as RoomScene
	var ctx := {
		"room_lockers_count": cur_room.lockers.size() if cur_room != null else 0,
		"battery": player_ctrl.std_battery if player_ctrl.active_tool == 0 else player_ctrl.gummy_battery,
		"has_gummy": player_ctrl.has_gummy,
	}
	for k in extra_ctx.keys():
		ctx[k] = extra_ctx[k]

	var u_name := get_local_username()
	var reported_room := 0 if admin_ctrl.cheats_used else room_mgr.highest_opened
	var seq := architect.build_death_sequence(cause, reported_room, u_name, ctx)
	_arch_lines.clear()
	for l in seq.get("lines", []):
		_arch_lines.append(String(l))
	if _arch_lines.is_empty():
		_arch_lines.append("Died cause of %s" % cause)
	_arch_line_idx = 0
	_arch_glitch_step = 0
	_arch_glitch_timer = 0.0
	_arch_prev_text = "hello"
	_arch_auto_advance_timer = 0.0

	var stats_lbl := ui_mgr.get_node_ref("arch_stats_lbl") as Label
	if stats_lbl != null:
		var r_disp := RoomsI18n.t("arch_admin_void", [room_mgr.highest_opened]) if admin_ctrl.cheats_used else ("A-%03d" % room_mgr.highest_opened)
		stats_lbl.text = RoomsI18n.t("arch_report", [
			cause, r_disp, int(seq["deaths_total"]), architect.best_room, String(seq["summary"])
		])
	var ascii_lbl := ui_mgr.get_node_ref("arch_ascii") as RichTextLabel
	if ascii_lbl != null:
		ascii_lbl.visible = false
	var sp := ui_mgr.get_node_ref("arch_speech") as Label
	sp.text = ""
	sp.add_theme_color_override("font_color", Color.WHITE)
	sp.visible = true
	(ui_mgr.get_node_ref("arch_meta") as Label).text = RoomsI18n.t("arch_meta", [cause, int(seq["deaths_total"]), architect.best_room])
	(ui_mgr.get_node_ref("arch_meta") as Control).visible = true
	(ui_mgr.get_node_ref("arch_page") as Label).text = RoomsI18n.t("arch_line", [1, maxi(_arch_lines.size(), 1)])
	(ui_mgr.get_node_ref("arch_page") as Control).visible = true
	ui_mgr.get_node_ref("arch_window_big").visible = false
	ui_mgr.get_node_ref("arch_restart_hint").visible = false
	var arch_ov := ui_mgr.get_node_ref("architect_overlay")
	arch_ov.visible = false
	arch_ov.modulate.a = 0.0


func get_local_username() -> String:
	if net != null and net.persona_name != "" and net.persona_name != "Player":
		return net.persona_name
	var env_u := OS.get_environment("USERNAME")
	return env_u if env_u != "" else "Player"


func advance_architect_dialogue() -> void:
	if state != State.DEAD:
		return
	if _death_phase == 3:
		if net.is_online() and not avatar_mgr.remote_players.is_empty():
			start_spectating()
		return
	if _death_phase < 2 or _arch_lines.is_empty():
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if _arch_glitch_step < 12:
		_arch_glitch_step = 12
		var sp := ui_mgr.get_node_ref("arch_speech") as Label
		sp.text = cur_line
		sp.add_theme_color_override("font_color", Color.WHITE)
		_arch_prev_text = cur_line
		_arch_auto_advance_timer = 0.0
		return
	if _arch_line_idx + 1 < _arch_lines.size():
		_arch_line_idx += 1
		_arch_glitch_step = 0
		_arch_glitch_timer = 0.0
		_arch_auto_advance_timer = 0.0
		(ui_mgr.get_node_ref("arch_page") as Label).text = RoomsI18n.t("arch_line", [_arch_line_idx + 1, _arch_lines.size()])
	else:
		_death_phase = 3
		for k in ["arch_speech", "arch_ascii", "arch_page", "arch_meta"]:
			ui_mgr.get_node_ref(k).visible = false
		var big := ui_mgr.get_node_ref("arch_window_big")
		big.visible = true
		big.modulate.a = 0.0
		big.pivot_offset = big.size * 0.5
		big.scale = Vector2(0.92, 0.92)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(big, "modulate:a", 1.0, 0.25)
		tw.tween_property(big, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ui_mgr.get_node_ref("arch_restart_hint").visible = true
		ui_mgr.get_node_ref("btn_stat_spectate").visible = (net.is_online() and not avatar_mgr.remote_players.is_empty())
		var btn_srev := ui_mgr.get_node_ref("btn_stat_revive") as Button
		if btn_srev != null:
			btn_srev.visible = can_revive()
			btn_srev.text = RoomsI18n.t("arch_btn_revive") + (" (∞)" if can_use_admin() else (" (%d)" % revives_left))


func start_spectating() -> void:
	set_state(State.SPECTATING)
	_spectate_pitch = 0.25
	cycle_spectate_target(0)


func cycle_spectate_target(step: int) -> void:
	var keys := avatar_mgr.remote_players.keys()
	if keys.is_empty():
		_spectate_key = ""
		(ui_mgr.get_node_ref("spectate_lbl") as Label).text = RoomsI18n.t("spec_none")
		return
	keys.sort()
	var alive_keys: Array = []
	for k in keys:
		if not bool((avatar_mgr.remote_players[k] as Dictionary).get("dead", false)):
			alive_keys.append(k)
	var pool: Array = alive_keys if not alive_keys.is_empty() else keys
	var cur_idx := pool.find(_spectate_key)
	if cur_idx < 0:
		cur_idx = 0
	elif step != 0:
		cur_idx = posmod(cur_idx + step, pool.size())
	_spectate_key = String(pool[cur_idx])
	var rp: Dictionary = avatar_mgr.remote_players.get(_spectate_key, {})
	_spectate_last_hiding = bool(rp.get("hiding", false))
	_spectate_user_orbited = false
	var rp_yaw := float(rp.get("tgt_yaw", 0.0))
	_spectate_yaw = wrapf(rp_yaw + PI * 0.88, -PI, PI) if _spectate_last_hiding else rp_yaw
	var tgt_node := rp.get("node") as Node3D
	if is_instance_valid(tgt_node):
		var pivot := tgt_node.global_position + Vector3(0.0, 1.48, 0.0)
		var back_dir := (Basis(Vector3.UP, _spectate_yaw) * Basis(Vector3.RIGHT, -_spectate_pitch) * Vector3(0.0, 0.0, 1.0)).normalized()
		cam.global_position = pivot + back_dir * 2.55
		cam.look_at(pivot, Vector3.UP)


func cycle_render_quality() -> void:
	var nxt := (settings_mgr.render_quality + 1) % 3
	settings_mgr.apply_render_quality(nxt, world_env, flashlight, cam, true)
	var fx_on := settings_mgr.render_quality != SettingsManager.RenderQuality.MOBILE_OPT
	player_ctrl.set_dust_enabled(fx_on)
	ui_mgr.set_cinema_fx_enabled(fx_on)
	room_mgr.update_room_visibility(settings_mgr.room_vis_radius)
	ui_mgr.refresh_render_buttons()
	ui_mgr.show_toast(RoomsI18n.t("toast_quality", [settings_mgr.quality_label()]), 2.2)


func restart_for_render() -> void:
	if settings_mgr.is_mobile_platform():
		ui_mgr.show_toast(RoomsI18n.t("toast_restart_mobile"), 3.0)
	else:
		net.disconnect_session()
		net.shutdown_steam()
		OS.set_restart_on_exit(true)
		get_tree().quit()


func refresh_mobile_mode() -> void:
	var en := settings_mgr.compute_mobile_enabled()
	var mg := ui_mgr.get_node_ref("mobile_group")
	if mg != null:
		mg.visible = en and (state == State.PLAYING)
	var bm := ui_mgr.get_node_ref("btn_mobile") as Button
	if bm != null:
		var lbl := RoomsI18n.t("set_mobile_auto")
		if settings_mgr.mobile_override == 1:
			lbl = RoomsI18n.t("set_mobile_on")
		elif settings_mgr.mobile_override == -1:
			lbl = RoomsI18n.t("set_mobile_off")
		bm.text = lbl
	if state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if en else Input.MOUSE_MODE_CAPTURED


func cycle_mobile_mode() -> void:
	settings_mgr.cycle_mobile_mode()
	refresh_mobile_mode()


func _on_net_session_synced(seed_val: int, room_idx: int, start_room_idx: int = 0) -> void:
	if not net.is_host:
		active_modifiers["admin_panel"] = false
		admin_ctrl.reset_all(player_col, true)
		ui_mgr.open_admin_panel(false)
		ui_mgr.update_menu_modifiers_ui()
		ui_mgr.update_pause_modifiers_ui()
		ui_mgr.update_admin_buttons_ui()
	if seed_val > 0 and (room_mgr.world_seed != seed_val or room_mgr.highest_opened < start_room_idx) and not net.is_host:
		reset_run(seed_val, start_room_idx)
	if room_idx > room_mgr.highest_opened:
		for idx in range(room_mgr.highest_opened, room_idx):
			var r: RoomScene = room_mgr.room_by_idx.get(idx) as RoomScene
			if r != null and not r.door_opened:
				open_room_door(idx, false, true)
	ui_mgr.show_toast(RoomsI18n.t("toast_sync", [room_idx]), 2.8)


func _on_remote_door_opened(room_index: int, slam: bool = false) -> void:
	for idx in range(maxi(room_index - 1, 0), room_index + 1):
		var r: RoomScene = room_mgr.room_by_idx.get(idx) as RoomScene
		if r != null and not r.door_opened:
			var before_high := room_mgr.highest_opened
			open_room_door(idx, slam and (idx == room_index), true)
			if net.is_online() and net.is_host and room_mgr.highest_opened > before_high:
				entity_dir.maybe_spawn_door_entities(room_mgr.highest_opened)


func _on_remote_entity_event(msg: Dictionary) -> void:
	var kind := String(msg.get("k", ""))
	var from_host := bool(msg.get("_from_host", false))
	# Client-allowed gameplay sync events (Make Haste levers & A-120 client hit relay)
	if kind == "lever_pull":
		interact_ctrl.pull_wall_lever(int(msg.get("r", -1)), int(msg.get("l", -1)), true)
		return
	if kind == "a120_end" and bool(msg.get("from_client", false)) and net.is_host:
		entity_dir.handle_remote_event(msg, state == State.PLAYING, state == State.DEAD)
		return
	if kind == "start_game":
		if not from_host:
			return
		var m: Variant = msg.get("mods", null)
		if m is Dictionary:
			active_modifiers = (m as Dictionary).duplicate()
			ui_mgr.update_menu_modifiers_ui()
		if not bool(active_modifiers.get("admin_panel", false)):
			admin_ctrl.reset_all(player_col, true)
		var s := int(msg.get("seed", 0))
		var sr := int(msg.get("start_room", 0))
		if s > 0 and (room_mgr.world_seed != s or checkpoint_room != sr):
			reset_run(s, sr)
		menu_begin_game(true, "")
		return
	if kind == "mods_update":
		if not from_host:
			return
		var m: Variant = msg.get("mods", null)
		if m is Dictionary:
			active_modifiers = (m as Dictionary).duplicate()
			if not bool(active_modifiers.get("admin_panel", false)):
				admin_ctrl.reset_all(player_col, true)
				ui_mgr.open_admin_panel(false)
			else:
				run_used_admin = true
			ui_mgr.update_menu_modifiers_ui()
			ui_mgr.update_pause_modifiers_ui()
			ui_mgr.update_admin_buttons_ui()
		return
	if kind == "power_state":
		if not from_host:
			return
		if bool(msg.get("out", false)):
			if not room_mgr.power_out:
				room_mgr.trigger_power_outage(audio)
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.045)
		else:
			if room_mgr.power_out:
				room_mgr.restore_power()
		return
	if kind == "admin_grant":
		if not from_host or not bool(active_modifiers.get("admin_panel", false)):
			return
		admin_ctrl.granted_by_host = true
		run_used_admin = true
		ui_mgr.update_pause_modifiers_ui()
		ui_mgr.show_toast(RoomsI18n.t("toast_admin_granted"), 3.0)
		return
	if kind == "admin_revive":
		if not from_host:
			return
		admin_revive_self(true)
		return
	if kind == "player_revived":
		var p_key := String(msg.get("peer", ""))
		if avatar_mgr.remote_players.has(p_key):
			var rp: Dictionary = avatar_mgr.remote_players[p_key]
			rp["dead"] = false
			var node := rp.get("node") as Node3D
			if is_instance_valid(node):
				node.visible = true
			var lbl := rp.get("lbl") as Label3D
			if is_instance_valid(lbl):
				lbl.text = "%s [A-%03d]" % [String(rp.get("name", "Player")), int(rp.get("room", 0))]
		return
	if not from_host:
		return
	entity_dir.handle_remote_event(msg, state == State.PLAYING, state == State.DEAD)


func _physics_process(delta: float) -> void:
	if player_ctrl == null or entity_dir == null or room_mgr == null:
		return
	if state == State.SPECTATING:
		entity_dir.process_entities(delta, false, false)
		entity_dir.process_a075(delta, false, false, active_modifiers)
		entity_dir.process_a085(delta, false, false, active_modifiers)
		entity_dir.process_a160(delta, false, false, active_modifiers)
		return
	if state == State.PAUSED:
		# In multiplayer, host pausing must not freeze monsters or entity spawners for other players
		if net.is_online():
			room_mgr.process_doors(delta)
			if entity_dir.is_authority():
				entity_dir.process_spawners(delta, active_modifiers)
			entity_dir.process_entities(delta, false, false)
			entity_dir.process_a075(delta, false, false, active_modifiers)
			entity_dir.process_a085(delta, false, false, active_modifiers)
			entity_dir.process_a160(delta, false, false, active_modifiers)
			entity_dir.process_a90(delta, active_modifiers)
		return
	if state == State.DEAD:
		if entity_dir.is_authority() and net.is_online() and avatar_mgr.has_alive_remote_players():
			entity_dir.process_entities(delta, false, true)
			entity_dir.process_a075(delta, false, true, active_modifiers)
			entity_dir.process_a085(delta, false, true, active_modifiers)
			entity_dir.process_a160(delta, false, true, active_modifiers)
		return
	if state != State.PLAYING:
		return

	run_time += delta
	room_mgr.process_doors(delta)
	player_ctrl.process_flashlight(delta, active_modifiers, entity_dir, ui_mgr, rng)

	if room_mgr.door50_flicker_active:
		player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.007)
		if room_mgr.process_door50_flicker(delta):
			if room_mgr.trigger_power_outage(audio):
				player_ctrl.shake_amount = maxf(player_ctrl.shake_amount, 0.045)
				if net.is_online() and net.is_host:
					net.broadcast_entity_event({"k": "power_state", "out": true}, true)

	if bool(active_modifiers.get("make_haste", false)):
		haste_timer -= delta
		if haste_timer <= 0.0:
			haste_timer = 0.0
			trigger_death("Время вышло (Make Haste)", "", {})
			return

	if admin_ctrl.god_mode and admin_ctrl.is_active(active_modifiers, net):
		hp = 100

	entity_dir.process_spawners(delta, active_modifiers)
	entity_dir.process_entities(delta, true, false)
	entity_dir.process_a075(delta, true, false, active_modifiers)
	entity_dir.process_a085(delta, true, false, active_modifiers)
	entity_dir.process_a160(delta, true, false, active_modifiers)
	player_ctrl.process_movement(delta, active_modifiers, ui_mgr.chat_open, entity_dir, rng)
	entity_dir.process_a90(delta, active_modifiers)
	ui_mgr.update_playing_hud(delta, hp, haste_timer, active_modifiers)


func _process(delta: float) -> void:
	if net == null or entity_dir == null or avatar_mgr == null:
		return
	if net.is_online() and settings_mgr != null and not settings_mgr.mobile_controls_enabled:
		net.voice_talking = Input.is_key_pressed(KEY_V) and ui_mgr != null and not ui_mgr.chat_open
	_sync_net_local_state()
	avatar_mgr.process_remote_players(delta)
	entity_dir.update_warp_fx(delta)

	if state == State.DEAD:
		_process_architect_death(delta)
		return
	if state == State.SPECTATING:
		room_mgr.process_doors(delta)
		_process_spectating(delta)
		return
	if state != State.PLAYING:
		return
	var a075_threat := entity_dir.a075_active and (entity_dir.a075_phase == 1 or entity_dir.a075_phase == 2)
	player_ctrl.process_camera_and_viewmodel(delta, ui_mgr.get_node_ref("locker_mask") as ColorRect, a075_threat)


func _sync_net_local_state() -> void:
	if not net.is_online():
		return
	var gp := player_body.global_position
	var hspd := Vector2(player_body.velocity.x, player_body.velocity.z).length()
	net.update_local_state({
		"pos": [gp.x, gp.y, gp.z],
		"yaw": player_body.rotation.y if player_ctrl.is_hiding else player_ctrl.yaw,
		"pitch": player_ctrl.hide_pitch_offset if player_ctrl.is_hiding else player_ctrl.pitch,
		"light": player_ctrl.light_on and (player_ctrl.std_battery > 0.05 if player_ctrl.active_tool == 0 else player_ctrl.gummy_battery > 0.05),
		"hide": player_ctrl.is_hiding,
		"hr": player_ctrl.hiding_room_idx if player_ctrl.is_hiding else -1,
		"hl": player_ctrl.hiding_locker_idx if player_ctrl.is_hiding else -1,
		"dead": (state == State.DEAD or state == State.SPECTATING),
		"sprint": hspd > 4.6,
		"room": room_mgr.highest_opened,
		"hp": hp,
		"tool": player_ctrl.active_tool,
		"gum": player_ctrl.has_gummy,
		"insp": (player_ctrl.battery_inspect_timer > 0.0),
		"dh": (player_ctrl.door_hand_timer > 0.0),
		"cov": player_ctrl.is_covering_gummy,
	})
	var alive_now := 1 if state == State.PLAYING else 0
	for rp_v in avatar_mgr.remote_players.values():
		if rp_v is Dictionary and not bool((rp_v as Dictionary).get("dead", false)):
			alive_now += 1
	net.update_presence(room_mgr.highest_opened, alive_now, 1 + avatar_mgr.remote_players.size())


func _process_architect_death(delta: float) -> void:
	_death_phase_t += delta
	var iris := ui_mgr.get_node_ref("death_iris")
	var imat := ui_mgr.ui.get("death_iris_mat") as ShaderMaterial
	var a_rect := ui_mgr.get_node_ref("a075_flash_rect")
	var a_mat := ui_mgr.ui.get("a075_flash_mat") as ShaderMaterial

	if _death_cause == "A-075":
		if _death_phase == 0:
			var p0 := clampf(_death_phase_t / 1.15, 0.0, 1.0)
			player_ctrl.process_a075_blind_death_pose(delta, p0)
			if a_rect != null and a_mat != null:
				a_rect.visible = true
				var strobe := 1.0 if (int(_death_phase_t * 18.0) % 2 == 0 or p0 > 0.35) else 0.78
				a_mat.set_shader_parameter("flash_amt", lerpf(1.0, 0.65, p0) * strobe)
				a_mat.set_shader_parameter("blind_burn", lerpf(0.05, 0.52, ease(p0, 0.7)))
			if p0 >= 1.0:
				_death_phase = 1
				_death_phase_t = 0.0
			return
		elif _death_phase == 1:
			var p1 := clampf(_death_phase_t / 0.95, 0.0, 1.0)
			player_ctrl.process_a075_blind_death_pose(delta, 1.0)
			if a_rect != null and a_mat != null:
				a_rect.visible = true
				a_mat.set_shader_parameter("flash_amt", lerpf(0.65, 0.0, p1))
				a_mat.set_shader_parameter("blind_burn", lerpf(0.52, 1.0, ease(p1, 0.85)))
			if p1 >= 1.0:
				_death_phase = 2
				_death_phase_t = 0.0
				audio.play_architect_appear()
				var arch_ov := ui_mgr.get_node_ref("architect_overlay")
				arch_ov.visible = true
				arch_ov.modulate.a = 0.0
				create_tween().tween_property(arch_ov, "modulate:a", 1.0, 0.75)
				var btn_rev := ui_mgr.get_node_ref("btn_arch_revive") as Button
				if btn_rev != null:
					btn_rev.visible = can_revive()
					btn_rev.text = RoomsI18n.t("arch_btn_revive") + (" (∞)" if can_use_admin() else (" (%d)" % revives_left))
			return
		if a_rect != null:
			var keep_a := ui_mgr.get_node_ref("architect_overlay").modulate.a < 0.99
			a_rect.visible = keep_a
			if not keep_a and a_mat != null:
				a_mat.set_shader_parameter("blind_burn", 0.0)
	else:
		if _death_phase == 0:
			if imat != null:
				imat.set_shader_parameter("red_amt", lerpf(0.92, 0.78, clampf(_death_phase_t / 0.48, 0.0, 1.0)))
			if _death_phase_t >= 0.48:
				_death_phase = 1
				_death_phase_t = 0.0
			return
		elif _death_phase == 1:
			var sp := clampf(_death_phase_t / 0.80, 0.0, 1.0)
			if imat != null:
				imat.set_shader_parameter("shrink_amt", sp)
				imat.set_shader_parameter("red_amt", lerpf(0.78, 0.0, ease(sp, 0.55)))
			if sp >= 1.0:
				_death_phase = 2
				_death_phase_t = 0.0
				audio.play_architect_appear()
				var arch_ov := ui_mgr.get_node_ref("architect_overlay")
				arch_ov.visible = true
				arch_ov.modulate.a = 0.0
				create_tween().tween_property(arch_ov, "modulate:a", 1.0, 0.75)
				var btn_rev := ui_mgr.get_node_ref("btn_arch_revive") as Button
				if btn_rev != null:
					btn_rev.visible = can_revive()
					btn_rev.text = RoomsI18n.t("arch_btn_revive") + (" (∞)" if can_use_admin() else (" (%d)" % revives_left))
			return
		if iris != null:
			iris.visible = ui_mgr.get_node_ref("architect_overlay").modulate.a < 0.99

	if _arch_lines.is_empty() or _death_phase != 2:
		return
	var cur_line := _arch_lines[_arch_line_idx]
	if _arch_glitch_step >= 0 and _arch_glitch_step < 12:
		_arch_glitch_timer += delta
		if _arch_glitch_timer >= 0.045:
			_arch_glitch_timer = 0.0
			_arch_glitch_step += 1
			var sp_lbl := ui_mgr.get_node_ref("arch_speech") as Label
			if _arch_glitch_step < 12:
				sp_lbl.text = RoomsArchitect.generate_glitch_frame(_arch_prev_text, cur_line, _arch_glitch_step, 12)
				audio.play_architect_blip(rng.randf_range(0.92, 1.10))
			else:
				sp_lbl.text = cur_line
				sp_lbl.modulate.a = 0.72
				create_tween().tween_property(sp_lbl, "modulate:a", 1.0, 0.22)
				_arch_prev_text = cur_line
				_arch_auto_advance_timer = 0.0
	elif _arch_glitch_step >= 12:
		_arch_auto_advance_timer += delta
		if _arch_auto_advance_timer >= 6.0:
			advance_architect_dialogue()


func _process_spectating(delta: float) -> void:
	if _spectate_key.is_empty() or not avatar_mgr.remote_players.has(_spectate_key):
		cycle_spectate_target(0)
	if _spectate_key.is_empty() or not avatar_mgr.remote_players.has(_spectate_key):
		return
	var rp: Dictionary = avatar_mgr.remote_players[_spectate_key]
	var tgt_node := rp.get("node") as Node3D
	if not is_instance_valid(tgt_node):
		return
	var r_num := int(rp.get("room", 0))

	# Spawn ahead rooms dynamically so spectating a teammate further ahead never shows pitch-black void!
	if r_num > room_mgr.highest_opened:
		var prev_high := room_mgr.highest_opened
		room_mgr.highest_opened = r_num
		while room_mgr.rooms.is_empty() or room_mgr.rooms[-1].index < r_num + 4:
			room_mgr.spawn_next_room(settings_mgr.render_quality, bool(active_modifiers.get("make_haste", false)), settings_mgr.room_vis_radius)
		for idx in range(prev_high, r_num):
			var r_door: RoomScene = room_mgr.room_by_idx.get(idx) as RoomScene
			if r_door != null and not r_door.door_opened:
				open_room_door(idx, false, true)

	if r_num != room_mgr.current_room_idx:
		room_mgr.current_room_idx = r_num
		room_mgr.update_room_visibility(settings_mgr.room_vis_radius)

	var s_txt := RoomsI18n.t("spec_watching", [String(rp.get("name", "Player")), r_num])
	s_txt += RoomsI18n.t("spec_dead_suffix") if bool(rp.get("dead", false)) else RoomsI18n.t("spec_alive_suffix")
	(ui_mgr.get_node_ref("spectate_lbl") as Label).text = s_txt

	var rp_yaw := float(rp.get("tgt_yaw", 0.0))
	if not _spectate_user_orbited:
		_spectate_yaw = lerp_angle(_spectate_yaw, rp_yaw, 1.0 - exp(-10.0 * delta))
	var pivot := tgt_node.global_position + Vector3(0.0, 1.48, 0.0)
	var back_dir := (Basis(Vector3.UP, _spectate_yaw) * Basis(Vector3.RIGHT, -_spectate_pitch) * Vector3(0.0, 0.0, 1.0)).normalized()
	var desired := pivot + back_dir * 2.55
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var q := PhysicsRayQueryParameters3D.create(pivot, desired, 0xFFFFFFFF, [player_body.get_rid()])
		var hit := space_state.intersect_ray(q)
		if not hit.is_empty():
			desired = hit.get("position", desired) - back_dir * 0.22

	# Snap camera if target is distant (switching target or large room gap) to avoid long lerp through walls
	if cam.global_position.distance_squared_to(pivot) > 625.0:
		cam.global_position = desired
	else:
		cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
	cam.look_at(pivot, Vector3.UP)
	cam.fov = lerpf(cam.fov, 76.0, 1.0 - exp(-10.0 * delta))


func _point_hits_mobile_btn(pos: Vector2) -> bool:
	if ui_mgr == null:
		return false
	for b in ui_mgr.mobile_btns:
		if is_instance_valid(b) and b.visible and b.get_global_rect().grow(10.0).has_point(pos):
			return true
	return false


func _update_joystick_from_pos(pos: Vector2) -> void:
	var max_r := 92.0
	var delta_v := pos - _joy_origin
	var dist := delta_v.length()
	var clamped := delta_v.normalized() * minf(dist, max_r) if dist > 0.001 else Vector2.ZERO
	player_ctrl.joy_vec = clamped / max_r
	if player_ctrl.joy_vec.length() < 0.14:
		player_ctrl.joy_vec = Vector2.ZERO
	if ui_mgr != null and ui_mgr.joy_ring != null and ui_mgr.joy_knob != null:
		ui_mgr.joy_knob.position = Vector2(110.0, 110.0) - ui_mgr.joy_knob.size * 0.5 + clamped


func _reset_touch_state() -> void:
	_joy_touch_id = -1
	_look_touch_id = -1
	_tap_touch_id = -1
	player_ctrl.joy_vec = Vector2.ZERO
	player_ctrl.mobile_sprint_held = false
	player_ctrl.mobile_gummy_held = false
	if ui_mgr != null and ui_mgr.joy_ring != null and ui_mgr.joy_knob != null:
		var vp_sz := get_viewport().get_visible_rect().size
		ui_mgr.joy_ring.position = Vector2(40.0, maxf(vp_sz.y - 270.0, 60.0))
		ui_mgr.joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.72)
		ui_mgr.joy_knob.position = Vector2(68.0, 68.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_V:
			net.voice_talking = false

	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed and not settings_mgr.mobile_controls_enabled and settings_mgr.mobile_override == 0:
			settings_mgr.touch_seen = true
			refresh_mobile_mode()
		if ui_mgr.disclaimer_active:
			return
		if state == State.DEAD and te.pressed:
			advance_architect_dialogue()
			get_viewport().set_input_as_handled()
			return
		if state == State.SPECTATING:
			if te.pressed and _look_touch_id == -1:
				_look_touch_id = te.index
			elif not te.pressed and te.index == _look_touch_id:
				_look_touch_id = -1
			return
		if state != State.PLAYING or not settings_mgr.mobile_controls_enabled or ui_mgr.chat_open:
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
				if ui_mgr.joy_ring != null:
					ui_mgr.joy_ring.position = _joy_origin - half
					ui_mgr.joy_ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_update_joystick_from_pos(te.position)
			elif _look_touch_id == -1:
				_look_touch_id = te.index
		else:
			if te.index == _tap_touch_id:
				var dt_ms := Time.get_ticks_msec() - _tap_start_time_ms
				var dist_px := te.position.distance_to(_tap_start_pos)
				_tap_touch_id = -1
				if dt_ms <= 300 and dist_px <= 20.0 and not player_ctrl.is_hiding and not _point_hits_mobile_btn(te.position):
					interact_ctrl.try_tap_world_interact(te.position, ui_mgr.reticle_screen_pos)
			if te.index == _joy_touch_id:
				_joy_touch_id = -1
				player_ctrl.joy_vec = Vector2.ZERO
				if ui_mgr.joy_ring != null and ui_mgr.joy_knob != null:
					ui_mgr.joy_ring.position = Vector2(40.0, maxf(vp_sz.y - 270.0, 60.0))
					ui_mgr.joy_ring.modulate = Color(1.0, 1.0, 1.0, 0.72)
					ui_mgr.joy_knob.position = Vector2(68.0, 68.0)
			elif te.index == _look_touch_id:
				_look_touch_id = -1
		return

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var vp_sz := get_viewport().get_visible_rect().size
		if state == State.SPECTATING and sd.index == _look_touch_id:
			var sp_sens := 0.0044 * settings_mgr.mouse_sens_mult
			_spectate_yaw -= sd.relative.x * sp_sens
			_spectate_pitch = clampf(_spectate_pitch - sd.relative.y * sp_sens, -1.15, 0.85)
			_spectate_user_orbited = true
			return
		if state != State.PLAYING or not settings_mgr.mobile_controls_enabled or ui_mgr.chat_open:
			return
		if sd.index == _joy_touch_id:
			_update_joystick_from_pos(sd.position)
		elif sd.index == _look_touch_id or (_look_touch_id == -1 and sd.position.x > vp_sz.x * 0.35):
			_look_touch_id = sd.index
			if player_ctrl.locker_transition_t < 1.0:
				return
			var sens := 0.0044 * settings_mgr.mouse_sens_mult
			if player_ctrl.is_hiding:
				player_ctrl.target_hide_yaw = clampf(player_ctrl.target_hide_yaw - sd.relative.x * sens, -0.58, 0.58)
				player_ctrl.target_hide_pitch = clampf(player_ctrl.target_hide_pitch - sd.relative.y * sens, -0.38, 0.38)
			else:
				player_ctrl.target_yaw -= sd.relative.x * sens
				player_ctrl.target_pitch = clampf(player_ctrl.target_pitch - sd.relative.y * sens, -1.42, 1.42)
		return

	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke := event as InputEventKey
		if ui_mgr.disclaimer_active:
			if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_ESCAPE:
				ui_mgr.dismiss_disclaimer()
				get_viewport().set_input_as_handled()
			return
		if ui_mgr.chat_open:
			if ke.keycode == KEY_ESCAPE:
				ui_mgr.chat_toggle(false)
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
				ui_mgr.chat_submit()
				get_viewport().set_input_as_handled()
			return
		var is_admin_key := (
			ke.keycode == KEY_F1
			or ke.keycode == KEY_QUOTELEFT
			or ke.keycode == KEY_ASCIITILDE
			or ke.physical_keycode == KEY_QUOTELEFT
			or ke.physical_keycode == KEY_ASCIITILDE
			or ke.as_text().to_lower() in ["quoteleft", "asciitilde", "ё", "`", "~"]
		)
		if is_admin_key:
			if can_use_admin():
				if state == State.PLAYING:
					set_state(State.PAUSED)
					ui_mgr.open_admin_panel(true)
				elif state == State.PAUSED:
					ui_mgr.open_admin_panel(not ui_mgr.get_node_ref("m_admin_scroll").visible)
				elif state == State.DEAD:
					var adm_visible := ui_mgr.get_node_ref("m_admin_scroll").visible
					ui_mgr.open_admin_panel(not adm_visible)
					var modal := ui_mgr.get_node_ref("modal")
					if modal != null:
						modal.visible = not adm_visible
				get_viewport().set_input_as_handled()
				return
		if state == State.DEAD:
			if (ke.keycode == KEY_TAB and not ke.shift_pressed) or ke.keycode == KEY_ESCAPE:
				if ui_mgr.get_node_ref("m_admin_scroll").visible:
					ui_mgr.open_admin_panel(false)
					var modal := ui_mgr.get_node_ref("modal")
					if modal != null:
						modal.visible = false
					get_viewport().set_input_as_handled()
					return
			if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				advance_architect_dialogue()
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_R:
				reset_run(-1, checkpoint_room)
				get_viewport().set_input_as_handled()
			return
		if state == State.MENU:
			if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_BACKSPACE:
				if ui_mgr.face_editor != null and ui_mgr.face_editor.visible:
					ui_mgr.face_editor.visible = false
					ui_mgr.get_node_ref("main_menu").visible = true
				elif ui_mgr.settings_from_menu:
					ui_mgr.open_settings_panel(false)
				elif ui_mgr.menu_view != "main":
					ui_mgr.set_menu_view("main")
				get_viewport().set_input_as_handled()
			return
		if state == State.SPECTATING:
			if ke.keycode == KEY_A or ke.keycode == KEY_LEFT:
				cycle_spectate_target(-1)
			elif ke.keycode == KEY_D or ke.keycode == KEY_RIGHT:
				cycle_spectate_target(1)
			elif ke.keycode == KEY_R:
				reset_run(-1, checkpoint_room)
			return
		if ke.keycode == KEY_F11:
			var win := get_window()
			win.mode = Window.MODE_WINDOWED if win.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
			get_viewport().set_input_as_handled()
			return
		if ke.keycode == KEY_TAB and ke.shift_pressed:
			if net.steam_ready and net._steam != null:
				net._steam.call("activateGameOverlay", "")
			get_viewport().set_input_as_handled()
			return
		if (ke.keycode == KEY_TAB and not ke.shift_pressed) or ke.keycode == KEY_ESCAPE:
			if state == State.PLAYING:
				set_state(State.PAUSED)
			elif state == State.PAUSED:
				if ui_mgr.get_node_ref("m_settings_scroll").visible:
					ui_mgr.open_settings_panel(false)
				elif ui_mgr.get_node_ref("m_admin_scroll").visible:
					ui_mgr.open_admin_panel(false)
				else:
					set_state(State.PLAYING)
			get_viewport().set_input_as_handled()
			return
		if state == State.PLAYING:
			if not settings_mgr.mobile_controls_enabled and ke.keycode == KEY_T and net.is_online():
				ui_mgr.chat_toggle(true)
				get_viewport().set_input_as_handled()
				return
			if ke.keycode == KEY_V:
				net.voice_talking = net.is_online() and not settings_mgr.mobile_controls_enabled
				return
			if ke.keycode == KEY_E:
				interact_ctrl.try_interact()
				return
			if player_ctrl.is_action_locked():
				return
			if player_ctrl.is_hiding and ke.keycode == KEY_W:
				player_ctrl.exit_locker(false, entity_dir)
			elif player_ctrl.is_hiding and ke.keycode == KEY_S:
				player_ctrl.exit_locker(true, entity_dir)
			elif ke.keycode == KEY_R:
				player_ctrl.try_reload_flashlight(ui_mgr)
			elif ke.keycode == KEY_M:
				settings_mgr.audio_muted = not settings_mgr.audio_muted
				settings_mgr.apply_audio_settings(audio, true)
				ui_mgr.sync_settings_ui()
				ui_mgr.show_toast(RoomsI18n.t("toast_mute_on" if settings_mgr.audio_muted else "toast_mute_off"), 1.5)

	elif event is InputEventMouseMotion and (state == State.PLAYING or state == State.SPECTATING):
		var mm := event as InputEventMouseMotion
		if ui_mgr.chat_open:
			return
		if state == State.SPECTATING:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_spectate_yaw -= mm.relative.x * 0.004 * settings_mgr.mouse_sens_mult
				_spectate_pitch = clampf(_spectate_pitch - mm.relative.y * 0.004 * settings_mgr.mouse_sens_mult, -1.15, 0.85)
				_spectate_user_orbited = true
			return
		if not settings_mgr.mobile_controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if player_ctrl.locker_transition_t < 1.0:
			return
		if player_ctrl.is_hiding:
			player_ctrl.target_hide_yaw = clampf(player_ctrl.target_hide_yaw - mm.relative.x * 0.0022 * settings_mgr.mouse_sens_mult, -0.58, 0.58)
			player_ctrl.target_hide_pitch = clampf(player_ctrl.target_hide_pitch - mm.relative.y * 0.0022 * settings_mgr.mouse_sens_mult, -0.38, 0.38)
		else:
			player_ctrl.target_yaw -= mm.relative.x * 0.0024 * settings_mgr.mouse_sens_mult
			player_ctrl.target_pitch = clampf(player_ctrl.target_pitch - mm.relative.y * 0.0024 * settings_mgr.mouse_sens_mult, -1.42, 1.42)

	elif event is InputEventMouseButton and (state == State.PLAYING or state == State.SPECTATING):
		var mb := event as InputEventMouseButton
		if ui_mgr.chat_open:
			return
		if state == State.SPECTATING:
			if mb.pressed:
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					cycle_spectate_target(-1)
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					cycle_spectate_target(1)
			return
		if mb.pressed and not settings_mgr.mobile_controls_enabled:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if not player_ctrl.is_action_locked():
				interact_ctrl.try_interact()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if player_ctrl.is_action_locked():
					return
				if player_ctrl.active_tool == 1:
					player_ctrl.rmb_held = true
					var a075_threat := entity_dir.a075_active and (entity_dir.a075_phase == 1 or entity_dir.a075_phase == 2)
					if not a075_threat:
						player_ctrl.try_shake_gummy(3.5)
				else:
					player_ctrl.toggle_flashlight(entity_dir, ui_mgr)
			else:
				player_ctrl.rmb_held = false
