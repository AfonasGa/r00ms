class_name RoomsAudio
extends AudioStreamPlayer

## Horror audio manager for Rooms: real foley/reverb samples, corridor ambience, footsteps, doors, lockers, and entities.

var muted := false:
	set(v):
		muted = v
		apply_volume_settings()
var master_volume := 0.75:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		apply_volume_settings()
var sfx_volume := 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		apply_volume_settings()
var entity_volume := 1.0:
	set(v):
		entity_volume = clampf(v, 0.0, 1.0)
		apply_volume_settings()
var ambient_volume := 1.0:
	set(v):
		ambient_volume = clampf(v, 0.0, 1.0)
		apply_volume_settings()

var _master_bus_idx := 0
var _sfx_bus_idx := -1
var _entities_bus_idx := -1
var _ambient_bus_idx := -1
var _a120_distant_bus_idx := -1

var a60_intensity := 0.0
var low_hp_mode := false
var _hb_timer := 0.0

var _room_ambient: AudioStreamPlayer
var _sfx_heartbeat: AudioStreamPlayer
var _sfx_door_open: AudioStreamPlayer
var _sfx_locker_enter: AudioStreamPlayer
var _sfx_locker_exit: AudioStreamPlayer
var _sfx_desk_crawl: AudioStreamPlayer
var _sfx_flashlight_click: AudioStreamPlayer
var _sfx_flashlight_low: AudioStreamPlayer
var _sfx_flashlight_flicker: AudioStreamPlayer
var _sfx_gummy_shake: AudioStreamPlayer
var _sfx_pickup: AudioStreamPlayer
var _sfx_power_down: AudioStreamPlayer
var _sfx_pant_in: AudioStreamPlayer
var _sfx_pant_out: AudioStreamPlayer
var _sfx_arch_appear: AudioStreamPlayer
var _sfx_arch_blip: AudioStreamPlayer
var _sfx_a90_warn: AudioStreamPlayer
var _sfx_a90_hit: AudioStreamPlayer
var _sfx_jumpscare: AudioStreamPlayer

var _hs_ambience: AudioStreamPlayer
var _hs_distant: AudioStreamPlayer
var _hs_nearby: AudioStreamPlayer
var _hs_scream: AudioStreamPlayer
var _hs_active := false

var _a60_rumble: AudioStreamPlayer
var _a60_ambience: AudioStreamPlayer
var _a60_near: AudioStreamPlayer
var _a60_door_break: AudioStreamPlayer
var _a60_jumpscare: AudioStreamPlayer
var _a075_warn: AudioStreamPlayer
var _a075_scan: AudioStreamPlayer
var _a075_attack: AudioStreamPlayer
var _a075_despawn: AudioStreamPlayer
var _a085_warn: AudioStreamPlayer
var _a085_door_slam: AudioStreamPlayer
var _a085_pass: AudioStreamPlayer
var _a160_alert: AudioStreamPlayer
var _a160_lunge: AudioStreamPlayer
var _a160_banish: AudioStreamPlayer
var _death_player: AudioStreamPlayer
var _darkness_whisper: AudioStreamPlayer
var _foot_iron: AudioStreamPlayer
var _foot_carpet: AudioStreamPlayer
var _foot_iron_cutoff := 0.0
var _foot_carpet_cutoff := 0.0
var _foot_iron_cursor := 0
var _foot_carpet_cursor := 0
var _a60_stream_active := false
var _hs_pitch_timer := 0.0
var _hs_pitch_cur := 1.0
var _hs_pitch_tgt := 1.0
var _hs_amb_wave_cur := 0.5
var _hs_amb_wave_tgt := 0.8
var _hs_near_wave_cur := 0.2
var _hs_near_wave_tgt := 0.9
var _hs_wave_timer := 0.0
var _hs_bang_timer := 0.0
var _hs_drum_cd := 0.0
var _hs_drum_prev_db := -40.0
var _hs_headless_drum_timer := 0.0
var _hs_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_hs_rng.randomize()
	autoplay = false
	_setup_audio_players()


func _exit_tree() -> void:
	stop_a120()
	stop_a60()
	stop_a075_scan()
	stop_darkness()
	if is_instance_valid(_room_ambient) and _room_ambient.playing:
		_room_ambient.stop()
	stop()


