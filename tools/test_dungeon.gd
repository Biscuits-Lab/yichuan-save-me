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

func step(count: int = 1) -> void:
	for i in range(count):
		game._physics_process(1.0 / 60.0)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	game._unhandled_input(event)

func safe_start(seed_number: int = 12345) -> void:
	game.start_run(seed_number, true)
	game.enemies.clear()
	game.current_room().cleared = true
	game.invulnerable = 100

func test_generation() -> void:
	var layouts: Dictionary = {}
	var service_cases: Dictionary = {}
	for seed_number in range(1, 61):
		for floor_number in range(3):
			var generated: Dictionary = game.Data.generate(seed_number, floor_number)
			var repeat: Dictionary = game.Data.generate(seed_number, floor_number)
			check(generated == repeat, "Seeded graph and encounters reproduce exactly")
			var rooms: Array = generated.rooms
			check(rooms.size() == 10 + floor_number, "Floor has its specified room count")
			var queue: Array[int] = [0]
			var seen: Dictionary = {0:true}
			var kinds: Dictionary = {}
			var npc_ids: Dictionary = {}
			var links_valid: bool = true
			while not queue.is_empty():
				var at: int = queue.pop_front()
				for direction in range(4):
					var link: int = rooms[at].links[direction]
					if link < 0:
						continue
					links_valid = links_valid and rooms[link].links[(direction + 2) % 4] == at
					if not seen.has(link):
						seen[link] = true
						queue.append(link)
			for room in rooms:
				kinds[room.type] = int(kinds.get(room.type, 0)) + 1
				if room.npc >= 0:
					npc_ids[room.npc] = true
			check(seen.size() == rooms.size() and links_valid, "Every room is reachable through reciprocal cardinal doors")
			check(kinds.get("boss", 0) == 1 and kinds.get("rest", 0) == 1 and kinds.get("treasure", 0) == 1 and kinds.get("elite", 0) == 1, "Boss, rest, treasure and elite rooms each exist exactly once")
			check(rooms[generated.boss].type == "boss" and generated.boss != 0, "Boss never replaces entrance")
			var services: int = kinds.get("npc", 0) + kinds.get("shop", 0)
			check(services >= 0 and services <= 1 and npc_ids.size() == kinds.get("npc", 0), "NPC and shop rooms share a strict zero-or-one budget per floor")
			service_cases["npc" if kinds.get("npc", 0) > 0 else ("shop" if kinds.get("shop", 0) > 0 else "none")] = true
			check(kinds.get("combat", 0) + kinds.get("elite", 0) + kinds.get("boss", 0) >= rooms.size() - 4, "At least sixty percent of floor rooms contain combat")
			var sizes: Dictionary = {}
			var safe_npcs: bool = true
			var compact_npcs: bool = true
			for room in rooms:
				sizes[str(room.rect.size)] = true
				safe_npcs = safe_npcs and ((room.npc >= 0) == (room.type == "npc"))
				if room.type == "npc":
					compact_npcs = compact_npcs and room.rect.size.x >= 512 and room.rect.size.x <= 576 and room.rect.size.y >= 352 and room.rect.size.y <= 416
			check(safe_npcs, "NPCs never populate combat, elite, boss, shop or ordinary rooms")
			check(compact_npcs, "NPC meeting rooms use compact dimensions with room for exits and interaction")
			check(sizes.size() >= 3, "Each floor mixes small, medium and large physical rooms")
			var connected: bool = true
			for hall in generated.corridors:
				connected = connected and hall.rect.has_area() and hall.rect.intersects(rooms[hall.a].rect) and hall.rect.intersects(rooms[hall.b].rect)
			check(connected and generated.corridors.size() >= rooms.size() - 1, "Real corridors physically join both room footprints")
			layouts[str(rooms[1].cell) + str(rooms[2].cell) + str(rooms[3].cell)] = true
	check(layouts.size() > 20, "Seeds create varied branching floor layouts")
	check(service_cases.size() == 3, "Seeds can produce no service, one NPC or one shop without forcing an encounter")
	print("Generation checks complete")

