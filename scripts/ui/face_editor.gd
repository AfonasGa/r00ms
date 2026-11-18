class_name FaceEditor
extends Control

## Minimalist in-game face painter for the dummi player model.
## Draws onto a 64x64 RGBA Image, shows a live 3D rotating dummi head preview,
## saves to user://dummi_face.png and emits face_saved(image, png_bytes) for multiplayer sync.

signal face_saved(image: Image, png_bytes: PackedByteArray)
signal closed

const CANVAS_SIZE := 64
const SAVE_PATH := "user://dummi_face.png"
const MAX_UNDO := 20

var _img: Image = null
var _tex: ImageTexture = null
var _undo_stack: Array[PackedByteArray] = []

var _brush_color := Color(0.07, 0.07, 0.08, 1.0)
var _brush_radius := 2
var _eraser_mode := false
var _is_drawing := false
var _last_px := Vector2i(-1, -1)

var _canvas_rect: TextureRect = null
var _preview_avatar: DummiAvatar = null
var _preview_pivot: Node3D = null
var _preview_angle := 0.0
var _size_btns: Dictionary = {}
var _color_btns: Array[Dictionary] = []
var _tool_btn_draw: Button = null
var _tool_btn_erase: Button = null
var _lbl_title: Label = null
var _lbl_sub: Label = null
var _lbl_pal: Label = null
var _btn_undo: Button = null
var _btn_clear: Button = null
var _btn_cancel: Button = null
var _btn_save: Button = null
var _content_root: MarginContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_load_or_init_image()
	_build_ui()


func _process(delta: float) -> void:
	if not visible:
		return
	if _preview_pivot != null:
		_preview_angle += delta * 0.55
		_preview_pivot.rotation.y = sin(_preview_angle) * 0.42


func get_current_image() -> Image:
	if _img == null:
		_load_or_init_image()
	return _img


func get_current_texture() -> ImageTexture:
	if _tex == null:
		_load_or_init_image()
	return _tex


func get_current_png_bytes() -> PackedByteArray:
	if _img == null:
		_load_or_init_image()
	return _img.save_png_to_buffer()


func open_editor() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_localization()
	visible = true
	if _preview_avatar != null and _tex != null:
		_preview_avatar.set_face_texture(_tex)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.20)


func apply_localization() -> void:
	if _lbl_title != null:
		_lbl_title.text = RoomsI18n.t("fe_title").to_lower()
	if _lbl_sub != null:
		_lbl_sub.text = RoomsI18n.t("fe_sub").to_lower()
	if _lbl_pal != null:
		_lbl_pal.text = RoomsI18n.t("fe_color").to_lower()
	if _btn_undo != null:
		_btn_undo.text = RoomsI18n.t("fe_undo").to_lower()
	if _btn_clear != null:
		_btn_clear.text = RoomsI18n.t("fe_clear").to_lower()
	if _btn_cancel != null:
		_btn_cancel.text = RoomsI18n.t("menu_back_arrow").to_lower()
	if _btn_save != null:
		_btn_save.text = RoomsI18n.t("fe_save").to_lower()
	_sync_tool_buttons()


func _load_or_init_image() -> void:
	_img = Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	if FileAccess.file_exists(SAVE_PATH):
		var loaded := Image.new()
		if loaded.load(SAVE_PATH) == OK:
			loaded.convert(Image.FORMAT_RGBA8)
			if loaded.get_width() != CANVAS_SIZE or loaded.get_height() != CANVAS_SIZE:
				loaded.resize(CANVAS_SIZE, CANVAS_SIZE, Image.INTERPOLATE_NEAREST)
			_img = loaded
		else:
			_apply_preset_classic()
	else:
		_apply_preset_classic()
	_tex = ImageTexture.create_from_image(_img)


func _push_undo() -> void:
	if _img == null:
		return
	_undo_stack.append(_img.get_data())
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()


func _do_undo() -> void:
	if _undo_stack.is_empty():
		return
	var prev_bytes: PackedByteArray = _undo_stack.pop_back()
	_img = Image.create_from_data(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8, prev_bytes)
	_refresh_texture()