func _setup_audio_players() -> void:
	_master_bus_idx = maxi(AudioServer.get_bus_index("Master"), 0)

	_entities_bus_idx = AudioServer.get_bus_index("Entities")
	if _entities_bus_idx == -1:
		_entities_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_entities_bus_idx)
		AudioServer.set_bus_name(_entities_bus_idx, "Entities")
		AudioServer.set_bus_send(_entities_bus_idx, "Master")

	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if _sfx_bus_idx == -1:
		_sfx_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_sfx_bus_idx)
		AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(_sfx_bus_idx, "Master")

	_ambient_bus_idx = AudioServer.get_bus_index("Ambient")
	if _ambient_bus_idx == -1:
		_ambient_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_ambient_bus_idx)
		AudioServer.set_bus_name(_ambient_bus_idx, "Ambient")
		AudioServer.set_bus_send(_ambient_bus_idx, "Master")

	_a120_distant_bus_idx = AudioServer.get_bus_index("A120Distant")
	if _a120_distant_bus_idx == -1:
		_a120_distant_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_a120_distant_bus_idx)
		AudioServer.set_bus_name(_a120_distant_bus_idx, "A120Distant")
		AudioServer.set_bus_send(_a120_distant_bus_idx, "Entities")

	# Ambient & physiology
	_room_ambient = _make_stream_player("res://assets/sound/sfx/room_ambient.wav", true, "Ambient")
	_sfx_heartbeat = _make_stream_player("res://assets/sound/sfx/heartbeat.wav", false, "Ambient", 2)

	# Foley & UI SFX
	_sfx_door_open = _make_stream_player("res://assets/sound/sfx/door_open.wav", false, "SFX", 3)
	_sfx_locker_enter = _make_stream_player("res://assets/sound/sfx/locker_enter.wav", false, "SFX", 2)
	_sfx_locker_exit = _make_stream_player("res://assets/sound/sfx/locker_exit.wav", false, "SFX", 2)
	_sfx_desk_crawl = _make_stream_player("res://assets/sound/sfx/desk_crawl.wav", false, "SFX", 2)
	_sfx_flashlight_click = _make_stream_player("res://assets/sound/sfx/flashlight_click.wav", false, "SFX", 4)
	_sfx_flashlight_low = _make_stream_player("res://assets/sound/sfx/flashlight_low_power.wav", false, "SFX", 2)
	_sfx_flashlight_flicker = _make_stream_player("res://assets/sound/sfx/flashlight_flicker.wav", false, "SFX", 4)
	_sfx_gummy_shake = _make_stream_player("res://assets/sound/sfx/gummy_shake.wav", false, "SFX", 4)
	_sfx_pickup = _make_stream_player("res://assets/sound/sfx/pickup.wav", false, "SFX", 3)
	_sfx_power_down = _make_stream_player("res://assets/sound/sfx/power_down.wav", false, "SFX", 2)
	_sfx_pant_in = _make_stream_player("res://assets/sound/sfx/pant_in.wav", false, "SFX", 2)
	_sfx_pant_out = _make_stream_player("res://assets/sound/sfx/pant_out.wav", false, "SFX", 2)
	_sfx_arch_appear = _make_stream_player("res://assets/sound/sfx/architect_appear.wav", false, "SFX", 2)
	_sfx_arch_blip = _make_stream_player("res://assets/sound/sfx/architect_blip.wav", false, "SFX", 4)
	_death_player = _make_stream_player("res://assets/sound/Dead_sound_effect.mp3", false, "SFX")
	_foot_iron = _make_stream_player("res://assets/sound/foot/footsteps-iron-record.mp3", false, "SFX")
	_foot_carpet = _make_stream_player("res://assets/sound/foot/hard-carpet-footwork-shoes-footsteps-walking-ntg3.mp3", false, "SFX")

	# Entities
	_sfx_a90_warn = _make_stream_player("res://assets/sound/sfx/a90_warn.wav", false, "Entities", 2)
	_sfx_a90_hit = _make_stream_player("res://assets/sound/sfx/a90_hit.wav", false, "Entities", 2)
	_sfx_jumpscare = _make_stream_player("res://assets/sound/sfx/jumpscare.wav", false, "Entities", 2)

	_hs_ambience = _make_stream_player("res://assets/sound/a120/AmbienceA120.mp3", true, "Entities")
	_hs_distant = _make_stream_player("res://assets/sound/a120/DistantA120.mp3", true, "A120Distant")
	_hs_nearby = _make_stream_player("res://assets/sound/a120/NearbyA120.mp3", true, "Entities")
	_hs_scream = _make_stream_player("res://assets/sound/a120/Ghost_scream.mp3", false, "Entities")

	_a60_rumble = _make_stream_player("res://assets/sound/a60/A-60_Rumble_Sound.mp3", false, "Entities")
	_a60_ambience = _make_stream_player("res://assets/sound/a60/ActualA-60IngameAmbience.wav", true, "Entities")
	_a60_near = _make_stream_player("res://assets/sound/a60/A-60_Near_Sound.mp3", true, "Entities")
	_a60_door_break = _make_stream_player("res://assets/sound/a60/A60BreakingDoor.ogg", false, "Entities")
	_a60_jumpscare = _make_stream_player("res://assets/sound/a60/A60_Jumpscare.ogg", false, "Entities")

	_a075_warn = _make_stream_player("res://assets/sound/a075/a075_warning_charge.wav", false, "Entities")
	_a075_scan = _make_stream_player("res://assets/sound/a075/a075_scan_ambience.wav", true, "Entities")
	_a075_attack = _make_stream_player("res://assets/sound/a075/a075_flash_attack.wav", false, "Entities")
	_a075_despawn = _make_stream_player("res://assets/sound/a075/a075_despawn.wav", false, "Entities")
	_a085_warn = _make_stream_player("res://assets/sound/a085/a085_warning_rumble.wav", false, "Entities")
	_a085_door_slam = _make_stream_player("res://assets/sound/a085/a085_door_slam_throw.wav", false, "Entities")
	_a085_pass = _make_stream_player("res://assets/sound/a085/a085_corridor_pass.wav", false, "Entities")
	_a160_alert = _make_stream_player("res://assets/sound/a160/a160_alert.wav", false, "Entities")
	_a160_lunge = _make_stream_player("res://assets/sound/a160/a160_lunge.wav", false, "Entities")
	_a160_banish = _make_stream_player("res://assets/sound/a160/a160_banish.wav", false, "Entities")
	_darkness_whisper = _make_stream_player("res://assets/sound/darkness/darkness_whisper.ogg", true, "Entities")

	apply_volume_settings()

	if _room_ambient != null and _room_ambient.stream != null:
		_room_ambient.volume_db = -14.0
		_room_ambient.play()