func test_motion_and_rooms() -> void:
	safe_start()
	check(game.state == "playing" and game.floor_index == 0 and game.weapons.size() == 1, "New run starts with selected weapon on top-down floor")
	var start: Vector2 = game.player
	Input.action_press("move_up")
	step(12)
	Input.action_release("move_up")
	var straight: float = game.player.distance_to(start)
	check(game.player.y < start.y - 40, "W moves freely north without jumping or gravity")
	game.player = start
	Input.action_press("move_right")
	Input.action_press("move_down")
	step(12)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(absf(game.player.distance_to(start) - straight) < 0.1, "Diagonal movement is normalized")
	game.obstacles = game.Data.obstacles(0, "combat", game.current_room().rect)
	var cover: Rect2 = game.obstacles[0]
	game.player = cover.position + Vector2(-35, 19)
	game.facing = Vector2.RIGHT
	game.dash_cooldown = 0
	game.start_dash()
	step(12)
	check(game.player.x < cover.position.x - 12 and game.walkable(game.player), "Dash substeps cannot tunnel through cover")
	game.obstacles.clear()
	for layout in range(5):
		game.obstacles = game.Data.obstacles(layout, "combat", game.current_room().rect)
		game.build_navigation()
		for door in game.current_room().doors:
			var destination: Vector2 = door.lerp(game.room_center(), 0.2)
			var path: PackedVector2Array = game.nav.get_point_path(Vector2i(game.Data.CENTER / 20), Vector2i(destination / 20))
			check(path.size() > 1, "Every arena layout leaves all doors accessible")
	game.obstacles.clear()
	game.build_navigation()
	var old_id: int = game.room_id
	var next_id: int = -1
	var direction: int = -1
	for i in range(4):
		if game.current_room().links[i] >= 0:
			direction = i
			next_id = game.current_room().links[i]
			break
	game.current_room().cleared = false
	check(not game.enter_room(next_id, direction) and game.room_id == old_id, "Combat locks room transitions")
	game.current_room().cleared = true
	game.knight_active = true
	check(game.enter_room(next_id, direction), "Cleared room allows walking to a linked neighbor")
	check(game.knight_active, "Heide remains recruited across rooms on the same floor")
	check(game.walkable(game.player), "Door spawn is on walkable top-down floor")
	game.current_room().cleared = true
	game.enemies.clear()
	check(game.enter_room(old_id, (direction + 2) % 4) and game.enemies.is_empty(), "Returning to a cleared room never respawns enemies")
	game.state = "paused"
	var frozen: Vector2 = game.player
	var time_before: float = game.run_time
	Input.action_press("move_right")
	step(20)
	Input.action_release("move_right")
	check(game.player == frozen and game.run_time == time_before, "Pause freezes movement, attacks and run timer")
	game.state = "playing"
	key(KEY_ESCAPE)
	check(game.state == "inventory" and game.return_state == "playing", "Esc opens the backpack directly")
	frozen = game.player
	time_before = game.run_time
	Input.action_press("move_right")
	step(20)
	Input.action_release("move_right")
	check(game.player == frozen and game.run_time == time_before, "Backpack pauses actual simulation")
	key(KEY_ESCAPE)
	check(game.state == "playing", "Esc closes backpack and resumes combat")
	print("Movement and navigation checks complete")

func test_continuous_traversal() -> void:
	safe_start(20261113)
	var origin_id: int = game.room_id
	var next_id: int = -1
	var direction: int = -1
	for i in range(4):
		if game.current_room().links[i] >= 0:
			direction = i
			next_id = game.current_room().links[i]
			break
	var action: String = ["move_up", "move_right", "move_down", "move_left"][direction]
	var start: Vector2 = game.player
	var camera_start: Vector2 = game.camera.position
	var max_jump: float = 0
	var walked_hall: bool = false
	Input.action_press(action)
	for i in range(1100):
		var previous: Vector2 = game.player
		step()
		max_jump = maxf(max_jump, game.player.distance_to(previous))
		var in_room: bool = false
		for room in game.rooms:
			in_room = in_room or room.rect.has_point(game.player)
		walked_hall = walked_hall or not in_room
		if game.room_id == next_id:
			break
	Input.action_release(action)
	check(walked_hall and game.room_id == next_id, "Held movement physically crosses a corridor into the next room")
	check(max_jump < 5 and game.player.distance_to(start) > 800, "Cross-room movement is continuous without any teleport frame")
	check(game.camera.position.distance_to(camera_start) > 700 and game.camera.position.distance_to(game.player) < 45, "Camera follows actual long-distance player movement")
	var room: Dictionary = game.current_room()
	if room.type in ["combat", "elite", "boss"]:
		check(room.started and not room.cleared and game.enemies.size() > 0, "Entering a combat room starts its encounter and seals exits")
		var reverse_action: String = ["move_down", "move_left", "move_up", "move_right"][direction]
		Input.action_press(reverse_action)
		step(100)
		Input.action_release(reverse_action)
		check(game.room_id == next_id and room.rect.has_point(game.player), "Closed combat doors prevent escaping back into the corridor")
		for i in range(5):
			for enemy in game.enemies.duplicate():
				game.hit_enemy(enemy, 100000, game.player)
			step(46)
		check(room.cleared, "All waves release the physical doorway")
	if game.state == "shop":
		game.leave_shop()
	# Return along the same corridor without replacing the player position.
	game.current_room().cleared = true
	game.enemies.clear()
	var reverse_action: String = ["move_down", "move_left", "move_up", "move_right"][direction]
	Input.action_press(reverse_action)
	for i in range(1100):
		var previous: Vector2 = game.player
		step()
		max_jump = maxf(max_jump, game.player.distance_to(previous))
		if game.room_id == origin_id:
			break
	Input.action_release(reverse_action)
	check(game.room_id == origin_id and max_jump < 5 and game.enemies.is_empty(), "Cleared rooms can be reached again by walking back through their corridor")
	print("Continuous traversal and camera checks complete")

