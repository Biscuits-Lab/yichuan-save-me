extends Node2D
var game: Node
var speech_style: StyleBoxFlat
const CREAM := Color("f2e6cb")
const MINT := Color("b0e3bf")
const MUTED := Color("91aca2")
const INK := Color("0d202b")
const CORAL := Color("e78d7b")

func _ready() -> void:
	speech_style = StyleBoxFlat.new()
	speech_style.bg_color = Color("eee9d1")
	speech_style.border_color = Color("b4cbb0")
	speech_style.set_border_width_all(1)
	speech_style.set_corner_radius_all(9)

func _draw() -> void:
	if game.state == "title" or (game.state == "guide" and game.previous_state == "title"):
		title_screen()
	else:
		game_hud()
	match game.state:
		"guide": guide()
		"build": build_panel()
		"upgrade": upgrades()
		"route": routes()
		"npc": npc_panel()
		"paused", "dead", "won": overlay()
	for y in range(0,720,4):
		draw_rect(Rect2(0,y,1280,1),Color(0,0,0,0.035))

func text(value: String, point: Vector2, size: int = 20, color: Color = CREAM, font: Font = null) -> void:
	draw_string(game.font if font == null else font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func pixel(value: String, point: Vector2, size: int = 9, color: Color = MUTED) -> void:
	text(value,point,size,color,game.pixel_font)

func center(value: String, point: Vector2, size: int, color: Color = CREAM) -> void:
	text(value,point - Vector2(game.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x * 0.5,0),size,color)

func paragraph(value: String, point: Vector2, width: float, size: int = 18, color: Color = MUTED, max_lines: int = 5) -> void:
	var line: String = ""
	var row: int = 0
	for character in value:
		if game.font.get_string_size(line + character,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width or character == "\n":
			text(line,point + Vector2(0,row * (size + 9)),size,color)
			row += 1
			line = ""
			if row >= max_lines:
				return
		if character != "\n":
			line += character
	text(line,point + Vector2(0,row * (size + 9)),size,color)

func panel(rect: Rect2, fill: Color = INK, border: Color = Color("3d5c54")) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,border,false,1)
	draw_rect(Rect2(rect.position - Vector2.ONE,Vector2(4,4)),border)
	draw_rect(Rect2(rect.end - Vector2(3,3),Vector2(4,4)),border)

func button(rect: Rect2, label: String, primary: bool, selected: bool = false) -> void:
	var hover: bool = rect.has_point(get_global_mouse_position()) or selected
	panel(rect,Color("cdeac8") if primary and hover else (MINT if primary else (Color("274344") if hover else Color("122c36"))),MINT if primary or hover else Color("506e64"))
	text(label,rect.position + Vector2(22,rect.size.y * 0.5 + 8),20,INK if primary else CREAM)
	text("→",Vector2(rect.end.x - 36,rect.position.y + rect.size.y * 0.5 + 8),24,INK if primary else MINT)

func scrim() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.025,0.065,0.09,0.95))

func icon(index: int, point: Vector2, size: float = 60) -> void:
	if game.icons_atlas:
		game.icons_atlas.draw(self,index,point,size,1,Color.WHITE,true)

func title_screen() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("0c1426"))
	draw_texture_rect(game.key_art,Rect2(-12,-70 + sin(game.clock * 0.25) * 3,1304,870),false)
	for i in range(65):
		draw_rect(Rect2(i * 14,0,14,720),Color(0.025,0.06,0.105,clampf(0.92 - i / 69.0,0,0.92)))
	draw_rect(Rect2(94,54,8,8),MINT)
	pixel("YICHUAN / ROGUELITE",Vector2(116,64),10,MINT)
	pixel("BUILD 02",Vector2(1100,64),9,CREAM)
	panel(Rect2(96,145,227,31),Color("17323a"),Color("577b70"))
	text("横版肉鸽 · 今天也在救项目",Vector2(109,167),15,MINT)
	text("毅川",Vector2(90,264),84,CREAM,game.display_font)
	text("救我",Vector2(90,354),84,MINT,game.display_font)
	panel(Rect2(294,217,34,78),Color("a85f53"),Color("dd9b77"))
	text("除",Vector2(301,245),20)
	text("错",Vector2(301,276),20)
	text("12 类故障。12 个 Boss。你的技能流派。",Vector2(96,397),18,Color("c3cfb8"))
	button(Rect2(96,426,320,52),"来了 · 剧情救场",true,game.selection == 0)
	button(Rect2(96,488,320,52),"无尽加班 · 无尽模式",false,game.selection == 1)
	button(Rect2(96,550,320,52),"工程生存手册",false,game.selection == 2)
	text("本局构筑 · 随机路线 · 关底三选一",Vector2(97,630),14,MUTED)
	draw_line(Vector2(96,648),Vector2(1184,648),Color(0.64,0.75,0.65,0.25),1)
	pixel("STORY / 12 STAGES     ENDLESS / NO LIMIT",Vector2(96,679),8)
	text("无尽纪录 %d 关  ·  最高分 %d" % [game.best_floor,game.best_score],Vector2(872,679),16,CREAM)

