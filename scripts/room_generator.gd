class_name RogueRooms
extends RefCounted

const LAYOUTS: Array[String] = ["断桥双廊", "阶梯机房", "高架回路", "镜像庭院", "缓存塔桥", "交错栈道"]

static func generate(seed_value: int, floor_number: int, route: String) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + floor_number * 7919 + route.hash()
	var layout: int = random.randi_range(0, LAYOUTS.size() - 1)
	var length: float = 3520
	var platforms: Array[Rect2] = [Rect2(0, 600, 1020, 180), Rect2(1180, 600, 1050, 180), Rect2(2390, 600, 1130, 180)]
	# Two guaranteed, ascending routes. Adjacent steps rise at most 120 pixels;
	# the 160px ground gaps always have a bridge above them.
	var ledges: Array[Rect2] = [
		Rect2(530, 490, 220, 22), Rect2(790, 380, 240, 22), Rect2(990, 480, 260, 22),
		Rect2(1330, 490, 210, 22), Rect2(1570, 380, 240, 22), Rect2(1830, 480, 220, 22),
		Rect2(2090, 480, 350, 22), Rect2(2500, 490, 190, 22), Rect2(2800, 390, 230, 22), Rect2(3100, 420, 200, 22)
	]
	for i in range(ledges.size()):
		# Change horizontal spacing and the secondary route without breaking reach.
		var rect: Rect2 = ledges[i]
		if i in [0, 3, 7, 9]:
			rect.position.x += random.randi_range(-25, 25)
		if layout % 2 == 1 and i in [1, 4, 8]:
			rect.position.y += 35
		platforms.append(rect)
	if layout in [2, 4]:
		platforms.append(Rect2(1170, 280, 220, 22))
		platforms.append(Rect2(1870, 280, 200, 22))
	if layout in [3, 5]:
		platforms.append(Rect2(470, 310, 180, 22))
		platforms.append(Rect2(2580, 280, 170, 22))
	var relay_y: float = 380 if layout % 2 == 0 else 415
	var traps: Array[Rect2] = [Rect2(1400, 580, 160, 20), Rect2(2540, 580, 150, 20)]
	if route == "elite":
		traps.append(Rect2(1780, 580, 150, 20))
	return {"name": LAYOUTS[layout], "layout": layout, "length": length, "platforms": platforms,
		"gates": [1600.0, 2650.0], "boss_spawn": Vector2(3160,598),
		"gaps": [Rect2(1020, 605, 160, 115), Rect2(2230, 605, 160, 115)],
		"relays": [{"p": Vector2(910, relay_y), "done": false}, {"p": Vector2(2190, 480), "done": false}],
		"traps": traps, "chest": Vector2(2900, 390), "spawn": Vector2(180, 598)}
