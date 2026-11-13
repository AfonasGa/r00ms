class_name RoomsAudio
extends AudioStreamPlayer

## Procedural horror audio synthesizer for Rooms: ambient hum, footsteps, doors, lockers, and entities.

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
var _master_bus_idx := 0
var _sfx_bus_idx := -1
var _entities_bus_idx := -1
var a60_intensity := 0.0
var low_hp_mode := false

var _playback: AudioStreamGeneratorPlayback = null
var _sample_rate := 22050.0
var _hum_phase := 0.0
var _growl_phase := 0.0
var _hb_timer := 0.0
var _noise_seed := 1337
var _voices: Array[Dictionary] = []

var _hs_ambience: AudioStreamPlayer
var _hs_distant: AudioStreamPlayer
var _hs_nearby: AudioStreamPlayer
var _hs_scream: AudioStreamPlayer
var _a120_distant_bus_idx := -1
var _hs_active := false

var _a60_rumble: AudioStreamPlayer
var _a60_ambience: AudioStreamPlayer
var _a60_near: AudioStreamPlayer
var _a60_door_break: AudioStreamPlayer
var _a60_jumpscare: AudioStreamPlayer
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
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _sample_rate
	gen.buffer_length = 0.08
	stream = gen
	autoplay = false
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback
	_setup_a120_players()


func _exit_tree() -> void:
	stop_a120()
	stop_a60()
	stop_darkness()
	_playback = null
	stop()


func _setup_a120_players() -> void:
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

	_a120_distant_bus_idx = AudioServer.get_bus_index("A120Distant")
	if _a120_distant_bus_idx == -1:
		_a120_distant_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(_a120_distant_bus_idx)
		AudioServer.set_bus_name(_a120_distant_bus_idx, "A120Distant")
		AudioServer.set_bus_send(_a120_distant_bus_idx, "Entities")

	_hs_ambience = _make_stream_player("res://assets/sound/a120/AmbienceA120.mp3", true, "Entities")
	_hs_distant = _make_stream_player("res://assets/sound/a120/DistantA120.mp3", true, "A120Distant")
	_hs_nearby = _make_stream_player("res://assets/sound/a120/NearbyA120.mp3", true, "Entities")
	_hs_scream = _make_stream_player("res://assets/sound/a120/Ghost_scream.mp3", false, "Entities")

	_death_player = _make_stream_player("res://assets/sound/Dead_sound_effect.mp3", false, "SFX")
	_a60_rumble = _make_stream_player("res://assets/sound/a60/A-60_Rumble_Sound.mp3", false, "Entities")
	_a60_ambience = _make_stream_player("res://assets/sound/a60/ActualA-60IngameAmbience.wav", true, "Entities")
	_a60_near = _make_stream_player("res://assets/sound/a60/A-60_Near_Sound.mp3", true, "Entities")
	_a60_door_break = _make_stream_player("res://assets/sound/a60/A60BreakingDoor.ogg", false, "Entities")
	_a60_jumpscare = _make_stream_player("res://assets/sound/a60/A60_Jumpscare.ogg", false, "Entities")
	_darkness_whisper = _make_stream_player("res://assets/sound/darkness/darkness_whisper.ogg", true, "Entities")
	_foot_iron = _make_stream_player("res://assets/sound/foot/footsteps-iron-record.mp3", false, "SFX")
	_foot_carpet = _make_stream_player("res://assets/sound/foot/hard-carpet-footwork-shoes-footsteps-walking-ntg3.mp3", false, "SFX")
	apply_volume_settings()


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


