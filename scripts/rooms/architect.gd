class_name RoomsArchitect
extends RefCounted

## "Архитектор" — Guiding-Light style death analyst that explains how and why the player died.

var deaths_total := 0
var best_room := 0
var deaths_by_cause: Dictionary = {}


func record_progress(room_num: int) -> void:
	if room_num > best_room:
		best_room = room_num


func build_death_sequence(cause: String, room_num: int, ctx: Dictionary = {}) -> Dictionary:
	deaths_total += 1
	record_progress(room_num)

	var cause_count: int = int(deaths_by_cause.get(cause, 0)) + 1
	deaths_by_cause[cause] = cause_count

	var lines: Array[String] = []
	var accent := Color(1.0, 0.88, 0.36)
	var title := "АРХИТЕКТОР  •  A-%03d" % room_num
	var summary := ""

	var lockers_here: int = int(ctx.get("room_lockers_count", 0))
	var cur_battery: float = float(ctx.get("battery", 100.0))
	var has_gummy: bool = bool(ctx.get("has_gummy", false))

	if cause == "A-60":
		accent = Color(1.0, 0.86, 0.34)
		summary = "Когда усиливается статика и виньетка (до A-100) или слышен гул — прячьтесь в шкаф [ЛКМ]!"
		if cause_count == 1:
			lines.append("...Что это было? Кажется, тебя настиг MultiMonster (A-60) на A-%03d." % room_num)
			lines.append("До A-100 перед его атакой экран темнеет по краям и усиливается статика — это твой сигнал бежать к укрытию.")
			lines.append("Он несётся до самой закрытой двери впереди и выламывает её, оставляя отпечаток своего лица. Если он увидит тебя в прямой видимости — убьёт мгновенно!")
			if lockers_here > 0:
				lines.append("В той комнате стояло %d шкаф(а) — ныряй внутрь на [ЛКМ] или хотя бы уйди с линии его взгляда за стену." % lockers_here)
			else:
				lines.append("Беги на [Shift] к шкафу или спрячься за стеной/перегородкой — без прямой видимости он тебя не достанет.")
		else:
			lines.append("...Снова A-60 на A-%03d (смертей: %d). Не забывай, что после A-100 статики предупреждения уже не будет — слушай приближающийся гул!" % [room_num, cause_count])
			lines.append("При первых помехах или тряске экрана сразу ищи шкаф [ЛКМ] и не выходи, пока он не выбьет следующую дверь.")

	elif cause == "A-60'":
		accent = Color(1.0, 0.90, 0.42)
		summary = "MultiMonster Prime (A-60') появляется после A-049 следом за атакой A-60: мерцание фонарика предупреждает о нём!"
		if cause_count == 1:
			lines.append("...Это был MultiMonster Prime (A-60') на A-%03d. Он тихий и приходит следом за обычным A-60 начиная с комнаты A-050." % room_num)
			lines.append("Перед его атакой фонарики начинают постоянно мерцать. Если прячешься под столом, у него есть 90% шанс обжечь тебя (20 урона).")
			lines.append("Он может прийти несколько раз подряд (до 4 раз к A-900). В шкафу перезаходи [S] -> [ЛКМ], если слышишь Тьму, пока мерцание не прекратится!")
		else:
			lines.append("...Снова MultiMonster Prime (A-60') на A-%03d (смертей: %d)." % [room_num, cause_count])
			lines.append("Замигал фонарик после A-60 — прячься в шкаф или холодильник! Нанесёт меньше урона, но серия атак способна добить.")

	elif cause == "A-90":
		accent = Color(1.0, 0.88, 0.38)
		summary = "При знаке СТОП замрите полностью — отпустите клавиши и не шевелите мышью!"
		var moved: bool = bool(ctx.get("a90_moved", false))
		var turned: bool = bool(ctx.get("a90_turned", false))

		if moved and turned:
			lines.append("...В комнате A-%03d перед тобой вспыхнул A-90. Ты продолжил идти И дёрнул камеру." % room_num)
		elif turned:
			lines.append("...В комнате A-%03d тебя погубило движение камеры — когда появился знак СТОП, ты пошевелил мышью." % room_num)
		elif moved:
			lines.append("...На подходе к A-%03d появился A-90 — ты не успел отпустить клавишу ходьбы." % room_num)
		else:
			lines.append("...Ты пал от A-90 в комнате A-%03d." % room_num)

		if cause_count == 1:
			lines.append("Он возникает прямо перед глазами: сначала мелькает его искажённое лицо с помехами...")
			lines.append("А затем загорается красный знак СТОП. В этот миг замри полностью — убери пальцы с клавиш и останови мышь!")
		else:
			lines.append("...Снова Паралич (смертей: %d). Даже если рядом гремит другой монстр — сначала переживи знак СТОП." % cause_count)

	elif cause == "A-120":
		accent = Color(1.0, 0.90, 0.42)
		summary = "При громком стуке и плавающей статике прячьтесь в шкаф [ЛКМ] и переждите до 3 отскоков A-120!"
		var rebounds_done: bool = bool(ctx.get("a120_rebounded", false))
		if cause_count == 1:
			lines.append("...На A-%03d тебя встретил A-120 (Happy Scribble) — и запаса сил не хватило." % room_num)
			lines.append("Обычно его касание вызывает «Варп»: отнимает ~40 HP и отбрасывает на 3–4 комнаты назад.")
			lines.append("Перед атакой он гремит и фонит статикой с плавающим питчем, подпрыгивая лицом под далёкие барабаны.")
			lines.append("Он летит к живым — даже в шкафах — уходит назад и может вернуться до 3 раз. Пережди его в шкафу [ЛКМ]!")
		else:
			lines.append("...И снова A-120 на A-%03d (смертей: %d)." % [room_num, cause_count])
			if rebounds_done:
				lines.append("Он подловил тебя на развороте — до 3 отскоков! Не вылезай из шкафа [ЛКМ], пока волнистый гул и барабаны не стихнут.")
			else:
				lines.append("Как только услышишь громкие удары и статику с меняющимся питчем — беги в шкаф: вблизи его волны шума оглушают.")

	elif cause == "The Darkness":
		accent = Color(1.0, 0.36, 0.36)
		summary = "Начиная с A-021 не сиди в укрытии слишком долго! Обычный фонарик [ПКМ] временно отгоняет Тьму (но сажает режим в слабый)."
		if cause_count == 1:
			lines.append("...В шкафу или укрытии тебя настигла Тьма (The Darkness) на A-%03d." % room_num)
			lines.append("После 21-й комнаты долго сидеть в укрытии опасно: чем дальше ты зашёл, тем быстрее просыпается шёпот.")
			lines.append("Как только услышишь нарастающий шёпот и увидишь красный глаз с красной виньеткой — выходи [W] или [S], либо включи ОБЫЧНЫЙ фонарик [1]+[ПКМ]!")
			lines.append("Обычный фонарик временно остановит Тьму (и перейдёт в слабый режим — повторно уже не спасёт). Трясосвет против неё бесполезен!")
		else:
			lines.append("...Снова Тьма (The Darkness) на A-%03d (смертей: %d)." % [room_num, cause_count])
			lines.append("Услышал нарастающий шёпот — выпрыгивай из укрытия [S]/[W], пока монстр снаружи уже пронёсся, или подсвети обычным фонариком [1]+[ПКМ] в самом крайнем случае.")

	else:
		lines.append("Твой забег оборвался в комнате A-%03d (причина: %s)." % [room_num, cause])
		lines.append("Будь внимателен к свету и звукам в коридорах Секции A.")
		summary = "Наблюдайте за светом ламп и прислушивайтесь к коридору."

	if cur_battery < 8.0 and not has_gummy:
		lines.append("Совет по свету: твой фонарик почти разрядился. Собирай батарейки (нужно 2 шт.) и нажимай [R] для зарядки, либо зажимай [ПКМ] на Трясосвете.")
	elif room_num >= 100:
		lines.append("Дойти до A-%03d — сильный результат (рекорд: A-%03d). Выход на A-200 уже близко." % [room_num, best_room])
	elif deaths_total == 1:
		lines.append("Я буду здесь после каждой ошибки, чтобы подсказать, что пошло не так. Попробуй снова.")

	return {
		"title": title,
		"accent": accent,
		"lines": lines,
		"summary": summary,
		"deaths_total": deaths_total,
		"cause_count": cause_count,
	}


