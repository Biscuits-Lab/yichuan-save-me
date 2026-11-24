extends RefCounted
const Data = preload("res://scripts/sandbox_data.gd")
const Catalog = preload("res://scripts/sandbox_catalog.gd")
var v
var g
var journal_tab: int = 0

func _init(canvas) -> void:
	v = canvas
	g = canvas.game

static func paint_tile(image: Image, id: int) -> void:
	var color := Color(Data.BLOCKS[id].color)
	if id in [Data.Block.GOLD,Data.Block.MOLTEN,Data.Block.MYTHRIL,Data.Block.STARSHARD]:
		image.fill(Color("65717f"))
		for p in [Vector2i(3,4),Vector2i(13,3),Vector2i(8,14),Vector2i(17,15)]:
			image.fill_rect(Rect2i(p,Vector2i(5,5)),color.darkened(0.2))
			image.fill_rect(Rect2i(p,Vector2i(4,3)),color)
			image.fill_rect(Rect2i(p,Vector2i(2,1)),color.lightened(0.3))
	elif id == Data.Block.PLATFORM:
		image.fill(Color.TRANSPARENT)
		image.fill_rect(Rect2i(0,0,24,5),color)
		image.fill_rect(Rect2i(0,4,24,2),color.darkened(0.3))
	elif id in [Data.Block.DOOR,Data.Block.DOOR_OPEN]:
		image.fill(Color.TRANSPARENT)
		var width: int = 5 if id == Data.Block.DOOR_OPEN else 20
		image.fill_rect(Rect2i(2,0,width,24),color.darkened(0.3))
		image.fill_rect(Rect2i(4,2,maxi(1,width - 4),20),color)
		if id == Data.Block.DOOR:
			image.fill_rect(Rect2i(16,12,3,3),Color("f2d391"))
	elif id >= Data.Block.CHAIR and id <= Data.Block.CAMPFIRE:
		image.fill(Color.TRANSPARENT)
		match id:
			Data.Block.CHAIR:
				image.fill_rect(Rect2i(4,2,4,20),color)
				image.fill_rect(Rect2i(4,13,16,4),color)
				image.fill_rect(Rect2i(17,17,3,7),color.darkened(0.2))
			Data.Block.CHEST:
				image.fill_rect(Rect2i(2,7,20,16),color.darkened(0.2))
				image.fill_rect(Rect2i(3,4,18,7),color)
				image.fill_rect(Rect2i(2,11,20,3),Color("e5cd8d"))
				image.fill_rect(Rect2i(11,10,3,6),Color("f2e4b2"))
			Data.Block.BED:
				image.fill_rect(Rect2i(0,15,24,5),color)
				image.fill_rect(Rect2i(0,12,7,5),Color("eadfc9"))
				image.fill_rect(Rect2i(1,20,3,4),Color("9e815e"))
				image.fill_rect(Rect2i(20,20,3,4),Color("9e815e"))
			Data.Block.ANVIL:
				image.fill_rect(Rect2i(1,6,22,5),color)
				image.fill_rect(Rect2i(8,11,9,9),color.darkened(0.25))
				image.fill_rect(Rect2i(4,20,17,4),color)
			Data.Block.ALTAR:
				image.fill_rect(Rect2i(2,18,20,6),Color("7b7491"))
				image.fill_rect(Rect2i(7,9,10,12),color.darkened(0.2))
				image.fill_rect(Rect2i(9,2,6,11),color.lightened(0.3))
			Data.Block.CAMPFIRE:
				image.fill_rect(Rect2i(2,19,20,4),Color("ae855b"))
				image.fill_rect(Rect2i(5,9,14,11),color)
				image.fill_rect(Rect2i(8,3,7,15),Color("f6cd87"))
				image.fill_rect(Rect2i(10,10,3,8),Color("fff0c8"))
	elif id in [Data.Block.LIFE_CRYSTAL,Data.Block.HERB,Data.Block.SAPLING,Data.Block.ROPE,Data.Block.MUSHROOM,Data.Block.POT]:
		image.fill(Color.TRANSPARENT)
		match id:
			Data.Block.LIFE_CRYSTAL:
				image.fill_rect(Rect2i(6,5,12,14),color)
				image.fill_rect(Rect2i(3,8,18,7),color)
				image.fill_rect(Rect2i(10,2,4,20),color.lightened(0.25))
			Data.Block.HERB,Data.Block.SAPLING:
				image.fill_rect(Rect2i(11,8,3,16),Color("9a8f56"))
				image.fill_rect(Rect2i(4,12,9,4),color)
				image.fill_rect(Rect2i(13,6,8,5),color.lightened(0.15))
			Data.Block.ROPE:
				image.fill_rect(Rect2i(10,0,4,24),color)
				for y in range(2,24,6):
					image.fill_rect(Rect2i(8,y,8,2),color.darkened(0.25))
			Data.Block.MUSHROOM:
				image.fill_rect(Rect2i(10,12,5,12),Color("eadac4"))
				image.fill_rect(Rect2i(4,7,16,8),color)
				image.fill_rect(Rect2i(7,4,10,5),color)
				image.fill_rect(Rect2i(7,8,3,3),Color("f5e4cf"))
			Data.Block.POT:
				image.fill_rect(Rect2i(5,7,15,15),color)
				image.fill_rect(Rect2i(7,4,11,4),color.darkened(0.3))
				image.fill_rect(Rect2i(8,9,2,8),color.lightened(0.2))

