extends RefCounted
## Death, the hearth attendant, and the temporary System Fault world.
const Data = preload("res://scripts/sandbox_data.gd")
const LIMIT: int = 10
const REVIVE_SECONDS: float = 1.8
const TRANSITION_COVER: float = 0.90
const TRANSITION_CUT: float = 1.05
const TRANSITION_REVEAL: float = 1.20
const TRANSITION_END: float = 2.25
const ENCOUNTER_RANGE: float = 610.0
const BOSS_MIN_HP: float = 700.0
const BOSS_MAX_HP: float = 1610.0
const BOSS_ID: String = "fault_ape"
const ENEMIES: Dictionary = {
	"fault_zombie": {"name":"夜班尸", "hp":52, "damage":13, "speed":103, "art":"zombie", "height":44, "attack":"lunge", "reach":120, "windup":0.42, "active":0.30},
	"fault_eye": {"name":"窥雾复眼", "hp":58, "damage":15, "speed":92, "art":"eye", "height":36, "attack":"fan", "reach":420, "windup":0.65, "active":0.36, "flying":true},
	"fault_hands": {"name":"多手林孽", "hp":98, "damage":19, "speed":73, "art":"hands", "height":53, "attack":"slam", "reach":112, "windup":0.68, "active":0.35},
	"fault_mimic": {"name":"蜕形体", "hp":80, "damage":18, "speed":135, "art":"mimic", "height":39, "attack":"lunge", "reach":185, "windup":0.48, "active":0.42},
	"fault_chroma": {"name":"异色漂影", "hp":66, "damage":13, "speed":84, "art":"chroma", "height":45, "attack":"ring", "reach":280, "windup":0.78, "active":0.42, "flying":true},
}
const APE_ATTACKS: Array[Dictionary] = [
	{"id":"pounce", "name":"扑袭", "windup":0.76, "active":0.54, "frame":4},
	{"id":"quake", "name":"重拳", "windup":0.90, "active":0.45, "frame":8},
	{"id":"howl", "name":"吼叫", "windup":0.96, "active":0.48, "frame":12},
]

var game: Node
var leaks: int = 0
var revivals: int = 0
var keeper_unlocked: bool = false
var pending: bool = false
var revive_time: float = 0.0
var last_heal_day: int = 0
var active: bool = false
var cycles: int = 0
var priest_site := Vector2.ZERO
var ape_site := Vector2.ZERO
var keeper_site := Vector2.INF
var boss_hp: float = 0.0
var boss_max_hp: float = 0.0
var boss_damage: float = 0.0
var position_clock: float = 0.0
var escape_text: String = ""
var transition_kind: String = ""
var transition_time: float = 0.0
var transition_swapped: bool = false

func _init(owner: Node) -> void:
	game = owner

func reset() -> void:
	leaks = 0
	revivals = 0
	keeper_unlocked = false
	pending = false
	revive_time = 0
	last_heal_day = 0
	active = false
	cycles = 0
	priest_site = Vector2.ZERO
	ape_site = Vector2.ZERO
	keeper_site = Vector2.INF
	boss_hp = 0
	boss_max_hp = 0
	boss_damage = 0
	position_clock = 0
	escape_text = ""
	clear_transition()

func record_death() -> void:
	if pending:
		return
	pending = true
	keeper_unlocked = true
	revive_time = 0
	leaks += 1

func death_tick(delta: float) -> void:
	if pending:
		revive_time += delta
		if revive_time >= REVIVE_SECONDS:
			game.respawn()

func finish_revival() -> bool:
	if not pending:
		return false
	pending = false
	revivals += 1
	if not active and revivals >= LIMIT:
		begin_transition("enter")
		return true
	refresh_keeper()
	return false

func revive_position() -> Vector2:
	var fallen: Vector2 = game.player
	if usable(fallen, 8, 36):
		return fallen
	var near: Vector2 = standing_near(fallen, 7, 6, 8, 36)
	return near if near.is_finite() else game.safe_spawn()

func death_actor_position() -> Vector2:
	for side in [1, -1]:
		var feet: Vector2 = game.player + Vector2(side * 32, 0)
		if usable(feet, 8, 42):
			return feet
	return game.player + Vector2(18 * game.facing, -12)

func usable(feet: Vector2, width: float, height: float) -> bool:
	if not feet.is_finite() or not game.world.valid(game.cell_at(feet)) or not game.body_free(feet, width, height, true):
		return false
	var structures = game.adventure.structures
	var lower: Vector2i = structures.fluid(game.cell_at(feet - Vector2(0, 8)))
	var upper: Vector2i = structures.fluid(game.cell_at(feet - Vector2(0, height * 0.8)))
	return lower.x != 2 and upper.y <= 4

