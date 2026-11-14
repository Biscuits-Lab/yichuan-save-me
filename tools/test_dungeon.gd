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

func finish_encounter() -> void:
	game.invulnerable = 999
	var guard: int = 0
	while not game.current_room().cleared and guard < 160:
		for enemy in game.enemies.duplicate():
			game.hit_enemy(enemy, 100000, game.player)
		step(60)
		guard += 1

func test_generation() -> void:
	var layouts: Dictionary = {}
	var service_cases: Dictionary = {}
	for seed_number in range(1, 61):
		for floor_number in range(game.Data.FLOOR_COUNT):
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
			var main: Array = rooms.filter(func(room: Dictionary) -> bool: return room.main_route)
			check(generated.corridors.size() == rooms.size() - 1 and main.size() >= 6, "A single main route with short branches forms a tree without loops")
			check(rooms[0].links.filter(func(id: int) -> bool: return id >= 0).size() <= 2, "Spawn room has only one or two exits")
			var boundary: bool = false
			for direction in game.Data.DIRECTIONS:
				boundary = boundary or rooms.all(func(room: Dictionary) -> bool: return Vector2(room.cell).dot(Vector2(direction)) >= 0)
			check(boundary, "Spawn room lies on the outer edge of the generated map")
			var short_branches: bool = true
			for room in rooms:
				if not room.main_route:
					short_branches = short_branches and room.links.filter(func(id: int) -> bool: return id >= 0).size() == 1 and rooms[room.parent].main_route
				if room.type in ["rest", "treasure", "npc", "shop"]:
					short_branches = short_branches and not room.main_route
			check(short_branches and rooms[generated.boss].main_route and generated.boss == main.size() - 1, "Service rooms occupy one-room branches and the boss terminates the main route")
			check(kinds.get("boss", 0) == 1 and kinds.get("rest", 0) == 1 and kinds.get("treasure", 0) == 1 and kinds.get("elite", 0) == 1, "Boss, rest, treasure and elite rooms each exist exactly once")
			check(rooms[generated.boss].type == "boss" and generated.boss != 0, "Boss never replaces entrance")
			var services: int = kinds.get("npc", 0) + kinds.get("shop", 0)
			check(services >= 0 and services <= 1 and npc_ids.size() == kinds.get("npc", 0), "NPC and shop rooms share a strict zero-or-one budget per floor")
			service_cases["npc" if kinds.get("npc", 0) > 0 else ("shop" if kinds.get("shop", 0) > 0 else "none")] = true
			check(kinds.get("combat", 0) + kinds.get("elite", 0) + kinds.get("boss", 0) >= rooms.size() - 4, "At least sixty percent of floor rooms contain combat")
			var sizes: Dictionary = {}
			var safe_npcs: bool = true
			var compact_npcs: bool = true
			var compact_combat: bool = true
			for room in rooms:
				sizes[str(room.rect.size)] = true
				safe_npcs = safe_npcs and ((room.npc >= 0) == (room.type == "npc"))
				if room.type == "npc":
					compact_npcs = compact_npcs and room.rect.size.x >= 416 and room.rect.size.x <= 480 and room.rect.size.y >= 288 and room.rect.size.y <= 352
				elif room.type in ["start", "rest", "shop", "treasure"]:
					compact_npcs = compact_npcs and room.rect.size.x <= 576 and room.rect.size.y <= 416
				elif room.type == "combat":
					compact_combat = compact_combat and room.rect.size.x >= 800 and room.rect.size.x <= 1152 and room.rect.size.y >= 544 and room.rect.size.y <= 736
				elif room.type == "elite":
					compact_combat = compact_combat and room.rect.size == Vector2(1152, 768)
				elif room.type == "boss":
					compact_combat = compact_combat and room.rect.size == Vector2(1344, 896)
			check(safe_npcs, "NPCs never populate combat, elite, boss, shop or ordinary rooms")
			check(compact_npcs, "NPC meeting rooms use compact dimensions with room for exits and interaction")
			check(compact_combat, "Combat, elite and boss rooms use the smaller battle footprints")
			check(sizes.size() >= 3, "Each floor mixes small, medium and large physical rooms")
			var connected: bool = true
			for hall in generated.corridors:
				connected = connected and hall.rect.has_area() and hall.rect.intersects(rooms[hall.a].rect) and hall.rect.intersects(rooms[hall.b].rect)
			check(connected and generated.corridors.size() >= rooms.size() - 1, "Real corridors physically join both room footprints")
			layouts[str(rooms.map(func(room: Dictionary) -> Vector2i: return room.cell))] = true
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
		finish_encounter()
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
		for floor_number in range(game.Data.FLOOR_COUNT):
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

func test_compact_room_population() -> void:
	var normal_counts: Array = [[12, 16], [16, 20], [20, 24], [24, 28], [28, 32], [32, 36], [36, 40]]
	for seed_number in [7, 51, 20261113]:
		for floor_number in range(game.Data.FLOOR_COUNT):
			safe_start(seed_number)
			game.floor_index = floor_number
			game.generate_floor()
			for room in game.rooms:
				if room.type not in ["combat", "elite"]:
					continue
				game.current_room().cleared = true
				game.enemies.clear()
				room.encounter = "double"
				game.enter_room(room.id)
				for wave_index in range(2):
					if wave_index == 1:
						game.enemies.clear()
						game.spawn_wave()
					var expected: int = normal_counts[floor_number][wave_index] + (4 if room.type == "elite" else 0)
					check(game.enemies.size() + game.spawn_remaining == expected, "Room population increases by floor and preserves any queued reinforcements")
					var safe: bool = true
					var separated: bool = true
					var reachable: bool = true
					for enemy in game.enemies:
						safe = safe and game.walkable(enemy.p, enemy.radius) and enemy.p.distance_to(game.player) > 230
						var path: PackedVector2Array = game.nav.get_point_path(game.nav_cell(enemy.p), game.nav_cell(game.player))
						reachable = reachable and path.size() > 1
						for other in game.enemies:
							if other != enemy:
								separated = separated and enemy.p.distance_to(other.p) >= enemy.radius + other.radius
					check(safe, "Dense wave spawns remain inside clear floor space away from the player")
					check(separated, "Dense waves do not begin with overlapping enemy bodies")
					check(reachable, "Every enemy in the denser small-room waves can navigate to the player")
	print("Compact rooms and denser waves checks complete")

