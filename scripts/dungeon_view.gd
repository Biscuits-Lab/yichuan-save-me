extends Node2D
## A top-down arena and its UI share one 1280 x 720 logical canvas.
var game: Node
var surface: String = "world"
var overlay: Node2D
var geometry_root: Node2D
var geometry: Dictionary = {}
var geometry_kind: String = ""
var style_cache: Dictionary = {}
var ui_redraw_time: float = 0
var visible_world: Rect2
var buttons: Array[Dictionary] = []
const BG := Color("101922")
const PANEL := Color("182630")
const LINE := Color("34464f")
const WHITE := Color("f3ecd8")
const MUTED := Color("93a8ad")
const MINT := Color("85e0b9")
const GOLD := Color("ffca80")
const RED := Color("ff8c96")
const PURPLE := Color("bda1ed")

func _ready() -> void:
	if surface != "world":
		return
	geometry_root = Node2D.new()
	geometry_root.z_index = -10
	add_child(geometry_root)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	overlay = get_script().new()
	overlay.game = game
	overlay.surface = "ui"
	layer.add_child(overlay)

func _draw() -> void:
	if surface == "geometry":
		visible_world = geometry.rect.grow(160)
		if geometry_kind == "room":
			draw_room_geometry(geometry)
		else:
			draw_corridor_geometry(geometry)
		return
	if surface == "world":
		if not game.rooms.is_empty() and game.state != "title" and not (game.state == "guide" and game.return_state == "title"):
			var size: Vector2 = Vector2(1280, 720) / game.camera.zoom
			visible_world = Rect2(game.camera.get_screen_center_position() - size / 2, size).grow(160)
			arena()
		return
	buttons.clear()
	if game.state == "title" or (game.state == "guide" and game.return_state == "title"):
		draw_rect(Rect2(0, 0, 1280, 720), BG)
		title_screen()
	else:
		hud()
	if game.state not in ["title", "playing"]:
		buttons.clear()
	match game.state:
		"dialogue": story()
		"shop": shop()
		"skill": skill_reward()
		"inventory": inventory()
		"npc": npc_panel()
		"paused", "dead", "won": ending_panel()
		"guide": guide()
		"cheats": cheats()
	if game.message_time > 0 and game.state != "title":
		var width: float = minf(1120, game.font.get_string_size(game.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 44)
		box(Rect2(640 - width / 2, 675, width, 32), Color("263d3a"), MINT, 8)
		center(game.message, Vector2(640, 697), 17, WHITE)
	if game.show_fps:
		micro("%d FPS" % Engine.get_frames_per_second(), Vector2(1100, 248), MINT, 9)

func text(value: String, p: Vector2, size: int = 18, color: Color = WHITE, heavy: bool = false) -> void:
	draw_string(game.bold if heavy else game.font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func center(value: String, p: Vector2, size: int = 18, color: Color = WHITE, heavy: bool = false) -> void:
	var font: Font = game.bold if heavy else game.font
	text(value, p - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, 0), size, color, heavy)

func micro(value: String, p: Vector2, color: Color = MUTED, size: int = 8) -> void:
	draw_string(game.pixel, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func paragraph(value: String, p: Vector2, width: float, size: int = 18, color: Color = MUTED, max_lines: int = 5) -> void:
	var line: String = ""
	var row: int = 0
	for character in value:
		if character == "\n" or game.font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and character not in "。，！？、；：":
			text(line, p + Vector2(0, row * (size + 8)), size, color)
			line = ""
			row += 1
			if row >= max_lines:
				return
		if character != "\n":
			line += character
	text(line, p + Vector2(0, row * (size + 8)), size, color)

func box(rect: Rect2, fill: Color = PANEL, edge: Color = LINE, radius: int = 10) -> void:
	var key: Array = [fill, edge, radius]
	if not style_cache.has(key):
		var created := StyleBoxFlat.new()
		created.bg_color = fill
		created.border_color = edge
		created.set_border_width_all(1)
		created.set_corner_radius_all(radius)
		style_cache[key] = created
	var style: StyleBoxFlat = style_cache[key]
	draw_style_box(style, rect)

func button(rect: Rect2, label: String, action: String, index: int = 0, primary: bool = false, enabled: bool = true) -> void:
	var hover: bool = rect.has_point(get_global_mouse_position()) and enabled
	box(rect, (MINT.lightened(0.12) if hover else MINT) if primary and enabled else (Color("2a4048") if hover else PANEL), MINT if hover or primary and enabled else LINE, 8)
	center(label, rect.get_center() + Vector2(0, 7), 18, BG if primary and enabled else (WHITE if enabled else MUTED), primary)
	if enabled:
		buttons.append({"rect":rect, "action":action, "index":index, "state":game.state})

func scrim() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.035, 0.065, 0.085, 0.91))

func stamp(index: int, p: Vector2, size: Vector2, angle: float = 0, tint: Color = Color.WHITE) -> void:
	var frame: Dictionary = game.utility_atlas.frames[clampi(index, 0, 15)]
	var source := Rect2(frame.region.position + frame.bounds.position, frame.bounds.size)
	draw_set_transform(p, angle)
	draw_texture_rect_region(game.utility_atlas.texture, Rect2(-size / 2, size), source, tint)
	draw_set_transform(Vector2.ZERO)

func shadow(p: Vector2, radius: float = 21) -> void:
	stamp(2, p, Vector2(radius * 2.2, radius * 0.7), 0, Color(1, 1, 1, 0.55))