func background(first: Vector2i, end: Vector2i) -> void:
	var walls: PackedByteArray = g.adventure.structures.walls
	for y in range(first.y, end.y):
		var row: int = y * Data.WIDTH
		for x in range(first.x, end.x):
			if walls[row + x] != 0:
				if g.fault.active:
					v.fault_view.draw_back_wall(Vector2i(x, y))
					continue
				var p := Vector2(x, y) * Data.TILE
				v.draw_rect(Rect2(p, Vector2.ONE * Data.TILE), Color("6a584b"))
				v.draw_rect(Rect2(p + Vector2.ONE, Vector2(22, 2)), Color("8c7158"))

func liquids(first: Vector2i, end: Vector2i) -> void:
	var amounts: PackedByteArray = g.adventure.structures.liquid_amount
	var types: PackedByteArray = g.adventure.structures.liquid_type
	for y in range(first.y, end.y):
		var row: int = y * Data.WIDTH
		for x in range(first.x, end.x):
			var index: int = row + x
			var amount: int = amounts[index]
			if amount == 0 or g.world.solid(Vector2i(x, y)):
				continue
			var height: float = amount * 3
			var color := Color(0.32, 0.62, 0.82, 0.7) if types[index] == 1 else Color(0.94, 0.4, 0.19, 0.9)
			var rect := Rect2(Vector2(x, y) * Data.TILE + Vector2(0, Data.TILE - height), Vector2(Data.TILE, height))
			v.draw_rect(rect, color)
			if y == 0 or amounts[index - Data.WIDTH] == 0:
				v.draw_rect(Rect2(rect.position, Vector2(Data.TILE, 2)), color.lightened(0.3))

func enemy(enemy: Dictionary) -> void:
	g.adventure.hydrate(enemy)
	var spec: Dictionary = enemy.spec
	var p: Vector2 = v.render_position(enemy.p,enemy.previous)
	if not v.visible_world.grow(180).has_point(p):
		return
	var tint: Color = Color("fff3cc") if enemy.flash > 0 else Color.WHITE
	if enemy.slow > 0:
		tint = Color("a5dbef")
	if spec.get("fault", false):
		v.fault_view.draw_enemy(enemy, p, tint)
	else:
		var pose: int = 2 if enemy.windup > 0 else (3 if enemy.charge > 0 else int(enemy.age * 6) % 2)
		if spec.art == "expanded":
			pose = 1 if enemy.windup > 0 or enemy.charge > 0 else int(enemy.age * 4) % 2
		var atlas = g.adventure.atlases.get(spec.art,g.enemy_atlas)
		var frame: int = mini(spec.frame + pose,atlas.frames.size() - 1)
		var facing: float = enemy.facing
		if (enemy.kind == "wolf" and pose < 3) or spec.art in ["classic","expanded"]:
			facing *= -1
		atlas.draw(v,frame,p,spec.height,facing,tint)
	if enemy.windup > 0:
		v.world_label("! " + enemy.get("fault_warning", "蓄力"),p - Vector2(0,spec.height + 12),v.CORAL)
	if enemy.burn > 0:
		v.icon("torch",p - Vector2(0,spec.height + 14),15)
	if enemy.hp < enemy.max_hp:
		var width: float = 60 if enemy.boss_index >= 0 or spec.get("fault_boss", false) else 34
		v.draw_rect(Rect2(p - Vector2(width / 2,spec.height + 6),Vector2(width,3)),v.INK)
		v.draw_rect(Rect2(p - Vector2(width / 2,spec.height + 6),Vector2(width * maxf(0,enemy.hp / enemy.max_hp),3)),v.CORAL)

