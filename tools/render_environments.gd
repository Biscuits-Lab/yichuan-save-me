extends SceneTree
var game: Node
var checks: int = 0
var failures: int = 0

class PlatformProbe:
	extends "res://scripts/world.gd"
	var fixtures: Array[Rect2] = []
	func _draw() -> void:
		for rect in fixtures:
			platform(rect,0,game.environment.accent)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func snap(name: String) -> Image:
	game.hud.queue_redraw()
	if is_instance_valid(game.scenery):
		game.scenery.queue_redraw()
	for i in range(4):
		await frame()
	var img: Image = root.get_texture().get_image()
	check(img.save_png("res://output/previews/" + name + ".png") == OK,"Rendered " + name)
	return img

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/previews")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.record_path = "res://.tools/environment-preview-record.json"
	game.set_process(false)
	game.difficulty_index = 1
	await snap("new-01-title")
	game.toggle_cheats()
	game.toggle_cheat(0)
	game.toggle_cheat(1)
	await snap("new-02-cheats")
	game.toggle_cheat(0)
	game.toggle_cheat(1)
	game.toggle_cheats()
	# Compare actual rendered pixels to a baseline, including tiny, uneven and
	# non-tile-aligned platform widths. Nothing may bleed beyond either edge.
	game.hud.hide()
	await frame()
	var baseline: Image = root.get_texture().get_image()
	var probe := PlatformProbe.new()
	probe.game = game
	var widths: Array[int] = [1,17,47,49,73,125,211]
	for row in range(2):
		for col in range(widths.size()):
			probe.fixtures.append(Rect2(30 + col * 170,220 + row * 140,widths[col],22 if row == 0 else 180))
	root.add_child(probe)
	await frame()
	var drawn: Image = root.get_texture().get_image()
	var outside: int = 0
	var painted: int = 0
	for y in range(200,560):
		for x in range(10,1275):
			var difference: Color = drawn.get_pixel(x,y) - baseline.get_pixel(x,y)
			if absf(difference.r) + absf(difference.g) + absf(difference.b) > 0.025:
				painted += 1
				var inside: bool = false
				for rect in probe.fixtures:
					if rect.has_point(Vector2(x + 0.5,y + 0.5)):
						inside = true
						break
				if not inside:
					outside += 1
	check(painted > 5000 and outside == 0,"No platform stripes or bricks render outside any of the fourteen fixture bounds")
	print("PLATFORM PIXEL METRICS: outside=",outside," painted=",painted)
	drawn.save_png("res://output/previews/new-03-platform-bounds.png")
	probe.queue_free()
	game.hud.show()
	game.start_run("story",20261112)
	game.event_order.assign([0,1,2,3,4,5,6,7,8,9,10,11])
	var sheet: Image = Image.create(1440,1080,false,Image.FORMAT_RGBA8)
	for i in range(12):
		game.room_index = i
		game.build_room()
		game.chapter_time = 0
		game.player.position = Vector2(620,598)
		game.player.velocity = Vector2.ZERO
		game.player.invulnerable = 999
		game.camera_x = 180
		game.world.position.x = -180
		game.player.reset_physics_interpolation()
		for tick in range(4):
			await physics_frame
		game.player.set_physics_process(false)
		game.player.invulnerable = 0
		game.spawn_wave(0)
		for bug in game.enemies:
			bug.set_physics_process(false)
		game.feedback_time = 0
		check(game.background_art.resource_path.ends_with("/%s.png" % game.event.kind),"The live scene actually loads its own " + game.event.tool + " background")
		var img: Image = await snap("level-" + game.event.kind)
		img.convert(Image.FORMAT_RGBA8)
		img.resize(480,270,Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(img,Rect2i(0,0,480,270),Vector2i(i % 3 * 480,i / 3 * 270))
	sheet.save_png("res://output/previews/levels-in-game.png")
	print("ENVIRONMENT RENDER RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	for i in range(3):
		await process_frame
	quit(1 if failures else 0)
