extends SceneTree
var game: Node
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ",description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 3) -> void:
	for i in range(count):
		await physics_frame

func clear_mobs() -> void:
	for pass_index in range(8):
		for bug in game.enemies.duplicate():
			if is_instance_valid(bug) and not bug.dead and not bug.is_boss:
				bug.take_hit(9999,1,true)
		await frames()
		if game.enemies.is_empty():
			return
	check(false,"Mob wave must terminate, including memory-leak splits")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/rogue-test-record.json"
	await frames()
	check(game.state == "title","Starts at the three-option title screen")
	check(game.Data.EVENTS.size() == 12,"Twelve distinct development events are configured")
	check(game.Data.SKILLS.size() == 18,"Eighteen ranked skills are available")
	check(game.extra_enemies_atlas != null and game.extra_enemies_atlas.frames.size() == 16,"Eight new monster species are connected")
	check(game.npc_atlas != null and game.npc_atlas.frames.size() == 8,"All four NPCs have idle and talking sprites")
	check(game.icons_atlas != null and game.icons_atlas.frames.size() == 12,"Skill artwork is actually connected")
	check(game.run_atlas.frames[0].anchor == game.run_atlas.frames[15].anchor,"Run cycle uses a stable root across rows")
	check(game.attack_atlas.frames[0].anchor == game.attack_atlas.frames[15].anchor,"Attack cycle uses a stable root across rows")
	check(game.player.visual.material.shader != null,"GPU frame interpolation is attached to the player")
	var layouts: Dictionary = {}
	for seed_value in range(1,33):
		var room: Dictionary = game.Rooms.generate(seed_value,2,"normal")
		layouts[room.layout] = true
		check(room.platforms == game.Rooms.generate(seed_value,2,"normal").platforms,"Room generation is reproducible for seed %d" % seed_value)
	check(layouts.size() >= 5,"Different seeds produce multiple room layouts")
	game.handle_click(Vector2(220,573))
	check(game.state == "guide","Manual opens through the menu")
	game.handle_click(Vector2(1070,88))
	game.start_run("story",12345)
	await frames(12)
	check(game.state == "playing" and game.room_index == 0,"Story starts in the first generated room")
	check(game.player.is_on_floor(),"Player stands on real level collision")
	var x: float = game.player.position.x
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(game.player.position.x > x + 50,"Movement controls work")
	var weight: float = game.player.visual.material.get_shader_parameter("blend_weight")
	check(weight > 0.001 and weight < 0.999,"Animation evaluates an intermediate render pose instead of snapping only to integer frames")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(game.player.jumps == 2 and game.player.velocity.y < 0,"Double jump works")
	await frames(60)
	# Every named NPC offers a different, single-use service.
	for id in range(4):
		game.npcs[0].id = id
		game.npcs[0].used = false
		game.player.position = game.npcs[0].p
		game.player.velocity = Vector2.ZERO
		game.player.health = 4
		game.coins = 20
		game.interact()
		check(game.state == "npc","NPC %s opens an interaction" % game.Data.NPCS[id].name)
		var before: int = game.bonus_damage
		game.accept_npc()
		check(game.state == "playing" and game.npcs[0].used,"NPC service is applied once")
		if id == 0:
			check(game.player.health == 6,"Ruoyu restores health")
		elif id == 1:
			check(game.npc_contract,"Rhode adds the optional work-order challenge")
		elif id == 2:
			check(game.ward > 0,"Heide Knight grants a ward")
		else:
			check(game.bonus_damage == before + 1 and game.coins == 8,"Sekiro training costs currency and improves actual damage")
		var after: int = game.coins
		game.accept_npc()
		check(game.coins == after,"NPC cannot charge or reward a second time")
	game.npcs[0].id = 3
	game.npcs[0].used = false
	game.coins = 0
	game.state = "npc"
	game.accept_npc()
	check(game.state == "npc" and not game.npcs[0].used,"Insufficient funds do not apply a paid NPC service")
	game.state = "playing"
	game.room_wave = 1
	game.room_phase = "relay"
	game.npcs[0].id = 1
	game.npcs[0].used = false
	var adds_before: int = game.enemies.size()
	game.accept_npc()
	check(game.enemies.size() == adds_before + 2 and game.room_phase == "combat","A late Rhode contract creates its promised additional combat wave")
	await clear_mobs()
	game.room_phase = "approach"
	game.state = "playing"
	game.player.invulnerable = 0
	var health: int = game.player.health
	game.ward = 1
	game.player.hurt(1,500)
	check(game.player.health == health and game.ward == 0,"Ward absorbs exactly one hit")
	game.player.invulnerable = 0
	game.player.hurt(1,500)
	game.player.hurt(1,500)
	check(game.player.health == health - 1,"Damage invulnerability prevents duplicate hits")
	game.player.invulnerable = 999
	# Actual attack hitbox and input buffer, not direct stat inspection.
	game.player.position = Vector2(650,598)
	game.player.velocity = Vector2.ZERO
	var target: Node = game.spawn_bug(Vector2(720,598),"ugs")
	target.stun = 3
	var hp: int = target.hp
	Input.action_press("attack")
	await frames(19)
	Input.action_release("attack")
	check(target.hp < hp or target.dead,"J damages an enemy through the melee hitbox")
	game.player.attack_time = 0
	game.player.attack_cooldown = 0.08
	game.player.attack_buffer = 0.2
	await frames(7)
	check(game.player.attack_time > 0,"Buffered attack starts when recovery ends")
	game.apply_upgrade("swords")
	game.apply_upgrade("rollback")
	game.apply_upgrade("chain")
	game.apply_upgrade("burn")
	game.player.swords_cooldown = 0
	var locked: Node = game.spawn_bug(Vector2(740,598),"p4")
	locked.shield_open = false
	var locked_hp: int = locked.hp
	locked.take_hit(1,1,false)
	check(locked.hp == locked_hp,"P4 shield blocks normal hits")
	game.player.energy = 100
	game.player.skill_cooldown = 0
	game.player.cast_skill()
	check(locked.dead or locked.hp < locked_hp,"Breakpoint pierces P4 lock armour")
	game.use_swords()
	check(game.player.swords_cooldown > 0 and game.projectiles.any(func(p): return p.friendly),"U creates real homing projectiles and starts cooldown")
	Input.action_press("shield")
	await frames(2)
	Input.action_release("shield")
	check(game.player.shield_time > 0 and game.player.shield_cooldown > 0,"I activates the unlocked rollback shield")
	# Verify all twelve boss families produce a real attack or hazard.
	await clear_mobs()
	game.room_phase = "boss"
	for spec in game.Data.EVENTS:
		var boss: Node = game.spawn_bug(Vector2(2700,598),spec.kind,true)
		var shots: int = game.projectiles.size()
		var traps: int = game.hazards.size()
		boss.boss_attack(false)
		check(game.projectiles.size() > shots or game.hazards.size() > traps or boss.charge > 0,"%s boss has an implemented attack" % spec.tool)
		boss.dead = true
		boss.queue_free()
		await frames()
	# Exercise the complete twelve-room campaign through both waves and relays.
	game.start_run("story",9876)
	await frames()
	for room in range(12):
		game.player.invulnerable = 999
		game.spawn_wave(0)
		game.player.position = game.room_data.relays[0].p
		game.interact()
		check(game.relay_count == 0,"Room %d cannot skip its first combat wave" % (room + 1))
		await clear_mobs()
		check(game.room_phase == "relay","Room %d first wave unlocks a relay" % (room + 1))
		game.player.position = game.room_data.relays[0].p
		game.player.velocity = Vector2.ZERO
		game.interact()
		check(game.relay_count == 1 and game.room_wave == 1,"Room %d first relay starts a second wave" % (room + 1))
		await clear_mobs()
		game.player.position = game.room_data.relays[1].p
		game.player.velocity = Vector2.ZERO
		game.interact()
		check(is_instance_valid(game.boss_ref) and game.boss_ref.is_boss,"Room %d has its own final boss" % (room + 1))
		game.boss_ref.take_hit(99999,1,true)
		await frames()
		check(game.state == "upgrade" and game.upgrade_choices.size() == 3,"Room %d boss opens three skill choices" % (room + 1))
		game.choose_route(0)
		check(game.state == "upgrade","A skill must be selected before the next room")
		var skill_id: String = game.upgrade_choices[0].id
		var old_rank: int = game.rank(skill_id)
		game.choose_upgrade(-1)
		check(game.state == "upgrade","Invalid skill indices cannot consume the reward")
		game.choose_upgrade(0)
		check(game.rank(skill_id) == old_rank + 1,"Chosen skill is applied")
		game.choose_upgrade(0)
		check(game.rank(skill_id) == old_rank + 1,"Boss reward cannot be claimed twice")
		if room < 11:
			check(game.state == "route","Skill selection proceeds to a route decision")
			game.choose_route(room % 2)
			await frames()
			check(game.room_index == room + 1 and game.rank(skill_id) > 0,"Next sublevel preserves the build")
	check(game.state == "won" and game.cleared_rooms == 12,"Story ends after twelve bosses, not after the original four events")
	check(FileAccess.file_exists(game.record_path),"Run records are saved")
	game.start_run("endless",444)
	await frames()
	check(game.skill_ranks.is_empty() and game.coins == 0,"New roguelite run resets the previous build")
	game.room_index = 11
	game.cleared_rooms = 11
	game.build_room()
	await frames()
	game.summon_boss()
	game.boss_ref.take_hit(99999,1,true)
	await frames()
	game.choose_upgrade(0)
	check(game.state == "route","Endless mode does not finish at boss twelve")
	game.choose_route(1)
	await frames()
	check(game.room_index == 12 and game.state == "playing","Endless mode generates room thirteen")
	check(game.enemy_health(true) > 26,"Endless enemy health scales with depth")
	for skill in game.Data.SKILLS:
		game.skill_ranks[skill.id] = skill.max
	game.upgrade_choices = game.roll_upgrades()
	check(game.upgrade_choices.size() == 3 and game.upgrade_choices.all(func(skill): return skill.id in ["overclock","rest","funds"]),"Maxed builds receive valid endless rewards")
	game.player.health = 1
	game.player.invulnerable = 0
	game.player.shield_time = 0
	game.ward = 0
	game.player.hurt(1,300)
	check(game.state == "dead" and game.speech == "哦豁，完蛋","Death ends the run with Yichuan's catchphrase")
	var expected: int = game.best_floor
	game.best_floor = 0
	game.load_record()
	check(game.best_floor == expected and expected >= 12,"Endless record round-trips independently of story time")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await frames()
	quit(1 if failures else 0)
