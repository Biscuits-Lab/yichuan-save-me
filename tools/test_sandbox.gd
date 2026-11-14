extends SceneTree
const Data = preload("res://scripts/sandbox_data.gd")
var game: Node
var checks: int = 0
var failures: int = 0
var test_path: String = "res://.tools/sandbox-test.save"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func step(frames: int) -> void:
	for frame in range(frames):
		game._physics_process(1.0 / 60.0)

func test_generation() -> void:
	var first := Data.new()
	var second := Data.new()
	for seed_number in [1, 19, 8675309, 20261113, 99999999]:
		first.generate(seed_number)
		second.generate(seed_number)
		check(first.tiles == second.tiles and first.surface == second.surface, "Same seed reproduces terrain and caves")
		check(first.spawn == second.spawn and first.tiles.size() == Data.WIDTH * Data.HEIGHT, "World dimensions and spawn are deterministic")
		check(first.tile(Vector2i(-1, 10)) == Data.Block.BEDROCK and first.solid(Vector2i(10, Data.HEIGHT)), "World edges are closed")
		check(first.tile(first.heart_cell) == Data.Block.CORE, "Every world has the progression objective")
		var resources: Dictionary = {}
		for id in first.tiles:
			resources[id] = int(resources.get(id, 0)) + 1
		for id in [Data.Block.COPPER, Data.Block.IRON, Data.Block.COAL, Data.Block.CRYSTAL, Data.Block.WOOD]:
			check(resources.get(id, 0) > 20, "All resource tiers exist, seed %d resource %d" % [seed_number, id])
	first.generate(1)
	second.generate(2)
	check(first.tiles != second.tiles, "Different seeds create different worlds")
	check(first.biome(30) != first.biome(Data.WIDTH / 2) and first.biome(Data.WIDTH - 30) != first.biome(30), "Three biomes have distinct regions")

func test_motion() -> void:
	game.start_world(20261113)
	game.set_physics_process(false)
	check(game.body_free(game.player), "Player starts outside solid terrain")
	step(5)
	check(game.grounded, "Gravity settles onto generated terrain")
	var origin: Vector2 = game.player
	Input.action_press("sandbox_right")
	step(20)
	Input.action_release("sandbox_right")
	check(game.player.x > origin.x + 40, "Horizontal input moves the character")
	check(game.body_free(game.player), "Movement never embeds the player")
	game.jump_buffer = 0.14
	Input.action_press("sandbox_jump")
	step(12)
	check(game.player.y < origin.y - 35 and not game.grounded, "Jump rises above the ground")
	Input.action_release("sandbox_jump")
	step(100)
	check(game.grounded and absf(game.player.y - origin.y) < 1, "Jump lands on the original surface")
	var at: Vector2i = game.cell_at(game.player)
	for y in range(at.y - 5, at.y + 1):
		game.world.set_tile(Vector2i(at.x + 3, y), Data.Block.STONE)
	var sweep: Dictionary = game.move_body(game.player, Vector2(600, 0))
	check(sweep.hit.x == 1 and sweep.p.x < (at.x + 3) * Data.TILE, "Swept movement cannot tunnel through a tile wall")
	check(game.body_free(sweep.p), "Swept collision resolves to a free position")
	var elapsed_before: float = game.elapsed
	game.set_state("paused")
	step(60)
	check(game.elapsed == elapsed_before, "Paused interfaces freeze the survival clock")

