extends SceneTree
const Data = preload("res://scripts/sandbox_data.gd")
var game: Node

func _initialize() -> void:
	call_deferred("run")

func snap(label: String) -> void:
	game.previous_player = game.player
	game.camera.position = game.player + Vector2(0,-80)
	game.camera.reset_physics_interpolation()
	game.message_time = 0
	game.view.queue_redraw()
	game.ui.queue_redraw()
	game.sky.queue_redraw()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	print("PREVIEW ",label," ",root.get_texture().get_image().save_png("res://output/previews/" + label + ".png"))

func house(at: Vector2i) -> void:
	var s = game.adventure.structures
	for dy in range(-7,1):
		for dx in range(-6,7):
			var c: Vector2i = at + Vector2i(dx,dy)
			game.world.set_tile(c,Data.Block.PLANK if absi(dx) == 6 or dy in [-7,0] else Data.Block.AIR)
			s.walls[s.index(c)] = 1
	game.world.set_tile(at + Vector2i(1,-1),Data.Block.CHAIR)
	game.world.set_tile(at + Vector2i(-1,-1),Data.Block.BENCH)
	game.world.set_tile(at + Vector2i(4,-3),Data.Block.TORCH)
	game.world.set_tile(at + Vector2i(-4,-3),Data.Block.TORCH)
	s.install_door(at + Vector2i(6,-1))
	s.register_house(at + Vector2i(0,-2))

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/sandbox.tscn").instantiate()
	game.save_path = "res://.tools/adventure-preview.save"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_world(20261113)
	var a = game.adventure
	for id in Data.ITEMS:
		game.inventory[id] = 45
	game.pick_tier = 3
	game.sword_tier = 2
	a.life_upgrades = 8
	a.mana_upgrades = 3
	a.armor = "gold_armor"
	a.accessories.assign(["boots","double_jump","grapple"])
	for i in range(2):
		a.bosses[game.Catalog.BOSSES[i].id] = true
	for cy in range(40,61):
		for cx in range(260,313):
			game.world.set_tile(Vector2i(cx,cy),Data.Block.DIRT if cy >= 59 else Data.Block.AIR)
	house(Vector2i(274,59))
	house(Vector2i(290,59))
	house(Vector2i(274,50))
	house(Vector2i(290,50))
	a.structures.update_town()
	game.player = Vector2(285.5 * 24,59 * 24 - 0.01)
	var chest := Vector2i(293,58)
	game.world.set_tile(chest,Data.Block.CHEST)
	a.structures.chests[chest] = {"wood":88,"iron_bar":16,"gold_bar":9,"arrow":120,"herb":35}
	game.world.set_tile(Vector2i(284,58),Data.Block.CAMPFIRE)
	game.world.set_tile(Vector2i(286,58),Data.Block.ANVIL)
	game.world.set_tile(Vector2i(287,58),Data.Block.ALTAR)
	game.world.set_tile(Vector2i(286,57),Data.Block.PLATFORM)
	game.world.set_tile(Vector2i(287,57),Data.Block.PLATFORM)
	game.health = game.max_health()
	game.world.reveal(game.player)
	await snap("sandbox-v06-settlement")
	game.state = "inventory"
	a.inventory_page = 2
	game.recipe_category = 2
	a.recipe_page = 1
	await snap("sandbox-v06-equipment")
	game.state = "journal"
	await snap("sandbox-v06-progression")
	game.ui.detail.journal_tab = 1
	for kind in game.Catalog.ENEMIES:
		a.bestiary[kind] = 5
	await snap("sandbox-v06-bestiary")
	game.state = "chest"
	a.structures.selected_chest = chest
	await snap("sandbox-v06-storage")
	game.start_world(20261113)
	a = game.adventure
	game.player = Vector2(150.5 * 24,58 * 24)
	for y in range(45,64):
		for x in range(127,174):
			game.world.set_tile(Vector2i(x,y),Data.Block.JUNGLE_GRASS if y >= 61 else Data.Block.AIR)
	for x in range(140,163):
		game.world.set_tile(Vector2i(x,57),Data.Block.PLATFORM)
	game.player.y = 57 * 24 - 0.01
	game.hotbar[1] = "fire_staff"
	game.inventory.fire_staff = 1
	game.pick_tier = 5
	game.selected = 1
	a.mana_upgrades = 4
	a.mana = 110
	a.life_upgrades = 12
	game.health = game.max_health()
	a.armor = "molten_armor"
	game.inventory.molten_armor = 1
	game.elapsed = 330
	game.refresh_merchant()
	for i in range(5):
		a.bosses[game.Catalog.BOSSES[i].id] = true
	var boss: Dictionary = a.spawn("brood",game.player + Vector2(220,-100),5)
	boss.hp *= 0.7
	boss.windup = 0.3
	a.boss_attack(boss,1)
	a.spawn("wolf",game.player + Vector2(-160,80))
	a.spawn("ropehead",game.player + Vector2(300,80))
	a.companion = true
	a.companion_p = game.player + Vector2(-70,-10)
	a.shoot(game.player - Vector2(0,20),Vector2(300,-60),31,true)
	a.shots[-1].p += Vector2(90,-20)
	a.shots[-1].previous = a.shots[-1].p
	a.update_shots(0.35)
	for shot in a.shots:
		shot.previous = shot.p
	game.world.set_tile(Vector2i(149,60),Data.Block.CAMPFIRE)
	game.world.set_tile(Vector2i(155,60),Data.Block.TORCH)
	game.world.reveal(game.player)
	await snap("sandbox-v06-boss")
	game.queue_free()
	await process_frame
	quit()
