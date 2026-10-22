extends GutTest
## The portrait identity guard (docs/wide_sky_design.md §6): the wide sky must leave portrait play
## byte-identical. Every map is played by a fixed bot for seeds 1-SEEDS on the 9:16 sky and on a tall
## phone's (play_sky(TALL_ROWS)): its intros as Main plays them, the guide spots, then links and
## launches until the run ends. Every signal the run emits (stars, moves, falls, payouts, outcome)
## and the dust, light and stars left go into one digest per map and sky, recorded before the wide
## sky was built. A change to the shipped balance (game/config/balance.json) changes play, so it
## needs the digests recorded again: the failure message prints the new table.

const Fixtures := preload("res://tests/fixtures.gd")

const SEEDS: int = 20
## A tall phone's extra rows above the 9:16 screen (as test_scorpio uses).
const TALL_ROWS: int = 102
const MAX_ACTIONS: int = 300
## The bot aims just up-left of the first unlit landmark (as tools/rage and tools/gravity aim).
const TARGET_OFFSET := Vector2i(-12, -18)
## Every map by_id knows, the chapters' whole figures included.
const MAP_IDS: Array[String] = [
	"scorpio", "stinger", "tail", "body", "heart", "claws", "final",
	"aquarius", "aquarius_hand", "aquarius_body", "aquarius_legs", "aquarius_stream", "aquarius_jar", "aquarius_final",
	"leo", "leo_tail", "leo_haunch", "leo_heart", "leo_mane", "leo_head", "leo_final",
	"virgo", "virgo_head", "virgo_wing", "virgo_robe", "virgo_feet", "virgo_wheat", "virgo_final",
	"sagittarius", "sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs", "sagittarius_head", "sagittarius_final",
	"pisces", "pisces_circlet", "pisces_west_cord", "pisces_knot", "pisces_east_cord", "pisces_north_fish", "pisces_final",
	"aries", "aries_horns", "aries_head", "aries_fleece", "ram_trial",
]
## The debug trials, which by_id doesn't build.
const TRIAL_IDS: Array[String] = ["current_trial", "current_aquarius", "black_hole_trial", "cord_trial"]
## md5 per "map@sky", recorded on the portrait code before the wide sky.
const EXPECTED: Dictionary[String, String] = {
	"scorpio@home": "be318173f26f0f5ece7a5412c058dad8",
	"stinger@home": "70973ab19d11cc58ae2e186fd0afcb49",
	"tail@home": "c68cfafe921bed8ce94cbcf7b700fdb1",
	"body@home": "f12d34ad3fe83c8b25f6b02ffa44c9e5",
	"heart@home": "d36292826a9ccea9f9392b38f960921c",
	"claws@home": "e4ed15b38b764caf06d0eeaab0cd399e",
	"final@home": "cfdc9b0a66de4957807a8e37df33aec6",
	"aquarius@home": "21fdb2cfb757f17dd94df0b7cf4169d5",
	"aquarius_hand@home": "2068e2f3f8e3fd396d2779f429cfa176",
	"aquarius_body@home": "1d4fde309dd831e190601ab6b74124a6",
	"aquarius_legs@home": "88a455abbdd49b99249d0b2f178b431f",
	"aquarius_stream@home": "6a28942e562ff186bb0d8216fe522325",
	"aquarius_jar@home": "e4b365d09763706ce690834444131e79",
	"aquarius_final@home": "7ccfbbeb33bc35c79ddb05096932de38",
	"leo@home": "f2f3da5c5fdcd09e84db81bcc5895bb5",
	"leo_tail@home": "e834ac52abc7fc20ff1490d12a290579",
	"leo_haunch@home": "1568fb71e3fc0f519382fdde9ceb00e0",
	"leo_heart@home": "4e185a9289d2ec6f7847113f9fd64f82",
	"leo_mane@home": "57eb30b78dc1566fe115beb117a56ac1",
	"leo_head@home": "b6d768a9352d0fcbea2eb30a79056931",
	"leo_final@home": "67f63a770ced9a87409031ce9fa0ce8f",
	"virgo@home": "ea09b4e1006c4be68091e7f02d5ebbcd",
	"virgo_head@home": "bab944845b26ae75a42be33033918167",
	"virgo_wing@home": "85a19c9d38ad3535cada1c532b3b09d0",
	"virgo_robe@home": "33dc2f8c80d7a1b881cb074ca2924441",
	"virgo_feet@home": "316fc26a0fae3cf79c9e8011e8a69e36",
	"virgo_wheat@home": "1985792c7f3756b73e1d152b863111aa",
	"virgo_final@home": "16070275d468679acaacde25a54b6f06",
	"sagittarius@home": "d2ed5efc739b8641f66e3accb9a2d83f",
	"sagittarius_arrow@home": "1d6c822efde2707ecda9807fae91dfdd",
	"sagittarius_bow@home": "ede5514c7dd5c3e9c8391e43102abe76",
	"sagittarius_body@home": "7af01e15ffb55a341b71c523f3e0c399",
	"sagittarius_legs@home": "6e42706aa7f89d3106542fe502b49188",
	"sagittarius_head@home": "6957cd92aa815dcd7ae4228208d0475f",
	"sagittarius_final@home": "e1298c4ea8ee4300d07e4499aaec7572",
	"pisces@home": "ca6545361552256020b6c8db9c4b2482",
	"pisces_circlet@home": "64625031cfe01e7198eea39a0c47d65a",
	"pisces_west_cord@home": "7fcdf9b41c2dd5447c8e1ae254ac0d54",
	"pisces_knot@home": "b7d172620069bc2a516deeeacc0e4d5b",
	"pisces_east_cord@home": "577027bec0dbccba40ae2b9bd5b4f396",
	"pisces_north_fish@home": "9dd8153bccdf7c137eb9fdece2440dea",
	"pisces_final@home": "376518c295a36c55a30094c4839660d3",
	"aries@home": "e9c0d20ea5b3bd0b5e3514dd01166b6f",
	"aries_horns@home": "791df68ad706f51400b9b59a2f2ffb43",
	"aries_head@home": "54fb6edd2431fdf19e243c0601bbf7a2",
	"aries_fleece@home": "ebc924be0597abb0bc9b56aca611f63c",
	"ram_trial@home": "9e380ff0cbb62777dd735d5ab74a405e",
	"current_trial@home": "c8bced78a9e5ad1286877a9932ea437a",
	"current_aquarius@home": "0e218f48fce2761937dafc160e4ee5d5",
	"black_hole_trial@home": "d62ee9f06f70e22415d0ddb959e37b43",
	"cord_trial@home": "97659698e576d2fe07027798bcfefc18",
	"scorpio@tall": "546c5914dfec62496a31729261e3a0ee",
	"stinger@tall": "80c86a3cc7938ed645c0efabf9ac0dfb",
	"tail@tall": "3b5fb06ac8550d0c984b454f2031e2fd",
	"body@tall": "13a109fa8959cd9e7192a668cdfd4256",
	"heart@tall": "6eb2e27d2a88c872ac4f5196026d1be9",
	"claws@tall": "5664ce7cb879f1e023ab49a6c4c60fcf",
	"final@tall": "5448fd446a42fd29df80b46cc64aeb8d",
	"aquarius@tall": "165fa4f5902a80d05c3dd4549a834b4a",
	"aquarius_hand@tall": "616c19e08728b540995861a8318da561",
	"aquarius_body@tall": "98d8aaca418499d871277320c45ef6cc",
	"aquarius_legs@tall": "caf7738d17b1748998fcccb86a512ec8",
	"aquarius_stream@tall": "618cb1ca8da67367e97503092147337b",
	"aquarius_jar@tall": "8cb291f3494bd4d59c89222d2f89f91c",
	"aquarius_final@tall": "a957e684464aa080ddf486ad6e0e50d2",
	"leo@tall": "86282ce808cdf88e6780dd41c1ab1dd3",
	"leo_tail@tall": "6559e6876ef3f8c51ac772df0e9906bd",
	"leo_haunch@tall": "cd00806db5cdcb39e6c51aee4962d9d0",
	"leo_heart@tall": "2a12fb08010eb50634069841bf0eb223",
	"leo_mane@tall": "95c7ceb2afc032ad73be2d92bc0c28f4",
	"leo_head@tall": "c5862b0c8a99355a57423767ae73242b",
	"leo_final@tall": "262c36ead24bdbefd3a1e0b948b3886e",
	"virgo@tall": "28b6308817c6ef00964aebdb5095b9ee",
	"virgo_head@tall": "d682cd8ca7a5ce63914960c6a2d5d3cd",
	"virgo_wing@tall": "63252d3272dff3a9ea2c6efc1793ead6",
	"virgo_robe@tall": "38b167aa8cb28ce19353666f29cfac53",
	"virgo_feet@tall": "b7ce4d5f623adc4ef03d64a05087b42d",
	"virgo_wheat@tall": "70ebd1c8b3e472e01534216cbc1c8e26",
	"virgo_final@tall": "5cdcf0c83d61c66db03029981247ea67",
	"sagittarius@tall": "62a767267957c49dc4aea4d1b655099c",
	"sagittarius_arrow@tall": "db0ebcc68a21e738493208a8f7e399df",
	"sagittarius_bow@tall": "f169f5a78dd9b801d97870edd69911a9",
	"sagittarius_body@tall": "f4bfb1563db60e7e4862a8bafd332be0",
	"sagittarius_legs@tall": "f6750e1746b9b6f737259667e3cc1319",
	"sagittarius_head@tall": "4867bff56215bfe35bf370efbb834901",
	"sagittarius_final@tall": "911daf5ef8adf22a4d3eefe4166da870",
	"pisces@tall": "8e30e187b078a25bb61e0006314f6ea4",
	"pisces_circlet@tall": "28452539b05b83f01edc922ec75f9fd9",
	"pisces_west_cord@tall": "30c704e1da1818178c16663211296e96",
	"pisces_knot@tall": "e512dcdca28b9427d636f4e402e01ac0",
	"pisces_east_cord@tall": "ac8e05f4574c362241f3ba16dd03a9d9",
	"pisces_north_fish@tall": "189493fbc03491da567f52167943afe9",
	"pisces_final@tall": "ee6579215ad2e1216ee4d819f34a1653",
	"aries@tall": "ea4333ad05590a0c7d7e10f7c3a65ff9",
	"aries_horns@tall": "da1228553da02539a22d0850ec8d3109",
	"aries_head@tall": "818840f357ed52ee43b117c5afd2a02b",
	"aries_fleece@tall": "b9734e3328d634454cb5b1dd033ead1d",
	"ram_trial@tall": "0f9c173f14543e45865f80e47b3b588f",
	"current_trial@tall": "e0c8da1018286761dd34ca3754103c8d",
	"current_aquarius@tall": "1a286284d75633b93fd9689bc6401976",
	"black_hole_trial@tall": "324142f4e70fa939471aa69e473a2a0d",
	"cord_trial@tall": "d1991d350c542a288c55755bd3d577da",
}

