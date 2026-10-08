extends SceneTree
## Reuse Chapter 1's palette-locked, dithered star field for the AloneLab section.
## Run: godot --headless --path . -s tools/web/export_space_background.gd

func _initialize() -> void:
	var sky: Image = ChapterSelect.space_image(Rect2i(-70, 50, 320, 200))
	var error: Error = sky.save_png("res://web/site/dust_space.png")
	if error != OK:
		push_error("Couldn't export the website star field: %s" % error_string(error))
	quit(error)
