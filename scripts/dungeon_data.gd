extends RefCounted
## Data for the top-down rescue run. Tiers start at one; two equal items fuse.

const ARENA := Rect2(20, 44, 1240, 656)
const CENTER := Vector2(640, 372)
const CELL_SPACING := Vector2(1840, 1320)
const CORRIDOR_WIDTH: float = 176.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DOORS: Array[Vector2] = [Vector2(640, 44), Vector2(1260, 372), Vector2(640, 700), Vector2(20, 372)]
const TIER_NAMES: Array[String] = ["普通", "精良", "史诗", "传说"]
const TIER_COLORS: Array[Color] = [Color("a5b9c8"), Color("68dcb4"), Color("b69aff"), Color("ffc878")]
const MULTIPLIERS: Array[float] = [1.0, 1.65, 2.65, 4.1]
const FLOOR_NAMES: Array[String] = ["需求办公室", "迭代工坊", "策划的空中城堡"]
const FLOOR_COLORS: Array[Color] = [Color("77d9b4"), Color("c4a0f2"), Color("ffb878")]
const ROOM_NAMES := {"start":"安全屋", "combat":"故障战区", "elite":"精英工单", "shop":"积分商店", "treasure":"装备宝库", "rest":"咖啡驿站", "boss":"首领房间", "npc":"同伴会客室"}
const DIFFICULTIES: Array[Dictionary] = [
	{"name":"休闲", "health":100, "enemy":0.75, "damage":0.75},
	{"name":"标准", "health":80, "enemy":1.0, "damage":1.0},
	{"name":"硬核", "health":60, "enemy":1.3, "damage":1.25}
]
const WEAPONS: Array[Dictionary] = [
	{"id":"blade", "name":"断点太刀", "kind":"weapon", "tag":"近战 · 扇形斩击", "desc":"自动斩向附近敌人，一刀可命中多个目标。", "price":18, "damage":17.0, "cooldown":0.72, "reach":112.0, "color":Color("74e4cb")},
	{"id":"pistol", "name":"提交手枪", "kind":"weapon", "tag":"远程 · 快速点射", "desc":"自动瞄准；史诗以上的子弹可以穿透一个目标。", "price":18, "damage":10.0, "cooldown":0.48, "reach":490.0, "color":Color("ffd18c")},
	{"id":"wand", "name":"提示词法杖", "kind":"weapon", "tag":"远程 · 连锁电弧", "desc":"命中后跳向附近另一名敌人，升级增加连锁数。", "price":24, "damage":15.0, "cooldown":1.05, "reach":355.0, "color":Color("bd9eff")},
	{"id":"spear", "name":"热修复长枪", "kind":"weapon", "tag":"近战 · 直线贯穿", "desc":"长距离刺击，贯穿同一直线上的所有目标。", "price":22, "damage":22.0, "cooldown":0.94, "reach":180.0, "color":Color("8fcfff")},
	{"id":"shotgun", "name":"需求霰弹枪", "kind":"weapon", "tag":"远程 · 扇形弹幕", "desc":"同时发射五枚弹丸，贴近目标时爆发更高。", "price":28, "damage":7.0, "cooldown":1.15, "reach":320.0, "color":Color("ffa58f")},
	{"id":"orb", "name":"回滚力场", "kind":"weapon", "tag":"范围 · 环形脉冲", "desc":"周期性震退并伤害身边所有敌人。", "price":26, "damage":13.0, "cooldown":1.42, "reach":136.0, "color":Color("9ce6ef")}
]
const EQUIPMENT: Array[Dictionary] = [
	{"id":"vest", "name":"防崩溃背心", "kind":"equipment", "tag":"护甲", "desc":"受到的伤害降低 12% × 品质倍率，上限 65%。", "price":20, "color":Color("8fcfff")},
	{"id":"boots", "name":"敏捷运动鞋", "kind":"equipment", "tag":"移动速度", "desc":"移动速度提高 10% × 品质倍率。", "price":16, "color":Color("ffd18c")},
	{"id":"chip", "name":"超频芯片", "kind":"equipment", "tag":"攻击速度", "desc":"所有武器攻击速度提高 12% × 品质倍率。", "price":22, "color":Color("bd9eff")},
	{"id":"scope", "name":"精准断言镜", "kind":"equipment", "tag":"伤害", "desc":"所有武器伤害提高 15% × 品质倍率。", "price":22, "color":Color("ffa58f")},
	{"id":"coffee", "name":"永动咖啡杯", "kind":"equipment", "tag":"生命恢复", "desc":"每秒恢复 0.5 × 品质倍率点生命。", "price":24, "color":Color("77d9b4")},
	{"id":"heart", "name":"稳定性电池", "kind":"equipment", "tag":"生命上限", "desc":"生命上限增加 20 × 品质倍率，并恢复等量生命。", "price":20, "color":Color("ff96a1")}
]
const DIALOGUES: Array[Dictionary] = [
	{"speaker":"ChatGPT 公主", "line":"毅川救我！策划杨梓亮把我带进了需求城堡……他说还有最后一个小改动！"},
	{"speaker":"毅川", "line":"来了。这一次，我自己选武器。"},
	{"speaker":"杨梓亮 · 策划", "line":"想带走公主？先过需求评审。放心，就改亿点点。"}
]
const BOSS_NAMES: Array[String] = ["需求守门人", "迭代缝合兽", "杨梓亮 · 策划"]
const NPCS: Array[Dictionary] = [
	{"id":"ruoyu", "name":"若宇", "quote":"我这显示是对的", "role":"补给", "offer":"免费恢复 35 点生命。每次偶遇只能领取一次。", "button":"检查显示，领取补给", "color":Color("77d9b4")},
	{"id":"rhode", "name":"罗德", "quote":"给毅川派活", "role":"加急委托", "offer":"下一间战斗房追加一波敌人，完成后获得 45 积分。这里是安全区。", "button":"接下加急工单", "color":Color("ffbe83")},
	{"id":"heide", "name":"海德骑士", "quote":"毅川救我", "role":"临时战友", "offer":"加入队伍，自动追击敌人。跟随当前层，进入下一层后离队。", "button":"并肩救回公主", "color":Color("d9e6dc")},
	{"id":"sekiro", "name":"只狼", "quote":"好他妈卡我草了", "role":"付费训练", "offer":"花费 12 积分，本局所有武器伤害提高 12%。", "button":"学习识破 · 12 积分", "color":Color("ff9e84")},
	{"id":"laya", "name":"菈雅", "quote":"这条路我熟，带上这个吧。", "role":"旅途赠礼", "offer":"免费赠送一件随机武器或装备；背包满时会等你整理。", "button":"接受菈雅的礼物", "color":Color("bb9ef1")},
	{"id":"coin", "name":"硬币", "quote":"别赌运气，积分花在刀刃上。", "role":"游商", "offer":"出售武器和装备，可刷新货架。相同物品可在背包中合并。", "button":"看看硬币的货架", "color":Color("ffcf83")},
	{"id":"onion", "name":"洋葱骑士哈少", "quote":"嗯——先想一想，再一起上！", "role":"技能传授", "offer":"解锁 Q「洋葱守护」：震退周围敌人并抵挡伤害 2 秒，冷却 10 秒。", "button":"学会洋葱守护", "color":Color("ced5ad")}
]

