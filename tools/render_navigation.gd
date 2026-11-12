extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	game.scenery.queue_redraw()
	game.hud.queue_redraw()
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	print("PREVIEW: ",name," ",root.get_texture().get_image().save_png("res://output/previews/" + name + ".png"))

func camera_at(x: float) -> void:
	game.camera_x = x
	game.world.position.x = -x
	game.world.reset_physics_interpolation()
	game.player.reset_physics_interpolation()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/navigation-preview-record.json"
	game.start_run("story",20261112)
	game.set_process(false)
	game.player.position = Vector2(1300,598)
	game.player.invulnerable = 0
	for i in range(5):
		await physics_frame
	game.player.set_physics_process(false)
	game.chapter_time = 0
	game.speech_time = 0
	game.feedback_time = 0
	game.room_phase = "combat"
	var bug: Node = game.spawn_bug(Vector2(1515,598),"ugs")
	bug.set_physics_process(false)
	camera_at(960)
	game.room_clock = 1
	await snap("fix-01-trap-idle")
	game.room_clock = 3.2
	await snap("fix-02-trap-warning")
	game.room_clock = 4.1
	await snap("fix-03-trap-active")
	bug.dead = true
	bug.queue_free()
	game.enemies.clear()
	game.room_phase = "relay"
	game.player.position = Vector2(1575,598)
	camera_at(1120)
	await snap("fix-04-locked-gate-guide")
	game.player.position = Vector2(910,game.room_data.relays[0].p.y)
	camera_at(470)
	await snap("fix-05-relay-guide")
	game.open_gate(0)
	game.open_gate(1)
	game.relay_count = 2
	game.summon_boss()
	game.boss_ref.set_physics_process(false)
	game.boss_ref.telegraph = 0.7
	game.player.position = Vector2(2920,598)
	camera_at(2240)
	await snap("fix-06-right-end-boss")
	game.queue_free()
	for i in range(3):
		await process_frame
	quit()
