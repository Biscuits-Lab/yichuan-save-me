extends Node2D
## A side-view survival mode with its own simulation, inventory and save slot.
const Data = preload("res://scripts/sandbox_data.gd")
const View = preload("res://scripts/sandbox_view.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
const Audio = preload("res://scripts/audio.gd")
const REACH: float = 132.0
var world := Data.new()
var state: String = "menu"
var player := Vector2.ZERO # Feet position, in world pixels.
var previous_player := Vector2.ZERO
var velocity := Vector2.ZERO
var grounded: bool = false
var facing: float = 1.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var health: float = 100.0
var hurt_time: float = 0.0
var heal_delay: float = 0.0
var sword_time: float = 0.0
var sword_cooldown: float = 0.0
var place_cooldown: float = 0.0
var mining_cell := Vector2i(-1, -1)
var mining_progress: float = 0.0
var left_held: bool = false
var right_held: bool = false
var pointer := Vector2.ZERO
var inventory: Dictionary = {}
var pick_tier: int = 0
var sword_tier: int = 0
var selected: int = 0
var hotbar: Array[String] = Data.HOTBAR.duplicate()
var recipe_category: int = 0
var elapsed: float = 0.0
var visual_clock: float = 0.0
var autosave_time: float = 0.0
var enemy_timer: float = 10.0
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var stats: Dictionary = {}
var completed: bool = false
var save_path: String = "user://sandbox-v1.save"
var save_available: bool = false
var last_saved: String = ""
var save_error: String = ""
var message: String = ""
var message_time: float = 0.0
var camera: Camera2D
var view: Node2D
var sky: Node2D
var ui: Node2D
var font: Font
var bold: Font
var pixel: Font
var hero_atlas: RefCounted
var priest_atlas: RefCounted
var enemy_atlas: RefCounted
var audio: Node
var merchant_present: bool = false
var merchant_info: Dictionary = {}
var merchant_visit: int = 0
var merchant_terrain_revision: int = -1
var merchant_stock: Array[int] = []
var review_completed_visit: int = 0
var review_reward_pending: bool = false
var review_cards: Array[int] = []
var review_matched: Array[bool] = []
var review_open: Array[int] = []
var review_time: float = 0.0
var review_wait: float = 0.0
var review_turns: int = 0
var review_pairs: int = 0
var merchant_position := Vector2.ZERO
var show_fps: bool = false
var last_reveal := Vector2i(-1, -1)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	font = load("res://assets/fonts/NotoSansSC.ttf")
	var heavy := FontVariation.new()
	heavy.base_font = font
	heavy.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):800}
	bold = heavy
	pixel = load("res://assets/fonts/PressStart2P.ttf")
	hero_atlas = Atlas.new(load("res://assets/generated/dungeon/hero.png"), 4, 4, true)
	priest_atlas = Atlas.new(load("res://assets/generated/sandbox/friday-priest.png"), 1, 1)
	enemy_atlas = Atlas.new(load("res://assets/generated/dungeon/enemies.png"), 4, 4)
	audio = Audio.new()
	add_child(audio)
	setup_input()
	pointer = get_viewport().get_mouse_position()
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * 1.2
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	var backdrop := CanvasLayer.new()
	backdrop.layer = -10
	add_child(backdrop)
	sky = View.new()
	sky.game = self
	sky.surface = "sky"
	backdrop.add_child(sky)
	view = View.new()
	view.game = self
	add_child(view)
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	ui = View.new()
	ui.game = self
	ui.surface = "ui"
	overlay.add_child(ui)
	world.generate(20261113)
	player = world.spawn
	previous_player = player
	camera.position = player + Vector2(0, -80)
	rng.randomize()
	save_available = FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	refresh_merchant()
	get_tree().auto_accept_quit = false
	if "--sandbox-play" in OS.get_cmdline_user_args():
		start_world(20261113)

func setup_input() -> void:
	for binding in [{"id":"sandbox_left", "keys":[KEY_A, KEY_LEFT]}, {"id":"sandbox_right", "keys":[KEY_D, KEY_RIGHT]}, {"id":"sandbox_jump", "keys":[KEY_SPACE, KEY_W, KEY_UP]}]:
		if not InputMap.has_action(binding.id):
			InputMap.add_action(binding.id)
			for code in binding.keys:
				var key := InputEventKey.new()
				key.physical_keycode = code
				InputMap.action_add_event(binding.id, key)

func start_world(chosen_seed: int = 0) -> void:
	world.generate(chosen_seed if chosen_seed != 0 else rng.randi_range(1, 99999999))
	inventory = {"pickaxe":1, "sword":1, "dirt":20, "torch":8, "potion":3, "coin":20}
	stats = {"mined":0, "wood":0, "placed":0, "kills":0, "crafted":0}
	pick_tier = 0
	sword_tier = 0
	selected = 0
	hotbar.assign(Data.HOTBAR)
	elapsed = 0.0
	health = 100.0
	completed = false
	merchant_visit = 0
	review_completed_visit = 0
	review_reward_pending = false
	merchant_stock.clear()
	reset_transients()
	player = world.spawn
	previous_player = player
	state = "playing"
	refresh_merchant()
	world.reveal(player)
	view.clear_cache()
	ui.map_dirty = true
	camera.position = player + Vector2(0, -80)
	camera.reset_physics_interpolation()
	notify("来了！先砍树，再在出生地搭一个工作台。")
	audio.sfx("start")
	# A new world only replaces the slot after the in-game confirmation.
	save_world()