func actors() -> void:
	for npc in g.adventure.structures.npcs:
		if not v.visible_world.grow(80).has_point(npc.p):
			continue
		var names: Dictionary = {"guide":"菈雅 · 向导","nurse":"若宇 · 治疗","heide":"海德骑士","miner":"嘉豪 · 矿工"}
		if npc.id == "heide":
			g.adventure.atlases.heide.draw(v,24,npc.p,47)
		elif npc.id == "miner":
			g.adventure.atlases.jiahao.draw(v,0,npc.p,46)
		else:
			g.adventure.atlases.cast.draw(v,{"guide":8,"nurse":0,"miner":6}[npc.id],npc.p,46)
		v.world_label(names[npc.id],npc.p - Vector2(0,59),v.MINT)
		if npc.p.distance_to(g.player) < 72:
			v.world_label("[%s] 交谈" % g.pad.key("X", "E"),npc.p - Vector2(0,42),v.WHITE)
	if g.adventure.companion:
		var p: Vector2 = g.adventure.companion_p
		g.adventure.atlases.heide.draw(v,int(g.visual_clock * 7) % 8,p,44,1 if p.x < g.player.x else -1)
	for shot in g.adventure.shots:
		var p: Vector2 = v.render_position(shot.p,shot.previous)
		if v.visible_world.has_point(p):
			v.draw_set_transform(p,shot.v.angle())
			v.draw_rect(Rect2(-6,-2,12,4),shot.color)
			v.draw_rect(Rect2(-2,-1,7,2),v.WHITE)
			v.draw_set_transform(Vector2.ZERO)
	for hazard in g.adventure.hazards:
		var rect := Rect2(hazard.p - Vector2(hazard.radius,12),Vector2(hazard.radius * 2,12))
		v.draw_rect(rect,Color(1,0.4,0.35,0.35) if hazard.delay > 0 else Color(1,0.6,0.3,0.75))
		if hazard.delay > 0:
			v.world_label("危险",hazard.p - Vector2(0,30),v.CORAL)
	if g.adventure.hook.is_finite():
		v.draw_line(g.player - Vector2(0,20),g.adventure.hook,Color("c9c8af"),2)
	if not g.adventure.fishing.is_empty():
		var fishing: Dictionary = g.adventure.fishing
		var p: Vector2 = g.cell_center(fishing.cell) + Vector2(0,-7)
		v.draw_line(g.player - Vector2(0,25),p,Color(0.9,0.9,0.8,0.7),1)
		v.draw_circle(p,3,v.CORAL)
		if fishing.time >= fishing.bite:
			v.world_label(g.pad.text("! 咬钩了 · 左键收竿", "! 咬钩了 · {RT} 收竿"),p - Vector2(0,24),v.GOLD)

