extends SceneTree
const Data = preload("res://scripts/sandbox_data.gd")
const Catalog = preload("res://scripts/sandbox_catalog.gd")
class Fixture:
	extends "res://scripts/sandbox_run.gd"
	var reject_saves: bool = false
	var force_spawn_fallback: bool = false
	func save_world() -> bool:
		return failed_save("模拟磁盘故障") if reject_saves else super.save_world()
	func nearby_surface(anchor: Vector2, radius: int = 32) -> Vector2:
		return Vector2.INF if force_spawn_fallback else super.nearby_surface(anchor,radius)

var game: Node
var checks: int = 0
var failures: int = 0
const PATH = "res://.tools/sandbox-adventure-test.save"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func arena(x: int = 280, y: int = 58) -> void:
	game.enemies.clear()
	game.adventure.reset_transients()
	for cy in range(y - 14, y + 5):
		for cx in range(x - 22, x + 23):
			game.world.set_tile(Vector2i(cx, cy), Data.Block.STONE if cy >= y else Data.Block.AIR)
	game.player = Vector2((x + 0.5) * 24, y * 24 - 0.01)
	game.previous_player = game.player
	game.velocity = Vector2.ZERO
	game.grounded = true
	game.health = game.max_health()
	game.hurt_time = 0
	game.state = "playing"
	game.adventure.structures.active.clear()
	game.adventure.structures.npcs.clear()

func recipe(id: String) -> int:
	for i in range(Data.RECIPES.size()):
		if Data.RECIPES[i].id == id:
			return i
	return -1

func craft_with_materials(id: String) -> void:
	var at: int = recipe(id)
	check(at >= 0, "Recipe exists: " + id)
	if at < 0:
		return
	var spec: Dictionary = Data.RECIPES[at]
	for item in spec.cost:
		if item in ["royal_gel","feather","scale","core_fragment","jungle_heart","sumo_token"]:
			check(game.count_item(item) >= spec.cost[item], "Boss material actually dropped: " + item)
		game.inventory[item] = maxi(game.count_item(item), spec.cost[item])
	var c: Vector2i = game.cell_at(game.player) + Vector2i(-2, -1)
	if spec.station > 0:
		game.world.set_tile(c, spec.station)
	var before: Dictionary = game.inventory.duplicate()
	check(game.craft(at), "Can craft in correct progression: " + id)
	for item in spec.cost:
		check(game.count_item(item) == before[item] - spec.cost[item], "Craft charges material once: " + id + "/" + item)

func test_content_and_generation() -> void:
	check(Catalog.ENEMIES.size() == 19 and Catalog.BOSSES.size() == 8, "19 monster types and 8 sequential bosses")
	for seed in [1,19,20261113]:
		game.start_world(seed)
		var counts: Dictionary = {}
		for tile in game.world.tiles:
			counts[tile] = int(counts.get(tile, 0)) + 1
		for id in [Data.Block.GOLD,Data.Block.MOLTEN,Data.Block.STARSHARD,Data.Block.LIFE_CRYSTAL,Data.Block.CHEST,Data.Block.OBSIDIAN]:
			check(counts.get(id,0) > 0, "Generated resource/structure exists: %d seed %d" % [id,seed])
		check(counts.get(Data.Block.LIFE_CRYSTAL,0) >= 7, "Crystals plus boss drops can reach 400 health")
		check(not counts.has(Data.Block.MYTHRIL), "Hardmode ore is gated before wall boss")
		check(game.adventure.structures.chests.size() == 3, "Three exploration cabins have persistent loot")
		check(game.adventure.structures.liquid_amount.count(8) > 300, "World has real water and lava volumes")
		check(game.body_free(game.world.spawn), "Expanded terrain preserves safe spawn")
	for kind in Catalog.ENEMIES:
		var spec: Dictionary = Catalog.ENEMIES[kind]
		check(game.adventure.atlases[spec.art].frames.size() > spec.frame, "Reused monster art has valid frame: " + kind)
	for id in Catalog.WEAPONS:
		check(game.adventure.icons.has(id), "Reused weapon art exists: " + id)

