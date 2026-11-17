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

# Death / Architect / Spectator state
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
		if state == State.MENU and net.is_online() and not net.is_host:
			ui_mgr.set_menu_view("multi")
	)


func reset_run(forced_seed: int = -1) -> void:
	admin_ctrl.reset_all(player_col)
	ui_mgr.update_admin_buttons_ui()

	var haste_on := bool(active_modifiers.get("make_haste", false))
	var lights_out_on := bool(active_modifiers.get("lights_out", false))
	room_mgr.reset_world(forced_seed, settings_mgr.render_quality, lights_out_on, haste_on, settings_mgr.room_vis_radius)
	rng.seed = room_mgr.world_seed

	hp = 100
	run_time = 0.0
	victory_reached = false
	checkpoint_room = 0
	haste_timer = 60.0
	_death_phase = 0
	_death_phase_t = 0.0
	_spectate_key = ""
	_spectate_yaw = 0.0
	_spectate_pitch = 0.25
	_spectate_last_hiding = false
	_spectate_user_orbited = false

	player_ctrl.reset_for_run()
	entity_dir.reset_for_run()
	audio.low_hp_mode = false

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

	net.update_lobby_progress(room_mgr.world_seed, 0)
	if net.is_online() and net.is_host and forced_seed <= 0:
		net.broadcast_session_sync(room_mgr.world_seed, 0)

	set_state(State.PLAYING)
	ui_mgr.show_toast(RoomsI18n.t("toast_start"), 3.5)


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
	elif state == State.SPECTATING:
		_reset_touch_state()
		ui_mgr.clear_all_vignettes()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui_mgr.get_node_ref("modal").visible = false
		ui_mgr.get_node_ref("architect_overlay").visible = false
		ui_mgr.get_node_ref("death_iris").visible = false
		if player_ctrl.vm_holder != null:
			player_ctrl.vm_holder.visible = false
		if player_ctrl.anim_hand != null:
			player_ctrl.anim_hand.visible = false
		flashlight.visible = false
	elif state == State.MENU:
		_reset_touch_state()
		ui_mgr.clear_all_vignettes()
		admin_ctrl.reset_all(player_col)
		ui_mgr.update_admin_buttons_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui_mgr.get_node_ref("modal").visible = false
		ui_mgr.get_node_ref("architect_overlay").visible = false
		ui_mgr.get_node_ref("death_iris").visible = false
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
	reset_run(-1)
	set_state(State.MENU)


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
		net.broadcast_entity_event({"k": "start_game", "seed": room_mgr.world_seed, "mods": active_modifiers})
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
			ui_mgr.show_toast(RoomsI18n.t("toast_door20"), 4.0)
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
			ui_mgr.show_toast(RoomsI18n.t("toast_power_flicker"), 3.0)
		if bool(active_modifiers.get("make_haste", false)):
			haste_timer = maxf(haste_timer, 60.0)
		room_mgr.ensure_ahead_rooms(settings_mgr.render_quality, bool(active_modifiers.get("make_haste", false)), settings_mgr.room_vis_radius)

		if opened_num == 19:
			entity_dir.a60_door20_trigger_timer = 5.0
		elif opened_num == 100:
			checkpoint_room = 100
			ui_mgr.show_toast(RoomsI18n.t("toast_cp", [100]), 3.5)
		elif opened_num == 200:
			checkpoint_room = 200
			ui_mgr.show_toast(RoomsI18n.t("toast_cp", [200]), 3.5)
		elif opened_num >= 300 and not victory_reached:
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
		ui_mgr.show_toast(RoomsI18n.t("toast_a120_warp", [back_steps, target_idx]), 3.4)
		return true
	ui_mgr.flash_damage(Color(0.85, 0.08, 0.08, 0.65))
	ui_mgr.show_toast(RoomsI18n.t("toast_a120_hit", [hp]), 2.6)
	return false