func test_floor_geometry_and_restart() -> void:
	for seed_number in [20261113, 51, 90210]:
		for floor_number in range(3):
			game.seed_value = seed_number
			game.floor_index = floor_number
			game.generate_floor()
			for room in game.rooms:
				room.cleared = true
			for hall in game.corridors:
				var a: Vector2 = game.rooms[hall.a].doors[hall.direction]
				var b: Vector2 = game.rooms[hall.b].doors[(hall.direction + 2) % 4]
				var clear: bool = true
				var steps: int = maxi(1, ceili(a.distance_to(b) / 32))
				for i in range(steps + 1):
					clear = clear and game.walkable(a.lerp(b, float(i) / steps), 29)
				check(clear, "Physical corridor is passable for circular actors across room boundaries")
			var a: Vector2 = game.rooms[0].rect.position - Vector2(80, 80)
			check(not game.point_on_floor(a), "Empty space beyond room walls is not traversable")
	safe_start()
	for room in game.rooms:
		if room.type == "combat":
			game.enter_room(room.id)
			break
	check(not game.enemies.is_empty(), "Restart fixture contains a live encounter")
	game.start_run(51, true)
	check(game.room_id == 0 and game.current_room().type == "start" and game.enemies.is_empty() and game.player == game.room_center(), "Restart clears old enemies and resets the active room and spawn")
	print("Floor geometry and restart checks complete")

func test_combat() -> void:
	for spec in game.Data.WEAPONS:
		safe_start()
		game.weapons.clear()
		game.add_item(spec.id)
		game.player = Vector2(440, 404)
		var target: Dictionary = game.spawn_enemy(Vector2(515, 404))
		target.age = 2
		target.hp = 1000
		target.max_hp = 1000
		game.update_weapons(0.02)
		game.update_projectiles(0.2)
		check(target.hp < 1000, spec.name + " deals actual damage with no attack button")
		check(game.weapons[0].cooldown > 0, "Each automatic weapon starts its own cooldown")
		var normal_damage: float = 1000 - target.hp
		game.weapons[0].tier = 4
		game.weapons[0].cooldown = 0
		game.projectiles.clear()
		target.hp = 1000
		target.p = Vector2(515, 404)
		game.update_weapons(0.02)
		game.update_projectiles(0.2)
		check(1000 - target.hp > normal_damage * 3, "Legendary tier improves real damage")
	safe_start()
	game.weapons.clear()
	game.add_item("pistol")
	game.obstacles.assign([Rect2(270, 270, 80, 48)])
	game.player = Vector2(230, 290)
	var blocked: Dictionary = game.spawn_enemy(Vector2(390, 290))
	blocked.age = 2
	game.update_weapons(0.1)
	check(game.projectiles.is_empty(), "Weapons do not aim through solid cover")
	game.shoot(Vector2(245, 290), Vector2(650, 0), 100, true, Color.WHITE)
	game.update_projectiles(0.2)
	check(blocked.hp == blocked.max_hp and game.projectiles.is_empty(), "Bullets collide with cover using substeps")
	safe_start()
	game.invulnerable = 0
	var before: float = game.health
	game.hurt(10, game.player + Vector2.RIGHT * 30)
	game.hurt(10, game.player + Vector2.RIGHT * 30)
	check(game.health == before - 10, "Damage invulnerability prevents duplicate contact hits")
	game.equipment.clear()
	game.add_item("vest")
	game.invulnerable = 0
	before = game.health
	game.hurt(10, game.player + Vector2.RIGHT * 30)
	check(absf(before - game.health - 8.8) < 0.01, "Armour changes actual incoming damage")
	game.add_item("coffee")
	before = game.health
	step(60)
	check(game.health > before + 0.45, "Coffee equipment regenerates actual health")
	game.onion_skill = true
	game.onion_cooldown = 0
	game.use_onion()
	before = game.health
	game.invulnerable = 0
	game.hurt(999, game.player)
	check(game.health == before and game.onion_cooldown > 0 and game.shield_time > 0, "Q skill grants an actual timed shield and cooldown")
	game.shield_time = 0
	game.cheat_invincible = true
	game.hurt(999, game.player)
	check(game.health == before, "Home invulnerability blocks damage")
	game.cheat_invincible = false
	game.cheat_one_hit = true
	var tough: Dictionary = game.spawn_enemy(Vector2(650, 404), "boss")
	game.hit_enemy(tough, 1, game.player)
	check(tough.dead, "One-hit assist applies to bosses")
	game.cheat_one_hit = false
	# Death of a boss clears all projectiles, including shots currently being iterated.
	safe_start()
	var boss: Dictionary = game.spawn_enemy(Vector2(580, 404), "boss")
	boss.age = 2
	boss.hp = 1
	for i in range(5):
		game.shoot(Vector2(520, 404), Vector2(650, 0), 100, true, Color.WHITE)
	game.update_projectiles(0.2)
	check(boss.dead and game.projectiles.is_empty(), "Boss death safely removes an in-flight projectile batch")
	for floor_number in range(3):
		game.floor_index = floor_number
		game.enemies.clear()
		boss = game.spawn_enemy(Vector2(700, 404), "boss")
		game.boss_attack(boss)
		check(game.projectiles.size() > 10, "Each floor boss has a real radial and aimed attack")
		game.projectiles.clear()
	print("Combat checks complete")

