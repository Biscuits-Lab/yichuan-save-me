extends RefCounted
## Data for the top-down rescue run. Tiers start at one; two equal items fuse.

const ARENA := Rect2(20, 44, 1240, 656)
const CENTER := Vector2(640, 372)
const CELL_SPACING := Vector2(1408, 1024)
const CORRIDOR_WIDTH: float = 176.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DOORS: Array[Vector2] = [Vector2(640, 44), Vector2(1260, 372), Vector2(640, 700), Vector2(20, 372)]
const TIER_NAMES: Array[String] = ["普通", "精良", "史诗", "传说"]
const TIER_COLORS: Array[Color] = [Color("a5b9c8"), Color("68dcb4"), Color("b69aff"), Color("ffc878")]
const MULTIPLIERS: Array[float] = [1.0, 1.65, 2.65, 4.1]
const EQUIPMENT_MULTIPLIERS: Array[float] = [0.25, 0.55, 1.0, 1.65]
const STAT_BASES := {"health":25.0, "armor":0.0, "move_speed":220.0, "damage":1.0, "attack_speed":1.0, "regen":0.0, "crit_chance":0.05, "crit_damage":1.5, "dodge":0.0, "lifesteal":0.0, "pickup_radius":140.0, "reach":1.0, "dash_recovery":1.0, "melee_damage":1.0, "ranged_damage":1.0, "magic_damage":1.0, "incoming_damage":1.0}
const STAT_CAPS := {"health":200.0, "armor":0.65, "move_speed":352.0, "damage":3.0, "attack_speed":2.5, "regen":3.0, "crit_chance":0.6, "crit_damage":3.0, "dodge":0.5, "lifesteal":0.15, "pickup_radius":280.0, "reach":1.5, "dash_recovery":2.0, "melee_damage":2.5, "ranged_damage":2.5, "magic_damage":2.5, "incoming_damage":2.0}
const STAT_NAMES := {"health":"生命上限", "armor":"减伤", "move_speed":"移速", "damage":"伤害加成", "attack_speed":"攻速加成", "regen":"每秒恢复", "crit_chance":"暴击率", "crit_damage":"暴击伤害", "dodge":"闪避率", "lifesteal":"生命偷取", "pickup_radius":"拾取范围", "reach":"攻击范围", "dash_recovery":"冲刺恢复", "melee_damage":"近战攻击", "ranged_damage":"远程攻击", "magic_damage":"魔法攻击", "incoming_damage":"受到伤害"}
const STAT_MINIMUMS := {"health":5.0, "move_speed":132.0, "damage":0.25, "attack_speed":0.35, "crit_damage":1.0, "reach":0.5, "dash_recovery":0.5, "melee_damage":0.25, "ranged_damage":0.25, "magic_damage":0.25, "incoming_damage":0.5, "armor":-0.5}
const ATTACK_NAMES := {"melee":"近战", "ranged":"远程", "magic":"魔法"}
const ITEM_ICONS: Array[String] = ["blade", "pistol", "wand", "spear", "shotgun", "orb", "vest", "boots", "chip", "scope", "coffee", "heart"]
const FLOOR_NAMES: Array[String] = ["张江高科", "需求办公室", "霓虹机房", "暗黑地牢", "牛来的森林与草地", "山田的相扑道场", "策划的空中城堡"]
const FLOOR_COUNT: int = 7
const FLOOR_ROOM_COUNTS: Array[int] = [9, 10, 11, 11, 11, 12, 12]
const FLOOR_COLORS: Array[Color] = [Color("e9bf81"), Color("77d9b4"), Color("63dfee"), Color("d39cae"), Color("a7d574"), Color("efbd76"), Color("ffb878")]
const FLOOR_STYLES: Array[String] = ["zhangjiang", "office", "server", "dark_home", "wilds", "sumo", "castle"]
const HOME_AREAS: Array[String] = ["网吧", "小区内部", "客厅", "卧室"]
const FLOOR_STORIES: Array[String] = [
	"穿过张江高科的园区街道，办公楼门口有保安大爷守着。",
	"进了需求办公室，小心守门人的工牌连射和举盾反击。",
	"信号穿过了霓虹机房！躲开核心的交错电流。",
	"前面是暗黑地牢。从网吧穿过小区和客厅，若宇在卧室等你。",
	"穿过森林和草地，牛来守着尽头！提防豹拉扑击、狼群和小绳头的毒液。",
	"山田挡在相扑道场！躲开冲锋和跺地，半血后要击败四个分身。",
	"终于到城堡了。杨梓亮就在深处，毅川，我等你！"
]
const ROOM_NAMES := {"start":"安全屋", "combat":"故障战区", "elite":"精英工单", "shop":"字节商店", "treasure":"装备宝库", "rest":"咖啡驿站", "boss":"首领房间", "npc":"同伴会客室"}
const DIFFICULTIES: Array[Dictionary] = [
	{"name":"休闲", "health":25, "enemy":0.75, "damage":0.75},
	{"name":"标准", "health":25, "enemy":1.0, "damage":1.0},
	{"name":"硬核", "health":25, "enemy":1.3, "damage":1.25}
]
const WEAPONS: Array[Dictionary] = [
	{"id":"blade", "attack_type":"melee", "name":"断点太刀", "kind":"weapon", "tag":"近战 · 扇形斩击", "desc":"自动斩向附近敌人，一刀可命中多个目标。", "price":18, "damage":17.0, "cooldown":0.72, "reach":112.0, "color":Color("74e4cb")},
	{"id":"pistol", "attack_type":"ranged", "name":"提交手枪", "kind":"weapon", "tag":"远程 · 快速点射", "desc":"自动瞄准；史诗以上的子弹可以穿透一个目标。", "price":18, "damage":10.0, "cooldown":0.48, "reach":490.0, "color":Color("ffd18c")},
	{"id":"wand", "attack_type":"magic", "name":"提示词法杖", "kind":"weapon", "tag":"远程 · 连锁电弧", "desc":"命中后跳向附近另一名敌人，升级增加连锁数。", "price":24, "damage":15.0, "cooldown":1.05, "reach":355.0, "color":Color("bd9eff")},
	{"id":"spear", "attack_type":"melee", "name":"热修复长枪", "kind":"weapon", "tag":"近战 · 直线贯穿", "desc":"长距离刺击，贯穿同一直线上的所有目标。", "price":22, "damage":22.0, "cooldown":0.94, "reach":180.0, "color":Color("8fcfff")},
	{"id":"shotgun", "attack_type":"ranged", "name":"需求霰弹枪", "kind":"weapon", "tag":"远程 · 扇形弹幕", "desc":"同时发射五枚弹丸，贴近目标时爆发更高。", "price":28, "damage":7.0, "cooldown":1.15, "reach":320.0, "color":Color("ffa58f")},
	{"id":"orb", "attack_type":"magic", "name":"回滚力场", "kind":"weapon", "tag":"范围 · 环形脉冲", "desc":"周期性震退并伤害身边所有敌人。", "price":26, "damage":13.0, "cooldown":1.42, "reach":136.0, "color":Color("9ce6ef")},
	{"id":"dagger", "attack_type":"melee", "name":"拆箱美工刀", "kind":"weapon", "attack":"blade", "arc":0.45, "stats":{"crit_chance":0.08}, "tag":"近战 · 高速暴击", "desc":"快速窄扇斩击，携带时提高暴击率。", "price":18, "damage":9.0, "cooldown":0.3, "reach":86.0, "color":Color("c8a3ff")},
	{"id":"axe", "attack_type":"melee", "name":"裁员巨斧", "kind":"weapon", "attack":"blade", "arc":-0.4, "knockback":25.0, "tag":"近战 · 宽幅重斩", "desc":"大扇形重击，推开成群敌人。", "price":26, "damage":32.0, "cooldown":1.3, "reach":132.0, "color":Color("ff916d")},
	{"id":"hammer", "attack_type":"melee", "name":"需求粉碎锤", "kind":"weapon", "attack":"orb", "knockback":38.0, "tag":"近战 · 震退重击", "desc":"缓慢砸击周围所有敌人，强力震退。", "price":30, "damage":40.0, "cooldown":1.7, "reach":118.0, "color":Color("ffd17d")},
	{"id":"rapier", "attack_type":"melee", "name":"签字钢笔", "kind":"weapon", "attack":"spear", "arc":0.96, "stats":{"dodge":0.04}, "tag":"近战 · 精准快刺", "desc":"快速直线刺击，携带时提高闪避率。", "price":24, "damage":15.0, "cooldown":0.48, "reach":190.0, "color":Color("9be6da")},
	{"id":"smg", "attack_type":"ranged", "name":"并发冲锋枪", "kind":"weapon", "attack":"projectile", "tag":"远程 · 高速连射", "desc":"单发伤害较低，以高射速持续压制。", "price":25, "damage":5.0, "cooldown":0.16, "reach":430.0, "color":Color("f5df9b")},
	{"id":"crossbow", "attack_type":"ranged", "name":"订书重弩", "kind":"weapon", "attack":"projectile", "pierce":2, "speed":560.0, "tag":"远程 · 贯穿弩箭", "desc":"重弩箭可连续穿过三个敌人。", "price":27, "damage":28.0, "cooldown":0.98, "reach":580.0, "color":Color("91d7af")},
	{"id":"sniper", "attack_type":"ranged", "name":"断言狙击枪", "kind":"weapon", "attack":"projectile", "pierce":3, "speed":1000.0, "stats":{"crit_chance":0.1, "crit_damage":0.25}, "tag":"远程 · 暴击狙杀", "desc":"超远距离贯穿射击，提高暴击率与暴击伤害。", "price":34, "damage":58.0, "cooldown":1.9, "reach":700.0, "color":Color("d5b5ff")},
	{"id":"twins", "attack_type":"ranged", "name":"摸鱼左轮", "kind":"weapon", "attack":"projectile", "tag":"远程 · 单发重击", "desc":"单把左轮，每次发射一枚高伤害弹丸。", "price":23, "damage":22.0, "cooldown":0.9, "reach":490.0, "color":Color("ffb0ca")},
	{"id":"shuriken", "attack_type":"ranged", "name":"飞旋工牌", "kind":"weapon", "attack":"projectile", "pellets":3, "spread":0.2, "pierce":1, "speed":480.0, "tag":"远程 · 三路穿透", "desc":"扇形掷出三枚穿透手里剑。", "price":26, "damage":10.0, "cooldown":0.78, "reach":400.0, "color":Color("9be2d5")},
	{"id":"firestaff", "attack_type":"magic", "name":"加班怒火杖", "kind":"weapon", "attack":"projectile", "splash":85.0, "speed":400.0, "tag":"法术 · 爆炸火球", "desc":"火球命中后爆炸，对附近敌人造成溅射伤害。", "price":30, "damage":20.0, "cooldown":1.2, "reach":460.0, "color":Color("ff9b68")},
	{"id":"frost", "attack_type":"magic", "name":"冷处理法杖", "kind":"weapon", "attack":"projectile", "slow":0.55, "speed":470.0, "tag":"法术 · 冰霜减速", "desc":"冰弹使目标移动速度降低 45%，持续 1.5 秒。", "price":27, "damage":11.0, "cooldown":0.85, "reach":460.0, "color":Color("8cdbff")},
	{"id":"railgun", "attack_type":"ranged", "name":"主干轨道炮", "kind":"weapon", "attack":"beam", "tag":"远程 · 直线光束", "desc":"瞬间命中射线上的所有敌人，受到掩体阻挡。", "price":35, "damage":42.0, "cooldown":1.65, "reach":620.0, "color":Color("dda4ff")},
	{"id":"staple_blaster", "attack_type":"ranged", "name":"电动订书枪", "kind":"weapon", "attack":"projectile", "tag":"远程 · 三路穿透", "desc":"连射三路订书钉，每路可穿过一个额外目标。", "price":25, "damage":9, "cooldown":0.56, "reach":407, "pellets":3, "spread":0.12, "pierce":1, "speed":570, "art_frame":0, "color":Color("f5856f")},
	{"id":"keyboard_mace", "attack_type":"melee", "name":"机械键盘锤", "kind":"weapon", "attack":"orb", "tag":"近战 · 重击击退", "desc":"用整块机械键盘砸开周围怪物，击退较强。", "price":29, "damage":36, "cooldown":1.45, "reach":128, "knockback":33, "art_frame":1, "color":Color("bdafed")},
	{"id":"cable_whip", "attack_type":"melee", "name":"网线鞭", "kind":"weapon", "attack":"blade", "tag":"近战 · 远距扫击", "desc":"甩开加长网线扫过前方，攻击范围大于常规近战。", "price":22, "damage":13, "cooldown":0.57, "reach":182, "arc":0.38, "art_frame":2, "color":Color("80b2f4")},
	{"id":"meeting_pointer", "attack_type":"ranged", "name":"激光翻页笔", "kind":"weapon", "attack":"beam", "tag":"远程 · 快速光束", "desc":"快速扫出一束贯穿光线，掩体可以截断光束。", "price":25, "damage":15, "cooldown":0.39, "reach":590, "art_frame":3, "color":Color("9de4a2")},
	{"id":"printer_cannon", "attack_type":"ranged", "name":"缺纸打印炮", "kind":"weapon", "attack":"projectile", "tag":"远程 · 纸团爆炸", "desc":"发射压实纸团，命中后伤及附近目标。", "price":30, "damage":28, "cooldown":1.46, "reach":455, "splash":72, "speed":395, "art_frame":4, "color":Color("f4c591")},
	{"id":"scanner_lamp", "attack_type":"magic", "name":"扫描仪法灯", "kind":"weapon", "attack":"wand", "tag":"法术 · 扫描连锁", "desc":"扫描光沿相邻敌人跳转，升级会扫描更多目标。", "price":28, "damage":18, "cooldown":0.89, "reach":302, "art_frame":5, "color":Color("cba6f5")},
	{"id":"cold_ac", "attack_type":"magic", "name":"中央空调", "kind":"weapon", "attack":"projectile", "tag":"法术 · 冷风减速", "desc":"吹出两股冷风，命中的敌人短时间减速。", "price":29, "damage":12, "cooldown":0.92, "reach":410, "pellets":2, "spread":0.18, "slow":0.65, "speed":415, "art_frame":6, "color":Color("9de4fb")},
	{"id":"fire_drill", "attack_type":"ranged", "name":"消防演练喷筒", "kind":"weapon", "attack":"projectile", "tag":"远程 · 近距离扇射", "desc":"近距离喷出七枚散射弹，适合清理围上来的怪物。", "price":24, "damage":5, "cooldown":0.76, "reach":265, "pellets":7, "spread":0.15, "speed":465, "art_frame":7, "color":Color("fdb77e")},
	{"id":"swivel_chair", "attack_type":"melee", "name":"转椅旋风", "kind":"weapon", "attack":"orb", "tag":"近战 · 快速环扫", "desc":"原地旋转转椅，连续推开身边目标。", "price":24, "damage":11, "cooldown":0.43, "reach":108, "knockback":21, "art_frame":8, "color":Color("a8b9e3")},
	{"id":"timecard_blade", "attack_type":"melee", "name":"门禁闸刀", "kind":"weapon", "attack":"spear", "tag":"近战 · 窄线贯穿", "desc":"横伸门禁闸刀，命中线上的多个敌人。", "price":25, "damage":25, "cooldown":0.91, "reach":205, "arc":0.94, "art_frame":9, "color":Color("aee4ce")},
	{"id":"elevator_button", "attack_type":"magic", "name":"电梯权限魔盒", "kind":"weapon", "attack":"orb", "tag":"法术 · 大范围震荡", "desc":"权限验证失败时释放大范围震荡，冷却较长。", "price":31, "damage":29, "cooldown":1.55, "reach":186, "knockback":28, "art_frame":10, "color":Color("f9d995")},
	{"id":"whiteboard_eraser", "attack_type":"magic", "name":"白板擦爆弹", "kind":"weapon", "attack":"projectile", "tag":"法术 · 粉尘爆炸", "desc":"发射白板擦，命中时炸开粉尘并波及邻近目标。", "price":27, "damage":22, "cooldown":1.13, "reach":374, "splash":94, "speed":385, "art_frame":11, "color":Color("d1a0f7")},
]
const EQUIPMENT: Array[Dictionary] = [
	{"id":"vest", "name":"防猝死马甲", "kind":"equipment", "stats":{"armor":0.12}, "tag":"护甲", "desc":"提升减伤，适合近身作战。", "price":20, "color":Color("8fcfff")},
	{"id":"boots", "name":"通勤跑鞋", "kind":"equipment", "stats":{"move_speed":22.0}, "tag":"移动速度", "desc":"提高移动速度，方便拉开距离。", "price":16, "color":Color("ffd18c")},
	{"id":"chip", "name":"双倍浓缩", "kind":"equipment", "stats":{"attack_speed":0.12}, "tag":"攻击速度", "desc":"加快所有武器的攻击频率。", "price":22, "color":Color("bd9eff")},
	{"id":"scope", "name":"绩效目标", "kind":"equipment", "stats":{"damage":0.15}, "tag":"伤害", "desc":"提高所有武器伤害。", "price":22, "color":Color("ffa58f")},
	{"id":"coffee", "name":"蜜雪冰城", "kind":"equipment", "stats":{"regen":0.5}, "tag":"生命恢复", "desc":"持续恢复生命，受伤后也生效。", "price":24, "color":Color("77d9b4")},
	{"id":"heart", "name":"健康餐", "kind":"equipment", "stats":{"health":20.0}, "tag":"生命上限", "desc":"增加生命上限，获得时恢复增加的生命。", "price":20, "color":Color("ff96a1")},
	{"id":"crit_lens", "name":"周报放大镜", "kind":"equipment", "stats":{"crit_chance":0.08}, "tag":"暴击率", "desc":"更容易打出暴击。", "price":23, "color":Color("ffd17d")},
	{"id":"prism", "name":"年终奖预期", "kind":"equipment", "stats":{"crit_damage":0.3}, "tag":"暴击伤害", "desc":"提高暴击命中的伤害倍率。", "price":24, "color":Color("efb0ff")},
	{"id":"feather", "name":"摸鱼工牌", "kind":"equipment", "stats":{"dodge":0.08}, "tag":"闪避", "desc":"有概率完全避开一次伤害。", "price":23, "color":Color("a9e9f0")},
	{"id":"fang", "name":"带薪回血", "kind":"equipment", "stats":{"lifesteal":0.03}, "tag":"生命偷取", "desc":"按对敌人造成的实际伤害恢复生命。", "price":27, "color":Color("ff93b0")},
	{"id":"magnet", "name":"报销夹", "kind":"equipment", "stats":{"pickup_radius":50.0}, "tag":"拾取范围", "desc":"从更远处吸引战斗掉落的字节。", "price":16, "color":Color("99cfff")},
	{"id":"focus", "name":"外接显示器", "kind":"equipment", "stats":{"reach":0.12}, "tag":"攻击范围", "desc":"扩大近战范围与远程索敌射程。", "price":22, "color":Color("a9d1ff")},
	{"id":"spring", "name":"弹性打卡", "kind":"equipment", "stats":{"dash_recovery":0.2}, "tag":"冲刺恢复", "desc":"缩短冲刺的恢复时间。", "price":19, "color":Color("f4dc9a")},
	{"id":"bruiser", "name":"健身年卡", "kind":"equipment", "stats":{"health":10.0, "damage":0.06}, "tag":"生命 / 伤害", "desc":"兼顾生存与火力。", "price":25, "color":Color("f1ab8f")},
	{"id":"reactor", "name":"双屏工位", "kind":"equipment", "stats":{"attack_speed":0.08, "damage":0.05}, "tag":"攻速 / 伤害", "desc":"同时提升攻击频率与威力。", "price":26, "color":Color("d3adff")},
	{"id":"cloak", "name":"带薪病假", "kind":"equipment", "stats":{"armor":0.06, "dodge":0.04}, "tag":"护甲 / 闪避", "desc":"减轻伤害，并有机会完全避开攻击。", "price":26, "color":Color("a4c7ed")},
	{"id":"sprinter", "name":"下班闹钟", "kind":"equipment", "stats":{"move_speed":22.0, "dodge":0.03}, "tag":"移速 / 闪避", "desc":"灵活走位，提升容错。", "price":24, "color":Color("9ce9be")},
	{"id":"medkit", "name":"护肝片", "kind":"equipment", "stats":{"regen":0.3, "health":8.0}, "tag":"恢复 / 生命", "desc":"持续恢复并增加生命储备。", "price":25, "color":Color("9be4c2")},
	{"id":"hunter", "name":"绩效红榜", "kind":"equipment", "stats":{"crit_chance":0.04, "damage":0.07}, "tag":"暴击 / 伤害", "desc":"提高弱点命中率与基础火力。", "price":25, "color":Color("f3c593")},
	{"id":"duelist", "name":"升职通知", "kind":"equipment", "stats":{"crit_damage":0.2, "attack_speed":0.06}, "tag":"暴伤 / 攻速", "desc":"更快攻击，暴击更有力。", "price":26, "color":Color("e1b0e9")},
	{"id":"fortress", "name":"人体工学椅", "kind":"equipment", "stats":{"armor":0.08, "health":8.0}, "tag":"护甲 / 生命", "desc":"稳定承受伤害，增加生命上限。", "price":25, "color":Color("9fbce9")},
	{"id":"charm", "name":"锦鲤桌宠", "kind":"equipment", "stats":{"dodge":0.04, "crit_chance":0.04}, "tag":"闪避 / 暴击", "desc":"同时增加闪避与暴击机会。", "price":27, "color":Color("f0b2dc")},
	{"id":"conduit", "name":"充电宝", "kind":"equipment", "stats":{"attack_speed":0.06, "pickup_radius":35.0}, "tag":"攻速 / 拾取", "desc":"战斗与收集两不误。", "price":20, "color":Color("94d8df")},
	{"id":"tracker", "name":"班车月卡", "kind":"equipment", "stats":{"reach":0.08, "move_speed":11.0}, "tag":"范围 / 移速", "desc":"扩大攻击范围并提升移动速度。", "price":22, "color":Color("d7dfa0")},

	{"id":"wrist_rest", "name":"键盘手托", "kind":"equipment", "stats":{"melee_damage":0.15}, "tag":"近战攻击", "desc":"手腕稳了，近战武器更有力。", "price":19, "color":Color("f0bc94")},
	{"id":"mouse", "name":"人体工学鼠标", "kind":"equipment", "stats":{"ranged_damage":0.15}, "tag":"远程攻击", "desc":"只提高远程武器伤害。", "price":19, "color":Color("a7cfff")},
	{"id":"sticky", "name":"灵感便签", "kind":"equipment", "stats":{"magic_damage":0.15}, "tag":"魔法攻击", "desc":"灵感爆发，只提高魔法武器伤害。", "price":19, "color":Color("d3b0ff")},
	{"id":"night_run", "name":"夜跑手环", "kind":"equipment", "stats":{"melee_damage":0.1, "crit_damage":0.15}, "tag":"近战 / 暴伤", "desc":"近战攻击更强，暴击更有力。", "price":25, "color":Color("f2c194")},
	{"id":"headphones", "name":"降噪耳机", "kind":"equipment", "stats":{"ranged_damage":0.1, "crit_chance":0.03}, "tag":"远程 / 暴击", "desc":"专注目标，提高远程攻击与暴击率。", "price":25, "color":Color("b5ccff")},
	{"id":"mint", "name":"提神薄荷", "kind":"equipment", "stats":{"magic_damage":0.1, "attack_speed":0.05}, "tag":"魔法 / 攻速", "desc":"头脑清醒，法术更强，攻击更快。", "price":25, "color":Color("a5e9ca")},
	{"id":"breakfast", "name":"蛋白早餐", "kind":"equipment", "stats":{"melee_damage":0.1, "health":8.0}, "tag":"近战 / 生命", "desc":"吃饱再开工，近战与生命同时提升。", "price":24, "color":Color("ffbf99")},
	{"id":"glasses", "name":"防蓝光眼镜", "kind":"equipment", "stats":{"ranged_damage":0.1, "reach":0.06}, "tag":"远程 / 范围", "desc":"远程攻击更强，所有武器索敌更远。", "price":24, "color":Color("a6d5e8")},
	{"id":"thermos", "name":"枸杞保温杯", "kind":"equipment", "stats":{"magic_damage":0.1, "regen":0.2}, "tag":"魔法 / 恢复", "desc":"保温杯里泡枸杞，边回生命边放法术。", "price":25, "color":Color("d8b7e8")},
	{"id":"glass_trophy", "name":"玻璃心奖杯", "kind":"equipment", "stats":{"damage":0.3, "incoming_damage":0.25}, "tag":"高伤害 / 易伤", "desc":"所有武器伤害提高，但自己受到的伤害也放大。", "price":22, "color":Color("ffb0c0")},
	{"id":"overtime", "name":"996 合同", "kind":"equipment", "stats":{"melee_damage":0.45, "armor":-0.08}, "tag":"高近战 / 减伤降低", "desc":"近战大幅增强，减伤降低；负减伤会放大受伤。", "price":22, "color":Color("ffab87")},
	{"id":"all_nighter", "name":"通宵方案", "kind":"equipment", "stats":{"magic_damage":0.45, "health":-12.0}, "tag":"高魔法 / 生命降低", "desc":"魔法攻击大幅增强，生命上限降低。", "price":22, "color":Color("d5a0f2")},
	{"id":"briefcase", "name":"超载公文包", "kind":"equipment", "stats":{"ranged_damage":0.4, "attack_speed":-0.1}, "tag":"高远程 / 攻速降低", "desc":"远程单发更痛，所有武器攻击变慢。", "price":22, "color":Color("aac5ea")},
	{"id":"triple_espresso", "name":"三倍浓缩", "kind":"equipment", "stats":{"attack_speed":0.3, "regen":-0.3}, "tag":"高攻速 / 恢复降低", "desc":"所有武器攻击更快，每秒生命恢复降低。", "price":22, "color":Color("e5b78d")},
	{"id":"laptop_bag", "name":"负重电脑包", "kind":"equipment", "stats":{"armor":0.2, "move_speed":-22.0}, "tag":"高护甲 / 移速降低", "desc":"更耐打，但通勤般沉重的背包让移动变慢。", "price":20, "color":Color("a6b8d6")},
	{"id":"water_dispenser", "name":"饮水机工位", "kind":"equipment", "stats":{"regen":0.6,"move_speed":-14}, "tag":"恢复 / 移速降低", "desc":"走两步就能接水，坐下来就舍不得走。", "price":25, "art_frame":12, "color":Color("9ad9ed")},
	{"id":"fatty_liver", "name":"脂肪肝", "kind":"equipment", "stats":{"health":15,"regen":-0.45}, "tag":"生命 / 恢复降低", "desc":"体检报告加粗了这行字。生命上限增加，恢复变慢。", "price":22, "art_frame":13, "color":Color("f4cb79")},
	{"id":"shared_bike", "name":"共享单车", "kind":"equipment", "stats":{"move_speed":28,"dash_recovery":0.13}, "tag":"移速 / 冲刺", "desc":"骑得快一点，就能赶在迟到前到公司。", "price":25, "art_frame":14, "color":Color("8fcfff")},
	{"id":"team_building", "name":"周末团建", "kind":"equipment", "stats":{"crit_damage":0.3,"move_speed":-18}, "tag":"暴伤 / 移速降低", "desc":"合照要跳得够高，散场只想慢慢走。", "price":23, "art_frame":15, "color":Color("edb27c")},
	{"id":"punch_clock", "name":"打卡机", "kind":"equipment", "stats":{"attack_speed":0.12,"dash_recovery":-0.1}, "tag":"攻速 / 冲刺变慢", "desc":"卡点的手越来越快，出门时间越来越难估。", "price":22, "art_frame":16, "color":Color("a8b8c7")},
	{"id":"badge_lanyard", "name":"工牌挂绳", "kind":"equipment", "stats":{"reach":0.14,"incoming_damage":0.12}, "tag":"范围 / 易伤", "desc":"工牌要挂得显眼，连怪物都记住你了。", "price":20, "art_frame":17, "color":Color("8dd9ca")},
	{"id":"shift_roster", "name":"值班排班表", "kind":"equipment", "stats":{"damage":0.16,"move_speed":-12}, "tag":"伤害 / 移速降低", "desc":"排到自己时，出手很快，脚步很沉。", "price":24, "art_frame":18, "color":Color("e1c2dc")},
	{"id":"social_insurance", "name":"五险一金", "kind":"equipment", "stats":{"health":8,"armor":0.04}, "tag":"生命 / 减伤", "desc":"到账通知在凌晨亮起，安全感实打实。", "price":27, "art_frame":19, "color":Color("92a8e0")},
	{"id":"meal_voucher", "name":"加班餐券", "kind":"equipment", "stats":{"regen":0.27,"lifesteal":0.025}, "tag":"恢复 / 生命偷取", "desc":"持券去楼下，热饭能撑过下一间房。", "price":24, "art_frame":20, "color":Color("f6b777")},
	{"id":"standing_desk", "name":"升降工位", "kind":"equipment", "stats":{"reach":0.08,"dodge":0.045}, "tag":"范围 / 闪避", "desc":"桌面上升，腾出来的空间正好用来闪躲。", "price":24, "art_frame":21, "color":Color("a9dbc9")},
	{"id":"quarter_bonus", "name":"季度奖金", "kind":"equipment", "stats":{"damage":0.08,"crit_damage":0.17}, "tag":"伤害 / 暴伤", "desc":"到账那声提示，比绩效面谈悦耳。", "price":26, "art_frame":22, "color":Color("f4d08d")},
	{"id":"open_office", "name":"开放式工位", "kind":"equipment", "stats":{"pickup_radius":54,"incoming_damage":0.11}, "tag":"拾取 / 易伤", "desc":"伸手能捡到更多字节，也更容易被盯上。", "price":19, "art_frame":23, "color":Color("aac5ea")},
	{"id":"noise_report", "name":"噪音投诉单", "kind":"equipment", "stats":{"dodge":0.09,"attack_speed":-0.08}, "tag":"闪避 / 攻速降低", "desc":"有人嫌你动作太大，交表之后下手都轻了。", "price":21, "art_frame":24, "color":Color("f5aa9c")},
	{"id":"bottled_coffee", "name":"隔夜冰美式", "kind":"equipment", "stats":{"attack_speed":0.19,"health":-7}, "tag":"攻速 / 生命降低", "desc":"还能喝。喝完确实快，也确实少了点什么。", "price":23, "art_frame":25, "color":Color("c99a7e")},
	{"id":"meeting_minutes", "name":"会议纪要", "kind":"equipment", "stats":{"magic_damage":0.16,"crit_chance":0.035}, "tag":"法术 / 暴击率", "desc":"你记下了所有人没说清楚的那一部分。", "price":23, "art_frame":26, "color":Color("c4adef")},
	{"id":"urgent_stamp", "name":"加急红章", "kind":"equipment", "stats":{"melee_damage":0.15,"move_speed":10}, "tag":"近战 / 移速", "desc":"盖章声音越响，事情办得越急。", "price":24, "art_frame":27, "color":Color("f49188")},
	{"id":"bus_transfer", "name":"末班地铁", "kind":"equipment", "stats":{"dash_recovery":0.19,"move_speed":13}, "tag":"冲刺 / 移速", "desc":"听见关门提示，腿比脑子先动。", "price":27, "art_frame":28, "color":Color("8ebbe6")},
	{"id":"insurance_form", "name":"体检报告", "kind":"equipment", "stats":{"regen":0.21,"armor":0.055}, "tag":"恢复 / 减伤", "desc":"这张纸教你认真休息，偶尔也认真抗揍。", "price":25, "art_frame":29, "color":Color("a7d6bb")},
	{"id":"phone_bank", "name":"备用机", "kind":"equipment", "stats":{"ranged_damage":0.18,"reach":0.07}, "tag":"远程 / 范围", "desc":"主力机没电时，它能从很远的地方发出消息。", "price":24, "art_frame":30, "color":Color("b8c6d0")},
	{"id":"vpn_token", "name":"VPN 令牌", "kind":"equipment", "stats":{"magic_damage":0.17,"lifesteal":0.02}, "tag":"法术 / 生命偷取", "desc":"认证成功，临时连上对面的补给。", "price":24, "art_frame":31, "color":Color("c3a2e9")},
	{"id":"coworker_snacks", "name":"茶水间零食", "kind":"equipment", "stats":{"health":6,"lifesteal":0.035}, "tag":"生命 / 生命偷取", "desc":"同事放在桌上说随便拿，你只拿了一小包。", "price":23, "art_frame":32, "color":Color("f2b38f")},
	{"id":"white_noise", "name":"降噪耳塞", "kind":"equipment", "stats":{"dodge":0.045,"incoming_damage":-0.075}, "tag":"闪避 / 受到伤害降低", "desc":"隔绝同事和杂音，更容易看清眼前的攻击。", "price":26, "art_frame":33, "color":Color("c9e5ed")},
	{"id":"desk_calendar", "name":"交付倒计时", "kind":"equipment", "stats":{"crit_chance":0.045,"attack_speed":0.065}, "tag":"暴击率 / 攻速", "desc":"错过提醒就得同时处理两件，所以一直盯着时间。", "price":25, "art_frame":34, "color":Color("f4a6b8")},
	{"id":"return_receipt", "name":"报销回执", "kind":"equipment", "stats":{"pickup_radius":48,"health":4}, "tag":"拾取 / 生命", "desc":"每一张小票都收好，月底真的能换回一点血。", "price":20, "art_frame":35, "color":Color("f2d09f")},
	{"id":"read_receipts", "name":"已读不回", "kind":"equipment", "stats":{"dodge":0.095,"reach":-0.08}, "tag":"闪避 / 范围降低", "desc":"两个勾亮了。把手机扣回桌上，先别让人看见你在线。", "price":22, "color":Color("8aa9ec")},
	{"id":"meeting_link", "name":"拉会链接", "kind":"equipment", "stats":{"pickup_radius":34,"magic_damage":0.10}, "tag":"拾取 / 魔法", "desc":"拉个短会吧，最多十分钟。再把他们组也拉进来。", "price":22, "color":Color("89c8ee")},
	{"id":"muted_mic", "name":"静音麦克风", "kind":"equipment", "stats":{"dodge":0.055,"incoming_damage":-0.055}, "tag":"闪避 / 受到伤害降低", "desc":"你在静音。真的？刚才那句也没听见吧？", "price":24, "color":Color("b2bdd0")},
	{"id":"screen_share", "name":"共享屏幕", "kind":"equipment", "stats":{"reach":0.12,"crit_chance":0.035}, "tag":"范围 / 暴击率", "desc":"共享前关掉聊天窗口。对，就是最上面那个。", "price":25, "color":Color("8ad4c4")},
	{"id":"reserved_chair", "name":"会议室占座", "kind":"equipment", "stats":{"armor":0.075,"move_speed":-8}, "tag":"减伤 / 移速降低", "desc":"椅背上有件外套。会议还有四十分钟才开始。", "price":22, "color":Color("a3aae8")},
	{"id":"change_request", "name":"需求变更单", "kind":"equipment", "stats":{"melee_damage":0.22,"magic_damage":-0.09}, "tag":"近战 / 魔法降低", "desc":"改动很小，只是把昨天定下来的方向整个翻过来。", "price":23, "color":Color("f6b374")},
	{"id":"p0_alarm", "name":"优先级全是 P0", "kind":"equipment", "stats":{"crit_chance":0.025}, "tag":"F 部署 · 范围警灯", "desc":"战斗中按 F 放下警灯，持续对附近敌人发出伤害脉冲。", "price":31, "color":Color("ff8a6a")},
	{"id":"rework_boomerang", "name":"返工回旋镖", "kind":"equipment", "stats":{"ranged_damage":0.20,"attack_speed":-0.055}, "tag":"远程 / 攻速降低", "desc":"丢给上一环节的问题，绕了一圈又回到你手上。", "price":22, "color":Color("e78dbd")},
	{"id":"client_voice_note", "name":"甲方语音条", "kind":"equipment", "stats":{"magic_damage":0.16,"reach":0.07}, "tag":"魔法 / 范围", "desc":"六十秒。对方正在讲话。又一条六十秒。", "price":25, "color":Color("88dba0")},
	{"id":"paid_toilet_break", "name":"带薪拉屎", "kind":"equipment", "stats":{"regen":0.26,"dash_recovery":0.10}, "tag":"恢复 / 冲刺", "desc":"蹲够七分钟，回去洗手，顺便假装没看见群里点名。", "price":24, "color":Color("e6c58b")},
	{"id":"exit_certificate", "name":"离职证明", "kind":"equipment", "stats":{"move_speed":17,"incoming_damage":-0.06}, "tag":"移速 / 受到伤害降低", "desc":"最后一栏终于盖好了章。走出闸机时，肩膀一下就松了。", "price":28, "color":Color("e9b9a7")},
	{"id":"hiring_freeze", "name":"冻结 HC", "kind":"equipment", "stats":{"armor":0.09,"attack_speed":-0.07}, "tag":"减伤 / 攻速降低", "desc":"椅子倒是还在，岗位名额说下个季度再问。", "price":23, "color":Color("91d8ee")},
	{"id":"comp_time_request", "name":"调休申请", "kind":"equipment", "stats":{"health":7,"dash_recovery":0.12}, "tag":"生命 / 冲刺", "desc":"周六先来赶进度，下周三能不能睡个懒觉还得等批。", "price":25, "color":Color("c6a9ee")},
	{"id":"payslip", "name":"工资条", "kind":"equipment", "stats":{"pickup_radius":44,"armor":0.025}, "tag":"拾取 / 减伤", "desc":"税前、税后、房租后，三种数字能讲三个不同的故事。", "price":22, "color":Color("b7d891")},
	{"id":"probation_timer", "name":"试用期倒计时", "kind":"equipment", "stats":{"attack_speed":0.17,"incoming_damage":0.10}, "tag":"攻速 / 易伤", "desc":"离转正还剩一天，系统显示主管尚未提交评价。", "price":24, "color":Color("f2c37c")},
	{"id":"loose_adapter", "name":"断网转接头", "kind":"equipment", "stats":{"magic_damage":0.22,"reach":-0.075}, "tag":"魔法 / 范围降低", "desc":"拔下来就安静了。插回去，工单又都涌上来了。", "price":22, "color":Color("84c8c5")},
	{"id":"rental_laptop", "name":"租来的笔记本", "kind":"equipment", "stats":{"ranged_damage":0.14,"pickup_radius":25}, "tag":"远程 / 拾取", "desc":"转轴处贴着胶带，桌面却比发下来的新机还干净。", "price":24, "color":Color("baa3dc")},
	{"id":"back_heat_patch", "name":"久坐热贴", "kind":"equipment", "stats":{"regen":0.19,"melee_damage":0.10}, "tag":"恢复 / 近战", "desc":"贴在腰上，一下午都能坐直一点。", "price":23, "color":Color("f4ae65")},
	{"id":"office_cot", "name":"折叠午睡床", "kind":"equipment", "stats":{"regen":0.34,"move_speed":-10}, "tag":"恢复 / 移速降低", "desc":"两点前塞回工位底下，动作轻一点，旁边还没醒。", "price":23, "color":Color("9aaee9")},
	{"id":"focus_lamp", "name":"护眼台灯", "kind":"equipment", "stats":{"reach":0.045}, "tag":"F 部署 · 单体光束", "desc":"战斗中按 F 放下台灯，自动用光束照射最近的敌人。", "price":31, "color":Color("badf8f")},
	{"id":"red_markup", "name":"红线批注", "kind":"equipment", "stats":{"crit_chance":0.055,"melee_damage":0.08}, "tag":"暴击率 / 近战", "desc":"图上每一圈红线，都是一句没写出来的「这里重来」。", "price":25, "color":Color("f69a90")},
	{"id":"source_archive", "name":"源文件归档", "kind":"equipment", "stats":{"armor":0.04,"pickup_radius":37}, "tag":"减伤 / 拾取", "desc":"贴图、工程、字体、交接文档，全在这个盒里。希望吧。", "price":24, "color":Color("88c9bd")},
	{"id":"crash_recovery_disk", "name":"崩溃恢复盘", "kind":"equipment", "stats":{"regen":0.17,"magic_damage":0.14}, "tag":"恢复 / 魔法", "desc":"自动保存时间是四分钟前。头一回觉得四分钟这么短。", "price":25, "color":Color("9acf90")},
	{"id":"rollback_switch", "name":"一键回滚", "kind":"equipment", "stats":{"dash_recovery":0.22,"crit_damage":0.14}, "tag":"冲刺 / 暴伤", "desc":"按下去，线上恢复了。群里那三十多条消息还在。", "price":25, "color":Color("fac178")},
	{"id":"final_final", "name":"最终版_真最终", "kind":"equipment", "stats":{"damage":0.18,"incoming_damage":0.13}, "tag":"伤害 / 易伤", "desc":"改文件名前，先确认下发给群里的是第几个最终版。", "price":25, "color":Color("c29bea")},
	{"id":"rush_hour_strap", "name":"早高峰扶手", "kind":"equipment", "stats":{"armor":0.042,"melee_damage":0.11}, "tag":"减伤 / 近战", "desc":"挤进车厢最庆幸的事，是伸手还有个能抓的地方。", "price":23, "color":Color("ecae72")},
	{"id":"late_waiver", "name":"迟到免责券", "kind":"equipment", "stats":{"move_speed":11,"dodge":0.045}, "tag":"移速 / 闪避", "desc":"系统送了你一次宽容。用完记得把闹铃调早。", "price":24, "color":Color("a6c7f3")},
	{"id":"flat_key_fob", "name":"合租门禁", "kind":"equipment", "stats":{"health":5,"pickup_radius":29}, "tag":"生命 / 拾取", "desc":"塑料牌磨掉了颜色。钥匙串上惟一一个自己掏钱配的。", "price":21, "color":Color("acd6be")},
	{"id":"bike_basket_umbrella", "name":"车筐里的折伞", "kind":"equipment", "stats":{"armor":0.032,"dash_recovery":0.15}, "tag":"减伤 / 冲刺", "desc":"晴天嫌它占地方，下雨那天又庆幸自己忘了收。", "price":23, "color":Color("f4b27e")},
	{"id":"scooter_helmet", "name":"电瓶车头盔", "kind":"equipment", "stats":{"incoming_damage":-0.10,"crit_damage":-0.10}, "tag":"受到伤害降低 / 暴伤降低", "desc":"戴上再出门。下巴扣终于调到正好勒不疼的位置。", "price":24, "color":Color("87b8a8")},
	{"id":"stop_alarm", "name":"到站闹铃", "kind":"equipment", "stats":{"attack_speed":0.095,"dash_recovery":0.13}, "tag":"攻速 / 冲刺", "desc":"闭眼一小会儿，离家还有三站时它会叫你。", "price":25, "color":Color("87bdf3")},
	{"id":"subway_scarf", "name":"地铁空调围巾", "kind":"equipment", "stats":{"health":7,"incoming_damage":-0.04}, "tag":"生命 / 受到伤害降低", "desc":"八月也得用。上车十分钟，空调风就吹到后颈了。", "price":23, "color":Color("89cece")},
	{"id":"last_battery_bar", "name":"最后一格电", "kind":"equipment", "stats":{"move_speed":23,"regen":-0.18}, "tag":"移速 / 恢复降低", "desc":"油门再松一点，前面还有个坡。", "price":22, "color":Color("f6a095")},
	{"id":"platform_soy_milk", "name":"站台热豆浆", "kind":"equipment", "stats":{"regen":0.22,"health":4}, "tag":"恢复 / 生命", "desc":"早班第一口烫嘴的东西。暖完手才舍得喝。", "price":22, "color":Color("e6cb9e")},
	{"id":"pack_rain_cover", "name":"背包雨罩", "kind":"equipment", "stats":{"incoming_damage":-0.08,"move_speed":5}, "tag":"受到伤害降低 / 移速", "desc":"电脑平安到家。裤脚的事，明天再说。", "price":24, "color":Color("c6dc80")},
	{"id":"store_oden", "name":"便利店关东煮", "kind":"equipment", "stats":{"lifesteal":0.026,"armor":0.045}, "tag":"生命偷取 / 减伤", "desc":"快收摊了，店员多装了一块煮透的萝卜。", "price":24, "color":Color("e7b47e")},
	{"id":"egg_crepe", "name":"煎饼加蛋", "kind":"equipment", "stats":{"health":6,"melee_damage":0.12}, "tag":"生命 / 近战", "desc":"脆饼掰成两半，辣酱只刷薄薄一层。", "price":24, "color":Color("f3be72")},
	{"id":"packed_lunch", "name":"自带饭盒", "kind":"equipment", "stats":{"health":9,"pickup_radius":17}, "tag":"生命 / 拾取", "desc":"昨晚特意多煮一份，今天就不用盯着满减凑单。", "price":23, "color":Color("bad49e")},
	{"id":"instant_noodles", "name":"三分钟泡面", "kind":"equipment", "stats":{"lifesteal":0.036,"reach":-0.045}, "tag":"生命偷取 / 范围降低", "desc":"工区没人了，才敢撕开调料包。", "price":22, "color":Color("eb947f")},
	{"id":"delivery_bag", "name":"外卖保温袋", "kind":"equipment", "stats":{"armor":0.04,"regen":0.15}, "tag":"减伤 / 恢复", "desc":"等电梯等了十二分钟，打开袋子还有热气。", "price":23, "color":Color("f5ac71")},
	{"id":"weekend_sleep", "name":"周末补觉", "kind":"equipment", "stats":{"health":10,"regen":0.15}, "tag":"生命 / 恢复", "desc":"醒来已经过中午，手机还有电，没人找你。", "price":27, "color":Color("c1a3e6")},
	{"id":"litter_scoop", "name":"半夜猫砂铲", "kind":"equipment", "stats":{"melee_damage":0.16,"reach":0.065}, "tag":"近战 / 范围", "desc":"有些事可以明天再做。猫盯着你，意思是这个不行。", "price":24, "color":Color("9ed6b7")},
	{"id":"wet_socks", "name":"晾不干的袜子", "kind":"equipment", "stats":{"dodge":0.072,"move_speed":-9}, "tag":"闪避 / 移速降低", "desc":"踩着凉凉的，一路都在挑地上干燥的地方走。", "price":21, "color":Color("a5b6d1")},
	{"id":"discount_detergent", "name":"折扣洗衣液", "kind":"equipment", "stats":{"pickup_radius":42,"dodge":0.026}, "tag":"拾取 / 闪避", "desc":"两瓶打七折，拎回家才发现洗衣机旁没地方了。", "price":23, "color":Color("9ebbf3")},
	{"id":"rent_renewal", "name":"续租账单", "kind":"equipment", "stats":{"crit_damage":0.30,"health":-5}, "tag":"暴伤 / 生命降低", "desc":"房东说涨得很少。你点开计算器，重新算了一遍。", "price":24, "color":Color("edacac")},
	{"id":"stretching_mat", "name":"地毯拉伸垫", "kind":"equipment", "stats":{"dash_recovery":0.16,"move_speed":9}, "tag":"冲刺 / 移速", "desc":"每天十分钟。先把垫子铺开，剩下的好商量。", "price":24, "color":Color("ca9ac4")},
	{"id":"sewing_tin", "name":"奶奶的针线盒", "kind":"equipment", "stats":{"ranged_damage":0.12,"crit_chance":0.041}, "tag":"远程 / 暴击率", "desc":"打开曲奇铁盒，里面有两颗备用扣子和一截蓝线。", "price":25, "color":Color("eeb39c")},
	{"id":"roasted_sweet_potato", "name":"楼下的烤红薯", "kind":"equipment", "stats":{"health":5,"lifesteal":0.025}, "tag":"生命 / 生命偷取", "desc":"到家前剥开烫手的纸袋，最甜的是贴着皮的那一层。", "price":23, "color":Color("f4aa72")},
	{"id":"evening_shower", "name":"晚间热水澡", "kind":"equipment", "stats":{"regen":0.24,"incoming_damage":-0.045}, "tag":"恢复 / 受到伤害降低", "desc":"水温刚好，浴室起雾，今天终于可以到此为止。", "price":25, "color":Color("9dd8f4")},
	{"id":"fridge_watermelon", "name":"冰箱里的半个西瓜", "kind":"equipment", "stats":{"health":8,"attack_speed":0.06}, "tag":"生命 / 攻速", "desc":"保鲜膜掀开，勺子直接挖中间那一口。", "price":26, "color":Color("f2939a")},
]
const TURRETS := {
	"p0_alarm":{"pulse":true, "reach":145.0, "damage":19.0, "interval":1.2, "lifetime":7.0, "cooldown":14.0},
	"focus_lamp":{"pulse":false, "reach":365.0, "damage":22.0, "interval":0.85, "lifetime":8.0, "cooldown":15.0}
}
const DIALOGUES: Array[Dictionary] = [
	{"speaker":"ChatGPT 公主", "line":"毅川救我！策划杨梓亮把我带进了需求城堡……他说还有最后一个小改动！"},
	{"speaker":"毅川", "line":"来了。这一次，我自己选武器。"},
	{"speaker":"杨梓亮 · 策划", "line":"想带走公主？先过需求评审。放心，就改亿点点。"}
]
const BOSS_NAMES: Array[String] = ["保安大爷", "需求守门人", "过载核心", "若宇", "牛来 · 森野蛮王", "山田 · 相扑横纲", "杨梓亮 · 策划"]
const NIULAI_QUOTE: String = "妈妈"
const YAMADA_CLONE_COUNT: int = 4
const YAMADA_SPLIT_DURATION: float = 1.0
const RUOYU_QUOTES: Array[String] = ["让我看看", "我房里有一些好康的", "好他妈卡我操了", "味真足", "哎呦"]
const RUOYU_UNSEAL_QUOTE: String = "听话，给我看看！"
const RUOYU_UNSEAL_DURATION: float = 2.8
const RUOYU_POUNCE_FLIGHT: float = 0.44
const RUOYU_POUNCE_RECOVERY: float = 0.90
const YANG_ESCORT_NAMES := {"lin_yu":"关卡策划 · 林宇", "lin_yifeng":"TA · 林逸枫"}
const YANG_WEAK_DURATION := 1.2
const YANG_PEAK_QUOTES: Array[String] = ["你不理解", "你说的都不对", "美术都是耗材"]
const BOSS_HEALTH: Array[float] = [1000.0, 1750.0, 2100.0, 2400.0, 2700.0, 3000.0, 3300.0]
const SHARK_HEALTH: Array[float] = [600.0, 1000.0, 1300.0, 1600.0, 1900.0, 2200.0, 2500.0]
const ELITES: Array[String] = ["shark", "brood", "warden", "baola"]
const FLOOR_ELITES: Array[String] = ["barrier_bot", "file_brute", "firewall", "shoe_cabinet", "baola", "komainu", "seal_knight"]
const ELITE_NAMES := {
	"shark":"大鲨鱼", "brood":"孵化母体", "warden":"风暴哨卫", "baola":"豹拉",
	"barrier_bot":"抬杆机器人", "file_brute":"档案柜暴徒", "firewall":"防火墙哨兵", "vine_brute":"巨藤卫士",
	"komainu":"石狮师范", "shoe_cabinet":"鞋柜怪", "seal_knight":"蜡封骑士"
}
const FLOOR_ENEMIES := [
	["cone_mimic", "patrol_drone"], ["stapler", "memo_bat"], ["packet_drone", "fiber_crawler"],
	["crt_mimic", "dust_sweeper"], ["wolf", "ropehead", "wolf", "wolf", "ropehead"], ["straw_brawler", "drum_yokai", "lantern"],
	["chess_rook", "ink_scribe"]
]
const ENEMY_CAST := {
	"cone_mimic":{"art":0, "moves":["lunge", "ring"]},
	"patrol_drone":{"art":1, "moves":["burst", "mark"], "ranged":true},
	"barrier_bot":{"art":2, "moves":["pull", "guard", "cross"]},
	"stapler":{"art":0, "moves":["lunge", "slam"]},
	"memo_bat":{"art":1, "moves":["fan", "mark"], "ranged":true},
	"file_brute":{"art":2, "moves":["guard", "slam", "summon"]},
	"packet_drone":{"art":8, "moves":["burst", "cross"], "ranged":true},
	"fiber_crawler":{"art":9, "moves":["lunge", "mark"]},
	"firewall":{"art":10, "moves":["cross", "guard", "summon"]},
	"thorn_bud":{"art":12, "moves":["fan", "slam"]},
	"spore_moth":{"art":13, "moves":["ring", "mark"], "ranged":true},
	"vine_brute":{"art":14, "moves":["slam", "mark", "fan"]},
	"straw_brawler":{"art":16, "moves":["lunge", "guard"]},
	"drum_yokai":{"art":17, "moves":["ring", "slam"]},
	"komainu":{"art":18, "moves":["lunge", "ring", "slam"]},
	"lantern":{"art":19, "moves":["mark", "fan"], "ranged":true},
	"crt_mimic":{"art":0, "moves":["fan", "mark"], "ranged":true},
	"dust_sweeper":{"art":1, "moves":["lunge", "ring"]},
	"shoe_cabinet":{"art":2, "moves":["guard", "slam"]},
	"chess_rook":{"art":20, "moves":["lunge", "cross"]},
	"ink_scribe":{"art":21, "moves":["mark", "burst"], "ranged":true},
	"lin_yu":{"art":0, "moves":["mark", "cross"]},
	"lin_yifeng":{"art":1, "moves":["burst", "ring"], "ranged":true},
	"seal_knight":{"art":22, "moves":["guard", "lunge", "cross"]}
}
const BOSS_ART: Array[int] = [0, 3, 11, 0, -1, -1, -1]
const BOSS_MOVES := [
	["fan", "lunge", "slam", "summon"], ["burst", "guard", "mark", "summon"],
	["cross", "mark", "burst", "summon"], ["fan", "mark", "cross", "pull", "summon"],
	[], [], ["decree", "cross", "mark", "summon", "laser"]
]
const SKILLS: Array[Dictionary] = [
	{"id":"power", "name":"战意", "icon":"blade", "desc":"所有武器伤害提高 15%。"},
	{"id":"haste", "name":"疾风", "icon":"chip", "desc":"所有武器攻击速度提高 12%。"},
	{"id":"vigor", "name":"强健", "icon":"heart", "desc":"生命上限增加 20，并恢复 20 生命。"},
	{"id":"recovery", "name":"再生", "icon":"coffee", "desc":"每秒额外恢复 0.5 生命。"},
	{"id":"dash", "name":"瞬身", "icon":"boots", "desc":"冲刺恢复速度提高 20%。"},
	{"id":"onion", "name":"洋葱守护", "icon":"orb", "desc":"解锁 Q 守护；已有技能则强化伤害、范围、护盾与冷却。"}
]
const NPCS: Array[Dictionary] = [
	{"id":"rhode", "name":"罗德", "quote":"给毅川派活", "role":"加急委托", "offer":"下一间战斗房追加一波敌人，完成后获得 45 字节。这里是安全区。", "button":"接下加急工单", "color":Color("ffbe83")},
	{"id":"heide", "name":"海德骑士", "quote":"毅川救我", "role":"临时战友", "offer":"加入队伍，自动追击敌人。跟随当前层，进入下一层后离队。", "button":"并肩救回公主", "color":Color("d9e6dc")},
	{"id":"basan", "name":"八桑", "quote":"好他妈卡我草了", "role":"付费训练", "offer":"花费 12 字节，本局所有武器伤害提高 12%。", "button":"学习识破 · 12 字节", "color":Color("ff9e84")},
	{"id":"laya", "name":"菈雅", "quote":"这条路我熟，带上这个吧。", "role":"旅途赠礼", "offer":"免费赠送一件随机武器或装备；满栏时可自动合并同名同品质副本。", "button":"接受菈雅的礼物", "color":Color("bb9ef1")},
	{"id":"coin", "name":"硬币", "quote":"别赌运气，字节花在刀刃上。", "role":"游商", "offer":"出售武器和装备，可刷新货架。相同物品可在背包中合并。", "button":"看看硬币的货架", "color":Color("ffcf83")},
	{"id":"onion", "name":"洋葱骑士哈少", "quote":"学习学习", "role":"技能传授", "offer":"解锁 Q「洋葱守护」：震退周围敌人并抵挡伤害 2 秒，冷却 10 秒。", "button":"学会洋葱守护", "color":Color("ced5ad")},
	{"id":"jiahao", "name":"嘉豪", "quote":"装备到位，直接开干。", "role":"武器工匠", "offer":"免费把一把当前携带的武器提升一个品质，最高传说。每次偶遇只能改装一次。", "button":"请嘉豪改装武器", "color":Color("8fcfff")}
]