func test_mining_building() -> void:
	game.start_world(20261113)
	var at: Vector2i = game.cell_at(game.player)
	var ground: int = game.world.surface_at(at.x)
	var target := Vector2i(at.x + 2, ground - 1)
	game.world.set_tile(target, Data.Block.DIRT)
	var before: int = game.count_item("dirt")
	check(game.mine(target), "Nearby exposed terrain can be mined")
	check(game.world.tile(target) == Data.Block.AIR and game.count_item("dirt") == before + 1, "Mining transfers terrain into the inventory")
	check(game.place(target, "dirt"), "A harvested block can be placed against terrain")
	check(game.count_item("dirt") == before, "Placement consumes exactly one block")
	check(not game.place(game.cell_at(game.player - Vector2(0, 10)), "dirt"), "Cannot place solid terrain inside the player")
	check(not game.mine(target + Vector2i(20, 0)), "Remote mining is rejected")
	game.world.set_tile(target, Data.Block.IRON)
	check(not game.mine(target), "Starter pick cannot harvest iron")
	game.pick_tier = 1
	check(game.mine(target) and game.count_item("iron_ore") == 1, "Copper pick unlocks iron mining")
	game.world.set_tile(target, Data.Block.CRYSTAL)
	check(not game.mine(target), "Copper pick cannot harvest crystal")
	game.pick_tier = 2
	check(game.mine(target), "Iron pick unlocks crystal mining")
	game.world.set_tile(target, Data.Block.BEDROCK)
	check(not game.mine(target), "Bedrock is indestructible at every tier")
	game.world.set_tile(target, Data.Block.AIR)
	game.add_item("wood", 10)
	var wood_before: int = game.count_item("wood")
	game.world.plant_tree(at.x + 3, 7)
	check(game.mine(Vector2i(at.x + 3, ground - 1)), "Tree trunks are harvestable with the starter tool")
	check(game.count_item("wood") >= wood_before + 7, "Chopping a tree collects its upper trunk")
	var far := Vector2i(at.x + 4, ground - 2)
	var wall := Vector2i(at.x + 2, ground - 2)
	game.world.set_tile(wall, Data.Block.STONE)
	game.world.set_tile(wall + Vector2i.UP, Data.Block.STONE)
	game.world.set_tile(far, Data.Block.COPPER)
	check(not game.can_mine(far), "Cannot mine resources through a solid wall")
	game.world.set_tile(wall, Data.Block.AIR)
	game.world.set_tile(wall + Vector2i.UP, Data.Block.AIR)
	game.add_item("torch", 1)
	var torch_cell := Vector2i(at.x - 2, ground - 1)
	check(game.place(torch_cell, "torch") and game.world.torch_cells.has(torch_cell), "Placed torches enter the lighting index")
	check(game.mine(torch_cell) and not game.world.torch_cells.has(torch_cell), "Removed torches leave the lighting index")

func test_crafting() -> void:
	game.start_world(20261113)
	check(not game.craft(3), "Missing crafting materials are rejected")
	game.add_item("wood", 80)
	game.add_item("stone", 40)
	game.add_item("coal", 50)
	game.add_item("copper_ore", 30)
	game.add_item("iron_ore", 36)
	check(game.craft(3), "Workbench can be crafted by hand")
	var at: Vector2i = game.cell_at(game.player)
	var ground: int = game.world.surface_at(at.x)
	check(not game.craft(4), "A carried workbench does not count as a placed station")
	check(game.place(Vector2i(at.x + 2, ground - 1), "bench"), "Workbench can be placed in the world")
	check(game.craft(4), "Placed workbench unlocks furnace recipe")
	check(not game.craft(6), "Smelting requires an actual nearby furnace")
	check(game.place(Vector2i(at.x + 3, ground - 1), "furnace"), "Furnace can be placed beside the workbench")
	var coal_before: int = game.count_item("coal")
	for n in range(5):
		check(game.craft(6), "Copper ore can be smelted")
	check(game.count_item("coal") == coal_before - 5, "Smelting consumes fuel")
	check(game.craft(8) and game.pick_tier == 1, "Copper pick upgrades the existing tool")
	var wood_before: int = game.count_item("wood")
	check(not game.craft(8) and game.count_item("wood") == wood_before, "Duplicate upgrades cannot consume materials")
	for n in range(10):
		check(game.craft(7), "Iron ore can be smelted")
	check(game.craft(9) and game.pick_tier == 2, "Iron pick completes the mining progression")
	game.add_item("core", 1)
	game.add_item("crystal", 12)
	check(game.craft(12), "Deep resources unlock the beacon recipe")
	game.equip_item("beacon")
	check(game.held_item() == "beacon", "Crafted items outside the default hotbar can be equipped")
	check(game.place(Vector2i(at.x - 2, ground - 1)), "Equipped beacon can be placed using the normal build action")
	check(game.completed and game.state == "complete", "Surface beacon completes the expedition")

func test_combat() -> void:
	game.start_world(20261113)
	game.sword_tier = 2
	game.facing = 1
	var enemy: Dictionary = {"p":game.player + Vector2(45, 0), "previous":game.player + Vector2(45, 0), "v":Vector2.ZERO, "hp":30, "max_hp":30, "jump":1.0, "flash":0.0, "dark":false}
	game.enemies.append(enemy)
	var silver_before: int = game.count_item("coin")
	game.attack()
	check(game.enemies.is_empty() and game.count_item("gel") == 2, "Sword damage kills nearby enemies and grants crafting drops")
	check(game.count_item("coin") > silver_before, "Combat funds merchant trading")
	game.hurt_time = 0
	game.hurt(30, game.player + Vector2(10, 0))
	check(game.health == 70, "Enemy damage removes health")
	game.hurt(30, game.player + Vector2(10, 0))
	check(game.health == 70, "Hit invulnerability prevents repeated contact damage")
	check(game.heal() and game.health == 100 and game.count_item("potion") == 2, "Potion heals and consumes one item")
	game.hurt_time = 0
	game.hurt(1000, game.player)
	check(game.state == "dead", "Lethal damage opens the respawn state")
	var inventory_before: Dictionary = game.inventory.duplicate()
	game.respawn()
	check(game.state == "playing" and game.inventory == inventory_before and game.body_free(game.player), "Respawn retains possessions and finds free terrain")
	game.elapsed = Data.DAY_SECONDS * 0.55
	check(game.is_night() and game.daylight() < 0.5, "The day cycle reaches a dark night")

