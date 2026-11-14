# 像素旷野：2D 沙盒模式

## 现有游戏分析

当前主场景为 `scenes/main.tscn`，由 `scripts/dungeon_run.gd` 驱动；`dungeon_data.gd` 生成俯视房间与走廊，`dungeon_view.gd` 负责世界和固定屏幕 UI。它的战斗、碰撞、导航、房间封路和装备交易都以俯视平面为前提。早期 `game.gd` / `samurai.gd` 虽然提供横版跳跃，但依赖关卡、房门和旧战斗状态，直接复用会让可破坏地形与旧逻辑互相牵制。

新增模式因此采用独立场景、数据和运行状态，通过原主菜单按钮或 B 进入。复用毅川、怪物、字体、音效和图集切片工具，地牢玩法与纪录使用原来的入口和存储。当前版本为 0.5.1。

## 实现结构

| 文件 | 职责 |
| --- | --- |
| `scenes/sandbox.tscn` | 沙盒场景入口 |
| `scripts/sandbox_data.gd` | 方块与物品、配方、商人物资、带种子的地形、游戏日到访与 Review 参数 |
| `scripts/sandbox_run.gd` | 横版移动、扫掠碰撞、挖掘放置、制作、战斗、商人、持久化和输入 |
| `scripts/sandbox_view.gd` | 像素方块贴图、可见分块缓存、昼夜天空、照明、地图、背包与交易 UI |
| `assets/generated/sandbox/friday-priest.png` | 神父透明像素立绘 |
| `tools/test_sandbox.gd` | 沙盒自动检查 |
| `tools/test_modes.gd` | 主菜单进入、保存退出、返回地牢后的开局检查 |
| `tools/test_sandbox_regressions.gd` | 存档异常、鼠标操作、到访周期及 Code Review 回归检查 |
| `tools/render_sandbox.gd` | 实机渲染与界面截图 |