func animated_fx(row: int, progress: float, p: Vector2, size: Vector2, angle: float = 0, alpha: float = 1.0) -> void:
	var frame: Dictionary = game.vfx_atlas.frames[row * 4 + clampi(int(progress * 4), 0, 3)]
	draw_set_transform(p, angle)
	draw_texture_rect_region(game.vfx_atlas.texture, Rect2(-size / 2, size), frame.region, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)

func sprite(atlas: RefCounted, index: int, p: Vector2, size: float, centered: bool = false, angle: float = 0, tint: Color = Color.WHITE) -> void:
	var frame: Dictionary = atlas.frames[clampi(index, 0, atlas.frames.size() - 1)]
	var factor: float = size / (maxf(frame.bounds.size.x, frame.bounds.size.y) if centered else atlas.row_heights[index / atlas.columns])
	var anchor: Vector2 = frame.bounds.get_center() if centered else frame.anchor
	draw_set_transform(p, angle, Vector2.ONE * factor)
	draw_texture_rect_region(atlas.texture, Rect2(-anchor, frame.region.size), frame.region, tint)
	draw_set_transform(Vector2.ZERO)

func hero(p: Vector2, scale_value: float = 1.0, direction: Vector2 = Vector2.RIGHT, moving: bool = false, tint: Color = Color.WHITE) -> void:
	shadow(p, 20 * scale_value)
	var row: int = (0 if direction.x >= 0 else 2) if absf(direction.x) >= absf(direction.y) else (1 if direction.y < 0 else 3)
	var pose: int = int(game.clock * 9) % 4 if moving else 0
	sprite(game.hero_atlas, row * 4 + pose, p, 67 * scale_value, false, 0, tint)

func knight(p: Vector2, scale_value: float = 1.0, onion: bool = false) -> void:
	shadow(p, 18 * scale_value)
	var index: int = 12 if onion else (5 if game.knight_cooldown > 0.45 else 4)
	sprite(game.cast_atlas, index, p, 68 * scale_value)

func princess(p: Vector2, scale_value: float = 1) -> void:
	shadow(p, 24 * scale_value)
	sprite(game.cast_atlas, 14, p, 92 * scale_value)

func item_icon(id: String, p: Vector2, scale_value: float = 1.0, angle: float = 0) -> void:
	var index: int = 0
	for entry in game.Data.WEAPONS + game.Data.EQUIPMENT:
		if entry.id == id:
			break
		index += 1
	sprite(game.item_atlas, index, p, 48 * scale_value, true, angle)

func npc_art(index: int, p: Vector2, scale_value: float = 1) -> void:
	shadow(p, 18 * scale_value)
	var talking: bool = game.state == "npc" and game.selected_npc == index
	var pose: int = 1 if talking and int(game.clock * 2) % 2 == 0 else 0
	if index == 3:
		sprite(game.basan_atlas, pose, p, 68 * scale_value)
	elif index == 7:
		sprite(game.jiahao_atlas, pose, p, 68 * scale_value)
	else:
		sprite(game.cast_atlas, index * 2 + pose, p, 68 * scale_value)

