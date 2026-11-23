extends SceneTree
## Run with the graphics renderer, --fixed-fps 144 and --disable-vsync.

var game: Node
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.record_path = "res://.tools/dungeon-motion-record.json"
	root.add_child(game)
	game.start_run(20261113, true)
	game.cheat_invincible = true
	game.weapons.clear()
	game.obstacles.clear()
	game.player = game.room_center() - Vector2(245, 0)
	game.camera_snap()
	var enemy: Dictionary = game.spawn_enemy(game.room_center() + Vector2(0, 160), game.Data.FLOOR_ENEMIES[0][0])
	enemy.max_hp = 1000000.0
	enemy.hp = enemy.max_hp
	enemy.speed = 0.0

	Input.action_press("move_right")
	var previous: Vector2 = root.get_canvas_transform().origin
	var smallest: float = INF
	var largest: float = 0.0
	var total: float = 0.0
	for frame in range(255):
		await RenderingServer.frame_post_draw
		var current: Vector2 = root.get_canvas_transform().origin
		if frame >= 80:
			var step: float = previous.x - current.x
			smallest = minf(smallest, step)
			largest = maxf(largest, step)
			total += step
		previous = current
		if frame % 9 == 2:
			game.hit_enemy(enemy, 1.0, game.player, {"knockback":0.0})
	check(total > 270.0, "Held movement must scroll the arena while shots land.")
	check(smallest > 0.0 and largest - smallest < 0.08, "Repeated attack impacts must not disturb steady camera motion.")

	Input.action_release("move_right")
	for frame in range(24):
		await RenderingServer.frame_post_draw
	game.hit_enemy(enemy, 1.0, game.player, {"knockback":0.0})
	for frame in range(3):
		await RenderingServer.frame_post_draw
	check(game.camera.offset.length() > 0.0, "Attack feedback still shakes the camera while stationary.")
	Input.action_press("move_left")
	for frame in range(5):
		await RenderingServer.frame_post_draw
	check(game.camera.offset.is_zero_approx(), "Movement clears any shake left over from the stationary hit.")
	Input.action_release("move_left")

	print("DUNGEON MOTION: %.3f–%.3f px per rendered frame, %d failures" % [smallest, largest, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
