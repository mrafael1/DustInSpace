extends SceneTree
## Native-size aim/readability captures. Run without --headless (the viewport needs a renderer).

const MainScene := preload("res://game/scenes/main.tscn")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var main: Main = MainScene.instantiate()
	main.current_trial = true
	main.seed_override = 7
	root.add_child(main)
	# Crowded board, including a saved small link and a stranded big link.
	var points: Array[Vector2i] = [Vector2i(118, 132), Vector2i(108, 154), Vector2i(162, 216), Vector2i(162, 192), Vector2i(45, 110), Vector2i(68, 100), Vector2i(96, 98), Vector2i(38, 146), Vector2i(58, 174), Vector2i(30, 202), Vector2i(70, 204), Vector2i(142, 230)]
	for i: int in points.size():
		main.run.add_star((Star.Size.SMALL if i < 2 else Star.Size.BIG if i < 4 else i % 3) as Star.Size, points[i] + main.run.scorpio.shift)
	(main.get_node("Sky") as SkyView).setup(main.run, main.get_node("EventSequencer") as EventSequencer)
	(main.get_node("Telescope") as Telescope).request_aim()
	await process_frame
	await _save("aim")
	(main.get_node("Telescope") as Telescope).cancel_aim()
	var sky: SkyView = main.get_node("Sky")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(points[0] + main.run.scorpio.shift)
	sky.handle_pointer(touch)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(points[1] + main.run.scorpio.shift)
	sky.handle_pointer(drag)
	await process_frame
	await _save("trace")
	main.queue_free()
	await process_frame
	quit()


func _save(state: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/currents/out"))
	var frame: Image = root.get_texture().get_image()
	var destination: String = "res://tools/currents/out/%s-%dx%d.png" % [state, frame.get_width(), frame.get_height()]
	frame.save_png(destination)
	print("Captured ", destination)
