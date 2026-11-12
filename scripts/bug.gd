class_name EngineBug
extends CharacterBody2D

var game: Node
var kind: String = "ugs"
var is_boss: bool = false
var spawn_depth: int = 0
var hp: int = 3
var max_hp: int = 3
var origin := Vector2.ZERO
var clock: float = 0
var facing: float = -1
var hurt_time: float = 0
var shot_timer: float = 2
var stun: float = 0
var dead: bool = false
var shield_open: bool = false
var telegraph: float = 0
var charge: float = 0
var charge_direction: float = 1
var attack_count: int = 0
var burn_time: float = 0
var burn_damage: int = 0
var burn_tick: float = 1

func _ready() -> void:
	origin = position
	clock = position.x * 0.013
	shot_timer = 1.4 + fmod(position.x,1.2)
	hp = game.enemy_health(is_boss)
	if kind == "p4":
		hp += 1
	if spawn_depth > 0:
		hp = maxi(1,hp / 2)
	max_hp = hp
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(85,115) if is_boss else Vector2(40,42)
	collider.shape = shape
	collider.position.y = -57 if is_boss else -23
	add_child(collider)
	collision_layer = 4
	collision_mask = 1
	z_index = 4

func _physics_process(delta: float) -> void:
	if game.state != "playing" or dead:
		return
	clock += delta
	hurt_time = maxf(0,hurt_time - delta)
	stun = maxf(0,stun - delta)
	if burn_time > 0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0:
			burn_tick = 1
			take_hit(burn_damage,0,true)
			if dead:
				return
	var dx: float = game.player.position.x - position.x
	if absf(dx) > 1300:
		return
	if dx != 0:
		facing = signf(dx)
	shield_open = fmod(clock,3.2) > (1.8 if not is_boss else 2.0)
	if is_boss:
		process_boss(delta,dx)
	else:
		process_mob(delta,dx)
	if position.y > 800:
		position = origin
		velocity = Vector2.ZERO
		reset_physics_interpolation()
	if stun <= 0 and get_bounds().intersects(game.player.bounds()):
		game.player.hurt(1,position.x)
	queue_redraw()

func process_mob(delta: float, dx: float) -> void:
	if kind in ["script","net","lumen","nanite"]:
		if stun <= 0:
			position.y = origin.y - 18 + sin(clock * 2.2) * 35
			position.x = origin.x + sin(clock * 0.85) * 82
	else:
		velocity.y += 1450 * delta
		var patrol: float = signf(sin(clock * 0.8))
		var proposed: float = patrol * (65 if kind != "live" else 105)
		if absf(position.x - origin.x) > 90:
			proposed = signf(origin.x - position.x) * 65
		if not game.ground_support(position + Vector2(signf(proposed) * 38,8)) and is_on_floor():
			proposed = signf(origin.x - position.x) * 65
		velocity.x = proposed if stun <= 0 else move_toward(velocity.x,0,delta * 900)
		move_and_slide()
	shot_timer -= delta if stun <= 0 else 0.0
	if shot_timer <= 0 and absf(dx) < 700 and game.player.position.x > 450:
		shot_timer = 2.8 + fmod(origin.x,0.8)
		var point: Vector2 = position + Vector2(0,-32)
		var aim: Vector2 = (game.player.position + Vector2(0,-40) - point).normalized()
		match kind:
			"shader":
				game.hazards.append({"rect":Rect2(game.player.position.x - 42,490,84,110),"delay":0.9,"life":0.45})
			"lumen":
				for i in range(6):
					game.shoot(point,Vector2.from_angle(i * TAU / 6) * 145,color())
			"gc":
				game.shoot(point,aim * 160,color(),0.4)
			"net":
				game.shoot(point,aim * 245,color(),0.7)
			"ddc":
				velocity.y = -330
			"live", "nanite":
				game.shoot(point,aim * 225,color())
			_:
				game.shoot(point,aim * 180,color())

func process_boss(delta: float, dx: float) -> void:
	velocity.y += 1450 * delta
	var enraged: bool = hp <= max_hp / 2
	if charge > 0:
		charge -= delta
		velocity.x = charge_direction * 490
	elif telegraph > 0:
		telegraph -= delta
		velocity.x = 0
		if telegraph <= 0:
			boss_attack(enraged)
	else:
		var next_x: float = facing * (85 if not enraged else 125)
		if absf(dx) < 115 or stun > 0:
			next_x = 0
		if not game.ground_support(position + Vector2(signf(next_x) * 60,8)) and is_on_floor():
			next_x = 0
		velocity.x = next_x
		shot_timer -= delta if stun <= 0 else 0.0
		if shot_timer <= 0:
			telegraph = 0.7 if not enraged else 0.5
			charge_direction = facing
	position.x = clampf(position.x,520,game.world_length - 130)
	move_and_slide()