func hud() -> void:
	v.draw_rect(Rect2(32,100,210,5),Color("334355"))
	v.draw_rect(Rect2(32,100,210 * g.adventure.mana / g.adventure.max_mana(),5),Color("91b5ee"))
	v.text("MP %d" % g.adventure.mana,Vector2(252,108),11,Color("b9d4fa"))
	if g.adventure.heal_cooldown > 0:
		v.text("药水冷却 %d 秒" % ceili(g.adventure.heal_cooldown),Vector2(352,37),12,v.CORAL)
	v.box(Rect2(16,305,319,92),Color(0.07,0.13,0.16,0.88),v.EDGE)
	v.text("%s · Boss %d / 8" % ["困难世界" if g.adventure.hardmode() else "探索世界",g.adventure.stage()],Vector2(31,330),16,v.GOLD,true)
	if g.fault.keeper_unlocked:
		var count: String = "%d" % g.fault.leaks if g.fault.active else "%d / %d" % [g.fault.leaks, g.fault.LIMIT]
		v.text("内存泄漏 " + count, Vector2(216, 330), 13, v.CORAL)
	v.text("护甲 %d   饰品 %d / 5   生命强化 %d" % [g.adventure.defense(),g.adventure.accessories.size(),g.adventure.life_upgrades],Vector2(31,357),12,v.MUTED)
	v.button(Rect2(31,365,140,24),"成长 / 图鉴 · " + g.pad.key("↑", "T"),"journal")
	v.button(Rect2(183,365,135,24),"检查住房 · " + g.pad.key("L3", "F7"),"house_check")
	var boss: Dictionary = g.adventure.current_boss()
	if not boss.is_empty():
		v.box(Rect2(370,17,566,51),v.INK,v.CORAL)
		v.centered(boss.spec.name,Vector2(653,38),16,v.WHITE,true)
		v.draw_rect(Rect2(386,46,534,8),v.PANEL)
		v.draw_rect(Rect2(386,46,534 * maxf(0,boss.hp / boss.max_hp),8),v.CORAL)
	if g.adventure.structures.breath < 12:
		v.centered("氧气 %d%%" % roundi(g.adventure.structures.breath / 12 * 100),Vector2(640,90),16,Color("a7d8ee"))
	if not g.adventure.event.is_empty():
		v.centered("%s · 击退 %d / 24" % [g.adventure.event,g.adventure.event_kills],Vector2(640,120),18,v.CORAL)
	elif g.adventure.blood_moon:
		v.centered("血色加班夜",Vector2(640,120),18,v.CORAL)

func inventory_panel() -> void:
	v.scrim()
	v.box(Rect2(100,48,1080,614),v.INK,v.EDGE,14)
	v.text("随身行囊",Vector2(130,91),27,v.WHITE,true)
	v.text("制作台",Vector2(607,91),27,v.WHITE,true)
	v.button(Rect2(1087,65,66,31),"关闭","resume")
	v.text("%s · 护甲 %d · 5 饰品槽" % [Catalog.PICK_NAMES[g.pick_tier],g.adventure.defense()],Vector2(132,127),14,v.MINT)
	var keys: Array = Data.ITEMS.keys()
	var pages: int = ceili(keys.size() / 25.0)
	g.adventure.inventory_page = clampi(g.adventure.inventory_page,0,pages - 1)
	for position in range(25):
		var at: int = g.adventure.inventory_page * 25 + position
		if at >= keys.size():
			break
		var id: String = keys[at]
		var rect := Rect2(130 + position % 5 * 86,147 + position / 5 * 87,78,78)
		var worn: bool = id == g.adventure.armor or g.adventure.accessories.has(id)
		v.box(rect,v.PANEL,v.MINT if worn else v.EDGE,5)
		v.icon(id,rect.position + Vector2(39,27),30,Color.WHITE if g.count_item(id) > 0 else Color(1,1,1,0.3))
		var label: String = Data.ITEMS[id].name
		v.centered(label if label.length() <= 6 else label.substr(0,5) + "…",rect.position + Vector2(39,58),11,v.WHITE if g.count_item(id) > 0 else v.MUTED)
		v.centered("已装备" if worn else str(g.count_item(id)),rect.position + Vector2(39,73),11,v.GOLD)
		if Data.equippable(id) or Data.ITEMS[id].has("armor") or Data.ITEMS[id].has("accessory"):
			v.buttons.append({"rect":rect,"action":"equip","item":id,"state":g.state})
		if rect.has_point(g.pointer):
			v.text(Data.ITEMS[id].name + " ×%d" % g.count_item(id),Vector2(132,643),13,v.MINT)
	v.button(Rect2(130,585,90,27),"上一页","bag_page",-1)
	v.centered("%d / %d" % [g.adventure.inventory_page + 1,pages],Vector2(336,605),14,v.MUTED)
	v.button(Rect2(472,585,80,27),"下一页","bag_page",1)
	for category in range(4):
		v.button(Rect2(606 + category * 136,111,128,34),["1 建造","2 冶炼 / 防具","3 战斗 / 探索","4 Boss / 事件"][category],"category",category,g.recipe_category == category)
	var filtered: Array[int] = []
	for i in range(Data.RECIPES.size()):
		if Data.RECIPES[i].category == g.recipe_category:
			filtered.append(i)
	var recipe_pages: int = maxi(1,ceili(filtered.size() / 6.0))
	g.adventure.recipe_page = clampi(g.adventure.recipe_page,0,recipe_pages - 1)
	for row in range(6):
		var at: int = g.adventure.recipe_page * 6 + row
		if at >= filtered.size():
			break
		var index: int = filtered[at]
		var recipe: Dictionary = Data.RECIPES[index]
		var y: float = 159 + row * 73
		var reason: String = g.craft_reason(index)
		v.box(Rect2(604,y,548,65),v.PANEL,v.EDGE,5)
		var item: String = "pickaxe" if recipe.id.ends_with("pick") else ("sword" if recipe.id.ends_with("sword") else recipe.id)
		v.icon(item,Vector2(630,y + 26),27)
		v.text(recipe.get("name",Data.ITEMS.get(recipe.id,{}).get("name",recipe.id)) + (" ×%d" % recipe.amount if recipe.amount > 1 else ""),Vector2(653,y + 22),16,v.WHITE,true)
		var cost: String = ""
		for id in recipe.cost:
			cost += "%s %d/%d  " % [Data.ITEMS[id].name,g.count_item(id),recipe.cost[id]]
		v.text(cost,Vector2(615,y + 54),12,v.GOLD if reason.is_empty() else v.MUTED)
		v.button(Rect2(1010,y + 10,130,28),"制作" if reason.is_empty() else reason,"craft",index,reason.is_empty())
		if Rect2(604,y,548,65).has_point(g.pointer):
			v.text(recipe.desc,Vector2(606,651),12,v.MINT)
	v.button(Rect2(606,605,98,27),"上一页","recipe_page",-1)
	v.centered("%d / %d" % [g.adventure.recipe_page + 1,recipe_pages],Vector2(880,625),14,v.MUTED)
	v.button(Rect2(1054,605,98,27),"下一页","recipe_page",1)

