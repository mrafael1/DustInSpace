extends SceneTree
## Paired seeded runs of Pisces's reflection (chapter 6) through the spatial core, the seam off and on.
## Bots are deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=<StarMap id> (default pisces_circlet; pisces_west_cord is the other seam), --runs=N,
## --policies=a,b.
## Policies: link-first links the best link before launching and aims so the burst lands at its
## target near the first unlit landmark (throws at the target's reflection when there's a seam);
## naive links like link-first but throws at the target itself, ignoring the seam (with a seam its
## stars land mirrored: what reading the seam is worth); careless links the first valid link found
## and aims aware; launch-first launches every owned pack before linking (hoards) and aims aware.

const POLICIES: Array[String] = ["link-first", "naive", "careless", "launch-first"]
## The target, from the first unlit landmark (just up-left of it, as tools/gravity aims).
const TARGET_OFFSET := Vector2i(-12, -18)
## How near a burst must land to its target to count as on target, px.
const ON_TARGET: int = 12
var _balance: Balance
var _runs: int = 200
var _map: String = "pisces_circlet"
var _policies: Array[String] = POLICIES
var _policy: String = ""


func _initialize() -> void:
	_balance = Balance.load_file()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	_simulate.call_deferred()


func _simulate() -> void:
	var probe: StarMap = _layout(true)
	print("Paired seeds 1..%d; %s; seam %s" % [_runs, _map, StarMap.Seam.keys()[probe.seam]])
	_print_geometry()
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			var row: Dictionary = {"policy": policy, "seam": enabled, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "launches": 0, "clamped": 0, "on_target": 0, "miss_px": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["clamped_rate"] = snappedf(100.0 * row.clamped / maxi(1, row.launches), 0.1)
			row["on_target_rate"] = snappedf(100.0 * row.on_target / maxi(1, row.launches), 0.1)
			row["miss_px_mean"] = snappedf(float(row.miss_px) / maxi(1, row.launches), 0.1)
			row["launches_per_run"] = snappedf(float(row.launches) / _runs, 0.01)
			for key: String in ["packs_in_wins", "launches", "clamped", "on_target", "miss_px"]:
				row.erase(key)
			rows.append(row)
			print("%-13s seam=%-5s won %5.1f%%  lost %3d  capped %d  packs/win %5.2f  launches/run %5.2f  on target %5.1f%%  miss %5.1f px  clamped %4.1f%%" % [policy, enabled, row.win_rate, row.losses, row.capped, row.packs_per_win, row.launches_per_run, row.on_target_rate, row.miss_px_mean, row.clamped_rate])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/reflect/out"))
	var file: FileAccess = FileAccess.open("res://tools/reflect/out/results-%s.json" % _map, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.by_id(_map)
	if not enabled:
		map.seam = StarMap.Seam.NONE
	return map


## Each landmark's target, where an aware bot throws for it, and whether that throw (or the
## landmark's own reflection) leaves the sky or falls on the land and HUD below it (y >= 230).
func _print_geometry() -> void:
	var run := RunState.new(_balance, RandomNumberGenerator.new(), Scorpio.HOME_SKY, _layout(true))
	for index: int in run.scorpio.map.count():
		var landmark: Vector2i = run.scorpio.landmark_position(index)
		var target: Vector2i = landmark + TARGET_OFFSET
		var throw: Vector2i = run.reflect(target)
		var mirrored: Vector2i = run.reflect(landmark)
		var lands: Vector2i = run.burst_centre(throw)
		var notes: Array[String] = []
		if StarScatter.clamp_to_sky(throw, run.sky_rect) != throw:
			notes.append("throw off-sky")
		if lands != target:
			notes.append("burst clamped to %s" % lands)
		if mirrored.y >= 230 or not run.sky_rect.has_point(mirrored):
			notes.append("landmark's reflection %s off-sky/under land" % mirrored)
		print("  landmark %d %s%s target %s throw %s %s" % [index, landmark, " (lit)" if run.scorpio.is_lit(index) else "", target, throw, ", ".join(notes)])


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	for action: int in 400:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		var can_launch: bool = run.total_packs() > 0 or run.can_afford("blue")
		if not links.is_empty() and not (policy == "launch-first" and run.total_packs() > 0):
			run.link(_first_link(links) if policy == "careless" else _best_link(run, links))
			continue
		if not can_launch:
			break
		if run.total_packs() == 0:
			var kind: String = "red" if run.can_afford("red") else "blue"
			if not run.buy(kind):
				break
		if run.loaded_pack == "":
			for kind: String in ["red", "blue"]:
				if run.load_pack(kind):
					break
		var target: Vector2i = _target(run)
		var aim: Vector2i = target if policy == "naive" else run.reflect(target)
		var burst: Vector2i = run.burst_centre(aim)
		if not run.launch(aim):
			break
		packs += 1
		row.launches += 1
		var unclamped: Vector2i = run.reflect(aim) if run.scorpio.map.seam != StarMap.Seam.NONE else aim
		if burst != unclamped:
			row.clamped += 1
		var miss: int = roundi(Vector2(burst - target).length())
		row.miss_px += miss
		if miss <= ON_TARGET:
			row.on_target += 1
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## Just up-left of the first unlit landmark.
func _target(run: RunState) -> Vector2i:
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			return run.scorpio.landmark_position(index) + TARGET_OFFSET
	return Vector2i(90, 160)


func _first_link(links: Array[Array]) -> Array[int]:
	var ids: Array[int] = []
	ids.assign(links[0])
	return ids


func _best_link(run: RunState, links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var combo: String = run.combo_for(ids)
		var score: int = run.link_dust(combo) + run.balance.combos[combo].light
		for id: int in ids:
			if run.scorpio.is_landmark(id):
				score += 100
		if score > best_score:
			best = ids
			best_score = score
	return best
