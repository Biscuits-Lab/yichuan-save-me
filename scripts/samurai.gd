class_name Samurai
extends CharacterBody2D

var game: Node
var facing: float = 1
var health: int = 8
var energy: float = 100
var jumps: int = 0
var coyote: float = 0
var jump_buffer: float = 0
var attack_buffer: float = 0
var invulnerable: float = 0
var hurt_pose: float = 0
var attack_time: float = 0
var attack_duration: float = 0.5
var attack_cooldown: float = 0
var skill_cooldown: float = 0
var swords_cooldown: float = 0
var shield_cooldown: float = 0
var shield_time: float = 0
var dash_time: float = 0
var dash_cooldown: float = 0
var skill_time: float = 0
var combo: int = 0
var combo_window: float = 0
var hit_ids: Array[int] = []
var dash_hit_ids: Array[int] = []
var run_phase: float = 0
var visual_attack: float = 0
var clock: float = 0
var visual: Sprite2D
var visual_state: String = "idle"

func _ready() -> void:
	var hitbox := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34,70)
	hitbox.shape = shape
	hitbox.position.y = -35
	add_child(hitbox)
	collision_layer = 2
	collision_mask = 1
	z_index = 5
	visual = Sprite2D.new()
	visual.centered = false
	visual.region_enabled = true
	# The body moves on physics ticks. Atlas offsets and facing change on render
	# frames, so only the body's transform may use physics interpolation.
	# In 2D a child with interpolation off still inherits its parent's smooth motion.
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var blend := ShaderMaterial.new()
	blend.shader = load("res://assets/sprite_blend.gdshader")
	visual.material = blend
	add_child(visual)

func reset_motion() -> void:
	jumps = 0
	attack_time = 0
	attack_cooldown = 0
	attack_buffer = 0
	dash_time = 0
	dash_cooldown = 0
	skill_time = 0
	skill_cooldown = 0
	swords_cooldown = 0
	shield_cooldown = 0
	shield_time = 0
	hurt_pose = 0
	facing = 1
	run_phase = 0
	visual_attack = 0

func bounds() -> Rect2:
	return Rect2(position + Vector2(-17,-70),Vector2(34,70))

