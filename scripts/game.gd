extends Node2D

const Data = preload("res://scripts/rogue_data.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const PlayerScript = preload("res://scripts/samurai.gd")
const BugScript = preload("res://scripts/bug.gd")
const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio.gd")
const AtlasScript = preload("res://scripts/sprite_atlas.gd")
const STORY_ROOMS: int = 12
var state: String = "title"
var previous_state: String = "title"
var mode: String = "story"
var world: Node2D
var scenery: Node2D
var hud: Node2D
var player: CharacterBody2D
var audio: Node
var world_length: float = 3520
var camera_x: float = 0
var stage: int = 0
var room_index: int = 0
var room_data: Dictionary = {}
var event: Dictionary = Data.EVENTS[0]
var event_order: Array[int] = []
var room_phase: String = "approach"
var route: String = "normal"
var run_seed: int = 0
var room_clock: float = 0
var room_wave: int = 0
var room_kills: int = 0
var cleared_rooms: int = 0
var relay_count: int = 0
var boss_ref: Node
var platforms: Array[Rect2] = []
var gates: Array[Dictionary] = []
var enemies: Array = []
var coffee: Array = []
var projectiles: Array = []
var particles: Array = []
var floating_text: Array = []
var trails: Array = []
var effects: Array = []
var hazards: Array = []
var npcs: Array = []
var logs: Array = []
var skill_ranks: Dictionary = {}
var upgrade_choices: Array[Dictionary] = []
var coins: int = 0
var score: int = 0
var total_kills: int = 0
var bonus_damage: int = 0
var ward: int = 0
var npc_contract: bool = false
var npc_selected: int = -1
var chest_open: bool = false
var trap_cycles: Dictionary = {}
var clock: float = 0
var run_time: float = 0
var best_time: float = 0
var best_floor: int = 0
var best_score: int = 0
var shake: float = 0
var damage_flash: float = 0
var speech: String = "来了"
var speaker: String = "毅川 / 虚幻引擎开发师"
var speech_time: float = 0
var speech_anchor: Vector2 = Vector2.INF
var chapter_time: float = 0
var feedback: String = ""
var feedback_time: float = 0
var selection: int = 0
var card_selection: int = 0
var rng := RandomNumberGenerator.new()
var font: Font
var pixel_font: Font
var display_font: Font
var speech_font: Font
var key_art: Texture2D
var background_art: Texture2D
var actions_atlas: RefCounted
var run_atlas: RefCounted
var attack_atlas: RefCounted
var enemies_atlas: RefCounted
var extra_enemies_atlas: RefCounted
var effects_atlas: RefCounted
var npc_atlas: RefCounted
var icons_atlas: RefCounted
var muted: bool = false
var record_path: String = "user://record.json"

func _ready() -> void:
	var base: Font = load("res://assets/fonts/NotoSansSC.ttf")
	font = make_font(base, 550)
	display_font = make_font(base, 850)
	speech_font = make_font(base, 780)
	pixel_font = load("res://assets/fonts/PressStart2P.ttf")
	key_art = load("res://assets/art/key-art.png")
	background_art = load("res://assets/art/district-background.png")
	actions_atlas = load_atlas("res://assets/sprites/yichuan-actions.png", 4, 2, true)
	run_atlas = load_atlas("res://assets/sprites/yichuan-run-v2.png", 4, 4, true)
	attack_atlas = load_atlas("res://assets/sprites/yichuan-attack.png", 4, 4, true)
	enemies_atlas = load_atlas("res://assets/sprites/engine-enemies.png", 4, 4)
	extra_enemies_atlas = load_atlas("res://assets/sprites/engine-enemies-expanded.png", 4, 4)
	effects_atlas = load_atlas("res://assets/vfx/combat-effects.png", 4, 2)
	npc_atlas = load_atlas("res://assets/sprites/developer-npcs.png", 4, 2)
	icons_atlas = load_atlas("res://assets/ui/skill-icons.png", 4, 3)
	setup_input()
	audio = AudioScript.new()
	add_child(audio)
	world = Node2D.new()
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(world)
	player = PlayerScript.new()
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	player.game = self
	world.add_child(player)
	hud = HudScript.new()
	hud.game = self
	hud.z_index = 100
	add_child(hud)
	world.visible = false
	load_record()
	if "--smoke-play" in OS.get_cmdline_user_args():
		start_run()

func make_font(base: Font, weight: int) -> Font:
	var result := FontVariation.new()
	result.base_font = base
	result.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return result

func load_atlas(path: String, columns: int, rows: int, hero: bool = false) -> RefCounted:
	return AtlasScript.new(load(path), columns, rows, hero) if ResourceLoader.exists(path) else null

func setup_input() -> void:
	var bindings: Dictionary = {"move_left":[KEY_A,KEY_LEFT], "move_right":[KEY_D,KEY_RIGHT], "jump":[KEY_SPACE,KEY_W,KEY_UP],
		"attack":[KEY_J,KEY_X], "skill":[KEY_K,KEY_C], "dash":[KEY_L,KEY_SHIFT], "interact":[KEY_E], "swords":[KEY_U], "shield":[KEY_I]}
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key in bindings[action]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key
			InputMap.action_add_event(action, key_event)

func start_run(selected_mode: String = "", seed_value: int = 0) -> void:
	if not selected_mode.is_empty():
		mode = selected_mode
	rng.randomize()
	run_seed = seed_value if seed_value != 0 else rng.randi_range(1, 999999)
	rng.seed = run_seed
	event_order.assign([0,1,2,3,4,5,6,7,8,9,10,11])
	for group in range(4):
		var at: int = group * 3 + (0 if group > 0 else 1)
		if at + 1 < 11 and rng.randf() > 0.5:
			var saved: int = event_order[at]
			event_order[at] = event_order[at + 1]
			event_order[at + 1] = saved
	room_index = 0
	cleared_rooms = 0
	run_time = 0
	score = 0
	coins = 0
	total_kills = 0
	bonus_damage = 0
	ward = 0
	skill_ranks.clear()
	upgrade_choices.clear()
	player.health = max_health()
	player.energy = 100
	route = "normal"
	logs.clear()
	build_room()
	log_event("同事：毅川救我！今天的工单有点多。", Color("e6bb85"))
	say("来了", 3)
	audio.sfx("start")

func build_room() -> void:
	state = "loading"
	for child in world.get_children():
		if child != player:
			child.queue_free()
	enemies.clear()
	platforms.clear()
	gates.clear()
	coffee.clear()
	projectiles.clear()
	particles.clear()
	effects.clear()
	trails.clear()
	floating_text.clear()
	hazards.clear()
	trap_cycles.clear()
	npcs.clear()
	boss_ref = null
	stage = (room_index / 3) % 4
	event = Data.EVENTS[event_order[room_index % event_order.size()]]
	room_data = Rooms.generate(run_seed, room_index, route)
	world_length = room_data.length
	room_phase = "approach"
	room_clock = 0
	room_kills = 0
	room_wave = 0
	relay_count = 0
	npc_contract = false
	chest_open = false
	scenery = WorldScript.new()
	scenery.game = self
	scenery.z_index = -10
	world.add_child(scenery)
	for rect in room_data.platforms:
		platforms.append(rect)
		add_solid(rect)
	add_solid(Rect2(-30, 200, 30, 600))
	add_solid(Rect2(world_length, 200, 30, 600))
	for gate_x in room_data.gates:
		var rect := Rect2(float(gate_x),-200,24,1000)
		gates.append({"rect":rect,"body":add_solid(rect),"open":false})
	npcs.append({"id":room_index % 4, "p":Vector2(295,600), "used":false})
	npcs.append({"id":(room_index + 2) % 4, "p":Vector2(1900,480), "used":false})
	coffee.append({"p":Vector2(1385,455), "taken":false})
	player.position = room_data.spawn
	player.velocity = Vector2.ZERO
	player.reset_motion()
	player.reset_physics_interpolation()
	if route == "supply":
		player.health = mini(max_health(), player.health + 2)
	player.energy = minf(100, player.energy + 35)
	player.invulnerable = 0.5
	camera_x = 0
	world.position = Vector2.ZERO
	world.visible = true
	chapter_time = 3.5
	speech_time = 0
	feedback_time = 0
	state = "playing"
	log_event("%02d · %s / %s" % [room_index + 1,event.tool,event.title], event.color)

func add_solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.get_center()
	if rect.size.y <= 24:
		collider.one_way_collision = true
		collider.one_way_collision_margin = 5
	body.add_child(collider)
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)
	return body