func enemy_art(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	if enemy.age < 0.8:
		stamp(6, p, Vector2.ONE * (46 + enemy.age * 25), 0, Color(1, 0.65, 0.7, 0.8))
		return
	shadow(p, enemy.radius)
	if enemy.kind == "shark":
		var pose: int = 3 if enemy.charge > 0 or enemy.flash > 0 else (2 if enemy.windup > 0 else int(enemy.age * 4) % 2)
		sprite(game.shark_atlas, pose, p, 120, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE)
	else:
		var row: int = {"slime":0, "ranged":1, "charger":2, "boss":3}[enemy.kind]
		var pose: int = 3 if enemy.flash > 0 else (2 if enemy.windup > 0 or enemy.charge > 0 else int(enemy.age * 5) % 2)
		var height: float = 45 if enemy.kind == "slime" else 54
		if enemy.kind == "boss":
			row = 2 if game.floor_index == 0 else (1 if game.floor_index == 1 else 3)
			height = 110
		sprite(game.enemy_atlas, row * 4 + pose, p, height, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE)
	if enemy.hp < enemy.max_hp:
		var width: float = 64 if game.is_boss(enemy) else 32
		box(Rect2(p.x - width / 2, p.y + 8, width, 4), BG, BG, 2)
		draw_rect(Rect2(p.x - width / 2, p.y + 8, width * maxf(0, enemy.hp / enemy.max_hp), 4), RED)

func tiles(rect: Rect2, index: int, tile_size: int = 128, tint: Color = Color(0.62, 0.66, 0.68)) -> void:
	var frame: Dictionary = game.environment_atlas.frames[index]
	var clip: Rect2 = rect.intersection(visible_world) if surface == "world" else rect
	if not clip.has_area():
		return
	var first := Vector2(rect.position.x + floor((clip.position.x - rect.position.x) / tile_size) * tile_size, rect.position.y + floor((clip.position.y - rect.position.y) / tile_size) * tile_size)
	for y in range(int(first.y), int(clip.end.y) + 1, tile_size):
		for x in range(int(first.x), int(clip.end.x) + 1, tile_size):
			var size := Vector2(minf(tile_size, rect.end.x - x), minf(tile_size, rect.end.y - y))
			if size.x <= 0 or size.y <= 0:
				continue
			var region := Rect2(frame.region.position + Vector2(3, 3), (frame.region.size - Vector2(6, 6)) * size / tile_size)
			draw_texture_rect_region(game.environment_atlas.texture, Rect2(Vector2(x, y), size), region, tint)

func wall_segment(rect: Rect2) -> void:
	if not rect.has_area() or not visible_world.intersects(rect):
		return
	var horizontal: bool = rect.size.x > rect.size.y
	var count: int = maxi(1, ceili((rect.size.x if horizontal else rect.size.y) / 96))
	for i in range(count):
		var segment: Rect2 = rect
		if horizontal:
			segment.position.x += i * rect.size.x / count
			segment.size.x = rect.size.x / count + 1
		else:
			segment.position.y += i * rect.size.y / count
			segment.size.y = rect.size.y / count + 1
		stamp(8 if horizontal else 9, segment.get_center(), segment.size)

func room_walls(room: Dictionary) -> void:
	var rect: Rect2 = room.rect
	var c: Vector2 = room.center
	for direction in range(4):
		var horizontal: bool = direction % 2 == 0
		var first: float = rect.position.x if horizontal else rect.position.y
		var end: float = rect.end.x if horizontal else rect.end.y
		var middle: float = c.x if horizontal else c.y
		var spans: Array[Vector2] = [Vector2(first, end)]
		if room.links[direction] >= 0:
			spans = [Vector2(first, middle - game.Data.CORRIDOR_WIDTH / 2), Vector2(middle + game.Data.CORRIDOR_WIDTH / 2, end)]
		for span in spans:
			if horizontal:
				wall_segment(Rect2(span.x, rect.position.y - 30 if direction == 0 else rect.end.y, span.y - span.x, 30))
			else:
				wall_segment(Rect2(rect.position.x - 30 if direction == 3 else rect.end.x, span.x, 30, span.y - span.x))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		if visible_world.has_point(corner):
			stamp(10, corner, Vector2(36, 42))

func rebuild_geometry() -> void:
	# Retained per-room commands let Godot cull rooms without repainting every floor tile.
	for child in geometry_root.get_children():
		geometry_root.remove_child(child)
		child.queue_free()
	for kind in ["hall", "room"]:
		for entry in game.corridors if kind == "hall" else game.rooms:
			var piece: Node2D = get_script().new()
			piece.surface = "geometry"
			piece.geometry_kind = kind
			piece.geometry = entry
			piece.game = game
			geometry_root.add_child(piece)

func refresh_ui(delta: float) -> void:
	ui_redraw_time -= delta
	if game.state != "playing" or ui_redraw_time <= 0:
		queue_redraw()
		ui_redraw_time = 1.0 / 30.0

func draw_room_geometry(room: Dictionary) -> void:
	tiles(room.rect, game.floor_index)
	room_walls(room)
	for p in [room.rect.position + Vector2(95, 112), room.rect.end - Vector2(95, 20)]:
		sprite(game.environment_atlas, 4 if game.floor_index == 0 else (6 if game.floor_index == 1 else 7), p, 75)

func draw_corridor_geometry(hall: Dictionary) -> void:
	var rect: Rect2 = hall.rect
	tiles(rect, game.floor_index, 128, Color(0.72, 0.74, 0.77))
	if hall.direction == 1:
		wall_segment(Rect2(rect.position + Vector2(64, -28), Vector2(rect.size.x - 128, 28)))
		wall_segment(Rect2(rect.position + Vector2(64, rect.size.y), Vector2(rect.size.x - 128, 28)))
	else:
		wall_segment(Rect2(rect.position + Vector2(-28, 64), Vector2(28, rect.size.y - 128)))
		wall_segment(Rect2(rect.position + Vector2(rect.size.x, 64), Vector2(28, rect.size.y - 128)))

func combat_barriers() -> void:
	# Only a small raster warning remains while a fight seals the passage.
	for rect in game.closed_gates():
		if visible_world.intersects(rect):
			var horizontal: bool = rect.size.x > rect.size.y
			for i in range(4):
				var p: Vector2 = rect.get_center() + (Vector2.RIGHT if horizontal else Vector2.DOWN) * (i - 1.5) * 40
				stamp(4, p, Vector2(36, 22), PI if horizontal else PI / 2, Color(1, 0.55, 0.55, 0.65))

func cover_draw_rect(rect: Rect2) -> Rect2:
	var frame: Dictionary = game.environment_atlas.frames[5 + game.floor_index]
	var width: float = rect.size.x + 8
	var size: Vector2 = frame.bounds.size * width / frame.bounds.size.x
	return Rect2(Vector2(rect.get_center().x - size.x / 2, rect.end.y - size.y), size)

func cover_art(rect: Rect2) -> void:
	var frame: Dictionary = game.environment_atlas.frames[5 + game.floor_index]
	var bounds := Rect2(frame.region.position + frame.bounds.position, frame.bounds.size)
	draw_texture_rect_region(game.environment_atlas.texture, cover_draw_rect(rect), bounds)

func title_screen() -> void:
	micro("YICHUAN / PRINCESS RESCUE", Vector2(68, 55), MINT, 9)
	micro("V 0.4", Vector2(1138, 55), MUTED, 9)
	box(Rect2(68, 105, 180, 30), Color("223a36"), Color("45675b"), 15)
	text("俯视角自动战斗肉鸽", Vector2(82, 126), 16, MINT)
	text("毅川救我", Vector2(63, 222), 74, WHITE, true)
	text("公主抢救计划", Vector2(68, 273), 35, MINT, true)
	text("从杨梓亮手里，救回 ChatGPT 公主。", Vector2(70, 324), 22, MUTED)
	text("01 选择初始武器", Vector2(70, 418), 18, GOLD, true)
	for i in range(4):
		var selected: bool = game.selected_weapon == i
		var rect := Rect2(68 + i * 126, 437, 115, 92)
		box(rect, Color("253e3c") if selected else PANEL, MINT if selected else LINE, 10)
		item_icon(game.Data.WEAPONS[i].id, rect.position + Vector2(57, 33), 0.85)
		center(game.Data.WEAPONS[i].name, rect.position + Vector2(57, 76), 16, MINT if selected else WHITE)
		buttons.append({"rect":rect, "action":"weapon", "index":i, "state":game.state})
	for i in range(3):
		var rect := Rect2(68 + i * 105, 547, 96, 35)
		box(rect, Color("35433e") if game.difficulty == i else PANEL, GOLD if game.difficulty == i else LINE, 6)
		center(game.Data.DIFFICULTIES[i].name, rect.get_center() + Vector2(0, 6), 16, GOLD if game.difficulty == i else MUTED)
		buttons.append({"rect":rect, "action":"difficulty", "index":i, "state":game.state})
	button(Rect2(68, 602, 316, 58), "来了，去救公主  →", "start", 0, true)
	button(Rect2(399, 602, 174, 58), "游玩指南 · F1", "guide")
	# A staged illustration communicates the new perspective before the run.
	box(Rect2(630, 111, 580, 494), Color("1b2b31"), Color("41574e"), 28)
	tiles(Rect2(648, 130, 544, 456), 0, 128)
	sprite(game.environment_atlas, 4, Vector2(718, 246), 88)
	sprite(game.environment_atlas, 5, Vector2(1122, 520), 85)
	stamp(6, Vector2(885, 386), Vector2.ONE * 274, 0, Color(1, 1, 1, 0.22))
	hero(Vector2(869, 418), 2.45, Vector2.RIGHT)
	item_icon("blade", Vector2(1000, 390), 1.8, -0.5 + sin(game.clock) * 0.1)
	item_icon("pistol", Vector2(735, 390), 1.5, -0.3)
	item_icon("wand", Vector2(920, 500), 1.4, sin(game.clock) * 0.1)
	princess(Vector2(1100, 242), 0.8)
	box(Rect2(1018, 134, 166, 28), Color("2c403b"), MINT, 14)
	center("救回 ChatGPT 公主", Vector2(1101, 154), 14, MINT)
	for i in range(3):
		stamp(7, Vector2(744 + i * 124, 536), Vector2.ONE * 13)
	micro("MOVE. AUTO ATTACK. FUSE. RESCUE.", Vector2(667, 577), MUTED, 8)
	text("随机地牢", Vector2(654, 645), 20, WHITE, true)
	text("六武器构筑", Vector2(842, 645), 20, WHITE, true)
	text("同装合并", Vector2(1064, 645), 20, WHITE, true)
	draw_line(Vector2(68, 685), Vector2(1210, 685), LINE)
	text("WASD 移动 / 自动攻击 / 空格冲刺", Vector2(68, 708), 14, MUTED)
	text("最高累计积分 %d  ·  通关层数 %d / 3" % [game.best_score, game.best_floor], Vector2(884, 708), 14, MUTED)

func arena() -> void:
	var player_p: Vector2 = game.render_position(game.player, game.previous_player)
	combat_barriers()
	for room in game.rooms:
		if not visible_world.intersects(room.rect.grow(140)):
			continue
		if room.cleared:
			terminal(room)
		if room.type == "npc" and room.npc >= 0:
			var p: Vector2 = room.center + Vector2(-112, 0)
			npc_art(room.npc, p)
			center(game.Data.NPCS[room.npc].name, p + Vector2(0, 22), 14, game.Data.NPCS[room.npc].color, true)
			if room.id == game.room_id and game.player.distance_to(p) < 72:
				text("E", p + Vector2(-5, -80), 17, WHITE, true)
	for drop in game.drops:
		stamp(7, drop.p, Vector2.ONE * 18)
	for enemy in game.enemies:
		if enemy.windup > 0:
			var aim: Vector2 = enemy.aim
			for i in range(1, 5):
				var p: Vector2 = enemy.p + aim * i * 65
				if not game.line_clear(enemy.p, p):
					break
				stamp(4, p, Vector2(62, 27), aim.angle(), Color(1, 1, 1, 0.3 + enemy.windup * 0.35))
			if game.is_boss(enemy):
				stamp(6, enemy.p, Vector2.ONE * 140, game.clock * 0.4, Color(1, 0.6, 0.7, 0.65))
	var actors: Array[Dictionary] = []
	for enemy in game.enemies:
		var drawn: Dictionary = enemy.duplicate()
		drawn.p = game.render_position(enemy.p, enemy.get("previous_p", enemy.p))
		actors.append(drawn)
	actors.append({"kind":"hero", "p":player_p})
	for rect in game.obstacles:
		if visible_world.intersects(rect.grow(50)):
			actors.append({"kind":"cover", "p":rect.end, "rect":rect})
	if game.knight_active:
		actors.append({"kind":"knight", "p":game.render_position(game.knight, game.previous_knight)})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.p.y < b.p.y)
	for actor in actors:
		if actor.kind == "hero":
			# The silhouette remains visible during damage immunity.
			hero(actor.p, 0.9, game.facing, game.player_moving, Color(1, 0.8, 0.8) if game.invulnerable > 0 and int(game.clock * 16) % 2 == 0 else Color.WHITE)
			if game.shield_time > 0:
				stamp(5, player_p + Vector2(0, -25), Vector2.ONE * 90, 0, Color(1, 1, 1, 0.8))
		elif actor.kind == "cover":
			shadow(actor.p - Vector2(actor.rect.size.x / 2, 0), actor.rect.size.x * 0.6)
			cover_art(actor.rect)
		elif actor.kind == "knight":
			knight(actor.p, 0.9)
		else:
			enemy_art(actor)
	for i in range(game.weapons.size()):
		var weapon: Dictionary = game.weapons[i]
		var angle: float = TAU * i / maxi(1, game.weapons.size()) + game.clock * 0.16
		var recoil: float = float(weapon.get("recoil", 0.0)) / 0.16
		var p: Vector2 = player_p + Vector2.from_angle(angle) * 36 + Vector2(0, -22) - weapon.aim * recoil * 7
		item_icon(weapon.id, p, 0.57, weapon.aim.angle() + PI / 4 - recoil * 0.16)
	for shot in game.projectiles:
		var index: int = 0 if shot.friendly else (13 if game.floor_index == 2 else 1)
		stamp(index, game.render_position(shot.p, shot.get("previous_p", shot.p)) + Vector2(0, -16), Vector2(26, 12) if shot.friendly else Vector2(29, 24), shot.velocity.angle())
	for effect in game.effects:
		var progress: float = clampf(1.0 - effect.life / effect.max_life, 0, 0.999)
		var alpha: float = minf(1, effect.life / effect.max_life * 2)
		var direction: Vector2 = (effect.b - effect.a).normalized()
		var p: Vector2 = effect.a + Vector2(0, -18)
		match effect.kind:
			"slash": animated_fx(0, progress, p + direction * effect.size * 0.4, Vector2.ONE * effect.size * 1.6, direction.angle(), alpha)
			"thrust", "beam":
				var distance: float = maxf(32, effect.a.distance_to(effect.b))
				animated_fx(3, progress, (effect.a + effect.b) / 2 + Vector2(0, -18), Vector2(distance * 1.4, 66), direction.angle(), alpha)
			"impact": animated_fx(1, progress, effect.a, Vector2.ONE * effect.size, 0, alpha)
			"dash": animated_fx(3, progress, p - direction * 25, Vector2(effect.size * 1.6, effect.size), direction.angle(), alpha)
			"muzzle": stamp(3, p + direction * 12, Vector2(34, 26), direction.angle(), alpha_tint(alpha))
			"dust": stamp(14, effect.a, Vector2.ONE * effect.size * (0.6 + progress), 0, alpha_tint(alpha * 0.4))
			_: animated_fx(2, progress, p, Vector2.ONE * maxf(60, effect.size), 0, alpha)
	for entry in game.texts:
		center(entry.text, entry.p, 17, Color(entry.color, minf(1, entry.life * 2)), true)
	if game.speech_time > 0:
		center(game.speech, player_p + Vector2(0, -82), 16, WHITE, true)