func _physics_process(delta: float) -> void:
	if game.state != "playing":
		return
	for property in ["invulnerable","hurt_pose","attack_time","attack_cooldown","dash_cooldown","skill_time","combo_window","jump_buffer","attack_buffer","skill_cooldown","swords_cooldown","shield_cooldown","shield_time"]:
		set(property,maxf(0,float(get(property)) - delta))
	energy = minf(100,energy + delta * (10 + game.rank("energy") * 3) * (0.6 if game.event.hazard == "vacuum" else 1))
	var was_grounded: bool = is_on_floor()
	if was_grounded:
		jumps = 0
		coyote = 0.11
	else:
		coyote = maxf(0,coyote - delta)
	var axis: float = Input.get_axis("move_left","move_right")
	if axis != 0 and attack_time <= 0:
		facing = signf(axis)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.14
	if jump_buffer > 0 and (coyote > 0 or jumps < 2):
		if coyote == 0 and jumps == 0:
			jumps = 1
		velocity.y = -540 if jumps == 0 else -490 - game.rank("jump") * 20
		jumps += 1
		coyote = 0
		jump_buffer = 0
		game.audio.sfx("jump")
		game.burst(position,Color("b7e8c6"),8)
	if Input.is_action_just_released("jump") and velocity.y < -210:
		velocity.y = -210
	if Input.is_action_just_pressed("attack"):
		attack_buffer = 0.2
	if (attack_buffer > 0 or Input.is_action_pressed("attack")) and attack_cooldown <= 0 and dash_time <= 0:
		attack()
		attack_buffer = 0
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0:
		dash_time = 0.17
		dash_cooldown = 0.9 * (1 - game.rank("dash") * 0.18)
		invulnerable = maxf(invulnerable,0.25 + game.rank("dash") * 0.04)
		attack_time = 0
		dash_hit_ids.clear()
		game.audio.sfx("dash")
		game.vfx(3,position + Vector2(-facing * 65,-45),80,0.22,facing)
	if Input.is_action_just_pressed("skill"):
		cast_skill()
	if Input.is_action_just_pressed("swords"):
		game.use_swords()
	if Input.is_action_just_pressed("shield") and game.rank("rollback") > 0 and shield_cooldown <= 0:
		shield_time = 2 + game.rank("rollback") * 0.3
		shield_cooldown = (15 - game.rank("rollback") * 2) * game.cooldown_scale()
		if game.rank("rollback") >= 2:
			health = mini(game.max_health(),health + 1)
		game.vfx(2,position + Vector2(0,-40),120,0.45)
	if dash_time > 0:
		dash_time -= delta
		velocity = Vector2(facing * (790 + game.rank("dash") * 25),0)
		game.trails.append({"p":position,"life":0.16})
		if game.rank("dash_cut") > 0:
			for bug in game.enemies.duplicate():
				if is_instance_valid(bug) and not bug.dead and not dash_hit_ids.has(bug.get_instance_id()) and bounds().grow(15).intersects(bug.get_bounds()):
					dash_hit_ids.append(bug.get_instance_id())
					bug.take_hit(2 * game.rank("dash_cut"),facing,true)
	else:
		if hurt_pose <= 0:
			velocity.x = move_toward(velocity.x,axis * (205 if attack_time > 0 else 290),delta * 1900)
		velocity.y = minf(850,velocity.y + 1450 * delta)
	move_and_slide()
	if not was_grounded and is_on_floor() and game.rank("jump") > 0:
		energy = minf(100,energy + game.rank("jump") * 3)
	position.x = clampf(position.x,25,game.world_length - 25)
	if position.y > 850:
		game.fall_recover()
	if attack_time > attack_duration * 0.2 and attack_time < attack_duration * 0.65:
		var reach: float = 104 + game.rank("reach") * 18
		var strike := Rect2(position + Vector2(6 if facing > 0 else -reach - 6,-112),Vector2(reach,124))
		for bug in game.enemies.duplicate():
			if is_instance_valid(bug) and not bug.dead and not hit_ids.has(bug.get_instance_id()) and strike.intersects(bug.get_bounds()):
				hit_ids.append(bug.get_instance_id())
				game.resolve_attack(bug,game.melee_damage() + (1 if combo == 3 else 0),facing)

func attack() -> void:
	combo = combo % 3 + 1 if combo_window > 0 else 1
	combo_window = 1.0
	attack_duration = 0.5 / (1 + game.rank("haste") * 0.1)
	attack_time = attack_duration
	visual_attack = 0
	attack_cooldown = attack_duration
	hit_ids.clear()
	game.audio.sfx("slash")

func cast_skill() -> void:
	if energy < 35 or skill_cooldown > 0:
		return
	energy -= 35
	skill_cooldown = 3.8 * game.cooldown_scale()
	skill_time = 0.42
	invulnerable = maxf(invulnerable,0.35)
	game.shake = 6
	game.audio.sfx("skill")
	var radius: float = 225 + game.rank("breakpoint") * 24
	game.vfx(2,position + Vector2(0,-40),radius * 1.8,0.45)
	for bug in game.enemies.duplicate():
		if is_instance_valid(bug) and not bug.dead and position.distance_to(bug.position) < radius:
			bug.take_hit(3 + game.rank("breakpoint") * 2 + game.rank("overclock"),signf(bug.position.x - position.x),true)
	for orb in game.projectiles:
		if not orb.friendly and orb.p.distance_to(position) < radius:
			orb.life = 0

