extends SceneTree
## Deterministic combat load; run headless for CPU or normally for frame pacing.
var game: Node
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func summarize(samples: Array[float]) -> Dictionary:
	samples.sort()
	var total: float = 0
	for value in samples:
		total += value
	return {"mean_ms":total / samples.size(), "p95_ms":samples[int(samples.size() * 0.95)], "max_ms":samples[-1]}

func setup_combat(boss: bool = false) -> void:
	game.start_run(20261113, true)
	game.floor_index = 2
	game.generate_floor()
	for room in game.rooms:
		if room.type == ("boss" if boss else "combat"):
			game.enter_room(room.id)
			break
	game.weapons.clear()
	for spec in game.Data.WEAPONS:
		game.add_item(spec.id)
	game.cheat_invincible = true
	for enemy in game.enemies:
		enemy.hp = 1000000
		enemy.max_hp = 2000001 if boss else 1000000
		enemy.age = 2
	game.set_physics_process(false)
	game.speech_time = 0
	game.message_time = 0

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.view.free()
	game.view = load("res://tools/profile_dungeon_view.gd").new()
	game.view.game = game
	game.add_child(game.view)
	game.view.repaint_geometry = "--repaint-geometry" in OS.get_cmdline_user_args()
	game.view.geometry_root.visible = not game.view.repaint_geometry
	game.record_path = "res://.tools/profile-record.json"
	game.set_physics_process(false)
	for boss in [false, true]:
		setup_combat(boss)
		var samples: Array[float] = []
		for tick in range(600):
			var start: int = Time.get_ticks_usec()
			game._physics_process(1.0 / 60)
			samples.append((Time.get_ticks_usec() - start) / 1000.0)
		report["boss_cpu" if boss else "combat_cpu"] = summarize(samples)
	setup_combat()
	var samples: Array[float] = []
	for repeat in range(12):
		var start: int = Time.get_ticks_usec()
		game.build_navigation()
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	report["room_navigation"] = summarize(samples)
	if DisplayServer.get_name() != "headless":
		setup_combat()
		var frame_times: Array[float] = []
		var draws: Array[float] = []
		var draw_times: Array[float] = []
		for frame in range(300):
			game._physics_process(1.0 / 60)
			var ui_count: int = game.view.overlay.draw_count
			var start: int = Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			if frame >= 120:
				frame_times.append((Time.get_ticks_usec() - start) / 1000.0)
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				draw_times.append((game.view.draw_usec + (game.view.overlay.draw_usec if game.view.overlay.draw_count != ui_count else 0)) / 1000.0)
		report["render_frame"] = summarize(frame_times)
		report["redraw_cpu"] = summarize(draw_times)
		report["draw_calls"] = {"mean":draws.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / draws.size(), "max":draws.max()}
	var output: String = "res://.tools/dungeon-profile.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-output="):
			output = argument.trim_prefix("--benchmark-output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DUNGEON_PROFILE ", JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit()
