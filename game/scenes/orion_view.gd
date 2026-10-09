class_name OrionView
extends Node2D
## Orion the hunter (#64), on stages he hunts: his figure, ember in the sky's top-left corner (drawn
## on the FigureLayer, under the stars); when he marks a star his figure flashes bright and a dotted
## ember sight line runs from his bow to it, then the ember crosshair closes on it and stays (a cue
## unlike the warm selection ring, the lit landmarks and the unlit landmarks' corner hints),
## his bow held drawn while it stands. While the player traces a link that would leave the marked
## star behind, his bow readies: the figure lights up and the sight line holds on the star. Then his
## arrow flying to it.
## On the Body (#70) he looses volleys instead, as falling arrows (#98): as each countdown starts he
## shoots OVERHEAD arrows up to a row under the top of the sky, where they hang pointing down while
## the countdown drops (his bow drawn; on the last link the bow blinks bright and the arrows shiver a
## pixel; steady bright while a traced link would loose it). At zero they rain down: an arrow falls
## straight onto each star the volley takes (an empty sky: they fall to the horizon).
## On the Heart (#71) he does both: the crosshair marks the single target (and only a link that
## would shoot it holds the sight line), while the nocked arrows and the countdown announce the volley.
## On the Heart (#71) he hunts an area: a dotted ember ring (S4, like the crosshair) on the sky (the sight line runs to it as
## it's marked); each launch, once its pack bursts, his arrow flies to the ring's centre and every
## loose star inside bursts as it lands.
## On the boss stage (the final) he is the boss. He enters as it opens: his stars light one by one
## from his feet to his bow, then the whole figure flashes C0 and shakes a pixel (his roar, as the
## HUD names him). He is ember like on every stage (S2 lines, S3 bow, S4 stars), and a row of
## pips under his feet counts the landmarks still to light: his health. Each landmark lit hurts
## him: he flashes and flinches and a pip breaks (C0, then an empty N3 slot). When the constellation
## is complete he falls: one flash, then his stars burst one by one from the bow down to his feet.
## Owns no rules: SkyView tells it what the events say.

## Orion bent his bow: the arrow is off. Feedback only (sound).
signal arrow_loosed
## The boss's entrance began: his stars start to light. Feedback only (sound).
signal entered
## The boss's entrance: his figure is whole and he roars (flash and shake). Feedback only (sound).
signal roared
## A landmark lit hurt the boss. Feedback only (sound).
signal hurt_taken
## The boss falls: one of his stars burst at `at`. Feedback only (sparks, sound).
signal star_fell(at: Vector2i)
## The boss has fallen: every star of his burst. The constellation plays next.
signal fallen