func _refresh_texture() -> void:
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
	else:
		_tex.update(_img)
	if _canvas_rect != null:
		_canvas_rect.texture = _tex
	if _preview_avatar != null:
		_preview_avatar.set_face_texture(_tex)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.008, 0.009, 0.013, 0.96)
	add_child(bg)

	var noise := ColorRect.new()
	noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	noise.material = RoomsUI.make_noise_material(0.50, 1.0)
	noise.color = Color.WHITE
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 52)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	_content_root = margin

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 20)
	margin.add_child(outer)

	# Minimalist typographic header
	var hdr_row := HBoxContainer.new()
	outer.add_child(hdr_row)
	var title := Label.new()
	title.text = RoomsI18n.t("fe_title").to_lower()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99, 0.96))
	hdr_row.add_child(title)
	_lbl_title = title

	var sub := Label.new()
	sub.text = RoomsI18n.t("fe_sub").to_lower()
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80, 0.50))
	hdr_row.add_child(sub)
	_lbl_sub = sub

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(1.0, 1.0, 1.0, 0.14)
	outer.add_child(div)

	# Body: Left = Full-height Square Canvas, Right = Minimalist 3D Preview + Typographic Tools
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 44)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	var canvas_aspect := AspectRatioContainer.new()
	canvas_aspect.ratio = 1.0
	canvas_aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	canvas_aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_aspect.size_flags_stretch_ratio = 1.15
	body.add_child(canvas_aspect)

	var canvas_style := StyleBoxFlat.new()
	canvas_style.bg_color = Color(0.92, 0.89, 0.82, 1.0)
	canvas_style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	canvas_style.set_border_width_all(1)
	canvas_style.set_corner_radius_all(0)

	var canvas_frame := PanelContainer.new()
	canvas_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_theme_stylebox_override("panel", canvas_style)
	canvas_aspect.add_child(canvas_frame)

	_canvas_rect = TextureRect.new()
	_canvas_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canvas_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas_rect.texture = _tex
	_canvas_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_rect.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_canvas_rect.gui_input.connect(_on_canvas_gui_input)
	canvas_frame.add_child(_canvas_rect)

	# Right column
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.90
	right.custom_minimum_size = Vector2(360, 0)
	right.add_theme_constant_override("separation", 16)
	body.add_child(right)

	# Frameless-feel 3D preview with razor hairline
	var vp_style := StyleBoxFlat.new()
	vp_style.bg_color = Color(0.012, 0.014, 0.020, 1.0)
	vp_style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	vp_style.set_border_width_all(1)
	vp_style.set_corner_radius_all(0)

	var vp_frame := PanelContainer.new()
	vp_frame.custom_minimum_size = Vector2(0, 220)
	vp_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_frame.add_theme_stylebox_override("panel", vp_style)
	right.add_child(vp_frame)

	var vp_cont := SubViewportContainer.new()
	vp_cont.stretch = true
	vp_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_frame.add_child(vp_cont)

	var sub_vp := SubViewport.new()
	sub_vp.own_world_3d = true
	sub_vp.transparent_bg = false
	sub_vp.size = Vector2i(480, 280)
	sub_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp_cont.add_child(sub_vp)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.020)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.94, 1.0)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	sub_vp.add_child(env_node)

	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-28.0, 32.0, 0.0)
	dl.light_energy = 1.15
	sub_vp.add_child(dl)

	var pcam := Camera3D.new()
	pcam.position = Vector3(0.0, 1.44, -1.16)
	pcam.fov = 38.0
	sub_vp.add_child(pcam)
	pcam.look_at(Vector3(0.0, 1.44, 0.0), Vector3.UP)

	_preview_pivot = Node3D.new()
	sub_vp.add_child(_preview_pivot)
	_preview_avatar = DummiAvatar.new()
	_preview_pivot.add_child(_preview_avatar)
	_preview_avatar.setup(null, null, null, false)
	_preview_avatar.set_face_texture(_tex)

	# Compact minimalist color strip (10 sharp swatches in a single clean row)
	var pal_lbl := Label.new()
	pal_lbl.text = RoomsI18n.t("fe_color").to_lower()
	pal_lbl.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	pal_lbl.add_theme_font_size_override("font_size", 12)
	pal_lbl.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80, 0.50))
	right.add_child(pal_lbl)
	_lbl_pal = pal_lbl

	var pal_row := HBoxContainer.new()
	pal_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal_row.add_theme_constant_override("separation", 6)
	right.add_child(pal_row)

	var colors: Array[Color] = [
		Color(0.07, 0.07, 0.08),
		Color(0.98, 0.98, 0.99),
		Color(0.45, 0.48, 0.54),
		Color(0.88, 0.16, 0.16),
		Color(0.96, 0.52, 0.16),
		Color(0.95, 0.84, 0.22),
		Color(0.20, 0.80, 0.40),
		Color(0.18, 0.76, 0.90),
		Color(0.22, 0.44, 0.92),
		Color(0.64, 0.28, 0.90),
	]
	_color_btns.clear()
	for col in colors:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(24, 24)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.focus_mode = Control.FOCUS_NONE
		cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.border_color = Color(1.0, 1.0, 1.0, 0.18)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(0)
		cb.add_theme_stylebox_override("normal", sb)
		cb.add_theme_stylebox_override("hover", sb)
		cb.add_theme_stylebox_override("pressed", sb)
		cb.pressed.connect(func() -> void:
			_brush_color = col
			_eraser_mode = false
			_sync_tool_buttons()
		)
		pal_row.add_child(cb)
		_color_btns.append({"btn": cb, "style": sb, "color": col})

	var sep_r1 := ColorRect.new()
	sep_r1.custom_minimum_size = Vector2(0, 1)
	sep_r1.color = Color(1.0, 1.0, 1.0, 0.09)
	right.add_child(sep_r1)

	# Flat typographic tools row (matches r00ms menu style)
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 18)
	right.add_child(tool_row)

	_tool_btn_draw = Button.new()
	_tool_btn_draw.custom_minimum_size = Vector2(0, 32)
	RoomsUI.style_link_button(_tool_btn_draw, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_tool_btn_draw.pressed.connect(func() -> void:
		_eraser_mode = false
		_sync_tool_buttons()
	)
	tool_row.add_child(_tool_btn_draw)

	_tool_btn_erase = Button.new()
	_tool_btn_erase.custom_minimum_size = Vector2(0, 32)
	RoomsUI.style_link_button(_tool_btn_erase, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_tool_btn_erase.pressed.connect(func() -> void:
		_eraser_mode = true
		_sync_tool_buttons()
	)
	tool_row.add_child(_tool_btn_erase)

	var btn_undo := Button.new()
	btn_undo.custom_minimum_size = Vector2(0, 32)
	RoomsUI.style_link_button(btn_undo, 16, HORIZONTAL_ALIGNMENT_LEFT)
	btn_undo.pressed.connect(_do_undo)
	tool_row.add_child(btn_undo)
	_btn_undo = btn_undo

	var t_sp := Control.new()
	t_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_row.add_child(t_sp)

	var btn_clear := Button.new()
	btn_clear.custom_minimum_size = Vector2(0, 32)
	RoomsUI.style_link_button(btn_clear, 15, HORIZONTAL_ALIGNMENT_RIGHT)
	btn_clear.add_theme_color_override("font_color", Color(0.92, 0.45, 0.45, 0.72))
	btn_clear.add_theme_color_override("font_hover_color", Color(1.0, 0.62, 0.62, 1.0))
	btn_clear.pressed.connect(func() -> void:
		_push_undo()
		_img.fill(Color(0.0, 0.0, 0.0, 0.0))
		_refresh_texture()
	)
	tool_row.add_child(btn_clear)
	_btn_clear = btn_clear

	# Brush sizes + Presets on one clean minimalist row
	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 16)
	right.add_child(sub_row)

	for sz in [1, 2, 4, 6]:
		var b := Button.new()
		b.text = "%dpx" % sz
		b.custom_minimum_size = Vector2(0, 28)
		RoomsUI.style_link_button(b, 14, HORIZONTAL_ALIGNMENT_LEFT)
		b.pressed.connect(func() -> void:
			_brush_radius = sz
			_sync_tool_buttons()
		)
		sub_row.add_child(b)
		_size_btns[sz] = b

	var sub_sp := Control.new()
	sub_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.add_child(sub_sp)

	var btn_p_classic := Button.new()
	btn_p_classic.text = ":D"
	btn_p_classic.custom_minimum_size = Vector2(0, 28)
	RoomsUI.style_link_button(btn_p_classic, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	btn_p_classic.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84, 0.58))
	btn_p_classic.pressed.connect(func() -> void:
		_push_undo()
		_apply_preset_classic()
		_refresh_texture()
	)
	sub_row.add_child(btn_p_classic)

	var btn_p_shock := Button.new()
	btn_p_shock.text = "O_O"
	btn_p_shock.custom_minimum_size = Vector2(0, 28)
	RoomsUI.style_link_button(btn_p_shock, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	btn_p_shock.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84, 0.58))
	btn_p_shock.pressed.connect(func() -> void:
		_push_undo()
		_apply_preset_shocked()
		_refresh_texture()
	)
	sub_row.add_child(btn_p_shock)

	var btn_p_angry := Button.new()
	btn_p_angry.text = ">:("
	btn_p_angry.custom_minimum_size = Vector2(0, 28)
	RoomsUI.style_link_button(btn_p_angry, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	btn_p_angry.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84, 0.58))
	btn_p_angry.pressed.connect(func() -> void:
		_push_undo()
		_apply_preset_angry()
		_refresh_texture()
	)
	sub_row.add_child(btn_p_angry)

	# Footer save / close (pure flat typographic links, identical to main menu)
	var div_bot := ColorRect.new()
	div_bot.custom_minimum_size = Vector2(0, 1)
	div_bot.color = Color(1.0, 1.0, 1.0, 0.14)
	outer.add_child(div_bot)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	outer.add_child(foot)

	var btn_cancel := Button.new()
	btn_cancel.text = RoomsI18n.t("menu_back_arrow").to_lower()
	btn_cancel.custom_minimum_size = Vector2(140, 42)
	RoomsUI.style_link_button(btn_cancel, 22, HORIZONTAL_ALIGNMENT_LEFT)
	btn_cancel.pressed.connect(func() -> void:
		visible = false
		emit_signal("closed")
	)
	foot.add_child(btn_cancel)
	_btn_cancel = btn_cancel

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)

	var btn_save := Button.new()
	btn_save.text = RoomsI18n.t("fe_save").to_lower()
	btn_save.custom_minimum_size = Vector2(160, 42)
	RoomsUI.style_link_button(btn_save, 22, HORIZONTAL_ALIGNMENT_RIGHT)
	btn_save.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.94))
	btn_save.pressed.connect(_save_and_close)
	foot.add_child(btn_save)
	_btn_save = btn_save

	apply_localization()