func test_combat() -> void:
	game.start_world(101)
	arena()
	var a = game.adventure
	for kind in Catalog.ENEMIES:
		game.enemies.clear()
		a.reset_transients()
		var enemy: Dictionary = a.spawn(kind,game.player + Vector2(200,0))
		var start: Vector2 = enemy.p
		enemy.timer = 0.01
		for frame in range(90):
			a.update_enemies(1.0 / 60)
		check(enemy.p.is_finite() and enemy.p.distance_to(start) > 1, "Monster moves with terrain: " + kind)
		if enemy.spec.ai in ["caster","fly_shoot","ring"]:
			check(a.shots.size() > 0, "Monster fires after windup: " + kind)
		if enemy.spec.ai == "hazard":
			check(a.hazards.size() > 0 and a.hazards[0].delay > 0, "Ground attack has visible warning")
	game.enemies.clear()
	var splitter: Dictionary = a.spawn("splitter",game.player + Vector2(180,0))
	a.damage_enemy(splitter,9999,game.player)
	check(game.enemies.size() == 3 and game.enemies.all(func(e): return e.kind == "minislime"), "Splitter creates three non-recursive children")
	game.enemies.clear()
	var shield: Dictionary = a.spawn("p4",game.player + Vector2(160,0))
	shield.facing = -1
	a.damage_enemy(shield,20,shield.p - Vector2(30,0))
	check(is_equal_approx(shield.hp,shield.max_hp - 4), "P4 shield blocks frontal damage")
	a.damage_enemy(shield,20,shield.p + Vector2(30,0))
	check(is_equal_approx(shield.hp,shield.max_hp - 24), "Flanking bypasses shield")
	game.enemies.clear()
	a.reset_transients()
	var target: Dictionary = a.spawn("ddc",game.player + Vector2(110,0))
	a.shoot(game.player - Vector2(0,18),Vector2(800,0),31,true,{"burn":4.0,"slow":3.0})
	a.update_shots(0.2)
	check(target.hp == target.max_hp - 31 and target.burn == 4 and target.slow == 3, "Swept magic hits and applies burn and slow")
	var hp: float = target.hp
	a.update_enemies(0.01)
	check(target.hp == hp - 5, "Burn deals timed damage")
	game.enemies.clear()
	a.reset_transients()
	var first: Dictionary = a.spawn("ddc",game.player + Vector2(80,0))
	var second: Dictionary = a.spawn("ddc",game.player + Vector2(150,0))
	a.shoot(game.player - Vector2(0,18),Vector2(900,0),20,true,{"pierce":1})
	a.update_shots(0.2)
	check(first.hp == first.max_hp - 20 and second.hp == second.max_hp - 20, "Piercing projectile hits distinct targets once")
	game.world.set_tile(game.cell_at(game.player) + Vector2i(2,-1),Data.Block.STONE)
	a.reset_transients()
	hp = second.hp
	a.shoot(game.player - Vector2(0,18),Vector2(3000,0),90,true)
	a.update_shots(0.2)
	check(second.hp == hp and a.shots.is_empty(), "High speed projectile cannot tunnel through a wall")
	arena()
	a.shoot(game.player - Vector2(90,18),Vector2(900,0),18,false)
	a.update_shots(0.15)
	check(game.health == game.max_health() - 18, "Enemy projectile damages player")
	game.hurt_time = 0
	game.inventory.iron_armor = 1
	game.equip_item("iron_armor")
	hp = game.health
	game.hurt(18,game.player + Vector2(100,0))
	check(game.health == hp - 14 and a.defense() == 8, "Equipped armor reduces actual incoming damage")
	game.inventory.bow = 1
	game.inventory.arrow = 0
	game.sword_cooldown = 0
	check(not a.fire_weapon("bow"), "Bow cannot fire without ammunition")
	game.inventory.arrow = 4
	check(a.fire_weapon("bow") and game.count_item("arrow") == 3, "Bow consumes one arrow")
	check(not a.fire_weapon("bow") and game.count_item("arrow") == 3, "Cooldown prevents repeated ammo consumption")
	game.sword_cooldown = 0
	a.mana = 60
	game.inventory.fire_staff = 1
	check(a.fire_weapon("fire_staff") and a.mana == 53, "Magic consumes actual mana")
	game.sword_cooldown = 0
	a.mana = 0
	check(not a.fire_weapon("fire_staff"), "Insufficient mana prevents casting")
	game.inventory.fire_staff = 0
	a.mana = 60
	check(not a.fire_weapon("fire_staff"), "Missing weapon cannot attack from an empty hotbar slot")
	a.mana = 0
	a.mana_delay = 0
	a.tick(1)
	check(a.mana >= 12, "Mana regenerates during play")