func apply_volume_settings() -> void:
	if not is_inside_tree():
		return
	var m_idx := maxi(AudioServer.get_bus_index("Master"), 0)
	AudioServer.set_bus_mute(m_idx, muted or master_volume <= 0.001)
	AudioServer.set_bus_volume_db(m_idx, linear_to_db(maxf(master_volume, 0.001)) if master_volume > 0.001 else -80.0)
	if _sfx_bus_idx >= 0:
		AudioServer.set_bus_mute(_sfx_bus_idx, muted or sfx_volume <= 0.001)
		AudioServer.set_bus_volume_db(_sfx_bus_idx, linear_to_db(maxf(sfx_volume, 0.001)) if sfx_volume > 0.001 else -80.0)
	if _entities_bus_idx >= 0:
		AudioServer.set_bus_mute(_entities_bus_idx, muted or entity_volume <= 0.001)
		AudioServer.set_bus_volume_db(_entities_bus_idx, linear_to_db(maxf(entity_volume, 0.001)) if entity_volume > 0.001 else -80.0)
	if _ambient_bus_idx >= 0:
		AudioServer.set_bus_mute(_ambient_bus_idx, muted or ambient_volume <= 0.001)
		AudioServer.set_bus_volume_db(_ambient_bus_idx, linear_to_db(maxf(ambient_volume, 0.001)) if ambient_volume > 0.001 else -80.0)


func _make_stream_player(res_path: String, should_loop: bool, bus_name: String, polyphony: int = 1) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.volume_db = -40.0
	p.max_polyphony = maxi(polyphony, 1)
	if ResourceLoader.exists(res_path):
		var st := load(res_path) as AudioStream
		if st != null:
			if st is AudioStreamMP3:
				(st as AudioStreamMP3).loop = should_loop
			elif st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = should_loop
			elif st is AudioStreamWAV and should_loop:
				var wav := st as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				if wav.loop_end <= 0:
					var total_frames := int(round(wav.get_length() * float(maxi(wav.mix_rate, 1))))
					if total_frames > 0:
						wav.loop_end = total_frames
			p.stream = st
	add_child(p)
	return p


