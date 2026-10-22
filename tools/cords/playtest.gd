extends SceneTree
## Paired seeded runs of Pisces's cords (chapter 6 trial) through the spatial core, the cords off and
## on. Bots are deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=<StarMap id> (default cord_trial, the trial's own map; any other is a borrowed layout with
## its heat, current, harvest, hole and threats switched off and cords set), --runs=N, --policies=a,b.
## Policies: link-first links the best link (dust, light, landmarks) before launching, aiming at the
## first unlit landmark; careless links the first valid link found; launch-first launches every
## owned pack before linking (hoards); planner links first, choosing the link and its middle star by
## what its cords would wall off (other links blocked, landmarks cut off), and aims where the burst
## isn't walled off from that landmark; planner-hoard chooses as the planner and hoards.
## The planners only run with cords on.
## --keep-cords: a what-if, in the tool only: cords outlast the sky's clears (re-tied at once on
## cords_cleared), so they stay the whole stage (the plan's open question); the planner then counts
## a clearing link's cords too.
## --fish=x,y;x,y;...: the fish's cord as a home-layout polyline (StarMap.fish_cord), overriding the
## map's; --fish=none removes it. Quote it in a shell ("--fish=0,128;98,176;179,132"). Only used with
## cords on. The results file then carries the polyline in its name.

const PlaytestSky := preload("res://tools/playtest_sky.gd")
const POLICIES: Array[String] = ["link-first", "careless", "launch-first", "planner", "planner-hoard"]
## The planner's weights: a link's dust and light, plus these.
const LANDMARK_WEIGHT: int = 100
const BLOCKED_WEIGHT: int = 25
const CUT_OFF_WEIGHT: int = 150
## The planner looks this far round its landmark for an aim whose line to it crosses no cord.
const AIM_SEARCH: int = 48
const AIM_GRID: int = 4
## Where link-first aims, from the landmark (as tools/gravity/playtest.gd).
const AIM_OFFSET := Vector2i(-12, -18)

## The play sky (--sky=WxH, tools/playtest_sky.gd; the 9:16 sky without it).
var _sky: Rect2i = Scorpio.HOME_SKY
var _balance: Balance
var _runs: int = 300
var _map: String = "cord_trial"
var _policies: Array[String] = POLICIES.duplicate()
var _policy: String = ""
var _keep_cords: bool = false
## Whether --fish was given, and its polyline (empty for none).
var _fish_set: bool = false
var _fish: Array[Vector2i] = []


func _initialize() -> void:
	_sky = PlaytestSky.from_args()
	print(PlaytestSky.label(_sky))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
		elif argument == "--keep-cords":
			_keep_cords = true
		elif argument.begins_with("--fish="):
			if not _parse_fish(argument.trim_prefix("--fish=")):
				push_error("Bad --fish '%s' (want x,y;x,y;... or none)" % argument)
				quit(1)
				return
	for policy: String in _policies:
		if not POLICIES.has(policy):
			push_error("Unknown policy '%s' (known: %s)" % [policy, ", ".join(POLICIES)])
			quit(1)
			return
	_balance = Balance.load_file()
	_simulate.call_deferred()


