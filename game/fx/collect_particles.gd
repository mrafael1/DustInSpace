class_name CollectParticles
extends Node2D
## Payouts travel (game-feel): when a combo_collected event plays, dust particles fly from the
## linked stars to the dust counter and light particles fly into the Sun. Each particle carries
## part of the reward; `dust_arrived` / `light_arrived` fire as it lands, so the counters tick up
## on arrival. Particles never hold the sequencer, so input comes back while they fly.
## Juice: each particle first pops a few pixels away from its star (anticipation), then swooshes
## into its counter, and every landing throws a few tiny sparks at the counter.
## Owns no rules: the amounts come from the event. Every particle is 1-2 palette pixels on
## whole pixels: a head and a one-step-darker trail.

signal dust_arrived(amount: int)
signal light_arrived(amount: int)

enum Kind { DUST, LIGHT }

## Particles leave once the link has flared and dissolved.
const LAUNCH_DELAY: float = StarView.DISSOLVE_TIME
## Game-feel timings: staggered ~28 ms each, 750-1100 ms along a Bézier path.
const STAGGER: float = 0.028
const FLIGHT_MIN: float = 0.75
const FLIGHT_MAX: float = 1.1
## A reward bigger than this is shared between this many particles, so a big payout stays quick.
const MAX_PARTICLES: int = 10
## How far the path bows sideways at its middle, at most.
const MAX_BOW: int = 30
## Anticipation: the first part of a flight pops the particle this far out from its star.
const POP_SHARE: float = 0.18
const POP_MIN: int = 5
const POP_MAX: int = 10
## Landing sparks: a few pixels thrown from the landing point, cooling down the kind's ramp.
const IMPACT_SPARKS: int = 4
const IMPACT_TIME: float = 0.25
const IMPACT_REACH_MIN: int = 3
const IMPACT_REACH_MAX: int = 6
const IMPACT_RAMPS: Dictionary[Kind, Array] = {
	Kind.DUST: [Palette.D0, Palette.D0, Palette.N8, Palette.N7],
	Kind.LIGHT: [Palette.C0, Palette.C1, Palette.C2, Palette.C3],
}
## The longest a combo's particles can take to all land: dust and light together.
const LONGEST_TRAVEL: float = LAUNCH_DELAY + STAGGER * (2 * MAX_PARTICLES - 1) + FLIGHT_MAX
## Head colour, then trail colour, per kind.
const COLOURS: Dictionary[Kind, Array] = {
	Kind.DUST: [Palette.D0, Palette.N8],
	Kind.LIGHT: [Palette.C0, Palette.C2],
}

## Where dust particles land: the dust icon.
@export var dust_target: Vector2i = Vector2i(12, 300)
## Where light particles land: the Sun's centre.
@export var light_target: Vector2i = Vector2i(90, 39)


class Particle:
	extends RefCounted
	var kind: Kind
	var amount: int
	var from: Vector2
	## Where the pop leaves it, and where the swoosh's curve starts.
	var popped: Vector2
	var bend: Vector2
	var to: Vector2
	var delay: float
	var duration: float
	var age: float = 0.0

	func progress() -> float:
		return clampf((age - delay) / duration, 0.0, 1.0)

	## The point at `t` of the flight: an ease-out pop from the star, then a quadratic Bézier
	## from there, eased so it speeds into the counter.
	func point_at(t: float) -> Vector2i:
		if t < POP_SHARE:
			var u: float = t / POP_SHARE
			return Vector2i(from.lerp(popped, 1.0 - (1.0 - u) * (1.0 - u)).round())
		var e: float = pow((t - POP_SHARE) / (1.0 - POP_SHARE), 2)
		return Vector2i(popped.lerp(bend, e).lerp(bend.lerp(to, e), e).round())


class Impact:
	extends RefCounted
	var kind: Kind
	var at: Vector2i
	var reach: Array[Vector2] = []
	var age: float = 0.0