func build_house(at: Vector2i) -> void:
	var s = game.adventure.structures
	for dx in range(-5,6):
		for dy in range(-6,1):
			var c: Vector2i = at + Vector2i(dx,dy)
			game.world.set_tile(c,Data.Block.PLANK if absi(dx) == 5 or dy in [-6,0] else Data.Block.AIR)
			s.walls[s.index(c)] = 1
	s.install_door(at + Vector2i(-5,-1))
	game.world.set_tile(at + Vector2i(-2,-1),Data.Block.BENCH)
	game.world.set_tile(at + Vector2i(1,-1),Data.Block.CHAIR)
	game.world.set_tile(at + Vector2i(3,-2),Data.Block.TORCH)

func test_housing_and_storage() -> void:
	game.start_world(101)
	arena()
	var s = game.adventure.structures
	var at := Vector2i(280,58)
	build_house(at)
	check(s.register_house(at + Vector2i(0,-2)).valid, "Closed backed room with furnishings is a valid house")
	s.update_town()
	check(s.npcs.size() == 1 and s.npcs[0].housed, "Guide occupies validated housing")
	s.walls[s.index(at + Vector2i(0,-2))] = 0
	check(not s.inspect_house(at + Vector2i(0,-2)).valid, "Missing background wall invalidates home")
	s.walls[s.index(at + Vector2i(0,-2))] = 1
	game.world.set_tile(at + Vector2i(1,-1),Data.Block.AIR)
	check(not s.inspect_house(at + Vector2i(0,-2)).valid, "Missing chair invalidates home")
	game.world.set_tile(at + Vector2i(1,-1),Data.Block.CHAIR)
	var door: Vector2i = at + Vector2i(-5,-1)
	game.player = Vector2(at + Vector2i(-3,0)) * 24 + Vector2(12,-0.01)
	check(s.interact() and game.world.tile(door) == Data.Block.DOOR_OPEN and game.world.tile(door + Vector2i.UP) == Data.Block.DOOR_OPEN, "E opens both halves of door")
	check(s.interact() and game.world.tile(door) == Data.Block.DOOR, "E closes door")
	var before: int = game.count_item("door")
	check(game.mine(door + Vector2i.UP), "Upper door tile can be mined")
	check(game.world.tile(door) == Data.Block.AIR and game.count_item("door") == before + 1, "Mining two-cell door refunds one item")
	s.install_door(door)
	var chest: Vector2i = at + Vector2i(2,-1)
	game.world.set_tile(chest,Data.Block.CHEST)
	s.chests[chest] = {"wood":7,"coin":12}
	s.selected_chest = chest
	game.state = "chest"
	game.inventory.wood = 18
	game.inventory.gold_bar = 9
	var coins: int = game.count_item("coin")
	s.transfer_chest(true)
	check(game.count_item("wood") == 0 and s.chests[chest].wood == 25 and s.chests[chest].gold_bar == 9, "Chest deposits placeable raw materials as well as ingots")
	check(game.count_item("coin") == coins and game.count_item("pickaxe") == 1, "Deposit leaves currency and tools available")
	game.reject_saves = true
	s.transfer_chest(false)
	check(game.count_item("wood") == 0 and s.chests[chest].wood == 25, "Failed chest save rolls transfer back without losing or duplicating items")
	game.reject_saves = false
	s.transfer_chest(false)
	check(game.count_item("wood") == 25 and s.chests[chest].is_empty() and game.count_item("coin") == coins + 12, "Successful chest withdrawal conserves every item")
	s.chests[chest] = {"wood":1}
	check(not s.can_mine(chest), "Nonempty chest cannot be destroyed")
	game.state = "playing"
	game.world.set_tile(at + Vector2i(2,-1),Data.Block.BED)
	game.player = Vector2(at + Vector2i(2,0)) * 24 + Vector2(12,-0.01)
	var spawn: Vector2 = game.world.spawn
	check(s.interact() and game.world.spawn != spawn and game.body_free(game.world.spawn), "Bed in valid housing creates a safe new respawn point")
	game.world.spawn = Vector2(280.5 * 24,58 * 24 - 0.01)
	var rescue: Vector2i = game.cell_at(game.world.spawn)
	var stored: Vector2i = rescue + Vector2i(0,-1)
	game.world.set_tile(rescue,Data.Block.PLANK)
	game.world.set_tile(stored,Data.Block.CHEST)
	s.chests[stored] = {"wood":17,"gold_bar":9}
	var wood: int = game.count_item("wood")
	var doors: int = game.count_item("door")
	s.install_door(rescue + Vector2i(-1,-1))
	game.force_spawn_fallback = true
	var recovered: Vector2 = game.safe_spawn()
	game.force_spawn_fallback = false
	check(game.body_free(recovered), "Emergency recall creates usable space when the whole spawn is blocked")
	check(game.count_item("wood") >= wood + 17 and not s.chests.has(stored), "Emergency clearance refunds a chest's contents")
	check(game.count_item("door") == doors + 1 and not s.door_roots.has(rescue + Vector2i(-1,-1)), "Emergency clearance refunds a two-tile door exactly once")