func test_exploration_minimap() -> void:
	for seed_number in [7, 51, 20261113]:
		for floor_number in range(game.Data.FLOOR_COUNT):
			safe_start(seed_number)
			game.floor_index = floor_number
			game.generate_floor()
			var layout: Dictionary = game.view.minimap_layout()
			check(layout.panel.position.x > 1000 and layout.panel.position.y > 58 and layout.panel.end.x <= 1280, "Minimap occupies a small upper-right panel below the points HUD")
			check(layout.rooms.size() == game.rooms.size() and layout.halls.size() == game.corridors.size(), "Minimap shows the complete connected floor")
			var fits: bool = true
			for room in layout.rooms:
				fits = fits and layout.panel.grow(-10).encloses(room.rect)
			for hall in layout.halls:
				fits = fits and layout.panel.grow(-10).encloses(hall.rect)
			check(fits and layout.panel.has_point(layout.player), "All map rooms, corridors and the player fit in the panel across floor shapes")
			check(layout.rooms[0].status == "current" and layout.rooms.filter(func(room: Dictionary) -> bool: return room.status == "unvisited").size() == game.rooms.size() - 1, "New floors distinguish the current entrance from unvisited rooms")
	safe_start(20261113)
	var next_id: int = game.current_room().links.filter(func(id: int) -> bool: return id >= 0)[0]
	game.enter_room(next_id)
	var layout: Dictionary = game.view.minimap_layout()
	check(layout.rooms[0].status == "visited" and layout.rooms[next_id].status == "current", "Entering another room updates visited and current room markers")
	game.current_room().cleared = true
	game.enemies.clear()
	game.enter_room(0)
	layout = game.view.minimap_layout()
	check(layout.rooms[0].status == "current" and layout.rooms[next_id].status == "visited", "Revisiting rooms keeps exploration history")
	game.player = game.corridors[0].rect.get_center()
	layout = game.view.minimap_layout()
	check(layout.halls.any(func(hall: Dictionary) -> bool: return hall.rect.grow(0.1).has_point(layout.player)), "Player marker follows continuous movement into a corridor")
	check(layout.rooms.all(func(room: Dictionary) -> bool: return room.status != "current"), "Corridor travel does not mark an empty room as the player's position")
	game.floor_index = 1
	game.generate_floor()
	layout = game.view.minimap_layout()
	check(layout.rooms.filter(func(room: Dictionary) -> bool: return room.status != "unvisited").size() == 1, "Entering a new floor resets that floor's exploration map")
	print("Exploration minimap checks complete")

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
	check(game.projectiles.size() == 1 and blocked.hp == blocked.max_hp, "Weapons target blocking destructible cover when enemies are hidden")
	game.update_projectiles(0.2)
	check(game.cover_damage.get(game.obstacles[0], 0) == 1, "An automatic bullet damages cover without hitting the hidden enemy")
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
	game.add_item("vest", 3)
	game.invulnerable = 0
	before = game.health
	game.hurt(10, game.player + Vector2.RIGHT * 30)
	check(absf(before - game.health - 8.8) < 0.01, "Armour changes actual incoming damage")
	game.add_item("coffee", 3)
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
	for floor_number in range(game.Data.FLOOR_COUNT):
		game.floor_index = floor_number
		game.enemies.clear()
		boss = game.spawn_enemy(Vector2(700, 404), "boss")
		game.boss_attack(boss)
		check(game.projectiles.size() > 10, "Each floor boss has a real multi-projectile attack")
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
	game.stock[0] = {"id":"blade", "tier":1, "sold":false}
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
	check(absf(game.equipment_stat("vest") - 0.55) < 0.001, "Fused equipment applies the stronger stat multiplier")
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
	check(game.max_health() == 30 and game.health == 15, "Battery increases maximum and current health")
	game.health = 45
	game.sell("equipment", 0)
	check(game.health == 25 and game.max_health() == 25, "Selling health equipment clamps health to the new maximum")
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
	for kind in ["weapon"]:
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
	check(game.add_item("heart") and game.equipment_count() == 7 and is_equal_approx(game.max_health(), 35) and is_equal_approx(game.health, 20), "Battery copies stack beyond six items without forced fusion or lost healing")
	safe_start()
	for tier in [1, 2, 3]:
		game.add_item("heart", tier)
	for i in range(3):
		game.add_item("boots")
	game.health = game.max_health()
	check(game.add_item("heart") and game.equipment_count() == 7 and is_equal_approx(game.max_health(), 66) and is_equal_approx(game.health, 66), "Different equipment qualities retain all additive bonuses and pickup healing")
	safe_start()
	game.weapons.clear()
	for spec in game.Data.WEAPONS:
		game.add_item(spec.id, 2)
	game.current_room().type = "treasure"
	game.player = game.room_center()
	game.interact()
	check(game.state == "treasure" and not game.current_room().used and game.weapons.size() == 6, "Opening a chest previews cards without equipping a reward")
	game.choose_treasure(0)
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
		game.add_item("pistol", 4)
		game.add_item("vest", 4)
	game.current_room().type = "npc"
	game.current_room().npc = 4
	game.selected_npc = 4
	game.state = "npc"
	check(game.accept_npc() and game.current_room().npc_used and game.weapons.size() == 6 and game.equipment_count() == 7, "Laya can always give equipment when all weapon slots are legendary")
	print("Full inventory auto-fusion checks complete")

func test_equipment_stacks() -> void:
	safe_start()
	for spec in game.Data.EQUIPMENT:
		for tier in range(1, 5):
			for i in range(8):
				check(game.add_item(spec.id, tier), "All equipment tiers accept unlimited stacked copies")
	check(game.equipment.size() == game.Data.EQUIPMENT.size() * 4 and game.equipment_count() == game.Data.EQUIPMENT.size() * 32, "Equipment is grouped by identity and quality without losing copies")
	check(is_equal_approx(game.equipment_stat("scope"), 27.6), "Every stacked quality contributes its full bonus")
	check(is_equal_approx(game.max_health(), 200) and game.health <= 200, "Stacked health bonuses obey the maximum and never overheal")
	game.state = "inventory"
	var balance: int = game.points
	var price: int = game.sell_price(game.equipment[0])
	check(game.sell("equipment", 0) and game.equipment[0].count == 7 and game.equipment_count() == game.Data.EQUIPMENT.size() * 32 - 1 and game.points == balance + price, "Selling stacked equipment consumes and pays for exactly one copy")
	check(game.fuse("equipment", 0) and game.equipment[0].count == 5 and game.equipment[1].count == 9 and game.equipment_count() == game.Data.EQUIPMENT.size() * 32 - 2, "Manual fusion consumes two stacked copies and stacks the upgraded result")
	check(not game.can_add_item("vest", 5) and not game.add_item("missing"), "Unlimited equipment still validates item identity and tier")
	print("Unlimited equipment checks complete")

func test_room_progression() -> void:
	for level in range(3):
		game.difficulty = level
		safe_start()
		check(game.health == 25 and game.max_health() == 25, "Every difficulty starts at exactly 25 health")
	game.difficulty = 1
	safe_start()
	game.current_room().type = "combat"
	game.current_room().rect = game.Data.ARENA
	var offer: Dictionary = {"id":"blade", "tier":1}
	var base_price: int = game.shop_price(offer)
	var normal: Dictionary = game.spawn_enemy(game.room_center() + Vector2(200, 0))
	var base_hp: float = normal.max_hp
	game.enemies.clear()
	for cleared in [1, 5, 12]:
		game.cleared_count = cleared
		normal = game.spawn_enemy(game.room_center() + Vector2(200, 0))
		check(is_equal_approx(normal.max_hp, base_hp * (1.0 + cleared * 0.1)), "Enemy health follows successful room count")
		check(game.shop_price(offer) == ceili(base_price * (1.0 + cleared * 0.05)), "Item prices follow successful room count")
		game.projectiles.clear()
		game.shoot(game.room_center(), Vector2.RIGHT, 10, false, Color.WHITE)
		check(is_equal_approx(game.projectiles[0].damage, 10 * (1.0 + cleared * 0.04)), "Hostile projectile damage follows successful room count")
		game.shoot(game.room_center(), Vector2.RIGHT, 10, true, Color.WHITE)
		check(game.projectiles[-1].damage == 10, "Room progression does not inflate player projectile damage")
		game.enemies.clear()
		game.player = game.room_center()
		game.health = game.max_health()
		game.invulnerable = 0
		normal = game.spawn_enemy(game.player)
		normal.age = 2
		game.update_enemies(0)
		check(is_equal_approx(25 - game.health, 8 * (1.0 + cleared * 0.04)), "Contact damage receives the room multiplier once")
		game.enemies.clear()
	game.current_room().type = "shop"
	check(game.shop_price(offer) == ceili(base_price * 1.6 * 0.85), "Shop room discount is applied together with room inflation")
	game.floor_index = 1
	game.generate_floor()
	check(game.cleared_count == 12, "Changing floors preserves successful room progression")
	game.start_run(51, true)
	check(game.cleared_count == 0 and game.shop_price(offer) == base_price and game.health == 25, "Restart resets scaling and initial health")
	print("Room progression checks complete")