static var item_index: Dictionary = {}

static func item(id: String) -> Dictionary:
	if item_index.is_empty():
		for spec in WEAPONS + EQUIPMENT:
			item_index[spec.id] = spec
	return item_index.get(id, {})

static func multiplier(tier: int) -> float:
	return MULTIPLIERS[clampi(tier - 1, 0, 3)]

static func equipment_multiplier(tier: int) -> float:
	return EQUIPMENT_MULTIPLIERS[clampi(tier - 1, 0, 3)]

static func stat_text(id: String, value: float, bonus: bool = false) -> String:
	if id in ["damage", "attack_speed", "reach", "dash_recovery", "melee_damage", "ranged_damage", "magic_damage", "incoming_damage"]:
		return "%+.1f%%" % ((value if bonus else value - 1.0) * 100)
	if id in ["armor", "crit_chance", "crit_damage", "dodge", "lifesteal"]:
		return ("%+.1f%%" if bonus else "%.1f%%") % (value * 100)
	return ("%+.2f" if bonus else "%.2f") % value if id == "regen" else ("%+.1f" if bonus else "%.1f") % value

static func item_bonus_text(spec: Dictionary, tier: int, count: int = 1) -> String:
	var parts: Array[String] = []
	for id in spec.get("stats", {}):
		parts.append(STAT_NAMES[id] + " " + stat_text(id, spec.stats[id] * equipment_multiplier(tier) * count, true))
	return " · ".join(parts)