func rank(id: String) -> int:
	return int(skill_ranks.get(id,0))

func max_health() -> int:
	return 8 + rank("health") * 2

func cooldown_scale() -> float:
	return 1.0 - rank("cooldown") * 0.12

func melee_damage() -> int:
	return 1 + rank("blade") + rank("overclock") + bonus_damage

func spawn_bug(point: Vector2, kind: String, boss: bool = false, depth: int = 0) -> CharacterBody2D:
	var bug := BugScript.new()
	bug.position = point
	bug.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	bug.kind = kind
	bug.is_boss = boss
	bug.spawn_depth = depth
	bug.game = self
	enemies.append(bug)
	world.add_child(bug)
	return bug

func enemy_health(boss: bool) -> int:
	var amount: int = 26 + room_index * 6 if boss else 3 + room_index / 3
	return ceili(amount * (1.3 if route == "elite" else 1.0))

func spawn_wave(index: int) -> void:
	room_wave = index
	room_phase = "combat"
	var count: int = mini(10,4 + room_index / 4 + (2 if route == "elite" else 0) + (2 if npc_contract and index == 1 else 0))
	var mixed: Array[String] = [event.kind,"ugs","script","p4","shader","nanite","lumen","ddc","gc","leak","live","net"]
	for i in range(count):
		var kind: String = event.kind if i % 2 == 0 else mixed[rng.randi_range(1,mixed.size() - 1)]
		var x: float = (650 if index == 0 else 1640) + i * (800.0 / maxf(1,count - 1))
		if (x > 990 and x < 1210) or (x > 2200 and x < 2420):
			x = 1240 if index == 0 else 2450
		spawn_bug(Vector2(x,465 if kind in ["script","net","lumen","nanite"] else 598),kind)
	feedback = "第 %d / 2 波 · 清理故障后修复发光节点" % (index + 1)
	feedback_time = 3
	audio.sfx("select")