## The figure brightens and draws the bow, then the arrow flies; the star breaks as it lands.
const DRAW_TIME: float = 0.2
const FLIGHT_TIME: float = 0.35
## The arrow's shaft, behind its tip.
const SHAFT: int = 7
## A new mark: the figure flashes bright and the sight line runs from the bow hand to the star in
## TRACE_TIME; then the reticle closes in from LOCK_STEPS px further out, a pixel a step. The sight
## line and the flash cut together once the reticle has locked (MARK_TIME).
const TRACE_TIME: float = 0.18
const LOCK_STEPS: int = 3
const LOCK_STEP_TIME: float = 0.06
const MARK_TIME: float = TRACE_TIME + LOCK_STEPS * LOCK_STEP_TIME
## The sight line: a dot every SIGHT_GAP px, stopping short of the reticle.
const SIGHT_GAP: int = 2
## A locked reticle jumps a pixel out and back once a period, so a marked star keeps catching the eye.
const PULSE_PERIOD: float = 1.0
const PULSE_OUT: float = 0.12
## Each reticle tick's length, pointing in at the star.
const TICK: int = 3
## The volley's arrows leave VOLLEY_STAGGER apart. On the last link before it the bow blinks bright
## and dim, CHARGE_BLINK each, and the hanging arrows shiver a pixel in step.
const VOLLEY_STAGGER: float = 0.05
const CHARGE_BLINK: float = 0.3
## The staged volley (#98): after DRAW_TIME each arrow flies straight up out of the sky (UP_TIME, to
## ABOVE px over its top), then drops into its place (SETTLE_TIME, pointing down), its tip OVERHEAD_Y
## px under the sky's top at OVERHEAD_X (from its left edge), clear of his corner. At zero each falls
## onto its star in RAIN_TIME.
const OVERHEAD_X: Array[int] = [56, 83, 110, 137, 164]
const OVERHEAD_Y: int = 12
const ABOVE: int = 24
const UP_TIME: float = 0.25
const SETTLE_TIME: float = 0.15
const RAIN_TIME: float = 0.3
## The hunting ring's dots: every RING_GAP-th pixel of its outline.
const RING_GAP: int = 3
## Where the figure sits: this far into the play sky from its top-left corner.
const FIGURE_AT := Vector2i(6, 6)
## The boss's entrance: a star lights every ENTER_STEP (ENTRANCE order), then he roars for ROAR_TIME
## (C0, shaking a pixel every SHAKE_STEP), then his health fills a pip every HEALTH_STEP; the
## entrance holds the sequence ENTER_TIME in all, while the HUD names him.
const ENTER_STEP: float = 0.07
const ROAR_TIME: float = 0.3
const SHAKE_STEP: float = 0.05
const HEALTH_STEP: float = 0.04
const ENTER_HOLD: float = 0.9
## His health: a pip per landmark to light, HEALTH_PIP px square, HEALTH_GAP px apart, this far below
## the figure's top-left; colours: whole (top row, bottom row), and the empty slot.
const HEALTH_AT := Vector2i(0, 41)
const HEALTH_PIP: int = 2
const HEALTH_GAP: int = 1
const HEALTH_WHOLE: Array[Color] = [Palette.S4, Palette.S3]
const HEALTH_EMPTY: Color = Palette.N3
## A landmark lit hurts him: C0 and a pixel's flinch for HURT_TIME.
const HURT_TIME: float = 0.25
## His fall: a FALL_FLASH flash and shake, then a star bursts every FALL_STEP (the entrance in
## reverse), then a beat.
const FALL_FLASH: float = 0.3
const FALL_STEP: float = 0.08
const FALL_REST: float = 0.3
## Orion's stars (figure coordinates), laid out as in the sky (RA/Dec at about 1.7 px a degree):
## Meissa (head); Betelgeuse, Bellatrix; the belt Alnitak, Alnilam, Mintaka; Saiph, Rigel. His bow is
## the arc of Pi Orionis (the classic shield), held out right, towards the sky he hunts.
const HEAD := Vector2i(12, 0)
const BODY: Array[Vector2i] = [Vector2i(4, 4), Vector2i(17, 6), Vector2i(10, 20), Vector2i(12, 19), Vector2i(14, 17), Vector2i(7, 33), Vector2i(21, 31)]
const BOW: Array[Vector2i] = [Vector2i(30, 0), Vector2i(31, 2), Vector2i(32, 5), Vector2i(31, 7), Vector2i(30, 13), Vector2i(28, 14)]
## The figure's lines, between BODY stars (by index): shoulders to belt, the belt, belt to feet.
const LINES: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 4), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5), Vector2i(4, 6)]
## The arm from Bellatrix to the bow hand, gripping the bow's middle.
const BOW_HAND := Vector2i(29, 8)
## The boss's stars in the order they light as he enters (figure coordinates): his feet (Saiph,
## Rigel), the belt, the shoulders, the head, then the bow from top to bottom.
const ENTRANCE: Array[Vector2i] = [
	Vector2i(7, 33), Vector2i(21, 31), Vector2i(10, 20), Vector2i(12, 19), Vector2i(14, 17),
	Vector2i(4, 4), Vector2i(17, 6), Vector2i(12, 0),
	Vector2i(30, 0), Vector2i(31, 2), Vector2i(32, 5), Vector2i(31, 7), Vector2i(30, 13), Vector2i(28, 14),
]
const ROAR_AT: float = ENTER_STEP * 14
const ENTER_TIME: float = ROAR_AT + ROAR_TIME + ENTER_HOLD
const FALL_TIME: float = FALL_FLASH + FALL_STEP * 14 + FALL_REST

var _figure_shown: bool = false
var _figure_at: Vector2i = Vector2i.ZERO
## The marked star's view, or null.
var _marked: StarView
var _mark_age: float = 0.0
## The arrow: where from, where to, and how long since the bow was drawn (-1: none).
var _arrow_from: Vector2i = Vector2i.ZERO
var _arrow_to: Vector2i = Vector2i.ZERO
var _arrow_age: float = -1.0
## The shot star's size: its crosshair stays on it until the arrow lands.
var _arrow_size: int = 0
## The traced link would leave the marked star behind, or loose the volley.
var _shot_ready: bool = false
var _volley_ready: bool = false
## The volley's charge: 0 at rest, 1 building, 2 on the last link before it (VOLLEY_* only).
var _charge: int = 0
var _charge_age: float = 0.0
## The volley falling: where each arrow falls from and to, and how long since it started (-1: none).
var _volley_from: Array[Vector2i] = []
var _volley_to: Array[Vector2i] = []
var _volley_age: float = -1.0
## The staged volley: seconds since Orion shot it up (-1: no arrows overhead).
var _overhead_age: float = -1.0
var _sky: Rect2i = Rect2i()
## The hunting area: its centre and radius (0: none), and how long since it was marked.
var _area_centre: Vector2i = Vector2i.ZERO
var _area_radius: int = 0
var _area_age: float = 0.0
## The struck area's radius: its ring stays on the arrow's target until it lands (0: a star's shot).
var _arrow_radius: int = 0
## The boss stage: his health (landmarks still to light) of its full count, and how long since his
## entrance began, he was last hurt, and his fall began (-1: not playing).
var _boss: bool = false
var _health: int = 0
var _health_max: int = 0
var _enter_age: float = -1.0
var _hurt_age: float = -1.0
var _fall_age: float = -1.0

