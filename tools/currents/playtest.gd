extends SceneTree
## Paired seeded runs through the spatial core. Bots are deliberately simple; this is
## pressure evidence, not a prediction of human difficulty or a chapter tuning target.
## --map=tail (the first trial) or --map=aquarius (the flow layout); --runs=N; --step=N and
## --reach=N override currents.step and scorpio.max_link_distance for a what-if (balance.json is
## untouched).

const POLICIES: Array[Dictionary] = [
	{"name": "link-first", "launch_first": false, "upstream": false},
	{"name": "link-first-upstream-aim", "launch_first": false, "upstream": true},
	{"name": "launch-owned-first", "launch_first": true, "upstream": false},
]

var _balance: Balance
var _runs: int = 200
var _map: String = "tail"
var _step: int = 0
var _reach: int = 0
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--step="):
			_step = argument.trim_prefix("--step=").to_int()
		elif argument.begins_with("--reach="):
			_reach = argument.trim_prefix("--reach=").to_int()
	_balance = Balance.load_file()
	if _step > 0:
		_balance.current_step = _step
	if _reach > 0:
		_balance.scorpio_max_link_distance = _reach
	_simulate.call_deferred()


func _simulate() -> void:
	print("Paired seeds 1..%d; %s layout; NO Orion; reach %d; step %d" % [_runs, _map, _balance.scorpio_max_link_distance, _balance.current_step])
	for policy: Dictionary in POLICIES:
		for enabled: bool in [false, true]:
			var row: Dictionary = {"map": _map, "step": _balance.current_step, "reach": _balance.scorpio_max_link_distance, "policy": policy.name, "current": enabled, "runs": _runs, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "launches": 0, "moving_launches": 0, "probe_boards": 0, "boards_losing_links": 0, "boards_gaining_links": 0, "boards_with_both": 0, "runs_with_both": 0, "waiting_stars_carried_off": 0, "stars_carried_in": 0, "boards_carrying_off_and_in": 0, "runs_carrying_off_and_in": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			_rows.append(row)
			print(JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/currents/out"))
	var file: FileAccess = FileAccess.open("res://tools/currents/out/results-%s-step%d-reach%d.json" % [_map, _balance.current_step, _balance.scorpio_max_link_distance], FileAccess.WRITE)
	file.store_string(JSON.stringify(_rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	return StarMap.aquarius_flow(enabled) if _map == "aquarius" else StarMap.current_trial(enabled)


func _play(seed_value: int, enabled: bool, policy: Dictionary, row: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	var had_conflict: bool = false
	var had_waiting_conflict: bool = false
	for action: int in 200:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		if not links.is_empty() and not (policy.launch_first and run.total_packs() > 0):
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
			var probe: Vector4i = _probe(run)
			row.probe_boards += 1
			row.boards_losing_links += int(probe.x > 0)
			row.boards_gaining_links += int(probe.y > 0)
			row.boards_with_both += int(probe.x > 0 and probe.y > 0)
			had_conflict = had_conflict or (probe.x > 0 and probe.y > 0)
			row.waiting_stars_carried_off += probe.z
			row.stars_carried_in += probe.w
			row.boards_carrying_off_and_in += int(probe.z > 0 and probe.w > 0)
			had_waiting_conflict = had_waiting_conflict or (probe.z > 0 and probe.w > 0)
			var preview: Dictionary[int, Vector2i] = run.current_preview()
			for star: Star in run.stars:
				if star.position != preview[star.id]:
					row.moving_launches += 1
					break
		if not run.launch(_aim(run, policy.upstream)):
			break
		packs += 1
		row.launches += 1
	row.runs_with_both += int(had_conflict)
	row.runs_carrying_off_and_in += int(had_waiting_conflict)
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## Just up-left of the first unlit landmark. Upstream aim moves a target inside the flow one step
## against it, so the burst drifts back toward the landmark (it knows the step, not the scatter).
func _aim(run: RunState, upstream: bool) -> Vector2i:
	var target := Vector2i(90, 160)
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			target = run.scorpio.landmark_position(index) + Vector2i(-12, -18)
			break
	if upstream and run.current != null and run.current.region.has_point(target):
		target -= run.current.displacement
	return target


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
## x/y: complete landmark links lost/gained (canonical sets, so orders count once).
## z/w: loose stars carried out of / into reach of every unlit landmark. A star in reach of one is
## a waiting star: any second star completes a combo with the landmark, so it's half a link.
func _probe(run: RunState) -> Vector4i:
	var before: Dictionary[String, bool] = _landmark_links(run)
	var near_before: Dictionary[int, bool] = _waiting_stars(run)
	var original: Dictionary[int, Vector2i] = {}
	var preview: Dictionary[int, Vector2i] = run.current_preview()
	for star: Star in run.stars:
		original[star.id] = star.position
		star.position = preview[star.id]
	var after: Dictionary[String, bool] = _landmark_links(run)
	var near_after: Dictionary[int, bool] = _waiting_stars(run)
	for star: Star in run.stars:
		star.position = original[star.id]
	var result := Vector4i.ZERO
	for key: String in before:
		result.x += int(not after.has(key))
	for key: String in after:
		result.y += int(not before.has(key))
	for id: int in near_before:
		result.z += int(not near_after.has(id))
	for id: int in near_after:
		result.w += int(not near_before.has(id))
	return result


func _landmark_links(run: RunState) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for ids: Array in run.valid_links():
		ids.sort()
		if ids[0] < 0:
			result[str(ids)] = true
	return result


func _waiting_stars(run: RunState) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	var reach: int = run.link_reach()
	for star: Star in run.stars:
		if run.scorpio.is_landmark(star.id):
			continue
		for index: int in run.scorpio.map.count():
			if not run.scorpio.is_lit(index) and star.position.distance_squared_to(run.scorpio.landmark_position(index)) <= reach * reach:
				result[star.id] = true
				break
	return result