func test_inventory_and_economy() -> void:
	safe_start()
	game.interact()
	check(game.state == "playing" and not game.has_shop(), "The entrance does not act as an extra shop")
	for kind in ["combat", "elite"]:
		game.current_room().type = kind
		game.open_shop()
		game.interact()
		check(game.state == "playing" and not game.has_shop(), "Cleared combat rooms do not become hidden shops")
	game.current_room().type = "shop"
	game.points = 200
	game.open_shop()
	var balance: int = game.points
	var total: int = game.earned
	var price: int = game.shop_price(game.stock[0])
	check(game.buy(0) and game.points == balance - price and game.earned == total, "Purchases spend balance without reducing earned score")
	balance = game.points
	check(not game.buy(0) and game.points == balance, "Sold stock cannot be purchased twice")
	game.points = 0
	check(not game.buy(1), "Insufficient points never grant an item")
	game.points = 100
	game.toggle_inventory()
	check(game.state == "inventory", "Inventory opens from shop")
	check(game.fuse("weapon", 0) and game.weapons.size() == 1 and game.weapons[0].tier == 2, "Two identical ordinary weapons fuse to one fine weapon")
	game.add_item(game.weapons[0].id, 1)
	check(not game.fuse("weapon", 0), "Different tiers cannot fuse")
	game.add_item(game.weapons[0].id, 2)
	check(game.fuse("weapon", 0) and game.weapons[0].tier == 3, "Fine pair upgrades to epic")
	game.add_item(game.weapons[0].id, 3)
	check(game.fuse("weapon", 0) and game.weapons[0].tier == 4, "Epic pair upgrades to legendary")
	game.add_item(game.weapons[0].id, 4)
	check(not game.fuse("weapon", 0), "Legendary is the maximum tier")
	game.equipment.clear()
	game.add_item("vest")
	game.add_item("vest")
	check(game.fuse("equipment", 0) and game.equipment.size() == 1 and game.equipment[0].tier == 2, "Equipment follows the same fusion rules")
	check(absf(game.equipment_stat("vest") - 1.65) < 0.001, "Fused equipment applies the stronger stat multiplier")
	while game.weapons.size() < 6:
		game.add_item("pistol")
	check(not game.add_item("orb"), "Full weapon slots reject an unmatched pickup")
	game.state = "shop"
	game.stock[1] = {"id":"orb", "tier":1, "sold":false}
	balance = game.points
	check(not game.buy(1) and game.points == balance and not game.stock[1].sold, "Full inventory never consumes currency or stock")
	game.state = "inventory"
	total = game.earned
	balance = game.points
	check(game.sell("weapon", 5) and game.points > balance and game.earned == total, "Selling refunds points without farming score")
	while game.weapons.size() > 1:
		game.sell("weapon", game.weapons.size() - 1)
	check(not game.sell("weapon", 0), "Cannot sell the last weapon and strand the run")
	game.equipment.clear()
	game.health = 10
	game.add_item("heart")
	check(game.max_health() == 100 and game.health == 30, "Battery increases maximum and current health")
	game.health = 100
	game.sell("equipment", 0)
	check(game.health == 80 and game.max_health() == 80, "Selling health equipment clamps health to the new maximum")
	game.state = "shop"
	game.points = 100
	var refresh: int = game.refresh_price()
	balance = game.points
	check(refresh == 0 and game.refresh_shop() and game.points == balance and game.refresh_price() == 4, "First shelf refresh is free and the second costs four points")
	balance = game.points
	check(game.refresh_shop() and game.points == balance - 4 and game.refresh_price() == 6, "Later shelf refreshes charge points and increase the price")
	var saved_stock: Array = game.stock.duplicate(true)
	game.state = "playing"
	game.open_shop()
	check(game.stock == saved_stock, "Reopening supply preserves sold stock and rerolls")
	game.state = "playing"
	check(not game.fuse("weapon", 0) and not game.buy(0) and not game.sell("weapon", 0), "Combat cannot invoke shop-only transactions")
	print("Inventory and economy checks complete")