func alpha_tint(alpha: float) -> Color:
	return Color(1, 1, 1, alpha)

func terminal(room: Dictionary) -> void:
	if room.type not in ["shop", "treasure", "rest", "boss"] and not room.get("reward_shop", false):
		return
	var p: Vector2 = room.center
	var label: String = "E 补给"
	var prop: int = 10
	match room.type:
		"boss":
			label = "E 技能提升"
			stamp(6, p, Vector2.ONE * 96, game.clock * 0.2)
			prop = -1
		"treasure":
			label = "已领取" if room.used else "E 宝箱"
			prop = 9 if room.used else 8
		"rest":
			label = "已休息" if room.used else "E 休息"
			prop = 11
		"shop", "combat", "elite": label = "E 商店"
	if prop >= 0:
		shadow(p + Vector2(0, 10), 30)
		sprite(game.environment_atlas, prop, p + Vector2(0, 6), 66)
	if room.id == game.room_id and game.player.distance_to(p) < 90:
		center(label, p + Vector2(0, 32), 14, MINT)

func minimap_layout() -> Dictionary:
	var panel := Rect2(1062, 76, 194, 154)
	if game.rooms.is_empty():
		return {"panel":panel, "rooms":[], "halls":[], "player":panel.get_center()}
	var bounds: Rect2 = game.rooms[0].rect
	for room in game.rooms:
		bounds = bounds.merge(room.rect)
	var inner: Rect2 = panel.grow(-12)
	var scale_value: float = minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
	var offset: Vector2 = inner.get_center() - bounds.get_center() * scale_value
	var mapped_rooms: Array[Dictionary] = []
	for room in game.rooms:
		var status: String = "visited" if room.visited else "unvisited"
		if room.id == game.room_id and room.rect.has_point(game.player):
			status = "current"
		mapped_rooms.append({"id":room.id, "rect":Rect2(offset + room.rect.position * scale_value, room.rect.size * scale_value), "status":status})
	var halls: Array[Dictionary] = []
	for hall in game.corridors:
		halls.append({"rect":Rect2(offset + hall.rect.position * scale_value, hall.rect.size * scale_value), "visited":game.rooms[hall.a].visited and game.rooms[hall.b].visited})
	return {"panel":panel, "rooms":mapped_rooms, "halls":halls, "player":offset + game.player * scale_value}