func test_fluids_plants_movement() -> void:
	game.start_world(101)
	arena()
	var s = game.adventure.structures
	var c := Vector2i(282,57)
	game.inventory.bucket = 1
	s.set_fluid(c,1,4)
	check(not game.place(c,"bucket") and game.count_item("bucket") == 1, "Partial liquid cannot create a full bucket")
	s.set_fluid(c,1,8)
	check(game.place(c,"bucket") and s.fluid(c).y == 0 and game.count_item("water_bucket") == 1, "Bucket collects eight liquid units")
	check(game.place(c,"water_bucket") and s.fluid(c) == Vector2i(1,8) and game.count_item("bucket") == 1, "Pouring conserves bucket and liquid volume")
	for cy in range(55,58):
		for cx in range(281,286):
			s.set_fluid(Vector2i(cx,cy),0,0)
	s.set_fluid(Vector2i(283,55),1,8)
	for frame in range(15):
		s.flow_step()
	var volume: int = 0
	for cy in range(44,58):
		for cx in range(258,303):
			volume += s.fluid(Vector2i(cx,cy)).y
	check(volume == 8 and s.fluid(Vector2i(283,55)).y == 0, "Flow moves down and sideways while conserving volume")
	s.set_fluid(c,1,8)
	game.inventory.stone = 5
	check(game.place(c,"stone") and s.fluid(c).y == 0, "Placed solid displaces liquid instead of hiding it")
	var sealed := Vector2i(277,57)
	s.set_fluid(sealed,1,8)
	for offset in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
		game.world.set_tile(sealed + offset,Data.Block.STONE)
	check(not s.displace([sealed]) and s.fluid(sealed).y == 8, "Sealed liquid cannot be deleted by construction")
	arena()
	s.set_fluid(c,1,8)
	s.set_fluid(c + Vector2i.RIGHT,2,8)
	s.flow_step()
	check(game.world.tile(c) == Data.Block.OBSIDIAN or game.world.tile(c + Vector2i.RIGHT) == Data.Block.OBSIDIAN, "Water and lava react into obsidian")
	arena()
	var sapling := Vector2i(282,57)
	game.world.set_tile(sapling + Vector2i.DOWN,Data.Block.DIRT)
	game.inventory.acorn = 1
	check(game.place(sapling,"acorn"), "Tree seed can be planted on soil")
	game.world.set_tile(sapling + Vector2i.UP,Data.Block.PLANK)
	check(not s.grow_tree(sapling), "Tree growth cannot overwrite player buildings")
	game.world.set_tile(sapling + Vector2i.UP,Data.Block.AIR)
	game.elapsed += 181
	s.tick(0.1)
	check(game.world.tile(sapling) == Data.Block.WOOD and not s.crops.has(sapling), "Mature sapling becomes a harvestable tree")
	game.world.set_tile(sapling,Data.Block.AIR)
	game.inventory.seed = 1
	check(game.place(sapling,"seed"), "Herb seed is plantable")
	game.elapsed += 61
	game.player = Vector2(sapling + Vector2i(-1,1)) * 24 + Vector2(12,-0.01)
	var herbs: int = game.count_item("herb")
	check(s.interact() and game.count_item("herb") == herbs + 3 and game.count_item("seed") >= 1, "Grown herb yields renewable medicine ingredients and seeds")
	arena()
	var platform := Vector2i(280,54)
	game.world.set_tile(platform,Data.Block.PLATFORM)
	var p := Vector2(280.5 * 24,54 * 24 - 0.01)
	check(game.move_body(p,Vector2(0,50)).hit.y == 1, "One-way platform catches falling player")
	check(game.move_body(p + Vector2(0,40),Vector2(0,-90)).hit.y == 0, "Player can jump up through platform")
	Input.action_press("sandbox_down")
	check(game.move_body(p,Vector2(0,40),8,36,Input.is_action_pressed("sandbox_down")).hit.y == 0, "S drops player through platform")
	check(game.move_body(p,Vector2(0,40),10,28).hit.y == 1, "Player drop input does not make monsters fall through platforms")
	Input.action_release("sandbox_down")
	game.adventure.shots.clear()
	game.adventure.shoot(p - Vector2(0,40),Vector2(0,500),10,true)
	game.adventure.update_shots(0.12)
	check(game.adventure.shots.size() == 1 and game.adventure.shots[0].p.y > p.y, "Friendly projectiles pass through combat platforms")
	game.inventory.grapple = 1
	game.equip_item("grapple")
	var wall: Vector2i = game.cell_at(game.player) + Vector2i(5,-1)
	game.world.set_tile(wall,Data.Block.STONE)
	game.pointer = game.get_viewport().get_canvas_transform() * game.cell_center(wall)
	game.adventure.hook_action()
	check(game.adventure.hook.is_finite(), "Equipped grappling hook attaches to real terrain")
	game.adventure.adjust_motion(0.016)
	check(game.velocity.length() > 600, "Attached hook pulls the player")
	game.adventure.hook_action()
	check(not game.adventure.hook.is_finite(), "Q toggles grapple release")
	s.active.clear()
	s.set_fluid(game.cell_at(game.player - Vector2(0,29)),1,8)
	s.fluid_clock = -100
	s.breath = 0.01
	game.health = 100
	game.hurt_time = 0
	s.tick(0.02)
	check(game.health < 100, "Running out of oxygen causes drowning damage")