static func generate(seed_value: int, floor_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + floor_index * 104729
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var target: int = FLOOR_ROOM_COUNTS[floor_index]
	var main_count: int = target - rng.randi_range(2, 3)
	var parents: Array[int] = [-1]
	var forward: Vector2i = DIRECTIONS[rng.randi_range(0, 3)]
	var side := Vector2i(-forward.y, forward.x)
	var last_turn: bool = false
	for i in range(1, main_count):
		var turn: bool = i > 1 and i < main_count - 1 and not last_turn and rng.randf() < 0.35
		var direction: Vector2i = side * (1 if rng.randf() < 0.5 else -1) if turn else forward
		var candidate: Vector2i = cells[-1] + direction
		if candidate in cells:
			candidate = cells[-1] + forward
			turn = false
		cells.append(candidate)
		parents.append(i - 1)
		last_turn = turn
	# Explicit parent links keep touching rooms from creating accidental loops.
	while cells.size() < target:
		var candidates: Array[Dictionary] = []
		for parent in range(1, main_count - 1):
			for direction in DIRECTIONS:
				var candidate: Vector2i = cells[parent] + direction
				if candidate not in cells and Vector2(candidate).dot(Vector2(forward)) > 0:
					candidates.append({"cell":candidate, "parent":parent})
		var pick: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		cells.append(pick.cell)
		parents.append(pick.parent)
	var rooms: Array[Dictionary] = []
	for i in range(cells.size()):
		rooms.append({"id":i, "cell":cells[i], "links":[-1, -1, -1, -1], "main_route":i < main_count, "parent":parents[i], "type":"combat", "visited":false, "revealed":i == 0, "cleared":false, "used":false, "stock":[], "refreshes":0, "layout":rng.randi_range(0, 4)})
		if i > 0:
			var direction: int = DIRECTIONS.find(cells[i] - cells[parents[i]])
			rooms[parents[i]].links[direction] = i
			rooms[i].links[(direction + 2) % 4] = parents[i]
	var boss: int = main_count - 1
	rooms[0].type = "start"
	rooms[boss].type = "boss"
	rooms[rng.randi_range(2, main_count - 2)].type = "elite"
	var service_type: String = "rest" if rng.randi_range(0, 1) == 0 else "npc"
	var on_main_route: bool = rng.randf() < 0.30
	var available: Array[int] = []
	for room in rooms:
		if room.type == "combat" and room.main_route == on_main_route:
			available.append(room.id)
	rooms[available[rng.randi_range(0, available.size() - 1)]].type = service_type
	var encounter_weights := PackedFloat32Array([7, 1, 2] if floor_index < 2 else [1, 1, 1])
	var npc_pool: Array[int] = []
	for i in range(NPCS.size()):
		npc_pool.append(i)
	var dark_home: bool = FLOOR_STYLES[floor_index] == "dark_home"
	var cover_size := Vector2(72, 42) if dark_home else Vector2(96, 56)
	for room in rooms:
		room["npc"] = -1
		room["npc_used"] = false
		room["started"] = false
		room["reward_shop"] = false
		room["skill_claimed"] = false
		room["encounter"] = ["single", "double", "stream"][rng.rand_weighted(encounter_weights)]
		room["elite_kind"] = FLOOR_ELITES[floor_index]
		room["terrain"] = ("forest" if (room.id if room.main_route else room.parent) < main_count / 2 else "grassland") if FLOOR_STYLES[floor_index] == "wilds" else "indoor"
		if dark_home:
			var route_id: int = room.id if room.main_route else room.parent
			room["area"] = 3 if room.id == boss else mini(2, route_id * 3 / boss)
		if room.type == "npc":
			var pick: int = rng.randi_range(0, npc_pool.size() - 1)
			room.npc = npc_pool[pick]
			npc_pool.remove_at(pick)
		var sizes: Array[Vector2] = [Vector2(800, 544), Vector2(896, 608), Vector2(1024, 672), Vector2(1152, 736)]
		var size: Vector2 = sizes[rng.randi_range(0, sizes.size() - 1)]
		if room.type in ["start", "npc", "rest", "shop", "treasure"]:
			size = Vector2(576, 416) if room.type == "start" else Vector2(480 + rng.randi_range(0, 1) * 64, 352 + rng.randi_range(0, 1) * 64)
			if room.type == "npc":
				size = Vector2(416 + rng.randi_range(0, 1) * 64, 288 + rng.randi_range(0, 1) * 64)
		elif room.type == "boss":
			size = Vector2(1344, 896)
		elif room.type == "elite":
			size = Vector2(1152, 768)
		room["center"] = CENTER + Vector2(room.cell) * CELL_SPACING
		room["rect"] = Rect2(room.center - size / 2, size)
		room["doors"] = door_points(room.rect)
		room["obstacles"] = obstacles(room.layout, room.type, room.rect, cover_size)
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

static func obstacles(layout: int, room_type: String, bounds: Rect2 = ARENA, cover_size: Vector2 = Vector2(96, 56)) -> Array[Rect2]:
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
		var center: Vector2 = bounds.position + (rect.get_center() - Vector2(64, 166)) * factor
		var offsets: Array[Vector2] = [Vector2.ZERO]
		if rect.size.x > 100:
			offsets = [Vector2(-56, 0), Vector2(56, 0)]
		elif rect.size.y > 80:
			offsets = [Vector2(0, -44), Vector2(0, 44)]
		for offset in offsets:
			# Furniture size stays constant; larger rooms spread out the arrangement.
			result.append(Rect2(center + offset - cover_size / 2, cover_size))
	return result