func test_enemy_variety() -> void:
	safe_start()
	game.current_room().type = "combat"
	game.current_room().encounter = "single"
	game.current_room().rect = game.Data.ARENA
	game.current_room().cleared = false
	game.weapons.clear()
	game.wave = 0
	game.wave_total = 1
	game.spawn_wave()
	var kinds: Dictionary = {}
	for enemy in game.enemies:
		kinds[enemy.kind] = true
	check(kinds.size() == 5 and kinds.has("splitter") and kinds.has("dasher"), "Normal waves contain all five distinct enemy behaviors")
	game.enemies.clear()
	game.spawn_remaining = 0
	game.player = Vector2(850, 380)
	var dasher: Dictionary = game.spawn_enemy(Vector2(500, 380), "dasher")
	dasher.age = 2
	dasher.cooldown = 0
	game.update_enemies(0.01)
	check(dasher.windup > 0 and dasher.charge == 0, "Fast dash enemy warns before attacking")
	game.update_enemies(0.36)
	game.update_enemies(0.02)
	var start: Vector2 = dasher.p
	game.update_enemies(0.1)
	check(dasher.charge > 0 and dasher.p.distance_to(start) > 40, "Fast dash enemy performs a real short burst of movement")
	game.enemies.clear()
	var splitter: Dictionary = game.spawn_enemy(Vector2(640, 380), "splitter")
	game.hit_enemy(splitter, 100000, game.player)
	check(game.enemies.size() == 3 and game.enemies.all(func(enemy: Dictionary) -> bool: return enemy.kind == "minislime" and enemy.radius == 10 and game.walkable(enemy.p, enemy.radius)), "Killing a splitting slime creates three smaller live enemies on valid floor")
	step(46)
	check(not game.current_room().cleared and game.state == "playing", "Split children keep the encounter locked until defeated")
	for child in game.enemies.duplicate():
		game.hit_enemy(child, 100000, game.player)
	check(game.enemies.is_empty(), "Small slimes die without recursively splitting")
	step(46)
	check(game.current_room().cleared and game.state == "shop", "Defeating all split children completes the room normally")
	print("Enemy variety checks complete")

func test_dense_boss_barrages() -> void:
	var previous_counts: Array = [[15, 21], [16, 20], [16, 24], [20, 28], [12, 12], [12, 12], [25, 33]]
	for floor_number in range(game.Data.FLOOR_COUNT):
		for phase in range(2):
			safe_start()
			game.floor_index = floor_number
			var boss: Dictionary = game.spawn_enemy(game.room_center(), "boss")
			boss.phase = phase
			for move in range(4):
				game.projectiles.clear()
				game.boss_attack(boss)
				var previous: int = previous_counts[floor_number][phase]
				if floor_number == 4:
					previous = ([12, 12, 18, 21] if phase == 0 else [12, 12, 24, 21])[move]
				elif floor_number == 5:
					previous = ([12, 15, 16, 12] if phase == 0 else [12, 20, 24, 12])[move]
				check(game.projectiles.size() >= ceili(previous * 1.4), "Every boss move fires a denser barrage in both phases")
				check(game.projectiles.size() <= 64 and game.projectiles.all(func(shot: Dictionary) -> bool: return not shot.friendly and shot.velocity.length() <= 400 and shot.life <= 3.3), "Denser boss volleys keep finite counts, speeds and lifetimes")
	print("Dense boss barrage checks complete")

func test_destructible_cover() -> void:
	safe_start()
	var cover := Rect2(510, 376, 64, 56)
	game.obstacles.assign([cover])
	game.build_navigation()
	game.player = Vector2(440, 404)
	var balance: int = game.points
	var kills: int = game.kills
	check(not game.walkable(cover.get_center()) and not game.line_clear(game.player, Vector2(620, 404)), "Intact scenery blocks movement and attacks")
	for i in range(3):
		game.shoot(game.player + Vector2(24, 0), Vector2(650, 0), 999, i != 1, Color.WHITE)
		game.update_projectiles(0.3)
		check(game.projectiles.is_empty() and game.cover_damage.get(cover, 0) == i + 1, "Friendly and hostile shots each damage scenery once and stop at it")
		if i < 2:
			check(cover in game.obstacles and cover not in game.broken_obstacles, "Damaged scenery survives the first two hits")
	check(cover not in game.obstacles and cover in game.broken_obstacles and game.walkable(cover.get_center()) and game.line_clear(game.player, Vector2(620, 404)), "Third hit leaves rubble and releases movement and attack collision")
	check(not game.nav.is_point_solid(game.nav_cell(cover.get_center())), "Breaking scenery immediately updates the navigation grid")
	game.hit_cover(cover)
	check(game.broken_obstacles.size() == 1 and game.points == balance and game.kills == kills, "Rubble cannot break twice or grant enemy kill rewards")
	for spec in game.Data.WEAPONS:
		safe_start()
		game.obstacles.assign([cover])
		game.player = Vector2(440, 404)
		game.weapons.clear()
		game.add_item(spec.id)
		for i in range(3):
			game.weapons[0].cooldown = 0
			game.update_weapons(0.01)
			game.update_projectiles(0.3)
		check(cover not in game.obstacles and cover in game.broken_obstacles, spec.name + " actually destroys scenery through its normal automatic attack")
	safe_start()
	for room in game.rooms:
		if room.type == "combat":
			game.enter_room(room.id)
			break
	var room_id: int = game.room_id
	cover = game.current_room().obstacles[0]
	for i in range(3):
		game.hit_cover(cover)
	game.enemies.clear()
	game.current_room().cleared = true
	game.enter_room(0)
	game.enter_room(room_id)
	check(cover not in game.obstacles and cover in game.broken_obstacles, "Destroyed scenery remains destroyed when returning to the room")
	game.generate_floor()
	check(cover in game.obstacles and game.cover_damage.is_empty() and game.broken_obstacles.is_empty(), "Regenerating a floor resets scenery damage and rubble")
	print("Destructible scenery checks complete")

func test_enemy_facing() -> void:
	for kind in ["slime", "ranged", "charger", "wolf", "ropehead", "shark", "boss"]:
		safe_start()
		game.obstacles.clear()
		game.player = game.room_center() + Vector2(200, 0)
		var enemy: Dictionary = game.spawn_enemy(game.room_center(), kind)
		enemy.age = 2
		enemy.cooldown = 10
		game.update_enemies(0.1)
		check(enemy.facing == 1, "Enemy faces its rightward movement or initial target: " + kind)
		game.player = enemy.p - Vector2(400, 0)
		game.update_enemies(0.1)
		check(enemy.facing == -1, "Enemy turns left when its actual movement changes: " + kind)
		enemy.charge = 0.2
		enemy.aim = Vector2.RIGHT
		game.update_enemies(0.05)
		check(enemy.facing == 1, "Charging faces movement even when the player is behind: " + kind)
	safe_start()
	game.obstacles.clear()
	var caster: Dictionary = game.spawn_enemy(game.room_center(), "ranged")
	caster.age = 2
	caster.cooldown = 10
	game.player = caster.p + Vector2(100, 0)
	game.update_enemies(0.1)
	check(caster.facing == -1, "Ranged retreat faces its real movement rather than the player")
	caster.cooldown = 0
	game.update_enemies(0.01)
	check(caster.windup > 0 and caster.facing == 1, "A stationary ranged windup faces its locked firing direction")
	game.player = caster.p - Vector2(100, 0)
	game.update_enemies(0.01)
	check(caster.facing == 1, "Moving around a warned attack does not flip its locked aim")
	print("Enemy facing checks complete")

