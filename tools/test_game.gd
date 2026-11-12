extends SceneTree

var checks: int = 0
var failures: int = 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/test-record.json"
	await frames(3)
	check(game.state == "title", "Starts at title screen")
	check(game.enemies.size() == 10, "All 3 tool encounters and the build boss exist")
	check(game.run_atlas != null and game.run_atlas.frames.size() == 16, "Generated running animation contains 16 usable frames")
	check(game.attack_atlas != null and game.attack_atlas.frames.size() == 16, "Generated attack animation contains 16 usable frames")
	check(game.enemies_atlas != null and game.enemies_atlas.frames.size() == 16, "All four generated monster animation sets are connected")
	check(game.effects_atlas != null and game.effects_atlas.frames.size() == 8, "All eight generated combat effects are connected")
	check(game.actions_atlas.texture.get_image().get_pixel(0, 0).a < 0.01, "Hero sprites retain actual transparent alpha")
	check(game.run_atlas.texture.get_image().get_pixel(0, 0).a < 0.01, "Run cycle has no white background matte")
	check(game.attack_atlas.texture.get_image().get_pixel(0, 0).a < 0.01, "Attack cycle retains transparent alpha")
	check(game.enemies_atlas.texture.get_image().get_pixel(0, 0).a < 0.01, "Monster sprites retain transparent alpha")
	game.handle_click(Vector2(200, 540))
	check(game.state == "guide", "Manual opens from title")
	game.handle_click(Vector2(1070, 88))
	check(game.state == "title", "Manual returns to title")
	game.handle_click(Vector2(200, 470))
	await frames(10)
	check(game.state == "playing" and game.stage == 0, "Start button enters the run")
	check(game.player.is_on_floor(), "Player lands on the real ground collision")
	var start_x: float = game.player.position.x
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(game.player.position.x > start_x + 60, "Movement input drives CharacterBody2D")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(2)
	check(game.player.velocity.y < 0 and game.player.jumps == 1, "First jump launches the player")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(2)
	check(game.player.jumps == 2 and game.player.velocity.y < 0, "Second jump works in the air")
	await frames(65)
	game.player.position = Vector2(1500, 598)
	game.interact()
	check(game.stage == 0 and not game.gates[0].open, "Unresolved UGS errors block the terminal")
	game.player.position = Vector2(450, 598)
	game.player.velocity = Vector2.ZERO
	await frames(2)
	var first: Node = game.enemies[0]
	first.position = game.player.position + Vector2(70, 0)
	first.origin = first.position
	first.stun = 2
	var hp_before: int = first.hp
	game.player.facing = 1
	Input.action_press("attack")
	await frames(9)
	Input.action_release("attack")
	check(first.hp < hp_before, "J attack damages a real enemy through its hitbox")
	var health_before: int = game.player.health
	game.player.invulnerable = 0
	game.player.hurt(1, game.player.position.x + 20)
	game.player.hurt(1, game.player.position.x + 20)
	check(game.player.health == health_before - 1, "Invulnerability prevents duplicate contact damage")
	game.player.energy = 100
	Input.action_press("dash")
	await frames(2)
	Input.action_release("dash")
	check(game.player.dash_cooldown > 0 and game.player.invulnerable > 0, "Dash has cooldown and invulnerability")
	await frames(12)
	for kind in ["ugs", "script", "p4"]:
		var targets: Array = game.enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.kind == kind)
		if kind == "p4":
			var locked: Node = targets[0]
			locked.shield_open = false
			var locked_hp: int = locked.hp
			locked.take_hit(1, 1, false)
			check(locked.hp == locked_hp, "P4 exclusive lock blocks ordinary attacks")
			game.player.position = locked.position - Vector2(80, 0)
			game.player.energy = 100
			game.player.cast_skill()
			check(locked.hp < locked_hp and game.player.energy < 100, "K spends energy and pierces P4 locks")
		for enemy in targets:
			if is_instance_valid(enemy) and not enemy.dead:
				enemy.take_hit(99, 1, true)
		await frames(2)
		var current: int = game.stage
		game.player.position = Vector2(float(game.STAGES[current].x), 598)
		game.player.velocity = Vector2.ZERO
		game.interact()
		check(game.stage == current + 1 and game.gates[current].open, "%s terminal advances progression and removes its gate" % kind)
		check(game.player.health == 6, "%s checkpoint refills health" % kind)
	check(game.repaired == 3, "Three tools are repaired before the boss")
	game.player.invulnerable = 0
	game.player.position.y = 1000
	game.fall_recover()
	check(game.player.position.distance_to(game.checkpoint) < 1, "Void fall restores the last checkpoint")
	var saved_kills: Dictionary = game.kills.duplicate()
	game.player.health = 1
	game.player.invulnerable = 0
	game.player.hurt(1, 6000)
	check(game.state == "dead" and game.speech == "哦豁，完蛋", "Death triggers Yichuan's actual catchphrase")
	game.respawn()
	check(game.state == "playing" and game.stage == 3 and game.kills == saved_kills, "Respawn preserves tool repairs and cleared enemies")
	game.player.position = Vector2(5480, 598)
	await frames(4)
	var boss: Node = game.enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.kind == "boss")[0]
	check(boss.boss_activated, "Entering the final district activates the build boss")
	boss.shot_timer = 0
	await frames(2)
	check(game.projectiles.size() >= 3, "Boss emits a real three-projectile attack")
	boss.take_hit(99, 1, true)
	await frames(2)
	check(game.state == "won" and game.repaired == 4, "Defeating the boss completes the entire pipeline")
	check(FileAccess.file_exists(game.record_path), "Completion saves the time record")
	var saved_time: float = game.best_time
	game.best_time = 0
	game.load_record()
	check(is_equal_approx(game.best_time, saved_time), "Saved time record round-trips")
	game.start_run()
	await frames(3)
	check(game.stage == 0 and game.kills.ugs == 0 and game.enemies.size() == 10, "A fresh run completely resets progression")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await frames(3)
	quit(1 if failures else 0)
