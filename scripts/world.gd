extends Node2D
var game: Node
const PAPER := Color("e9debd")

func _draw() -> void:
	var cam: float = game.camera_x
	var time: float = game.room_clock
	var tint: Color = game.event.color
	draw_rect(Rect2(cam - 30,-30,1340,800),Color("0b1a2b"))
	if game.background_art:
		var shift: float = fmod(cam * 0.12,1280)
		draw_texture_rect(game.background_art,Rect2(cam - shift,-130,1280,853),false,Color("b7c5cb"))
		draw_set_transform(Vector2(cam - shift + 2560,0),0,Vector2(-1,1))
		draw_texture_rect(game.background_art,Rect2(0,-130,1280,853),false,Color("b7c5cb"))
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
	# The hub and upper route are physical destinations, not decorative menu NPCs.
	for x in [205.0,1830.0,3220.0]:
		draw_rect(Rect2(x,336,11,264),Color("80564b"))
		draw_rect(Rect2(x + 160,336,11,264),Color("80564b"))
		draw_rect(Rect2(x - 10,331,192,13),Color("a7785c"))
		draw_rect(Rect2(x - 20,323,210,8),Color("4c7272"))
		lantern(Vector2(x + 85,350))
	if cam < 800:
		draw_rect(Rect2(495,245,260,83),Color("18343f"))
		draw_rect(Rect2(495,245,4,83),tint)
		draw_string(game.font,Vector2(515,278),game.event.tool,HORIZONTAL_ALIGNMENT_LEFT,-1,22,tint)
		draw_string(game.font,Vector2(515,308),game.room_data.name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,PAPER)
	for i in range(game.room_data.traps.size()):
		trap(i)
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
	for i in range(14):
		var p := Vector2(cam + fposmod(i * 113.0 - game.clock * 15 - cam * 0.3,1360) - 40,fposmod(i * 61.0 + game.clock * 14,590))
		draw_rect(Rect2(p,Vector2(4,3)),Color(tint,0.4))

func platform(rect: Rect2, cam: float, accent: Color) -> void:
	draw_rect(rect,Color("182e38"))
	draw_rect(Rect2(rect.position + Vector2(0,5),Vector2(rect.size.x,7)),Color("384d4e"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x,4)),Color("8da797"))
	draw_rect(Rect2(rect.position + Vector2(0,1),Vector2(rect.size.x,1)),Color("bed3af"))
	var start: int = maxi(0,int((cam - rect.position.x - 60) / 48))
	var end: int = mini(int(rect.size.x / 48) + 1,int((cam + 1340 - rect.position.x) / 48))
	for col in range(start,end):
		var x: float = rect.position.x + col * 48
		draw_rect(Rect2(x + 3,rect.position.y + 7,38,4),Color("4a6060"))
		if rect.size.y > 50:
			for row in range(3):
				var y: float = rect.position.y + 22 + row * 39
				draw_rect(Rect2(x + 4,y,40,30),Color("203842") if (col + row) % 3 else Color("243e46"))
			if col % 5 == 0:
				draw_rect(Rect2(x + 19,rect.position.y + 22,2,66),Color("3f6665"))
				draw_rect(Rect2(x + 20,rect.position.y + 85,24,2),Color(accent,0.45))

func lantern(p: Vector2) -> void:
	draw_line(p - Vector2(0,14),p,Color("9a9678"),2)
	draw_circle(p + Vector2(0,13),23,Color(0.95,0.6,0.3,0.06))
	draw_rect(Rect2(p + Vector2(-9,0),Vector2(18,25)),Color("c88c59"))
	draw_rect(Rect2(p + Vector2(-6,2),Vector2(12,21)),Color("edc383"))
	draw_rect(Rect2(p + Vector2(-10,-2),Vector2(20,3)),Color("34383b"))
	draw_rect(Rect2(p + Vector2(-10,24),Vector2(20,3)),Color("34383b"))