func reset_transients() -> void:
	velocity = Vector2.ZERO
	grounded = false
	coyote = 0.0
	jump_buffer = 0.0
	hurt_time = 1.5
	heal_delay = 0.0
	sword_time = 0.0
	sword_cooldown = 0.0
	place_cooldown = 0.0
	left_held = false
	right_held = false
	mining_progress = 0.0
	mining_cell = Vector2i(-1, -1)
	enemies.clear()
	particles.clear()
	texts.clear()
	autosave_time = 0.0
	enemy_timer = 10.0
	last_reveal = Vector2i(-1, -1)
	review_cards.clear()
	review_matched.clear()
	review_open.clear()

func day_fraction() -> float:
	return fposmod(0.32 + elapsed / Data.DAY_SECONDS, 1.0)

func day_number() -> int:
	return floori(0.32 + elapsed / Data.DAY_SECONDS) + 1

func daylight() -> float:
	return clampf(sin((day_fraction() - 0.25) * TAU) * 1.25 + 0.5, 0.08, 1.0)

func is_night() -> bool:
	return day_fraction() < 0.22 or day_fraction() > 0.79

func max_health() -> float:
	return 120.0 if count_item("charm") > 0 else 100.0

func count_item(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, amount: int) -> void:
	inventory[id] = count_item(id) + amount

func held_item() -> String:
	return hotbar[selected]

func equip_item(id: String) -> void:
	if not Data.ITEMS.has(id) or (Data.ITEMS[id].block == 0 and id not in ["pickaxe", "sword", "potion"]):
		return
	var existing: int = hotbar.find(id)
	if existing >= 0:
		selected = existing
	else:
		hotbar[selected] = id
	set_state("playing")

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i((p / Data.TILE).floor())

func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2.ONE * 0.5) * Data.TILE

func mouse_world() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * pointer

func body_free(p: Vector2, half_width: float = 8.0, height: float = 36.0) -> bool:
	var first: Vector2i = cell_at(p + Vector2(-half_width, -height))
	var last: Vector2i = cell_at(p + Vector2(half_width - 0.01, -0.01))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if world.solid(Vector2i(x, y)):
				return false
	return true

func move_body(p: Vector2, motion: Vector2, half_width: float = 8.0, height: float = 36.0) -> Dictionary:
	var result: Vector2 = p
	var hit := Vector2.ZERO
	for axis in range(2):
		var distance: float = motion[axis]
		var steps: int = maxi(1, ceili(absf(distance) / 4.0))
		for n in range(steps):
			var next: Vector2 = result
			next[axis] += distance / steps
			if body_free(next, half_width, height):
				result = next
			else:
				# Binary refinement keeps feet flush with terrain at every framerate.
				var near: Vector2 = result
				var far: Vector2 = next
				for refinement in range(8):
					var middle: Vector2 = (near + far) * 0.5
					if body_free(middle, half_width, height):
						near = middle
					else:
						far = middle
				result = near
				hit[axis] = signf(distance)
				break
	return {"p":result, "hit":hit}

func line_clear(target: Vector2i) -> bool:
	var origin: Vector2 = player - Vector2(0, 20)
	var end: Vector2 = cell_center(target)
	var steps: int = maxi(1, ceili(origin.distance_to(end) / 6.0))
	for n in range(steps):
		var c: Vector2i = cell_at(origin.lerp(end, float(n) / steps))
		if c != target and world.solid(c):
			return false
	return true

func reachable(c: Vector2i) -> bool:
	return world.valid(c) and (player - Vector2(0, 20)).distance_to(cell_center(c)) <= REACH and line_clear(c)

func can_mine(c: Vector2i) -> bool:
	var id: int = world.tile(c)
	return id != Data.Block.AIR and Data.BLOCKS[id].tier <= pick_tier and reachable(c)

func mine(c: Vector2i) -> bool:
	if state != "playing" or not can_mine(c):
		return false
	var id: int = world.tile(c)
	var item: String = Data.BLOCKS[id].item
	if id == Data.Block.LEAF:
		item = ""
	world.set_tile(c, Data.Block.AIR)
	if not item.is_empty():
		add_item(item, 1)
		float_text("+1 " + Data.ITEMS[item].name, cell_center(c), Color(Data.BLOCKS[id].color))
	stats.mined = int(stats.get("mined", 0)) + 1
	if id == Data.Block.WOOD:
		stats.wood = int(stats.get("wood", 0)) + 1
		# Chopping a trunk fells the connected upper trunk and its canopy.
		for y in range(c.y - 1, maxi(1, c.y - 14), -1):
			var trunk := Vector2i(c.x, y)
			if world.tile(trunk) != Data.Block.WOOD:
				break
			world.set_tile(trunk, Data.Block.AIR)
			add_item("wood", 1)
			stats.wood += 1
			for dx in range(-3, 4):
				for dy in range(-3, 2):
					var leaf: Vector2i = trunk + Vector2i(dx, dy)
					if world.tile(leaf) == Data.Block.LEAF:
						world.set_tile(leaf, Data.Block.AIR)
	burst(cell_center(c), Color(Data.BLOCKS[id].color), 7)
	mining_progress = 0.0
	ui.map_dirty = true
	audio.sfx("hit")
	return true

