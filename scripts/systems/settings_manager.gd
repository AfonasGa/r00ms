class_name SettingsManager
extends Node

## Manages graphics presets, render backend overrides, audio levels/devices,
## camera/control preferences, and mobile touch detection.

enum RenderQuality { MOBILE_OPT, MEDIUM, HIGH }

const SETTINGS_PATH := "user://rooms_settings.cfg"
const OVERRIDE_PATH := "user://override.cfg"

var render_quality: int = RenderQuality.HIGH
var room_vis_radius := 7
var render_backend := "forward_plus"
var active_render_backend := "forward_plus"

var audio_master := 0.75
var audio_entities := 1.0
var audio_sfx := 1.0
var audio_ambient := 1.0
var audio_muted := false
var mouse_sens_mult := 1.0
var base_fov := 75.0
var head_bob_enabled := true
var language := "ru"

var mobile_controls_enabled := false
var mobile_override := 0 # 0=auto, 1=force on, -1=force off


func is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.get_name() in ["Android", "iOS"]


func detect_active_render_backend() -> String:
	var rs := RenderingServer
	if rs != null and rs.has_method("get_current_rendering_method"):
		var cur := String(rs.call("get_current_rendering_method"))
		if not cur.is_empty():
			return cur
	if is_mobile_platform():
		return String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "mobile"))
	return String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))


func load_settings() -> void:
	active_render_backend = detect_active_render_backend()
	render_backend = active_render_backend
	render_quality = RenderQuality.MOBILE_OPT if is_mobile_platform() else RenderQuality.HIGH
	language = RoomsI18n.detect_default_lang()

	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		language = String(cfg.get_value("general", "language", language))
		render_quality = clampi(int(cfg.get_value("graphics", "quality", render_quality)), RenderQuality.MOBILE_OPT, RenderQuality.HIGH)
		audio_master = clampf(float(cfg.get_value("audio", "master", 0.75)), 0.0, 1.0)
		audio_entities = clampf(float(cfg.get_value("audio", "entities", 1.0)), 0.0, 1.0)
		audio_sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
		audio_ambient = clampf(float(cfg.get_value("audio", "ambient", 1.0)), 0.0, 1.0)
		audio_muted = bool(cfg.get_value("audio", "muted", false))
		mouse_sens_mult = clampf(float(cfg.get_value("controls", "sensitivity", 1.0)), 0.4, 2.2)
		base_fov = clampf(float(cfg.get_value("controls", "fov", 75.0)), 65.0, 95.0)
		head_bob_enabled = bool(cfg.get_value("controls", "head_bob", true))
		var saved_out := String(cfg.get_value("audio", "output_device", ""))
		if not saved_out.is_empty() and saved_out in AudioServer.get_output_device_list():
			AudioServer.output_device = saved_out
		var saved_in := String(cfg.get_value("audio", "input_device", ""))
		if not saved_in.is_empty() and saved_in in AudioServer.get_input_device_list():
			AudioServer.input_device = saved_in

	RoomsI18n.set_lang(language)
	language = RoomsI18n.lang

	var ov := ConfigFile.new()
	if ov.load(OVERRIDE_PATH) == OK:
		var saved_b := String(ov.get_value("rendering", "renderer/rendering_method", ""))
		if saved_b in ["forward_plus", "mobile", "gl_compatibility"]:
			render_backend = saved_b


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "language", language)
	cfg.set_value("graphics", "quality", render_quality)
	cfg.set_value("audio", "master", audio_master)
	cfg.set_value("audio", "entities", audio_entities)
	cfg.set_value("audio", "sfx", audio_sfx)
	cfg.set_value("audio", "ambient", audio_ambient)
	cfg.set_value("audio", "muted", audio_muted)
	cfg.set_value("controls", "sensitivity", mouse_sens_mult)
	cfg.set_value("controls", "fov", base_fov)
	cfg.set_value("controls", "head_bob", head_bob_enabled)
	cfg.set_value("audio", "output_device", AudioServer.output_device)
	cfg.set_value("audio", "input_device", AudioServer.input_device)
	cfg.save(SETTINGS_PATH)


func apply_audio_settings(audio: RoomsAudio, save_cfg: bool = true) -> void:
	if audio != null:
		audio.muted = audio_muted
		audio.master_volume = audio_master
		audio.entity_volume = audio_entities
		audio.sfx_volume = audio_sfx
		audio.ambient_volume = audio_ambient
		audio.apply_volume_settings()
	if save_cfg:
		save_settings()