func test_full_inventory_auto_merge() -> void:
	for kind in ["weapon", "equipment"]:
		safe_start()
		var id: String = "pistol" if kind == "weapon" else "vest"
		var storage: Array[Dictionary] = game.weapons if kind == "weapon" else game.equipment
		storage.clear()
		game.add_item(id)
		game.add_item(id)
		check(storage.size() == 2 and storage[0].tier == 1 and storage[1].tier == 1, "Unfilled slots keep duplicate pickups for manual fusion")
		while storage.size() < 6:
			game.add_item(id)
		check(game.add_item(id) and storage.size() == 6, "Full slots accept a matching pickup without exceeding capacity")
		check(storage.filter(func(entry: Dictionary) -> bool: return entry.tier == 2).size() == 1 and storage.filter(func(entry: Dictionary) -> bool: return entry.tier == 1).size() == 5, "Incoming copy and one carried copy upgrade together")
		check(game.message.begins_with("自动合并"), "Pickup reports the automatic upgrade")
		var saved: Array = storage.duplicate(true)
		check(not game.add_item(id, 3) and storage == saved, "Different-quality pickups leave full inventory unchanged")
		check(game.add_item(id, 2) and storage.size() == 6 and storage[-1].tier == 3, "Matching fine pickups upgrade to epic")
		check(game.add_item(id, 3) and storage.size() == 6 and storage[-1].tier == 4, "Matching epic pickups upgrade to legendary")
		saved = storage.duplicate(true)
		check(not game.add_item(id, 4) and storage == saved, "Legendary duplicates cannot exceed the quality limit")
	safe_start()
	game.weapons.clear()
	for tier in [1, 2, 3]:
		game.add_item("blade", tier)
	for i in range(3):
		game.add_item("pistol")
	check(game.add_item("blade") and game.weapons.size() == 4 and game.weapons[-1].id == "blade" and game.weapons[-1].tier == 4, "A full-slot pickup chains through matching higher qualities and frees slots")
	check(game.weapons.filter(func(entry: Dictionary) -> bool: return entry.id == "pistol" and entry.tier == 1).size() == 3, "Chain fusion preserves unrelated weapons")
	safe_start()
	game.health = 10
	game.add_item("heart")
	for i in range(5):
		game.add_item("boots")
	check(game.add_item("heart") and is_equal_approx(game.max_health(), 113) and is_equal_approx(game.health, 50), "Auto-fused batteries preserve pickup healing and apply the upgraded maximum")
	safe_start()
	for tier in [1, 2, 3]:
		game.add_item("heart", tier)
	for i in range(3):
		game.add_item("boots")
	game.health = game.max_health()
	check(game.add_item("heart") and game.equipment.size() == 4 and is_equal_approx(game.max_health(), 162) and is_equal_approx(game.health, 162), "Chained health equipment fusion clamps current health to the final maximum")
	safe_start()
	game.weapons.clear()
	for spec in game.Data.WEAPONS:
		game.add_item(spec.id, 2)
	game.current_room().type = "treasure"
	game.player = game.room_center()
	game.interact()
	check(game.current_room().used and game.weapons.size() == 6 and game.weapons[-1].tier == 3, "Full weapon slots receive and auto-fuse a real treasure-room reward")
	check(game.message.begins_with("自动合并"), "Treasure reward preserves the automatic fusion message")
	safe_start()
	game.weapons.clear()
	for i in range(6):
		game.add_item("pistol")
	game.current_room().type = "shop"
	game.open_shop()
	game.points = 100
	game.stock[0] = {"id":"pistol", "tier":1, "sold":false}
	var price: int = game.shop_price(game.stock[0])
	key(KEY_1)
	check(game.stock[0].sold and game.points == 100 - price and game.weapons.size() == 6 and game.weapons[-1].tier == 2, "Shop purchase keys pay once and auto-fuse matching stock into full slots")
	check(game.message.begins_with("自动合并"), "Shop keeps the automatic fusion result visible")
	safe_start()
	game.weapons.clear()
	for i in range(6):
		game.add_item("pistol")
		game.add_item("vest", 4)
	game.current_room().type = "npc"
	game.current_room().npc = 4
	game.selected_npc = 4
	game.state = "npc"
	check(game.accept_npc() and game.current_room().npc_used and game.weapons.size() == 6 and game.weapons[-1].tier == 2, "Laya can give a matching normal weapon when both bags are full")
	check(game.message.begins_with("自动合并"), "NPC gift preserves the automatic fusion message")
	print("Full inventory auto-fusion checks complete")

func test_enemy_behaviour() -> void:
	safe_start()
	game.weapons.clear()
	game.player = Vector2(600, 350)
	var caster: Dictionary = game.spawn_enemy(Vector2(330, 350), "ranged")
	caster.age = 2
	caster.cooldown = 0
	game.update_enemies(0.01)
	check(caster.windup > 0 and game.projectiles.is_empty(), "Ranged attacks show a warning before shooting")
	game.update_enemies(0.7)
	check(not game.projectiles.is_empty() and not game.projectiles[0].friendly, "Ranged windup produces a hostile projectile")
	game.enemies.clear()
	game.projectiles.clear()
	var charger: Dictionary = game.spawn_enemy(Vector2(400, 350), "charger")
	charger.age = 2
	charger.cooldown = 0
	game.update_enemies(0.01)
	check(charger.windup > 0 and charger.charge == 0, "Charger warns before committing to its dash")
	var before: Vector2 = charger.p
	game.update_enemies(0.7)
	game.update_enemies(0.1)
	check(charger.p.distance_to(before) > 30, "Charger actually moves quickly after its warning")
	safe_start()
	game.weapons.clear()
	game.player = Vector2(440, 290)
	game.obstacles.assign([Rect2(270, 250, 80, 80)])
	game.build_navigation()
	var seeker: Dictionary = game.spawn_enemy(Vector2(240, 290))
	seeker.age = 2
	for i in range(600):
		game.update_enemies(1.0 / 60.0)
	check(seeker.p.distance_to(game.player) < 60, "Real enemy movement navigates around blocking office cover")
	print("Enemy behaviour checks complete")