func terminal(relay: Dictionary, index: int) -> void:
	var p: Vector2 = relay.p
	var ready: bool = game.room_phase == "relay" and game.relay_count == index
	var tint: Color = Color("afe6b7") if relay.done else (game.event.color if ready else Color("627d82"))
	draw_rect(Rect2(p + Vector2(-7,-43),Vector2(14,43)),Color("49656a"))
	draw_rect(Rect2(p + Vector2(-29,-83),Vector2(58,43)),Color("607c76"))
	draw_rect(Rect2(p + Vector2(-25,-79),Vector2(50,34)),Color("17323c"))
	draw_string(game.pixel_font,p + Vector2(-18,-57),"OK" if relay.done else str(index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,13,tint)
	if ready:
		draw_circle(p + Vector2(0,-63),41,Color(tint,0.07 + sin(game.clock * 3) * 0.02))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-10,-116),p + Vector2(10,-116),p + Vector2(0,-104)]),tint)
		draw_string(game.font,p + Vector2(-75,-139),"节点 %d · 按 E 重启" % (index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,tint)

func trap(index: int) -> void:
	var rect: Rect2 = game.room_data.traps[index]
	var state: String = game.trap_state(index)
	var safe: bool = state == "safe"
	var active: bool = state == "active"
	var warning: bool = state == "warning"
	var amber := Color("e9bf69")
	var color: Color = Color("9bd2bb") if safe else (Color("ee9276") if active else amber)
	var base := Rect2(rect.position.x,593,rect.size.x,7)
	draw_rect(base,Color("101e29"))
	draw_rect(base,color,false,1)
	# Flush-mounted, striped warning plate; no raised platform silhouette.
	for j in range(int(rect.size.x / 16)):
		var x: float = rect.position.x + j * 16
		draw_colored_polygon(PackedVector2Array([Vector2(x,593),Vector2(x + 7,593),Vector2(x + 13,600),Vector2(x + 6,600)]),color)
	for j in range(5):
		var p := Vector2(rect.position.x + 8 + j * 28,583)
		draw_rect(Rect2(p,Vector2(20,9)),Color("14232e"))
		draw_rect(Rect2(p + Vector2(3,2),Vector2(14,3)),color if warning or active else Color("9c704d"))
	var center := Vector2(rect.get_center().x,563)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-10,8),center + Vector2(0,-10),center + Vector2(10,8)]),color)
	draw_rect(Rect2(center + Vector2(-1,-4),Vector2(2,6)),Color("202936"))
	draw_rect(Rect2(center + Vector2(-1,4),Vector2(2,2)),Color("202936"))
	var label: String = "待机 · 周期喷口"
	if safe:
		label = "缓存监测 · 安全"
	elif warning:
		label = "预警 · 立即避开"
	elif active:
		label = "回收 · 消耗能量" if game.event.hazard == "vacuum" else "危险 · 正在喷发"
	if warning or active:
		var area: Rect2 = game.trap_area(index)
		draw_rect(area,Color(color,0.12 if warning else 0.28))
		draw_rect(area,color,false,2)
		if warning:
			for j in range(7):
				var x: float = rect.position.x + j * 23
				draw_line(Vector2(x,590),Vector2(x + 13,572),Color(color,0.75),2)
		else:
			for j in range(14):
				var x: float = rect.position.x + 5 + fmod(j * 31.0,rect.size.x - 10)
				var y: float = 588 - fmod(game.clock * 95 + j * 19,69)
				draw_rect(Rect2(x,y,4,7 + j % 3),color)
	draw_rect(Rect2(rect.position.x + 4,526,rect.size.x - 8,24),Color(0.035,0.10,0.14,0.9))
	draw_string(game.font,Vector2(rect.position.x + 9,544),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)

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
	draw_string(game.font,Vector2(x - 130,294),"战区封锁 · 节点 %d 未修复" % (index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,20,color)
	draw_string(game.font,Vector2(x - 130,322),game.gate_hint(index),HORIZONTAL_ALIGNMENT_LEFT,-1,16,PAPER)
