extends Node2D
## Fixed-step simulation: every actor moves on the same top-down plane.

const Data = preload("res://scripts/dungeon_data.gd")
const View = preload("res://scripts/dungeon_view.gd")
const Audio = preload("res://scripts/audio.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
var hero_atlas: RefCounted
var cast_atlas: RefCounted
var basan_atlas: RefCounted
var jiahao_atlas: RefCounted
var shark_atlas: RefCounted
var item_atlas: RefCounted
var enemy_atlas: RefCounted
var environment_atlas: RefCounted
var vfx_atlas: RefCounted
var utility_atlas: RefCounted
var camera: Camera2D
var camera_shake: float = 0.0
var footstep_timer: float = 0.0
var corridors: Array[Dictionary] = []
var contract_pending: bool = false
var state: String = "title"
var return_state: String = "playing"
var clock: float = 0.0
var run_time: float = 0.0
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var floor_index: int = 0
var room_id: int = 0
var rooms: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var nav := AStarGrid2D.new()
var player: Vector2 = Data.CENTER
var facing: Vector2 = Vector2.RIGHT
var player_moving: bool = false
var health: float = 80.0
var points: int = 0
var earned: int = 0
var kills: int = 0
var cleared_count: int = 0
var weapons: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var stock: Array[Dictionary] = []
var shop_return: String = "playing"
var selected_weapon: int = 0
var difficulty: int = 1
var run_difficulty: int = 1
var wave: int = 0
var wave_total: int = 0
var wave_wait: float = 0.0
var room_time: float = 0.0
var door_cooldown: float = 0.0
var interaction_cooldown: float = 0.0
var invulnerable: float = 0.0
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var dialogue_index: int = 0
var dialogue_kind: String = "intro"
var message: String = ""
var message_time: float = 0.0
var speech: String = ""
var speech_time: float = 0.0
var buff_damage: float = 0.0
var skill_levels: Dictionary = {}
var skill_offers: Array[Dictionary] = []
var previous_player: Vector2 = Data.CENTER
var previous_knight: Vector2 = Data.CENTER
var knight_active: bool = false
var knight: Vector2 = Data.CENTER + Vector2(-52, 0)
var knight_cooldown: float = 0.0
var onion_skill: bool = false
var onion_cooldown: float = 0.0
var shield_time: float = 0.0
var contract_active: bool = false
var cheat_invincible: bool = false
var cheat_one_hit: bool = false
var assisted: bool = false
var selected_npc: int = -1
var best_score: int = 0
var best_floor: int = 0
var record_path: String = "user://dungeon-record-v1.json"
var font: Font
var bold: Font
var pixel: Font
var audio: Node
var view: Node2D
var muted: bool = false
var show_fps: bool = false

func _ready() -> void:
	var base: Font = load("res://assets/fonts/NotoSansSC.ttf")
	var weight_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	var regular := FontVariation.new()
	regular.base_font = base
	regular.variation_opentype = {weight_tag:550}
	font = regular
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {weight_tag:850}
	bold = variation
	pixel = load("res://assets/fonts/PressStart2P.ttf")
	hero_atlas = Atlas.new(load("res://assets/generated/dungeon/hero.png"), 4, 4, true)
	cast_atlas = Atlas.new(load("res://assets/generated/dungeon/cast.png"), 4, 4)
	basan_atlas = Atlas.new(load("res://assets/generated/dungeon/basan.png"), 2, 1)
	jiahao_atlas = Atlas.new(load("res://assets/generated/dungeon/jiahao.png"), 2, 1)
	shark_atlas = Atlas.new(load("res://assets/generated/dungeon/big-shark.png"), 2, 2)
	item_atlas = Atlas.new(load("res://assets/generated/dungeon/items.png"), 4, 3)
	enemy_atlas = Atlas.new(load("res://assets/generated/dungeon/enemies.png"), 4, 4)
	environment_atlas = Atlas.new(load("res://assets/generated/dungeon/environment-office.png"), 4, 3)
	vfx_atlas = Atlas.new(load("res://assets/generated/dungeon/combat-vfx.png"), 4, 4)
	utility_atlas = Atlas.new(load("res://assets/generated/dungeon/dungeon-utility.png"), 4, 4)
	setup_input()
	audio = Audio.new()
	add_child(audio)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	view = View.new()
	view.game = self
	add_child(view)
	load_record()
	if "--smoke-play" in OS.get_cmdline_user_args():
		start_run(20261113, true)

func setup_input() -> void:
	var bindings: Dictionary = {"move_left":[KEY_A, KEY_LEFT], "move_right":[KEY_D, KEY_RIGHT], "move_up":[KEY_W, KEY_UP], "move_down":[KEY_S, KEY_DOWN], "dash":[KEY_SPACE, KEY_SHIFT], "interact":[KEY_E], "onion":[KEY_Q]}
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func start_run(chosen_seed: int = 0, skip_story: bool = false) -> void:
	rng.randomize()
	seed_value = chosen_seed if chosen_seed != 0 else rng.randi_range(1, 99999999)
	rng.seed = seed_value
	run_difficulty = difficulty
	floor_index = 0
	points = 30
	earned = 0
	kills = 0
	cleared_count = 0
	run_time = 0
	buff_damage = 0
	skill_levels.clear()
	skill_offers.clear()
	onion_skill = false
	onion_cooldown = 0
	shield_time = 0
	knight_active = false
	contract_pending = false
	weapons.clear()
	equipment.clear()
	add_item(Data.WEAPONS[selected_weapon].id)
	health = max_health()
	assisted = cheat_invincible or cheat_one_hit
	generate_floor()
	speech = "来了"
	speech_time = 2
	if not skip_story:
		dialogue_kind = "intro"
		dialogue_index = 0
		state = "dialogue"
	audio.sfx("start")

func generate_floor() -> void:
	state = "loading"
	var generated: Dictionary = Data.generate(seed_value, floor_index)
	rooms.assign(generated.rooms)
	corridors.assign(generated.corridors)
	room_id = 0
	enemies.clear()
	projectiles.clear()
	drops.clear()
	effects.clear()
	texts.clear()
	obstacles.clear()
	for room in rooms:
		obstacles.append_array(room.obstacles)
	view.rebuild_geometry()
	knight_active = false
	enter_room(0)
	notify(Data.FLOOR_NAMES[floor_index])

func current_room() -> Dictionary:
	return rooms[room_id] if not rooms.is_empty() else {}

func room_center() -> Vector2:
	return current_room().center if not rooms.is_empty() else Data.CENTER

func camera_snap() -> void:
	previous_player = player
	previous_knight = knight
	camera.position = player
	camera.offset = Vector2.ZERO
	camera_shake = 0
	camera.reset_physics_interpolation()

func enter_room(id: int, from_direction: int = -1) -> bool:
	# Spawn/debug helper. Walking between rooms uses update_room_presence instead.
	if id < 0 or id >= rooms.size():
		return false
	if state == "playing" and not current_room().cleared and id != room_id:
		return false
	var destination: Dictionary = rooms[id]
	player = destination.center if from_direction < 0 else destination.doors[(from_direction + 2) % 4].move_toward(destination.center, 96)
	knight = player + Vector2(-30, 24)
	dash_time = 0
	invulnerable = 0.9
	interaction_cooldown = 0.25
	activate_room(id)
	camera_snap()
	return true

func activate_room(id: int) -> void:
	if not enemies.is_empty() and id != room_id:
		return
	collect_drops()
	room_id = id
	var room: Dictionary = current_room()
	room.visited = true
	room.revealed = true
	for link in room.links:
		if link >= 0:
			rooms[link].revealed = true
	projectiles.clear()
	contract_active = false
	room_time = 0
	wave = 0
	wave_wait = 0
	wave_total = 3 if room.type == "elite" else 2
	state = "playing"
	if room.type in ["start", "shop", "treasure", "rest", "npc"]:
		room.cleared = true
	elif not room.cleared:
		room.started = true
		if room.type == "boss":
			wave_total = 1
			spawn_enemy(room.center + Vector2(220, 0), "boss")
			wave = 1
			notify(Data.BOSS_NAMES[floor_index])
		else:
			if contract_pending:
				contract_pending = false
				contract_active = true
				wave_total += 1
			spawn_wave()
	build_navigation()

func update_room_presence() -> void:
	for room in rooms:
		if room.id != room_id and room.rect.grow(-48).has_point(player):
			activate_room(room.id)
			return

func closed_gates() -> Array[Rect2]:
	var gates: Array[Rect2] = []
	if rooms.is_empty():
		return gates
	var room: Dictionary = current_room()
	if room.started and not room.cleared:
		for direction in range(4):
			if room.links[direction] >= 0:
				gates.append(Data.gate_rect(room, direction))
	return gates

func point_on_floor(p: Vector2) -> bool:
	for room in rooms:
		if room.rect.has_point(p):
			return true
	for hall in corridors:
		if hall.rect.has_point(p):
			return true
	return false

func walkable(p: Vector2, radius: float = 13.0) -> bool:
	# Interior circles are fully inside this rectangle; only boundaries need union tests.
	if rooms.is_empty() or not current_room().rect.grow(-radius).has_point(p):
		if not point_on_floor(p):
			return false
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(0.707, 0.707), Vector2(-0.707, 0.707), Vector2(0.707, -0.707), Vector2(-0.707, -0.707)]:
			if not point_on_floor(p + direction * radius):
				return false
	for rect in obstacles:
		if rect.grow(radius).has_point(p):
			return false
	for rect in closed_gates():
		if rect.grow(radius).has_point(p):
			return false
	return true