func test_npcs() -> void:
	for index in range(game.Data.NPCS.size()):
		safe_start()
		game.current_room().type = "npc"
		game.current_room().npc = index
		game.current_room().npc_used = false
		game.selected_npc = index
		game.player = game.npc_position()
		game.health = 20
		game.points = 20
		game.interact()
		check(game.state == "npc", "Every NPC opens through actual proximity interaction")
		check(game.accept_npc(), "Every NPC has an implemented service")
		match index:
			0: check(game.health == 55, "Ruoyu restores 35 health")
			1:
				check(game.contract_pending and game.current_room().cleared and game.enemies.is_empty(), "Rhode keeps his meeting room safe and queues a later challenge")
				for room in game.rooms:
					if room.type == "combat":
						game.enter_room(room.id)
						break
				check(game.contract_active and game.wave_total == 3 and game.current_room().npc == -1, "Contract adds a wave only to the next NPC-free combat room")
				var before: int = game.points
				for pass_index in range(4):
					for enemy in game.enemies.duplicate():
						game.hit_enemy(enemy, 100000, game.player)
					step(46)
				check(game.current_room().cleared and game.points >= before + 45 and not game.contract_active, "Contract pays only after all combat waves finish")
				check(game.cleared_count == 1, "Contract room still counts as a normal clear")
			2:
				check(game.knight_active, "Heide joins as a temporary companion")
				check(game.spawn_enemy(game.player).is_empty() and game.enemies.is_empty(), "NPC meeting rooms reject enemy spawning")
				game.current_room().type = "combat"
				game.current_room().npc = -1
				var enemy: Dictionary = game.spawn_enemy(game.knight + Vector2(65, 0))
				enemy.age = 2
				game.update_knight(0.1)
				check(enemy.hp < enemy.max_hp, "Companion independently attacks an actual enemy")
			3: check(game.points == 8 and game.damage_scale() > 1.1, "Basan training charges points and raises damage")
			4: check(game.weapons.size() + game.equipment.size() == 2, "Laya grants a real weapon or equipment")
			5: check(game.state == "shop" and game.stock.size() == 4, "Coin opens a persistent purchasable stock")
			6: check(game.onion_skill, "Hashao unlocks Q onion guard")
			7: check(game.weapons[0].tier == 2 and game.points == 20, "Jiahao upgrades an equipped weapon without charging or consuming a slot")
		if index != 5:
			game.state = "npc"
			var before: int = game.points
			check(not game.accept_npc() and game.points == before, "Each nonmerchant service can be claimed only once")
	safe_start()
	game.current_room().type = "npc"
	game.current_room().npc = 3
	game.current_room().npc_used = false
	game.selected_npc = 3
	game.state = "npc"
	game.points = 0
	check(not game.accept_npc() and not game.current_room().npc_used and game.buff_damage == 0, "Unaffordable training remains available without applying buffs")
	safe_start()
	while game.weapons.size() < 6:
		game.add_item("pistol")
	for i in range(6):
		game.add_item("vest")
	for entry in game.weapons + game.equipment:
		entry.tier = 4
	game.current_room().type = "npc"
	game.current_room().npc = 4
	game.current_room().npc_used = false
	game.selected_npc = 4
	game.state = "npc"
	check(not game.accept_npc() and not game.current_room().npc_used, "Full bags with no eligible fusion do not consume Laya's gift")
	check(game.Data.NPCS[0].quote == "this is the way" and game.Data.NPCS[1].quote == "给毅川派活" and game.Data.NPCS[2].quote == "毅川救我" and game.Data.NPCS[3].quote == "好他妈卡我草了", "NPC catchphrases match the requested dialogue")
	print("NPC checks complete")

func test_new_characters() -> void:
	safe_start()
	game.current_room().type = "elite"
	game.current_room().npc = -1
	game.current_room().cleared = false
	game.current_room().started = true
	game.wave = 2
	game.wave_total = 3
	game.spawn_wave()
	check(game.enemies.size() == 1 and game.enemies[0].kind == "shark", "Elite room final wave spawns Big Shark as its real boss")
	var shark: Dictionary = game.enemies[0]
	shark.age = 2
	shark.cooldown = 0
	game.update_enemies(0.01)
	check(shark.windup > 0 and game.projectiles.is_empty(), "Big Shark warns before its attack")
	var before: Vector2 = shark.p
	game.update_enemies(0.7)
	game.update_enemies(0.2)
	check(shark.charge > 0 and shark.p.distance_to(before) > 30 and game.projectiles.size() == 5, "Big Shark performs a physical charge and five-shot fan")
	shark.hp = shark.max_hp * 0.45
	game.update_enemies(0.01)
	check(shark.phase == 1, "Big Shark enrages below half health")
	game.projectiles.clear()
	game.boss_attack(shark)
	check(game.projectiles.size() == 7, "Enraged Big Shark widens its projectile fan")
	game.hit_enemy(shark, 100000, game.player)
	step(46)
	check(game.current_room().cleared and game.state == "shop" and game.floor_index == 0, "Defeating the elite boss opens supplies without ending the floor early")
	game.leave_shop()
	check(game.state == "playing", "Leaving elite supplies resumes exploration")
	safe_start()
	game.current_room().type = "npc"
	game.current_room().npc = 7
	game.current_room().npc_used = false
	game.selected_npc = 7
	game.state = "npc"
	game.weapons[0].tier = 4
	check(not game.accept_npc() and not game.current_room().npc_used, "Jiahao cannot exceed legendary quality or consume an unavailable upgrade")
	game.weapons[0].tier = 3
	var points_before: int = game.points
	check(game.accept_npc() and game.weapons[0].tier == 4 and game.points == points_before and game.weapons.size() == 1, "Jiahao upgrades epic to legendary in place without charging")
	print("New NPC and elite boss checks complete")

