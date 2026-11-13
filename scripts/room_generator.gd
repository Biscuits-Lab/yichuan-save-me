class_name RogueRooms
extends RefCounted

const LAYOUTS: Array[String] = ["断桥双廊", "阶梯机房", "高架回路", "镜像庭院", "缓存塔桥", "交错栈道"]
const ZONE_LENGTH: float = 1900
const ZONE_COUNT: int = 3

static func generate(seed_value: int, floor_number: int, route: String) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + floor_number * 7919 + route.hash()
	var layout: int = random.randi_range(0, LAYOUTS.size() - 1)
	var length: float = ZONE_LENGTH * ZONE_COUNT + 1340
	var platforms: Array[Rect2] = []
	var gaps: Array[Rect2] = []
	var gates: Array[float] = []
	var relays: Array[Dictionary] = []
	var zones: Array[Dictionary] = []
	var encounters: Array[Dictionary] = []
	var coffee: Array[Vector2] = []
	var npc_ids: Array[int] = [0,1,2,3]
	for zone in range(ZONE_COUNT):
		var offset: float = zone * ZONE_LENGTH
		var variant: int = (layout + zone + floor_number) % LAYOUTS.size()
		platforms.append(Rect2(offset,600,1020,180))
		platforms.append(Rect2(offset + 1180,600,720,180))
		gaps.append(Rect2(offset + 1020,605,160,115))
		var ledges: Array[Rect2] = [
			Rect2(530,490,220,22), Rect2(790,380,240,22), Rect2(990,480,260,22),
			Rect2(1330,490,210,22), Rect2(1570,380,240,22)
		]
		for i in range(ledges.size()):
			var ledge: Rect2 = ledges[i]
			if i in [0,3]:
				ledge.position.x += random.randi_range(-25,25)
			if variant % 2 == 1 and i in [1,4]:
				ledge.position.y += 35
			ledge.position.x += offset
			platforms.append(ledge)
		if variant in [2,4]:
			platforms.append(Rect2(offset + 1170,280,220,22))
		elif variant in [3,5]:
			platforms.append(Rect2(offset + 470,310,180,22))
		var gate_x: float = offset + 1770
		gates.append(gate_x)
		relays.append({"p":Vector2(gate_x - 100,600),"done":false})
		zones.append({"start":offset,"end":offset + ZONE_LENGTH,
			"trigger":offset + (510 if zone == 0 else 180),"first_wave":zone * 2,"waves":2})
		coffee.append(Vector2(offset + 1410,455))
		# Seeded encounters are revealed only when reached during exploration.
		if encounters.size() < 2 and random.randf() < 0.68:
			var npc_index: int = random.randi_range(0,npc_ids.size() - 1)
			var point := Vector2(offset + random.randi_range(1490,1630),600)
			encounters.append({"id":npc_ids.pop_at(npc_index),"p":point,
				"trigger_x":point.x - 360,"revealed":false})
	platforms.append(Rect2(ZONE_LENGTH * ZONE_COUNT,600,1340,180))
	platforms.append(Rect2(5900,490,200,22))
	platforms.append(Rect2(6150,390,230,22))
	return {"name":LAYOUTS[layout],"layout":layout,"length":length,"platforms":platforms,
		"zones":zones,"gates":gates,"relays":relays,"gaps":gaps,"encounters":encounters,
		"coffee":coffee,"arena":Vector2(5800,length - 200),"boss_spawn":Vector2(length - 450,598),
		"chest":Vector2(6260,390),"spawn":Vector2(180,598)}