func can_place(c: Vector2i, item: String) -> bool:
	if not Data.ITEMS.has(item) or count_item(item) <= 0 or not reachable(c) or world.tile(c) != Data.Block.AIR:
		return false
	var id: int = Data.ITEMS[item].block
	if id == Data.Block.AIR:
		return false
	if Data.BLOCKS[id].solid:
		var placed := Rect2(Vector2(c) * Data.TILE, Vector2.ONE * Data.TILE)
		if placed.intersects(Rect2(player - Vector2(8, 36), Vector2(16, 36))):
			return false
		if merchant_present and placed.intersects(Rect2(merchant_position - Vector2(10, 52), Vector2(20, 52))):
			return false
		for enemy in enemies:
			if placed.intersects(Rect2(enemy.p - Vector2(12, 24), Vector2(24, 24))):
				return false
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if world.tile(c + offset) != Data.Block.AIR:
			return true
	return false

func place(c: Vector2i, item: String = "") -> bool:
	if item.is_empty():
		item = held_item()
	if state != "playing" or not can_place(c, item):
		return false
	var id: int = Data.ITEMS[item].block
	world.set_tile(c, id)
	add_item(item, -1)
	stats.placed = int(stats.get("placed", 0)) + 1
	burst(cell_center(c), Color(Data.BLOCKS[id].color), 4)
	ui.map_dirty = true
	audio.sfx("block")
	if id == Data.Block.BEACON and c.y <= world.surface_at(c.x) + 2 and not completed:
		completed = true
		save_world()
		set_state("complete")
	return true

func near_station(id: int) -> bool:
	if id == 0:
		return true
	var at: Vector2i = cell_at(player)
	for dx in range(-5, 6):
		for dy in range(-4, 3):
			if world.tile(at + Vector2i(dx, dy)) == id:
				return true
	return false

func craft_reason(index: int) -> String:
	if index < 0 or index >= Data.RECIPES.size():
		return "无效配方"
	var recipe: Dictionary = Data.RECIPES[index]
	if recipe.has("tier"):
		var tier: int = pick_tier if recipe.id.ends_with("pick") else sword_tier
		if tier >= recipe.tier:
			return "已拥有此等级装备"
		if tier < recipe.tier - 1:
			return "先制作铜装备"
	if not near_station(recipe.station):
		return "需要靠近" + Data.BLOCKS[recipe.station].name
	for id in recipe.cost:
		if count_item(id) < recipe.cost[id]:
			return "材料不足"
	return ""

func craft(index: int) -> bool:
	var reason: String = craft_reason(index)
	if state not in ["playing", "inventory"] or not reason.is_empty():
		if not reason.is_empty():
			notify(reason)
		return false
	var recipe: Dictionary = Data.RECIPES[index]
	for id in recipe.cost:
		add_item(id, -recipe.cost[id])
	if recipe.id.ends_with("pick"):
		pick_tier = recipe.tier
	elif recipe.id.ends_with("sword"):
		sword_tier = recipe.tier
	else:
		add_item(recipe.id, recipe.amount)
	stats.crafted = int(stats.get("crafted", 0)) + 1
	notify("制作完成：" + recipe.get("name", Data.ITEMS.get(recipe.id, {}).get("name", recipe.id)) + " ×" + str(recipe.amount))
	audio.sfx("repair")
	return true

func heal() -> bool:
	if state != "playing" or count_item("potion") <= 0 or health >= max_health():
		return false
	add_item("potion", -1)
	health = minf(max_health(), health + 45)
	float_text("+45 生命", player - Vector2(0, 45), Color("93e6ba"))
	audio.sfx("coffee")
	return true

func attack() -> void:
	if state != "playing" or sword_cooldown > 0:
		return
	sword_cooldown = 0.36
	sword_time = 0.24
	audio.sfx("slash")
	var origin: Vector2 = player - Vector2(0, 18)
	for enemy in enemies.duplicate():
		var diff: Vector2 = enemy.p - Vector2(0, 12) - origin
		if diff.length() < 94 and diff.x * facing > -18 and line_clear(cell_at(enemy.p - Vector2(0, 12))):
			enemy.hp -= [14, 24, 36][sword_tier]
			enemy.v = Vector2(facing * 220, -200)
			enemy.flash = 0.18
			burst(enemy.p - Vector2(0, 14), Color("a5e3bb"), 6)
			float_text(str([14, 24, 36][sword_tier]), enemy.p - Vector2(0, 35), Color("f2e3b6"))
			if enemy.hp <= 0:
				enemies.erase(enemy)
				add_item("gel", 2)
				var coins: int = rng.randi_range(3, 7)
				add_item("coin", coins)
				stats.kills = int(stats.get("kills", 0)) + 1
				float_text("凝胶 +2 · 旧银币 +%d" % coins, enemy.p - Vector2(0, 45), Color("e6cc92"))