func game_hud() -> void:
	panel(Rect2(24,22,365,112),Color(0.04,0.1,0.14,0.95),Color("416158"))
	panel(Rect2(34,32,72,88),Color("203e41"),Color("7b9c81"))
	game.actions_atlas.draw(self,0,Vector2(70,115),78)
	text("毅川",Vector2(120,51),22)
	pixel("ENGINE RONIN",Vector2(186,48),8)
	text("生命 %d / %d" % [game.player.health,game.max_health()],Vector2(121,78),16,CREAM)
	text("守护 %d" % game.ward,Vector2(300,78),13,MUTED)
	draw_rect(Rect2(121,87,239,7),Color("30434a"))
	draw_rect(Rect2(121,87,239.0 * game.player.health / game.max_health(),7),CORAL)
	draw_rect(Rect2(121,108,198,6),Color("30434a"))
	draw_rect(Rect2(121,108,198 * game.player.energy / 100.0,6),MINT)
	text("能量",Vector2(330,115),12,MUTED)
	text("无尽加班" if game.mode == "endless" else game.Data.CHAPTERS[game.stage],Vector2(435,42),18,MINT)
	pixel("STAGE %02d%s" % [game.room_index + 1," / 12" if game.mode == "story" else " / INF"],Vector2(436,67),9,CREAM)
	text("工单 %d   击杀 %d" % [game.coins,game.total_kills],Vector2(436,94),16,MUTED)
	pixel(game.time_label(game.run_time),Vector2(436,120),10,MINT)
	text("Tab 查看技能",Vector2(563,120),13,MUTED)
	panel(Rect2(760,22,406,113),Color(0.04,0.1,0.14,0.95),Color("416158"))
	draw_rect(Rect2(760,22,4,113),game.event.color)
	text(game.event.tool + " · " + game.event.title,Vector2(780,51),22,CREAM)
	var objective: String = "前进进入战区 · E 与路上的 NPC 交谈"
	match game.room_phase:
		"combat": objective = "清理第 %d 波 · 剩余 %d 个故障" % [game.room_wave + 1,game.enemies.size()]
		"relay": objective = "跳到节点 %d（地图菱形），按 E 修复" % (game.relay_count + 1)
		"boss": objective = "关底 Boss · " + game.event.boss
		"reward": objective = "故障已解决 · 选择技能进入下一关"
	text(objective,Vector2(781,79),16,MINT)
	text(game.room_data.name + (" · 精英路线" if game.route == "elite" else " · 分层探索"),Vector2(781,111),14,MUTED)
	panel(Rect2(1180,23,64,46),Color("142d37"),Color("416158"))
	draw_rect(Rect2(1200,37,5,17),CREAM)
	draw_rect(Rect2(1212,37,5,17),CREAM)
	text("F1 手册",Vector2(1181,96),13,MUTED)
	# Room map gives the vertical objectives a clear destination.
	draw_line(Vector2(780,151),Vector2(1147,151),Color("45685f"),2)
	for i in range(2):
		var relay: Dictionary = game.room_data.relays[i]
		var x: float = 780 + relay.p.x / game.world_length * 367
		draw_circle(Vector2(x,151),4,MINT if relay.done else game.event.color)
	draw_circle(Vector2(780 + game.player.position.x / game.world_length * 367,151),3,CREAM)
	draw_rect(Rect2(0,627,1280,93),Color(0.035,0.09,0.13,0.98))
	draw_line(Vector2(0,627),Vector2(1280,627),Color("3a5653"),1)
	pixel("OUTPUT LOG",Vector2(27,648),8,MUTED)
	for i in range(game.logs.size()):
		var entry: Dictionary = game.logs[i]
		text(entry.text.substr(0,56),Vector2(27,669 + i * 18),12,entry.color)
	var controls: Array = [["J","断点斩",0.0,true],["K","断点领域",game.player.skill_cooldown,true],
		["U","飞剑",game.player.swords_cooldown,game.rank("swords") > 0],["I","回滚盾",game.player.shield_cooldown,game.rank("rollback") > 0],
		["L / SHIFT","热重载",game.player.dash_cooldown,true],["E","交互",0.0,true]]
	for i in range(controls.size()):
		var x: float = 650 + i * 100
		var item: Array = controls[i]
		panel(Rect2(x,641,91,60),Color("142d36"),Color("3b5852"))
		pixel(item[0],Vector2(x + 10,660),6 if i == 4 else 9,MINT if item[3] else MUTED)
		text("%.1fs" % item[2] if item[2] > 0 else (item[1] if item[3] else "未解锁"),Vector2(x + 10,688),14,CREAM if item[3] else MUTED)
	if game.speech_time > 0:
		dialogue()
	if game.feedback_time > 0 and game.state == "playing" and game.chapter_time <= 0 and game.room_phase != "boss":
		var width: float = game.font.get_string_size(game.feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x + 34
		panel(Rect2(640 - width * 0.5,172,width,34),Color("153038"),Color("708369"))
		center(game.feedback,Vector2(640,195),16,CREAM)
	if game.chapter_time > 0 and game.state == "playing":
		panel(Rect2(430,185,420,90),Color(0.05,0.13,0.17,0.95),game.event.color)
		center("子关卡 %02d · %s" % [game.room_index + 1,game.event.title],Vector2(640,223),25)
		center("双节点 → 关底 Boss → 技能三选一",Vector2(640,255),16,game.event.color)
	if is_instance_valid(game.boss_ref) and not game.boss_ref.dead:
		panel(Rect2(390,172,500,42),Color("142530"),Color("805b5d"))
		draw_rect(Rect2(395,200,490.0 * maxf(0,game.boss_ref.hp) / game.boss_ref.max_hp,8),game.event.color)
		center(game.event.boss,Vector2(640,193),16)
	if game.damage_flash > 0:
		draw_rect(Rect2(0,0,1280,720),Color(0.8,0.22,0.2,game.damage_flash * 0.4))

func dialogue() -> void:
	var width: float = clampf(game.speech_font.get_string_size(game.speech,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x + 28,76,360)
	var anchor: Vector2 = game.player.position if game.speech_anchor == Vector2.INF else game.speech_anchor
	var p := Vector2(clampf(anchor.x - game.camera_x - width * 0.5,28,1250 - width),maxf(280,anchor.y - 157))
	draw_style_box(speech_style,Rect2(p,Vector2(width,42)))
	text(game.speech,p + Vector2(14,29),21,INK,game.speech_font)
	draw_colored_polygon(PackedVector2Array([p + Vector2(width * 0.5 - 6,41),p + Vector2(width * 0.5 + 6,41),p + Vector2(width * 0.5,49)]),speech_style.bg_color)
	text(game.speaker,p + Vector2(0,-8),11,CREAM)

func upgrades() -> void:
	scrim()
	pixel("BOSS CLEARED / NEW BUILD",Vector2(160,105),10,MINT)
	text("故障已排除。选一个新技能。",Vector2(158,162),36,CREAM,game.display_font)
	text("本局持续生效，重复选择可以升级。同一轮只有一次选择。",Vector2(160,197),17,MUTED)
	for i in range(game.upgrade_choices.size()):
		var skill: Dictionary = game.upgrade_choices[i]
		var rect := Rect2(160 + i * 328,220,304,328)
		var selected: bool = game.card_selection == i or rect.has_point(get_global_mouse_position())
		panel(rect,Color("1b373f") if selected else Color("142c36"),MINT if selected else Color("486357"))
		draw_rect(Rect2(rect.position,Vector2(304,4)),MINT if selected else game.event.color)
		icon(skill.icon,rect.position + Vector2(63,66),77)
		pixel("0%d" % (i + 1),rect.position + Vector2(243,42),12,MINT)
		text(skill.tag,rect.position + Vector2(118,73),16,game.event.color)
		text(skill.name,rect.position + Vector2(24,139),26,CREAM,game.display_font)
		text("Lv.%d → Lv.%d" % [game.rank(skill.id),game.rank(skill.id) + 1],rect.position + Vector2(24,172),16,MINT)
		paragraph(skill.desc,rect.position + Vector2(24,211),254,18,MUTED,4)
		text("选择技能  →",rect.position + Vector2(24,302),18,CREAM)
	center("按 1 / 2 / 3 或点击卡片选择 · 方向键 + Enter 也可操作",Vector2(640,600),17,MUTED)
	center("已解决 %d 个关底 Boss · 本局工单 %d" % [game.cleared_rooms,game.coins],Vector2(640,643),16,MINT)

func routes() -> void:
	scrim()
	center("下一张工单，怎么接？",Vector2(640,150),37)
	center("技能会保留。下一关会重新生成布局、怪物与机关。",Vector2(640,190),18,MUTED)
	for i in range(2):
		var rect := Rect2(285 + i * 370,250,340,280)
		panel(rect,Color("1a363e") if game.card_selection == i else Color("142c36"),MINT if game.card_selection == i else Color("496356"))
		icon(7 if i == 0 else 8,rect.position + Vector2(60,63),70)
		text("稳定分支" if i == 0 else "精英分支",rect.position + Vector2(110,70),27)
		paragraph("进入下一关，恢复 2 点生命。适合继续探索和积累技能。" if i == 0 else "敌人数量增加、生命 +30%；工单掉落 +50%，多一处机关。",rect.position + Vector2(28,135),284,20,MUTED,4)
		text("1 · 继续救场" if i == 0 else "2 · 接受挑战",rect.position + Vector2(28,247),19,MINT if i == 0 else CORAL)

func npc_panel() -> void:
	scrim()
	var npc: Dictionary = game.npcs[game.npc_selected]
	var spec: Dictionary = game.Data.NPCS[npc.id]
	panel(Rect2(280,125,720,490),Color("112b34"),spec.color)
	pixel("CAMP / DEVELOPER ENCOUNTER",Vector2(315,168),9,spec.color)
	if game.npc_atlas:
		game.npc_atlas.draw(self,npc.id + 4,Vector2(383,399),190)
	text(spec.name,Vector2(495,222),34,CREAM,game.display_font)
	text(spec.role,Vector2(495,254),16,MUTED)
	text("「" + spec.quote + "」",Vector2(492,306),24,spec.color,game.speech_font)
	paragraph("这次已经帮过你了。继续前进，关底还有活。" if npc.used else spec.offer,Vector2(495,352),450,18,MUTED,3)
	if game.feedback_time > 0:
		text(game.feedback,Vector2(445,425),14,CORAL)
	button(Rect2(445,440,390,58),"继续救场" if npc.used else spec.button,true)
	button(Rect2(445,515,390,46),"先不麻烦你了 · Esc",false)

func guide() -> void:
	scrim()
	panel(Rect2(80,43,1120,636),Color("102831"),Color("54766a"))
	pixel("FIELD MANUAL / ROGUELITE",Vector2(112,87),9,MINT)
	text("工程生存手册",Vector2(111,137),37,CREAM,game.display_font)
	button(Rect2(1000,65,150,44),"返回",false)
	text("每个子关卡：两波故障 → 两个分层节点 → 独立 Boss → 技能三选一",Vector2(112,180),21,MINT)
	for i in range(4):
		var x: float = 112 + i * 267
		panel(Rect2(x,214,253,172),Color("17313a"),Color("446053"))
		pixel("0%d" % (i + 1),Vector2(x + 17,244),10,game.Data.EVENTS[i * 3].color)
		text(game.Data.CHAPTERS[i],Vector2(x + 17,278),24)
		for j in range(3):
			text(game.Data.EVENTS[i * 3 + j].tool + " · " + game.Data.EVENTS[i * 3 + j].title,Vector2(x + 17,312 + j * 24),14,MUTED)
	text("A / D 移动 · 空格二段跳 · J 连斩（可长按）· K 断点领域 · L / Shift 无敌冲刺",Vector2(112,430),18,MINT)
	text("U 飞剑 / I 回滚盾需要技能解锁 · E 交互 · Tab 技能列表 · Esc 暂停 · M 静音 · F11 全屏",Vector2(112,466),17,MUTED)
	paragraph("剧情共 12 个子关卡；无尽模式不会在第 12 关结束，敌人和 Boss 持续成长。倒下会结束本局，重新开局时技能与工单重置；最高分和无尽纪录保留。",Vector2(112,510),1028,18,MUTED,3)
	draw_line(Vector2(112,590),Vector2(1168,590),Color("3a5750"),1)
	text("旅途中会遇到：若宇、罗德、海德骑士、只狼。每人提供不同帮助，每关只能领取一次。",Vector2(112,624),17,CREAM)
	text("宝箱可选，精英路线有额外收益。地面亮起预警时离开危险区域。",Vector2(112,654),16,MUTED)

func build_panel() -> void:
	scrim()
	panel(Rect2(80,43,1120,636),Color("102831"),Color("54766a"))
	pixel("CURRENT BUILD",Vector2(112,87),9,MINT)
	text("本局技能构筑",Vector2(112,139),36,CREAM,game.display_font)
	button(Rect2(1000,65,150,44),"返回",false)
	text("近战伤害 %d · 生命上限 %d · 主动冷却倍率 %.2f" % [game.melee_damage(),game.max_health(),game.cooldown_scale()],Vector2(112,179),18,MINT)
	var learned: Array = []
	for id in game.skill_ranks:
		learned.append(game.Data.skill(id))
	if learned.is_empty():
		center("击败第一个关底 Boss，就能选择新技能。",Vector2(640,350),25,MUTED)
	for i in range(mini(18,learned.size())):
		var x: float = 112 + (i % 3) * 354
		var y: float = 215 + (i / 3) * 65
		var skill: Dictionary = learned[i]
		panel(Rect2(x,y,336,55),Color("17323b"),Color("3f5d51"))
		icon(skill.icon,Vector2(x + 27,y + 28),38)
		text(skill.name,Vector2(x + 57,y + 25),18)
		text(skill.tag,Vector2(x + 57,y + 45),12,MUTED)
		text("Lv.%d" % game.rank(skill.id),Vector2(x + 272,y + 34),17,MINT)
	text("本局技能不会带到下一次开局。只狼训练的额外刀术伤害：+%d" % game.bonus_damage,Vector2(112,650),16,MUTED)

func overlay() -> void:
	scrim()
	panel(Rect2(365,132,550,476),Color("102831"),Color("618471"))
	var won: bool = game.state == "won"
	var dead: bool = game.state == "dead"
	pixel("RUN COMPLETE" if won else ("RUN ENDED" if dead else "BREAKPOINT HIT"),Vector2(412,178),10,MINT if won else CORAL)
	game.actions_atlas.draw(self,7 if won else (6 if dead else 0),Vector2(640,286),95)
	center("终于，下班了。" if won else ("哦豁，完蛋" if dead else "断点休息一下"),Vector2(640,339),37)
	center("%d 个 Boss · %d 击杀 · %d 分" % [game.cleared_rooms,game.total_kills,game.score],Vector2(640,378),19,MINT)
	center("倒下结束本局，再来一次换个流派。" if dead else ("12 个开发故障全部解决。" if won else "按 Tab 可以查看本局技能。"),Vector2(640,414),17,MUTED)
	button(Rect2(470,440,340,60),"新的一局 · R" if dead or won else "继续救场 · Enter",true)
	button(Rect2(470,518,340,48),"返回标题",false)