func test_distinct_bosses() -> void:
	var signatures: Dictionary = {}
	var shark_signatures: Dictionary = {}
	for floor_number in range(game.Data.FLOOR_COUNT):
		safe_start()
		game.floor_index = floor_number
		game.current_room().rect = game.Data.ARENA
		game.current_room().type = "boss"
		game.player = game.room_center() - Vector2(200, 0)
		var boss: Dictionary = game.spawn_enemy(game.room_center() + Vector2(200, 0), "boss")
		check(boss.max_hp > 390 + floor_number * 260, "Each floor boss has more base health than before")
		boss.age = 2
		boss.cooldown = 0
		game.update_enemies(0.01)
		check(boss.windup > 0 and game.projectiles.is_empty(), "Each stronger boss still warns before firing")
		for i in range(46):
			game.update_enemies(1.0 / 60.0)
		signatures[str(game.projectiles.map(func(shot: Dictionary) -> Vector2: return shot.velocity)) + str(boss.charge)] = true
		check(boss.cooldown <= 1.9, "Boss attack cadence is faster than before")
		if floor_number == 1:
			check(boss.charge > 0 and boss.charge_left == 1, "Workshop boss starts a two-charge combination")
			boss.charge = 0
			game.boss_attack(boss)
			check(boss.charge > 0 and boss.charge_left == 0, "Workshop boss follows through with the second charge")
		elif floor_number == game.Data.FLOOR_COUNT - 1:
			game.boss_attack(boss)
			check(game.enemies.size() == 4, "Castle boss mixes rotating barrages with reinforcements")
		game.enemies.clear()
		game.projectiles.clear()
		var shark: Dictionary = game.spawn_enemy(game.room_center(), "shark")
		check(shark.max_hp > 270 + floor_number * 170, "Elite sharks also gain stronger base health")
		game.boss_attack(shark)
		shark_signatures[str(game.projectiles.map(func(shot: Dictionary) -> Vector2: return shot.velocity))] = true
	check(signatures.size() == game.Data.FLOOR_COUNT and shark_signatures.size() == game.Data.FLOOR_COUNT, "All floor bosses and elite variants have distinct attack patterns")
	print("Distinct boss checks complete")

func test_expanded_campaign() -> void:
	check(game.Data.FLOOR_COUNT == 7 and game.Data.FLOOR_NAMES.size() == 7 and game.Data.FLOOR_STYLES.size() == 7 and game.Data.FLOOR_COLORS.size() == 7 and game.Data.FLOOR_STORIES.size() == 7 and game.Data.BOSS_NAMES.size() == 7 and game.Data.BOSS_HEALTH.size() == 7 and game.Data.SHARK_HEALTH.size() == 7, "Seven-floor data covers names, art, story and enemy scaling")
	check(game.Data.BOSS_NAMES[5].contains("山田") and game.Data.BOSS_NAMES[-1].contains("杨梓亮"), "Yamada guards his dojo and Yang remains the final boss")
	check(game.yamada_atlas.frames.size() == 4 and game.stage_atlases.size() == 4, "Yamada and the four new environment atlases are loaded")
	for theme in ["server", "garden", "sumo"]:
		var atlas: RefCounted = game.stage_atlases[theme]
		var image: Image = atlas.texture.get_image()
		check(atlas.frames.size() == 8 and image.get_pixel(20, image.get_height() - 20).a < 0.05, "Theme props retain real transparent backgrounds: " + theme)
		check(image.get_pixel(100, 100).a > 0.95, "Theme floors remain opaque: " + theme)
	safe_start()
	game.floor_index = 5
	game.generate_floor()
	for room in game.rooms:
		if room.type == "boss":
			game.enter_room(room.id)
			break
	var boss: Dictionary = game.enemies[0]
	boss.age = 2
	boss.cooldown = 0
	game.player = boss.p - Vector2(240, 0)
	game.update_enemies(0.01)
	var aim: Vector2 = boss.aim
	check(boss.windup > 0 and boss.charge == 0 and game.projectiles.is_empty(), "Yamada warns and locks his aim before charging")
	game.player = boss.p + Vector2(0, 240)
	for i in range(46):
		game.update_enemies(1.0 / 60.0)
	check(boss.charge > 0 and boss.aim == aim and game.projectiles.size() == 18, "Yamada charges toward his warned direction with denser side shockwaves")
	boss.cooldown = 0
	game.update_enemies(0.01)
	check(boss.windup <= 0, "An active Yamada charge cannot start another attack")
	boss.charge = 0
	game.projectiles.clear()
	game.boss_attack(boss)
	check(boss.charge == 0 and game.projectiles.size() == 28, "Yamada follows with four seven-shot palm-strike waves")
	game.projectiles.clear()
	game.boss_attack(boss)
	check(game.projectiles.size() == 24 and game.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "dust"), "Yamada's third attack stomps out a denser shockwave and dust")
	boss.hp = boss.max_hp * 0.4
	boss.cooldown = 10
	game.update_enemies(0.01)
	for i in range(8):
		game.update_enemies(1.0 / 60.0)
	check(boss.phase == 1 and boss.windup > 0, "Yamada enrages at half health while preserving his warning")
	boss.attack = 5
	game.projectiles.clear()
	game.boss_attack(boss)
	check(game.projectiles.size() == 36 and game.enemies.size() == 3, "Enraged Yamada adds shockwaves and bounded reinforcements")
	game.hit_enemy(boss, 1000000, game.player)
	step(46)
	check(game.state == "skill" and game.floor_index == 5, "Yamada's defeat gives the regular floor reward")
	game.choose_skill(0)
	check(game.floor_index == 6 and game.dialogue_kind == "floor" and game.dialogue().line.contains("杨梓亮"), "Yamada's reward proceeds to the castle without ending the run")
	print("Expanded campaign and Yamada checks complete")

func test_wilds_chapter() -> void:
	safe_start(20261114)
	game.floor_index = 4
	game.generate_floor()
	check(game.Data.BOSS_NAMES[4].contains("牛来") and game.wilds_atlas.frames.size() == 16 and game.stage_atlases.wilds.frames.size() == 12, "Niulai, Baola, wolves, Ropehead and forest art are connected")
	check(game.rooms.any(func(room: Dictionary) -> bool: return room.terrain == "forest") and game.rooms.any(func(room: Dictionary) -> bool: return room.terrain == "grassland"), "The wilds chapter traverses both shaded forest and sunny meadow")
	check(game.rooms.filter(func(room: Dictionary) -> bool: return room.type == "elite").all(func(room: Dictionary) -> bool: return room.elite_kind == "baola"), "Baola guards the wilds elite encounter")
	for room in game.rooms:
		if room.type == "combat":
			game.enter_room(room.id)
			break
	check(not game.enemies.is_empty() and game.enemies.all(func(enemy: Dictionary) -> bool: return enemy.kind in ["wolf", "ropehead"]), "Wilds battle waves contain wolves and Ropehead instead of indoor monsters")
	game.enemies.clear()
	var wolf: Dictionary = game.spawn_enemy(game.room_center() + Vector2(180, 0), "wolf")
	var snake: Dictionary = game.spawn_enemy(game.room_center() + Vector2(-180, 0), "ropehead")
	for enemy in [wolf, snake]:
		enemy.age = 2
		enemy.cooldown = 0
	game.update_enemies(0.01)
	check(wolf.windup > 0 and snake.windup > 0 and game.projectiles.is_empty(), "Wolf pounces and Ropehead venom both give a warning")
	for i in range(42):
		game.update_enemies(1.0 / 60.0)
	check(wolf.cooldown > 0 and snake.cooldown > 0 and game.projectiles.size() == 3, "Wolf completes its pounce while Ropehead fires three venom projectiles")
	game.enemies.clear()
	game.projectiles.clear()
	game.current_room().cleared = true
	for room in game.rooms:
		if room.type == "boss":
			game.enter_room(room.id)
			break
	var boss: Dictionary = game.enemies[0]
	check(game.current_room().terrain == "grassland" and game.boss_name(boss).contains("牛来"), "Niulai waits in the open meadow boss clearing")
	game.boss_attack(boss)
	check(boss.charge > 0 and boss.charge_left == 1 and game.projectiles.size() == 18, "Niulai opens with the first warned horn charge")
	boss.charge = 0
	game.boss_attack(boss)
	check(boss.charge > 0 and boss.charge_left == 0, "Niulai follows with the second charge")
	boss.charge = 0
	game.projectiles.clear()
	game.boss_attack(boss)
	check(boss.charge == 0 and game.projectiles.size() == 28, "Niulai follows his charges with a denser radial ground shockwave")
	game.projectiles.clear()
	game.boss_attack(boss)
	check(game.enemies.size() == 3 and game.enemies.any(func(enemy: Dictionary) -> bool: return enemy.kind == "wolf") and game.enemies.any(func(enemy: Dictionary) -> bool: return enemy.kind == "ropehead"), "Niulai's fourth move calls his actual forest animals")
	game.hit_enemy(boss, 1000000, game.player)
	step(46)
	check(game.state == "skill", "Niulai's defeat opens the normal floor skill reward")
	game.choose_skill(0)
	check(game.floor_index == 5 and game.dialogue_kind == "floor" and game.dialogue().line.contains("山田"), "The wilds chapter proceeds to Yamada rather than prematurely rescuing the princess")
	print("Forest, meadow and Niulai checks complete")