func _play_sfx(player: AudioStreamPlayer, vol_db: float, pitch_min: float = 1.0, pitch_max: float = 1.0) -> void:
	if muted or player == null or player.stream == null:
		return
	player.volume_db = vol_db
	player.pitch_scale = _hs_rng.randf_range(pitch_min, pitch_max) if pitch_max > pitch_min else pitch_min
	player.play()


func play_a075_warning() -> void:
	_play_sfx(_a075_warn, -1.5, 0.98, 1.02)


func start_a075_scan() -> void:
	if _a075_scan != null and _a075_scan.stream != null:
		_a075_scan.volume_db = 0.5
		_a075_scan.pitch_scale = 1.0
		if not _a075_scan.playing:
			_a075_scan.play()


func stop_a075_scan() -> void:
	if _a075_scan != null and _a075_scan.playing:
		_a075_scan.stop()
	if _a075_warn != null and _a075_warn.playing:
		_a075_warn.stop()


func play_a075_attack() -> void:
	stop_a075_scan()
	_play_sfx(_a075_attack, 1.5, 0.98, 1.03)


func play_a075_despawn() -> void:
	stop_a075_scan()
	_play_sfx(_a075_despawn, -2.0, 0.97, 1.03)


func play_a085_warning() -> void:
	_play_sfx(_a085_warn, 2.0, 0.98, 1.02)


func play_a085_door_slam() -> void:
	stop_a085_all()
	_play_sfx(_a085_door_slam, 3.5, 0.98, 1.02)


func play_a085_pass() -> void:
	_play_sfx(_a085_pass, 1.5, 0.98, 1.02)


func stop_a085_all() -> void:
	if _a085_warn != null and _a085_warn.playing:
		_a085_warn.stop()


func play_a160_alert() -> void:
	_play_sfx(_a160_alert, 1.5, 0.98, 1.02)


func play_a160_lunge() -> void:
	_play_sfx(_a160_lunge, 2.5, 0.98, 1.02)


func play_a160_banish() -> void:
	_play_sfx(_a160_banish, 0.5, 0.98, 1.03)


func stop_a160_all() -> void:
	if _a160_alert != null and _a160_alert.playing:
		_a160_alert.stop()
	if _a160_lunge != null and _a160_lunge.playing:
		_a160_lunge.stop()
	if _a160_banish != null and _a160_banish.playing:
		_a160_banish.stop()


func start_a60_spawn(is_prime: bool = false, _is_before_100: bool = true) -> void:
	_a60_stream_active = not is_prime
	if is_prime:
		stop_a60()
		return
	var base_pitch := 1.0
	if _a60_rumble.stream != null:
		_a60_rumble.pitch_scale = _hs_rng.randf_range(0.95, 1.05) * base_pitch
		_a60_rumble.volume_db = -58.0 if not muted else -80.0
		_a60_rumble.play()
	if _a60_ambience.stream != null:
		_a60_ambience.pitch_scale = base_pitch
		_a60_ambience.volume_db = -44.0 if not muted else -80.0
		_a60_ambience.play()
	if _a60_near.stream != null:
		_a60_near.pitch_scale = base_pitch
		_a60_near.volume_db = -72.0 if not muted else -80.0
		_a60_near.play()


