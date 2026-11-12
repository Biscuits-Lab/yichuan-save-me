extends Node2D

const SamuraiScript = preload("res://scripts/samurai.gd")
const BugScript = preload("res://scripts/bug.gd")
const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio.gd")
const AtlasScript = preload("res://scripts/sprite_atlas.gd")
const WORLD_LENGTH: float = 6480
const STAGES: Array[Dictionary] = [
	{"tool": "UGS", "title": "同步风暴", "task": "斩断 3 个同步冲突，在终端重新同步", "kind": "ugs", "color": Color("e6ad74"), "x": 1500.0, "gate": 1770.0, "log": "UGS: Workspace synced. Build is healthy."},
	{"tool": "AngelScript", "title": "脚本迷城", "task": "清除 3 个编译幽灵，在终端热重载", "kind": "script", "color": Color("bcaae3"), "x": 3150.0, "gate": 3400.0, "log": "AngelScript: Compile succeeded. Hot reload complete."},
	{"tool": "P4", "title": "独占检出", "task": "用 K 破除 3 把文件锁，在终端提交", "kind": "p4", "color": Color("81c9d6"), "x": 4700.0, "gate": 4950.0, "log": "P4: Change 1024 submitted. All files unlocked."},
	{"tool": "BUILD", "title": "最后一次打包", "task": "击败打包失败，守住今晚的下班时间", "kind": "boss", "color": Color("ed8d82"), "x": 6200.0, "gate": 6480.0, "log": "AutomationTool exiting with ExitCode=0 (Success)"}
]

var state: String = "title"
var previous_state: String = "title"
var world: Node2D
var scenery: Node2D
var hud: Node2D
var player: CharacterBody2D
var audio: Node
var world_length: float = WORLD_LENGTH
var camera_x: float = 0
var stage: int = 0
var checkpoint := Vector2(180, 598)
var enemies: Array = []
var platforms: Array[Rect2] = []
var gates: Array = []
var terminals: Array = []
var coffee: Array = []
var projectiles: Array = []
var particles: Array = []
var floating_text: Array = []
var trails: Array = []
var logs: Array = []
var kills: Dictionary = {"ugs": 0, "script": 0, "p4": 0, "boss": 0}
var clock: float = 0
var run_time: float = 0
var best_time: float = 0
var deaths: int = 0
var repaired: int = 0
var shake: float = 0
var damage_flash: float = 0
var speech: String = "来了"
var speaker: String = "毅川 / 虚幻引擎开发师"
var speech_time: float = 0
var chapter_time: float = 0
var feedback: String = ""
var feedback_time: float = 0
var selection: int = 0
var rng := RandomNumberGenerator.new()
var font: Font
var pixel_font: Font
var key_art: Texture2D
var background_art: Texture2D
var actions_atlas: RefCounted
var run_atlas: RefCounted
var attack_atlas: RefCounted
var enemies_atlas: RefCounted
var effects_atlas: RefCounted
var effects: Array = []
var display_font: Font
var speech_font: Font
var muted: bool = false
var record_path: String = "user://record.json"

func _ready() -> void:
	rng.seed = 20261112
	var base_font: Font = load("res://assets/fonts/NotoSansSC.ttf") if ResourceLoader.exists("res://assets/fonts/NotoSansSC.ttf") else ThemeDB.fallback_font
	var body_font := FontVariation.new()
	body_font.base_font = base_font
	body_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 550.0}
	font = body_font
	var title_font := FontVariation.new()
	title_font.base_font = base_font
	title_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 850.0}
	display_font = title_font
	var bubble_font := FontVariation.new()
	bubble_font.base_font = base_font
	bubble_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 780.0}
	speech_font = bubble_font
	pixel_font = load("res://assets/fonts/PressStart2P.ttf") if ResourceLoader.exists("res://assets/fonts/PressStart2P.ttf") else ThemeDB.fallback_font
	if ResourceLoader.exists("res://assets/art/key-art.png"):
		key_art = load("res://assets/art/key-art.png")
	if ResourceLoader.exists("res://assets/art/district-background.png"):
		background_art = load("res://assets/art/district-background.png")
	actions_atlas = load_atlas("res://assets/sprites/yichuan-actions.png", 4, 2, true)
	run_atlas = load_atlas("res://assets/sprites/yichuan-run-v2.png", 4, 4, true)
	attack_atlas = load_atlas("res://assets/sprites/yichuan-attack.png", 4, 4, true)
	enemies_atlas = load_atlas("res://assets/sprites/engine-enemies.png", 4, 4)
	effects_atlas = load_atlas("res://assets/vfx/combat-effects.png", 4, 2)
	setup_input()
	audio = AudioScript.new()
	add_child(audio)
	world = Node2D.new()
	add_child(world)
	build_world()
	hud = HudScript.new()
	hud.game = self
	add_child(hud)
	world.visible = false
	load_record()
	if "--smoke-play" in OS.get_cmdline_user_args():
		start_run()