func _sync_tool_buttons() -> void:
	var brush_lbl := RoomsI18n.t("fe_brush").to_lower()
	var erase_lbl := RoomsI18n.t("fe_eraser").to_lower()
	if _tool_btn_draw != null:
		_tool_btn_draw.text = ("[%s]" % brush_lbl) if not _eraser_mode else brush_lbl
		_tool_btn_draw.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if not _eraser_mode else Color(0.70, 0.74, 0.80, 0.45))
	if _tool_btn_erase != null:
		_tool_btn_erase.text = ("[%s]" % erase_lbl) if _eraser_mode else erase_lbl
		_tool_btn_erase.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if _eraser_mode else Color(0.70, 0.74, 0.80, 0.45))
	for sz_k in _size_btns.keys():
		var b: Button = _size_btns[sz_k]
		var active := (int(sz_k) == _brush_radius)
		b.text = ("[%dpx]" % int(sz_k)) if active else ("%dpx" % int(sz_k))
		b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98) if active else Color(0.70, 0.74, 0.80, 0.45))
	for entry in _color_btns:
		var sb := entry["style"] as StyleBoxFlat
		var c: Color = entry["color"]
		var is_sel := (not _eraser_mode) and c.is_equal_approx(_brush_color)
		sb.border_color = Color(1.0, 1.0, 1.0, 0.95) if is_sel else Color(1.0, 1.0, 1.0, 0.16)
		sb.set_border_width_all(2 if is_sel else 1)


