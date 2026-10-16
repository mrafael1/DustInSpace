extends SceneTree
## Taurus's red cloth (chapter 8, plan 8A), step A: how often a link could be either a triple or a
## sequence. Paired seeded runs on the built chapter maps through the real RunState, each stage's
## own mechanics on. At every decision point with at least one valid link (traceable, in reach), it
## records which combo kinds the valid links offer: a triple, a sequence, or both. The red cloth's
## choice only exists when both are on offer. Bots are deliberately simple; this is evidence for
## the gate, not a prediction of human play.
## --maps=a,b (default MAPS; maps whose mechanic changes sizes, Leo's heat, are skipped),
## --runs=N, --policies=a,b.
## Policies: link-first links the best link (landmarks first, then dust plus light) before
## launching, aiming just up-left of the first unlit landmark (at its reflection when there's a
## seam); triple-first plays the same, but when a triple and a sequence are both on offer it takes
## the best triple.

const POLICIES: Array[String] = ["link-first", "triple-first"]
const MAPS: Array[String] = [
	"stinger", "tail", "body", "heart", "claws", "final",
	"aquarius_hand", "aquarius_body", "aquarius_legs", "aquarius_stream", "aquarius_jar", "aquarius_final",
	"virgo_head", "virgo_wing", "virgo_robe", "virgo_feet", "virgo_wheat", "virgo_final",
	"sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs", "sagittarius_head", "sagittarius_final",
	"pisces_circlet", "pisces_west_cord", "pisces_knot", "pisces_east_cord", "pisces_north_fish", "pisces_final",
]
## The target, from the first unlit landmark (just up-left of it, as tools/gravity aims).
const TARGET_OFFSET := Vector2i(-12, -18)
const MAX_ACTIONS: int = 400
const OUT_DIR: String = "res://tools/rage/out"

var _balance: Balance
var _runs: int = 300
var _maps: Array[String] = MAPS
var _policies: Array[String] = POLICIES


func _initialize() -> void:
	_balance = Balance.load_file()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs = maxi(1, argument.trim_prefix("--runs=").to_int())
		elif argument.begins_with("--maps="):
			_maps.assign(argument.trim_prefix("--maps=").split(","))
		elif argument.begins_with("--policies="):
			_policies.assign(argument.trim_prefix("--policies=").split(","))
	_measure.call_deferred()


