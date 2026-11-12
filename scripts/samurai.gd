class_name Samurai
extends CharacterBody2D

var game: Node
var facing: float = 1.0
var health: int = 6
var energy: float = 100.0
var jumps: int = 0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var invulnerable: float = 0.0
var attack_time: float = 0.0
var attack_cooldown: float = 0.0
var dash_time: float = 0.0
var dash_cooldown: float = 0.0
var skill_time: float = 0.0
var combo: int = 0
var combo_window: float = 0.0
var clock: float = 0.0
var distance_walked: float = 0.0
var attack_serial: int = 0
var hit_ids: Array[int] = []

func _ready() -> void:
	var hitbox := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(34, 68)
	hitbox.shape = shape
	hitbox.position.y = -34
	add_child(hitbox)
	collision_layer = 2
	collision_mask = 1
	z_index = 5

func _physics_process(delta: float) -> void:
	if game.state != "playing":
		queue_redraw()
		return
	clock += delta
	invulnerable = maxf(0, invulnerable - delta)
	attack_time = maxf(0, attack_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	skill_time = maxf(0, skill_time - delta)
	combo_window = maxf(0, combo_window - delta)
	energy = minf(100, energy + delta * 10)
	jump_buffer = maxf(0, jump_buffer - delta)
	if is_on_floor():
		jumps = 0
		coyote = 0.11
	else:
		coyote = maxf(0, coyote - delta)
	var axis: float = Input.get_axis("move_left", "move_right")
	if axis != 0:
		facing = signf(axis)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13
	if jump_buffer > 0 and (coyote > 0 or jumps < 2):
		if coyote == 0 and jumps == 0:
			jumps = 1
		velocity.y = -540 if jumps == 0 else -490
		jumps += 1
		coyote = 0
		jump_buffer = 0
		game.audio.sfx("jump")
		game.burst(position + Vector2(0, -4), Color("c3f7cf"), 9)
	if Input.is_action_just_released("jump") and velocity.y < -210:
		velocity.y = -210
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0:
		attack()
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0:
		dash_time = 0.16
		dash_cooldown = 0.8
		invulnerable = maxf(invulnerable, 0.25)
		game.audio.sfx("dash")
		game.vfx(3, position + Vector2(-facing * 65, -45), 80, 0.22, facing)
	if Input.is_action_just_pressed("skill") and energy >= 35:
		cast_skill()
	if dash_time > 0:
		dash_time -= delta
		velocity = Vector2(facing * 850, 0)
		game.trails.append({"p": position, "face": facing, "life": 0.22})
	else:
		velocity.x = move_toward(velocity.x, axis * 290, delta * 2400)
		velocity.y = minf(850, velocity.y + 1450 * delta)
	distance_walked += absf(velocity.x * delta)
	move_and_slide()
	position.x = clampf(position.x, 32, game.world_length - 32)
	if position.y > 880:
		game.fall_recover()
	if attack_time > 0.06 and attack_time < 0.27:
		var strike := Rect2(position + Vector2(8 if facing > 0 else -112, -100), Vector2(104, 112))
		for enemy in game.enemies:
			if is_instance_valid(enemy) and enemy.hp > 0 and not hit_ids.has(enemy.get_instance_id()) and strike.intersects(enemy.get_bounds()):
				hit_ids.append(enemy.get_instance_id())
				enemy.take_hit(2 if combo == 3 else 1, facing, false)
	queue_redraw()

func attack() -> void:
	combo = combo + 1 if combo_window > 0 else 1
	if combo > 3:
		combo = 1
	combo_window = 0.8
	attack_time = 0.36
	attack_cooldown = 0.38
	hit_ids.clear()
	attack_serial += 1
	game.audio.sfx("slash")
	game.vfx(0 if combo != 3 else 1, position + Vector2(facing * 65, -52), 120, 0.32, facing)

func cast_skill() -> void:
	energy -= 35
	skill_time = 0.42
	invulnerable = maxf(invulnerable, 0.4)
	game.shake = 8
	game.audio.sfx("skill")
	game.say("断点一开，谁都别动。", 2.0)
	game.burst(position + Vector2(0, -40), Color("8cffe0"), 40)
	game.vfx(2, position + Vector2(0, -40), 390, 0.45)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.hp > 0 and position.distance_to(enemy.position) < 235:
			enemy.take_hit(3, signf(enemy.position.x - position.x), true)
	for projectile in game.projectiles:
		if projectile.p.distance_to(position) < 250:
			projectile.life = 0

func hurt(amount: int, source_x: float) -> void:
	if invulnerable > 0 or game.state != "playing":
		return
	health = maxi(0, health - amount)
	invulnerable = 1.2
	velocity = Vector2(signf(position.x - source_x) * 260, -260)
	game.shake = 10
	game.damage_flash = 0.25
	game.audio.sfx("hurt")
	game.burst(position + Vector2(0, -40), Color("ef8078"), 16)
	game.vfx(6, position + Vector2(0, -40), 95, 0.25)
	game.say("救命" if health <= 2 else "坏啦", 2.0)
	if health <= 0:
		game.die()

func _draw() -> void:
	if invulnerable > 0 and int(invulnerable * 18) % 2 == 0:
		modulate.a = 0.45
	else:
		modulate.a = 1
	draw_ellipse_shadow()
	var bob: float = sin(clock * 9) * 1.5 if is_on_floor() else -2.0
	var stride: float = sin(distance_walked * 0.075) * 3 if absf(velocity.x) > 20 and is_on_floor() else 0.0
	if game.actions_atlas:
		var atlas: RefCounted = game.actions_atlas
		var frame: int = 0
		if invulnerable > 0.95:
			frame = 6
		elif dash_time > 0:
			frame = 5
		elif attack_time > 0 and game.attack_atlas:
			atlas = game.attack_atlas
			frame = clampi(int((1.0 - attack_time / 0.36) * 16), 0, 15)
		elif not is_on_floor():
			frame = 3
		elif absf(velocity.x) > 20 and game.run_atlas:
			atlas = game.run_atlas
			frame = int(distance_walked / 11) % 16
		elif game.state == "won":
			frame = 7
		atlas.draw(self, frame, Vector2(0, bob), 105, facing)
	else:
		draw_set_transform(Vector2(0, bob), 0, Vector2(facing * 2.25, 2.25))
		draw_dog(self, clock, stride, attack_time > 0, false)
		draw_set_transform(Vector2.ZERO)
	if attack_time > 0:
		var phase: float = 1.0 - attack_time / 0.36
		var center := Vector2(facing * 10, -46)
		var start: float = -1.8 + phase * 1.8 if facing > 0 else PI - 1.8 + phase * 1.8
		draw_arc(center, 88, start, start + 1.65, 14, Color(0.56, 1, 0.86, attack_time * 3.5), 11, false)
		draw_arc(center, 92, start, start + 1.65, 14, Color(0.88, 1, 0.91, attack_time * 3.5), 3, false)
	if skill_time > 0:
		var radius: float = (1.0 - skill_time / 0.42) * 235
		draw_arc(Vector2(0, -38), radius, 0, TAU, 40, Color(0.55, 1, 0.85, skill_time * 2), 5, false)
		for i in range(8):
			var point := Vector2.from_angle(i * TAU / 8) * radius + Vector2(0, -38)
			draw_rect(Rect2(point, Vector2(7, 7)), Color("c6ffe1"))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 27, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)

