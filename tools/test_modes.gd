extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in range(4):
		await process_frame

func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	check(current_scene.state == "title", "Original entry still opens the dungeon title")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_B
	current_scene._unhandled_input(event)
	await settle()
	check(current_scene.scene_file_path == "res://scenes/sandbox.tscn" and current_scene.state == "menu", "B opens the sandbox mode menu")
	var sandbox: Node = current_scene
	sandbox.save_path = "res://.tools/mode-transition-test.save"
	sandbox.start_world(20261113)
	check(sandbox.state == "playing" and not sandbox.inventory.is_empty(), "Sandbox menu can start a world")
	sandbox.leave_mode()
	await settle()
	check(current_scene.scene_file_path == "res://scenes/main.tscn" and current_scene.state == "title", "Saving and leaving returns to the original dungeon title")
	check(auto_accept_quit, "Returning restores normal window-close behavior")
	current_scene.start_run(20261113, true)
	check(current_scene.state == "playing" and not current_scene.rooms.is_empty(), "Dungeon still starts after a sandbox visit")
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = "res://.tools/mode-transition-test.save" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("MODE TRANSITIONS: 6 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