func load_atlas(path: String, columns: int, rows: int, align_head: bool = false) -> RefCounted:
	return AtlasScript.new(load(path), columns, rows, align_head) if ResourceLoader.exists(path) else null

func setup_input() -> void:
	var bindings: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "attack": [KEY_J, KEY_X],
		"skill": [KEY_K, KEY_C], "dash": [KEY_L, KEY_SHIFT], "interact": [KEY_E]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func build_world() -> void:
	for child in world.get_children():
		child.queue_free()
	enemies.clear()
	platforms.clear()
	gates.clear()
	terminals.clear()
	coffee.clear()
	projectiles.clear()
	particles.clear()
	effects.clear()
	trails.clear()
	floating_text.clear()
	scenery = WorldScript.new()
	scenery.game = self
	world.add_child(scenery)
	var ground: Array[Rect2] = [Rect2(0, 600, 920, 170), Rect2(1080, 600, 1500, 170), Rect2(2730, 600, 1450, 170), Rect2(4340, 600, 2140, 170)]
	var ledges: Array[Rect2] = [
		Rect2(400, 465, 210, 24), Rect2(740, 420, 200, 24), Rect2(1000, 475, 200, 24),
		Rect2(1990, 480, 180, 24), Rect2(2300, 400, 220, 24), Rect2(2550, 480, 200, 24), Rect2(2900, 445, 180, 24),
		Rect2(3590, 475, 190, 24), Rect2(3920, 415, 190, 24), Rect2(4160, 480, 220, 24), Rect2(4510, 455, 160, 24),
		Rect2(5360, 455, 150, 24), Rect2(5830, 455, 150, 24)
	]
	for rect in ground + ledges:
		platforms.append(rect)
		add_solid(rect)
	for i in range(3):
		var data: Dictionary = STAGES[i]
		var gate_rect := Rect2(float(data.gate), 295, 28, 305)
		gates.append({"rect": gate_rect, "body": add_solid(gate_rect), "open": false})
		terminals.append({"p": Vector2(float(data.x), 600), "done": false, "tool": data.tool})
	for spec in [[530, 600, "ugs"], [1220, 600, "ugs"], [1450, 600, "ugs"], [2200, 480, "script"], [2780, 505, "script"], [3040, 420, "script"], [3730, 600, "p4"], [4000, 600, "p4"], [4540, 600, "p4"], [5730, 600, "boss"]]:
		spawn_bug(Vector2(spec[0], spec[1]), spec[2])
	for point in [Vector2(820, 386), Vector2(2080, 446), Vector2(2965, 411), Vector2(3660, 441), Vector2(4600, 421), Vector2(5430, 421)]:
		coffee.append({"p": point, "taken": false})
	player = SamuraiScript.new()
	player.game = self
	player.position = Vector2(180, 598)
	world.add_child(player)

func add_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.get_center()
	body.add_child(collider)
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)
	return body

func spawn_bug(point: Vector2, kind: String) -> CharacterBody2D:
	var bug := BugScript.new()
	bug.position = point
	bug.kind = kind
	bug.game = self
	enemies.append(bug)
	world.add_child(bug)
	return bug

func start_run() -> void:
	stage = 0
	run_time = 0
	deaths = 0
	repaired = 0
	kills = {"ugs": 0, "script": 0, "p4": 0, "boss": 0}
	checkpoint = Vector2(180, 598)
	build_world()
	state = "playing"
	world.visible = true
	camera_x = 0
	chapter_time = 4
	logs.clear()
	log_event("[22:47] 同事：毅川救我！工程又炸了。", Color("e6bb85"))
	log_event("UGS: Sync failed. 3 workspace conflicts detected.", Color("e5ad76"))
	say("来了", 3.5)
	audio.sfx("start")

