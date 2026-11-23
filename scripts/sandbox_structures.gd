extends RefCounted
const Data = preload("res://scripts/sandbox_data.gd")
var game: Node
var walls := PackedByteArray()
var liquid_type := PackedByteArray()
var liquid_amount := PackedByteArray()
var active: Dictionary = {}
var crops: Dictionary = {}
var chests: Dictionary = {}
var door_roots: Array[Vector2i] = []
var house_anchors: Array[Vector2i] = []
var homes: Array[Dictionary] = []
var npcs: Array[Dictionary] = []
var selected_chest := Vector2i(-1, -1)
var selected_npc: String = "guide"
var chest_page: int = 0
var fluid_clock: float = 0
var town_clock: float = 0
var breath: float = 12.0
var environment_hurt: float = 0

func _init(owner: Node) -> void:
	game = owner
	reset()

func reset() -> void:
	walls.resize(Data.WIDTH * Data.HEIGHT)
	walls.fill(0)
	liquid_type.resize(walls.size())
	liquid_type.fill(0)
	liquid_amount.resize(walls.size())
	liquid_amount.fill(0)
	active.clear()
	crops.clear()
	chests.clear()
	door_roots.clear()
	house_anchors.clear()
	homes.clear()
	npcs.clear()
	breath = 12
	fluid_clock = 0
	town_clock = 0
	environment_hurt = 0

func index(c: Vector2i) -> int:
	return c.y * Data.WIDTH + c.x

func wall(c: Vector2i) -> bool:
	return game.world.valid(c) and walls[index(c)] != 0

func fluid(c: Vector2i) -> Vector2i:
	return Vector2i(liquid_type[index(c)], liquid_amount[index(c)]) if game.world.valid(c) else Vector2i.ZERO

func set_fluid(c: Vector2i, type: int, amount: int) -> void:
	if not game.world.valid(c):
		return
	var at: int = index(c)
	liquid_amount[at] = clampi(amount, 0, 8)
	liquid_type[at] = type if amount > 0 else 0
	wake_fluid(c)