func summon_boss() -> void:
	room_phase = "boss"
	boss_ref = spawn_bug(room_data.boss_spawn,event.kind,true)
	chapter_time = 0
	feedback_time = 0
	log_event("BOSS · " + event.boss + "：先看蓄力预警，再出刀。",event.color)
	say("怀不上了" if event.kind == "boss" else "来了",2.5)
	projectiles.clear()
	burst(room_data.boss_spawn + Vector2(0,-78),event.color,40)

func open_gate(index: int) -> void:
	if index < 0 or index >= gates.size() or gates[index].open:
		return
	gates[index].open = true
	if is_instance_valid(gates[index].body):
		gates[index].body.queue_free()

func objective_target() -> Dictionary:
	if room_phase == "boss" and is_instance_valid(boss_ref) and not boss_ref.dead:
		return {"p":boss_ref.position,"label":"关底 Boss","hint":"J 斩击 · K 破锁","color":Color("ec9c82")}
	if room_phase == "combat" or room_phase == "boss":
		var nearest: Node = null
		var distance: float = INF
		for bug in enemies:
			if is_instance_valid(bug) and not bug.dead:
				var current: float = player.position.distance_squared_to(bug.position)
				if current < distance:
					distance = current
					nearest = bug
		if nearest != null:
			return {"p":nearest.position,"label":"关底 Boss" if nearest.is_boss else "剩余故障", "hint":"J 斩击 · K 破锁", "color":Color("ec9c82")}
	if room_phase == "relay" and relay_count < room_data.relays.size():
		return {"p":room_data.relays[relay_count].p,"label":"修复节点 %d" % (relay_count + 1),"hint":"跳上高台，按 E 重启","color":Color("b4e7bd")}
	return {"p":Vector2(535,598),"label":"进入战区","hint":"向右前进，开始救场","color":event.color}

func gate_hint(index: int) -> String:
	if index == relay_count and room_phase == "relay":
		return "修复上层节点 %d · 按 E" % (index + 1)
	return "清理当前波次后修复节点 %d" % (index + 1)