func minimap() -> void:
	var layout: Dictionary = minimap_layout()
	box(layout.panel, Color(0.055, 0.09, 0.12, 0.9), LINE, 8)
	for hall in layout.halls:
		draw_rect(hall.rect, Color("4b7969") if hall.visited else Color("34444d"))
	for room in layout.rooms:
		var color: Color = {"unvisited":Color("45535d"), "visited":MINT.darkened(0.35), "current":GOLD}[room.status]
		draw_rect(room.rect, color)
		draw_rect(room.rect, color.lightened(0.2), false, 1)
	draw_circle(layout.player, 3.5, BG)
	draw_circle(layout.player, 2, WHITE)

func hud() -> void:
	if game.rooms.is_empty():
		return
	minimap()
	var room: Dictionary = game.current_room()
	box(Rect2(24, 19, 225, 39), Color(0.055, 0.09, 0.12, 0.88), Color("485561"), 10)
	item_icon("heart", Vector2(43, 38), 0.44)
	draw_rect(Rect2(64, 31, 116, 12), Color("432e39"))
	draw_rect(Rect2(64, 31, 116 * clampf(game.health / game.max_health(), 0, 1), 12), RED)
	text("%d/%d" % [ceili(game.health), int(game.max_health())], Vector2(189, 43), 13, WHITE)
	box(Rect2(1093, 19, 163, 39), Color(0.055, 0.09, 0.12, 0.88), Color("6d5942"), 10)
	draw_circle(Vector2(1113, 38), 5, GOLD)
	text(str(game.points), Vector2(1131, 46), 24, GOLD, true)
	var label: String = "%d-3" % (game.floor_index + 1)
	if not room.cleared:
		label += "   %d/%d" % [game.wave, game.wave_total]
	box(Rect2(586, 18, 108, 28), Color(0.055, 0.09, 0.12, 0.8), LINE, 9)
	center(label, Vector2(640, 38), 15, WHITE)
	for i in range(game.weapons.size()):
		var entry: Dictionary = game.weapons[i]
		var rect := Rect2(24 + i * 51, 649, 44, 47)
		box(rect, Color(0.055, 0.09, 0.12, 0.83), game.Data.TIER_COLORS[entry.tier - 1].darkened(0.35), 7)
		item_icon(entry.id, rect.get_center() - Vector2(0, 3), 0.67)
		for pip in range(entry.tier):
			draw_circle(rect.position + Vector2(14 + pip * 5, 41), 1.6, game.Data.TIER_COLORS[entry.tier - 1])
	for i in range(game.equipment.size()):
		var entry: Dictionary = game.equipment[i]
		var rect := Rect2(1212 - i * 51, 649, 44, 47)
		box(rect, Color(0.055, 0.09, 0.12, 0.83), game.Data.TIER_COLORS[entry.tier - 1].darkened(0.35), 7)
		item_icon(entry.id, rect.get_center() - Vector2(0, 3), 0.62)
		for pip in range(entry.tier):
			draw_circle(rect.position + Vector2(14 + pip * 5, 41), 1.6, game.Data.TIER_COLORS[entry.tier - 1])
	if game.onion_skill:
		box(Rect2(343, 652, 48, 42), Color(0.055, 0.09, 0.12, 0.83), GOLD, 9)
		center("Q" if game.onion_cooldown <= 0 else str(ceili(game.onion_cooldown)), Vector2(367, 680), 20, GOLD)
	if game.assisted:
		micro("DEBUG", Vector2(267, 42), RED, 8)
	for enemy in game.enemies:
		if game.is_boss(enemy):
			box(Rect2(390, 65, 500, 27), Color(0.1, 0.06, 0.1, 0.88), Color("8c545e"), 7)
			draw_rect(Rect2(398, 85, 484 * maxf(0, enemy.hp / enemy.max_hp), 3), RED)
			center(game.boss_name(enemy), Vector2(640, 81), 14, WHITE)
			break