func test_encounter_modes() -> void:
	var generated_modes: Dictionary = {}
	var generated_elites: Dictionary = {}
	for seed_number in range(1, 31):
		for room in game.Data.generate(seed_number, 0).rooms:
			if room.type == "combat":
				generated_modes[room.encounter] = true
			elif room.type == "elite":
				generated_elites[room.elite_kind] = true
	check(generated_modes.size() == 3 and generated_elites.size() == 3, "Generated floors vary all encounter modes and elite identities")
	for mode in ["single", "double", "stream"]:
		safe_start()
		var room: Dictionary = game.current_room()
		room.type = "combat"
		room.encounter = mode
		room.rect = game.Data.ARENA
		room.cleared = false
		game.activate_room(game.room_id)
		game.weapons.clear()
		game.invulnerable = 999
		check(game.wave_total == (2 if mode == "double" else 1), "Single, double and streamed rooms advertise their actual wave structure")
		var total: int = game.enemies.size() + game.spawn_remaining
		check(total == game.encounter_population(), "Every encounter has a finite accounted spawn budget")
		if mode == "stream":
			check(game.enemies.size() == 4 and game.spawn_remaining == total - 4, "Streamed encounter starts small and holds back reinforcements")
			var before: int = game.spawn_remaining
			step(60)
			check(game.spawn_remaining < before and game.wave == 1, "Streamed reinforcements arrive while previous enemies are still alive")
			for enemy in game.enemies.duplicate():
				game.hit_enemy(enemy, 100000, game.player)
			game.enemies.clear()
			game.spawn_timer = 2
			step(46)
			check(not room.cleared and game.state == "playing", "An empty field cannot finish a room with queued reinforcements")
		finish_encounter()
		check(room.cleared and game.state == "shop" and game.cleared_count == 1 and game.spawn_remaining == 0, "Every encounter mode finishes once and grants one supply visit")
		safe_start()
		game.current_room().type = "combat"
		game.current_room().encounter = mode
		game.wave = 1
		var early: int = game.encounter_population()
		game.cleared_count = 18
		check(game.encounter_population() > early, "Room population grows with successful clears in every mode")
		game.floor_index = 2
		check(game.encounter_population() > early + 18, "Later floors add population on top of room progression")
	safe_start()
	game.current_room().rect = game.Data.ARENA
	game.player = game.room_center() + Vector2(200, 0)
	var early: Dictionary = game.spawn_enemy(game.room_center() - Vector2(200, 0), "ranged")
	game.cleared_count = 15
	var late: Dictionary = game.spawn_enemy(early.p, "ranged")
	check(late.speed > early.speed and late.haste > early.haste, "Later enemies have greater movement speed and attack cadence")
	early.age = 2
	late.age = 2
	early.cooldown = 1
	late.cooldown = 1
	game.update_enemies(0.2)
	check(late.cooldown < early.cooldown, "Enemy haste changes actual attack countdowns")
	print("Encounter mode checks complete")

func test_elite_variety_and_summons() -> void:
	for kind in game.Data.ELITES:
		safe_start()
		game.current_room().type = "elite"
		game.current_room().elite_kind = kind
		game.current_room().rect = game.Data.ARENA
		game.current_room().cleared = false
		game.wave = 1
		game.wave_total = 2
		game.spawn_wave()
		var elite: Dictionary = game.enemies[0]
		check(game.enemies.size() == 1 and elite.kind == kind and game.is_boss(elite) and not game.boss_name(elite).is_empty(), "Elite final waves spawn the generated elite with proper boss handling")
		game.boss_attack(elite)
		if kind == "brood":
			check(game.enemies.size() == 3 and game.enemies[1].kind == "minislime", "Brood elite summons live children alongside its projectile ring")
		elif kind == "warden":
			check(game.projectiles.size() == 15 and elite.charge == 0, "Warden elite combines a rotating ring and aimed shots without shark charges")
		else:
			check(elite.charge > 0, "Shark elite retains its distinct physical charge")
		game.hit_enemy(elite, 100000, game.player)
		step(46)
		check(game.current_room().cleared and game.state == "shop", "Each elite type clears its summons and finishes through room supplies")
	for floor_number in range(game.Data.FLOOR_COUNT):
		safe_start()
		game.floor_index = floor_number
		game.current_room().type = "boss"
		game.current_room().rect = game.Data.ARENA
		var boss: Dictionary = game.spawn_enemy(game.room_center(), "boss")
		boss.phase = 1
		boss.attack = 5
		game.boss_attack(boss)
		check(game.enemies.size() > 1 and game.enemies.size() <= 7, "Each floor boss has a bounded reinforcement mechanic")
		var summons: Array = game.enemies.filter(func(enemy: Dictionary) -> bool: return enemy != boss)
		check(summons.all(func(enemy: Dictionary) -> bool: return game.walkable(enemy.p, enemy.radius) and enemy.age == 0), "Boss reinforcements spawn on valid floor with their spawn warning")
	print("Elite and summon checks complete")

func test_treasure_choices() -> void:
	safe_start()
	game.current_room().type = "treasure"
	game.player = game.room_center()
	var before: int = game.weapons.size() + game.equipment_count()
	game.interact()
	var offers: Array = game.current_room().treasure_offers.duplicate(true)
	check(game.state == "treasure" and offers.size() == 3 and game.weapons.size() + game.equipment_count() == before and not game.current_room().used, "Chest cards preview three rewards before changing the loadout")
	var position: Vector2 = game.player
	step(60)
	check(game.player == position, "Chest choice pauses movement and combat")
	key(KEY_TAB)
	check(game.state == "inventory" and game.return_state == "treasure", "Chest preview allows making room in the inventory")
	key(KEY_ESCAPE)
	check(game.state == "treasure" and game.current_room().treasure_offers == offers, "Returning to the chest preserves its exact reward choices")
	check(not game.choose_treasure(-1), "Invalid treasure selection cannot consume the chest")
	key(KEY_3)
	check(game.state == "playing" and game.current_room().used and game.equipment_count() == 1 and not game.choose_treasure(0), "Selecting a card equips exactly one reward and consumes the chest once")
	game.interact()
	check(game.state == "playing", "Claimed chests cannot be reopened")
	safe_start()
	game.current_room().type = "treasure"
	game.player = game.room_center()
	game.interact()
	key(KEY_ESCAPE)
	check(game.state == "playing" and game.current_room().used and game.weapons.size() == 1 and game.equipment.is_empty(), "Abandoning the cards consumes the chest without equipping an item")
	safe_start()
	game.weapons.clear()
	for spec in game.Data.WEAPONS:
		game.add_item(spec.id, 4)
	game.current_room().type = "treasure"
	game.player = game.room_center()
	game.interact()
	check(not game.choose_treasure(0) and game.state == "treasure" and not game.current_room().used, "A full weapon inventory leaves chest choices available after a rejected pickup")
	check(game.choose_treasure(2) and game.equipment_count() == 1, "Equipment remains selectable when all weapon slots are full")
	print("Treasure choice checks complete")