func _on_canvas_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_push_undo()
				_is_drawing = true
				var erase := _eraser_mode or (mb.button_index == MOUSE_BUTTON_RIGHT)
				var px := _local_to_pixel(mb.position)
				_paint_disc(px, erase)
				_last_px = px
				_refresh_texture()
			else:
				_is_drawing = false
				_last_px = Vector2i(-1, -1)
	elif ev is InputEventMouseMotion and _is_drawing:
		var mm := ev as InputEventMouseMotion
		var erase := _eraser_mode or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		var px := _local_to_pixel(mm.position)
		if _last_px.x >= 0:
			_paint_line(_last_px, px, erase)
		else:
			_paint_disc(px, erase)
		_last_px = px
		_refresh_texture()


func _local_to_pixel(pos: Vector2) -> Vector2i:
	var sz := _canvas_rect.size
	var x := clampi(int(floor((pos.x / maxf(sz.x, 1.0)) * float(CANVAS_SIZE))), 0, CANVAS_SIZE - 1)
	var y := clampi(int(floor((pos.y / maxf(sz.y, 1.0)) * float(CANVAS_SIZE))), 0, CANVAS_SIZE - 1)
	return Vector2i(x, y)


func _paint_line(a: Vector2i, b: Vector2i, erase: bool) -> void:
	var dx := b.x - a.x
	var dy := b.y - a.y
	var steps := maxi(absi(dx), absi(dy))
	if steps == 0:
		_paint_disc(b, erase)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := Vector2i(int(round(lerpf(float(a.x), float(b.x), t))), int(round(lerpf(float(a.y), float(b.y), t))))
		_paint_disc(px, erase)


