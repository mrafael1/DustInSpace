class_name BalanceEdit
extends RefCounted
## The debug overlay's edits to the balance (#11), in memory only: balance.json is never written.
## Holds a deep copy of a Balance's source dictionary and names each tunable leaf by its dotted
## path ("packs.blue.cost"), in the file's order: whole numbers, fractions (chances) and switches.
## `build()` re-validates the edits through Balance.from_dict, so an invalid edit is caught the way
## the file is.

## A value's step when nudged: whole numbers by 1; fractions of 0..1 (chances) by CHANCE_STEP;
## other fractions (seconds) by SECONDS_STEP. Editing steps, not tuning.
const CHANCE_STEP: float = 0.01
const SECONDS_STEP: float = 0.5

var data: Dictionary = {}


func _init(balance: Balance) -> void:
	data = balance.source.duplicate(true)
	_normalise(data)


## Every editable leaf's dotted path, in the file's order (notes and other text are left out).
func keys() -> Array[String]:
	var found: Array[String] = []
	_collect(data, "", found)
	return found


func value(key: String) -> Variant:
	var parent: Variant = _parent(key)
	return (parent as Dictionary).get(_leaf(key)) if parent != null else null


## Nudges `key` one step up (`direction` 1) or down (-1): a switch flips. Never below 0; a chance or
## a fraction stays in 0..1. Returns whether the key exists.
func step(key: String, direction: int) -> bool:
	var parent: Variant = _parent(key)
	if parent == null or not (parent as Dictionary).has(_leaf(key)):
		return false
	var leaf: String = _leaf(key)
	var current: Variant = parent[leaf]
	match typeof(current):
		TYPE_BOOL:
			parent[leaf] = not current
		TYPE_INT:
			parent[leaf] = maxi(int(current) + direction, 0)
		TYPE_FLOAT:
			if _is_unit_key(leaf):
				parent[leaf] = clampf(snappedf(float(current) + direction * CHANCE_STEP, CHANCE_STEP), 0.0, 1.0)
			else:
				parent[leaf] = maxf(snappedf(float(current) + direction * SECONDS_STEP, SECONDS_STEP), 0.0)
		_:
			return false
	return true


## The edited balance, validated like the file: check `is_valid()` and `errors`.
func build() -> Balance:
	return Balance.from_dict(data.duplicate(true))


## A value as the overlay shows it: whole numbers plain, fractions to two places, switches ON/OFF.
static func show_value(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "ON" if v else "OFF"
		TYPE_FLOAT:
			return ("%.2f" % v).trim_suffix("0").trim_suffix(".0") if float(v) != floorf(float(v)) else str(int(v))
	return str(v)


func _collect(node: Dictionary, prefix: String, found: Array[String]) -> void:
	for k: Variant in node.keys():
		var v: Variant = node[k]
		if typeof(v) == TYPE_DICTIONARY:
			_collect(v, prefix + str(k) + ".", found)
		elif typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
			found.append(prefix + str(k))


## JSON reads every number as a float: whole ones become whole numbers, so they step by 1, except
## the keys that hold fractions or seconds (a chance of 1.0, 4 seconds).
static func _normalise(node: Dictionary) -> void:
	for k: Variant in node.keys():
		var v: Variant = node[k]
		if typeof(v) == TYPE_DICTIONARY:
			_normalise(v)
		elif typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)) and not _is_float_key(str(k)):
			node[k] = int(v)


## Keys that hold a chance or a fraction: 0..1, nudged by CHANCE_STEP.
static func _is_unit_key(k: String) -> bool:
	return k.ends_with("chance") or k == "fraction"


## Keys that hold fractions even when whole: the 0..1 ones and seconds.
static func _is_float_key(k: String) -> bool:
	return _is_unit_key(k) or k.ends_with("seconds")


func _parent(key: String) -> Variant:
	var parts: PackedStringArray = key.split(".")
	var node: Variant = data
	for i: int in parts.size() - 1:
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(parts[i]):
			return null
		node = node[parts[i]]
	return node if typeof(node) == TYPE_DICTIONARY else null


func _leaf(key: String) -> String:
	return key.get_slice(".", key.get_slice_count(".") - 1)
