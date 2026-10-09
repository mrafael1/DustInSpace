class_name PackSlot
extends Node2D
## One pack in the HUD: its icon (r6) with "×count", and a "+◆cost" buy button below.
## The icon is lit while at least one is owned (tapping it loads), grey at ×0, even when the dust
## would buy one: the buy button shows that. Only the loaded pack's icon moves: it spins, and hops
## now and then while the dust can buy another. The others stay still.
## Becoming buyable plays a one-off cue: the icon flashes solid C0 for FLASH_TIME and a cross
## sparkle shrinks away beside it. Staying buyable never repeats it.
## Two tap targets (docs/design.md, Packs): the icon loads the pack if owned, or buys it if none
## is owned; the buy button always buys one more. It reads as a button on its own: a plate with
## clipped corners, a "+", a warm C2 border when the dust is there (cool M4 when not), a lighter
## fill while pressed, a C0 border flash when a buy plays, and an S4 border with a refused tap.
## The Hud decides what a tap does; this only shows the slot.
## Centred on the icon. Numbers are Labels in the 3x5 font; nothing is baked into art.

## The pack just became buyable and its cue started. Feedback only (sound).
signal cue_started(kind: String)

const ICON_RADIUS: int = 6
## Tap targets around the icon and under it, meeting at y +8, both 24x22 px (44 pt at 2 pt per
## px). The buy button's runs to the bottom of the screen when the slot sits at y 290.
const ICON_TARGET := Rect2i(-12, -14, 24, 22)
const COST_TARGET := Rect2i(-12, 8, 24, 22)
## The buy button's plate, inside its target: "+", the small dust icon and the cost.
const BUY_PLATE := Rect2i(-11, 13, 22, 9)
## The button's row, centred on the plate: "+" (3 px), 1 px, dust icon (5 px), 1 px, the cost in
## the 3x5 font (4 px a digit, less the last gap). BUY_ROW_Y is the row's middle pixel.
const BUY_ROW_Y: int = 17
const DIGIT_ADVANCE: int = 4
## The border flashes C0 this long when a buy plays.
const BOUGHT_FLASH: float = 0.12
## A refused tap nudges the icon (never the numbers) by whole pixels.
const NUDGE: Array[int] = [1, -1, 1, -1, 0]
const NUDGE_STEP: float = 0.04
## A buyable icon spins (PackView) and hops 1 px for HOP_TIME every HOP_PERIOD, starting at once.
const HOP_PERIOD: float = 1.5
const HOP_TIME: float = 0.16
## The cue: two frames of solid flash, then the sparkle's arms (px) step down, SPARKLE_STEP each.
const FLASH_TIME: float = 0.07
const SPARKLE_ARMS: Array[int] = [2, 1, 0]
const SPARKLE_STEP: float = 0.1
## The sparkle's centre, up and right of the icon, clear of "×count".
const SPARKLE_AT := Vector2i(8, -7)

var kind: String = "":
	set(value):
		kind = value
		if _icon != null:
			_icon.kind = value

var _loaded: bool = false
var _affordable: bool = false
var _hop_time: float = 0.0
var _nudge_time: float = -1.0
var _buy_pressed: bool = false
## The "+"'s centre, set when the cost is laid out.
var _plus_at := Vector2i(-8, BUY_ROW_Y)
## Seconds left of the bought flash.
var _bought_left: float = 0.0
## Seconds into the cue, or -1 when none is playing.
var _cue_time: float = -1.0

@onready var _icon: PackView = $Icon
@onready var _cue: Node2D = $Cue
@onready var _buy: Node2D = $Buy
@onready var _count: Label = $Count
@onready var _cost: Label = $Cost
@onready var _cost_icon: Node2D = $CostIcon


func _ready() -> void:
	_icon.radius_override = ICON_RADIUS
	_icon.kind = kind
	_count.label_settings = HudText.secondary(Palette.M6)
	_cost.label_settings = HudText.secondary(Palette.D0)
	_cue.draw.connect(_draw_cue)
	_buy.draw.connect(_draw_buy)


func _process(delta: float) -> void:
	advance(delta)


## A short C1 bar under the loaded pack: warm, because it is what the slingshot will fire.
func _draw() -> void:
	if _loaded:
		draw_rect(Rect2(-3, 8, 7, 1), Palette.C1)


## `announce` false takes the state as it is without a cue: a new run's setup isn't news.
func show_pack(count: int, cost: int, affordable: bool, loaded: bool, announce: bool = true) -> void:
	_count.text = "×%d" % count
	if _cost.text != "%d" % cost:
		_cost.text = "%d" % cost
		_lay_out_buy_row()
	# Cool N7 when the dust isn't there: warm/light colours mean something you can use.
	_cost.label_settings.font_color = Palette.D0 if affordable else Palette.N7
	# The planet: lit one step up its ramp while one is owned, grey at ×0; spinning only if loaded.
	_icon.bright = count > 0
	_icon.greyed = count == 0
	_icon.spinning = loaded
	if affordable and not _affordable:
		_hop_time = 0.0
		if announce:
			_cue_time = 0.0
			cue_started.emit(kind)
	if not affordable or not announce:
		_cue_time = -1.0
	_affordable = affordable
	_loaded = loaded
	queue_redraw()
	_cue.queue_redraw()
	_buy.queue_redraw()


func is_loaded() -> bool:
	return _loaded