func test_complete_progression() -> void:
	game.start_world(901)
	arena()
	var a = game.adventure
	for id in ["copper_pick","iron_pick","copper_sword","iron_sword","iron_armor","altar","bow"]:
		craft_with_materials(id)
	check(game.pick_tier == 2 and game.sword_tier == 2, "Early mining and combat tiers upgrade in order")
	game.inventory.life_crystal = 15
	for i in range(15):
		check(a.use_item("life_crystal"), "Life crystal upgrades to 400 health")
	game.inventory.life_crystal = 1
	check(not a.use_item("life_crystal") and game.max_health() == 400, "Life crystal cap is enforced without consuming item")
	game.inventory.mana_star = 8
	for i in range(7):
		check(a.use_item("mana_star"), "Mana star grows maximum mana")
	check(not a.use_item("mana_star") and a.max_mana() == 200 and game.count_item("mana_star") == 1, "Mana cap matches item description")
	game.inventory.final_ticket = 1
	check(not a.use_item("final_ticket") and game.count_item("final_ticket") == 1, "Final boss cannot skip predecessors")
	var summons: Array[String] = ["slime_crown","charged_eye","fossil_lure","build_contract","mechanical_key","thorn_bud","arena_banner","final_ticket"]
	for i in range(8):
		arena(390 if i == 2 else (150 if i == 5 else 280),175 if i == 3 else 58)
		if i == 1:
			game.elapsed = 0
			game.inventory.charged_eye = 1
			check(not a.use_item("charged_eye") and game.count_item("charged_eye") == 1, "Night boss rejects daylight without consuming summon")
			game.elapsed = 420
		craft_with_materials(summons[i])
		check(a.use_item(summons[i]), "Summon boss at legitimate stage/biome: " + Catalog.BOSSES[i].id)
		var boss: Dictionary = a.current_boss()
		check(not boss.is_empty() and boss.boss_index == i, "Correct boss instantiated")
		if boss.is_empty():
			continue
		game.inventory[summons[i]] = 1
		check(not a.use_item(summons[i]) and game.count_item(summons[i]) == 1, "Only one boss can be active")
		boss.timer = 0
		a.update_enemies(0.01)
		check(boss.windup > 0 and a.shots.is_empty(), "Boss warns before attacking")
		boss.windup = 0.001
		a.update_enemies(0.01)
		check(a.shots.size() > 0, "Boss has active combat attacks")
		var drop: String = Catalog.BOSSES[i].drop
		var before: int = game.count_item(drop)
		a.damage_enemy(boss,99999,game.player,true)
		check(a.stage() == i + 1 and a.bosses[Catalog.BOSSES[i].id], "Boss victory advances progression")
		check(game.count_item(drop) == before + Catalog.BOSSES[i].amount, "Boss victory gives next-stage crafting materials")
		check(a.current_boss().is_empty(), "Defeated boss is removed")
		if i == 1:
			craft_with_materials("gold_pick")
		if i == 2:
			craft_with_materials("molten_pick")
		if i == 3:
			check(a.hardmode() and game.world.tiles.count(Data.Block.MYTHRIL) > 100, "Wall victory unlocks real Hardmode ores")
			var mob: Dictionary = a.spawn("slime",game.player + Vector2(150,0))
			check(mob.max_hp == Catalog.ENEMIES.slime.hp * 1.8, "Hardmode increases natural monster strength")
			game.enemies.clear()
		if i == 4:
			craft_with_materials("mythril_pick")
		if i < 7:
			check(game.save_world() and game.load_world() and a.stage() == i + 1, "Stage and layers survive save/reload")
	check(game.state == "sandbox_victory" and a.stage() == 8, "Final victory reaches princess rescue conclusion")
	game.state = "playing"
	game.inventory.life_fruit = 21
	for i in range(20):
		check(a.use_item("life_fruit"), "Late life fruit extends final health")
	check(game.max_health() == 500 and not a.use_item("life_fruit"), "Late health cap is 500 plus optional merchant charm")
	check(game.save_world() and game.load_world() and a.stage() == 8 and game.max_health() == 500, "Post-victory sandbox is persistent and playable")
	var malformed: Dictionary = a.save_data().duplicate(true)
	malformed.structures.types[0] = 9
	check(not a.valid_save(malformed), "Malformed liquid type is rejected")
	malformed = a.save_data().duplicate(true)
	malformed.accessories = ["wings","wings"]
	check(not a.valid_save(malformed), "Duplicate equipped accessories are rejected")
	malformed = a.save_data().duplicate(true)
	malformed.structures.crops[Vector2i(5,5)] = {"tree":true,"ready":NAN}
	check(not a.valid_save(malformed), "Nonfinite crop timers are rejected")
	var legacy: Dictionary = game.read_save(PATH)
	legacy.erase("adventure")
	var file := FileAccess.open(PATH + ".legacy",FileAccess.WRITE)
	file.store_var(legacy)
	file.close()
	check(not game.read_save(PATH + ".legacy").is_empty(), "Original v1 worlds remain readable without expansion fields")
	game.save_path = PATH + ".legacy"
	check(game.load_world() and a.stage() == 0 and game.inventory == legacy.inventory, "Legacy world actually loads while preserving its inventory")
	var protected: Vector2i = Vector2i(280,55)
	game.world.set_tile(protected,Data.Block.PLANK)
	game.world.explored[protected.y * Data.WIDTH + protected.x] = 1
	a.structures.generate_features(true)
	check(game.world.tile(protected) == Data.Block.PLANK, "Migration cannot replace explored player construction")
	game.save_path = PATH

