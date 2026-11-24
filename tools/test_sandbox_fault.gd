extends SceneTree
const Data = preload("res://scripts/sandbox_data.gd")
const Fault = preload("res://scripts/sandbox_fault.gd")
const Sandbox = preload("res://scripts/sandbox_run.gd")

class Fixture:
	extends Sandbox
	var reject_saves: bool = false
	func save_world() -> bool:
		return false if reject_saves else super.save_world()

var game: Node
var checks: int = 0
var failures: int = 0
var save_path: String = "res://.tools/fault-test.save"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func kill_player() -> void:
	game.hurt_time = 0.0
	game.hurt(game.max_health() + 100.0, game.player + Vector2.LEFT)

func finish_death() -> void:
	game._physics_process(Fault.REVIVE_SECONDS + 0.02)

func finish_transition() -> void:
	game._physics_process(Fault.TRANSITION_END - game.fault.transition_time + 0.01)

func test_first_death() -> void:
	game.start_world(808)
	check(not game.fault.keeper_unlocked and not game.fault.keeper_site.is_finite(), "New world has no Fire Keeper before the first death")
	var fell_at: Vector2 = game.player
	kill_player()
	check(game.state == "dead" and game.health == 0 and game.fault.leaks == 1 and game.fault.revivals == 0, "First lethal hit records one leak and starts the resurrection")
	check(game.fault.death_actor_position().distance_to(fell_at) < 40, "The Fire Keeper appears beside the fallen hero")
	game.hurt(game.max_health(), game.player)
	check(game.fault.leaks == 1, "Extra lethal damage during the scene cannot record a second death")
	check(game.load_world() and game.state == "dead" and game.fault.pending, "A saved pending resurrection resumes after loading")
	game._physics_process(0.3)
	check(game.state == "dead", "The grave scene is visible before revival")
	finish_death()
	check(game.state == "playing" and game.health == game.max_health() and game.player.distance_to(fell_at) < 1, "The Fire Keeper restores life at a safe death position")
	check(game.fault.revivals == 1 and game.fault.keeper_site.distance_to(game.world.spawn) < 160, "After revival the keeper moves to the home area")
	check(not game.fault.active and game.load_world() and game.fault.revivals == 1, "Revival progress persists in the ordinary world")

func test_daily_heal() -> void:
	var now: int = game.day_number()
	game.player = game.fault.keeper_site
	game.interact()
	check(game.state == "fire_keeper", "Interact opens the home healing service")
	check(not game.fault.heal_at_home() and game.fault.last_heal_day == 0, "Full health does not use the daily heal")
	game.health = 20
	game.reject_saves = true
	check(not game.fault.heal_at_home() and game.health == 20 and game.fault.last_heal_day == 0, "Failed save does not spend the healing service")
	game.reject_saves = false
	check(game.fault.heal_at_home() and game.health == game.max_health() and game.fault.last_heal_day == now, "First heal restores full health and records the game day")
	check(game.load_world(), "Load after using healing")
	game.health = 15
	game.player = game.fault.keeper_site
	game.interact()
	check(not game.fault.heal_at_home() and game.health == 15, "The same game day stays used after loading")
	game.set_state("playing")
	game.elapsed += Data.DAY_SECONDS
	game.interact()
	check(game.fault.heal_at_home() and game.fault.last_heal_day == now + 1, "The next game day refreshes the service")
	game.health = 40
	game.set_state("recall")
	var revivals: int = game.fault.revivals
	game.recall_home()
	check(game.health == 40 and game.fault.revivals == revivals, "Recall neither heals nor counts as a death or revival")

func advance_to_fault() -> void:
	while game.fault.revivals < Fault.LIMIT:
		var before: int = game.fault.revivals
		kill_player()
		if game.state != "dead":
			check(false, "Expected a death state")
			return
		check(game.fault.leaks == before + 1 and not game.fault.active, "The threshold is reached on the tenth completed revival")
		if before == Fault.LIMIT - 1:
			check(game.load_world() and not game.fault.active and game.merchant_present, "Loading the tenth pending death preserves timing and normal merchant")
		finish_death()
	check(game.state == "fault_transition" and game.fault.transition_kind == "enter" and not game.fault.active, "The tenth revival starts an entrance without replacing the visible world")
	check(game.fault.revivals == Fault.LIMIT and not game.fault.pending, "The completed revival counts exactly once")