@onready var _figure_layer: Node2D = get_node("../FigureLayer")


func _ready() -> void:
	_figure_layer.draw.connect(_draw_figure)


func _process(delta: float) -> void:
	advance(delta)


## Shows the figure for a run Orion hunts (in `sky`'s top-left), hides everything otherwise.
func setup(hunts: bool, sky: Rect2i) -> void:
	_figure_shown = hunts
	_figure_at = sky.position + FIGURE_AT
	_sky = sky
	_overhead_age = -1.0
	_volley_from.clear()
	_marked = null
	_arrow_age = -1.0
	_shot_ready = false
	_volley_ready = false
	_charge = 0
	_volley_to.clear()
	_volley_age = -1.0
	_area_radius = 0
	_arrow_radius = 0
	_boss = false
	_enter_age = -1.0
	_hurt_age = -1.0
	_fall_age = -1.0
	queue_redraw()
	_figure_layer.queue_redraw()


## The boss stage: he is the boss, with `health` landmarks to light (after setup).
func setup_boss(health: int) -> void:
	_boss = true
	_health = health
	_health_max = health
	_figure_layer.queue_redraw()


func is_boss() -> bool:
	return _boss


## The boss enters: his stars light one by one, then he roars. Lasts ENTER_TIME.
func enter() -> void:
	if not _boss:
		return
	_enter_age = 0.0
	entered.emit()
	_figure_layer.queue_redraw()


func is_entering() -> bool:
	return _enter_age >= 0.0


## A landmark lit hurts the boss: he has `health` left. He flashes and flinches and a pip breaks.
func hurt(health: int) -> void:
	if not _boss or health >= _health:
		return
	_health = maxi(health, 0)
	_hurt_age = 0.0
	hurt_taken.emit()
	_figure_layer.queue_redraw()


func health() -> int:
	return _health


## The boss falls: a flash, then his stars burst one by one (star_fell), then `fallen`. Not the
## boss: `fallen` at once.
func fall() -> void:
	if not _boss:
		fallen.emit()
		return
	_fall_age = 0.0
	_enter_age = -1.0
	_marked = null
	_area_radius = 0
	_charge = 0
	queue_redraw()
	_figure_layer.queue_redraw()


func is_falling() -> bool:
	return _fall_age >= 0.0


## How many of his stars (ENTRANCE order) show now: all, but fewer while he enters, and fewer as
## his fall bursts them (from the bow down).
func stars_shown() -> int:
	if _enter_age >= 0.0 and _enter_age < ROAR_AT:
		return mini(int(_enter_age / ENTER_STEP) + 1, ENTRANCE.size())
	if _fall_age >= FALL_FLASH:
		return maxi(ENTRANCE.size() - int((_fall_age - FALL_FLASH) / FALL_STEP) - 1, 0)
	return ENTRANCE.size()


## The boss is flashing C0: roaring as he enters, hurt, or about to fall.
func is_flashing() -> bool:
	return (_enter_age >= ROAR_AT and _enter_age < ROAR_AT + ROAR_TIME) \
		or (_hurt_age >= 0.0 and _hurt_age < HURT_TIME) \
		or (_fall_age >= 0.0 and _fall_age < FALL_FLASH)


## The figure's shake now: a pixel side to side while he flashes, else none.
func shake() -> Vector2i:
	if not is_flashing():
		return Vector2i.ZERO
	var age: float = _hurt_age if _hurt_age >= 0.0 and _hurt_age < HURT_TIME else maxf(_enter_age - ROAR_AT, _fall_age)
	return Motion.shake(Vector2i(1 if int(age / SHAKE_STEP) % 2 == 0 else -1, 0))


## How many health pips show: they fill one by one after his roar; all once he has entered.
func health_filled() -> int:
	if _enter_age < 0.0:
		return _health_max
	if _enter_age < ROAR_AT + ROAR_TIME:
		return 0
	return mini(int((_enter_age - ROAR_AT - ROAR_TIME) / HEALTH_STEP) + 1, _health_max)