func standing_near(anchor: Vector2, horizontal: int, vertical: int, width: float, height: float) -> Vector2:
	var cell: Vector2i = game.cell_at(anchor)
	var best := Vector2.INF
	var best_distance: float = INF
	for x in range(maxi(1, cell.x - horizontal), mini(Data.WIDTH - 1, cell.x + horizontal + 1)):
		for y in range(maxi(3, cell.y - vertical), mini(Data.HEIGHT - 1, cell.y + vertical + 1)):
			var feet := Vector2((x + 0.5) * Data.TILE, y * Data.TILE - 0.01)
			var distance: float = feet.distance_squared_to(anchor)
			if distance < best_distance and game.world.solid(Vector2i(x, y)) and usable(feet, width, height):
				best = feet
				best_distance = distance
	return best

func refresh_keeper() -> void:
	keeper_site = Vector2.INF
	if not keeper_unlocked or pending:
		return
	var base: Vector2 = game.world.spawn
	var anchor: Vector2 = base + Vector2(55, 0)
	var room: Dictionary = game.adventure.structures.inspect_house(game.cell_at(base - Vector2(0, 16)))
	if room.valid:
		var best_score: float = INF
		for feet in room.standing:
			if not usable(feet, 8, 42):
				continue
			var score: float = feet.distance_squared_to(anchor)
			for npc in game.adventure.structures.npcs:
				if feet.distance_to(npc.p) < 22:
					score += 18000
			if score < best_score:
				best_score = score
				keeper_site = feet
	if not keeper_site.is_finite():
		keeper_site = standing_near(anchor, 8, 6, 8, 42)
	if not keeper_site.is_finite():
		keeper_site = game.nearby_surface(base, 12)
	if not keeper_site.is_finite():
		keeper_site = base - Vector2(0, 30)

func can_talk_at(feet: Vector2, reach: float = 85.0) -> bool:
	return feet.is_finite() and game.player.distance_to(feet) < reach and game.line_clear(game.cell_at(feet - Vector2(0, 23)))

func interact() -> bool:
	if active and can_talk_at(priest_site):
		game.set_state("fault_priest")
		return true
	if not keeper_unlocked or not can_talk_at(keeper_site, 72):
		return false
	var furniture: Vector2i = game.adventure.structures.nearby_interactable()
	if furniture.x >= 0 and game.cell_center(furniture).distance_to(game.player - Vector2(0, 12)) < keeper_site.distance_to(game.player):
		return false
	game.set_state("fire_keeper")
	return true

func heal_reason() -> String:
	if last_heal_day == game.day_number():
		return "今日已经疗愈，等下一个游戏日。"
	if game.health >= game.max_health():
		return "你的生命已经恢复。"
	return ""

func heal_at_home() -> bool:
	if game.state != "fire_keeper" or not keeper_unlocked or not can_talk_at(keeper_site, 72):
		return false
	var reason: String = heal_reason()
	if not reason.is_empty():
		game.notify("防火女：" + reason)
		return false
	var health_before: float = game.health
	var healed_before: int = last_heal_day
	game.health = game.max_health()
	last_heal_day = game.day_number()
	if not game.save_world():
		game.health = health_before
		last_heal_day = healed_before
		return false
	game.set_state("playing")
	game.notify("防火女：把手伸近些。今天的火还暖着。")
	game.audio.sfx("repair")
	return true

func surface_site(x: int, width: float, height: float) -> Vector2:
	var ground: int = game.world.surface_at(x)
	var anchor := Vector2((x + 0.5) * Data.TILE, ground * Data.TILE)
	var spot: Vector2 = standing_near(anchor, 16, 15, width, height)
	return spot if spot.is_finite() else anchor - Vector2(0, 48)

func begin_transition(kind: String) -> void:
	transition_kind = kind
	transition_time = 0.0
	transition_swapped = false
	game.set_state("fault_transition")
	game.message_time = 0.0
	game.audio.sfx("fault_close")

func clear_transition() -> void:
	transition_kind = ""
	transition_time = 0.0
	transition_swapped = false

func transition_tick(delta: float) -> void:
	transition_time = minf(TRANSITION_END, transition_time + delta)
	if transition_time >= TRANSITION_CUT and not transition_swapped:
		swap_worlds()
		game.save_world()
	if transition_time >= TRANSITION_END:
		var entering: bool = transition_kind == "enter"
		clear_transition()
		game.pad_jump_blocked = game.pad.active and Input.is_joy_button_pressed(game.pad.device, JOY_BUTTON_A)
		if not entering:
			game.set_state("fault_resolved")
			return
		game.set_state("playing" if game.window_focused else "paused")
		if game.save_error.is_empty():
			game.notify("第十次复活。内存泄漏已触发：里世界「系统故障」。")

