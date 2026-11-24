extends RefCounted
## The fault changes the presentation of the existing tiles, leaving their IDs intact.
const Data = preload("res://scripts/sandbox_data.gd")
const Atlas = preload("res://scripts/sprite_atlas.gd")
const ASSETS: String = "res://assets/generated/sandbox/system-fault/"

var canvas: Node2D
var game: Node
var atlases: Dictionary = {}
var horizon: Texture2D
var membrane: Image
var membrane_texture: Texture2D
var fog: ColorRect
var fog_material: ShaderMaterial
var transition_cover: ColorRect
var transition_material: ShaderMaterial
var transition_labels: VBoxContainer
var transition_title: Label
var transition_detail: Label

func _init(owner: Node2D) -> void:
	canvas = owner
	game = owner.game

func build_membrane() -> void:
	if membrane != null:
		return
	var source: Texture2D = load(ASSETS + "flesh.png")
	var quadrant: Image = source.get_image()
	quadrant.convert(Image.FORMAT_RGBA8)
	var span: int = Data.TILE * 4
	quadrant.resize(span, span, Image.INTERPOLATE_NEAREST)
	membrane = Image.create(span * 2, span * 2, false, Image.FORMAT_RGBA8)
	var region := Rect2i(0, 0, span, span)
	# Mirrored repeats meet at identical edges on both axes.
	membrane.blit_rect(quadrant, region, Vector2i.ZERO)
	quadrant.flip_x()
	membrane.blit_rect(quadrant, region, Vector2i(span, 0))
	quadrant.flip_y()
	membrane.blit_rect(quadrant, region, Vector2i(span, span))
	quadrant.flip_x()
	membrane.blit_rect(quadrant, region, Vector2i(0, span))
	membrane_texture = ImageTexture.create_from_image(membrane)

func membrane_region(cell: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(posmod(cell.x, 8), posmod(cell.y, 8)) * Data.TILE, Vector2i.ONE * Data.TILE)

func apply_tile(image: Image, cell: Vector2i, dest: Vector2i, tile_id: int) -> void:
	if tile_id in [Data.Block.GRASS, Data.Block.DIRT, Data.Block.STONE, Data.Block.SAND, Data.Block.SNOW, Data.Block.JUNGLE_GRASS, Data.Block.CORRUPT_STONE, Data.Block.DUNGEON_BRICK, Data.Block.BEDROCK]:
		image.blit_rect(membrane, membrane_region(cell), dest)
	elif tile_id in [Data.Block.WOOD, Data.Block.LEAF, Data.Block.PLANK, Data.Block.DOOR, Data.Block.DOOR_OPEN]:
		var source: Vector2i = membrane_region(cell).position
		for y in range(Data.TILE):
			for x in range(Data.TILE):
				var offset := Vector2i(x, y)
				var color: Color = image.get_pixelv(dest + offset)
				if color.a <= 0.01:
					continue
				var alpha: float = color.a
				color = color.lerp(membrane.get_pixelv(source + offset), 0.62)
				color.a = alpha
				image.set_pixelv(dest + offset, color)

func draw_horizon() -> void:
	if horizon == null:
		horizon = load(ASSETS + "horizon.png")
	var shift: float = clampf((game.camera.position.x / (Data.WIDTH * Data.TILE) - 0.5) * 64, -32, 32)
	canvas.draw_texture_rect(horizon, Rect2(-39 + shift, -22, 1358, 764), false)

func draw_back_wall(cell: Vector2i) -> void:
	build_membrane()
	canvas.draw_texture_rect_region(
		membrane_texture,
		Rect2(Vector2(cell) * Data.TILE, Vector2.ONE * Data.TILE),
		Rect2(membrane_region(cell)),
		Color(0.65, 0.54, 0.67)
	)