func test_enemy_behaviour() -> void:
	safe_start()
	game.current_room().rect = game.Data.ARENA
	game.weapons.clear()
	game.player = Vector2(600, 350)
	var caster: Dictionary = game.spawn_enemy(Vector2(330, 350), "ranged")
	caster.age = 2
	caster.cooldown = 0
	game.update_enemies(0.01)
	check(caster.windup > 0 and game.projectiles.is_empty(), "Ranged attacks show a warning before shooting")
	game.update_enemies(0.7)
	check(game.projectiles.size() == 3 and game.projectiles.all(func(shot: Dictionary) -> bool: return not shot.friendly and is_equal_approx(shot.velocity.length(), 225)), "Ranged windup produces a three-shot hostile fan")
	check(game.projectiles[0].velocity.cross(game.projectiles[1].velocity) != 0 and game.projectiles[1].velocity.cross(game.projectiles[2].velocity) != 0, "Ranged volley lanes fan out rather than stacking identical shots")
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
	game.current_room().rect = game.Data.ARENA
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
			0: check(game.health == game.max_health(), "Ruoyu restores health up to the current maximum")
			1:
				check(game.contract_pending and game.current_room().cleared and game.enemies.is_empty(), "Rhode keeps his meeting room safe and queues a later challenge")
				for room in game.rooms:
					if room.type == "combat":
						game.enter_room(room.id)
						break
				check(game.contract_active and game.wave_total == (3 if game.current_room().encounter == "double" else 2) and game.current_room().npc == -1, "Contract adds a wave only to the next NPC-free combat room")
				var before: int = game.points
				finish_encounter()
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
	check(game.accept_npc() and game.current_room().npc_used and game.equipment_count() == 7, "Unlimited equipment keeps Laya's gift claimable with full legendary weapons")
	check(game.Data.NPCS[0].quote == "this is the way" and game.Data.NPCS[1].quote == "给毅川派活" and game.Data.NPCS[2].quote == "毅川救我" and game.Data.NPCS[3].quote == "好他妈卡我草了", "NPC catchphrases match the requested dialogue")
	print("NPC checks complete")

func test_heide_companion() -> void:
	safe_start()
	var heide: int = 2
	game.current_room().type = "npc"
	game.current_room().npc = heide
	game.current_room().npc_used = false
	game.selected_npc = heide
	game.player = game.npc_position()
	game.state = "npc"
	check(game.accept_npc(), "Heide can be recruited at his meeting room")
	check(game.current_room().npc == -1, "Recruiting Heide removes his stationary NPC and interaction prompt")
	game.interact()
	check(game.state == "playing", "Recruited Heide cannot reopen a second stationary conversation")
	for direction in range(4):
		safe_start()
		for room in game.rooms:
			if room.type != "combat" or room.links[direction] < 0:
				continue
			game.player = room.doors[direction].move_toward(room.center, 55)
			game.knight = room.doors[direction].move_toward(room.center, -30)
			game.previous_knight = game.knight
			game.knight_active = true
			game.activate_room(room.id)
			check(not game.closed_gates().is_empty(), "Companion regression enters a genuinely sealed combat room")
			check(room.rect.grow(-32).has_point(game.knight) and game.walkable(game.knight), "Heide enters before the combat gate traps him: direction %d" % direction)
			check(game.previous_knight == game.knight, "Regrouping clears interpolation across the sealed gate")
			break
	safe_start()
	game.current_room().rect = game.Data.ARENA
	game.obstacles.assign([Rect2(365, 230, 60, 140)])
	game.build_navigation()
	game.player = Vector2(510, 300)
	game.knight = Vector2(300, 300)
	game.knight_active = true
	var max_step: float = 0
	for i in range(240):
		var before: Vector2 = game.knight
		game.update_knight(1.0 / 60.0)
		max_step = maxf(max_step, before.distance_to(game.knight))
	check(game.knight.distance_to(game.player) < 100 and game.walkable(game.knight), "Heide follows around furniture instead of walking into it forever")
	check(max_step < 4, "Following around cover uses actual walking rather than teleporting")
	game.obstacles.clear()
	game.knight = game.player + Vector2(500, 0)
	game.previous_knight = game.knight
	game.update_knight(1.0 / 60.0)
	check(game.knight.distance_to(game.player) < 80 and game.walkable(game.knight), "A distant companion rejoins on valid floor")
	check(game.previous_knight.distance_to(game.knight) < 4, "Companion recovery never interpolates across walls")
	var atlas: RefCounted = game.heide_atlas
	check(atlas.frames.size() == 32 and atlas.texture.get_image().get_pixel(0, 0).a < 0.01, "Heide has a transparent dedicated 32-frame animation atlas")
	for frame in atlas.frames:
		check(frame.bounds.get_area() > 100 and frame.anchor == atlas.frames[0].anchor, "Every Heide pose is visible and keeps a stable feet anchor")
	check(atlas.row_heights.all(func(height: float) -> bool: return height == atlas.row_heights[0]), "Heide keeps the same body scale across all four directions")
	for row in range(4):
		game.knight_facing = [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN][row]
		game.knight_moving = false
		game.knight_attack_time = 0
		for pose in range(2):
			game.knight_animation_time = pose * 0.5
			check(game.knight_frame() == row * 8 + pose, "Heide breathes in the direction he faces")
		game.knight_moving = true
		for pose in range(4):
			game.knight_animation_time = (pose + 0.1) / 9.0
			check(game.knight_frame() == row * 8 + 2 + pose, "Heide walks through each of four directional leg poses")
		for pose in range(2):
			game.knight_attack_time = 0.28 - pose * 0.15
			check(game.knight_frame() == row * 8 + 6 + pose, "Sword windup and follow-through override walking in every direction")
	print("Heide companion checks complete")

