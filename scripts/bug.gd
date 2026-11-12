class_name EngineBug
extends CharacterBody2D

var game: Node
var kind: String = "ugs"
var hp: int = 3
var max_hp: int = 3
var origin := Vector2.ZERO
var clock: float = 0
var facing: float = -1
var hurt_time: float = 0
var shot_timer: float = 2
var stun: float = 0
var dead: bool = false
var boss_phase: int = 0
var shield_open: bool = false
var boss_activated: bool = false

func _ready() -> void:
	origin = position
	clock = position.x * 0.013
	shot_timer = 1.5 + fmod(position.x, 2)
	if kind == "boss":
		hp = 24
		max_hp = 24
	elif kind == "p4":
		hp = 4
		max_hp = 4
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(94, 110) if kind == "boss" else Vector2(40, 40)
	collider.shape = shape
	collider.position.y = -55 if kind == "boss" else -22
	add_child(collider)
	collision_layer = 4
	collision_mask = 1
	z_index = 4

func _physics_process(delta: float) -> void:
	if game.state != "playing" or dead:
		return
	clock += delta
	hurt_time = maxf(0, hurt_time - delta)
	stun = maxf(0, stun - delta)
	if absf(position.x - game.player.position.x) > 1050:
		return
	var dx: float = game.player.position.x - position.x
	facing = signf(dx)
	if kind == "boss":
		process_boss(delta, dx)
	elif kind == "script":
		if stun <= 0:
			position.y = origin.y - 30 + sin(clock * 2.5) * 42
			position.x = origin.x + sin(clock * 0.9) * 90
		shot_timer -= delta if stun <= 0 else 0.0
		if shot_timer <= 0 and absf(dx) < 620:
			shot_timer = 2.4
			game.shoot(position + Vector2(0, -20), (game.player.position + Vector2(0, -35) - position).normalized() * 190, Color("cc9aea"))
	else:
		velocity.y += 1400 * delta
		shield_open = fmod(clock, 3.0) > 1.6
		if stun <= 0:
			var patrol: float = signf(sin(clock * 0.85))
			velocity.x = patrol * (55 if kind == "p4" else 85)
			if absf(position.x - origin.x) > 110:
				velocity.x = signf(origin.x - position.x) * 80
		else:
			velocity.x = move_toward(velocity.x, 0, delta * 900)
		move_and_slide()
		shot_timer -= delta if stun <= 0 else 0.0
		if kind == "ugs" and shot_timer <= 0 and absf(dx) < 550:
			shot_timer = 3.0
			game.shoot(position + Vector2(facing * 22, -25), Vector2(facing * 205, -18), Color("eca76a"))
	if stun <= 0 and get_bounds().intersects(Rect2(game.player.position + Vector2(-17, -68), Vector2(34, 68))):
		game.player.hurt(1, position.x)
	queue_redraw()

func process_boss(delta: float, dx: float) -> void:
	if game.stage < 3 or game.player.position.x < 5160:
		return
	if not boss_activated:
		boss_activated = true
		game.say("怀不上了", 3.3, "毅川 · 看着第 99 次打包失败")
		game.log_event("UATHelper: Packaging (Windows): ERROR", Color("eb827e"))
	velocity.y += 1400 * delta
	boss_phase = 1 if hp > 12 else 2
	shield_open = fmod(clock, 3.4) > 1.9
	if stun <= 0:
		velocity.x = facing * (65 if boss_phase == 1 else 105) if absf(dx) > 95 else 0.0
	else:
		velocity.x = move_toward(velocity.x, 0, 900 * delta)
	position.x = clampf(position.x, 5220, 6210)
	move_and_slide()
	shot_timer -= delta if stun <= 0 else 0.0
	if shot_timer <= 0:
		shot_timer = 2.1 if boss_phase == 1 else 1.4
		var base: Vector2 = (game.player.position + Vector2(0, -40) - position - Vector2(0, -60)).normalized()
		for angle in [-0.3, 0.0, 0.3]:
			game.shoot(position + Vector2(0, -60), base.rotated(angle) * 210, Color("ee827f"))
		game.burst(position + Vector2(0, -55), Color("ee827f"), 8)

func get_bounds() -> Rect2:
	return Rect2(position + Vector2(-52, -115), Vector2(104, 115)) if kind == "boss" else Rect2(position + Vector2(-25, -52), Vector2(50, 52))

func take_hit(amount: int, direction: float, piercing: bool = false) -> void:
	if dead:
		return
	if kind == "boss" and not boss_activated:
		return
	if kind == "p4" and not shield_open and not piercing:
		game.float_text("文件只读！K 断点破锁", position + Vector2(0, -75), Color("ffc785"))
		game.burst(position + Vector2(0, -30), Color("ffc785"), 5)
		game.audio.sfx("block")
		return
	hp -= amount
	hurt_time = 0.18
	stun = 0.3 if not piercing else 1.0
	velocity.x = direction * 160
	game.shake = 4
	game.player.energy = minf(100, game.player.energy + 6)
	game.burst(position + Vector2(0, -30), color(), 12)
	game.vfx(5 if kind == "script" else 4, position + Vector2(0, -35), 88, 0.22)
	game.float_text(str(amount), position + Vector2(0, -60), Color("ffefc7"))
	game.audio.sfx("hit")
	if hp <= 0:
		dead = true
		game.bug_defeated(self)
		queue_free()

func color() -> Color:
	match kind:
		"ugs": return Color("e6a15f")
		"script": return Color("b3a1dc")
		"p4": return Color("69bccc")
		_: return Color("eb7d79")