func try_transition_inputs() -> void:
	for code in [KEY_F5, KEY_E, KEY_J, KEY_TAB, KEY_ESCAPE, KEY_R, KEY_2]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		root.push_input(key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(640, 383)
	mouse.pressed = true
	root.push_input(mouse, true)
	var controller := InputEventJoypadButton.new()
	controller.device = 11
	controller.button_index = JOY_BUTTON_A
	controller.pressed = true
	root.push_input(controller)
	check(game.state == "fault_transition" and not game.left_held and not game.right_held, "Keyboard, mouse and gamepad cannot click through or interrupt the transition")

func test_fault_entry_and_priest() -> void:
	game.elapsed = 4 * Data.DAY_SECONDS
	game.refresh_merchant()
	game.merchant_stock[0] -= 1
	var stock: Array = game.merchant_stock.duplicate()
	var tile: Vector2i = game.cell_at(game.world.spawn) + Vector2i(2, -4)
	game.world.set_tile(tile, Data.Block.PLANK)
	game.inventory.stone = 55
	game.adventure.event = "故障入侵"
	game.adventure.event_kills = 4
	advance_to_fault()
	var world_time: float = game.elapsed
	var position: Vector2 = game.player
	var selection: int = game.selected
	try_transition_inputs()
	game._physics_process(Fault.TRANSITION_CUT - 0.01)
	check(game.elapsed == world_time and game.player == position and selection == game.selected, "Gameplay, calendar and slot selection stay frozen")
	check(not game.save_world() and game.read_save(save_path).fault.pending, "Saving during the closing phase preserves the valid pending-death save")
	check(not game.fault.active and game.merchant_present, "The surface world and its merchant remain until the concealed cut")
	game._physics_process(0.02)
	check(game.fault.active and game.state == "fault_transition" and game.read_save(save_path).fault.active, "At the cut the fault world is installed and saved while input stays locked")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	finish_transition()
	check(game.state == "paused" and game.fault.transition_kind.is_empty(), "Losing focus during entry leaves the game paused when the reveal ends")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(not game.merchant_present and not game.can_trade(), "The scheduled CTO merchant is hidden during the fault")
	check(game.merchant_stock == stock and game.world.tile(tile) == Data.Block.PLANK and game.count_item("stone") == 55, "Entry preserves stock, buildings and inventory")
	check(game.fault.priest_site.distance_to(game.fault.ape_site) > 600, "The two exits are separated by exploration")
	check(game.load_world() and game.fault.active and not game.merchant_present, "The transformed world and hidden shop survive loading")
	check(game.adventure.event_kills == 4 and not game.adventure.summon_reason(0).is_empty(), "The fault does not replace normal adventure progress or allow a competing boss")
	game.interact()
	check(game.state != "fault_priest", "Cannot purge from the home area")
	game.set_state("playing")
	game.player = game.fault.priest_site
	game.interact()
	check(game.state == "fault_priest", "The missing priest has an interactable position in the fog")
	check(game.fault.priest_purge() and game.fault.active and game.fault.transition_kind == "priest", "The priest starts his own exit animation while the fault is still visible")
	try_transition_inputs()
	check(not game.fault.priest_purge(), "The same interaction cannot restart the exit animation")
	game._physics_process(Fault.TRANSITION_CUT + 0.01)
	check(not game.fault.active and game.fault.leaks == 0 and game.fault.revivals == 0, "The priest restores the normal world and clears this leak cycle")
	check(game.merchant_present and game.merchant_stock == stock, "Returning on a visit day restores the same merchant stock")
	finish_transition()
	check(game.state == "fault_resolved", "The return message waits until the animation has revealed the surface")
	check(game.load_world() and game.fault.keeper_unlocked and not game.fault.active, "The exit saves and retains the Fire Keeper")

func test_fault_enemies_and_ape() -> void:
	advance_to_fault()
	check(game.save_before_exit() and game.fault.active and game.read_save(save_path).fault.active, "Closing the window before the entry cut saves the completed trip without losing a revival")
	check(game.load_world() and game.fault.transition_kind.is_empty(), "Loading after an early close restores the destination without replaying the animation")
	check(game.fault.cycles == 2 and game.fault.active, "A second cycle can enter after the first was cleared")
	game.rng.seed = 891
	game.player = game.safe_spawn()
	var kinds: Dictionary = {}
	for i in range(100):
		game.enemies.clear()
		game.spawn_enemy()
		if game.enemies.is_empty():
			continue
		var enemy: Dictionary = game.enemies[0]
		kinds[enemy.kind] = true
		if not Fault.ENEMIES.has(enemy.kind) or enemy.max_hp <= Fault.ENEMIES[enemy.kind].hp:
			check(false, "Fault enemies must come from the transformed, strengthened pool")
	check(kinds.size() == Fault.ENEMIES.size(), "Normal spawns are replaced by zombies and all four aberrations")
	game.enemies.clear()
	game.player = game.fault.ape_site
	game.fault.tick(2.1)
	var ape: Dictionary = game.adventure.current_boss()
	check(ape.get("kind", "") == Fault.BOSS_ID and ape.hp == game.fault.boss_max_hp, "Approaching the cleared path reveals the independent boss")
	if ape.is_empty():
		return
	var expected: Array[String] = ["pounce", "quake", "howl"]
	for phase in range(expected.size()):
		game.adventure.shots.clear()
		game.adventure.hazards.clear()
		ape.attack = phase
		game.fault.begin_attack(ape, ape.p + Vector2(118, -28), ape.p - Vector2(0, 51), false)
		var frame: int = 4 + phase * 4
		check(ape.fault_attack == expected[phase] and game.fault.enemy_frame(ape) == frame, "Each ape attack selects its own windup frames")
		game.fault.update_enemy(ape, float(ape.windup) + 0.001)
		check(game.fault.enemy_frame(ape) == frame + 2, "Attack release selects the matching strike frames")
		match expected[phase]:
			"pounce": check(absf(ape.v.x) > 0 or ape.fault_strike > 0, "Pounce starts its active lunge")
			"quake": check(game.adventure.hazards.size() == 3, "Quake creates distinct ground impacts")
			"howl": check(game.adventure.shots.size() == 5, "Howl fires a telegraphed fan")
	game.adventure.damage_enemy(ape, 60.0, game.player)
	var wounded: float = ape.hp
	check(wounded == game.fault.boss_hp and game.save_world() and game.load_world(), "A wounded ape saves its remaining life")
	game.player = game.fault.ape_site
	game.fault.tick(0.02)
	ape = game.adventure.current_boss()
	check(not ape.is_empty() and ape.hp == wounded, "Reload does not restore the fought boss to full health")
	if ape.is_empty():
		return
	kill_player()
	check(game.fault.active and game.fault.leaks == Fault.LIMIT + 1, "A death inside the fault records one leak and keeps the same world")
	finish_death()
	game.player = game.fault.ape_site
	game.fault.tick(0.02)
	ape = game.adventure.current_boss()
	check(not ape.is_empty() and ape.hp == wounded and game.fault.cycles == 2, "Reviving inside the fault preserves the wounded boss and current cycle")
	if ape.is_empty():
		return
	var before: int = game.adventure.stage()
	var coins: int = game.count_item("coin")
	ape.hp = 1.0
	game.fault.boss_hp = 1.0
	var witness: Dictionary = game.adventure.spawn("fault_zombie", ape.p, -1, Fault.ENEMIES.fault_zombie)
	game.player = ape.p - Vector2(12, 0)
	game.facing = 1
	game.attack()
	check(game.state == "fault_transition" and game.fault.active and game.fault.transition_kind == "ape", "A killing blow starts the ape exit with its own presentation")
	check(witness.hp == witness.max_hp and game.count_item("coin") == coins, "The killing swing cannot keep dealing damage or grant the reward before the cut")
	game.pad.active = true
	game.pad.device = 11
	game.reject_saves = true
	check(not game.save_before_exit() and game.state == "fault_transition" and not game.fault.active, "If a close cannot save, the applied transition remains playable")
	check(game.pad.rumble_pattern == game.pad.RUMBLE.victory, "Resetting fault combat cannot cancel the victory vibration")
	game.reject_saves = false
	check(game.save_before_exit() and game.read_save(save_path).inventory.coin == coins + 120, "Retrying a close saves the victory once")
	finish_transition()
	check(game.state == "fault_resolved" and not game.fault.active and game.fault.leaks == 0, "Defeating the ape exits by the second route")
	check(game.adventure.stage() == before and game.count_item("coin") == coins + 120, "Ape rewards are independent of the eight normal bosses")
	check(game.load_world() and not game.fault.active and game.count_item("coin") == coins + 120, "The boss exit persists without duplicating the reward")

func test_save_validation() -> void:
	var saved: Dictionary = game.fault.save_data()
	saved.leaks = 12
	check(not game.fault.valid_save(saved, game.health, game.day_number()), "Reject impossible death and revival counters")
	saved = game.fault.save_data()
	saved.heal_day = game.day_number() + 1
	check(not game.fault.valid_save(saved, game.health, game.day_number()), "Reject healing from a future day")
	var old: Dictionary = game.read_save(save_path)
	old.erase("fault")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(old)
	file.close()
	check(game.load_world() and not game.fault.keeper_unlocked and not game.fault.active, "A previous-version save loads with a fresh cycle")

func test_keeper_follows_bed() -> void:
	game.start_world(299)
	kill_player()
	finish_death()
	var at := Vector2i(318, 109)
	var structures = game.adventure.structures
	for dy in range(-6, 1):
		for dx in range(-5, 6):
			var cell: Vector2i = at + Vector2i(dx, dy)
			var boundary: bool = abs(dx) == 5 or dy in [-6, 0]
			game.world.set_tile(cell, Data.Block.PLANK if boundary else Data.Block.AIR)
			structures.walls[structures.index(cell)] = 1
	structures.install_door(at + Vector2i(5, -1))
	game.world.set_tile(at + Vector2i(-2, -1), Data.Block.BENCH)
	game.world.set_tile(at + Vector2i(2, -1), Data.Block.CHAIR)
	game.world.set_tile(at + Vector2i(-4, -3), Data.Block.TORCH)
	game.world.set_tile(at + Vector2i(0, -1), Data.Block.BED)
	game.player = Vector2(at) * Data.TILE + Vector2(12, -0.01)
	game.interact()
	var bed_site: Vector2 = game.world.spawn
	check(bed_site.distance_to(game.player) < 24 and game.fault.keeper_site.distance_to(bed_site) < 100, "Making a basement bed the home moves the keeper inside its room")
	check(game.save_world() and game.load_world() and game.fault.keeper_site.distance_to(bed_site) < 100, "The keeper stays at the new home after loading")
	game.player = game.fault.keeper_site
	game.health = 15.0
	game.interact()
	check(game.state == "fire_keeper" and game.fault.heal_at_home(), "The relocated NPC can heal inside the house")

func test_exportable_art() -> void:
	var view = game.view.fault_view
	for key in ["keeper", "zombie", "eye", "hands", "mimic", "chroma", "ape"]:
		var atlas = view.atlas_for(key)
		var image: Image = atlas.texture.get_image()
		var count: int = 16 if key == "ape" else 8
		check(image.get_size() == Vector2i(512, count / 4 * 128) and atlas.frames.size() == count, key + " has the expected atlas layout")
		var isolated: bool = true
		for i in range(count):
			var cel: Image = image.get_region(Rect2i(atlas.frames[i].region))
			var bounds: Rect2i = cel.get_used_rect()
			var cell_bounds := Rect2i(1, 1, 126, 126)
			isolated = isolated and cell_bounds.encloses(bounds) and bounds.size.y > 20
		check(isolated, key + " has transparent borders and a visible subject in every cel")
	for path in ["flesh.png", "horizon.png", "fog.png"]:
		check(load(view.ASSETS + path) is Texture2D, path + " can be loaded by the game")
	view.build_membrane()
	var repeat: Image = view.membrane
	var length: int = repeat.get_width()
	var seams: bool = true
	for offset in range(length):
		seams = seams and repeat.get_pixel(0, offset) == repeat.get_pixel(length - 1, offset)
		seams = seams and repeat.get_pixel(offset, 0) == repeat.get_pixel(offset, length - 1)
	check(seams, "The fleshy wall tiles meet at both repeated edges")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-save="):
			save_path = argument.trim_prefix("--test-save=")
	game = Fixture.new()
	game.save_path = save_path
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	test_first_death()
	test_daily_heal()
	test_fault_entry_and_priest()
	test_fault_enemies_and_ape()
	test_save_validation()
	test_keeper_follows_bed()
	test_exportable_art()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	game.queue_free()
	await process_frame
	print("SANDBOX SYSTEM FAULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