func wake_fluid(c: Vector2i) -> void:
	for offset in [Vector2i.ZERO, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if game.world.valid(c + offset):
			active[c + offset] = true

func displace(cells: Array) -> bool:
	# Plan every transfer before changing the world; sealed liquid cannot vanish.
	var planned: Dictionary = {}
	for source in cells:
		var value: Vector2i = fluid(source)
		if value.y == 0:
			continue
		var left: int = value.y
		var queue: Array = [source]
		var seen: Dictionary = {}
		while not queue.is_empty() and seen.size() < 80 and left > 0:
			var c: Vector2i = queue.pop_front()
			if seen.has(c) or not game.world.valid(c) or game.world.solid(c):
				continue
			seen[c] = true
			if not cells.has(c):
				var existing: Vector2i = planned.get(c, fluid(c))
				if existing.x == 0 or existing.x == value.x:
					var amount: int = mini(left, 8 - existing.y)
					if amount > 0:
						planned[c] = Vector2i(value.x, existing.y + amount)
						left -= amount
			if c.distance_squared_to(source) < 16:
				for offset in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
					queue.append(c + offset)
		if left > 0:
			game.notify("液体没有排出的空间。")
			return false
	for c in cells:
		set_fluid(c, 0, 0)
	for c in planned:
		set_fluid(c, planned[c].x, planned[c].y)
	return true

func generate_features(legacy: bool = false) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = game.world.seed_value ^ 763351
	for y in range(80, Data.HEIGHT - 3):
		for x in range(3, Data.WIDTH - 3):
			var c := Vector2i(x, y)
			if legacy and game.world.explored[index(c)] != 0:
				continue
			if game.world.tile(c) == Data.Block.STONE:
				var value: int = posmod(x * 181 + y * 719 + game.world.seed_value, 97)
				if y > 150 and value < 14:
					game.world.set_tile(c, Data.Block.MOLTEN)
				elif y > 135 and value > 91:
					game.world.set_tile(c, Data.Block.STARSHARD)
				elif value < 8:
					game.world.set_tile(c, Data.Block.GOLD)
			elif game.world.tile(c) == Data.Block.AIR and game.world.solid(c + Vector2i.DOWN) and random.randf() < 0.012:
				game.world.set_tile(c, Data.Block.LIFE_CRYSTAL if random.randf() < 0.45 else Data.Block.POT)
	if legacy:
		return
	# A connected underworld corridor gives the final pre-Hardmode battle room.
	for x in range(7, Data.WIDTH - 7):
		for y in range(164, 181):
			game.world.set_tile(Vector2i(x, y), Data.Block.AIR)
		game.world.set_tile(Vector2i(x, 181), Data.Block.OBSIDIAN)
		if x % 47 < 13:
			for y in range(179, 181):
				set_fluid(Vector2i(x, y), 2, 8)
	for x in range(8, Data.WIDTH - 8):
		var ground: int = game.world.surface_at(x)
		if x > 116 and x < 180 and game.world.tile(Vector2i(x, ground)) == Data.Block.GRASS:
			game.world.set_tile(Vector2i(x, ground), Data.Block.JUNGLE_GRASS)
		if x > 362 and x < 433:
			for y in range(ground, ground + 5):
				if game.world.solid(Vector2i(x, y)):
					game.world.set_tile(Vector2i(x, y), Data.Block.CORRUPT_STONE)
		if x % 11 == 0 and game.world.tile(Vector2i(x, ground - 1)) == Data.Block.AIR:
			game.world.set_tile(Vector2i(x, ground - 1), Data.Block.HERB if x % 2 == 0 else Data.Block.MUSHROOM)
	for cx in [45, 153, 512]:
		var ground: int = game.world.surface_at(cx)
		for dx in range(-6, 7):
			for dy in range(-1, 6):
				var c := Vector2i(cx + dx, ground + dy)
				game.world.set_tile(c, Data.Block.STONE if absi(dx) == 6 or dy == 5 else Data.Block.AIR)
				if absi(dx) < 6 and dy > 0 and dy < 5:
					set_fluid(c, 1, 8)
	for pair in [Vector2i(225, 91), Vector2i(461, 122), Vector2i(91, 111)]:
		cabin(pair)
	# Renewable seed sources near the first settlement.
	for dx in [-11, 11]:
		var c := Vector2i(Data.WIDTH / 2 + dx, 58)
		if game.world.tile(c) == Data.Block.AIR:
			game.world.set_tile(c, Data.Block.HERB)

func cabin(at: Vector2i) -> void:
	for dy in range(-6, 1):
		for dx in range(-5, 6):
			var c: Vector2i = at + Vector2i(dx, dy)
			game.world.set_tile(c, Data.Block.PLANK if absi(dx) == 5 or dy in [-6, 0] else Data.Block.AIR)
			walls[index(c)] = 1
	var chest: Vector2i = at + Vector2i(2, -1)
	game.world.set_tile(chest, Data.Block.CHEST)
	game.world.set_tile(at + Vector2i(-2, -1), Data.Block.TORCH)
	chests[chest] = {"coin":25,"potion":3,"life_crystal":1,"arrow":40,"seed":4,"double_jump":1 if at.x == 225 else 0,"boots":1 if at.x != 225 else 0}
	install_door(at + Vector2i(-5, -1))

func install_door(c: Vector2i) -> void:
	game.world.set_tile(c, Data.Block.DOOR)
	game.world.set_tile(c + Vector2i.UP, Data.Block.DOOR)
	if not door_roots.has(c):
		door_roots.append(c)

func door_root(c: Vector2i) -> Vector2i:
	for root in door_roots:
		if root.x == c.x and c.y >= root.y - 1 and c.y <= root.y:
			return root
	return c

func mine_special(c: Vector2i) -> bool:
	var tile: int = game.world.tile(c)
	if tile in [Data.Block.DOOR, Data.Block.DOOR_OPEN]:
		var root: Vector2i = door_root(c)
		game.world.set_tile(root, Data.Block.AIR)
		game.world.set_tile(root + Vector2i.UP, Data.Block.AIR)
		wake_fluid(root)
		wake_fluid(root + Vector2i.UP)
		door_roots.erase(root)
		game.add_item("door", 1)
		return true
	if tile == Data.Block.CHEST:
		chests.erase(c)
	if tile in [Data.Block.HERB, Data.Block.SAPLING, Data.Block.MUSHROOM]:
		return harvest_plant(c)
	if tile == Data.Block.CHAIR:
		house_anchors.erase(c)
	if tile == Data.Block.WOOD:
		game.add_item("acorn", 1)
	if tile == Data.Block.POT:
		game.add_item("coin", game.rng.randi_range(3, 9))
		game.add_item("potion", 1)
	crops.erase(c)
	return false

func harvest_plant(c: Vector2i) -> bool:
	match game.world.tile(c):
		Data.Block.HERB:
			game.add_item("seed", 1)
			if not crops.has(c) or crops[c].ready <= game.elapsed:
				game.add_item("herb", 3)
		Data.Block.SAPLING:
			game.add_item("acorn", 1)
		Data.Block.MUSHROOM:
			game.add_item("mushroom", 1)
		_:
			return false
	crops.erase(c)
	game.world.set_tile(c, Data.Block.AIR)
	wake_fluid(c)
	return true

func can_mine(c: Vector2i) -> bool:
	if game.world.tile(c) != Data.Block.CHEST:
		return true
	for amount in chests.get(c, {}).values():
		if amount > 0:
			return false
	return true

func salvage(c: Vector2i) -> void:
	# Emergency respawn clearance must refund furniture and stored contents too.
	var tile: int = game.world.tile(c)
	if tile == Data.Block.AIR:
		return
	if tile == Data.Block.CHEST:
		for id in chests.get(c, {}):
			game.add_item(id, chests[c][id])
	if mine_special(c):
		return
	var item: String = Data.BLOCKS[tile].item
	if not item.is_empty() and tile != Data.Block.LEAF:
		game.add_item(item, 1)
	game.world.set_tile(c, Data.Block.AIR)
	wake_fluid(c)

func place_special(c: Vector2i, item: String) -> bool:
	if not game.reachable(c) or game.count_item(item) <= 0:
		return false
	if item == "wall":
		if wall(c):
			return false
		walls[index(c)] = 1
		game.add_item(item, -1)
		return true
	if item in ["bucket", "water_bucket", "lava_bucket"]:
		var existing: Vector2i = fluid(c)
		if item == "bucket" and existing.y == 8:
			set_fluid(c, 0, 0)
			game.add_item("water_bucket" if existing.x == 1 else "lava_bucket", 1)
		elif item != "bucket" and existing.y == 0 and not game.world.solid(c):
			set_fluid(c, 1 if item == "water_bucket" else 2, 8)
			game.add_item("bucket", 1)
		else:
			return false
		game.add_item(item, -1)
		return true
	if item == "door":
		if not game.can_place(c, item) or game.world.tile(c + Vector2i.UP) != Data.Block.AIR:
			return false
		var upper := Rect2(Vector2(c + Vector2i.UP) * Data.TILE, Vector2.ONE * Data.TILE)
		if upper.intersects(Rect2(game.player - Vector2(8, 36), Vector2(16, 36))):
			return false
		for actor in game.enemies + npcs:
			if upper.intersects(Rect2(actor.p - Vector2(12, 44), Vector2(24, 44))):
				return false
		if not displace([c, c + Vector2i.UP]):
			return false
		install_door(c)
		game.add_item(item, -1)
		return true
	if item in ["seed", "acorn"]:
		if game.world.tile(c) != Data.Block.AIR or game.world.tile(c + Vector2i.DOWN) not in [Data.Block.DIRT, Data.Block.GRASS, Data.Block.JUNGLE_GRASS]:
			return false
		game.world.set_tile(c, Data.Block.SAPLING if item == "acorn" else Data.Block.HERB)
		crops[c] = {"tree":item == "acorn","ready":game.elapsed + (180 if item == "acorn" else 60)}
		game.add_item(item, -1)
		return true
	return false

func take_wall(c: Vector2i) -> bool:
	if not game.reachable(c) or not wall(c):
		return false
	walls[index(c)] = 0
	game.add_item("wall", 1)
	return true

func flow_step() -> void:
	var cells: Array = active.keys().slice(0, 256)
	for c in cells:
		active.erase(c)
		var value: Vector2i = fluid(c)
		if value.y <= 0 or game.world.solid(c):
			continue
		for offset in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var target: Vector2i = c + offset
			if not game.world.valid(target) or game.world.solid(target):
				continue
			var other: Vector2i = fluid(target)
			if other.y > 0 and other.x != value.x:
				set_fluid(target, 0, 0)
				set_fluid(c, 0, 0)
				game.world.set_tile(target, Data.Block.OBSIDIAN)
				break
			var amount: int = mini(value.y, 8 - other.y) if offset == Vector2i.DOWN else maxi(0, (value.y - other.y) / 2)
			if amount > 0:
				set_fluid(target, value.x, other.y + amount)
				value.y -= amount
				set_fluid(c, value.x, value.y)
			if value.y == 0:
				break

func inspect_house(start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {}
	var fixtures: Dictionary = {}
	var backed: int = 0
	var region: int = Data.WIDTH * Data.HEIGHT
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if seen.has(c):
			continue
		if not game.world.valid(c) or seen.size() > 240:
			return {"valid":false,"reason":"房间未封闭或空间过大"}
		var tile: int = game.world.tile(c)
		if game.world.solid(c) or tile in [Data.Block.DOOR, Data.Block.DOOR_OPEN]:
			fixtures[tile] = c
			continue
		seen[c] = true
		region = mini(region, index(c))
		if not fixtures.has(tile) or index(c) < index(fixtures[tile]):
			fixtures[tile] = c
		if wall(c):
			backed += 1
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not seen.has(c + offset):
				queue.append(c + offset)
	if seen.size() < 24:
		return {"valid":false,"reason":"内部空间不足 24 格"}
	if backed < seen.size():
		return {"valid":false,"reason":"内部需要铺满背景墙"}
	if not fixtures.has(Data.Block.BENCH) or not fixtures.has(Data.Block.CHAIR):
		return {"valid":false,"reason":"缺少工作台或椅子"}
	if not fixtures.has(Data.Block.TORCH) and not fixtures.has(Data.Block.BEACON):
		return {"valid":false,"reason":"缺少火把照明"}
	if not fixtures.has(Data.Block.DOOR) and not fixtures.has(Data.Block.DOOR_OPEN):
		return {"valid":false,"reason":"缺少出入口木门"}
	var chair: Vector2i = fixtures[Data.Block.CHAIR]
	var standing: Array[Vector2] = []
	var nearest := Vector2.INF
	var target: Vector2 = Vector2(chair + Vector2i.DOWN) * Data.TILE + Vector2(12, -0.01)
	for c in seen:
		if not seen.has(c + Vector2i.UP) or not game.world.solid(c + Vector2i.DOWN):
			continue
		var p: Vector2 = Vector2(c + Vector2i.DOWN) * Data.TILE + Vector2(12, -0.01)
		if game.body_free(p, 9, 42):
			standing.append(p)
			if not nearest.is_finite() or p.distance_squared_to(target) < nearest.distance_squared_to(target):
				nearest = p
	if standing.is_empty():
		return {"valid":false,"reason":"住宅需要可站立的地面和两格净空"}
	return {"valid":true,"reason":"住宅合格","anchor":chair,"region":region,"p":nearest,"standing":standing,"cells":seen.size()}

func register_house(c: Vector2i) -> Dictionary:
	var house: Dictionary = inspect_house(c)
	if house.valid and not house_anchors.has(house.anchor):
		house_anchors.append(house.anchor)
	town_clock = 3
	return house

func update_town() -> void:
	homes.clear()
	var occupied: Dictionary = {}
	for anchor in house_anchors:
		var house: Dictionary = inspect_house(anchor)
		if house.valid and not occupied.has(house.region):
			occupied[house.region] = true
			homes.append(house)
	var available: Array[String] = ["guide"]
	if game.adventure.life_upgrades > 0:
		available.append("nurse")
	if game.adventure.stage() >= 1:
		available.append("heide")
	if game.adventure.stage() >= 2:
		available.append("miner")
	npcs.clear()
	for i in range(available.size()):
		if i >= homes.size() and i > 0:
			break
		var p: Vector2 = homes[i].p if i < homes.size() else game.nearby_surface(game.world.spawn + Vector2(144, 0), 12)
		if not p.is_finite():
			p = game.safe_spawn()
		npcs.append({"id":available[i],"p":p,"housed":i < homes.size()})

func interact() -> bool:
	var at: Vector2i = game.cell_at(game.player - Vector2(0, 12))
	var nearest := Vector2i(-1, -1)
	var distance: float = 80
	for dx in range(-3, 4):
		for dy in range(-2, 3):
			var c: Vector2i = at + Vector2i(dx, dy)
			if game.world.tile(c) in [Data.Block.CHEST,Data.Block.DOOR,Data.Block.DOOR_OPEN,Data.Block.BED,Data.Block.HERB]:
				var gap: float = game.cell_center(c).distance_to(game.player - Vector2(0, 12))
				if gap < distance:
					distance = gap
					nearest = c
	if nearest.x >= 0:
		var tile: int = game.world.tile(nearest)
		match tile:
			Data.Block.DOOR, Data.Block.DOOR_OPEN:
				var root: Vector2i = door_root(nearest)
				var body := Rect2(Vector2(root + Vector2i.UP) * Data.TILE, Vector2(24,48))
				if tile == Data.Block.DOOR_OPEN and body.intersects(Rect2(game.player - Vector2(8,36),Vector2(16,36))):
					game.notify("先离开门的位置，再关门。")
				else:
					if tile == Data.Block.DOOR_OPEN:
						for actor in game.enemies + npcs:
							if body.intersects(Rect2(actor.p - Vector2(12,44),Vector2(24,44))):
								game.notify("门口有角色，暂时无法关门。")
								return true
						if not displace([root, root + Vector2i.UP]):
							return true
					for c in [root, root + Vector2i.UP]:
						game.world.set_tile(c, Data.Block.DOOR_OPEN if tile == Data.Block.DOOR else Data.Block.DOOR)
						wake_fluid(c)
			Data.Block.CHEST:
				selected_chest = nearest
				chest_page = 0
				if not chests.has(nearest):
					chests[nearest] = {}
				game.set_state("chest")
			Data.Block.BED:
				var house: Dictionary = register_house(nearest)
				if house.valid:
					var spawn := Vector2.INF
					for p in house.standing:
						if not spawn.is_finite() or p.distance_squared_to(game.cell_center(nearest)) < spawn.distance_squared_to(game.cell_center(nearest)):
							spawn = p
					game.world.spawn = spawn
					game.notify("重生点已设到床边。")
				else:
					game.notify(house.reason)
			Data.Block.HERB:
				if crops.has(nearest) and crops[nearest].ready > game.elapsed:
					game.notify("药草还在生长。")
				else:
					harvest_plant(nearest)
		return true
	for npc in npcs:
		if npc.p.distance_to(game.player) < 72:
			selected_npc = npc.id
			game.set_state("town_npc")
			return true
	return false

func transfer_chest(deposit: bool) -> void:
	if game.state != "chest" or not chests.has(selected_chest):
		return
	var storage: Dictionary = chests[selected_chest]
	var previous_inventory: Dictionary = game.inventory.duplicate(true)
	var previous_storage: Dictionary = storage.duplicate(true)
	if deposit:
		for id in game.inventory:
			var spec: Dictionary = Data.ITEMS[id]
			if id not in ["coin","pickaxe","sword","potion","charm","lantern"] and not spec.has("weapon") and not spec.has("use") and not spec.has("summon") and not spec.has("armor") and not spec.has("accessory") and game.count_item(id) > 0:
				storage[id] = int(storage.get(id,0)) + game.count_item(id)
				game.inventory[id] = 0
	else:
		for id in storage:
			game.add_item(id,storage[id])
		storage.clear()
	if not game.save_world():
		game.inventory = previous_inventory
		chests[selected_chest] = previous_storage
		game.notify("转存未能保存，物品已留在原处。")

func tick(delta: float) -> void:
	fluid_clock += delta
	town_clock += delta
	if fluid_clock >= 0.12:
		fluid_clock = 0
		flow_step()
	if town_clock >= 2:
		town_clock = 0
		update_town()
	for c in crops.keys():
		if crops[c].tree and crops[c].ready <= game.elapsed:
			if grow_tree(c):
				crops.erase(c)
	var head: Vector2i = fluid(game.cell_at(game.player - Vector2(0,29)))
	breath = maxf(0, breath - delta) if head.y > 4 else minf(12,breath + delta * 5)
	environment_hurt = maxf(0, environment_hurt - delta)
	var feet: Vector2i = fluid(game.cell_at(game.player - Vector2(0,8)))
	if environment_hurt <= 0 and (breath <= 0 or feet.x == 2):
		environment_hurt = 1
		game.hurt((4 if game.adventure.has_accessory("lava_charm") else 26) if feet.x == 2 else 10,game.player + Vector2(0,20))

func grow_tree(c: Vector2i) -> bool:
	for y in range(c.y - 9, c.y + 1):
		for x in range(c.x - 3, c.x + 4):
			var at := Vector2i(x, y)
			if not game.world.valid(at) or (at != c and game.world.tile(at) not in [Data.Block.AIR, Data.Block.LEAF]) or wall(at):
				return false
	for y in range(c.y - 6, c.y + 1):
		game.world.set_tile(Vector2i(c.x, y), Data.Block.WOOD)
	for dx in range(-3, 4):
		for dy in range(-3, 2):
			var at: Vector2i = c + Vector2i(dx, dy - 6)
			if dx != 0 and absf(dx / 3.5) + absf(dy / 3.5) < 1.5 and game.world.tile(at) == Data.Block.AIR:
				game.world.set_tile(at, Data.Block.LEAF)
	return true

func save_data() -> Dictionary:
	return {"walls":walls,"types":liquid_type,"amounts":liquid_amount,"crops":crops,"chests":chests,"doors":door_roots,"houses":house_anchors}

func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["walls","types","amounts"]:
		if not value.get(key) is PackedByteArray or value[key].size() != Data.WIDTH * Data.HEIGHT:
			return false
	for i in range(value.walls.size()):
		if value.walls[i] > 1 or value.types[i] > 2 or value.amounts[i] > 8 or (value.types[i] == 0) != (value.amounts[i] == 0):
			return false
	for key in ["doors","houses"]:
		if not value.get(key) is Array:
			return false
		for c in value[key]:
			if not c is Vector2i or not game.world.valid(c) or (key == "doors" and c.y < 1):
				return false
	for key in ["crops","chests"]:
		if not value.get(key) is Dictionary:
			return false
		for c in value[key]:
			if not c is Vector2i or not game.world.valid(c) or not value[key][c] is Dictionary:
				return false
	for content in value.chests.values():
		for id in content:
			if not Data.ITEMS.has(id) or not content[id] is int or content[id] < 0 or content[id] > 9999999:
				return false
	for crop in value.crops.values():
		if not crop.get("tree") is bool or typeof(crop.get("ready")) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(crop.ready)) or crop.ready < 0:
			return false
	return true

func load_data(value: Dictionary) -> void:
	reset()
	walls = value.walls
	liquid_type = value.types
	liquid_amount = value.amounts
	crops = value.crops
	chests = value.chests
	door_roots.assign(value.doors)
	house_anchors.assign(value.houses)
	for y in range(Data.HEIGHT):
		for x in range(Data.WIDTH):
			if liquid_amount[y * Data.WIDTH + x] > 0:
				active[Vector2i(x,y)] = true
	update_town()