func boss_attack(enraged: bool) -> void:
	attack_count += 1
	shot_timer = (2.25 if not enraged else 1.65) * maxf(0.65,1 - game.room_index * 0.012)
	var point := position + Vector2(0,-70)
	var aim: Vector2 = (game.player.position + Vector2(0,-40) - point).normalized()
	match kind:
		"ugs", "leak", "ddc":
			if attack_count % 2 == 0 and game.enemies.size() < 12:
				for side in [-1,1]:
					game.spawn_bug(Vector2(clampf(position.x + side * 100,500,3300),598),kind,false,1)
			for angle in [-0.22,0.0,0.22]:
				game.shoot(point,aim.rotated(angle) * 210,color())
		"live", "nanite", "p4":
			charge = 0.42
			for angle in [-0.3,0.3]:
				game.shoot(point,aim.rotated(angle) * 190,color())
		"shader", "gc":
			for offset in [-100,0,100]:
				game.hazards.append({"rect":Rect2(game.player.position.x + offset - 30,450,60,150),"delay":0.75,"life":0.5})
			game.shoot(point,aim * 175,color())
		"lumen", "net", "script":
			for i in range(8 if enraged else 6):
				game.shoot(point,Vector2.from_angle(i * TAU / (8 if enraged else 6) + attack_count * 0.3) * 170,color(),0.5 if kind == "net" else 0)
			if kind == "script":
				position.x = clampf(game.player.position.x + (240 if attack_count % 2 else -240),2450,3200)
				reset_physics_interpolation()
		_:
			for angle in [-0.4,-0.2,0.0,0.2,0.4]:
				game.shoot(point,aim.rotated(angle) * 205,color())
			if attack_count % 2 == 0:
				for side in [-1,1]:
					game.shoot(position + Vector2(0,-20),Vector2(side * 270,0),Color("edbb7f"))
	game.burst(point,color(),8)

func get_bounds() -> Rect2:
	return Rect2(position + Vector2(-50,-145),Vector2(100,145)) if is_boss else Rect2(position + Vector2(-27,-64),Vector2(54,64))

func take_hit(amount: int, direction: float, piercing: bool = false) -> bool:
	if dead:
		return false
	if kind == "p4" and not shield_open and not piercing:
		game.float_text("只读 · K 破锁",position + Vector2(0,-83),Color("e6c78e"))
		game.audio.sfx("block")
		return false
	hp -= amount
	hurt_time = 0.13
	stun = (0.08 if not piercing else 0.22) if is_boss else (0.22 if not piercing else 0.6)
	velocity.x = direction * 140
	game.player.energy = minf(100,game.player.energy + 3)
	game.shake = maxf(game.shake,3)
	game.float_text(str(amount),position + Vector2(0,-85 if is_boss else -65),Color("ffe8bf"))
	game.vfx(5 if kind in ["shader","script"] else 4,position + Vector2(0,-50 if is_boss else -30),80,0.2)
	game.audio.sfx("hit")
	if hp <= 0:
		dead = true
		game.bug_defeated(self)
		queue_free()
	return true

func color() -> Color:
	return {"ugs":Color("e6ad74"),"script":Color("b3a1dc"),"p4":Color("81c9d6"),"shader":Color("bd99eb"),"nanite":Color("8bcdc6"),"lumen":Color("f1cf84"),"ddc":Color("c9a67b"),"gc":Color("c5cdb4"),"leak":Color("87cd9c"),"live":Color("ef9b74"),"net":Color("8ac4ea"),"boss":Color("ed8d82")}.get(kind,Color.WHITE)

func _draw() -> void:
	var atlas: RefCounted = game.enemies_atlas
	var index: int = 0
	var frame: int = 3 if hurt_time > 0 else (2 if telegraph > 0 or shot_timer < 0.35 or (kind == "p4" and shield_open) else int(clock * 5) % 2)
	if kind in ["ugs","script","p4","boss"]:
		index = {"ugs":0,"script":1,"p4":2,"boss":3}[kind] * 4 + frame
	elif game.extra_enemies_atlas:
		atlas = game.extra_enemies_atlas
		var species: int = ["shader","nanite","lumen","ddc","gc","leak","live","net"].find(kind)
		index = species / 2 * 4 + (species % 2) * 2 + (1 if frame in [2,3] else 0)
	var height: float = 155 if is_boss else (43 if spawn_depth > 0 else 67)
	if atlas:
		atlas.draw(self,index,Vector2(0,sin(clock * 4) * 1.5),height,-facing,Color(1.3,1.2,1.1) if hurt_time > 0 else Color.WHITE)
	if is_boss:
		draw_arc(Vector2(0,-65),70,PI,TAU,12,Color(color(),0.4),2)
	if telegraph > 0:
		draw_rect(Rect2(-26,-185,52,27),Color("e9b47f"))
		draw_string(game.font,Vector2(-19,-165),"危险",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("202936"))
		draw_line(Vector2(0,-20),Vector2(facing * 250,-20),Color(0.95,0.5,0.4,0.5),3)
	if hp < max_hp and not is_boss:
		draw_rect(Rect2(-24,-82,48,4),Color("253940"))
		draw_rect(Rect2(-24,-82,48.0 * maxf(hp,0) / max_hp,4),color())
	if burn_time > 0:
		draw_rect(Rect2(-4,-82,8,9),Color("f4b064"))