func _process(delta: float) -> void:
	clock += delta
	if state == "playing":
		run_time += delta
		speech_time = maxf(0, speech_time - delta)
		chapter_time = maxf(0, chapter_time - delta)
		feedback_time = maxf(0, feedback_time - delta)
		shake = maxf(0, shake - delta * 35)
		damage_flash = maxf(0, damage_flash - delta)
		var wanted: float = clampf(player.position.x - 440, 0, WORLD_LENGTH - 1280)
		camera_x = lerpf(camera_x, wanted, 1.0 - exp(-delta * 7))
		var offset := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake * 0.5, shake * 0.5))
		world.position = Vector2(-floorf(camera_x), 0) + offset
		update_effects(delta)
		enemies = enemies.filter(func(enemy): return is_instance_valid(enemy) and not enemy.dead)
		for cup in coffee:
			if not cup.taken and player.position.distance_to(cup.p + Vector2(0, 25)) < 60:
				cup.taken = true
				player.health = mini(6, player.health + 2)
				player.energy = minf(100, player.energy + 30)
				burst(cup.p, Color("edc78d"), 15)
				float_text("咖啡续命 +2", cup.p, Color("ffe4b5"))
				audio.sfx("coffee")
		if Input.is_action_just_pressed("interact"):
			interact()
	if is_instance_valid(scenery):
		scenery.queue_redraw()
	if is_instance_valid(hud):
		hud.queue_redraw()