func update_a60_mix(_delta: float, distance: float, phase: int, is_prime: bool = false) -> void:
	if is_prime or not _a60_stream_active or phase == 0:
		return
	if _a60_rumble.stream != null and not _a60_rumble.playing:
		_a60_rumble.play()
	if _a60_ambience.stream != null and not _a60_ambience.playing:
		_a60_ambience.play()
	if _a60_near.stream != null and not _a60_near.playing:
		_a60_near.play()

	if muted or master_volume <= 0.001 or entity_volume <= 0.001:
		_a60_ambience.volume_db = -80.0
		_a60_near.volume_db = -80.0
		_a60_rumble.volume_db = -80.0
		return

	var dist_att := clampf(1.0 - (distance - 4.0) / 225.0, 0.0, 1.0)
	var curve := pow(dist_att, 2.3)
	var amb_att := clampf(1.0 - (distance - 6.0) / 360.0, 0.04, 1.0)
	var amb_curve := pow(amb_att, 1.35)
	var prox := clampf(1.0 - (distance - 2.0) / 28.0, 0.0, 1.0)
	var prime_pitch := 1.18 if is_prime else 1.0

	_a60_rumble.volume_db = lerpf(-58.0, -4.5, curve)
	_a60_ambience.pitch_scale = prime_pitch + _hs_rng.randf_range(-0.04, 0.04)
	_a60_ambience.volume_db = lerpf(-44.0, -0.5, amb_curve)
	_a60_near.pitch_scale = prime_pitch
	_a60_near.volume_db = lerpf(-38.0, 2.5, prox * prox) if (phase == 2 and prox > 0.02) else -80.0


func play_a60_door_break(is_prime: bool = false) -> void:
	if muted:
		return
	if _a60_door_break != null and _a60_door_break.stream != null:
		_a60_door_break.pitch_scale = _hs_rng.randf_range(0.84, 1.22) * (1.10 if is_prime else 1.0)
		_a60_door_break.volume_db = 2.0
		_a60_door_break.play()


func play_a60_jumpscare(is_prime: bool = false) -> void:
	if muted:
		return
	if _a60_jumpscare != null and _a60_jumpscare.stream != null:
		_a60_jumpscare.pitch_scale = (1.14 if is_prime else 1.0) + _hs_rng.randf_range(-0.05, 0.05)
		_a60_jumpscare.volume_db = 3.0
		_a60_jumpscare.play()
	else:
		play_jumpscare()


func stop_a60() -> void:
	_a60_stream_active = false
	for p in [_a60_rumble, _a60_ambience, _a60_near]:
		if is_instance_valid(p) and p.playing:
			p.stop()


func play_death_sound() -> void:
	_play_sfx(_death_player, 1.0, 1.0, 1.0)


func play_pant(inhale: bool = false) -> void:
	if inhale:
		_play_sfx(_sfx_pant_in, -6.5, 0.94, 1.06)
	else:
		_play_sfx(_sfx_pant_out, -5.5, 0.94, 1.06)


func play_desk_crawl(entering: bool) -> void:
	_play_sfx(_sfx_desk_crawl, -3.5, 0.92 if entering else 1.02, 1.00 if entering else 1.10)


func play_power_down() -> void:
	_play_sfx(_sfx_power_down, -1.5, 0.97, 1.03)


func start_darkness() -> void:
	if _darkness_whisper != null and _darkness_whisper.stream != null:
		_darkness_whisper.volume_db = -36.0 if not muted else -80.0
		if not _darkness_whisper.playing:
			_darkness_whisper.play()


func update_darkness(intensity: float) -> void:
	if _darkness_whisper == null or _darkness_whisper.stream == null:
		return
	if not _darkness_whisper.playing:
		_darkness_whisper.play()
	if muted or master_volume <= 0.001 or entity_volume <= 0.001:
		_darkness_whisper.volume_db = -80.0
		return
	var lvl := clampf(intensity, 0.0, 1.0)
	_darkness_whisper.volume_db = lerpf(-34.0, 3.0, pow(lvl, 1.15))
	_darkness_whisper.pitch_scale = lerpf(0.95, 1.08, lvl)


func stop_darkness() -> void:
	if is_instance_valid(_darkness_whisper) and _darkness_whisper.playing:
		_darkness_whisper.stop()


func play_flashlight_low_power() -> void:
	_play_sfx(_sfx_flashlight_low, -3.5, 0.96, 1.04)


func play_flashlight_flicker() -> void:
	_play_sfx(_sfx_flashlight_flicker, -6.5, 0.88, 1.16)


func start_a120_spawn() -> void:
	_hs_active = true
	_hs_pitch_timer = 0.0
	_hs_wave_timer = 0.0
	_hs_bang_timer = 0.12
	_hs_drum_cd = 0.0
	_hs_drum_prev_db = -40.0
	_hs_headless_drum_timer = 0.0
	var p_base := 1.0
	if _hs_ambience.stream != null:
		_hs_ambience.pitch_scale = p_base
		_hs_ambience.volume_db = -26.0 if not muted else -80.0
		_hs_ambience.play()
	if _hs_distant.stream != null:
		_hs_distant.pitch_scale = p_base
		_hs_distant.volume_db = -24.0 if not muted else -80.0
		_hs_distant.play()
	if _hs_nearby.stream != null:
		_hs_nearby.pitch_scale = p_base
		_hs_nearby.volume_db = -60.0 if not muted else -80.0
		_hs_nearby.play()


