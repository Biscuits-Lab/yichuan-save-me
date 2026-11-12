extends SceneTree

# Requires the actual renderer: local transforms can look correct in a headless
# test while Godot displays an interpolated sprite hundreds of pixels away.
var game: Node
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func render_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func head_sample(foot: Vector2) -> Dictionary:
	var img: Image = root.get_texture().get_image()
	var count: int = 0
	var total := Vector2.ZERO
	for y in range(maxi(0,int(foot.y - 170)),mini(img.get_height(),int(foot.y - 35)),2):
		for x in range(maxi(0,int(foot.x - 260)),mini(img.get_width(),int(foot.x + 260)),2):
			var color: Color = img.get_pixel(x,y)
			# Dash grants invulnerability and deliberately dims the sprite. Track
			# the head's hue even at the lowest flash opacity, not its brightness.
			if color.r > 0.15 and color.r > color.g * 1.1 and color.g > color.b * 1.3:
				count += 1
				total += Vector2(x,y)
	return {"p":total / maxf(1,count),"count":count}

func run() -> void:
	Engine.physics_ticks_per_second = 20
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/player-motion-record.json"
	game.start_run("story",20261112)
	game.set_process(false)
	game.hud.hide()
	game.scenery.hide()
	for i in range(12):
		await physics_frame
	game.player.position = Vector2(640,600)
	game.player.velocity = Vector2.ZERO
	game.player.invulnerable = 0
	game.player.set_physics_process(false)
	game.player.reset_physics_interpolation()
	var previous: Dictionary = {}
	var max_pose_step: float = 0
	var missing: int = 0
	var max_root_error: float = 0
	# Fixed body + rapidly alternating facing / atlas isolates visual teleports.
	for frame in range(176):
		game.player.attack_time = 0
		game.player.dash_time = 0
		game.player.hurt_pose = 0
		game.player.velocity.x = 0
		game.player.facing = 1
		if frame >= 16 and frame < 64:
			game.player.velocity.x = 290
			game.player.facing = -1 if frame >= 32 and frame < 48 else 1
		if frame >= 80 and frame < 112:
			game.player.attack_time = 0.4
			game.player.visual_attack = (frame - 80) * 0.45
		if frame >= 112 and frame < 128:
			game.player.facing = -1
			game.player.dash_time = 0.1
		if frame >= 144 and frame < 160:
			game.player.hurt_pose = 0.1
		await render_frame()
		var current: Dictionary = head_sample(Vector2(640,600))
		if current.count < 8:
			missing += 1
		elif not previous.is_empty() and previous.count >= 8:
			max_pose_step = maxf(max_pose_step,current.p.distance_to(previous.p))
		previous = current
		max_root_error = maxf(max_root_error,game.player.position.distance_to(Vector2(640,600)))
	check(missing == 0,"Hero remains visible in every rendered facing / pose transition")
	check(max_pose_step < 45,"No large visual teleport when the collision body is stationary")
	check(max_root_error < 0.01,"Animation changes never move the collision body")
	print("FIXED ROOT METRICS: max rendered head step=",max_pose_step," missing=",missing)
	# A quiet, flat fixture tests actual CharacterBody2D motion and camera follow.
	# It isolates movement from damage knockback, pits and intentional recovery.
	Engine.physics_ticks_per_second = 60
	for node in game.world.get_children():
		if node != game.player:
			node.queue_free()
	game.platforms.clear()
	var floor_rect := Rect2(0,600,3520,200)
	game.platforms.append(floor_rect)
	game.add_solid(floor_rect)
	game.room_data.traps = []
	game.coffee.clear()
	game.room_phase = "motion_test"
	game.player.position = Vector2(1600,600)
	game.player.velocity = Vector2.ZERO
	game.player.reset_motion()
	game.player.invulnerable = 0
	game.player.reset_physics_interpolation()
	game.camera_x = 1160
	game.world.position = Vector2(-1160,0)
	game.player.set_physics_process(true)
	game.set_process(true)
	for i in range(5):
		await render_frame()
	previous = {}
	var prior_position: Vector2 = game.player.position
	var max_body_step: float = 0
	var max_moving_step: float = 0
	var moving_missing: int = 0
	for frame in range(96):
		if frame == 0 or frame == 40:
			Input.action_release("move_left")
			Input.action_press("move_right")
		elif frame == 25:
			Input.action_release("move_right")
			Input.action_press("move_left")
		if frame in [8,22]:
			Input.action_press("jump")
		elif frame in [17,33]:
			Input.action_release("jump")
		if frame == 55:
			Input.action_press("dash")
		elif frame == 58:
			Input.action_release("dash")
		if frame == 74:
			Input.action_press("attack")
		elif frame == 77:
			Input.action_release("attack")
		await render_frame()
		max_body_step = maxf(max_body_step,game.player.position.distance_to(prior_position))
		prior_position = game.player.position
		var current: Dictionary = head_sample(game.player.position - Vector2(game.camera_x,0))
		if current.count < 8:
			moving_missing += 1
		elif not previous.is_empty() and previous.count >= 8:
			max_moving_step = maxf(max_moving_step,current.p.distance_to(previous.p))
		previous = current
	for action in ["move_left","move_right","jump","dash","attack"]:
		Input.action_release(action)
	check(max_body_step < 30,"Run, double jump and dash preserve continuous physical movement")
	check(moving_missing == 0 and max_moving_step < 55,"Hero and camera remain continuous throughout actual movement")
	print("MOVING METRICS: max body step=",max_body_step," max rendered step=",max_moving_step," missing=",moving_missing)
	game.state = "paused"
	for i in range(8):
		await render_frame()
	var paused: Dictionary = head_sample(game.player.position - Vector2(game.camera_x,0))
	var paused_position: Vector2 = game.player.position
	for i in range(8):
		await render_frame()
	var still_paused: Dictionary = head_sample(game.player.position - Vector2(game.camera_x,0))
	check(paused.p.distance_to(still_paused.p) < 0.1 and game.player.position == paused_position,"Pausing does not leave a drifting or fading duplicate hero")
	game.state = "playing"
	await render_frame()
	var resumed: Dictionary = head_sample(game.player.position - Vector2(game.camera_x,0))
	check(resumed.count >= 8 and resumed.p.distance_to(still_paused.p) < 45,"Resuming does not introduce a visual teleport")
	print("PLAYER MOTION RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	for i in range(3):
		await process_frame
	quit(1 if failures else 0)