func swap_worlds() -> void:
	if transition_kind.is_empty() or transition_swapped:
		return
	transition_time = maxf(transition_time, TRANSITION_CUT)
	transition_swapped = true
	if transition_kind == "enter":
		enter_world()
		game.audio.sfx("fault_open")
	else:
		leave_world(transition_kind == "ape")
	game.view.clear_cache()
	game.refresh_merchant()

func enter_world() -> void:
	active = true
	cycles += 1
	var center: int = clampi(game.cell_at(game.world.spawn).x, 77, Data.WIDTH - 78)
	var side: int = -1 if posmod(game.world.seed_value + cycles, 2) == 0 else 1
	priest_site = surface_site(center + side * 35, 9, 42)
	ape_site = surface_site(center - side * 43, 24, 66)
	boss_max_hp = BOSS_MIN_HP + game.adventure.stage() * 70 + game.pick_tier * 70
	boss_hp = boss_max_hp
	boss_damage = 22.0 + game.adventure.stage() * 2.0
	refresh_keeper()
	game.enemy_timer = 4

func priest_purge() -> bool:
	if game.state != "fault_priest" or not active or not can_talk_at(priest_site):
		return false
	exit(false)
	return true

func exit(ape_defeated: bool) -> void:
	if active and transition_kind.is_empty():
		begin_transition("ape" if ape_defeated else "priest")

func leave_world(ape_defeated: bool) -> void:
	active = false
	leaks = 0
	revivals = 0
	priest_site = Vector2.ZERO
	ape_site = Vector2.ZERO
	boss_hp = 0
	boss_max_hp = 0
	boss_damage = 0
	game.reset_transients()
	if ape_defeated:
		game.add_item("coin", 120)
		game.pad.pulse("victory")
		game.audio.sfx("kill_boss")
		escape_text = "狮子猿倒下了，雾开始消散。"
	else:
		game.audio.sfx("repair")
		escape_text = "神父：故障解除了。走吧，别让公主再等。"

func location_hint(site: Vector2) -> String:
	var distance: int = roundi((site.x - game.player.x) / Data.TILE)
	if abs(distance) <= 5:
		return "就在附近" if absf(site.y - game.player.y) < 100 else "在上方的地表"
	return "%s %d 格" % ["往右" if distance > 0 else "往左", abs(distance)]

func tick(delta: float) -> void:
	position_clock -= delta
	if position_clock <= 0:
		position_clock = 2.0
		refresh_keeper()
		if active and not usable(priest_site, 9, 42):
			var moved: Vector2 = standing_near(priest_site, 10, 14, 9, 42)
			if moved.is_finite():
				priest_site = moved
	if not active or not game.adventure.current_boss().is_empty():
		return
	if game.player.distance_to(ape_site) > ENCOUNTER_RANGE:
		return
	var site: Vector2 = ape_site
	if not usable(site, 24, 66):
		site = standing_near(ape_site, 13, 15, 24, 66)
	if not site.is_finite():
		return
	var spec: Dictionary = {"name":"狮子猿", "hp":boss_max_hp, "damage":boss_damage, "speed":112, "art":"ape", "height":110, "fault":true, "fault_boss":true}
	var ape: Dictionary = game.adventure.spawn(BOSS_ID, site, -1, spec)
	ape.hp = boss_hp
	game.notify("狮子猿从雾里逼近。")

func spawn_enemy() -> void:
	if game.enemies.size() >= 18:
		return
	var at: Vector2i = game.cell_at(game.player)
	var deep: bool = at.y > game.world.surface_at(at.x) + 13
	var local_kind: String = "fault_eye"
	match game.adventure.biome(game.player):
		"forest", "jungle": local_kind = "fault_hands"
		"desert", "snow", "cavern": local_kind = "fault_mimic"
		"underworld", "ocean": local_kind = "fault_chroma"
	var pool: Array[String] = ["fault_zombie", "fault_zombie", "fault_zombie", local_kind, local_kind, "fault_eye", "fault_hands", "fault_mimic", "fault_chroma"]
	var kind: String = pool[game.rng.randi_range(0, pool.size() - 1)]
	var spec: Dictionary = ENEMIES[kind].duplicate()
	spec.fault = true
	var flying: bool = spec.get("flying", false)
	var preferred_side: int = -1 if game.rng.randi_range(0, 1) == 0 else 1
	for attempt in range(8):
		var side: int = preferred_side if attempt % 2 == 0 else -preferred_side
		var span: int = game.rng.randi_range(8, 16) if deep else game.rng.randi_range(19, 28)
		var x: int = clampi(at.x + side * span, 3, Data.WIDTH - 4)
		var y: int = at.y if deep else game.world.surface_at(x)
		var anchor := Vector2((x + 0.5) * Data.TILE, y * Data.TILE)
		var p: Vector2 = standing_near(anchor, 2, 9, 10, 34)
		if not p.is_finite() or p.distance_to(priest_site) < 125:
			continue
		if flying and usable(p - Vector2(0, 48), 10, 28):
			p.y -= 48
		var escalation: float = 1.35 + game.adventure.stage() * 0.075
		spec.hp *= escalation
		spec.damage *= 1.28 + game.adventure.stage() * 0.045
		spec.speed *= 1.16
		game.adventure.spawn(kind, p, -1, spec)
		return