func stop_a120() -> void:
	_hs_active = false
	for p in [_hs_ambience, _hs_distant, _hs_nearby]:
		if is_instance_valid(p) and p.playing:
			p.stop()


func play_a120_bang(_intensity: float = 0.9) -> void:
	return


func play_a120_thud(_intensity: float) -> void:
	return


func play_a120_scream() -> void:
	stop_a120()
	if muted:
		return
	if _hs_scream != null and _hs_scream.stream != null:
		_hs_scream.volume_db = 2.0
		_hs_scream.pitch_scale = _hs_rng.randf_range(0.95, 1.06)
		_hs_scream.play()
	else:
		play_jumpscare()


func update_a120_mix(delta: float, distance: float, phase: int) -> bool:
	if not _hs_active or phase == 0:
		return false

	_hs_pitch_timer -= delta
	if _hs_pitch_timer <= 0.0:
		_hs_pitch_timer = _hs_rng.randf_range(0.16, 0.44)
		_hs_pitch_tgt = _hs_rng.randf_range(0.76, 1.34)
		_hs_amb_wave_tgt = _hs_rng.randf_range(0.25, 1.0)

	_hs_wave_timer -= delta
	if _hs_wave_timer <= 0.0:
		_hs_wave_timer = _hs_rng.randf_range(0.18, 0.56)
		_hs_near_wave_tgt = _hs_rng.randf_range(0.12, 1.0)

	_hs_pitch_cur = lerpf(_hs_pitch_cur, _hs_pitch_tgt, minf(delta * 9.0, 1.0))
	_hs_amb_wave_cur = lerpf(_hs_amb_wave_cur, _hs_amb_wave_tgt, minf(delta * 7.0, 1.0))
	_hs_near_wave_cur = lerpf(_hs_near_wave_cur, _hs_near_wave_tgt, minf(delta * 10.0, 1.0))

	var dist_att := clampf(1.0 - (distance - 3.0) / 145.0, 0.0, 1.0)
	var dist_curve := pow(dist_att, 1.45)
	var prox_close := clampf(1.0 - (distance - 2.0) / 26.0, 0.0, 1.0)

	if muted or master_volume <= 0.001 or entity_volume <= 0.001 or dist_att <= 0.01:
		_hs_ambience.volume_db = -80.0
		_hs_distant.volume_db = -80.0
		_hs_nearby.volume_db = -80.0
	else:
		_hs_ambience.pitch_scale = _hs_pitch_cur
		var amb_lvl := clampf(dist_curve * _hs_amb_wave_cur, 0.0, 1.0)
		_hs_ambience.volume_db = lerpf(-26.0, 3.5, amb_lvl)

		var dist_db := lerpf(-24.0, 4.0, dist_curve) if phase == 2 else lerpf(-22.0, -1.0, dist_curve)
		_hs_distant.volume_db = dist_db

		var near_lvl := prox_close * _hs_near_wave_cur if phase == 2 else 0.0
		_hs_nearby.pitch_scale = lerpf(0.94, 1.10, _hs_near_wave_cur)
		_hs_nearby.volume_db = lerpf(-22.0, 6.0, near_lvl) if near_lvl > 0.01 else -80.0

	_hs_drum_cd = maxf(_hs_drum_cd - delta, 0.0)
	var drum_hit := false
	if phase == 2 and _a120_distant_bus_idx >= 0 and _hs_distant.playing:
		var l_db := AudioServer.get_bus_peak_volume_left_db(_a120_distant_bus_idx, 0)
		var r_db := AudioServer.get_bus_peak_volume_right_db(_a120_distant_bus_idx, 0)
		var raw_peak := maxf(l_db, r_db)
		if raw_peak > -120.0:
			var source_db := raw_peak - _hs_distant.volume_db
			if source_db > -15.4 and (source_db > _hs_drum_prev_db + 0.8 or source_db > -14.3) and _hs_drum_cd <= 0.0:
				drum_hit = true
				_hs_drum_cd = 0.22
			_hs_drum_prev_db = lerpf(_hs_drum_prev_db, source_db, minf(delta * 10.0, 1.0))
		else:
			_hs_headless_drum_timer += delta
			if _hs_headless_drum_timer >= 0.42:
				_hs_headless_drum_timer = 0.0
				drum_hit = true
	return drum_hit