var _balance: Balance = Balance.load_file()


func test_every_map_plays_as_it_did_on_the_9_16_sky() -> void:
	_assert_identical(Fixtures.SKY, "home")


func test_every_map_plays_as_it_did_on_a_tall_phones_sky() -> void:
	_assert_identical(ScreenZones.play_sky(TALL_ROWS), "tall")


func _assert_identical(sky: Rect2i, label: String) -> void:
	var changed: Array[String] = []
	var table: Array[String] = []
	for map_id: String in MAP_IDS + TRIAL_IDS:
		var key: String = "%s@%s" % [map_id, label]
		var digest: String = _digest(map_id, sky)
		table.append('\t"%s": "%s",' % [key, digest])
		if EXPECTED.get(key, "") != digest:
			changed.append(key)
	if not changed.is_empty():
		gut.p("Digests on this code:\n" + "\n".join(table))
	assert_eq(changed, [] as Array[String], "every map plays exactly as recorded on the %s sky" % label)


func _digest(map_id: String, sky: Rect2i) -> String:
	var log: PackedStringArray = []
	for seed_value: int in range(1, SEEDS + 1):
		log.append("seed %d" % seed_value)
		_play(_map(map_id), seed_value, sky, log)
	return "\n".join(log).md5_text()


func _map(map_id: String) -> StarMap:
	match map_id:
		"current_trial":
			return StarMap.current_trial()
		"current_aquarius":
			return StarMap.aquarius_flow()
		"black_hole_trial":
			return StarMap.black_hole_trial()
		"cord_trial":
			return StarMap.cord_trial()
	return StarMap.by_id(map_id)