func test_room_shops_and_skills() -> void:
	for floor_number in range(3):
		safe_start()
		game.floor_index = floor_number
		game.current_room().type = "combat" if floor_number % 2 == 0 else "elite"
		game.current_room().npc = -1
		game.current_room().started = true
		game.current_room().cleared = false
		game.wave = 1
		game.wave_total = 1
		var enemy: Dictionary = game.spawn_enemy(game.room_center() + Vector2(220, 0))
		game.hit_enemy(enemy, 100000, game.player)
		step(46)
		check(game.state == "shop" and game.current_room().reward_shop and game.stock.size() == 4, "Completed combat and elite rooms automatically open four supply cards")
		var weapons: int = 0
		var gear: int = 0
		for offer in game.stock:
			weapons += 1 if game.Data.item(offer.id).kind == "weapon" else 0
			gear += 1 if game.Data.item(offer.id).kind == "equipment" else 0
		check(weapons == 2 and gear == 2, "Each shelf offers both random weapons and equipment")
		game.points = 1000
		for i in range(4):
			check(game.buy(i), "All four post-combat cards can be purchased")
		check(game.stock.all(func(offer: Dictionary) -> bool: return offer.sold), "Purchased shelf records each sold card")
		var old_signature: String = str(game.stock.map(func(offer: Dictionary) -> String: return offer.id + str(offer.tier)))
		var balance: int = game.points
		check(game.refresh_shop() and game.points == balance and game.current_room().refreshes == 1, "First post-combat refresh is free")
		check(game.stock.all(func(offer: Dictionary) -> bool: return not offer.sold), "Refreshing a sold-out shelf creates purchasable cards")
		check(str(game.stock.map(func(offer: Dictionary) -> String: return offer.id + str(offer.tier))) != old_signature, "Refresh guarantees a changed item selection")
		balance = game.points
		check(game.refresh_shop() and game.points == balance - 4 and game.refresh_price() == 6, "Second post-combat refresh charges the advertised price")
		key(KEY_ESCAPE)
		check(game.state == "playing" and game.floor_index == floor_number, "Closing room supplies resumes the same floor")
		game.player = game.room_center()
		game.interact()
		check(game.state == "shop" and game.refresh_price() == 6 and game.current_room().refreshes == 2, "E reopens cleared combat supplies without another free refresh")
		game.points = 0
		var refreshes: int = game.current_room().refreshes
		var saved_stock: Array = game.stock.duplicate(true)
		check(not game.refresh_shop() and game.current_room().refreshes == refreshes and game.stock == saved_stock, "Unaffordable paid refresh does not consume or replace stock")
	for floor_number in range(3):
		safe_start()
		game.floor_index = floor_number
		game.current_room().type = "boss"
		game.current_room().started = true
		game.current_room().cleared = false
		game.wave = 1
		game.wave_total = 1
		var boss: Dictionary = game.spawn_enemy(game.room_center() + Vector2(220, 0), "boss")
		game.hit_enemy(boss, 100000, game.player)
		step(46)
		check(game.state == "skill" and game.skill_offers.size() == 3 and not game.has_shop(), "Floor boss gives three skill choices instead of a shop")
		var ids: Dictionary = {}
		for spec in game.skill_offers:
			ids[spec.id] = true
		check(ids.size() == 3, "Skill choices are distinct")
		var offered: Array = game.skill_offers.duplicate()
		game.open_skill_reward()
		check(game.skill_offers == offered and not game.choose_skill(-1) and not game.next_floor(), "Pending skill choices cannot be rerolled or skipped")
		var frozen: Vector2 = game.player
		var time_before: float = game.run_time
		Input.action_press("move_right")
		step(12)
		Input.action_release("move_right")
		key(KEY_ESCAPE)
		check(game.state == "skill" and game.player == frozen and game.run_time == time_before, "Skill selection pauses the fight and Esc does not discard the reward")
		var id: String = game.skill_offers[0].id
		var balance: int = game.points
		key(KEY_1)
		check(game.skill_level(id) == 1 and game.points == balance and not game.choose_skill(0), "Choosing a skill is free and can only be claimed once")
		if floor_number < 2:
			check(game.floor_index == floor_number + 1 and game.state == "dialogue", "Skill selection advances to the next floor")
		else:
			check(game.state == "dialogue" and game.dialogue_kind == "ending", "Final boss skill reward leads into the princess rescue ending")
	for spec in game.Data.SKILLS:
		safe_start()
		game.current_room().type = "boss"
		game.skill_offers.assign([spec])
		game.state = "skill"
		check(game.choose_skill(0), "Each skill reward can be selected")
		game.advance_dialogue()
		match spec.id:
			"power": check(is_equal_approx(game.damage_scale(), 1.15), "War spirit increases actual weapon damage")
			"haste": check(is_equal_approx(game.attack_speed(), 1.12), "Gale increases actual attack speed")
			"vigor": check(game.max_health() == 100, "Vitality increases actual maximum health")
			"recovery":
				game.health = 40
				step(60)
				check(game.health > 40.49, "Regeneration restores health in real simulation")
			"dash":
				game.start_dash()
				check(game.dash_cooldown < 1.51, "Blink reduces actual dash cooldown")
			"onion":
				game.use_onion()
				check(game.onion_skill and game.shield_time > 2 and game.onion_cooldown < 10, "Onion skill unlocks and strengthens the active guard")
	safe_start()
	for floor_number in range(3):
		game.floor_index = floor_number
		for room_size in [Vector2(960, 640), Vector2(1792, 1216)]:
			for layout in range(5):
				for rect in game.Data.obstacles(layout, "combat", Rect2(Vector2.ZERO, room_size)):
					var drawn: Rect2 = game.view.cover_draw_rect(rect)
					var frame: Dictionary = game.environment_atlas.frames[5 + floor_number]
					check(rect.size == Vector2(96, 56), "Furniture footprints stay the same size in small and large rooms")
					check(absf(drawn.size.x / drawn.size.y - frame.bounds.size.x / frame.bounds.size.y) < 0.001, "Furniture textures keep their source aspect ratio")
	check(game.view.geometry_root.get_child_count() == game.rooms.size() + game.corridors.size(), "Static room and corridor geometry is retained separately from actors")
	print("Room supplies, floor skills and furniture checks complete")