static func draw_dog(canvas: CanvasItem, time: float = 0.0, stride: float = 0.0, attacking: bool = false, portrait: bool = false) -> void:
	var ink := Color("172735")
	var orange := Color("df9446")
	var light := Color("ffc36b")
	var cream := Color("fff0cb")
	# Curled tail, boots, lacquered lamellar armour.
	canvas.draw_rect(Rect2(-18, -18, 11, 9), ink)
	canvas.draw_rect(Rect2(-18, -19, 7, 6), orange)
	canvas.draw_rect(Rect2(-18, -21, 6, 3), light)
	canvas.draw_rect(Rect2(-16, -18, 3, 3), cream)
	canvas.draw_rect(Rect2(-9 + stride, -9, 7, 9), ink)
	canvas.draw_rect(Rect2(3 - stride, -9, 7, 9), ink)
	canvas.draw_rect(Rect2(-10 + stride, -3, 9, 3), Color("ccd9c0"))
	canvas.draw_rect(Rect2(3 - stride, -3, 9, 3), Color("ccd9c0"))
	canvas.draw_rect(Rect2(-11, -24, 23, 15), ink)
	canvas.draw_rect(Rect2(-9, -23, 19, 12), Color("334957"))
	for y in [-21, -17, -13]:
		canvas.draw_rect(Rect2(-9, y, 19, 1), Color("79917f"))
		canvas.draw_rect(Rect2(-4, y + 1, 2, 2), Color("b9a16a"))
	canvas.draw_rect(Rect2(-11, -11, 24, 2), Color("d79d62"))
	canvas.draw_rect(Rect2(-1, -24, 3, 14), Color("bc9b65"))
	# Angular Shiba ears and face, matching the supplied avatar.
	canvas.draw_rect(Rect2(-12, -43, 8, 16), ink)
	canvas.draw_rect(Rect2(5, -43, 8, 16), ink)
	canvas.draw_rect(Rect2(-10, -41, 4, 10), orange)
	canvas.draw_rect(Rect2(7, -41, 4, 10), orange)
	canvas.draw_rect(Rect2(-9, -38, 2, 5), Color("704344"))
	canvas.draw_rect(Rect2(8, -38, 2, 5), Color("704344"))
	canvas.draw_rect(Rect2(-13, -34, 27, 14), ink)
	canvas.draw_rect(Rect2(-11, -35, 23, 15), orange)
	canvas.draw_rect(Rect2(-8, -36, 17, 5), light)
	canvas.draw_rect(Rect2(-12, -29, 25, 7), orange)
	canvas.draw_rect(Rect2(-10, -26, 21, 7), cream)
	canvas.draw_rect(Rect2(-12, -28, 6, 6), cream)
	canvas.draw_rect(Rect2(7, -28, 6, 6), cream)
	canvas.draw_rect(Rect2(-7, -31, 3, 3), ink)
	canvas.draw_rect(Rect2(5, -31, 3, 3), ink)
	canvas.draw_rect(Rect2(-7, -33, 3, 1), cream)
	canvas.draw_rect(Rect2(5, -33, 3, 1), cream)
	canvas.draw_rect(Rect2(-1, -27, 4, 2), ink)
	canvas.draw_rect(Rect2(0, -25, 2, 2), ink)
	canvas.draw_rect(Rect2(-2, -23, 6, 1), Color("9c633e"))
	# Red scarf with animated ribbon.
	canvas.draw_rect(Rect2(-12, -20, 26, 4), Color("aa4248"))
	canvas.draw_rect(Rect2(-11, -20, 23, 1), Color("f18a70"))
	for i in range(4):
		canvas.draw_rect(Rect2(-14 - i * 4, -19 + roundf(sin(time * 7 + i) * 2), 5, 3), Color("c65352"))
	# Katana and amber tsuba.
	if not portrait:
		var sword_y: float = -26 if attacking else -15
		canvas.draw_rect(Rect2(10, sword_y, 7, 4), Color("bc854d"))
		canvas.draw_rect(Rect2(16, sword_y - 3, 2, 9), Color("f8cb7b"))
		canvas.draw_rect(Rect2(18, sword_y - 1, 18, 3), Color("68cdb9"))
		canvas.draw_rect(Rect2(18, sword_y - 1, 18, 1), Color("e0ffe1"))
		canvas.draw_rect(Rect2(36, sword_y - 2, 3, 2), Color("e0ffe1"))
