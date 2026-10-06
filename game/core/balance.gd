class_name Balance
extends RefCounted
## Loads and validates game/config/balance.json. Every tuning number the game uses comes from here.
## Loading never crashes: problems are collected in `errors`, and callers check `is_valid()`.

const DEFAULT_PATH: String = "res://game/config/balance.json"
const COMBO_KEYS: Array[String] = ["small_triple", "medium_triple", "big_triple", "sequence"]
## The volley blocks a map can name (StarMap.volley): the Body's so far.
const VOLLEY_BLOCKS: Array[String] = ["volley"]


class PackDef:
	extends RefCounted
	var kind: String = ""
	var cost: int = 0
	## Stars per burst.
	var stars: int = 0
	## How many bursts the pack splits into (the red pack's twin burst): one aim, `bursts` burst
	## points `burst_spread` px apart across it, each with `stars` stars. Optional: 1.
	var bursts: int = 1
	var burst_spread: int = 0
	## Indexed by Star.Size (small, medium, big).
	var weights: Array[int] = [0, 0, 0]
	var big_bang_chance: float = 0.0


class ComboReward:
	extends RefCounted
	var dust: int = 0
	var light: int = 0


## One volley's tuning: successful links between volleys, the share of loose stars each destroys
## (rounded up), and the stars already in the sky when its stage opens, which an intro volley
## destroys (0: no intro).
class VolleyDef:
	extends RefCounted
	var interval: int = 0
	var fraction: float = 0.0
	var intro_stars: int = 0


var sun_target: int = 0
var start_dust: int = 0
var start_packs: Dictionary[String, int] = {}
var packs: Dictionary[String, PackDef] = {}
var combos: Dictionary[String, ComboReward] = {}
var big_bang_base_dust: int = 0
var big_bang_dust_per_cleared_star: int = 0
## The Scorpio map (#40, a prototype). Optional in the file: without a "scorpio" block it's off.
var scorpio_enabled: bool = false
## Dust per star a rekindled Sun bursts.
var scorpio_sun_dust_per_star: int = 0
## The light that fills the Sun on the Scorpio map (it rekindles there). Optional: 0 = sun_target.
var scorpio_sun_target: int = 0
## The light that fills the Sun the first time in the guided first run, so the player sees a full
## Sun light a star before the stage ends. Optional: 0 = the stage's own target.
var scorpio_tutorial_sun_target: int = 0
## The longest step (native px) between consecutive stars in a link on the Scorpio map.
## Optional: 0 = no limit.
var scorpio_max_link_distance: int = 0
## Whether packs can open as a Big Bang on a constellation stage. Optional: true. The debug trigger
## still forces one.
var scorpio_big_bang: bool = true
## Orion (#64): the launch whose burst Orion marks first, on maps that bring him (the Tail).
## Optional in the file: without an "orion" block he never marks (0).
var orion_first_mark_launch: int = 0
## Orion's volleys (#70), by block name: each map that brings one names its block (the Body's is
## "volley"). Optional: without its block a map has no volley.
var volleys: Dictionary[String, VolleyDef] = {}
## Orion's hunting area (#71), on maps that bring it (the Heart): the circle's radius in native px.
## Optional: without a "hunt" block there is none (0).
var hunt_radius: int = 0
## The stars already in the circle when the hunt's stage opens, before its intro's demo launch.
## Optional in the block: 0 = no intro.
var hunt_intro_stars: int = 0
## The idle hint (#90): seconds without interaction (animations aside) before a valid link shines.
## Optional: without a "hints" block there is none (0).
var hint_idle_seconds: float = 0.0
## Native pixels a current moves stars per launch; absent means no current. A stage can have its
## own (current_steps, by StarMap id: chapter 2's stages ramp up), else it uses this one.
var current_step: int = 0
var current_steps: Dictionary[String, int] = {}

var errors: Array[String] = []


## How far the current moves stars per launch on the stage playing map `map_id` (0: no current).
func current_step_for(map_id: String) -> int:
	return current_steps.get(map_id, current_step)


