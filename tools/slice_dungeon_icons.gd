extends SceneTree
## Preserve imagegen pixels and alpha; export one icon per catalog identity.
const Data = preload("res://scripts/dungeon_data.gd")

func gutters(source: Image, count: int, horizontal: bool) -> Array[int]:
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
		for candidate in range(nominal - margin, nominal + margin + 1):
			if scores[candidate] < scores[best] or scores[candidate] == scores[best] and absi(candidate - nominal) < absi(best - nominal):
				best = candidate
		result.append(best)
	result.append(length)
	return result

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/generated/dungeon/icons")
	var sheets: Array[Dictionary] = [
		{"path":"res://assets/generated/dungeon/office-items-v2.png", "columns":7, "rows":6, "items":Data.EQUIPMENT},
		{"path":"res://assets/generated/dungeon/office-weapons-v2.png", "columns":4, "rows":3, "items":Data.WEAPONS.slice(6)}
	]
	var total: int = 0
	for sheet in sheets:
		var source: Image = Image.load_from_file(ProjectSettings.globalize_path(sheet.path))
		assert(source != null and source.get_pixel(0, 0).a < 0.01, "Source sheet must retain transparency")
		print("SOURCE ", sheet.path, " ", source.get_size())
		# Generated sheets can trim outer padding; find actual transparent gutters.
		var xs: Array[int] = gutters(source, sheet.columns, true)
		var ys: Array[int] = gutters(source, sheet.rows, false)
		print("GUTTERS ", xs, " / ", ys)
		for index in range(sheet.items.size()):
			if sheet.items[index].id == "twins":
				continue # Revolver artwork is generated separately from the original atlas.
			var column: int = index % sheet.columns
			var row: int = index / sheet.columns
			var left: int = xs[column]
			var top: int = ys[row]
			var right: int = xs[column + 1]
			var bottom: int = ys[row + 1]
			var icon: Image = source.get_region(Rect2i(left, top, right - left, bottom - top))
			assert(not icon.is_invisible(), "Each catalog item needs visible artwork")
			assert(icon.save_png("res://assets/generated/dungeon/icons/%s.png" % sheet.items[index].id) == OK)
			total += 1
	print("EXPORTED ", total, " independent imagegen icons")
	quit()
