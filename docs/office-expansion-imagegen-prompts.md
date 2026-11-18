# 道具图集生成提示词

两张图集均由内置 imagegen 生成，使用透明背景。每张 5 列 × 5 行，按道具表顺序切出独立 PNG。游戏读取 `assets/generated/dungeon/icons/` 下以道具 ID 命名的 PNG。

## 工位、会议和项目流程

源图位于 `assets/generated/dungeon/office-items-meeting.png`。

```text
Use case: game-asset. Create one square production sprite atlas with exactly 25 DIFFERENT inventory icons, arranged on a fixed 5-column by 5-row grid in the order below, left to right. Each cell is equal size and contains exactly one centered object or very tight group, wholly inside the middle 68% of that cell. Keep generous genuinely transparent gutters along every grid line and around the outer bounds. Actual RGBA transparency, no checkerboard, background, frames, inset tiles, labels, glyphs or text. Use the full square and center each icon at the respective regular 10%, 30%, 50%, 70%, 90% positions on both axes. Style: hand-crafted richly shaded pixel art for a Chinese office roguelite, readable at 36 pixels, chunky deliberate pixels, warm light from top left, dark blue-gray stepped outlines, sparse saturated accents, mostly three-quarter top-down views. Clean silhouettes, no shadows floating outside the cutout. No extra objects beyond the requested cell subjects.
Subject: workplace bureaucracy, meetings and office survival. Each row below is one full row of the image, with five separate cell subjects.
Row 1: navy messenger envelope with two mint checkmarks | blue video camera with a small orange chain link | gray tabletop microphone with a red mute slash | nested teal and yellow monitors with a small arrow | royal blue meeting chair reserved with a rust jacket draped across it
Row 2: parchment clipboard with large orange change arrows | scarlet emergency desk beacon | bright magenta return boomerang | emerald chat bubble containing short golden waveform | white side-view toilet with one gold coin carefully beside the cistern
Row 3: ivory rolled certificate tied in a scarlet seal | empty steel chair entirely encased in a cyan ice cube | square lilac leave calendar with one crescent sticker | fan of three pale-green payslips with a small copper coin | squat gold hourglass with magenta sand
Row 4: teal network dongle with a short unplugged lead | old open purple laptop with silver repair tape on its lid | ochre self-heating back patch peeled from a white square wrapper | low blue folding camp cot and one cream pillow | forest-green articulating desk lamp with cream lamp shade
Row 5: large coral drafting pencil lying on a small dark-blue blueprint corner | teal storage archive box with open lid and manila folders | navy blue floppy disk with a fluorescent green rescue cross | amber illuminated desktop button with a backward curving arrow icon | stack of three purple file folders sticking out at three different angles
```

## 通勤和日常生活

源图位于 `assets/generated/dungeon/office-items-after-hours.png`。

```text
Use case: game-asset. Create one square production sprite atlas with exactly 25 DIFFERENT inventory icons, arranged on a fixed 5-column by 5-row grid in the order below, left to right. Each cell is equal size and contains exactly one centered object or very tight group, wholly inside the middle 68% of that cell. Keep generous genuinely transparent gutters along every grid line and around the outer bounds. Actual RGBA transparency, no checkerboard, background, frames, inset tiles, labels, glyphs or text. Use the full square and center each icon at the respective regular 10%, 30%, 50%, 70%, 90% positions on both axes. Style: hand-crafted richly shaded pixel art for a Chinese office roguelite, readable at 36 pixels, chunky deliberate pixels, warm light from top left, dark blue-gray stepped outlines, sparse saturated accents, mostly three-quarter top-down views. Clean silhouettes, no shadows floating outside the cutout. No extra objects beyond the requested cell subjects.
Subject: commute and small daily comforts after work. Each row below is one full row of the image, with five separate cell subjects.
Row 1: gray triangular subway grab handle with bright orange strap | small torn pale blue late-arrival waiver ticket with a red checkmark stamp | pale mint rectangular apartment access fob on a brass key ring | folded orange umbrella sitting diagonally in a small silver wire bike basket | dark jade electric-scooter half helmet with white stripe
Row 2: blue smartphone with a tiny bus pictogram and amber ringing bell | knitted teal winter scarf with bold tassels | black electric-scooter battery showing one red bar | takeaway paper cup of hot soy milk with cream lid and three soybeans at its foot | bright chartreuse rain cover tightly wrapped around a dark backpack
Row 3: black convenience-store oden bowl with three recognizable skewers | folded golden egg street crepe in a kraft sleeve | stacked pastel green bento lunch box with one dark elastic strap | red instant noodle cup with lifted foil lid and chopsticks | boxy orange insulated food-delivery bag with gray handles
Row 4: violet padded sleep mask with little warm yellow stars | seafoam slotted cat litter scoop with a short handle | two navy and cream wet socks pegged together with a droplet | cobalt blue laundry detergent jug with an orange discount sticker | cream envelope and curled rose-colored rental renewal bill with small house pictogram
Row 5: rolled plum floor exercise mat with strap | small hinged terracotta sewing tin with teal thread and a needle nestled inside | split roasted sweet potato with russet skin and bright orange flesh | curved silver showerhead with a short arc of large blue droplets | half a round watermelon with bright coral cut face and striped green rind
```
