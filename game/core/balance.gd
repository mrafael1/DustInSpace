class_name Balance
extends RefCounted
## Loads and validates game/config/balance.json. Every tuning number the game uses comes from here.
## Loading never crashes: problems are collected in `errors`, and callers check `is_valid()`.

const DEFAULT_PATH: String = "res://game/config/balance.json"
const COMBO_KEYS: Array[String] = ["small_triple", "medium_triple", "big_triple", "sequence"]


class PackDef:
	extends RefCounted
	var kind: String = ""
	var cost: int = 0
	var stars: int = 0
	## Indexed by Star.Size (small, medium, big).
	var weights: Array[int] = [0, 0, 0]
	var big_bang_chance: float = 0.0


class ComboReward:
	extends RefCounted
	var dust: int = 0
	var light: int = 0


var sun_target: int = 0
var start_dust: int = 0
var start_packs: Dictionary[String, int] = {}
var packs: Dictionary[String, PackDef] = {}
var combos: Dictionary[String, ComboReward] = {}
var big_bang_base_dust: int = 0
var big_bang_dust_per_cleared_star: int = 0
var errors: Array[String] = []


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
