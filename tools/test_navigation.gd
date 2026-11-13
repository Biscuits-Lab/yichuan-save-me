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
	for i in range(400):
		await physics_frame
		if (game.player.position.x - x) * direction >= 0:
			break
	Input.action_release(action)
	await frames(12)

func jump_to(x: float) -> void:
	await frames(2)
	var direction: int = 1 if x > game.player.position.x else -1
	var action: String = "move_right" if direction > 0 else "move_left"
	Input.action_press(action)
	Input.action_press("jump")
	for i in range(95):
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
	Input.action_release("jump")

func finish_area() -> void:
	for i in range(60):
		for bug in game.enemies.duplicate():
			if is_instance_valid(bug) and not bug.dead and not bug.is_boss:
				bug.take_hit(99999,1,true)
		await frames(3)
		if game.room_phase in ["approach","boss"]:
			return
	check(false,"Both waves and any split enemies terminate")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/navigation-record.json"
	await frames(3)
	game.difficulty_index = 1
	game.start_run("story",20261112)
	await frames(5)
	game.player.invulnerable = 999
	for area in range(3):
		var offset: float = area * game.Rooms.ZONE_LENGTH
		await walk_to(offset + 430)
		await jump_to(offset + 620)
		check(absf(game.player.position.y - 490) < 3,"Area %d optional first high platform is reachable with real input" % (area + 1))
		await jump_to(offset + 910)
		check(game.player.position.y < 450 and absf(game.player.position.x - offset - 910) < 70,"Area %d optional upper route is reachable" % (area + 1))
		var gate_x: float = game.room_data.gates[area]
		await walk_to(gate_x + 80)
		check(game.player.position.x < gate_x and not game.gates[area].open,"The uncleared area's gate blocks actual movement")
		check(game.room_phase == "combat" and game.objective_target().label == "剩余故障","Guidance leads to enemies instead of asking for a return to a node")
		await finish_area()
		check(game.gates[area].open and game.room_data.relays[area].done,"Area %d gate unlocks automatically after both waves" % (area + 1))
		await walk_to(gate_x + 90)
		check(game.player.position.x > gate_x + 50,"The automatically opened gate can actually be crossed without E")
	check(game.relay_count == 3 and game.room_wave == 5,"All six waves and all three gates precede the boss")
	check(is_instance_valid(game.boss_ref) and game.boss_ref.position.x >= game.room_data.arena.x,"The final boss appears inside the extended final arena")
	check(game.objective_target().label == "关底 Boss","Guidance points straight to the boss at the end")
	await walk_to(game.room_data.arena.x + 200)
	check(game.player.position.x > 5800,"The full extended level is physically traversable")
	var add: Node = game.spawn_bug(game.player.position + Vector2(35,0),"ugs",false,1)
	check(game.objective_target().p == game.boss_ref.position,"A nearby summon cannot divert final boss guidance")
	add.dead = true
	add.queue_free()
	game.boss_ref.take_hit(99999,1,true)
	await frames(3)
	check(game.state == "upgrade","Defeating the boss still opens the skill reward")
	var layouts: Dictionary = {}
	for seed_value in range(1,65):
		var room: Dictionary = game.Rooms.generate(seed_value,0,"normal")
		if not layouts.has(room.layout):
			layouts[room.layout] = seed_value
		check(room.relays.all(func(relay): return room.platforms.any(func(rect): return rect.has_point(relay.p + Vector2(0,2)))),"Seed %d automatic nodes rest on real ground" % seed_value)
	check(layouts.size() == 6,"Navigation fixtures cover all six layout variants")
	for layout in layouts:
		game.start_run("story",layouts[layout])
		game.player.position = Vector2(430,598)
		game.player.velocity = Vector2.ZERO
		game.player.invulnerable = 999
		game.player.reset_physics_interpolation()
		await frames(5)
		await jump_to(620)
		await jump_to(910)
		check(game.player.position.y < 450 and absf(game.player.position.x - 910) < 70,"Actual optional high route works in layout %d" % layout)
	# Recovery must use the local ground throughout the longer level.
	game.room_phase = "recovery_test"
	for gap in game.room_data.gaps:
		game.player.health = game.max_health()
		game.player.position = Vector2(gap.get_center().x,900)
		game.fall_recover()
		check(absf(game.player.position.x - gap.get_center().x) < 250 and game.player.position.y < 650,"Falling recovers locally instead of teleporting to the old short map")
	print("NAVIGATION RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames(3)
	quit(1 if failures else 0)
