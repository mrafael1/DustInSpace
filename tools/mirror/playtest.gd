extends SceneTree
## Paired seeded runs of Pisces's mirror (chapter 6) through the spatial core, the mirror off and on.
## Bots are deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=<StarMap id> (default pisces_circlet; pisces_west_cord has echoes that light; any other is a
## borrowed layout with its heat, current, harvest, hole, cords and threats switched off and the
## mirror set), --runs=N, --policies=a,b, --echo-reach=N (a what-if for mirror.echo_reach).
## Policies: link-first links the best link (dust, light, landmarks) before launching, blind to its
## echo, aiming at the first unlit landmark; careless links the first valid link found; launch-first
## launches every owned pack before linking (hoards); mirror links first, scoring every link in every
## order it can be traced in (the echo goes by pick order) by its own value plus its echo's (a paid
## echo's dust, light and landmarks; a lost echo's stars and the links they were in), and aims round
## the landmark where its bursts' mirror spots hold three or more stars to echo onto, else none.
## The mirror bot only runs with the mirror on.

const POLICIES: Array[String] = ["link-first", "careless", "launch-first", "mirror"]
## A link's dust and light, plus these.
const LANDMARK_WEIGHT: int = 100
## What a star an echo loses is worth, and each valid link it was in besides.
const LOST_STAR_WEIGHT: int = 8
const BROKEN_LINK_WEIGHT: int = 6
## The mirror bot's aim: looks this far round its landmark, on this grid, for bursts whose mirror
## spots hold ECHO_PARTNERS or more stars (a full echo can pay), else none (no echo to lose).
const AIM_SEARCH: int = 32
const AIM_GRID: int = 8
const ECHO_PARTNERS: int = 3
const PARTNER_BONUS: int = 60
const PARTNER_PENALTY: int = 20
## Where link-first aims, from the landmark (as tools/gravity/playtest.gd).
const AIM_OFFSET := Vector2i(-12, -18)

var _balance: Balance
var _runs: int = 300
var _map: String = "pisces_circlet"
## A what-if for balance.json's mirror.echo_reach (-1: as it has it).
var _echo_reach_what_if: int = -1
var _policies: Array[String] = POLICIES.duplicate()
var _policy: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--echo-reach="):
			_echo_reach_what_if = argument.trim_prefix("--echo-reach=").to_int()
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	for policy: String in _policies:
		if not POLICIES.has(policy):
			push_error("Unknown policy '%s' (known: %s)" % [policy, ", ".join(POLICIES)])
			quit(1)
			return
	_balance = Balance.load_file()
	if _echo_reach_what_if >= 0:
		_balance.mirror_echo_reach = _echo_reach_what_if
	_simulate.call_deferred()


