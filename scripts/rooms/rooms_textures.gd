class_name RoomsTextures
extends RefCounted

## Generates procedural wall/floor textures and creepy entity face sprites in pure GDScript.


static func make_wall_texture() -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40401
	for y in range(sz):
		for x in range(sz):
			var speckle := rng.randf_range(-0.022, 0.022)
			var base := 0.50 + speckle
			var v := clampf(base, 0.12, 0.88)
			img.set_pixel(x, y, Color(v * 0.95, v * 0.97, v * 1.02, 1.0))
	return ImageTexture.create_from_image(img)


static func make_floor_texture() -> ImageTexture:
	# Iconic Rooms & Doors dark navy speckled office carpet
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 80802
	for y in range(sz):
		for x in range(sz):
			var weave := 0.015 if ((x + y) % 4 == 0 or y % 4 == 0) else -0.01
			var speck := rng.randf_range(-0.045, 0.05)
			if rng.randf() < 0.08:
				speck += 0.06
			var b := clampf(0.16 + weave + speck, 0.05, 0.36)
			img.set_pixel(x, y, Color(b * 0.48, b * 0.72, clampf(b * 1.38, 0.08, 0.52), 1.0))
	return ImageTexture.create_from_image(img)


static func make_tile_floor_texture() -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 50505
	for y in range(sz):
		for x in range(sz):
			var seam := (x % 32 == 0 or y % 32 == 0)
			var base := 0.42 if seam else (0.74 + rng.randf_range(-0.035, 0.035))
			img.set_pixel(x, y, Color(base * 0.96, base * 0.98, base, 1.0))
	return ImageTexture.create_from_image(img)


static func make_metal_grate_texture() -> ImageTexture:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var diag := ((x + y) % 8 < 2) or ((x - y + 64) % 8 < 2)
			var base := 0.34 if diag else 0.22
			img.set_pixel(x, y, Color(base * 0.78, base * 0.92, base * 1.15, 1.0))
	return ImageTexture.create_from_image(img)


static func make_surface_normal(seed_val: int, bump_strength: float = 1.0, grid_step: int = 0) -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in range(sz):
		for x in range(sz):
			var h := 0.5 + rng.randf_range(-0.06, 0.06)
			if grid_step > 0 and (x % grid_step == 0 or y % grid_step == 0):
				h = 0.25
			h = clampf(h, 0.0, 1.0)
			img.set_pixel(x, y, Color(h, h, h, 1.0))
	img.bump_map_to_normal_map(bump_strength)
	return ImageTexture.create_from_image(img)


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
