# 毅川救我 · 横版肉鸽

一位虚幻开发师，一把断点刀，一个不能崩溃的夜晚。以毅川的橙白柴犬头像为原型，穿过开发工具变成的像素异世界，通过每局不同的技能组合救回项目组。

## 试玩

到 [v0.3.0 Releases 下载 Windows 64 位修复版](https://github.com/Biscuits-Lab/yichuan-save-me/releases/tag/v0.3.0)。双击 EXE 即可运行，或下载 ZIP 解压后运行其中的 EXE；资源已内嵌，无需安装 Godot 或联网。本地构建输出为 `build/windows-v0.3.0/毅川救我.exe` 和 `build/毅川救我-v0.3.0-肉鸽版-Windows-x64.zip`。

v0.3.0 包含长关卡、清怪自动开门、途中随机 NPC、三档难度、Home 作弊面板和 12 套关卡场景，并移除周期喷口、修复平台条纹越界。

从源码运行：用 Godot 4.5 或更新的 4.x 导入 `project.godot`，按 F5。当前工作目录也可双击 **开始游戏.cmd**。缺少本地运行时可执行 `python tools/bootstrap.py`，需要 Python 与 requests；运行时下载到 `.tools/`。

## 两种模式

- **剧情救场**：四个章节、12 个子关卡，每关长 7040 像素，包含三个战区、六波怪物和独立关底 Boss。打败 Boss 后必须完成技能三选一，再选择补给或精英路线进入下一关。
- **无尽加班**：沿用完整的关卡循环，第 12 关后继续生成。敌人与 Boss 随深度成长，记录最高通过关数和最高分。常规技能满级后仍有可重复强化与补给选项。

倒下会结束本局。新的一局重置技能、工单和进度；最高纪录保留。没有强制等待倒计时，以探索、战斗、节点和 Boss 延长流程。

## 故障与怪物

| 章节 | 子关卡事件 |
| --- | --- |
| 同步荒原 | UGS 同步死锁、DDC 缓存迷宫、Shader 编译洪流 |
| 脚本深井 | AngelScript 脚本深井、Live Coding 热重载熔炉、GC 回收风暴 |
| 版本牢城 | P4 独占检出、Memory 泄漏沼泽、Network 高延迟边境 |
| 渲染天守 | Nanite 装配碎境、Lumen 反射幻城、BUILD 最后一次打包 |

每局可调换章节内的事件顺序，并按种子从六种布局模板生成平台组合。子关卡有上下层可选路线、断桥、三处咖啡补给、可选宝箱和途中随机 NPC。精英路线增加敌人，敌人生命 +30%，工单收益 +50%；补给路线进入下一关时恢复 2 点生命。

每个战区有两波敌人，全部击败后节点自动恢复、封锁门自动打开，无需回头按 E。持续箭头指向剩余敌人、下一战区或关底 Boss；高台只用于可选探索，悬空平台可从下方跳上。三个战区清空后，右侧最终竞技场出现 Boss。周期喷口及其伤害、耗能与弹幕已移除；保留敌人施法的蓄力预警。平台条纹和砖块细节会裁剪到平台实际边界。

12 类敌人拥有对应造型与行为：机械同步虫、编译幽灵、锁甲武士、服务器鬼武者，以及新增的 Shader 晶体法师、Nanite 构造体、Lumen 灯蛾、DDC 拟态箱、GC 收集妖、泄漏软泥、热重载机械龙、网络延迟蝠。关底版本拥有更高生命、蓄力预警和强化招式，例如召唤、突进、地面法阵、环形弹幕和冲击波。

GC 区域能量恢复降低、击杀回能提高；DDC 宝箱会触发拟态怪；延迟弹先悬停后飞出，玩家输入保持正常响应。敌人施法会先预警再造成伤害。

## 难度与作弊

标题界面可用鼠标或左右方向键选择 **休闲 / 标准 / 硬核**。三档初始生命分别为 12 / 8 / 6，并调整敌人生命、每波数量、攻击频率和伤害。剧情与无尽均生效，开局后难度固定；纪录按难度分别保存，旧纪录保留在标准档。

按 **Home** 打开或关闭作弊面板，游戏会暂停。鼠标点击或按 **1 / 2** 分别切换无敌与一击必杀（包括 P4 锁甲和 Boss）；Home / Esc 返回。选项可独立开启、关闭，关闭后恢复正常战斗。开启过作弊的本局不覆盖普通难度纪录，HUD 会明确提示。

## 技能与操作

| 按键 | 动作 |
| --- | --- |
| A / D、左右方向键 | 移动 |
| 空格 / W / 上方向键 | 跳跃与二段跳 |
| J / X | 三连斩，可长按；支持提前输入下一刀 |
| K / C | 断点领域，35 能量，范围伤害并穿透 P4 锁甲 |
| U | 自动化飞剑，需要技能解锁，发射追踪飞剑 |
| I | 版本回滚，需要技能解锁，获得短时护盾 |
| L / Shift | 无敌冲刺 |
| E | 与随机 NPC 交谈、打开宝箱；战区开门无需交互 |
| Home | 作弊面板，1 切换无敌、2 切换一击必杀 |
| 1 / 2 / 3 | Boss 奖励三选一；路线页使用 1 / 2 |
| Tab | 本局技能列表 |
| F1 | 工程生存手册 |
| Esc | 暂停、关闭手册或离开 NPC 对话 |
| R / Enter | 本局结束后重新开局 |
| M / F11 | 静音 / 全屏 |

18 项可升级技能可组成近战、暴击、灼烧、异常连锁、飞剑、断点、回滚护盾、冲刺伤害或续航等组合。第一位 Boss 的奖励保证提供飞剑选项。技能只在本局保留；上限已满的技能不会继续占用奖励卡。

## NPC

| NPC | 常用语 | 服务 |
| --- | --- | --- |
| 若宇 | 我这显示是对的 | 免费恢复 2 点生命和 30 能量 |
| 罗德 | 给毅川派活 | 接加急工单，增加敌人，打败本关 Boss 额外获得 25 工单 |
| 海德骑士 | 毅川救我 | 免费提供一次伤害抵挡 |
| 只狼 | 好他妈卡我草了 | 花 12 工单训练，本局近战伤害 +1 |

入口不会固定出现 NPC；每关按种子随机安排 0–2 次途中偶遇，接近对应区域才会出现，身份和位置都会变化。每个 NPC 的服务在每关只能领取一次。毅川仍会说“来了”“救命”“哦豁，完蛋”“坏啦”“怀不上了”。对白使用紧凑圆角气泡和加粗文字。

## 动作、美术与声音

保留 16 帧跑步和 16 帧挥刀源图，改为连续时间推进、固定图集根锚点、GPU 帧间混合和物理插值；增加 0.2 秒连招输入缓冲。受伤姿态与无敌状态分离，避免整段无敌时间一直切到受伤图。

内置 imagegen 生成主视觉、背景、主角、怪物、NPC、技能图标与特效，源文件都在 `assets/`，规格与提示词组见 `docs/art-direction.md`。新增的 12 张场景背景位于 `assets/art/environments/`，每关使用自己的建筑主题、平台材质和天气，完整生成提示词见 `docs/environment-art.md`。AI 图集仍有轮廓与装备细节差异，可在正式制作阶段继续逐帧精修。

音效和五声音阶芯片音乐由 GDScript 合成；字体 Noto Sans SC 和 Press Start 2P 使用 OFL 授权，授权附在 `assets/fonts/`。

## 验证与打包

```powershell
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --log-file .tools/tests.log --fixed-fps 60 --script tools/test_game.gd -- --no-music
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --log-file .tools/navigation.log --fixed-fps 60 --script tools/test_navigation.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . --log-file .tools/player-motion.log --audio-driver Dummy --fixed-fps 120 --script tools/test_player_motion.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . --log-file .tools/render.log --audio-driver Dummy --fixed-fps 60 --script tools/render_preview.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --log-file .tools/options.log --fixed-fps 60 --script tools/test_run_options.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . --log-file .tools/environments.log --audio-driver Dummy --fixed-fps 60 --script tools/render_environments.gd -- --no-audio
python tools/build_windows.py
```

受限环境下建议将 `--log-file` 改为项目内的绝对路径。集成验证覆盖完整 12 关流程、每关 Boss 与奖励防重领、NPC 的单次服务与费用、输入与伤害、P4 破锁、主动技能、无尽第 13 关、满级奖励和存档；渲染工具输出实机截图到 `output/previews/`。

Windows 构建使用项目本地的官方 Godot 4.5.2 x64 release 模板，将资源嵌入 EXE。构建脚本只下载所需模板成员，随后生成 EXE 与 ZIP；不会自动提交或发布。