static func item(id: String) -> Dictionary:
	for spec in WEAPONS + EQUIPMENT:
		if spec.id == id:
			return spec
	return {}

static func multiplier(tier: int) -> float:
	return MULTIPLIERS[clampi(tier - 1, 0, 3)]

static func generate(seed_value: int, floor_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + floor_index * 104729
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var target: int = 10 + floor_index
	while cells.size() < target:
		var parent: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var candidate: Vector2i = parent + DIRECTIONS[rng.randi_range(0, 3)]
		if candidate not in cells and absi(candidate.x) <= 3 and absi(candidate.y) <= 3:
			cells.append(candidate)
	var rooms: Array[Dictionary] = []
	for i in range(cells.size()):
		var links: Array[int] = []
		for direction in DIRECTIONS:
			links.append(cells.find(cells[i] + direction))
		rooms.append({"id":i, "cell":cells[i], "links":links, "type":"combat", "visited":false, "revealed":i == 0, "cleared":false, "used":false, "stock":[], "refreshes":0, "layout":rng.randi_range(0, 4)})
	# Breadth-first distance picks a boss actually far from the entrance.
	var distance: Dictionary = {0:0}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for neighbor in rooms[at].links:
			if neighbor >= 0 and not distance.has(neighbor):
				distance[neighbor] = distance[at] + 1
				queue.append(neighbor)
	var boss: int = 1
	for i in range(1, rooms.size()):
		if distance[i] > distance[boss]:
			boss = i
	rooms[0].type = "start"
	rooms[boss].type = "boss"
	var available: Array[int] = []
	for i in range(1, rooms.size()):
		if i != boss:
			available.append(i)
	var special_rooms: Array[String] = ["treasure", "rest", "elite"]
	# One shared optional slot: a floor may have either an NPC or a shop, or neither.
	if rng.randi_range(0, 1) == 1:
		special_rooms.append("npc" if rng.randi_range(0, 1) == 0 else "shop")
	for special in special_rooms:
		var slot: int = rng.randi_range(0, available.size() - 1)
		rooms[available[slot]].type = special
		available.remove_at(slot)
	var npc_pool: Array[int] = [0, 1, 2, 3, 4, 5, 6]
	for room in rooms:
		room["npc"] = -1
		room["npc_used"] = false
		room["started"] = false
		if room.type == "npc":
			var pick: int = rng.randi_range(0, npc_pool.size() - 1)
			room.npc = npc_pool[pick]
			npc_pool.remove_at(pick)
		var sizes: Array[Vector2] = [Vector2(960, 640), Vector2(1280, 832), Vector2(1536, 1056), Vector2(1792, 1216)]
		var size: Vector2 = sizes[rng.randi_range(0, sizes.size() - 1)]
		if room.type in ["start", "npc", "rest", "shop", "treasure"]:
			size = Vector2(864, 608) if room.type == "start" else Vector2(736 + rng.randi_range(0, 2) * 96, 544 + rng.randi_range(0, 1) * 96)
		elif room.type == "boss":
			size = Vector2(1792, 1216)
		elif room.type == "elite":
			size = Vector2(1536, 1056)
		room["center"] = CENTER + Vector2(room.cell) * CELL_SPACING
		room["rect"] = Rect2(room.center - size / 2, size)
		room["doors"] = door_points(room.rect)
		room["obstacles"] = obstacles(room.layout, room.type, room.rect)
	var corridors: Array[Dictionary] = []
	for room in rooms:
		for direction in [1, 2]:
			var neighbor: int = room.links[direction]
			if neighbor < 0:
				continue
			var other: Dictionary = rooms[neighbor]
			var a: Vector2 = room.doors[direction]
			var b: Vector2 = other.doors[(direction + 2) % 4]
			var rect: Rect2
			if direction == 1:
				rect = Rect2(a.x - 64, a.y - CORRIDOR_WIDTH / 2, b.x - a.x + 128, CORRIDOR_WIDTH)
			else:
				rect = Rect2(a.x - CORRIDOR_WIDTH / 2, a.y - 64, CORRIDOR_WIDTH, b.y - a.y + 128)
			corridors.append({"a":room.id, "b":neighbor, "rect":rect, "direction":direction})
	return {"rooms":rooms, "boss":boss, "corridors":corridors}

static func door_points(rect: Rect2) -> Array[Vector2]:
	var c: Vector2 = rect.get_center()
	return [Vector2(c.x, rect.position.y), Vector2(rect.end.x, c.y), Vector2(c.x, rect.end.y), Vector2(rect.position.x, c.y)]

static func gate_rect(room: Dictionary, direction: int) -> Rect2:
	var p: Vector2 = room.doors[direction]
	var size: Vector2 = Vector2(CORRIDOR_WIDTH, 38) if direction % 2 == 0 else Vector2(38, CORRIDOR_WIDTH)
	return Rect2(p - size / 2, size)

static func obstacles(layout: int, room_type: String, bounds: Rect2 = ARENA) -> Array[Rect2]:
	if room_type in ["start", "shop", "rest", "treasure", "boss", "npc"]:
		return []
	# Symmetric islands leave a wide cross through every door and the centre.
	var options: Array = [
		[Rect2(270, 270, 80, 48), Rect2(674, 490, 80, 48)],
		[Rect2(270, 270, 68, 58), Rect2(686, 270, 68, 58), Rect2(270, 490, 68, 58), Rect2(686, 490, 68, 58)],
		[Rect2(300, 260, 54, 95), Rect2(670, 460, 54, 95)],
		[Rect2(240, 290, 120, 42), Rect2(664, 474, 120, 42)],
		[Rect2(290, 255, 64, 64), Rect2(670, 255, 64, 64), Rect2(290, 490, 64, 64), Rect2(670, 490, 64, 64)]
	]
	var result: Array[Rect2] = []
	for rect: Rect2 in options[layout % options.size()]:
		var factor: Vector2 = bounds.size / Vector2(896, 476)
		result.append(Rect2(bounds.position + (rect.position - Vector2(64, 166)) * factor, rect.size * factor))
	return result
