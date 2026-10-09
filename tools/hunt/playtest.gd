extends SceneTree
## Paired seeded runs of Orion's stages (the Tail, Body, Heart, Claws and final) through the spatial
## core: positions, the link reach, where his circles land and every loss check are the game's own.
## Bots are deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=heart (default; any of tail, body, heart, claws, final), --runs=N, --policies=a,b.
## Policies: naive links the best link (constellation stars first) before launching and aims at the
## next constellation star to light; careful also links out the marked star and the stars in the
## circle first, and aims the launch clear of the circle (RunState.is_safe_launch), as near that
## constellation star as it can.
## Besides the win rate it counts how many unlit constellation stars each new circle covers (the
## circle's placement, #149) and the stars his threats take a run.

const POLICIES: Array[String] = ["naive", "careful"]
## The careful bot looks this far round the constellation star it aims for, for a launch clear of
## the circle (a step of the grid it tries).
const AIM_SEARCH: int = 48
const AIM_GRID: int = 4

var _balance: Balance
var _runs: int = 300
var _map: String = "heart"
var _policies: Array[String] = POLICIES.duplicate()
var _policy: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	_balance = Balance.load_file()
	_simulate.call_deferred()


func _simulate() -> void:
	print("Paired seeds 1..%d; %s; reach %d; hunt radius %d" % [_runs, _map, _balance.scorpio_max_link_distance, _balance.hunt_radius])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		var row: Dictionary = {"map": _map, "policy": policy, "runs": _runs, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0,
			"circles": 0, "landmarks_covered": 0, "circles_on_landmarks": 0, "struck": 0, "shot": 0, "volleyed": 0}
		for seed_value: int in range(1, _runs + 1):
			_play(seed_value, policy, row)
			if seed_value % 20 == 0:
				await process_frame
		row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
		row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
		row["landmarks_per_circle"] = snappedf(float(row.landmarks_covered) / maxi(1, row.circles), 0.01)
		row["circles_on_landmarks_pct"] = snappedf(100.0 * row.circles_on_landmarks / maxi(1, row.circles), 0.1)
		row["struck_per_run"] = snappedf(float(row.struck) / _runs, 0.01)
		rows.append(row)
		print("%-8s won %5.1f%%  lost %3d  capped %d  packs/win %5.2f  circles on the figure %5.1f%% (%.2f stars each)  struck/run %5.2f  shot/run %4.2f  volleyed/run %5.2f" % [
			policy, row.win_rate, row.losses, row.capped, row.packs_per_win, row.circles_on_landmarks_pct, row.landmarks_per_circle,
			row.struck_per_run, float(row.shot) / _runs, float(row.volleyed) / _runs])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/hunt/out"))
	var file: FileAccess = FileAccess.open("res://tools/hunt/out/results-%s.json" % _map, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _play(seed_value: int, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, StarMap.by_id(_map))
	var packs: int = 0
	run.area_marked.connect(func(centre: Vector2i, radius: int) -> void:
		var covered: int = 0
		for i: int in run.scorpio.map.count():
			if not run.scorpio.is_lit(i) and (run.scorpio.landmark_position(i) - centre).length_squared() <= radius * radius:
				covered += 1
		row.circles += 1
		row.landmarks_covered += covered
		row.circles_on_landmarks += int(covered > 0))
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: row.struck += stars.size())
	run.star_shot.connect(func(_star: Star) -> void: row.shot += 1)
	run.volley_fired.connect(func(stars: Array[Star]) -> void: row.volleyed += stars.size())
	for action: int in 400:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		if not links.is_empty():
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


## The next constellation star to light (one next to a lit one first, as the Sun would), aimed at;
## the careful bot keeps the launch clear of the circle, as near it as it can.
func _aim(run: RunState) -> Vector2i:
	var index: int = run.rekindle_target()
	var target: Vector2i = run.scorpio.landmark_position(index) if index >= 0 else Scorpio.HOME_SKY.get_center()
	if _policy != "careful" or run.is_safe_launch(target):
		return target
	var best := Vector2i(-1, -1)
	for y: int in range(-AIM_SEARCH, AIM_SEARCH + 1, AIM_GRID):
		for x: int in range(-AIM_SEARCH, AIM_SEARCH + 1, AIM_GRID):
			var spot: Vector2i = StarScatter.clamp_to_sky(target + Vector2i(x, y), run.sky_rect)
			if run.is_safe_launch(spot) and (best.x < 0 or (spot - target).length_squared() < (best - target).length_squared()):
				best = spot
	return best if best.x >= 0 else target


## The best link: constellation stars first, then (careful) the marked star and the stars in the
## circle, then the most dust and light.
func _best_link(run: RunState, links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	var marked: Star = run.marked_star()
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var combo: String = run.combo_for(ids)
		var score: int = run.balance.combos[combo].dust + run.balance.combos[combo].light
		for id: int in ids:
			if run.scorpio.is_landmark(id):
				score += 100
			elif _policy == "careful":
				if marked != null and id == marked.id:
					score += 60
				var star: Star = run.find_star(id)
				if star != null and run.hunt != null and run.hunt.contains(star.position):
					score += 40
		if score > best_score:
			best = ids
			best_score = score
	return best