## Which target holds `point` (in this slot's coordinates): &"icon", &"cost" or &"".
func target_at(point: Vector2i) -> StringName:
	if ICON_TARGET.has_point(point):
		return &"icon"
	if COST_TARGET.has_point(point):
		return &"cost"
	return &""


func nudge() -> void:
	_nudge_time = 0.0
	_buy.queue_redraw()


## Shows the buy button held down (or let go): immediate feedback on the press.
func press_buy(pressed: bool) -> void:
	if pressed != _buy_pressed:
		_buy_pressed = pressed
		_buy.queue_redraw()


func is_buy_pressed() -> bool:
	return _buy_pressed


## A buy of this pack played: the button's border flashes.
func flash_bought() -> void:
	_bought_left = BOUGHT_FLASH
	_buy.queue_redraw()


## The buy button's colours now: [fill, border, plus/text].
func buy_colours() -> Array[Color]:
	var border: Color = Palette.C2 if _affordable else Palette.M4
	if is_nudging():
		border = Palette.S4
	elif _bought_left > 0.0:
		border = Palette.C0
	var text: Color = Palette.D0 if _affordable else Palette.N7
	return [Palette.M3 if _buy_pressed else Palette.M1, border, text]


func is_nudging() -> bool:
	return _nudge_time >= 0.0


func is_cueing() -> bool:
	return _cue_time >= 0.0


func is_flashing() -> bool:
	return _cue_time >= 0.0 and _cue_time < FLASH_TIME


## The sparkle's arm length now, or -1 when it isn't showing.
func sparkle_arm() -> int:
	if _cue_time < 0.0:
		return -1
	return SPARKLE_ARMS[mini(int(_cue_time / SPARKLE_STEP), SPARKLE_ARMS.size() - 1)]


func is_hopping() -> bool:
	return _icon.position.y < 0.0


## Moves the nudge, the buyable hop and the cue forward. Driven by `_process`; tests call it
## directly. A nudge wins over the hop.
func advance(delta: float) -> void:
	_advance_cue(delta)
	if _bought_left > 0.0:
		_bought_left = maxf(_bought_left - delta, 0.0)
		if _bought_left == 0.0:
			_buy.queue_redraw()
	_hop_time = fmod(_hop_time + delta, HOP_PERIOD)
	if _nudge_time < 0.0:
		var hops: bool = _affordable and _loaded
		_icon.position = Vector2(0, -1 if hops and _hop_time < HOP_TIME else 0)
		return
	_nudge_time += delta
	var step: int = int(_nudge_time / NUDGE_STEP)
	if step >= NUDGE.size():
		_nudge_time = -1.0
		_icon.position = Vector2.ZERO
		_buy.queue_redraw()
		return
	_icon.position = Vector2(Motion.shake_x(NUDGE[step]), 0)


func _advance_cue(delta: float) -> void:
	if _cue_time < 0.0:
		return
	var shown: Array = [is_flashing(), sparkle_arm()]
	_cue_time += delta
	if _cue_time >= SPARKLE_STEP * SPARKLE_ARMS.size():
		_cue_time = -1.0
	if [is_flashing(), sparkle_arm()] != shown:
		_cue.queue_redraw()


## Over the icon: its own shape in solid C0 while flashing, and the sparkle (C1 arms, C0 core).
func _draw_cue() -> void:
	if is_flashing():
		var at := Vector2i(_icon.position)
		for dot: Vector2i in PackView.pixels(kind, false, false, ICON_RADIUS):
			_cue.draw_rect(Rect2(at + dot, Vector2.ONE), Palette.C0)
	var arm: int = sparkle_arm()
	if arm < 0:
		return
	if arm > 0:
		_cue.draw_rect(Rect2(SPARKLE_AT.x - arm, SPARKLE_AT.y, arm * 2 + 1, 1), Palette.C1)
		_cue.draw_rect(Rect2(SPARKLE_AT.x, SPARKLE_AT.y - arm, 1, arm * 2 + 1), Palette.C1)
	_cue.draw_rect(Rect2(SPARKLE_AT, Vector2.ONE), Palette.C0)


## The buy plate: fill, then a 1 px border with its corners clipped, then a 3x3 "+".
func _draw_buy() -> void:
	var colours: Array[Color] = buy_colours()
	var r: Rect2i = BUY_PLATE
	_buy.draw_rect(Rect2(r.grow(-1)), colours[0])
	_buy.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), colours[1])
	_buy.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), colours[1])
	_buy.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), colours[1])
	_buy.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), colours[1])
	_buy.draw_rect(Rect2(_plus_at.x - 1, _plus_at.y, 3, 1), colours[2])
	_buy.draw_rect(Rect2(_plus_at.x, _plus_at.y - 1, 1, 3), colours[2])


## Centres "+◆cost" on the plate, on whole pixels.
func _lay_out_buy_row() -> void:
	var text_width: int = _cost.text.length() * DIGIT_ADVANCE - 1
	var width: int = 3 + 1 + 5 + 1 + text_width
	var left: int = BUY_PLATE.position.x + (BUY_PLATE.size.x - width) / 2
	_plus_at = Vector2i(left + 1, BUY_ROW_Y)
	_cost_icon.position = Vector2(left + 6, BUY_ROW_Y)
	_cost.position = Vector2(left + 10, BUY_ROW_Y - 2)
	_buy.queue_redraw()


## Where "+", the dust icon and the cost sit, for tests: [plus centre, icon centre, text left].
func buy_row() -> Array[Vector2i]:
	return [_plus_at, Vector2i(_cost_icon.position), Vector2i(_cost.position)]
