extends SceneTree
## Run on the offscreen desktop so the same menu hotspots are drawn as in the game.

class PadProbe extends "res://scripts/gamepad.gd":
	var motor_calls: Array[Vector3] = []

	func send_motors(weak: float, strong: float, seconds: float) -> void:
		motor_calls.append(Vector3(weak, strong, seconds))

const DEVICE: int = 7
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame

func button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(index: JoyButton) -> void:
	button(index, true)
	await frames()
	button(index, false)
	await frames()

func axis(id: JoyAxis, strength: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = id
	event.axis_value = strength
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func screenshot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var output: String = "res://.tools/gamepad-" + label + ".png"
	check(root.get_texture().get_image().save_png(output) == OK, "Screenshot saved: " + label)

func scene(path: String) -> Node:
	var game: Node = load(path).instantiate()
	game.pad.free()
	game.pad = PadProbe.new()
	root.add_child(game)
	game.set_physics_process(false)
	return game

func dungeon_checks() -> void:
	var game: Node = scene("res://scenes/main.tscn")
	game.record_path = "res://.tools/gamepad-test-record.json"
	var pad: PadProbe = game.pad
	await frames()
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(game.state == "guide" and pad.active and pad.key("A") == "A", "Gamepad activity activates prompts and opens the dungeon guide")
	await tap(JOY_BUTTON_B)
	check(game.state == "title", "Gamepad back returns to the dungeon title")
	await screenshot("title")
	await tap(JOY_BUTTON_DPAD_UP)
	await tap(JOY_BUTTON_DPAD_LEFT)
	await tap(JOY_BUTTON_A)
	check(game.difficulty == 0 and game.state == "title", "D-pad focus and confirm select difficulty")
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	check(game.state == "dialogue", "Confirm starts a dungeon run from the focused button")
	await tap(JOY_BUTTON_A)
	check(game.dialogue_index == 1, "Confirm advances the story")
	await tap(JOY_BUTTON_B)
	game.interaction_cooldown = 0
	var old_position: Vector2 = game.player
	axis(JOY_AXIS_LEFT_X, 0.84)
	for frame in range(8):
		game._physics_process(1.0 / 60.0)
	check(game.player.x > old_position.x and pad.active, "An analog stick on a nonzero device moves the dungeon player")
	axis(JOY_AXIS_LEFT_X, 0.0)
	pad.stop_rumble()
	button(JOY_BUTTON_A, true)
	game._physics_process(1.0 / 60.0)
	check(game.dash_time > 0.0 and pad.rumble_pattern == pad.RUMBLE.dash, "A activates dash with a short vibration")
	button(JOY_BUTTON_A, false)
	await frames()
	await tap(JOY_BUTTON_START)
	check(game.state == "inventory", "Start opens the dungeon inventory")
	await tap(JOY_BUTTON_X)
	check(not game.view.overlay.item_context.is_empty(), "A focused inventory item exposes its action menu")
	await screenshot("inventory")
	await tap(JOY_BUTTON_B)
	check(game.state == "inventory" and game.view.overlay.item_context.is_empty(), "Back first closes the item action menu")
	await tap(JOY_BUTTON_B)
	await screenshot("dungeon-hud")
	pad.stop_rumble()
	var mob: Dictionary = game.spawn_enemy(game.player + Vector2(70, 0), "slime")
	game.hit_enemy(mob, 1, game.player)
	check(not mob.dead and pad.rumble_pattern.is_empty(), "A nonlethal hit does not send the kill pulse")
	game.hit_enemy(mob, 10000, game.player)
	check(mob.dead and pad.rumble_pattern == pad.RUMBLE.kill and pad.motor_calls.back() == pad.RUMBLE.kill[1], "Dungeon enemy death vibrates both motors")
	var kill_calls: int = pad.motor_calls.size()
	var second_mob: Dictionary = game.spawn_enemy(game.player + Vector2(80, 0), "slime")
	game.hit_enemy(second_mob, 10000, game.player)
	check(second_mob.dead and pad.motor_calls.size() == kill_calls, "Simultaneous kills share the short pulse")
	game.current_room().cleared = true
	game.current_room().reward_shop = true
	game.open_shop()
	game._process(0.0)
	check(game.state == "shop" and pad.rumble_pattern == pad.RUMBLE.kill, "The kill pulse can finish during the shop transition")
	game.leave_shop()
	var boss: Dictionary = game.spawn_enemy(game.player + Vector2(100, 0), "boss")
	pad.stop_rumble()
	game.perform_enemy_move(boss, "lunge")
	check(pad.rumble_pattern == pad.RUMBLE.charge, "A boss charge dispatches its own pattern")
	game.perform_enemy_move(boss, "laser")
	check(pad.rumble_pattern == pad.RUMBLE.laser, "A boss laser supersedes the charge with a different pattern")
	game.hit_enemy(boss, 10000, game.player)
	check(boss.dead and pad.rumble_pattern == pad.RUMBLE.victory, "Boss defeat still plays the stronger victory sequence")
	game.invulnerable = 0.0
	game.hurt(game.max_health() * 100, boss.p)
	check(game.state == "dead" and pad.rumble_pattern == pad.RUMBLE.death, "Death overrides active boss vibration")
	var calls: int = pad.motor_calls.size()
	pad.pulse("dash")
	check(pad.motor_calls.size() == calls, "A lighter pulse cannot interrupt death")
	pad.advance_rumble(pad.rumble_until)
	pad.advance_rumble(pad.rumble_until)
	var gap: Vector3 = pad.motor_calls.back()
	check(is_zero_approx(gap.x) and is_zero_approx(gap.y), "Death has a silent gap before its last pulse")
	var keyboard := InputEventKey.new()
	keyboard.keycode = KEY_F3
	keyboard.pressed = true
	Input.parse_input_event(keyboard)
	Input.flush_buffered_events()
	check(not pad.active and pad.key("A", "Enter") == "Enter" and pad.rumble_pattern.is_empty(), "Keyboard restores keyboard prompts and stops rumble")
	keyboard = keyboard.duplicate()
	keyboard.pressed = false
	Input.parse_input_event(keyboard)
	Input.flush_buffered_events()
	pad.connection_changed(DEVICE, true)
	pad.labels = pad.PLAYSTATION
	check(pad.text("键盘", "{A} 确认 · {RT} 使用") == "× 确认 · R2 使用", "PlayStation labels follow the control positions")
	pad.connection_changed(DEVICE, false)
	check(not pad.active or pad.device != DEVICE, "Removing the active gamepad clears its input mode")
	game.free()

func sandbox_checks() -> void:
	var game: Node = scene("res://scenes/sandbox.tscn")
	game.save_available = false
	game.save_path = "res://.tools/gamepad-test.save"
	await frames()
	button(JOY_BUTTON_A, true)
	check(game.state == "playing" and game.pad.active and not game.jump_pressed(), "A launches the world without also jumping")
	button(JOY_BUTTON_A, false)
	await frames()
	game.start_world(20261113)
	await tap(JOY_BUTTON_Y)
	check(game.state == "inventory", "Y opens the sandbox inventory")
	await screenshot("sandbox-inventory")
	await tap(JOY_BUTTON_B)
	button(JOY_BUTTON_A, true)
	check(game.jump_pressed(), "A in the world starts a jump")
	button(JOY_BUTTON_A, false)
	await tap(JOY_BUTTON_START)
	check(game.state == "paused", "Start pauses the sandbox")
	axis(JOY_AXIS_LEFT_Y, 0.90)
	await frames()
	axis(JOY_AXIS_LEFT_Y, 0.0)
	var focus: Dictionary = game.pad.focused(game.ui.menu_entries(), game.state)
	check(focus.get("action") == "save", "Left stick navigates the sandbox pause menu")
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	check(game.selected == 1, "Shoulder buttons switch sandbox hotbar slots")
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	game.player = game.world.spawn
	axis(JOY_AXIS_RIGHT_X, 0.82)
	game.update_pad_aim()
	axis(JOY_AXIS_RIGHT_X, 0.0)
	game.update_pad_aim()
	var cell: Vector2i = game.cell_at(game.mouse_world())
	check(cell.x > game.cell_at(game.player).x, "Right stick aims in world space and holds the target after release")
	for x in range(game.cell_at(game.player).x, cell.x):
		game.world.set_tile(Vector2i(x, cell.y), game.Data.Block.AIR)
	game.world.set_tile(cell + Vector2i.DOWN, game.Data.Block.DIRT)
	game.world.set_tile(cell, game.Data.Block.DIRT)
	var dirt_before: int = game.count_item("dirt")
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	for frame in range(120):
		game.update_tools(1.0 / 60.0)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(game.count_item("dirt") == dirt_before + 1, "Held right trigger mines the aimed tile")
	game.selected = 2
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	game.update_tools(1.0 / 60.0)
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(game.world.tile(cell) == game.Data.Block.DIRT and game.count_item("dirt") == dirt_before, "Left trigger places the selected tile at the same target")
	await screenshot("sandbox-hud")
	var mob: Dictionary = game.adventure.spawn("slime", game.player + Vector2(60, 0))
	game.adventure.damage_enemy(mob, 10000, game.player)
	check(mob.dead and game.pad.rumble_pattern == game.pad.RUMBLE.kill, "Sandbox enemy death plays the kill pulse")
	game.pad.stop_rumble()
	var boss: Dictionary = game.adventure.spawn("yamada", game.player + Vector2(180, 0), 6)
	game.adventure.boss_attack(boss, 0)
	check(game.pad.rumble_pattern == game.pad.RUMBLE.charge, "Sandbox boss charge uses combat vibration")
	game.hurt_time = 0.0
	game.hurt(10000, game.player)
	check(game.state == "dead" and game.pad.rumble_pattern == game.pad.RUMBLE.death, "Sandbox lethal damage plays the death sequence")
	await frames()
	await tap(JOY_BUTTON_A)
	check(game.state == "playing", "Gamepad confirms respawn in the sandbox")
	game.free()

func run() -> void:
	await dungeon_checks()
	await sandbox_checks()
	print("GAMEPAD: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
