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
const FLOOR_NAMES: Array[String] = ["需求办公室", "迭代工坊", "霓虹机房", "失控温室", "牛来的森林与草地", "山田的相扑道场", "策划的空中城堡"]
const FLOOR_COUNT: int = 7
const FLOOR_COLORS: Array[Color] = [Color("77d9b4"), Color("c4a0f2"), Color("63dfee"), Color("afd889"), Color("a7d574"), Color("efbd76"), Color("ffb878")]
const FLOOR_STYLES: Array[String] = ["office", "workshop", "server", "garden", "wilds", "sumo", "castle"]
const FLOOR_STORIES: Array[String] = [
	"先穿过办公室，找到通往工坊的路线。",
	"前面是迭代工坊，小心缝合兽的连续冲锋。",
	"信号穿过了霓虹机房！躲开核心的交错电流。",
	"温室已经失控，荆棘母体守着出口，小心扩散的花粉。",
	"穿过森林和草地，牛来守着尽头！提防豹拉扑击、狼群和小绳头的毒液。",
	"山田挡在相扑道场！看到蓄力就侧闪，跺地时拉开距离。",
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
	{"id":"railgun", "attack_type":"ranged", "name":"主干轨道炮", "kind":"weapon", "attack":"beam", "tag":"远程 · 直线光束", "desc":"瞬间命中射线上的所有敌人，受到掩体阻挡。", "price":35, "damage":42.0, "cooldown":1.65, "reach":620.0, "color":Color("dda4ff")}
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
	{"id":"laptop_bag", "name":"负重电脑包", "kind":"equipment", "stats":{"armor":0.2, "move_speed":-22.0}, "tag":"高护甲 / 移速降低", "desc":"更耐打，但通勤般沉重的背包让移动变慢。", "price":20, "color":Color("a6b8d6")}
]
const DIALOGUES: Array[Dictionary] = [
	{"speaker":"ChatGPT 公主", "line":"毅川救我！策划杨梓亮把我带进了需求城堡……他说还有最后一个小改动！"},
	{"speaker":"毅川", "line":"来了。这一次，我自己选武器。"},
	{"speaker":"杨梓亮 · 策划", "line":"想带走公主？先过需求评审。放心，就改亿点点。"}
]
const BOSS_NAMES: Array[String] = ["需求守门人", "迭代缝合兽", "过载核心", "荆棘母体", "牛来 · 森野蛮王", "山田 · 相扑横纲", "杨梓亮 · 策划"]
const NIULAI_QUOTE: String = "妈妈"
const BOSS_HEALTH: Array[float] = [1000.0, 1750.0, 2100.0, 2400.0, 2700.0, 3000.0, 3300.0]
const SHARK_HEALTH: Array[float] = [600.0, 1000.0, 1300.0, 1600.0, 1900.0, 2200.0, 2500.0]
const ELITES: Array[String] = ["shark", "brood", "warden", "baola"]
const ELITE_NAMES := {"shark":"大鲨鱼", "brood":"孵化母体", "warden":"风暴哨卫", "baola":"豹拉"}
const SKILLS: Array[Dictionary] = [
	{"id":"power", "name":"战意", "icon":"blade", "desc":"所有武器伤害提高 15%。"},
	{"id":"haste", "name":"疾风", "icon":"chip", "desc":"所有武器攻击速度提高 12%。"},
	{"id":"vigor", "name":"强健", "icon":"heart", "desc":"生命上限增加 20，并恢复 20 生命。"},
	{"id":"recovery", "name":"再生", "icon":"coffee", "desc":"每秒额外恢复 0.5 生命。"},
	{"id":"dash", "name":"瞬身", "icon":"boots", "desc":"冲刺恢复速度提高 20%。"},
	{"id":"onion", "name":"洋葱守护", "icon":"orb", "desc":"解锁 Q 守护；已有技能则强化伤害、范围、护盾与冷却。"}
]
const NPCS: Array[Dictionary] = [
	{"id":"ruoyu", "name":"若宇", "quote":"this is the way", "role":"补给", "offer":"免费恢复 35 点生命。每次偶遇只能领取一次。", "button":"检查显示，领取补给", "color":Color("77d9b4")},
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
	var target: int = 10 + floor_index
	var main_count: int = target - rng.randi_range(3, 4)
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
	var available: Array[int] = []
	for i in range(main_count, rooms.size()):
		available.append(i)
	rooms[rng.randi_range(2, main_count - 2)].type = "elite"
	var special_rooms: Array[String] = ["treasure", "rest"]
	# One shared optional slot: a floor may have either an NPC or a shop, or neither.
	if rng.randi_range(0, 1) == 1:
		special_rooms.append("npc" if rng.randi_range(0, 1) == 0 else "shop")
	for special in special_rooms:
		var slot: int = rng.randi_range(0, available.size() - 1)
		rooms[available[slot]].type = special
		available.remove_at(slot)
	var npc_pool: Array[int] = []
	for i in range(NPCS.size()):
		npc_pool.append(i)
	for room in rooms:
		room["npc"] = -1
		room["npc_used"] = false
		room["started"] = false
		room["reward_shop"] = false
		room["skill_claimed"] = false
		room["encounter"] = ["single", "double", "stream"][rng.randi_range(0, 2)]
		room["elite_kind"] = "baola" if FLOOR_STYLES[floor_index] == "wilds" else ELITES[rng.randi_range(0, 2)]
		room["terrain"] = ("forest" if (room.id if room.main_route else room.parent) < main_count / 2 else "grassland") if FLOOR_STYLES[floor_index] == "wilds" else "indoor"
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
		var center: Vector2 = bounds.position + (rect.get_center() - Vector2(64, 166)) * factor
		var offsets: Array[Vector2] = [Vector2.ZERO]
		if rect.size.x > 100:
			offsets = [Vector2(-56, 0), Vector2(56, 0)]
		elif rect.size.y > 80:
			offsets = [Vector2(0, -44), Vector2(0, 44)]
		for offset in offsets:
			# Furniture size stays constant; larger rooms spread out the arrangement.
			result.append(Rect2(center + offset - Vector2(48, 28), Vector2(96, 56)))
	return result