func _play(map: StarMap, seed_value: int, sky: Rect2i, log: PackedStringArray) -> void:
	var run := RunState.new(_balance, Fixtures.rng(seed_value), sky, map)
	for info: Dictionary in run.get_signal_list():
		var name: String = info.name
		run.connect(name, func(...args: Array) -> void: log.append(name + " " + _describe(args)))
	_play_intros(run)
	_log_guide_spots(run, log)
	var launched: bool = false
	for action: int in MAX_ACTIONS:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		if not links.is_empty():
			log.append("link %s" % run.link(_best_link(run, links)))
			continue
		if run.hunt != null:
			log.append("safe %s" % run.safe_launch_spot())
		if not _launch(run):
			break
		if not launched:
			launched = true
			_log_guide_spots(run, log)
	log.append("end %d %d %d %s %s" % [run.outcome, run.dust, run.light, _describe(run.stars), _describe(run.scorpio.lit if run.scorpio != null else [])])


## The intros in the order Main plays them as a stage opens.
func _play_intros(run: RunState) -> void:
	run.play_boss_intro()
	run.play_volley_intro()
	run.play_hunt_intro()
	run.play_heat_intro()
	run.play_harvest_intro()
	run.play_current_intro()
	run.play_hole_intro()
	run.play_twins_intro()
	run.play_gauge_intro()
	run.play_reflect_intro()
	run.play_ram_intro()