func _process(delta: float) -> void:
	clock += delta
	if state == "playing":
		run_time += delta
		room_clock += delta
		speech_time = maxf(0,speech_time - delta)
		chapter_time = maxf(0,chapter_time - delta)
		feedback_time = maxf(0,feedback_time - delta)
		shake = maxf(0,shake - delta * 38)
		damage_flash = maxf(0,damage_flash - delta)
		camera_x = lerpf(camera_x,clampf(player.position.x - 440,0,world_length - 1280),1 - exp(-delta * 8))
		world.position = Vector2(-camera_x + sin(clock * 133) * shake,cos(clock * 97) * shake * 0.45)
		update_effects(delta)
		update_hazards(delta)
		enemies = enemies.filter(func(bug): return is_instance_valid(bug) and not bug.dead)
		if room_phase == "approach" and player.position.x > 510:
			spawn_wave(0)
		elif room_phase == "combat" and enemies.is_empty():
			room_phase = "relay"
			feedback = "故障已清空：跳到发光节点，按 E 修复。"
			feedback_time = 4
		for cup in coffee:
			if not cup.taken and player.position.distance_to(cup.p + Vector2(0,25)) < 55:
				cup.taken = true
				player.health = mini(max_health(),player.health + 2)
				player.energy = minf(100,player.energy + 30)
				vfx(7,cup.p,80,0.4)
				audio.sfx("coffee")
		if Input.is_action_just_pressed("interact"):
			interact()
	if is_instance_valid(scenery):
		scenery.queue_redraw()
	hud.queue_redraw()

func update_effects(delta: float) -> void:
	for item in particles:
		item.life -= delta
		item.p += item.v * delta
		item.v.y += 430 * delta
	particles = particles.filter(func(p): return p.life > 0)
	for item in effects:
		item.life -= delta
	effects = effects.filter(func(p): return p.life > 0)
	for item in trails:
		item.life -= delta
	trails = trails.filter(func(p): return p.life > 0)
	for item in floating_text:
		item.life -= delta
		item.p.y -= 26 * delta
	floating_text = floating_text.filter(func(p): return p.life > 0)
	for orb in projectiles.duplicate():
		orb.life -= delta
		if orb.delay > 0:
			orb.delay -= delta
			continue
		if orb.friendly and is_instance_valid(orb.target) and not orb.target.dead:
			orb.v = (orb.target.position + Vector2(0,-35) - orb.p).normalized() * 520
		orb.p += orb.v * delta
		if orb.life <= 0:
			continue
		if orb.friendly:
			for bug in enemies.duplicate():
				if is_instance_valid(bug) and not bug.dead and bug.get_bounds().grow(7).has_point(orb.p):
					bug.take_hit(orb.damage,signf(orb.v.x),true)
					orb.life = 0
					break
		elif orb.p.distance_to(player.position + Vector2(0,-35)) < 23:
			player.hurt(1,orb.p.x)
			orb.life = 0
	projectiles = projectiles.filter(func(p): return p.life > 0 and p.p.x > -100 and p.p.x < world_length + 100 and p.p.y > -200 and p.p.y < 850)

func trap_phase(index: int) -> float:
	return fmod(room_clock + index * 1.7,5.5)

func trap_state(index: int) -> String:
	if event.hazard == "cache":
		return "safe"
	if room_phase == "approach":
		return "idle"
	var phase: float = trap_phase(index)
	if phase >= 3.8 and phase < 4.6:
		return "active"
	if phase >= 2.9 and phase < 3.8:
		return "warning"
	return "idle"

func trap_area(index: int) -> Rect2:
	return room_data.traps[index].grow_individual(0,65,0,0)

func update_hazards(delta: float) -> void:
	if room_phase == "approach":
		return
	for i in range(room_data.traps.size()):
		var rect: Rect2 = room_data.traps[i]
		var cycle: int = int((room_clock + i * 1.7) / 5.5)
		if trap_state(i) == "active":
			if trap_area(i).intersects(player.bounds()):
				if event.hazard == "vacuum":
					player.energy = maxf(0,player.energy - 18 * delta)
				elif event.hazard != "cache":
					player.hurt(1,rect.get_center().x)
			if int(trap_cycles.get(i,-1)) != cycle and absf(rect.position.x - player.position.x) < 850:
				trap_cycles[i] = cycle
				if event.hazard in ["light","delayed","pulse"]:
					var p: Vector2 = rect.get_center() + Vector2(0,-35)
					var direction: Vector2 = (player.position + Vector2(0,-40) - p).normalized()
					shoot(p,direction * 180,event.color,0.75 if event.hazard == "delayed" else 0)
	for hazard in hazards:
		hazard.delay -= delta
		if hazard.delay <= 0:
			hazard.life -= delta
			if hazard.rect.intersects(player.bounds()):
				player.hurt(1,hazard.rect.get_center().x)
	hazards = hazards.filter(func(h): return h.life > 0)

