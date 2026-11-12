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
		var rect: Rect2 = game.room_data.traps[i]
		var phase: float = game.trap_phase(i)
		draw_rect(rect,Color("263e46"))
		for j in range(5):
			draw_rect(Rect2(rect.position + Vector2(j * 29 + 8,5),Vector2(13,3)),Color("71877b"))
		if phase > 2.9 and game.room_phase != "approach":
			var active: bool = phase >= 3.8 and phase < 4.6
			var warning: Color = Color("e8b883") if not active else tint
			draw_rect(Rect2(rect.position + Vector2(0,-65),Vector2(rect.size.x,65)),Color(warning,0.16 if not active else 0.4))
			for j in range(6):
				draw_line(rect.position + Vector2(j * 28,-4),rect.position + Vector2(j * 28 + 15,-25 if not active else -60),Color(warning,0.8),2)
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
		draw_string(game.font,p + Vector2(-56,-105),"E 重启节点 " + str(index + 1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,tint)