func test_ui() -> void:
	game.state = "inventory"
	for page in range(ceili(Data.ITEMS.size() / 25.0)):
		game.adventure.inventory_page = page
		game.ui.queue_redraw()
		await process_frame
		await process_frame
		var entries: Array = game.ui.buttons.filter(func(e): return e.action == "equip")
		check(entries.size() > 0 and entries.all(func(e): return Rect2(100,48,1080,614).encloses(e.rect)), "Inventory page has reachable item controls: %d" % page)
	var item_index: int = Data.ITEMS.keys().find("iron_armor")
	game.inventory.iron_armor = 1
	game.adventure.inventory_page = item_index / 25
	game.ui.queue_redraw()
	await process_frame
	await process_frame
	var equip_buttons: Array = game.ui.buttons.filter(func(e): return e.action == "equip" and e.item == "iron_armor")
	if equip_buttons.size() == 1:
		game.ui.click(equip_buttons[0].rect.get_center())
	check(equip_buttons.size() == 1 and game.adventure.armor == "iron_armor", "Actual inventory control equips an owned armor set")
	game.recipe_category = 3
	game.adventure.recipe_page = 1
	game.ui.queue_redraw()
	await process_frame
	await process_frame
	var categories: Array = game.ui.buttons.filter(func(e): return e.action == "category")
	check(categories.size() == 4, "All four crafting categories have buttons")
	game.ui.click(categories[0].rect.get_center())
	check(game.recipe_category == 0 and game.adventure.recipe_page == 0, "Category switch resets pagination")
	game.state = "playing"
	game.ui.queue_redraw()
	await process_frame
	await process_frame
	game.ui.click(Vector2(90,377))
	check(game.state == "journal", "Growth journal opens through actual HUD control")
	game.ui.queue_redraw()
	await process_frame
	await process_frame
	game.ui.click(Vector2(520,171))
	check(game.ui.detail.journal_tab == 1, "Journal switches to bestiary")