func hurt(amount: float, source: Vector2) -> void:
	if state != "playing" or hurt_time > 0:
		return
	health = maxf(0, health - amount)
	hurt_time = 1.0
	heal_delay = 9.0
	velocity = Vector2(signf(player.x - source.x) * 180, -190)
	float_text("-%d" % int(amount), player - Vector2(0, 45), Color("f28d99"))
	audio.sfx("hurt")
	if health <= 0:
		set_state("dead")
		audio.sfx("dead")

func nearby_surface(anchor: Vector2, radius: int = 32) -> Vector2:
	var best := Vector2.INF
	var best_score: float = INF
	var center: int = cell_at(anchor).x
	# Compare all candidates by distance to the original surface, so a shaft
	# directly under the anchor cannot win against intact ground beside it.
	for x in range(maxi(1, center - radius), mini(Data.WIDTH - 1, center + radius + 1)):
		for y in range(3, mini(Data.HEIGHT - 2, world.surface_at(x) + 16)):
			var feet := Vector2((x + 0.5) * Data.TILE, y * Data.TILE - 0.01)
			var score: float = feet.distance_squared_to(anchor)
			if score < best_score and world.solid(Vector2i(x, y)) and body_free(feet):
				best = feet
				best_score = score
	return best

func safe_spawn() -> Vector2:
	var safe: Vector2 = nearby_surface(world.spawn)
	if safe.is_finite():
		return safe
	# An extensively excavated or filled spawn still needs a usable return point.
	# Make a small landing pocket and return displaced materials to the backpack.
	var at: Vector2i = cell_at(world.spawn)
	for dx in range(-1, 2):
		for dy in range(-3, 0):
			var c: Vector2i = at + Vector2i(dx, dy)
			var id: int = world.tile(c)
			if id != Data.Block.AIR:
				var item: String = Data.BLOCKS[id].item
				if not item.is_empty() and id != Data.Block.LEAF:
					add_item(item, 1)
				world.set_tile(c, Data.Block.AIR)
	if not world.solid(at):
		var old: int = world.tile(at)
		if old != Data.Block.AIR and not Data.BLOCKS[old].item.is_empty():
			add_item(Data.BLOCKS[old].item, 1)
		world.set_tile(at, Data.Block.DIRT)
	ui.map_dirty = true
	return Vector2((at.x + 0.5) * Data.TILE, at.y * Data.TILE - 0.01)

func respawn() -> void:
	player = safe_spawn()
	previous_player = player
	health = max_health()
	reset_transients()
	state = "playing"
	camera.position = player + Vector2(0, -80)
	camera.reset_physics_interpolation()
	notify("毅川：来了。背包和建造进度都还在。")
	save_world()

func refresh_merchant() -> void:
	var was_present: bool = merchant_present
	merchant_info = Data.merchant_schedule(day_number())
	merchant_present = merchant_info.present
	if merchant_present and (merchant_visit != merchant_info.day or merchant_stock.size() != Data.OFFERS.size()):
		merchant_visit = merchant_info.day
		merchant_stock.clear()
		for offer in Data.OFFERS:
			merchant_stock.append(offer.stock)
	if world.surface.size() == Data.WIDTH and merchant_terrain_revision != world.revision:
		var x: int = Data.WIDTH / 2 - 7
		var anchor := Vector2((x + 0.5) * Data.TILE, world.surface_at(x) * Data.TILE)
		merchant_position = nearby_surface(anchor, 14)
		if not merchant_position.is_finite():
			merchant_position = safe_spawn()
		merchant_terrain_revision = world.revision
	if was_present and not merchant_present and state == "merchant":
		set_state("playing")
		notify("神父：补给先收好，第 %d 天我再来。" % merchant_info.next_day)
	elif merchant_present and not was_present and state == "playing":
		notify("神父：毅川，第 %d 天的补给到了。我在出生地等你。" % merchant_info.day)

func can_trade() -> bool:
	return merchant_present and player.distance_to(merchant_position) < 110 and line_clear(cell_at(merchant_position - Vector2(0, 24)))

func interact() -> void:
	if state != "playing":
		return
	refresh_merchant()
	if can_trade():
		set_state("merchant")
		audio.sfx("select")
	else:
		set_state("inventory")

