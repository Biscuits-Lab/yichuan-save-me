extends Node2D

var game: Node
var speech_style: StyleBoxFlat
const CREAM := Color("f2e6cb")
const MINT := Color("b0e3bf")
const MUTED := Color("8ca89f")
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
	if game.state == "guide":
		guide()
	elif game.state in ["paused", "dead", "won"]:
		overlay()
	# Thin grain-like scanlines maintain a restrained pixel-display character.
	for y in range(0, 720, 4):
		draw_rect(Rect2(0, y, 1280, 1), Color(0, 0, 0, 0.045))

func text(value: String, point: Vector2, size: int = 20, color: Color = CREAM, font: Font = null) -> void:
	draw_string(game.font if font == null else font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func pixel(value: String, point: Vector2, size: int = 10, color: Color = MUTED) -> void:
	text(value, point, size, color, game.pixel_font)

func center(value: String, point: Vector2, size: int, color: Color = CREAM) -> void:
	var width: float = game.font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(value, point - Vector2(width * 0.5, 0), size, color)

func panel(rect: Rect2, fill: Color = INK, border: Color = Color("36534e")) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 1)
	draw_rect(Rect2(rect.position + Vector2(-1, -1), Vector2(4, 4)), border)
	draw_rect(Rect2(rect.end - Vector2(3, 3), Vector2(4, 4)), border)

func button(rect: Rect2, label: String, primary: bool, selected: bool = false) -> void:
	var hover: bool = rect.has_point(get_global_mouse_position()) or selected
	var fill: Color = MINT if primary else Color(0.06, 0.13, 0.17, 0.83)
	if hover:
		fill = Color("d2efcd") if primary else Color("1e3b40")
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.3))
	panel(rect, fill, Color("d0ecc7") if primary else Color("54776d"))
	text(label, rect.position + Vector2(25, rect.size.y * 0.5 + 8), 22, INK if primary else CREAM)
	text("→" if primary else "+", Vector2(rect.end.x - 39, rect.position.y + rect.size.y * 0.5 + 8), 24, INK if primary else MINT)

func title_screen() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("0c1426"))
	if game.key_art:
		var breathing: float = sin(game.clock * 0.24) * 3
		draw_texture_rect(game.key_art, Rect2(-12, -70 + breathing, 1304, 870), false)
	# Fade into the illustration instead of covering it with a hard panel.
	for i in range(70):
		var alpha: float = clampf(0.91 - i / 72.0, 0, 0.9)
		draw_rect(Rect2(i * 14, 0, 14, 720), Color(0.025, 0.06, 0.105, alpha))
	draw_rect(Rect2(0, 0, 1280, 104), Color(0.03, 0.06, 0.10, 0.25))
	draw_rect(Rect2(94, 54, 8, 8), MINT)
	pixel("YICHUAN / AFTER HOURS", Vector2(116, 64), 10, MINT)
	pixel("A GODOT PIXEL ADVENTURE", Vector2(962, 64), 8, Color("b4c8b7"))
	panel(Rect2(96, 149, 188, 30), Color(0.11, 0.2, 0.23, 0.7), Color("577b70"))
	text("虚幻开发师的奇妙加班", Vector2(108, 170), 15, MINT)
	text("毅川", Vector2(90, 267), 84, CREAM, game.display_font)
	text("救我", Vector2(90, 357), 84, MINT, game.display_font)
	# A small seal-like accent beside the title.
	panel(Rect2(294, 219, 34, 78), Color("a85f53"), Color("dd9b77"))
	text("除", Vector2(301, 247), 20, CREAM)
	text("错", Vector2(301, 278), 20, CREAM)
	pixel("ONE SHIBA. ZERO FATAL ERRORS.", Vector2(98, 384), 8, Color("bcbfa6"))
	text("一把断点刀，救回整个项目组。", Vector2(96, 417), 20, Color("c3cfb8"))
	button(Rect2(96, 438, 310, 64), "来了 · 开始救场", true, game.selection == 0)
	button(Rect2(96, 516, 310, 54), "工程生存手册", false, game.selection == 1)
	text("横版动作  /  双段跳跃  /  开发者的浪漫", Vector2(97, 607), 14, Color("829d92"))
	draw_line(Vector2(96, 645), Vector2(1184, 645), Color(0.64, 0.75, 0.65, 0.2), 1)
	pixel("UGS  /  ANGELSCRIPT  /  P4  /  BUILD", Vector2(96, 676), 8, Color("91a99c"))
	text("「来了」", Vector2(1083, 624), 23, Color("f0dfba"))
	text("毅川 · 虚幻引擎开发师", Vector2(1020, 676), 14, Color("bbccb5"))
	if game.best_time > 0:
		text("最快下班  " + game.time_label(game.best_time), Vector2(96, 632), 14, MINT)