func _simulate() -> void:
	var started: int = Time.get_ticks_msec()
	print("Paired seeds 1..%d; %s; reach %d%s; fish %s" % [_runs, _map, _balance.scorpio_max_link_distance, "; cords kept through clears" if _keep_cords else "",
		_fish_text(_layout(true).fish_cord)])
	print("%-13s %-5s %6s %5s %6s %9s %9s %7s %13s %13s %12s %6s" % ["policy", "cords", "won%", "lost", "capped", "packs/win", "cords/run", "refused", "blocked/board", "lost_to_cords", "strand/loss", "secs"])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			if policy.begins_with("planner") and not enabled:
				continue
			var row_started: int = Time.get_ticks_msec()
			var row: Dictionary = {"map": _map, "fish": _fish_text(_layout(true).fish_cord), "keep_cords": _keep_cords, "policy": policy, "cords": enabled, "runs": _runs, "wins": 0, "losses": 0, "capped": 0,
				"packs_in_wins": 0, "cords_tied": 0, "refused": 0, "boards": 0, "blocked": 0, "lost_to_cords": 0, "stranded": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			if row.refused > 0:
				push_error("%s cords=%s: %d links refused (the bots should only link valid links)" % [policy, enabled, row.refused])
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["cords_per_run"] = snappedf(float(row.cords_tied) / _runs, 0.01)
			row["blocked_per_board"] = snappedf(float(row.blocked) / maxi(1, row.boards), 0.001)
			row["stranded_per_loss"] = snappedf(float(row.stranded) / maxi(1, row.losses), 0.01)
			row["seconds"] = snappedf((Time.get_ticks_msec() - row_started) / 1000.0, 0.1)
			for key: String in ["packs_in_wins", "cords_tied", "blocked", "stranded"]:
				row.erase(key)
			rows.append(row)
			print("%-13s %-5s %6.1f %5d %6d %9.2f %9.2f %7d %13.3f %13d %12.2f %6.1f" % [policy, enabled, row.win_rate, row.losses, row.capped,
				row.packs_per_win, row.cords_per_run, row.refused, row.blocked_per_board, row.lost_to_cords, row.stranded_per_loss, row.seconds])
	print("Total %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/cords/out"))
	var fish_suffix: String = ""
	if _fish_set:
		fish_suffix = "-fish_" + (_fish_text(_fish).replace(";", "_").replace(",", "-") if not _fish.is_empty() else "none")
	var file: FileAccess = FileAccess.open(("res://tools/cords/out/results-%s%s%s.json" % [_map, "-kept" if _keep_cords else "", fish_suffix]).trim_suffix(".json") + PlaytestSky.suffix(_sky) + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = _base_layout(enabled)
	if _fish_set and enabled:
		map.fish_cord = _fish.duplicate()
	return map


func _base_layout(enabled: bool) -> StarMap:
	if _map == "cord_trial":
		return StarMap.cord_trial(enabled)
	# A borrowed layout: its own rules off, the cords set.
	var map: StarMap = StarMap.by_id(_map)
	map.heat_change = 0
	map.heat_landmarks = false
	map.heat_on_links = false
	map.current_region = Rect2i()
	map.harvest = false
	map.orion = false
	map.volley = ""
	map.hunt = false
	map.boss = false
	map.black_hole = false
	map.black_hole_hungry = false
	map.black_hole_twins = false
	map.black_hole_gauge = false
	map.cords = enabled
	return map


## Reads --fish's polyline ("none": no fish cord). False if it doesn't parse.
func _parse_fish(text: String) -> bool:
	_fish_set = true
	_fish.clear()
	if text == "none":
		return true
	for pair: String in text.split(";", false):
		var xy: PackedStringArray = pair.split(",")
		if xy.size() != 2 or not xy[0].strip_edges().is_valid_int() or not xy[1].strip_edges().is_valid_int():
			return false
		_fish.append(Vector2i(xy[0].strip_edges().to_int(), xy[1].strip_edges().to_int()))
	return _fish.size() >= 2


static func _fish_text(points: Array[Vector2i]) -> String:
	if points.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for point: Vector2i in points:
		parts.append("%d,%d" % [point.x, point.y])
	return ";".join(parts)


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, _sky, _layout(enabled))
	var packs: int = 0
	var hoards: bool = policy in ["launch-first", "planner-hoard"]
	var plans: bool = policy.begins_with("planner")
	run.cord_tied.connect(func(_points: Array[Vector2i]) -> void: row.cords_tied += 1)
	run.link_rejected.connect(func(_ids: Array[int]) -> void: row.refused += 1)
	if _keep_cords and run.cords != null:
		# The closures hold the cords, not the run (no reference cycle).
		var kept: Array[Array] = []
		var tied: StarCords = run.cords
		run.cord_tied.connect(func(points: Array[Vector2i]) -> void: kept.append(points))
		run.cords_cleared.connect(func() -> void:
			for points: Array[Vector2i] in kept:
				tied.tie(points))
	for action: int in 400:
		if run.is_over():
			break
		if run.cords != null:
			_count_blocked(run, row)
		var can_launch: bool = run.total_packs() > 0 or run.can_afford("blue")
		if not (hoards and run.total_packs() > 0):
			var link: Array[int] = _choose_link(run, plans)
			if not link.is_empty():
				run.link(link)
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
		if not run.launch(_aim(run, plans)):
			break
		packs += 1
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
			row.stranded += run.stars.size()
			if run.cords != null and _has_combo_without_cords(run):
				row.lost_to_cords += 1
		_:
			row.capped += 1


## Whether a combo would remain if the cords were gone (the loss is the cords' doing). The cords are
## put back at once; nothing else is touched.
func _has_combo_without_cords(run: RunState) -> bool:
	var saved: StarCords = run.cords
	run.cords = null
	var found: bool = run.has_remaining_combo()
	run.cords = saved
	return found


## Links that only the cords stop on this board: valid links ignoring them minus valid links.
func _count_blocked(run: RunState, row: Dictionary) -> void:
	var aware: int = run.valid_links().size()
	var saved: StarCords = run.cords
	run.cords = null
	var free: int = run.valid_links().size()
	run.cords = saved
	row.boards += 1
	row.blocked += free - aware


func _choose_link(run: RunState, plans: bool) -> Array[int]:
	if plans:
		return _planned_link(run)
	var links: Array[Array] = run.valid_links()
	if links.is_empty():
		return [] as Array[int]
	if _policy == "careless":
		var first: Array[int] = []
		first.assign(links[0])
		return first
	return _best_link(run, links)


