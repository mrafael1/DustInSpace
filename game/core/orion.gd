class_name Orion
extends RefCounted
## Orion the hunter (#64), the Tail stage's twist: from its intro launch on he keeps one loose sky
## star (never a landmark) marked, and the next successful link decides its fate. A link that uses
## the marked star saves it; a link that leaves it behind makes his arrow destroy it, for nothing.
## Either way he marks a new star once the link resolves. A launch never fires: it only adds stars,
## and marks one if none is marked. Invalid links, aiming and purchases don't move him. A Sun clear,
## the completion or a Big Bang taking the marked star leaves nothing to shoot. At most one mark at
## a time. Targets are drawn at random from their own RNG stream: some marks can't be saved, and
## nothing guarantees a rescue.
## Pure state; RunState applies it inside launch() and link() so each stays one atomic step.

## XOR'd into the run seed so Orion's picks have their own stream and never shift packs or layout.
const SEED_SALT: int = 0x0810A

## The launch whose burst Orion marks first (balance.json orion.first_mark_launch).
var first_mark_launch: int = 0
## Packs launched so far this run.
var launches: int = 0
## The id of the marked star, or 0 when none is marked.
var target: int = 0

var _rng := RandomNumberGenerator.new()


func _init(p_first_mark_launch: int, run_seed: int) -> void:
	first_mark_launch = p_first_mark_launch
	_rng.seed = run_seed ^ SEED_SALT


func has_target() -> bool:
	return target != 0


func is_target(id: int) -> bool:
	return target != 0 and id == target


## A pack is being launched: counts it. No arrow.
func count_launch() -> void:
	launches += 1


## A successful link left the marked star behind: hands back its id to shoot (0: none), clearing
## the mark. The caller checks the star is still in the sky.
func draw_bow() -> int:
	var shot: int = target
	target = 0
	return shot


## After a move (a launch's burst with no mark, or any successful link): marks one of `loose` (the
## sky's stars, landmarks never in it) from the intro launch on. Returns the marked id, or 0 when
## it's too early or nothing can be marked.
func mark(loose: Array[Star]) -> int:
	if launches < first_mark_launch or loose.is_empty():
		return 0
	target = loose[_rng.randi_range(0, loose.size() - 1)].id
	return target


## The marked star left the sky some other way (a combo, a Sun clear, a Big Bang).
func forget(ids: Array[int]) -> void:
	if ids.has(target):
		target = 0