func journal() -> void:
	v.scrim()
	v.box(Rect2(140,58,1000,600),v.INK,v.EDGE,14)
	v.text("旷野手册",Vector2(174,105),30,v.WHITE,true)
	v.text("%s · %s" % [g.adventure.biome_name(),"困难世界" if g.adventure.hardmode() else "初始世界"],Vector2(175,136),16,v.MUTED)
	v.button(Rect2(1025,79,82,32),"关闭","resume")
	v.button(Rect2(174,154,230,34),"成长与 Boss","journal_tab",0,journal_tab == 0)
	v.button(Rect2(421,154,230,34),"怪物图鉴","journal_tab",1,journal_tab == 1)
	if journal_tab == 0:
		for i in range(Catalog.BOSSES.size()):
			var boss: Dictionary = Catalog.BOSSES[i]
			var cleared: bool = g.adventure.bosses.get(boss.id,false)
			var y: float = 220 + i * 49
			v.box(Rect2(174,y - 23,932,43),v.PANEL,v.MINT if cleared else v.EDGE,5)
			v.text(("✓ " if cleared else "%02d " % (i + 1)) + boss.name,Vector2(190,y + 3),17,v.MINT if cleared else v.WHITE,true)
			v.text("掉落 " + Data.ITEMS[boss.drop].name,Vector2(552,y + 3),14,v.GOLD)
			v.text("已击败" if cleared else ("可挑战" if i <= g.adventure.stage() else "未解锁"),Vector2(991,y + 3),14,v.MUTED)
	else:
		var keys: Array = Catalog.ENEMIES.keys()
		var behaviors: Dictionary = {"hop":"跳跃追击","charge":"预警冲锋","wolf":"扑击追猎","caster":"扇形弹幕","walk":"地面追击","fly":"飞行追踪","shield":"正面护盾","hazard":"地面预警","fly_shoot":"飞行弹幕","ring":"环形弹幕","split":"分裂繁殖"}
		for i in range(keys.size()):
			var spec: Dictionary = Catalog.ENEMIES[keys[i]]
			var p := Vector2(181 + i % 2 * 475,224 + i / 2 * 39)
			v.text(spec.name,p,16,v.WHITE,true)
			v.text("击败 %d · %s" % [g.adventure.bestiary.get(keys[i],0),behaviors[spec.ai]],p + Vector2(230,0),12,v.MUTED)