func story() -> void:
	var line: Dictionary = game.dialogue()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.06, 0.08, 0.38))
	box(Rect2(104, 445, 1072, 210), Color("172c32"), MINT, 18)
	if line.speaker.contains("公主"):
		princess(Vector2(201, 603), 1.2)
	elif line.speaker.contains("杨梓亮"):
		sprite(game.enemy_atlas, 12, Vector2(201, 604), 128)
	else:
		hero(Vector2(201, 603), 1.4)
	text(line.speaker, Vector2(287, 490), 23, MINT, true)
	paragraph(line.line, Vector2(287, 534), 806, 22, WHITE, 3)
	button(Rect2(921, 602, 219, 36), "继续 · Enter / E", "dialogue", 0, true)
	text("Esc 跳过这段剧情", Vector2(288, 629), 14, MUTED)

func shop() -> void:
	scrim()
	box(Rect2(83, 63, 1114, 580), PANEL, LINE, 18)
	micro("SUPPLY / BUILD YOUR LOADOUT", Vector2(117, 100), GOLD)
	text("战后补给" if game.current_room().get("reward_shop", false) else "积分补给站", Vector2(116, 143), 34, WHITE, true)
	text("余额 %d 积分" % game.points, Vector2(914, 140), 25, GOLD, true)
	text("同名同品质可合并 · 满栏时自动合并 · 每类 6 个栏位", Vector2(117, 179), 17, MUTED)
	if game.current_room().type == "shop":
		text("商店房专享 85 折", Vector2(942, 179), 16, MINT)
	for i in range(game.stock.size()):
		var offer: Dictionary = game.stock[i]
		var spec: Dictionary = game.Data.item(offer.id)
		var color: Color = game.Data.TIER_COLORS[offer.tier - 1]
		var rect := Rect2(116 + i * 266, 208, 250, 310)
		box(rect, Color("13232c"), color.darkened(0.4), 12)
		text("%d / %s · %s" % [i + 1, game.Data.TIER_NAMES[offer.tier - 1], "武器" if spec.kind == "weapon" else "装备"], rect.position + Vector2(18, 30), 15, color)
		draw_circle(rect.position + Vector2(125, 92), 43, Color(spec.color, 0.08))
		item_icon(offer.id, rect.position + Vector2(125, 92), 1.5)
		text(spec.name, rect.position + Vector2(18, 164), 24, WHITE, true)
		text(spec.tag, rect.position + Vector2(18, 194), 16, color)
		paragraph(spec.desc, rect.position + Vector2(18, 226), 214, 15, MUTED, 2)
		button(Rect2(rect.position + Vector2(16, 259), Vector2(218, 35)), "已购入" if offer.sold else "购买 · %d 积分" % game.shop_price(offer), "buy", i, not offer.sold, not offer.sold)
	button(Rect2(117, 547, 270, 49), "首次免费刷新 · R" if game.refresh_price() == 0 else "刷新 · %d 积分 / R" % game.refresh_price(), "refresh", 0, game.refresh_price() == 0)
	button(Rect2(407, 547, 270, 49), "整理背包 / 合并 · Tab", "inventory")
	button(Rect2(884, 547, 280, 49), "继续探索 · Esc", "close_shop", 0, true)

