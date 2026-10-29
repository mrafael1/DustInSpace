extends SceneTree
## Records real, seeded gameplay through the existing presentation and pointer handlers.
## godot --path . --windowed --resolution 540x960 --fixed-fps 30 \
##   --write-movie output/media/lossless/gameplay.png --script tools/media/capture_ad.gd
## Use PNG/WAV output: JPEG movie frames introduce artifacts before HD composition.

const MAIN_SCENE: PackedScene = preload("res://game/scenes/main.tscn")
const FPS: int = 30
const LENGTH: int = 32

var _main: Main
var _frames: int = 0
var _launches: int = 0
var _map: String = "scorpio"
var _length: int = LENGTH
var _mode: String = "gameplay"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--length="):
			_length = argument.trim_prefix("--length=").to_int()
		elif argument.begins_with("--mode="):
			_mode = argument.trim_prefix("--mode=")
	_record.call_deferred()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= _length * FPS:
		quit()
	return false


func _record() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(540, 960)
	if _mode == "title" or _mode == "painting":
		await _record_chart()
		return
	_main = MAIN_SCENE.instantiate() as Main
	_main.seed_override = 7
	_main.star_map = _map
	_main.in_chapter = true
	root.add_child(_main)
	await _wait(0.6)
	while _frames < _length * FPS and not _main.run.is_over():
		await _settle()
		var links: Array[Array] = _main.run.valid_links()
		if not links.is_empty():
			await _trace(_best_link(links))
		else:
			await _launch()
	await _wait(4.0)
	quit()


func _record_chart() -> void:
	var chart: ChapterSelect = preload("res://game/scenes/chapter_select.tscn").instantiate() as ChapterSelect
	root.add_child(chart)
	var chapter := Chapter.new(ChapterDef.scorpio())
	if _mode == "painting":
		# The existing chart's completion preview, on an unsaved in-memory chapter.
		for stage: int in Chapter.stage_count():
			chapter.complete(stage)
	chart.setup(chapter)
	if _mode == "title":
		chart.show_title()
	else:
		await _wait(0.35)
		chart.show_progress(Chapter.FINAL, -1)
	await _wait(float(_length))


func _wait(seconds: float) -> void:
	for frame: int in maxi(1, int(seconds * FPS)):
		await process_frame


func _settle() -> void:
	var sequencer: EventSequencer = _main.get_node("EventSequencer") as EventSequencer
	await _wait(0.15)
	while sequencer.is_busy():
		await process_frame
	await _wait(0.25)


func _best_link(links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var score: int = -1
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var value: int = _main.run.link_dust(_main.run.combo_for(ids))
		for id: int in ids:
			if _main.run.scorpio.is_landmark(id):
				value += 100
		if value > score:
			score = value
			best = ids
	return best


func _position(id: int) -> Vector2i:
	if _main.run.scorpio.is_landmark(id):
		for star: Star in _main.run.scorpio.unlit_stars():
			if star.id == id:
				return star.position
	return _main.run.find_star(id).position


func _trace(ids: Array[int]) -> void:
	var telescope: Telescope = _main.get_node("Telescope") as Telescope
	telescope.cancel_aim()
	var sky: SkyView = _main.get_node("Sky") as SkyView
	var orders: Array[Array] = _main.run.traceable_orders(ids)
	if orders.is_empty():
		return
	ids.assign(orders[0])
	# Tap selection is also a supported player gesture. It avoids incidental stars
	# intersecting a scripted swipe through a densely packed launch.
	sky.drop_press()
	for id: int in ids:
		var point: Vector2i = _position(id)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = Vector2(point)
		sky.handle_pointer(touch)
		await _wait(0.18)
		touch = InputEventScreenTouch.new()
		touch.pressed = false
		touch.position = Vector2(point)
		sky.handle_pointer(touch)
		await _wait(0.28)
	print("AD link at ", float(_frames) / FPS, "s: ", ids)
	await _settle()


func _launch() -> void:
	var run: RunState = _main.run
	if run.total_packs() == 0:
		var kind: String = "red" if run.can_afford("red") else "blue"
		if not run.buy(kind):
			return
		await _wait(0.65)
	if run.loaded_pack == "":
		for kind: String in ["red", "blue"]:
			if run.load_pack(kind):
				break
	var target := Vector2i(92, 166)
	var unlit: Array[Star] = run.scorpio.unlit_stars()
	if not unlit.is_empty():
		target = unlit[mini(_launches / 2, unlit.size() - 1)].position
		target.x = clampi(target.x, 35, 145)
		target.y = clampi(target.y, 105, 220)
	var telescope: Telescope = _main.get_node("Telescope") as Telescope
	telescope.request_aim()
	await _wait(0.45)
	telescope.aim_at(target)
	await _wait(0.4)
	var touch := InputEventScreenTouch.new()
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.position = Vector2(target - telescope.origin())
	touch.pressed = true
	telescope.handle_pointer(touch)
	await _wait(0.15)
	touch = InputEventScreenTouch.new()
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.position = Vector2(target - telescope.origin())
	touch.pressed = false
	telescope.handle_pointer(touch)
	_launches += 1
	print("AD launch at ", float(_frames) / FPS, "s: ", target)
	await _settle()
