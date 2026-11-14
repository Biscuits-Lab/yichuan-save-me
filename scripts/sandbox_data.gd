extends RefCounted
## Deterministic, editable world data. Simulation and saves share these tile IDs.
const TILE: int = 24
const WIDTH: int = 576
const HEIGHT: int = 192
const CHUNK: int = 16
const DAY_SECONDS: float = 600.0
const MERCHANT_INTERVAL: int = 5
const PRIEST: Dictionary = {
	"name":"神父", "role":"CTO",
	"quote":"毅川，物资备好了。\n需求我来挡，公主你去救。",
	"thanks":"神父：补给领好。需求有变我来扛，别把自己也写成 Bug。"
}
const REVIEW_SECONDS: float = 60.0
const REVIEW_MAX_TURNS: int = 16
const REVIEW_PAIRS: Array[Dictionary] = [
	{"code":"NULL", "name":"空指针", "color":"f0ba87"},
	{"code":"LEAK", "name":"内存泄漏", "color":"91d6b0"},
	{"code":"LOCK", "name":"死锁", "color":"c2a4e6"},
	{"code":"RACE", "name":"竞争条件", "color":"e99ea4"},
	{"code":"BOUNDS", "name":"数组越界", "color":"9dcde1"},
	{"code":"STATE", "name":"状态错误", "color":"e0ce92"},
	{"code":"LOOP", "name":"死循环", "color":"a9b6ed"},
	{"code":"TEST", "name":"漏写测试", "color":"d7b0c8"},
	{"code":"UNDO", "name":"回滚失效", "color":"b8ca9f"},
	{"code":"BUILD", "name":"构建失败", "color":"e0b899"}
]
enum Block { AIR, GRASS, DIRT, STONE, WOOD, LEAF, COPPER, IRON, CRYSTAL, PLANK, TORCH, BENCH, FURNACE, BEDROCK, SAND, SNOW, CORE, COAL, BEACON }
const BLOCKS: Array[Dictionary] = [
	{"name":"空气", "item":"", "solid":false, "hardness":0.0, "tier":0, "color":"00000000"},
	{"name":"草地", "item":"dirt", "solid":true, "hardness":0.28, "tier":0, "color":"6e9c55"},
	{"name":"泥土", "item":"dirt", "solid":true, "hardness":0.28, "tier":0, "color":"956447"},
	{"name":"石块", "item":"stone", "solid":true, "hardness":0.65, "tier":0, "color":"747c89"},
	{"name":"原木", "item":"wood", "solid":false, "hardness":0.38, "tier":0, "color":"996c45"},
	{"name":"树叶", "item":"wood", "solid":false, "hardness":0.12, "tier":0, "color":"4d8861"},
	{"name":"铜矿", "item":"copper_ore", "solid":true, "hardness":1.0, "tier":0, "color":"dd9460"},
	{"name":"铁矿", "item":"iron_ore", "solid":true, "hardness":1.2, "tier":1, "color":"bdc9d0"},
	{"name":"辉光水晶", "item":"crystal", "solid":true, "hardness":1.4, "tier":2, "color":"a5a2ef"},
	{"name":"木板", "item":"plank", "solid":true, "hardness":0.3, "tier":0, "color":"c18f60"},
	{"name":"火把", "item":"torch", "solid":false, "hardness":0.1, "tier":0, "color":"f5bb68"},
	{"name":"工作台", "item":"bench", "solid":false, "hardness":0.3, "tier":0, "color":"c38d60"},
	{"name":"熔炉", "item":"furnace", "solid":false, "hardness":0.55, "tier":0, "color":"989899"},
	{"name":"基岩", "item":"", "solid":true, "hardness":999.0, "tier":99, "color":"303840"},
	{"name":"沙块", "item":"sand", "solid":true, "hardness":0.25, "tier":0, "color":"d4b77d"},
	{"name":"雪块", "item":"snow", "solid":true, "hardness":0.3, "tier":0, "color":"c5dbe1"},
	{"name":"大地之心", "item":"core", "solid":true, "hardness":3.0, "tier":2, "color":"f4cf84"},
	{"name":"煤矿", "item":"coal", "solid":true, "hardness":0.75, "tier":0, "color":"333e4b"},
	{"name":"归途信标", "item":"beacon", "solid":false, "hardness":0.5, "tier":0, "color":"8df3cf"}
]
const ITEMS: Dictionary = {
	"pickaxe":{"name":"采掘镐", "color":"c6d0d8", "block":0}, "sword":{"name":"猎虫剑", "color":"e0e9df", "block":0},
	"dirt":{"name":"泥土", "color":"956447", "block":Block.DIRT}, "stone":{"name":"石块", "color":"828b98", "block":Block.STONE},
	"wood":{"name":"原木", "color":"af8052", "block":Block.WOOD}, "plank":{"name":"木板", "color":"c69c6e", "block":Block.PLANK},
	"torch":{"name":"火把", "color":"f9bb66", "block":Block.TORCH}, "bench":{"name":"工作台", "color":"c38d60", "block":Block.BENCH},
	"furnace":{"name":"熔炉", "color":"989899", "block":Block.FURNACE}, "potion":{"name":"治疗药水", "color":"ee8e9c", "block":0},
	"copper_ore":{"name":"铜矿石", "color":"e59a64", "block":0}, "iron_ore":{"name":"铁矿石", "color":"c1d2d8", "block":0},
	"coal":{"name":"煤炭", "color":"525967", "block":0}, "copper_bar":{"name":"铜锭", "color":"eba46d", "block":0},
	"iron_bar":{"name":"铁锭", "color":"d4e2e8", "block":0}, "crystal":{"name":"辉光水晶", "color":"b7a3f3", "block":0},
	"gel":{"name":"凝胶", "color":"8adba6", "block":0}, "sand":{"name":"沙块", "color":"d4b77d", "block":Block.SAND},
	"snow":{"name":"雪块", "color":"c5dbe1", "block":Block.SNOW}, "core":{"name":"大地之心", "color":"f4cf84", "block":0},
	"beacon":{"name":"归途信标", "color":"8df3cf", "block":Block.BEACON}, "coin":{"name":"旧银币", "color":"e5ce95", "block":0},
	"lantern":{"name":"猎人提灯", "color":"f6d193", "block":0}, "charm":{"name":"神父护符", "color":"b6cde0", "block":0}
}
const HOTBAR: Array[String] = ["pickaxe", "sword", "dirt", "stone", "wood", "plank", "torch", "bench", "furnace", "potion"]
const RECIPES: Array[Dictionary] = [
	{"id":"plank", "amount":4, "cost":{"wood":1}, "station":0, "category":0, "desc":"搭桥、垫脚，也能建造自己的小屋。"},
	{"id":"torch", "amount":4, "cost":{"wood":1, "gel":1}, "station":0, "category":0, "desc":"驱散地下与夜晚的黑暗。"},
	{"id":"torch", "amount":4, "cost":{"wood":1, "coal":1}, "station":0, "category":0, "desc":"用煤炭替代凝胶制作照明。"},
	{"id":"bench", "amount":1, "cost":{"wood":8}, "station":0, "category":0, "desc":"放在地面，靠近后解锁装备制作。"},
	{"id":"furnace", "amount":1, "cost":{"stone":20, "torch":4}, "station":Block.BENCH, "category":0, "desc":"放置后靠近，可将矿石熔炼成锭。"},
	{"id":"potion", "amount":1, "cost":{"gel":4, "wood":2}, "station":Block.BENCH, "category":0, "desc":"按 H 饮用，立即恢复 45 生命。"},
	{"id":"copper_bar", "amount":1, "cost":{"copper_ore":3, "coal":1}, "station":Block.FURNACE, "category":1, "desc":"铜装备的基础材料。"},
	{"id":"iron_bar", "amount":1, "cost":{"iron_ore":3, "coal":1}, "station":Block.FURNACE, "category":1, "desc":"铁装备与信标的基础材料。"},
	{"id":"copper_pick", "name":"铜镐", "amount":1, "cost":{"copper_bar":5, "wood":6}, "station":Block.BENCH, "category":1, "tier":1, "desc":"采掘加速，并可开采铁矿。"},
	{"id":"iron_pick", "name":"铁镐", "amount":1, "cost":{"iron_bar":6, "wood":8}, "station":Block.BENCH, "category":1, "tier":2, "desc":"采掘进一步加速，可开采水晶与大地之心。"},
	{"id":"copper_sword", "name":"铜剑", "amount":1, "cost":{"copper_bar":4, "wood":4}, "station":Block.BENCH, "category":2, "tier":1, "desc":"剑伤害提升到 24。"},
	{"id":"iron_sword", "name":"铁剑", "amount":1, "cost":{"iron_bar":5, "wood":4}, "station":Block.BENCH, "category":2, "tier":2, "desc":"剑伤害提升到 36。"},
	{"id":"beacon", "amount":1, "cost":{"core":1, "crystal":12, "iron_bar":4}, "station":Block.BENCH, "category":2, "desc":"在地表放置信标，完成旷野探索。之后仍可继续建造。"}
]
const OFFERS: Array[Dictionary] = [
	{"id":"torch", "amount":12, "price":6, "stock":8, "desc":"一束火光，足够走过下一段黑夜。"},
	{"id":"potion", "amount":3, "price":12, "stock":5, "desc":"恢复生命的应急补给。H 快捷使用。"},
	{"id":"wood", "amount":30, "price":10, "stock":6, "desc":"干燥的木料，可用于建筑与制作。"},
	{"id":"coal", "amount":12, "price":14, "stock":4, "desc":"熔炼矿石需要的燃料。"},
	{"id":"copper_ore", "amount":15, "price":18, "stock":4, "desc":"准备好你的第一套铜装备。"},
	{"id":"iron_ore", "amount":12, "price":28, "stock":3, "desc":"从遥远矿井运来的铁矿。"},
	{"id":"lantern", "amount":1, "price":55, "stock":1, "unique":true, "desc":"随身生效：地下照明范围扩大。"},
	{"id":"charm", "amount":1, "price":65, "stock":1, "unique":true, "desc":"随身生效：生命上限增加 20。"}
]