func _draw() -> void:
	var c := Color("fff4ce") if hurt_time > 0 else color()
	var ink := Color("142733")
	if game.enemies_atlas:
		var row: int = {"ugs": 0, "script": 1, "p4": 2, "boss": 3}[kind]
		var frame: int = int(clock * 7) % 2
		if hurt_time > 0:
			frame = 3
		elif shot_timer < 0.35 or (kind == "p4" and shield_open):
			frame = 2
		game.enemies_atlas.draw(self, row * 4 + frame, Vector2(0, sin(clock * 5) * 2), 150 if kind == "boss" else 64, -facing, Color(1.5, 1.3, 1.1) if hurt_time > 0 else Color.WHITE)
		if hp < max_hp and kind != "boss":
			draw_rect(Rect2(-25, -80, 50, 4), Color("1b2734"))
			draw_rect(Rect2(-25, -80, 50.0 * maxf(hp, 0) / max_hp, 4), c)
		return
	if kind == "boss":
		draw_boss(c, ink)
		return
	var bob: float = sin(clock * 5) * 2
	draw_set_transform(Vector2(0, bob), 0, Vector2(2, 2))
	if kind == "script":
		draw_rect(Rect2(-14, -22, 28, 19), ink)
		draw_rect(Rect2(-13, -24, 26, 20), c)
		draw_rect(Rect2(-11, -22, 22, 14), Color("51416a"))
		for side in [-1, 1]:
			draw_line(Vector2(side * 8, -19), Vector2(side * 11, -15), Color("ead8f1"), 2)
			draw_line(Vector2(side * 11, -15), Vector2(side * 8, -11), Color("ead8f1"), 2)
		draw_rect(Rect2(-1, -18, 2, 7), Color("f3c17c"))
		for i in range(3):
			draw_rect(Rect2(-10 + i * 8, -5, 5, 3 + sin(clock * 6 + i) * 3), c)
	elif kind == "p4":
		draw_rect(Rect2(-12, -19, 24, 17), ink)
		draw_rect(Rect2(-10, -18, 20, 15), c)
		draw_rect(Rect2(-7, -27, 14, 13), c)
		draw_rect(Rect2(-4, -24, 8, 6), ink)
		draw_rect(Rect2(-8, -16, 16, 11), Color("295365"))
		draw_rect(Rect2(-2, -13, 4, 5), Color("f5c982"))
		draw_rect(Rect2(-9, -3, 5, 3), c)
		draw_rect(Rect2(4, -3, 5, 3), c)
		if not shield_open:
			draw_arc(Vector2(0, -13), 19, -PI * 0.9, -PI * 0.1, 6, Color("b5eef0"), 2)
	else:
		for side in [-1, 1]:
			for i in range(3):
				var y: float = -16 + i * 6
				draw_line(Vector2(side * 10, y), Vector2(side * (19 + sin(clock * 8 + i) * 3), y + 5), c, 3)
		draw_rect(Rect2(-11, -22, 22, 20), ink)
		draw_rect(Rect2(-9, -23, 18, 19), c)
		draw_rect(Rect2(-7, -18, 14, 10), Color("764949"))
		draw_rect(Rect2(-6, -18, 4, 3), Color("fff1bd"))
		draw_rect(Rect2(3, -18, 4, 3), Color("fff1bd"))
		draw_rect(Rect2(-4, -10, 9, 2), Color("f17666"))
		draw_line(Vector2(-5, -23), Vector2(-9, -29), c, 2)
		draw_line(Vector2(5, -23), Vector2(9, -29), c, 2)
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		draw_rect(Rect2(-22, -65, 44, 4), Color("1b2734"))
		draw_rect(Rect2(-22, -65, 44.0 * maxf(hp, 0) / max_hp, 4), c)

func draw_boss(c: Color, ink: Color) -> void:
	draw_set_transform(Vector2(0, sin(clock * 3) * 2), 0, Vector2(3, 3))
	# A cursed build server wearing a horned kabuto.
	draw_rect(Rect2(-18, -31, 36, 29), ink)
	draw_rect(Rect2(-16, -33, 32, 29), Color("563e50"))
	draw_rect(Rect2(-14, -32, 28, 3), c)
	draw_rect(Rect2(-20, -31, 5, 21), Color("986065"))
	draw_rect(Rect2(15, -31, 5, 21), Color("986065"))
	draw_rect(Rect2(-11, -41, 22, 12), ink)
	draw_rect(Rect2(-13, -38, 26, 8), c)
	draw_rect(Rect2(-18, -45, 4, 10), c)
	draw_rect(Rect2(-21, -48, 4, 7), Color("ffd09a"))
	draw_rect(Rect2(14, -45, 4, 10), c)
	draw_rect(Rect2(17, -48, 4, 7), Color("ffd09a"))
	draw_rect(Rect2(-12, -27, 24, 14), Color("1e283a"))
	draw_rect(Rect2(-9, -25, 6, 3), Color("ffb099"))
	draw_rect(Rect2(4, -25, 6, 3), Color("ffb099"))
	draw_rect(Rect2(-5, -18, 11, 2), c)
	for i in range(3):
		draw_rect(Rect2(-11, -10 + i * 3, 22, 1), c)
	draw_rect(Rect2(-14, -4, 8, 4), ink)
	draw_rect(Rect2(6, -4, 8, 4), ink)
	draw_set_transform(Vector2.ZERO)
