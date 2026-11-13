extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func snap(label: String) -> void:
	if not game.rooms.is_empty():
		game.camera_snap()
	game.view.queue_redraw()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://output/previews/" + label + ".png")
	print("PREVIEW ", label, " ", error)

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
	game.add_item("blade")
	game.add_item("vest")
	game.toggle_inventory()
	await snap("dungeon-05-fusion")
	game.state = "playing"
	game.current_room().cleared = true
	service_room("npc")
	game.current_room().npc = 6
	game.selected_npc = 6
	game.state = "npc"
	await snap("dungeon-06-npc")
	game.floor_index = 2
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
		if room.type == "combat" and room.rect.size.x > 1250:
			game.enter_room(room.id)
			break
	game.invulnerable = 999
	game.player = game.room_center() + Vector2(-300, 0)
	await snap("dungeon-11-camera-west")
	game.player = game.room_center() + Vector2(300, 0)
	await snap("dungeon-12-camera-east")
	game.state = "won"
	await snap("dungeon-09-ending")
	game.queue_free()
	await process_frame
	quit()
