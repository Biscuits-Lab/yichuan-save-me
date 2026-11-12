class_name SpriteAtlas
extends RefCounted

var texture: Texture2D
var frames: Array[Dictionary] = []
var row_heights: Array[float] = []
var columns: int
var rows: int

func _init(source: Texture2D, cols: int, row_count: int, align_head: bool = false) -> void:
	texture = source
	columns = cols
	rows = row_count
	var image: Image = texture.get_image()
	var cell := Vector2i(image.get_width() / cols, image.get_height() / row_count)
	# Runtime atlas slicing: ignore low-alpha glow when finding the body bounds.
	# Every frame retains the source pixels; no generated image is rewritten.
	for row in range(row_count):
		var heights: Array[float] = []
		for col in range(cols):
			var offset := Vector2i(col * cell.x, row * cell.y)
			var min_p := cell
			var max_p := Vector2i.ZERO
			var head_x: float = cell.x * 0.5
			var largest_orange_row: int = 0
			for y in range(0, cell.y, 2):
				var orange_count: int = 0
				var orange_x: float = 0
				for x in range(0, cell.x, 2):
					var pixel: Color = image.get_pixel(offset.x + x, offset.y + y)
					if pixel.a > 0.66:
						min_p.x = mini(min_p.x, x)
						min_p.y = mini(min_p.y, y)
						max_p.x = maxi(max_p.x, x)
						max_p.y = maxi(max_p.y, y)
						if align_head and y < cell.y * 0.65 and pixel.r > 0.5 and pixel.r > pixel.g * 1.12 and pixel.g > pixel.b * 1.4:
							orange_count += 1
							orange_x += x
				if orange_count > largest_orange_row:
					largest_orange_row = orange_count
					head_x = orange_x / orange_count
			if min_p.x > max_p.x:
				min_p = Vector2i.ZERO
				max_p = cell - Vector2i.ONE
			var height: float = maxf(1, max_p.y - min_p.y)
			heights.append(height)
			var anchor := Vector2(head_x if align_head else (min_p.x + max_p.x) * 0.5, max_p.y)
			frames.append({"region": Rect2(Vector2(offset), Vector2(cell)), "anchor": anchor, "height": height, "bounds": Rect2(Vector2(min_p), Vector2(max_p - min_p))})
		heights.sort()
		row_heights.append(heights[heights.size() / 2])
	if align_head:
		var common_heights: Array[float] = row_heights.duplicate()
		common_heights.sort()
		row_heights.fill(common_heights[common_heights.size() / 2])
		if row_count == 4:
			# A run/attack atlas is one animation, not four different characters.
			# Lock its root to a single baseline instead of chasing each frame's head.
			var xs: Array[float] = []
			var ys: Array[float] = []
			for frame in frames:
				xs.append(frame.anchor.x)
				ys.append(frame.anchor.y)
			xs.sort()
			ys.sort()
			for frame in frames:
				frame.anchor = Vector2(xs[xs.size() / 2], ys[ys.size() / 2])

func draw(canvas: CanvasItem, index: int, point: Vector2, height: float, facing: float = 1, tint: Color = Color.WHITE, center_anchor: bool = false) -> void:
	if frames.is_empty():
		return
	index = clampi(index, 0, frames.size() - 1)
	var frame: Dictionary = frames[index]
	var scale: float = height / row_heights[index / columns]
	var anchor: Vector2 = frame.anchor
	if center_anchor:
		anchor = frame.bounds.get_center()
	canvas.draw_set_transform(point, 0, Vector2(facing * scale, scale))
	canvas.draw_texture_rect_region(texture, Rect2(-anchor, frame.region.size), frame.region, tint)
	canvas.draw_set_transform(Vector2.ZERO)