func game_hud() -> void:
	var player: CharacterBody2D = game.player
	var data: Dictionary = game.STAGES[game.stage]
	panel(Rect2(24, 22, 365, 103), Color(0.04, 0.1, 0.14, 0.93), Color("416158"))
	panel(Rect2(34, 32, 72, 82), Color("203e41"), Color("7b9c81"))
	if game.actions_atlas:
		game.actions_atlas.draw(self, 0, Vector2(70, 110), 75)
	else:
		draw_set_transform(Vector2(70, 105), 0, Vector2(1.65, 1.65))
		Samurai.draw_dog(self, game.clock, 0, false, true)
		draw_set_transform(Vector2.ZERO)
	text("毅川", Vector2(120, 51), 21, CREAM)
	pixel("ENGINE RONIN", Vector2(186, 48), 8, MUTED)
	for i in range(6):
		heart(Vector2(122 + i * 31, 66), i < player.health)
	draw_rect(Rect2(121, 101, 198, 6), Color("263e45"))
	draw_rect(Rect2(121, 101, 198 * player.energy / 100.0, 6), MINT)
	text("断点", Vector2(331, 107), 12, MUTED)
	# A quiet progress indicator sits between portrait and objective.
	for i in range(4):
		var complete: bool = game.stage > i or game.state == "won"
		var current: bool = game.stage == i
		var x: float = 439 + i * 91
		draw_rect(Rect2(x, 37, 70, 4), MINT if complete else (data.color if current else Color("29434a")))
		text(["同步", "脚本", "提交", "打包"][i], Vector2(x + 14, 64), 15, CREAM if current or complete else Color("667f7c"))
	pixel(game.time_label(game.run_time), Vector2(559, 95), 12, Color("a8bdaa"))
	panel(Rect2(842, 22, 324, 114), Color(0.04, 0.1, 0.14, 0.93), Color("416158"))
	draw_rect(Rect2(842, 22, 4, 114), data.color)
	pixel("MISSION %02d / 04" % (game.stage + 1), Vector2(861, 45), 8, data.color)
	text(data.tool + " · " + data.title, Vector2(861, 75), 22, CREAM)
	if game.stage < 3:
		var count: int = game.kills[data.kind]
		text("问题修复  %d / 3" % count, Vector2(862, 103), 17, MUTED)
		text("找到终端 E" if count >= 3 else ("K 断点破锁" if game.stage == 2 else "前进，清理故障"), Vector2(1011, 103), 15, MINT)
	else:
		text("击败打包失败，今天准时下班。", Vector2(862, 104), 16, MUTED)
	panel(Rect2(1180, 23, 64, 46), Color(0.04, 0.1, 0.14, 0.9), Color("416158"))
	draw_rect(Rect2(1200, 37, 5, 17), CREAM)
	draw_rect(Rect2(1212, 37, 5, 17), CREAM)
	text("F1 手册", Vector2(1183, 96), 13, MUTED)
	# Developer console and action bar occupy the floor below the play space.
	draw_rect(Rect2(0, 627, 1280, 93), Color(0.035, 0.09, 0.13, 0.97))
	draw_line(Vector2(0, 627), Vector2(1280, 627), Color("3a5653"), 1)
	pixel("OUTPUT LOG", Vector2(27, 649), 8, Color("91ac9b"))
	for i in range(game.logs.size()):
		var entry: Dictionary = game.logs[i]
		var value: String = entry.text
		if value.length() > 70:
			value = value.substr(0, 68) + "…"
		text(value, Vector2(27, 669 + i * 18), 12, entry.color)
	var controls: Array = [["A D", "移动"], ["SPACE", "二段跳"], ["J", "断点斩"], ["K", "断点领域"], ["L / SHIFT", "热重载"], ["E", "修复"]]
	for i in range(controls.size()):
		var x: float = 681 + i * 96
		panel(Rect2(x, 644, 87, 54), Color("132c35"), Color("35534e"))
		var k: Array = controls[i]
		pixel(k[0], Vector2(x + 9, 663), 6 if i in [1, 4] else 8, MINT)
		text(k[1], Vector2(x + 9, 686), 13, CREAM)
	if game.speech_time > 0:
		dialogue()
	if game.feedback_time > 0:
		var width: float = game.font.get_string_size(game.feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		panel(Rect2(640 - width * 0.5 - 20, 565, width + 40, 40), Color("152f37"), Color("a18c66"))
		center(game.feedback, Vector2(640, 592), 17, CREAM)
	if game.chapter_time > 0:
		var alpha: float = minf(1, game.chapter_time)
		panel(Rect2(435, 161, 410, 84), Color(0.05, 0.13, 0.17, 0.9 * alpha), Color(data.color, alpha * 0.6))
		center("第 %s 幕  ·  %s" % [["一", "二", "三", "四"][game.stage], data.title], Vector2(640, 198), 27, Color(CREAM, alpha))
		center(["有人吗？我的工程又同步挂了。", "热重载之后，全是红的。", "这个文件……到底谁锁的？", "再试最后一次。真的最后一次。 "][game.stage], Vector2(640, 228), 16, Color(data.color, alpha))
	if game.stage == 3:
		for enemy in game.enemies:
			if is_instance_valid(enemy) and enemy.kind == "boss" and enemy.boss_activated:
				panel(Rect2(397, 136, 486, 32), Color("14232f"), Color("805b5d"))
				draw_rect(Rect2(402, 141, 476.0 * maxf(0, enemy.hp) / enemy.max_hp, 22), CORAL)
				center("打包失败  /  EXIT CODE 1", Vector2(640, 158), 14, INK)
	if game.damage_flash > 0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.22, 0.2, game.damage_flash * 0.5))

