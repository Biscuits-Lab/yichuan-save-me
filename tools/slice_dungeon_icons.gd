extends SceneTree
## Preserve imagegen pixels and alpha; export one icon per catalog identity.
const Data = preload("res://scripts/dungeon_data.gd")

func gutters(source: Image, count: int, horizontal: bool, padding: int = 0) -> Array[int]:
	var length: int = source.get_width() if horizontal else source.get_height()
	var depth: int = source.get_height() if horizontal else source.get_width()
	var scores: Array[int] = []
	for axis in range(length):
		var score: int = 0
		for other in range(depth):
			var pixel: Color = source.get_pixel(axis, other) if horizontal else source.get_pixel(other, axis)
			if pixel.a > 0.15:
				score += 1
		scores.append(score)
	var result: Array[int] = [0]
	for index in range(1, count):
		var nominal: int = roundi(float(index) * length / count)
		var margin: int = roundi(float(length) / count * 0.3)
		var best: int = nominal
		var best_score: int = depth * (2 * padding + 1) + 1
		for candidate in range(nominal - margin, nominal + margin + 1):
			var score: int = 0
			for axis in range(candidate - padding, candidate + padding + 1):
				score += scores[axis]
			if score < best_score or score == best_score and absi(candidate - nominal) < absi(best - nominal):
				best = candidate
				best_score = score
		result.append(best)
	result.append(length)
	return result

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/generated/dungeon/icons")
	var sheets: Array[Dictionary] = [
		{"path":"res://assets/generated/dungeon/office-items-v2.png", "columns":7, "rows":6, "items":Data.EQUIPMENT.slice(0, 39)},
		{"path":"res://assets/generated/dungeon/office-weapons-v2.png", "columns":4, "rows":3, "items":Data.WEAPONS.slice(6, 18)},
		{"path":"res://assets/generated/dungeon/office-items-meeting.png", "columns":5, "rows":5, "items":Data.EQUIPMENT.slice(63, 88), "column_gutters":true},
		{"path":"res://assets/generated/dungeon/office-items-after-hours.png", "columns":5, "rows":5, "items":Data.EQUIPMENT.slice(88, 113), "column_gutters":true}
	]
	if "--office-expansion" in OS.get_cmdline_user_args():
		sheets = sheets.slice(2)
	var total: int = 0
	for sheet in sheets:
		var source: Image = Image.load_from_file(ProjectSettings.globalize_path(sheet.path))
		assert(source != null and source.get_pixel(0, 0).a < 0.01, "Source sheet must retain transparency")
		print("SOURCE ", sheet.path, " ", source.get_size())
		# Generated sheets can trim outer padding; find actual transparent gutters.
		var column_gutters: bool = sheet.get("column_gutters", false)
		var xs: Array[int] = gutters(source, sheet.columns, true, 3 if column_gutters else 0)
		var ys: Array[int] = gutters(source, sheet.rows, false)
		var ys_by_column: Array[Array] = []
		for column in range(sheet.columns):
			if column_gutters:
				var strip: Image = source.get_region(Rect2i(xs[column], 0, xs[column + 1] - xs[column], source.get_height()))
				ys_by_column.append(gutters(strip, sheet.rows, false, 3))
			else:
				ys_by_column.append(ys)
		print("GUTTERS ", xs, " / ", ys_by_column)
		for index in range(sheet.items.size()):
			if sheet.items[index].id == "twins":
				continue # Revolver artwork is generated separately from the original atlas.
			var column: int = index % sheet.columns
			var row: int = index / sheet.columns
			var left: int = xs[column]
			var top: int = ys_by_column[column][row]
			var right: int = xs[column + 1]
			var bottom: int = ys_by_column[column][row + 1]
			var icon: Image = source.get_region(Rect2i(left, top, right - left, bottom - top))
			assert(not icon.is_invisible(), "Each catalog item needs visible artwork")
			assert(icon.save_png("res://assets/generated/dungeon/icons/%s.png" % sheet.items[index].id) == OK)
			total += 1
	print("EXPORTED ", total, " independent imagegen icons")
	quit()