func test_campaign() -> void:
	game.start_run(98765)
	check(game.state == "dialogue" and game.dialogue().line.contains("杨梓亮"), "Opening establishes the kidnapped ChatGPT princess")
	for i in range(3):
		game.advance_dialogue()
	check(game.state == "playing", "Opening returns to playable dungeon")
	for floor_number in range(3):
		game.invulnerable = 999
		# Traverse all rooms in a BFS over real links, returning through cleared paths.
		var queue: Array[int] = [0]
		var seen: Dictionary = {0:true}
		while not queue.is_empty():
			var at: int = queue.pop_front()
			game.current_room().cleared = true
			game.state = "playing"
			game.enter_room(at)
			if game.current_room().type == "boss":
				# Leave the boss for the end of this floor.
				game.enemies.clear()
			else:
				var guard: int = 0
				while not game.current_room().cleared and guard < 10:
					for enemy in game.enemies.duplicate():
						game.hit_enemy(enemy, 100000, game.player)
					step(46)
					guard += 1
				check(game.current_room().cleared, "Combat and elite rooms complete all waves")
			for link in game.current_room().links:
				if link >= 0 and not seen.has(link):
					seen[link] = true
					queue.append(link)
		var boss_id: int = -1
		for room in game.rooms:
			if room.type == "boss":
				boss_id = room.id
		game.current_room().cleared = true
		game.rooms[boss_id].cleared = false
		game.enter_room(boss_id)
		check(game.enemies.size() == 1 and game.enemies[0].kind == "boss", "Every floor ends in a real unique boss encounter")
		game.hit_enemy(game.enemies[0], 100000, game.player)
		step(46)
		check(game.current_room().cleared, "Defeating the boss unlocks the central portal")
		if floor_number < 2:
			game.knight_active = true
			game.player = game.room_center()
			check(game.state == "skill", "Floor boss automatically opens skill rewards")
			game.choose_skill(0)
			check(game.floor_index == floor_number + 1 and game.state == "dialogue", "E portal progresses to the next seeded floor with story")
			check(not game.knight_active, "Heide leaves precisely when entering the next floor")
			game.advance_dialogue()
		else:
			check(game.state == "skill", "Final boss offers a skill reward")
			game.choose_skill(0)
			check(game.state == "dialogue" and game.dialogue_kind == "ending", "Defeating Yang Ziliang starts the princess rescue ending")
	for i in range(3):
		game.advance_dialogue()
	check(game.state == "won" and game.best_floor == 3, "Three-floor campaign reaches the rescued princess ending")
	check(FileAccess.file_exists(game.record_path), "New mode writes its own run records")
	var best: int = game.best_score
	game.best_score = 0
	game.load_record()
	check(game.best_score == best and best > 0, "Score record round-trips from disk")
	game.start_run(98765, true)
	check(game.points == 30 and game.earned == 0 and game.equipment.is_empty() and game.weapons.size() == 1 and not game.onion_skill and not game.knight_active and game.skill_levels.is_empty() and game.skill_offers.is_empty(), "Restart resets points, gear, skills and companions")
	game.invulnerable = 0
	game.health = 1
	game.hurt(100, game.player)
	check(game.state == "dead", "Death ends the current run")
	var old_best: int = game.best_score
	game.assisted = true
	game.earned = 99999999
	game.finish_run(true)
	check(game.best_score == old_best, "Cheat-assisted run cannot overwrite the legitimate record")
	print("Campaign checks complete")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/dungeon-test-record.json"
	game.set_physics_process(false)
	await process_frame
	check(game.state == "title", "Game launches at the redesigned title")
	check(game.hero_atlas.frames.size() == 16 and game.cast_atlas.frames.size() == 16 and game.item_atlas.frames.size() == 12 and game.enemy_atlas.frames.size() == 16 and game.environment_atlas.frames.size() == 12 and game.basan_atlas.frames.size() == 2 and game.jiahao_atlas.frames.size() == 2 and game.shark_atlas.frames.size() == 4, "Main character and NPC imagegen atlases are connected and sliced")
	check(game.hero_atlas.frames[0].anchor == game.hero_atlas.frames[15].anchor, "Four-direction hero animation uses a stable anchor")
	check(game.camera is Camera2D and game.view.overlay.get_parent() is CanvasLayer, "World camera follows independently of the fixed full-window HUD")
	check(game.vfx_atlas.frames.size() == 16 and game.utility_atlas.frames.size() == 16, "Generated animated VFX and world utility sprites are connected")
	test_generation()
	test_motion_and_rooms()
	test_continuous_traversal()
	test_floor_geometry_and_restart()
	test_combat()
	test_enemy_behaviour()
	test_inventory_and_economy()
	test_full_inventory_auto_merge()
	test_npcs()
	test_new_characters()
	test_room_shops_and_skills()
	test_campaign()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