## The guides' spots (the hunt's encounter and the guided run's launch), and the ram intro's layout.
func _log_guide_spots(run: RunState, log: PackedStringArray) -> void:
	log.append("guide %s %s" % [run.safe_launch_spot(), run.open_launch_spot(run.sky_rect.position.y)])
	if run.ram != null and run.scorpio != null:
		log.append("ram layout %s" % [run.ram_intro_layout()])
	if run.gravity != null:
		log.append("hole spots %s" % [run.hole_intro_spots()])


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


func _target(run: RunState) -> Vector2i:
	if run.scorpio != null:
		for index: int in run.scorpio.map.count():
			if not run.scorpio.is_lit(index):
				return run.scorpio.landmark_position(index) + TARGET_OFFSET
	return run.sky_rect.get_center()


## Landmarks first, then dust plus light; the first of equals.
func _best_link(run: RunState, links: Array[Array]) -> Array[int]:
	var best: Array[int] = []
	var best_score: int = -1
	for candidate: Array in links:
		var ids: Array[int] = []
		ids.assign(candidate)
		var combo: String = run.combo_for(ids)
		var score: int = run.link_dust(combo) + run.balance.combos[combo].light
		if run.scorpio != null and ids.any(func(id: int) -> bool: return run.scorpio.is_landmark(id)):
			score += 100
		if score > best_score:
			best = ids
			best_score = score
	return best


## A value as text that doesn't depend on object ids: stars by id, size and position; other objects
## by their script variables.
func _describe(value: Variant) -> String:
	if value is Star:
		return "S%d/%d%s" % [value.id, value.size, value.position]
	if value is Object:
		var parts: Array[String] = []
		for property: Dictionary in (value as Object).get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				parts.append("%s=%s" % [property.name, _describe((value as Object).get(property.name))])
		return "{%s}" % ", ".join(parts)
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value:
			items.append(_describe(item))
		return "[%s]" % ", ".join(items)
	if value is Dictionary:
		var entries: Array[String] = []
		for key: Variant in value:
			entries.append("%s: %s" % [_describe(key), _describe(value[key])])
		return "{%s}" % ", ".join(entries)
	return str(value)