var seed_value: int = 1
var tiles := PackedByteArray()
var explored := PackedByteArray()
var surface := PackedInt32Array()
var dirty_chunks: Dictionary = {}
var torch_cells: Dictionary = {}
var spawn := Vector2.ZERO
var heart_cell := Vector2i.ZERO
var revision: int = 0

func valid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < WIDTH and c.y >= 0 and c.y < HEIGHT

func tile(c: Vector2i) -> int:
	return tiles[c.y * WIDTH + c.x] if valid(c) and tiles.size() == WIDTH * HEIGHT else Block.BEDROCK

func solid(c: Vector2i) -> bool:
	return BLOCKS[tile(c)].solid

func set_tile(c: Vector2i, value: int) -> void:
	if not valid(c):
		return
	tiles[c.y * WIDTH + c.x] = value
	var chunk := Vector2i(c.x / CHUNK, c.y / CHUNK)
	dirty_chunks[chunk] = true
	if value in [Block.TORCH, Block.BEACON]:
		torch_cells[c] = true
	else:
		torch_cells.erase(c)
	revision += 1

func surface_at(x: int) -> int:
	return surface[clampi(x, 0, WIDTH - 1)] if surface.size() == WIDTH else 60

func biome(x: int) -> String:
	return "落日沙丘" if x < WIDTH * 0.23 else ("霜松雪原" if x > WIDTH * 0.77 else "青苔旷野")

