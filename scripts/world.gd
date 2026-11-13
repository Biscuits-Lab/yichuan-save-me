extends Node2D
var game: Node
const PAPER := Color("e9debd")

func _draw() -> void:
	var cam: float = game.camera_x
	var time: float = game.room_clock
	var tint: Color = game.environment.accent
	draw_rect(Rect2(cam - 30,-30,1340,800),game.environment.sky)
	if game.background_art:
		var shift: float = fmod(cam * 0.12,1280)
		draw_texture_rect(game.background_art,Rect2(cam - shift,-130,1280,853),false,Color("aebbc1"))
		draw_set_transform(Vector2(cam - shift + 2560,0),0,Vector2(-1,1))
		draw_texture_rect(game.background_art,Rect2(0,-130,1280,853),false,Color("aebbc1"))
		draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(cam,0,1280,627),Color(tint,0.035))
	for i in range(15):
		draw_rect(Rect2(cam,445 + i * 12,1280,12),Color(0.02,0.09,0.13,i / 42.0))
	for gap in game.room_data.gaps:
		draw_rect(gap,Color("102331"))
		for i in range(5):
			draw_rect(Rect2(gap.position + Vector2(12 + i * 29,fmod(time * 25 + i * 19,110)),Vector2(12,2)),Color("a26372"))
		draw_string(game.pixel_font,gap.position + Vector2(20,40),"NULL",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ae7384"))
	for rect in game.platforms:
		if rect.end.x > cam - 30 and rect.position.x < cam + 1310:
			platform(rect,cam,tint)
	for i in range(int(game.world_length / 440) + 1):
		var x: float = 205 + i * 440
		if x > cam - 200 and x < cam + 1400:
			environment_prop(Vector2(x,600),game.environment)
	if cam < 800:
		draw_rect(Rect2(495,245,260,83),Color("18343f"))
		draw_rect(Rect2(495,245,4,83),tint)
		draw_string(game.font,Vector2(515,278),game.event.tool,HORIZONTAL_ALIGNMENT_LEFT,-1,22,tint)
		draw_string(game.font,Vector2(515,308),game.environment.name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,PAPER)
	for i in range(game.gates.size()):
		gate(game.gates[i],i)
	# The end of the room remains a visible destination even while the boss lives.
	var exit_p := Vector2(game.world_length - 125,600)
	draw_rect(Rect2(exit_p + Vector2(-39,-175),Vector2(78,175)),Color("1d3d45"))
	draw_rect(Rect2(exit_p + Vector2(-32,-168),Vector2(64,162)),Color("0c2534"))
	draw_rect(Rect2(exit_p + Vector2(-40,-180),Vector2(80,7)),tint)
	draw_string(game.font,exit_p + Vector2(-48,-199),"关底 · 出口",HORIZONTAL_ALIGNMENT_LEFT,-1,20,PAPER)
	draw_string(game.font,exit_p + Vector2(-67,-105),"击败 Boss 后解锁",HORIZONTAL_ALIGNMENT_LEFT,-1,15,tint)
	for hazard in game.hazards:
		var color: Color = Color("f1b786") if hazard.delay > 0 else Color("ed8a79")
		draw_rect(hazard.rect,Color(color,0.16 if hazard.delay > 0 else 0.55))
		draw_rect(hazard.rect,color,false,2)
	for i in range(game.room_data.relays.size()):
		terminal(game.room_data.relays[i],i)
	for npc in game.npcs:
		var spec: Dictionary = game.Data.NPCS[npc.id]
		if game.npc_atlas:
			game.npc_atlas.draw(self,npc.id + (4 if int(game.clock * 0.6) % 2 else 0),npc.p,105)
		else:
			draw_rect(Rect2(npc.p + Vector2(-15,-80),Vector2(30,80)),spec.color)
		draw_string(game.font,npc.p + Vector2(-31,-118),spec.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,spec.color)
		if game.player.position.distance_to(npc.p) < 150:
			draw_rect(Rect2(npc.p + Vector2(-40,-153),Vector2(100,25)),Color("142e37"))
			draw_string(game.font,npc.p + Vector2(-31,-134),"E  交谈" if not npc.used else "E  再聊聊",HORIZONTAL_ALIGNMENT_LEFT,-1,14,PAPER)
	var chest: Vector2 = game.room_data.chest
	draw_rect(Rect2(chest + Vector2(-25,-36),Vector2(50,36)),Color("916742"))
	draw_rect(Rect2(chest + Vector2(-28,-40),Vector2(56,12)),Color("c19c64"))
	draw_rect(Rect2(chest + Vector2(-5,-28),Vector2(10,12)),Color("bbdbb0") if not game.chest_open else Color("4d615b"))
	if not game.chest_open:
		draw_string(game.font,chest + Vector2(-42,-59),"E 缓存宝箱",HORIZONTAL_ALIGNMENT_LEFT,-1,15,PAPER)
	for cup in game.coffee:
		if not cup.taken:
			var p: Vector2 = cup.p + Vector2(0,sin(time * 3) * 3)
			draw_rect(Rect2(p + Vector2(-9,-14),Vector2(18,24)),Color("edcf9d"))
			draw_rect(Rect2(p + Vector2(-11,-16),Vector2(22,4)),Color("9d704f"))
			draw_rect(Rect2(p + Vector2(8,-8),Vector2(7,12)),Color("edcf9d"))
	for item in game.trails:
		draw_rect(Rect2(item.p + Vector2(-20,-90),Vector2(40,85)),Color(0.6,0.95,0.8,item.life * 0.6))
	for orb in game.projectiles:
		if orb.friendly:
			draw_line(orb.p - orb.v.normalized() * 10,orb.p + orb.v.normalized() * 10,orb.color,4)
		else:
			draw_circle(orb.p,10 if orb.delay > 0 else 8,Color(orb.color,0.18))
			draw_rect(Rect2(orb.p - Vector2(5,5),Vector2(10,10)),Color(orb.color,0.45 if orb.delay > 0 else 1))
			draw_rect(Rect2(orb.p - Vector2(2,2),Vector2(4,4)),Color("ffeac7"))
	if game.effects_atlas:
		for effect in game.effects:
			var phase: float = 1 - effect.life / effect.duration
			game.effects_atlas.draw(self,effect.index,effect.p,effect.size * (0.65 + phase * 0.6),effect.facing,Color(1,1,1,minf(1,effect.life * 7)),true)
	for item in game.particles:
		draw_rect(Rect2(item.p,Vector2.ONE * item.size),Color(item.color,minf(1,item.life * 3)))
	for item in game.floating_text:
		var width: float = game.font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		draw_string(game.font,item.p - Vector2(width * 0.5,0),item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(item.color,minf(1,item.life * 2)))
	weather(cam,game.environment)

func platform(rect: Rect2, cam: float, accent: Color) -> void:
	var material: Dictionary = game.environment
	draw_rect(rect,material.stone)
	platform_detail(Rect2(rect.position + Vector2(0,5),Vector2(rect.size.x,7)),rect,material.stone.lightened(0.16))
	platform_detail(Rect2(rect.position,Vector2(rect.size.x,4)),rect,material.trim)
	platform_detail(Rect2(rect.position + Vector2(0,1),Vector2(rect.size.x,1)),rect,material.trim.lightened(0.25))
	var start: int = maxi(0,int((cam - rect.position.x - 60) / 48))
	var end: int = mini(int(rect.size.x / 48) + 1,int((cam + 1340 - rect.position.x) / 48))
	for col in range(start,end):
		var x: float = rect.position.x + col * 48
		platform_detail(Rect2(x + 3,rect.position.y + 7,38,4),rect,material.trim.darkened(0.35))
		if rect.size.y > 50:
			for row in range(3):
				var y: float = rect.position.y + 22 + row * 39
				platform_detail(Rect2(x + 4,y,40,30),rect,material.stone.lightened(0.05 if (col + row) % 3 else 0.1))
			if col % 5 == 0:
				platform_detail(Rect2(x + 19,rect.position.y + 22,2,66),rect,material.trim.darkened(0.3))
				platform_detail(Rect2(x + 20,rect.position.y + 85,24,2),rect,Color(accent,0.45))

func platform_detail(detail: Rect2, bounds: Rect2, color: Color) -> void:
	var clipped: Rect2 = detail.intersection(bounds)
	if clipped.has_area():
		draw_rect(clipped,color)

func lantern(p: Vector2) -> void:
	draw_line(p - Vector2(0,14),p,Color("9a9678"),2)
	draw_circle(p + Vector2(0,13),23,Color(0.95,0.6,0.3,0.06))
	draw_rect(Rect2(p + Vector2(-9,0),Vector2(18,25)),Color("c88c59"))
	draw_rect(Rect2(p + Vector2(-6,2),Vector2(12,21)),Color("edc383"))
	draw_rect(Rect2(p + Vector2(-10,-2),Vector2(20,3)),Color("34383b"))
	draw_rect(Rect2(p + Vector2(-10,24),Vector2(20,3)),Color("34383b"))

func terminal(relay: Dictionary, index: int) -> void:
	var p: Vector2 = relay.p
	var ready: bool = game.relay_count == index and game.room_phase in ["combat","reinforce"]
	var tint: Color = Color("afe6b7") if relay.done else (game.event.color if ready else Color("627d82"))
	draw_rect(Rect2(p + Vector2(-7,-43),Vector2(14,43)),Color("49656a"))
	draw_rect(Rect2(p + Vector2(-29,-83),Vector2(58,43)),Color("607c76"))
	draw_rect(Rect2(p + Vector2(-25,-79),Vector2(50,34)),Color("17323c"))
	draw_string(game.pixel_font,p + Vector2(-18,-57),"OK" if relay.done else str(index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,tint)
	if ready:
		draw_circle(p + Vector2(0,-63),41,Color(tint,0.07 + sin(game.clock * 3) * 0.02))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-10,-116),p + Vector2(10,-116),p + Vector2(0,-104)]),tint)
		draw_string(game.font,p + Vector2(-93,-139),"区域 %d · 清空后自动恢复" % (index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,tint)


func gate(data: Dictionary, index: int) -> void:
	var x: float = data.rect.position.x
	if x < game.camera_x - 200 or x > game.camera_x + 1450:
		return
	var color: Color = Color("acdcb9") if data.open else Color("e5b37a")
	draw_rect(Rect2(x - 11,-20,8,620),Color("4b696c"))
	draw_rect(Rect2(x + 27,-20,8,620),Color("4b696c"))
	if data.open:
		draw_string(game.font,Vector2(x - 37,195),"通路已恢复",HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
		return
	draw_rect(Rect2(x - 2,-20,28,620),Color(color,0.12))
	for j in range(30):
		var y: float = -15 + fmod(j * 21.0 + game.clock * 28,606)
		draw_rect(Rect2(x,y,24,9),Color(color,0.6))
	draw_rect(Rect2(x - 152,268,328,69),Color("112b35"))
	draw_rect(Rect2(x - 152,268,328,69),Color("805f4d"),false,1)
	draw_string(game.font,Vector2(x - 138,294),"战区 %d · 清空敌人自动解锁" % (index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	draw_string(game.font,Vector2(x - 130,322),game.gate_hint(index),HORIZONTAL_ALIGNMENT_LEFT,-1,16,PAPER)

func environment_prop(p: Vector2, theme: Dictionary) -> void:
	var dark: Color = theme.stone.darkened(0.25)
	var light: Color = Color(theme.accent,0.65)
	match String(theme.motif):
		"rail":
			draw_rect(Rect2(p + Vector2(0,-200),Vector2(12,200)),dark)
			draw_rect(Rect2(p + Vector2(150,-200),Vector2(12,200)),dark)
			draw_rect(Rect2(p + Vector2(-14,-207),Vector2(190,13)),theme.trim.darkened(0.45))
			for i in range(5):
				draw_rect(Rect2(p + Vector2(i * 30,-196),Vector2(15,3)),light)
		"archive":
			draw_rect(Rect2(p + Vector2(0,-150),Vector2(120,150)),dark)
			for row in range(5):
				for col in range(3):
					draw_rect(Rect2(p + Vector2(5 + col * 38,-145 + row * 28),Vector2(33,23)),theme.stone)
					draw_rect(Rect2(p + Vector2(15 + col * 38,-135 + row * 28),Vector2(12,3)),light)
		"crystal":
			for i in range(3):
				var q: Vector2 = p + Vector2(i * 37,-10)
				var height: float = 100 + i % 2 * 65
				draw_colored_polygon(PackedVector2Array([q,q + Vector2(-20,-height + 24),q + Vector2(2,-height),q + Vector2(28,-35)]),Color(theme.accent,0.4))
				draw_line(q,q + Vector2(2,-height),light,2)
		"scroll":
			draw_rect(Rect2(p + Vector2(40,-225),Vector2(6,225)),dark)
			draw_rect(Rect2(p + Vector2(20,-205),Vector2(75,110)),Color(theme.trim,0.42))
			draw_rect(Rect2(p + Vector2(15,-211),Vector2(85,6)),theme.trim)
			for i in range(5):
				draw_rect(Rect2(p + Vector2(33,-185 + i * 16),Vector2(42 - i % 3 * 9,3)),light)
		"forge":
			draw_rect(Rect2(p + Vector2(0,-195),Vector2(45,195)),dark)
			draw_rect(Rect2(p + Vector2(-10,-202),Vector2(66,12)),theme.trim.darkened(0.35))
			draw_rect(Rect2(p + Vector2(10,-105),Vector2(25,49)),Color(theme.accent,0.5))
			draw_line(p + Vector2(45,-160),p + Vector2(140,-160),theme.trim.darkened(0.4),5)
		"tree":
			draw_rect(Rect2(p + Vector2(45,-205),Vector2(25,205)),dark)
			for i in range(4):
				draw_rect(Rect2(p + Vector2(5 + i % 2 * 35,-245 + i * 30),Vector2(105 - i * 8,49)),Color(theme.trim,0.22 + i * 0.05))
			draw_line(p + Vector2(55,-55),p + Vector2(5,-8),theme.stone,10)
		"chain":
			draw_rect(Rect2(p + Vector2(0,-225),Vector2(22,225)),dark)
			for i in range(8):
				draw_rect(Rect2(p + Vector2(70,-215 + i * 23),Vector2(15,29)),theme.trim.darkened(0.35),false,3)
		"pipe":
			draw_rect(Rect2(p + Vector2(20,-155),Vector2(24,155)),dark)
			draw_rect(Rect2(p + Vector2(20,-163),Vector2(114,20)),theme.stone)
			for i in range(3):
				draw_rect(Rect2(p + Vector2(45 + i * 34,-168),Vector2(5,30)),theme.trim.darkened(0.4))
		"antenna":
			draw_line(p + Vector2(60,0),p + Vector2(60,-250),theme.trim.darkened(0.45),5)
			draw_line(p + Vector2(10,-180),p + Vector2(110,-180),light,3)
			draw_line(p + Vector2(25,-210),p + Vector2(95,-210),light,3)
			draw_rect(Rect2(p + Vector2(54,-259),Vector2(13,9)),light)
		"cube":
			for i in range(3):
				var q: Vector2 = p + Vector2(i * 43,-95 - i * 26 + sin(game.clock + i) * 6)
				draw_rect(Rect2(q,Vector2(37,37)),dark)
				draw_rect(Rect2(q,Vector2(37,37)),light,false,2)
		"mirror":
			draw_rect(Rect2(p + Vector2(10,-185),Vector2(92,185)),theme.trim.darkened(0.5))
			draw_rect(Rect2(p + Vector2(17,-178),Vector2(78,173)),Color(theme.accent,0.2))
			draw_line(p + Vector2(25,-35),p + Vector2(85,-165),light,3)
		"citadel":
			draw_rect(Rect2(p + Vector2(8,-210),Vector2(14,210)),dark)
			draw_rect(Rect2(p + Vector2(145,-210),Vector2(14,210)),dark)
			draw_rect(Rect2(p + Vector2(-15,-216),Vector2(196,10)),theme.trim.darkened(0.3))
			draw_rect(Rect2(p + Vector2(-26,-228),Vector2(218,9)),dark)
			lantern(p + Vector2(83,-204))

func weather(cam: float, theme: Dictionary) -> void:
	for i in range(22):
		var rain: bool = theme.weather == "rain"
		var falling: bool = rain or theme.weather == "snow"
		var speed: float = 285 if rain else (27 if falling else -16)
		var p := Vector2(cam + fposmod(i * 113.0 - game.clock * (75 if rain else 15) - cam * 0.3,1360) - 40,fposmod(i * 61.0 + game.clock * speed,590))
		var color: Color = Color(theme.accent,0.35)
		if rain:
			draw_line(p,p + Vector2(-5,13),color,1)
		elif theme.weather == "rune":
			draw_rect(Rect2(p,Vector2(6,8)),color,false,1)
		elif theme.weather == "shard":
			draw_colored_polygon(PackedVector2Array([p,p + Vector2(5,8),p + Vector2(-4,7)]),color)
		else:
			draw_rect(Rect2(p,Vector2(3,3) if falling else Vector2(4,2)),color)
