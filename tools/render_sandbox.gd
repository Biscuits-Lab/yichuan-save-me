extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func snap(label: String) -> void:
	game.previous_player = game.player
	game.camera.position = game.player + Vector2(0, -80)
	game.camera.reset_physics_interpolation()
	game.view.queue_redraw()
	game.sky.queue_redraw()
	game.ui.queue_redraw()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://output/previews/" + label + ".png")
	print("PREVIEW ", label, " ", error)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/sandbox.tscn").instantiate()
	game.save_path = "res://.tools/sandbox-preview.save"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await snap("sandbox-01-menu")
	game.start_world(20261113)
	game.message_time = 0
	await snap("sandbox-02-surface")
	game.inventory.wood = 48
	game.inventory.stone = 73
	game.inventory.gel = 12
	game.inventory.coal = 18
	game.inventory.copper_ore = 30
	game.state = "inventory"
	await snap("sandbox-03-crafting")
	game.elapsed = 4 * 600.0
	game.refresh_merchant()
	game.player = game.merchant_position + Vector2(45, 0)
	game.inventory.coin = 126
	game.state = "merchant"
	await snap("sandbox-04-priest")
	game.start_review()
	game.flip_review(0)
	await snap("sandbox-08-code-review")
	game.review_completed_visit = game.merchant_visit
	game.review_reward_pending = true
	game.state = "review_reward"
	await snap("sandbox-09-review-reward")
	game.state = "playing"
	game.player = Vector2((576 / 2 + 23 + 65) * 24, (59 + 65 / 3) * 24)
	game.elapsed = 330.0
	game.refresh_merchant()
	game.world.set_tile(game.cell_at(game.player) + Vector2i(-3, -1), 10)
	game.world.reveal(game.player)
	game.ui.map_dirty = true
	await snap("sandbox-05-cave")
	game.state = "map"
	await snap("sandbox-06-map")
	game.state = "guide"
	await snap("sandbox-07-guide")
	game.queue_free()
	await process_frame
	quit()