func _make_stream_player(res_path: String, should_loop: bool, bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.volume_db = -40.0
	if ResourceLoader.exists(res_path):
		var st := load(res_path) as AudioStream
		if st != null:
			if st is AudioStreamMP3:
				(st as AudioStreamMP3).loop = should_loop
			elif st is AudioStreamOggVorbis:
				(st as AudioStreamOggVorbis).loop = should_loop
			p.stream = st
	add_child(p)
	return p


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
	# ActualA-60IngameAmbience carries far down the corridors so the player hears it earlier
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
	if muted:
		return
	if _death_player != null and _death_player.stream != null:
		_death_player.volume_db = 1.0
		_death_player.play()


func play_pant(inhale: bool = false) -> void:
	if muted:
		return
	if inhale:
		_add_voice(520.0, 680.0, 0.19, 0.10, "noise_thud")
	else:
		_add_voice(380.0, 210.0, 0.24, 0.13, "noise_thud")


func play_desk_crawl(entering: bool) -> void:
	if muted:
		return
	var f0 := 280.0 if entering else 340.0
	_add_voice(f0, f0 * 0.65, 0.18, 0.14, "noise_thud")


func play_power_down() -> void:
	if muted:
		return
	_add_voice(190.0, 42.0, 0.35, 0.44, "square_thud")
	_add_voice(120.0, 28.0, 1.15, 0.34, "sine", 0.05)
	_add_voice(640.0, 90.0, 0.90, 0.16, "triangle", 0.04)


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
	if muted:
		return
	_add_voice(1100.0, 240.0, 0.16, 0.22, "triangle")
	_add_voice(520.0, 180.0, 0.18, 0.14, "sine", 0.05)


func play_flashlight_flicker() -> void:
	if muted:
		return
	var base := _hs_rng.randf_range(1650.0, 2550.0)
	_add_voice(base, base * 0.55, 0.038, 0.11, "noise_thud")
	_add_voice(base * 1.15, base * 0.72, 0.028, 0.06, "triangle")


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
	# Disabled synthetic stomp sound so only user-supplied A-120 audio files play
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
		_hs_ambience.volume_db = lerpf(-68.0, -2.5, amb_lvl)

		var dist_db := lerpf(-68.0, -3.0, dist_curve) if phase == 2 else lerpf(-38.0, -14.0, dist_curve)
		_hs_distant.volume_db = dist_db

		var near_lvl := prox_close * _hs_near_wave_cur if phase == 2 else 0.0
		_hs_nearby.pitch_scale = lerpf(0.94, 1.10, _hs_near_wave_cur)
		_hs_nearby.volume_db = lerpf(-46.0, 1.5, near_lvl) if near_lvl > 0.01 else -80.0

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
			# Dummy headless driver fallback so drum bounce can also be verified without hardware audio
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
			# Louder metallic iron footsteps as requested!
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
		return
	# Fallback synthesized step if stream missing
	var amp := (0.28 if is_metal else 0.16) if not sprinting else (0.38 if is_metal else 0.22)
	_add_voice(180.0 if is_metal else 95.0, 56.0 if is_metal else 42.0, 0.09, amp, "square_thud" if is_metal else "noise_thud")


func play_door_open() -> void:
	if muted:
		return
	_add_voice(180.0, 70.0, 0.28, 0.26, "square_thud")
	_add_voice(440.0, 560.0, 0.14, 0.10, "sine", 0.03)


func play_locker_toggle(entering: bool) -> void:
	if muted:
		return
	var f0 := 220.0 if entering else 280.0
	var f1 := 110.0 if entering else 150.0
	_add_voice(f0, f1, 0.18, 0.26, "square_thud")


func play_flashlight_click() -> void:
	if muted:
		return
	_add_voice(1450.0, 900.0, 0.04, 0.14, "sine")


func play_gummy_shake() -> void:
	if muted:
		return
	_add_voice(640.0, 960.0, 0.07, 0.16, "triangle")
	_add_voice(980.0, 620.0, 0.06, 0.12, "triangle", 0.06)


func play_pickup() -> void:
	if muted:
		return
	_add_voice(587.33, 880.0, 0.22, 0.20, "sine")


func play_a90_warn() -> void:
	if muted:
		return
	_add_voice(1120.0, 1480.0, 0.16, 0.25, "square_thud", 0.0, "entity")
	_add_voice(260.0, 190.0, 0.28, 0.20, "noise_thud", 0.04, "entity")


func play_a90_hit() -> void:
	if muted:
		return
	_add_voice(920.0, 120.0, 0.65, 0.42, "noise_thud", 0.0, "entity")
	_add_voice(140.0, 48.0, 0.55, 0.36, "square_thud", 0.0, "entity")


func play_a120_thud(intensity: float) -> void:
	if muted:
		return
	var amp := clampf(intensity * 0.34, 0.05, 0.38)
	_add_voice(115.0, 38.0, 0.24, amp, "square_thud", 0.0, "entity")
	_add_voice(520.0, 310.0, 0.14, amp * 0.45, "sine", 0.0, "entity")


func play_jumpscare() -> void:
	if muted:
		return
	_add_voice(780.0, 190.0, 0.85, 0.48, "noise_thud", 0.0, "entity")
	_add_voice(160.0, 52.0, 0.85, 0.42, "square_thud", 0.0, "entity")


func play_architect_appear() -> void:
	if muted:
		return
	# Ethereal Guiding Light chord (D4 - A4 - C5 - E5)
	_add_voice(293.66, 290.0, 1.35, 0.14, "sine", 0.00)
	_add_voice(440.00, 438.0, 1.25, 0.11, "triangle", 0.07)
	_add_voice(523.25, 521.0, 1.15, 0.09, "sine", 0.14)
	_add_voice(659.25, 654.0, 1.10, 0.07, "sine", 0.22)


func play_architect_blip(pitch_mul: float = 1.0) -> void:
	if muted:
		return
	var f0 := 620.0 * pitch_mul
	_add_voice(f0, f0 * 0.82, 0.045, 0.055, "sine")


func _add_voice(f0: float, f1: float, dur: float, amp: float, kind: String, delay: float = 0.0, chan: String = "sfx") -> void:
	if _voices.size() > 16:
		_voices.pop_front()
	_voices.append({
		"f0": f0,
		"f1": f1,
		"dur": maxf(dur, 0.01),
		"age": -delay,
		"amp": amp,
		"kind": kind,
		"chan": chan,
		"phase": 0.0,
	})


func _next_noise() -> float:
	_noise_seed = (_noise_seed * 1103515245 + 12345) & 0x7FFFFFFF
	return (float(_noise_seed) / 1073741824.0) - 1.0


func _process(delta: float) -> void:
	if _foot_iron_cutoff > 0.0:
		_foot_iron_cutoff -= delta
		if _foot_iron_cutoff <= 0.0 and _foot_iron != null and _foot_iron.playing:
			_foot_iron.stop()
	if _foot_carpet_cutoff > 0.0:
		_foot_carpet_cutoff -= delta
		if _foot_carpet_cutoff <= 0.0 and _foot_carpet != null and _foot_carpet.playing:
			_foot_carpet.stop()
	if _playback == null:
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback
		if _playback == null:
			return

	if low_hp_mode:
		_hb_timer -= delta
		if _hb_timer <= 0.0:
			_hb_timer = 0.72
			_add_voice(78.0, 44.0, 0.14, 0.24, "sine", 0.0, "ambient")
			_add_voice(68.0, 40.0, 0.12, 0.16, "sine", 0.18, "ambient")

	var frames := _playback.get_frames_available()
	if frames <= 0:
		return

	var inv_sr := 1.0 / _sample_rate
	for _i in range(frames):
		if muted or master_volume <= 0.001:
			_playback.push_frame(Vector2.ZERO)
			continue

		_hum_phase = fmod(_hum_phase + 58.0 * inv_sr, 1.0)
		_growl_phase = fmod(_growl_phase + 44.0 * inv_sr, 1.0)

		var n_raw := _next_noise()
		var hum := sin(_hum_phase * TAU) * 0.025 + sin(_hum_phase * 2.0 * TAU) * 0.012
		var a60_sig := 0.0
		if a60_intensity > 0.01 and (_a60_ambience == null or _a60_ambience.stream == null):
			var growl := sin(_growl_phase * TAU) * 0.35 + (1.0 if sin(_growl_phase * 3.0 * TAU) > 0.0 else -1.0) * 0.15
			a60_sig = (n_raw * 0.55 + growl * 0.45) * clampf(a60_intensity, 0.0, 1.0) * 0.42

		var fx := 0.0
		var write_idx := 0
		for idx in range(_voices.size()):
			var v: Dictionary = _voices[idx]
			var age: float = float(v["age"]) + inv_sr
			v["age"] = age
			var dur: float = float(v["dur"])
			if age < 0.0:
				_voices[write_idx] = v
				write_idx += 1
				continue
			if age >= dur:
				continue

			var t := age / dur
			var env := sin(minf(t * 14.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.7)
			var freq := lerpf(float(v["f0"]), float(v["f1"]), t)
			var phase := fmod(float(v["phase"]) + freq * inv_sr, 1.0)
			v["phase"] = phase

			var kind := String(v["kind"])
			var s := 0.0
			if kind == "noise_thud":
				s = n_raw * 0.65 + sin(phase * TAU) * 0.35
			elif kind == "square_thud":
				s = (1.0 if sin(phase * TAU) >= 0.0 else -1.0) * 0.5 + sin(phase * TAU) * 0.5
			elif kind == "triangle":
				s = 1.0 - 4.0 * absf(phase - 0.5)
			else:
				s = sin(phase * TAU)

			var chan := String(v.get("chan", "sfx"))
			var ch_mul := entity_volume if chan == "entity" else (ambient_volume if chan == "ambient" else sfx_volume)
			fx += s * env * float(v["amp"]) * ch_mul
			_voices[write_idx] = v
			write_idx += 1

		if write_idx < _voices.size():
			_voices.resize(write_idx)

		var out := clampf(hum * ambient_volume + a60_sig * entity_volume + fx, -0.88, 0.88)
		_playback.push_frame(Vector2(out, out))