func skill_reward() -> void:
	scrim()
	text("关卡通关 · 技能提升", Vector2(148, 144), 38, WHITE, true)
	text("选择一项，本局持续生效", Vector2(150, 184), 20, MINT)
	for i in range(game.skill_offers.size()):
		var spec: Dictionary = game.skill_offers[i]
		var level: int = game.skill_level(spec.id)
		var rect := Rect2(148 + i * 336, 223, 312, 340)
		box(rect, PANEL, MINT.darkened(0.35), 14)
		item_icon(spec.icon, rect.position + Vector2(156, 78), 1.8)
		center(spec.name, rect.position + Vector2(156, 156), 28, WHITE, true)
		center("Lv.%d → Lv.%d" % [level, level + 1], rect.position + Vector2(156, 190), 18, GOLD)
		paragraph(spec.desc, rect.position + Vector2(24, 228), 264, 18, MUTED, 3)
		button(Rect2(rect.position + Vector2(24, 281), Vector2(264, 39)), "选择 · %d" % (i + 1), "skill_choice", i, true)
	center("选择后" + ("救回公主" if game.floor_index == 2 else "进入下一层"), Vector2(640, 618), 18, MUTED)

func inventory() -> void:
	scrim()
	box(Rect2(64, 35, 1152, 620), PANEL, LINE, 17)
	micro("LOADOUT / TWO OF A KIND", Vector2(94, 72), MINT)
	text("背包", Vector2(94, 112), 32, WHITE, true)
	text("同名 + 同品质 ×2 → 高一级 · 普通 → 精良 → 史诗 → 传说", Vector2(360, 109), 17, MINT)
	button(Rect2(1050, 61, 132, 41), "返回 · Esc", "inventory")
	button(Rect2(1050, 113, 132, 32), "返回标题", "title")
	text("伤害 +%d%%  ·  攻速 +%d%%  ·  减伤 %d%%  ·  移速 %d" % [int((game.damage_scale() - 1) * 100), int((game.attack_speed() - 1) * 100), int(minf(0.65, game.equipment_stat("vest") * 0.12) * 100), int(game.move_speed())], Vector2(94, 147), 16, MUTED)
	for row in range(2):
		var kind: String = "weapon" if row == 0 else "equipment"
		var entries: Array = game.weapons if row == 0 else game.equipment
		text(("武器" if row == 0 else "装备") + "  %d / 6" % entries.size(), Vector2(94, 183 + row * 225), 17, GOLD, true)
		for i in range(6):
			var rect := Rect2(94 + i * 184, 198 + row * 225, 171, 194)
			box(rect, Color("13222c"), LINE, 9)
			if i >= entries.size():
				center("空栏位", rect.get_center(), 17, Color("566c77"))
				continue
			var entry: Dictionary = entries[i]
			var spec: Dictionary = game.Data.item(entry.id)
			var color: Color = game.Data.TIER_COLORS[entry.tier - 1]
			text(game.Data.TIER_NAMES[entry.tier - 1] + " " + "★".repeat(entry.tier), rect.position + Vector2(12, 24), 13, color)
			item_icon(entry.id, rect.position + Vector2(85, 59), 0.85)
			center(spec.name, rect.position + Vector2(85, 104), 19, WHITE, true)
			var can_fuse: bool = game.fusion_pair(kind, i) >= 0
			button(Rect2(rect.position + Vector2(10, 117), Vector2(151, 29)), "合并升级 ↑" if can_fuse else ("已达传说" if entry.tier == 4 else "等待相同物品"), "fuse_" + kind, i, can_fuse, can_fuse)
			button(Rect2(rect.position + Vector2(10, 153), Vector2(151, 29)), "出售 +%d" % game.sell_price(entry), "sell_" + kind, i, false, row != 0 or entries.size() > 1)
	var learned: PackedStringArray = []
	for spec in game.Data.SKILLS:
		if game.skill_level(spec.id) > 0:
			learned.append("%s Lv.%d" % [spec.name, game.skill_level(spec.id)])
	if not learned.is_empty():
		text("技能：" + "  ·  ".join(learned), Vector2(95, 641), 15, MINT)

func npc_panel() -> void:
	scrim()
	var spec: Dictionary = game.Data.NPCS[game.selected_npc]
	var used: bool = game.current_room().get("npc_used", false) and spec.id != "coin"
	box(Rect2(228, 133, 824, 471), PANEL, spec.color.darkened(0.3), 18)
	micro("ENCOUNTER / A FRIEND ON THE ROAD", Vector2(266, 176), spec.color)
	npc_art(game.selected_npc, Vector2(365, 416), 2.1)
	text(spec.name, Vector2(505, 239), 34, WHITE, true)
	text(spec.role, Vector2(505, 273), 18, spec.color)
	paragraph("「" + spec.quote + "」", Vector2(502, 321), 480, 23, spec.color, 2)
	paragraph("这次已经帮过你了。继续前进，公主还在等你。" if used else spec.offer, Vector2(505, 392), 469, 19, MUTED, 3)
	button(Rect2(504, 493, 493, 45), "谢谢，下次见" if used else spec.button, "npc_accept", 0, true)
	button(Rect2(504, 548, 493, 36), "先继续探索 · Esc", "npc_close")