func test_events_fishing_and_survival() -> void:
	game.start_world(701)
	arena()
	var a = game.adventure
	var s = a.structures
	game.inventory.fishing_rod = 1
	var water: Vector2i = game.cell_at(game.player) + Vector2i(4,-1)
	s.set_fluid(water,1,8)
	game.pointer = game.get_viewport().get_canvas_transform() * game.cell_center(water)
	check(a.use_item("fishing_rod") and not a.fishing.is_empty() and game.count_item("fishing_rod") == 1, "Fishing casts at reachable water without consuming rod")
	a.fishing.time = a.fishing.bite + 0.1
	check(a.use_item("fishing_rod") and game.count_item("fish") > 0 and a.fishing.is_empty(), "Timed hook input catches fish")
	craft_with_materials("cooked_fish")
	game.health = 10
	check(a.use_item("cooked_fish") and game.health == 60 and a.food_buff == 120, "Cooked fish heals and grants actual regeneration")
	check(not a.use_item("cooked_fish"), "Food cannot be consumed again during short cooldown")
	s.active.clear()
	s.set_fluid(water,0,0)
	a.tick(1)
	check(game.health > 60, "Well-fed regeneration restores health over time")
	game.health = 10
	check(game.heal() and a.heal_cooldown == 45, "Quick heal enters potion cooldown")
	var potions: int = game.count_item("potion")
	check(not game.heal() and game.count_item("potion") == potions, "Potion cooldown prevents healing spam without consuming inventory")
	check(game.save_world() and game.load_world() and a.heal_cooldown == 45 and a.food_buff > 0, "Survival cooldowns and food buff persist across reopening")
	arena()
	game.inventory.wings = 1
	game.equip_item("wings")
	game.grounded = false
	game.coyote = 0
	game.velocity = Vector2(0,100)
	Input.action_press("sandbox_jump")
	a.adjust_motion(0.1)
	check(game.velocity.y < 0 and a.flight < 2.2, "Equipped wings provide finite upward flight")
	Input.action_release("sandbox_jump")
	game.grounded = true
	a.adjust_motion(0.1)
	check(a.flight == 2.2, "Landing restores flight capacity")
	game.inventory.double_jump = 1
	game.equip_item("double_jump")
	game.grounded = false
	game.coyote = 0
	game.jump_buffer = 0.14
	game.velocity.y = 40
	Input.action_press("sandbox_jump")
	a.adjust_motion(0.016)
	check(a.air_jumps == 1 and game.velocity.y < -450, "Jump input triggers equipped cloud bottle while airborne")
	game.jump_buffer = 0.14
	a.adjust_motion(0.016)
	check(a.air_jumps == 1 and game.jump_buffer > 0, "Cloud bottle cannot grant unlimited extra jumps")
	Input.action_release("sandbox_jump")
	game.inventory.invasion_banner = 1
	check(a.use_item("invasion_banner") and a.event_left == 24, "Invasion starts with a finite budget of 24 enemies")
	a.tick(1)
	var members: Array = game.enemies.filter(func(e): return e.get("event_member",false))
	check(members.size() == 1 and a.event_left == 23, "Actual invasion spawn spends exactly one budget unit")
	if not members.is_empty():
		members[0].p += Vector2(3000,0)
		a.update_enemies(0.01)
	check(a.event_left == 24, "Despawned invasion enemies return to remaining budget")
	a.tick(1)
	check(game.save_world() and game.load_world() and a.event_left == 24, "Reload resumes unfinished invasion instead of losing live enemies")
	var rewarded: int = game.count_item("coin")
	for i in range(24):
		game.enemies.clear()
		a.tick(1)
		var pending: Array = game.enemies.filter(func(e): return e.get("event_member",false))
		check(pending.size() == 1, "Invasion can continue to completion after reload")
		if not pending.is_empty():
			a.damage_enemy(pending[0],99999,game.player,true)
	check(a.event.is_empty() and a.event_kills == 24 and game.count_item("coin") >= rewarded + 80, "Twenty-four invasion kills end event and grant reward once")
	game.elapsed = 3 * Data.DAY_SECONDS + 330
	a.tick(0.01)
	check(a.blood_moon, "Fourth game night starts blood event")
	check(game.save_world() and game.load_world(), "Blood event world saves")
	a.tick(0.01)
	check(a.blood_moon, "Reopening the same blood night preserves event rules")
	game.elapsed = 4 * Data.DAY_SECONDS
	a.tick(0.01)
	check(not a.blood_moon, "Blood event ends on correct day")