世界为 576×192 格、每格 24 像素，使用 `PackedByteArray` 保存方块和探索迷雾。地表丘陵、洞穴、矿脉使用带固定种子的 FastNoiseLite；出生地附近提供平地、向东延伸的洞口及基础矿脉，深处固定生成一颗大地之心。随机生成同时包含森林、沙漠和雪原。FastNoiseLite 接口参考 [Godot 4.5 官方文档](https://docs.godotengine.org/en/4.5/classes/class_fastnoiselite.html)。

角色以脚底为位置基准，使用 16×36 像素碰撞体。移动分轴处理，每次至多推进 4 像素，在发生碰撞时二分细化；提供跳跃缓冲和离地宽限。可挖掘目标同时受到距离、视线、方块硬度和工具等级限制。实体方块不能放进角色体内，方块放置需要相邻支撑和实际库存。树木不阻挡行走，砍断树干会收集连接的上部原木。

制作按配方扣除材料，必须靠近实际放下的工作台或熔炉；背包内携带设施不算。铜、铁镐原位升级并解锁下一矿物等级，剑也可升级。基础资源、方块和设施可装备到十格快捷栏，其他矿物、消耗品和货币留在行囊。击败怪物直接获得凝胶和旧银币。护符和提灯只需留在背包即可生效。

地形按 16×16 格生成 ImageTexture，仅绘制镜头附近分块；编辑方块时只失效相关分块。天空使用视差山脉、云层与昼夜色调，地下保留背景岩壁。人物、火把、信标与大地之心提供局部照明。地图只显示已探索区域。

## 神父与五日到访

神父按用户要求采用加斯科因神父形象：宽檐帽、蒙眼绷带、灰白胡须、猎人长衣、斧和枪。立绘使用内置 `image_gen` 生成，保留透明背景，原始提示词见 [sandbox-priest-imagegen-prompt.txt](sandbox-priest-imagegen-prompt.txt)。图像没有在运行时依赖生成目录，已复制到项目资产目录。

主线是游戏公司开发团队的救援喜剧：ChatGPT 公主被策划杨梓亮带进需求城堡，毅川穿过需求办公室、迭代工坊和策划城堡救回她，结局是「保存，提交，今晚准时下班」。神父在设定中是 CTO，界面身份栏只显示「CTO」。店内台词为「毅川，物资备好了。需求我来挡，公主你去救。」

到访使用存档中的世界时间：第 5、10、15……个游戏日出现，每次停留一天。游戏从第 1 天上午开始，世界在午夜换日；每轮昼夜 600 秒。暂停、背包、商店和 Code Review 不推进世界时间。商人位于出生地左侧约七格，接近后 E 打开交易；菜单、HUD、指南和商店显示下次到访日。地形被挖空时会选择附近安全地表，避免落到矿坑底部。

每份世界存档记录上次到访的游戏日与各商品剩余份数。同次到访重新交互、回到菜单或读档不会补货，下次到访重新补货。交易验证到访、距离、视线、库存、货币和唯一物品后再扣款，保存失败回滚物品、货币和库存。旧版按现实日期保存的世界可以继续读取，已有建筑和物品保留，商人切换到游戏日规则。

## Code Review 彩蛋

神父商店的「Code Review · 挑战」打开高难记忆翻牌小游戏。20 张牌、10 组 Bug，限时 60 秒、最多 16 回合。每回合翻两张，相同则配对，不同则展示 0.7 秒后盖回；展示期间不能翻第三张。完成至少需要 10 回合，因此最多容许 6 次配错。时间或回合耗尽可以重新挑战，Esc 返回商店。

全部配对后显示「Code Review 通关」，从神父货架免费任选一个物品，数量为 1。奖励由 CTO 单独提供，不扣旧银币和商店库存，已拥有的提灯或护符不能重复领。每次到访可领取一次，下次到访重新开放。通关资格与待领奖状态保存，退出后可以回来领取；领奖保存失败时回滚发放并保留资格。进行中的牌局不保存。

## 存档与边界

沙盒采用独立的 `user://sandbox-v1.save`，含地形、探索迷雾、背包、装备、快捷栏、位置、生命、游戏时间、里程碑、商人库存和 Review 资格。每 30 秒自动保存，F5 手动保存，退出、交易和领奖也保存。先写临时文件，校验旧主档后备份并替换；损坏主档不会覆盖有效备份。读取使用 `get_var(false)`，检查类型、尺寸、方块编号、工具等级、数量、位置、库存和奖励状态。死亡存档按正常复活恢复，保留建筑与物品。文件接口参考 [Godot 4.5 FileAccess](https://docs.godotengine.org/en/4.5/classes/class_fileaccess.html)。

当前一个世界槽；创建新世界有替换确认。地牢纪录与早期横版纪录保持独立。此版不含液体流动、多人联网、住房判定、农作物、地下 Boss 进度树或无限世界。沙块为静态可建造方块，没有重力模拟。

## 验证与本地构建

```powershell
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --log-file .tools/sandbox-tests.log --script tools/test_sandbox.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --log-file .tools/dungeon-regression.log --script tools/test_dungeon.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . --audio-driver Dummy --log-file .tools/sandbox-render.log --script tools/render_sandbox.gd -- --no-audio
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . --audio-driver Dummy --log-file .tools/sandbox-audit.log --script tools/test_sandbox_regressions.gd -- --no-audio
python tools/build_windows.py
```

自动检查涵盖地形、碰撞、挖掘、制作、战斗、昼夜、五日到访、库存持久化、存档异常、真实鼠标和键盘事件，以及 Review 配对、超时、回合限制、最后一回合获胜、领奖、防重复领取和旧存档兼容。

自检中复现的问题、修复和本轮检查结果见 [sandbox-self-check.md](sandbox-self-check.md)。

截图输出到 `output/previews/sandbox-*.png`，包含模式菜单、地表、制作、神父商店、洞穴、地图、指南、Code Review 和领奖。Windows 导出使用原有官方模板下载器，只下载匹配 Godot 4.5.2 的 Windows x64 模板，校验 ZIP 成员 CRC，再生成内嵌资源 EXE 和便携 ZIP。下载器使用 Python 标准库，无需额外安装 requests。本地构建不会提交或发布。
