extends SceneTree
## Paired seeded runs of Leo's heat stages through the spatial core, heat off and on. Bots are
## deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=leo_tail (default) or another heat stage's StarMap id; --runs=N.
## Policies: link-first links every link before launching; launch-first launches every owned pack
## before linking; ripen holds triples of loose stars that won't burn next launch, to let them grow;
## hot-first links like link-first but takes the links using stars the heat burns next first (the
## skill Leo's final asks, where every link breathes heat).

const POLICIES: Array[String] = ["link-first", "launch-first", "ripen", "hot-first"]
var _balance: Balance
var _runs: int = 200
var _map: String = "leo_tail"
var _rows: Array[Dictionary] = []
var _policy: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
	_balance = Balance.load_file()
	_simulate.call_deferred()


func _simulate() -> void:
	print("Paired seeds 1..%d; %s; reach %d" % [_runs, _map, _balance.scorpio_max_link_distance])
	for policy: String in POLICIES:
		for enabled: bool in [false, true]:
			if (policy == "ripen" or policy == "hot-first") and not enabled:
				continue
			var row: Dictionary = {"map": _map, "policy": policy, "heat": enabled, "runs": _runs, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "launches": 0, "grown": 0, "burned": 0, "runs_burning": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			_rows.append(row)
			print(JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/heat/out"))
	var file: FileAccess = FileAccess.open("res://tools/heat/out/results-%s.json" % _map, FileAccess.WRITE)
	file.store_string(JSON.stringify(_rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.by_id(_map)
	if not enabled:
		map.heat_change = 0
	return map


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	var counts: Array[int] = [0, 0]
	var count := func(changes: Array[StarHeat.Change]) -> void:
		for change: StarHeat.Change in changes:
			counts[1 if change.lost else 0] += 1
	run.stars_resized.connect(count)
	run.heat_breathed.connect(func(_at: Vector2i, changes: Array[StarHeat.Change]) -> void: count.call(changes))
	for action: int in 300:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		var can_launch: bool = run.total_packs() > 0 or run.can_afford("blue")
		if policy == "ripen" and can_launch:
			links = links.filter(func(ids: Array) -> bool: return not _ripening(run, ids))
		if not links.is_empty() and not (policy == "launch-first" and run.total_packs() > 0):
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
		if not run.launch(_aim(run)):
			break
		packs += 1
		row.launches += 1
	row.grown += counts[0]
	row.burned += counts[1]
	row.runs_burning += int(counts[1] > 0)
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## A link the ripen policy holds: three loose stars of one size that the next launch grows.
func _ripening(run: RunState, ids: Array) -> bool:
	if run.heat == null:
		return false
	var size: int = -1
	for id: int in ids:
		var star: Star = run.find_star(id)
		if star == null:
			return false
		if size >= 0 and star.size != size:
			return false
		size = star.size
	var grows: bool = size + run.heat.change >= Star.Size.SMALL and size + run.heat.change <= Star.Size.BIG
	return grows or not run.heat.burns


## Just up-left of the first unlit landmark.
func _aim(run: RunState) -> Vector2i:
	var target := Vector2i(90, 160)
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			target = run.scorpio.landmark_position(index) + Vector2i(-12, -18)
			break
	return target


## Whether the heat's next step burns loose star `id` out.
func _burns_next(run: RunState, id: int) -> bool:
	var star: Star = run.find_star(id)
	if star == null or run.heat == null or not run.heat.burns:
		return false
	var next: int = star.size + run.heat.change
	return next > Star.Size.BIG or next < Star.Size.SMALL


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
			elif _policy == "hot-first" and _burns_next(run, id):
				score += 60
		if score > best_score:
			best = ids
			best_score = score
	return best
