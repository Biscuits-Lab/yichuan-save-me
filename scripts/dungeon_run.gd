extends Node2D
## Fixed-step simulation: every actor moves on the same top-down plane.

const Data = preload("res://scripts/dungeon_data.gd")
const View = preload("res://scripts/dungeon_view.gd")
const Audio = preload("res://scripts/audio.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
var hero_atlas: RefCounted
var cast_atlas: RefCounted
var heide_atlas: RefCounted
var basan_atlas: RefCounted
var jiahao_atlas: RefCounted
var shark_atlas: RefCounted
var yamada_atlas: RefCounted
var yamada_split_atlas: RefCounted
var wilds_atlas: RefCounted
var stage_atlases: Dictionary = {}
var item_atlas: RefCounted
var workplace_item_atlas: RefCounted
var item_icons: Dictionary = {}
var enemy_atlas: RefCounted
var themed_enemy_atlas: RefCounted
var street_atlas: RefCounted
var street_surface_atlas: RefCounted
var street_enemy_atlas: RefCounted
var security_atlas: RefCounted
var home_enemy_atlas: RefCounted
var ruoyu_atlases: Array[RefCounted] = []
var ruoyu_unseal_atlas: RefCounted
var ruoyu_pounce_atlas: RefCounted
var yang_atlas: RefCounted
var yang_escort_atlas: RefCounted
var yang_peak_atlas: RefCounted
var ruoyu_unseal_time: float = 0.0
var environment_atlas: RefCounted
var vfx_atlas: RefCounted
var utility_atlas: RefCounted
var byte_atlas: RefCounted
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
var cover_damage: Dictionary = {}
var broken_obstacles: Array[Rect2] = []
var nav := AStarGrid2D.new()
var player: Vector2 = Data.CENTER
var facing: Vector2 = Vector2.RIGHT
var player_moving: bool = false
var health: float = 25.0
var points: int = 0
var earned: int = 0
var kills: int = 0
var cleared_count: int = 0
var weapons: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var turrets: Array[Dictionary] = []
var turret_ready_at: Dictionary = {}
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
var spawn_remaining: int = 0
var spawn_timer: float = 0.0
var spawn_serial: int = 0
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
var knight_facing: Vector2 = Vector2.DOWN
var knight_moving: bool = false
var knight_animation_time: float = 0.0
var knight_attack_time: float = 0.0
var knight_path: PackedVector2Array = []
var knight_path_time: float = 0.0
var onion_skill: bool = false
var onion_cooldown: float = 0.0
var shield_time: float = 0.0
var contract_active: bool = false
var cheat_invincible: bool = false
var cheat_one_hit: bool = false
var assisted: bool = false
var selected_npc: int = -1
var npc_reply: String = ""
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
	heide_atlas = Atlas.new(load("res://assets/generated/dungeon/heide-animations.png"), 8, 4)
	# Sword and cape extents vary; keep the animation's scale and feet root fixed.
	var heide_baselines: Array[float] = []
	for frame in heide_atlas.frames:
		heide_baselines.append(frame.anchor.y)
	heide_baselines.sort()
	var heide_heights: Array[float] = heide_atlas.row_heights.duplicate()
	heide_heights.sort()
	for frame in heide_atlas.frames:
		frame.anchor = Vector2(frame.region.size.x / 2, heide_baselines[heide_baselines.size() / 2])
	heide_atlas.row_heights.fill(heide_heights[heide_heights.size() / 2])
	basan_atlas = Atlas.new(load("res://assets/generated/dungeon/basan.png"), 2, 1)
	jiahao_atlas = Atlas.new(load("res://assets/generated/dungeon/jiahao.png"), 2, 1)
	shark_atlas = Atlas.new(load("res://assets/generated/dungeon/big-shark.png"), 2, 2)
	yamada_atlas = Atlas.new(load("res://assets/generated/dungeon/yamada-actions.png"), 4, 2)
	yamada_split_atlas = Atlas.new(load("res://assets/generated/dungeon/yamada-split.png"), 2, 2)
	yamada_atlas.row_heights.fill(yamada_atlas.frames[0].height)
	yamada_split_atlas.row_heights.fill(yamada_split_atlas.frames[0].height)
	wilds_atlas = Atlas.new(load("res://assets/generated/dungeon/wilds-cast.png"), 4, 4)
	stage_atlases["wilds"] = Atlas.new(load("res://assets/generated/dungeon/environment-wilds.png"), 4, 3)
	for theme in ["server", "sumo"]:
		stage_atlases[theme] = Atlas.new(load("res://assets/generated/dungeon/environment-%s.png" % theme), 4, 2)
	stage_atlases["dark_home"] = Atlas.new(load("res://assets/generated/dungeon/environment-dark-home.png"), 4, 3, false, {
		0:Rect2i(2, 2, 380, 336), 1:Rect2i(386, 2, 380, 336), 2:Rect2i(770, 2, 380, 336),
		3:Rect2i(1154, 2, 380, 336), 8:Rect2i(2, 685, 380, 335)
	}, [4, 5, 6, 7, 9, 10, 11])
	item_atlas = Atlas.new(load("res://assets/generated/dungeon/items.png"), 4, 3)
	workplace_item_atlas = Atlas.new(load("res://assets/generated/dungeon/workplace-items.png"), 6, 6, false, {5:Rect2i(1051, 0, 203, 209)}, range(36))
	for spec in Data.EQUIPMENT + Data.WEAPONS.slice(6):
		if not spec.has("art_frame"):
			item_icons[spec.id] = Atlas.new(load("res://assets/generated/dungeon/icons/%s.png" % spec.id), 1, 1)
	# Yang's head extends above the equal-grid seam. Split both rows in the transparent gap.
	var enemy_cells: Dictionary = {}
	for column in range(4):
		var x: int = column * 313
		enemy_cells[8 + column] = Rect2i(x, 626, 313, 239)
		enemy_cells[12 + column] = Rect2i(x, 865, 313, 389)
	enemy_atlas = Atlas.new(load("res://assets/generated/dungeon/enemies.png"), 4, 4, false, enemy_cells)
	# The orchid's petal tips cross one grid line, so these cells cut between the silhouettes.
	themed_enemy_atlas = Atlas.new(load("res://assets/generated/dungeon/floor-monsters.png"), 4, 6, false, {
		11:Rect2i(768, 512, 256, 232), 15:Rect2i(752, 755, 272, 269)
	}, range(24))
	street_atlas = Atlas.new(load("res://assets/generated/dungeon/zhangjiang-street.png"), 1, 1, false, {0:Rect2i(0, 512, 784, 512)}, [0])
	street_surface_atlas = Atlas.new(load("res://assets/generated/dungeon/zhangjiang-tiles.png"), 4, 2, false, {
		0:Rect2i(18, 15, 344, 482), 1:Rect2i(394, 10, 361, 491), 5:Rect2i(405, 620, 350, 275)
	}, [2, 3, 4, 5, 6, 7])
	street_enemy_atlas = Atlas.new(load("res://assets/generated/dungeon/zhangjiang-enemy-actions.png"), 8, 3, false, {19:Rect2i(652, 590, 242, 297)}, range(24))
	security_atlas = Atlas.new(load("res://assets/generated/dungeon/security-uncle-actions.png"), 5, 2, false, {}, range(10))
	home_enemy_atlas = Atlas.new(load("res://assets/generated/dungeon/dark-home-enemies.png"), 6, 3, false, {}, range(18))
	ruoyu_atlases.append(Atlas.new(load("res://assets/generated/dungeon/ruoyu-actions.png"), 6, 2, false, {}, range(12)))
	ruoyu_atlases.append(Atlas.new(load("res://assets/generated/dungeon/ruoyu-unsealed-actions.png"), 6, 2, false, {}, range(12)))
	ruoyu_unseal_atlas = Atlas.new(load("res://assets/generated/dungeon/ruoyu-unseal.png"), 2, 2, false, {}, range(4))
	ruoyu_pounce_atlas = Atlas.new(load("res://assets/generated/dungeon/ruoyu-pounce.png"), 4, 2, false, {}, range(8))
	yang_atlas = Atlas.new(load("res://assets/generated/dungeon/yang-actions.png"), 4, 3, false, {}, range(8))
	# The wider casting poses cross the nominal column seams; cut in the transparent gutters.
	yang_escort_atlas = Atlas.new(load("res://assets/generated/dungeon/yang-escorts.png"), 6, 2, false, {
		10: Rect2i(1448, 362, 330, 362), 11: Rect2i(1778, 362, 394, 362)
	}, range(12))
	yang_peak_atlas = Atlas.new(load("res://assets/generated/dungeon/yang-peak.png"), 4, 3, false, {
		4: Rect2i(0, 362, 333, 362), 5: Rect2i(333, 362, 391, 362),
		8: Rect2i(0, 724, 333, 362), 9: Rect2i(333, 724, 391, 362),
		10: Rect2i(724, 724, 322, 362), 11: Rect2i(1046, 724, 402, 362)
	}, range(12))
	environment_atlas = Atlas.new(load("res://assets/generated/dungeon/environment-office.png"), 4, 3)
	vfx_atlas = Atlas.new(load("res://assets/generated/dungeon/combat-vfx.png"), 4, 4)
	utility_atlas = Atlas.new(load("res://assets/generated/dungeon/dungeon-utility.png"), 4, 4)
	byte_atlas = Atlas.new(load("res://assets/generated/dungeon/icons/byte.png"), 1, 1)
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
	var args := OS.get_cmdline_user_args()
	if "--check-startup" in args and state == "title" and view.overlay != null and view.overlay.is_visible_in_tree():
		print("STARTUP CHECK: title initialized")
	if "--smoke-play" in args:
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
	turret_ready_at.clear()
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
	ruoyu_unseal_time = 0.0
	speech_time = 0.0
	audio.play_floor_music(Data.FLOOR_STYLES[floor_index])
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
	cover_damage.clear()
	broken_obstacles.clear()
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
	turrets.clear()
	contract_active = false
	room_time = 0
	wave = 0
	wave_wait = 0
	spawn_remaining = 0
	spawn_timer = 0
	spawn_serial = 0
	wave_total = (2 if room.get("encounter", "double") == "double" else 1) + (1 if room.type == "elite" else 0)
	state = "playing"
	if room.type in ["start", "shop", "treasure", "rest", "npc"]:
		room.cleared = true
	elif not room.cleared:
		room.started = true
		if room.type == "boss":
			wave_total = 1
			spawn_enemy(room.center + Vector2(220, 0), "boss")
			wave = 1
			notify("杨梓亮 · 护盾开启，先击败召援" if Data.FLOOR_STYLES[floor_index] == "castle" else Data.BOSS_NAMES[floor_index])
		else:
			if contract_pending:
				contract_pending = false
				contract_active = true
				wave_total += 1
			spawn_wave()
	build_navigation()
	knight_path.clear()
	knight_path_time = 0
	# Seal the encounter with the companion inside, even when he trails in the hall.
	if knight_active and room.started and not room.cleared and (not room.rect.grow(-32).has_point(knight) or not walkable(knight)):
		regroup_knight()

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
			nav.set_point_solid(Vector2i(x, y), not walkable(p, clearance))

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

func hit_cover(rect: Rect2) -> void:
	if rect not in obstacles:
		return
	cover_damage[rect] = int(cover_damage.get(rect, 0)) + 1
	add_effect("impact", rect.get_center(), rect.get_center(), Color.WHITE, 0.2, 45)
	if cover_damage[rect] >= 3:
		obstacles.erase(rect)
		broken_obstacles.append(rect)
		add_effect("dust", rect.get_center(), rect.get_center(), Color.WHITE, 0.5, 120)
		if current_room().rect.intersects(rect):
			build_navigation()
			for enemy in enemies:
				enemy.path_time = 0
	audio.sfx("hit")

func hit_cover_area(origin: Vector2, aim: Vector2, reach: float, arc: float = -1.0, beam: bool = false) -> void:
	for rect in obstacles.duplicate():
		var point: Vector2 = origin.clamp(rect.position, rect.end)
		var offset: Vector2 = point - origin
		if offset.length() > reach or aim.dot(offset.normalized()) < arc:
			continue
		if beam and absf(offset.cross(aim)) > 12:
			continue
		if line_clear(origin, point.move_toward(origin, 1)):
			hit_cover(rect)

func _process(delta: float) -> void:
	clock += delta
	message_time = maxf(0, message_time - delta)
	view.queue_redraw()
	if view.overlay != null:
		view.overlay.refresh_ui(delta)

func _physics_process(delta: float) -> void:
	if state == "ruoyu_unseal":
		ruoyu_unseal_time += delta
		if ruoyu_unseal_time >= Data.RUOYU_UNSEAL_DURATION:
			state = "playing"
			invulnerable = maxf(invulnerable, 0.35)
			notify("若宇 · 封印解除")
		return
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
	health = minf(max_health(), health + player_stat("regen") * delta)
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
	if spawn_remaining > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_batch(3 if current_room().get("encounter", "double") == "stream" else spawn_remaining)
	update_enemies(delta)
	if state != "playing":
		return
	update_weapons(delta)
	update_turrets(delta)
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
	if not current_room().cleared and enemies.is_empty() and spawn_remaining == 0:
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
	dash_cooldown = 1.8 / player_stat("dash_recovery")
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
			hit_enemy(enemy, (24 + level * 10) * damage_scale("magic"), player)
	hit_cover_area(player, facing, 165 + level * 20)
	add_effect("burst", player, player, Color.WHITE, 0.5, 280 + level * 35)
	notify("洋葱守护 · %.1f 秒护盾" % shield_time)
	audio.sfx("skill")

func turret_cooldown(id: String) -> float:
	return maxf(0.0, float(turret_ready_at.get(id, 0.0)) - run_time)

func deploy_turret() -> bool:
	if state != "playing" or rooms.is_empty() or current_room().cleared:
		return false
	if not current_room().rect.grow(-18).has_point(player) or not walkable(player, 17):
		return false
	for id in Data.TURRETS:
		if turret_cooldown(id) > 0.0:
			continue
		var tier: int = 0
		for entry in equipment:
			if entry.id == id:
				tier = maxi(tier, entry.tier)
		if tier == 0:
			continue
		var spec: Dictionary = Data.TURRETS[id]
		var quality: float = 0.6 + 0.4 * Data.equipment_multiplier(tier)
		turrets.append({"kind":"turret", "id":id, "p":player, "life":spec.lifetime, "wait":0.0, "quality":quality})
		turret_ready_at[id] = run_time + spec.cooldown
		notify("已部署 · " + Data.item(id).name)
		audio.sfx("skill")
		return true
	return false

func update_turrets(delta: float) -> void:
	for i in range(turrets.size() - 1, -1, -1):
		var turret: Dictionary = turrets[i]
		turret.life -= delta
		if turret.life <= 0.0:
			turrets.remove_at(i)
			continue
		turret.wait -= delta
		if turret.wait > 0.0:
			continue
		var spec: Dictionary = Data.TURRETS[turret.id]
		var origin: Vector2 = turret.p
		var target: Dictionary = target_near(origin, spec.reach)
		if target.is_empty():
			continue
		turret.wait = spec.interval
		var damage: float = spec.damage * turret.quality * damage_scale("magic")
		var color: Color = Data.item(turret.id).color
		if spec.pulse:
			add_effect("burst", origin, origin, color, 0.32, spec.reach * 2)
			for enemy in enemies.duplicate():
				if enemy.age > 0.65 and origin.distance_to(enemy.p) < spec.reach and line_clear(origin, enemy.p):
					hit_enemy(enemy, damage, origin)
		else:
			add_effect("beam", origin, target.p, color, 0.20, 0)
			hit_enemy(target, damage, origin)
		audio.sfx("hit")

func spawn_wave() -> void:
	if current_room().type not in ["combat", "elite"]:
		return
	wave += 1
	wave_wait = 0
	if current_room().type == "elite" and wave == wave_total:
		var kind: String = current_room().get("elite_kind", Data.FLOOR_ELITES[floor_index])
		spawn_enemy(spawn_point(50), kind)
		build_navigation(35)
		notify("精英首领 · " + Data.ELITE_NAMES[kind])
		return
	spawn_remaining = encounter_population()
	spawn_batch(4 if current_room().get("encounter", "double") == "stream" else spawn_remaining)
	notify("%s · %s" % [Data.ROOM_NAMES[current_room().type], "持续增援" if current_room().get("encounter", "double") == "stream" else "第 %d / %d 波" % [wave, wave_total]])

func encounter_population() -> int:
	var mode: String = current_room().get("encounter", "double")
	var base: int = 20 if mode == "stream" else (14 if mode == "single" else 6 + wave * 3)
	var clear_bonus: int = mini(floori(cleared_count / 3.0), 16)
	return base + floor_index * 2 + clear_bonus + (4 if current_room().type == "elite" else 0)

func spawn_batch(count: int) -> void:
	var capacity: int = 16 + floor_index * 2
	var kinds: Array = Data.FLOOR_ENEMIES[floor_index]
	for i in range(mini(count, spawn_remaining)):
		if enemies.size() >= capacity:
			break
		var p: Vector2 = spawn_point()
		if not walkable(p, 23) or p.distance_to(player) <= 230:
			break
		var crowded: bool = false
		for enemy in enemies:
			crowded = crowded or p.distance_to(enemy.p) < enemy.radius + 25
		if crowded:
			break
		var kind: String = kinds[(spawn_serial + wave + floor_index) % kinds.size()]
		spawn_enemy(p, kind)
		spawn_serial += 1
		spawn_remaining -= 1
	spawn_timer = 0.9 / (1.0 + cleared_count * 0.025)

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
	var elite: bool = Data.ELITE_NAMES.has(kind)
	var boss_kind: bool = kind == "boss" or elite
	var hp: float = (Data.BOSS_HEALTH[floor_index] if boss_kind else 22.0 + floor_index * 13) * Data.DIFFICULTIES[run_difficulty].enemy
	if elite:
		hp = Data.SHARK_HEALTH[floor_index] * Data.DIFFICULTIES[run_difficulty].enemy
		if kind == "brood":
			hp *= 1.15
	hp *= 1.0 + cleared_count * 0.1
	if kind == "charger":
		hp *= 1.5
	elif kind == "splitter":
		hp *= 1.7
	elif kind == "minislime":
		hp *= 0.28
	elif kind == "dasher":
		hp *= 0.9
	if current_room().type == "elite" and not boss_kind:
		hp *= 1.35
	if Data.YANG_ESCORT_NAMES.has(kind):
		hp *= 2.5
	var spec: Dictionary = Data.ENEMY_CAST.get(kind, {})
	var enemy: Dictionary = {"p":p, "kind":kind, "hp":hp, "max_hp":hp, "radius":33.0 if elite else (29.0 if boss_kind else 16.0), "speed":(66.0 + floor_index * 12) * (1.0 + cleared_count * 0.02), "haste":1.0 + cleared_count * 0.025 + floor_index * 0.08, "age":0.0, "cooldown":2.0 + rng.randf(), "windup":0.0, "aim":Vector2.RIGHT, "charge":0.0, "flash":0.0, "path":PackedVector2Array(), "path_time":0.0, "dead":false, "phase":0}
	enemy["art"] = Data.BOSS_ART[floor_index] if kind == "boss" else spec.get("art", -1)
	enemy["moves"] = Data.BOSS_MOVES[floor_index] if kind == "boss" else spec.get("moves", [])
	enemy["ranged"] = spec.get("ranged", false)
	enemy["attack"] = 0
	enemy["attack_pose_time"] = 0.0
	enemy["moving"] = false
	enemy["guard_time"] = 0.0
	enemies.append(enemy)
	enemy.previous_p = p
	enemy["facing"] = 1.0 if player.x >= p.x else -1.0
	if kind == "splitter":
		enemy.radius = 21.0
		enemy.speed *= 0.75
	elif kind == "minislime":
		enemy.radius = 10.0
		enemy.speed *= 1.5
	elif kind == "dasher":
		enemy.speed *= 1.4
	elif kind == "wolf":
		enemy.speed *= 1.25
	elif kind == "ropehead":
		enemy.speed *= 0.7
	if boss_kind:
		enemy.cooldown = 1.2
		enemy["charge_left"] = 0
		if is_ruoyu(enemy):
			enemy["pounce_time"] = 0.0
			enemy["pounce_recovery"] = 0.0
		elif is_yang(enemy):
			enemy["castle_shield"] = true
			enemy["escorts_summoned"] = false
			enemy["castle_weak_time"] = 0.0
			enemy.windup = 0.85
		if kind == "boss" and Data.FLOOR_STYLES[floor_index] in ["sumo", "wilds"]:
			enemy.radius = 38.0
			if Data.FLOOR_STYLES[floor_index] == "wilds":
				boss_say(enemy, Data.NIULAI_QUOTE, INF)
	return enemy

func is_boss(enemy: Dictionary) -> bool:
	return enemy.kind == "boss" or Data.ELITE_NAMES.has(enemy.kind)

func is_ruoyu(enemy: Dictionary) -> bool:
	return enemy.kind == "boss" and Data.FLOOR_STYLES[floor_index] == "dark_home"

func is_yang(enemy: Dictionary) -> bool:
	return enemy.kind == "boss" and Data.FLOOR_STYLES[floor_index] == "castle"

func is_yamada(enemy: Dictionary) -> bool:
	return enemy.kind == "boss" and Data.FLOOR_STYLES[floor_index] == "sumo"

func boss_name(enemy: Dictionary) -> String:
	return Data.ELITE_NAMES.get(enemy.kind, Data.BOSS_NAMES[floor_index])

func target_near(p: Vector2, reach: float, include_cover: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var closest: float = reach
	for enemy in enemies:
		var distance: float = enemy.p.distance_to(p)
		if not enemy.dead and not enemy.get("castle_shield", false) and enemy.age > 0.65 and distance < closest and line_clear(p, enemy.p):
			closest = distance
			result = enemy
	if result.is_empty() and include_cover:
		for rect in obstacles:
			var point: Vector2 = p.clamp(rect.position, rect.end)
			var distance: float = p.distance_to(point)
			if distance < closest and line_clear(p, point.move_toward(p, 1)):
				closest = distance
				result = {"p":point, "cover":rect}
	return result

func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if enemy.dead:
			continue
		enemy.age += delta
		if enemy.has("speech_time"):
			enemy.speech_time = maxf(0.0, enemy.speech_time - delta)
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.attack_pose_time = maxf(0.0, enemy.attack_pose_time - delta)
		enemy.guard_time = maxf(0.0, enemy.guard_time - delta)
		enemy["slow_time"] = maxf(0, enemy.get("slow_time", 0.0) - delta)
		if enemy.age < 0.8:
			continue
		var offset: Vector2 = player - enemy.p
		var previous_position: Vector2 = enemy.p
		var distance: float = offset.length()
		enemy.cooldown -= delta * enemy.haste
		var speed: float = enemy.speed
		if is_boss(enemy):
			var yang: bool = is_yang(enemy)
			if yang and enemy.phase == 0 and update_yang_phase_one(enemy, delta):
				continue
			var ruoyu: bool = is_ruoyu(enemy)
			if ruoyu and enemy.phase == 0 and enemy.hp <= enemy.max_hp * 0.5:
				enemy.phase = 1
				enemy.erase("speech_time")
				enemy.windup = 0.0
				enemy.charge = 0.0
				enemy.guard_time = 0.0
				enemy.attack_pose_time = 0.0
				enemy.cooldown = 0.7
				enemy.pounce_time = 0.0
				enemy.pounce_recovery = 0.0
				enemy.moves = enemy.moves + ["pounce"]
				enemy.attack = enemy.moves.size() - 1
				projectiles.clear()
				ruoyu_unseal_time = 0.0
				state = "ruoyu_unseal"
				audio.sfx("skill")
				return
			if ruoyu and update_ruoyu_pounce(enemy, delta):
				continue
			if is_yamada(enemy) and enemy.phase == 0 and enemy.hp <= enemy.max_hp * 0.5:
				if not enemy.has("split_time"):
					enemy["split_time"] = Data.YAMADA_SPLIT_DURATION
					enemy.windup = 0.0
					enemy.charge = 0.0
					enemy.moving = false
					notify("山田开始蓄力分身！")
					audio.sfx("skill")
				enemy.split_time -= delta
				if enemy.split_time <= 0.0:
					split_yamada(enemy)
				continue
			if enemy.hp < enemy.max_hp * 0.5 and enemy.phase == 0:
				enemy.phase = 1
				notify(boss_name(enemy) + "进入狂暴阶段！")
				enemy.cooldown = 0.1
			speed = (82 + enemy.phase * 14 if enemy.kind == "shark" else (30 if enemy.kind == "brood" else 68 + floor_index * 8)) * (1.0 + cleared_count * 0.02)
			if ruoyu and enemy.phase > 0:
				speed *= 1.18
			if yang:
				speed *= 1.16
			if enemy.cooldown <= 0 and enemy.windup <= 0 and enemy.charge <= 0 and enemy.guard_time <= 0:
				enemy.windup = 0.75 if enemy.phase == 0 else 0.6
				enemy.aim = offset.normalized()
				enemy["target"] = player
				if ruoyu and next_enemy_move(enemy) == "pounce":
					enemy.windup = 0.92
					enemy.target = enemy.p + offset.limit_length(490.0)
				elif yang and next_enemy_move(enemy) == "laser":
					enemy.windup = 0.95
					if enemy.aim.is_zero_approx():
						enemy.aim = Vector2(enemy.facing, 0)
					enemy.target = laser_endpoint(enemy.p, enemy.aim)
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					boss_attack(enemy)
					enemy.cooldown = 1.55 if enemy.phase == 0 else 1.0
					if ruoyu and enemy.pounce_time > 0.0:
						continue
					if enemy.charge_left > 0:
						enemy.cooldown = 0.55
			elif yang and enemy.phase > 0 and enemy.attack_pose_time > 0.0 and enemy.moves[posmod(enemy.attack - 1, enemy.moves.size())] == "laser":
				speed = 0
		elif not enemy.moves.is_empty():
			var move: String = next_enemy_move(enemy)
			if enemy.ranged:
				speed = 0 if distance > 185 and distance < 320 else (speed if distance >= 320 else -speed * 0.7)
			var reach: float = 118.0 if move == "slam" else (240.0 if move == "lunge" else 390.0)
			if enemy.cooldown <= 0 and enemy.windup <= 0 and enemy.charge <= 0 and enemy.guard_time <= 0 and distance <= reach and line_clear(enemy.p, player):
				enemy.windup = 0.38 if move == "lunge" else 0.65
				enemy.aim = offset.normalized()
				enemy["target"] = player
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					enemy.attack += 1
					perform_enemy_move(enemy, move)
					enemy.cooldown = 2.3 if enemy.ranged else 1.9
		elif enemy.kind in ["ranged", "ropehead"]:
			speed = 0 if distance > 185 and distance < 320 else (speed if distance >= 320 else -speed * 0.7)
			if enemy.cooldown <= 0 and enemy.windup <= 0 and line_clear(enemy.p, player):
				enemy.windup = 0.65
				enemy.aim = offset.normalized()
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					for i in range(3):
						shoot(enemy.p, enemy.aim.rotated((i - 1) * 0.17) * 225, 9 + floor_index * 2, false, Color("a7d574") if enemy.kind == "ropehead" else Color("ff8e9f"), 0)
					enemy.cooldown = 2.3
		elif enemy.kind in ["charger", "dasher", "wolf"]:
			var agile: bool = enemy.kind in ["dasher", "wolf"]
			if enemy.cooldown <= 0 and enemy.windup <= 0 and enemy.charge <= 0:
				enemy.windup = 0.38 if agile else 0.65
				enemy.aim = offset.normalized()
			if enemy.windup > 0:
				enemy.windup -= delta
				speed = 0
				if enemy.windup <= 0:
					enemy.charge = 0.22 if agile else 0.48
					enemy.cooldown = 1.7 if agile else 3.4
		var slow: float = float(enemy.get("slow", 1.0)) if enemy.slow_time > 0 else 1.0
		speed *= slow
		if enemy.charge > 0:
			enemy.charge -= delta
			var charge_speed: float = 470 if enemy.kind in ["dasher", "wolf", "cone_mimic"] else 340
			if enemy.kind == "baola" or enemy.kind == "boss" and Data.FLOOR_STYLES[floor_index] in ["sumo", "wilds"]:
				charge_speed = 460
			enemy.p = slide(enemy.p, enemy.aim * charge_speed * (1.0 + cleared_count * 0.02) * slow * delta, enemy.radius)
		elif speed != 0 and enemy.guard_time <= 0.0:
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
		var facing_motion: Vector2 = enemy.p - previous_position
		enemy.moving = facing_motion.length_squared() > 0.001
		if facing_motion.length_squared() < 0.001 and enemy.windup > 0:
			facing_motion = enemy.aim
		if absf(facing_motion.x) > 0.01:
			enemy.facing = 1.0 if facing_motion.x > 0 else -1.0
		if enemy.p.distance_to(player) < enemy.radius + 12:
			hurt((12 if is_boss(enemy) else (3 if enemy.kind == "minislime" else 8)) * (1.0 + cleared_count * 0.04), enemy.p)

func next_enemy_move(enemy: Dictionary) -> String:
	if is_yang(enemy) and enemy.phase == 0:
		return "decree"
	return "" if enemy.moves.is_empty() else enemy.moves[enemy.attack % enemy.moves.size()]

func split_yamada(enemy: Dictionary) -> void:
	var clone_hp: float = enemy.hp / Data.YAMADA_CLONE_COUNT * 1.4
	var bounds: Rect2 = current_room().rect.grow(-enemy.radius)
	var tint: Color = Data.FLOOR_COLORS[floor_index]
	enemy.dead = true
	enemies.erase(enemy)
	add_effect("burst", enemy.p, enemy.p, tint, 0.5, 260)
	for i in range(Data.YAMADA_CLONE_COUNT):
		var point: Vector2 = enemy.p + Vector2.from_angle(TAU * (i + 0.5) / Data.YAMADA_CLONE_COUNT) * 156.0
		var near_player: bool = point.distance_to(player) < enemy.radius + 30.0
		var crowded: bool = enemies.any(func(other: Dictionary) -> bool:
			return point.distance_to(other.p) < enemy.radius + other.radius + 10.0
		)
		if near_player or crowded or not bounds.has_point(point) or not walkable(point, enemy.radius):
			point = spawn_point(enemy.radius)
		var clone: Dictionary = spawn_enemy(point, "boss")
		clone["yamada_clone"] = true
		clone.hp = clone_hp
		clone.max_hp = clone_hp
		clone.phase = 1
		clone.attack = i % 3
		clone.cooldown = 0.65 + i * 0.75
		add_effect("burst", point, point, tint, 0.48, 124)
	notify("山田一分为四 · 击败全部分身")

func update_yang_phase_one(enemy: Dictionary, delta: float) -> bool:
	if not enemy.escorts_summoned:
		enemy.windup = maxf(0.0, enemy.windup - delta)
		if enemy.windup == 0.0:
			enemy.escorts_summoned = true
			enemy.attack_pose_time = 0.45
			for kind in ["lin_yu", "lin_yifeng", "chess_rook", "ink_scribe", "chess_rook"]:
				spawn_enemy(spawn_point(), kind)
			add_effect("burst", enemy.p, enemy.p, Color("ffb878"), 0.46, 150)
			notify("护盾由林宇、林逸枫和小怪维持")
		return true
	if enemy.castle_shield:
		if enemies.size() == 1:
			enemy.castle_shield = false
			enemy.castle_weak_time = Data.YANG_WEAK_DURATION
			enemy.attack_pose_time = 0.0
			add_effect("burst", enemy.p, enemy.p, Color("84cdf9"), 0.60, 170)
			audio.sfx("skill")
			notify("护盾已破 · 杨梓亮陷入虚弱")
		return true
	if enemy.hp <= enemy.max_hp * 0.5:
		enemy.phase = 1
		enemy.castle_weak_time = 0.0
		enemy.windup = 0.0
		enemy.attack_pose_time = 0.0
		enemy.attack = 0
		enemy.cooldown = 0.65
		notify("杨梓亮 · 巅峰状态")
		return false
	if enemy.castle_weak_time > 0.0:
		enemy.castle_weak_time = maxf(0.0, enemy.castle_weak_time - delta)
		if enemy.castle_weak_time == 0.0:
			enemy.cooldown = 0.35
	return enemy.castle_weak_time > 0.0

func update_ruoyu_pounce(enemy: Dictionary, delta: float) -> bool:
	if enemy.pounce_time > 0.0:
		var travel: Vector2 = (enemy.target - enemy.p) * minf(1.0, delta / enemy.pounce_time)
		enemy.p = slide(enemy.p, travel, enemy.radius)
		enemy.pounce_time = maxf(0.0, enemy.pounce_time - delta)
		if enemy.pounce_time <= 0.0:
			var radius: float = attack_radius(enemy, "pounce")
			add_effect("dust", enemy.p, enemy.p, Color.WHITE, 0.50, radius * 2.0)
			if player.distance_to(enemy.p) <= radius and line_clear(enemy.p, player):
				hurt((22.0 + enemy.phase * 3.0) * (1.0 + minf(0.35, cleared_count * 0.025)), enemy.p)
			enemy.pounce_recovery = Data.RUOYU_POUNCE_RECOVERY
			boss_say(enemy, "哎呦")
		return true
	if enemy.pounce_recovery > 0.0:
		enemy.pounce_recovery = maxf(0.0, enemy.pounce_recovery - delta)
		if enemy.pounce_recovery <= 0.0:
			enemy.cooldown = 0.35
		return true
	return false

func attack_center(enemy: Dictionary, move: String) -> Vector2:
	return enemy.get("target", player) if move in ["mark", "pull", "pounce"] else enemy.p

func attack_radius(enemy: Dictionary, move: String) -> float:
	match move:
		"slam": return 150.0 if is_boss(enemy) else 122.0
		"mark": return 94.0 if is_boss(enemy) else 57.0
		"pull": return 112.0
		"pounce": return 104.0 + enemy.phase * 12.0
	return 0.0

func laser_endpoint(origin: Vector2, aim: Vector2) -> Vector2:
	var bounds: Rect2 = current_room().rect.grow(-8.0)
	var end: Vector2 = origin
	for distance in range(12, 1441, 12):
		var point: Vector2 = origin + aim * distance
		if not bounds.has_point(point) or not line_clear(origin, point):
			break
		end = point
	return end

func perform_enemy_move(enemy: Dictionary, move: String) -> void:
	enemy.attack_pose_time = 0.30
	var leader: bool = is_boss(enemy)
	var tint: Color = Data.FLOOR_COLORS[floor_index]
	var power: float = 13.0 + enemy.phase * 2 if leader else 7.0 + floor_index * 0.6
	match move:
		"lunge":
			enemy.charge = 0.52 + enemy.phase * 0.08 if leader else (0.22 if enemy.kind == "wolf" else 0.33)
			add_effect("dust", enemy.p, enemy.p, tint, 0.4, 92)
		"pounce":
			enemy["target"] = enemy.get("target", player)
			enemy.attack_pose_time = 0.0
			enemy.moving = false
			enemy.pounce_time = Data.RUOYU_POUNCE_FLIGHT
		"fan", "guard", "burst":
			if move == "guard":
				enemy.guard_time = 1.3 if leader else 0.9
			var count: int = (9 + enemy.phase * 4 if leader else 3) if move != "burst" else (5 + enemy.phase * 2 if leader else 2)
			if is_ruoyu(enemy) and move == "fan":
				count += 4
			var spread: float = 0.048 if move == "burst" else 0.17
			for i in range(count):
				var angle: float = (i - (count - 1) * 0.5) * spread
				shoot(enemy.p, enemy.aim.rotated(angle) * (245 + i * 12 if move == "burst" else 225), power, false, tint, 0, 2.7)
		"ring":
			var count: int = 22 + enemy.phase * 8 if leader else 6
			for i in range(count):
				shoot(enemy.p, Vector2.from_angle(TAU * i / count + enemy.attack * 0.18) * 195, power, false, tint, 0, 3.0)
		"cross":
			var count: int = 5 + enemy.phase * 2 if leader else 1
			for arm in range(4):
				for i in range(count):
					var angle: float = arm * PI / 2 + (i - (count - 1) * 0.5) * 0.09
					shoot(enemy.p, Vector2.from_angle(angle) * 245, power, false, tint, 0, 2.8)
		"decree":
			for lane in range(-4 - enemy.phase, 5 + enemy.phase):
				var origin: Vector2 = enemy.p + enemy.aim.orthogonal() * lane * 41
				if walkable(origin, 3):
					shoot(origin, enemy.aim * 265, power, false, tint, 0, 2.8)
					shoot(origin, -enemy.aim * 215, power, false, tint, 0, 2.8)
		"laser":
			var end: Vector2 = enemy.target if enemy.has("target") else laser_endpoint(enemy.p, enemy.aim)
			add_effect("yang_laser", enemy.p, end, Color("ff354f"), 0.30, 58)
			effects.back()["facing"] = enemy.facing
			if player.distance_to(Geometry2D.get_closest_point_to_segment(player, enemy.p, end)) <= 29.0 and line_clear(enemy.p, player):
				hurt(20.0 * (1.0 + minf(cleared_count * 0.025, 0.5)), enemy.p)
		"slam", "mark", "pull":
			var point: Vector2 = attack_center(enemy, move)
			var radius: float = attack_radius(enemy, move)
			add_effect("burst", point, point, tint, 0.42, radius * 2)
			if player.distance_to(point) <= radius and line_clear(point, player):
				hurt(power * (1.0 + cleared_count * 0.04), point)
				if move == "pull" and dash_time <= 0:
					player = slide(player, player.direction_to(enemy.p) * minf(95, player.distance_to(enemy.p)), 12)
		"summon":
			var local_kinds: Array = Data.FLOOR_ENEMIES[floor_index]
			for i in range(mini(2 + enemy.phase, 7 - enemies.size())):
				spawn_enemy(spawn_point(), local_kinds[i % local_kinds.size()])
			add_effect("burst", enemy.p, enemy.p, tint, 0.46, 150)

func boss_attack(enemy: Dictionary) -> void:
	if is_yang(enemy):
		if enemy.castle_shield or enemy.castle_weak_time > 0.0:
			return
		if enemy.phase > 0:
			boss_say(enemy, Data.YANG_PEAK_QUOTES[enemy.attack % Data.YANG_PEAK_QUOTES.size()])
	var move: String = next_enemy_move(enemy)
	if is_ruoyu(enemy) and move != "pounce":
		boss_say(enemy, Data.RUOYU_QUOTES[enemy.attack % enemy.moves.size()])
	enemy.attack += 1
	if not move.is_empty():
		perform_enemy_move(enemy, move)
		return
	if enemy.kind == "baola":
		if enemy.charge_left <= 0:
			enemy.charge_left = 2 + enemy.phase
		enemy.charge_left -= 1
		enemy.charge = 0.36
		for i in range(7 + enemy.phase * 2):
			shoot(enemy.p, enemy.aim.rotated((i - (6 + enemy.phase * 2) * 0.5) * 0.22) * 240, 14, false, Color("efbd76"), 0, 2.4)
		if enemy.attack % 3 == 0 and enemies.size() < 7:
			for i in range(2):
				spawn_enemy(spawn_point(), "wolf")
		add_effect("dust", enemy.p, enemy.p, Color.WHITE, 0.4, 130)
		return
	if enemy.kind == "brood":
		for i in range(8 + enemy.phase * 4):
			shoot(enemy.p, Vector2.from_angle(TAU * i / (8 + enemy.phase * 4) + enemy.attack * 0.2) * 180, 11, false, Color("bb9ef1"), 0, 3.0)
		if enemies.size() < 9:
			for i in range(2 + enemy.phase):
				spawn_enemy(spawn_point(), "splitter" if enemy.phase > 0 and i == 0 else "minislime")
		add_effect("burst", enemy.p, enemy.p, Color("bb9ef1"), 0.4, 150)
		return
	if enemy.kind == "warden":
		for i in range(12 + enemy.phase * 4):
			shoot(enemy.p, Vector2.from_angle(TAU * i / (12 + enemy.phase * 4) + enemy.attack * 0.35) * 210, 12, false, Color("8fcfff"), 0, 3.0)
		for i in range(3):
			shoot(enemy.p, enemy.aim.rotated((i - 1) * 0.2) * 310, 13, false, Color("8fcfff"), 0, 2.6)
		return
	if enemy.kind == "shark":
		enemy.charge = 0.52 + enemy.phase * 0.12
		var count: int = 5 + floor_index * 2 + enemy.phase * 2
		for i in range(count):
			shoot(enemy.p, enemy.aim.rotated((i - (count - 1) * 0.5) * 0.18) * 225, 11 + floor_index * 2, false, Color("8fcfff"))
		if floor_index == 1:
			for side in [-1, 1]:
				shoot(enemy.p, enemy.aim.rotated(side * PI / 2) * 200, 12, false, Color("bd9eff"))
		elif floor_index == 2:
			for i in range(8):
				shoot(enemy.p, Vector2.from_angle(TAU * i / 8 + enemy.attack * 0.3) * 175, 13, false, Color("ffb178"))
		add_effect("burst", enemy.p, enemy.p, Color.WHITE, 0.4, 130)
		return
	match Data.FLOOR_STYLES[floor_index]:
		"wilds":
			if enemy.attack % 4 in [1, 2]:
				enemy.charge_left = 1 if enemy.attack % 4 == 1 else 0
				enemy.charge = 0.6 + enemy.phase * 0.1
				for side in [-1, 1]:
					for i in range(9 + enemy.phase * 2):
						shoot(enemy.p, enemy.aim.rotated(side * (0.65 + i * 0.1)) * 205, 14, false, Color("c7de8f"), 0, 2.5)
			elif enemy.attack % 4 == 3:
				var count: int = 28 + enemy.phase * 10
				for i in range(count):
					shoot(enemy.p, Vector2.from_angle(TAU * i / count + enemy.attack * 0.1) * 190, 15, false, Color("c7de8f"), 0, 3.0)
				add_effect("dust", enemy.p, enemy.p, Color.WHITE, 0.6, 250)
			else:
				for row in range(4):
					for i in range(9 + enemy.phase * 2):
						shoot(enemy.p, enemy.aim.rotated((i - (8 + enemy.phase * 2) * 0.5) * 0.15) * (180 + row * 40), 14, false, Color("c7de8f"), 0, 2.8)
			if (enemy.attack % 4 == 0 or enemy.phase > 0 and enemy.attack % 3 == 0) and enemies.size() < 7:
				for kind in ["wolf", "ropehead"]:
					spawn_enemy(spawn_point(), kind)
		"sumo":
			enemy.attack_pose_time = 0.30
			match enemy.attack % 3:
				1:
					enemy.charge = 0.62 + enemy.phase * 0.12
					for side in [-1, 1]:
						for i in range(9 + enemy.phase * 2):
							shoot(enemy.p, enemy.aim.rotated(side * (0.6 + i * 0.09)) * 195, 14, false, Color("efbd76"), 0, 2.2)
				2:
					for row in range(4 + enemy.phase):
						for i in range(7):
							shoot(enemy.p, enemy.aim.rotated((i - 3) * 0.12) * (215 + row * 38), 15, false, Color("efbd76"), 0, 2.3)
				0:
					for i in range(24 + enemy.phase * 12):
						shoot(enemy.p, Vector2.from_angle(TAU * i / (24 + enemy.phase * 12)) * 185, 16, false, Color("efbd76"), 0, 2.8)
					perform_enemy_move(enemy, "slam")
					add_effect("dust", enemy.p, enemy.p, Color.WHITE, 0.65, 260)
			if enemy.phase > 0 and enemy.attack % 6 == 0 and enemies.size() < 7:
				for kind in ["straw_brawler", "drum_yokai"]:
					spawn_enemy(spawn_point(), kind)
	add_effect("dust", enemy.p, enemy.p, Color.WHITE, 0.45, 150)

func update_weapons(delta: float) -> void:
	for weapon in weapons:
		weapon.cooldown = maxf(0, weapon.cooldown - delta)
		weapon.recoil = maxf(0, float(weapon.get("recoil", 0.0)) - delta)
		if weapon.cooldown > 0:
			continue
		var spec: Dictionary = Data.item(weapon.id)
		var reach: float = spec.reach * player_stat("reach")
		var target: Dictionary = target_near(player, reach, true)
		if target.is_empty():
			continue
		var aim: Vector2 = (target.p - player).normalized()
		weapon.aim = aim
		weapon.recoil = 0.16
		weapon.cooldown = spec.cooldown / attack_speed()
		var damage: float = spec.damage * Data.multiplier(weapon.tier) * damage_scale(spec.attack_type)
		var attack: String = spec.get("attack", weapon.id)
		match attack:
			"blade", "spear", "orb":
				add_effect("slash" if attack == "blade" else ("thrust" if attack == "spear" else "burst"), player, player + aim * reach, spec.color, 0.24, reach)
				for enemy in enemies.duplicate():
					var offset: Vector2 = enemy.p - player
					var hit: bool = enemy.age > 0.65 and offset.length() <= reach
					if attack == "blade":
						hit = hit and aim.dot(offset.normalized()) > spec.get("arc", 0.2)
					elif attack == "spear":
						hit = hit and aim.dot(offset.normalized()) > spec.get("arc", 0.89)
					if hit and line_clear(player, enemy.p):
						hit_enemy(enemy, damage, player, spec)
				hit_cover_area(player, aim, reach, spec.get("arc", 0.2 if attack == "blade" else 0.89) if attack != "orb" else -1.0)
			"beam":
				add_effect("beam", player, player + aim * reach, spec.color, 0.25, reach)
				for enemy in enemies.duplicate():
					var offset: Vector2 = enemy.p - player
					if enemy.age > 0.65 and offset.dot(aim) >= 0 and offset.length() <= reach and absf(offset.cross(aim)) < enemy.radius + 12 and line_clear(player, enemy.p):
						hit_enemy(enemy, damage, player, spec)
				hit_cover_area(player, aim, reach, 0, true)
			"wand":
				var origin: Vector2 = player
				var chain: Dictionary = target
				var struck: Array[Dictionary] = []
				for i in range(weapon.tier + 1):
					if chain.is_empty():
						break
					if chain.has("cover"):
						add_effect("beam", origin, chain.p, spec.color, 0.22, 0)
						hit_cover(chain.cover)
						break
					struck.append(chain)
					add_effect("beam", origin, chain.p, spec.color, 0.22, 0)
					origin = chain.p
					hit_enemy(chain, damage * pow(0.8, i), player)
					chain = {}
					for candidate in enemies:
						if candidate not in struck and not candidate.dead and not candidate.get("castle_shield", false) and candidate.p.distance_to(origin) < 165 and line_clear(origin, candidate.p):
							chain = candidate
			"shotgun":
				for i in range(5):
					shoot(player + aim * 24, aim.rotated((i - 2) * 0.14) * 500, damage, true, spec.color, 0, reach / 500, spec)
			_:
				var pellets: int = spec.get("pellets", 1)
				var speed: float = spec.get("speed", 650.0)
				var pierce: int = spec.get("pierce", 1 if weapon.tier >= 3 else 0)
				for i in range(pellets):
					shoot(player + aim * 24, aim.rotated((i - (pellets - 1) * 0.5) * spec.get("spread", 0.0)) * speed, damage, true, spec.color, pierce, reach / speed, spec)
		audio.sfx("slash" if spec.attack_type == "melee" else "hit")

func regroup_knight() -> void:
	for offset in [Vector2(-24, 24), Vector2(24, 24), Vector2(-24, -24), Vector2(24, -24), Vector2.ZERO]:
		var candidate: Vector2 = player + offset
		if walkable(candidate) and line_clear(player, candidate):
			knight = candidate
			break
	previous_knight = knight
	knight_path.clear()
	knight_path_time = 0
	knight_moving = false

func update_knight(delta: float) -> void:
	if not knight_active:
		return
	knight_cooldown = maxf(0, knight_cooldown - delta)
	knight_attack_time = maxf(0, knight_attack_time - delta)
	knight_animation_time += delta
	if knight.distance_to(player) > 250 or not walkable(knight):
		regroup_knight()
	var target: Dictionary = target_near(knight, 360)
	var destination: Vector2 = player + Vector2(-42, 24) if target.is_empty() else target.p
	if target.is_empty() and (not walkable(destination) or not line_clear(player, destination)):
		destination = player
	var before: Vector2 = knight
	var blocked: bool = not line_clear(knight, destination)
	if knight_attack_time <= 0 and (knight.distance_to(destination) > 52 or blocked):
		var waypoint: Vector2 = destination
		if blocked:
			knight_path_time -= delta
			if knight_path_time <= 0:
				knight_path.clear()
				var source: Vector2i = nav_cell(knight)
				var goal: Vector2i = nav_cell(destination)
				if nav.is_in_boundsv(source) and nav.is_in_boundsv(goal) and not nav.is_point_solid(source) and not nav.is_point_solid(goal):
					knight_path = nav.get_point_path(source, goal)
				knight_path_time = 0.25
			while not knight_path.is_empty() and knight.distance_to(knight_path[0]) < 12:
				knight_path.remove_at(0)
			if not knight_path.is_empty():
				waypoint = knight_path[0]
		else:
			knight_path.clear()
			knight_path_time = 0
		knight = slide(knight, knight.direction_to(waypoint) * minf(230 * delta, knight.distance_to(waypoint)))
	var moving: bool = knight.distance_squared_to(before) > 0.001
	if moving != knight_moving:
		knight_animation_time = 0
	knight_moving = moving
	if moving:
		knight_facing = before.direction_to(knight)
	if not target.is_empty() and knight.distance_to(target.p) < 100 and knight_cooldown <= 0 and line_clear(knight, target.p):
		knight_cooldown = 0.7
		knight_attack_time = 0.28
		knight_facing = knight.direction_to(target.p)
		add_effect("slash", knight, target.p, Color("d9e6dc"), 0.22, 86)
		hit_enemy(target, 22 + floor_index * 10, knight)

func knight_frame() -> int:
	var row: int = (0 if knight_facing.x >= 0 else 2) if absf(knight_facing.x) >= absf(knight_facing.y) else (1 if knight_facing.y < 0 else 3)
	var pose: int = int(knight_animation_time * 2) % 2
	if knight_attack_time > 0:
		pose = 6 + clampi(int((0.28 - knight_attack_time) / 0.14), 0, 1)
	elif knight_moving:
		pose = 2 + int(knight_animation_time * 9) % 4
	return row * 8 + pose

func shoot(p: Vector2, velocity: Vector2, damage: float, friendly: bool, color: Color, pierce: int = 0, life: float = 1.8, traits: Dictionary = {}) -> void:
	if friendly:
		add_effect("muzzle", p, p + velocity.normalized(), Color.WHITE, 0.1, 42)
	else:
		damage *= 1.0 + cleared_count * 0.04
	projectiles.append({"p":p, "previous_p":p, "velocity":velocity, "damage":damage, "friendly":friendly, "color":color, "pierce":pierce, "life":life, "hit":[], "traits":traits})

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
			for rect in obstacles:
				if rect.grow(3).has_point(shot.p):
					hit_cover(rect)
					shot.life = 0
					break
			if shot.life <= 0:
				break
			if not walkable(shot.p, 3):
				shot.life = 0
				break
			if shot.friendly:
				for enemy in enemies.duplicate():
					if not enemy.dead and enemy.age > 0.65 and enemy not in shot.hit and enemy.p.distance_to(shot.p) < enemy.radius + 5:
						shot.hit.append(enemy)
						hit_enemy(enemy, shot.damage, shot.p - shot.velocity.normalized() * 20, shot.traits)
						var splash: float = shot.traits.get("splash", 0.0)
						if splash > 0:
							add_effect("burst", shot.p, shot.p, shot.color, 0.3, splash * 2)
							for nearby in enemies.duplicate():
								if nearby != enemy and not nearby.dead and nearby.age > 0.65 and nearby.p.distance_to(shot.p) <= splash and line_clear(shot.p, nearby.p):
									hit_enemy(nearby, shot.damage * 0.6, shot.p)
						if shot not in projectiles:
							break
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

func hit_enemy(enemy: Dictionary, damage: float, source: Vector2, traits: Dictionary = {}) -> void:
	if enemy.is_empty() or enemy.dead:
		return
	if enemy.get("castle_shield", false):
		return
	if is_ruoyu(enemy) and state == "ruoyu_unseal":
		return
	var critical: bool = rng.randf() < player_stat("crit_chance")
	if critical:
		damage *= player_stat("crit_damage")
	if cheat_one_hit:
		damage = enemy.max_hp + 1
	elif (is_ruoyu(enemy) or is_yang(enemy) or is_yamada(enemy)) and enemy.phase == 0:
		damage = minf(damage, maxf(0.0, enemy.hp - enemy.max_hp * 0.5))
	elif enemy.guard_time > 0.0 and enemy.aim.dot(enemy.p.direction_to(source)) > 0.25:
		damage *= 0.4
	var dealt: float = minf(maxf(0, enemy.hp), damage)
	enemy.hp -= damage
	health = minf(max_health(), health + dealt * player_stat("lifesteal"))
	if traits.has("slow"):
		enemy["slow"] = maxf(0.75, traits.slow) if is_boss(enemy) else traits.slow
		enemy["slow_time"] = 1.5
	enemy.flash = 0.12
	add_effect("impact", enemy.p + Vector2(0, -18), enemy.p + (enemy.p - source).normalized(), Color.WHITE, 0.26, 60)
	camera_shake = maxf(camera_shake, 1.8 if not is_boss(enemy) else 3.0)
	texts.append({"p":enemy.p + Vector2(-10, -28), "text":("暴击 " if critical else "") + str(int(ceil(damage))), "color":Color("ffc878") if critical else Color("ffe2b3"), "life":0.65})
	if not is_boss(enemy):
		enemy.p = slide(enemy.p, (enemy.p - source).normalized() * float(traits.get("knockback", 11.0)), enemy.radius)
	if enemy.hp <= 0:
		enemy.dead = true
		add_effect("burst", enemy.p + Vector2(0, -16), enemy.p, Color.WHITE, 0.35, 75)
		enemies.erase(enemy)
		if enemy.get("yamada_clone", false) and enemies.any(func(other: Dictionary) -> bool: return other.get("yamada_clone", false)):
			audio.sfx("kill")
			return
		kills += 1
		audio.sfx("kill_boss" if is_boss(enemy) else "kill")
		var reward: int = 60 if is_boss(enemy) else (1 if enemy.kind == "minislime" else (5 if enemy.kind in ["charger", "dasher"] else 3))
		drops.append({"p":enemy.p, "value":reward, "age":0.0})
		if enemy.kind == "splitter":
			for i in range(3):
				var p: Vector2 = slide(enemy.p, Vector2.from_angle(TAU * i / 3) * 34, 10)
				spawn_enemy(p, "minislime")
		if is_boss(enemy):
			for other in enemies:
				other.dead = true
			enemies.clear()
			projectiles.clear()

func hurt(amount: float, source: Vector2) -> void:
	if state != "playing" or invulnerable > 0 or shield_time > 0 or cheat_invincible:
		return
	if rng.randf() < player_stat("dodge"):
		invulnerable = 0.25
		texts.append({"p":player + Vector2(-10, -42), "text":"闪避", "color":Color("85e0b9"), "life":0.65})
		audio.sfx("dash")
		return
	var actual: float = maxf(1, amount * (1.0 - player_stat("armor")) * player_stat("incoming_damage") * Data.DIFFICULTIES[run_difficulty].damage)
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
		if distance < player_stat("pickup_radius") or current_room().cleared:
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
	spawn_remaining = 0
	projectiles.clear()
	turrets.clear()
	collect_drops()
	cleared_count += 1
	gain_points(18 if room.type != "boss" else 60)
	health = minf(max_health(), health + 4)
	if contract_active:
		gain_points(45)
		contract_active = false
		notify("加急工单完成 · 罗德支付了 45 字节")
	else:
		notify("战区已清空 · 字节已收集 · 所有出口开启")
	if room.type == "boss":
		open_skill_reward()
	elif room.type in ["combat", "elite"]:
		room.reward_shop = true
		open_shop()
		notify("战后补给 · 可刷新货架")
	audio.sfx("repair")

func max_health() -> float:
	return player_stat("health")

func player_stat(id: String) -> float:
	var value: float = Data.STAT_BASES[id]
	for entry in equipment + weapons:
		var stats: Dictionary = Data.item(entry.id).get("stats", {})
		value += float(stats.get(id, 0.0)) * Data.equipment_multiplier(entry.tier) * entry.get("count", 1)
	match id:
		"damage": value += buff_damage + skill_level("power") * 0.15
		"attack_speed": value += skill_level("haste") * 0.12
		"health": value += skill_level("vigor") * 20
		"regen": value += skill_level("recovery") * 0.5
		"dash_recovery": value += skill_level("dash") * 0.2
	return clampf(value, Data.STAT_MINIMUMS.get(id, 0.0), Data.STAT_CAPS[id])

func equipment_stat(id: String) -> float:
	var result: float = 0
	for entry in equipment:
		if entry.id == id:
			result += Data.equipment_multiplier(entry.tier) * entry.get("count", 1)
	return result

func equipment_count(id: String = "") -> int:
	var result: int = 0
	for entry in equipment:
		if id.is_empty() or entry.id == id:
			result += entry.get("count", 1)
	return result

func move_speed() -> float:
	return player_stat("move_speed")

func damage_scale(attack_type: String = "") -> float:
	var value: float = player_stat("damage")
	if attack_type in Data.ATTACK_NAMES:
		value += player_stat(attack_type + "_damage") - 1.0
	return clampf(value, 0.25, Data.STAT_CAPS.damage)

func attack_speed() -> float:
	return player_stat("attack_speed")

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
	if floor_index < Data.FLOOR_COUNT - 1:
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
	if spec.kind == "equipment" or inventory.size() < 6:
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
	var previous_max: float = max_health()
	if spec.kind == "equipment":
		for entry in equipment:
			if entry.id == id and entry.tier == tier:
				entry.count += 1
				health = minf(max_health(), health + maxf(0, max_health() - previous_max))
				return true
	var inventory: Array[Dictionary] = weapons if spec.kind == "weapon" else equipment
	if not can_add_item(id, tier):
		notify("%s栏已满 · 没有可合并的同名同品质物品" % ("武器" if spec.kind == "weapon" else "装备"))
		return false
	var auto_merge: bool = spec.kind == "weapon" and inventory.size() >= 6
	inventory.append({"id":id, "tier":tier, "count":1, "cooldown":0.0, "aim":Vector2.RIGHT})
	health = minf(max_health(), health + maxf(0, max_health() - previous_max))
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
	if kind == "equipment" and inventory[index].count >= 2:
		return index
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
	if kind == "equipment":
		var previous_health: float = health
		var next_tier: int = entry.tier + 1
		var other: Dictionary = inventory[partner]
		entry.count -= 1
		other.count -= 1
		if other.count <= 0:
			inventory.erase(other)
		if index != partner and entry.count <= 0:
			inventory.erase(entry)
		add_item(entry.id, next_tier)
		health = minf(previous_health + maxf(0, max_health() - previous_max), max_health())
		for i in range(inventory.size()):
			if inventory[i].id == entry.id and inventory[i].tier == next_tier:
				return i
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
	if kind == "equipment" and entry.count > 1:
		entry.count -= 1
	else:
		inventory.remove_at(index)
	health = minf(health, max_health())
	notify("物品已出售 · 字节已返还")
	return true

func sell_price(entry: Dictionary) -> int:
	return maxi(1, int(Data.item(entry.id).price * pow(2, entry.tier - 1) * 0.45))

func shop_price(entry: Dictionary) -> int:
	var discount: float = 0.85 if current_room().type == "shop" else 1.0
	return maxi(1, ceili(Data.item(entry.id).price * pow(2, entry.tier - 1) * discount * price_scale()))

func price_scale() -> float:
	return (1.0 + cleared_count * 0.05) * pow(1.15, floor_index)

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
	if current_room().reward_shop:
		current_room().reward_shop = false
	state = shop_return
	interaction_cooldown = 0.25

func roll_stock() -> void:
	var room: Dictionary = current_room()
	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = seed_value + floor_index * 8191 + room_id * 101 + room.refreshes * 100003
	var offers: Array[Dictionary] = []
	var pool: Array[Dictionary] = []
	pool.assign(Data.WEAPONS + Data.EQUIPMENT)
	for i in range(4):
		var spec: Dictionary = pool[shop_rng.randi_range(0, pool.size() - 1)]
		var tier: int = 1
		if floor_index > 0 and shop_rng.randf() < 0.25:
			tier = 2
		pool.erase(spec)
		offers.append({"id":spec.id, "tier":tier, "sold":false})
	if not room.stock.is_empty():
		var same: bool = true
		for i in range(4):
			same = same and room.stock[i].id == offers[i].id and room.stock[i].tier == offers[i].tier
		if same:
			offers[0].id = pool[shop_rng.randi_range(0, pool.size() - 1)].id
	room.stock = offers
	stock = room.stock

func buy(index: int) -> bool:
	if state != "shop" or index < 0 or index >= stock.size() or stock[index].sold:
		return false
	var offer: Dictionary = stock[index]
	var price: int = shop_price(offer)
	if points < price:
		notify("字节不足 · 清怪和完成委托可以获得字节")
		return false
	var inventory: Array[Dictionary] = weapons if Data.item(offer.id).kind == "weapon" else equipment
	var auto_merge: bool = Data.item(offer.id).kind == "weapon" and inventory.size() >= 6
	if not add_item(offer.id, offer.tier):
		return false
	points -= price
	offer.sold = true
	if not auto_merge:
		notify("获得 " + Data.item(offer.id).name + " · Tab 查看 / 合并")
	audio.sfx("coffee")
	return true

func refresh_price() -> int:
	return 0 if current_room().refreshes == 0 else ceili((4 + (current_room().refreshes - 1) * 2) * price_scale())

func refresh_shop() -> bool:
	if state != "shop":
		return false
	var price: int = refresh_price()
	if points < price:
		notify("刷新需要 %d 字节" % price)
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
		npc_reply = ""
		state = "npc"
		return
	if not room.rect.has_point(player):
		return
	if player.distance_to(room_center()) > 90:
		notify("走近中央装置或 NPC 后按 E")
		return
	match room.type:
		"boss": open_skill_reward()
		"treasure": open_treasure()
		"rest":
			if not room.used:
				room.used = true
				health = minf(max_health(), health + 40)
				notify("咖啡驿站 · 恢复 40 生命")
				audio.sfx("coffee")
			else:
				notify("咖啡已经喝完了，继续前进吧")
		"shop": open_shop()

func open_treasure() -> void:
	var room: Dictionary = current_room()
	if state != "playing" or room.type != "treasure" or not room.cleared or room.used:
		return
	if not room.has("treasure_offers"):
		var reward_rng := RandomNumberGenerator.new()
		reward_rng.seed = seed_value + floor_index * 8191 + room_id * 101 + 503
		var pool: Array[Dictionary] = Data.WEAPONS.duplicate()
		var offers: Array[Dictionary] = []
		for i in range(3):
			var index: int = reward_rng.randi_range(0, pool.size() - 1)
			offers.append({"id":pool[index].id, "tier":2})
			pool.remove_at(index)
			if i == 1:
				pool.assign(Data.EQUIPMENT)
		room["treasure_offers"] = offers
	state = "treasure"
	audio.sfx("coffee")

func choose_treasure(index: int) -> bool:
	var room: Dictionary = current_room()
	var offers: Array = room.get("treasure_offers", [])
	if state != "treasure" or room.used or index < 0 or index >= offers.size():
		return false
	var offer: Dictionary = offers[index]
	var auto_merge: bool = Data.item(offer.id).kind == "weapon" and weapons.size() >= 6
	if not add_item(offer.id, offer.tier):
		return false
	room.used = true
	state = "playing"
	interaction_cooldown = 0.25
	if not auto_merge:
		notify("宝箱奖励 · " + Data.item(offer.id).name)
	audio.sfx("repair")
	return true

func skip_treasure() -> bool:
	if state != "treasure" or current_room().used:
		return false
	current_room().used = true
	state = "playing"
	interaction_cooldown = 0.25
	notify("已放弃宝箱奖励")
	return true

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
		"rhode":
			contract_pending = true
			notify("委托已接受 · 下一间战斗房追加一波")
		"heide":
			knight_active = true
			knight = npc_position()
			previous_knight = knight
			knight_cooldown = 0
			knight_attack_time = 0
			knight_facing = Vector2.DOWN
			knight_moving = false
			knight_animation_time = 0
			knight_path.clear()
			knight_path_time = 0
			room.npc = -1
		"basan":
			if points < 12:
				npc_reply = "先凑够 12 字节再来"
				return false
			points -= 12
			buff_damage += 0.12
		"laya":
			var candidates: Array[Dictionary] = []
			for spec_item in Data.WEAPONS + Data.EQUIPMENT:
				if can_add_item(spec_item.id):
					candidates.append(spec_item)
			if candidates.is_empty():
				npc_reply = "先在 Tab 背包里腾出一个位置吧"
				return false
			var gift: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
			var inventory: Array[Dictionary] = weapons if gift.kind == "weapon" else equipment
			var auto_merge: bool = gift.kind == "weapon" and inventory.size() >= 6
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
				npc_reply = "你的武器都已经是传说品质了"
				return false
	room.npc_used = true
	state = "playing"
	interaction_cooldown = 0.25
	audio.sfx("repair")
	return true

func next_floor() -> bool:
	if state != "playing" or current_room().type != "boss" or not current_room().cleared or not current_room().skill_claimed or floor_index >= Data.FLOOR_COUNT - 1:
		return false
	load_next_floor()
	dialogue_kind = "floor"
	dialogue_index = 0
	state = "dialogue"
	return true

func skip_floor() -> bool:
	if state != "cheats" or floor_index >= Data.FLOOR_COUNT - 1:
		return false
	assisted = true
	load_next_floor()
	return true

func load_next_floor() -> void:
	collect_drops()
	floor_index += 1
	health = minf(max_health(), health + 25)
	generate_floor()

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
	return {"speaker":"ChatGPT 公主", "line":"我收到你的信号了！" + Data.FLOOR_STORIES[floor_index] + "（生命恢复 25；海德骑士已在层间离队。）"}

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
		best_floor = clampi(int(data.get("floor", 0)), 0, Data.FLOOR_COUNT)

func notify(value: String) -> void:
	message = value
	message_time = 3.5

func boss_say(enemy: Dictionary, value: String, duration: float = 2.5) -> void:
	enemy["speech"] = value
	enemy["speech_time"] = duration

func add_effect(kind: String, a: Vector2, b: Vector2, color: Color, life: float, size: float) -> void:
	effects.append({"kind":kind, "a":a, "b":b, "color":color, "life":life, "max_life":life, "size":size})

func toggle_inventory() -> void:
	view.reset_inventory_interaction()
	if state == "inventory":
		state = return_state
	elif state in ["playing", "shop", "paused", "npc", "treasure"]:
		return_state = state
		state = "inventory"

func start_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/sandbox.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		view.move_pointer(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		view.click(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		view.right_click(event.position)
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
		if state == "inventory" and view.dismiss_context():
			return
		match state:
			"playing": toggle_inventory()
			"paused", "npc": state = "playing"
			"confirm_title": state = "inventory"
			"inventory", "guide", "map", "cheats": state = return_state
			"shop": leave_shop()
			"treasure": skip_treasure()
			"dialogue":
				if dialogue_kind == "ending":
					finish_run(true)
				else:
					state = "playing"
	elif state == "dialogue" and code in [KEY_ENTER, KEY_SPACE, KEY_E]:
		advance_dialogue()
	elif code == KEY_F and state == "playing":
		deploy_turret()
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
	elif state == "treasure" and code >= KEY_1 and code <= KEY_3:
		choose_treasure(code - KEY_1)
	elif state == "npc" and code in [KEY_ENTER, KEY_E]:
		accept_npc()
	elif state == "cheats":
		if code in [KEY_1, KEY_2]:
			toggle_cheat(code - KEY_1)
		elif code == KEY_3:
			skip_floor()

func toggle_cheat(index: int) -> void:
	if state != "cheats":
		return
	if index == 0:
		cheat_invincible = not cheat_invincible
	else:
		cheat_one_hit = not cheat_one_hit
	assisted = assisted or cheat_invincible or cheat_one_hit