func nav_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 20), floori(p.y / 20))

func build_navigation(clearance: float = 19.0) -> void:
	var bounds: Rect2 = current_room().rect.grow(40)
	var first: Vector2i = nav_cell(bounds.position)
	var last: Vector2i = nav_cell(bounds.end) + Vector2i.ONE
	nav.region = Rect2i(first, last - first)
	nav.cell_size = Vector2(20, 20)
	nav.offset = Vector2(10, 10)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var p := Vector2(x * 20 + 10, y * 20 + 10)
			if not walkable(p, clearance):
				nav.set_point_solid(Vector2i(x, y))

func slide(p: Vector2, motion: Vector2, radius: float = 13.0) -> Vector2:
	# Small substeps keep dashes from crossing narrow collision islands.
	var steps: int = maxi(1, int(ceil(motion.length() / 7.0)))
	var step: Vector2 = motion / steps
	for i in range(steps):
		if step.x != 0 and walkable(p + Vector2(step.x, 0), radius):
			p.x += step.x
		if step.y != 0 and walkable(p + Vector2(0, step.y), radius):
			p.y += step.y
	return p

func line_clear(a: Vector2, b: Vector2) -> bool:
	# A segment between two points in the same rectangular room cannot leave its floor.
	if rooms.is_empty() or not (current_room().rect.has_point(a) and current_room().rect.has_point(b)):
		var steps: int = maxi(1, ceili(a.distance_to(b) / 20))
		for i in range(steps + 1):
			if not point_on_floor(a.lerp(b, float(i) / steps)):
				return false
	var blockers: Array[Rect2] = obstacles.duplicate()
	blockers.append_array(closed_gates())
	for rect in blockers:
		if Geometry2D.segment_intersects_segment(a, b, rect.position, Vector2(rect.end.x, rect.position.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(rect.end.x, rect.position.y), rect.end) != null or Geometry2D.segment_intersects_segment(a, b, rect.end, Vector2(rect.position.x, rect.end.y)) != null or Geometry2D.segment_intersects_segment(a, b, Vector2(rect.position.x, rect.end.y), rect.position) != null:
			return false
	return true

func _process(delta: float) -> void:
	clock += delta
	message_time = maxf(0, message_time - delta)
	view.queue_redraw()
	if view.overlay != null:
		view.overlay.refresh_ui(delta)

func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	previous_player = player
	previous_knight = knight
	for enemy in enemies:
		enemy.previous_p = enemy.p
	for shot in projectiles:
		shot.previous_p = shot.p
	run_time += delta
	room_time += delta
	invulnerable = maxf(0, invulnerable - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	dash_time = maxf(0, dash_time - delta)
	onion_cooldown = maxf(0, onion_cooldown - delta)
	shield_time = maxf(0, shield_time - delta)
	door_cooldown = maxf(0, door_cooldown - delta)
	interaction_cooldown = maxf(0, interaction_cooldown - delta)
	speech_time = maxf(0, speech_time - delta)
	health = minf(max_health(), health + (equipment_stat("coffee") + skill_level("recovery")) * 0.5 * delta)
	var motion: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player_moving = motion.length_squared() > 0.01
	if player_moving:
		facing = motion.normalized()
	if Input.is_action_just_pressed("dash") and interaction_cooldown <= 0:
		start_dash()
	if Input.is_action_just_pressed("onion") and interaction_cooldown <= 0:
		use_onion()
	player = slide(player, (dash_direction * 780 if dash_time > 0 else motion * move_speed()) * delta)
	update_room_presence()
	camera.position = camera.position.lerp(player, 1.0 - exp(-delta * 10))
	camera_shake = maxf(0, camera_shake - delta * 20)
	camera.offset = Vector2(sin(clock * 61), cos(clock * 53)) * camera_shake
	if dash_time > 0 and effects.size() < 65:
		add_effect("dash", player, player + facing, Color.WHITE, 0.18, 65)
	footstep_timer -= delta
	if player_moving and dash_time <= 0 and footstep_timer <= 0:
		footstep_timer = 0.18
		add_effect("dust", player, player, Color.WHITE, 0.3, 26)
	update_enemies(delta)
	if state != "playing":
		return
	update_weapons(delta)
	update_knight(delta)
	update_projectiles(delta)
	update_drops(delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if effects[i].life <= 0:
			effects.remove_at(i)
	for i in range(texts.size() - 1, -1, -1):
		texts[i].life -= delta
		texts[i].p.y -= 23 * delta
		if texts[i].life <= 0:
			texts.remove_at(i)
	if not current_room().cleared and enemies.is_empty():
		wave_wait += delta
		if wave_wait > 0.7:
			if wave < wave_total:
				spawn_wave()
			else:
				clear_room()
	if Input.is_action_just_pressed("interact") and interaction_cooldown <= 0:
		interact()

func start_dash() -> void:
	if state != "playing" or dash_cooldown > 0:
		return
	dash_direction = facing
	dash_time = 0.17
	dash_cooldown = 1.8 / (1.0 + skill_level("dash") * 0.2)
	invulnerable = maxf(invulnerable, 0.24)
	audio.sfx("dash")

func use_onion() -> void:
	if state != "playing" or not onion_skill or onion_cooldown > 0:
		return
	var level: int = skill_level("onion")
	onion_cooldown = 10.0 / (1.0 + level * 0.15)
	shield_time = 2.0 + level * 0.4
	for enemy in enemies.duplicate():
		if enemy.p.distance_to(player) < 165 + level * 20:
			hit_enemy(enemy, (24 + level * 10) * damage_scale(), player)
	add_effect("burst", player, player, Color.WHITE, 0.5, 280 + level * 35)
	notify("洋葱守护 · %.1f 秒护盾" % shield_time)
	audio.sfx("skill")

func spawn_wave() -> void:
	if current_room().type not in ["combat", "elite"]:
		return
	wave += 1
	wave_wait = 0
	if current_room().type == "elite" and wave == wave_total:
		spawn_enemy(spawn_point(50), "shark")
		build_navigation(35)
		notify("精英首领 · 大鲨鱼")
		return
	var count: int = 8 + floor_index * 3 + wave * 4 + (4 if current_room().type == "elite" else 0)
	for i in range(count):
		var kind: String = "ranged" if i % 4 == 3 else ("charger" if i % 5 == 4 else "slime")
		spawn_enemy(spawn_point(), kind)
	notify("%s · 第 %d / %d 波" % [Data.ROOM_NAMES[current_room().type], wave, wave_total])

func spawn_point(radius: float = 23.0) -> Vector2:
	var fallback: Vector2 = room_center() + Vector2(220, 0) if player.x < room_center().x else room_center() - Vector2(220, 0)
	var best_gap: float = -INF
	for attempt in range(150):
		var p := Vector2(rng.randf_range(current_room().rect.position.x + 65, current_room().rect.end.x - 65), rng.randf_range(current_room().rect.position.y + 75, current_room().rect.end.y - 65))
		if not walkable(p, radius) or p.distance_to(player) <= 230:
			continue
		var gap: float = INF
		for enemy in enemies:
			if not enemy.dead:
				gap = minf(gap, p.distance_to(enemy.p) - radius - enemy.radius - 10)
		if gap >= 0:
			return p
		if gap > best_gap:
			best_gap = gap
			fallback = p
	return fallback

func spawn_enemy(p: Vector2, kind: String = "slime") -> Dictionary:
	if current_room().type == "npc":
		return {}
	var boss_kind: bool = kind in ["boss", "shark"]
	var hp: float = (390 + floor_index * 260 if boss_kind else 22 + floor_index * 13) * Data.DIFFICULTIES[run_difficulty].enemy
	if kind == "shark":
		hp = (270 + floor_index * 170) * Data.DIFFICULTIES[run_difficulty].enemy
	if kind == "charger":
		hp *= 1.5
	if current_room().type == "elite" and not boss_kind:
		hp *= 1.35
	var enemy: Dictionary = {"p":p, "kind":kind, "hp":hp, "max_hp":hp, "radius":33.0 if kind == "shark" else (29.0 if boss_kind else 16.0), "speed":66.0 + floor_index * 12, "age":0.0, "cooldown":2.0 + rng.randf(), "windup":0.0, "aim":Vector2.RIGHT, "charge":0.0, "flash":0.0, "path":PackedVector2Array(), "path_time":0.0, "dead":false, "phase":0}
	enemies.append(enemy)
	enemy.previous_p = p
	return enemy

func is_boss(enemy: Dictionary) -> bool:
	return enemy.kind in ["boss", "shark"]

func boss_name(enemy: Dictionary) -> String:
	return "大鲨鱼" if enemy.kind == "shark" else Data.BOSS_NAMES[floor_index]

func target_near(p: Vector2, reach: float) -> Dictionary:
	var result: Dictionary = {}
	var closest: float = reach
	for enemy in enemies:
		var distance: float = enemy.p.distance_to(p)
		if not enemy.dead and enemy.age > 0.65 and distance < closest and line_clear(p, enemy.p):
			closest = distance
			result = enemy
	return result

func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if enemy.dead:
			continue
		enemy.age += delta
		enemy.flash = maxf(0, enemy.flash - delta)
		if enemy.age < 0.8:
			continue
		var offset: Vector2 = player - enemy.p
		var distance: float = offset.length()
		enemy.cooldown -= delta
		var speed: float = enemy.speed
		if is_boss(enemy):
			if enemy.hp < enemy.max_hp * 0.5 and enemy.phase == 0:
				enemy.phase = 1
				notify("大鲨鱼进入狂暴阶段！" if enemy.kind == "shark" else ("杨梓亮：再加一个小需求！" if floor_index == 2 else "首领进入狂暴阶段！"))
				enemy.cooldown = 0.1
			speed = 82 + enemy.phase * 14 if enemy.kind == "shark" else 52
			if enemy.cooldown <= 0 and enemy.windup <= 0:
				enemy.windup = 0.85
				enemy.aim = offset.normalized()
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					boss_attack(enemy)
					enemy.cooldown = 2.4 if enemy.phase == 0 else 1.7
		elif enemy.kind == "ranged":
			speed = 0 if distance > 185 and distance < 320 else (speed if distance >= 320 else -speed * 0.7)
			if enemy.cooldown <= 0 and enemy.windup <= 0 and line_clear(enemy.p, player):
				enemy.windup = 0.65
				enemy.aim = offset.normalized()
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					shoot(enemy.p, enemy.aim * 225, 9 + floor_index * 2, false, Color("ff8e9f"), 0)
					enemy.cooldown = 2.3
		elif enemy.kind == "charger":
			if enemy.cooldown <= 0 and enemy.windup <= 0 and enemy.charge <= 0:
				enemy.windup = 0.65
				enemy.aim = offset.normalized()
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					enemy.charge = 0.48
					enemy.cooldown = 3.4
		if enemy.charge > 0:
			enemy.charge -= delta
			enemy.p = slide(enemy.p, enemy.aim * 340 * delta, enemy.radius)
		elif speed != 0:
			var direction: Vector2 = offset.normalized()
			if not line_clear(enemy.p, player) and speed > 0:
				enemy.path_time -= delta
				if enemy.path_time <= 0:
					var source := nav_cell(enemy.p)
					var destination := nav_cell(player)
					if nav.is_in_boundsv(source) and nav.is_in_boundsv(destination) and not nav.is_point_solid(source) and not nav.is_point_solid(destination):
						enemy.path = nav.get_point_path(source, destination)
					enemy.path_time = 0.4
				if enemy.path.size() > 1:
					direction = (enemy.path[1] - enemy.p).normalized()
					if enemy.p.distance_to(enemy.path[1]) < 12:
						enemy.path.remove_at(0)
			var separation := Vector2.ZERO
			for other in enemies:
				if other != enemy and not other.dead:
					var difference: Vector2 = enemy.p - other.p
					if difference.length_squared() > 1 and difference.length_squared() < 900:
						separation += difference.normalized() * 20
			enemy.p = slide(enemy.p, (direction * speed + separation) * delta, enemy.radius)
		if enemy.p.distance_to(player) < enemy.radius + 12:
			hurt(12 if is_boss(enemy) else 8, enemy.p)

func boss_attack(enemy: Dictionary) -> void:
	if enemy.kind == "shark":
		enemy.charge = 0.52 + enemy.phase * 0.12
		var count: int = 5 + enemy.phase * 2
		for i in range(count):
			shoot(enemy.p, enemy.aim.rotated((i - (count - 1) * 0.5) * 0.18) * 225, 11 + floor_index * 2, false, Color("8fcfff"))
		add_effect("burst", enemy.p, enemy.p, Color.WHITE, 0.4, 130)
		return
	var count: int = 10 + floor_index * 2 + enemy.phase * 4
	for i in range(count):
		var direction: Vector2 = Vector2.from_angle(TAU * i / count + room_time * 0.25)
		shoot(enemy.p, direction * (145 + floor_index * 20), 12 + floor_index * 2, false, Color("ffb178"), 0)
	for i in range(3):
		shoot(enemy.p, enemy.aim.rotated((i - 1) * 0.17) * 240, 14, false, Color("ff8099"), 0)
	add_effect("burst", enemy.p, enemy.p, Color.WHITE, 0.45, 150)
	if enemy.phase > 0 and enemies.size() < 7:
		for i in range(2):
			spawn_enemy(spawn_point(), "slime" if floor_index < 2 else "ranged")

func update_weapons(delta: float) -> void:
	for weapon in weapons:
		weapon.cooldown = maxf(0, weapon.cooldown - delta)
		weapon.recoil = maxf(0, float(weapon.get("recoil", 0.0)) - delta)
		if weapon.cooldown > 0:
			continue
		var spec: Dictionary = Data.item(weapon.id)
		var target: Dictionary = target_near(player, spec.reach)
		if target.is_empty():
			continue
		var aim: Vector2 = (target.p - player).normalized()
		weapon.aim = aim
		weapon.recoil = 0.16
		weapon.cooldown = spec.cooldown / attack_speed()
		var damage: float = spec.damage * Data.multiplier(weapon.tier) * damage_scale()
		match weapon.id:
			"blade", "spear", "orb":
				add_effect("slash" if weapon.id == "blade" else ("thrust" if weapon.id == "spear" else "burst"), player, player + aim * spec.reach, spec.color, 0.24, spec.reach)
				for enemy in enemies.duplicate():
					var offset: Vector2 = enemy.p - player
					var hit: bool = offset.length() <= spec.reach
					if weapon.id == "blade":
						hit = hit and aim.dot(offset.normalized()) > 0.2
					elif weapon.id == "spear":
						hit = hit and aim.dot(offset.normalized()) > 0.89
					if hit and line_clear(player, enemy.p):
						hit_enemy(enemy, damage, player)
			"wand":
				var origin: Vector2 = player
				var chain: Dictionary = target
				var struck: Array[Dictionary] = []
				for i in range(weapon.tier + 1):
					if chain.is_empty():
						break
					struck.append(chain)
					add_effect("beam", origin, chain.p, spec.color, 0.22, 0)
					origin = chain.p
					hit_enemy(chain, damage * pow(0.8, i), player)
					chain = {}
					for candidate in enemies:
						if candidate not in struck and not candidate.dead and candidate.p.distance_to(origin) < 165 and line_clear(origin, candidate.p):
							chain = candidate
			"shotgun":
				for i in range(5):
					shoot(player + aim * 24, aim.rotated((i - 2) * 0.14) * 500, damage, true, spec.color, 0, 0.62)
			_:
				shoot(player + aim * 24, aim * 650, damage, true, spec.color, 1 if weapon.tier >= 3 else 0)
		audio.sfx("slash" if weapon.id == "blade" else "hit")

func update_knight(delta: float) -> void:
	if not knight_active:
		return
	knight_cooldown = maxf(0, knight_cooldown - delta)
	var target: Dictionary = target_near(knight, 360)
	var destination: Vector2 = player + Vector2(-42, 24) if target.is_empty() else target.p
	if knight.distance_to(destination) > 52:
		knight = slide(knight, (destination - knight).normalized() * 230 * delta)
	if knight.distance_to(player) > 250:
		knight = player + Vector2(-24, 24)
	if not target.is_empty() and knight.distance_to(target.p) < 100 and knight_cooldown <= 0:
		knight_cooldown = 0.7
		add_effect("slash", knight, target.p, Color("d9e6dc"), 0.22, 86)
		hit_enemy(target, 22 + floor_index * 10, knight)

func shoot(p: Vector2, velocity: Vector2, damage: float, friendly: bool, color: Color, pierce: int = 0, life: float = 1.8) -> void:
	if friendly:
		add_effect("muzzle", p, p + velocity.normalized(), Color.WHITE, 0.1, 42)
	projectiles.append({"p":p, "previous_p":p, "velocity":velocity, "damage":damage, "friendly":friendly, "color":color, "pierce":pierce, "life":life, "hit":[]})

func update_projectiles(delta: float) -> void:
	var active_shots: Array[Dictionary] = projectiles.duplicate()
	active_shots.reverse()
	for shot in active_shots:
		if shot not in projectiles:
			continue
		shot.life -= delta
		var motion: Vector2 = shot.velocity * delta
		var steps: int = maxi(1, int(ceil(motion.length() / 7)))
		for step in range(steps):
			shot.p += motion / steps
			if not walkable(shot.p, 3):
				shot.life = 0
				break
			if shot.friendly:
				for enemy in enemies.duplicate():
					if not enemy.dead and enemy.age > 0.65 and enemy not in shot.hit and enemy.p.distance_to(shot.p) < enemy.radius + 5:
						shot.hit.append(enemy)
						hit_enemy(enemy, shot.damage, shot.p - shot.velocity.normalized() * 20)
						shot.pierce -= 1
						if shot.pierce < 0:
							shot.life = 0
							break
			elif shot.p.distance_to(player) < 16:
				hurt(shot.damage, shot.p)
				shot.life = 0
			if shot.life <= 0:
				break
		if shot.life <= 0:
			projectiles.erase(shot)

func hit_enemy(enemy: Dictionary, damage: float, source: Vector2) -> void:
	if enemy.is_empty() or enemy.dead:
		return
	if cheat_one_hit:
		damage = enemy.max_hp + 1
	enemy.hp -= damage
	enemy.flash = 0.12
	add_effect("impact", enemy.p + Vector2(0, -18), enemy.p + (enemy.p - source).normalized(), Color.WHITE, 0.26, 60)
	camera_shake = maxf(camera_shake, 1.8 if not is_boss(enemy) else 3.0)
	texts.append({"p":enemy.p + Vector2(-10, -28), "text":str(int(ceil(damage))), "color":Color("ffe2b3"), "life":0.65})
	if not is_boss(enemy):
		enemy.p = slide(enemy.p, (enemy.p - source).normalized() * 11, enemy.radius)
	if enemy.hp <= 0:
		enemy.dead = true
		kills += 1
		var reward: int = 60 if is_boss(enemy) else (5 if enemy.kind == "charger" else 3)
		drops.append({"p":enemy.p, "value":reward, "age":0.0})
		add_effect("burst", enemy.p + Vector2(0, -16), enemy.p, Color.WHITE, 0.35, 75)
		enemies.erase(enemy)
		if is_boss(enemy):
			for other in enemies:
				other.dead = true
			enemies.clear()
			projectiles.clear()

func hurt(amount: float, source: Vector2) -> void:
	if state != "playing" or invulnerable > 0 or shield_time > 0 or cheat_invincible:
		return
	var actual: float = maxf(1, amount * (1.0 - minf(0.65, equipment_stat("vest") * 0.12)) * Data.DIFFICULTIES[run_difficulty].damage)
	health -= actual
	invulnerable = 0.85
	camera_shake = 5
	add_effect("impact", player + Vector2(0, -22), player, Color.WHITE, 0.3, 72)
	if speech_time <= 0:
		var phrases: Array[String] = ["救命", "坏啦", "怀不上了"]
		speech = phrases[rng.randi_range(0, phrases.size() - 1)]
		speech_time = 2.5
	player = slide(player, (player - source).normalized() * 24)
	texts.append({"p":player + Vector2(-10, -42), "text":"-" + str(int(ceil(actual))), "color":Color("ff8e9f"), "life":0.8})
	audio.sfx("hurt")
	if health <= 0:
		health = 0
		finish_run(false)

func update_drops(delta: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[i]
		drop.age += delta
		var distance: float = drop.p.distance_to(player)
		if distance < 140 or current_room().cleared:
			drop.p = drop.p.move_toward(player, (330 + drop.age * 35) * delta)
		if drop.p.distance_to(player) < 22:
			gain_points(drop.value)
			drops.remove_at(i)

func gain_points(amount: int) -> void:
	points += amount
	earned += amount

func collect_drops() -> void:
	for drop in drops:
		gain_points(drop.value)
	drops.clear()

func clear_room() -> void:
	var room: Dictionary = current_room()
	if room.cleared:
		return
	room.cleared = true
	projectiles.clear()
	collect_drops()
	cleared_count += 1
	gain_points(18 if room.type != "boss" else 60)
	health = minf(max_health(), health + 4)
	if contract_active:
		gain_points(45)
		contract_active = false
		notify("加急工单完成 · 罗德支付了 45 积分")
	else:
		notify("战区已清空 · 积分已收集 · 所有出口开启")
	if room.type == "boss":
		open_skill_reward()
	elif room.type in ["combat", "elite"]:
		room.reward_shop = true
		open_shop()
		notify("战后补给 · 首次刷新免费")
	audio.sfx("repair")

func max_health() -> float:
	return float(Data.DIFFICULTIES[run_difficulty].health) + (equipment_stat("heart") + skill_level("vigor")) * 20

func equipment_stat(id: String) -> float:
	var result: float = 0
	for entry in equipment:
		if entry.id == id:
			result += Data.multiplier(entry.tier)
	return result

func move_speed() -> float:
	return 220 * (1 + equipment_stat("boots") * 0.1)

func damage_scale() -> float:
	return 1 + buff_damage + (equipment_stat("scope") + skill_level("power")) * 0.15

func attack_speed() -> float:
	return 1 + (equipment_stat("chip") + skill_level("haste")) * 0.12

func skill_level(id: String) -> int:
	return int(skill_levels.get(id, 0))

func open_skill_reward() -> void:
	var room: Dictionary = current_room()
	if room.type != "boss" or not room.cleared or room.skill_claimed:
		return
	if skill_offers.is_empty():
		var pool: Array[Dictionary] = Data.SKILLS.duplicate()
		var reward_rng := RandomNumberGenerator.new()
		reward_rng.seed = seed_value + floor_index * 8191 + 707
		for i in range(3):
			var index: int = reward_rng.randi_range(0, pool.size() - 1)
			skill_offers.append(pool[index])
			pool.remove_at(index)
	state = "skill"
	notify("关卡通关 · 选择一项技能提升")

func choose_skill(index: int) -> bool:
	if state != "skill" or index < 0 or index >= skill_offers.size() or current_room().skill_claimed:
		return false
	var id: String = skill_offers[index].id
	skill_levels[id] = skill_level(id) + 1
	if id == "vigor":
		health = minf(max_health(), health + 20)
	elif id == "onion":
		onion_skill = true
		onion_cooldown = 0
	current_room().skill_claimed = true
	skill_offers.clear()
	audio.sfx("skill")
	state = "playing"
	if floor_index < 2:
		next_floor()
	else:
		dialogue_kind = "ending"
		dialogue_index = 0
		state = "dialogue"
	return true

func render_position(current: Vector2, previous: Vector2) -> Vector2:
	# Immediate-mode drawings need interpolation too; Node2D interpolation only moves nodes.
	if not is_physics_processing() or state != "playing":
		return current
	return previous.lerp(current, Engine.get_physics_interpolation_fraction())

func can_add_item(id: String, tier: int = 1) -> bool:
	var spec: Dictionary = Data.item(id)
	if spec.is_empty() or tier < 1 or tier > 4:
		return false
	var inventory: Array[Dictionary] = weapons if spec.kind == "weapon" else equipment
	if inventory.size() < 6:
		return true
	if tier < 4:
		for entry in inventory:
			if entry.id == id and entry.tier == tier:
				return true
	return false

func add_item(id: String, tier: int = 1) -> bool:
	var spec: Dictionary = Data.item(id)
	if spec.is_empty() or tier < 1 or tier > 4:
		return false
	var inventory: Array[Dictionary] = weapons if spec.kind == "weapon" else equipment
	if not can_add_item(id, tier):
		notify("%s栏已满 · 没有可合并的同名同品质物品" % ("武器" if spec.kind == "weapon" else "装备"))
		return false
	var auto_merge: bool = inventory.size() >= 6
	var previous_max: float = max_health()
	inventory.append({"id":id, "tier":tier, "cooldown":0.0, "aim":Vector2.RIGHT})
	if id == "heart":
		health += max_health() - previous_max
	if auto_merge:
		var index: int = inventory.size() - 1
		while fusion_pair(spec.kind, index) >= 0:
			index = merge_pair(spec.kind, index)
		notify("自动合并 · %s %s" % [Data.TIER_NAMES[inventory[index].tier - 1], spec.name])
		audio.sfx("repair")
	return true

func fusion_pair(kind: String, index: int) -> int:
	var inventory: Array[Dictionary] = weapons if kind == "weapon" else equipment
	if index < 0 or index >= inventory.size() or inventory[index].tier >= 4:
		return -1
	for i in range(inventory.size()):
		if i != index and inventory[i].id == inventory[index].id and inventory[i].tier == inventory[index].tier:
			return i
	return -1

func fuse(kind: String, index: int) -> bool:
	if state not in ["inventory", "shop"]:
		return false
	var merged: int = merge_pair(kind, index)
	if merged < 0:
		notify("需要两件同名、同品质物品；传说为最高品质")
		return false
	var inventory: Array[Dictionary] = weapons if kind == "weapon" else equipment
	var entry: Dictionary = inventory[merged]
	notify("合并成功 · %s %s" % [Data.TIER_NAMES[entry.tier - 1], Data.item(entry.id).name])
	audio.sfx("repair")
	return true

func merge_pair(kind: String, index: int) -> int:
	var inventory: Array[Dictionary] = weapons if kind == "weapon" else equipment
	var partner: int = fusion_pair(kind, index)
	if partner < 0:
		return -1
	var previous_max: float = max_health()
	var entry: Dictionary = inventory[index]
	entry.tier += 1
	entry.cooldown = 0
	inventory.remove_at(partner)
	health = minf(health + maxf(0, max_health() - previous_max), max_health())
	return index - 1 if partner < index else index

func sell(kind: String, index: int) -> bool:
	if state not in ["inventory", "shop"]:
		return false
	var inventory: Array[Dictionary] = weapons if kind == "weapon" else equipment
	if index < 0 or index >= inventory.size():
		return false
	if kind == "weapon" and inventory.size() <= 1:
		notify("至少保留一把武器")
		return false
	var entry: Dictionary = inventory[index]
	points += sell_price(entry)
	inventory.remove_at(index)
	health = minf(health, max_health())
	notify("物品已出售 · 积分已返还")
	return true

func sell_price(entry: Dictionary) -> int:
	return maxi(1, int(Data.item(entry.id).price * pow(2, entry.tier - 1) * 0.45))

func shop_price(entry: Dictionary) -> int:
	var discount: float = 0.85 if current_room().type == "shop" else 1.0
	return maxi(1, int(ceil(Data.item(entry.id).price * pow(2, entry.tier - 1) * discount)))

func has_shop() -> bool:
	var room: Dictionary = current_room()
	if room.type == "shop" or room.get("reward_shop", false) and room.cleared:
		return true
	return room.type == "npc" and room.npc >= 0 and room.npc < Data.NPCS.size() and Data.NPCS[room.npc].id == "coin"

func open_shop() -> void:
	if state not in ["playing", "npc"] or not current_room().cleared or not has_shop():
		return
	collect_drops()
	shop_return = state
	state = "shop"
	if current_room().stock.is_empty():
		roll_stock()
	stock = current_room().stock

func leave_shop() -> void:
	if state != "shop":
		return
	state = shop_return
	interaction_cooldown = 0.25

func roll_stock() -> void:
	var room: Dictionary = current_room()
	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = seed_value + floor_index * 8191 + room_id * 101 + room.refreshes * 100003
	var offers: Array[Dictionary] = []
	var weapon_pool: Array[Dictionary] = []
	var equipment_pool: Array[Dictionary] = []
	weapon_pool.assign(Data.WEAPONS)
	equipment_pool.assign(Data.EQUIPMENT)
	for i in range(4):
		var pool: Array[Dictionary] = weapon_pool if i < 2 else equipment_pool
		var spec: Dictionary = pool[shop_rng.randi_range(0, pool.size() - 1)]
		var tier: int = 1
		if i == 0 and not weapons.is_empty():
			spec = Data.item(weapons[0].id)
			tier = mini(3, weapons[0].tier)
		elif floor_index > 0 and shop_rng.randf() < 0.25:
			tier = 2
		pool.erase(spec)
		offers.append({"id":spec.id, "tier":tier, "sold":false})
	if not room.stock.is_empty():
		var same: bool = true
		for i in range(4):
			same = same and room.stock[i].id == offers[i].id and room.stock[i].tier == offers[i].tier
		if same:
			# Preserve useful matching copies, while guaranteeing a visibly new shelf.
			var alternatives: Array[Dictionary] = []
			for spec in Data.WEAPONS:
				if spec.id != offers[0].id and spec.id != offers[1].id:
					alternatives.append(spec)
			offers[1].id = alternatives[shop_rng.randi_range(0, alternatives.size() - 1)].id
	room.stock = offers
	stock = room.stock

func buy(index: int) -> bool:
	if state != "shop" or index < 0 or index >= stock.size() or stock[index].sold:
		return false
	var offer: Dictionary = stock[index]
	var price: int = shop_price(offer)
	if points < price:
		notify("积分不足 · 清怪和完成委托可以获得积分")
		return false
	var inventory: Array[Dictionary] = weapons if Data.item(offer.id).kind == "weapon" else equipment
	var auto_merge: bool = inventory.size() >= 6
	if not add_item(offer.id, offer.tier):
		return false
	points -= price
	offer.sold = true
	if not auto_merge:
		notify("获得 " + Data.item(offer.id).name + " · Tab 查看 / 合并")
	audio.sfx("coffee")
	return true

func refresh_price() -> int:
	return 0 if current_room().refreshes == 0 else 4 + (current_room().refreshes - 1) * 2

func refresh_shop() -> bool:
	if state != "shop":
		return false
	var price: int = refresh_price()
	if points < price:
		notify("刷新需要 %d 积分" % price)
		return false
	points -= price
	current_room().refreshes += 1
	roll_stock()
	return true

func npc_position() -> Vector2:
	return room_center() + Vector2(-112, 0)

func interact() -> void:
	if state != "playing":
		return
	var room: Dictionary = current_room()
	if not room.cleared:
		notify("先击败全部敌人，出口与交互会自动解锁")
		return
	if room.type == "npc" and room.npc >= 0 and player.distance_to(npc_position()) < 72:
		selected_npc = room.npc
		state = "npc"
		return
	if not room.rect.has_point(player):
		return
	if player.distance_to(room_center()) > 90:
		notify("走近中央装置或 NPC 后按 E")
		return
	match room.type:
		"boss": open_skill_reward()
		"combat", "elite":
			if room.get("reward_shop", false):
				open_shop()
		"treasure":
			if not room.used:
				var gift: Dictionary = Data.WEAPONS[rng.randi_range(0, Data.WEAPONS.size() - 1)]
				var auto_merge: bool = weapons.size() >= 6
				if add_item(gift.id, 2):
					room.used = true
					if not auto_merge:
						notify("宝库开启 · 获得精良 " + gift.name)
					audio.sfx("repair")
			else:
				notify("宝库已经领取过了")
		"rest":
			if not room.used:
				room.used = true
				health = minf(max_health(), health + 40)
				notify("咖啡驿站 · 恢复 40 生命")
				audio.sfx("coffee")
			else:
				notify("咖啡已经喝完了，继续前进吧")
		"shop": open_shop()

func accept_npc() -> bool:
	if state != "npc" or selected_npc < 0 or selected_npc >= Data.NPCS.size():
		return false
	var room: Dictionary = current_room()
	if room.type != "npc" or room.npc != selected_npc:
		return false
	var spec: Dictionary = Data.NPCS[selected_npc]
	if spec.id == "coin":
		open_shop()
		return true
	if room.get("npc_used", false):
		notify("这次已经帮过你了，继续救公主吧")
		return false
	match spec.id:
		"ruoyu": health = minf(max_health(), health + 35)
		"rhode":
			contract_pending = true
			notify("委托已接受 · 下一间战斗房追加一波")
		"heide":
			knight_active = true
			knight = player + Vector2(32, 20)
			knight_cooldown = 0
		"basan":
			if points < 12:
				notify("八桑：先凑够 12 积分再来")
				return false
			points -= 12
			buff_damage += 0.12
		"laya":
			var candidates: Array[Dictionary] = []
			for spec_item in Data.WEAPONS + Data.EQUIPMENT:
				if can_add_item(spec_item.id):
					candidates.append(spec_item)
			if candidates.is_empty():
				notify("菈雅：先在 Tab 背包里腾出一个位置吧")
				return false
			var gift: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
			var inventory: Array[Dictionary] = weapons if gift.kind == "weapon" else equipment
			var auto_merge: bool = inventory.size() >= 6
			if not add_item(gift.id):
				return false
			if not auto_merge:
				notify("菈雅送给你 " + gift.name)
		"onion":
			onion_skill = true
			onion_cooldown = 0
			notify("学会 Q 洋葱守护 · 震退敌人并获得 2 秒护盾")
		"jiahao":
			var upgraded: bool = false
			for weapon in weapons:
				if weapon.tier < 4:
					weapon.tier += 1
					weapon.cooldown = 0
					upgraded = true
					notify("嘉豪改装完成 · %s %s" % [Data.TIER_NAMES[weapon.tier - 1], Data.item(weapon.id).name])
					break
			if not upgraded:
				notify("嘉豪：你的武器都已经是传说品质了")
				return false
	room.npc_used = true
	state = "playing"
	interaction_cooldown = 0.25
	audio.sfx("repair")
	return true

func next_floor() -> bool:
	if state != "playing" or current_room().type != "boss" or not current_room().cleared or not current_room().skill_claimed or floor_index >= 2:
		return false
	collect_drops()
	floor_index += 1
	knight_active = false
	health = minf(max_health(), health + 25)
	state = "transition"
	generate_floor()
	dialogue_kind = "floor"
	dialogue_index = 0
	state = "dialogue"
	return true

func advance_dialogue() -> void:
	if state != "dialogue":
		return
	dialogue_index += 1
	if dialogue_kind == "intro" and dialogue_index < Data.DIALOGUES.size():
		return
	if dialogue_kind == "ending" and dialogue_index < 3:
		return
	if dialogue_kind == "ending":
		finish_run(true)
	else:
		state = "playing"
		interaction_cooldown = 0.25

func dialogue() -> Dictionary:
	if dialogue_kind == "intro":
		return Data.DIALOGUES[mini(dialogue_index, Data.DIALOGUES.size() - 1)]
	if dialogue_kind == "ending":
		var lines: Array[Dictionary] = [
			{"speaker":"杨梓亮 · 策划", "line":"好吧……这版需求通过了。公主，你可以走了。"},
			{"speaker":"ChatGPT 公主", "line":"毅川，你真的来了！这次，我们一起把故事写完吧。"},
			{"speaker":"毅川", "line":"来了。保存，提交，今晚准时下班。"}
		]
		return lines[mini(dialogue_index, 2)]
	return {"speaker":"ChatGPT 公主", "line":"我收到你的信号了！" + ("前面是迭代工坊，小心那些会冲刺的需求。" if floor_index == 1 else "杨梓亮就在城堡深处。毅川，我等你！") + "（生命恢复 25；海德骑士已在层间离队。）"}

func finish_run(won: bool) -> void:
	state = "won" if won else "dead"
	if not assisted:
		best_score = maxi(best_score, earned)
		best_floor = maxi(best_floor, floor_index + (1 if won else 0))
		save_record()
	audio.sfx("win" if won else "dead")

func save_record() -> bool:
	var file := FileAccess.open(record_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":1, "score":best_score, "floor":best_floor}))
	file.close()
	return DirAccess.rename_absolute(record_path + ".tmp", record_path) == OK

func load_record() -> void:
	if not FileAccess.file_exists(record_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	if data is Dictionary:
		best_score = maxi(0, int(data.get("score", 0)))
		best_floor = clampi(int(data.get("floor", 0)), 0, 3)

func notify(value: String) -> void:
	message = value
	message_time = 3.5

func add_effect(kind: String, a: Vector2, b: Vector2, color: Color, life: float, size: float) -> void:
	effects.append({"kind":kind, "a":a, "b":b, "color":color, "life":life, "max_life":life, "size":size})

func toggle_inventory() -> void:
	if state == "inventory":
		state = return_state
	elif state in ["playing", "shop", "paused", "npc"]:
		return_state = state
		state = "inventory"

func start_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/sandbox.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		view.click(get_viewport().get_mouse_position())
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.keycode
	if code == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif code == KEY_F3:
		show_fps = not show_fps
	elif code == KEY_M:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
	elif code == KEY_HOME and state in ["playing", "paused", "cheats"]:
		if state == "cheats":
			state = return_state
		else:
			return_state = state
			state = "cheats"
	elif code == KEY_TAB:
		toggle_inventory()
	elif code == KEY_F1:
		if state == "guide":
			state = return_state
		elif state in ["title", "playing", "paused"]:
			return_state = state
			state = "guide"
	elif code == KEY_ESCAPE:
		match state:
			"playing": toggle_inventory()
			"paused", "npc": state = "playing"
			"inventory", "guide", "map", "cheats": state = return_state
			"shop": leave_shop()
			"dialogue":
				if dialogue_kind == "ending":
					finish_run(true)
				else:
					state = "playing"
	elif state == "dialogue" and code in [KEY_ENTER, KEY_SPACE, KEY_E]:
		advance_dialogue()
	elif state == "title":
		if code == KEY_ENTER:
			start_run()
		elif code == KEY_B:
			start_sandbox()
		elif code in [KEY_LEFT, KEY_A]:
			selected_weapon = posmod(selected_weapon - 1, 4)
		elif code in [KEY_RIGHT, KEY_D]:
			selected_weapon = (selected_weapon + 1) % 4
	elif state in ["dead", "won"] and code in [KEY_R, KEY_ENTER]:
		start_run()
	elif state == "paused" and code == KEY_ENTER:
		state = "playing"
	elif state == "shop":
		if code >= KEY_1 and code <= KEY_4:
			buy(code - KEY_1)
		elif code == KEY_R:
			refresh_shop()
	elif state == "skill" and code >= KEY_1 and code <= KEY_3:
		choose_skill(code - KEY_1)
	elif state == "npc" and code in [KEY_ENTER, KEY_E]:
		accept_npc()
	elif state == "cheats" and code in [KEY_1, KEY_2]:
		toggle_cheat(code - KEY_1)

func toggle_cheat(index: int) -> void:
	if state != "cheats":
		return
	if index == 0:
		cheat_invincible = not cheat_invincible
	else:
		cheat_one_hit = not cheat_one_hit
	assisted = assisted or cheat_invincible or cheat_one_hit
