extends Node2D

var game: Node
const INK := Color("102531")
const MINT := Color("a1dac2")
const PAPER := Color("f2dfb6")

func _draw() -> void:
	var cam: float = game.camera_x
	var time: float = game.clock
	var accent: Color = game.STAGES[game.stage].color
	# Draw at world coordinates; the parent supplies camera movement.
	draw_rect(Rect2(cam - 20, -20, 1320, 800), Color("0d1a2b"))
	for i in range(38):
		var sx: float = fposmod(i * 137.0 - cam * 0.09, 1380) + cam - 40
		var sy: float = 45 + fmod(i * 71, 295)
		draw_rect(Rect2(sx, sy, 2 if i % 3 else 3, 2), Color(0.6, 0.78, 0.72, 0.25 + sin(time + i) * 0.15))
	var moon := Vector2(cam + 1050 - fmod(cam * 0.025, 140), 173)
	draw_circle(moon, 75, Color("172f3c"))
	draw_circle(moon, 61, Color("254850"))
	draw_circle(moon, 54, Color("aacabc"))
	draw_rect(Rect2(moon.x - 60, moon.y + 12, 140, 8), Color("17313e"))
	draw_rect(Rect2(moon.x - 85, moon.y + 24, 150, 5), Color("17313e"))
	# Layered, gently scrolling mountain silhouettes.
	for layer in range(3):
		var polygon := PackedVector2Array([Vector2(cam - 50, 720)])
		for i in range(16):
			var x: float = cam - 100 + i * 105
			var y: float = 390 + layer * 66 - sin((x - cam * (0.82 - layer * 0.1)) * 0.008) * 60 - sin(x * 0.014) * 18
			polygon.append(Vector2(x, y))
		polygon.append(Vector2(cam + 1500, 720))
		draw_colored_polygon(polygon, [Color("173243"), Color("193b49"), Color("1b414b")][layer])
	# Distant server-temples.
	for i in range(9):
		var x: float = cam + fposmod(i * 208.0 - cam * 0.24, 1664) - 160
		var height: float = 100 + fmod(i * 79, 180)
		var base_y: float = 552
		var tint := Color("204351")
		draw_rect(Rect2(x, base_y - height, 87, height), tint)
		for floor_index in range(3):
			var roof_y: float = base_y - height + floor_index * 64
			roof(x - 20, roof_y, 128, Color("1b3447"), Color("3d6467"))
		for row in range(int(height / 22)):
			for col in range(4):
				if (row + col + i) % 3 != 0:
					draw_rect(Rect2(x + 11 + col * 18, base_y - height + 22 + row * 22, 5, 9), Color("69968c") if (col + row) % 4 else Color("a88f65"))
	# Midground power lines and server racks, with clear play-space silhouettes.
	for i in range(8):
		var x: float = cam + fposmod(i * 230.0 - cam * 0.5, 1840) - 180
		var y: float = 388 + (i % 3) * 31
		draw_rect(Rect2(x, y, 111, 215), Color("152e3a"))
		draw_rect(Rect2(x + 6, y + 5, 99, 205), Color("213d46"))
		for row in range(7):
			var slot := Rect2(x + 13, y + 13 + row * 24, 85, 16)
			draw_rect(slot, Color("102b36"))
			draw_rect(Rect2(slot.position + Vector2(7, 6), Vector2(4, 4)), Color("72b39c"))
			for vent in range(6):
				draw_rect(Rect2(x + 42 + vent * 7, slot.position.y + 5, 3, 6), Color("35555b"))
		roof(x - 15, y - 10, 142, Color("142c3b"), Color("466c70"))
		var cable := PackedVector2Array()
		for j in range(17):
			cable.append(Vector2(x + j * 15, y - 22 + sin(j / 16.0 * PI) * 42))
		draw_polyline(cable, Color("0c2330"), 4)
		lantern(Vector2(x + 138, y + 17), time + i)
	# A generated skyline supplies the final distant layer. Mirror the next tile
	# at its edge so slow parallax never exposes an empty background.
	if game.background_art:
		var shift: float = fmod(cam * 0.12, 1280)
		draw_texture_rect(game.background_art, Rect2(cam - shift, -130, 1280, 853), false, Color("c3cfce"))
		draw_set_transform(Vector2(cam - shift + 2560, 0), 0, Vector2(-1, 1))
		draw_texture_rect(game.background_art, Rect2(0, -130, 1280, 853), false, Color("c3cfce"))
		draw_set_transform(Vector2.ZERO)
		for i in range(16):
			draw_rect(Rect2(cam, 440 + i * 12, 1280, 12), Color(0.025, 0.10, 0.14, i / 45.0))
	# Landmark signage belongs to the current district, not the HUD.
	for i in range(4):
		var x: float = [240.0, 2070.0, 3700.0, 5410.0][i]
		if absf(x - cam - 640) < 1100:
			draw_rect(Rect2(x, 285, 216, 80), Color("172e3b"))
			draw_rect(Rect2(x + 4, 289, 208, 72), Color("24434b"))
			draw_rect(Rect2(x + 8, 293, 3, 64), game.STAGES[i].color)
			draw_string(game.font, Vector2(x + 23, 318), game.STAGES[i].tool, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, game.STAGES[i].color)
			draw_string(game.font, Vector2(x + 23, 348), game.STAGES[i].title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, PAPER)
			draw_rect(Rect2(x + 22, 365, 5, 235), Color("304e53"))
			draw_rect(Rect2(x + 189, 365, 5, 235), Color("304e53"))
	# Torii at the beginning and between engineering districts.
	for x in [110.0, 1850.0, 3480.0, 5030.0, 6300.0]:
		if x > cam - 300 and x < cam + 1400:
			draw_rect(Rect2(x + 16, 365, 13, 235), Color("7e4c49"))
			draw_rect(Rect2(x + 163, 365, 13, 235), Color("7e4c49"))
			draw_rect(Rect2(x + 20, 365, 4, 235), Color("b47d60"))
			draw_rect(Rect2(x + 167, 365, 4, 235), Color("b47d60"))
			draw_rect(Rect2(x + 2, 358, 190, 15), Color("a56351"))
			draw_rect(Rect2(x + 10, 400, 176, 10), Color("905749"))
			roof(x - 10, 341, 214, Color("203d43"), Color("839b89"))
			lantern(Vector2(x + 97, 397), time)
	# Falling into gaps is recoverable at the last successful build.
	for hole in [Rect2(920, 605, 160, 115), Rect2(2580, 605, 150, 115), Rect2(4180, 605, 160, 115)]:
		if hole.end.x < cam or hole.position.x > cam + 1280:
			continue
		draw_rect(hole, Color("102331"))
		for i in range(8):
			var y: float = hole.position.y + fposmod(i * 22.0 + time * 27, 115)
			draw_rect(Rect2(hole.position.x + 7 + (i * 29) % 140, y, 17, 2), Color("b46065"))
		draw_string(game.pixel_font, hole.position + Vector2(12, 45), "NULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a16170"))
	for rect in game.platforms:
		if rect.end.x >= cam - 20 and rect.position.x < cam + 1300:
			platform(rect, cam, accent)
	for i in range(game.gates.size()):
		var gate: Dictionary = game.gates[i]
		var rect: Rect2 = gate.rect
		if rect.position.x < cam - 100 or rect.position.x > cam + 1400:
			continue
		var tint: Color = game.STAGES[i].color
		if not gate.open:
			draw_rect(Rect2(rect.position - Vector2(7, 0), rect.size + Vector2(14, 0)), Color(tint, 0.12))
			for j in range(12):
				var y: float = rect.position.y + fposmod(j * 27.0 + time * 30, rect.size.y)
				draw_rect(Rect2(rect.position.x, y, 28, 10), Color(tint, 0.7))
			draw_rect(Rect2(rect.position.x - 7, rect.position.y, 42, 8), tint)
			draw_rect(Rect2(rect.position.x - 7, 592, 42, 8), tint)
	for i in range(game.terminals.size()):
		var terminal: Dictionary = game.terminals[i]
		if absf(terminal.p.x - cam - 640) < 900:
			draw_terminal(terminal, i, time)
	for cup in game.coffee:
		if cup.taken or cup.p.x < cam - 100 or cup.p.x > cam + 1380:
			continue
		var p: Vector2 = cup.p + Vector2(0, sin(time * 3 + cup.p.x) * 4)
		draw_circle(p, 22, Color(0.95, 0.75, 0.4, 0.05))
		draw_rect(Rect2(p - Vector2(9, 12), Vector2(18, 22)), Color("f2d59e"))
		draw_rect(Rect2(p + Vector2(-11, -14), Vector2(22, 4)), Color("a86c4d"))
		draw_rect(Rect2(p + Vector2(-8, -4), Vector2(16, 8)), Color("b17e5a"))
		draw_rect(Rect2(p + Vector2(9, -8), Vector2(6, 12)), Color("f2d59e"))
		draw_line(p + Vector2(-3, -20), p + Vector2(-3 + sin(time * 3) * 3, -28), Color("b0c7ad"), 2)
	for trail in game.trails:
		draw_rect(Rect2(trail.p + Vector2(-20, -77), Vector2(40, 75)), Color(0.6, 0.95, 0.8, trail.life * 0.5))
	if game.effects_atlas:
		for effect in game.effects:
			var phase: float = 1 - effect.life / effect.duration
			game.effects_atlas.draw(self, effect.index, effect.p, effect.size * (0.65 + phase * 0.6), effect.facing, Color(1, 1, 1, minf(1, effect.life * 7)), true)
	for orb in game.projectiles:
		draw_rect(Rect2(orb.p - Vector2(9, 9), Vector2(18, 18)), Color(orb.color, 0.14))
		draw_rect(Rect2(orb.p - Vector2(5, 5), Vector2(10, 10)), orb.color)
		draw_rect(Rect2(orb.p - Vector2(2, 2), Vector2(4, 4)), Color("ffe8c7"))
	for particle in game.particles:
		draw_rect(Rect2(particle.p, Vector2.ONE * particle.size), Color(particle.color, minf(1, particle.life * 3)))
	for item in game.floating_text:
		var w: float = game.font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(game.font, item.p - Vector2(w * 0.5, 0), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(item.color, minf(1, item.life * 2)))
	# A few slow petals make the industrial environment feel alive.
	for i in range(16):
		var p := Vector2(cam + fposmod(i * 113.0 - time * (12 + i % 3) - cam * 0.3, 1360) - 40, fposmod(i * 61.0 + time * 14, 590))
		draw_rect(Rect2(p, Vector2(4, 3)), Color(0.87, 0.64, 0.57, 0.42))