## His health pips now, pixel by pixel: whole ones, the one breaking (C0) and empty slots. None on
## other stages nor once he falls.
func health_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if not _boss or _fall_age >= 0.0:
		return dots
	var breaking: bool = _hurt_age >= 0.0 and _hurt_age < HURT_TIME
	for i: int in health_filled():
		var at: Vector2i = _figure_at + HEALTH_AT + Vector2i(i * (HEALTH_PIP + HEALTH_GAP), 0)
		for y: int in HEALTH_PIP:
			for x: int in HEALTH_PIP:
				var colour: Color = HEALTH_WHOLE[y]
				if i >= _health:
					colour = Palette.C0 if breaking and i == _health else HEALTH_EMPTY
				dots[at + Vector2i(x, y)] = colour
	return dots


func is_figure_shown() -> bool:
	return _figure_shown


## Where the arrow leaves from: the bow hand.
func bow_hand() -> Vector2i:
	return _figure_at + BOW_HAND


## Orion marked the star `view` shows: the flash and sight line, then the reticle locks on.
func mark(view: StarView) -> void:
	_marked = view
	_mark_age = 0.0
	queue_redraw()
	_figure_layer.queue_redraw()


func marked() -> StarView:
	return _marked if is_instance_valid(_marked) else null


## Orion marked the hunting area: a circle of `radius` at `centre`. The figure flashes and the sight
## line runs to its edge, then the ring stays.
func mark_area(centre: Vector2i, radius: int) -> void:
	_area_centre = centre
	_area_radius = radius
	_area_age = 0.0
	queue_redraw()
	_figure_layer.queue_redraw()


func has_area() -> bool:
	return _area_radius > 0


## The arrow strikes the hunting area: it flies to the centre and the ring stays until it lands.
## Returns how long until it lands.
func strike_area() -> float:
	_arrow_from = bow_hand()
	_arrow_to = _area_centre
	_arrow_radius = _area_radius
	_arrow_age = 0.0
	_area_radius = 0
	queue_redraw()
	_figure_layer.queue_redraw()
	return DRAW_TIME + FLIGHT_TIME


## The dotted ring of a circle of `radius` round the origin, 1 px further out while it pulses: a
## midpoint-circle outline, every RING_GAP-th pixel of one octant mirrored eight ways, so the dots
## are evenly spaced and the ring exactly symmetric, and no two dots touch.
static func ring_pixels(radius: int, pulse: int = 0) -> Array[Vector2i]:
	var r: int = radius + pulse
	var octant: Array[Vector2i] = []
	var x: int = 0
	var y: int = r
	var d: int = 1 - r
	while x <= y:
		octant.append(Vector2i(x, y))
		if d < 0:
			d += 2 * x + 3
		else:
			d += 2 * (x - y) + 5
			y -= 1
		x += 1
	var dots: Array[Vector2i] = []
	var seen: Dictionary = {}
	for k: int in range(0, octant.size(), RING_GAP):
		var p: Vector2i = octant[k]
		# Next to the diagonal a dot and its mirror would touch: keep only the one on it.
		if p.x != p.y and absi(p.x - p.y) <= 1:
			continue
		for q: Vector2i in [Vector2i(p.x, p.y), Vector2i(p.y, p.x), Vector2i(-p.x, p.y), Vector2i(-p.y, p.x), Vector2i(p.x, -p.y), Vector2i(p.y, -p.x), Vector2i(-p.x, -p.y), Vector2i(-p.y, -p.x)]:
			if not seen.has(q):
				seen[q] = true
				dots.append(q)
	return dots


func clear_mark() -> void:
	_marked = null
	_shot_ready = false
	queue_redraw()
	_figure_layer.queue_redraw()


## The link being traced would leave the marked star to his arrow (`shot`), or loose the volley
## (`volley`). Either lights his figure; only a shot holds the sight line on the mark, so a link that
## saves the mark but looses the volley (the Heart, #71) never aims at the star it saves.
func ready_bow(shot: bool, volley: bool = false) -> void:
	if shot == _shot_ready and volley == _volley_ready:
		return
	_shot_ready = shot
	_volley_ready = volley
	queue_redraw()
	_figure_layer.queue_redraw()


func is_bow_ready() -> bool:
	return is_shot_ready() or (_volley_ready and _charge > 0)


## The traced link would have his arrow take the marked star.
func is_shot_ready() -> bool:
	return _shot_ready and marked() != null


