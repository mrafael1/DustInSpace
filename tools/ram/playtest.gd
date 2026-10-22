extends SceneTree
## Paired seeded runs of Aries's ram (chapter 7) through the spatial core, the ram off and on.
## Bots are deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=<StarMap id> (default aries_horns), --runs=N, --policies=a,b, and what-ifs --butt=PX,
## --lane=PX (over balance.json's).
## Policies: link-first links the best link before launching and aims at the first unlit landmark;
## careful plays link-first but aims its burst out of the lane (the next charge's) when the target is
## in it; careless links the first valid link found; launch-first launches every owned pack before
## linking (hoards).

const PlaytestSky := preload("res://tools/playtest_sky.gd")
const POLICIES: Array[String] = ["link-first", "careful", "careless", "launch-first"]
## The target, from the first unlit landmark (just up-left of it, as tools/reflect aims).
const TARGET_OFFSET := Vector2i(-12, -18)

## The play sky (--sky=WxH, tools/playtest_sky.gd; the 9:16 sky without it).
var _sky: Rect2i = Scorpio.HOME_SKY
var _balance: Balance
var _runs: int = 200
var _map: String = "aries_horns"
var _policies: Array[String] = POLICIES
## Stars the ram butted out of the sky this run.
var _lost: int = 0


func _initialize() -> void:
	_sky = PlaytestSky.from_args()
	print(PlaytestSky.label(_sky))
	_balance = Balance.load_file()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--butt="):
			_balance.ram_butt = argument.trim_prefix("--butt=").to_int()
			_balance.ram_hard_butt = _balance.ram_butt
		elif argument.begins_with("--lane="):
			_balance.ram_lane = argument.trim_prefix("--lane=").to_int()
			_balance.ram_hard_lane = _balance.ram_lane
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	_simulate.call_deferred()


func _simulate() -> void:
	var butt: int = _balance.ram_hard_butt if StarMap.by_id(_map).ram_hard and _balance.ram_hard_butt > 0 else _balance.ram_butt
	var lane: int = _balance.ram_hard_lane if StarMap.by_id(_map).ram_hard and _balance.ram_hard_lane > 0 else _balance.ram_lane
	print("Paired seeds 1..%d; %s; ram every %d, lane %d, butt %d" % [_runs, _map, _balance.ram_every, lane, butt])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			var row: Dictionary = {"policy": policy, "on": enabled, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "launches": 0, "lost": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["launches_per_run"] = snappedf(float(row.launches) / _runs, 0.01)
			row["lost_per_run"] = snappedf(float(row.lost) / _runs, 0.01)
			for key: String in ["packs_in_wins", "launches", "lost"]:
				row.erase(key)
			rows.append(row)
			print("%-13s on=%-5s won %5.1f%%  lost %3d  capped %d  packs/win %5.2f  launches/run %5.2f  butted out/run %5.2f" % [policy, enabled, row.win_rate, row.losses, row.capped, row.packs_per_win, row.launches_per_run, row.lost_per_run])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/ram/out"))
	var file: FileAccess = FileAccess.open(("res://tools/ram/out/results-%s.json" % _map).trim_suffix(".json") + PlaytestSky.suffix(_sky) + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.by_id(_map)
	map.ram = enabled
	return map


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, _sky, _layout(enabled))
	_lost = 0
	run.ram_charged.connect(func(_row: int, moves: Array[StarCurrent.Move], _way: Vector2i) -> void:
		for move: StarCurrent.Move in moves:
			if move.drained:
				_lost += 1)
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
		var aim: Vector2i = _target(run)
		if policy == "careful" and run.ram != null:
			aim = _out_of_lane(run, aim)
		if not run.launch(aim):
			break
		packs += 1
		row.launches += 1
	row.lost += _lost
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## `aim` moved off the lane (up or down off a row, left or right off a column: the nearer way that
## stays in the sky) until its burst ring clears it.
func _out_of_lane(run: RunState, aim: Vector2i) -> Vector2i:
	var down: bool = run.ram.is_down()
	var across: Vector2i = Vector2i.RIGHT if down else Vector2i.DOWN
	var at: int = aim.x if down else aim.y
	var top: int = run.ram.lane_top()
	var bottom: int = top + run.ram.lane
	if at + StarScatter.RING_MAX < top or at - StarScatter.RING_MAX >= bottom:
		return aim
	var before: Vector2i = aim + across * (top - StarScatter.RING_MAX - 2 - at)
	var after: Vector2i = aim + across * (bottom + StarScatter.RING_MAX + 2 - at)
	var inner: Rect2i = StarScatter.inner_rect(run.launch_rect())
	if not inner.grow(-4).has_point(after):
		return before
	if not inner.grow(-4).has_point(before):
		return after
	return before if at - top <= bottom - at else after


## Just up-left of the first unlit landmark.
func _target(run: RunState) -> Vector2i:
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			return run.scorpio.landmark_position(index) + TARGET_OFFSET
	return Vector2i(90, 160) + run.scorpio.shift


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
