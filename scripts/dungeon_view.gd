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
var equipment_page: int = 0
const EQUIPMENT_COLUMNS: int = 10
const EQUIPMENT_PAGE_SIZE: int = 50
const STAT_ICONS := {
	"health":"heart", "damage":"hammer", "melee_damage":"blade", "ranged_damage":"pistol", "magic_damage":"wand",
	"attack_speed":"coffee", "crit_chance":"scope", "crit_damage":"crit_lens", "dodge":"feather", "armor":"vest",
	"incoming_damage":"glass_trophy", "move_speed":"boots", "regen":"medkit", "lifesteal":"fang",
	"reach":"glasses", "pickup_radius":"magnet", "dash_recovery":"sprinter"
}
var item_slots: Array[Dictionary] = []
var inventory_focus: Dictionary = {}
var item_context: Dictionary = {}
var pointer_position := Vector2(-1000, -1000)
const BG := Color("101922")
const PANEL := Color("182630")
const LINE := Color("34464f")
const WHITE := Color("f3ecd8")
const MUTED := Color("93a8ad")
const MINT := Color("85e0b9")
const GOLD := Color("ffca80")
const RED := Color("ff8c96")
const PURPLE := Color("bda1ed")
const WALL_INSET := 18.0
const YANG_PEAK_HEIGHT := 173.0
const YANG_LASER_GLASSES := Vector2(1280, 924)
const YANG_LASER_TEXTURE := preload("res://assets/generated/dungeon/yang-laser.png")
const YANG_LASER_SOURCE_X := 85.0
const YANG_LASER_FRAMES: Array[Rect2] = [
	Rect2(0, 0, 2160, 166), Rect2(0, 186, 2160, 182),
	Rect2(0, 381, 2160, 186), Rect2(0, 568, 2160, 152)
]

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
	item_slots.clear()
	if game.state != "inventory":
		inventory_focus.clear()
		item_context.clear()
	if game.state == "title" or (game.state == "guide" and game.return_state == "title"):
		draw_rect(Rect2(0, 0, 1280, 720), BG)
		title_screen()
	else:
		hud()
	if game.state not in ["title", "playing"]:
		buttons.clear()
	match game.state:
		"dialogue": story()
		"ruoyu_unseal": ruoyu_unseal()
		"shop": shop()
		"skill": skill_reward()
		"inventory", "confirm_title": inventory()
		"treasure": treasure_reward()
		"npc": npc_panel()
		"paused", "dead", "won": ending_panel()
		"guide": guide()
		"cheats": cheats()
	if game.pad.active and game.state not in ["playing", "ruoyu_unseal"]:
		var focus: Dictionary = game.pad.focused(menu_entries(), menu_context())
		if not focus.is_empty():
			draw_rect(focus.rect.grow(3), GOLD, false, 2.0)
			if game.state not in ["title", "dialogue", "inventory"]:
				var hint: String = "方向键选择 · {A} 确认"
				if game.state not in ["skill", "dead", "won"]:
					hint += " · {B} 返回"
				center(game.pad.text("", hint), Vector2(640, 666), 14, MUTED)
	if game.message_time > 0 and game.state not in ["title", "ruoyu_unseal"]:
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

func speech_bubble_rect(anchor: Vector2, size: Vector2, bounds: Rect2, gap: float) -> Rect2:
	var left: float = anchor.x - absf(gap) - size.x
	var right: float = anchor.x + absf(gap)
	var place_right: bool = gap > 0.0
	if place_right and right + size.x > bounds.end.x:
		place_right = left < bounds.position.x and anchor.x < bounds.get_center().x
	elif not place_right and left < bounds.position.x:
		place_right = right + size.x <= bounds.end.x or anchor.x < bounds.get_center().x
	var position := Vector2(right if place_right else left, anchor.y - size.y / 2)
	return Rect2(position.clamp(bounds.position, bounds.end - size), size)

func speech_bubble(value: String, anchor: Vector2, bounds: Rect2, gap: float, accent: Color, max_width: float = 270.0, font_size: int = 18) -> void:
	var font: Font = game.font
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var text_width: float = minf(ceilf(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x), minf(max_width, bounds.size.x - 24.0))
	var text_height: float = font.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, -1, flags).y
	var rect: Rect2 = speech_bubble_rect(anchor, Vector2(text_width + 24.0, ceilf(text_height) + 14.0), bounds, gap)
	var fill := Color("182630")
	box(rect, fill, accent, 8)
	var right: bool = rect.get_center().x > anchor.x
	var side: float = 1.0 if right else -1.0
	var edge_x: float = rect.position.x if right else rect.end.x
	var y: float = clampf(anchor.y, rect.position.y + 12.0, rect.end.y - 12.0)
	var tail := PackedVector2Array([Vector2(edge_x + side, y - 6.0), Vector2(edge_x - side * 9.0, y), Vector2(edge_x + side, y + 6.0)])
	draw_colored_polygon(tail, fill)
	draw_polyline(tail, accent, 1.0, true)
	draw_multiline_string(font, rect.position + Vector2(12, 7 + font.get_ascent(font_size)), value, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, -1, WHITE, flags)

func button(rect: Rect2, label: String, action: String, index: int = 0, primary: bool = false, enabled: bool = true) -> void:
	var hover: bool = not game.pad.active and rect.has_point(get_global_mouse_position()) and enabled
	box(rect, (MINT.lightened(0.12) if hover else MINT) if primary and enabled else (Color("2a4048") if hover else PANEL), MINT if hover or primary and enabled else LINE, 8)
	center(label, rect.get_center() + Vector2(0, 7), 18, BG if primary and enabled else (WHITE if enabled else MUTED), primary)
	if enabled:
		buttons.append({"rect":rect, "action":action, "index":index, "state":game.state, "primary":primary})

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

func yang_laser_art(origin: Vector2, endpoint: Vector2, frame: int, height: float, opacity: float) -> void:
	var ray: Vector2 = endpoint - origin
	if ray.is_zero_approx():
		return
	var region: Rect2 = YANG_LASER_FRAMES[frame]
	var scale_x: float = ray.length() / (region.size.x - YANG_LASER_SOURCE_X)
	# Align the source flare with the aim origin and the far edge with the blocked endpoint.
	var rect := Rect2(-YANG_LASER_SOURCE_X * scale_x, -height / 2.0, region.size.x * scale_x, height)
	draw_set_transform(origin, ray.angle())
	draw_texture_rect_region(YANG_LASER_TEXTURE, rect, region, alpha_tint(opacity))
	draw_set_transform(Vector2.ZERO)

func sprite(atlas: RefCounted, index: int, p: Vector2, size: float, centered: bool = false, angle: float = 0, tint: Color = Color.WHITE, facing: float = 1.0) -> void:
	var frame: Dictionary = atlas.frames[clampi(index, 0, atlas.frames.size() - 1)]
	var factor: float = size / (maxf(frame.bounds.size.x, frame.bounds.size.y) if centered else atlas.row_heights[index / atlas.columns])
	var anchor: Vector2 = frame.bounds.get_center() if centered else frame.anchor
	draw_set_transform(p, angle, Vector2(facing, 1) * factor)
	draw_texture_rect_region(atlas.texture, Rect2(-anchor, frame.region.size), frame.region, tint)
	draw_set_transform(Vector2.ZERO)

func hero(p: Vector2, scale_value: float = 1.0, direction: Vector2 = Vector2.RIGHT, moving: bool = false, tint: Color = Color.WHITE) -> void:
	shadow(p, 20 * scale_value)
	var row: int = (0 if direction.x >= 0 else 2) if absf(direction.x) >= absf(direction.y) else (1 if direction.y < 0 else 3)
	var pose: int = int(game.clock * 9) % 4 if moving else 0
	sprite(game.hero_atlas, row * 4 + pose, p, 67 * scale_value, false, 0, tint)

func knight(p: Vector2, scale_value: float = 1.0, onion: bool = false) -> void:
	shadow(p, 18 * scale_value)
	if onion:
		sprite(game.cast_atlas, 12, p, 68 * scale_value)
	else:
		sprite(game.heide_atlas, game.knight_frame(), p, 68 * scale_value)

func princess(p: Vector2, scale_value: float = 1) -> void:
	shadow(p, 24 * scale_value)
	sprite(game.cast_atlas, 14, p, 92 * scale_value)

func item_icon(id: String, p: Vector2, scale_value: float = 1.0, angle: float = 0) -> void:
	var spec: Dictionary = game.Data.item(id)
	if spec.is_empty():
		return
	if spec.has("art_frame"):
		sprite(game.workplace_item_atlas, spec.art_frame, p, 48 * scale_value, true, angle)
		return
	if game.item_icons.has(id):
		sprite(game.item_icons[id], 0, p, 48 * scale_value, true, angle)
		return
	var index: int = game.Data.ITEM_ICONS.find(id)
	sprite(game.item_atlas, maxi(0, index), p, 48 * scale_value, true, angle)

