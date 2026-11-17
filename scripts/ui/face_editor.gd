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

var _brush_color := Color(0.08, 0.08, 0.08, 1.0)
var _brush_radius := 2
var _eraser_mode := false
var _is_drawing := false
var _last_px := Vector2i(-1, -1)

var _canvas_rect: TextureRect = null
var _preview_avatar: DummiAvatar = null
var _preview_pivot: Node3D = null
var _preview_angle := 0.0
var _size_btns: Dictionary = {}
var _tool_btn_draw: Button = null
var _tool_btn_erase: Button = null
var _lbl_title: Label = null
var _lbl_sub: Label = null
var _lbl_pal: Label = null
var _btn_undo: Button = null
var _btn_clear: Button = null
var _btn_cancel: Button = null
var _btn_save: Button = null
var _panel: PanelContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	apply_localization()
	visible = true
	if _preview_avatar != null and _tex != null:
		_preview_avatar.set_face_texture(_tex)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	if _panel != null:
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.94, 0.94)
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func apply_localization() -> void:
	if _lbl_title != null:
		_lbl_title.text = RoomsI18n.t("fe_title")
	if _lbl_sub != null:
		_lbl_sub.text = RoomsI18n.t("fe_sub")
	if _lbl_pal != null:
		_lbl_pal.text = RoomsI18n.t("fe_color")
	if _tool_btn_draw != null:
		_tool_btn_draw.text = RoomsI18n.t("fe_brush")
	if _tool_btn_erase != null:
		_tool_btn_erase.text = RoomsI18n.t("fe_eraser")
	if _btn_undo != null:
		_btn_undo.text = RoomsI18n.t("fe_undo")
	if _btn_clear != null:
		_btn_clear.text = RoomsI18n.t("fe_clear")
	if _btn_cancel != null:
		_btn_cancel.text = RoomsI18n.t("menu_back_arrow")
	if _btn_save != null:
		_btn_save.text = RoomsI18n.t("fe_save")


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
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.012, 0.017, 0.94)
	add_child(bg)

	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.material = RoomsUI.make_noise_material(0.45, 1.0)
	noise.color = Color.WHITE
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 520)
	panel.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.035, 0.04, 0.052, 0.96), Color(1.0, 1.0, 1.0, 0.16), 6, 1))
	center.add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	# Header
	var hdr_row := HBoxContainer.new()
	outer.add_child(hdr_row)
	var title := Label.new()
	title.text = RoomsI18n.t("fe_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Medium.ttf"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
	hdr_row.add_child(title)
	_lbl_title = title

	var sub := Label.new()
	sub.text = RoomsI18n.t("fe_sub")
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", preload("res://assets/fonts/Montserrat-Regular.ttf"))
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.66, 0.72, 0.80))
	hdr_row.add_child(sub)
	_lbl_sub = sub

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(1.0, 1.0, 1.0, 0.18)
	outer.add_child(div)

	# Body: Left = Drawing Canvas, Right = Live 3D Dummi Preview + Tools
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	# Canvas frame (neutral warm background representing dummi head color)
	var canvas_frame := PanelContainer.new()
	canvas_frame.custom_minimum_size = Vector2(360, 360)
	canvas_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	canvas_frame.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.92, 0.89, 0.82, 1.0), Color(1.0, 1.0, 1.0, 0.35), 4, 2))
	body.add_child(canvas_frame)

	_canvas_rect = TextureRect.new()
	_canvas_rect.custom_minimum_size = Vector2(352, 352)
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
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)

	# Live 3D dummi preview
	var vp_frame := PanelContainer.new()
	vp_frame.custom_minimum_size = Vector2(0, 172)
	vp_frame.add_theme_stylebox_override("panel", RoomsUI.make_panel_style(Color(0.02, 0.024, 0.032, 1.0), Color(1.0, 1.0, 1.0, 0.14), 4, 1))
	right.add_child(vp_frame)

	var vp_cont := SubViewportContainer.new()
	vp_cont.stretch = true
	vp_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_frame.add_child(vp_cont)

	var sub_vp := SubViewport.new()
	sub_vp.own_world_3d = true
	sub_vp.transparent_bg = false
	sub_vp.size = Vector2i(320, 172)
	sub_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp_cont.add_child(sub_vp)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.036, 0.05)
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
	pcam.position = Vector3(0.0, 1.44, -1.12)
	pcam.fov = 38.0
	sub_vp.add_child(pcam)
	pcam.look_at(Vector3(0.0, 1.44, 0.0), Vector3.UP)

	_preview_pivot = Node3D.new()
	sub_vp.add_child(_preview_pivot)
	_preview_avatar = DummiAvatar.new()
	_preview_pivot.add_child(_preview_avatar)
	_preview_avatar.setup(null, null, null, false)
	_preview_avatar.set_face_texture(_tex)

	# Palette colors
	var pal_lbl := Label.new()
	pal_lbl.text = RoomsI18n.t("fe_color")
	pal_lbl.add_theme_font_size_override("font_size", 12)
	pal_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.80))
	right.add_child(pal_lbl)
	_lbl_pal = pal_lbl

	var pal_grid := GridContainer.new()
	pal_grid.columns = 7
	pal_grid.add_theme_constant_override("h_separation", 6)
	pal_grid.add_theme_constant_override("v_separation", 6)
	right.add_child(pal_grid)

	var colors: Array[Color] = [
		Color(0.07, 0.07, 0.08),
		Color(0.98, 0.98, 0.99),
		Color(0.45, 0.48, 0.54),
		Color(0.92, 0.16, 0.16),
		Color(1.0, 0.52, 0.12),
		Color(0.98, 0.86, 0.18),
		Color(0.18, 0.84, 0.36),
		Color(0.16, 0.82, 0.94),
		Color(0.18, 0.42, 0.96),
		Color(0.64, 0.24, 0.94),
		Color(0.96, 0.36, 0.68),
		Color(0.54, 0.32, 0.16),
		Color(0.98, 0.76, 0.60),
		Color(0.14, 0.42, 0.22),
	]
	for col in colors:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(36, 26)
		cb.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.border_color = Color(1.0, 1.0, 1.0, 0.35)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		cb.add_theme_stylebox_override("normal", sb)
		cb.add_theme_stylebox_override("hover", sb)
		cb.add_theme_stylebox_override("pressed", sb)
		cb.pressed.connect(func() -> void:
			_brush_color = col
			_eraser_mode = false
			_sync_tool_buttons()
		)
		pal_grid.add_child(cb)

	# Tools & Brush Sizes
	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 6)
	right.add_child(tool_row)

	_tool_btn_draw = Button.new()
	_tool_btn_draw.text = "кисть"
	_tool_btn_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(_tool_btn_draw, Color(0.85, 0.90, 0.98), 12)
	_tool_btn_draw.pressed.connect(func() -> void:
		_eraser_mode = false
		_sync_tool_buttons()
	)
	tool_row.add_child(_tool_btn_draw)

	_tool_btn_erase = Button.new()
	_tool_btn_erase.text = "ластик"
	_tool_btn_erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(_tool_btn_erase, Color(0.85, 0.90, 0.98), 12)
	_tool_btn_erase.pressed.connect(func() -> void:
		_eraser_mode = true
		_sync_tool_buttons()
	)
	tool_row.add_child(_tool_btn_erase)

	var btn_undo := Button.new()
	btn_undo.text = RoomsI18n.t("fe_undo")
	btn_undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_undo, Color(0.85, 0.90, 0.98), 12)
	btn_undo.pressed.connect(_do_undo)
	tool_row.add_child(btn_undo)
	_btn_undo = btn_undo

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	right.add_child(size_row)
	for sz in [1, 2, 4, 6]:
		var b := Button.new()
		b.text = "%dpx" % sz
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		RoomsUI.style_button(b, Color(0.80, 0.86, 0.94), 12)
		b.pressed.connect(func() -> void:
			_brush_radius = sz
			_sync_tool_buttons()
		)
		size_row.add_child(b)
		_size_btns[sz] = b

	# Presets row
	var pre_row := HBoxContainer.new()
	pre_row.add_theme_constant_override("separation", 6)
	right.add_child(pre_row)

	var btn_p_classic := Button.new()
	btn_p_classic.text = ":D"
	btn_p_classic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_p_classic, Color(0.75, 0.85, 0.95), 12)
	btn_p_classic.pressed.connect(func() -> void:
		_push_undo()
		_apply_preset_classic()
		_refresh_texture()
	)
	pre_row.add_child(btn_p_classic)

	var btn_p_shock := Button.new()
	btn_p_shock.text = "O_O"
	btn_p_shock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_p_shock, Color(0.75, 0.85, 0.95), 12)
	btn_p_shock.pressed.connect(func() -> void:
		_push_undo()
		_apply_preset_shocked()
		_refresh_texture()
	)
	pre_row.add_child(btn_p_shock)

	var btn_p_angry := Button.new()
	btn_p_angry.text = ">:("
	btn_p_angry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_p_angry, Color(0.75, 0.85, 0.95), 12)
	btn_p_angry.pressed.connect(func() -> void:
		_push_undo()
		_apply_preset_angry()
		_refresh_texture()
	)
	pre_row.add_child(btn_p_angry)

	var btn_clear := Button.new()
	btn_clear.text = RoomsI18n.t("fe_clear")
	btn_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoomsUI.style_button(btn_clear, Color(1.0, 0.55, 0.50), 12)
	btn_clear.pressed.connect(func() -> void:
		_push_undo()
		_img.fill(Color(0.0, 0.0, 0.0, 0.0))
		_refresh_texture()
	)
	pre_row.add_child(btn_clear)
	_btn_clear = btn_clear

	# Footer save / close
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	outer.add_child(foot)

	var btn_cancel := Button.new()
	btn_cancel.text = RoomsI18n.t("menu_back_arrow")
	btn_cancel.custom_minimum_size = Vector2(140, 40)
	RoomsUI.style_link_button(btn_cancel, 20, HORIZONTAL_ALIGNMENT_LEFT)
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
	btn_save.text = RoomsI18n.t("fe_save")
	btn_save.custom_minimum_size = Vector2(180, 40)
	RoomsUI.style_button(btn_save, Color(0.32, 1.0, 0.56), 15)
	btn_save.pressed.connect(_save_and_close)
	foot.add_child(btn_save)
	_btn_save = btn_save

	apply_localization()
	_sync_tool_buttons()


func _sync_tool_buttons() -> void:
	if _tool_btn_draw != null:
		_tool_btn_draw.modulate = Color(1.0, 1.0, 1.0) if not _eraser_mode else Color(0.65, 0.68, 0.74)
	if _tool_btn_erase != null:
		_tool_btn_erase.modulate = Color(1.0, 1.0, 1.0) if _eraser_mode else Color(0.65, 0.68, 0.74)
	for sz_k in _size_btns.keys():
		var b: Button = _size_btns[sz_k]
		b.modulate = Color(0.45, 1.0, 0.65) if int(sz_k) == _brush_radius else Color(0.75, 0.78, 0.84)


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
