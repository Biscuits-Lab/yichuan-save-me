class_name RogueData
extends RefCounted

const CHAPTERS: Array[String] = ["同步荒原", "脚本深井", "版本牢城", "渲染天守"]
const EVENTS: Array[Dictionary] = [
	{"tool":"UGS", "title":"同步死锁", "boss":"冲突监工", "kind":"ugs", "color":Color("e6ad74"), "rule":"同步包交叉火力；修复两处节点", "hazard":"pulse"},
	{"tool":"DDC", "title":"缓存迷宫", "boss":"缓存吞噬者", "kind":"ddc", "color":Color("d9b574"), "rule":"缓存宝箱含额外工单，也可能惊醒拟态怪", "hazard":"cache"},
	{"tool":"Shader", "title":"编译洪流", "boss":"万象编译师", "kind":"shader", "color":Color("b8a0e5"), "rule":"编译喷口周期点燃；先看地面预警", "hazard":"vent"},
	{"tool":"AngelScript", "title":"脚本深井", "boss":"空引用咒师", "kind":"script", "color":Color("b6a3e0"), "rule":"幽灵悬浮施法；上层节点需要二段跳", "hazard":"pulse"},
	{"tool":"Live Coding", "title":"热重载熔炉", "boss":"模块熔铸龙", "kind":"live", "color":Color("f39c75"), "rule":"机械龙蓄力突进；用冲刺穿过火线", "hazard":"vent"},
	{"tool":"GC", "title":"回收风暴", "boss":"对象收割者", "kind":"gc", "color":Color("c0c5a5"), "rule":"自然能量恢复减慢，击杀返还能量增加", "hazard":"vacuum"},
	{"tool":"P4", "title":"独占检出", "boss":"只读典狱长", "kind":"p4", "color":Color("81c9d6"), "rule":"锁甲正面减伤；K 断点领域可以破锁", "hazard":"pulse"},
	{"tool":"Memory", "title":"泄漏沼泽", "boss":"无限增长之物", "kind":"leak", "color":Color("8bce9c"), "rule":"泄漏软泥死亡后分裂；先清小怪", "hazard":"poison"},
	{"tool":"Network", "title":"高延迟边境", "boss":"超时信使", "kind":"net", "color":Color("8bc7ed"), "rule":"延迟弹先悬停再发射；操作响应保持正常", "hazard":"delayed"},
	{"tool":"Nanite", "title":"装配碎境", "boss":"三角破坏神", "kind":"nanite", "color":Color("8ed2c9"), "rule":"碎片区域有坍塌预警，保持移动", "hazard":"collapse"},
	{"tool":"Lumen", "title":"反射幻城", "boss":"流明灯蛾王", "kind":"lumen", "color":Color("f0d08a"), "rule":"灯蛾释放环形光弹；利用上下层躲避", "hazard":"light"},
	{"tool":"BUILD", "title":"最后一次打包", "boss":"打包失败·百次重试", "kind":"boss", "color":Color("ed8d82"), "rule":"服务器鬼武者：扇形弹幕、冲击波与近战", "hazard":"vent"}
]
const NPCS: Array[Dictionary] = [
	{"name":"若宇", "quote":"我这显示是对的", "role":"显示正常的技术美术", "offer":"先喝咖啡：免费恢复 2 点生命和 30 能量。", "button":"检查显示并补给", "color":Color("9fdbc1")},
	{"name":"罗德", "quote":"给毅川派活", "role":"永远有新需求的制作人", "offer":"接一张加急工单：本关多一组敌人，击败 Boss 额外获得 25 工单。", "button":"接下加急工单", "color":Color("e6b07f")},
	{"name":"海德骑士", "quote":"毅川救我", "role":"被只读诅咒困住的骑士", "offer":"缔结守护誓约：免费抵挡下一次伤害。", "button":"接受守护誓约", "color":Color("d2dcc9")},
	{"name":"只狼", "quote":"好他妈卡我草了", "role":"正在等待着色器编译的忍者", "offer":"花费 12 工单学习识破：本局近战伤害 +1。", "button":"训练识破 · 12 工单", "color":Color("e9a184")}
]
const SKILLS: Array[Dictionary] = [
	{"id":"blade", "name":"断点刀法", "desc":"近战每刀伤害 +1。第三刀仍有连段加成。", "tag":"近战", "icon":0, "max":5},
	{"id":"haste", "name":"增量编译", "desc":"挥刀速度提高 10%，连招可提前输入。", "tag":"连段", "icon":0, "max":3},
	{"id":"breakpoint", "name":"断点扩散", "desc":"K 伤害 +2、半径 +24，仍可破除文件锁。", "tag":"K 主动", "icon":1, "max":4},
	{"id":"swords", "name":"自动化飞剑", "desc":"解锁 U：发射 3 把追踪飞剑；升级增加数量与伤害。", "tag":"U 主动", "icon":2, "max":3},
	{"id":"rollback", "name":"版本回滚", "desc":"解锁 I：获得 2 秒护盾；升级缩短冷却并恢复生命。", "tag":"I 主动", "icon":3, "max":3},
	{"id":"chain", "name":"异常传播", "desc":"近战命中会连锁攻击附近另一个目标，伤害随等级提高。", "tag":"连锁", "icon":5, "max":3},
	{"id":"burn", "name":"高温补丁", "desc":"近战附加 3 秒灼烧，每秒造成技能等级点伤害。", "tag":"灼烧", "icon":6, "max":3},
	{"id":"dash", "name":"热重载优化", "desc":"冲刺冷却降低 18%，速度与无敌时间提高。", "tag":"机动", "icon":4, "max":3},
	{"id":"dash_cut", "name":"瞬身提交", "desc":"冲刺穿过敌人造成 2 点伤害，每级增加伤害。", "tag":"冲刺流", "icon":4, "max":3},
	{"id":"health", "name":"稳定性预算", "desc":"生命上限 +2，立即恢复 2 点生命。", "tag":"生存", "icon":8, "max":4},
	{"id":"energy", "name":"缓存预热", "desc":"自然能量恢复 +3/秒；每次击杀额外恢复 4 能量。", "tag":"能量", "icon":7, "max":3},
	{"id":"cooldown", "name":"并行构建", "desc":"K / U / I 技能冷却缩短 12%。", "tag":"主动流", "icon":9, "max":3},
	{"id":"crit", "name":"精准断言", "desc":"近战增加 10% 暴击率，暴击伤害翻倍。", "tag":"暴击", "icon":0, "max":4},
	{"id":"leech", "name":"回收补给", "desc":"每击败 8 个敌人恢复 1 点生命，升级降低所需数量。", "tag":"续航", "icon":7, "max":3},
	{"id":"jump", "name":"空中热修复", "desc":"空中跳跃高度提高，落地恢复少量能量。", "tag":"探索", "icon":10, "max":3},
	{"id":"thorns", "name":"反向调试", "desc":"受到伤害时向周围反击，造成 2 点范围伤害/级。", "tag":"反击", "icon":3, "max":3},
	{"id":"loot", "name":"工单翻倍", "desc":"敌人掉落和 Boss 工单收益提高 25%。", "tag":"经济", "icon":11, "max":3},
	{"id":"reach", "name":"长刀重构", "desc":"近战攻击距离 +18；刀光范围随之扩大。", "tag":"刀术", "icon":0, "max":3}
]
const BOONS: Array[Dictionary] = [
	{"id":"overclock", "name":"极限超频", "desc":"近战和断点伤害永久 +1，本局可反复选择。", "tag":"无尽强化", "icon":0, "max":999999},
	{"id":"rest", "name":"咖啡时间", "desc":"立即恢复全部生命与能量。", "tag":"补给", "icon":7, "max":999999},
	{"id":"funds", "name":"加班补贴", "desc":"获得 40 工单，并恢复 2 点生命。", "tag":"经济", "icon":11, "max":999999}
]

static func skill(id: String) -> Dictionary:
	for item in SKILLS + BOONS:
		if item.id == id:
			return item
	return {}
