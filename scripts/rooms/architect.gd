class_name RoomsArchitect
extends RefCounted

## "Архитектор" — In-game Terminal death analyst & guide with RU / EN localization.

var deaths_total := 0
var best_room := 0
var deaths_by_cause: Dictionary = {}

const GLITCH_CHARS: Array[String] = ["#", "1", "0", "=", "≠", "%", "@"]

static var _terminal_font: Font = null

static func get_terminal_font() -> Font:
	if _terminal_font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"Consolas",
			"Courier New",
			"Cascadia Mono",
			"Cascadia Code",
			"Lucida Console",
			"Roboto Mono",
			"Droid Sans Mono",
			"DejaVu Sans Mono",
			"Monospace",
			"monospace"
		])
		_terminal_font = sf
	return _terminal_font


func record_progress(room_num: int) -> void:
	if room_num > best_room:
		best_room = room_num


static func get_entity_art_bbcode(_cause: String) -> String:
	return ""


static func generate_glitch_frame(old_text: String, new_text: String, step: int, total_steps: int = 12) -> String:
	if step <= 0:
		return old_text
	if step >= total_steps - 1:
		return new_text
	var progress := float(step) / float(maxi(total_steps - 1, 1))
	var base := old_text
	if base.is_empty():
		base = "hello"
	while base.length() < new_text.length() + 4:
		base += "#10"

	var cur_len := int(lerpf(float(base.length()), float(new_text.length()), progress))
	cur_len = maxi(1, cur_len)
	var noise_pool := GLITCH_CHARS
	var frame_chars: Array[String] = []
	for i in range(cur_len):
		if i < new_text.length() and randf() < pow(progress, 1.3):
			frame_chars.append(new_text.substr(i, 1))
		elif randf() < 0.45:
			frame_chars.append(noise_pool[randi() % noise_pool.size()])
		elif i < base.length():
			frame_chars.append(base.substr(i, 1))
		else:
			frame_chars.append(["1", "0", "#"][randi() % 3])
	return "".join(frame_chars)