func test_new_characters() -> void:
	safe_start()
	game.current_room().type = "elite"
	game.current_room().elite_kind = "shark"
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
	for floor_number in range(game.Data.FLOOR_COUNT):
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
		check(weapons + gear == 4, "Every random shelf contains four valid items without a category quota")
		game.points = 1000
		for i in range(4):
			check(game.buy(i), "All four post-combat cards can be purchased")
		check(game.stock.all(func(offer: Dictionary) -> bool: return offer.sold), "Purchased shelf records each sold card")
		var saved_stock: Array = game.stock.duplicate(true)
		var balance: int = game.points
		check(not game.refresh_shop() and game.points == balance and game.stock == saved_stock and game.current_room().refreshes == 0, "Post-combat supplies reject refresh without changing stock, currency or counters")
		key(KEY_R)
		check(game.state == "shop" and game.stock == saved_stock and game.points == balance, "R cannot refresh sold-out post-combat supplies")
		key(KEY_TAB)
		check(game.state == "inventory", "One-time supplies still allow organizing the inventory")
		key(KEY_ESCAPE)
		check(game.state == "shop", "Returning from inventory preserves the current supply visit")
		game.points = 0
		var refreshes: int = game.current_room().refreshes
		saved_stock = game.stock.duplicate(true)
		check(not game.refresh_shop() and game.current_room().refreshes == refreshes and game.stock == saved_stock, "Unaffordable paid refresh does not consume or replace stock")
		key(KEY_ESCAPE)
		check(game.state == "playing" and game.floor_index == floor_number, "Closing room supplies resumes the same floor")
		game.player = game.room_center()
		game.interact()
		game.open_shop()
		game.clear_room()
		check(game.state == "playing" and not game.has_shop() and not game.current_room().reward_shop, "Closed combat supplies cannot reopen through E, direct opening or repeated clearing")
		var cleared: int = game.cleared_count
		var id: int = game.room_id
		game.enter_room(game.rooms.size() - 1)
		game.current_room().cleared = true
		game.enemies.clear()
		game.enter_room(id)
		game.interact()
		check(game.state == "playing" and not game.has_shop() and game.cleared_count == cleared, "Revisiting a cleared room cannot restore supplies or count another clear")
	for floor_number in range(game.Data.FLOOR_COUNT):
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
		if floor_number < game.Data.FLOOR_COUNT - 1:
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
			"vigor": check(game.max_health() == 45, "Vitality increases actual maximum health")
			"recovery":
				game.health = 10
				step(60)
				check(game.health > 10.49, "Regeneration restores health in real simulation")
			"dash":
				game.start_dash()
				check(game.dash_cooldown < 1.51, "Blink reduces actual dash cooldown")
			"onion":
				game.use_onion()
				check(game.onion_skill and game.shield_time > 2 and game.onion_cooldown < 10, "Onion skill unlocks and strengthens the active guard")
	safe_start()
	for floor_number in range(game.Data.FLOOR_COUNT):
		game.floor_index = floor_number
		for room_size in [Vector2(800, 544), Vector2(1152, 736)]:
			for layout in range(5):
				for rect in game.Data.obstacles(layout, "combat", Rect2(Vector2.ZERO, room_size)):
					var drawn: Rect2 = game.view.cover_draw_rect(rect)
					var frame: Dictionary = game.view.stage_atlas().frames[game.view.cover_index()]
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
	for floor_number in range(game.Data.FLOOR_COUNT):
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
				finish_encounter()
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
		if floor_number < game.Data.FLOOR_COUNT - 1:
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
	check(game.state == "won" and game.best_floor == game.Data.FLOOR_COUNT, "Seven-floor campaign reaches the rescued princess ending")
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