## The volley's countdown: `links_left` successful links until it (of `interval`). A countdown with
## no arrows overhead yet stages them: he shoots them up. Returns how long that takes (0: already up),
## for the sequence to wait.
func show_volley_charge(links_left: int, interval: int) -> float:
	var charge: int = 0
	if links_left <= 1:
		charge = 2
	elif links_left < interval:
		charge = 1
	if charge != _charge:
		_charge = charge
		_charge_age = 0.0
		_figure_layer.queue_redraw()
	return stage_volley()


## Shoots the volley's arrows up to hang overhead, unless they're up already (or falling). Returns how
## long until the last one hangs.
func stage_volley() -> float:
	if not _figure_shown or _overhead_age >= 0.0 or is_volleying():
		return 0.0
	_overhead_age = 0.0
	queue_redraw()
	_figure_layer.queue_redraw()
	return stage_time()


static func stage_time() -> float:
	return DRAW_TIME + (OVERHEAD_X.size() - 1) * VOLLEY_STAGGER + UP_TIME + SETTLE_TIME


func is_staged() -> bool:
	return _overhead_age >= 0.0


## The completion (or the end of the volleys): the arrows overhead go without falling.
func clear_overhead() -> void:
	_overhead_age = -1.0
	queue_redraw()


## Where each hanging arrow's tip is.
func overhead_spots() -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for x: int in OVERHEAD_X:
		spots.append(_sky.position + Vector2i(x, OVERHEAD_Y))
	return spots


## The staged arrows now, each one's pixels tip last: flying straight up from the bow hand out of the
## sky (tip up), dropping into place from above, then hanging pointing down (shivering a pixel on the
## last link). None before it leaves the bow.
func overhead_arrows() -> Array[Array]:
	var arrows: Array[Array] = []
	if _overhead_age < 0.0:
		return arrows
	var spots: Array[Vector2i] = overhead_spots()
	var shiver: int = 1 if _charge == 2 and int(_charge_age / CHARGE_BLINK) % 2 == 0 else 0
	for i: int in spots.size():
		var age: float = _overhead_age - DRAW_TIME - i * VOLLEY_STAGGER
		if age < 0.0:
			continue
		var bow: Vector2i = bow_hand()
		var up := Vector2i(bow.x + 2 * i, _sky.position.y - ABOVE)
		if age < UP_TIME:
			arrows.append(_arrow_line(bow, up, age / UP_TIME))
		elif age < UP_TIME + SETTLE_TIME:
			var from := Vector2i(spots[i].x, _sky.position.y - ABOVE)
			arrows.append(_arrow_line(from, spots[i], (age - UP_TIME) / SETTLE_TIME))
		else:
			var tip: Vector2i = spots[i] + Vector2i(shiver * (1 if i % 2 == 0 else -1), 0)
			arrows.append(_arrow_line(tip + Vector2i(0, -SHAFT * 2), tip, 1.0))
	return arrows


func volley_charge() -> int:
	return _charge


## The volley falls on `targets`: the arrows overhead come down, one straight onto each, from the
## row they hung in, VOLLEY_STAGGER apart. An empty sky: the hanging arrows fall to the horizon.
## Returns when each target's arrow lands, in order.
func fire_volley(targets: Array[Vector2i]) -> Array[float]:
	_volley_from.clear()
	_volley_to.clear()
	var top: int = _sky.position.y + OVERHEAD_Y
	if targets.is_empty():
		for spot: Vector2i in overhead_spots():
			_volley_from.append(spot)
			_volley_to.append(Vector2i(spot.x, _sky.end.y - 1))
	for target: Vector2i in targets:
		_volley_from.append(Vector2i(target.x, mini(top, target.y - SHAFT)))
		_volley_to.append(target)
	_volley_age = 0.0
	_overhead_age = -1.0
	_shot_ready = false
	_volley_ready = false
	var landings: Array[float] = []
	for i: int in targets.size():
		landings.append(i * VOLLEY_STAGGER + RAIN_TIME)
	arrow_loosed.emit()
	queue_redraw()
	_figure_layer.queue_redraw()
	return landings


## How long the whole volley falls, its last arrow included.
func volley_time() -> float:
	return maxi(_volley_to.size() - 1, 0) * VOLLEY_STAGGER + RAIN_TIME


func is_volleying() -> bool:
	return _volley_age >= 0.0


## The volley's arrows now: each one's pixels, tip last (none before it leaves or once it lands).
func volley_arrows() -> Array[Array]:
	var arrows: Array[Array] = []
	for i: int in _volley_to.size():
		var age: float = _volley_age - i * VOLLEY_STAGGER
		if age >= 0.0 and age < RAIN_TIME:
			arrows.append(_arrow_line(_volley_from[i], _volley_to[i], age / RAIN_TIME))
	return arrows


## The arrows are flying up to hang overhead: he's shooting them (his figure lights).
func is_staging() -> bool:
	return _overhead_age >= 0.0 and _overhead_age < stage_time()


