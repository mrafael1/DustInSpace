extends SceneTree
## Exports a reference sheet of the Sun's key states to docs/concept/sun_states.png, rendered
## from SunView.pixels, so it always matches the game. The Sun stays drawn in code (sun.gd):
## its look combines 35 fill rows, 12 rays, the pulse, the smoulder, the ignition and the
## ignited idle, too many states for hand-edited sprite frames. This sheet is the starting
## point for a hand pass.
## Frames, left to right: 0% (smoulder ticks 0 and 1), 25%, 50%, 50% pulse, 75%, 99%,
## ignited (idle ticks 0 and 1), ignited pulse.
##
## Run: godot --headless --path . -s tools/art/export_sun_reference.gd

const OUT := "res://docs/concept/sun_states.png"
const CELL: int = 2 * (SunView.RADIUS + 22) + 1


func _init() -> void:
	var states: Array = [
		[0.0, false, false, 0], [0.0, false, false, 1], [0.25, false, false, 0], [0.5, false, false, 0],
		[0.5, false, true, 0], [0.75, false, false, 0], [0.99, false, false, 0],
		[1.0, true, false, 0], [1.0, true, false, 1], [1.0, true, true, 0],
	]
	var image := Image.create_empty(CELL * states.size(), CELL, false, Image.FORMAT_RGBA8)
	for i: int in states.size():
		var s: Array = states[i]
		var rows: int = floori(s[0] * SunView.DISC_ROWS)
		var rays: int = floori(s[0] * SunView.RAYS)
		var dots: Dictionary[Vector2i, Color] = SunView.pixels(rows, rays, s[1], s[2], s[3])
		for offset: Vector2i in dots:
			image.set_pixelv(Vector2i(CELL * i + CELL / 2, CELL / 2) + offset, dots[offset])
	image.save_png(OUT)
	print("wrote %s (%dx%d, %d states)" % [OUT, image.get_width(), image.get_height(), states.size()])
	quit()