## The first unlit landmark, aimed just up-left of; the planner keeps the aim's line to it clear of
## cords (nearest such spot on a grid round it), so the burst lands on its side.
func _aim(run: RunState, plans: bool) -> Vector2i:
	var landmark: Vector2i = Vector2i(90, 160) + run.scorpio.shift
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			landmark = run.scorpio.landmark_position(index)
			break
	var preferred: Vector2i = landmark + AIM_OFFSET
	if not plans or run.cords == null or _clear_aim(run, preferred, landmark):
		return preferred
	var best: Vector2i = preferred
	var found: bool = false
	for y: int in range(-AIM_SEARCH, AIM_SEARCH + 1, AIM_GRID):
		for x: int in range(-AIM_SEARCH, AIM_SEARCH + 1, AIM_GRID):
			var spot: Vector2i = StarScatter.clamp_to_sky(landmark + Vector2i(x, y), run.sky_rect)
			if _clear_aim(run, spot, landmark) and (not found or (spot - preferred).length_squared() < (best - preferred).length_squared()):
				best = spot
				found = true
	return best


func _clear_aim(run: RunState, spot: Vector2i, landmark: Vector2i) -> bool:
	return run.is_safe_launch(spot) and not run.cords.crosses(spot, landmark)


## The best link by dust, light and landmarks (as tools/gravity/playtest.gd).
func _best_link(run: RunState, links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var score: int = _link_value(run, ids)
		if score > best_score:
			best = ids
			best_score = score
	return best


func _link_value(run: RunState, ids: Array[int]) -> int:
	var combo: String = run.combo_for(ids)
	var score: int = run.link_dust(combo) + run.balance.combos[combo].light
	for id: int in ids:
		if run.scorpio.is_landmark(id):
			score += LANDMARK_WEIGHT
	return score


## The planner: over every link and every order it can be traced in, its value less what its two
## new cords would wall off: other links (disjoint stars) traceable now that no longer would be, and
## unlit landmarks left with none. A link that clears the sky takes its cords with it (not with
## --keep-cords, where they're tied again).
func _planned_link(run: RunState) -> Array[int]:
	var orders: Array[Array] = run.valid_links(true)
	if orders.is_empty():
		return [] as Array[int]
	# Every trio traceable now, with the positions of each order it traces in.
	var trios: Dictionary = {}
	for order: Array in orders:
		var key: Array = order.duplicate()
		key.sort()
		if not trios.has(key):
			trios[key] = []
		trios[key].append(_positions(run, order))
	var best: Array[int] = []
	var best_score: int = -(1 << 30)
	for order: Array in orders:
		var ids: Array[int] = []
		ids.assign(order)
		var score: int = _link_value(run, ids)
		if _keep_cords or not _clears_sky(run, ids):
			var points: Array[Vector2i] = _positions(run, order)
			var blocked: int = 0
			var before: Dictionary = {}
			var after: Dictionary = {}
			for key: Array in trios:
				if key.any(func(id: int) -> bool: return ids.has(id)):
					continue
				var still: bool = false
				for traced: Array[Vector2i] in trios[key]:
					if not _walled(traced, points):
						still = true
						break
				blocked += int(not still)
				for id: int in key:
					if run.scorpio.is_landmark(id):
						before[id] = true
						if still:
							after[id] = true
			var cut_off: int = before.size() - after.size()
			score -= BLOCKED_WEIGHT * blocked + CUT_OFF_WEIGHT * cut_off
		if score > best_score:
			best = ids
			best_score = score
	return best


## Whether a link traced through `traced` (positions, pick order) crosses either segment of a new
## cord through `cord`.
func _walled(traced: Array[Vector2i], cord: Array[Vector2i]) -> bool:
	for s: int in 2:
		for c: int in 2:
			if StarCords.properly_cross(traced[s], traced[s + 1], cord[c], cord[c + 1]):
				return true
	return false


func _positions(run: RunState, ids: Array) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for id: int in ids:
		if run.scorpio.is_landmark(id):
			points.append(run.scorpio.landmark_star(Scorpio.landmark_index(id)).position)
		else:
			points.append(run.find_star(id).position)
	return points


## Whether linking `ids` rekindles the Sun or completes the figure, clearing the sky (and cords).
## RunState._link_clears_sky is private; this mirrors it.
func _clears_sky(run: RunState, ids: Array[int]) -> bool:
	var unlit: int = 0
	for index: int in run.scorpio.map.count():
		unlit += int(not run.scorpio.is_lit(index))
	var landmarks: int = ids.filter(run.scorpio.is_landmark).size()
	return run.light + run.balance.combos[run.combo_for(ids)].light >= run.light_target() or unlit - landmarks <= 0