func ending_panel() -> void:
	scrim()
	var won: bool = game.state == "won"
	var dead: bool = game.state == "dead"
	box(Rect2(341, 79, 598, 556), PANEL, MINT if won else LINE, 18)
	micro("PRINCESS RESCUED" if won else ("RUN ENDED" if dead else "TAKE A BREAK"), Vector2(385, 124), MINT if won else GOLD)
	if won:
		hero(Vector2(568, 281), 1.3)
		princess(Vector2(706, 281), 1.05)
	else:
		hero(Vector2(640, 281), 1.6)
	center("公主救回来了！" if won else ("哦豁，完蛋" if dead else "断点休息一下"), Vector2(640, 341), 37, WHITE, true)
	center("击败策划杨梓亮，今晚准时下班。" if won else ("坏啦。换套武器，再来救公主。" if dead else "公主还在等你，准备好就继续。"), Vector2(640, 379), 18, MUTED)
	center("累计 %d 积分  /  %d 击杀  /  %d 房间" % [game.earned, game.kills, game.cleared_count], Vector2(640, 425), 20, GOLD)
	if game.assisted:
		center("本局使用调试辅助，不写入最高纪录", Vector2(640, 455), 14, RED)
	button(Rect2(410, 482, 460, 49), "再来一局 · R" if won or dead else "继续探索 · Enter", "restart" if won or dead else "resume", 0, true)
	button(Rect2(410, 547, 460, 43), "返回标题", "title")

func guide() -> void:
	scrim()
	box(Rect2(124, 63, 1032, 584), PANEL, LINE, 18)
	micro("FIELD GUIDE / TOP-DOWN ROGUELITE", Vector2(163, 106), MINT)
	text("救公主行动手册", Vector2(162, 155), 36, WHITE, true)
	button(Rect2(956, 93, 160, 41), "返回 · Esc", "close_guide")
	var lines: Array[String] = [
		"WASD / 方向键：四向移动　　空格 / Shift：无敌冲刺　　攻击自动瞄准并释放。",
		"大小房间通过真实走廊连接，镜头跟随移动。走进战斗房会封路，清空后可沿原路返回。",
		"每间怪物房清空后自动进入商店，两张武器、两张装备；首刷免费，之后付费。",
		"商店房打 85 折；嘉豪可改装武器；精英房最后一波由大鲨鱼守关。",
		"Esc 暂停并整理背包：两件同名同品质合并一级，最高传说。每类最多装 6 件。",
		"每层 NPC 房与商店房合计随机 0–1 间，其余以战斗房为主；罗德委托在下一场战斗触发。",
		"海德骑士在当前层跟随作战，换房仍跟随，进入下一层后离队。哈少解锁 Q 护盾。",
		"击败关底首领后，按 1–3 选择技能提升，再进入下一层；最终救回 ChatGPT 公主。",
		"Esc / Tab 背包与暂停　F1 手册　M 静音　F11 全屏　Home 调试选项。"
	]
	for i in range(lines.size()):
		text("%02d" % (i + 1), Vector2(164, 209 + i * 43), 15, MINT)
		text(lines[i], Vector2(202, 209 + i * 43), 17, WHITE if i % 2 == 0 else MUTED)
	text("本局积分和构筑在重开后重置，最高累计积分与通关层数独立保存。", Vector2(164, 617), 16, GOLD)

func cheats() -> void:
	scrim()
	box(Rect2(365, 145, 550, 414), PANEL, LINE, 15)
	micro("DEBUG / ASSISTED RUN", Vector2(404, 187), RED)
	text("毅川的调试工具", Vector2(404, 230), 30, WHITE, true)
	button(Rect2(404, 267, 472, 55), "1 · 无敌    " + ("已开启" if game.cheat_invincible else "已关闭"), "cheat", 0, game.cheat_invincible)
	button(Rect2(404, 341, 472, 55), "2 · 一击必杀    " + ("已开启" if game.cheat_one_hit else "已关闭"), "cheat", 1, game.cheat_one_hit)
	text("开启过任意辅助后，本局不会写入普通纪录。", Vector2(404, 438), 16, MUTED)
	button(Rect2(404, 474, 472, 44), "返回 · Home / Esc", "close_cheats")

func click(p: Vector2) -> void:
	if surface == "world":
		if overlay != null:
			overlay.click(p)
		return
	for entry in buttons.duplicate():
		if entry.state != game.state or not entry.rect.has_point(p):
			continue
		match entry.action:
			"weapon": game.selected_weapon = entry.index
			"difficulty": game.difficulty = entry.index
			"start", "restart": game.start_run()
			"title": game.state = "title"
			"guide":
				game.return_state = game.state
				game.state = "guide"
			"close_guide", "close_map", "close_cheats": game.state = game.return_state
			"dialogue": game.advance_dialogue()
			"inventory": game.toggle_inventory()
			"map":
				if game.state == "playing":
					game.return_state = game.state
					game.state = "map"
			"buy": game.buy(entry.index)
			"refresh": game.refresh_shop()
			"close_shop": game.leave_shop()
			"skill_choice": game.choose_skill(entry.index)
			"fuse_weapon": game.fuse("weapon", entry.index)
			"fuse_equipment": game.fuse("equipment", entry.index)
			"sell_weapon": game.sell("weapon", entry.index)
			"sell_equipment": game.sell("equipment", entry.index)
			"npc_accept":
				if game.current_room().get("npc_used", false) and game.Data.NPCS[game.selected_npc].id != "coin":
					game.state = "playing"
				else:
					game.accept_npc()
			"npc_close", "resume": game.state = "playing"
			"cheat": game.toggle_cheat(entry.index)
		break
