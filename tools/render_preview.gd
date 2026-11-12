extends SceneTree

var game: Node

func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://output/previews/" + name + ".png"
	var result: Error = root.get_texture().get_image().save_png(path)
	print("PREVIEW: ", name, " ", result)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/preview-record.json"
	await snap("01-title")
	game.previous_state = "title"
	game.state = "guide"
	await snap("02-guide")
	game.start_run()
	game.chapter_time = 0
	game.player.position = Vector2(450, 600)
	game.say("来了", 20)
	await snap("03-ugs")
	game.player.cast_skill()
	await snap("04-breakpoint")
	game.player.position = Vector2(220, 600)
	game.player.invulnerable = 0
	game.player.skill_time = 0
	game.effects.clear()
	Input.action_press("move_right")
	for i in range(12):
		await physics_frame
	await snap("08-running")
	Input.action_release("move_right")
	game.player.position = Vector2(430, 600)
	game.player.velocity = Vector2.ZERO
	game.player.facing = 1
	game.player.attack()
	for i in range(8):
		await physics_frame
	await snap("09-slash")
	game.stage = 2
	game.chapter_time = 0
	game.player.position = Vector2(3910, 600)
	game.camera_x = 3470
	game.world.position.x = -3470
	game.say("坏啦", 20, "毅川 · 这个文件到底谁锁的？")
	await snap("05-p4")
	game.stage = 3
	game.player.position = Vector2(5490, 600)
	game.camera_x = 5050
	game.world.position.x = -5050
	game.say("怀不上了", 20)
	await snap("06-boss")
	game.run_time = 196
	game.repaired = 4
	game.state = "won"
	await snap("07-complete")
	game.queue_free()
	for i in range(3):
		await process_frame
	quit()