func update_effects(delta: float) -> void:
	for particle in particles:
		particle.life -= delta
		particle.p += particle.v * delta
		particle.v.y += 430 * delta
	particles = particles.filter(func(p): return p.life > 0)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect): return effect.life > 0)
	for trail in trails:
		trail.life -= delta
	trails = trails.filter(func(t): return t.life > 0)
	for item in floating_text:
		item.life -= delta
		item.p.y -= 26 * delta
	floating_text = floating_text.filter(func(t): return t.life > 0)
	for orb in projectiles:
		orb.life -= delta
		orb.p += orb.v * delta
		if orb.life <= 0:
			continue
		if orb.p.distance_to(player.position + Vector2(0, -35)) < 24:
			player.hurt(1, orb.p.x)
			orb.life = 0
		for rect in platforms:
			if rect.has_point(orb.p):
				orb.life = 0
				break
	projectiles = projectiles.filter(func(p): return p.life > 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				muted = not muted
				AudioServer.set_bus_mute(0, muted)
			KEY_F11:
				var mode := DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F1, KEY_TAB:
				if state == "guide":
					state = previous_state
				else:
					previous_state = state
					state = "guide"
			KEY_ESCAPE:
				if state == "playing":
					state = "paused"
				elif state == "paused":
					state = "playing"
				elif state == "guide":
					state = previous_state
			KEY_R:
				if state == "dead":
					respawn()
				elif state == "won":
					start_run()
			KEY_UP, KEY_DOWN:
				if state == "title":
					selection = 1 - selection
					audio.sfx("select")
			KEY_ENTER, KEY_KP_ENTER:
				if state == "title":
					if selection == 0:
						start_run()
					else:
						previous_state = "title"
						state = "guide"
				elif state == "paused":
					state = "playing"
				elif state == "dead":
					respawn()
				elif state == "won":
					start_run()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(get_global_mouse_position())

func handle_click(point: Vector2) -> void:
	if state == "title":
		if Rect2(96, 438, 310, 64).has_point(point):
			start_run()
		elif Rect2(96, 516, 310, 54).has_point(point):
			previous_state = "title"
			state = "guide"
	elif state == "guide":
		if Rect2(1000, 65, 150, 44).has_point(point):
			state = previous_state
	elif state in ["dead", "won", "paused"]:
		if Rect2(470, 440, 340, 60).has_point(point):
			if state == "dead":
				respawn()
			elif state == "won":
				start_run()
			else:
				state = "playing"
		elif Rect2(470, 518, 340, 48).has_point(point):
			state = "title"
			world.visible = false
	else:
		if Rect2(1180, 23, 64, 46).has_point(point):
			state = "paused"

func interact() -> void:
	for i in range(terminals.size()):
		var terminal: Dictionary = terminals[i]
		if absf(player.position.x - terminal.p.x) > 115 or absf(player.position.y - terminal.p.y) > 100:
			continue
		if terminal.done:
			feedback = "工程状态正常。往前走，大家还等着你。"
			feedback_time = 3
			return
		if stage != i:
			feedback = "先修复前一个工具，再继续流水线。"
			feedback_time = 3
			return
		var data: Dictionary = STAGES[i]
		if kills[data.kind] < 3:
			feedback = "%s：还有 %d 个问题没有修复。" % [data.tool, 3 - kills[data.kind]]
			feedback_time = 3
			say("坏啦", 2)
			return
		terminal.done = true
		gates[i].open = true
		gates[i].body.queue_free()
		stage += 1
		repaired += 1
		checkpoint = Vector2(float(data.gate) + 95, 598)
		player.health = 6
		player.energy = 100
		chapter_time = 4
		log_event(data.log, Color("b2e4bd"))
		if stage == 1:
			log_event("AngelScript: 3 errors. Script module not loaded.", Color("bcaae3"))
		elif stage == 2:
			log_event("P4: Can't edit exclusive file. Already opened by someone.", Color("81c9d6"))
		else:
			log_event("UAT: Cook failed. Unknown Error. 下班倒计时暂停。", Color("ed8d82"))
		say("来了", 2.2, "毅川 · 下一个问题")
		burst(terminal.p + Vector2(0, -60), Color("a5f5c3"), 45)
		audio.sfx("repair")
		return
	feedback = "靠近发光的工具终端，按 E 修复工程。"
	feedback_time = 3

func bug_defeated(bug: CharacterBody2D) -> void:
	kills[bug.kind] += 1
	burst(bug.position + Vector2(0, -25), bug.color(), 25)
	if bug.kind == "boss":
		state = "won"
		repaired = 4
		log_event(STAGES[3].log, Color("c3f3c7"))
		say("来了。走，下班。", 10)
		audio.sfx("win")
		if best_time == 0 or run_time < best_time:
			best_time = run_time
			save_record()
	else:
		float_text("%s 修复 %d/3" % [STAGES[mini(stage, 2)].tool, kills[bug.kind]], bug.position + Vector2(0, -85), Color("bcf1cb"))
		if kills[bug.kind] == 3:
			log_event("%s：问题已清空。找到终端，按 E。" % STAGES[stage].tool, Color("bde9c6"))

func fall_recover() -> void:
	player.invulnerable = 0
	player.hurt(2, player.position.x + 1)
	if state == "playing":
		player.position = checkpoint
		player.velocity = Vector2.ZERO
		camera_x = clampf(checkpoint.x - 440, 0, WORLD_LENGTH - 1280)
		say("坏啦", 2.5, "毅川 · 掉进空指针深渊")

func die() -> void:
	state = "dead"
	deaths += 1
	speech = "哦豁，完蛋"
	speech_time = 10
	audio.sfx("dead")

func respawn() -> void:
	player.position = checkpoint
	player.velocity = Vector2.ZERO
	player.health = 6
	player.energy = 100
	player.invulnerable = 2
	projectiles.clear()
	state = "playing"
	camera_x = clampf(checkpoint.x - 440, 0, WORLD_LENGTH - 1280)
	say("来了", 3, "毅川 · 从最近一次成功构建恢复")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.kind == "boss":
			enemy.hp = enemy.max_hp
			enemy.position = enemy.origin
			enemy.boss_activated = false

func shoot(point: Vector2, velocity: Vector2, color: Color) -> void:
	projectiles.append({"p": point, "v": velocity, "color": color, "life": 6.0})

func vfx(index: int, point: Vector2, size: float = 100, duration: float = 0.25, facing: float = 1) -> void:
	effects.append({"index": index, "p": point, "size": size, "life": duration, "duration": duration, "facing": facing})

func burst(point: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"p": point, "v": Vector2(rng.randf_range(-170, 170), rng.randf_range(-220, 60)), "color": color, "life": rng.randf_range(0.25, 0.65), "size": rng.randi_range(2, 6)})

func float_text(value: String, point: Vector2, color: Color) -> void:
	floating_text.append({"text": value, "p": point, "color": color, "life": 1.3})

func say(value: String, duration: float = 2.5, who: String = "毅川 / 虚幻引擎开发师") -> void:
	speech = value
	speaker = who
	speech_time = duration

func log_event(value: String, color: Color) -> void:
	logs.append({"text": value, "color": color})
	if logs.size() > 3:
		logs.pop_front()

func time_label(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func load_record() -> void:
	if FileAccess.file_exists(record_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if data is Dictionary:
			best_time = float(data.get("best_time", 0))

func save_record() -> void:
	var file := FileAccess.open(record_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"best_time": best_time}))
