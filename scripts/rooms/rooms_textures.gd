class_name RoomsTextures
extends RefCounted

## Generates procedural wall/floor textures and creepy entity face sprites in pure GDScript.


static func _finalize_tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func make_wall_texture() -> ImageTexture:
	# Subtle painted office plaster with faint drywall panel seams & fine roller grain
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40401
	for y in range(sz):
		var y_band := sin(float(y) * 0.049) * 0.012
		for x in range(sz):
			var seam := -0.055 if (x % 128 < 2) else 0.0
			var macro := sin(float(x) * 0.036 + float(y) * 0.022) * 0.014
			var speckle := rng.randf_range(-0.026, 0.026)
			var base := 0.52 + y_band + macro + seam + speckle
			var v := clampf(base, 0.14, 0.88)
			img.set_pixel(x, y, Color(v * 0.94, v * 0.97, v * 1.03, 1.0))
	return _finalize_tex(img)


static func make_floor_texture() -> ImageTexture:
	# Iconic Rooms & Doors deep navy office carpet tiles with woven cross-hatch & subtle tile seams
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 80802
	for y in range(sz):
		var seam_y := (y % 128 < 2)
		for x in range(sz):
			var seam_x := (x % 128 < 2)
			var tile_alt := 0.010 if (((x / 128) + (y / 128)) % 2 == 0) else -0.010
			var weave := 0.016 if ((x + y) % 4 == 0 or (x - y + sz) % 4 == 0) else -0.012
			var speck := rng.randf_range(-0.042, 0.048)
			if rng.randf() < 0.075:
				speck += 0.065
			var seam_drop := -0.055 if (seam_x or seam_y) else 0.0
			var b := clampf(0.165 + tile_alt + weave + speck + seam_drop, 0.04, 0.38)
			img.set_pixel(x, y, Color(b * 0.44, b * 0.68, clampf(b * 1.42, 0.07, 0.56), 1.0))
	return _finalize_tex(img)


static func make_tile_floor_texture() -> ImageTexture:
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 50505
	for y in range(sz):
		var sy := (y % 64 < 3)
		for x in range(sz):
			var sx := (x % 64 < 3)
			var bevel := 0.04 if (x % 64 == 3 or y % 64 == 3) else (-0.04 if (x % 64 == 63 or y % 64 == 63) else 0.0)
			var tint := 0.018 if (((x / 64) + (y / 64)) % 2 == 0) else -0.018
			var base := 0.30 if (sx or sy) else (0.72 + tint + bevel + rng.randf_range(-0.03, 0.03))
			img.set_pixel(x, y, Color(base * 0.94, base * 0.97, base * 1.01, 1.0))
	return _finalize_tex(img)


static func make_ceiling_texture() -> ImageTexture:
	# Acoustic drop-ceiling office tiles with metallic T-bar grid & pinhole texture
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for y in range(sz):
		var bar_y := (y % 128 < 4)
		for x in range(sz):
			var bar_x := (x % 128 < 4)
			if bar_x or bar_y:
				var m := 0.24 + rng.randf_range(-0.015, 0.015)
				img.set_pixel(x, y, Color(m * 0.92, m * 0.96, m * 1.05, 1.0))
			else:
				var pit := -0.075 if rng.randf() < 0.055 else 0.0
				var v := clampf(0.165 + pit + rng.randf_range(-0.018, 0.018), 0.06, 0.28)
				img.set_pixel(x, y, Color(v * 0.90, v * 0.94, v * 1.04, 1.0))
	return _finalize_tex(img)


static func make_wood_texture() -> ImageTexture:
	# Flowing organic wood grain & plank seams for doors, desks, bookshelves
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	for y in range(sz):
		var plank_seam := -0.14 if (y % 64 < 2) else 0.0
		var plank_tone := float((y / 64) % 3 - 1) * 0.03
		for x in range(sz):
			var warp := sin(float(x) * 0.045 + float(y / 64) * 1.7) * 4.5
			var grain := sin((float(y) + warp) * 0.62) * 0.055 + sin((float(y) * 1.45 - warp) * 0.35) * 0.035
			var micro := rng.randf_range(-0.022, 0.022)
			var b := clampf(0.76 + grain + plank_tone + plank_seam + micro, 0.25, 1.0)
			img.set_pixel(x, y, Color(b, b * 0.94, b * 0.86, 1.0))
	return _finalize_tex(img)