func generate(chosen_seed: int) -> void:
	seed_value = chosen_seed
	tiles.resize(WIDTH * HEIGHT)
	tiles.fill(Block.AIR)
	explored.resize(WIDTH * HEIGHT)
	explored.fill(0)
	surface.resize(WIDTH)
	torch_cells.clear()
	dirty_chunks.clear()
	var hills := FastNoiseLite.new()
	hills.seed = chosen_seed
	hills.frequency = 0.018
	hills.fractal_octaves = 3
	var caves := FastNoiseLite.new()
	caves.seed = chosen_seed ^ 61571
	caves.frequency = 0.055
	var veins := FastNoiseLite.new()
	veins.seed = chosen_seed ^ 25399
	veins.frequency = 0.16
	var rng := RandomNumberGenerator.new()
	rng.seed = chosen_seed
	for x in range(WIDTH):
		var ground: int = 59 + roundi(hills.get_noise_1d(x) * 16)
		if absi(x - WIDTH / 2) < 17:
			ground = 59
		surface[x] = ground
		for y in range(ground, HEIGHT):
			var id: int = Block.DIRT if y < ground + 7 else Block.STONE
			if y == ground:
				id = Block.GRASS
			if x < WIDTH * 0.23 and y < ground + 8:
				id = Block.SAND
			elif x > WIDTH * 0.77 and y < ground + 5:
				id = Block.SNOW
			if y > ground + 10 and caves.get_noise_2d(x, y) > 0.13:
				id = Block.AIR
			elif id == Block.STONE:
				var vein: float = veins.get_noise_2d(x, y)
				if vein > 0.27:
					id = Block.COPPER if y < 98 else Block.IRON
				elif vein < -0.32:
					id = Block.COAL
				elif y > 103 and vein > 0.15 and caves.get_noise_2d(x + 100, y) < -0.19:
					id = Block.CRYSTAL
			if x == 0 or x == WIDTH - 1 or y >= HEIGHT - 2:
				id = Block.BEDROCK
			tiles[y * WIDTH + x] = id
	# A walkable cave entrance east of spawn makes the first expedition readable.
	var entry: int = WIDTH / 2 + 23
	for step in range(100):
		var cx: int = entry + step
		var cy: int = surface[entry] + step / 3
		for dx in range(-2, 3):
			for dy in range(-4, 1):
				tiles[(cy + dy) * WIDTH + cx + dx] = Block.AIR
	# Guaranteed starter veins beside the entrance, still requiring excavation.
	for n in range(14):
		var c := Vector2i(entry + 16 + n / 3, surface[entry] + 8 + n % 3)
		tiles[c.y * WIDTH + c.x] = Block.COPPER
	for n in range(16):
		var c := Vector2i(entry + 33 + n / 4, surface[entry] + 13 + n % 4)
		tiles[c.y * WIDTH + c.x] = Block.COAL
	for x in range(8, WIDTH - 8):
		if x < WIDTH * 0.23 or absi(x - WIDTH / 2) < 4:
			continue
		if x % 8 == 0 and rng.randf() < 0.72 and tile(Vector2i(x, surface[x])) in [Block.GRASS, Block.SNOW]:
			plant_tree(x, rng.randi_range(5, 9))
	heart_cell = Vector2i(WIDTH / 2 + 74, 143)
	for dx in range(-7, 8):
		for dy in range(-5, 4):
			if Vector2(dx, dy).length() < 7:
				tiles[(heart_cell.y + dy) * WIDTH + heart_cell.x + dx] = Block.AIR
	tiles[heart_cell.y * WIDTH + heart_cell.x] = Block.CORE
	for dx in [-4, -3, 3, 4]:
		tiles[(heart_cell.y + 3) * WIDTH + heart_cell.x + dx] = Block.CRYSTAL
	spawn = Vector2((WIDTH / 2 + 0.5) * TILE, surface[WIDTH / 2] * TILE - 0.01)
	revision += 1

