# 关卡场景美术

使用内置 imagegen 生成。以下 12 张原始 PNG 已复制进项目，由当前事件 kind 选择，配合独立材质、前景装饰和天气。

- `assets/art/environments/ugs.png` — UGS synchronization rail depot, frost blue steel railway gantries, cable bridges and distant mirrored data trains, cold snow at night
- `assets/art/environments/ddc.png` — DDC cache archive, enormous warm amber library of data drawers, dusty gold storage towers and orderly shelves, soft hanging lamps
- `assets/art/environments/shader.png` — Shader compiler crystal foundry, immense violet prismatic crystals, luminous geometric furnaces and obsidian columns, magenta sparks
- `assets/art/environments/script.png` — AngelScript floating script monastery, ruined purple stone pagodas and floating parchment panels, moonlit bridges over mist
- `assets/art/environments/live.png` — Live Coding hot reload forge, red orange molten metal factory, dragon shaped cranes, smoke stacks and chain hoists
- `assets/art/environments/gc.png` — GC overgrown reclamation forest, moss green ancient server ruins with roots and enormous machine trees, drifting fireflies
- `assets/art/environments/p4.png` — Perforce version control fortress, cyan blue iron prison gate towers, monumental chains, cold rain and armored ramparts
- `assets/art/environments/leak.png` — Memory leak wetland, toxic emerald flooded server tombs, viscous pools and dead crooked trees, green low fog
- `assets/art/environments/net.png` — Network latency port, electric blue stormy ocean harbor with radar towers and suspended antenna bridges, rain and distant lightning
- `assets/art/environments/nanite.png` — Nanite assembly quarry, pale turquoise canyon of immense fragmented angular stone cubes, floating triangles and suspended geometric ruins
- `assets/art/environments/lumen.png` — Lumen reflection city, warm ivory gold cathedral of mirrors, tall glass arches and luminous lantern moth sculptures, reflective towers at dawn
- `assets/art/environments/boss.png` — BUILD final server citadel, crimson dusk above an enormous black Japanese cyber castle, red warning beacons and a huge eclipse behind the tower

## 完整提示词模板

将 `{SCENE}` 替换为上方对应场景描述；所有调用 `transparent_background=false`，未使用参考图。

```
Use case: stylized-concept. Asset type: production background art for a side-scrolling pixel-art Godot game featuring a shiba samurai developer. Create ONE wide landscape background only, ideally 1536x1024. Scene: {SCENE}. Style: carefully drawn 16-bit pixel art, crisp square pixel clusters, limited harmonious palette, Japanese cyber fantasy, detailed scenery at distance. Composition: completely side-on horizontal view, layered distant environment, open calm lower half behind playable characters, architecture mostly upper/middle distance; horizon at 65 percent image height. No walkable foreground platform, no floor strip, no characters, no monsters, no HUD, no text, no lettering, no logo, no watermark. Every pixel is opaque. Atmospheric but clear silhouettes. Must look like real cohesive game background art, not a poster or illustration in perspective.
```