func play_step(sprinting: bool, surface: String = "carpet") -> void:
	if muted:
		return
	var is_metal := (surface == "metal")
	var player: AudioStreamPlayer = _foot_iron if is_metal else _foot_carpet
	if player != null and player.stream != null:
		var stream_len := player.stream.get_length()
		var slice_dur := 0.23 if sprinting else 0.27
		var start_sec := 0.12
		if stream_len > 1.2:
			var step_slots := 6
			var cursor := _foot_iron_cursor if is_metal else _foot_carpet_cursor
			cursor = (cursor + 1 + _hs_rng.randi_range(0, 1)) % step_slots
			if is_metal:
				_foot_iron_cursor = cursor
			else:
				_foot_carpet_cursor = cursor
			var usable := maxf(stream_len - slice_dur - 0.35, 0.4)
			start_sec = 0.14 + (float(cursor) / float(step_slots)) * usable
		player.pitch_scale = _hs_rng.randf_range(1.06, 1.18) if sprinting else _hs_rng.randf_range(0.92, 1.04)
		if is_metal:
			player.volume_db = -2.0 if sprinting else -4.8
			_foot_iron_cutoff = slice_dur
			if _foot_carpet != null:
				_foot_carpet.stop()
		else:
			player.volume_db = -10.5 if sprinting else -13.5
			_foot_carpet_cutoff = slice_dur
			if _foot_iron != null:
				_foot_iron.stop()
		player.play(start_sec)


func play_door_open() -> void:
	_play_sfx(_sfx_door_open, -2.5, 0.94, 1.06)


func play_locker_toggle(entering: bool) -> void:
	if entering:
		_play_sfx(_sfx_locker_enter, -2.5, 0.95, 1.05)
	else:
		_play_sfx(_sfx_locker_exit, -2.5, 0.95, 1.05)


func play_flashlight_click() -> void:
	_play_sfx(_sfx_flashlight_click, -4.0, 0.96, 1.04)


func play_gummy_shake() -> void:
	_play_sfx(_sfx_gummy_shake, -3.0, 0.93, 1.09)


func play_pickup() -> void:
	_play_sfx(_sfx_pickup, -3.5, 0.96, 1.05)


func play_a90_warn() -> void:
	_play_sfx(_sfx_a90_warn, 0.0, 0.97, 1.03)


func play_a90_hit() -> void:
	_play_sfx(_sfx_a90_hit, 2.0, 0.96, 1.04)


func play_jumpscare() -> void:
	_play_sfx(_sfx_jumpscare, 2.5, 0.96, 1.04)


func play_architect_appear() -> void:
	_play_sfx(_sfx_arch_appear, -4.0, 1.0, 1.0)


func play_architect_blip(pitch_mul: float = 1.0) -> void:
	var p := clampf(pitch_mul, 0.5, 2.0)
	_play_sfx(_sfx_arch_blip, -9.5, p * 0.96, p * 1.04)


func _process(delta: float) -> void:
	if _foot_iron_cutoff > 0.0:
		_foot_iron_cutoff -= delta
		if _foot_iron_cutoff <= 0.0 and _foot_iron != null and _foot_iron.playing:
			_foot_iron.stop()
	if _foot_carpet_cutoff > 0.0:
		_foot_carpet_cutoff -= delta
		if _foot_carpet_cutoff <= 0.0 and _foot_carpet != null and _foot_carpet.playing:
			_foot_carpet.stop()

	if low_hp_mode:
		_hb_timer -= delta
		if _hb_timer <= 0.0:
			_hb_timer = 0.78
			_play_sfx(_sfx_heartbeat, -3.0, 0.96, 1.04)
	else:
		_hb_timer = 0.0


func play_heartbeat(vol_db: float = 0.0) -> void:
	_play_sfx(_sfx_heartbeat, vol_db, 0.94, 1.04)
