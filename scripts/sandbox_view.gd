extends Node2D
## Visible chunks use cached pixel textures; sky and interface use screen canvases.
const Data = preload("res://scripts/sandbox_data.gd")
const INK := Color("152a32")
const PANEL := Color("1d343d")
const EDGE := Color("3e5960")
const WHITE := Color("f4eedc")
const MUTED := Color("a4b9b9")
const MINT := Color("a9dfb5")
const GOLD := Color("efce8a")
const CORAL := Color("ec9292")
var game: Node
var surface: String = "world"
var buttons: Array[Dictionary] = []
var tile_image: Image
var tile_texture: Texture2D
var icon_textures: Dictionary = {}
var chunks: Dictionary = {}
var map_texture: Texture2D
var map_dirty: bool = true
var map_time: float = -10.0
var visible_world := Rect2()
var styles: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if surface in ["world", "ui"]:
		make_tiles()

func clear_cache() -> void:
	chunks.clear()
	game.world.dirty_chunks.clear()

func text(value: String, p: Vector2, size: int = 16, color: Color = WHITE, heavy: bool = false) -> void:
	draw_string(game.bold if heavy else game.font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, p: Vector2, size: int = 16, color: Color = WHITE, heavy: bool = false) -> void:
	var font: Font = game.bold if heavy else game.font
	text(value, p - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, 0), size, color, heavy)

