class_name RoomsArchitect
extends RefCounted

## "Архитектор" — In-game Terminal Matrix death analyst & guide inspired by test.py.
## Features authentic ASCII monster portraits, CRT phosphor aesthetics, glitch text transitions, and memory of past deaths.

var deaths_total := 0
var best_room := 0
var deaths_by_cause: Dictionary = {}

# Canonical ASCII art from test.py
const A120_ART: Array[String] = [
	"         ==                   ",
	"      =======                 ",
	"     ≠==≠≠=≠≠        ==≠===   ",
	"     ≠≠≠≠=≠         ≠==≠===≠  ",
	"                   ==≠==≠==   ",
	"                    ≠=≠≠=     ",
	"   =≠=≠                       ",
	"   =≠=≠=≠=                    ",
	"     ≠=====          ===≠≠=   ",
	"      =≠≠≠=≠=≠===≠≠=≠≠≠=≠=≠   ",
	"         =≠===≠≠=====≠=≠≠     ",
	"             ≠====≠           ",
]

const A60_ART: Array[String] = [
	"  ░▒▓█▓▒░           ░▒▓█▓▒░   ",
	" ▒▓█████▓▒  ░▒▓▒░  ▒▓█████▓▒  ",
	"░▓█@@*@@█▓▒▒▓███▓▒▒▓█@@*@@█▓░ ",
	"▒▓█@***@█▓██▓▒░▒▓██▓█@***@█▓▒ ",
	"░▓███████▓█▓░   ░▓█▓███████▓░ ",
	" ▒▓█████▓██▒  ░  ▒██▓█████▓▒  ",
	"  ░▒▓█▓▒▓█▓░ ▒▓▒ ░▓█▓▒▓█▓▒░   ",
	"  ▒▓███▓██▓▒▒▓█▓▒▒▓██▓███▓▒   ",
	" ░▓█@*@████▓█@*@█▓████@*@█▓░  ",
	" ▒▓█***███████████████***█▓▒  ",
	"  ░▒▓███████████████████▓▒░   ",
	"    ░▒▓██▓▒░     ░▒▓██▓▒░     ",
]

const A150_ART: Array[String] = [
	"        \\  /                  ",
	"      ==\\==/===               ",
	"     ≠==≠\\/≠≠        ==≠===   ",
	"     ≠≠≠/\\≠         ≠==≠===≠  ",
	"       /  \\        ==≠==≠==   ",
	"      / VV \\        ≠=≠≠=     ",
	"   =≠/ VVVV \\                 ",
	"   =≠=≠=≠=≠=≠                 ",
	"     ≠=====          ===≠≠=   ",
	"      =≠≠≠=≠=≠===≠≠=≠≠≠=≠=≠   ",
	"         =≠===≠≠=====≠=≠≠     ",
	"             ≠====≠           ",
]

const A35_ART: Array[String] = [
	"      .---.     .---.         ",
	"     /     \\   /     \\        ",
	"    | () () | | () () |       ",
	"     \\  =  /   \\  =  /        ",
	"   ===`---'=====`---'===      ",
	"  ░▒▓  >>>>> SHADOW >>>>>     ",
	"   ░▒▓███████████████▓▒░      ",
	"    ░▒▓██▓▒░   ░▒▓██▓▒░       ",
	"        <<< A-35 <<<          ",
	"     ~~~~~~~~~~~~~~~~~~       ",
]

const A90_ART: Array[String] = [
	"         .--------.           ",
	"        /  STOP!   \\          ",
	"       /   O    O   \\         ",
	"      |    ______    |        ",
	"      |   |______|   |        ",
	"       \\   FREEZE   /         ",
	"        \\          /          ",
	"         '--------'           ",
	"             ||               ",
	"             ||               ",
]

const DARKNESS_ART: Array[String] = [
	"         .---.                ",
	"      .-'     '-.             ",
	"    .'  .-----.  '.           ",
	"   /   /  (O)  \\   \\          ",
	"  |   |   .---. |   |         ",
	"   \\   \\  '---' /  /          ",
	"    '.  '-----'  .'           ",
	"      '-.     .-'             ",
	"         '---'                ",
	"   ..:: THE DARKNESS ::..     ",
]