func _measure() -> void:
	print("Paired seeds 1..%d; packs: %s" % [_runs, _pack_odds()])
	var rows: Array[Dictionary] = []
	for map_id: String in _maps:
		var map: StarMap = StarMap.by_id(map_id)
		if map.heat_change != 0:
			print("%-18s skipped: the heat changes sizes" % map_id)
			continue
		for policy: String in _policies:
			var row: Dictionary = _new_row(map_id, policy, _mechanics(map))
			for seed_value: int in range(1, _runs + 1):
				_play(map_id, seed_value, policy, row)
				if seed_value % 25 == 0:
					await process_frame
			_finish(row)
			rows.append(row)
			print("%-18s %-12s decisions %6d  both %5.1f%%  triple only %5.1f%%  sequence only %5.1f%%  links/decision %5.2f  turns with both %5.1f%%  landmark both %5.1f%%  won %5.1f%%  [%s]" % [map_id, policy, row.decisions, row.both_pct, row.triple_only_pct, row.sequence_only_pct, row.links_per_decision, row.turns_with_both_pct, row.landmark_both_pct, row.win_rate, row.mechanics])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var file: FileAccess = FileAccess.open("%s/combo_share.json" % OUT_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  ") + "\n")
	quit()


func _new_row(map_id: String, policy: String, mechanics: String) -> Dictionary:
	return {
		"map": map_id, "policy": policy, "mechanics": mechanics, "decisions": 0, "both": 0,
		"triple_only": 0, "sequence_only": 0, "links": 0, "turns": 0, "turns_with_both": 0,
		"landmark_decisions": 0, "landmark_both": 0, "sequences_linked": 0, "triples_linked": 0,
		"wins": 0, "losses": 0, "capped": 0,
	}


func _finish(row: Dictionary) -> void:
	var decisions: int = maxi(1, row.decisions)
	row["both_pct"] = snappedf(100.0 * row.both / decisions, 0.1)
	row["triple_only_pct"] = snappedf(100.0 * row.triple_only / decisions, 0.1)
	row["sequence_only_pct"] = snappedf(100.0 * row.sequence_only / decisions, 0.1)
	row["links_per_decision"] = snappedf(float(row.links) / decisions, 0.01)
	row["turns_with_both_pct"] = snappedf(100.0 * row.turns_with_both / maxi(1, row.turns), 0.1)
	row["landmark_both_pct"] = snappedf(100.0 * row.landmark_both / maxi(1, row.landmark_decisions), 0.1)
	row["sequence_link_pct"] = snappedf(100.0 * row.sequences_linked / maxi(1, row.sequences_linked + row.triples_linked), 0.1)
	row["win_rate"] = snappedf(100.0 * row.wins / _runs, 0.1)


func _play(map_id: String, seed_value: int, policy: String, row: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run := RunState.new(_balance, rng, Scorpio.HOME_SKY, StarMap.by_id(map_id))
	## Whether the link phase since the last launch has offered both kinds yet.
	var turn_open: bool = false
	var turn_had_both: bool = false
	for action: int in MAX_ACTIONS:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		if not links.is_empty():
			var offer: Dictionary = _offer(run, links)
			_record(row, offer, links.size())
			if not turn_open:
				turn_open = true
				turn_had_both = false
				row.turns += 1
			if offer.triple and offer.sequence and not turn_had_both:
				turn_had_both = true
				row.turns_with_both += 1
			var chosen: Array[int] = _choose(run, links, policy, offer)
			if run.combo_for(chosen) == Combos.SEQUENCE:
				row.sequences_linked += 1
			else:
				row.triples_linked += 1
			run.link(chosen)
			continue
		if not _launch(run):
			break
		turn_open = false
	match run.outcome:
		RunState.Outcome.WON:
			row.wins += 1
		RunState.Outcome.LOST:
			row.losses += 1
		_:
			row.capped += 1


## Which kinds the valid links offer, over every link and over those through an unlit landmark.
func _offer(run: RunState, links: Array[Array]) -> Dictionary:
	var offer: Dictionary = {"triple": false, "sequence": false, "landmark_triple": false, "landmark_sequence": false}
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var kind: String = "sequence" if run.combo_for(ids) == Combos.SEQUENCE else "triple"
		offer[kind] = true
		if _has_landmark(run, ids):
			offer["landmark_" + kind] = true
	return offer


func _record(row: Dictionary, offer: Dictionary, link_count: int) -> void:
	row.decisions += 1
	row.links += link_count
	if offer.triple and offer.sequence:
		row.both += 1
	elif offer.triple:
		row.triple_only += 1
	else:
		row.sequence_only += 1
	if offer.landmark_triple or offer.landmark_sequence:
		row.landmark_decisions += 1
		if offer.landmark_triple and offer.landmark_sequence:
			row.landmark_both += 1


func _choose(run: RunState, links: Array[Array], policy: String, offer: Dictionary) -> Array[int]:
	if policy == "triple-first" and offer.triple and offer.sequence:
		var triples: Array[Array] = []
		for candidate: Array in links:
			var ids: Array[int] = []
			ids.assign(candidate)
			if run.combo_for(ids) != Combos.SEQUENCE:
				triples.append(candidate)
		return _best_link(run, triples)
	return _best_link(run, links)


## Buys and loads a pack if needed, then throws it at the first unlit landmark. False if it can't.
func _launch(run: RunState) -> bool:
	if run.total_packs() == 0:
		var kind: String = "red" if run.can_afford("red") else "blue"
		if not run.buy(kind):
			return false
	if run.loaded_pack == "":
		for kind: String in ["red", "blue"]:
			if run.load_pack(kind):
				break
	return run.launch(run.reflect(_target(run)))


## Just up-left of the first unlit landmark.
func _target(run: RunState) -> Vector2i:
	for index: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(index):
			return run.scorpio.landmark_position(index) + TARGET_OFFSET
	return Vector2i(90, 160)


## Landmarks first, then dust plus light (as tools/reflect and tools/gravity pick).
func _best_link(run: RunState, links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var combo: String = run.combo_for(ids)
		var score: int = run.link_dust(combo) + run.balance.combos[combo].light
		if _has_landmark(run, ids):
			score += 100
		if score > best_score:
			best = ids
			best_score = score
	return best


func _has_landmark(run: RunState, ids: Array[int]) -> bool:
	for id: int in ids:
		if run.scorpio.is_landmark(id):
			return true
	return false


## The stage mechanics that are on, by name.
func _mechanics(map: StarMap) -> String:
	var on: Array[String] = []
	if map.orion:
		on.append("orion")
	if map.volley != "":
		on.append("volley")
	if map.hunt:
		on.append("hunt")
	if map.current_region.has_area():
		on.append("current" + (" drains" if map.current_drains else ""))
	if map.harvest:
		on.append("harvest")
	if map.harvest_binds or map.harvest_ties:
		on.append("binding")
	if map.black_hole:
		on.append("hole")
	if map.black_hole_hungry:
		on.append("hungry")
	if map.black_hole_twins:
		on.append("twins")
	if map.black_hole_gauge:
		on.append("gauge")
	if map.cords:
		on.append("cords")
	if map.seam != StarMap.Seam.NONE:
		on.append("seam " + String(StarMap.Seam.keys()[map.seam]).to_lower())
	if map.splash:
		on.append("splash")
	if map.wave:
		on.append("wave" + (" great" if map.wave_great else ""))
	return ", ".join(on) if not on.is_empty() else "none"


func _pack_odds() -> String:
	var parts: Array[String] = []
	for kind: String in _balance.packs:
		var pack: Balance.PackDef = _balance.packs[kind]
		parts.append("%s %d x%d small/medium/big %s" % [kind, pack.cost, pack.bursts, pack.weights])
	return "; ".join(parts)
