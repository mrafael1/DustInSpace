extends SceneTree
## Paired seeded runs through the spatial core. Bots are deliberately simple; this is
## pressure evidence, not a prediction of human difficulty or a chapter tuning target.

var _balance: Balance
var _runs: int = 200
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
	_balance = Balance.load_file()
	_simulate.call_deferred()


func _simulate() -> void:
	print("Paired seeds 1..%d; Tail geometry; NO Orion; reach %d" % [_runs, _balance.scorpio_max_link_distance])
	for launch_first: bool in [false, true]:
		for enabled: bool in [false, true]:
			var row: Dictionary = {"policy": "launch-owned-first" if launch_first else "link-first", "current": enabled, "runs": _runs, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "launches": 0, "moving_launches": 0, "probe_boards": 0, "boards_losing_links": 0, "boards_gaining_links": 0, "boards_with_both": 0, "runs_with_both": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, launch_first, row)
				if seed_value % 20 == 0:
					await process_frame
			_rows.append(row)
			print(JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/currents/out"))
	var file: FileAccess = FileAccess.open("res://tools/currents/out/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_rows, "  ") + "\n")
	quit()


func _play(seed_value: int, enabled: bool, launch_first: bool, row: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, StarMap.current_trial(enabled))
	var packs: int = 0
	var had_conflict: bool = false
	for action: int in 200:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		if not links.is_empty() and not (launch_first and run.total_packs() > 0):
			run.link(_best_link(run, links))
			continue
		if run.total_packs() == 0:
			var kind: String = "red" if run.can_afford("red") else "blue"
			if not run.buy(kind):
				break
		if run.loaded_pack == "":
			for kind: String in ["red", "blue"]:
				if run.load_pack(kind):
					break
		if enabled:
			var probe: Vector2i = _probe(run)
			row.probe_boards += 1
			row.boards_losing_links += int(probe.x > 0)
			row.boards_gaining_links += int(probe.y > 0)
			row.boards_with_both += int(probe.x > 0 and probe.y > 0)
			had_conflict = had_conflict or (probe.x > 0 and probe.y > 0)
			var preview: Dictionary[int, Vector2i] = run.current_preview()
			for star: Star in run.stars:
				if star.position != preview[star.id]:
					row.moving_launches += 1
					break
		var target := Vector2i(90, 160)
		for index: int in run.scorpio.map.count():
			if not run.scorpio.is_lit(index):
				target = run.scorpio.landmark_position(index) + Vector2i(-12, -18)
				break
		if not run.launch(target):
			break
		packs += 1
		row.launches += 1
	row.runs_with_both += int(had_conflict)
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


func _best_link(run: RunState, links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var combo: String = run.combo_for(ids)
		var score: int = run.balance.combos[combo].dust + run.balance.combos[combo].light
		for id: int in ids:
			if run.scorpio.is_landmark(id):
				score += 100
		if score > best_score:
			best = ids
			best_score = score
	return best


## Isolate only the movement of the board already visible, without a new pack.
## Canonical link sets avoid counting the same combination in different orders.
func _probe(run: RunState) -> Vector2i:
	var before: Dictionary[String, bool] = _landmark_links(run)
	var original: Dictionary[int, Vector2i] = {}
	var preview: Dictionary[int, Vector2i] = run.current_preview()
	for star: Star in run.stars:
		original[star.id] = star.position
		star.position = preview[star.id]
	var after: Dictionary[String, bool] = _landmark_links(run)
	for star: Star in run.stars:
		star.position = original[star.id]
	var result := Vector2i.ZERO
	for key: String in before:
		result.x += int(not after.has(key))
	for key: String in after:
		result.y += int(not before.has(key))
	return result


func _landmark_links(run: RunState) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for ids: Array in run.valid_links():
		ids.sort()
		if ids[0] < 0:
			result[str(ids)] = true
	return result
