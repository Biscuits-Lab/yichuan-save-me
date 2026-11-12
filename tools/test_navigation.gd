extends SceneTree
var game: Node
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label + " | player=" + str(game.player.position))

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func walk_to(x: float) -> void:
	var direction: int = 1 if x > game.player.position.x else -1
	var action: String = "move_right" if direction > 0 else "move_left"
	Input.action_press(action)
	for i in range(260):
		await physics_frame
		if (game.player.position.x - x) * direction >= 0:
			break
	Input.action_release(action)
	await frames(14)

func jump_to(x: float) -> void:
	# Separate physical key presses across frames, as a human release/repress does.
	await frames(2)
	var direction: int = 1 if x > game.player.position.x else -1
	var action: String = "move_right" if direction > 0 else "move_left"
	Input.action_press(action)
	Input.action_press("jump")
	for i in range(95):
		if "--trace-nav" in OS.get_cmdline_user_args() and i % 10 == 0:
			print("JUMP ",x," t=",i," p=",game.player.position," v=",game.player.velocity," jumps=",game.player.jumps," floor=",game.player.is_on_floor())
		if i == 9:
			Input.action_release("jump")
		elif i == 10:
			Input.action_press("jump")
		elif i == 32:
			Input.action_release("jump")
		if (game.player.position.x - x) * direction >= 0:
			Input.action_release(action)
		await physics_frame
	Input.action_release(action)
	if Input.is_action_pressed("jump"):
		Input.action_release("jump")

func clear_wave() -> void:
	for i in range(6):
		for bug in game.enemies.duplicate():
			if is_instance_valid(bug) and not bug.dead and not bug.is_boss:
				bug.take_hit(99999,1,true)
		await frames(3)
		if game.enemies.is_empty():
			return

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/navigation-record.json"
	await frames(3)
	game.start_run("story",20261112)
	await frames(5)
	game.player.invulnerable = 999
	game.player.position = Vector2(1510,598)
	game.player.reset_physics_interpolation()
	await frames(3)
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(30)
	Input.action_release("move_right")
	Input.action_release("dash")
	check(game.player.position.x < 1600,"Running and dashing cannot skip the first locked battle gate")
	await clear_wave()
	check(game.objective_target().label == "修复节点 1","After combat the persistent target returns to relay one")
	game.player.position = Vector2(430,598)
	game.player.velocity = Vector2.ZERO
	game.player.reset_physics_interpolation()
	await frames(5)
	await jump_to(620)
	check(absf(game.player.position.y - 490) < 3,"Actual double-jump input reaches the first stepping platform")
	await jump_to(910)
	check(absf(game.player.position.y - game.room_data.relays[0].p.y) < 3,"Actual movement reaches the first high relay")
	game.interact()
	await frames(3)
	check(game.relay_count == 1 and game.gates[0].open,"Using the first relay physically opens its gate and starts wave two")
	await walk_to(1660)
	check(game.player.position.x > 1630,"The opened first gate can actually be traversed")
	game.player.position = Vector2(2570,598)
	game.player.velocity = Vector2.ZERO
	game.player.reset_physics_interpolation()
	await frames(3)
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(game.player.position.x < 2650,"Second battle gate prevents reaching the empty end before its relay")
	await clear_wave()
	var target: Dictionary = game.objective_target()
	check(target.label == "修复节点 2" and target.p.x < game.player.position.x,"Standing near the locked end points back to the second relay")
	game.player.position = Vector2(1700,598)
	game.player.velocity = Vector2.ZERO
	game.player.reset_physics_interpolation()
	await frames(5)
	await jump_to(1940)
	check(absf(game.player.position.y - 480) < 3,"The second route's stepping platform is reachable with player input")
	await jump_to(2190)
	check(game.player.position.distance_to(game.room_data.relays[1].p) < 60,"The second relay can be reached without teleporting to it")
	game.interact()
	await frames(20)
	check(game.gates[1].open and is_instance_valid(game.boss_ref),"Repairing relay two opens the boss gate and spawns the boss")
	if is_instance_valid(game.boss_ref):
		check(game.boss_ref.position.x > 3000 and absf(game.boss_ref.position.y - 600) < 5,"Boss appears at the right end without overlapping a low platform")
		check(game.objective_target().label == "关底 Boss","The objective now leads directly to the boss")
		var add: Node = game.spawn_bug(game.player.position + Vector2(35,0),"ugs",false,1)
		check(game.objective_target().p == game.boss_ref.position,"Boss guidance is not diverted by nearby summoned enemies")
		add.dead = true
		add.queue_free()
		game.boss_ref.take_hit(99999,1,true)
		await frames(3)
		check(game.state == "upgrade","Defeating the final target opens the skill reward")
	# Verify all six layout variants contain reachable, supported relay anchors.
	var layouts: Dictionary = {}
	var layout_seeds: Dictionary = {}
	for seed_value in range(1,65):
		var room: Dictionary = game.Rooms.generate(seed_value,0,"normal")
		layouts[room.layout] = true
		if not layout_seeds.has(room.layout):
			layout_seeds[room.layout] = seed_value
		for relay in room.relays:
			var supported: bool = room.platforms.any(func(rect): return rect.position.y == relay.p.y and relay.p.x >= rect.position.x and relay.p.x <= rect.end.x)
			check(supported,"Seed %d relay rests on an actual platform" % seed_value)
	check(layouts.size() == 6,"Navigation fixtures cover every layout variant")
	for layout in layout_seeds:
		game.start_run("story",layout_seeds[layout])
		game.player.position = Vector2(430,598)
		game.player.velocity = Vector2.ZERO
		game.player.invulnerable = 999
		game.player.reset_physics_interpolation()
		await frames(5)
		await jump_to(620)
		await jump_to(910)
		check(game.player.position.distance_to(game.room_data.relays[0].p) < 40,"Real double-jump route reaches relay one in layout %d" % layout)
	game.start_run("story",55)
	game.room_phase = "combat"
	for spec in [[2.8,"idle"],[3.0,"warning"],[3.8,"active"],[4.59,"active"],[4.6,"idle"],[5.0,"idle"]]:
		game.room_clock = spec[0]
		check(game.trap_state(0) == spec[1],"Trap visual and damage phase agree at %.2fs" % spec[0])
	game.player.position = game.trap_area(0).get_center() + Vector2(0,35)
	game.player.invulnerable = 0
	var hp: int = game.player.health
	game.room_clock = 3.0
	game.update_hazards(0.01)
	check(game.player.health == hp,"Trap warning is safe")
	game.room_clock = 3.9
	game.update_hazards(0.01)
	check(game.player.health == hp - 1,"Trap damage starts only during visible eruption")
	print("NAVIGATION RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames(3)
	quit(1 if failures else 0)