func roof(x: float, y: float, width: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array([Vector2(x, y + 13), Vector2(x + 13, y + 10), Vector2(x + 25, y), Vector2(x + width - 25, y), Vector2(x + width - 13, y + 10), Vector2(x + width, y + 13), Vector2(x + width, y + 19), Vector2(x, y + 19)])
	draw_colored_polygon(points, fill)
	draw_line(Vector2(x, y + 14), Vector2(x + width, y + 14), edge, 3)
	for i in range(int(width / 15)):
		draw_rect(Rect2(x + 8 + i * 15, y + 15, 3, 3), edge)

func lantern(p: Vector2, time: float) -> void:
	draw_line(p - Vector2(0, 18), p, Color("756e59"), 2)
	draw_circle(p + Vector2(0, 13), 24, Color(0.95, 0.55, 0.25, 0.035 + sin(time * 3) * 0.01))
	draw_rect(Rect2(p + Vector2(-9, 0), Vector2(18, 25)), Color("b5754e"))
	draw_rect(Rect2(p + Vector2(-6, 2), Vector2(12, 21)), Color("e8ba79"))
	draw_rect(Rect2(p + Vector2(-10, -2), Vector2(20, 3)), Color("34383b"))
	draw_rect(Rect2(p + Vector2(-10, 24), Vector2(20, 3)), Color("34383b"))
	draw_rect(Rect2(p + Vector2(-1, 7), Vector2(2, 11)), Color("a46645"))

func platform(rect: Rect2, cam: float, accent: Color) -> void:
	var ground: bool = rect.size.y > 50
	draw_rect(rect, Color("182e38"))
	draw_rect(Rect2(rect.position + Vector2(0, 5), Vector2(rect.size.x, 7)), Color("384d4e"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("8da797"))
	draw_rect(Rect2(rect.position + Vector2(0, 1), Vector2(rect.size.x, 1)), Color("bed3af"))
	var start: int = maxi(0, int((cam - rect.position.x - 60) / 48))
	var end: int = mini(int(rect.size.x / 48) + 1, int((cam + 1340 - rect.position.x) / 48))
	for col in range(start, end):
		var x: float = rect.position.x + col * 48
		draw_rect(Rect2(x + 3, rect.position.y + 7, 38, 4), Color("4a6060"))
		if ground:
			for row in range(3):
				var y: float = rect.position.y + 22 + row * 39
				draw_rect(Rect2(x + 4, y, 40, 30), Color("203842") if (col + row) % 3 else Color("243e46"))
				draw_rect(Rect2(x + 9, y + 24, 12, 2), Color("344d50"))
			if col % 5 == 0:
				draw_line(Vector2(x + 20, rect.position.y + 18), Vector2(x + 20, rect.position.y + 86), Color("3f6665"), 2)
				draw_line(Vector2(x + 20, rect.position.y + 86), Vector2(x + 42, rect.position.y + 86), Color("3f6665"), 2)
				draw_rect(Rect2(x + 39, rect.position.y + 83, 5, 5), Color(accent, 0.6))
		else:
			draw_rect(Rect2(x + 11, rect.position.y + 14, 19, 4), Color("4f6d68"))

func draw_terminal(terminal: Dictionary, index: int, time: float) -> void:
	var p: Vector2 = terminal.p
	var tint: Color = Color("acdfb7") if terminal.done else game.STAGES[index].color
	draw_rect(Rect2(p + Vector2(-24, -15), Vector2(48, 15)), Color("122b35"))
	draw_rect(Rect2(p + Vector2(-8, -50), Vector2(16, 40)), Color("476466"))
	draw_rect(Rect2(p + Vector2(-42, -108), Vector2(84, 63)), Color("122b35"))
	draw_rect(Rect2(p + Vector2(-38, -104), Vector2(76, 54)), Color("536966"))
	draw_rect(Rect2(p + Vector2(-32, -98), Vector2(64, 41)), Color("18393c"))
	draw_rect(Rect2(p + Vector2(-30, -96), Vector2(60, 3)), tint)
	draw_string(game.pixel_font, p + Vector2(-23, -72), "OK" if terminal.done else ">_", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)
	draw_rect(Rect2(p + Vector2(25, -43), Vector2(5, 5)), tint)
	if absf(game.player.position.x - p.x) < 125 and not terminal.done:
		var ready: bool = game.kills[game.STAGES[index].kind] >= 3 and game.stage == index
		draw_rect(Rect2(p + Vector2(-61, -156), Vector2(122, 31)), Color("122b35"))
		draw_string(game.font, p + Vector2(-50, -133), "E  修复工程" if ready else "E  查看问题", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d7e9c5") if ready else tint)