func buy(index: int) -> bool:
	# Recheck the saved game clock; real dates never affect merchant visits.
	refresh_merchant()
	if state != "merchant" or not can_trade() or index < 0 or index >= Data.OFFERS.size():
		return false
	var offer: Dictionary = Data.OFFERS[index]
	if merchant_stock[index] <= 0 or count_item("coin") < offer.price:
		notify("本次到访已售罄" if merchant_stock[index] <= 0 else "旧银币不足：击败怪物可以获得。")
		return false
	if offer.get("unique", false) and count_item(offer.id) > 0:
		notify("背包里已经有这件物品。")
		return false
	var before: Dictionary = inventory.duplicate()
	var stock_before: int = merchant_stock[index]
	add_item("coin", -offer.price)
	add_item(offer.id, offer.amount)
	merchant_stock[index] -= 1
	if not save_world():
		inventory = before
		merchant_stock[index] = stock_before
		return false
	notify(Data.PRIEST.thanks)
	audio.sfx("coffee")
	return true

func start_review() -> bool:
	refresh_merchant()
	if state not in ["merchant", "review_failed"] or not can_trade():
		return false
	if review_reward_pending:
		set_state("review_reward")
		return true
	if review_completed_visit == merchant_visit:
		notify("神父：这次 Review 已通过，下次到访再来。")
		return false
	review_cards.clear()
	for pair in range(Data.REVIEW_PAIRS.size()):
		review_cards.append(pair)
		review_cards.append(pair)
	for index in range(review_cards.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var saved: int = review_cards[index]
		review_cards[index] = review_cards[other]
		review_cards[other] = saved
	review_matched.resize(review_cards.size())
	review_matched.fill(false)
	review_open.clear()
	review_time = Data.REVIEW_SECONDS
	review_wait = 0.0
	review_turns = 0
	review_pairs = 0
	message_time = 0.0
	set_state("review")
	return true

func flip_review(index: int) -> bool:
	if state != "review" or index < 0 or index >= review_cards.size() or review_wait > 0 or review_matched[index] or review_open.has(index):
		return false
	review_open.append(index)
	audio.sfx("select")
	if review_open.size() < 2:
		return true
	review_turns += 1
	var first: int = review_open[0]
	var second: int = review_open[1]
	if review_cards[first] == review_cards[second]:
		review_matched[first] = true
		review_matched[second] = true
		review_open.clear()
		review_pairs += 1
		audio.sfx("coffee")
		if review_pairs == Data.REVIEW_PAIRS.size():
			review_completed_visit = merchant_visit
			review_reward_pending = true
			set_state("review_reward")
			save_world()
		elif review_turns >= Data.REVIEW_MAX_TURNS:
			set_state("review_failed")
	else:
		review_wait = 0.7
	return true

func update_review(delta: float) -> void:
	if state != "review":
		return
	review_time = maxf(0, review_time - delta)
	if review_time <= 0:
		set_state("review_failed")
		return
	if review_wait > 0:
		review_wait = maxf(0, review_wait - delta)
		if review_wait <= 0:
			review_open.clear()
			if review_turns >= Data.REVIEW_MAX_TURNS:
				set_state("review_failed")

func claim_review_reward(index: int) -> bool:
	if state != "review_reward" or not review_reward_pending or index < 0 or index >= Data.OFFERS.size():
		return false
	var offer: Dictionary = Data.OFFERS[index]
	if offer.get("unique", false) and count_item(offer.id) > 0:
		notify("这件物品已经有了，选一件其他的吧。")
		return false
	var before: Dictionary = inventory.duplicate()
	add_item(offer.id, 1)
	review_reward_pending = false
	if not save_world():
		inventory = before
		review_reward_pending = true
		return false
	set_state("merchant")
	notify("神父：Code Review 通过！%s拿好，下次别漏写测试。" % Data.ITEMS[offer.id].name)
	audio.sfx("repair")
	return true

func spawn_enemy() -> void:
	if enemies.size() >= 10:
		return
	var direction: int = -1 if rng.randf() < 0.5 else 1
	var x: int = clampi(cell_at(player).x + direction * rng.randi_range(19, 27), 2, Data.WIDTH - 3)
	var underground: bool = cell_at(player).y > world.surface_at(x) + 12
	var search_y: int = cell_at(player).y - 10 if underground else world.surface_at(x) - 8
	for y in range(maxi(4, search_y), mini(Data.HEIGHT - 3, search_y + 30)):
		var p := Vector2((x + 0.5) * Data.TILE, y * Data.TILE - 0.01)
		if body_free(p, 12, 24) and world.solid(Vector2i(x, y)):
			var dark: bool = is_night() or underground
			enemies.append({"p":p, "previous":p, "v":Vector2.ZERO, "hp":60 if dark else 35, "max_hp":60 if dark else 35, "jump":rng.randf_range(0.1, 0.7), "flash":0.0, "dark":dark})
			return

func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		enemy.previous = enemy.p
		if enemy.p.distance_to(player) > 1500:
			enemies.erase(enemy)
			continue
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.jump -= delta
		var on_floor: bool = not body_free(enemy.p + Vector2(0, 1.0), 12, 24)
		if on_floor and enemy.jump <= 0:
			enemy.v = Vector2(signf(player.x - enemy.p.x) * (115 if enemy.dark else 85), -350)
			enemy.jump = rng.randf_range(0.7, 1.2)
		enemy.v.y = minf(800, enemy.v.y + 1050 * delta)
		var result: Dictionary = move_body(enemy.p, enemy.v * delta, 12, 24)
		enemy.p = result.p
		if result.hit.x != 0:
			enemy.v.x = 0
		if result.hit.y != 0:
			enemy.v.y = 0
		if absf(enemy.p.x - player.x) < 25 and absf(enemy.p.y - player.y) < 35:
			hurt(16 if enemy.dark else 10, enemy.p)

func _process(delta: float) -> void:
	visual_clock += delta
	update_review(delta)
	message_time = maxf(0, message_time - delta)
	view.queue_redraw()
	sky.queue_redraw()
	ui.queue_redraw()

func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	elapsed += delta
	if day_number() != merchant_info.get("day", 0) or (merchant_present and merchant_terrain_revision != world.revision):
		refresh_merchant()
	autosave_time += delta
	previous_player = player
	hurt_time = maxf(0, hurt_time - delta)
	heal_delay = maxf(0, heal_delay - delta)
	sword_time = maxf(0, sword_time - delta)
	sword_cooldown = maxf(0, sword_cooldown - delta)
	place_cooldown = maxf(0, place_cooldown - delta)
	jump_buffer = maxf(0, jump_buffer - delta)
	coyote = 0.12 if grounded else maxf(0, coyote - delta)
	var horizontal: float = Input.get_axis("sandbox_left", "sandbox_right")
	var speed: float = 200.0
	velocity.x = move_toward(velocity.x, horizontal * speed, (1900.0 if grounded else 1000.0) * delta)
	if horizontal != 0:
		facing = signf(horizontal)
	if Input.is_action_just_pressed("sandbox_jump"):
		jump_buffer = 0.14
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -490.0
		jump_buffer = 0.0
		coyote = 0.0
		grounded = false
		audio.sfx("jump")
	if not Input.is_action_pressed("sandbox_jump") and velocity.y < -200:
		velocity.y = move_toward(velocity.y, -200.0, 1900.0 * delta)
	velocity.y = minf(900, velocity.y + 1350 * delta)
	var falling_speed: float = velocity.y
	var motion: Dictionary = move_body(player, velocity * delta)
	player = motion.p
	grounded = motion.hit.y > 0
	if motion.hit.x != 0:
		velocity.x = 0
	if motion.hit.y != 0:
		velocity.y = 0
	if grounded and falling_speed > 700:
		hurt((falling_speed - 660) * 0.12, player + Vector2(0, 10))
	if heal_delay <= 0:
		health = minf(max_health(), health + delta * (2.0 if near_station(Data.Block.BENCH) else 0.35))
	update_tools(delta)
	if state != "playing":
		return
	enemy_timer -= delta
	if enemy_timer <= 0:
		enemy_timer = 6.0 if is_night() else 12.0
		spawn_enemy()
	update_enemies(delta)
	for particle in particles.duplicate():
		particle.life -= delta
		particle.p += particle.v * delta
		particle.v.y += 500 * delta
		if particle.life <= 0:
			particles.erase(particle)
	for entry in texts.duplicate():
		entry.life -= delta
		entry.p.y -= 24 * delta
		if entry.life <= 0:
			texts.erase(entry)
	var reveal_cell: Vector2i = cell_at(player)
	if reveal_cell != last_reveal:
		last_reveal = reveal_cell
		if world.reveal(player):
			ui.map_dirty = true
	var target: Vector2 = player + Vector2(velocity.x * 0.22, -80)
	camera.position = camera.position.lerp(target, 1.0 - exp(-5.0 * delta))
	camera.position.x = clampf(camera.position.x, 540, Data.WIDTH * Data.TILE - 540)
	camera.position.y = clampf(camera.position.y, 300, Data.HEIGHT * Data.TILE - 300)
	if autosave_time >= 30:
		autosave_time = 0.0
		save_world()

func update_tools(delta: float) -> void:
	var target: Vector2i = cell_at(mouse_world())
	if left_held and not ui.blocks_world(pointer):
		if held_item() == "sword":
			attack()
		elif held_item() == "pickaxe" and can_mine(target):
			if mining_cell != target:
				mining_cell = target
				mining_progress = 0.0
			var hardness: float = Data.BLOCKS[world.tile(target)].hardness
			mining_progress += delta * [1.0, 1.65, 2.4][pick_tier] / maxf(0.05, hardness)
			if mining_progress >= 1.0:
				mine(target)
		else:
			mining_progress = 0.0
	else:
		mining_progress = 0.0
	if right_held and place_cooldown <= 0 and not ui.blocks_world(pointer):
		if place(target):
			place_cooldown = 0.15

func burst(p: Vector2, color: Color, amount: int) -> void:
	for n in range(amount):
		particles.append({"p":p, "v":Vector2(rng.randf_range(-90, 90), rng.randf_range(-130, -35)), "life":rng.randf_range(0.2, 0.5), "color":color})

func float_text(value: String, p: Vector2, color: Color) -> void:
	texts.append({"text":value, "p":p, "life":1.2, "color":color})

func notify(value: String) -> void:
	message = value
	message_time = 4.0

func set_state(value: String) -> void:
	state = value
	left_held = false
	right_held = false
	mining_progress = 0.0
	previous_player = player

func objective() -> Dictionary:
	if completed:
		return {"title":"这里，就是新家", "text":"继续建造、探索；每 5 个游戏日找神父交易。"}
	if int(stats.get("wood", 0)) < 8 and count_item("bench") == 0 and not near_station(Data.Block.BENCH):
		return {"title":"01 / 从一棵树开始", "text":"选中 1 号镐，长按左键砍树。\n收集 8 原木，按 Tab 制作工作台。"}
	if pick_tier == 0:
		return {"title":"02 / 走进地下", "text":"右键放工作台、熔炉。向右寻找洞口。\n采铜矿与煤炭，熔炼 5 铜锭升级镐。"}
	if pick_tier == 1:
		return {"title":"03 / 更深的矿脉", "text":"铜镐可以开采铁矿。\n熔炼 6 铁锭，在工作台旁制作铁镐。"}
	return {"title":"04 / 点亮归途", "text":"寻找深处的大地之心与辉光水晶。\n制作归途信标，放在地表。"}

func save_world() -> bool:
	if inventory.is_empty():
		return false
	var data: Dictionary = {"version":1, "seed":world.seed_value, "tiles":world.tiles, "explored":world.explored, "surface":world.surface, "spawn":world.spawn, "heart":world.heart_cell, "inventory":inventory, "hotbar":hotbar, "pick":pick_tier, "sword":sword_tier, "elapsed":elapsed, "player":player, "health":health, "selected":selected, "stats":stats, "completed":completed, "merchant_visit":merchant_visit, "merchant_stock":merchant_stock, "review_completed_visit":review_completed_visit, "review_reward_pending":review_reward_pending}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return failed_save("无法写入存档")
	file.store_var(data)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return failed_save("存档写入失败")
	if FileAccess.file_exists(save_path) and not read_save(save_path).is_empty():
		var backup_error: Error = DirAccess.copy_absolute(save_path, save_path + ".bak")
		if backup_error != OK:
			return failed_save("无法备份旧存档")
	var error: Error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error != OK:
		return failed_save("无法替换存档")
	save_available = true
	save_error = ""
	last_saved = Time.get_time_string_from_system().left(5)
	return true

func failed_save(reason: String) -> bool:
	save_error = reason
	notify(reason + "，请检查存档目录。")
	return false

func read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4000000:
		return {}
	var value: Variant = file.get_var(false)
	file.close()
	if not value is Dictionary:
		return {}
	var required: Dictionary = {"tiles":TYPE_PACKED_BYTE_ARRAY, "explored":TYPE_PACKED_BYTE_ARRAY, "surface":TYPE_PACKED_INT32_ARRAY, "spawn":TYPE_VECTOR2, "heart":TYPE_VECTOR2I, "player":TYPE_VECTOR2, "inventory":TYPE_DICTIONARY, "stats":TYPE_DICTIONARY, "merchant_stock":TYPE_ARRAY}
	if value.get("version", 0) != 1:
		return {}
	for key in required:
		if not value.has(key) or typeof(value[key]) != required[key]:
			return {}
	if value.tiles.size() != Data.WIDTH * Data.HEIGHT or value.explored.size() != Data.WIDTH * Data.HEIGHT or value.surface.size() != Data.WIDTH:
		return {}
	for id in value.tiles:
		if id >= Data.BLOCKS.size():
			return {}
	for ground in value.surface:
		if ground < 10 or ground >= Data.HEIGHT - 3:
			return {}
	for id in value.inventory:
		if not Data.ITEMS.has(id) or not value.inventory[id] is int or value.inventory[id] < 0 or value.inventory[id] > 100000000:
			return {}
	var saved_bar: Variant = value.get("hotbar", Data.HOTBAR)
	if not saved_bar is Array or saved_bar.size() != Data.HOTBAR.size():
		return {}
	for item in saved_bar:
		if not item is String or not Data.ITEMS.has(item) or (Data.ITEMS[item].block == 0 and item not in ["pickaxe", "sword", "potion"]):
			return {}
	for key in ["pick", "sword", "seed", "selected"]:
		if not value.get(key) is int:
			return {}
	if value.pick < 0 or value.pick > 2 or value.sword < 0 or value.sword > 2:
		return {}
	for key in ["health", "elapsed"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])) or value[key] < 0:
			return {}
	if not value.player.is_finite() or not value.spawn.is_finite() or not world.valid(cell_at(value.spawn)) or not world.valid(value.heart):
		return {}
	if not value.get("completed", false) is bool or not value.get("merchant_visit", 0) is int:
		return {}
	var visit: int = value.get("merchant_visit", 0)
	if visit < 0 or visit % Data.MERCHANT_INTERVAL != 0 or visit > floori(0.32 + float(value.elapsed) / Data.DAY_SECONDS) + 1:
		return {}
	if not value.get("review_completed_visit", 0) is int or not value.get("review_reward_pending", false) is bool:
		return {}
	var reviewed: int = value.get("review_completed_visit", 0)
	if reviewed < 0 or reviewed % Data.MERCHANT_INTERVAL != 0 or reviewed > visit or (value.get("review_reward_pending", false) and reviewed == 0):
		return {}
	for key in value.stats:
		if key not in ["wood", "mined", "placed", "kills", "crafted"] or not value.stats[key] is int or value.stats[key] < 0:
			return {}
	for flag in value.explored:
		if flag > 1:
			return {}
	if value.merchant_stock.size() not in [0, Data.OFFERS.size()]:
		return {}
	for index in range(value.merchant_stock.size()):
		var stock: Variant = value.merchant_stock[index]
		if not stock is int or stock < 0 or stock > Data.OFFERS[index].stock:
			return {}
	return value

