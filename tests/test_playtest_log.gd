extends GutTest
## The playtest log (#89): debug builds record tutorial steps, refusals, idle gaps and the run's
## outcome, one JSON object a line, for tools/playtest/summary.py. Nothing in release builds, and
## no files left behind here.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const DIR: String = "user://test_playtest"

var log: PlaytestLog
var run: RunState


func before_each() -> void:
	PlaytestLog.new_session()
	log = PlaytestLog.new()
	log.enabled = true
	log.log_dir = DIR
	add_child_autofree(log)
	log.set_process(false)
	run = Fixtures.run()


func after_each() -> void:
	# Freeing it would log the run as left.
	if is_instance_valid(log):
		log.enabled = false
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)
	DirAccess.remove_absolute(DIR)
	PlaytestLog.new_session()


func test_a_run_leaves_one_readable_record_a_line() -> void:
	log.setup(run, null)
	run.tutorial_step.emit(Tutorial.Step.GOAL)
	log.advance(3.0)
	run.tutorial_step.emit(Tutorial.Step.LAUNCH)
	log.advance(1.5)
	log.refused("launch")
	log.advance(2.5)
	log.touched()
	run.pack_launched.emit("blue", Vector2i(90, 150))
	run.link_rejected.emit([1, 2, 3] as Array[int])
	log.advance(1.0)
	run.tutorial_step.emit(Tutorial.Step.DONE)
	run.run_won.emit()
	var records: Array[Dictionary] = _records()
	var types: Array[String] = []
	for record: Dictionary in records:
		types.append(record["type"])
	assert_eq(types, ["run_started", "step_entered", "step_left", "step_entered", "refusal", "idle", "refusal", "step_left", "run_ended"] as Array[String])
	assert_eq(records[0]["stage"], "sun")
	assert_eq(records[2]["step"], "GOAL")
	assert_almost_eq(float(records[2]["seconds"]), 3.0, 0.01, "time spent on the step")
	assert_eq(records[4]["kind"], "launch")
	assert_eq(records[4]["step"], "LAUNCH", "on which step")
	assert_almost_eq(float(records[5]["seconds"]), 7.0, 0.01, "the gap since the run started")
	assert_eq(records[6]["kind"], "link", "a rejected link")
	assert_eq(records[7]["step"], "LAUNCH")
	assert_almost_eq(float(records[7]["seconds"]), 5.0, 0.01)
	assert_eq(records[8]["outcome"], "won")
	assert_eq(records[8]["packs_used"], 1)
	assert_almost_eq(float(records[8]["seconds"]), 8.0, 0.01)


func test_short_gaps_arent_idle() -> void:
	log.setup(run, null)
	log.advance(PlaytestLog.IDLE_MIN - 0.1)
	log.touched()
	log.advance(PlaytestLog.IDLE_MIN - 0.1)
	log.touched()
	for record: Dictionary in _records():
		assert_ne(record["type"], "idle")


func test_a_long_hold_or_drag_isnt_idle() -> void:
	log.setup(run, null)
	log.touched()
	for i: int in 5:
		log.advance(1.0)
		log.dragged()
	log.released()
	log.touched()
	log.released()
	log.touched()
	log.advance(6.0)
	log.released()
	log.touched()
	for record: Dictionary in _records():
		assert_ne(record["type"], "idle", "aiming, tracing and holding are interaction")


func test_the_gap_starts_when_the_last_finger_lifts() -> void:
	log.setup(run, null)
	log.touched()
	log.advance(4.0)
	log.released()
	log.advance(3.0)
	log.touched()
	var idles: Array[float] = []
	for record: Dictionary in _records():
		if record["type"] == "idle":
			idles.append(float(record["seconds"]))
	assert_eq(idles.size(), 1)
	assert_almost_eq(idles[0], 3.0, 0.01, "from the release, not from the press")


func test_main_hears_drags_and_releases_through_the_idle_hint() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var main_log: PlaytestLog = main.get_node("PlaytestLog")
	main_log.enabled = true
	main_log.log_dir = DIR
	main_log.set_process(false)
	var hint: IdleHint = main.get_node("IdleHint")
	var press := InputEventScreenTouch.new()
	press.pressed = true
	hint.observe(press)
	for i: int in 5:
		main_log.advance(1.0)
		hint.observe(InputEventScreenDrag.new())
	var lift := InputEventScreenTouch.new()
	hint.observe(lift)
	main_log.advance(3.0)
	hint.observe(press)
	var idles: Array[float] = []
	for record: Dictionary in _records():
		if record["type"] == "idle":
			idles.append(float(record["seconds"]))
	assert_eq(idles.size(), 1, "a five-second drag is no stall; the gap after it is")
	assert_almost_eq(idles[0], 3.0, 0.01)
	main_log.enabled = false


func test_planet_taps_are_loads_or_buys() -> void:
	log.setup(run, null)
	log.pack_tap_refused("red", &"icon")
	log.pack_tap_refused("red", &"cost")
	var kinds: Array[String] = []
	for record: Dictionary in _records():
		if record["type"] == "refusal":
			kinds.append(record["kind"])
	assert_eq(kinds, ["load", "buy"] as Array[String])


func test_a_lost_run_ends_once_and_nothing_follows() -> void:
	log.setup(run, null)
	run.run_lost.emit()
	run.run_lost.emit()
	log.refused("buy")
	var ended: int = 0
	for record: Dictionary in _records():
		ended += int(record["type"] == "run_ended")
		assert_ne(record["type"], "refusal", "nothing after the end")
	assert_eq(ended, 1)


