extends SceneTree
## Paired seeded runs of Virgo's harvest through the spatial core, harvest off and on. Bots are
## deliberately simple; this is pressure evidence, not a prediction of human difficulty.
## --map=virgo_wing (default; any StarMap id: a borrowed layout has its heat, current and threats
## switched off and the harvest switched on), --runs=N, --every=N and --link-dust=P (else
## balance.json's for that stage), --binds or --no-binds (else the map's), --policies=a,b.
## Policies: link-first links every link before launching (careless about binding); launch-first
## launches every owned pack before linking (hoards); bound links like link-first but lights the
## constellation stars next to the lit figure first; bound-strict never lights one that isn't while
## the harvest is next.
## Measured on the way to this rule (docs/chapter_4_6_plan.md): a harvest that paid dust, sheaves, a
## cap and ripe links; none had stakes without the binding.

const POLICIES: Array[String] = ["link-first", "launch-first", "bound", "bound-strict"]
var _balance: Balance
var _runs: int = 200
var _map: String = "virgo_wing"
var _binds: int = -1
## Twists switched on for the run: "quickens", "ties". (The swath, each harvest reaping half the
## sky by turns, was measured and dropped: docs/design.md, chapter 4.)
var _twists: Array[String] = []
var _policies: Array[String] = POLICIES
var _policy: String = ""


func _initialize() -> void:
	_balance = Balance.load_file()
	var every: int = -1
	var link_dust: int = -1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--every="):
			every = maxi(1, argument.trim_prefix("--every=").to_int())
		elif argument.begins_with("--link-dust="):
			link_dust = argument.trim_prefix("--link-dust=").to_int()
		elif argument == "--binds":
			_binds = 1
		elif argument == "--no-binds":
			_binds = 0
		elif argument in ["--quickens", "--ties"]:
			_twists.append(argument.trim_prefix("--"))
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	var stage: Dictionary = _balance.harvest_stages.get(_map, {}).duplicate()
	if every > 0:
		stage["every"] = every
	if link_dust >= 0:
		stage["link_dust_percent"] = link_dust
	if _balance.harvest_every_for(_map) <= 0 and not stage.has("every"):
		stage["every"] = 3
	_balance.harvest_stages[_map] = stage
	_simulate.call_deferred()


func _simulate() -> void:
	var probe: StarMap = _layout(true)
	print("Paired seeds 1..%d; %s; every %d; link dust %d%%; binds %s; twists %s" % [_runs, _map, _balance.harvest_every_for(_map), _balance.harvest_link_dust_percent_for(_map), probe.harvest_binds, _twists])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			if policy not in ["link-first", "launch-first"] and not enabled:
				continue
			var row: Dictionary = {"policy": policy, "harvest": enabled, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "reaped": 0, "unbound": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["reaped_per_run"] = snappedf(float(row.reaped) / _runs, 0.01)
			row["unbound_per_run"] = snappedf(float(row.unbound) / _runs, 0.01)
			for key: String in ["reaped", "unbound", "packs_in_wins"]:
				row.erase(key)
			rows.append(row)
			print("%-13s harvest=%-5s won %5.1f%%  lost %3d  capped %d  packs/win %5.2f  reaped/run %5.2f  put out/run %5.2f" % [policy, enabled, row.win_rate, row.losses, row.capped, row.packs_per_win, row.reaped_per_run, row.unbound_per_run])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/harvest/out"))
	var file: FileAccess = FileAccess.open("res://tools/harvest/out/results-%s.json" % _map, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.by_id(_map)
	if not map.harvest:
		# A borrowed layout: its own rules off.
		map.heat_change = 0
		map.heat_landmarks = false
		map.heat_on_links = false
		map.current_region = Rect2i()
		map.orion = false
		map.volley = ""
		map.hunt = false
		map.boss = false
	map.harvest = enabled
	if _binds >= 0:
		map.harvest_binds = _binds == 1
	map.harvest_quickens = map.harvest_quickens or _twists.has("quickens")
	map.harvest_ties = map.harvest_ties or _twists.has("ties")
	return map


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	run.harvested.connect(func(stars: Array[Star]) -> void: row.reaped += stars.size())
	run.landmarks_unbound.connect(func(indices: Array[int]) -> void: row.unbound += indices.size())
	for action: int in 400:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		var can_launch: bool = run.total_packs() > 0 or run.can_afford("blue")
		if can_launch:
			links = links.filter(func(ids: Array) -> bool: return _takes(run, ids))
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
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
			row.packs_in_wins += packs
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## Whether the policy takes link `ids` now (only asked while a launch is still possible).
func _takes(run: RunState, ids: Array) -> bool:
	if _policy != "bound-strict" or run.harvest == null or not run.harvest.is_next():
		return true
	for id: int in ids:
		if run.scorpio.is_landmark(id) and not _joined(run, Scorpio.landmark_index(id)):
			return false
	return true


## Whether landmark `index` is next to a lit one.
func _joined(run: RunState, index: int) -> bool:
	for n: int in run.scorpio.map.neighbours(index):
		if run.scorpio.is_lit(n):
			return true
	return false


## Just up-left of the first unlit landmark.
func _aim(run: RunState) -> Vector2i:
	var target := Vector2i(90, 160)
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			target = run.scorpio.landmark_position(index) + Vector2i(-12, -18)
			break
	return target


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
				if _policy in ["bound", "bound-strict"] and not _joined(run, Scorpio.landmark_index(id)):
					score -= 80
		if score > best_score:
			best = ids
			best_score = score
	return best