func ground_support(point: Vector2) -> bool:
	for rect in platforms:
		if rect.has_point(point):
			return true
	return false

func interact() -> void:
	for i in range(npcs.size()):
		if player.position.distance_to(npcs[i].p) < 110:
			npc_selected = i
			state = "npc"
			card_selection = 0
			return
	if not chest_open and player.position.distance_to(room_data.chest) < 110:
		chest_open = true
		coins += 14
		player.energy = minf(100,player.energy + 30)
		vfx(7,room_data.chest + Vector2(0,-25),100,0.5)
		if event.hazard == "cache":
			spawn_bug(room_data.chest + Vector2(-80,-25),"ddc")
			spawn_bug(Vector2(3040,598),"ddc")
			say("坏啦",2,"毅川 · 缓存箱活过来了")
		else:
			float_text("+14 工单 · 能量补给",room_data.chest + Vector2(0,-70),Color("eed09a"))
		return
	for i in range(room_data.relays.size()):
		var relay: Dictionary = room_data.relays[i]
		if player.position.distance_to(relay.p) < 110:
			if relay.done:
				feedback = "这个节点已经恢复。"
			elif room_phase != "relay" or i != relay_count:
				feedback = "先清理当前波次，再按顺序重启节点。"
			else:
				relay.done = true
				open_gate(i)
				relay_count += 1
				player.energy = minf(100,player.energy + 25)
				burst(relay.p + Vector2(0,-40),Color("a7eec0"),25)
				audio.sfx("repair")
				if relay_count == 1:
					spawn_wave(1)
				else:
					summon_boss()
				return
			feedback_time = 3
			return
	feedback = "E 与 NPC 交谈、打开宝箱，或修复已解锁节点。"
	feedback_time = 3

func accept_npc() -> void:
	if npc_selected < 0 or npc_selected >= npcs.size():
		return
	var npc: Dictionary = npcs[npc_selected]
	var spec: Dictionary = Data.NPCS[npc.id]
	if npc.used:
		state = "playing"
		return
	match int(npc.id):
		0:
			player.health = mini(max_health(),player.health + 2)
			player.energy = minf(100,player.energy + 30)
		1:
			npc_contract = true
			if room_wave == 1:
				spawn_bug(Vector2(2000,598),event.kind)
				spawn_bug(Vector2(2500,598),event.kind)
				if room_phase == "relay":
					room_phase = "combat"
		2:
			ward = mini(3,ward + 1)
		3:
			if coins < 12:
				feedback = "工单不足：只狼的训练需要 12 工单。"
				feedback_time = 3
				return
			coins -= 12
			bonus_damage += 1
	npc.used = true
	state = "playing"
	say(spec.quote,3,spec.name,npc.p)
	log_event(spec.name + "：" + spec.quote,spec.color)
	audio.sfx("coffee")

func bug_defeated(bug: CharacterBody2D) -> void:
	total_kills += 1
	room_kills += 1
	coins += ceili((12 if bug.is_boss else 2) * (1 + rank("loot") * 0.25) * (1.5 if route == "elite" else 1.0))
	score += 500 if bug.is_boss else 35
	player.energy = minf(100,player.energy + 5 + rank("energy") * 4 + (6 if event.hazard == "vacuum" else 0))
	if rank("leech") > 0 and total_kills % (10 - rank("leech") * 2) == 0:
		player.health = mini(max_health(),player.health + 1)
	burst(bug.position + Vector2(0,-35),bug.color(),24)
	if bug.is_boss:
		cleared_rooms += 1
		room_phase = "reward"
		coins += 25 if npc_contract else 0
		projectiles.clear()
		hazards.clear()
		player.health = mini(max_health(),player.health + 1)
		player.energy = 100
		upgrade_choices = roll_upgrades()
		state = "upgrade"
		card_selection = 0
		log_event("%s 已解决 · 选择技能继续救场。" % event.title,Color("b5e4bc"))
		audio.sfx("win")
		update_records(false)
	elif bug.kind == "leak" and bug.spawn_depth == 0 and enemies.size() < 16:
		for offset in [-32,32]:
			spawn_bug(bug.position + Vector2(offset,-8),"leak",false,1)