func load_world() -> bool:
	var data: Dictionary = read_save(save_path)
	var recovered: bool = false
	if data.is_empty():
		data = read_save(save_path + ".bak")
		recovered = not data.is_empty()
	if data.is_empty():
		notify("未找到有效存档。可以创建一个新世界。")
		return false
	world.seed_value = data.seed
	world.tiles = data.tiles
	world.explored = data.explored
	world.surface = data.surface
	world.spawn = data.spawn
	world.heart_cell = data.heart
	world.revision += 1
	world.torch_cells.clear()
	for y in range(Data.HEIGHT):
		for x in range(Data.WIDTH):
			if world.tile(Vector2i(x, y)) in [Data.Block.TORCH, Data.Block.BEACON]:
				world.torch_cells[Vector2i(x, y)] = true
	inventory = data.inventory
	pick_tier = data.pick
	sword_tier = data.sword
	elapsed = data.elapsed
	player = data.player
	health = clampf(float(data.health), 1, max_health())
	selected = clampi(data.selected, 0, Data.HOTBAR.size() - 1)
	hotbar.assign(data.get("hotbar", Data.HOTBAR))
	stats = data.stats
	completed = data.get("completed", false)
	# Earlier v1 saves used a real-world date; their world and items remain valid.
	merchant_visit = data.get("merchant_visit", 0)
	merchant_stock.assign(data.merchant_stock)
	review_completed_visit = data.get("review_completed_visit", 0)
	review_reward_pending = data.get("review_reward_pending", false)
	reset_transients()
	if data.health <= 0:
		health = max_health()
		player = safe_spawn()
	elif not body_free(player) or not world.valid(cell_at(player)):
		player = safe_spawn()
	previous_player = player
	state = "playing"
	last_saved = ""
	save_available = true
	refresh_merchant()
	view.clear_cache()
	ui.map_dirty = true
	camera.position = player + Vector2(0, -80)
	camera.reset_physics_interpolation()
	notify("已从备份恢复世界。" if recovered else "欢迎回来，你的世界还在。")
	return true