func micro(value: String, p: Vector2, size: int = 8, color: Color = MUTED) -> void:
	draw_string(game.pixel, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func box(rect: Rect2, color: Color = PANEL, border: Color = EDGE, radius: int = 8) -> void:
	var key: Array = [color, border, radius]
	if not styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = border
		style.set_border_width_all(1)
		style.set_corner_radius_all(radius)
		styles[key] = style
	draw_style_box(styles[key], rect)

func button(rect: Rect2, label: String, action: String, index: int = 0, primary: bool = false, enabled: bool = true) -> void:
	var hover: bool = rect.has_point(game.pointer) and enabled
	box(rect, (MINT.lightened(0.08) if hover else MINT) if primary and enabled else (Color("304a50") if hover else PANEL), MINT if primary or hover else EDGE)
	centered(label, rect.get_center() + Vector2(0, 6), 16, INK if primary and enabled else (WHITE if enabled else MUTED), primary)
	if enabled:
		buttons.append({"rect":rect, "action":action, "index":index, "state":game.state})

func make_tiles() -> void:
	var t: int = Data.TILE
	tile_image = Image.create(t * Data.BLOCKS.size(), t, false, Image.FORMAT_RGBA8)
	var random := RandomNumberGenerator.new()
	random.seed = 13017
	for id in range(1, Data.BLOCKS.size()):
		var image := Image.create(t, t, false, Image.FORMAT_RGBA8)
		var color := Color(Data.BLOCKS[id].color)
		if Data.BLOCKS[id].solid:
			var base: Color = Color("697480") if id in [Data.Block.COPPER, Data.Block.IRON, Data.Block.CRYSTAL, Data.Block.COAL, Data.Block.CORE] else color
			if id == Data.Block.GRASS:
				base = Color("986c50")
			image.fill(base)
			for n in range(17):
				var shade: Color = base.lightened(random.randf_range(0.04, 0.16)) if n % 2 == 0 else base.darkened(0.14)
				image.fill_rect(Rect2i(random.randi_range(1, 20), random.randi_range(2, 20), random.randi_range(2, 4), 2), shade)
			image.fill_rect(Rect2i(0, t - 2, t, 2), base.darkened(0.12))
			if id == Data.Block.GRASS:
				image.fill_rect(Rect2i(0, 0, t, 4), Color("88ad68"))
				image.fill_rect(Rect2i(0, 0, t, 2), Color("bad38c"))
				for x in range(0, t, 5):
					image.fill_rect(Rect2i(x, 3, 3, 3 + x % 4), Color("718e52"))
			elif id == Data.Block.SNOW:
				image.fill_rect(Rect2i(0, 0, t, 3), Color("eef2df"))
			elif id == Data.Block.PLANK:
				for y in [0, 8, 16]:
					image.fill_rect(Rect2i(0, y, t, 1), color.darkened(0.3))
					image.fill_rect(Rect2i(4 + y / 2, y + 2, 2, 2), color.darkened(0.4))
			elif id in [Data.Block.COPPER, Data.Block.IRON, Data.Block.CRYSTAL, Data.Block.COAL, Data.Block.CORE]:
				for spot in [Vector2i(4, 5), Vector2i(14, 3), Vector2i(10, 15), Vector2i(18, 16)]:
					image.fill_rect(Rect2i(spot, Vector2i(5, 5)), color.darkened(0.2))
					image.fill_rect(Rect2i(spot, Vector2i(4, 3)), color)
					image.fill_rect(Rect2i(spot, Vector2i(2, 1)), color.lightened(0.3))
			if id == Data.Block.CORE:
				image.fill_rect(Rect2i(7, 4, 10, 16), Color("ffe4a1"))
				image.fill_rect(Rect2i(4, 8, 16, 8), Color("f5cf80"))
		elif id == Data.Block.WOOD:
			image.fill_rect(Rect2i(7, 0, 11, t), color.darkened(0.3))
			image.fill_rect(Rect2i(9, 0, 6, t), color)
			image.fill_rect(Rect2i(13, 2, 2, 12), color.lightened(0.17))
			image.fill_rect(Rect2i(7, 12, 4, 3), color.darkened(0.4))
		elif id == Data.Block.LEAF:
			image.fill_rect(Rect2i(2, 0, 20, 24), color.darkened(0.13))
			image.fill_rect(Rect2i(0, 3, 24, 17), color)
			for n in range(14):
				image.fill_rect(Rect2i(random.randi_range(1, 19), random.randi_range(1, 19), 4, 3), color.lightened(0.15) if n % 2 == 0 else color.darkened(0.15))
		elif id == Data.Block.TORCH:
			image.fill_rect(Rect2i(10, 10, 4, 14), Color("9e6a45"))
			image.fill_rect(Rect2i(8, 4, 8, 10), Color("e18a4b"))
			image.fill_rect(Rect2i(10, 2, 4, 9), Color("ffdf91"))
			image.fill_rect(Rect2i(11, 6, 2, 4), WHITE)
		elif id == Data.Block.BENCH:
			image.fill_rect(Rect2i(0, 8, 24, 5), color.lightened(0.12))
			image.fill_rect(Rect2i(3, 13, 4, 11), color.darkened(0.18))
			image.fill_rect(Rect2i(18, 13, 4, 11), color.darkened(0.18))
			image.fill_rect(Rect2i(4, 17, 16, 3), color)
			image.fill_rect(Rect2i(15, 4, 6, 4), Color("74818c"))
		elif id == Data.Block.FURNACE:
			image.fill_rect(Rect2i(2, 6, 20, 18), color.darkened(0.15))
			image.fill_rect(Rect2i(5, 2, 14, 5), color)
			image.fill_rect(Rect2i(7, 11, 10, 11), Color("413b3b"))
			image.fill_rect(Rect2i(9, 15, 6, 6), Color("e6a05a"))
			image.fill_rect(Rect2i(11, 16, 2, 4), Color("ffdb8b"))
		elif id == Data.Block.BEACON:
			image.fill_rect(Rect2i(3, 21, 18, 3), Color("96b1b8"))
			image.fill_rect(Rect2i(8, 9, 8, 13), Color("667c89"))
			image.fill_rect(Rect2i(7, 4, 10, 10), MINT)
			image.fill_rect(Rect2i(10, 1, 4, 16), Color("e0f8d4"))
		tile_image.blit_rect(image, Rect2i(0, 0, t, t), Vector2i(id * t, 0))
	tile_texture = ImageTexture.create_from_image(tile_image)
	make_icons()

func make_icons() -> void:
	for id in Data.ITEMS:
		if Data.ITEMS[id].block != 0:
			continue
		var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		var color := Color(Data.ITEMS[id].color)
		if id == "pickaxe":
			image.fill_rect(Rect2i(10, 5, 3, 17), Color("b58e62"))
			image.fill_rect(Rect2i(4, 4, 16, 4), color)
			image.fill_rect(Rect2i(18, 7, 3, 5), color.darkened(0.2))
		elif id == "sword":
			image.fill_rect(Rect2i(10, 1, 4, 15), color)
			image.fill_rect(Rect2i(11, 0, 2, 3), WHITE)
			image.fill_rect(Rect2i(6, 15, 12, 3), GOLD)
			image.fill_rect(Rect2i(10, 18, 4, 5), Color("ad8058"))
		elif id == "potion":
			image.fill_rect(Rect2i(9, 1, 6, 5), Color("c6b48a"))
			image.fill_rect(Rect2i(7, 6, 10, 16), color)
			image.fill_rect(Rect2i(4, 11, 16, 9), color)
			image.fill_rect(Rect2i(8, 8, 3, 8), WHITE.lightened(0.1))
		elif id == "lantern":
			image.fill_rect(Rect2i(7, 2, 10, 3), Color("94a4ae"))
			image.fill_rect(Rect2i(5, 6, 14, 16), Color("6b6260"))
			image.fill_rect(Rect2i(8, 8, 8, 11), color)
			image.fill_rect(Rect2i(11, 10, 2, 7), WHITE)
		elif id in ["coin", "charm"]:
			image.fill_rect(Rect2i(6, 5, 12, 14), color)
			image.fill_rect(Rect2i(4, 8, 16, 8), color)
			image.fill_rect(Rect2i(8, 7, 7, 9), color.darkened(0.25))
			image.fill_rect(Rect2i(10, 8, 3, 7), color)
		else:
			image.fill_rect(Rect2i(5, 6, 14, 13), color.darkened(0.25))
			image.fill_rect(Rect2i(7, 3, 10, 16), color)
			image.fill_rect(Rect2i(3, 10, 17, 8), color)
			image.fill_rect(Rect2i(8, 5, 3, 6), color.lightened(0.35))
			if id.ends_with("bar"):
				image.fill_rect(Rect2i(3, 8, 18, 9), color)
				image.fill_rect(Rect2i(5, 6, 14, 3), color.lightened(0.25))
		icon_textures[id] = ImageTexture.create_from_image(image)

func icon(id: String, p: Vector2, size: float = 28.0, tint: Color = Color.WHITE) -> void:
	if not Data.ITEMS.has(id):
		return
	var block: int = Data.ITEMS[id].block
	var rect := Rect2(p - Vector2.ONE * size / 2, Vector2.ONE * size)
	if block != 0:
		draw_texture_rect_region(tile_texture, rect, Rect2(block * Data.TILE, 0, Data.TILE, Data.TILE), tint)
	else:
		draw_texture_rect(icon_textures[id], rect, false, tint)

func chunk_texture(c: Vector2i) -> Texture2D:
	if chunks.has(c):
		return chunks[c]
	var size: int = Data.CHUNK * Data.TILE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(Data.CHUNK):
		for x in range(Data.CHUNK):
			var cell: Vector2i = c * Data.CHUNK + Vector2i(x, y)
			if not game.world.valid(cell):
				continue
			var id: int = game.world.tile(cell)
			if id != Data.Block.AIR:
				image.blit_rect(tile_image, Rect2i(id * Data.TILE, 0, Data.TILE, Data.TILE), Vector2i(x, y) * Data.TILE)
	var result: Texture2D = ImageTexture.create_from_image(image)
	chunks[c] = result
	return result

func _draw() -> void:
	match surface:
		"sky": draw_sky()
		"world": draw_world()
		"ui": draw_ui()

func draw_sky() -> void:
	var light: float = game.daylight()
	var top: Color = Color("18273e").lerp(Color("80b5bd"), light)
	var bottom: Color = Color("384758").lerp(Color("eee0b6"), light)
	for y in range(0, 720, 4):
		draw_rect(Rect2(0, y, 1280, 4), top.lerp(bottom, float(y) / 720))
	if light < 0.5:
		for n in range(70):
			var star := Vector2(posmod(n * 197 + 47, 1280), posmod(n * 83 + 29, 370))
			draw_rect(Rect2(star, Vector2.ONE * (2 if n % 3 else 3)), Color(0.95, 0.93, 0.76, 0.8 * (1 - light)))
	var sun: Vector2 = Vector2(fposmod(game.day_fraction() + 0.8, 1.0) * 1500 - 100, 144)
	draw_circle(sun, 34, Color("f9e5ab") if light > 0.5 else Color("d9e4d7"))
	for n in range(6):
		var x: float = fposmod(n * 267.0 - game.camera.position.x * 0.04 - game.visual_clock * 3, 1550) - 100
		var y: float = 95 + (n % 3) * 48
		var cloud: Color = Color("b2c7c7").lerp(Color("f4eacb"), light)
		draw_rect(Rect2(x, y, 122, 15), cloud)
		draw_rect(Rect2(x + 20, y - 12, 76, 15), cloud)
		draw_rect(Rect2(x + 43, y - 21, 35, 12), cloud)
	for layer in range(3):
		var polygon := PackedVector2Array([Vector2(-80, 720)])
		var parallax: float = game.camera.position.x * (0.025 + layer * 0.025)
		for x in range(-80, 1380, 28):
			var ridge: float = sin((x + parallax) * 0.006 + layer * 3.4) * 52 + sin((x + parallax) * 0.017) * 18
			polygon.append(Vector2(x, 330 + layer * 85 + ridge))
		polygon.append(Vector2(1380, 720))
		var day: Color = [Color("a0b6a0"), Color("839d87"), Color("5f8675")][layer]
		draw_colored_polygon(polygon, Color("263a45").lerp(day, light))
	for n in range(23):
		var x: float = fposmod(n * 97 - game.camera.position.x * 0.12, 1500) - 100
		var y: float = 472 + sin(n * 4.1) * 35
		var color: Color = Color("203f47").lerp(Color("537965"), light)
		draw_rect(Rect2(x + 16, y, 5, 110), color)
		for tier in range(4):
			var width: float = 18 + tier * 10
			draw_rect(Rect2(x + 18 - width / 2, y + tier * 18, width, 22), color)

func render_position(current: Vector2, previous: Vector2) -> Vector2:
	return previous.lerp(current, Engine.get_physics_interpolation_fraction()) if game.state == "playing" else current

func draw_world() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size / game.camera.zoom
	visible_world = Rect2(game.camera.get_screen_center_position() - viewport_size / 2, viewport_size).grow(48)
	for dirty in game.world.dirty_chunks:
		chunks.erase(dirty)
	game.world.dirty_chunks.clear()
	if chunks.size() > 128:
		chunks.clear()
	var first: Vector2i = game.cell_at(visible_world.position)
	var last: Vector2i = game.cell_at(visible_world.end)
	for x in range(maxi(0, first.x), mini(Data.WIDTH, last.x + 1)):
		var ground: int = game.world.surface_at(x)
		var top: float = ground * Data.TILE
		var fill := Color("4e4949")
		draw_rect(Rect2(x * Data.TILE, top, Data.TILE, Data.HEIGHT * Data.TILE - top), fill)
		draw_rect(Rect2(x * Data.TILE, (ground + 10) * Data.TILE, Data.TILE, (Data.HEIGHT - ground - 10) * Data.TILE), Color("353d49"))
	for y in range(maxi(0, first.y), mini(Data.HEIGHT, last.y + 1), 2):
		for x in range(maxi(0, first.x), mini(Data.WIDTH, last.x + 1), 2):
			if y > game.world.surface_at(x) + 1:
				draw_rect(Rect2(x * Data.TILE + 10, y * Data.TILE + 6, 12, 3), Color("3d444e"))
	var chunk_size: int = Data.CHUNK * Data.TILE
	var from: Vector2i = Vector2i((visible_world.position / chunk_size).floor())
	var to: Vector2i = Vector2i((visible_world.end / chunk_size).floor())
	for y in range(maxi(0, from.y), mini(Data.HEIGHT / Data.CHUNK - 1, to.y) + 1):
		for x in range(maxi(0, from.x), mini(Data.WIDTH / Data.CHUNK - 1, to.x) + 1):
			var c := Vector2i(x, y)
			draw_texture(chunk_texture(c), Vector2(c) * chunk_size)
	if game.merchant_present and visible_world.grow(100).has_point(game.merchant_position):
		game.priest_atlas.draw(self, 0, game.merchant_position, 64, 1)
		world_label("神父 · CTO", game.merchant_position - Vector2(0, 83), GOLD)
		if game.can_trade() and game.state == "playing":
			world_label("[E] 购买物资", game.merchant_position - Vector2(0, 65), WHITE)
	for enemy in game.enemies:
		var p: Vector2 = render_position(enemy.p, enemy.previous)
		var tint: Color = Color("b9a4dd") if enemy.dark else Color("a7d1a7")
		game.enemy_atlas.draw(self, (int(game.visual_clock * 5) % 4), p, 29, 1, Color("ffffff") if enemy.flash > 0 else tint)
		if enemy.hp < enemy.max_hp:
			draw_rect(Rect2(p - Vector2(17, 39), Vector2(34, 3)), INK)
			draw_rect(Rect2(p - Vector2(17, 39), Vector2(34 * enemy.hp / enemy.max_hp, 3)), CORAL)
	var p: Vector2 = render_position(game.player, game.previous_player)
	var pose: int = int(game.visual_clock * 9) % 4 if absf(game.velocity.x) > 5 else 0
	var tint: Color = Color(1, 1, 1, 0.5) if game.hurt_time > 0 and int(game.visual_clock * 15) % 2 == 0 else Color.WHITE
	game.hero_atlas.draw(self, pose if game.facing > 0 else 8 + pose, p, 44, 1, tint)
	if game.sword_time > 0:
		var progress: float = 1 - game.sword_time / 0.24
		draw_set_transform(p - Vector2(0, 23), (progress * 2.5 - 1.25) * game.facing)
		icon("sword", Vector2(game.facing * 28, -12), 46)
		draw_set_transform(Vector2.ZERO)
	elif game.mining_progress > 0:
		draw_set_transform(p - Vector2(0, 22), sin(game.visual_clock * 20) * 0.65 * game.facing)
		icon("pickaxe", Vector2(game.facing * 21, -6), 32)
		draw_set_transform(Vector2.ZERO)
	for particle in game.particles:
		draw_rect(Rect2(particle.p, Vector2.ONE * 3), particle.color)
	draw_lighting()
	if game.state == "playing":
		draw_target()
	for entry in game.texts:
		world_label(entry.text, entry.p, Color(entry.color, minf(1, entry.life * 2)))

func world_label(value: String, p: Vector2, color: Color) -> void:
	var offset: float = game.font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / 2
	draw_string_outline(game.bold, p - Vector2(offset, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, INK)
	draw_string(game.bold, p - Vector2(offset, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func draw_lighting() -> void:
	var lights: Array[Vector2] = []
	for c in game.world.torch_cells:
		var p: Vector2 = game.cell_center(c)
		if visible_world.grow(180).has_point(p):
			lights.append(p)
	if visible_world.grow(180).has_point(game.cell_center(game.world.heart_cell)) and game.world.tile(game.world.heart_cell) == Data.Block.CORE:
		lights.append(game.cell_center(game.world.heart_cell))
	var step: int = 32
	var origin: Vector2 = (visible_world.position / step).floor() * step
	for y in range(0, ceili(visible_world.size.y / step) + 1):
		for x in range(0, ceili(visible_world.size.x / step) + 1):
			var p: Vector2 = origin + Vector2(x, y) * step
			var center: Vector2 = p + Vector2.ONE * step / 2
			var depth: float = center.y / Data.TILE - game.world.surface_at(int(center.x / Data.TILE))
			var light: float = maxf(0.07, game.daylight() * (1 - clampf(depth / 11, 0, 1)))
			var radius: float = 160.0 if game.count_item("lantern") > 0 else 102.0
			light = maxf(light, clampf(1 - center.distance_to(game.player - Vector2(0, 18)) / radius, 0, 1) * 0.8)
			for lamp in lights:
				light = maxf(light, clampf(1 - center.distance_to(lamp) / 175.0, 0, 1) * 1.1)
			if light < 0.98:
				draw_rect(Rect2(p, Vector2.ONE * step), Color(0.025, 0.035, 0.07, (1 - light) * 0.92))

func draw_target() -> void:
	if game.ui.blocks_world(game.pointer):
		return
	var c: Vector2i = game.cell_at(game.mouse_world())
	if not game.world.valid(c) or not game.reachable(c):
		return
	var id: int = game.world.tile(c)
	var ok: bool = game.can_mine(c) if game.held_item() == "pickaxe" else game.can_place(c, game.held_item())
	if game.held_item() == "sword":
		return
	var rect := Rect2(Vector2(c) * Data.TILE, Vector2.ONE * Data.TILE)
	var color: Color = MINT if ok else CORAL
	draw_rect(rect.grow(1), Color(color, 0.18))
	draw_rect(rect.grow(1), color, false, 1.3)
	if game.mining_progress > 0 and game.mining_cell == c:
		draw_rect(Rect2(rect.position - Vector2(0, 6), Vector2(Data.TILE, 3)), INK)
		draw_rect(Rect2(rect.position - Vector2(0, 6), Vector2(Data.TILE * game.mining_progress, 3)), GOLD)
	if id != Data.Block.AIR:
		var label: String = Data.BLOCKS[id].name
		if Data.BLOCKS[id].tier > game.pick_tier:
			label += " · 需要" + ("铜镐" if Data.BLOCKS[id].tier == 1 else "铁镐")
		world_label(label, rect.get_center() + Vector2(0, 38), WHITE)

func update_map() -> void:
	if not map_dirty or game.visual_clock - map_time < 0.6:
		return
	map_time = game.visual_clock
	map_dirty = false
	var image := Image.create(Data.WIDTH, Data.HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color("12232e"))
	for y in range(Data.HEIGHT):
		for x in range(Data.WIDTH):
			if game.world.explored[y * Data.WIDTH + x] != 0:
				var id: int = game.world.tile(Vector2i(x, y))
				var color: Color = Color("45586a") if y > game.world.surface_at(x) else Color("a5c8cb")
				image.set_pixel(x, y, color if id == Data.Block.AIR else Color(Data.BLOCKS[id].color))
	map_texture = ImageTexture.create_from_image(image)

func draw_map(rect: Rect2, full: bool = false) -> void:
	update_map()
	box(rect.grow(3), INK, EDGE, 3)
	if map_texture == null:
		return
	var source := Rect2(0, 0, Data.WIDTH, Data.HEIGHT)
	if not full:
		var at: Vector2 = game.player / Data.TILE
		source = Rect2(clampf(at.x - 52, 0, Data.WIDTH - 104), clampf(at.y - 23, 0, Data.HEIGHT - 46), 104, 46)
	draw_texture_rect_region(map_texture, rect, source)
	var p: Vector2 = rect.position + (game.player / Data.TILE - source.position) / source.size * rect.size
	draw_rect(Rect2(p - Vector2.ONE * 2, Vector2.ONE * 4), WHITE)
	var spawn: Vector2 = rect.position + (game.world.spawn / Data.TILE - source.position) / source.size * rect.size
	if rect.has_point(spawn):
		draw_rect(Rect2(spawn - Vector2(3, 6), Vector2(6, 6)), GOLD)
	if game.merchant_present:
		var merchant: Vector2 = rect.position + (game.merchant_position / Data.TILE - source.position) / source.size * rect.size
		if rect.has_point(merchant):
			draw_rect(Rect2(merchant - Vector2(2, 7), Vector2(4, 7)), Color("f1bd7a"))

func blocks_world(p: Vector2) -> bool:
	return game.state != "playing" or p.y > 606 or Rect2(970, 12, 296, 192).has_point(p) or Rect2(14, 12, 324, 283).has_point(p)

func draw_ui() -> void:
	buttons.clear()
	if game.state in ["menu", "confirm"]:
		menu()
		if game.state == "confirm":
			buttons.clear()
			modal("开辟一个新世界？", "新世界将替换当前存档，并重新开始采集与建造。", "开辟新世界", "new_confirm")
		draw_message()
		return
	hud()
	if game.state != "playing":
		buttons.clear()
		match game.state:
			"inventory": inventory_panel()
			"merchant": merchant_panel()
			"review": review_panel()
			"review_reward": merchant_panel(true)
			"review_failed":
				modal("Code Review 未通过", "神父：先缓一缓，把那些 Bug 重新对上号。", "重新 Review", "review_start")
				button(Rect2(472, 425, 336, 39), "返回补给", "review_return")
			"map": map_panel()
			"guide": guide()
			"paused": pause_panel()
			"dead": modal("哦豁，完蛋。", "旅途还没结束。背包、矿洞和建筑都会保留。", "回到出生地", "respawn")
			"complete": modal("归途已被点亮", "毅川在这片旷野有了自己的家。你可以继续探索和建造。", "继续我的世界", "resume")
			"recall": modal("返回出生地？", "保留所有物资与地图，传送回出生地附近。", "返回出生地", "recall")
	draw_message()
	if game.show_fps:
		micro("%d FPS" % Engine.get_frames_per_second(), Vector2(892, 30), 8, MINT)

func draw_message() -> void:
	if game.message_time <= 0:
		return
	var width: float = minf(1140, game.font.get_string_size(game.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 36)
	var y: float = 677 if game.state in ["menu", "confirm"] else 560
	box(Rect2(640 - width / 2, y, width, 34), Color("263e3c"), Color("698977"))
	centered(game.message, Vector2(640, y + 23), 16, WHITE)

func menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.035, 0.07, 0.09, 0.45))
	box(Rect2(58, 54, 523, 607), Color(0.07, 0.13, 0.16, 0.96), Color("607a72"), 18)
	micro("YICHUAN / THE WILDERNESS", Vector2(91, 99), 9, MINT)
	text("毅川的", Vector2(88, 172), 42, WHITE, true)
	text("像素旷野", Vector2(86, 244), 66, WHITE, true)
	text("挖下第一块土，建起自己的世界。", Vector2(92, 288), 20, MINT)
	text("随机地形 / 地下矿脉 / 自由建造", Vector2(94, 338), 17, MUTED)
	text("制作升级 / 昼夜生存 / 独立存档", Vector2(94, 371), 17, MUTED)
	if game.save_available:
		button(Rect2(92, 414, 455, 54), "继续我的世界  →", "continue", 0, true)
		button(Rect2(92, 481, 455, 47), "开辟新世界", "new")
	else:
		button(Rect2(92, 414, 455, 58), "来了，开辟新世界  →", "new", 0, true)
	button(Rect2(92, 545, 455, 44), "返回地牢模式", "leave")
	text("A / D 移动    空格跳跃    鼠标挖掘与建造", Vector2(93, 631), 15, MUTED)
	box(Rect2(853, 83, 349, 36), Color("263f40"), Color("72968a"), 18)
	centered("全新模式 · 横版 2D 沙盒", Vector2(1028, 108), 17, MINT, true)
	var p := Vector2(762, 559)
	game.hero_atlas.draw(self, 0, p, 175, 1)
	game.priest_atlas.draw(self, 0, Vector2(1055, 561), 245, -1)
	box(Rect2(665, 600, 539, 58), Color(0.07, 0.13, 0.16, 0.94), EDGE, 10)
	centered("神父 / CTO · 每 5 个游戏日送补给", Vector2(934, 625), 20, GOLD, true)
	centered("今天已到访，在出生地等你。" if game.merchant_present else "第 %d 天到访 · 还需 %d 个游戏日。" % [game.merchant_info.next_day, game.merchant_info.days], Vector2(934, 649), 14, MUTED)

func hud() -> void:
	box(Rect2(16, 14, 319, 103), Color(0.07, 0.13, 0.16, 0.93), EDGE, 10)
	text("毅川的像素旷野", Vector2(31, 42), 19, WHITE, true)
	var hour: int = int(game.day_fraction() * 24)
	var minute: int = int(fposmod(game.day_fraction() * 1440, 60))
	text("第 %d 天  ·  %02d:%02d  ·  %s" % [game.day_number(), hour, minute, "夜晚" if game.is_night() else "白昼"], Vector2(31, 67), 14, MUTED)
	draw_rect(Rect2(32, 81, 210, 11), Color("3b4445"))
	draw_rect(Rect2(32, 81, 210 * game.health / game.max_health(), 11), CORAL)
	text("%d / %d" % [ceili(game.health), int(game.max_health())], Vector2(252, 92), 13, WHITE)
	var objective: Dictionary = game.objective()
	box(Rect2(16, 128, 319, 101), Color(0.07, 0.13, 0.16, 0.87), Color("405a54"))
	text(objective.title, Vector2(31, 154), 16, GOLD, true)
	var line: int = 0
	for part in objective.text.split("\n"):
		text(part, Vector2(31, 180 + line * 24), 13, MUTED)
		line += 1
	box(Rect2(16, 242, 319, 51), Color(0.07, 0.13, 0.16, 0.88), EDGE)
	text("神父到访 · 出生地附近 [E]" if game.merchant_present else "CTO 神父 · 每 5 个游戏日到访", Vector2(31, 264), 14, GOLD if game.merchant_present else MUTED, true)
	text("本次库存已记录 · 击败怪物获得旧银币" if game.merchant_present else "第 %d 天到访 · 还需 %d 个游戏日" % [game.merchant_info.next_day, game.merchant_info.days], Vector2(31, 284), 11, MUTED)
	box(Rect2(982, 14, 282, 141), Color(0.07, 0.13, 0.16, 0.93), EDGE, 9)
	text(game.world.biome(game.cell_at(game.player).x), Vector2(997, 38), 15, WHITE, true)
	text("深度 %d m" % maxi(0, int((game.player.y / Data.TILE - game.world.surface_at(game.cell_at(game.player).x)) * 2)), Vector2(1170, 38), 12, MUTED)
	draw_map(Rect2(997, 50, 252, 81))
	text("白点：你   金色：出生地   [M] 地图", Vector2(997, 147), 11, MUTED)
	button(Rect2(1001, 167, 119, 32), "背包 · Tab", "inventory")
	button(Rect2(1128, 167, 120, 32), "暂停 · Esc", "pause")
	var item: String = game.held_item()
	var name: String = ["采掘镐", "铜镐", "铁镐"][game.pick_tier] if item == "pickaxe" else (["猎虫剑", "铜剑", "铁剑"][game.sword_tier] if item == "sword" else Data.ITEMS[item].name)
	var help: String = "长按左键开采" if item == "pickaxe" else ("左键挥剑" if item == "sword" else ("H 快捷治疗" if item == "potion" else "右键放置"))
	centered(name + "  ·  " + help, Vector2(640, 612), 16, WHITE, true)
	for i in range(game.hotbar.size()):
		var rect := Rect2(330 + i * 62, 627, 56, 57)
		var active: bool = game.selected == i
		box(rect, Color("3a5147") if active else INK, GOLD if active else EDGE, 6)
		text(str((i + 1) % 10), rect.position + Vector2(5, 14), 11, GOLD if active else MUTED)
		var id: String = game.hotbar[i]
		icon(id, rect.position + Vector2(29, 27), 29, Color.WHITE if game.count_item(id) > 0 else Color(1, 1, 1, 0.23))
		if id not in ["pickaxe", "sword"]:
			text(str(game.count_item(id)), rect.position + Vector2(32, 50), 12, WHITE)
		buttons.append({"rect":rect, "action":"slot", "index":i, "state":game.state})
	text("A / D 移动   空格跳跃   J 挥剑   E 交互   H 治疗   R 回家   F1 指南", Vector2(22, 708), 13, Color("c4d4cc"))
	var saved: String = "已保存 " + game.last_saved if not game.last_saved.is_empty() else ("存档已读取" if game.save_available else "尚未保存")
	text("旧银币 %d  ·  %s" % [game.count_item("coin"), "保存失败 · F5 重试" if not game.save_error.is_empty() else saved], Vector2(1000, 706), 12, CORAL if not game.save_error.is_empty() else MUTED)

func scrim() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.035, 0.065, 0.08, 0.87))

func inventory_panel() -> void:
	scrim()
	box(Rect2(100, 48, 1080, 614), INK, EDGE, 14)
	text("随身行囊", Vector2(130, 91), 27, WHITE, true)
	text("制作台", Vector2(607, 91), 27, WHITE, true)
	button(Rect2(1087, 65, 66, 31), "关闭", "resume")
	text("镐：%s    剑：%s" % [["基础", "铜", "铁"][game.pick_tier], ["基础", "铜", "铁"][game.sword_tier]], Vector2(132, 127), 15, MINT)
	var index: int = 0
	for id in Data.ITEMS:
		var rect := Rect2(130 + index % 5 * 86, 147 + index / 5 * 87, 78, 78)
		box(rect, PANEL, EDGE, 5)
		icon(id, rect.position + Vector2(39, 27), 30, Color.WHITE if game.count_item(id) > 0 else Color(1, 1, 1, 0.3))
		centered(Data.ITEMS[id].name, rect.position + Vector2(39, 58), 11, WHITE if game.count_item(id) > 0 else MUTED)
		centered(str(game.count_item(id)), rect.position + Vector2(39, 73), 11, GOLD)
		if Data.ITEMS[id].block != 0 or id in ["pickaxe", "sword", "potion"]:
			buttons.append({"rect":rect, "action":"equip", "item":id, "state":game.state})
		index += 1
	for category in range(3):
		button(Rect2(606 + category * 178, 111, 164, 34), ["1 基础建造", "2 采掘冶炼", "3 战斗 / 归途"][category], "category", category, game.recipe_category == category)
	var row: int = 0
	for n in range(Data.RECIPES.size()):
		var recipe: Dictionary = Data.RECIPES[n]
		if recipe.category != game.recipe_category:
			continue
		var y: float = 159 + row * 73
		var reason: String = game.craft_reason(n)
		box(Rect2(604, y, 548, 65), PANEL, EDGE, 5)
		var item: String = "pickaxe" if recipe.id.ends_with("pick") else ("sword" if recipe.id.ends_with("sword") else recipe.id)
		icon(item, Vector2(630, y + 26), 27)
		var name: String = recipe.get("name", Data.ITEMS.get(recipe.id, {}).get("name", recipe.id))
		text(name + (" ×%d" % recipe.amount if recipe.amount > 1 else ""), Vector2(653, y + 22), 16, WHITE, true)
		var cost: String = ""
		for id in recipe.cost:
			cost += "%s %d/%d  " % [Data.ITEMS[id].name, game.count_item(id), recipe.cost[id]]
		text(cost, Vector2(615, y + 54), 12, GOLD if reason.is_empty() else MUTED)
		button(Rect2(1010, y + 10, 130, 28), "制作" if reason.is_empty() else reason, "craft", n, reason.is_empty(), true)
		row += 1
	text("点击方块放入当前快捷格；已有物品直接切换。", Vector2(132, 625), 13, MUTED)
	text("附近设施：%s  /  %s" % ["工作台 ✓" if game.near_station(Data.Block.BENCH) else "无工作台", "熔炉 ✓" if game.near_station(Data.Block.FURNACE) else "无熔炉"], Vector2(606, 627), 14, MINT)

func merchant_panel(reward: bool = false) -> void:
	scrim()
	box(Rect2(78, 51, 1124, 612), INK, Color("786a51"), 14)
	micro("CTO / FIELD SUPPLY", Vector2(112, 91), 8, GOLD)
	text(Data.PRIEST.name, Vector2(111, 142), 40, WHITE, true)
	text(Data.PRIEST.role, Vector2(112, 168), 14, GOLD)
	var quote: String = "Code Review 通过。\n挑一件物资，算你的奖励。" if reward else Data.PRIEST.quote
	var quote_lines: PackedStringArray = quote.split("\n")
	for row in range(quote_lines.size()):
		text(quote_lines[row], Vector2(112, 194 + row * 23), 16, WHITE)
	game.priest_atlas.draw(self, 0, Vector2(259, 511), 278, 1)
	text("每 5 个游戏日到访", Vector2(112, 548), 20, GOLD, true)
	text("本次第 %d 天 · 下次第 %d 天" % [game.merchant_info.day, game.merchant_info.next_day], Vector2(112, 580), 14, MUTED)
	text("旧银币  %d" % game.count_item("coin"), Vector2(112, 618), 23, GOLD, true)
	text("Code Review 通关" if reward else "救援补给", Vector2(463, 104), 27, WHITE, true)
	text("免费任选 1 件物品 · 不消耗旧银币" if reward else "每次到访补货 · 库存随世界保存", Vector2(463, 130), 14, MUTED)
	button(Rect2(1101, 73, 71, 32), "返回" if reward else "离开", "review_return" if reward else "resume")
	if not reward:
		var reviewed: bool = game.review_completed_visit == game.merchant_visit
		var label: String = "领取 Review 奖励" if game.review_reward_pending else ("本次 Review 已通过" if reviewed else "Code Review · 挑战")
		button(Rect2(930, 113, 242, 30), label, "review_start", 0, not reviewed or game.review_reward_pending, not reviewed or game.review_reward_pending)
	for index in range(Data.OFFERS.size()):
		var offer: Dictionary = Data.OFFERS[index]
		var rect := Rect2(460 + index % 2 * 352, 155 + index / 2 * 112, 337, 101)
		box(rect, PANEL, EDGE, 7)
		icon(offer.id, rect.position + Vector2(30, 30), 32)
		text(Data.ITEMS[offer.id].name + (" ×%d" % offer.amount if offer.amount > 1 and not reward else ""), rect.position + Vector2(57, 27), 17, WHITE, true)
		var stock: int = game.merchant_stock[index]
		text("免费领取 ×1" if reward else "库存 %d / %d" % [stock, offer.stock], rect.position + Vector2(57, 50), 12, GOLD if reward else MUTED)
		var desc: String = offer.desc
		text(desc, rect.position + Vector2(12, 83), 12, MUTED)
		var owned: bool = offer.get("unique", false) and game.count_item(offer.id) > 0
		var available: bool = not owned and (reward or stock > 0)
		var label: String = "免费领取" if reward else ("售罄" if stock <= 0 else "%d 银币" % offer.price)
		button(Rect2(rect.position + Vector2(219, 13), Vector2(105, 37)), "已拥有" if owned else label, "review_claim" if reward else "buy", index, available, available)
	text("击败地表与地下怪物可获得旧银币。提灯与护符放在背包中即可生效。", Vector2(462, 631), 13, MINT)

func review_panel() -> void:
	scrim()
	box(Rect2(96, 52, 1088, 611), INK, EDGE, 14)
	text("Code Review", Vector2(128, 107), 32, WHITE, true)
	text("精神衰弱 · 高难挑战 / 20 张牌 / 60 秒 / 最多 16 回合", Vector2(129, 143), 17, MUTED)
	button(Rect2(1080, 77, 73, 32), "返回", "review_return")
	for index in range(game.review_cards.size()):
		var rect := Rect2(128 + index % 5 * 142, 175 + index / 5 * 103, 130, 85)
		var matched: bool = game.review_matched[index]
		var visible_card: bool = matched or game.review_open.has(index)
		var pair: Dictionary = Data.REVIEW_PAIRS[game.review_cards[index]]
		var color: Color = Color(pair.color)
		box(rect, Color("294d44") if matched else PANEL, MINT if matched else (color if visible_card else EDGE), 9)
		if visible_card:
			micro(pair.code, rect.get_center() + Vector2(-pair.code.length() * 4, -6), 8, color)
			centered(pair.name, rect.get_center() + Vector2(0, 21), 17, MINT if matched else WHITE, true)
		else:
			centered("?", rect.get_center() + Vector2(0, 7), 32, MUTED, true)
			micro("REVIEW", rect.position + Vector2(40, 71), 7, MUTED)
		if not matched and not game.review_open.has(index) and game.review_wait <= 0:
			buttons.append({"rect":rect, "action":"review_flip", "index":index, "state":game.state})
	box(Rect2(858, 175, 296, 394), PANEL, EDGE, 9)
	text("CTO 的随堂 Review", Vector2(879, 210), 19, GOLD, true)
	text("剩余时间", Vector2(880, 251), 14, MUTED)
	var seconds: int = ceili(game.review_time)
	micro("%02d:%02d" % [seconds / 60, seconds % 60], Vector2(880, 288), 20, CORAL if seconds < 20 else MINT)
	text("已配对  %d / %d" % [game.review_pairs, Data.REVIEW_PAIRS.size()], Vector2(880, 333), 20, WHITE, true)
	text("翻牌回合  %d / %d" % [game.review_turns, Data.REVIEW_MAX_TURNS], Vector2(880, 366), 17, MUTED)
	text("每次翻开两张，找到相同的 Bug。", Vector2(880, 411), 13, MUTED)
	text("最多配错 6 次。过关免费任选一件。", Vector2(880, 437), 13, GOLD)
	text("“别把同一个 Bug", Vector2(880, 493), 18, WHITE)
	text("Review 两遍。”", Vector2(880, 523), 18, WHITE)
	text("游戏世界暂停 · Esc 返回商店 · 每次神父到访可领取一次奖励", Vector2(129, 621), 15, MUTED)

func map_panel() -> void:
	scrim()
	box(Rect2(91, 96, 1098, 521), INK, EDGE, 14)
	text("你探索过的世界", Vector2(123, 145), 28, WHITE, true)
	text("种子 %d · 未探索地区保留迷雾" % game.world.seed_value, Vector2(124, 179), 16, MUTED)
	draw_map(Rect2(122, 216, 1036, 345), true)
	text("白点：毅川   金色：出生地   琥珀色：神父", Vector2(124, 594), 14, MUTED)
	button(Rect2(1040, 118, 116, 35), "关闭 · M", "resume")

func guide() -> void:
	scrim()
	box(Rect2(177, 63, 926, 593), INK, EDGE, 14)
	text("在旷野，慢慢建立自己的生活。", Vector2(215, 115), 28, WHITE, true)
	var entries: Array[String] = [
		"A / D 或 ← / → 移动，空格 / W / ↑ 跳跃。",
		"1 号镐：长按鼠标左键挖掘。砍断树干可收集上方原木。",
		"数字键 / 滚轮切换快捷栏；选择方块，再按右键放置。",
		"Tab / I 打开背包与制作，靠近放下的工作台、熔炉解锁配方。",
		"铜镐可挖铁矿；铁镐可挖水晶和大地之心。矿石需煤炭熔炼。",
		"J 随时挥剑；选 2 号剑也可长按左键攻击。H 饮用治疗药水。",
		"每 10 分钟一轮昼夜，夜间与地下怪物更强。火把可永久照明。",
		"第 5、10、15……个游戏日，CTO 神父来到出生地左侧；靠近按 E 交易。",
		"每次停留一个游戏日；到访时补货，同次到访读档不会刷新库存。",
		"M 查看探索地图；R 返回出生地。倒下可复活，物品和建筑保留。",
		"30 秒自动保存；F5 手动保存。Esc 暂停，退出时会先保存。"
	]
	for index in range(entries.size()):
		text(entries[index], Vector2(216, 163 + index * 35), 17, MUTED)
	button(Rect2(833, 593, 228, 39), "明白了，继续探索", "resume", 0, true)

func pause_panel() -> void:
	scrim()
	box(Rect2(417, 130, 446, 455), INK, EDGE, 14)
	centered("歇一会儿", Vector2(640, 189), 34, WHITE, true)
	centered("世界已暂停。", Vector2(640, 223), 16, MUTED)
	button(Rect2(453, 252, 374, 49), "继续探索", "resume", 0, true)
	button(Rect2(453, 314, 374, 45), "保存世界 · F5", "save")
	button(Rect2(453, 371, 374, 45), "游玩指南", "guide")
	button(Rect2(453, 428, 374, 45), "保存并返回模式主页", "menu")
	button(Rect2(453, 485, 374, 45), "保存并返回地牢模式", "leave")

func modal(title: String, body: String, label: String, action: String) -> void:
	scrim()
	box(Rect2(300, 218, 680, 278), INK, EDGE, 14)
	centered(title, Vector2(640, 281), 35, WHITE, true)
	centered(body, Vector2(640, 326), 17, MUTED)
	button(Rect2(472, 362, 336, 46), label, action, 0, true)
	if game.state in ["confirm", "recall"]:
		button(Rect2(472, 425, 336, 39), "再想想", "cancel")

func click(p: Vector2) -> bool:
	for entry in buttons.duplicate():
		if entry.state != game.state or not entry.rect.has_point(p):
			continue
		match entry.action:
			"new":
				if game.save_available:
					game.set_state("confirm")
				else:
					game.start_world()
			"new_confirm": game.start_world()
			"continue": game.load_world()
			"cancel": game.set_state("menu" if game.state == "confirm" else "playing")
			"resume": game.set_state("playing")
			"inventory": game.set_state("inventory")
			"pause": game.set_state("paused")
			"guide": game.set_state("guide")
			"leave": game.leave_mode()
			"save":
				if game.save_world():
					game.notify("世界已保存。")
			"menu":
				if game.save_world():
					game.set_state("menu")
			"respawn": game.respawn()
			"recall": game.respawn()
			"slot": game.selected = entry.index
			"equip": game.equip_item(entry.item)
			"category": game.recipe_category = entry.index
			"craft": game.craft(entry.index)
			"buy": game.buy(entry.index)
			"review_start": game.start_review()
			"review_flip": game.flip_review(entry.index)
			"review_return": game.set_state("merchant")
			"review_claim": game.claim_review_reward(entry.index)
		return true
	return false