func test_sustained_simulation() -> void:
	game.start_world(390)
	arena()
	var a = game.adventure
	var start: int = Time.get_ticks_msec()
	var ticks: int = 0
	for index in range(3):
		arena(150 if index == 1 else 280,175 if index == 2 else 58)
		game.health = game.max_health()
		var kinds: Array = Catalog.ENEMIES.keys()
		for i in range(12):
			a.spawn(kinds[(i + index * 5) % kinds.size()],game.player + Vector2((1 if i % 2 else -1) * (90 + i * 30),-40))
		for frame in range(1200):
			game.hurt_time = 1
			game.enemy_timer = 100
			game._physics_process(1.0 / 60)
			ticks += 1
		check(game.state == "playing" and game.player.is_finite() and game.body_free(game.player), "Sustained play remains outside terrain in biome %d" % index)
		check(a.shots.size() <= 220 and game.enemies.size() <= 28 and a.hazards.size() < 80, "Enemy/projectile/hazard counts stay bounded")
	print("SIMULATION: %d physics ticks in %d ms" % [ticks,Time.get_ticks_msec() - start])

func run() -> void:
	game = Fixture.new()
	game.save_path = PATH
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	test_content_and_generation()
	test_combat()
	test_housing_and_storage()
	test_fluids_plants_movement()
	test_complete_progression()
	test_events_fishing_and_survival()
	test_sustained_simulation()
	await test_ui()
	for suffix in ["", ".bak", ".tmp", ".legacy", ".legacy.bak", ".legacy.tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	game.queue_free()
	await process_frame
	print("SANDBOX ADVENTURE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