static func load_file(path: String = DEFAULT_PATH) -> Balance:
	var balance := Balance.new()
	if not FileAccess.file_exists(path):
		balance.errors.append("balance file not found: %s" % path)
		return balance
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		balance.errors.append("invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return balance
	if typeof(json.data) != TYPE_DICTIONARY:
		balance.errors.append("balance root must be an object")
		return balance
	balance._parse(json.data)
	return balance


static func from_dict(data: Dictionary) -> Balance:
	var balance := Balance.new()
	balance._parse(data)
	return balance


func is_valid() -> bool:
	return errors.is_empty()


## Pack kinds in the order they appear in the file (blue, red).
func pack_kinds() -> Array[String]:
	var kinds: Array[String] = []
	kinds.assign(packs.keys())
	return kinds


## The volley tuned by `block`, or null when the file has no such block.
func volley(block: String) -> VolleyDef:
	return volleys.get(block)


func cheapest_pack_cost() -> int:
	var cheapest: int = -1
	for pack: PackDef in packs.values():
		if cheapest < 0 or pack.cost < cheapest:
			cheapest = pack.cost
	return cheapest


func _parse(data: Dictionary) -> void:
	sun_target = _read_int(data, "sun_target", "", 1)
	start_dust = _read_int(data, "start_dust", "", 0)
	_parse_packs(_read_dict(data, "packs", ""))
	_parse_start_packs(_read_dict(data, "start_packs", ""))
	_parse_combos(_read_dict(data, "combos", ""))
	var big_bang: Dictionary = _read_dict(data, "big_bang", "")
	big_bang_base_dust = _read_int(big_bang, "base_dust", "big_bang.", 0)
	big_bang_dust_per_cleared_star = _read_int(big_bang, "dust_per_cleared_star", "big_bang.", 0)
	if data.has("scorpio"):
		_parse_scorpio(_read_dict(data, "scorpio", ""))
	if data.has("orion"):
		orion_first_mark_launch = _read_int(_read_dict(data, "orion", ""), "first_mark_launch", "orion.", 1)
	if data.has("hunt"):
		var hunt: Dictionary = _read_dict(data, "hunt", "")
		hunt_radius = _read_int(hunt, "radius", "hunt.", 1)
		if hunt.has("intro_stars"):
			hunt_intro_stars = _read_int(hunt, "intro_stars", "hunt.", 0)
	if data.has("hints"):
		hint_idle_seconds = _read_seconds(_read_dict(data, "hints", ""), "idle_seconds", "hints.")
	if data.has("currents"):
		var currents: Dictionary = _read_dict(data, "currents", "")
		current_step = _read_int(currents, "step", "currents.", 1)
		if currents.has("stages"):
			var stages: Dictionary = _read_dict(currents, "stages", "currents.")
			for map_id: Variant in stages:
				current_steps[str(map_id)] = _read_int(stages, map_id, "currents.stages.", 1)
	for block: String in VOLLEY_BLOCKS:
		if data.has(block):
			volleys[block] = _parse_volley(_read_dict(data, block, ""), block + ".")


func _parse_packs(raw: Dictionary) -> void:
	if raw.is_empty():
		errors.append("packs: at least one pack is required")
		return
	for kind: Variant in raw.keys():
		var ctx: String = "packs.%s." % kind
		var entry: Dictionary = _read_dict(raw, kind, "packs.")
		var pack := PackDef.new()
		pack.kind = str(kind)
		pack.cost = _read_int(entry, "cost", ctx, 1)
		pack.stars = _read_int(entry, "stars", ctx, 1)
		pack.big_bang_chance = _read_chance(entry, "big_bang_chance", ctx)
		if entry.has("bursts"):
			pack.bursts = _read_int(entry, "bursts", ctx, 1)
			pack.burst_spread = _read_int(entry, "burst_spread", ctx, 1) if pack.bursts > 1 else 0
		var raw_weights: Dictionary = _read_dict(entry, "weights", ctx)
		pack.weights = [
			_read_int(raw_weights, "small", ctx + "weights.", 0),
			_read_int(raw_weights, "medium", ctx + "weights.", 0),
			_read_int(raw_weights, "big", ctx + "weights.", 0),
		]
		if pack.weights[0] + pack.weights[1] + pack.weights[2] <= 0:
			errors.append(ctx + "weights: must have a positive total")
		packs[pack.kind] = pack


func _parse_start_packs(raw: Dictionary) -> void:
	for kind: Variant in raw.keys():
		if not packs.has(str(kind)):
			errors.append("start_packs.%s: unknown pack kind" % kind)
			continue
		start_packs[str(kind)] = _read_int(raw, kind, "start_packs.", 0)


func _parse_combos(raw: Dictionary) -> void:
	for key: String in COMBO_KEYS:
		var ctx: String = "combos.%s." % key
		var entry: Dictionary = _read_dict(raw, key, "combos.")
		var reward := ComboReward.new()
		reward.dust = _read_int(entry, "dust", ctx, 0)
		reward.light = _read_int(entry, "light", ctx, 0)
		combos[key] = reward


func _parse_volley(raw: Dictionary, ctx: String) -> VolleyDef:
	var def := VolleyDef.new()
	def.interval = _read_int(raw, "interval", ctx, 1)
	def.fraction = _read_chance(raw, "fraction", ctx)
	if raw.has("fraction") and def.fraction <= 0.0:
		errors.append(ctx + "fraction: must be above 0")
	if raw.has("intro_stars"):
		def.intro_stars = _read_int(raw, "intro_stars", ctx, 0)
	return def


func _parse_scorpio(raw: Dictionary) -> void:
	if not raw.has("enabled") or typeof(raw["enabled"]) != TYPE_BOOL:
		errors.append("scorpio.enabled: must be true or false")
	else:
		scorpio_enabled = raw["enabled"]
	scorpio_sun_dust_per_star = _read_int(raw, "sun_dust_per_star", "scorpio.", 0)
	if raw.has("sun_target"):
		scorpio_sun_target = _read_int(raw, "sun_target", "scorpio.", 1)
	if raw.has("tutorial_sun_target"):
		scorpio_tutorial_sun_target = _read_int(raw, "tutorial_sun_target", "scorpio.", 1)
	if raw.has("max_link_distance"):
		scorpio_max_link_distance = _read_int(raw, "max_link_distance", "scorpio.", 1)
	if raw.has("big_bang"):
		if typeof(raw["big_bang"]) != TYPE_BOOL:
			errors.append("scorpio.big_bang: must be true or false")
		else:
			scorpio_big_bang = raw["big_bang"]


func _read_dict(data: Dictionary, key: Variant, ctx: String) -> Dictionary:
	if not data.has(key):
		errors.append("%s%s: missing" % [ctx, key])
		return {}
	if typeof(data[key]) != TYPE_DICTIONARY:
		errors.append("%s%s: must be an object" % [ctx, key])
		return {}
	return data[key]


func _read_int(data: Dictionary, key: Variant, ctx: String, minimum: int) -> int:
	if not data.has(key):
		errors.append("%s%s: missing" % [ctx, key])
		return minimum
	var value: Variant = data[key]
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		errors.append("%s%s: must be a number" % [ctx, key])
		return minimum
	if typeof(value) == TYPE_FLOAT and float(value) != floorf(float(value)):
		errors.append("%s%s: must be a whole number, got %s" % [ctx, key, value])
		return minimum
	if int(value) < minimum:
		errors.append("%s%s: must be >= %d, got %s" % [ctx, key, minimum, value])
		return minimum
	return int(value)


func _read_seconds(data: Dictionary, key: String, ctx: String) -> float:
	if not data.has(key):
		errors.append("%s%s: missing" % [ctx, key])
		return 0.0
	var value: Variant = data[key]
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		errors.append("%s%s: must be a number" % [ctx, key])
		return 0.0
	if float(value) <= 0.0:
		errors.append("%s%s: must be above 0, got %s" % [ctx, key, value])
		return 0.0
	return float(value)


func _read_chance(data: Dictionary, key: String, ctx: String) -> float:
	if not data.has(key):
		errors.append("%s%s: missing" % [ctx, key])
		return 0.0
	var value: Variant = data[key]
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		errors.append("%s%s: must be a number" % [ctx, key])
		return 0.0
	if float(value) < 0.0 or float(value) > 1.0:
		errors.append("%s%s: must be between 0 and 1, got %s" % [ctx, key, value])
		return 0.0
	return float(value)
