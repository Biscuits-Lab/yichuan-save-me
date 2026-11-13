extends SceneTree
var game: Node
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ",label)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

func title() -> void:
	game.state = "title"
	game.world.visible = false

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/run-options-test-record.json"
	game.difficulty_records = {}
	game.set_process(false)
	await frames()
	var health_values: Array[int] = []
	var mob_health: Array[int] = []
	var counts: Array[int] = []
	var timer_steps: Array[float] = []
	for index in range(3):
		title()
		game.handle_click(Vector2(506 + index * 96,487))
		check(game.difficulty_index == index,"Mouse difficulty choice %d is selected before starting" % index)
		game.activate_menu(0)
		check(game.run_difficulty == index and game.mode == "story","The selected difficulty is latched into the story run")
		health_values.append(game.player.health)
		mob_health.append(game.enemy_health(false))
		counts.append(game.enemies_per_wave(0))
		game.set_difficulty((index + 1) % 3)
		check(game.run_difficulty == index and game.difficulty_index == index,"Difficulty cannot be changed mid-run")
		var bug: Node = game.spawn_bug(Vector2(650,598),"ugs")
		bug.set_physics_process(false)
		bug.shot_timer = 5
		game.player.position = Vector2(550,598)
		bug.process_mob(0.2,-100)
		timer_steps.append(5 - bug.shot_timer)
		game.player.invulnerable = 0
		game.player.hurt(1,400)
		check(game.player.health == game.max_health() - (2 if index == 2 else 1),"Actual incoming damage respects the chosen difficulty")
		await frames()
	check(health_values == [12,8,6],"Difficulty changes actual starting health")
	check(mob_health[0] < mob_health[1] and mob_health[1] < mob_health[2],"Difficulty changes actual enemy health")
	check(counts[0] < counts[1] and counts[1] < counts[2],"Difficulty changes wave density")
	check(timer_steps[0] < timer_steps[1] and timer_steps[1] < timer_steps[2],"Difficulty changes actual attack cooldown progression")
	title()
	key(KEY_LEFT)
	check(game.difficulty_index == 1,"Left / right keys adjust difficulty without activating a mode")
	key(KEY_DOWN)
	check(game.selection == 1,"Up / down still select the game mode")
	game.activate_menu(1)
	check(game.mode == "endless" and game.run_difficulty == 1,"Endless mode also receives the selected difficulty")
	await frames()
	# Home opens a real paused panel. Each toggle is independent and reversible.
	game.player.invulnerable = 0
	key(KEY_HOME)
	check(game.state == "cheats" and game.cheat_return_state == "playing","Home opens cheats and suspends the active run")
	var still_position: Vector2 = game.player.position
	await frames(12)
	check(game.player.position == still_position,"The character does not move behind the cheat panel")
	key(KEY_1)
	check(game.cheat_invincible and not game.cheat_one_hit,"Key 1 enables invulnerability independently")
	game.handle_click(Vector2(640,402))
	check(game.cheat_one_hit,"One-hit kill can be enabled with the mouse")
	key(KEY_HOME)
	game.player.invulnerable = 0
	var hp: int = game.player.health
	game.player.hurt(999,0)
	check(game.player.health == hp and game.state == "playing","Invulnerability blocks real damage without killing the run")
	var shielded: Node = game.spawn_bug(Vector2(720,598),"p4")
	shielded.set_physics_process(false)
	shielded.shield_open = false
	shielded.take_hit(1,1,false)
	check(shielded.dead,"One-hit kill defeats a shielded P4 enemy with a normal hit")
	game.room_phase = "boss"
	var boss: Node = game.spawn_bug(game.room_data.boss_spawn,"boss",true)
	boss.set_physics_process(false)
	boss.take_hit(1,1,false)
	check(boss.dead and game.state == "upgrade","One-hit kill defeats a boss and still opens its real skill reward")
	check(game.run_assisted,"A run remembers that cheats were enabled")
	check(game.difficulty_records.is_empty(),"Cheat-assisted results do not replace normal difficulty records")
	game.state = "paused"
	key(KEY_HOME)
	key(KEY_1)
	key(KEY_2)
	key(KEY_ESCAPE)
	check(game.state == "paused" and not game.cheat_invincible and not game.cheat_one_hit,"Turning cheats off returns to the previous paused state")
	game.state = "playing"
	game.player.invulnerable = 0
	hp = game.player.health
	game.player.hurt(1,0)
	check(game.player.health == hp - 1,"Damage works again after invulnerability is disabled")
	var regular: Node = game.spawn_bug(Vector2(750,598),"ugs")
	regular.set_physics_process(false)
	regular.take_hit(1,1,true)
	check(not regular.dead,"Normal multi-hit combat returns when one-hit kill is disabled")
	await frames()
	# Empty entry, seeded plans and supported encounter points across many seeds.
	var plans: Dictionary = {}
	var identities: Dictionary = {}
	var encounter_seed: int = 0
	for seed_value in range(1,65):
		var room: Dictionary = game.Rooms.generate(seed_value,0,"normal")
		check(room.length >= 7000 and room.zones.size() == 3,"Seed %d has an extended three-area level" % seed_value)
		check(not room.has("traps"),"Seed %d contains no periodic floor vents" % seed_value)
		var supported: bool = true
		for encounter in room.encounters:
			identities[encounter.id] = true
			supported = supported and encounter.trigger_x > 1000 and room.platforms.any(func(rect): return rect.has_point(encounter.p + Vector2(0,2)))
		check(supported,"Random encounters are away from entry and stand on real ground")
		check(room.encounters == game.Rooms.generate(seed_value,0,"normal").encounters,"Encounter plans reproduce with the room seed")
		plans[str(room.encounters)] = true
		if encounter_seed == 0 and not room.encounters.is_empty():
			encounter_seed = seed_value
	check(plans.size() > 20 and identities.size() == 4,"Encounter locations and all four identities vary across runs")
	title()
	game.set_difficulty(1)
	game.start_run("story",encounter_seed)
	check(game.npcs.is_empty(),"No NPC is instantiated at the start of a room")
	var first: Dictionary = game.room_data.encounters[0]
	game.player.position.x = first.trigger_x - 1
	game.reveal_encounters()
	check(game.npcs.is_empty(),"Unreached encounters stay hidden")
	game.player.position.x += 2
	game.reveal_encounters()
	check(game.npcs.size() == 1 and game.npcs[0].id == first.id,"An actual encounter appears only after travelling to its trigger")
	game.reveal_encounters()
	check(game.npcs.size() == 1,"Revisiting an encounter cannot duplicate its NPC")
	# A producer met between areas queues work for the next area, never behind
	# a future locked gate (which would prevent the current area's completion).
	game.npcs[0].id = 1
	game.npc_selected = 0
	game.room_phase = "approach"
	game.state = "npc"
	var before: int = game.enemies.size()
	game.accept_npc()
	check(game.contract_pending and game.enemies.size() == before,"A between-area contract queues work instead of spawning unreachable enemies")
	game.spawn_wave(0)
	check(not game.contract_pending and game.enemies.size() == before + game.enemies_per_wave(0) + 2,"Queued work appears in the next real combat area")
	# Floor time alone can no longer cause damage, drain energy, or emit bullets.
	for event in game.Data.EVENTS:
		game.event = event
		game.projectiles.clear()
		game.hazards.clear()
		game.player.invulnerable = 0
		game.player.health = game.max_health()
		game.player.energy = 75
		for tick in range(40):
			game.room_clock = tick * 0.5
			game.update_hazards(0.5)
		check(game.player.health == game.max_health() and game.player.energy == 75 and game.projectiles.is_empty(),"No passive vent damage or bullets in " + event.tool)
		var theme: Dictionary = game.Data.ENVIRONMENTS[event.kind]
		check(theme.has("motif") and ResourceLoader.exists("res://assets/art/environments/%s.png" % event.kind),"Distinct environment assets exist for " + event.tool)
	# Scores stay separate by difficulty and legacy standard records still load.
	title()
	game.set_difficulty(0)
	game.start_run("endless",777)
	game.cleared_rooms = 3
	game.score = 900
	game.update_records(false)
	title()
	game.set_difficulty(2)
	check(game.best_floor == 0,"Casual records do not leak into hard difficulty")
	game.start_run("endless",888)
	game.cleared_rooms = 1
	game.score = 200
	game.update_records(false)
	game.load_record()
	check(game.best_floor == 1 and game.best_score == 200,"Hard difficulty records round-trip independently")
	title()
	game.set_difficulty(0)
	check(game.best_floor == 3 and game.best_score == 900,"Switching back restores the casual record")
	game.start_run("story",999)
	game.player.position = Vector2(1450,598)
	game.spawn_wave(1)
	check(game.enemies.all(func(bug): return bug.position.x >= 1240 and bug.position.x <= 1640),"Reinforcements arrive in the forward half instead of sending the player back to the entrance")
	check(game.enemies.all(func(bug): return absf(bug.position.x - game.player.position.x) >= 160),"Reinforcements do not appear directly on top of the player")
	game.start_run("story",999)
	game.player.position = Vector2(900,598)
	game.spawn_wave(0)
	check(game.enemies.all(func(bug): return game.ground_support(Vector2(bug.position.x,602))),"Spawn avoidance never relocates a ground enemy into an unwalkable gap")
	game.record_path = "res://.tools/legacy-record-migration-test.json"
	var legacy := FileAccess.open(game.record_path,FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"rogue_best_time":123.0,"best_floor":7,"best_score":2500}))
	legacy.close()
	game.load_record()
	check(game.difficulty_index == 1 and game.best_floor == 7 and game.best_score == 2500 and game.best_time == 123.0,"Existing records migrate intact into standard difficulty")
	title()
	game.set_difficulty(2)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.record_path))
	check(saved.best_floor == 7 and saved.best_score == 2500 and saved.difficulty_records.standard.best_time == 123.0,"Saving a new difficulty keeps the original standard record and legacy fields")
	print("RUN OPTIONS RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames()
	quit(1 if failures else 0)