const GLITCH_CHARS: Array[String] = ["#", "1", "0", "=", "≠", "%", "@"]


func record_progress(room_num: int) -> void:
	if room_num > best_room:
		best_room = room_num


static func colorize_a60_char(ch: String, is_prime: bool = false) -> String:
	if ch == "@" or ch == "*":
		return "[color=#ffffff]%s[/color]" % ch
	elif ch == "█":
		return "[color=#0a1824]%s[/color]" % ch if is_prime else "[color=#2a0404]%s[/color]" % ch
	elif ch == "▓":
		return "[color=#24a8ff]%s[/color]" % ch if is_prime else "[color=#ff2020]%s[/color]" % ch
	elif ch == "▒" or ch == "░":
		return "[color=#4ae0ff]%s[/color]" % ch if is_prime else "[color=#ff4040]%s[/color]" % ch
	return ch


static func get_entity_art_bbcode(cause: String) -> String:
	var out: Array[String] = []
	if cause == "A-120":
		for line in A120_ART:
			out.append("[color=#00e5ff]%s[/color]" % line)
	elif cause == "A-150":
		for line in A150_ART:
			out.append("[color=#ff6b22]%s[/color]" % line)
	elif cause == "A-35":
		for line in A35_ART:
			out.append("[color=#b44aff]%s[/color]" % line)
	elif cause == "A-90" or cause == "A-90'":
		for line in A90_ART:
			out.append("[color=#ff2828]%s[/color]" % line)
	elif cause == "The Darkness":
		for line in DARKNESS_ART:
			out.append("[color=#dd1818]%s[/color]" % line)
	elif cause == "A-60'":
		for line in A60_ART:
			var colored := ""
			for i in range(line.length()):
				colored += colorize_a60_char(line.substr(i, 1), true)
			out.append(colored)
	else:
		# A-60 / default
		for line in A60_ART:
			var colored := ""
			for i in range(line.length()):
				colored += colorize_a60_char(line.substr(i, 1), false)
			out.append(colored)
	return "[font_size=11]%s[/font_size]" % "\n".join(out)


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