func heart(p: Vector2, full: bool) -> void:
	var c: Color = CORAL if full else Color("36504e")
	draw_rect(Rect2(p + Vector2(3, 0), Vector2(6, 3)), c)
	draw_rect(Rect2(p + Vector2(12, 0), Vector2(6, 3)), c)
	draw_rect(Rect2(p + Vector2(0, 3), Vector2(21, 6)), c)
	draw_rect(Rect2(p + Vector2(3, 9), Vector2(15, 3)), c)
	draw_rect(Rect2(p + Vector2(6, 12), Vector2(9, 3)), c)
	draw_rect(Rect2(p + Vector2(9, 15), Vector2(3, 3)), c)
	if full:
		draw_rect(Rect2(p + Vector2(3, 3), Vector2(3, 3)), Color("f7c7a3"))

func dialogue() -> void:
	var width: float = clampf(game.speech_font.get_string_size(game.speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 28, 76, 360)
	var p := Vector2(clampf(game.player.position.x - game.camera_x - width * 0.5, 28, 1250 - width), maxf(265, game.player.position.y - 159))
	draw_style_box(speech_style, Rect2(p, Vector2(width, 42)))
	text(game.speech, p + Vector2(14, 29), 21, INK, game.speech_font)
	var tail_x: float = width * 0.5
	draw_colored_polygon(PackedVector2Array([p + Vector2(tail_x - 6, 41), p + Vector2(tail_x + 6, 41), p + Vector2(tail_x, 49)]), speech_style.bg_color)
	text(game.speaker, p + Vector2(0, -8), 11, Color("c7d9b8"))

func guide() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.07, 0.10, 0.94))
	panel(Rect2(80, 43, 1120, 636), Color("102831"), Color("54766a"))
	pixel("FIELD MANUAL / BUILD 01", Vector2(112, 86), 9, MINT)
	text("工程生存手册", Vector2(111, 137), 37, CREAM)
	text("把同事的「毅川救我」，变成今晚的「终于下班」。", Vector2(112, 172), 18, MUTED)
	button(Rect2(1000, 65, 150, 44), "返回", false)
	var cards: Array = [
		["01", "UGS", "同步风暴", "同步冲突化成巡逻虫。", "避开同步包，J 连斩清场。", "清理 3 只 → E 重新同步", "e6ad74"],
		["02", "AngelScript", "脚本迷城", "编译错误变成悬浮幽灵。", "二段跳接近，K 定住它们。", "清理 3 只 → E 热重载", "bcaae3"],
		["03", "P4", "独占检出", "只读文件披上了锁甲。", "等护盾消失，或 K 直接破锁。", "解除 3 锁 → E 提交工程", "81c9d6"],
		["04", "BUILD", "最后一次打包", "打包失败盘踞在流水线尽头。", "L 穿过弹幕，抓住空隙输出。", "击败首领 → 成功下班", "ed8d82"]
	]
	for i in range(cards.size()):
		var card: Array = cards[i]
		var x: float = 112 + i * 267
		var tint := Color(card[6])
		panel(Rect2(x, 202, 253, 223), Color("16313a"), Color("38564f"))
		draw_rect(Rect2(x, 202, 253, 3), tint)
		pixel(card[0], Vector2(x + 18, 231), 10, tint)
		text(card[1], Vector2(x + 18, 269), 25, CREAM)
		text(card[2], Vector2(x + 18, 300), 19, tint)
		text(card[3], Vector2(x + 18, 339), 14, MUTED)
		text(card[4], Vector2(x + 18, 365), 13, MUTED)
		text(card[5], Vector2(x + 18, 403), 14, CREAM)
	text("操作", Vector2(112, 472), 22, CREAM)
	text("A / D 或方向键移动    空格二段跳    J 三连斩    K 断点领域（35 能量）", Vector2(112, 511), 19, MINT)
	text("L / Shift 无敌冲刺    E 工具交互    Esc 暂停    F1 / Tab 手册    M 静音    F11 全屏", Vector2(112, 547), 18, MUTED)
	text("咖啡恢复 2 格生命与能量。终端修复后自动保存检查点，并补满状态。", Vector2(112, 582), 17, MUTED)
	draw_line(Vector2(112, 604), Vector2(1168, 604), Color("36534e"), 1)
	text("毅川语录", Vector2(112, 643), 15, Color("dbad7d"))
	text("「来了」   「救命」   「哦豁，完蛋」   「坏啦」   「怀不上了」", Vector2(224, 644), 18, CREAM)