func npc_art(index: int, p: Vector2, scale_value: float = 1) -> void:
	shadow(p, 18 * scale_value)
	var talking: bool = game.state == "npc" and game.selected_npc == index
	var pose: int = 1 if talking and int(game.clock * 2) % 2 == 0 else 0
	if index == 2:
		sprite(game.heide_atlas, 24 + int(game.clock * 2) % 2, p, 68 * scale_value)
	elif index == 3:
		sprite(game.basan_atlas, pose, p, 68 * scale_value)
	elif index == 7:
		sprite(game.jiahao_atlas, pose, p, 68 * scale_value)
	else:
		# The first pair in the original sheet belonged to the former Ruoyu NPC.
		sprite(game.cast_atlas, (index + 1) * 2 + pose, p, 68 * scale_value)

func enemy_action_frame(enemy: Dictionary, frames_per_enemy: int = 8) -> int:
	var base: int = enemy.art * frames_per_enemy
	if enemy.windup > 0:
		return base + 2 + posmod(enemy.attack, enemy.moves.size()) * 2
	if enemy.attack_pose_time > 0 or enemy.charge > 0 or enemy.guard_time > 0:
		return base + 3 + posmod(enemy.attack - 1, enemy.moves.size()) * 2
	if enemy.moving:
		var alternate: int = 7 if enemy.kind in ["cone_mimic", "patrol_drone"] else 0
		return base + (1 if int(enemy.age * 7) % 2 == 0 else alternate)
	return base

func ruoyu_pounce_frame(enemy: Dictionary) -> int:
	var base: int = enemy.phase * 4
	if enemy.windup > 0.0 and game.next_enemy_move(enemy) == "pounce":
		return base
	if enemy.pounce_time > 0.0:
		return base + 1
	if enemy.pounce_recovery > 0.0:
		return base + (2 if enemy.pounce_recovery > game.Data.RUOYU_POUNCE_RECOVERY * 0.55 else 3)
	return -1

func yang_action_frame(enemy: Dictionary) -> int:
	if enemy.phase == 0:
		if enemy.castle_shield:
			if enemy.windup > 0.0:
				return 1
			return 2 if enemy.attack_pose_time > 0.0 else 0
		if enemy.castle_weak_time > 0.0:
			return 3
		if enemy.windup > 0.0:
			return 6
		if enemy.attack_pose_time > 0.0:
			return 7
		return 4 + (int(enemy.age * 7) % 2 if enemy.moving else 0)
	if enemy.windup > 0.0:
		return 2 + posmod(enemy.attack, enemy.moves.size()) * 2
	if enemy.attack_pose_time > 0.0:
		return 3 + posmod(enemy.attack - 1, enemy.moves.size()) * 2
	return int(enemy.age * 7) % 2 if enemy.moving else 0

func yamada_action_frame(enemy: Dictionary) -> int:
	if enemy.windup > 0.0:
		return 2 + enemy.attack % 3 * 2
	if enemy.charge > 0.0:
		return 3
	if enemy.attack_pose_time > 0.0:
		return 3 + posmod(enemy.attack - 1, 3) * 2
	return int(enemy.age * 5) % 2 if enemy.moving else 0