func enemy_frame(enemy: Dictionary) -> int:
	if enemy.windup > 0:
		var time: float = enemy.windup / enemy.get("fault_windup_total", 1.0)
		return enemy.get("fault_frame", 4) + (0 if time > 0.5 else 1)
	var strike: float = enemy.get("fault_strike", 0.0)
	if strike > 0:
		var time: float = strike / enemy.get("fault_strike_total", 1.0)
		return enemy.get("fault_frame", 4) + (2 if time > 0.5 else 3)
	return (2 if absf(enemy.v.x) > 12 or absf(enemy.v.y) > 20 else 0) + int(enemy.age * 5.5) % 2

func update_enemy(enemy: Dictionary, delta: float) -> void:
	var spec: Dictionary = enemy.spec
	var ape: bool = spec.get("fault_boss", false)
	var flying: bool = spec.get("flying", false)
	var enraged: bool = ape and enemy.hp <= enemy.max_hp * 0.5
	var strike: float = enemy.get("fault_strike", 0.0)
	var aim_at: Vector2 = game.player - Vector2(0, 22)
	var origin: Vector2 = enemy.p - Vector2(0, 51 if ape else 20)
	var distance: float = aim_at.distance_to(origin)
	if enemy.windup > 0:
		enemy.windup = maxf(0, enemy.windup - delta)
		if enemy.windup <= 0:
			release_attack(enemy, enraged)
		strike = enemy.get("fault_strike", 0.0)
	elif strike > 0:
		strike = maxf(0, strike - delta)
		enemy.fault_strike = strike
	else:
		enemy.timer -= delta
		var reach: float = 360.0 if ape else spec.reach
		if enemy.timer <= 0 and distance <= reach and game.line_clear(game.cell_at(origin)):
			begin_attack(enemy, aim_at, origin, enraged)

	var speed: float = float(spec.speed) * (0.56 if enemy.slow > 0 else 1.0)
	var committed: bool = enemy.windup > 0 or strike > 0
	if not committed:
		var direction: float = signf(aim_at.x - enemy.p.x)
		if direction != 0:
			enemy.facing = direction
	var half_width: float = 24.0 if ape else 10.0
	var height: float = 66.0 if ape else 30.0
	var ground: bool = not game.body_free(enemy.p + Vector2(0, 1), half_width, height)
	var mode: String = enemy.get("fault_attack", "")
	if strike > 0 and mode in ["lunge", "pounce"]:
		enemy.v.x = enemy.facing * (460.0 if ape else speed * 3.05)
	elif flying:
		var target: Vector2 = game.player + Vector2(sin(enemy.age * 1.45) * 105, -85)
		var motion: Vector2 = (target - enemy.p).normalized() * speed
		enemy.v = enemy.v.lerp(Vector2.ZERO if committed else motion, minf(1, delta * 4.0))
	else:
		enemy.v.x = 0.0 if committed else enemy.facing * speed * (1.25 if enraged else 1.0)
		if not committed and ground and not game.body_free(enemy.p + Vector2(enemy.facing * 14, 0), half_width, height, true):
			enemy.v.y = -410 if ape else -365
	if not flying:
		enemy.v.y = minf(850, enemy.v.y + 1120 * delta)
	var moved: Dictionary = game.move_body(enemy.p, enemy.v * delta, half_width, height)
	enemy.p = moved.p
	if moved.hit.y != 0:
		enemy.v.y = 0
	if moved.hit.x != 0:
		enemy.v.x = 0

