extends SceneTree
var game: Node
func _initialize() -> void:
	call_deferred("run")
func snap(name: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	print("PREVIEW: ",name," ",root.get_texture().get_image().save_png("res://output/previews/" + name + ".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/rogue-preview-record.json"
	await snap("rogue-01-title")
	game.start_run("story",20261112)
	game.chapter_time = 0
	game.player.position.x = game.room_data.encounters[0].trigger_x + 1
	game.reveal_encounters()
	game.player.position = game.npcs[0].p
	game.player.health = 5
	game.coins = 20
	game.interact()
	await snap("rogue-02-npc")
	game.accept_npc()
	game.player.position = Vector2(620,598)
	game.spawn_wave(0)
	game.player.invulnerable = 0
	game.say("来了",10)
	Input.action_press("move_right")
	for i in range(8):
		await physics_frame
	await snap("rogue-03-room")
	Input.action_release("move_right")
	game.player.attack()
	for i in range(15):
		await physics_frame
	await snap("rogue-04-animation")
	for bug in game.enemies:
		if is_instance_valid(bug):
			bug.dead = true
			bug.queue_free()
	game.enemies.clear()
	game.player.position = Vector2(game.room_data.arena.x + 120,598)
	game.player.velocity = Vector2.ZERO
	game.camera_x = game.player.position.x - 440
	game.world.position.x = -game.camera_x
	game.player.reset_physics_interpolation()
	for i in range(game.gates.size()):
		game.open_gate(i)
	game.summon_boss()
	game.boss_ref.telegraph = 0.7
	game.say("毅川救我",8,"若宇")
	await snap("rogue-05-boss")
	game.boss_ref.take_hit(99999,1,true)
	game.upgrade_choices.assign([game.Data.skill("swords"),game.Data.skill("chain"),game.Data.skill("rollback")])
	await snap("rogue-06-skills")
	game.choose_upgrade(0)
	await snap("rogue-07-routes")
	game.choose_route(1)
	game.chapter_time = 0
	game.apply_upgrade("rollback")
	game.apply_upgrade("blade")
	game.apply_upgrade("chain")
	game.previous_state = "playing"
	game.state = "build"
	await snap("rogue-08-build")
	game.state = "guide"
	await snap("rogue-09-guide")
	game.start_run("endless",42)
	game.room_index = 12
	game.cleared_rooms = 12
	game.build_room()
	game.chapter_time = 0
	game.player.position = Vector2(620,598)
	game.spawn_wave(0)
	await snap("rogue-10-endless")
	game.queue_free()
	for i in range(3):
		await process_frame
	quit()