func enemy_art(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.p
	var facing: float = enemy.get("facing", 1.0)
	if enemy.age < 0.8:
		if enemy.get("yamada_clone", false):
			shadow(p, enemy.radius)
			var opacity: float = minf(1.0, 0.45 + enemy.age * 2.0)
			sprite(game.yamada_split_atlas, 3, p, 150, false, 0, Color(1, 1, 1, opacity), facing)
		else:
			stamp(6, p, Vector2.ONE * (46 + enemy.age * 25), 0, Color(1, 0.65, 0.7, 0.8))
		return
	shadow(p, enemy.radius)
	if game.is_yang(enemy):
		var atlas: RefCounted = game.yang_atlas if enemy.phase == 0 else game.yang_peak_atlas
		var frame: int = yang_action_frame(enemy)
		var height: float = 164.0 if enemy.phase == 0 else YANG_PEAK_HEIGHT
		var scale: float = atlas.row_heights[frame / atlas.columns] / atlas.frames[0].height
		var shield_center: Vector2 = p + Vector2(0, -79)
		if enemy.castle_shield:
			draw_circle(shield_center, 91, Color(0.35, 0.73, 0.98, 0.13))
		sprite(atlas, frame, p, height * scale, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE, facing)
		if enemy.castle_shield:
			draw_arc(shield_center, 91, 0, TAU, 48, Color(0.59, 0.85, 1.0, 0.74), 3, true)
	elif enemy.art >= 0:
		var atlas: RefCounted = game.themed_enemy_atlas
		var frame: int = enemy.art
		var idle_frame: int = frame
		var bob: float = sin(enemy.age * 7) * 2 if enemy.windup <= 0 else 0.0
		if game.Data.YANG_ESCORT_NAMES.has(enemy.kind):
			atlas = game.yang_escort_atlas
			frame = enemy_action_frame(enemy, 6)
			idle_frame = enemy.art * 6
			bob = 0.0
		elif game.floor_index == 0:
			atlas = game.security_atlas if enemy.kind == "boss" else game.street_enemy_atlas
			frame = enemy_action_frame(enemy)
			idle_frame = enemy.art * 8
			bob = 0.0
		elif game.Data.FLOOR_STYLES[game.floor_index] == "dark_home":
			atlas = game.ruoyu_atlases[enemy.phase] if game.is_ruoyu(enemy) else game.home_enemy_atlas
			frame = enemy_action_frame(enemy, 6)
			idle_frame = enemy.art * 6
			bob = 0.0
			if game.is_ruoyu(enemy):
				var pounce_frame: int = ruoyu_pounce_frame(enemy)
				if pounce_frame >= 0:
					atlas = game.ruoyu_pounce_atlas
					frame = pounce_frame
					idle_frame = enemy.phase * 4
					bob = -sin(PI * enemy.pounce_time / game.Data.RUOYU_POUNCE_FLIGHT) * 54.0
		var height: float = 116.0 + game.floor_index * 5 if enemy.kind == "boss" else (104.0 if game.is_boss(enemy) else 53.0)
		if atlas == game.yang_escort_atlas:
			height = 94.0
		var scale: float = atlas.row_heights[frame / atlas.columns] / atlas.frames[idle_frame].height
		sprite(atlas, frame, p + Vector2(0, bob), height * scale, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE, facing)
		if atlas == game.yang_escort_atlas:
			center(game.Data.YANG_ESCORT_NAMES[enemy.kind], p + Vector2(0, -106), 15, GOLD, true)
	elif enemy.kind in ["wolf", "ropehead", "baola"] or enemy.kind == "boss" and game.Data.FLOOR_STYLES[game.floor_index] == "wilds":
		var row: int = 0 if enemy.kind == "boss" else {"baola":1, "wolf":2, "ropehead":3}[enemy.kind]
		var pose: int = 3 if enemy.charge > 0 or enemy.kind == "ropehead" and enemy.cooldown > 2.1 else (2 if enemy.windup > 0 else int(enemy.age * 5) % 2)
		var height: float = {"boss":146, "baola":106, "wolf":52, "ropehead":59}[enemy.kind]
		# Wolf idle/walk/windup frames face left; its pounce frame faces right.
		var source_facing: float = -1.0 if enemy.kind == "wolf" and pose < 3 else 1.0
		sprite(game.wilds_atlas, row * 4 + pose, p, height, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE, facing * source_facing)
	elif game.is_yamada(enemy):
		if enemy.has("split_time"):
			var progress: float = 1.0 - enemy.split_time / game.Data.YAMADA_SPLIT_DURATION
			var pose: int = clampi(int(progress * 3), 0, 2)
			sprite(game.yamada_split_atlas, pose, p, 150, false, 0, Color.WHITE, facing)
		else:
			sprite(game.yamada_atlas, yamada_action_frame(enemy), p, 150, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE, facing)
	elif enemy.kind == "shark":
		var pose: int = 3 if enemy.charge > 0 or enemy.flash > 0 else (2 if enemy.windup > 0 else int(enemy.age * 4) % 2)
		sprite(game.shark_atlas, pose, p, 120, false, 0, Color("fff0d2") if enemy.flash > 0 else Color.WHITE, facing)
	else:
		var row: int = {"slime":0, "splitter":0, "minislime":0, "brood":0, "warden":1, "ranged":1, "charger":2, "dasher":2, "boss":3}[enemy.kind]
		var pose: int = 3 if enemy.flash > 0 else (2 if enemy.windup > 0 or enemy.charge > 0 else int(enemy.age * 5) % 2)
		var height: float = 45 if enemy.kind == "slime" else 54
		var tint: Color = Color.WHITE
		if enemy.kind == "splitter":
			height = 66
			tint = Color("bd9eff")
		elif enemy.kind == "minislime":
			height = 28
			tint = Color("d7b9ff")
		elif enemy.kind == "dasher":
			height = 48
			tint = Color("ffa58f")
		elif enemy.kind == "brood":
			height = 115
			tint = Color("bb9ef1")
		elif enemy.kind == "warden":
			height = 112
			tint = Color("8fcfff")
		elif enemy.kind == "boss":
			height = 110 + game.floor_index * 9
			tint = game.Data.FLOOR_COLORS[game.floor_index]
		sprite(game.enemy_atlas, row * 4 + pose, p, height, false, 0, Color("fff0d2") if enemy.flash > 0 else tint, facing)
	if enemy.guard_time > 0.0:
		var angle: float = enemy.aim.angle()
		draw_arc(p + Vector2(0, -12), enemy.radius + 8, angle - 0.9, angle + 0.9, 18, MINT, 3, true)
	if enemy.hp < enemy.max_hp:
		var width: float = 64 if game.is_boss(enemy) else 32
		box(Rect2(p.x - width / 2, p.y + 8, width, 4), BG, BG, 2)
		draw_rect(Rect2(p.x - width / 2, p.y + 8, width * maxf(0, enemy.hp / enemy.max_hp), 4), RED)

func stage_atlas(floor_number: int = -1) -> RefCounted:
	return game.stage_atlases.get(game.Data.FLOOR_STYLES[game.floor_index if floor_number < 0 else floor_number], game.environment_atlas)

func cover_index() -> int:
	if game.Data.FLOOR_STYLES[game.floor_index] == "dark_home":
		return 9
	if game.Data.FLOOR_STYLES[game.floor_index] == "wilds":
		return 5
	if game.Data.FLOOR_STYLES[game.floor_index] == "office":
		return 5
	return 4 if game.floor_index in [2, 3, 5] else 5 + mini(game.floor_index, 2)

func stage_stamp(index: int, p: Vector2, size: Vector2) -> void:
	var atlas: RefCounted = stage_atlas()
	var frame: Dictionary = atlas.frames[index]
	draw_texture_rect_region(atlas.texture, Rect2(p - size / 2, size), Rect2(frame.region.position + frame.bounds.position, frame.bounds.size))

func tiles(rect: Rect2, index: int, tile_size: int = 128, tint: Color = Color(0.62, 0.66, 0.68), tile_index: int = -1) -> void:
	var atlas: RefCounted = stage_atlas(index)
	var frame: Dictionary = atlas.frames[tile_index if tile_index >= 0 else (2 if index == 6 else 0)]
	var clip: Rect2 = rect.intersection(visible_world) if surface == "world" else rect
	if not clip.has_area():
		return
	var first := Vector2(rect.position.x + floor((clip.position.x - rect.position.x) / tile_size) * tile_size, rect.position.y + floor((clip.position.y - rect.position.y) / tile_size) * tile_size)
	for y in range(int(first.y), int(clip.end.y) + 1, tile_size):
		for x in range(int(first.x), int(clip.end.x) + 1, tile_size):
			var size := Vector2(minf(tile_size, rect.end.x - x), minf(tile_size, rect.end.y - y))
			if size.x <= 0 or size.y <= 0:
				continue
			var inset := Vector2.ONE * (20 if game.Data.FLOOR_STYLES[index] == "wilds" else 3)
			var region := Rect2(frame.region.position + inset, (frame.region.size - inset * 2) * size / tile_size)
			draw_texture_rect_region(atlas.texture, Rect2(Vector2(x, y), size), region, tint)

func wall_segment(rect: Rect2) -> void:
	if not rect.has_area() or not visible_world.intersects(rect):
		return
	var style: String = game.Data.FLOOR_STYLES[game.floor_index]
	if style == "zhangjiang":
		var atlas: RefCounted = game.street_surface_atlas
		var frame: Dictionary = atlas.frames[4]
		var source := Rect2(frame.region.position + frame.bounds.position + Vector2(24, 0), frame.bounds.size - Vector2(48, 0))
		tile_wall(rect, atlas.texture, source, 102.0)
		return
	if style == "dark_home":
		var atlas: RefCounted = stage_atlas()
		tile_wall(rect, atlas.texture, atlas.frames[8].region, 132.0)
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
		if style == "wilds":
			stage_stamp(8 if horizontal else 9, segment.get_center(), segment.size)
		elif game.floor_index in [2, 3, 5]:
			stage_stamp(1 if horizontal else 2, segment.get_center(), segment.size)
		else:
			stamp(8 if horizontal else 9, segment.get_center(), segment.size, 0, Color.WHITE.lerp(game.Data.FLOOR_COLORS[game.floor_index], 0.25))

func tile_wall(rect: Rect2, texture: Texture2D, source: Rect2, tile_length: float) -> void:
	var horizontal: bool = rect.size.x >= rect.size.y
	var length: float = rect.size.x if horizontal else rect.size.y
	var thickness: float = rect.size.y if horizontal else rect.size.x
	var direction: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
	for i in range(ceili(length / tile_length)):
		var start: float = i * tile_length
		var width: float = minf(tile_length, length - start)
		var sample: Rect2 = source
		sample.size.x *= width / tile_length
		var flip: bool = i % 2 == 1
		if flip:
			sample.position.x = source.end.x - sample.size.x
		var center: Vector2 = rect.get_center() + direction * (start + width / 2 - length / 2)
		# Adjacent spans meet at the same texture edge, even at a clipped wall end.
		draw_set_transform(center, 0.0 if horizontal else PI / 2, Vector2(-1 if flip else 1, 1))
		draw_texture_rect_region(texture, Rect2(-width / 2, -thickness / 2, width, thickness), sample)
	draw_set_transform(Vector2.ZERO)

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
				wall_segment(Rect2(span.x, rect.position.y - 30 + WALL_INSET if direction == 0 else rect.end.y - WALL_INSET, span.y - span.x, 30))
			else:
				wall_segment(Rect2(rect.position.x - 30 + WALL_INSET if direction == 3 else rect.end.x - WALL_INSET, span.x, 30, span.y - span.x))
	var corners: Rect2 = rect.grow(-12)
	for corner in [corners.position, Vector2(corners.end.x, corners.position.y), corners.end, Vector2(corners.position.x, corners.end.y)]:
		if visible_world.has_point(corner):
			if game.Data.FLOOR_STYLES[game.floor_index] in ["zhangjiang", "dark_home"]:
				continue
			elif game.Data.FLOOR_STYLES[game.floor_index] == "wilds":
				stage_stamp(10, corner, Vector2(48, 42))
			elif game.floor_index in [2, 3, 5]:
				stage_stamp(3, corner, Vector2(36, 52))
			else:
				stamp(10, corner, Vector2(36, 42), 0, Color.WHITE.lerp(game.Data.FLOOR_COLORS[game.floor_index], 0.25))

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
	if game.Data.FLOOR_STYLES[game.floor_index] == "zhangjiang":
		draw_street_room(room)
		return
	if game.Data.FLOOR_STYLES[game.floor_index] == "dark_home":
		var area: int = room.get("area", 0)
		tiles(room.rect, game.floor_index, 216, Color.WHITE, area)
		room_walls(room)
		var atlas: RefCounted = stage_atlas()
		var width: float = minf(220.0, room.rect.size.x * 0.27)
		var bounds: Rect2 = atlas.frames[area + 4].bounds
		var height: float = width * bounds.size.y / bounds.size.x
		var bottom: float = room.rect.position.y + maxf(162.0 if area == 3 else 106.0, WALL_INSET + 8.0 + height)
		var x: float = room.center.x if area == 3 else room.center.x - room.rect.size.x * 0.23
		draw_grounded_prop(atlas, area + 4, Vector2(x, bottom), width)
		return
	var wilds: bool = game.Data.FLOOR_STYLES[game.floor_index] == "wilds"
	tiles(room.rect, game.floor_index, 128, Color(0.62, 0.66, 0.68), (1 if room.terrain == "forest" else 0) if wilds else -1)
	if room.type == "boss" and game.floor_index in [2, 3, 4, 5]:
		var size: float = 560 if game.floor_index in [4, 5] else 360
		sprite(stage_atlas(), 11 if wilds else 6, room.center, size, true, 0, Color(1, 1, 1, 0.45) if game.floor_index in [2, 3] else Color.WHITE)
	room_walls(room)
	var positions: Array[Vector2] = [room.rect.position + Vector2(95, 112), room.rect.end - Vector2(95, 20)]
	for i in range(positions.size()):
		var index: int = (4 if i == 0 else 7) if wilds else (5 if game.floor_index in [2, 3, 5] else (4 if game.floor_index == 1 else 7))
		sprite(stage_atlas(), index, positions[i], 125 if wilds and i == 0 else 75)

func draw_street_room(room: Dictionary) -> void:
	var rect: Rect2 = room.rect
	var curb: float = minf(102.0, rect.size.y * 0.22)
	var road := Rect2(rect.position + Vector2(0, curb), rect.size - Vector2(0, curb * 1.65))
	var crossing_x: float = room.center.x if room.type == "boss" else room.center.x + (room.layout - 2) * rect.size.x * 0.09
	street_tiles(1, Rect2(rect.position, Vector2(rect.size.x, curb)))
	street_tiles(0, road)
	street_tiles(1, Rect2(rect.position.x, road.end.y, rect.size.x, rect.end.y - road.end.y))
	for edge in [road.position.y - 4, road.end.y - 4]:
		wall_segment(Rect2(rect.position.x, edge, rect.size.x, 8))
	for x in range(int(rect.position.x) + 30, int(rect.end.x) - 28, 80):
		if absf(x - crossing_x) > 103:
			street_prop(2, Vector2(x, room.center.y), Vector2(44, 6))
	for y in range(int(road.position.y) + 17, int(road.end.y) - 21, 30):
		street_prop(3, Vector2(crossing_x, y), Vector2(120, 16))
	room_walls(room)
	if room.type == "boss":
		draw_grounded_prop(game.street_atlas, 0, Vector2(room.center.x, rect.position.y + 158), 525)
	else:
		var width: float = minf(238, (rect.size.x - 186) * 0.5)
		for side in [-1, 1]:
			draw_grounded_prop(game.street_surface_atlas, 7, Vector2(room.center.x + side * (width * 0.5 + 93), rect.position.y + curb * 0.76), width)

func draw_grounded_prop(atlas: RefCounted, index: int, p: Vector2, width: float) -> void:
	var frame: Dictionary = atlas.frames[index]
	var source := Rect2(frame.region.position + frame.bounds.position, frame.bounds.size)
	var size: Vector2 = source.size * width / source.size.x
	draw_texture_rect_region(atlas.texture, Rect2(p - Vector2(size.x * 0.5, size.y), size), source)

func street_tiles(index: int, rect: Rect2) -> void:
	var atlas: RefCounted = game.street_surface_atlas
	var source: Rect2 = atlas.frames[index].region
	var tile_size: int = 224
	for row in range(ceili(rect.size.y / tile_size)):
		for column in range(ceili(rect.size.x / tile_size)):
			var offset := Vector2(column, row) * tile_size
			var size: Vector2 = (rect.size - offset).min(Vector2.ONE * tile_size)
			draw_texture_rect_region(atlas.texture, Rect2(rect.position + offset, size), Rect2(source.position, source.size * size / tile_size))

func street_prop(index: int, p: Vector2, size: Vector2, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	var atlas: RefCounted = game.street_surface_atlas
	var frame: Dictionary = atlas.frames[index]
	draw_set_transform(p, angle)
	draw_texture_rect_region(atlas.texture, Rect2(-size / 2, size), Rect2(frame.region.position + frame.bounds.position, frame.bounds.size), tint)
	draw_set_transform(Vector2.ZERO)

func draw_corridor_geometry(hall: Dictionary) -> void:
	var rect: Rect2 = hall.rect
	var style: String = game.Data.FLOOR_STYLES[game.floor_index]
	if style == "zhangjiang":
		street_tiles(0, rect)
		var horizontal: bool = hall.direction == 1
		var axis: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
		var length: float = rect.size.x if horizontal else rect.size.y
		for step_position in range(32, int(length) - 24, 70):
			var p: Vector2 = rect.get_center() + axis * (step_position - length / 2)
			street_prop(2, p, Vector2(38, 6), 0.0 if horizontal else PI / 2)
	elif style == "dark_home":
		var child: Dictionary = game.rooms[maxi(hall.a, hall.b)]
		tiles(rect, game.floor_index, 216, Color.WHITE, child.get("area", 0))
	else:
		tiles(rect, game.floor_index, 128, Color(0.72, 0.74, 0.77), 2 if style == "wilds" else -1)
	if hall.direction == 1:
		wall_segment(Rect2(rect.position + Vector2(64, -28 + WALL_INSET), Vector2(rect.size.x - 128, 28)))
		wall_segment(Rect2(rect.position + Vector2(64, rect.size.y - WALL_INSET), Vector2(rect.size.x - 128, 28)))
	else:
		wall_segment(Rect2(rect.position + Vector2(-28 + WALL_INSET, 64), Vector2(28, rect.size.y - 128)))
		wall_segment(Rect2(rect.position + Vector2(rect.size.x - WALL_INSET, 64), Vector2(28, rect.size.y - 128)))

func combat_barriers() -> void:
	# Only a small raster warning remains while a fight seals the passage.
	for rect in game.closed_gates():
		if visible_world.intersects(rect):
			var horizontal: bool = rect.size.x > rect.size.y
			for i in range(4):
				var p: Vector2 = rect.get_center() + (Vector2.RIGHT if horizontal else Vector2.DOWN) * (i - 1.5) * 40
				stamp(4, p, Vector2(36, 22), PI if horizontal else PI / 2, Color(1, 0.55, 0.55, 0.65))

func cover_draw_rect(rect: Rect2) -> Rect2:
	var frame: Dictionary = game.street_surface_atlas.frames[5] if game.floor_index == 0 else stage_atlas().frames[cover_index()]
	var width: float = rect.size.x + 8
	var size: Vector2 = frame.bounds.size * width / frame.bounds.size.x
	return Rect2(Vector2(rect.get_center().x - size.x / 2, rect.end.y - size.y), size)

func cover_art(rect: Rect2, broken: bool = false) -> void:
	if game.Data.FLOOR_STYLES[game.floor_index] == "zhangjiang":
		var destination: Rect2 = cover_draw_rect(rect)
		var size: Vector2 = destination.size * Vector2(1, 0.58 if broken else 1)
		var damage: int = game.cover_damage.get(rect, 0)
		street_prop(6 if broken else 5, Vector2(rect.get_center().x, rect.end.y - size.y / 2), size, 0.0, Color.WHITE.darkened(damage * 0.12))
		return
	var atlas: RefCounted = stage_atlas()
	var frame: Dictionary = atlas.frames[cover_index()]
	var bounds := Rect2(frame.region.position + frame.bounds.position, frame.bounds.size)
	var destination: Rect2 = cover_draw_rect(rect)
	if broken:
		for i in range(4):
			var source := Rect2(bounds.position + Vector2(i % 2, i / 2) * bounds.size / 2, bounds.size / 2)
			var p := Vector2(rect.get_center().x, rect.end.y - 8) + Vector2((i % 2 - 0.5) * 38, (i / 2 - 0.5) * 19)
			draw_set_transform(p, (i - 1.5) * 0.22)
			draw_texture_rect_region(atlas.texture, Rect2(-destination.size * Vector2(0.18, 0.175), destination.size * Vector2(0.36, 0.35)), source, Color("ded2b9"))
		draw_set_transform(Vector2.ZERO)
		return
	var damage: int = game.cover_damage.get(rect, 0)
	for i in range(3):
		var source := Rect2(bounds.position + Vector2(bounds.size.x * i / 3, 0), Vector2(bounds.size.x / 3, bounds.size.y))
		var piece := Rect2(destination.position + Vector2(destination.size.x * i / 3 + (i - 1) * damage * 2, (i % 2) * damage * 3), Vector2(destination.size.x / 3, destination.size.y))
		draw_texture_rect_region(atlas.texture, piece, source, Color.WHITE.lerp(Color("a49b88"), damage * 0.2))

func title_screen() -> void:
	micro("YICHUAN / PRINCESS RESCUE", Vector2(68, 55), MINT, 9)
	micro("V " + str(ProjectSettings.get_setting("application/config/version")), Vector2(1138, 55), MUTED, 9)
	box(Rect2(68, 105, 180, 30), Color("223a36"), Color("45675b"), 15)
	text("双模式 · 地牢 / 沙盒", Vector2(82, 126), 16, MINT)
	text("毅川救我", Vector2(63, 222), 74, WHITE, true)
	text("公主抢救计划", Vector2(68, 273), 35, MINT, true)
	text("从杨梓亮手里，救回 ChatGPT 公主。", Vector2(70, 324), 22, MUTED)
	text("七大主题关卡 · 挑战牛来与相扑横纲山田", Vector2(70, 364), 19, GOLD)
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
	button(Rect2(399, 602, 174, 58), "游玩指南 · " + game.pad.key("LB", "F1"), "guide")
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
	button(Rect2(648, 611, 544, 49), "像素旷野 · 2D 沙盒生存  →  " + game.pad.key("Y", "B"), "sandbox")
	draw_line(Vector2(68, 685), Vector2(1210, 685), LINE)
	text(game.pad.text("WASD 移动 / 自动攻击 / 空格冲刺", "方向键或左摇杆选择 · {A} 确认"), Vector2(68, 708), 14, MUTED)
	text("最高累计字节 %d  ·  通关层数 %d / %d" % [game.best_score, game.best_floor, game.Data.FLOOR_COUNT], Vector2(884, 708), 14, MUTED)

func arena() -> void:
	var player_p: Vector2 = game.render_position(game.player, game.previous_player)
	combat_barriers()
	for room in game.rooms:
		if not visible_world.intersects(room.rect.grow(140)):
			continue
		terminal(room)
		if room.type == "npc" and room.npc >= 0:
			var p: Vector2 = room.center + Vector2(-112, 0)
			npc_art(room.npc, p)
			center(game.Data.NPCS[room.npc].name, p + Vector2(0, 22), 14, game.Data.NPCS[room.npc].color, true)
			if room.id == game.room_id and game.player.distance_to(p) < 72:
				center(game.pad.key("X", "E"), p + Vector2(0, -80), 17, WHITE, true)
	for rect in game.broken_obstacles:
		if visible_world.intersects(rect.grow(50)):
			cover_art(rect, true)
	for drop in game.drops:
		sprite(game.byte_atlas, 0, drop.p, 18, true)
	for enemy in game.enemies:
		if enemy.windup > 0 and not enemy.get("castle_shield", false):
			var aim: Vector2 = enemy.aim
			var style: String = game.Data.FLOOR_STYLES[game.floor_index]
			var move: String = game.next_enemy_move(enemy)
			if enemy.kind == "boss" and style == "sumo" and (enemy.attack + 1) % 3 == 0:
				move = "slam"
			var radius: float = game.attack_radius(enemy, move)
			var stomp: bool = enemy.kind == "boss" and style == "wilds" and (enemy.attack + 1) % 4 == 3
			if radius > 0.0:
				var target: Vector2 = game.attack_center(enemy, move)
				var tint := Color("63dfee") if move == "pull" else Color("ff8099")
				if move == "pounce":
					tint = Color("ffc278")
					draw_line(enemy.p, target, Color(tint, 0.45), 3, true)
				draw_circle(target, radius, Color(tint, 0.17))
				draw_arc(target, radius, 0, TAU, 42, Color(tint, 0.86), 2, true)
			elif move == "laser":
				draw_line(enemy.p, enemy.target, Color(1.0, 0.14, 0.24, 0.18), 58, true)
				yang_laser_art(enemy.p, enemy.target, 0, 58.0, 1.0 - enemy.windup * 0.45)
			elif move == "decree":
				for lane in range(-4 - enemy.phase, 5 + enemy.phase):
					var origin: Vector2 = enemy.p + aim.orthogonal() * lane * 41
					if game.walkable(origin, 3):
						draw_line(origin - aim * 145, origin + aim * 145, Color(1, 0.55, 0.6, 0.55), 2, true)
			elif move in ["cross", "ring", "summon"] or stomp:
				var spokes: int = 4 if move in ["cross", "summon"] else 8
				for i in range(spokes):
					var direction: Vector2 = Vector2.from_angle(TAU * i / spokes)
					stamp(4, enemy.p + direction * 105, Vector2(48, 24), direction.angle(), Color(1, 1, 1, 0.6))
			else:
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
	actors.append_array(game.turrets)
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
		elif actor.kind == "turret":
			shadow(actor.p, 19)
			item_icon(actor.id, actor.p + Vector2(0, -17), 0.73)
			var lifetime: float = game.Data.TURRETS[actor.id].lifetime
			var tint: Color = game.Data.item(actor.id).color
			draw_rect(Rect2(actor.p + Vector2(-13, 5), Vector2(26, 3)), Color(tint, 0.25))
			draw_rect(Rect2(actor.p + Vector2(-13, 5), Vector2(26 * actor.life / lifetime, 3)), tint)
		else:
			enemy_art(actor)
	for i in range(game.weapons.size()):
		var weapon: Dictionary = game.weapons[i]
		var angle: float = TAU * i / maxi(1, game.weapons.size()) + game.clock * 0.16
		var recoil: float = float(weapon.get("recoil", 0.0)) / 0.16
		var p: Vector2 = player_p + Vector2.from_angle(angle) * 36 + Vector2(0, -22) - weapon.aim * recoil * 7
		item_icon(weapon.id, p, 0.57, weapon.aim.angle() + PI / 4 - recoil * 0.16)
	for shot in game.projectiles:
		var index: int = 0 if shot.friendly else (13 if game.floor_index == game.Data.FLOOR_COUNT - 1 else 1)
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
			"yang_laser":
				var atlas: RefCounted = game.yang_peak_atlas
				var frame: Dictionary = atlas.frames[11]
				var lenses: Vector2 = (YANG_LASER_GLASSES - frame.region.position - frame.anchor) * YANG_PEAK_HEIGHT / atlas.frames[0].height
				var glasses: Vector2 = effect.a + Vector2(lenses.x * effect.facing, lenses.y)
				var end: Vector2 = effect.b + Vector2(0, lenses.y)
				draw_line(effect.a, effect.b, Color(effect.color, alpha * 0.18), effect.size, true)
				yang_laser_art(glasses, end, 1 + int(progress * 3), 78.0, alpha)
			"impact": animated_fx(1, progress, effect.a, Vector2.ONE * effect.size, 0, alpha)
			"dash": animated_fx(3, progress, p - direction * 25, Vector2(effect.size * 1.6, effect.size), direction.angle(), alpha)
			"muzzle": stamp(3, p + direction * 12, Vector2(34, 26), direction.angle(), alpha_tint(alpha))
			"dust": stamp(14, effect.a, Vector2.ONE * effect.size * (0.6 + progress), 0, alpha_tint(alpha * 0.4))
			_: animated_fx(2, progress, p, Vector2.ONE * maxf(60, effect.size), 0, alpha)
	for entry in game.texts:
		center(entry.text, entry.p, 17, Color(entry.color, minf(1, entry.life * 2)), true)
	if game.state == "playing":
		combat_speech(player_p)

func combat_speech(player_p: Vector2) -> void:
	var bounds: Rect2 = (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(-12.0)
	var hero_gap: float = 44.0
	for enemy in game.enemies:
		if enemy.age < 0.8 or enemy.get("speech_time", 0.0) <= 0.0:
			continue
		var p: Vector2 = game.render_position(enemy.p, enemy.previous_p)
		var anchor := p - Vector2(0, 94)
		if not bounds.grow(24.0).has_point(anchor) and not bounds.grow(24.0).has_point(p):
			continue
		var side: float = -1.0 if p.x < player_p.x else 1.0
		hero_gap = -side * 44.0
		speech_bubble(enemy.speech, anchor, bounds, side * maxf(65.0, enemy.radius * 2.45), GOLD)
	if game.speech_time > 0:
		speech_bubble(game.speech, player_p - Vector2(0, 52), bounds, hero_gap, MINT)

func alpha_tint(alpha: float) -> Color:
	return Color(1, 1, 1, alpha)

func terminal(room: Dictionary) -> void:
	if room.type not in ["shop", "treasure", "rest", "boss"]:
		return
	if room.type == "boss" and not room.cleared:
		return
	var p: Vector2 = room.center
	var key: String = game.pad.key("X", "E")
	var label: String = key + " 补给"
	var prop: int = 10
	match room.type:
		"boss":
			label = key + " 技能提升"
			stamp(6, p, Vector2.ONE * 96, game.clock * 0.2)
			prop = -1
		"treasure":
			label = "已开启" if room.used else key + " 宝箱"
			prop = 9 if room.used else 8
		"rest":
			label = "已休息" if room.used else key + " 休息"
			prop = 11
		"shop": label = key + " 商店"
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
	text("%d/%d" % [ceili(game.health), ceili(game.max_health())], Vector2(189, 43), 13, WHITE)
	box(Rect2(1093, 19, 163, 39), Color(0.055, 0.09, 0.12, 0.88), MINT.darkened(0.45), 10)
	sprite(game.byte_atlas, 0, Vector2(1113, 38), 24, true)
	text(str(game.points), Vector2(1133, 46), 24, MINT, true)
	var label: String = "%d/%d" % [game.floor_index + 1, game.Data.FLOOR_COUNT]
	if not room.cleared:
		label += "   +%d" % game.spawn_remaining if room.get("encounter", "double") == "stream" and game.spawn_remaining > 0 else "   %d/%d" % [game.wave, game.wave_total]
	box(Rect2(586, 18, 108, 28), Color(0.055, 0.09, 0.12, 0.8), LINE, 9)
	center(label, Vector2(640, 38), 15, WHITE)
	var floor_label: String = game.Data.FLOOR_NAMES[game.floor_index]
	if game.Data.FLOOR_STYLES[game.floor_index] == "dark_home":
		floor_label += " · " + game.Data.HOME_AREAS[game.current_room().get("area", 0)]
	center(floor_label, Vector2(640, 61), 13, game.Data.FLOOR_COLORS[game.floor_index])
	if game.onion_skill:
		box(Rect2(343, 652, 48, 42), Color(0.055, 0.09, 0.12, 0.83), GOLD, 9)
		center(game.pad.key("Y", "Q") if game.onion_cooldown <= 0 else str(ceili(game.onion_cooldown)), Vector2(367, 680), 20, GOLD)
	var turret_x: float = 24.0
	for id in game.Data.TURRETS:
		if game.equipment_count(id) == 0:
			continue
		var cooldown: float = game.turret_cooldown(id)
		var tint: Color = game.Data.item(id).color
		box(Rect2(turret_x, 652, 76, 42), Color(0.055, 0.09, 0.12, 0.83), tint.darkened(0.4) if cooldown > 0 else tint, 9)
		item_icon(id, Vector2(turret_x + 20, 673), 0.51)
		center(game.pad.key("RB", "F") if cooldown <= 0 else "%d秒" % ceili(cooldown), Vector2(turret_x + 54, 679), 15, tint)
		turret_x += 84.0
	if game.pad.active:
		var hint: String = game.pad.text("", "左摇杆 移动 · {A} 冲刺 · {X} 交互 · {Start} 背包 · {LB} 指南")
		var width: float = game.font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		box(Rect2(12, 689, width + 20, 26), Color(0.055, 0.09, 0.12, 0.90), LINE, 7)
		text(hint, Vector2(22, 708), 14, WHITE)
	if game.assisted:
		micro("DEBUG", Vector2(267, 42), RED, 8)
	for enemy in game.enemies:
		if game.is_boss(enemy):
			var boss_label: String = game.boss_name(enemy)
			var boss_bar_color: Color = RED
			var boss_health_ratio: float = enemy.hp / enemy.max_hp
			if game.is_yang(enemy):
				if enemy.phase > 0:
					boss_label += " · 巅峰"
				elif enemy.castle_shield:
					boss_label += " · 护盾"
				elif enemy.castle_weak_time > 0.0:
					boss_label += " · 虚弱"
				boss_bar_color = Color("84cdf9") if enemy.castle_shield else RED
			elif enemy.get("yamada_clone", false):
				var remaining: int = 0
				var total_hp: float = 0.0
				for clone in game.enemies:
					if clone.get("yamada_clone", false):
						remaining += 1
						total_hp += clone.hp
				boss_label += " · 分身 %d/%d" % [remaining, game.Data.YAMADA_CLONE_COUNT]
				boss_health_ratio = total_hp / (enemy.max_hp * game.Data.YAMADA_CLONE_COUNT)
			elif enemy.has("split_time"):
				boss_label += " · 分身蓄力"
			box(Rect2(390, 65, 500, 27), Color(0.1, 0.06, 0.1, 0.88), Color("8c545e"), 7)
			draw_rect(Rect2(398, 85, 484 * maxf(0, boss_health_ratio), 3), boss_bar_color)
			center(boss_label, Vector2(640, 81), 14, WHITE)
			break

func ruoyu_unseal() -> void:
	var elapsed: float = game.ruoyu_unseal_time
	var viewport: Rect2 = get_viewport_rect()
	var p: Vector2 = viewport.get_center()
	var tint := Color("1b1021").lerp(Color("382032"), smoothstep(0.6, 1.8, elapsed))
	draw_rect(viewport, tint)
	var frame: int = mini(3, int(elapsed / 0.46))
	var scale_value: float = minf(viewport.size.x * 0.56, viewport.size.y * 0.79)
	var opacity: float = smoothstep(0.0, 0.18, elapsed)
	sprite(game.ruoyu_unseal_atlas, frame, p - Vector2(0, viewport.size.y * 0.047), scale_value, true, 0, Color(1, 1, 1, opacity))
	if frame >= 2:
		speech_bubble(game.Data.RUOYU_UNSEAL_QUOTE, p - Vector2(0, scale_value * 0.19), viewport.grow(-24.0), scale_value * 0.46, GOLD, 265.0, 25)
		center("封印解除", Vector2(p.x, viewport.end.y - 31), 19, Color("eda2b4"), true)

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
	speech_bubble(line.line, Vector2(201, 546), Rect2(278, 504, 846, 90), 88.0, MINT, 806.0, 22)
	button(Rect2(921, 602, 219, 36), "继续 · " + game.pad.key("A", "Enter / E"), "dialogue", 0, true)
	text(game.pad.key("B", "Esc") + " 跳过这段剧情", Vector2(288, 629), 14, MUTED)

func shop() -> void:
	scrim()
	box(Rect2(83, 63, 1114, 580), PANEL, LINE, 18)
	micro("SUPPLY / BUILD YOUR LOADOUT", Vector2(117, 100), GOLD)
	text("战后补给" if game.current_room().get("reward_shop", false) else "字节补给站", Vector2(116, 143), 34, WHITE, true)
	sprite(game.byte_atlas, 0, Vector2(891, 131), 28, true)
	text("余额 %d 字节" % game.points, Vector2(914, 140), 25, GOLD, true)
	text("可刷新货架 · 退出后结束补给" if game.current_room().reward_shop else "武器限 6 栏，满栏自动合并 · 装备无限叠加", Vector2(117, 179), 17, MUTED)
	if game.current_room().type == "shop":
		text("商店房专享 85 折", Vector2(942, 179), 16, MINT)
	for i in range(game.stock.size()):
		var offer: Dictionary = game.stock[i]
		var spec: Dictionary = game.Data.item(offer.id)
		var color: Color = game.Data.TIER_COLORS[offer.tier - 1]
		var rect := Rect2(116 + i * 266, 208, 250, 310)
		box(rect, color.darkened(0.78), color.darkened(0.4), 12)
		text("%d · %s" % [i + 1, game.Data.ATTACK_NAMES[spec.attack_type] if spec.kind == "weapon" else "道具"], rect.position + Vector2(18, 30), 15, color)
		draw_circle(rect.position + Vector2(125, 92), 43, Color(spec.color, 0.08))
		item_icon(offer.id, rect.position + Vector2(125, 92), 1.5)
		text(spec.name, rect.position + Vector2(18, 164), 24, WHITE, true)
		text(spec.tag, rect.position + Vector2(18, 194), 16, color)
		if spec.kind == "equipment":
			var row: int = 0
			for id in spec.stats:
				var bonus: float = spec.stats[id] * game.Data.equipment_multiplier(offer.tier)
				var harmful: bool = bonus < 0 or id == "incoming_damage" and bonus > 0
				text(game.Data.STAT_NAMES[id] + " " + game.Data.stat_text(id, bonus, true), rect.position + Vector2(18, 226 + row * 23), 15, RED if harmful else MUTED)
				row += 1
		else:
			paragraph(spec.desc, rect.position + Vector2(18, 226), 214, 15, MUTED, 2)
		button(Rect2(rect.position + Vector2(16, 259), Vector2(218, 35)), "已购入" if offer.sold else "购买 · %d 字节" % game.shop_price(offer), "buy", i, not offer.sold, not offer.sold)
	var refresh_cost: int = game.refresh_price()
	var refresh_key: String = game.pad.key("Y", "R")
	button(Rect2(117, 547, 270, 49), "首次免费刷新 · " + refresh_key if refresh_cost == 0 else "刷新 · %d 字节 / %s" % [refresh_cost, refresh_key], "refresh", 0, refresh_cost == 0)
	button(Rect2(407, 547, 270, 49), "整理背包 / 合并 · " + game.pad.key("Start", "Tab"), "inventory")
	button(Rect2(884, 547, 280, 49), "继续探索 · " + game.pad.key("B", "Esc"), "close_shop", 0, true)
	text("清房 %d · 物价 +%.1f%% · 每清房 +5%% / 每换层 ×1.15 · 四格随机供货" % [game.cleared_count, (game.price_scale() - 1) * 100], Vector2(117, 624), 16, MUTED)

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
		button(Rect2(rect.position + Vector2(24, 281), Vector2(264, 39)), "选择" if game.pad.active else "选择 · %d" % (i + 1), "skill_choice", i, true)
	center("选择后" + ("救回公主" if game.floor_index == game.Data.FLOOR_COUNT - 1 else "进入下一层"), Vector2(640, 618), 18, MUTED)

func inventory() -> void:
	draw_rect(get_viewport_rect(), PANEL)
	text("背包", Vector2(40, 56), 30, WHITE, true)
	sprite(game.byte_atlas, 0, Vector2(926, 43), 22, true)
	text("%d 字节" % game.points, Vector2(946, 49), 17, MINT)
	button(Rect2(1098, 23, 140, 39), "返回标题", "ask_title")
	draw_line(Vector2(40, 78), Vector2(1238, 78), LINE, 1)
	button(Rect2(606, 630, 146, 36), "返回 · " + game.pad.key("B", "Esc"), "inventory")
	var pages: int = maxi(1, ceili(float(game.equipment.size()) / EQUIPMENT_PAGE_SIZE))
	equipment_page = clampi(equipment_page, 0, pages - 1)
	text("武器  %d / 6" % game.weapons.size(), Vector2(40, 113), 18, GOLD, true)
	for index in range(6):
		var rect := Rect2(40 + index * 72, 128, 64, 64)
		if index < game.weapons.size():
			draw_inventory_item(rect, "weapon", index, game.weapons[index])
		else:
			box(rect, Color("13222c"), LINE.darkened(0.3), 7)
	text("道具  %d" % game.equipment_count(), Vector2(40, 228), 18, GOLD, true)
	if game.equipment.is_empty():
		text("暂无道具", Vector2(40, 268), 16, MUTED)
	var first: int = equipment_page * EQUIPMENT_PAGE_SIZE
	for index in range(first, mini(first + EQUIPMENT_PAGE_SIZE, game.equipment.size())):
		var slot: int = index - first
		var rect := Rect2(40 + slot % EQUIPMENT_COLUMNS * 72, 244 + (slot / EQUIPMENT_COLUMNS) * 70, 64, 64)
		draw_inventory_item(rect, "equipment", index, game.equipment[index])
	if pages > 1:
		button(Rect2(526, 204, 68, 31), "上页", "equipment_page", -1, false, equipment_page > 0)
		center("%d / %d" % [equipment_page + 1, pages], Vector2(634, 225), 14, MUTED)
		button(Rect2(684, 204, 68, 31), "下页", "equipment_page", 1, false, equipment_page < pages - 1)
	text(game.pad.text("悬停 / 点击查看 · 右键合并 / 出售", "方向键查看物品 · {X} 或 {A} 合并 / 出售 · {B} 返回"), Vector2(40, 653), 15, MUTED)
	character_stats()
	if game.state == "confirm_title":
		buttons.clear()
		item_slots.clear()
		scrim()
		box(Rect2(380, 243, 520, 220), PANEL, LINE, 14)
		text("返回标题？", Vector2(408, 296), 26, WHITE, true)
		text("返回后将结束本局，当前进度会丢失。", Vector2(408, 336), 17, MUTED)
		button(Rect2(408, 382, 212, 48), "取消 · " + game.pad.key("B", "Esc"), "cancel_title", 0, true)
		button(Rect2(636, 382, 236, 48), "确认返回标题", "confirm_title")
		return
	if not item_context.is_empty():
		draw_item_context()
		return
	if game.pad.active:
		var focus: Dictionary = game.pad.focused(menu_entries(), menu_context())
		if focus.get("action") == "item" and valid_item_slot(focus):
			show_item_at(focus, focus.rect.get_center())
		return
	var hovered: Dictionary = inventory_focus
	for slot in item_slots:
		if slot.rect.has_point(pointer_position):
			hovered = slot
			break
	if not hovered.is_empty() and valid_item_slot(hovered):
		show_item_at(hovered, pointer_position)

func show_item_at(slot: Dictionary, p: Vector2) -> void:
	var tip_x: float = p.x + 20 if p.x < 438 else p.x - 340
	item_tooltip(slot.entry, Vector2(tip_x, p.y + 20))

func draw_inventory_item(rect: Rect2, kind: String, index: int, entry: Dictionary) -> void:
	var color: Color = game.Data.TIER_COLORS[entry.tier - 1]
	var hover: bool = not game.pad.active and rect.has_point(pointer_position)
	box(rect, color.darkened(0.68 if hover else 0.78), color if hover else color.darkened(0.35), 7)
	item_icon(entry.id, rect.get_center() - Vector2(0, 2), 0.76)
	if kind == "equipment":
		var count_text: String = "×%d" % entry.count
		text(count_text, rect.position + Vector2(61 - game.bold.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, 15), 12, WHITE, true)
	for pip in range(entry.tier):
		draw_circle(rect.position + Vector2(23 + pip * 6, 57), 1.7, color)
	item_slots.append({"rect":rect, "kind":kind, "index":index, "entry":entry, "action":"item", "primary":kind == "weapon" and index == 0})

func character_stats() -> void:
	box(Rect2(784, 94, 454, 572), BG, LINE, 9)
	text("角色属性", Vector2(806, 128), 21, WHITE, true)
	text("当前", Vector2(1088, 152), 14, MUTED)
	text("上限", Vector2(1188, 152), 14, MUTED)
	draw_line(Vector2(806, 161), Vector2(1216, 161), LINE, 1)
	var ids: Array = STAT_ICONS.keys()
	for i in range(ids.size()):
		var id: String = ids[i]
		var value: float = game.player_stat(id)
		var cap: float = game.Data.STAT_CAPS[id]
		if id in ["melee_damage", "ranged_damage", "magic_damage"]:
			value = game.damage_scale(id.trim_suffix("_damage"))
			cap = game.Data.STAT_CAPS.damage
		var value_text: String = game.Data.stat_text(id, value)
		if id == "health":
			value_text = "%d/%d" % [ceili(game.health), ceili(value)]
		var color: Color = MINT if is_equal_approx(value, cap) else WHITE
		if value < game.Data.STAT_BASES[id] or id == "incoming_damage" and value > 1.0:
			color = RED
		var y: float = 184 + i * 25
		item_icon(STAT_ICONS[id], Vector2(816, y - 5), 0.38)
		text(game.Data.STAT_NAMES[id], Vector2(836, y), 16, MUTED)
		text(value_text, Vector2(1117 - game.font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, y), 16, color)
		var cap_text: String = game.Data.stat_text(id, cap)
		text(cap_text, Vector2(1216 - game.font.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, y), 14, MUTED)
	var skills: Array[String] = []
	for skill in game.Data.SKILLS:
		if game.skill_level(skill.id) > 0:
			skills.append("%s Lv.%d" % [skill.name, game.skill_level(skill.id)])
	if not skills.is_empty():
		paragraph(" · ".join(skills), Vector2(806, 623), 410, 14, MINT, 2)

func item_tooltip(entry: Dictionary, position: Vector2) -> void:
	var spec: Dictionary = game.Data.item(entry.id)
	var color: Color = game.Data.TIER_COLORS[entry.tier - 1]
	var p := Vector2(clampf(position.x, 20, 940), clampf(position.y, 20, 388))
	box(Rect2(p, Vector2(320, 278)), BG, color.darkened(0.3), 10)
	text(spec.name, p + Vector2(18, 34), 23, WHITE, true)
	var category: String = game.Data.ATTACK_NAMES[spec.attack_type] + "武器" if spec.kind == "weapon" else "道具"
	text("%s · %s · %s" % [game.Data.TIER_NAMES[entry.tier - 1], category, spec.tag.get_slice(" · ", 0)], p + Vector2(18, 65), 15, color)
	paragraph(spec.desc, p + Vector2(18, 99), 284, 16, MUTED, 2)
	if spec.kind == "weapon":
		text("伤害 %.1f · 间隔 %.2f 秒" % [spec.damage * game.Data.multiplier(entry.tier) * game.damage_scale(spec.attack_type), spec.cooldown / game.attack_speed()], p + Vector2(18, 158), 16, WHITE)
		text("范围 %d · 暴击率 %.1f%%" % [spec.reach * game.player_stat("reach"), game.player_stat("crit_chance") * 100], p + Vector2(18, 184), 15, MUTED)
		paragraph(game.Data.item_bonus_text(spec, entry.tier), p + Vector2(18, 210), 284, 14, MINT, 2)
	else:
		var row: int = 0
		for id in spec.stats:
			var bonus: float = spec.stats[id] * game.Data.equipment_multiplier(entry.tier)
			var harmful: bool = bonus < 0 or id == "incoming_damage" and bonus > 0
			text("%s %s / 件" % [game.Data.STAT_NAMES[id], game.Data.stat_text(id, bonus, true)], p + Vector2(18, 160 + row * 27), 16, RED if harmful else MINT)
			row += 1
		if game.Data.TURRETS.has(spec.id):
			var turret: Dictionary = game.Data.TURRETS[spec.id]
			text("持续 %d 秒 · 冷却 %d 秒" % [turret.lifetime, turret.cooldown], p + Vector2(18, 189), 15, MINT)
		text("本组 ×%d · 叠加效果受角色属性上下限约束" % entry.get("count", 1), p + Vector2(18, 221), 13, MUTED)
	text("单件售价 %d 字节" % game.sell_price(entry), p + Vector2(18, 253), 16, GOLD)

func draw_item_context() -> void:
	var p: Vector2 = item_context.position
	box(Rect2(p, Vector2(246, 112)), BG, LINE, 9)
	var can_fuse: bool = game.fusion_pair(item_context.kind, item_context.index) >= 0
	var can_sell: bool = item_context.kind != "weapon" or game.weapons.size() > 1
	button(Rect2(p + Vector2(8, 9), Vector2(230, 42)), "合并升级" if can_fuse else "需要同名同品质 ×2", "menu_fuse", 0, false, can_fuse)
	button(Rect2(p + Vector2(8, 60), Vector2(230, 42)), "出售 1 件 · +%d" % game.sell_price(item_context.entry) if can_sell else "至少保留一把武器", "menu_sell", 0, false, can_sell)

func treasure_reward() -> void:
	scrim()
	text("宝箱奖励", Vector2(230, 142), 36, WHITE, true)
	text("选择一件带走", Vector2(232, 179), 18, MUTED)
	var offers: Array = game.current_room().get("treasure_offers", [])
	for i in range(offers.size()):
		var entry: Dictionary = offers[i]
		var spec: Dictionary = game.Data.item(entry.id)
		var color: Color = game.Data.TIER_COLORS[entry.tier - 1]
		var rect := Rect2(230 + i * 278, 221, 250, 306)
		box(rect, color.darkened(0.78), color.darkened(0.35), 12)
		item_icon(entry.id, rect.position + Vector2(125, 88), 1.7)
		center(spec.name, rect.position + Vector2(125, 172), 23, WHITE, true)
		center(spec.tag, rect.position + Vector2(125, 207), 16, color)
		var can_take: bool = game.can_add_item(entry.id, entry.tier)
		button(Rect2(rect.position + Vector2(20, 244), Vector2(210, 42)), ("装备" if game.pad.active else "装备 · %d" % (i + 1)) if can_take else "武器栏已满", "treasure_choice", i, can_take, can_take)
	button(Rect2(230, 567, 250, 45), "放弃奖励 · " + game.pad.key("B", "Esc"), "treasure_skip")
	button(Rect2(786, 567, 250, 45), "整理背包 · " + game.pad.key("Start", "Tab"), "inventory")
	for i in range(offers.size()):
		if Rect2(230 + i * 278, 221, 250, 235).has_point(pointer_position):
			item_tooltip(offers[i], pointer_position + Vector2(20, 20))
			break

func npc_panel() -> void:
	scrim()
	var spec: Dictionary = game.Data.NPCS[game.selected_npc]
	var used: bool = game.current_room().get("npc_used", false) and spec.id != "coin"
	box(Rect2(228, 133, 824, 471), PANEL, spec.color.darkened(0.3), 18)
	micro("ENCOUNTER / A FRIEND ON THE ROAD", Vector2(266, 176), spec.color)
	npc_art(game.selected_npc, Vector2(365, 416), 2.1)
	text(spec.name, Vector2(505, 239), 34, WHITE, true)
	text(spec.role, Vector2(505, 273), 18, spec.color)
	var line: String = spec.quote if game.npc_reply.is_empty() else game.npc_reply
	speech_bubble(line, Vector2(365, 322), Rect2(488, 283, 510, 87), 138.0, spec.color, 470.0, 23)
	paragraph("这次已经帮过你了。继续前进，公主还在等你。" if used else spec.offer, Vector2(505, 392), 469, 19, MUTED, 3)
	button(Rect2(504, 493, 493, 45), "谢谢，下次见" if used else spec.button, "npc_accept", 0, true)
	button(Rect2(504, 548, 493, 36), "先继续探索 · " + game.pad.key("B", "Esc"), "npc_close")

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
	center("累计 %d 字节  /  %d 击杀  /  %d 房间" % [game.earned, game.kills, game.cleared_count], Vector2(640, 425), 20, GOLD)
	if game.assisted:
		center("本局使用调试辅助，不写入最高纪录", Vector2(640, 455), 14, RED)
	button(Rect2(410, 482, 460, 49), ("再来一局 · " + game.pad.key("A", "R")) if won or dead else ("继续探索 · " + game.pad.key("A", "Enter")), "restart" if won or dead else "resume", 0, true)
	button(Rect2(410, 547, 460, 43), "返回标题", "title")

func guide() -> void:
	scrim()
	box(Rect2(124, 63, 1032, 584), PANEL, LINE, 18)
	micro("FIELD GUIDE / TOP-DOWN ROGUELITE", Vector2(163, 106), MINT)
	text("救公主行动手册", Vector2(162, 155), 36, WHITE, true)
	button(Rect2(956, 93, 160, 41), "返回 · " + game.pad.key("B", "Esc"), "close_guide")
	var lines: Array[String] = [
		"WASD / 方向键：四向移动　　空格 / Shift：无敌冲刺　　攻击自动瞄准并释放。",
		"沿主路前进到首领。战斗中携带可部署道具时，按 F 在脚下放置一台炮塔。",
		"普通与精英房清空后可以购买补给，按 R 刷新货架。关闭后结束补给。",
		"各层有不同的普通怪和精英。关底首领会轮换招式，留意地上和身前的预警。",
		"武器限 6 栏，装备无限叠加；背包悬停看属性、右键合并或出售，底色表示品质。",
		"战斗房随机单波、双波或持续增援，前两层双波较少。清房会提高敌人的攻速和移速。",
		"武器栏满时可按 Tab 整理背包，同名同品质的两件物品可以合并。",
		"击败关底首领后，按 1–3 选择技能提升，再进入下一层；最终救回 ChatGPT 公主。",
		"Esc / Tab 背包与暂停　F1 手册　M 静音　F11 全屏　Home 调试选项。"
	]
	if game.pad.active:
		lines[0] = game.pad.text("", "左摇杆 / 方向键移动，{A} 无敌冲刺，{X} 交互。攻击自动瞄准并释放。")
		lines[1] = game.pad.text("", "沿主路前进到首领。{RB} 在脚下部署炮塔，{Y} 施放已解锁的洋葱守护。")
		lines[2] = game.pad.text("", "普通与精英房清空后可以购买补给，{Y} 刷新货架。关闭后结束补给。")
		lines[4] = game.pad.text("", "武器限 6 栏，装备无限叠加。用方向键查看属性，{X} 打开合并与出售菜单。")
		lines[6] = game.pad.text("", "{Start} 整理背包。同名同品质的两件物品可以合并。")
		lines[7] = game.pad.text("", "击败关底首领后，用方向键选择技能，{A} 确认，再进入下一层。")
		lines[8] = game.pad.text("", "{Start} 暂停 / 背包　{LB} 手册　{B} 返回。菜单支持左摇杆和方向键。")
	for i in range(lines.size()):
		text("%02d" % (i + 1), Vector2(164, 209 + i * 43), 15, MINT)
		text(lines[i], Vector2(202, 209 + i * 43), 17, WHITE if i % 2 == 0 else MUTED)
	text("近战 / 远程 / 魔法分别加成；每清房物价 +5%，每换层再涨 15%，属性均有上限。", Vector2(164, 617), 16, GOLD)

func cheats() -> void:
	scrim()
	box(Rect2(365, 111, 550, 490), PANEL, LINE, 15)
	micro("DEBUG / ASSISTED RUN", Vector2(404, 153), RED)
	text("毅川的调试工具", Vector2(404, 196), 30, WHITE, true)
	button(Rect2(404, 233, 472, 55), "1 · 无敌    " + ("已开启" if game.cheat_invincible else "已关闭"), "cheat", 0, game.cheat_invincible)
	button(Rect2(404, 307, 472, 55), "2 · 一击必杀    " + ("已开启" if game.cheat_one_hit else "已关闭"), "cheat", 1, game.cheat_one_hit)
	var can_skip: bool = game.floor_index < game.Data.FLOOR_COUNT - 1
	button(Rect2(404, 381, 472, 55), "3 · 跳到下一关" if can_skip else "3 · 已到最终关", "skip_floor", 0, false, can_skip)
	text("使用任意辅助后，本局不会写入普通纪录。", Vector2(404, 478), 16, MUTED)
	button(Rect2(404, 514, 472, 44), "返回 · " + game.pad.key("B", "Home / Esc"), "close_cheats")

func menu_context() -> String:
	return game.state + ("/item" if not item_context.is_empty() else "")

func menu_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in buttons:
		if entry.state == game.state and (item_context.is_empty() or entry.action in ["menu_sell", "menu_fuse"]):
			entries.append(entry)
	if game.state == "inventory" and item_context.is_empty():
		entries.append_array(item_slots)
	return entries

func move_menu_focus(direction: Vector2) -> void:
	game.pad.move_focus(menu_entries(), menu_context(), direction)
	queue_redraw()

func confirm_menu_focus() -> void:
	var focus: Dictionary = game.pad.focused(menu_entries(), menu_context())
	if focus.is_empty():
		return
	if focus.action == "item":
		right_click(focus.rect.get_center())
	else:
		click(focus.rect.get_center())
	queue_redraw()

func open_focused_item() -> void:
	var focus: Dictionary = game.pad.focused(menu_entries(), menu_context())
	if focus.get("action") == "item":
		right_click(focus.rect.get_center())

func move_pointer(p: Vector2) -> void:
	if surface == "world":
		if overlay != null:
			overlay.move_pointer(p)
		return
	if pointer_position != p:
		inventory_focus.clear()
	pointer_position = p
	if game.state in ["inventory", "treasure"]:
		queue_redraw()

func valid_item_slot(slot: Dictionary) -> bool:
	var entries: Array = game.weapons if slot.kind == "weapon" else game.equipment
	return slot.index >= 0 and slot.index < entries.size() and entries[slot.index] == slot.entry

func reset_inventory_interaction() -> void:
	if surface == "world":
		if overlay != null:
			overlay.reset_inventory_interaction()
		return
	inventory_focus.clear()
	item_context.clear()
	queue_redraw()

func dismiss_context() -> bool:
	if surface == "world":
		return overlay.dismiss_context() if overlay != null else false
	if item_context.is_empty():
		return false
	item_context.clear()
	queue_redraw()
	return true

func right_click(p: Vector2) -> void:
	if surface == "world":
		if overlay != null:
			overlay.right_click(p)
		return
	if game.state != "inventory":
		return
	pointer_position = p
	item_context.clear()
	inventory_focus.clear()
	for slot in item_slots:
		if slot.rect.has_point(p) and valid_item_slot(slot):
			item_context = slot.duplicate()
			item_context["position"] = Vector2(clampf(p.x, 20, 1014), clampf(p.y, 20, 588))
			break
	queue_redraw()

func click(p: Vector2) -> void:
	if surface == "world":
		if overlay != null:
			overlay.click(p)
		return
	pointer_position = p
	if game.state == "inventory" and not item_context.is_empty():
		if not valid_item_slot(item_context):
			reset_inventory_interaction()
			return
		for entry in buttons:
			if entry.state == game.state and entry.rect.has_point(p):
				if entry.action == "menu_sell":
					game.sell(item_context.kind, item_context.index)
				elif entry.action == "menu_fuse":
					game.fuse(item_context.kind, item_context.index)
		reset_inventory_interaction()
		return
	for entry in buttons.duplicate():
		if entry.state != game.state or not entry.rect.has_point(p):
			continue
		match entry.action:
			"sandbox": game.start_sandbox()
			"weapon": game.selected_weapon = entry.index
			"difficulty": game.difficulty = entry.index
			"start", "restart": game.start_run()
			"title": game.state = "title"
			"ask_title":
				reset_inventory_interaction()
				game.state = "confirm_title"
			"cancel_title": game.state = "inventory"
			"confirm_title": game.state = "title"
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
			"equipment_page":
				equipment_page += entry.index
				reset_inventory_interaction()
			"treasure_choice": game.choose_treasure(entry.index)
			"treasure_skip": game.skip_treasure()
			"npc_accept":
				if game.current_room().get("npc_used", false) and game.Data.NPCS[game.selected_npc].id != "coin":
					game.state = "playing"
				else:
					game.accept_npc()
			"npc_close", "resume": game.state = "playing"
			"cheat": game.toggle_cheat(entry.index)
			"skip_floor": game.skip_floor()
		return
	if game.state == "inventory":
		inventory_focus.clear()
		for slot in item_slots:
			if slot.rect.has_point(p):
				inventory_focus = slot
				break
		queue_redraw()