func begin_attack(enemy: Dictionary, aim_at: Vector2, origin: Vector2, enraged: bool) -> void:
	var attack_spec: Dictionary = APE_ATTACKS[enemy.attack % APE_ATTACKS.size()] if enemy.spec.get("fault_boss", false) else {}
	var windup: float = attack_spec.get("windup", enemy.spec.get("windup", 0.55))
	enemy.fault_attack = attack_spec.get("id", enemy.spec.get("attack"))
	enemy.fault_frame = attack_spec.get("frame", 4)
	enemy.fault_warning = attack_spec.get("name", "蓄力")
	enemy.aim = (aim_at - origin).normalized()
	if absf(enemy.aim.x) > 0.02:
		enemy.facing = signf(enemy.aim.x)
	enemy.windup = windup * (0.84 if enraged else 1.0)
	enemy.fault_windup_total = enemy.windup
	enemy.fault_strike_total = attack_spec.get("active", enemy.spec.get("active", 0.32))

func release_attack(enemy: Dictionary, enraged: bool) -> void:
	enemy.fault_strike = enemy.fault_strike_total
	enemy.attack += 1
	enemy.timer = 0.95 if enraged else 1.3
	var damage: float = enemy.spec.damage
	var origin: Vector2 = enemy.p - Vector2(0, 54 if enemy.spec.get("fault_boss", false) else 21)
	match enemy.fault_attack:
		"lunge":
			enemy.v.y = -160
		"pounce":
			enemy.v.y = -260
			game.adventure.boss_rumble("charge", enemy.p)
		"slam", "quake":
			var ape: bool = enemy.fault_attack == "quake"
			var offsets: Array = [34, 98, 170] if ape else [42]
			for i in range(offsets.size()):
				var impact: Vector2 = enemy.p + Vector2(enemy.facing * offsets[i], 0)
				game.adventure.hazards.append({"p":impact, "delay":0.11 + i * 0.18, "life":0.26, "damage":damage, "radius":43.0 if ape else 37.0})
			game.audio.sfx("block")
		"fan", "howl":
			var ape: bool = enemy.fault_attack == "howl"
			var count: int = (7 if enraged else 5) if ape else 3
			for index in range(count):
				var angle: float = (index - (count - 1) * 0.5) * 0.19
				game.adventure.shoot(origin, enemy.aim.rotated(angle) * (290.0 if ape else 230.0), damage * 0.82, false)
			if ape:
				game.adventure.boss_rumble("volley", enemy.p)
		"ring":
			for index in range(7):
				var angle: float = TAU * index / 7 + enemy.age
				game.adventure.shoot(origin, Vector2.from_angle(angle) * 172, damage * 0.85, false)

func save_data() -> Dictionary:
	return {
		"leaks":leaks, "revivals":revivals, "keeper":keeper_unlocked, "pending":pending,
		"heal_day":last_heal_day, "active":active, "cycles":cycles,
		"priest":priest_site, "ape":ape_site,
		"boss_hp":boss_hp, "boss_max":boss_max_hp, "boss_damage":boss_damage,
	}

func valid_save(data: Variant, health: float, day: int) -> bool:
	if not data is Dictionary:
		return false
	for key in ["leaks", "revivals", "heal_day", "cycles"]:
		if not data.get(key) is int or data[key] < 0 or data[key] > 100000000:
			return false
	for key in ["keeper", "pending", "active"]:
		if not data.get(key) is bool:
			return false
	if data.leaks != data.revivals + int(data.pending) or (data.pending and health > 0):
		return false
	if data.heal_day > day or (not data.keeper and (data.leaks > 0 or data.cycles > 0 or data.heal_day > 0)):
		return false
	if data.active != (data.revivals >= LIMIT) or (data.active and data.cycles == 0):
		return false
	for key in ["priest", "ape"]:
		if not data.get(key) is Vector2 or not data[key].is_finite() or not game.world.valid(game.cell_at(data[key])):
			return false
	for key in ["boss_hp", "boss_max", "boss_damage"]:
		if typeof(data.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(data[key])):
			return false
	if data.active:
		return data.boss_max >= BOSS_MIN_HP and data.boss_max <= BOSS_MAX_HP and data.boss_hp > 0 and data.boss_hp <= data.boss_max and data.boss_damage >= 22.0 and data.boss_damage <= 38.0
	return data.boss_hp == 0 and data.boss_max == 0 and data.boss_damage == 0

func load_data(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	leaks = data.leaks
	revivals = data.revivals
	keeper_unlocked = data.keeper
	pending = data.pending
	last_heal_day = data.heal_day
	active = data.active
	cycles = data.cycles
	priest_site = data.priest
	ape_site = data.ape
	boss_hp = data.boss_hp
	boss_max_hp = data.boss_max
	boss_damage = data.boss_damage
