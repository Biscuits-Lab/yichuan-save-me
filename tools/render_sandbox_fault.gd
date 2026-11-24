extends SceneTree
const Fault = preload("res://scripts/sandbox_fault.gd")
const Data = preload("res://scripts/sandbox_data.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> Image:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var viewport_image: Image = root.get_texture().get_image()
	var path: String = "res://output/previews/fault-" + label + ".png"
	if viewport_image == null or viewport_image.save_png(path) != OK:
		failures += 1
		push_error("Preview failed: " + path)
	else:
		print("PREVIEW ", path)
	return viewport_image

func snap_sandbox(game: Node, label: String) -> Image:
	game.previous_player = game.player
	game.camera.position = game.player + Vector2(0, -80)
	game.camera.reset_physics_interpolation()
	game.camera.force_update_scroll()
	game.view.fault_view.sync_fog()
	game.view.fault_view.sync_transition()
	game.view.queue_redraw()
	game.ui.queue_redraw()
	game.sky.queue_redraw()
	return await capture(label)

func check_transition(game: Node, route: String, target_fault: bool) -> void:
	var label: String = "transition-" + route
	if game.state != "fault_transition" or game.fault.transition_kind != route:
		failures += 1
		push_error("No presentation started for " + route)
		return
	game._physics_process(0.50)
	await snap_sandbox(game, label + "-1-closing")
	game._physics_process(Fault.TRANSITION_CUT - 0.53)
	var before: Image = await snap_sandbox(game, label + "-2-covered")
	if game.fault.active == target_fault:
		failures += 1
		push_error("The " + route + " cut began before the transition was fully covered")
	game._physics_process(0.06)
	var after: Image = await snap_sandbox(game, label + "-3-cut")
	if game.fault.active != target_fault or game.state != "fault_transition":
		failures += 1
		push_error("The " + route + " cut did not switch to its destination under the cover")
	check_concealed_cut(before, after, route)
	game._physics_process(0.69)
	await snap_sandbox(game, label + "-4-reveal")
	game._physics_process(Fault.TRANSITION_END - game.fault.transition_time + 0.02)
	await snap_sandbox(game, label + "-5-end")
	var presentation = game.view.fault_view
	if presentation.transition_cover.visible or (presentation.fog != null and presentation.fog.visible != target_fault):
		failures += 1
		push_error("The " + route + " presentation left an overlay in the wrong world")

func check_concealed_cut(before: Image, after: Image, route: String) -> void:
	if before == null or after == null:
		return
	var sample_points: Array[Vector2] = [
		Vector2(0.02, 0.02), Vector2(0.98, 0.02), Vector2(0.02, 0.98), Vector2(0.98, 0.98),
		Vector2(0.51, 0.73), Vector2(0.51, 0.30), Vector2(0.20, 0.52), Vector2(0.81, 0.52),
	]
	for uv in sample_points:
		var pixel := Vector2i(uv * Vector2(before.get_size()))
		var original: Color = before.get_pixelv(pixel)
		var changed: Color = after.get_pixelv(pixel)
		if original.get_luminance() > 0.23 or absf(original.get_luminance() - changed.get_luminance()) > 0.035:
			failures += 1
			push_error("Visible pixels changed under the " + route + " cut at " + str(uv))

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await capture("00-main-menu")
	if "--title-only" in OS.get_cmdline_user_args():
		quit(0 if failures == 0 else 1)
		return
	main.queue_free()
	await process_frame
	var game: Node = load("res://scenes/sandbox.tscn").instantiate()
	game.save_path = "res://.tools/fault-preview.save"
	root.add_child(game)
	game.set_physics_process(false)
	await snap_sandbox(game, "01-sandbox-menu")
	game.start_world(20261124)
	game.hurt_time = 0
	game.hurt(1000, game.player)
	game.fault.death_tick(0.85)
	game.message_time = 0
	await snap_sandbox(game, "02-revival")
	game.fault.death_tick(1.0)
	game.player = game.fault.keeper_site
	game.health = 49.0
	game.interact()
	game.message_time = 0
	await snap_sandbox(game, "03-home-heal")
	if not game.ui.click(Vector2(728, 381)) or game.state != "playing" or game.health != game.max_health():
		failures += 1
		push_error("The Fire Keeper's rendered heal button did not restore the player")
		game.set_state("playing")
	for count in range(9):
		game.hurt_time = 0.0
		game.hurt(1000, game.player)
		game.fault.death_tick(2.0)
	await check_transition(game, "enter", true)
	game.set_state("playing")
	game.message_time = 0
	for i in range(12):
		game.spawn_enemy()
	await snap_sandbox(game, "04-fog")
	game.enemies.clear()
	var origin: Vector2 = game.safe_spawn()
	game.player = origin
	for i in range(5):
		var kind: String = Fault.ENEMIES.keys()[i]
		var spec: Dictionary = Fault.ENEMIES[kind].duplicate()
		spec.fault = true
		var spot: Vector2 = origin + Vector2(-250 + i * 126, -66 if spec.get("flying", false) else 0)
		var enemy = game.adventure.spawn(kind, spot, -1, spec)
		enemy.facing = 1 if spot.x < origin.x else -1
	await snap_sandbox(game, "05-creatures")
	game.enemies.clear()
	game.player = game.fault.ape_site + Vector2(-250, 0)
	game.fault.tick(2.0)
	var ape: Dictionary = game.adventure.current_boss()
	if ape.is_empty():
		failures += 1
		push_error("The fault boss did not spawn for its preview")
	else:
		ape.attack = 1
		game.fault.begin_attack(ape, game.player, ape.p - Vector2(0, 51), false)
		ape.windup *= 0.3
		game.message_time = 0
		await snap_sandbox(game, "06-ape")
	game.player = game.fault.priest_site
	game.interact()
	await snap_sandbox(game, "07-priest")
	if not game.ui.click(Vector2(640, 383)) or game.state != "fault_transition":
		failures += 1
		push_error("The priest's rendered recovery button did not leave the fault")
	else:
		await check_transition(game, "priest", false)
		await snap_sandbox(game, "08-return")
		game.ui.click(Vector2(640, 383))
		for count in range(Fault.LIMIT):
			game.hurt_time = 0.0
			game.hurt(1000, game.player)
			game.fault.death_tick(2.0)
		game._physics_process(Fault.TRANSITION_END + 0.02)
		game.set_state("playing")
		game.player = game.fault.ape_site + Vector2(-180, 0)
		game.fault.tick(2.0)
		ape = game.adventure.current_boss()
		if ape.is_empty():
			failures += 1
			push_error("No ape for the second exit preview")
		else:
			game.adventure.damage_enemy(ape, ape.hp + 1, game.player)
			await check_transition(game, "ape", false)
	game.queue_free()
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = game.save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	await process_frame
	quit(0 if failures == 0 else 1)