func plant_tree(x: int, height: int) -> void:
	var ground: int = surface[x]
	for y in range(ground - height, ground):
		tiles[y * WIDTH + x] = Block.WOOD
	for dx in range(-3, 4):
		for dy in range(-3, 2):
			if absf(dx / 3.5) + absf(dy / 3.5) < 1.5 and dx != 0:
				var c := Vector2i(x + dx, ground - height + dy)
				if tile(c) == Block.AIR:
					tiles[c.y * WIDTH + c.x] = Block.LEAF

func reveal(p: Vector2) -> bool:
	var at := Vector2i((p / TILE).floor())
	var changed: bool = false
	for dx in range(-13, 14):
		for dy in range(-11, 12):
			var c: Vector2i = at + Vector2i(dx, dy)
			if valid(c) and dx * dx + dy * dy < 170 and explored[c.y * WIDTH + c.x] == 0:
				explored[c.y * WIDTH + c.x] = 1
				changed = true
	return changed

static func merchant_schedule(game_day: int) -> Dictionary:
	var day: int = maxi(1, game_day)
	var present: bool = day % MERCHANT_INTERVAL == 0
	var next_day: int = (day / MERCHANT_INTERVAL + 1) * MERCHANT_INTERVAL
	return {"present":present, "day":day, "next_day":next_day, "days":next_day - day}