func reset_audio_defaults(audio: RoomsAudio) -> void:
	audio_master = 0.75
	audio_entities = 1.0
	audio_sfx = 1.0
	audio_ambient = 1.0
	audio_muted = false
	apply_audio_settings(audio, true)


func quality_label(q: int = -1) -> String:
	var v := render_quality if q < 0 else q
	if v == RenderQuality.MOBILE_OPT:
		return RoomsI18n.t("qual_mobile")
	if v == RenderQuality.MEDIUM:
		return RoomsI18n.t("qual_medium")
	return RoomsI18n.t("qual_high")


func backend_label(b: String = "") -> String:
	var v := render_backend if b.is_empty() else b
	if v == "mobile":
		return "Mobile (Vulkan/Metal)"
	if v == "gl_compatibility":
		return "Compatibility (OpenGL)"
	return "Forward+ (PC)"


func setup_environment(world_env: WorldEnvironment, flashlight: SpotLight3D) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = Viewport.MSAA_DISABLED if render_quality != RenderQuality.HIGH else Viewport.MSAA_2X
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.005, 0.007, 0.011)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.075, 0.10)
	env.ambient_light_energy = 0.14
	env.fog_enabled = (render_quality != RenderQuality.MOBILE_OPT)
	env.fog_light_color = Color(0.008, 0.011, 0.018)
	env.fog_density = 0.024
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = (render_quality == RenderQuality.HIGH)
	env.ssao_radius = 0.85
	env.ssao_intensity = 1.65
	env.ssao_power = 1.6
	env.glow_enabled = (render_quality != RenderQuality.MOBILE_OPT)
	env.glow_intensity = 0.82
	env.glow_bloom = 0.35
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	world_env.environment = env

	if flashlight != null:
		flashlight.shadow_enabled = false
		flashlight.spot_angle_attenuation = 1.4
		flashlight.spot_attenuation = 1.2


func apply_render_quality(q: int, world_env: WorldEnvironment, flashlight: SpotLight3D, cam: Camera3D, save_cfg: bool = true) -> void:
	render_quality = clampi(q, RenderQuality.MOBILE_OPT, RenderQuality.HIGH)
	var vp := get_viewport()
	var env := world_env.environment if world_env != null else null
	if render_quality == RenderQuality.MOBILE_OPT:
		room_vis_radius = 3
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.72
		if flashlight != null:
			flashlight.shadow_enabled = false
		if cam != null:
			cam.far = 78.0
		if env != null:
			env.ssao_enabled = false
			env.glow_enabled = false
			env.fog_enabled = false
	elif render_quality == RenderQuality.MEDIUM:
		room_vis_radius = 5
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.88
		if flashlight != null:
			flashlight.shadow_enabled = false
		if cam != null:
			cam.far = 65.0
		if env != null:
			env.ssao_enabled = false
			env.glow_enabled = true
			env.fog_enabled = true
	else:
		room_vis_radius = 7
		if vp != null:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
		if flashlight != null:
			flashlight.shadow_enabled = false
		if cam != null:
			cam.far = 85.0
		if env != null:
			env.ssao_enabled = true
			env.glow_enabled = true
			env.fog_enabled = true

	if save_cfg:
		save_settings()


func set_render_backend(backend: String) -> String:
	if not (backend in ["forward_plus", "mobile", "gl_compatibility"]):
		return ""
	render_backend = backend
	var ov := ConfigFile.new()
	ov.load(OVERRIDE_PATH)
	ov.set_value("rendering", "renderer/rendering_method", backend)
	ov.set_value("rendering", "renderer/rendering_method.mobile", backend)
	ov.save(OVERRIDE_PATH)
	if backend != active_render_backend:
		return RoomsI18n.t("backend_restart", [backend_label(backend)])
	return RoomsI18n.t("backend_active", [backend_label(backend)])


func cycle_render_backend() -> String:
	var order: Array[String] = ["forward_plus", "mobile", "gl_compatibility"]
	var idx := order.find(render_backend)
	var nxt: String = order[(idx + 1) % order.size()]
	return set_render_backend(nxt)


func compute_mobile_enabled() -> bool:
	if mobile_override == 1:
		mobile_controls_enabled = true
	elif mobile_override == -1:
		mobile_controls_enabled = false
	else:
		mobile_controls_enabled = is_mobile_platform() or DisplayServer.is_touchscreen_available()
	return mobile_controls_enabled


func cycle_mobile_mode() -> void:
	if mobile_override == 0:
		mobile_override = 1
	elif mobile_override == 1:
		mobile_override = -1
	else:
		mobile_override = 0
	compute_mobile_enabled()
