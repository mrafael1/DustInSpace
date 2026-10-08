extends SceneTree
## Paired seeded runs of Virgo's harvest through the spatial core, harvest off and on, on a borrowed
## layout (any StarMap id; its heat, current and threats are switched off). Bots are deliberately
## simple; this is pressure evidence, not a prediction of human difficulty.
## --map=leo_haunch (default), --runs=N, --every=N, --pay=S,M,B, --reaps-new.
## Policies: link-first links every link before launching; launch-first launches every owned pack
## before linking; reaper links only links that light a constellation star while the harvest is
## next, leaving the rest standing to be reaped; landmarks-only never links a link without a
## constellation star; glean lets the field stand (launching, no links) and, on the launch before a
## harvest, first links the links that light a constellation star (the stars the harvest would
## otherwise reap), then launches; sheaf links every link but a triple of loose stars of one size
## while the harvest is next (a sheaf left standing for it); ripe waits for links whose loose stars
## have all ripened, unless the harvest is next (then it links everything before the scythe);
## bound links like link-first but lights the constellation stars next to the lit figure first;
## bound-strict never lights one that isn't next to the lit figure while the harvest is next.
## --policies=a,b picks some; --ripe=N, --binds.

const POLICIES: Array[String] = ["link-first", "launch-first", "reaper", "landmarks-only", "glean", "sheaf", "ripe", "bound", "bound-strict"]
var _policies: Array[String] = POLICIES
var _balance: Balance
var _runs: int = 200
var _map: String = "leo_haunch"
var _policy: String = ""


func _initialize() -> void:
	_balance = Balance.load_file()
	_balance.harvest_every = maxi(_balance.harvest_every, 3)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--map="):
			_map = argument.trim_prefix("--map=")
		elif argument.begins_with("--every="):
			_balance.harvest_every = maxi(1, argument.trim_prefix("--every=").to_int())
		elif argument.begins_with("--pay="):
			var pay: Array[int] = []
			for part: String in argument.trim_prefix("--pay=").split(","):
				pay.append(part.to_int())
			_balance.harvest_pay = pay
		elif argument == "--reaps-new":
			_balance.harvest_reaps_new = true
		elif argument.begins_with("--sheaves="):
			_balance.harvest_sheaf_scale = argument.trim_prefix("--sheaves=").to_int()
		elif argument.begins_with("--cap="):
			_balance.harvest_cap = argument.trim_prefix("--cap=").to_int()
		elif argument.begins_with("--ripe="):
			_balance.harvest_ripe_scale = argument.trim_prefix("--ripe=").to_int()
		elif argument == "--binds":
			_balance.harvest_binds = true
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
		elif argument == "--no-link-dust":
			_balance.harvest_link_dust_percent = 0
		elif argument.begins_with("--link-dust="):
			_balance.harvest_link_dust_percent = argument.trim_prefix("--link-dust=").to_int()
	_simulate.call_deferred()


func _simulate() -> void:
	print("Paired seeds 1..%d; %s; every %d; pay %s; sheaves x%d; cap %d; reaps new %s; link dust %d%%; binds %s" % [_runs, _map, _balance.harvest_every, _balance.harvest_pay, _balance.harvest_sheaf_scale, _balance.harvest_cap, _balance.harvest_reaps_new, _balance.harvest_link_dust_percent, _balance.harvest_binds])
	var rows: Array[Dictionary] = []
	for policy: String in _policies:
		for enabled: bool in [false, true]:
			if policy not in ["link-first", "launch-first"] and not enabled:
				continue
			var row: Dictionary = {"policy": policy, "harvest": enabled, "wins": 0, "losses": 0, "capped": 0, "packs_in_wins": 0, "launches": 0, "reaped": 0, "harvest_dust": 0, "link_dust": 0, "unbound": 0, "ripe": 0}
			for seed_value: int in range(1, _runs + 1):
				_play(seed_value, enabled, policy, row)
				if seed_value % 20 == 0:
					await process_frame
			row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)
			row["packs_per_win"] = snappedf(float(row.packs_in_wins) / maxi(1, row.wins), 0.01)
			row["reaped_per_run"] = snappedf(float(row.reaped) / _runs, 0.01)
			row["harvest_dust_per_run"] = snappedf(float(row.harvest_dust) / _runs, 0.01)
			row["link_dust_per_run"] = snappedf(float(row.link_dust) / _runs, 0.01)
			row["unbound_per_run"] = snappedf(float(row.unbound) / _runs, 0.01)
			row["ripe_links_per_run"] = snappedf(float(row.ripe) / _runs, 0.01)
			for key: String in ["reaped", "harvest_dust", "link_dust", "packs_in_wins", "launches", "unbound", "ripe"]:
				row.erase(key)
			rows.append(row)
			print(JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/harvest/out"))
	var file: FileAccess = FileAccess.open("res://tools/harvest/out/results-%s.json" % _map, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _layout(enabled: bool) -> StarMap:
	var map: StarMap = StarMap.by_id(_map)
	map.heat_change = 0
	map.heat_landmarks = false
	map.heat_on_links = false
	map.current_region = Rect2i()
	map.orion = false
	map.volley = ""
	map.hunt = false
	map.boss = false
	map.harvest = enabled
	return map


func _play(seed_value: int, enabled: bool, policy: String, row: Dictionary) -> void:
	_policy = policy
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, _layout(enabled))
	var packs: int = 0
	run.harvested.connect(func(stars: Array[Star], dust: int) -> void:
		row.reaped += stars.size()
		row.harvest_dust += dust)
	run.combo_collected.connect(func(_combo: String, linked: Array[Star], dust: int, _light: int) -> void:
		row.link_dust += dust
		row.ripe += int(run.is_ripe(linked)))
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
		row.launches += 1
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
	var lights: bool = false
	for id: int in ids:
		lights = lights or run.scorpio.is_landmark(id)
	match _policy:
		"reaper":
			return lights or run.harvest == null or not run.harvest.is_next()
		"landmarks-only":
			return lights
		"glean":
			return lights and run.harvest != null and run.harvest.is_next()
		"bound-strict":
			if run.harvest == null or not run.harvest.is_next():
				return true
			for id: int in ids:
				if run.scorpio.is_landmark(id) and not _joined(run, Scorpio.landmark_index(id)):
					return false
			return true
		"ripe":
			return run.harvest == null or run.harvest.is_next() or run.is_ripe(_stars_of(run, ids))
		"sheaf":
			if lights or run.harvest == null or not run.harvest.is_next():
				return true
			var size: int = run.find_star(ids[0]).size
			return not (run.find_star(ids[1]).size == size and run.find_star(ids[2]).size == size)
	return true


## Whether landmark `index` is next to a lit one.
func _joined(run: RunState, index: int) -> bool:
	for n: int in run.scorpio.map.neighbours(index):
		if run.scorpio.is_lit(n):
			return true
	return false


func _stars_of(run: RunState, ids: Array) -> Array[Star]:
	var found: Array[Star] = []
	for id: int in ids:
		found.append(run.scorpio.landmark_star(Scorpio.landmark_index(id)) if run.scorpio.is_landmark(id) else run.find_star(id))
	return found


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
		var score: int = run.balance.combos[combo].dust + run.balance.combos[combo].light
		for id: int in ids:
			if run.scorpio.is_landmark(id):
				score += 100
				if _policy in ["bound", "bound-strict"] and not _joined(run, Scorpio.landmark_index(id)):
					score -= 80
		if score > best_score:
			best = ids
			best_score = score
	return best