## A new mark (or hunting area) is being acquired: the figure flashes and the sight line shows.
func is_aiming() -> bool:
	return (marked() != null and _mark_age < MARK_TIME) or (has_area() and _area_age < MARK_TIME)


## The hunting area's ring now, on the sky: it closes in from LOCK_STEPS px further out as it's
## marked, then jumps a pixel out and back once a PULSE_PERIOD, like the reticle. None before the
## sight line reaches it.
func area_pixels() -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	if not has_area() or _area_age < TRACE_TIME:
		return dots
	var step: int = maxi(LOCK_STEPS - int((_area_age - TRACE_TIME) / LOCK_STEP_TIME), 0)
	if step == 0 and fmod(_area_age - MARK_TIME, PULSE_PERIOD) >= PULSE_PERIOD - PULSE_OUT:
		step = 1
	for p: Vector2i in ring_pixels(_area_radius, step):
		dots.append(_area_centre + p)
	return dots


## The sight line to a new hunting area, from the bow hand to short of its ring, while it's marked.
func area_sight_pixels() -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	if not has_area() or _area_age >= MARK_TIME:
		return dots
	var line: Array[Vector2i] = LinkLayer.line_pixels(bow_hand(), _area_centre)
	var reach: int = maxi(line.size() - _area_radius - LOCK_STEPS - 1, 0)
	var shown: int = ceili(reach * minf(_area_age / TRACE_TIME, 1.0))
	for i: int in range(0, shown, SIGHT_GAP):
		dots.append(line[i])
	return dots


## Orion shoots the star of `size` at `at`: the bow draws, then the arrow flies there; the
## crosshair stays on it until it lands. Returns how long until it lands.
func shoot(at: Vector2i, size: int) -> float:
	_marked = null
	_shot_ready = false
	_volley_ready = false
	_arrow_from = bow_hand()
	_arrow_to = at
	_arrow_size = size
	_arrow_radius = 0
	_arrow_age = 0.0
	queue_redraw()
	_figure_layer.queue_redraw()
	return DRAW_TIME + FLIGHT_TIME


func is_shooting() -> bool:
	return _arrow_age >= 0.0


func advance(delta: float) -> void:
	if _marked != null:
		if not is_instance_valid(_marked) or _marked.is_queued_for_deletion():
			_marked = null
		_mark_age += delta
		queue_redraw()
		_figure_layer.queue_redraw()
	if _arrow_age >= 0.0:
		var drawn: bool = _arrow_age >= DRAW_TIME
		_arrow_age += delta
		if not drawn and _arrow_age >= DRAW_TIME:
			arrow_loosed.emit()
		if _arrow_age >= DRAW_TIME + FLIGHT_TIME:
			_arrow_age = -1.0
		queue_redraw()
		_figure_layer.queue_redraw()
	if _volley_age >= 0.0:
		_volley_age += delta
		if _volley_age >= volley_time():
			_volley_age = -1.0
			_volley_to.clear()
			_volley_from.clear()
		queue_redraw()
		_figure_layer.queue_redraw()
	if _overhead_age >= 0.0:
		var shot: bool = _overhead_age >= DRAW_TIME
		_overhead_age += delta
		if not shot and _overhead_age >= DRAW_TIME:
			arrow_loosed.emit()
		queue_redraw()
		if _overhead_age < stage_time() + delta:
			_figure_layer.queue_redraw()
	if has_area():
		_area_age += delta
		queue_redraw()
		_figure_layer.queue_redraw()
	_advance_boss(delta)
	if _charge == 2:
		var blink: int = int(_charge_age / CHARGE_BLINK)
		_charge_age += delta
		if int(_charge_age / CHARGE_BLINK) != blink:
			_figure_layer.queue_redraw()
			queue_redraw()


func _advance_boss(delta: float) -> void:
	if not _boss:
		return
	if _enter_age >= 0.0:
		var roaring: bool = _enter_age >= ROAR_AT
		_enter_age += delta
		if not roaring and _enter_age >= ROAR_AT:
			roared.emit()
		if _enter_age >= ENTER_TIME:
			_enter_age = -1.0
		_figure_layer.queue_redraw()
	if _hurt_age >= 0.0:
		_hurt_age += delta
		if _hurt_age >= HURT_TIME:
			_hurt_age = -1.0
		_figure_layer.queue_redraw()
	if _fall_age >= 0.0:
		var shown: int = stars_shown()
		_fall_age += delta
		for i: int in range(stars_shown(), shown):
			star_fell.emit(_figure_at + ENTRANCE[i])
		if _fall_age >= FALL_TIME:
			_fall_age = -1.0
			_figure_shown = false
			_boss = false
			fallen.emit()
		_figure_layer.queue_redraw()