static func make_metal_texture() -> ImageTexture:
	# Brushed steel & subtle industrial wear for lockers, hinges, frames
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91919
	for y in range(sz):
		var streak := rng.randf_range(-0.04, 0.04)
		for x in range(sz):
			var fine := sin(float(x) * 0.14 + float(y) * 0.04) * 0.022
			var scratch := 0.08 if (rng.randf() < 0.008) else 0.0
			var v := clampf(0.76 + streak + fine + scratch + rng.randf_range(-0.025, 0.025), 0.38, 1.0)
			img.set_pixel(x, y, Color(v * 0.94, v * 0.97, v * 1.03, 1.0))
	return _finalize_tex(img)


static func make_cardboard_texture() -> ImageTexture:
	# Corrugated kraft cardboard fibers
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 65432
	for y in range(sz):
		var rib := sin(float(y) * 0.85) * 0.028
		for x in range(sz):
			var fleck := -0.06 if rng.randf() < 0.04 else rng.randf_range(-0.025, 0.025)
			var v := clampf(0.80 + rib + fleck, 0.45, 0.98)
			img.set_pixel(x, y, Color(v, v * 0.95, v * 0.86, 1.0))
	return _finalize_tex(img)


static func make_lamp_texture() -> ImageTexture:
	# Recessed fluorescent troffer diffuser with glowing dual tubes & louver ribs
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		var fy := float(y) / float(sz)
		# Two bright horizontal fluorescent tube bands
		var t1 := exp(-pow((fy - 0.30) * 6.5, 2.0))
		var t2 := exp(-pow((fy - 0.70) * 6.5, 2.0))
		var tube := clampf(0.52 + (t1 + t2) * 0.58, 0.0, 1.0)
		for x in range(sz):
			var border := (x < 4 or x >= sz - 4 or y < 4 or y >= sz - 4)
			var louver := (x % 32 < 2) or (absi(y - 64) < 2)
			if border:
				img.set_pixel(x, y, Color(0.28, 0.31, 0.36, 1.0))
			elif louver:
				img.set_pixel(x, y, Color(0.52, 0.58, 0.64, 1.0))
			else:
				img.set_pixel(x, y, Color(tube * 0.92, tube * 0.97, tube, 1.0))
	return _finalize_tex(img)


static func make_metal_grate_texture() -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var diag := ((x + y) % 12 < 3) or ((x - y + sz) % 12 < 3)
			var base := 0.38 if diag else 0.18
			img.set_pixel(x, y, Color(base * 0.80, base * 0.93, base * 1.15, 1.0))
	return _finalize_tex(img)


static func make_surface_normal(seed_val: int, bump_strength: float = 1.0, grid_step: int = 0) -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in range(sz):
		for x in range(sz):
			var h := 0.5 + rng.randf_range(-0.07, 0.07)
			if grid_step > 0 and (x % grid_step < 2 or y % grid_step < 2):
				h = 0.20
			h = clampf(h, 0.0, 1.0)
			img.set_pixel(x, y, Color(h, h, h, 1.0))
	img.bump_map_to_normal_map(bump_strength)
	return _finalize_tex(img)


static func make_wood_normal(seed_val: int = 77123) -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in range(sz):
		var seam := (y % 32 < 2)
		for x in range(sz):
			var h := 0.20 if seam else clampf(0.5 + sin(float(y) * 0.95 + sin(float(x) * 0.08) * 2.5) * 0.12 + rng.randf_range(-0.03, 0.03), 0.0, 1.0)
			img.set_pixel(x, y, Color(h, h, h, 1.0))
	img.bump_map_to_normal_map(2.2)
	return _finalize_tex(img)


static func make_metal_normal(seed_val: int = 91919) -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in range(sz):
		var line_h := rng.randf_range(-0.06, 0.06)
		for x in range(sz):
			var h := clampf(0.5 + line_h + rng.randf_range(-0.025, 0.025), 0.0, 1.0)
			img.set_pixel(x, y, Color(h, h, h, 1.0))
	img.bump_map_to_normal_map(1.6)
	return _finalize_tex(img)


