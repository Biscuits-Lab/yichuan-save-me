extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func snap(label: String) -> Image:
	if not game.rooms.is_empty():
		game.camera_snap()
	game.view.queue_redraw()
	game.view.overlay.queue_redraw()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var captured: Image = root.get_texture().get_image()
	var error: Error = captured.save_png("res://output/previews/" + label + ".png")
	print("PREVIEW ", label, " ", error)
	assert(error == OK, "Preview must save successfully")
	return captured

func service_room(kind: String) -> void:
	for candidate in range(1, 121):
		var generated: Dictionary = game.Data.generate(candidate, 0)
		for room in generated.rooms:
			if room.type == kind:
				game.seed_value = candidate
				game.floor_index = 0
				game.generate_floor()
				game.enter_room(room.id)
				return
	push_error("No service preview seed found")

func door_preview(direction: int) -> void:
	game.state = "playing"
	game.current_room().cleared = true
	game.enemies.clear()
	for room in game.rooms:
		if room.links[direction] >= 0:
			game.enter_room(room.id)
			break
	game.current_room().cleared = true
	game.enemies.clear()
	game.effects.clear()
	game.texts.clear()
	game.speech_time = 0
	game.message_time = 0
	game.player = game.current_room().doors[direction]
	await snap("dungeon-passages-%d" % direction)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/dungeon-preview-record.json"
	game.set_physics_process(false)
	await snap("dungeon-01-title")
	game.start_run(20261113)
	await snap("dungeon-02-story")
	game.state = "playing"
	for room in game.rooms:
		if room.type == "combat":
			game.enter_room(room.id)
			break
	game.add_item("pistol")
	game.add_item("wand", 2)
	game.add_item("vest")
	game.add_item("coffee")
	game.player = game.room_center() + Vector2(-100, 82)
	game.invulnerable = 0
	game.knight_active = true
	game.knight = game.player + Vector2(86, 36)
	var index: int = 0
	for enemy in game.enemies:
		enemy.age = 2
		enemy.p = game.room_center() + Vector2.from_angle(index * 1.1) * 210
		index += 1
	game.update_weapons(0.2)
	game.update_projectiles(0.06)
	game.add_effect("slash", game.player, game.player + Vector2(100, 0), Color.WHITE, 0.3, 115)
	game.effects[-1].life = 0.18
	game.add_effect("impact", game.player + Vector2(130, -18), game.player, Color.WHITE, 0.3, 70)
	game.effects[-1].life = 0.16
	await snap("dungeon-03-battle")
	for enemy in game.enemies.duplicate():
		game.hit_enemy(enemy, 100000, game.player)
	game.wave = game.wave_total
	game.clear_room()
	game.texts.clear()
	game.effects.clear()
	service_room("shop")
	game.open_shop()
	game.points = 126
	await snap("dungeon-04-shop")
	assert(game.view.overlay.buttons.any(func(entry: Dictionary) -> bool: return entry.action == "refresh"), "Dedicated shops retain the refresh button")
	game.add_item("blade")
	game.add_item("vest")
	game.toggle_inventory()
	await snap("dungeon-05-fusion")
	game.state = "playing"
	game.current_room().cleared = true
	service_room("npc")
	game.current_room().npc = 3
	game.player = game.npc_position() + Vector2(86, 30)
	game.state = "playing"
	game.knight_active = false
	await snap("dungeon-06a-basan-world")
	game.selected_npc = 3
	game.state = "npc"
	await snap("dungeon-06b-basan")
	game.current_room().npc = 6
	game.selected_npc = 6
	game.state = "npc"
	await snap("dungeon-06-npc")
	game.current_room().npc = 7
	game.selected_npc = 7
	await snap("dungeon-06c-jiahao")
	game.floor_index = game.Data.FLOOR_COUNT - 1
	game.generate_floor()
	for room in game.rooms:
		room.revealed = true
	game.current_room().cleared = true
	for room in game.rooms:
		if room.type == "boss":
			game.enter_room(room.id)
			break
	game.player = game.room_center() + Vector2(-170, 70)
	game.invulnerable = 0
	game.enemies[0].age = 2
	game.enemies[0].windup = 0.7
	game.enemies[0].aim = Vector2.LEFT
	await snap("dungeon-07-yang-boss")
	game.current_room().cleared = true
	game.enemies.clear()
	for room in game.rooms:
		if room.type == "elite":
			game.enter_room(room.id)
			break
	game.enemies.clear()
	game.spawn_remaining = 0
	game.current_room().elite_kind = "shark"
	game.wave = game.wave_total - 1
	game.spawn_wave()
	game.player = game.room_center() + Vector2(-160, 60)
	game.enemies[0].p = game.room_center() + Vector2(185, 0)
	game.enemies[0].age = 2
	game.enemies[0].windup = 0.7
	game.enemies[0].aim = (game.player - game.enemies[0].p).normalized()
	await snap("dungeon-07b-big-shark")
	game.hit_enemy(game.enemies[0], 100000, game.player)
	for i in range(46):
		game._physics_process(1.0 / 60.0)
	game.texts.clear()
	game.effects.clear()
	game.points = 200
	await snap("dungeon-13-boss-shop")
	for i in range(4):
		game.buy(i)
	await snap("dungeon-14-shop-sold-out")
	assert(not game.refresh_shop(), "Sold-out combat supplies cannot refresh")
	await snap("dungeon-15-supply-final-stock")
	game.floor_index = 0
	game.generate_floor()
	for room in game.rooms:
		if room.type == "boss":
			game.enter_room(room.id)
			break
	game.hit_enemy(game.enemies[0], 100000, game.player)
	for i in range(46):
		game._physics_process(1.0 / 60.0)
	game.texts.clear()
	game.effects.clear()
	await snap("dungeon-16-floor-skills")
	game.floor_index = 0
	game.generate_floor()
	game.invulnerable = 0
	await snap("dungeon-08-office")
	var hall: Dictionary = game.corridors[0]
	game.player = hall.rect.get_center()
	game.speech_time = 0
	game.message_time = 0
	await snap("dungeon-10-corridor")
	game.current_room().cleared = true
	for room in game.rooms:
		if room.type == "combat" and room.rect.size.x > 1000:
			game.enter_room(room.id)
			break
	game.invulnerable = 999
	game.player = game.room_center() + Vector2(-300, 0)
	await snap("dungeon-11-camera-west")
	game.player = game.room_center() + Vector2(300, 0)
	await snap("dungeon-12-camera-east")
	for direction in range(4):
		await door_preview(direction)
	game.floor_index = 2
	game.generate_floor()
	var compact_room: int = -1
	for room in game.rooms:
		if room.type == "combat" and (compact_room < 0 or room.rect.get_area() < game.rooms[compact_room].rect.get_area()):
			compact_room = room.id
	game.enter_room(compact_room)
	game.enemies.clear()
	game.spawn_wave()
	for enemy in game.enemies:
		enemy.age = 2
	game.speech_time = 0
	game.message_time = 0
	await snap("dungeon-17-compact-battle")
	game.start_run(20261114, true)
	for spec in game.Data.EQUIPMENT:
		for tier in range(1, 5):
			for copy in range(8):
				game.add_item(spec.id, tier)
	game.toggle_inventory()
	await snap("dungeon-18-equipment-stacks")
	var right_click := InputEventMouseButton.new()
	right_click.pressed = true
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.position = game.view.overlay.item_slots.filter(func(slot: Dictionary) -> bool: return slot.kind == "weapon")[0].rect.get_center()
	game._unhandled_input(right_click)
	await snap("dungeon-18a-last-weapon-menu")
	assert(game.view.overlay.buttons.all(func(entry: Dictionary) -> bool: return entry.action != "menu_sell"), "Last weapon must not have an enabled sale action")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game._unhandled_input(escape)
	assert(game.state == "inventory" and game.view.overlay.item_context.is_empty(), "Escape closes the context menu before the inventory")
	game.view.click(game.view.overlay.buttons.filter(func(entry: Dictionary) -> bool: return entry.action == "equipment_page" and entry.index == 1)[0].rect.get_center())
	assert(game.view.overlay.equipment_page == 1, "Equipment next-page button must work")
	await snap("dungeon-19-equipment-page-two")
	var hover := InputEventMouseMotion.new()
	hover.position = game.view.overlay.item_slots.filter(func(slot: Dictionary) -> bool: return slot.kind == "equipment")[0].rect.get_center()
	hover.global_position = hover.position
	root.push_input(hover)
	await snap("dungeon-19a-equipment-details")
	assert(game.view.overlay.pointer_position == hover.position, "Mouse motion must reach the inventory hover logic")
	var count_before: int = game.equipment_count()
	game.view.right_click(hover.position)
	await snap("dungeon-19b-equipment-context")
	game.view.click(game.view.overlay.buttons.filter(func(entry: Dictionary) -> bool: return entry.action == "menu_sell")[0].rect.get_center())
	assert(game.equipment_count() == count_before - 1, "Paged sale button must consume exactly one copy")
	await snap("dungeon-19c-after-sale")
	game.view.right_click(hover.position)
	await snap("dungeon-19d-fusion-menu")
	game.view.click(game.view.overlay.buttons.filter(func(entry: Dictionary) -> bool: return entry.action == "menu_fuse")[0].rect.get_center())
	assert(game.equipment_count() == count_before - 2, "Context fusion consumes two copies and grants one upgrade")
	for skill in game.Data.SKILLS:
		game.skill_levels[skill.id] = 2
	game.view.move_pointer(Vector2(700, 120))
	game.view.click(game.view.overlay.buttons.filter(func(entry: Dictionary) -> bool: return entry.action == "inventory_tab" and entry.index == 1)[0].rect.get_center())
	await snap("dungeon-19e-character-details")
	assert(game.view.overlay.inventory_tab == 1 and game.view.overlay.item_slots.is_empty() and game.view.overlay.item_context.is_empty(), "Character page hides item slots and stale item interactions")
	var frozen: Vector2 = game.player
	var frozen_time: float = game.run_time
	game._physics_process(0.5)
	assert(game.player == frozen and game.run_time == frozen_time, "Character attributes keep the game paused")
	game.view.click(game.view.overlay.buttons.filter(func(entry: Dictionary) -> bool: return entry.action == "inventory_tab" and entry.index == 0)[0].rect.get_center())
	await snap("dungeon-19f-backpack-return")
	assert(game.view.overlay.inventory_tab == 0 and game.view.overlay.equipment_page == 1 and not game.view.overlay.item_slots.is_empty(), "Returning to the backpack retains its page and item controls")
	game.toggle_inventory()
	game.current_room().type = "combat"
	game.current_room().cleared = false
	game.clear_room()
	await snap("dungeon-20-one-time-supplies")
	assert(game.view.overlay.buttons.all(func(entry: Dictionary) -> bool: return entry.action != "refresh"), "Combat supply UI offers no refresh action")
	game.view.click(Vector2(1024, 571))
	assert(game.state == "playing" and not game.has_shop(), "Closing supplies must permanently finish the visit")
	game.player = game.room_center()
	game.interact()
	await snap("dungeon-21-no-supply-entrance")
	for floor_number in range(game.Data.FLOOR_COUNT):
		game.floor_index = floor_number
		game.generate_floor()
		for room in game.rooms:
			if room.type == "boss":
				game.enter_room(room.id)
				break
		game.player = game.room_center() + Vector2(-190, 60)
		var boss: Dictionary = game.enemies[0]
		boss.p = game.room_center() + Vector2(70, 40)
		boss.age = 2
		boss.aim = (game.player - boss.p).normalized()
		boss.phase = 1
		boss.attack = 5
		game.boss_attack(boss)
		game.update_projectiles(0.45)
		await snap("dungeon-22-floor-%d-boss" % (floor_number + 1))
		if game.Data.FLOOR_STYLES[floor_number] == "sumo":
			game.projectiles.clear()
			game.effects.clear()
			boss.charge = 0
			boss.attack = 2
			boss.windup = 0.6
			await snap("dungeon-32-yamada-stomp-warning")
			boss.windup = 0
			boss.attack = 0
			game.boss_attack(boss)
			await snap("dungeon-33-yamada-charge")
		if game.Data.FLOOR_STYLES[floor_number] == "wilds":
			for terrain in ["forest", "grassland"]:
				game.current_room().cleared = true
				game.enemies.clear()
				for room in game.rooms:
					if room.type == "combat" and room.terrain == terrain:
						game.enter_room(room.id)
						break
				game.player = game.room_center() + Vector2(-110, 80)
				game.effects.clear()
				game.projectiles.clear()
				game.enemies.clear()
				for kind in ["wolf", "ropehead", "wolf", "ropehead"]:
					var i: int = game.enemies.size()
					var enemy: Dictionary = game.spawn_enemy(game.room_center() + Vector2(-150 + i * 100, -60), kind)
					if not game.walkable(enemy.p, enemy.radius):
						enemy.p = game.room_center() + Vector2(-150 + i * 100, 0)
					enemy.age = 2
				game.message_time = 0
				game.speech_time = 0
				await snap("dungeon-34-wilds-" + terrain)
			game.enemies.clear()
			game.projectiles.clear()
			var baola: Dictionary = game.spawn_enemy(game.room_center() + Vector2(160, 0), "baola")
			baola.age = 2
			baola.windup = 0.6
			baola.aim = Vector2.LEFT
			await snap("dungeon-35-baola-pounce")
	game.floor_index = 0
	game.generate_floor()
	for room in game.rooms:
		if room.type == "combat":
			game.enter_room(room.id)
			break
	game.enemies.clear()
	game.player = game.room_center() + Vector2(-160, 70)
	for kind in ["slime", "splitter", "minislime", "dasher", "charger", "ranged"]:
		var i: int = game.enemies.size()
		var enemy: Dictionary = game.spawn_enemy(game.room_center() + Vector2(-160 + i * 90, -60), kind)
		enemy.age = 2
		if kind == "dasher":
			enemy.windup = 0.35
			enemy.aim = (game.player - enemy.p).normalized()
	await snap("dungeon-23-enemy-variety")
	game.start_run(20261114, true)
	for room in game.rooms:
		if room.type == "treasure":
			game.enter_room(room.id)
			break
	game.player = game.room_center()
	game.interact()
	assert(game.state == "treasure" and not game.current_room().used, "Chest must preview its rewards before equipping")
	await snap("dungeon-24-chest-cards")
	game.view.click(Vector2(350, 590))
	assert(game.state == "playing" and game.current_room().used and game.weapons.size() == 1, "Chest abandon button must skip the reward")
	for room in game.rooms:
		if room.type == "elite":
			game.enter_room(room.id)
			break
	game.enemies.clear()
	game.spawn_remaining = 0
	for kind in ["brood", "warden"]:
		game.enemies.clear()
		game.projectiles.clear()
		game.player = game.room_center() + Vector2(-170, 70)
		var elite: Dictionary = game.spawn_enemy(game.room_center() + Vector2(140, 0), kind)
		elite.age = 2
		elite.phase = 1
		elite.aim = (game.player - elite.p).normalized()
		game.boss_attack(elite)
		game.update_projectiles(0.4)
		await snap("dungeon-25-elite-" + kind)
	game.start_run(20261114, true)
	for id in ["sniper", "wand"]:
		game.add_item(id, 2)
	for id in ["medkit", "heart", "coffee", "wrist_rest", "headphones", "sticky", "crit_lens", "prism", "feather", "glass_trophy", "all_nighter", "triple_espresso"]:
		game.add_item(id, 3)
	game.view.move_pointer(Vector2(700, 120))
	game.toggle_inventory()
	await snap("dungeon-26-office-build")
	assert(game.view.overlay.item_slots.all(func(slot: Dictionary) -> bool: return slot.rect.size == Vector2(64, 64) and Rect2(224, 100, 832, 520).encloses(slot.rect)), "Inventory cards must be small squares inside the compact panel")
	game.view.move_pointer(game.view.overlay.item_slots.filter(func(slot: Dictionary) -> bool: return slot.entry.id == "glass_trophy")[0].rect.get_center())
	await snap("dungeon-27-risky-item")
	game.view.move_pointer(game.view.overlay.item_slots.filter(func(slot: Dictionary) -> bool: return slot.entry.id == "sniper")[0].rect.get_center())
	await snap("dungeon-28-specialized-weapon")
	game.toggle_inventory()
	game.current_room().type = "shop"
	game.cleared_count = 10
	game.floor_index = 1
	game.open_shop()
	game.stock.assign([{"id":"glass_trophy", "tier":1, "sold":false}, {"id":"all_nighter", "tier":2, "sold":false}, {"id":"firestaff", "tier":1, "sold":false}, {"id":"medkit", "tier":1, "sold":false}])
	await snap("dungeon-29-mixed-office-shop")
	assert(game.audio.samples.kill.save_to_wav("res://output/previews/kill-preview.wav") == OK, "Kill sound preview must export")
	game.start_run(20261114, true)
	game.weapons.clear()
	for spec in game.Data.WEAPONS.slice(6, 12):
		game.add_item(spec.id)
	for spec in game.Data.EQUIPMENT:
		game.add_item(spec.id)
	game.view.move_pointer(Vector2(700, 120))
	game.toggle_inventory()
	for page in range(4):
		game.view.overlay.equipment_page = page
		await snap("dungeon-30-office-icons-page-%d" % (page + 1))
	game.weapons.clear()
	for spec in game.Data.WEAPONS.slice(12):
		game.add_item(spec.id)
	await snap("dungeon-31-new-weapon-icons")
	await scene_change_previews()
	game.state = "won"
	await snap("dungeon-09-ending")
	game.queue_free()
	await process_frame
	quit()