## The crosshair around a star of `size`, `lock` px further out than at rest: a tick of TICK pixels
## pointing in from each side (up, down, left, right), clear of the star and its selection ring.
static func reticle_pixels(size: int, lock: int = 0) -> Array[Vector2i]:
	var d: int = StarView.half_extent(size as Star.Size) + 3 + lock
	var pixels: Array[Vector2i] = []
	for axis: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for k: int in TICK:
			pixels.append(axis * (d + k))
	return pixels


## The reticle's offset now: LOCK_STEPS down to 0 while it locks on, then 1 during each pulse.
func lock_step() -> int:
	var step: int = maxi(LOCK_STEPS - int((_mark_age - TRACE_TIME) / LOCK_STEP_TIME), 0)
	if step > 0:
		return step
	return 1 if fmod(_mark_age - MARK_TIME, PULSE_PERIOD) >= PULSE_PERIOD - PULSE_OUT else 0


## The reticle shows once the sight line reaches the star, and stays until the mark goes.
func shows_reticle() -> bool:
	return marked() != null and _mark_age >= TRACE_TIME


## The sight line's dots now, from the bow hand towards the marked star, the leading dot last: it
## runs out while a mark locks on and holds while the bow is ready; none otherwise. It stops short
## of where the reticle closes in from.
func sight_pixels() -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	if marked() == null or (_mark_age >= MARK_TIME and not is_shot_ready()):
		return dots
	var line: Array[Vector2i] = LinkLayer.line_pixels(bow_hand(), Vector2i(_marked.position.round()))
	var short: int = StarView.half_extent(_marked.size as Star.Size) + 3 + LOCK_STEPS + TICK
	var reach: int = maxi(line.size() - short, 0)
	var shown: int = reach if is_shot_ready() else ceili(reach * minf(_mark_age / TRACE_TIME, 1.0))
	for i: int in range(0, shown, SIGHT_GAP):
		dots.append(line[i])
	return dots


## The arrow's pixels now, tip last, or none: its shaft trails SHAFT px behind the tip.
func arrow_pixels() -> Array[Vector2i]:
	if _arrow_age < DRAW_TIME:
		return []
	return _arrow_line(_arrow_from, _arrow_to, minf((_arrow_age - DRAW_TIME) / FLIGHT_TIME, 1.0))


## An arrow `k` of the way from `from` to `to`: its shaft trails SHAFT px behind the tip, tip last.
static func _arrow_line(from_at: Vector2i, to: Vector2i, k: float) -> Array[Vector2i]:
	var from := Vector2(from_at)
	var tip: Vector2 = from.lerp(Vector2(to), k)
	var back: Vector2 = (from - Vector2(to)).normalized() * SHAFT
	var tail: Vector2 = tip + back if tip.distance_to(from) > SHAFT else from
	return LinkLayer.line_pixels(Vector2i(tail.round()), Vector2i(tip.round()))


## A volley arrow's head: its tip and, on a straight up or down shaft, a pixel either side behind it.
static func head_pixels(shaft: Array) -> Array[Vector2i]:
	var head: Array[Vector2i] = []
	if shaft.is_empty():
		return head
	var tip: Vector2i = shaft[-1]
	head.append(tip)
	if shaft.size() > 1:
		var back: Vector2i = (shaft[-2] as Vector2i) - tip
		if back.x == 0 and back.y != 0:
			head.append(tip + Vector2i(-1, back.y))
			head.append(tip + Vector2i(1, back.y))
	return head


## The figure's pixels and colours: ember, like the boss (S2 lines, S3 bow, S4 stars; playtest: a
## dim cool figure went unseen); brighter while he marks, readies his bow or shoots (S4 lines, N10
## bow, C0 stars). While a threat stands (a mark, a volley charging, a hunting area) his bow stays
## drawn: S4, a step brighter than at rest.
func figure_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if not _figure_shown:
		return dots
	if _boss:
		return _boss_pixels()
	var blinking_on: bool = _charge == 2 and int(_charge_age / CHARGE_BLINK) % 2 == 0
	var hunting: bool = is_shooting() or is_aiming() or is_bow_ready() or is_volleying() or blinking_on or is_staging()
	var line_colour: Color = Palette.S4 if hunting else Palette.S2
	for pair: Vector2i in LINES:
		for p: Vector2i in LinkLayer.line_pixels(BODY[pair.x], BODY[pair.y]):
			dots[_figure_at + p] = line_colour
	for p: Vector2i in LinkLayer.line_pixels(HEAD, BODY[0]) + LinkLayer.line_pixels(HEAD, BODY[1]):
		dots[_figure_at + p] = line_colour
	for p: Vector2i in LinkLayer.line_pixels(BODY[1], BOW_HAND):
		dots[_figure_at + p] = line_colour
	var bow_colour: Color = Palette.N10 if hunting else (Palette.S4 if marked() != null or _charge > 0 or has_area() else Palette.S3)
	for k: int in range(1, BOW.size()):
		for p: Vector2i in LinkLayer.line_pixels(BOW[k - 1], BOW[k]):
			dots[_figure_at + p] = bow_colour
	var star_colour: Color = Palette.C0 if hunting else Palette.S4
	for p: Vector2i in BODY:
		dots[_figure_at + p] = star_colour
	dots[_figure_at + HEAD] = star_colour
	return dots