func build_death_sequence(cause: String, room_num: int, username: String = "Player", ctx: Dictionary = {}) -> Dictionary:
	deaths_total += 1
	record_progress(room_num)

	var cause_count: int = int(deaths_by_cause.get(cause, 0)) + 1
	deaths_by_cause[cause] = cause_count

	var lines: Array[String] = []
	var summary := ""
	var accent := Color(0.28, 1.0, 0.42)
	var title := "ARCHITECT  •  ROOM A-%03d" % room_num

	var u_name := username if username != "" else "Player"

	if cause == "A-120":
		summary = "When you hear loud banging and undulating static, hide in a locker and wait out up to 3 rebounds!"
		if cause_count == 1 and deaths_total == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from Happy Scribble",
				"You can also call him A-120",
				"He spawns with loud banging and static noises.",
				"When you hear him, find a hiding spot fast.",
				"He rushes at everyone, then goes back a room.",
				"Stay hidden! He can rebound up to 3 times.",
				"Listen for his drum-like sounds to know when he's gone.",
			]
		elif cause_count == 1:
			lines = [
				"Greetings, %s." % u_name,
				"You have been died from Happy Scribble (A-120).",
				"He spawns with loud banging and rushes down the halls.",
				"Stay hidden until his drum-like sounds stop.",
				"He can rebound up to 3 times — do not leave too early.",
			]
		elif cause_count == 2:
			lines = [
				"Hello again, %s." % u_name,
				"You died from Happy Scribble (A-120) again (2nd time).",
				"Remember: stay in the locker until the drums stop (up to 3 rebounds).",
				"Try again.",
			]
		else:
			lines = [
				"Back so soon, %s?" % u_name,
				"That is %d times from A-120 now." % cause_count,
				"Listen for his drum-like sounds to know when he has truly left.",
				"Stay focused.",
			]

	elif cause == "A-150":
		summary = "Angry Scribble (A-150) moves much faster than A-120 with rapid double-thuds!"
		if cause_count == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from Angry Scribble",
				"You can also call him A-150",
				"He is an enraged, faster variant of A-120 with an orange glow.",
				"He rushes with rapid double-thuds and aggressive rebounds.",
				"His speed gives you much less time to react.",
				"Find a hiding spot immediately when you hear the frantic drums.",
			]
		else:
			lines = [
				"Hello again, %s." % u_name,
				"A-150 got you again (death #%d)." % cause_count,
				"He moves faster than A-120 — hide as soon as the double-thud starts.",
				"Try again.",
			]

	elif cause == "A-60'":
		summary = "The MultiMonster Prime (A-60') attacks after A-60 post-A49: constant flashlight flicker is your warning!"
		if cause_count == 1 and deaths_total == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from The MultiMonster Prime",
				"You can also call him A-60'",
				"He spawns after A-49, following an attack from A-60.",
				"When he is about to attack, all flashlights flicker constantly.",
				"Lockers are safe, but leave and re-enter if Darkness approaches.",
				"Under tables, he has a 90% chance to inflict a 20 HP burn.",
				"He can spawn up to 4 times consecutively at high doors.",
			]
		elif cause_count == 1:
			lines = [
				"Greetings, %s." % u_name,
				"You have been died from The MultiMonster Prime (A-60').",
				"Flashlights flickering constantly is your warning that he is coming.",
				"He deals less damage, but can attack up to 4 times consecutively.",
				"Re-enter lockers between passes if you hear Darkness whisper.",
			]
		elif cause_count == 2:
			lines = [
				"Hello again, %s." % u_name,
				"A-60' caught you again.",
				"Watch your flashlight: if it keeps flickering, another Prime attack is coming.",
				"Try again.",
			]
		else:
			lines = [
				"Back so soon, %s?" % u_name,
				"That is %d times from A-60' now." % cause_count,
				"Re-enter lockers on [S] -> [LMB] between attacks to evade Darkness.",
				"Keep moving.",
			]

	elif cause == "A-35":
		summary = "The Phantom Sprinter (A-35) flies through rooms with a high-pitched warble!"
		if cause_count == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from The Phantom Sprinter",
				"You can also call him A-35",
				"He is a swift purple-shadow entity that flies through rooms.",
				"He strikes with a sharp warbling static sound.",
				"He moves in bursts — duck behind cover or into a locker fast.",
			]
		else:
			lines = [
				"Hello again, %s." % u_name,
				"A-35 caught you again (death #%d)." % cause_count,
				"Listen for the high warble — you have only a moment to break line of sight.",
				"Try again.",
			]

	elif cause == "A-90" or cause == "A-90'":
		summary = "When the red STOP sign flashes, freeze completely: release keys and stop mouse movement!"
		if cause_count == 1 and deaths_total == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from A-90",
				"You can also call him The Stop Sign",
				"He appears directly in front of your face with a glitched silhouette.",
				"When the red STOP sign flashes, freeze completely.",
				"Do not move. Do not turn your camera. Release all keys and mouse.",
				"Even if another monster approaches, survive the STOP sign first.",
			]
		elif cause_count == 1:
			lines = [
				"Greetings, %s." % u_name,
				"You have been died from A-90 (The Stop Sign).",
				"When the STOP sign appears, freeze completely.",
				"Do not move or rotate camera until the sign disappears.",
			]
		elif cause_count == 2:
			lines = [
				"Hello again, %s." % u_name,
				"A-90 caught you moving again.",
				"Hands off keys and mouse the instant the STOP sign flashes.",
				"Try again.",
			]
		else:
			lines = [
				"Back so soon, %s?" % u_name,
				"A-90 punished you %d times now." % cause_count,
				"Complete stillness is the only answer to A-90.",
				"Focus.",
			]

	elif cause == "The Darkness":
		summary = "Do not stay hidden too long after A-21! Leave the locker or use normal flashlight [ПКМ]."
		if cause_count == 1 and deaths_total == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from The Darkness",
				"It awakens when you hide inside a spot for too long after A-21.",
				"A red vignette and eerie whispering warn that it is approaching.",
				"Leave the locker [W] or [S] before it consumes your health.",
				"A standard flashlight flash will deter it once, but locks into low battery.",
			]
		elif cause_count == 1:
			lines = [
				"Greetings, %s." % u_name,
				"You have been died from The Darkness.",
				"Hiding too long awakens the whisper. Leave [W]/[S] once the coast is clear.",
			]
		elif cause_count == 2:
			lines = [
				"Hello again, %s." % u_name,
				"The Darkness consumed you again (2nd time).",
				"Do not linger in hiding spots once the danger outside has passed.",
				"Try again.",
			]
		else:
			lines = [
				"Back so soon, %s?" % u_name,
				"The Darkness got you %d times now." % cause_count,
				"Hop out on [S] as soon as the monster finishes its pass.",
				"Keep going.",
			]

	else:
		# A-60 / default
		summary = "Before A-100, heavy static and vignette warn you. Hide in a locker right away!"
		if cause_count == 1 and deaths_total == 1:
			lines = [
				"Hi",
				"Who are you?",
				"Oh, hello %s!" % u_name,
				"You have been died from The MultiMonster",
				"You can also call him A-60",
				"Before door A-100, heavy static and a vignette warn you.",
				"He rushes through every room with a constant static roar.",
				"Hide right away when your screen starts glitching!",
				"He smashes the current door and sinks into the floor.",
				"Once the door breaks and static stops, it's safe.",
			]
		elif cause_count == 1:
			lines = [
				"Greetings, %s." % u_name,
				"You have been died from The MultiMonster (A-60).",
				"Before door A-100, heavy static warns you.",
				"Hide right away when your screen glitches.",
				"Once he breaks the next door and sinks, it is safe.",
			]
		elif cause_count == 2:
			lines = [
				"Hello again, %s." % u_name,
				"You died from The MultiMonster (A-60) again (2nd time).",
				"Hide immediately when static spikes. Once the door breaks, he sinks.",
				"Try again.",
			]
		else:
			lines = [
				"Back so soon, %s?" % u_name,
				"That is %d times from A-60 now." % cause_count,
				"After A-100 there is no static warning — listen for his rumble.",
				"Stay alert.",
			]

	var art_bbcode := get_entity_art_bbcode(cause)

	return {
		"title": title,
		"accent": accent,
		"lines": lines,
		"summary": summary,
		"deaths_total": deaths_total,
		"cause_count": cause_count,
		"death_num_entity": cause_count,
		"art_bbcode": art_bbcode,
	}


static func make_void_shader_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;

void fragment() {
	vec2 uv = UV;

	// Deep matrix obsidian phosphor green background
	vec3 col = vec3(0.006, 0.014, 0.008);

	// Horizontal CRT scanlines
	float scanline = sin(uv.y * 420.0 * 3.14159) * 0.5 + 0.5;
	col *= (0.86 + 0.14 * scanline);

	// Subtle vertical phosphor shadow-mask
	float phos = sin(uv.x * 640.0 * 3.14159) * 0.5 + 0.5;
	col *= (0.94 + 0.06 * phos);

	// Subtle CRT edge vignette
	vec2 d = uv - vec2(0.5);
	float vig = smoothstep(0.85, 0.22, length(d));
	col *= mix(0.40, 1.0, vig);

	// Phosphor green border glow
	float edge = max(smoothstep(0.0, 0.04, uv.x) * smoothstep(1.0, 0.96, uv.x) *
	                 smoothstep(0.0, 0.04, uv.y) * smoothstep(1.0, 0.96, uv.y), 0.0);
	col += vec3(0.04, 0.22, 0.08) * (1.0 - edge) * 0.45;

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