func hurt(amount: int, source_x: float) -> void:
	if invulnerable > 0 or game.state != "playing":
		return
	if shield_time > 0 or game.ward > 0:
		if shield_time <= 0:
			game.ward -= 1
		invulnerable = 0.35
		game.vfx(4,position + Vector2(0,-40),100,0.2)
		return
	health = maxi(0,health - amount)
	invulnerable = 1.1
	hurt_pose = 0.16
	velocity = Vector2(signf(position.x - source_x) * 220,-200)
	game.shake = 7
	game.damage_flash = 0.2
	game.audio.sfx("hurt")
	game.vfx(6,position + Vector2(0,-40),95,0.25)
	game.say("救命" if health <= 2 else "坏啦",1.5)
	if game.rank("thorns") > 0:
		for bug in game.enemies.duplicate():
			if is_instance_valid(bug) and not bug.dead and bug.position.distance_to(position) < 180:
				bug.take_hit(game.rank("thorns") * 2,signf(bug.position.x - position.x),true)
	if health <= 0:
		game.die()

func _process(delta: float) -> void:
	if not game.actions_atlas:
		return
	if game.state == "playing":
		clock += delta
		run_phase = fmod(run_phase + delta * 20 * clampf(absf(velocity.x) / 290,0,1.3),16)
		visual_attack += delta / maxf(0.1,attack_duration) * 15
	var next_state: String = "idle"
	var atlas: RefCounted = game.actions_atlas
	var frame: float = 0
	if hurt_pose > 0:
		next_state = "hurt"
		frame = 6
	elif dash_time > 0:
		next_state = "dash"
		frame = 5
	elif attack_time > 0:
		next_state = "attack"
		atlas = game.attack_atlas
		frame = minf(15,visual_attack)
	elif not is_on_floor() and game.state != "title":
		next_state = "jump"
		frame = 3
	elif absf(velocity.x) > 18:
		next_state = "run"
		atlas = game.run_atlas
		frame = run_phase
	visual_state = next_state
	var first: int = int(frame)
	var second: int = (first + 1) % 16 if next_state == "run" else mini(15,first + 1)
	if atlas == game.actions_atlas:
		second = first
	var a: Dictionary = atlas.frames[first]
	var b: Dictionary = atlas.frames[second]
	var scale_factor: float = 105.0 / atlas.row_heights[first / atlas.columns]
	visual.texture = atlas.texture
	visual.region_rect = a.region
	# Flip texels inside the frame instead of interpolating a signed transform.
	# Reflect the frame's anchor as well, keeping the same root under both facings.
	visual.flip_h = facing < 0
	visual.scale = Vector2.ONE * scale_factor
	var anchor: Vector2 = a.anchor
	if visual.flip_h:
		anchor.x = a.region.size.x - anchor.x
	visual.position = -anchor * scale_factor
	var material: ShaderMaterial = visual.material
	var dimensions: Vector2 = atlas.texture.get_size()
	material.set_shader_parameter("frame_rect",Vector4(a.region.position.x / dimensions.x,a.region.position.y / dimensions.y,a.region.size.x / dimensions.x,a.region.size.y / dimensions.y))
	material.set_shader_parameter("next_rect",Vector4(b.region.position.x / dimensions.x,b.region.position.y / dimensions.y,b.region.size.x / dimensions.x,b.region.size.y / dimensions.y))
	material.set_shader_parameter("blend_weight",fmod(frame,1.0))
	modulate.a = 0.6 + sin(clock * 30) * 0.25 if invulnerable > 0 else 1
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0,2),0,Vector2(1,0.2))
	draw_circle(Vector2.ZERO,26,Color(0,0,0,0.25))
	draw_set_transform(Vector2.ZERO)
	if shield_time > 0 or game.ward > 0:
		draw_arc(Vector2(0,-48),61,0,TAU,36,Color(0.7,0.94,0.87,0.55),2)
	if skill_time > 0:
		draw_arc(Vector2(0,-40),(1 - skill_time / 0.42) * (225 + game.rank("breakpoint") * 24),0,TAU,40,Color(0.6,1,0.84,skill_time * 1.8),3)