static func make_void_shader_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * 1.7777, uv.y);
	vec2 star_pos = vec2(0.0, 0.165);
	vec2 d = p - star_pos;
	float r = length(d);

	// Obsidian void base
	vec3 col = vec3(0.006, 0.005, 0.003);

	// Downward volumetric golden god-rays and haze from the star
	float ang = atan(d.x, max(d.y, 0.001));
	float ray_mask = smoothstep(-0.08, 0.12, d.y) * exp(-r * 1.35);
	float rays = 0.55 + 0.45 * sin(ang * 13.0 + TIME * 0.22) * sin(ang * 21.0 - TIME * 0.15);
	rays *= smoothstep(1.25, 0.08, abs(ang));

	// Faint ghostly corridor pillars in the golden fog behind the light
	float ax = abs(uv.x - 0.5);
	float pillar_l = exp(-pow((ax - 0.15) * 34.0, 2.0)) + 0.7 * exp(-pow((ax - 0.23) * 28.0, 2.0));
	float pillar_frame = smoothstep(0.18, 0.36, uv.y) * smoothstep(0.88, 0.38, uv.y);
	float lintel = exp(-pow((uv.y - 0.28) * 38.0, 2.0)) * smoothstep(0.28, 0.08, ax);
	float arch_mist = clamp(pillar_l * pillar_frame + lintel * 0.85, 0.0, 1.0);

	// Golden star orb + 4-point cross flare + atmospheric halo
	float core = exp(-r * r * 1150.0);
	float orb = exp(-r * 19.0);
	float halo = exp(-r * 3.8);
	float flare = exp(-abs(d.x) * 44.0) * exp(-abs(d.y) * 9.0) * 0.55;
	flare += exp(-abs(d.y) * 44.0) * exp(-abs(d.x) * 9.0) * 0.55;

	vec3 warm_gold = vec3(1.0, 0.78, 0.24);
	vec3 bright_gold = vec3(1.0, 0.96, 0.72);
	vec3 haze_gold = vec3(0.42, 0.28, 0.07);

	col += haze_gold * (halo * 0.65 + ray_mask * rays * 0.52);
	col += vec3(0.20, 0.14, 0.03) * arch_mist * (0.35 + 0.65 * halo);
	col += warm_gold * (orb * 0.95 + flare * 0.45);
	col += bright_gold * (core * 1.35 + orb * 0.35);

	// Twinkling distant golden stars & rising dust motes
	vec2 star_grid = uv * vec2(32.0, 18.0);
	vec2 sg_id = floor(star_grid);
	vec2 sg_f = fract(star_grid) - 0.5;
	float h1 = hash21(sg_id);
	if (h1 > 0.91) {
		float tw = 0.5 + 0.5 * sin(TIME * (1.5 + h1 * 2.0) + h1 * 40.0);
		float sd = length(sg_f + (vec2(hash21(sg_id + 3.1), hash21(sg_id + 7.7)) - 0.5) * 0.55);
		float sp = exp(-sd * sd * 75.0) * tw * 0.55 * smoothstep(0.05, 0.35, abs(uv.x - 0.5) + abs(uv.y - 0.17));
		col += warm_gold * sp;
	}

	// Floating dusty bokeh bubbles near light shaft
	vec2 b_uv = uv * vec2(12.0, 7.0) + vec2(0.0, -TIME * 0.08);
	vec2 b_id = floor(b_uv);
	vec2 b_f = fract(b_uv) - 0.5;
	float hb = hash21(b_id + 19.3);
	if (hb > 0.82) {
		float bd = length(b_f + vec2(sin(TIME * 0.5 + hb * 12.0), cos(TIME * 0.4 + hb * 9.0)) * 0.18);
		float rad = 0.08 + fract(hb * 17.0) * 0.10;
		float ring = exp(-pow((bd - rad) * 42.0, 2.0)) * 0.25 + smoothstep(rad, 0.0, bd) * 0.06;
		col += bright_gold * ring * smoothstep(0.75, 0.0, r);
	}

	// Soft edge vignette
	float vig = smoothstep(1.15, 0.25, length(uv - vec2(0.5, 0.45)));
	col *= mix(0.45, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


static func make_silhouette_texture(w: int = 560, h: int = 270) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(h):
		var yn := float(y) / float(h)
		for x in range(w):
			var xn := (float(x) / float(w)) * 2.0 - 1.0 # -1..1

			# Hooded/haired head silhouette
			var hx := (xn - 0.0) / 0.21
			var hy := (yn - 0.36) / 0.24
			var d_head := sqrt(hx * hx + hy * hy)

			# Fused sharp hood/hair crest on top-right
			var dx_t := xn - 0.09
			var tuft_field := clampf(1.0 - (absf(dx_t - (yn - 0.12) * 0.35) * 8.5 + maxf(0.13 - yn, 0.0) * 14.0), 0.0, 1.0)
			var d_tuft := 1.08 - tuft_field * 0.35 if (yn > 0.10 and yn < 0.36 and xn > -0.02 and xn < 0.22) else 2.0

			# Collar/hood bulge around neck
			var cx := xn / 0.31
			var cy := (yn - 0.60) / 0.12
			var d_collar := sqrt(cx * cx + cy * cy)

			# Broad shoulders tapering cleanly down to bottom edge
			var sx := xn / (0.72 + maxf(yn - 0.64, 0.0) * 0.55)
			var sy := (yn - 0.94) / 0.34
			var d_torso := sqrt(sx * sx + sy * sy)

			var min_d := minf(minf(d_head, d_tuft), minf(d_collar, d_torso))
			if min_d >= 1.02:
				continue

			var alpha := clampf((1.0 - min_d) / 0.025, 0.0, 1.0)

			# Top-down golden rim light coming from the star straight above center
			var edge_band := exp(-pow(clampf((1.0 - min_d) * 14.0, 0.0, 8.0), 1.4))
			var upward_face := clampf(1.25 - yn * 1.18, 0.0, 1.0)
			# Brightest on crown of head, collar lip, and tops of shoulders
			var shoulder_top := clampf(1.0 - absf(yn - 0.61) * 4.5, 0.0, 1.0) * smoothstep(0.18, 0.60, absf(xn))
			var crown_rim := smoothstep(0.45, 0.08, yn) * edge_band
			var rim := clampf(edge_band * upward_face * 0.85 + shoulder_top * 0.42 + crown_rim * 0.35, 0.0, 1.0)

			var body_col := Color(0.015, 0.012, 0.008)
			var rim_col := Color(1.0, 0.88, 0.42)
			var out := body_col.lerp(rim_col, pow(rim, 1.25))
			out.a = alpha
			img.set_pixel(x, y, out)

	return ImageTexture.create_from_image(img)


static func make_sigil_texture(sz: int = 128) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c := float(sz) * 0.5
	for y in range(sz):
		for x in range(sz):
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var r := sqrt(dx * dx + dy * dy)
			if r > 0.98:
				continue
			var orb := exp(-r * r * 14.0)
			var halo := exp(-r * r * 3.8) * 0.65
			var cross := exp(-absf(dx) * 20.0) * maxf(0.0, 1.0 - absf(dy)) * 0.7
			cross += exp(-absf(dy) * 20.0) * maxf(0.0, 1.0 - absf(dx)) * 0.7
			var a := clampf(orb + halo + cross * 0.5, 0.0, 1.0)
			var col := Color(1.0, 0.80, 0.25, a).lerp(Color(1.0, 0.98, 0.82, a), orb)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