var _sequencer: EventSequencer
var _particles: Array[Particle] = []
var _impacts: Array[Impact] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for impact: Impact in _impacts:
		var dots: Dictionary[Vector2i, Color] = BurstSparks.spark_pixels(impact.reach, impact.age / IMPACT_TIME, IMPACT_RAMPS[impact.kind])
		for offset: Vector2i in dots:
			draw_rect(Rect2(Vector2(impact.at + offset), Vector2.ONE), dots[offset])
	for p: Particle in _particles:
		if p.age < p.delay:
			continue
		var t: float = p.progress()
		var head: Vector2i = p.point_at(t)
		var trail: Vector2i = p.point_at(maxf(t - 0.06, 0.0))
		if trail != head:
			draw_rect(Rect2(Vector2(trail), Vector2.ONE), COLOURS[p.kind][1])
		draw_rect(Rect2(Vector2(head), Vector2.ONE), COLOURS[p.kind][0])


## A new run drops every particle still in the air: the new run's counters start from its state.
func setup(_run: RunState, sequencer: EventSequencer) -> void:
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_particles.clear()
	_impacts.clear()
	queue_redraw()


func in_flight(kind: Kind) -> int:
	var total: int = 0
	for p: Particle in _particles:
		if p.kind == kind:
			total += p.amount
	return total


func particle_count() -> int:
	return _particles.size()


func impact_count() -> int:
	return _impacts.size()


## Moves every particle on and lands those that arrived. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	if _particles.is_empty() and _impacts.is_empty():
		return
	for impact: Impact in _impacts:
		impact.age += delta
	_impacts = _impacts.filter(func(i: Impact) -> bool: return i.age < IMPACT_TIME)
	var landed: Array[Particle] = []
	for p: Particle in _particles:
		p.age += delta
		if p.age >= p.delay + p.duration:
			landed.append(p)
	for p: Particle in landed:
		_particles.erase(p)
		_impact(p.kind, Vector2i(p.to))
		if p.kind == Kind.DUST:
			dust_arrived.emit(p.amount)
		else:
			light_arrived.emit(p.amount)
	queue_redraw()


## `total` shared between `parts` as evenly as whole numbers allow, largest shares first.
@warning_ignore("integer_division")
static func split(total: int, parts: int) -> Array[int]:
	var shares: Array[int] = []
	for i: int in parts:
		shares.append(total / parts + (1 if i < total % parts else 0))
	return shares


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	if event.type != &"combo_collected":
		return
	var sources: Array[Vector2i] = []
	for star: Star in event.args[1]:
		sources.append(star.position)
	if sources.is_empty():
		return
	var n: int = _particles.size()
	_launch(Kind.DUST, event.args[2], sources, dust_target)
	_launch(Kind.LIGHT, event.args[3], sources, light_target)
	# Stagger dust and light together, in launch order, from this combo's first particle.
	for i: int in range(n, _particles.size()):
		_particles[i].delay = LAUNCH_DELAY + STAGGER * (i - n)


func _launch(kind: Kind, total: int, sources: Array[Vector2i], target: Vector2i) -> void:
	if total <= 0:
		return
	var shares: Array[int] = split(total, mini(total, MAX_PARTICLES))
	for i: int in shares.size():
		var p := Particle.new()
		p.kind = kind
		p.amount = shares[i]
		p.from = Vector2(sources[i % sources.size()])
		p.popped = p.from + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(POP_MIN, POP_MAX)
		p.to = Vector2(target)
		var middle: Vector2 = p.popped.lerp(p.to, 0.5)
		p.bend = middle + (p.to - p.popped).orthogonal().normalized() * _rng.randf_range(-MAX_BOW, MAX_BOW)
		p.duration = _rng.randf_range(FLIGHT_MIN, FLIGHT_MAX)
		_particles.append(p)


func _impact(kind: Kind, at: Vector2i) -> void:
	var impact := Impact.new()
	impact.kind = kind
	impact.at = at
	for i: int in IMPACT_SPARKS:
		var angle: float = TAU * (i + _rng.randf_range(-0.3, 0.3)) / IMPACT_SPARKS
		impact.reach.append(Vector2.from_angle(angle) * _rng.randf_range(IMPACT_REACH_MIN, IMPACT_REACH_MAX))
	_impacts.append(impact)