func sync_fog() -> void:
	var visible: bool = game.fault.active and game.state not in ["menu", "confirm"]
	if fog == null and visible:
		var layer := CanvasLayer.new()
		layer.layer = 4
		game.add_child(layer)
		fog = ColorRect.new()
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_material = ShaderMaterial.new()
		fog_material.shader = load("res://scripts/sandbox_fault_fog.gdshader")
		fog_material.set_shader_parameter("fog_texture", load(ASSETS + "fog.png"))
		fog.material = fog_material
		layer.add_child(fog)
		fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if fog != null:
		fog.visible = visible
		if visible:
			fog_material.set_shader_parameter("player_uv", player_uv())
			fog_material.set_shader_parameter("drift", fposmod(game.visual_clock * 0.046, 1024.0))

func player_uv() -> Vector2:
	var viewport: Viewport = game.get_viewport()
	var light: Vector2 = viewport.get_canvas_transform() * (game.player - Vector2(0, 20))
	return light / viewport.get_visible_rect().size

func create_transition_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	game.add_child(layer)
	transition_cover = ColorRect.new()
	transition_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_material = ShaderMaterial.new()
	transition_material.shader = load("res://scripts/sandbox_fault_transition.gdshader")
	transition_material.set_shader_parameter("fog_texture", load(ASSETS + "fog.png"))
	transition_material.set_shader_parameter("membrane_texture", load(ASSETS + "flesh.png"))
	transition_cover.material = transition_material
	layer.add_child(transition_cover)
	transition_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_labels = VBoxContainer.new()
	transition_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_labels.add_theme_constant_override("separation", 5)
	center.add_child(transition_labels)
	transition_title = Label.new()
	transition_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_title.add_theme_font_override("font", game.bold)
	transition_title.add_theme_font_size_override("font_size", 47)
	transition_labels.add_child(transition_title)
	transition_detail = Label.new()
	transition_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transition_detail.add_theme_font_override("font", game.bold)
	transition_detail.add_theme_font_size_override("font_size", 19)
	transition_labels.add_child(transition_detail)

func sync_transition() -> void:
	if game.state != "fault_transition":
		if transition_cover != null:
			transition_cover.hide()
		return
	if transition_cover == null:
		create_transition_layer()
	var f = game.fault
	var time: float = f.transition_time
	var closing: float = smoothstep(0.0, f.TRANSITION_COVER, time)
	var opening: float = smoothstep(f.TRANSITION_REVEAL, f.TRANSITION_END, time)
	var closure: float = closing * (1.0 - opening)
	var entering: bool = f.transition_kind == "enter"
	if not transition_cover.visible:
		transition_cover.show()
	transition_material.set_shader_parameter("player_uv", player_uv().clamp(Vector2(0.03, 0.03), Vector2(0.97, 0.97)))
	transition_material.set_shader_parameter("aspect", transition_cover.size.aspect())
	transition_material.set_shader_parameter("closure", closure)
	transition_material.set_shader_parameter("elapsed", time)
	transition_material.set_shader_parameter("entering", entering)
	transition_labels.modulate.a = smoothstep(0.64, 0.94, closure)
	transition_title.text = "系统故障" if entering else "故障解除"
	transition_title.modulate = Color("ffe5ec") if entering else Color("ffecd3")
	match f.transition_kind:
		"enter": transition_detail.text = "内存泄漏达到十层"
		"priest": transition_detail.text = "神父解除了故障"
		"ape": transition_detail.text = "狮子猿已倒下"
	transition_detail.modulate = Color("e7bacb") if entering else Color("e3bf9f")

func atlas_for(key: String) -> RefCounted:
	if not atlases.has(key):
		var texture: Texture2D = load(ASSETS + key + ".png")
		var atlas := Atlas.new(texture, 4, 4 if key == "ape" else 2)
		var rest_height: float = (atlas.frames[0].height + atlas.frames[1].height) * 0.5
		atlas.row_heights.fill(rest_height)
		for frame in atlas.frames:
			frame.anchor = Vector2(64, 115)
		atlases[key] = atlas
	return atlases[key]

func draw_enemy(enemy: Dictionary, at: Vector2, tint: Color) -> void:
	var atlas: RefCounted = atlas_for(enemy.spec.art)
	atlas.draw(canvas, game.fault.enemy_frame(enemy), at, enemy.spec.height, enemy.facing, tint)

