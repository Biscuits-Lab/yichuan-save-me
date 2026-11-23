extends RefCounted
const Data = preload("res://scripts/sandbox_data.gd")
const Catalog = preload("res://scripts/sandbox_catalog.gd")
const Structures = preload("res://scripts/sandbox_structures.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
var game: Node
var structures: RefCounted
var atlases: Dictionary = {}
var icons: Dictionary = {}
var bosses: Dictionary = {}
var bestiary: Dictionary = {}
var armor: String = ""
var accessories: Array[String] = []
var life_upgrades: int = 0
var fruit_upgrades: int = 0
var mana_upgrades: int = 0
var mana: float = 60.0
var mana_delay: float = 0
var heal_cooldown: float = 0
var food_cooldown: float = 0
var food_buff: float = 0
var fishing: Dictionary = {}
var air_jumps: int = 0
var flight: float = 2.0
var hook := Vector2.INF
var shots: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var companion: bool = false
var companion_p := Vector2.ZERO
var companion_cooldown: float = 0
var event: String = ""
var event_left: int = 0
var event_kills: int = 0
var event_clock: float = 0
var last_blood_day: int = 0
var blood_moon: bool = false
var serial: int = 0
var inventory_page: int = 0
var recipe_page: int = 0

func _init(owner: Node) -> void:
	game = owner
	structures = Structures.new(game)
	atlases.dungeon = game.enemy_atlas
	for entry in [["classic","res://assets/sprites/engine-enemies.png",4,4], ["expanded","res://assets/sprites/engine-enemies-expanded.png",4,4], ["wilds","res://assets/generated/dungeon/wilds-cast.png",4,4], ["shark","res://assets/generated/dungeon/big-shark.png",2,2], ["yamada","res://assets/generated/dungeon/yamada.png",2,2], ["heide","res://assets/generated/dungeon/heide-animations.png",8,4], ["cast","res://assets/generated/dungeon/cast.png",4,4], ["jiahao","res://assets/generated/dungeon/jiahao.png",2,1]]:
		atlases[entry[0]] = Atlas.new(load(entry[1]),entry[2],entry[3])
	for id in Catalog.WEAPONS:
		var path: String = "res://assets/generated/dungeon/icons/%s.png" % Catalog.ITEMS[id].get("icon","wand")
		if ResourceLoader.exists(path):
			icons[id] = Atlas.new(load(path),1,1)
	var base_icons = Atlas.new(load("res://assets/generated/dungeon/items.png"),4,3)
	var base_frames: Dictionary = {"star_blade":0,"pistol":1,"summon_staff":2,"spear":3,"shotgun":4}
	for id in base_frames:
		var region: Rect2 = base_icons.frames[base_frames[id]].region
		icons[id] = Atlas.new(ImageTexture.create_from_image(base_icons.texture.get_image().get_region(Rect2i(region))),1,1)
	for id in ["copper_armor","iron_armor","gold_armor","molten_armor","mythril_armor","star_armor"]:
		var region: Rect2 = base_icons.frames[6].region
		icons[id] = Atlas.new(ImageTexture.create_from_image(base_icons.texture.get_image().get_region(Rect2i(region))),1,1)
	var equipment_icons: Dictionary = {"boots":"boots","double_jump":"spring","wings":"feather","lava_charm":"charm","life_crystal":"heart","life_fruit":"breakfast","mana_star":"prism","greater_potion":"medkit","core_fragment":"reactor","soul":"conduit","cooked_fish":"breakfast"}
	for id in equipment_icons:
		icons[id] = Atlas.new(load("res://assets/generated/dungeon/icons/%s.png" % equipment_icons[id]),1,1)

func reset() -> void:
	bosses.clear()
	bestiary.clear()
	armor = ""
	accessories.clear()
	life_upgrades = 0
	fruit_upgrades = 0
	mana_upgrades = 0
	mana = 60
	companion = false
	event = ""
	event_left = 0
	event_kills = 0
	last_blood_day = 0
	blood_moon = false
	inventory_page = 0
	recipe_page = 0
	mana_delay = 0
	heal_cooldown = 0
	food_cooldown = 0
	food_buff = 0
	event_clock = 0
	structures.reset()
	reset_transients()

func reset_transients() -> void:
	shots.clear()
	hazards.clear()
	hook = Vector2.INF
	fishing.clear()
	air_jumps = 0
	flight = 2
	companion_p = game.player
	companion_cooldown = 0
	if not event.is_empty():
		event_left = maxi(0,24 - event_kills)

func stage() -> int:
	var result: int = 0
	for boss in Catalog.BOSSES:
		if not bosses.get(boss.id,false):
			break
		result += 1
	return result

func hardmode() -> bool:
	return bosses.get("compiler_wall",false)

func biome(p: Vector2) -> String:
	var c: Vector2i = game.cell_at(p)
	if c.y >= 157:
		return "underworld"
	if c.x < 20 or c.x > Data.WIDTH - 20:
		return "ocean"
	if c.x >= 362 and c.x <= 433:
		return "corruption"
	if c.x >= 116 and c.x <= 180:
		return "jungle"
	if c.y > game.world.surface_at(c.x) + 15:
		return "cavern"
	if c.x > Data.WIDTH * 0.77:
		return "snow"
	if c.x < Data.WIDTH * 0.23:
		return "desert"
	return "forest"

func biome_name() -> String:
	return {"underworld":"熔火地狱","ocean":"边境海岸","corruption":"版本侵蚀区","jungle":"孢子丛林","cavern":"深层洞窟","snow":"霜松雪原","desert":"落日沙丘","forest":"青苔旷野"}[biome(game.player)]

func has_accessory(id: String) -> bool:
	return accessories.has(id) and game.count_item(id) > 0

func max_mana() -> float:
	return 60.0 + mana_upgrades * 20

func defense() -> float:
	return float(Data.ITEMS.get(armor,{}).get("armor",0)) if game.count_item(armor) > 0 else 0.0

func equip(id: String) -> bool:
	var spec: Dictionary = Data.ITEMS.get(id,{})
	if game.count_item(id) <= 0:
		return false
	if spec.has("armor"):
		armor = "" if armor == id else id
	elif spec.has("accessory"):
		if accessories.has(id):
			accessories.erase(id)
		elif accessories.size() < 5:
			accessories.append(id)
		else:
			game.notify("饰品最多装备 5 件，先卸下一件。")
			return false
	else:
		return false
	game.notify("装备已更新：" + spec.name)
	return true

func spawn(kind: String, p: Vector2, boss_index: int = -1) -> Dictionary:
	if game.enemies.size() >= 28 and boss_index < 0:
		return {}
	var spec: Dictionary = Catalog.ENEMIES.get(kind,Catalog.ENEMIES.slime).duplicate()
	if boss_index >= 0:
		spec = Catalog.BOSSES[boss_index].duplicate()
		spec.ai = "boss"
		spec.speed = 145
	var strength: float = 1.8 if hardmode() and boss_index < 0 else 1.0
	serial += 1
	var enemy: Dictionary = {"id":serial,"kind":kind,"spec":spec,"boss_index":boss_index,"p":p,"previous":p,"v":Vector2.ZERO,"hp":float(spec.hp) * strength,"max_hp":float(spec.hp) * strength,"jump":0.3,"timer":game.rng.randf_range(0.7,1.4),"windup":0.0,"charge":0.0,"aim":Vector2.LEFT,"flash":0.0,"age":0.0,"facing":-1.0,"dark":game.is_night(),"burn":0.0,"burn_tick":0.0,"slow":0.0,"attack":0}
	game.enemies.append(enemy)
	return enemy

func find_spawn(x: int, flying: bool) -> Vector2:
	var start: int = game.cell_at(game.player).y - 8 if biome(game.player) in ["cavern","underworld"] else game.world.surface_at(x) - 12
	for y in range(maxi(3,start),mini(Data.HEIGHT - 3,start + 28)):
		var p := Vector2((x + 0.5) * Data.TILE,y * Data.TILE - 0.01)
		if game.body_free(p,10,32) and (flying or game.world.solid(Vector2i(x,y))):
			return p
	return Vector2.INF

func natural_spawn() -> void:
	if game.enemies.size() >= (22 if blood_moon or not event.is_empty() else 12):
		return
	var pool: Array = {"forest":["slime","ugs","splitter"],"desert":["ugs","charger","net"],"snow":["slime","ranged","p4"],"jungle":["wolf","gc","leak","ropehead"],"corruption":["script","p4","splitter","charger"],"cavern":["ddc","ranged","shader","script"],"underworld":["live","nanite","lumen","shader"],"ocean":["slime","net","lumen"]}[biome(game.player)].duplicate()
	if game.is_night():
		pool.append_array(["script","dasher","splitter"])
	if hardmode():
		pool.append_array(["lumen","live","nanite"])
	var kind: String = pool[game.rng.randi_range(0,pool.size() - 1)]
	var flying: bool = Catalog.ENEMIES[kind].ai in ["fly","fly_shoot","ring"]
	var side: int = -1 if game.rng.randf() < 0.5 else 1
	var x: int = clampi(game.cell_at(game.player).x + side * game.rng.randi_range(21,29),3,Data.WIDTH - 4)
	var p: Vector2 = find_spawn(x,flying)
	if p.is_finite():
		spawn(kind,p)

func hydrate(enemy: Dictionary) -> void:
	if enemy.has("spec"):
		return
	serial += 1
	var defaults: Dictionary = {"id":serial,"kind":"slime","spec":Catalog.ENEMIES.slime,"boss_index":-1,"age":0.0,"timer":1.0,"windup":0.0,"charge":0.0,"aim":Vector2.LEFT,"facing":-1.0,"burn":0.0,"burn_tick":0.0,"slow":0.0,"attack":0}
	for key in defaults:
		if not enemy.has(key):
			enemy[key] = defaults[key]

func damage_enemy(enemy: Dictionary, damage: float, source: Vector2, piercing: bool = false) -> void:
	if not game.enemies.has(enemy) or enemy.get("dead",false):
		return
	hydrate(enemy)
	if enemy.kind == "p4" and not piercing and fposmod(enemy.age,3.2) < 1.8 and (source.x - enemy.p.x) * enemy.facing > 0:
		damage *= 0.2
		game.float_text("护盾",enemy.p - Vector2(0,40),Color("b4dae9"))
	enemy.hp -= damage
	enemy.flash = 0.15
	var side: float = signf(enemy.p.x - source.x)
	enemy.v = Vector2(side * (85 if enemy.boss_index >= 0 else 210),-150)
	game.burst(enemy.p - Vector2(0,15),Color("c0e0bf"),5)
	game.float_text(str(roundi(damage)),enemy.p - Vector2(0,35),Color("f0dbad"))
	if enemy.hp <= 0:
		enemy_died(enemy)

func enemy_died(enemy: Dictionary) -> void:
	if enemy.get("dead",false):
		return
	enemy.dead = true
	game.enemies.erase(enemy)
	bestiary[enemy.kind] = int(bestiary.get(enemy.kind,0)) + 1
	game.stats.kills = int(game.stats.get("kills",0)) + 1
	game.add_item("coin",game.rng.randi_range(3,7) if enemy.boss_index < 0 else 80 + enemy.boss_index * 35)
	game.pad.pulse("victory" if enemy.boss_index >= 0 else "kill")
	if enemy.boss_index >= 0:
		var spec: Dictionary = Catalog.BOSSES[enemy.boss_index]
		var first_victory: bool = not bosses.get(spec.id,false)
		bosses[spec.id] = true
		game.add_item(spec.drop,spec.amount)
		game.add_item("life_crystal",1)
		game.add_item("potion",3)
		game.notify("击败 %s！获得 %s ×%d" % [spec.name,Data.ITEMS[spec.drop].name,spec.amount])
		if spec.id == "compiler_wall" and first_victory:
			unlock_hardmode()
		if spec.id == "moon_planner":
			game.set_state("sandbox_victory")
		game.save_world()
	else:
		game.add_item("gel",2)
		if enemy.kind != "slime" and enemy.kind != "minislime":
			game.add_item("fang",1)
		if biome(enemy.p) in ["corruption","underworld"] or enemy.kind == "script":
			game.add_item("shadow",2)
		if hardmode():
			game.add_item("soul",1)
		if enemy.spec.has("split"):
			for i in range(3):
				var child: Dictionary = spawn(enemy.spec.split,enemy.p + Vector2((i - 1) * 22,-5))
				if not child.is_empty():
					child.v = Vector2((i - 1) * 100,-220)
		if not event.is_empty() and enemy.get("event_member",false):
			event_kills += 1
			if event_left == 0 and event_kills >= 24:
				event = ""
				game.add_item("coin",80)
				game.add_item("boots",1)
				game.notify("故障入侵结束！额外获得 80 旧银币和疾行靴。")
	game.audio.sfx("kill_boss" if enemy.boss_index >= 0 else "kill")

func unlock_hardmode() -> void:
	for y in range(92,Data.HEIGHT - 3):
		for x in range(3,Data.WIDTH - 3):
			var c := Vector2i(x,y)
			if not structures.wall(c) and game.world.tile(c) in [Data.Block.STONE,Data.Block.IRON,Data.Block.CORRUPT_STONE] and posmod(x * 173 + y * 661 + game.world.seed_value,37) < 5:
				game.world.set_tile(c,Data.Block.MYTHRIL)
	game.notify("构建之墙倒下了。困难世界开启：秘银矿脉生成，新的敌人开始游荡。")

func update_enemies(delta: float) -> void:
	for enemy in game.enemies.duplicate():
		if game.state != "playing":
			return
		hydrate(enemy)
		enemy.previous = enemy.p
		enemy.age += delta
		enemy.flash = maxf(0,enemy.flash - delta)
		enemy.slow = maxf(0,enemy.slow - delta)
		if enemy.burn > 0:
			enemy.burn -= delta
			enemy.burn_tick -= delta
			if enemy.burn_tick <= 0:
				enemy.burn_tick = 1
				damage_enemy(enemy,5,enemy.p,true)
				if enemy.get("dead",false):
					continue
		if enemy.p.distance_to(game.player) > (2300 if enemy.boss_index >= 0 else 1500):
			if enemy.get("event_member",false) and not event.is_empty():
				event_left += 1
			game.enemies.erase(enemy)
			continue
		var direction: float = signf(game.player.x - enemy.p.x)
		if direction != 0:
			enemy.facing = direction
		if enemy.boss_index >= 0:
			update_boss(enemy,delta)
		else:
			update_mob(enemy,delta)
		var radius: float = 34 if enemy.boss_index >= 0 else 19
		if (enemy.p - Vector2(0,radius)).distance_to(game.player - Vector2(0,18)) < radius + 12:
			game.hurt(float(enemy.spec.damage) * (1.3 if hardmode() and enemy.boss_index < 0 else 1),enemy.p)

func update_mob(enemy: Dictionary, delta: float) -> void:
	var ai: String = enemy.spec.ai
	var diff: Vector2 = game.player - Vector2(0,15) - enemy.p
	var speed: float = float(enemy.spec.speed) * (0.5 if enemy.slow > 0 else 1.0)
	var flying: bool = ai in ["fly","fly_shoot","ring"]
	var ground: bool = not game.body_free(enemy.p + Vector2(0,1),10,28)
	enemy.timer -= delta
	if enemy.windup > 0:
		enemy.windup -= delta
		if enemy.windup <= 0:
			mob_attack(enemy)
	elif enemy.timer <= 0 and diff.length() < 620:
		enemy.aim = diff.normalized()
		enemy.windup = 0.55
		enemy.timer = 2.1 if ai not in ["charge","wolf"] else 1.5
	if enemy.charge > 0:
		enemy.charge -= delta
		enemy.v.x = enemy.aim.x * speed * 3.5
	elif flying:
		var target: Vector2 = game.player + Vector2(sin(enemy.age * 1.8) * 100,-80)
		enemy.v = enemy.v.lerp((target - enemy.p).normalized() * speed,1 - exp(-delta * 3))
	else:
		enemy.v.x = enemy.facing * speed * (0.0 if enemy.windup > 0 else 1.0)
		if ai in ["caster","hazard","shield"] and absf(diff.x) < 180:
			enemy.v.x = 0
		enemy.jump -= delta
		if ground and (enemy.jump <= 0 or not game.body_free(enemy.p + Vector2(enemy.facing * 13,0),10,28)):
			enemy.v.y = -360 if ai in ["hop","split","wolf"] else -410
			enemy.jump = 0.9
		enemy.v.y = minf(800,enemy.v.y + 1150 * delta)
	var moved: Dictionary = game.move_body(enemy.p,enemy.v * delta,10,28)
	enemy.p = moved.p
	if moved.hit.x != 0:
		enemy.v.x = 0
	if moved.hit.y != 0:
		enemy.v.y = 0

func mob_attack(enemy: Dictionary) -> void:
	var ai: String = enemy.spec.ai
	if ai in ["charge","wolf"]:
		enemy.charge = 0.32
		enemy.v.y = -210
	elif ai == "hazard":
		var ground: Vector2 = game.player
		hazards.append({"p":ground,"delay":0.8,"life":0.45,"damage":float(enemy.spec.damage),"radius":48.0})
	elif ai == "ring":
		for i in range(8):
			shoot(enemy.p - Vector2(0,18),Vector2.from_angle(TAU * i / 8 + enemy.age) * 175,enemy.spec.damage,false)
	elif ai in ["caster","fly_shoot"] and game.line_clear(game.cell_at(enemy.p - Vector2(0,15))):
		for angle in [-0.18,0.0,0.18]:
			shoot(enemy.p - Vector2(0,18),enemy.aim.rotated(angle) * 240,enemy.spec.damage,false)

func update_boss(enemy: Dictionary, delta: float) -> void:
	var phase: int = 1 if enemy.hp < enemy.max_hp * 0.5 else 0
	var pattern: String = enemy.spec.pattern
	var target: Vector2 = game.player + Vector2(sin(enemy.age * 0.7) * 210,-110)
	if enemy.charge > 0:
		enemy.charge -= delta
		enemy.v = enemy.aim * (430 + phase * 90)
	elif pattern in ["eye","worm","machine","plant","final"]:
		enemy.v = enemy.v.lerp((target - enemy.p).normalized() * (135 + phase * 35),1 - exp(-delta * 2))
	else:
		enemy.v.x = enemy.facing * (70 + phase * 40)
		enemy.v.y = minf(800,enemy.v.y + 1150 * delta)
		if not game.body_free(enemy.p + Vector2(0,1),22,60) and enemy.timer < 1.2:
			enemy.v.y = -440 if pattern != "sumo" else -560
	if pattern in ["eye","worm","machine","plant","final"]:
		enemy.p += enemy.v * delta
	else:
		var result: Dictionary = game.move_body(enemy.p,enemy.v * delta,22,60)
		enemy.p = result.p
		if result.hit.y != 0:
			enemy.v.y = 0
		if result.hit.x != 0:
			enemy.v.y = -450
	enemy.p.x = clampf(enemy.p.x,48,Data.WIDTH * Data.TILE - 48)
	enemy.p.y = clampf(enemy.p.y,70,(Data.HEIGHT - 3) * Data.TILE)
	enemy.timer -= delta
	if enemy.windup > 0:
		enemy.windup -= delta
		if enemy.windup <= 0:
			boss_attack(enemy,phase)
	elif enemy.timer <= 0:
		enemy.windup = 0.7
		enemy.aim = (game.player - Vector2(0,20) - enemy.p).normalized()
		enemy.timer = 2.1 - phase * 0.5
		if pattern in ["eye", "worm", "sumo", "wall", "final"]:
			boss_rumble("windup", enemy.p)

func boss_attack(enemy: Dictionary, phase: int) -> void:
	enemy.attack += 1
	var pattern: String = enemy.spec.pattern
	var count: int = 8 + phase * 4
	match pattern:
		"eye", "worm", "sumo": boss_rumble("charge", enemy.p)
		"slime", "plant": boss_rumble("summon", enemy.p)
		"wall", "machine", "final": boss_rumble("volley", enemy.p)
	if pattern in ["eye","worm","sumo"]:
		enemy.charge = 0.5
		for i in range(5 + phase * 2):
			shoot(enemy.p - Vector2(0,25),enemy.aim.rotated((i - 2 - phase) * 0.22) * 230,enemy.spec.damage,false)
	if pattern in ["slime","plant","machine","final"]:
		for i in range(count):
			var angle: float = TAU * i / count + enemy.attack * 0.25
			shoot(enemy.p - Vector2(0,25),Vector2.from_angle(angle) * (160 + phase * 45),enemy.spec.damage,false)
	if pattern in ["wall","machine","final"]:
		for row in range(2 + phase):
			for i in range(5):
				shoot(enemy.p - Vector2(0,30 + row * 16),enemy.aim.rotated((i - 2) * 0.16) * (240 + row * 55),enemy.spec.damage,false)
	if pattern in ["slime","plant"] and game.enemies.size() < 18:
		for side in [-1,1]:
			spawn("minislime" if pattern == "slime" else "leak",enemy.p + Vector2(side * 55,0))
	if pattern in ["sumo","wall","final"]:
		for offset in [-70,0,70]:
			hazards.append({"p":game.player + Vector2(offset,0),"delay":0.8,"life":0.45,"damage":float(enemy.spec.damage),"radius":45.0,"boss":true})

func boss_rumble(kind: String, p: Vector2) -> void:
	var distance: float = game.player.distance_to(p)
	if distance < 800.0:
		game.pad.pulse(kind, remap(maxf(85.0, distance), 85.0, 800.0, 1.0, 0.35))

func shoot(p: Vector2, velocity: Vector2, damage: float, friendly: bool, options: Dictionary = {}) -> void:
	if shots.size() >= 220:
		return
	shots.append({"p":p,"previous":p,"v":velocity,"damage":damage,"friendly":friendly,"life":4.0,"gravity":float(options.get("gravity",0)),"pierce":int(options.get("pierce",0)),"burn":float(options.get("burn",0)),"slow":float(options.get("slow",0)),"hits":{},"color":Color("b8e6c5") if friendly else Color("f0a59b")})

func fire_weapon(id: String) -> bool:
	if game.state != "playing" or game.sword_cooldown > 0 or not Catalog.WEAPONS.has(id) or game.count_item(id) <= 0:
		return false
	var spec: Dictionary = Catalog.WEAPONS[id]
	if spec.type == "melee":
		var direction: float = game.mouse_world().x - game.player.x
		if absf(direction) > 1:
			game.facing = signf(direction)
		game.attack()
		return true
	if spec.has("ammo") and game.count_item(spec.ammo) <= 0:
		if game.message_time < 2:
			game.notify("需要弹药：" + Data.ITEMS[spec.ammo].name)
		return false
	if mana < spec.get("mana",0):
		if game.message_time < 2:
			game.notify("魔力不足，稍等恢复或使用魔力药水。")
		return false
	if spec.has("ammo"):
		game.add_item(spec.ammo,-1)
	mana -= spec.get("mana",0)
	mana_delay = 1.2
	game.sword_cooldown = spec.cooldown
	var origin: Vector2 = game.player - Vector2(0,23)
	var aim: Vector2 = (game.mouse_world() - origin).normalized()
	if aim.length_squared() < 0.1:
		aim = Vector2(game.facing,0)
	game.facing = signf(aim.x) if aim.x != 0 else game.facing
	if spec.type == "summon":
		companion = true
		companion_p = game.player + Vector2(-45,-35)
		game.notify("海德骑士：毅川救我！这次我来帮你。")
	else:
		var count: int = spec.get("count",1)
		for i in range(count):
			shoot(origin,aim.rotated((i - (count - 1) * 0.5) * 0.11) * spec.speed,spec.damage,true,spec)
	game.audio.sfx("slash" if spec.type == "ranged" else "skill")
	return true

func update_shots(delta: float) -> void:
	for shot in shots.duplicate():
		if game.state != "playing":
			return
		shot.previous = shot.p
		shot.life -= delta
		shot.v.y += shot.gravity * delta
		var steps: int = maxi(1,ceili(shot.v.length() * delta / 5.0))
		var removed: bool = false
		for step in range(steps):
			shot.p += shot.v * delta / steps
			if game.world.solid(game.cell_at(shot.p)) and game.world.tile(game.cell_at(shot.p)) != Data.Block.PLATFORM:
				removed = true
				break
			if shot.friendly:
				for enemy in game.enemies.duplicate():
					hydrate(enemy)
					if shot.hits.has(enemy.id):
						continue
					var height: float = 80 if enemy.boss_index >= 0 else 34
					if Rect2(enemy.p - Vector2(height * 0.4,height),Vector2(height * 0.8,height)).grow(3).has_point(shot.p):
						shot.hits[enemy.id] = true
						enemy.burn = maxf(enemy.burn,shot.burn)
						enemy.slow = maxf(enemy.slow,shot.slow)
						damage_enemy(enemy,shot.damage,shot.p - shot.v.normalized() * 10)
						if game.state != "playing":
							return
						shot.pierce -= 1
						if shot.pierce < 0:
							removed = true
							break
			else:
				if Rect2(game.player - Vector2(9,36),Vector2(18,36)).grow(3).has_point(shot.p):
					game.hurt(shot.damage,shot.p)
					removed = true
			if removed:
				break
		if removed or shot.life <= 0:
			shots.erase(shot)
	for hazard in hazards.duplicate():
		var activates: bool = hazard.delay > 0.0 and hazard.delay <= delta
		hazard.delay -= delta
		if hazard.delay <= 0:
			if activates and hazard.get("boss", false) and game.player.distance_to(hazard.p) < 240.0:
				boss_rumble("slam", hazard.p)
			hazard.life -= delta
			if absf(game.player.x - hazard.p.x) < hazard.radius and absf(game.player.y - hazard.p.y) < 70:
				game.hurt(hazard.damage,hazard.p)
			if hazard.life <= 0:
				hazards.erase(hazard)

func use_item(id: String) -> bool:
	if game.state != "playing" or game.count_item(id) <= 0:
		return false
	var spec: Dictionary = Data.ITEMS.get(id,{})
	if spec.has("weapon"):
		return fire_weapon(id)
	if spec.has("summon"):
		return summon_boss(spec.summon,id)
	var use: String = spec.get("use","")
	match use:
		"fishing":
			return fish_action()
		"life":
			if life_upgrades >= 15:
				game.notify("生命水晶已达到 400 基础生命，后续使用生命果。")
				return false
			life_upgrades += 1
			game.health = minf(game.max_health(),game.health + 20)
		"fruit":
			if life_upgrades < 15 or stage() < 6 or fruit_upgrades >= 20:
				game.notify("需用满生命水晶并击败荆棘母体，生命果上限 20 次。")
				return false
			fruit_upgrades += 1
			game.health = minf(game.max_health(),game.health + 5)
		"mana":
			if mana_upgrades >= 7:
				game.notify("基础魔力已达到 200。")
				return false
			mana_upgrades += 1
			mana = max_mana()
		"mana_potion":
			if mana >= max_mana():
				return false
			mana = minf(max_mana(),mana + 60)
		"greater_heal", "food", "meal":
			if (game.health >= game.max_health() and use != "meal") or (use == "greater_heal" and heal_cooldown > 0) or (use != "greater_heal" and food_cooldown > 0):
				return false
			game.health = minf(game.max_health(),game.health + (150 if use == "greater_heal" else (50 if use == "meal" else 20)))
			if use == "greater_heal":
				heal_cooldown = 45
			else:
				food_cooldown = 5
				if use == "meal":
					food_buff = 120
		"invasion":
			if not event.is_empty() or current_boss() != {}:
				return false
			event = "故障入侵"
			event_left = 24
			event_kills = 0
			event_clock = 0
		_:
			return false
	game.add_item(id,-1)
	game.audio.sfx("repair")
	return true

func fish_action() -> bool:
	if not fishing.is_empty():
		if fishing.time >= fishing.bite and fishing.time <= fishing.bite + 1.4:
			game.add_item("fish",game.rng.randi_range(1,3))
			if game.rng.randf() < 0.15:
				game.add_item("coin",12)
			game.notify("钓到鲜鱼！可以去篝火旁烤着吃。")
		else:
			game.notify("还没咬钩，再耐心等一会儿。")
		fishing.clear()
		return true
	var c: Vector2i = game.cell_at(game.mouse_world())
	if not game.world.valid(c) or structures.fluid(c).x != 1 or structures.fluid(c).y < 4 or game.cell_center(c).distance_to(game.player) > 330 or not game.line_clear(c):
		game.notify("向附近的水面抛竿。")
		return false
	fishing = {"cell":c,"time":0.0,"bite":game.rng.randf_range(2.4,5.0)}
	return true

func current_boss() -> Dictionary:
	for enemy in game.enemies:
		if enemy.get("boss_index",-1) >= 0:
			return enemy
	return {}

func summon_reason(index: int) -> String:
	if index < 0 or index >= Catalog.BOSSES.size():
		return "无效召唤物"
	var boss: Dictionary = Catalog.BOSSES[index]
	if not current_boss().is_empty():
		return "已有 Boss 在场"
	if boss.requires >= 0 and not bosses.get(Catalog.BOSSES[boss.requires].id,false):
		return "先击败" + Catalog.BOSSES[boss.requires].name
	if boss.biome == "night" and not game.is_night():
		return "只能在夜间召唤"
	if boss.biome not in ["any","night"] and biome(game.player) != boss.biome:
		return "需要前往" + {"corruption":"版本侵蚀区","underworld":"熔火地狱","jungle":"孢子丛林"}[boss.biome]
	return ""

func summon_boss(index: int, item: String) -> bool:
	var reason: String = summon_reason(index)
	if not reason.is_empty():
		game.notify(reason)
		return false
	if game.count_item(item) <= 0:
		return false
	var boss: Dictionary = Catalog.BOSSES[index]
	var p: Vector2 = game.player + Vector2(330,-80)
	if boss.pattern in ["slime","wall","sumo"]:
		var possible: Vector2 = find_spawn(clampi(game.cell_at(game.player).x + 13,3,Data.WIDTH - 4),false)
		if possible.is_finite():
			p = possible
	game.add_item(item,-1)
	spawn(boss.kind,p,index)
	game.notify("%s 已苏醒！" % boss.name)
	game.audio.sfx("start")
	return true

func hook_action() -> void:
	if not has_accessory("grapple"):
		game.notify("先装备矿工钩爪。")
		return
	if hook.is_finite():
		hook = Vector2.INF
		return
	var start: Vector2 = game.player - Vector2(0,20)
	var direction: Vector2 = (game.mouse_world() - start).normalized()
	for distance in range(12,337,4):
		var p: Vector2 = start + direction * distance
		if game.world.solid(game.cell_at(p)):
			hook = p
			return
	game.notify("钩爪范围内没有可附着的地形。")

func adjust_motion(delta: float) -> void:
	var c: Vector2i = game.cell_at(game.player - Vector2(0,12))
	if game.grounded:
		air_jumps = 0
		flight = 2.2
	if not game.grounded and game.coyote <= 0 and game.jump_buffer > 0:
		if has_accessory("double_jump") and air_jumps == 0:
			game.velocity.y = -490
			game.jump_buffer = 0
			air_jumps += 1
			hook = Vector2.INF
	if has_accessory("wings") and not game.grounded and game.jump_held() and flight > 0:
		flight -= delta
		game.velocity.y = move_toward(game.velocity.y,-260,1800 * delta)
	if game.world.tile(c) == Data.Block.ROPE:
		var climb_up: float = maxf(float(game.jump_held()), Input.get_action_strength("sandbox_climb_up"))
		game.velocity.y = (Input.get_action_strength("sandbox_down") - climb_up) * 135
	if hook.is_finite():
		if game.jump_pressed() or game.player.distance_to(hook) < 26:
			hook = Vector2.INF
		else:
			game.velocity = (hook - game.player + Vector2(0,20)).normalized() * 610
	if structures.fluid(c).y > 4:
		game.velocity *= Vector2(0.97,0.92)
		if game.jump_held():
			game.velocity.y = -175

func tick(delta: float) -> void:
	structures.tick(delta)
	if game.state != "playing":
		return
	mana_delay = maxf(0,mana_delay - delta)
	heal_cooldown = maxf(0,heal_cooldown - delta)
	food_cooldown = maxf(0,food_cooldown - delta)
	if food_buff > 0:
		food_buff = maxf(0,food_buff - delta)
		game.health = minf(game.max_health(),game.health + delta * 1.5)
	if not fishing.is_empty():
		fishing.time += delta
		if structures.fluid(fishing.cell).x != 1 or game.cell_center(fishing.cell).distance_to(game.player) > 380 or fishing.time > fishing.bite + 1.4:
			fishing.clear()
			game.notify("鱼跑掉了。")
	if mana_delay <= 0:
		mana = minf(max_mana(),mana + delta * 12)
	update_shots(delta)
	if game.state != "playing":
		return
	if companion:
		companion_cooldown = maxf(0,companion_cooldown - delta)
		var closest: Dictionary = {}
		var gap: float = 330
		for enemy in game.enemies:
			var distance: float = enemy.p.distance_to(game.player)
			if distance < gap:
				gap = distance
				closest = enemy
		var target: Vector2 = game.player + Vector2(-game.facing * 45,-15)
		if not closest.is_empty():
			target = closest.p
		companion_p = companion_p.move_toward(target,delta * 310)
		if not closest.is_empty() and companion_p.distance_to(closest.p) < 55 and companion_cooldown <= 0:
			companion_cooldown = 0.65
			damage_enemy(closest,26 + stage() * 3,companion_p)
	if game.is_night() and game.day_number() % 4 == 0 and last_blood_day != game.day_number():
		last_blood_day = game.day_number()
		game.notify("血色加班夜：怪物刷新加快，守住房屋！")
	blood_moon = game.is_night() and game.day_number() % 4 == 0
	if not event.is_empty() and event_left > 0:
		event_clock -= delta
		if event_clock <= 0 and game.enemies.size() < 18:
			event_clock = 0.8
			var before: int = game.enemies.size()
			natural_spawn()
			if game.enemies.size() > before:
				game.enemies[-1].event_member = true
				event_left -= 1

func town_service() -> void:
	match structures.selected_npc:
		"nurse":
			if game.health >= game.max_health():
				game.notify("若宇：我这显示是满的。")
			elif game.count_item("coin") >= 10:
				game.add_item("coin",-10)
				game.health = game.max_health()
				game.notify("若宇：检查完毕，满血回去吧。")
			else:
				game.notify("治疗需要 10 旧银币。")
		"heide":
			companion = not companion
			companion_p = game.player
			game.notify("海德骑士加入队伍。" if companion else "海德骑士留在住宅休息。")
		"miner":
			if game.count_item("coin") >= 12:
				game.add_item("coin",-12)
				game.add_item("coal",10)
				game.add_item("arrow",30)
				game.notify("嘉豪：矿工补给拿好，直接开干。")
			else:
				game.notify("矿工补给需要 12 旧银币。")
		_:
			game.notify("菈雅：%s" % objective().text.replace("\n"," "))
	game.save_world()

func objective() -> Dictionary:
	var current: int = stage()
	if current >= Catalog.BOSSES.size():
		return {"title":"公主已回家 · 自由建造","text":"完成 8 场成长战役。\n继续种植、建城与探索。"}
	if game.pick_tier < 2:
		return {"title":"起步 / 采集与冶炼","text":"建工作台、熔炉、铁砧。\n铜镐 → 铁镐，准备武器与护甲。"}
	var next: Dictionary = Catalog.BOSSES[current]
	var hints: Array[String] = ["金锭 + 凝胶制作王冠。\n探索地下，使用生命水晶。","祭坛制作风暴之眼。\n在夜间迎战风暴哨卫。","升级金镐，前往侵蚀区。\n祭坛制作并使用深渊诱饵。","采掘熔火矿，制作装备。\n在地狱使用构建合同。","困难世界出现秘银矿。\n制作并使用机械钥匙。","制作荆棘花苞。\n前往丛林迎战荆棘母体。","准备横纲战旗。\n留出横向移动的战斗场地。","制作星辉装备与最终需求单。\n迎接终战，救回公主。"]
	return {"title":"%02d / %s" % [current + 1,next.name],"text":hints[current]}

func save_data() -> Dictionary:
	var remaining: int = maxi(0, 24 - event_kills) if not event.is_empty() else 0
	return {"version":1,"bosses":bosses,"bestiary":bestiary,"armor":armor,"accessories":accessories,"life":life_upgrades,"fruit":fruit_upgrades,"mana":mana_upgrades,"companion":companion,"last_blood_day":last_blood_day,"event":event,"event_left":remaining,"event_kills":event_kills,"heal_cooldown":heal_cooldown,"food_cooldown":food_cooldown,"food_buff":food_buff,"structures":structures.save_data()}

func valid_save(value: Variant) -> bool:
	if not value is Dictionary or value.get("version",0) != 1:
		return false
	for field in ["life","fruit","mana","last_blood_day","event_left","event_kills"]:
		if not value.get(field) is int or value[field] < 0:
			return false
	if value.life > 15 or value.fruit > 20 or value.mana > 7 or value.event_left > 24 or value.event_kills > 24 or (value.fruit > 0 and value.life < 15):
		return false
	if typeof(value.get("heal_cooldown",0.0)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.get("heal_cooldown",0.0))) or value.get("heal_cooldown",0.0) < 0 or value.get("heal_cooldown",0.0) > 45:
		return false
	if value.get("event") not in ["","故障入侵"]:
		return false
	for field in ["food_cooldown","food_buff"]:
		if typeof(value.get(field,0.0)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.get(field,0.0))) or value.get(field,0.0) < 0 or value.get(field,0.0) > 120:
			return false
	if not value.get("armor") is String or (not value.armor.is_empty() and not Data.ITEMS.get(value.armor,{}).has("armor")):
		return false
	if not value.get("accessories") is Array or value.accessories.size() > 5:
		return false
	var seen: Dictionary = {}
	for id in value.accessories:
		if not id is String or not Data.ITEMS.get(id,{}).has("accessory") or seen.has(id):
			return false
		seen[id] = true
	if not value.get("bosses") is Dictionary or not value.get("bestiary") is Dictionary or not value.get("companion") is bool or not value.get("event") is String:
		return false
	var allowed: Dictionary = {}
	for boss in Catalog.BOSSES:
		allowed[boss.id] = true
	for id in value.bosses:
		if not allowed.has(id) or not value.bosses[id] is bool:
			return false
	for i in range(1,Catalog.BOSSES.size()):
		if value.bosses.get(Catalog.BOSSES[i].id,false) and not value.bosses.get(Catalog.BOSSES[i - 1].id,false):
			return false
	for id in value.bestiary:
		if not id is String or not value.bestiary[id] is int or value.bestiary[id] < 0:
			return false
	return structures.valid_save(value.get("structures"))

func load_data(value: Dictionary) -> void:
	reset()
	bosses = value.bosses
	bestiary = value.bestiary
	armor = value.armor
	accessories.assign(value.accessories)
	life_upgrades = value.life
	fruit_upgrades = value.fruit
	mana_upgrades = value.mana
	companion = value.companion
	last_blood_day = value.last_blood_day
	event = value.event
	event_left = value.event_left
	event_kills = value.event_kills
	heal_cooldown = value.get("heal_cooldown",0.0)
	food_cooldown = value.get("food_cooldown",0.0)
	food_buff = value.get("food_buff",0.0)
	mana = max_mana()
	structures.load_data(value.structures)