func roll_upgrades() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for skill in Data.SKILLS:
		if rank(skill.id) < int(skill.max):
			pool.append(skill)
	var choices: Array[Dictionary] = []
	while not pool.is_empty() and choices.size() < 3:
		var index: int = rng.randi_range(0,pool.size() - 1)
		choices.append(pool[index])
		pool.remove_at(index)
	for boon in Data.BOONS:
		if choices.size() < 3:
			choices.append(boon)
	if cleared_rooms == 1 and rank("swords") == 0 and not choices.any(func(skill): return skill.id == "swords"):
		choices[0] = Data.skill("swords")
	return choices

func choose_upgrade(index: int) -> void:
	if state != "upgrade" or index < 0 or index >= upgrade_choices.size():
		return
	var skill: Dictionary = upgrade_choices[index]
	if rank(skill.id) >= int(skill.max):
		return
	apply_upgrade(skill.id)
	upgrade_choices.clear()
	audio.sfx("repair")
	if mode == "story" and cleared_rooms >= STORY_ROOMS:
		state = "won"
		update_records(true)
	else:
		state = "route"
		card_selection = 0

func apply_upgrade(id: String) -> void:
	skill_ranks[id] = rank(id) + 1
	if id == "health":
		player.health = mini(max_health(),player.health + 2)
	elif id == "rest":
		player.health = max_health()
		player.energy = 100
	elif id == "funds":
		coins += 40
		player.health = mini(max_health(),player.health + 2)
	log_event("新技能：%s Lv.%d" % [Data.skill(id).name,rank(id)],Color("b8e9c6"))

func choose_route(index: int) -> void:
	if state != "route" or index not in [0,1]:
		return
	route = "supply" if index == 0 else "elite"
	room_index += 1
	build_room()

func resolve_attack(bug: Node, amount: int, direction: float) -> void:
	if not is_instance_valid(bug) or bug.dead:
		return
	var critical: bool = rng.randf() < rank("crit") * 0.1
	var applied: bool = bug.take_hit(amount * (2 if critical else 1),direction,false)
	if not applied:
		return
	if critical:
		float_text("暴击",bug.position + Vector2(0,-100),Color("ffdaa4"))
	if rank("burn") > 0:
		bug.burn_time = 3
		bug.burn_damage = rank("burn")
	if rank("chain") > 0:
		for other in enemies.duplicate():
			if is_instance_valid(other) and other != bug and not other.dead and other.position.distance_to(bug.position) < 220:
				other.take_hit(rank("chain"),direction,true)
				vfx(5,other.position + Vector2(0,-35),80,0.3)
				break

func use_swords() -> void:
	if rank("swords") == 0 or player.swords_cooldown > 0:
		return
	var targets: Array = enemies.filter(func(bug): return is_instance_valid(bug) and not bug.dead and bug.position.distance_to(player.position) < 720)
	if targets.is_empty():
		feedback = "飞剑范围内没有敌人。"
		feedback_time = 2
		return
	player.swords_cooldown = (7.0 - rank("swords") * 0.6) * cooldown_scale()
	for i in range(2 + rank("swords")):
		var target: Node = targets[i % targets.size()]
		shoot(player.position + Vector2(i * 11 - 15,-80 - i * 6),Vector2(0,-120),Color("f7d58b"),i * 0.06,true,1 + rank("swords"),target)
	audio.sfx("skill")

func fall_recover() -> void:
	player.invulnerable = 0
	player.hurt(2,player.position.x + 1)
	if state == "playing":
		player.position = Vector2(980 if player.position.x < 1180 else 2160,470)
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()
		say("坏啦",2,"毅川 · 空指针深渊")

func die() -> void:
	state = "dead"
	speech = "哦豁，完蛋"
	speech_time = 8
	audio.sfx("dead")
	update_records(false)

func update_records(won: bool) -> void:
	best_score = maxi(best_score,score)
	if mode == "endless":
		best_floor = maxi(best_floor,cleared_rooms)
	elif won and (best_time <= 0 or run_time < best_time):
		best_time = run_time
	save_record()

func load_record() -> void:
	if FileAccess.file_exists(record_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if data is Dictionary:
			best_time = float(data.get("rogue_best_time",0))
			best_floor = int(data.get("best_floor",0))
			best_score = int(data.get("best_score",0))

func save_record() -> void:
	var file := FileAccess.open(record_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"rogue_best_time":best_time,"best_floor":best_floor,"best_score":best_score}))