func admin_revive_self() -> void:
	hp = 100
	player_ctrl.is_hiding = false
	set_state(State.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui_mgr.show_toast(RoomsI18n.t("toast_revived"), 2.0)


func admin_skip_rooms(count: int) -> void:
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


func cycle_render_quality() -> void:
	var nxt := (settings_mgr.render_quality + 1) % 3
	settings_mgr.apply_render_quality(nxt, world_env, flashlight, cam, true)
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


func _on_net_session_synced(seed_val: int, room_idx: int) -> void:
	if seed_val > 0 and room_mgr.world_seed != seed_val and not net.is_host:
		reset_run(seed_val)
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
	if kind == "start_game":
		var s := int(msg.get("seed", 0))
		if s > 0 and room_mgr.world_seed != s:
			reset_run(s)
		var m: Variant = msg.get("mods", null)
		if m is Dictionary:
			active_modifiers = (m as Dictionary).duplicate()
			ui_mgr.update_menu_modifiers_ui()
		menu_begin_game(true, "")
		return
	if kind == "mods_update":
		var m: Variant = msg.get("mods", null)
		if m is Dictionary:
			active_modifiers = (m as Dictionary).duplicate()
			ui_mgr.update_menu_modifiers_ui()
		return
	if kind == "admin_grant":
		admin_ctrl.granted_by_host = true
		ui_mgr.get_node_ref("btn_pause_admin").visible = true
		ui_mgr.show_toast(RoomsI18n.t("toast_admin_granted"), 3.0)
		return
	if kind == "admin_revive":
		admin_revive_self()
		return
	entity_dir.handle_remote_event(msg, state == State.PLAYING, state == State.DEAD)


func _physics_process(delta: float) -> void:
	if state == State.SPECTATING:
		entity_dir.process_entities(delta, false, false)
		entity_dir.process_a075(delta, false, false, active_modifiers)
		return
	if state == State.DEAD:
		if entity_dir.is_authority() and net.is_online() and avatar_mgr.has_alive_remote_players():
			entity_dir.process_entities(delta, false, true)
			entity_dir.process_a075(delta, false, true, active_modifiers)
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
				ui_mgr.show_toast(RoomsI18n.t("toast_power_out"), 3.4)

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
	player_ctrl.process_movement(delta, active_modifiers, ui_mgr.chat_open, entity_dir, rng)
	entity_dir.process_a90(delta, active_modifiers)
	ui_mgr.update_playing_hud(delta, hp, haste_timer, active_modifiers)


func _process(delta: float) -> void:
	if net.is_online() and not settings_mgr.mobile_controls_enabled:
		net.voice_talking = Input.is_key_pressed(KEY_V) and not ui_mgr.chat_open
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
	cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
	cam.look_at(pivot, Vector3.UP)
	cam.fov = lerpf(cam.fov, 76.0, 1.0 - exp(-10.0 * delta))


func _reset_touch_state() -> void:
	_joy_touch_id = -1
	_look_touch_id = -1
	_tap_touch_id = -1
	player_ctrl.joy_vec = Vector2.ZERO
	player_ctrl.mobile_sprint_held = false
	player_ctrl.mobile_gummy_held = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_V:
			net.voice_talking = false

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
		if ke.keycode == KEY_F1 or ke.keycode == KEY_QUOTELEFT or ke.keycode == KEY_ASCIITILDE:
			if can_use_admin():
				if state == State.PLAYING:
					set_state(State.PAUSED)
					ui_mgr.open_admin_panel(true)
				elif state == State.PAUSED:
					ui_mgr.open_admin_panel(not ui_mgr.get_node_ref("m_admin_scroll").visible)
				get_viewport().set_input_as_handled()
				return
		if state == State.DEAD:
			if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				advance_architect_dialogue()
				get_viewport().set_input_as_handled()
			elif ke.keycode == KEY_R:
				reset_run(-1)
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
				reset_run(-1)
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
			elif ke.keycode == KEY_1:
				player_ctrl.set_active_tool(0)
			elif ke.keycode == KEY_2 and player_ctrl.has_gummy:
				player_ctrl.set_active_tool(1)
			elif ke.keycode == KEY_R:
				player_ctrl.try_reload_flashlight(ui_mgr)
			elif ke.keycode == KEY_M:
				settings_mgr.audio_muted = not settings_mgr.audio_muted
				settings_mgr.apply_audio_settings(audio, true)
				ui_mgr.sync_settings_ui()
				ui_mgr.show_toast(RoomsI18n.t("toast_mute_on" if settings_mgr.audio_muted else "toast_mute_off"), 1.5)

	elif event is InputEventMouseMotion and (state == State.PLAYING or state == State.SPECTATING):
		var mm := event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION or ui_mgr.chat_open:
			return
		if state == State.SPECTATING:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_spectate_yaw -= mm.relative.x * 0.004 * settings_mgr.mouse_sens_mult
				_spectate_pitch = clampf(_spectate_pitch - mm.relative.y * 0.004 * settings_mgr.mouse_sens_mult, -1.15, 0.85)
				_spectate_user_orbited = true
			return
		if not settings_mgr.mobile_controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
		if mb.device == InputEvent.DEVICE_ID_EMULATION or ui_mgr.chat_open:
			return
		if state == State.SPECTATING:
			if mb.pressed:
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					cycle_spectate_target(-1)
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					cycle_spectate_target(1)
			return
		if settings_mgr.mobile_controls_enabled:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif not player_ctrl.is_action_locked():
				interact_ctrl.try_interact()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