func _paint_disc(center: Vector2i, erase: bool) -> void:
	var col := Color(0.0, 0.0, 0.0, 0.0) if erase else _brush_color
	var r := _brush_radius
	var r2 := r * r
	for oy in range(-r, r + 1):
		var py := center.y + oy
		if py < 0 or py >= CANVAS_SIZE:
			continue
		for ox in range(-r, r + 1):
			var px := center.x + ox
			if px < 0 or px >= CANVAS_SIZE:
				continue
			if r <= 1 or (ox * ox + oy * oy) <= r2:
				_img.set_pixel(px, py, col)


func _save_and_close() -> void:
	if _img != null:
		_img.save_png(SAVE_PATH)
		var bytes := _img.save_png_to_buffer()
		emit_signal("face_saved", _img, bytes)
	visible = false
	emit_signal("closed")


func _fill_rect_px(x0: int, y0: int, w: int, h: int, col: Color) -> void:
	for y in range(maxi(y0, 0), mini(y0 + h, CANVAS_SIZE)):
		for x in range(maxi(x0, 0), mini(x0 + w, CANVAS_SIZE)):
			_img.set_pixel(x, y, col)


func _apply_preset_classic() -> void:
	_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var blk := Color(0.08, 0.08, 0.08, 1.0)
	# Iconic dummi :D face
	_fill_rect_px(15, 7, 6, 6, blk)
	_fill_rect_px(35, 7, 6, 6, blk)
	# Big open smile outline
	_fill_rect_px(15, 22, 34, 4, blk)
	for y in range(25, 52):
		var dy := float(y - 25) / 26.0
		var half_w := 17.0 * sqrt(maxf(1.0 - dy * dy * 0.88, 0.0))
		var cx := 32.0
		for x in range(14, 51):
			var d := absf(float(x) - cx)
			if d <= half_w and (d >= half_w - 4.0 or y >= 48):
				_img.set_pixel(x, y, blk)


func _apply_preset_shocked() -> void:
	_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var blk := Color(0.08, 0.08, 0.08, 1.0)
	var wht := Color(0.98, 0.98, 0.99, 1.0)
	for cx in [20, 44]:
		for y in range(10, 30):
			for x in range(cx - 8, cx + 9):
				var d := Vector2(float(x - cx), float(y - 20)).length()
				if d <= 8.0 and d >= 5.2:
					_img.set_pixel(x, y, blk)
				elif d < 5.2:
					_img.set_pixel(x, y, wht)
		_fill_rect_px(cx - 2, 18, 4, 4, blk)
	_fill_rect_px(24, 40, 16, 4, blk)


func _apply_preset_angry() -> void:
	_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var blk := Color(0.08, 0.08, 0.08, 1.0)
	for i in range(12):
		_fill_rect_px(12 + i, 12 + i / 2, 3, 3, blk)
		_fill_rect_px(50 - i, 12 + i / 2, 3, 3, blk)
	_fill_rect_px(16, 22, 6, 6, blk)
	_fill_rect_px(42, 22, 6, 6, blk)
	for x in range(18, 46):
		var dx := float(x - 32) / 14.0
		var y := int(round(40.0 + dx * dx * 8.0))
		_fill_rect_px(x, y, 2, 4, blk)