func shoot(point: Vector2, velocity: Vector2, color: Color, delay: float = 0, friendly: bool = false, amount: int = 1, target: Node = null) -> void:
	projectiles.append({"p":point,"v":velocity,"color":color,"delay":delay,"friendly":friendly,"damage":amount,"target":target,"life":7.0})

func vfx(index: int, point: Vector2, size: float = 100, duration: float = 0.25, facing: float = 1) -> void:
	effects.append({"index":index,"p":point,"size":size,"life":duration,"duration":duration,"facing":facing})

func burst(point: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"p":point,"v":Vector2(rng.randf_range(-170,170),rng.randf_range(-220,60)),"color":color,"life":rng.randf_range(0.25,0.65),"size":rng.randi_range(2,6)})

func float_text(value: String, point: Vector2, color: Color) -> void:
	floating_text.append({"text":value,"p":point,"color":color,"life":1.2})

func say(value: String, duration: float = 2.5, who: String = "毅川 / 虚幻引擎开发师", anchor: Vector2 = Vector2.INF) -> void:
	speech = value
	speaker = who
	speech_time = duration
	speech_anchor = anchor

func log_event(value: String, color: Color) -> void:
	logs.append({"text":value,"color":color})
	if logs.size() > 3:
		logs.pop_front()

func time_label(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60,int(seconds) % 60]

func _unhandled_input(input: InputEvent) -> void:
	if input is InputEventKey and input.pressed and not input.echo:
		var key: int = input.keycode
		if key == KEY_M:
			muted = not muted
			AudioServer.set_bus_mute(0,muted)
		elif key == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif key in [KEY_1,KEY_2,KEY_3] and state == "upgrade":
			choose_upgrade(key - KEY_1)
		elif key in [KEY_1,KEY_2] and state == "route":
			choose_route(key - KEY_1)
		elif key == KEY_F1 and state in ["title","playing","paused","guide"]:
			toggle_panel("guide")
		elif key == KEY_TAB and state in ["playing","paused","build"]:
			toggle_panel("build")
		elif key == KEY_ESCAPE:
			if state == "playing":
				state = "paused"
			elif state == "paused":
				state = "playing"
			elif state in ["build","guide"]:
				state = previous_state
			elif state == "npc":
				state = "playing"
		elif key == KEY_R and state in ["dead","won"]:
			start_run()
		elif key in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]:
			var increment: int = -1 if key in [KEY_LEFT,KEY_UP] else 1
			if state == "title":
				selection = posmod(selection + increment,3)
			elif state in ["upgrade","route"]:
				card_selection = posmod(card_selection + increment,3 if state == "upgrade" else 2)
		elif key in [KEY_ENTER,KEY_KP_ENTER]:
			match state:
				"title": activate_menu(selection)
				"upgrade": choose_upgrade(card_selection)
				"route": choose_route(card_selection)
				"npc": accept_npc()
				"paused": state = "playing"
				"dead", "won": start_run()
	if input is InputEventMouseButton and input.pressed and input.button_index == MOUSE_BUTTON_LEFT:
		handle_click(get_global_mouse_position())

func toggle_panel(panel: String) -> void:
	if state == panel:
		state = previous_state
	else:
		previous_state = state
		state = panel

func activate_menu(index: int) -> void:
	if index in [0,1]:
		start_run("story" if index == 0 else "endless")
	else:
		previous_state = "title"
		state = "guide"

func handle_click(point: Vector2) -> void:
	match state:
		"title":
			for i in range(3):
				if Rect2(96,426 + i * 62,320,52).has_point(point):
					activate_menu(i)
		"upgrade":
			for i in range(3):
				if Rect2(160 + i * 328,220,304,328).has_point(point):
					choose_upgrade(i)
		"route":
			for i in range(2):
				if Rect2(285 + i * 370,250,340,280).has_point(point):
					choose_route(i)
		"guide", "build":
			if Rect2(1000,65,150,44).has_point(point):
				state = previous_state
		"npc":
			if Rect2(445,440,390,58).has_point(point):
				accept_npc()
			elif Rect2(445,515,390,46).has_point(point):
				state = "playing"
		"paused", "dead", "won":
			if Rect2(470,440,340,60).has_point(point):
				if state == "paused":
					state = "playing"
				else:
					start_run()
			elif Rect2(470,518,340,48).has_point(point):
				state = "title"
				world.visible = false
		"playing":
			if Rect2(1180,23,64,46).has_point(point):
				state = "paused"