func chest_panel() -> void:
	v.scrim()
	v.box(Rect2(260,110,760,500),v.INK,v.EDGE,14)
	v.text("储物箱",Vector2(294,160),29,v.WHITE,true)
	v.button(Rect2(904,133,81,32),"关闭","resume")
	var storage: Dictionary = g.adventure.structures.chests.get(g.adventure.structures.selected_chest,{})
	var keys: Array = storage.keys().filter(func(id): return storage[id] > 0)
	var pages: int = maxi(1,ceili(keys.size() / 24.0))
	g.adventure.structures.chest_page = clampi(g.adventure.structures.chest_page,0,pages - 1)
	for index in range(mini(24, keys.size() - g.adventure.structures.chest_page * 24)):
		var id: String = keys[g.adventure.structures.chest_page * 24 + index]
		var p := Vector2(300 + index % 4 * 174,214 + index / 4 * 44)
		v.icon(id,p,25)
		v.text(Data.ITEMS[id].name.substr(0,6) + " ×%d" % storage[id],p + Vector2(19,5),12,v.WHITE)
	if keys.is_empty():
		v.centered("箱子空空的。",Vector2(640,339),22,v.MUTED)
	v.button(Rect2(296,465,120,28),"上一页","chest_page",-1)
	v.centered("%d / %d" % [g.adventure.structures.chest_page + 1,pages],Vector2(640,485),14,v.MUTED)
	v.button(Rect2(864,465,120,28),"下一页","chest_page",1)
	v.button(Rect2(296,524,324,46),"存入材料","chest_deposit")
	v.button(Rect2(640,524,344,46),"全部取出","chest_take",0,true)

func npc_panel() -> void:
	v.scrim()
	v.box(Rect2(300,170,680,375),v.INK,v.EDGE,14)
	var id: String = g.adventure.structures.selected_npc
	v.text({"guide":"菈雅 · 向导","nurse":"若宇 · 治疗","heide":"海德骑士","miner":"嘉豪 · 矿工"}[id],Vector2(340,226),30,v.WHITE,true)
	var descriptions: Dictionary = {"guide":"先建封闭房间，铺满背景墙，放工作台、椅子和火把。\n每一场 Boss 都会给下一阶段的材料。按 T 看成长手册。","nurse":"我这显示是对的。花 10 旧银币，恢复全部生命。","heide":"毅川救我！这次换我和你一起迎战。","miner":"装备到位，直接开干。12 旧银币换 10 煤炭和 30 木箭。"}
	var row: int = 0
	for line in descriptions[id].split("\n"):
		v.text(line,Vector2(341,280 + row * 32),16,v.MUTED)
		row += 1
	v.button(Rect2(340,398,600,45),{"guide":"询问下一步","nurse":"治疗 · 10 旧银币","heide":"加入 / 暂停同行","miner":"购买矿工补给 · 12 旧银币"}[id],"town_service",0,true)
	v.button(Rect2(340,462,600,39),"继续探索","resume")

func click(action: String, entry: Dictionary) -> bool:
	match action:
		"journal": g.set_state("journal")
		"journal_tab": journal_tab = entry.index
		"house_check":
			var house: Dictionary = g.adventure.structures.register_house(g.cell_at(g.player - Vector2(0,12)))
			g.notify(house.reason)
		"bag_page": g.adventure.inventory_page += entry.index
		"recipe_page": g.adventure.recipe_page += entry.index
		"chest_deposit": g.adventure.structures.transfer_chest(true)
		"chest_take": g.adventure.structures.transfer_chest(false)
		"chest_page": g.adventure.structures.chest_page += entry.index
		"town_service": g.adventure.town_service()
		_: return false
	return true
