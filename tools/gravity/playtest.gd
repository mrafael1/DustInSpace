extends SceneTree
## Paired seeded runs of Sagittarius's black hole (chapter 5 trial) through the spatial core, the hole
## off and on. Bots are deliberately simple; this is pressure evidence, not a prediction of human
## difficulty.
## --map=<StarMap id> (default black_hole_trial, the trial's own map; any other is a borrowed layout
## with its heat, current, harvest and threats switched off), --hole=x,y (home layout; else the map's own, else 90,164), --runs=N,
## --pull=N, --max-step=N, --horizon=N (what-ifs over balance.json's black_hole block, in memory
## only), --policies=a,b.
## Policies: link-first links every link before launching, aiming at the first unlit landmark;
## launch-first launches every owned pack before linking (hoards); archer links like link-first but
## aims past that landmark on the side away from the hole, so its stars fall toward it; archer-hoard
## aims as the archer and hoards as launch-first.

const POLICIES: Array[String] = ["link-first", "launch-first", "archer", "archer-hoard"]
## How far past its landmark the archer aims, away from the hole.
const ARCHER_LEAD: int = 26
var _balance: Balance
var _runs: int = 200
var _map: String = "black_hole_trial"
var _hole: Vector2i = Vector2i(-1, -1)
var _policies: Array[String] = POLICIES
var _policy: String = ""


func _initialize() -> void:
	_balance = Balance.load_file()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--hole="):
			var xy: PackedStringArray = argument.trim_prefix("--hole=").split(",")
			_hole = Vector2i(xy[0].to_int(), xy[1].to_int())
		elif argument.begins_with("--pull="):
			_balance.black_hole_pull = argument.trim_prefix("--pull=").to_int()
		elif argument.begins_with("--max-step="):
			_balance.black_hole_max_step = maxi(1, argument.trim_prefix("--max-step=").to_int())
		elif argument.begins_with("--horizon="):
			_balance.black_hole_horizon = argument.trim_prefix("--horizon=").to_int()
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	_simulate.call_deferred()


func _simulate() -> void:
	var probe: StarMap = _layout(true)
	print("Paired seeds 1..%d; %s; hole %s; pull %d; max step %d; horizon %d" % [_runs, _map, probe.black_hole_center, _balance.black_hole_pull, _balance.black_hole_max_step, _balance.black_hole_horizon])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			if policy.begins_with("archer") and not enabled:
				continue
			var row: Dictionary = {"policy": policy, "hole": enabled, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "swallowed": 0, "landed_in": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["swallowed_per_run"] = snappedf(float(row.swallowed) / _runs, 0.01)
			row["landed_in_per_run"] = snappedf(float(row.landed_in) / _runs, 0.01)
			for key: String in ["swallowed", "landed_in", "packs_in_wins"]:
				row.erase(key)
			rows.append(row)
			print("%-13s hole=%-5s won %5.1f%%  lost %3d  capped %d  packs/win %5.2f  swallowed/run %5.2f (on landing %4.2f)" % [policy, enabled, row.win_rate, row.losses, row.capped, row.packs_per_win, row.swallowed_per_run, row.landed_in_per_run])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/gravity/out"))
	var file: FileAccess = FileAccess.open("res://tools/gravity/out/results-%s-%d-%d.json" % [_map, probe.black_hole_center.x, probe.black_hole_center.y], FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.black_hole_trial() if _map == "black_hole_trial" else StarMap.by_id(_map)
	if not map.black_hole:
		# A borrowed layout: its own rules off.
		map.heat_change = 0
		map.heat_landmarks = false
		map.heat_on_links = false
		map.current_region = Rect2i()
		map.harvest = false
		map.orion = false
		map.volley = ""
		map.hunt = false
		map.boss = false
		map.black_hole_center = Vector2i(90, 164)
	if _hole.x >= 0:
		map.black_hole_center = _hole
	map.black_hole = enabled
	return map


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	var landed: Dictionary[int, bool] = {}
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
		for star: Star in stars:
			landed[star.id] = true)
	run.stars_fell.connect(func(falls: Array[StarGravity.Fall]) -> void:
		for fall: StarGravity.Fall in falls:
			if fall.swallowed:
				row.swallowed += 1
				if landed.has(fall.star_id):
					row.landed_in += 1
		landed.clear())
	for action: int in 400:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		var can_launch: bool = run.total_packs() > 0 or run.can_afford("blue")
		if not links.is_empty() and not (policy in ["launch-first", "archer-hoard"] and run.total_packs() > 0):
			run.link(_best_link(run, links))
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
		landed.clear()
		if not run.launch(_aim(run)):
			break
		packs += 1
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## Just up-left of the first unlit landmark; the archer aims past it, away from the hole.
func _aim(run: RunState) -> Vector2i:
	var target := Vector2i(90, 160)
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			target = run.scorpio.landmark_position(index)
			break
	if _policy.begins_with("archer") and run.gravity != null:
		var away: Vector2 = Vector2(target - run.gravity.center).normalized()
		return target + Vector2i((away * ARCHER_LEAD).round())
	return target + Vector2i(-12, -18)


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