static func make_a60_frames() -> Array[ImageTexture]:
	var frames: Array[ImageTexture] = []
	var sz := 128
	for f in range(5):
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 6000 + f * 137
		var cx := 64.0 + rng.randf_range(-3.0, 3.0)
		var cy := 64.0 + rng.randf_range(-3.0, 3.0)
		for y in range(sz):
			for x in range(sz):
				var dx := (float(x) - cx) / 52.0
				var dy := (float(y) - cy) / 56.0
				var r := sqrt(dx * dx + dy * dy)
				if r > 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var edge_a := clampf((1.0 - r) * 2.2, 0.0, 1.0)
				# Distorted eyes and gaping mouth
				var le := Vector2(dx + 0.32 + sin(float(f) * 1.7) * 0.05, dy + 0.22).length()
				var re := Vector2(dx - 0.32 - cos(float(f) * 1.3) * 0.05, dy + 0.22).length()
				var mouth := Vector2(dx * 0.72, (dy - 0.34) * (0.65 if f % 2 == 0 else 0.95)).length()

				var col := Color(0.55, 0.04, 0.04, edge_a * 0.92)
				var noise := rng.randf_range(-0.18, 0.18)
				col.r = clampf(col.r + noise + (1.0 - r) * 0.3, 0.05, 1.0)

				if le < 0.20 or re < 0.20:
					col = Color(0.02, 0.0, 0.0, 1.0)
					if le < 0.06 or re < 0.06:
						col = Color(1.0, 0.92, 0.92, 1.0)
				elif mouth < 0.30:
					var teeth := sin(dx * 34.0 + float(f)) > 0.35 and absf(dy - 0.34) > 0.12
					col = Color(0.95, 0.85, 0.85, 1.0) if teeth else Color(0.02, 0.0, 0.0, 1.0)
				elif int(y + f * 7) % 9 == 0 and rng.randf() > 0.55:
					col = Color(0.95, 0.15, 0.15, edge_a)

				img.set_pixel(x, y, col)
		frames.append(ImageTexture.create_from_image(img))
	return frames


static func make_a90_textures() -> Dictionary:
	var sz := 128
	var out := {}
	for mode in ["warn", "rage"]:
		var is_rage: bool = (String(mode) == "rage")
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9090 if not is_rage else 9999
		for y in range(sz):
			for x in range(sz):
				var dx := (float(x) - 64.0) / 56.0
				var dy := (float(y) - 64.0) / 56.0
				var r := sqrt(dx * dx + dy * dy)
				if r > 0.98:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var base := 0.86 + rng.randf_range(-0.12, 0.12)
				var col := Color(base, 0.08 if is_rage else base, 0.08 if is_rage else base, clampf((1.0 - r) * 3.0, 0.0, 1.0))
				var le := Vector2(dx + 0.28, dy + 0.18).length()
				var re := Vector2(dx - 0.28, dy + 0.18).length()
				var mouth := Vector2(dx * 0.65, (dy - 0.32) * (0.55 if is_rage else 1.2)).length()
				if le < 0.19 or re < 0.19 or mouth < 0.28:
					col = Color(0.03, 0.01, 0.01, 1.0)
					if (le < 0.05 or re < 0.05) and is_rage:
						col = Color(1.0, 0.25, 0.25, 1.0)
				if r > 0.82 and is_rage:
					col = Color(1.0, 0.15, 0.15, 1.0)
				img.set_pixel(x, y, col)
		out[mode] = ImageTexture.create_from_image(img)
	return out


static func make_a120_frames() -> Array[ImageTexture]:
	var frames: Array[ImageTexture] = []
	var sz := 128
	for f in range(2):
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 12000 + f * 53
		for y in range(sz):
			for x in range(sz):
				var dx := (float(x) - 64.0) / 50.0
				var dy := (float(y) - 64.0) / 54.0
				var r := sqrt(dx * dx + dy * dy)
				if r > 0.96:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var edge_a := clampf((1.0 - r) * 2.5, 0.0, 1.0)
				var jitter := rng.randf_range(-0.07, 0.07)
				var col := Color(0.88 + jitter, 0.94 + jitter, 1.0, edge_a * 0.92)
				# Sketchy spiral / wide grin
				var le := Vector2(dx + 0.28, dy + 0.18).length()
				var re := Vector2(dx - 0.28, dy + 0.18).length()
				var smile_y := 0.18 + dx * dx * 0.48
				var on_smile := absf(dy - smile_y) < (0.09 + (0.03 if f == 1 else 0.0)) and absf(dx) < 0.62
				if le < 0.16 or re < 0.16 or on_smile:
					col = Color(0.03, 0.04, 0.06, 1.0)
				elif absf(r - 0.86) < 0.07 and rng.randf() > 0.35:
					col = Color(0.05, 0.07, 0.10, edge_a)
				img.set_pixel(x, y, col)
		frames.append(ImageTexture.create_from_image(img))
	return frames
