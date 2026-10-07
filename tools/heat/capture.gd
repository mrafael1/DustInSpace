extends SceneTree
## Native-size aim/readability captures of Leo's heat. Run without --headless (the viewport needs a
## renderer). -- --map=leo_haunch (default) or another heat stage's StarMap id.

const MainScene := preload("res://game/scenes/main.tscn")

var _map: String = "leo_haunch"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
	_capture.call_deferred()


func _capture() -> void:
	var main: Main = MainScene.instantiate()
	main.star_map = _map
	main.in_chapter = true
	main.seed_override = 7
	root.add_child(main)
	# The busiest aim: a dozen loose stars, half in the heat, two bigs there about to burn, a small
	# pair ripening by the leg and a few stars out of the heat that stay as they are.
	var board: Array[Array] = [
		[Star.Size.SMALL, Vector2i(104, 120)], [Star.Size.SMALL, Vector2i(72, 140)],
		[Star.Size.MEDIUM, Vector2i(110, 176)], [Star.Size.BIG, Vector2i(64, 196)],
		[Star.Size.BIG, Vector2i(112, 228)], [Star.Size.MEDIUM, Vector2i(84, 100)],
		[Star.Size.SMALL, Vector2i(160, 124)], [Star.Size.BIG, Vector2i(162, 176)],
		[Star.Size.MEDIUM, Vector2i(140, 214)], [Star.Size.SMALL, Vector2i(30, 120)],
		[Star.Size.MEDIUM, Vector2i(34, 170)], [Star.Size.SMALL, Vector2i(30, 222)],
	]
	for entry: Array in board:
		main.run.add_star(entry[0], entry[1] + main.run.scorpio.shift)
	(main.get_node("Sky") as SkyView).setup(main.run, main.get_node("EventSequencer") as EventSequencer)
	(main.get_node("Telescope") as Telescope).request_aim()
	for i: int in 4:
		await process_frame
	await _save("aim")
	(main.get_node("Telescope") as Telescope).cancel_aim()
	for i: int in 4:
		await process_frame
	await _save("idle")
	main.queue_free()
	await process_frame
	quit()


func _save(state: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/heat/out"))
	var frame: Image = root.get_texture().get_image()
	var destination: String = "res://tools/heat/out/%s-%s-%dx%d.png" % [_map, state, frame.get_width(), frame.get_height()]
	frame.save_png(destination)
	print("Captured ", destination)