func scene_change_previews() -> void:
	game.start_run(20261114, true)
	game.message_time = 0
	game.speech_time = 0
	for kind in ["treasure", "rest"]:
		var room: Dictionary = game.rooms.filter(func(candidate: Dictionary) -> bool: return candidate.type == kind)[0]
		var direction: int = room.links.find(room.parent)
		game.player = room.doors[direction].move_toward(room.center, 24)
		assert(not room.visited and not room.cleared and not room.started, "Facility preview does not activate its room")
		var before: Image = await snap("dungeon-36-%s-before-visit" % kind)
		room.cleared = true
		var after: Image = await snap("dungeon-36-%s-after-visit" % kind)
		var center: Vector2 = Vector2(640, 360) + (room.center - game.player) * game.camera.zoom
		var sample := Rect2i(Vector2i(center) - Vector2i(55, 90), Vector2i(110, 115))
		assert(before.get_region(sample).get_data() == after.get_region(sample).get_data(), "Facility artwork must already be present before visiting")
	game.start_run(20261114, true)
	game.floor_index = 4
	game.generate_floor()
	for room in game.rooms:
		if room.type == "combat":
			game.enter_room(room.id)
			break
	game.enemies.clear()
	game.effects.clear()
	game.player = game.room_center() + Vector2(0, 70)
	game.message_time = 0
	game.speech_time = 0
	var cover: Rect2 = game.current_room().obstacles[0]
	game.player = cover.get_center() + Vector2(140, 70)
	await snap("dungeon-37-cover-intact")
	game.hit_cover(cover)
	game.hit_cover(cover)
	game.effects.clear()
	await snap("dungeon-37-cover-damaged")
	game.hit_cover(cover)
	game.effects.clear()
	await snap("dungeon-37-cover-broken")
	for kind in ["wolf", "ropehead", "baola", "shark", "boss"]:
		var i: int = game.enemies.size()
		var enemy: Dictionary = game.spawn_enemy(game.room_center() + Vector2(-240 + i * 115, -30), kind)
		enemy.age = 2
		enemy.facing = -1.0
	game.player = game.room_center() + Vector2(0, 140)
	await snap("dungeon-38-enemies-face-left")
	for enemy in game.enemies:
		enemy.facing = 1.0
	await snap("dungeon-38-enemies-face-right")
	game.enemies.clear()
	game.player = game.current_room().rect.position + Vector2(220, 180)
	await snap("dungeon-39-walls-inset")
	print("Scene change visual and interaction checks complete")