func test_visits_and_trade() -> void:
	for day in [1, 4, 6, 9, 11]:
		check(not Data.merchant_schedule(day).present, "Merchant is absent on game day %d" % day)
	for day in [5, 10, 15, 50]:
		check(Data.merchant_schedule(day).present, "Merchant arrives on game day %d" % day)
	check(Data.merchant_schedule(1).days == 4 and Data.merchant_schedule(6).next_day == 10, "Countdown uses the next five-day visit")
	game.start_world(20261113)
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	check(game.merchant_present and game.merchant_stock.size() == Data.OFFERS.size(), "Fifth game day generates shop stock")
	game.merchant_stock[0] -= 1
	game.refresh_merchant()
	check(game.merchant_stock[0] == Data.OFFERS[0].stock - 1, "Reopening the same visit cannot refill stock")
	game.state = "merchant"
	game.elapsed = 5 * Data.DAY_SECONDS
	game.refresh_merchant()
	check(not game.merchant_present and game.state == "playing", "Merchant leaves on game day six")
	game.elapsed = 9 * Data.DAY_SECONDS
	game.refresh_merchant()
	check(game.merchant_stock[0] == Data.OFFERS[0].stock, "Tenth game day restocks supplies")
	game.player = game.merchant_position + Vector2(35, 0)
	game.interact()
	check(game.state == "merchant", "E near the merchant opens trade")
	var coins_before: int = game.count_item("coin")
	var torch_before: int = game.count_item("torch")
	var stock_before: int = game.merchant_stock[0]
	check(game.buy(0), "Affordable visit purchase succeeds")
	check(game.count_item("coin") == coins_before - 6 and game.count_item("torch") == torch_before + 12 and game.merchant_stock[0] == stock_before - 1, "Purchase atomically updates currency, inventory and stock")
	game.inventory.coin = 0
	check(not game.buy(1), "Unaffordable purchases are rejected")
	game.inventory.coin = 200
	check(game.buy(6) and game.count_item("lantern") == 1, "Unique hunter lantern can be purchased")
	check(not game.buy(6), "Unique equipment cannot be purchased twice")
	check(game.buy(7) and game.max_health() == 120, "Priest charm applies its health bonus")
	game.player += Vector2(500, 0)
	check(not game.buy(0), "Trading requires physical proximity")

func test_saves() -> void:
	game.start_world(91827)
	var at: Vector2i = game.cell_at(game.player)
	game.world.set_tile(at + Vector2i(2, -1), Data.Block.TORCH)
	game.world.reveal(game.player)
	game.inventory.coin = 77
	game.pick_tier = 1
	game.equip_item("sand")
	game.elapsed = 4 * Data.DAY_SECONDS + 145.0
	game.refresh_merchant()
	if game.merchant_present:
		game.merchant_stock[0] = 2
	check(game.save_world(), "World save succeeds")
	var original_tiles: PackedByteArray = game.world.tiles.duplicate()
	game.inventory.coin = 0
	game.world.set_tile(at + Vector2i(2, -1), Data.Block.AIR)
	check(game.load_world(), "Saved world loads")
	check(game.inventory.coin == 77 and game.pick_tier == 1 and game.elapsed == 2545.0 and game.held_item() == "sand", "Inventory, hotbar, progression and world clock round-trip")
	check(game.world.tiles == original_tiles and game.world.torch_cells.has(at + Vector2i(2, -1)), "Terrain edits and torch lighting round-trip")
	if game.merchant_present:
		check(game.merchant_stock[0] == 2, "Loading cannot refill the current visit stock")
	check(game.save_world(), "A second save creates a recoverable backup")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_var({"version":1, "tiles":PackedByteArray([255])})
	corrupt.close()
	check(game.load_world() and game.inventory.coin == 77, "Corrupt primary save recovers the last valid backup")
	var malformed: Dictionary = game.read_save(test_path + ".bak")
	malformed.tiles[0] = 255
	var invalid := FileAccess.open(test_path + ".invalid", FileAccess.WRITE)
	invalid.store_var(malformed)
	invalid.close()
	check(game.read_save(test_path + ".invalid").is_empty(), "Unknown tile IDs are rejected before applying a save")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tools")
	game = load("res://scenes/sandbox.tscn").instantiate()
	game.save_path = test_path
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	test_generation()
	test_motion()
	test_mining_building()
	test_crafting()
	test_combat()
	test_visits_and_trade()
	test_saves()
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(test_path + suffix)
	game.queue_free()
	await process_frame
	print("SANDBOX TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
