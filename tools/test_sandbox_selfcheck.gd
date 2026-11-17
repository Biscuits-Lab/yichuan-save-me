extends SceneTree
const Data = preload("res://scripts/sandbox_data.gd")
const Catalog = preload("res://scripts/sandbox_catalog.gd")
var game: Node
var checks: int = 0
var failures: int = 0
const PATH = "res://.tools/sandbox-selfcheck.save"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func clear_area(center: Vector2i) -> void:
	game.enemies.clear()
	game.adventure.structures.npcs.clear()
	for y in range(center.y - 12,center.y + 3):
		for x in range(center.x - 12,center.x + 13):
			game.world.set_tile(Vector2i(x,y),Data.Block.AIR if y < center.y else Data.Block.DIRT)
	game.player = Vector2(center) * 24 + Vector2(12,-0.01)
	game.previous_player = game.player
	game.state = "playing"

func house(at: Vector2i) -> void:
	var s = game.adventure.structures
	for y in range(-6,1):
		for x in range(-5,6):
			var c: Vector2i = at + Vector2i(x,y)
			game.world.set_tile(c,Data.Block.PLANK if y in [-6,0] or absi(x) == 5 else Data.Block.AIR)
			s.walls[s.index(c)] = 1
	s.install_door(at + Vector2i(5,-1))
	game.world.set_tile(at + Vector2i(-2,-1),Data.Block.BENCH)
	game.world.set_tile(at + Vector2i(2,-1),Data.Block.CHAIR)
	game.world.set_tile(at + Vector2i(-4,-3),Data.Block.TORCH)

func test_underground_bed() -> void:
	game.start_world(808)
	var at := Vector2i(280,115)
	clear_area(at)
	house(at)
	game.world.set_tile(at + Vector2i(0,-1),Data.Block.BED)
	game.player = Vector2(at) * 24 + Vector2(12,-0.01)
	check(game.adventure.structures.interact(), "Underground bed interaction is handled")
	check(game.world.spawn.distance_to(game.player) < 100, "Bed sets respawn inside the underground house")
	check(game.safe_spawn().distance_to(game.player) < 100, "Recall keeps the underground bed location")
	game.health = 0
	game.state = "dead"
	game.respawn()
	check(game.player.distance_to(Vector2(at) * 24) < 100 and game.body_free(game.player), "Death returns to underground bed in usable space")
	check(game.save_world() and game.load_world() and game.player.distance_to(Vector2(at) * 24) < 100, "Underground home and player round-trip through save")
	var blocked: Vector2i = game.cell_at(game.world.spawn - Vector2(0,12))
	game.world.set_tile(blocked,Data.Block.PLANK)
	var safe: Vector2 = game.safe_spawn()
	check(safe.distance_to(Vector2(at) * 24) < 150 and game.body_free(safe), "Blocked underground bed finds nearby space in the base")

func test_room_identity_and_headroom() -> void:
	game.start_world(808)
	var at := Vector2i(280,58)
	clear_area(at)
	house(at)
	var s = game.adventure.structures
	game.world.set_tile(at + Vector2i(-1,-1),Data.Block.CHAIR)
	s.house_anchors.clear()
	s.house_anchors.append(at + Vector2i(-1,-1))
	s.house_anchors.append(at + Vector2i(2,-1))
	game.adventure.life_upgrades = 1
	s.update_town()
	check(s.homes.size() == 1 and s.npcs.size() == 1, "Two chairs in one room cannot allocate two homes")
	# Moving the chair to the ceiling must not spawn an NPC inside that ceiling.
	game.world.set_tile(at + Vector2i(-1,-1),Data.Block.AIR)
	game.world.set_tile(at + Vector2i(2,-1),Data.Block.AIR)
	var chair: Vector2i = at + Vector2i(1,-5)
	game.world.set_tile(chair,Data.Block.CHAIR)
	s.house_anchors.assign([chair])
	s.update_town()
	check(s.npcs.size() == 1 and game.body_free(s.npcs[0].p,9,42) and game.world.solid(game.cell_at(s.npcs[0].p + Vector2(0,0.02))), "NPC chooses actual standing space rather than the chair's tile")
	# A separate room must still receive its own resident.
	var other: Vector2i = at + Vector2i(24,0)
	clear_area(other)
	house(other)
	s.house_anchors.append(other + Vector2i(2,-1))
	s.update_town()
	check(s.homes.size() == 2 and s.npcs.size() == 2, "Independent rooms retain separate housing capacity")

func test_immature_herbs() -> void:
	game.start_world(808)
	var at := Vector2i(280,58)
	clear_area(at)
	var c: Vector2i = at + Vector2i(2,-1)
	game.inventory.seed = 1
	game.inventory.herb = 0
	check(game.place(c,"seed"), "Plant herb for early mining reproduction")
	check(game.mine(c), "Immature herb can be removed")
	check(game.count_item("herb") == 0 and game.count_item("seed") == 1, "Immature herb returns seed without producing instant medicine")
	game.inventory.seed = 1
	game.inventory.herb = 0
	check(game.place(c,"seed"), "Plant herb for construction replacement reproduction")
	check(game.place(c,"dirt"), "Construction can replace a seedling")
	check(game.count_item("herb") == 0 and game.count_item("seed") == 1, "Replacing immature herb cannot manufacture mature herb")
	game.world.set_tile(c,Data.Block.AIR)
	check(game.place(c,"seed"), "Replant the refunded seed")
	game.elapsed += 61
	check(game.mine(c) and game.count_item("herb") == 3 and game.count_item("seed") == 1, "Mature herb mining yields exactly one harvest")
	game.inventory.herb = 0
	check(game.place(c,"seed"), "Plant mature construction replacement fixture")
	game.elapsed += 61
	check(game.place(c,"dirt") and game.count_item("herb") == 3 and game.count_item("seed") == 1, "Construction replacement preserves a mature harvest exactly once")

func test_hardmode_transition_once() -> void:
	game.start_world(808)
	clear_area(Vector2i(280,115))
	var a = game.adventure
	for i in range(4):
		a.bosses[Catalog.BOSSES[i].id] = true
	var c := Vector2i(280,120)
	while posmod(c.x * 173 + c.y * 661 + game.world.seed_value,37) >= 5:
		c.x += 1
	game.world.set_tile(c,Data.Block.STONE)
	var boss: Dictionary = a.spawn("boss",game.player + Vector2(200,0),3)
	var souls: int = game.count_item("soul")
	a.damage_enemy(boss,99999,game.player,true)
	check(game.world.tile(c) == Data.Block.STONE, "Repeated wall victories do not rerun the world transition")
	check(game.count_item("soul") == souls + Catalog.BOSSES[3].amount, "Repeated boss still grants its normal material reward")

func run() -> void:
	game = load("res://scenes/sandbox.tscn").instantiate()
	game.save_path = PATH
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	test_underground_bed()
	test_room_identity_and_headroom()
	test_immature_herbs()
	test_hardmode_transition_once()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	game.queue_free()
	await process_frame
	print("SANDBOX SELFCHECK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