func draw_fallen_hero() -> void:
	var frame: Dictionary = game.hero_atlas.frames[0 if game.facing > 0 else 8]
	var height: float = game.hero_atlas.row_heights[0]
	var scale: float = 44.0 / height
	canvas.draw_set_transform(game.player + Vector2(0, -9), -1.48 * game.facing, Vector2.ONE * scale)
	canvas.draw_texture_rect_region(game.hero_atlas.texture, Rect2(-frame.anchor, frame.region.size), frame.region, Color("bcc3d2"))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_actors() -> void:
	var f = game.fault
	var bounds: Rect2 = canvas.visible_world.grow(100)
	if not f.keeper_unlocked:
		return
	if game.state == "dead" and f.pending:
		var healer: Vector2 = f.death_actor_position()
		var revive_pose: int = 4 + mini(3, int(f.revive_time / (f.REVIVE_SECONDS / 4.0)))
		atlas_for("keeper").draw(canvas, revive_pose, healer, 52, signf(game.player.x - healer.x))
	elif f.keeper_site.is_finite() and bounds.has_point(f.keeper_site):
		var facing: float = 1 if game.player.x >= f.keeper_site.x else -1
		atlas_for("keeper").draw(canvas, int(game.visual_clock * 1.7) % 2, f.keeper_site, 52, facing)
		canvas.world_label("防火女", f.keeper_site - Vector2(0, 63), canvas.GOLD)
		if game.state == "playing" and f.can_talk_at(f.keeper_site, 72):
			canvas.world_label("[%s] 疗愈" % game.pad.key("X", "E"), f.keeper_site - Vector2(0, 45), canvas.WHITE)
	if f.active and bounds.has_point(f.priest_site):
		game.priest_atlas.draw(canvas, 0, f.priest_site, 64, 1, Color("d0b8bb"))
		canvas.world_label("神父 · CTO", f.priest_site - Vector2(0, 83), canvas.GOLD)
		if game.state == "playing" and f.can_talk_at(f.priest_site):
			canvas.world_label("[%s] 解除故障" % game.pad.key("X", "E"), f.priest_site - Vector2(0, 64), canvas.WHITE)

func draw_revival() -> void:
	var f = game.fault
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color(0.055, 0.04, 0.067, 0.22))
	canvas.box(Rect2(329, 487, 622, 132), canvas.INK, canvas.GOLD, 10)
	canvas.centered("防火女", Vector2(640, 519), 22, canvas.GOLD, true)
	canvas.centered("火还在。听得见我吗，毅川？", Vector2(640, 548), 17, canvas.WHITE)
	canvas.centered("内存泄漏 +1   ·   %d / %d" % [f.leaks, f.LIMIT], Vector2(640, 578), 14, canvas.CORAL)
	var progress: float = clampf(f.revive_time / f.REVIVE_SECONDS, 0, 1)
	canvas.draw_rect(Rect2(481, 594, 318, 5), canvas.EDGE)
	canvas.draw_rect(Rect2(481, 594, 318 * progress, 5), canvas.GOLD)
	canvas.button(Rect2(813, 566, 116, 31), "起身", "respawn")

func draw_heal_panel() -> void:
	canvas.scrim()
	canvas.box(Rect2(298, 172, 684, 375), canvas.INK, canvas.GOLD, 14)
	atlas_for("keeper").draw(canvas, 1, Vector2(435, 470), 225, 1)
	canvas.text("防火女", Vector2(558, 236), 30, canvas.GOLD, true)
	canvas.text("过来坐一会儿，火还暖着。", Vector2(559, 279), 18, canvas.WHITE)
	var reason: String = game.fault.heal_reason()
	canvas.text("每天可恢复一次生命。" if reason.is_empty() else reason, Vector2(559, 320), 15, canvas.MUTED)
	canvas.button(Rect2(558, 360, 349, 43), "恢复全部生命", "keeper_heal", 0, true, reason.is_empty())
	canvas.button(Rect2(558, 421, 349, 43), "离开", "resume")