func build_death_sequence(cause: String, room_num: int, username: String = "Player", _ctx: Dictionary = {}) -> Dictionary:
	deaths_total += 1
	record_progress(room_num)

	var cause_count: int = int(deaths_by_cause.get(cause, 0)) + 1
	deaths_by_cause[cause] = cause_count

	var is_ru := (RoomsI18n.lang == "ru")
	var lines: Array[String] = []
	var summary := ""
	var accent := Color.WHITE
	var title := ("АРХИТЕКТОР  •  КОМНАТА A-%03d" if is_ru else "ARCHITECT  •  ROOM A-%03d") % room_num
	var u_name := username if username != "" else "Player"

	if cause == "A-120":
		if is_ru:
			summary = "Услышав громкий стук и волнообразные помехи, прячься в шкаф и пережди до 3 отскоков!"
			if cause_count == 1 and deaths_total == 1:
				lines = [
					"Привет.",
					"Кто ты?",
					"О, привет, %s!" % u_name,
					"Тебя убил Happy Scribble.",
					"Его также называют A-120.",
					"Он появляется с громким стуком и гудящими помехами.",
					"Услышишь его — немедленно прячься в шкаф.",
					"Он проносится вперёд, а затем возвращается обратно.",
					"Не вылезай сразу! Он может отскочить до 3 раз.",
					"Слушай барабанный ритм, чтобы понять, когда он ушёл.",
				]
			elif cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя убил Happy Scribble (A-120).",
					"Он появляется со стуком и мчится по коридорам.",
					"Сиди в укрытии, пока барабанный стук не стихнет полностью.",
					"Он может вернуться до 3 раз — не спеши выходить.",
				]
			elif cause_count == 2:
				lines = [
					"И снова привет, %s." % u_name,
					"A-120 снова достал тебя (2-й раз).",
					"Помни: жди в шкафу до конца всех отскоков (до 3 раз).",
					"Попробуй ещё раз.",
				]
			else:
				lines = [
					"Уже вернулся, %s?" % u_name,
					"Это уже %d-я смерть от A-120." % cause_count,
					"Прислушивайся к его барабанному стуку перед выходом.",
					"Не теряй бдительность.",
				]
		else:
			summary = "When you hear loud banging and undulating static, hide in a cabinet and wait out up to 3 rebounds!"
			if cause_count == 1 and deaths_total == 1:
				lines = [
					"Hi.",
					"Who are you?",
					"Oh, hello %s!" % u_name,
					"You died to Happy Scribble.",
					"You can also call him A-120.",
					"He spawns with loud banging and static noises.",
					"When you hear him, find a hiding spot fast.",
					"He rushes through, then rebounds back.",
					"Stay hidden! He can rebound up to 3 times.",
					"Listen for his drum-like sounds to know when he's gone.",
				]
			elif cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You died to Happy Scribble (A-120).",
					"Stay hidden until his drum-like sounds stop completely.",
					"He can rebound up to 3 times — do not leave too early.",
				]
			elif cause_count == 2:
				lines = [
					"Hello again, %s." % u_name,
					"You died to A-120 again (2nd time).",
					"Remember: wait in the cabinet until the drums stop (up to 3 rebounds).",
					"Try again.",
				]
			else:
				lines = [
					"Back so soon, %s?" % u_name,
					"That is %d times from A-120 now." % cause_count,
					"Listen for his drum-like sounds to know when he has truly left.",
					"Stay focused.",
				]

	elif cause == "A-075":
		if is_ru:
			summary = "A-075 (Затвор) убивает ослепляющей вспышкой! Выключи фонарик [ПКМ] (или зажми [ПКМ] с Трясосветом, чтобы прикрыть его рукой) и отвернись!"
			if cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя ослепил Затвор (A-075).",
					"Когда слышишь писк заряда вспышки и щелчки объектива — он рядом.",
					"Выключи обычный фонарик [ПКМ] и ОТВЕРНИСЬ от его объектива!",
					"В руках Трясосвет [2]? ЗАЖМИ [ПКМ], чтобы прикрыть линзу второй рукой.",
					"Если он заметит свет или твой взгляд — его вспышка смертельна.",
				]
			else:
				lines = [
					"Снова попал в кадр, %s?" % u_name,
					"Это уже %d-я смерть от A-075." % cause_count,
					"Никакого света, никакого взгляда — либо зажми [ПКМ] с Трясосветом.",
				]
		else:
			summary = "A-075 (Shutter) kills with a blinding flash! Turn OFF flashlight [RMB] (or HOLD [RMB] with Shakerlight to cover the lens) and look away!"
			if cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You were blinded by Shutter (A-075).",
					"Listen for the rising flash-capacitor whine and shutter clicks.",
					"Turn OFF your flashlight [RMB] and LOOK AWAY from its aperture!",
					"Holding Shakerlight [2]? HOLD [RMB] to cover the lens with your other hand.",
					"If it catches your light or gaze, its flash is lethal.",
				]
			else:
				lines = [
					"Caught in the flash again, %s?" % u_name,
					"That is %d times from A-075 now." % cause_count,
					"No light, no eye contact — or hold [RMB] to cover your Shakerlight.",
				]

	elif cause == "A-085":
		if is_ru:
			summary = "A-085 проверяет занятые шкафы в ПОСЛЕДНЕЙ комнате! Если летит другой монстр — прячься в предпоследней комнате."
			if cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя настиг Выселитель (A-085).",
					"Этот дым прилетает в центр последней открытой комнаты и окутывает занятые шкафы.",
					"Он поднимает дверцу, а если ты всё ещё внутри — швыряет и дверь, и тебя через всю комнату (-90 HP).",
					"Если рядом летит ещё один монстр — не прячься в последней комнате, уходи в шкаф в предпоследней.",
				]
			else:
				lines = [
					"Снова засел в шкафу в последней комнате, %s?" % u_name,
					"A-085 проверяет шкафы только в самой последней комнате.",
					"Если нужно спрятаться от другого монстра — используй предпоследнюю комнату.",
				]
		else:
			summary = "A-085 checks occupied lockers in the LAST room! If another monster is coming, hide in the second-to-last room."
			if cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You were thrown out by The Breacher (A-085).",
					"The dark smoke stops at the center of the last opened room and envelops occupied lockers.",
					"It lifts the door, and if you are still inside, it flings both the door and you across the room (-90 HP).",
					"If another monster is approaching too, don't hide in the last room — hide in the second-to-last room instead.",
				]
			else:
				lines = [
					"Hid in the last room again, %s?" % u_name,
					"A-085 only checks lockers inside the very last room.",
					"When comboed with another entity, retreat and hide in the second-to-last room.",
				]

	elif cause == "A-160":
		if is_ru:
			summary = "A-160 (Двойник) притворяется игроком! Не подходи ближе 3 метров и не свети ему прямо в лицо. Обойди его по дальней стене или изгони вспышкой трясосвета."
			if cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя убил Двойник (A-160).",
					"Он принимает облик одного из игроков и стоит у дальней двери комнаты.",
					"Его выдаёт неестественно поворачивающаяся голова, холодный луч света и полная тишина.",
					"Если подойти ближе 3 метров или долго светить ему в лицо — он нападёт.",
					"Обходи его по дальней стене или изгони вспышкой заряженного трясосвета.",
				]
			else:
				lines = [
					"Снова попался на копию, %s?" % u_name,
					"A-160 не двигается и следит за тобой неестественным взглядом.",
					"Держи дистанцию и не подходи вплотную, либо ослепи его трясосветом.",
				]
		else:
			summary = "A-160 (The Mimic) copies a player! Don't get closer than 3 meters and don't shine your flashlight at its face. Walk around it or banish it with the Shakerlight."
			if cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You were slain by The Mimic (A-160).",
					"It copies the appearance of a player and waits near the far door.",
					"You can recognize it by its unnaturally twisting head, chilly light, and total silence.",
					"Getting closer than 3 meters or shining your flashlight directly at its face triggers an attack.",
					"Walk around along the opposite wall, or banish it with the green Shakerlight flash.",
				]
			else:
				lines = [
					"Fooled by the duplicate again, %s?" % u_name,
					"A-160 stands completely still, turning its neck past human limits.",
					"Keep your distance and do not approach, or repel it with the Shakerlight.",
				]

	elif cause == "A-60'":
		if is_ru:
			summary = "MultiMonster Prime (A-60') приходит после A-60 за дверью A-49: непрерывное мерцание фонарика — сигнал!"
			if cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя убил MultiMonster Prime (A-60').",
					"Постоянное мерцание фонарика предупреждает о его атаке.",
					"Он может пролетать до 4 раз подряд — следи за светом.",
					"Вылезай и заходи обратно в шкаф между пролётами, если шепчет Тьма.",
				]
			else:
				lines = [
					"Снова здесь, %s?" % u_name,
					"A-60' поймал тебя %d-й раз." % cause_count,
					"Если фонарик продолжает искрить — жди новый пролёт Prime.",
				]
		else:
			summary = "The MultiMonster Prime (A-60') attacks after A-60 post-A49: constant flashlight flicker is your warning!"
			if cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You died to The MultiMonster Prime (A-60').",
					"Flashlights flickering constantly warn that he is coming.",
					"He can attack up to 4 times consecutively.",
					"Re-enter cabinets between passes if you hear Darkness whisper.",
				]
			else:
				lines = [
					"Back so soon, %s?" % u_name,
					"That is %d times from A-60' now." % cause_count,
					"Watch your flashlight: if it keeps flickering, another Prime pass is coming.",
				]

	elif cause == "A-90" or cause == "A-90'":
		if is_ru:
			summary = "При появлении красного знака STOP замри полностью: отпусти все клавиши и не двигай мышью!"
			if cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя поймал A-90 (Знак STOP).",
					"Как только он появляется перед лицом — ЗАМРИ полностью.",
					"Не иди. Не вращай камеру. Убери руки с клавиш и мыши.",
					"Даже если летит другой монстр — сначала переживи STOP.",
				]
			else:
				lines = [
					"Дёрнулся, %s?" % u_name,
					"A-90 наказал тебя уже %d раз." % cause_count,
					"Полная неподвижность — единственный способ выжить.",
				]
		else:
			summary = "When the red STOP sign flashes, freeze completely: release keys and stop mouse movement!"
			if cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You died to A-90 (The Stop Sign).",
					"When the STOP sign appears, freeze completely.",
					"Do not move or rotate the camera until the sign disappears.",
				]
			else:
				lines = [
					"Moved too soon, %s?" % u_name,
					"A-90 punished you %d times now." % cause_count,
					"Complete stillness is the only answer to A-90.",
				]

	elif cause == "The Darkness":
		if is_ru:
			summary = "Не сиди в укрытии слишком долго после A-21! Выходи из шкафа или вспыхни обычным фонариком [ПКМ]."
			if cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя поглотила Тьма.",
					"Она просыпается, если прятаться слишком долго после A-21.",
					"Красная виньетка и шёпот предупреждают о её приближении.",
					"Выходи по [W] или [S], как только опасность снаружи минует.",
				]
			else:
				lines = [
					"Снова засиделся, %s?" % u_name,
					"Тьма достала тебя %d-й раз." % cause_count,
					"Покидай укрытие сразу после пролёта монстра.",
				]
		else:
			summary = "Do not stay hidden too long after A-21! Leave the cabinet or flash a standard flashlight [RMB]."
			if cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You died to The Darkness.",
					"It awakens when you hide too long after A-21.",
					"Leave [W] / [S] as soon as the coast is clear.",
				]
			else:
				lines = [
					"Stayed hidden too long, %s?" % u_name,
					"The Darkness got you %d times now." % cause_count,
					"Step out on [S] as soon as the monster finishes its pass.",
				]

	else:
		if is_ru:
			summary = "До A-100 сильные помехи предупреждают о A-60. Сразу прячься в шкаф!"
			if cause_count == 1 and deaths_total == 1:
				lines = [
					"Привет.",
					"Кто ты?",
					"О, привет, %s!" % u_name,
					"Тебя убил The MultiMonster.",
					"Его также называют A-60.",
					"До двери A-100 о нём предупреждают помехи на экране.",
					"Он мчится сквозь комнаты с нарастающим рёвом.",
					"Прячься в шкаф сразу, как начнётся рябь!",
					"Когда он выбьет дверь и провалится под пол — можно выходить.",
				]
			elif cause_count == 1:
				lines = [
					"Здравствуй, %s." % u_name,
					"Тебя убил The MultiMonster (A-60).",
					"Прячься сразу при появлении помех и гула.",
					"После того как он выбьет следующую дверь, путь чист.",
				]
			else:
				lines = [
					"Снова ты, %s?" % u_name,
					"Это уже %d-я смерть от A-60." % cause_count,
					"После A-100 помех нет — ориентируйся только на его гул.",
					"Будь начеку.",
				]
		else:
			summary = "Before A-100, heavy static and vignette warn you. Hide in a cabinet right away!"
			if cause_count == 1 and deaths_total == 1:
				lines = [
					"Hi.",
					"Who are you?",
					"Oh, hello %s!" % u_name,
					"You died to The MultiMonster.",
					"You can also call him A-60.",
					"Before door A-100, heavy static warns you.",
					"He rushes through every room with a constant static roar.",
					"Hide right away when your screen starts glitching!",
					"Once he smashes the door and sinks, it is safe.",
				]
			elif cause_count == 1:
				lines = [
					"Greetings, %s." % u_name,
					"You died to The MultiMonster (A-60).",
					"Hide right away when your screen glitches.",
					"Once he breaks the next door and sinks, it is safe.",
				]
			else:
				lines = [
					"Back so soon, %s?" % u_name,
					"That is %d times from A-60 now." % cause_count,
					"After A-100 there is no static warning — listen for his rumble.",
					"Stay alert.",
				]

	return {
		"title": title,
		"accent": accent,
		"lines": lines,
		"summary": summary,
		"deaths_total": deaths_total,
		"cause_count": cause_count,
		"death_num_entity": cause_count,
		"art_bbcode": "",
	}


static func make_void_shader_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.008, 0.009, 0.011);
	float scanline = sin(uv.y * 420.0 * 3.14159) * 0.5 + 0.5;
	col *= (0.88 + 0.12 * scanline);
	vec2 d = uv - vec2(0.5);
	float vig = smoothstep(0.85, 0.22, length(d));
	col *= mix(0.42, 1.0, vig);
	float edge = max(smoothstep(0.0, 0.04, uv.x) * smoothstep(1.0, 0.96, uv.x) *
	                 smoothstep(0.0, 0.04, uv.y) * smoothstep(1.0, 0.96, uv.y), 0.0);
	col += vec3(0.14, 0.14, 0.16) * (1.0 - edge) * 0.30;
	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


static func make_silhouette_texture(w: int = 560, h: int = 270) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)


static func make_sigil_texture(sz: int = 128) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)
