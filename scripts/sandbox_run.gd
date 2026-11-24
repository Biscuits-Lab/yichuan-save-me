extends Node2D
## A side-view survival mode with its own simulation, inventory and save slot.
const Data = preload("res://scripts/sandbox_data.gd")
const View = preload("res://scripts/sandbox_view.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
const Catalog = preload("res://scripts/sandbox_catalog.gd")
const Adventure = preload("res://scripts/sandbox_adventure.gd")
const Fault = preload("res://scripts/sandbox_fault.gd")
const Audio = preload("res://scripts/audio.gd")
const Gamepad = preload("res://scripts/gamepad.gd")
const REACH: float = 132.0
var pad := Gamepad.new()
var pad_aim := Vector2.ZERO
var pad_jump_blocked: bool = false
var pad_use_blocked: bool = false
var pad_place_blocked: bool = false
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
var window_focused: bool = true
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
var adventure: RefCounted
var fault: RefCounted
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
	adventure = Adventure.new(self)
	fault = Fault.new(self)
	audio = Audio.new()
	add_child(audio)
	add_child(pad)
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
	for binding in [{"id":"sandbox_left", "keys":[KEY_A, KEY_LEFT]}, {"id":"sandbox_right", "keys":[KEY_D, KEY_RIGHT]}, {"id":"sandbox_jump", "keys":[KEY_SPACE, KEY_W, KEY_UP]}, {"id":"sandbox_down", "keys":[KEY_S,KEY_DOWN]}]:
		if not InputMap.has_action(binding.id):
			InputMap.add_action(binding.id)
			for code in binding.keys:
				var key := InputEventKey.new()
				key.physical_keycode = code
				InputMap.action_add_event(binding.id, key)
	for action in ["sandbox_left", "sandbox_right", "sandbox_down"]:
		InputMap.action_set_deadzone(action, 0.26)
	pad.bind_axis("sandbox_left", JOY_AXIS_LEFT_X, -1.0)
	pad.bind_axis("sandbox_right", JOY_AXIS_LEFT_X, 1.0)
	pad.bind_axis("sandbox_climb_up", JOY_AXIS_LEFT_Y, -1.0)
	pad.bind_axis("sandbox_down", JOY_AXIS_LEFT_Y, 1.0)
	pad.bind_button("sandbox_left", JOY_BUTTON_DPAD_LEFT)
	pad.bind_button("sandbox_right", JOY_BUTTON_DPAD_RIGHT)
	pad.bind_button("sandbox_jump", JOY_BUTTON_A)
	pad.bind_axis("sandbox_use", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	pad.bind_axis("sandbox_place", JOY_AXIS_TRIGGER_LEFT, 1.0)

func start_world(chosen_seed: int = 0) -> void:
	world.generate(chosen_seed if chosen_seed != 0 else rng.randi_range(1, 99999999))
	adventure.reset()
	fault.reset()
	adventure.structures.generate_features()
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
	pad.stop_rumble()
	pad_aim = Vector2.ZERO
	block_held_triggers()
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
	if adventure:
		adventure.reset_transients()
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
	return (120.0 if count_item("charm") > 0 else 100.0) + (adventure.life_upgrades * 20 + adventure.fruit_upgrades * 5 if adventure else 0)

func count_item(id: String) -> int:
	return int(inventory.get(id, 0))

func add_item(id: String, amount: int) -> void:
	inventory[id] = count_item(id) + amount

func held_item() -> String:
	return hotbar[selected]

func equip_item(id: String) -> void:
	if not Data.ITEMS.has(id):
		return
	if Data.ITEMS[id].has("armor") or Data.ITEMS[id].has("accessory"):
		adventure.equip(id)
		return
	if not Data.equippable(id):
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
	if pad.active:
		var offset: Vector2 = Vector2(facing * 54.0, 0.0)
		if not pad_aim.is_zero_approx():
			var max_distance: float = 305.0 if held_item() == "fishing_rod" else REACH - 18.0
			offset = pad_aim.normalized() * lerpf(22.0, max_distance, pad_aim.length())
		return player - Vector2(0, 20) + offset
	return get_viewport().get_canvas_transform().affine_inverse() * pointer

func update_pad_aim() -> void:
	if not pad.active:
		return
	var stick := Vector2(Input.get_joy_axis(pad.device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad.device, JOY_AXIS_RIGHT_Y))
	if stick.length() >= 0.24:
		var strength: float = maxf(0.01, inverse_lerp(0.24, 1.0, minf(1.0, stick.length())))
		pad_aim = stick.normalized() * strength

func block_held_triggers() -> void:
	pad_use_blocked = Input.is_action_pressed("sandbox_use")
	pad_place_blocked = Input.is_action_pressed("sandbox_place")

func jump_held() -> bool:
	return Input.is_action_pressed("sandbox_jump") and (not pad.active or not pad_jump_blocked)

func jump_pressed() -> bool:
	return Input.is_action_just_pressed("sandbox_jump") and (not pad.active or not pad_jump_blocked)

func body_free(p: Vector2, half_width: float = 8.0, height: float = 36.0, ignore_platforms: bool = false) -> bool:
	var first: Vector2i = cell_at(p + Vector2(-half_width, -height))
	var last: Vector2i = cell_at(p + Vector2(half_width - 0.01, -0.01))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if ignore_platforms and world.tile(Vector2i(x,y)) == Data.Block.PLATFORM:
				continue
			if world.solid(Vector2i(x, y)):
				return false
	return true

func motion_free(next: Vector2, previous: Vector2, axis: int, half_width: float, height: float, drop_platforms: bool) -> bool:
	if not body_free(next,half_width,height,true):
		return false
	if axis == 1 and next.y > previous.y and not drop_platforms:
		var y: int = floori((next.y - 0.01) / Data.TILE)
		for x in range(floori((next.x - half_width) / Data.TILE),floori((next.x + half_width - 0.01) / Data.TILE) + 1):
			if world.tile(Vector2i(x,y)) == Data.Block.PLATFORM and previous.y <= y * Data.TILE + 0.02 and next.y > y * Data.TILE:
				return false
	return true

func move_body(p: Vector2, motion: Vector2, half_width: float = 8.0, height: float = 36.0, drop_platforms: bool = false) -> Dictionary:
	var result: Vector2 = p
	var hit := Vector2.ZERO
	for axis in range(2):
		var distance: float = motion[axis]
		var steps: int = maxi(1, ceili(absf(distance) / 4.0))
		for n in range(steps):
			var next: Vector2 = result
			next[axis] += distance / steps
			if motion_free(next,result,axis,half_width,height,drop_platforms):
				result = next
			else:
				# Binary refinement keeps feet flush with terrain at every framerate.
				var near: Vector2 = result
				var far: Vector2 = next
				for refinement in range(8):
					var middle: Vector2 = (near + far) * 0.5
					if motion_free(middle,result,axis,half_width,height,drop_platforms):
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
		if c != target and world.solid(c) and world.tile(c) != Data.Block.PLATFORM:
			return false
	return true

func reachable(c: Vector2i) -> bool:
	return world.valid(c) and (player - Vector2(0, 20)).distance_to(cell_center(c)) <= REACH and line_clear(c)

func can_mine(c: Vector2i) -> bool:
	var id: int = world.tile(c)
	return id != Data.Block.AIR and Data.BLOCKS[id].tier <= pick_tier and reachable(c) and adventure.structures.can_mine(c)

func mine(c: Vector2i) -> bool:
	if state != "playing" or not can_mine(c):
		return false
	var id: int = world.tile(c)
	if adventure.structures.mine_special(c):
		return true
	var item: String = Data.BLOCKS[id].item
	if id == Data.Block.LEAF:
		item = ""
	world.set_tile(c, Data.Block.AIR)
	adventure.structures.wake_fluid(c)
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
	audio.sfx("hit")
	return true

func can_place(c: Vector2i, item: String) -> bool:
	if not Data.ITEMS.has(item) or count_item(item) <= 0 or not reachable(c) or world.tile(c) not in [Data.Block.AIR,Data.Block.HERB,Data.Block.MUSHROOM,Data.Block.SAPLING]:
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
		for npc in adventure.structures.npcs:
			if placed.intersects(Rect2(npc.p - Vector2(9, 42), Vector2(18, 42))):
				return false
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if world.tile(c + offset) != Data.Block.AIR:
			return true
	return false

func place(c: Vector2i, item: String = "") -> bool:
	if item.is_empty():
		item = held_item()
	if state == "playing" and item in ["wall","door","bucket","water_bucket","lava_bucket","seed","acorn"]:
		return adventure.structures.place_special(c,item)
	if state != "playing" or not can_place(c, item):
		return false
	var id: int = Data.ITEMS[item].block
	var previous: int = world.tile(c)
	if Data.BLOCKS[id].solid and not adventure.structures.displace([c]):
		return false
	if previous in [Data.Block.HERB,Data.Block.MUSHROOM,Data.Block.SAPLING]:
		adventure.structures.harvest_plant(c)
	world.set_tile(c, id)
	adventure.structures.active[c] = true
	if id == Data.Block.CHAIR and not adventure.structures.house_anchors.has(c):
		adventure.structures.house_anchors.append(c)
	add_item(item, -1)
	stats.placed = int(stats.get("placed", 0)) + 1
	burst(cell_center(c), Color(Data.BLOCKS[id].color), 4)
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
	if recipe.get("stage",0) > adventure.stage():
		return "需要推进 Boss 成长"
	if recipe.has("tier"):
		var tier: int = pick_tier if recipe.id.ends_with("pick") else sword_tier
		if tier >= recipe.tier:
			return "已拥有此等级装备"
		if tier < recipe.tier - 1:
			return "先制作上一级装备"
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
	if state != "playing" or health >= max_health():
		return false
	if adventure.heal_cooldown > 0:
		notify("治疗药水冷却中：%d 秒" % ceili(adventure.heal_cooldown))
		return false
	if count_item("greater_potion") > 0:
		return adventure.use_item("greater_potion")
	if count_item("potion") <= 0:
		return false
	add_item("potion", -1)
	health = minf(max_health(), health + 45)
	adventure.heal_cooldown = 45
	float_text("+45 生命", player - Vector2(0, 45), Color("93e6ba"))
	audio.sfx("coffee")
	return true

func attack() -> void:
	if state != "playing" or sword_cooldown > 0:
		return
	var spec: Dictionary = Catalog.WEAPONS.get(held_item(),{})
	if spec.get("type","") != "melee":
		spec = {"damage":[14,24,36][sword_tier],"reach":94,"cooldown":0.36}
	sword_cooldown = spec.cooldown
	sword_time = 0.24
	audio.sfx("slash")
	var origin: Vector2 = player - Vector2(0, 18)
	for enemy in enemies.duplicate():
		var diff: Vector2 = enemy.p - Vector2(0, 12) - origin
		if diff.length() < spec.reach and diff.x * facing > -18 and line_clear(cell_at(enemy.p - Vector2(0, 12))):
			adventure.damage_enemy(enemy,spec.damage,player)
			if state != "playing":
				return

func hurt(amount: float, source: Vector2) -> void:
	if state != "playing" or hurt_time > 0:
		return
	amount = maxf(1,amount - adventure.defense() * 0.5)
	health = maxf(0, health - amount)
	hurt_time = 1.0
	heal_delay = 9.0
	velocity = Vector2(signf(player.x - source.x) * 180, -190)
	float_text("-%d" % int(amount), player - Vector2(0, 45), Color("f28d99"))
	audio.sfx("hurt")
	if health <= 0:
		set_state("dead")
		fault.record_death()
		audio.sfx("dead")
		pad.pulse("death")
		save_world()
	else:
		pad.pulse("hurt", clampf(0.45 + amount / max_health(), 0.0, 1.0))

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
	# A valid bed can be far underground; retain its exact standing position.
	if world.valid(cell_at(world.spawn)) and body_free(world.spawn) and world.solid(cell_at(world.spawn + Vector2(0,0.02))):
		return world.spawn
	var home_cell: Vector2i = cell_at(world.spawn)
	if home_cell.y > world.surface_at(home_cell.x) + 16:
		var local := Vector2.INF
		for y in range(maxi(3,home_cell.y - 6),mini(Data.HEIGHT - 2,home_cell.y + 7)):
			for x in range(maxi(1,home_cell.x - 8),mini(Data.WIDTH - 1,home_cell.x + 9)):
				var feet := Vector2((x + 0.5) * Data.TILE,y * Data.TILE - 0.01)
				if world.solid(Vector2i(x,y)) and body_free(feet) and (not local.is_finite() or feet.distance_squared_to(world.spawn) < local.distance_squared_to(world.spawn)):
					local = feet
		if local.is_finite():
			return local
	var safe: Vector2 = nearby_surface(world.spawn)
	if safe.is_finite():
		return safe
	# An extensively excavated or filled spawn still needs a usable return point.
	# Make a small landing pocket and return displaced materials to the backpack.
	var at: Vector2i = cell_at(world.spawn)
	for dx in range(-1, 2):
		for dy in range(-3, 0):
			var c: Vector2i = at + Vector2i(dx, dy)
			adventure.structures.salvage(c)
	if not world.solid(at):
		adventure.structures.salvage(at)
		world.set_tile(at, Data.Block.DIRT)
	return Vector2((at.x + 0.5) * Data.TILE, at.y * Data.TILE - 0.01)

func respawn() -> void:
	if state != "dead":
		return
	var assisted: bool = fault.pending
	player = fault.revive_position() if assisted else safe_spawn()
	previous_player = player
	health = max_health()
	reset_transients()
	set_state("playing")
	if assisted:
		hurt_time = 3.0
	heal_delay = 0
	camera.position = player + Vector2(0, -80)
	camera.reset_physics_interpolation()
	if fault.finish_revival():
		return
	notify("防火女：火还没熄。醒过来吧。" if assisted else "毅川：来了。背包和建造进度都还在。")
	save_world()

func recall_home() -> void:
	if state != "recall":
		return
	player = safe_spawn()
	previous_player = player
	reset_transients()
	set_state("playing")
	camera.position = player + Vector2(0, -80)
	camera.reset_physics_interpolation()
	save_world()

func refresh_merchant() -> void:
	var was_present: bool = merchant_present
	merchant_info = Data.merchant_schedule(day_number())
	merchant_present = merchant_info.present and not fault.active
	if merchant_info.present and (merchant_visit != merchant_info.day or merchant_stock.size() != Data.OFFERS.size()):
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
	if fault.interact():
		return
	if can_trade():
		set_state("merchant")
		audio.sfx("select")
	elif adventure.structures.interact():
		return
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
	adventure.natural_spawn()

func update_enemies(delta: float) -> void:
	adventure.update_enemies(delta)

func _process(delta: float) -> void:
	visual_clock += delta
	update_review(delta)
	message_time = maxf(0, message_time - delta)
	view.fault_view.sync_fog()
	view.fault_view.sync_transition()
	view.queue_redraw()
	sky.queue_redraw()
	ui.queue_redraw()

func _physics_process(delta: float) -> void:
	if state == "fault_transition":
		fault.transition_tick(delta)
		return
	if state == "dead" and fault.pending:
		fault.death_tick(delta)
		return
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
	if grounded:
		adventure.air_jumps = 0
		adventure.flight = 2.2
	var horizontal: float = Input.get_axis("sandbox_left", "sandbox_right")
	var speed: float = 200.0
	if adventure.has_accessory("boots"):
		speed = 285
	velocity.x = move_toward(velocity.x, horizontal * speed, (1900.0 if grounded else 1000.0) * delta)
	if horizontal != 0:
		facing = signf(horizontal)
	if jump_pressed():
		jump_buffer = 0.14
	if jump_buffer > 0 and coyote > 0:
		velocity.y = -490.0
		jump_buffer = 0.0
		coyote = 0.0
		grounded = false
		audio.sfx("jump")
	if not jump_held() and velocity.y < -200:
		velocity.y = move_toward(velocity.y, -200.0, 1900.0 * delta)
	velocity.y = minf(900, velocity.y + 1350 * delta)
	adventure.adjust_motion(delta)
	var falling_speed: float = velocity.y
	var motion: Dictionary = move_body(player, velocity * delta, 8, 36, Input.is_action_pressed("sandbox_down"))
	player = motion.p
	grounded = motion.hit.y > 0
	if motion.hit.x != 0:
		velocity.x = 0
	if motion.hit.y != 0:
		velocity.y = 0
	if grounded and falling_speed > 700:
		hurt((falling_speed - 660) * 0.12, player + Vector2(0, 10))
	if heal_delay <= 0:
		health = minf(max_health(), health + delta * (3.0 if near_station(Data.Block.CAMPFIRE) else (2.0 if near_station(Data.Block.BENCH) else 0.35)))
	update_pad_aim()
	update_tools(delta)
	if state != "playing":
		return
	enemy_timer -= delta
	if enemy_timer <= 0:
		enemy_timer = 4.4 if fault.active else (3.5 if adventure.blood_moon else (6.0 if is_night() else 12.0))
		spawn_enemy()
	update_enemies(delta)
	if state != "playing":
		return
	adventure.tick(delta)
	if state != "playing":
		return
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
		world.reveal(player)
	var target: Vector2 = player + Vector2(velocity.x * 0.22, -80)
	camera.position = camera.position.lerp(target, 1.0 - exp(-5.0 * delta))
	camera.position.x = clampf(camera.position.x, 540, Data.WIDTH * Data.TILE - 540)
	camera.position.y = clampf(camera.position.y, 300, Data.HEIGHT * Data.TILE - 300)
	if autosave_time >= 30:
		autosave_time = 0.0
		save_world()

func update_tools(delta: float) -> void:
	var target: Vector2i = cell_at(mouse_world())
	var use_trigger: bool = Input.is_action_pressed("sandbox_use")
	var place_trigger: bool = Input.is_action_pressed("sandbox_place")
	pad_use_blocked = pad_use_blocked and use_trigger
	pad_place_blocked = pad_place_blocked and place_trigger
	var using_tool: bool = use_trigger and not pad_use_blocked if pad.active else left_held and not ui.blocks_world(pointer)
	var placing: bool = place_trigger and not pad_place_blocked if pad.active else right_held and not ui.blocks_world(pointer)
	if using_tool:
		if Data.ITEMS[held_item()].has("weapon"):
			adventure.fire_weapon(held_item())
		elif held_item() == "fishing_rod":
			if sword_cooldown <= 0 and (not pad.active or Input.is_action_just_pressed("sandbox_use")):
				adventure.use_item(held_item())
				sword_cooldown = 0.25
			left_held = false
		elif held_item() == "sword":
			var side: float = mouse_world().x - player.x
			if pad.active and absf(side) > 1.0:
				facing = signf(side)
			attack()
		elif held_item() == "hammer":
			adventure.structures.take_wall(target)
		elif held_item() == "potion":
			heal()
		elif held_item() != "pickaxe" and sword_cooldown <= 0:
			if adventure.use_item(held_item()):
				sword_cooldown = 0.25
		elif held_item() == "pickaxe" and can_mine(target):
			if mining_cell != target:
				mining_cell = target
				mining_progress = 0.0
			var hardness: float = Data.BLOCKS[world.tile(target)].hardness
			mining_progress += delta * [1.0,1.65,2.4,3.2,4.2,5.4][pick_tier] / maxf(0.05, hardness)
			if mining_progress >= 1.0:
				mine(target)
		else:
			mining_progress = 0.0
	else:
		mining_progress = 0.0
	if placing and place_cooldown <= 0:
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
	block_held_triggers()
	if state != "playing":
		pad.stop_combat_rumble()
	left_held = false
	right_held = false
	mining_progress = 0.0
	previous_player = player

func objective() -> Dictionary:
	if fault.active:
		return {
			"title":"里世界 · 系统故障",
			"text":"神父 %s，找到他可解除故障。\n狮子猿 %s，击倒它也能出去。" % [fault.location_hint(fault.priest_site), fault.location_hint(fault.ape_site)]
		}
	if adventure:
		return adventure.objective()
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
	# Only the fully applied destination can replace the last save during a transition.
	if inventory.is_empty() or (state == "fault_transition" and not fault.transition_swapped):
		return false
	var data: Dictionary = {"version":1, "seed":world.seed_value, "tiles":world.tiles, "explored":world.explored, "surface":world.surface, "spawn":world.spawn, "heart":world.heart_cell, "inventory":inventory, "hotbar":hotbar, "pick":pick_tier, "sword":sword_tier, "elapsed":elapsed, "player":player, "health":health, "selected":selected, "stats":stats, "completed":completed, "merchant_visit":merchant_visit, "merchant_stock":merchant_stock, "review_completed_visit":review_completed_visit, "review_reward_pending":review_reward_pending}
	data["adventure"] = adventure.save_data()
	data["fault"] = fault.save_data()
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
	if file == null or file.get_length() > 16000000:
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
		if not item is String or not Data.equippable(item):
			return {}
	for key in ["pick", "sword", "seed", "selected"]:
		if not value.get(key) is int:
			return {}
	if value.pick < 0 or value.pick > 5 or value.sword < 0 or value.sword > 2:
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
	if value.has("adventure") and not adventure.valid_save(value.adventure):
		return {}
	var saved_day: int = floori(0.32 + float(value.elapsed) / Data.DAY_SECONDS) + 1
	if value.has("fault") and not fault.valid_save(value.fault, float(value.health), saved_day):
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
			if world.tile(Vector2i(x, y)) in [Data.Block.TORCH, Data.Block.BEACON, Data.Block.CAMPFIRE, Data.Block.ALTAR, Data.Block.LIFE_CRYSTAL]:
				world.torch_cells[Vector2i(x, y)] = true
	inventory = data.inventory
	if data.has("adventure"):
		adventure.load_data(data.adventure)
	else:
		adventure.reset()
		adventure.structures.generate_features(true)
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
	fault.load_data(data.get("fault", {}))
	reset_transients()
	if fault.pending:
		health = 0
		if not world.valid(cell_at(player)):
			player = safe_spawn()
	elif data.health <= 0:
		health = max_health()
		player = safe_spawn()
	elif not body_free(player) or not world.valid(cell_at(player)):
		player = safe_spawn()
	previous_player = player
	set_state("dead" if fault.pending else "playing")
	fault.refresh_keeper()
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
	if not save_before_exit():
		return
	get_tree().auto_accept_quit = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func save_before_exit() -> bool:
	if state == "fault_transition":
		fault.swap_worlds()
	return inventory.is_empty() or save_world()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_before_exit():
			get_tree().quit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		window_focused = true
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		window_focused = false
		if state == "playing":
			set_state("paused")

func _unhandled_input(event: InputEvent) -> void:
	var pad_was_active: bool = pad.active
	pad.observe(event)
	if state == "fault_transition":
		if event is InputEventMouse:
			pointer = event.position
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not pad_was_active and pad.active:
			left_held = false
			right_held = false
		gamepad_input(event)
		return
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
	keyboard_shortcut(event.keycode)

func gamepad_input(event: InputEvent) -> void:
	if event.device != pad.device or not pad.active:
		return
	var direction: Vector2 = pad.menu_direction(event)
	if state != "playing" and not direction.is_zero_approx():
		pad.move_focus(ui.menu_entries(), state, direction)
	if not event is InputEventJoypadButton or not event.pressed:
		return
	if event.button_index == JOY_BUTTON_A:
		pad_jump_blocked = state != "playing"
	if state != "playing":
		match event.button_index:
			JOY_BUTTON_A:
				var focus: Dictionary = pad.focused(ui.menu_entries(), state)
				if not focus.is_empty() and focus.state == state:
					ui.click(focus.rect.get_center())
			JOY_BUTTON_B: keyboard_shortcut(KEY_ESCAPE)
			JOY_BUTTON_START:
				if state == "paused":
					set_state("playing")
			JOY_BUTTON_Y:
				if state == "inventory":
					set_state("playing")
		return
	match event.button_index:
		JOY_BUTTON_B:
			update_pad_aim()
			adventure.hook_action()
		JOY_BUTTON_X: interact()
		JOY_BUTTON_Y: set_state("inventory")
		JOY_BUTTON_START: set_state("paused")
		JOY_BUTTON_BACK: set_state("map")
		JOY_BUTTON_DPAD_UP: set_state("journal")
		JOY_BUTTON_DPAD_DOWN: heal()
		JOY_BUTTON_LEFT_STICK: keyboard_shortcut(KEY_F7)
		JOY_BUTTON_RIGHT_STICK: set_state("recall")
		JOY_BUTTON_LEFT_SHOULDER: selected = posmod(selected - 1, hotbar.size())
		JOY_BUTTON_RIGHT_SHOULDER: selected = posmod(selected + 1, hotbar.size())

func keyboard_shortcut(code: int) -> void:
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
			"paused", "inventory", "merchant", "map", "guide", "complete", "recall", "chest", "town_npc", "journal", "sandbox_victory", "fire_keeper", "fault_priest", "fault_resolved": set_state("playing")
			"confirm": set_state("menu")
			"review", "review_failed", "review_reward": set_state("merchant")
			"menu": leave_mode()
	elif state == "playing":
		if code == KEY_Q:
			adventure.hook_action()
		elif code == KEY_T:
			set_state("journal")
		elif code == KEY_F7:
			var house: Dictionary = adventure.structures.register_house(cell_at(player - Vector2(0,12)))
			notify(house.reason)
		elif code in [KEY_TAB, KEY_I]:
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
		elif code >= KEY_1 and code <= KEY_4:
			recipe_category = code - KEY_1
			adventure.recipe_page = 0
	elif state in ["merchant", "map", "guide"] and code in [KEY_E, KEY_M, KEY_F1]:
		set_state("playing")
	elif state in ["chest","town_npc","journal"] and code in [KEY_E,KEY_T,KEY_TAB]:
		set_state("playing")
	elif state == "dead" and code in [KEY_ENTER, KEY_R]:
		respawn()
	elif state == "menu" and code == KEY_ENTER:
		if save_available:
			load_world()
		else:
			start_world()