func overlay() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.06, 0.09, 0.81))
	panel(Rect2(365, 132, 550, 476), Color("102831"), Color("618471"))
	var won: bool = game.state == "won"
	var dead: bool = game.state == "dead"
	pixel("BUILD SUCCEEDED" if won else ("FATAL ERROR" if dead else "BREAKPOINT HIT"), Vector2(412, 178), 10, MINT if won else CORAL)
	if game.actions_atlas:
		game.actions_atlas.draw(self, 7 if won else (6 if dead else 0), Vector2(640, 294), 95)
	else:
		draw_set_transform(Vector2(640, 294), 0, Vector2(2, 2))
		Samurai.draw_dog(self, game.clock, 0, false, true)
		draw_set_transform(Vector2.ZERO)
	center("终于，下班了。" if won else ("哦豁，完蛋" if dead else "断点休息一下"), Vector2(640, 343), 39, CREAM)
	if won:
		center("UGS 已同步 · 脚本已编译 · P4 已提交 · 打包成功", Vector2(640, 380), 17, MINT)
		center("救场用时 %s    重试 %d 次" % [game.time_label(game.run_time), game.deaths], Vector2(640, 412), 19, MUTED)
	elif dead:
		center("别怕，最近一次成功构建还在。", Vector2(640, 387), 19, MUTED)
		center("已修复的工具和故障会保留。", Vector2(640, 415), 16, MUTED)
	else:
		center("工程先别动，我喝口咖啡。", Vector2(640, 389), 20, MUTED)
	button(Rect2(470, 440, 340, 60), "再救一次 · R" if won else ("来了 · 继续救场 R" if dead else "继续救场 · Enter"), true)
	button(Rect2(470, 518, 340, 48), "返回标题", false)
