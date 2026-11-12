# 毅川救我

一位虚幻引擎开发师，一把断点刀，一个不能崩溃的夜晚。

以毅川的柴犬头像为原型的 Godot 横版像素动作游戏。深夜，工程故障把办公室变成了赛博武士城。毅川系上红围巾，拔出断点刀，从 UGS 同步冲突一路砍到最终打包失败。

![毅川救我](assets/art/key-art.png)

## 运行

**直接试玩：**到 [Releases 下载 Windows 64 位独立版](https://github.com/Biscuits-Lab/yichuan-save-me/releases/latest)。下载 EXE 后双击即可，或下载 ZIP 解压后双击其中的 EXE。所有游戏资源均已内嵌，无需安装 Godot、复制项目或联网。

**从源码运行：**用 Godot 4.5 或更新的 4.x 版本导入 `project.godot`，按 F5 运行。

也可以先运行 `python tools/bootstrap.py`（需要 Python 和 `requests`）下载项目本地的 Godot 4.5.2 和字体，再双击 **开始游戏.cmd**。本地工具放在 `.tools/`，不提交到源码仓库。

## 操作

| 按键 | 动作 |
| --- | --- |
| A / D、左右方向键 | 移动 |
| 空格 / W / 上方向键 | 跳跃，空中可再跳一次 |
| J / X | 三段断点斩，第三刀伤害更高 |
| K / C | 断点领域，消耗 35 能量，范围伤害并穿透 P4 文件锁 |
| L / Shift | 热重载冲刺，短暂无敌 |
| E | 与工具终端交互 |
| Esc | 暂停 / 继续 |
| F1 / Tab | 工程生存手册 |
| R / Enter | 倒下后从检查点继续；通关后再玩一局 |
| M | 静音 |
| F11 | 全屏 |

## 四幕流程

1. **UGS · 同步风暴**：清理三个同步冲突虫，躲开数据包，在终端按 E 重新同步。
2. **AngelScript · 脚本迷城**：用二段跳接近编译幽灵，清理三个脚本错误，按 E 热重载。
3. **P4 · 独占检出**：普通攻击会被文件锁挡住。等锁甲打开，或用 K 穿透护盾，解锁后按 E 提交。
4. **BUILD · 最后一次打包**：击败“打包失败”首领，低血量时它会加快弹幕。

咖啡恢复 2 格生命和 30 能量。每次修复工具都会补满状态并保存本局检查点；死亡保留已修复的工具和已清理的故障。检查点只在本局有效，最快通关时间保存在 Godot 用户数据目录。

“来了”“救命”“哦豁，完蛋”“坏啦”“怀不上了”会由对应的出场、受伤、倒下及打包事件触发。AngelScript 使用正式拼写。

## 美术与声音

主视觉、场景背景、主角姿态与连续动作、四类怪物和战斗特效均使用内置 imagegen 生成，素材保存在 `assets/`。角色采用 16 帧跑步循环、16 帧挥刀序列；怪物各有待机、蓄力、攻击、受伤四帧。图集在运行时按透明通道识别可见边界、对齐脚底；玩家与怪物由真实的物理碰撞控制。

音效和五声音阶芯片音乐由 GDScript 合成。字体使用 OFL 授权的 Noto Sans SC 和 Press Start 2P，授权文件附在 `assets/fonts/`。

这是可玩的四幕原型，内容以一轮完整的救场流程为范围。动作图集由 AI 生成，后续正式制作仍适合逐帧精修轮廓、刀轨和装备一致性。

## 验证

```powershell
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script tools/test_game.gd -- --no-music
```

集成检查覆盖移动、二段跳、实际命中、冲刺无敌、P4 护盾、三个终端与关卡门、坠落恢复、死亡检查点、首领弹幕、通关、记录读写及重新开局。

```powershell
.\.tools\godot\Godot_v4.5.2-stable_win64_console.exe --path . --audio-driver Dummy --fixed-fps 60 --script tools/render_preview.gd -- --no-music
```

使用实际 Godot 渲染器生成 `output/previews/` 下的界面与关卡截图。`tools/bootstrap.py` 可重新下载官方运行时与字体；不会安装到系统目录。

## 重新打包 Windows 版

```powershell
python tools/build_windows.py
```

使用官方 Godot 4.5.2 Windows x64 release 模板和 `export_presets.cfg`，将 PCK 嵌入 `build/windows/毅川救我.exe`。首次运行仅下载所需的 Windows 模板并校验 ZIP 成员 CRC，不下载整个多平台模板包。导出不包含开发工具、预览截图与旧版跑步素材；发布文件通过 GitHub Releases 提供。