func test_build_balance() -> void:
	var ids: Dictionary = {}
	for spec in game.Data.WEAPONS + game.Data.EQUIPMENT:
		check(not ids.has(spec.id), "Each expanded item has a unique identity")
		ids[spec.id] = true
		check(game.item_icons.has(spec.id) or game.Data.ITEM_ICONS.has(spec.id), "Every item has connected artwork")
		if game.item_icons.has(spec.id):
			var icon: RefCounted = game.item_icons[spec.id]
			check(icon.frames.size() == 1 and icon.frames[0].bounds.get_area() > 0 and icon.texture.get_image().get_pixel(0, 0).a < 0.01, "Each new thumbnail is a visible independent image with alpha")
		if spec.kind == "weapon":
			check(spec.attack_type in game.Data.ATTACK_NAMES, "Every weapon declares its attack attribute")
		for id in spec.get("stats", {}):
			check(id in game.Data.STAT_CAPS, "Every item stat has a gameplay limit")
	safe_start()
	game.add_item("scope")
	check(is_equal_approx(game.damage_scale(), 1.0375), "Ordinary equipment grants one quarter of the former bonus")
	game.equipment.clear()
	game.add_item("scope", 3)
	check(is_equal_approx(game.damage_scale(), 1.15), "Tier three equipment reaches the former ordinary bonus")
	for pair in [["wrist_rest", "melee"], ["mouse", "ranged"], ["sticky", "magic"]]:
		safe_start()
		game.add_item(pair[0], 3)
		for attack_type in game.Data.ATTACK_NAMES:
			check(is_equal_approx(game.damage_scale(attack_type), 1.15 if attack_type == pair[1] else 1.0), "Specialized items only increase their matching attack type")
		for weapon_id in ["blade", "pistol", "wand"]:
			game.weapons.clear()
			game.add_item(weapon_id)
			game.current_room().rect = game.Data.ARENA
			game.obstacles.clear()
			game.player = Vector2(440, 404)
			game.enemies.clear()
			game.projectiles.clear()
			var target: Dictionary = game.spawn_enemy(Vector2(515, 404))
			target.age = 2
			target.hp = 1000
			var expected_rng := RandomNumberGenerator.new()
			expected_rng.seed = 20
			game.rng.seed = 20
			var critical: bool = expected_rng.randf() < game.player_stat("crit_chance")
			var spec: Dictionary = game.Data.item(weapon_id)
			var expected: float = spec.damage * (1.15 if spec.attack_type == pair[1] else 1.0) * (1.5 if critical else 1.0)
			game.update_weapons(0.01)
			game.update_projectiles(0.2)
			check(is_equal_approx(1000 - target.hp, expected), "Actual weapon damage uses the matching character attribute")
	safe_start()
	for spec in game.Data.EQUIPMENT:
		if spec.stats.values().any(func(value: float) -> bool: return value < 0) or spec.stats.has("incoming_damage"):
			continue
		for i in range(40):
			game.add_item(spec.id, 4)
	for id in game.Data.STAT_CAPS:
		if id == "incoming_damage":
			continue
		check(is_equal_approx(game.player_stat(id), game.Data.STAT_CAPS[id]), "Large builds obey the cap for " + id)
	for attack_type in game.Data.ATTACK_NAMES:
		check(game.damage_scale(attack_type) == 3.0, "Generic and specialized bonuses share the final damage cap")
	check(game.health <= game.max_health(), "Repeated health pickups never heal beyond the cap")
	game.skill_levels = {"power":100, "haste":100, "vigor":100, "recovery":100, "dash":100}
	check(game.damage_scale() == 3 and game.attack_speed() == 2.5 and game.max_health() == 200 and game.player_stat("regen") == 3 and game.player_stat("dash_recovery") == 2, "Skills and equipment obey the same attribute limits")
	safe_start()
	game.add_item("glass_trophy", 3)
	check(is_equal_approx(game.damage_scale(), 1.3) and is_equal_approx(game.player_stat("incoming_damage"), 1.25), "Glass trophy grants both damage and vulnerability")
	game.invulnerable = 0
	game.hurt(10, game.player)
	check(is_equal_approx(game.health, 12.5), "Vulnerability increases actual incoming damage")
	game.state = "inventory"
	game.sell("equipment", 0)
	check(game.damage_scale() == 1 and game.player_stat("incoming_damage") == 1, "Selling a risky item removes its benefit and penalty together")
	for pair in [["overtime", "armor"], ["all_nighter", "health"], ["briefcase", "attack_speed"], ["triple_espresso", "regen"], ["laptop_bag", "move_speed"]]:
		safe_start()
		if pair[1] == "regen":
			game.add_item("coffee", 3)
		var before: float = game.player_stat(pair[1])
		game.add_item(pair[0], 3)
		check(game.player_stat(pair[1]) < before, "Risky equipment applies its advertised drawback")
	safe_start()
	for i in range(30):
		game.add_item("all_nighter", 4)
		game.add_item("briefcase", 4)
		game.add_item("laptop_bag", 4)
		game.add_item("glass_trophy", 4)
	check(game.max_health() == 5 and game.health <= 5 and game.attack_speed() == 0.35 and game.move_speed() == 132 and game.player_stat("incoming_damage") == 2, "Stacked drawbacks respect playable lower bounds and vulnerability cap")
	safe_start()
	for i in range(20):
		game.add_item("crit_lens", 4)
		game.add_item("prism", 4)
	var dummy: Dictionary = game.spawn_enemy(game.player + Vector2(70, 0))
	dummy.hp = 10000
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 98
	game.rng.seed = 98
	var criticals: int = 0
	for i in range(64):
		var critical: bool = expected_rng.randf() < 0.6
		var before: float = dummy.hp
		game.hit_enemy(dummy, 10, dummy.p)
		check(is_equal_approx(before - dummy.hp, 30 if critical else 10), "Critical chance and damage change actual hits")
		criticals += 1 if critical else 0
	check(criticals > 0 and criticals < 64, "Capped critical chance still produces normal and critical hits")
	safe_start()
	for i in range(20):
		game.add_item("feather", 4)
		game.add_item("heart", 4)
	game.speech_time = 999
	expected_rng.seed = 98
	game.rng.seed = 98
	var dodges: int = 0
	for i in range(64):
		var dodge: bool = expected_rng.randf() < 0.5
		var before: float = game.health
		game.invulnerable = 0
		game.hurt(1, game.player)
		check(is_equal_approx(before - game.health, 0 if dodge else 1), "Dodge fully prevents the sampled incoming hit")
		dodges += 1 if dodge else 0
	check(dodges > 0 and dodges < 64, "Dodge cap leaves some attacks unavoidable")
	safe_start()
	for i in range(10):
		game.add_item("fang", 4)
	game.health = 10
	dummy = game.spawn_enemy(game.player + Vector2(70, 0))
	dummy.hp = 1
	game.hit_enemy(dummy, 10000, game.player)
	check(is_equal_approx(game.health, 10.15), "Life steal heals from actual damage without counting overkill")
	var kills_before: int = game.kills
	game.hit_enemy(dummy, 10000, game.player)
	check(game.kills == kills_before and is_equal_approx(game.health, 10.15), "Dead targets cannot repeat rewards or life steal")
	for weapon_id in ["firestaff", "frost", "crossbow", "railgun"]:
		safe_start()
		game.weapons.clear()
		game.add_item(weapon_id)
		game.current_room().rect = game.Data.ARENA
		game.obstacles.clear()
		game.player = Vector2(440, 404)
		var targets: Array[Dictionary] = []
		for p in [Vector2(515, 404), Vector2(560, 404), Vector2(515, 450)]:
			var target: Dictionary = game.spawn_enemy(p)
			target.hp = 1000
			target.age = 2
			targets.append(target)
		game.update_weapons(0.01)
		game.update_projectiles(0.25)
		match weapon_id:
			"firestaff": check(targets.all(func(target: Dictionary) -> bool: return target.hp < 1000), "Explosive fireballs damage nearby enemies")
			"frost":
				check(targets[0].slow_time > 0 and targets[0].slow == 0.55, "Ice projectiles apply a timed slow")
				game.enemies.assign([targets[0]])
				var previous: Vector2 = targets[0].p
				game.update_enemies(0.1)
				check(targets[0].p.distance_to(previous) < targets[0].speed * 0.06, "Timed ice slow reduces real movement")
			"crossbow", "railgun": check(targets[0].hp < 1000 and targets[1].hp < 1000 and targets[2].hp == 1000, "Piercing weapons hit the line without hitting off-axis targets")
	safe_start()
	var categories: Dictionary = {}
	var seen: Dictionary = {}
	for refresh in range(512):
		game.current_room().refreshes = refresh
		game.roll_stock()
		var weapons: int = 0
		var shelf: Dictionary = {}
		for offer in game.stock:
			weapons += 1 if game.Data.item(offer.id).kind == "weapon" else 0
			shelf[offer.id] = true
			seen[offer.id] = true
		categories[weapons] = true
		check(shelf.size() == 4, "Random shelves have four distinct items from the complete catalog")
	check(categories.size() == 5, "Random shelves support zero through four weapons with no fixed slots")
	check(seen.size() == ids.size(), "The full expanded catalog can appear in the shop")
	game.cleared_count = 10
	for floor_number in range(game.Data.FLOOR_COUNT):
		game.floor_index = floor_number
		var scale: float = 1.5 * pow(1.15, floor_number)
		game.current_room().type = "combat"
		check(game.shop_price({"id":"blade", "tier":1}) == ceili(18 * scale), "Room inflation and fifteen percent floor inflation compound")
		game.current_room().type = "shop"
		check(game.shop_price({"id":"blade", "tier":1}) == ceili(18 * scale * 0.85), "Dedicated shop discounts survive floor inflation")
		game.current_room().refreshes = 1
		check(game.refresh_price() == ceili(4 * scale), "Paid rerolls receive the room and floor inflation")
		game.current_room().refreshes = 0
		check(game.refresh_price() == 0, "The first reroll remains free on every floor")
	for key in ["kill", "kill_boss"]:
		var sample: AudioStreamWAV = game.audio.samples[key]
		check(sample.get_length() > 0.1 and sample.get_length() < 0.3, "Kill sounds are short, separate transient samples")
		var peak: int = 0
		for i in range(sample.data.size() / 2):
			peak = maxi(peak, absi(sample.data.decode_s16(i * 2)))
		check(peak > 5000 and peak < 30000 and sample.data.decode_s16(0) == 0 and absi(sample.data.decode_s16(sample.data.size() - 2)) < 20, "Kill samples have a clear transient without clipping or edge clicks")
	check(game.audio.kill_players.size() == 3, "Kill sounds have voices reserved separately from weapon fire")
	check(game.audio.kill_players.all(func(player: AudioStreamPlayer) -> bool: return is_equal_approx(player.volume_db, -6.0)), "Kill playback is six decibels louder than the previous mix")
	var audible_energy: float = 0
	var kill_data: PackedByteArray = game.audio.samples.kill.data
	var count: int = int(game.audio.RATE * 0.05)
	for i in range(count):
		var value: float = float(kill_data.decode_s16(i * 2)) / 32767
		audible_energy += value * value
	check(sqrt(audible_energy / count) > 0.2, "Kill pop retains an audible body after its short transient")
	safe_start()
	game.weapons.clear()
	game.add_item("twins")
	game.current_room().rect = game.Data.ARENA
	game.obstacles.clear()
	game.player = Vector2(440, 404)
	var revolver_target: Dictionary = game.spawn_enemy(Vector2(515, 404))
	revolver_target.age = 2
	revolver_target.hp = 1000
	game.update_weapons(0.01)
	check(game.projectiles.size() == 1 and game.projectiles[0].damage == 22, "The replacement revolver fires one high-damage bullet per attack")
	check(is_equal_approx(game.weapons[0].cooldown, 0.9), "Single revolver uses its own slower firing cadence")
	game.update_projectiles(0.2)
	check(revolver_target.hp < 1000, "Single revolver bullets deal actual ranged damage")
	print("Build attributes, drawbacks, expanded catalog, pricing and kill audio checks complete")

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
	test_compact_room_population()
	test_exploration_minimap()
	test_combat()
	test_enemy_behaviour()
	test_enemy_facing()
	test_destructible_cover()
	test_inventory_and_economy()
	test_full_inventory_auto_merge()
	test_equipment_stacks()
	test_room_progression()
	test_enemy_variety()
	test_distinct_bosses()
	test_dense_boss_barrages()
	test_expanded_campaign()
	test_wilds_chapter()
	test_encounter_modes()
	test_elite_variety_and_summons()
	test_treasure_choices()
	test_npcs()
	test_heide_companion()
	test_new_characters()
	test_room_shops_and_skills()
	test_build_balance()
	test_campaign()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