func leave_mode() -> void:
	if not inventory.is_empty() and not save_world():
		return
	get_tree().auto_accept_quit = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if inventory.is_empty() or save_world():
			get_tree().quit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and state == "playing":
		set_state("paused")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = event.position
		return
	if event is InputEventMouseButton:
		pointer = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and ui.click(pointer):
				return
			left_held = event.pressed and state == "playing"
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			right_held = event.pressed and state == "playing"
		elif event.pressed and state == "playing" and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			selected = posmod(selected + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), Data.HOTBAR.size())
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.keycode
	if code == KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif code == KEY_F3:
		show_fps = not show_fps
	elif code == KEY_F5 and state not in ["menu", "confirm"]:
		if save_world():
			notify("世界已保存。")
	elif code == KEY_ESCAPE:
		match state:
			"playing": set_state("paused")
			"paused", "inventory", "merchant", "map", "guide", "complete", "recall": set_state("playing")
			"confirm": set_state("menu")
			"review", "review_failed", "review_reward": set_state("merchant")
			"menu": leave_mode()
	elif state == "playing":
		if code in [KEY_TAB, KEY_I]:
			set_state("inventory")
		elif code == KEY_E:
			interact()
		elif code == KEY_M:
			set_state("map")
		elif code == KEY_F1:
			set_state("guide")
		elif code == KEY_H:
			heal()
		elif code == KEY_J:
			attack()
		elif code == KEY_R:
			set_state("recall")
		elif code >= KEY_1 and code <= KEY_9:
			selected = code - KEY_1
		elif code == KEY_0:
			selected = 9
	elif state == "inventory":
		if code in [KEY_TAB, KEY_I, KEY_E]:
			set_state("playing")
		elif code >= KEY_1 and code <= KEY_3:
			recipe_category = code - KEY_1
	elif state in ["merchant", "map", "guide"] and code in [KEY_E, KEY_M, KEY_F1]:
		set_state("playing")
	elif state == "dead" and code in [KEY_ENTER, KEY_R]:
		respawn()
	elif state == "menu" and code == KEY_ENTER:
		if save_available:
			load_world()
		else:
			start_world()