## The boss's figure: ember at rest (S2 lines, S3 bow, S4 stars), brighter while he hunts (S4
## lines, N10 bow, C0 stars), all C0 while he flashes, shaken a pixel. Only the stars shown so far
## (entering, falling), and a line only once both its ends show. His health under his feet.
func _boss_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var shown: Array[Vector2i] = ENTRANCE.slice(0, stars_shown())
	var blinking_on: bool = _charge == 2 and int(_charge_age / CHARGE_BLINK) % 2 == 0
	var hunting: bool = is_shooting() or is_aiming() or is_bow_ready() or is_volleying() or blinking_on
	var flash: bool = is_flashing()
	var line_colour: Color = Palette.C0 if flash else (Palette.S4 if hunting else Palette.S2)
	var bow_colour: Color = Palette.C0 if flash else (Palette.N10 if hunting else Palette.S3)
	var star_colour: Color = Palette.C0 if flash or hunting else Palette.S4
	var at: Vector2i = _figure_at + shake()
	var lines: Array[Vector2i] = []
	for pair: Vector2i in LINES:
		lines.append_array([BODY[pair.x], BODY[pair.y]])
	lines.append_array([HEAD, BODY[0], HEAD, BODY[1]])
	for k: int in range(0, lines.size(), 2):
		if shown.has(lines[k]) and shown.has(lines[k + 1]):
			for p: Vector2i in LinkLayer.line_pixels(lines[k], lines[k + 1]):
				dots[at + p] = line_colour
	if shown.has(BODY[1]) and shown.has(BOW[3]):
		for p: Vector2i in LinkLayer.line_pixels(BODY[1], BOW_HAND):
			dots[at + p] = line_colour
	for k: int in range(1, BOW.size()):
		if shown.has(BOW[k - 1]) and shown.has(BOW[k]):
			for p: Vector2i in LinkLayer.line_pixels(BOW[k - 1], BOW[k]):
				dots[at + p] = bow_colour
	for p: Vector2i in shown:
		dots[at + p] = star_colour
	# The star lighting right now as he enters shows white.
	if _enter_age >= 0.0 and _enter_age < ROAR_AT and not shown.is_empty():
		dots[at + shown[-1]] = Palette.C0
	var health: Dictionary[Vector2i, Color] = health_pixels()
	for p: Vector2i in health:
		dots[p] = health[p]
	return dots


func _draw() -> void:
	var sight: Array[Vector2i] = sight_pixels()
	for i: int in sight.size():
		_dot(sight[i], Palette.S4 if i == sight.size() - 1 else Palette.S3)
	if shows_reticle():
		var at := Vector2i(_marked.position.round())
		for p: Vector2i in reticle_pixels(_marked.size, lock_step()):
			_dot(at + p, Palette.S4)
	if is_shooting():
		var target: Array[Vector2i] = ring_pixels(_arrow_radius) if _arrow_radius > 0 else reticle_pixels(_arrow_size)
		for p: Vector2i in target:
			_dot(_arrow_to + p, Palette.S4)
	if has_area():
		for p: Vector2i in area_pixels():
			_dot(p, Palette.S4)
		for p: Vector2i in area_sight_pixels():
			_dot(p, Palette.S3)
	var arrow: Array[Vector2i] = arrow_pixels()
	for i: int in arrow.size():
		_dot(arrow[i], Palette.M6 if i >= arrow.size() - 2 else Palette.M5)
	# The volley's arrows are his threat: ember, with a head so they read as arrows (#98).
	var volley: Array[Array] = volley_arrows()
	volley.append_array(overhead_arrows())
	for shaft: Array in volley:
		for p: Vector2i in shaft:
			_dot(p, Palette.S4)
		for p: Vector2i in head_pixels(shaft):
			_dot(p, Palette.C3)


func _draw_figure() -> void:
	var dots: Dictionary[Vector2i, Color] = figure_pixels()
	for p: Vector2i in dots:
		_figure_layer.draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