func _simulate() -> void:
	var started: int = Time.get_ticks_msec()
	var probe: StarMap = _layout(true)
	print("Paired seeds 1..%d; %s; echo reach %d; echoes light %s; link reach %d" % [_runs, _map, _balance.mirror_echo_reach, probe.mirror_lights, _balance.scorpio_max_link_distance])
	print("%-13s %-6s %6s %5s %6s %9s %10s %10s %10s %9s %10s %12s %6s" % ["policy", "mirror", "won%", "lost", "capped", "packs/win", "paid/run", "lost/run", "starslost", "echo-lit", "echo-dust", "strand/loss", "secs"])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			if policy == "mirror" and not enabled:
				continue
			var row_started: int = Time.get_ticks_msec()
			var row: Dictionary = {"map": _map, "policy": policy, "mirror": enabled, "runs": _runs, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0,
				"paid": 0, "lost": 0, "stars_lost": 0, "echo_lit": 0, "echo_dust": 0, "echo_light": 0, "refused": 0, "stranded": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			if row.refused > 0:
				push_error("%s mirror=%s: %d links refused (the bots should only link valid links)" % [policy, enabled, row.refused])
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["paid_per_run"] = snappedf(float(row.paid) / _runs, 0.01)
			row["lost_per_run"] = snappedf(float(row.lost) / _runs, 0.01)
			row["stars_lost_per_run"] = snappedf(float(row.stars_lost) / _runs, 0.01)
			row["echo_lit_per_run"] = snappedf(float(row.echo_lit) / _runs, 0.01)
			row["echo_dust_per_run"] = snappedf(float(row.echo_dust) / _runs, 0.01)
			row["echo_light_per_run"] = snappedf(float(row.echo_light) / _runs, 0.01)
			row["stranded_per_loss"] = snappedf(float(row.stranded) / maxi(1, row.losses), 0.01)
			row["seconds"] = snappedf((Time.get_ticks_msec() - row_started) / 1000.0, 0.1)
			for key: String in ["packs_in_wins", "paid", "lost", "stars_lost", "echo_lit", "echo_dust", "echo_light", "stranded"]:
				row.erase(key)
			rows.append(row)
			print("%-13s %-6s %6.1f %5d %6d %9.2f %10.2f %10.2f %10.2f %9.2f %10.2f %12.2f %6.1f" % [policy, enabled, row.win_rate, row.losses, row.capped, row.packs_per_win,
				row.paid_per_run, row.lost_per_run, row.stars_lost_per_run, row.echo_lit_per_run, row.echo_dust_per_run, row.stranded_per_loss, row.seconds])
	print("Total %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/mirror/out"))
	var file: FileAccess = FileAccess.open("res://tools/mirror/out/results-%s.json" % _map, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.by_id(_map)
	if not _map.begins_with("pisces"):
		# A borrowed layout: its own rules off, the mirror set.
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
		map.cords = false
		map.fish_cord = []
	map.mirror = enabled
	if not enabled:
		map.mirror_lights = false
	return map


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	var hoards: bool = policy == "launch-first"
	run.link_rejected.connect(func(_ids: Array[int]) -> void: row.refused += 1)
	run.mirror_echoed.connect(func(echo: Array[Star], combo: String, dust: int, light: int) -> void:
		var landmarks: int = echo.filter(func(star: Star) -> bool: return star.id < 0).size()
		if combo == Combos.INVALID:
			row.lost += 1
			row.stars_lost += echo.size() - landmarks
		else:
			row.paid += 1
			row.echo_lit += landmarks
			row.echo_dust += dust
			row.echo_light += light)
	for action: int in 400:
		if run.is_over():
			break
		var can_launch: bool = run.total_packs() > 0 or run.can_afford("blue")
		if not (hoards and run.total_packs() > 0):
			var link: Array[int] = _choose_link(run)
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
		if not run.launch(_aim(run)):
			break
		packs += 1
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
			row.stranded += run.stars.size()
		_:
			row.capped += 1


func _choose_link(run: RunState) -> Array[int]:
	if _policy == "mirror":
		return _mirrored_link(run)
	var links: Array[Array] = run.valid_links()
	if links.is_empty():
		return [] as Array[int]
	if _policy == "careless":
		var first: Array[int] = []
		first.assign(links[0])
		return first
	return _best_link(run, links)


## The best link by dust, light and landmarks (as tools/gravity/playtest.gd), blind to its echo.
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


## The mirror bot: every link in every order it can be traced in (each middle, both ways round, as
## the echo takes its stars in pick order), by its value plus its echo's.
func _mirrored_link(run: RunState) -> Array[int]:
	var orders: Array[Array] = run.valid_links(true)
	if orders.is_empty():
		return [] as Array[int]
	var trios: Array[Array] = run.valid_links()
	var best: Array[int] = []
	var best_score: int = -(1 << 30)
	for order: Array in orders:
		for reversed: bool in [false, true]:
			var ids: Array[int] = []
			ids.assign(order)
			if reversed:
				ids.reverse()
			var score: int = _link_value(run, ids) + _echo_value(run, ids, trios)
			if score > best_score:
				best = ids
				best_score = score
	return best


## What a link's echo is worth: paid, its dust, light and the landmarks it lights; lost, minus its
## loose stars (each, and each other valid link it was in), unless the link clears the sky anyway.
func _echo_value(run: RunState, ids: Array[int], trios: Array[Array]) -> int:
	var echo: Array[Star] = run.link_echo(ids)
	if echo.is_empty():
		return 0
	var combo: String = StarMirror.combo_of(echo)
	if combo != Combos.INVALID:
		var score: int = run.link_dust(combo) + run.balance.combos[combo].light
		for star: Star in echo:
			if run.scorpio.is_landmark(star.id):
				score += LANDMARK_WEIGHT
		return score
	if _clears_sky(run, ids):
		return 0
	var cost: int = 0
	for star: Star in echo:
		if run.scorpio.is_landmark(star.id):
			continue
		cost += LOST_STAR_WEIGHT
		for trio: Array in trios:
			if trio.has(star.id) and not trio.any(func(id: int) -> bool: return ids.has(id)):
				cost += BROKEN_LINK_WEIGHT
	return -cost


## The first unlit landmark, aimed just up-left of; the mirror bot looks round it for an aim whose
## bursts' mirror spots hold three or more stars (an echo there can pay), else none (none lost).
func _aim(run: RunState) -> Vector2i:
	var landmark := Vector2i(90, 160)
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			landmark = run.scorpio.landmark_position(index)
			break
	var preferred: Vector2i = landmark + AIM_OFFSET
	if _policy != "mirror" or run.mirror == null:
		return preferred
	var best: Vector2i = preferred
	var best_score: int = -(1 << 30)
	for y: int in range(-AIM_SEARCH, AIM_SEARCH + 1, AIM_GRID):
		for x: int in range(-AIM_SEARCH, AIM_SEARCH + 1, AIM_GRID):
			var spot: Vector2i = StarScatter.clamp_to_sky(landmark + Vector2i(x, y), run.sky_rect)
			var partners: int = _echo_partners(run, spot)
			var score: int = (PARTNER_BONUS + partners) if partners >= ECHO_PARTNERS else -PARTNER_PENALTY * partners
			score -= int((spot - preferred).length()) / 2
			if score > best_score:
				best = spot
				best_score = score
	return best


## How many stars (and, where echoes light, unlit landmarks) stand at the mirror spots of the area a
## launch at `aim` bursts over: what links of its stars would echo onto.
func _echo_partners(run: RunState, aim: Vector2i) -> int:
	var kind: String = run.loaded_pack if run.loaded_pack != "" else "blue"
	var pack: Balance.PackDef = run.balance.packs[kind]
	var points: Array[Vector2i] = [StarScatter.clamp_to_sky(aim, run.sky_rect)]
	if pack.bursts > 1:
		points = StarScatter.split_points(aim, pack.burst_spread, pack.bursts, run.sky_rect)
	var near: int = StarScatter.RING_MAX + run.mirror.reach
	var others: Array[Star] = run.stars.duplicate()
	if run.mirror.lights:
		others.append_array(run.scorpio.unlit_stars())
	var count: int = 0
	for star: Star in others:
		var spot: Vector2i = run.mirror.mirror(star.position)
		for point: Vector2i in points:
			if (spot - point).length_squared() <= near * near:
				count += 1
				break
	return count


## Whether linking `ids` rekindles the Sun or completes the figure, clearing the sky (as
## tools/cords/playtest.gd; RunState._link_clears_sky is private).
func _clears_sky(run: RunState, ids: Array[int]) -> bool:
	var unlit: int = 0
	for index: int in run.scorpio.map.count():
		unlit += int(not run.scorpio.is_lit(index))
	var landmarks: int = ids.filter(run.scorpio.is_landmark).size()
	return run.light + run.balance.combos[run.combo_for(ids)].light >= run.light_target() or unlit - landmarks <= 0
