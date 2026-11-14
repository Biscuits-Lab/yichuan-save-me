extends SceneTree
const Data = preload("res://scripts/sandbox_data.gd")
class SandboxFixture:
	extends "res://scripts/sandbox_run.gd"
	var reject_saves: bool = false
	func save_world() -> bool:
		return failed_save("模拟写入失败") if reject_saves else super.save_world()

var game: Node
var checks: int = 0
var failures: int = 0
const PATH: String = "res://.tools/sandbox-audit.save"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func write_variant(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(value)
	file.close()

func test_backup_survives_recovery() -> void:
	game.start_world(101)
	game.inventory.coin = 73
	check(game.save_world() and game.save_world(), "Create a primary and backup with known resources")
	write_variant(PATH, {"version":1, "broken":true})
	check(game.load_world(), "Recover the known good backup")
	game.inventory.coin = 74
	check(game.save_world(), "Saving after recovery succeeds")
	check(not game.read_save(PATH + ".bak").is_empty(), "Recovery must not copy the corrupt primary over the only valid backup")

func test_respawn_avoids_dug_shaft() -> void:
	game.start_world(101)
	var center: int = Data.WIDTH / 2
	for x in range(center - 1, center + 2):
		for y in range(55, 150):
			game.world.set_tile(Vector2i(x, y), Data.Block.AIR)
		game.world.set_tile(Vector2i(x, 150), Data.Block.STONE)
	var home: Vector2 = game.safe_spawn()
	check(home.distance_to(game.world.spawn) < 150, "Recall should find nearby surface ground instead of the bottom of a dug spawn shaft")
	check(game.body_free(home), "Recovered spawn is outside terrain")
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	var merchant_cell: Vector2i = game.cell_at(game.merchant_position)
	for y in range(55, 155):
		game.world.set_tile(Vector2i(merchant_cell.x, y), Data.Block.AIR)
	game.world.set_tile(Vector2i(merchant_cell.x, 155), Data.Block.STONE)
	game.refresh_merchant()
	check(game.merchant_position.y < 70 * Data.TILE, "Merchant stays on the surface when his original column is excavated")

func test_death_load() -> void:
	game.start_world(101)
	game.inventory.wood = 19
	game.health = 0.0
	game.state = "dead"
	check(game.save_world() and game.load_world(), "A game saved after death can be reopened")
	check(game.health == game.max_health() and game.count_item("wood") == 19, "Loading a death save should follow normal respawn rules instead of reviving at one HP")

func test_failed_trade() -> void:
	game.start_world(101)
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.player = game.merchant_position + Vector2(36, 0)
	game.state = "merchant"
	game.inventory.coin = 100
	var before: Dictionary = game.inventory.duplicate(true)
	var stock: Array = game.merchant_stock.duplicate()
	game.reject_saves = true
	check(not game.buy(0), "Checkout reports failure when the purchase cannot be saved")
	check(game.inventory == before and game.merchant_stock == stock, "Failed checkout leaves currency, items and weekly stock unchanged")
	game.reject_saves = false
	game.elapsed = 5 * Data.DAY_SECONDS
	check(not game.buy(0) and game.state == "playing" and game.inventory == before, "A checkout outside the visiting game day cannot trade")
	game.elapsed = 9 * Data.DAY_SECONDS
	game.refresh_merchant()
	check(game.merchant_stock[0] == Data.OFFERS[0].stock, "Tenth game day restocks supplies")
	game.state = "merchant"
	check(game.buy(0), "Next visit checkout succeeds after storage recovers")
	var remaining: int = game.merchant_stock[0]
	check(game.load_world() and game.merchant_stock[0] == remaining, "Visit stock survives reopening the saved world")

func test_bad_save_fields() -> void:
	game.start_world(101)
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.save_world()
	var original: Dictionary = game.read_save(PATH)
	for pair in [["health", {}], ["elapsed", "bad clock"], ["completed", []], ["merchant_visit", "bad visit"], ["stats", {"wood":"bad count"}], ["spawn", Vector2(-9000, -1)], ["heart", Vector2i(-10, -10)]]:
		var invalid: Dictionary = original.duplicate(true)
		invalid[pair[0]] = pair[1]
		write_variant(PATH + ".invalid", invalid)
		check(game.read_save(PATH + ".invalid").is_empty(), "Invalid %s field is rejected safely" % pair[0])
	var invalid_bar: Dictionary = original.duplicate(true)
	invalid_bar.hotbar[0] = "coin"
	write_variant(PATH + ".invalid", invalid_bar)
	check(game.read_save(PATH + ".invalid").is_empty(), "Non-equippable items cannot corrupt the saved hotbar")
	var invalid_stock: Dictionary = original.duplicate(true)
	invalid_stock.merchant_stock[0] = Data.OFFERS[0].stock + 1
	write_variant(PATH + ".invalid", invalid_stock)
	check(game.read_save(PATH + ".invalid").is_empty(), "Saved merchant stock cannot exceed the weekly limit")
	write_variant(PATH, original.duplicate(true))
	write_variant(PATH + ".bak", original.duplicate(true))
	var broken: Dictionary = original.duplicate(true)
	broken.health = {"bad":true}
	write_variant(PATH, broken)
	check(game.load_world(), "Malformed scalar fields trigger backup recovery instead of a script error")

func test_day_boundary_and_occupied_tiles() -> void:
	game.start_world(101)
	game.elapsed = Data.DAY_SECONDS * 0.68 - 0.01
	check(game.day_number() == 1, "First evening is still day one")
	game.elapsed += 0.02
	check(game.day_number() == 2, "Displayed day advances at midnight instead of the following morning")
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.player = game.merchant_position + Vector2(48, 0)
	game.add_item("dirt", 10)
	check(not game.can_place(game.cell_at(game.merchant_position - Vector2(0, 20)), "dirt"), "Building cannot bury the visiting merchant")
	var p: Vector2 = game.player + Vector2(48, 0)
	game.enemies.append({"p":p})
	check(not game.can_place(game.cell_at(p - Vector2(0, 10)), "dirt"), "Building cannot embed an enemy into collision terrain")
	game.enemies.clear()

func send_key(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()

func redraw() -> void:
	game.view.queue_redraw()
	game.ui.queue_redraw()
	await process_frame
	await process_frame

func mouse(p: Vector2, button: MouseButton, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = p
	motion.global_position = p
	Input.parse_input_event(motion)
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	click.position = p
	click.global_position = p
	Input.parse_input_event(click)
	Input.flush_buffered_events()

func test_player_input_flow() -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.start_world(20261113)
	var at: Vector2i = game.cell_at(game.player)
	var ground: int = game.world.surface_at(at.x)
	game.world.plant_tree(at.x + 3, 9)
	await redraw()
	var target: Vector2 = game.get_viewport().get_canvas_transform() * game.cell_center(Vector2i(at.x + 3, ground - 1))
	mouse(target, MOUSE_BUTTON_LEFT, true)
	for frame in range(35):
		game._physics_process(1.0 / 60.0)
		await physics_frame
	mouse(target, MOUSE_BUTTON_LEFT, false)
	check(game.count_item("wood") >= 9, "Actual held mouse input harvests a nearby tree through tool timing")
	send_key(KEY_TAB)
	await redraw()
	check(game.state == "inventory", "Actual Tab input opens the crafting interface")
	mouse(Vector2(1070, 402), MOUSE_BUTTON_LEFT, true)
	mouse(Vector2(1070, 402), MOUSE_BUTTON_LEFT, false)
	check(game.count_item("bench") == 1 and game.count_item("wood") == 1, "Clicking the visible craft button creates a workbench and consumes wood")
	send_key(KEY_TAB)
	send_key(KEY_8)
	await redraw()
	var placement: Vector2 = game.get_viewport().get_canvas_transform() * game.cell_center(Vector2i(at.x + 2, ground - 1))
	mouse(placement, MOUSE_BUTTON_RIGHT, true)
	game._physics_process(1.0 / 60.0)
	mouse(placement, MOUSE_BUTTON_RIGHT, false)
	check(game.world.tile(Vector2i(at.x + 2, ground - 1)) == Data.Block.BENCH, "Actual number-key selection and right-click place the crafted station")
	game.health = 60
	send_key(KEY_H)
	check(game.health == 100 and game.count_item("potion") == 2, "Actual H input consumes the healing item")

func solve_review() -> void:
	for pair in range(Data.REVIEW_PAIRS.size()):
		var first: int = game.review_cards.find(pair)
		var second: int = game.review_cards.rfind(pair)
		game.flip_review(first)
		game.flip_review(second)

func test_code_review() -> void:
	game.start_world(302)
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.player = game.merchant_position + Vector2(36, 0)
	game.state = "merchant"
	check(game.start_review(), "Merchant opens the Code Review minigame")
	var counts: Dictionary = {}
	for card in game.review_cards:
		counts[card] = int(counts.get(card, 0)) + 1
	check(game.review_cards.size() == 20 and counts.size() == 10, "High difficulty uses twenty cards and ten distinct pairs")
	var pairs_valid: bool = true
	for amount in counts.values():
		pairs_valid = pairs_valid and amount == 2
	check(pairs_valid and game.review_time == 60 and Data.REVIEW_MAX_TURNS == 16, "Every card has one match with a sixty-second and sixteen-turn limit")
	var first: int = 0
	var mismatch: int = 1
	while game.review_cards[mismatch] == game.review_cards[first]:
		mismatch += 1
	check(game.flip_review(first) and not game.flip_review(first), "A card cannot match itself")
	game.flip_review(mismatch)
	check(game.review_wait > 0 and not game.flip_review((mismatch + 1) % 20), "Mismatched cards remain visible and block a third flip")
	game.update_review(0.71)
	check(game.review_open.is_empty() and game.review_turns == 1, "A failed pair consumes exactly one turn before closing")
	var world_time: float = game.elapsed
	game._physics_process(1.0)
	check(game.elapsed == world_time, "Code Review freezes the sandbox world clock")
	solve_review()
	check(game.state == "review_reward" and game.review_reward_pending and game.review_completed_visit == 5, "Matching every pair opens the free reward choice")
	var coins: int = game.count_item("coin")
	var stock: Array = game.merchant_stock.duplicate()
	check(game.claim_review_reward(6) and game.count_item("lantern") == 1, "A cleared review can award one chosen lantern")
	check(game.count_item("coin") == coins and game.merchant_stock == stock, "The CTO reward consumes neither currency nor shop inventory")
	check(not game.claim_review_reward(6), "A reward cannot be claimed twice")
	game.load_world()
	game.player = game.merchant_position + Vector2(36, 0)
	game.state = "merchant"
	check(not game.start_review(), "Reloading does not reset a completed visit's reward")
	game.elapsed = 9 * Data.DAY_SECONDS
	game.refresh_merchant()
	check(game.start_review(), "The next five-day visit opens a fresh review challenge")
	game.update_review(61.0)
	check(game.state == "review_failed" and not game.review_reward_pending, "Running out of time grants no reward")
	game.start_review()
	first = 0
	mismatch = 1
	while game.review_cards[mismatch] == game.review_cards[first]:
		mismatch += 1
	for turn in range(Data.REVIEW_MAX_TURNS):
		game.flip_review(first)
		game.flip_review(mismatch)
		game.update_review(0.71)
	check(game.state == "review_failed" and game.review_turns == 16, "Sixteen unsuccessful turns end the challenge")
	game.start_review()
	first = 0
	mismatch = 1
	while game.review_cards[mismatch] == game.review_cards[first]:
		mismatch += 1
	for turn in range(6):
		game.flip_review(first)
		game.flip_review(mismatch)
		game.update_review(0.71)
	solve_review()
	check(game.review_turns == 16 and game.state == "review_reward", "Ten correct matches plus six mistakes can still pass on the final allowed turn")
	check(game.save_world() and game.load_world() and game.review_reward_pending, "An unclaimed victory reward survives closing and loading the game")
	game.player = game.merchant_position + Vector2(36, 0)
	game.state = "merchant"
	check(game.start_review() and game.state == "review_reward", "Returning to the shop restores the pending reward choice")
	check(not game.claim_review_reward(6) and game.review_reward_pending, "An already owned unique reward does not consume the pending choice")
	var before: Dictionary = game.inventory.duplicate()
	game.reject_saves = true
	check(not game.claim_review_reward(1) and game.inventory == before and game.review_reward_pending, "Failed reward saves roll back the item while preserving the earned choice")
	game.reject_saves = false
	var potions: int = game.count_item("potion")
	check(game.claim_review_reward(1) and game.count_item("potion") == potions + 1, "The earned reward can be retried after storage recovers")

func test_visit_clock_and_legacy_save() -> void:
	game.start_world(101)
	game.elapsed = (4.0 - 0.32) * Data.DAY_SECONDS - 0.01
	game.refresh_merchant()
	check(not game.merchant_present and game.merchant_info.next_day == 5, "The merchant is absent just before game day five")
	game._physics_process(0.02)
	check(game.merchant_present and game.merchant_visit == 5, "Crossing into day five automatically brings the merchant")
	var clock: float = game.elapsed
	game.set_state("paused")
	game._physics_process(10000)
	check(game.elapsed == clock and game.merchant_present, "Paused time does not advance visits or departure")
	game.set_state("playing")
	game.elapsed = (5.0 - 0.32) * Data.DAY_SECONDS - 0.01
	game._physics_process(0.02)
	check(not game.merchant_present and game.merchant_info.next_day == 10, "Day six automatically ends the one-day visit")
	game.start_world(101)
	var legacy: Dictionary = game.read_save(PATH)
	legacy.erase("merchant_visit")
	legacy.erase("review_completed_visit")
	legacy.erase("review_reward_pending")
	legacy["merchant_week"] = "2026-11-13"
	write_variant(PATH, legacy)
	check(game.load_world() and not game.merchant_present and game.merchant_visit == 0, "Previous real-calendar saves migrate to the new game-day schedule")
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.save_world()
	var merchant_home: Vector2 = game.merchant_position
	var merchant_column: int = game.cell_at(merchant_home).x
	for y in range(55, 95):
		game.world.set_tile(Vector2i(merchant_column, y), Data.Block.AIR)
	game.refresh_merchant()
	check(game.merchant_position != merchant_home, "Excavation moves the merchant to nearby safe ground")
	check(game.load_world() and game.merchant_position.distance_to(merchant_home) < 0.1, "Loading restored terrain invalidates the cached merchant position")

func test_review_ui() -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.start_world(302)
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.player = game.merchant_position + Vector2(36, 0)
	send_key(KEY_E)
	await redraw()
	mouse(Vector2(1040, 128), MOUSE_BUTTON_LEFT, true)
	mouse(Vector2(1040, 128), MOUSE_BUTTON_LEFT, false)
	await redraw()
	check(game.state == "review" and game.ui.buttons.size() == 21, "The visible shop button opens twenty clickable review cards plus return")
	for pair in range(Data.REVIEW_PAIRS.size()):
		for index in [game.review_cards.find(pair), game.review_cards.rfind(pair)]:
			var p := Vector2(193 + index % 5 * 142, 217 + index / 5 * 103)
			mouse(p, MOUSE_BUTTON_LEFT, true)
			mouse(p, MOUSE_BUTTON_LEFT, false)
	await redraw()
	check(game.state == "review_reward", "Clicking all visible matching pairs opens the reward screen")
	mouse(Vector2(730, 522), MOUSE_BUTTON_LEFT, true)
	mouse(Vector2(730, 522), MOUSE_BUTTON_LEFT, false)
	check(game.count_item("lantern") == 1 and not game.review_reward_pending and game.state == "merchant", "Clicking a visible reward grants the chosen item and returns to trade")

func test_confirmation_hit_targets() -> void:
	game.state = "confirm"
	game.ui.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		check(game.ui.buttons.size() == 2, "New-world confirmation exposes only its two visible buttons")
		check(not game.ui.click(Vector2(200, 560)), "Clicking through the confirmation cannot activate the hidden mode-exit button")
	game.state = "playing"

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tools")
	game = SandboxFixture.new()
	game.save_path = PATH
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	test_backup_survives_recovery()
	test_respawn_avoids_dug_shaft()
	test_death_load()
	test_failed_trade()
	test_bad_save_fields()
	test_day_boundary_and_occupied_tiles()
	await test_confirmation_hit_targets()
	await test_player_input_flow()
	test_code_review()
	test_visit_clock_and_legacy_save()
	await test_review_ui()
	for suffix in ["", ".bak", ".tmp", ".invalid"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	game.queue_free()
	await process_frame
	print("SANDBOX REGRESSIONS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
