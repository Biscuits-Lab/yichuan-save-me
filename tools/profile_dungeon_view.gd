extends "res://scripts/dungeon_view.gd"
## Measures redraw work and can reproduce the old per-frame floor painting for A/B profiling.
var repaint_geometry: bool = false
var draw_usec: int = 0
var draw_count: int = 0

func _draw() -> void:
	var start: int = Time.get_ticks_usec()
	super._draw()
	draw_usec = Time.get_ticks_usec() - start
	draw_count += 1

func arena() -> void:
	if repaint_geometry:
		for hall in game.corridors:
			if visible_world.intersects(hall.rect.grow(40)):
				draw_corridor_geometry(hall)
		for room in game.rooms:
			if visible_world.intersects(room.rect.grow(140)):
				draw_room_geometry(room)
	super.arena()