func test_every_run_in_a_session_shares_one_file() -> void:
	log.setup(run, null)
	var first: String = PlaytestLog.session_file()
	log.setup(Fixtures.run({}, 2), null)
	assert_eq(PlaytestLog.session_file(), first)
	assert_eq(DirAccess.get_files_at(DIR).size(), 1)
	var types: Array[String] = []
	for record: Dictionary in _records():
		types.append(record["type"] + ":" + str(record.get("outcome", "")))
	assert_eq(types, ["run_started:", "run_ended:left", "run_started:"] as Array[String], "a restart leaves the first run")


func test_release_builds_write_nothing() -> void:
	log.enabled = false
	log.setup(run, null)
	log.refused("link")
	run.run_won.emit()
	assert_false(DirAccess.dir_exists_absolute(DIR), "no folder, no file")


func test_every_record_carries_one_session_id() -> void:
	log.setup(run, null)
	log.refused("link")
	var records: Array[Dictionary] = _records()
	assert_eq(str(records[0]["session"]).length(), 12)
	assert_eq(records[1]["session"], records[0]["session"], "one id a session")
	var first: String = PlaytestLog.session_id()
	PlaytestLog.new_session()
	assert_ne(PlaytestLog.session_id(), first, "a new session, a new id")


func test_records_are_sent_even_where_no_file_is_written() -> void:
	var sent: Array[String] = []
	log.enabled = false
	log.upload = func(text: String) -> void: sent.append(text)
	log.setup(run, null)
	run.run_lost.emit()
	assert_false(DirAccess.dir_exists_absolute(DIR), "a release build writes no file")
	assert_eq(sent.size(), 2)
	var started: Dictionary = JSON.parse_string(sent[0])
	assert_eq(started["type"], "run_started")
	assert_eq(started["platform"], PlaytestLog.platform())
	assert_eq(started["session"], PlaytestLog.session_id())
	assert_eq((JSON.parse_string(sent[1]) as Dictionary)["outcome"], "lost")


func test_links_are_logged_and_counted_at_the_end() -> void:
	log.setup(run, null)
	var stars: Array[Star] = []
	for size: Star.Size in [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG]:
		stars.append(run.add_star(size, Vector2i(90, 150)))
	run.pack_launched.emit("blue", Vector2i(90, 150))
	run.combo_collected.emit("sequence", stars, 3, 25)
	run.combo_collected.emit("small_triple", stars, 3, 5)
	run.link_rejected.emit([1, 2] as Array[int])
	run.big_bang_started.emit(Vector2i(90, 150), [] as Array[Star], 8)
	run.run_won.emit()
	var records: Array[Dictionary] = _records()
	var link: Dictionary = records[1]
	assert_eq(link["type"], "link")
	assert_eq(link["combo"], "sequence")
	assert_eq(link["stars"], 3.0)
	assert_eq(link["light"], 25.0)
	var ended: Dictionary = records[-1]
	assert_eq(ended["outcome"], "won")
	assert_eq(ended["packs_used"], 1.0)
	assert_eq(ended["links"], 2.0)
	assert_eq(ended["stars_linked"], 6.0)
	assert_eq(ended["links_rejected"], 1.0)
	assert_eq(ended["big_bangs"], 1.0)
	assert_eq(ended["dust_earned"], 14.0, "both links and the Big Bang")


func test_the_endpoint_comes_from_the_config_and_none_sends_nothing() -> void:
	assert_eq(AnalyticsUpload.endpoint(), "", "none is committed: nothing is sent")
	assert_eq(AnalyticsUpload.endpoint("res://no/such/file.json"), "")
	var path: String = DIR + "_endpoint.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"endpoint": " https://example.com/exec "}')
	file.close()
	assert_eq(AnalyticsUpload.endpoint(path), "https://example.com/exec")
	DirAccess.remove_absolute(path)
	assert_false(AnalyticsUpload.sender("").is_valid())
	assert_false(AnalyticsUpload.sender("https://example.com/exec").is_valid(), "headless runs never send")


func test_main_hears_the_refusals_and_the_touches() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var main_log: PlaytestLog = main.get_node("PlaytestLog")
	assert_false(main_log.enabled, "headless runs (the tests) write nothing by default")
	main_log.enabled = true
	main_log.log_dir = DIR
	main_log.set_process(false)
	assert_true(main.start_run(Fixtures.balance()))
	main_log.advance(5.0)
	var hint: IdleHint = main.get_node("IdleHint")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	hint.observe(touch)
	(main.get_node("HUD") as Hud).tap_refused.emit("red", &"cost")
	(main.get_node("Telescope") as Telescope).empty_tapped.emit()
	(main.get_node("Sky") as SkyView).step_refused.emit()
	var seen: Array[String] = []
	for record: Dictionary in _records():
		seen.append(record["type"] + ":" + str(record.get("kind", "")))
	assert_eq(seen, ["run_ended:", "run_started:", "idle:", "refusal:buy", "refusal:launch", "refusal:link"] as Array[String], "the run _ready started is left")
	main_log.enabled = false


func test_a_guided_run_says_so_and_leaving_ends_it() -> void:
	log.guided = true
	log.setup(run, null)
	log.advance(2.0)
	log.queue_free()
	await wait_physics_frames(2)
	var records: Array[Dictionary] = _records()
	assert_eq(records[0]["tutorial"], true)
	assert_eq(records[-1]["type"], "run_ended")
	assert_eq(records[-1]["outcome"], "left", "back to the chart")


func _records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var path: String = PlaytestLog.session_file()
	if path == "" or not FileAccess.file_exists(path):
		return records
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		records.append(JSON.parse_string(line))
	return records
