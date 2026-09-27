class_name PackSlot
extends Node2D
## One pack in the HUD: its icon (r6) with "×count", and "◆cost" below.
## The icon is grey and still when the dust can't buy one; lit, spinning and hopping when it can.
## Becoming buyable plays a one-off cue: the icon flashes solid C0 for FLASH_TIME and a cross
## sparkle shrinks away beside it. Staying buyable never repeats it.
## Two tap targets (docs/design.md, Packs): the icon loads the pack if owned, or buys it if none
## is owned; the cost buys one more. The Hud decides what a tap does; this only shows the slot.
## Centred on the icon. Numbers are Labels in the 3x5 font; nothing is baked into art.

## The pack just became buyable and its cue started. Feedback only (sound).
signal cue_started(kind: String)

const ICON_RADIUS: int = 6
## Tap targets around the icon and under it, meeting at y +11. The icon's is 24x22 px (44 pt);
## the cost's runs from there to the bottom of the screen (17 px when the slot sits at y 292).
const ICON_TARGET := Rect2i(-12, -11, 24, 22)
const COST_TARGET := Rect2i(-12, 11, 24, 17)
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
## Seconds into the cue, or -1 when none is playing.
var _cue_time: float = -1.0

@onready var _icon: PackView = $Icon
@onready var _cue: Node2D = $Cue
@onready var _count: Label = $Count
@onready var _cost: Label = $Cost


func _ready() -> void:
	_icon.radius_override = ICON_RADIUS
	_icon.kind = kind
	_count.label_settings = HudText.secondary(Palette.M6)
	_cost.label_settings = HudText.secondary(Palette.D0)
	_cue.draw.connect(_draw_cue)


func _process(delta: float) -> void:
	advance(delta)


## A short C1 bar under the loaded pack: warm, because it is what the slingshot will fire.
func _draw() -> void:
	if _loaded:
		draw_rect(Rect2(-3, 8, 7, 1), Palette.C1)


## `announce` false takes the state as it is without a cue: a new run's setup isn't news.
func show_pack(count: int, cost: int, affordable: bool, loaded: bool, announce: bool = true) -> void:
	_count.text = "×%d" % count
	_cost.text = "%d" % cost
	# Cool N7 when the dust isn't there: warm/light colours mean something you can use.
	_cost.label_settings.font_color = Palette.D0 if affordable else Palette.N7
	# The planet too: lit one step up its ramp when a buy would work, grey when it wouldn't.
	_icon.bright = affordable
	_icon.greyed = not affordable
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
	_hop_time = fmod(_hop_time + delta, HOP_PERIOD)
	if _nudge_time < 0.0:
		_icon.position = Vector2(0, -1 if _affordable and _hop_time < HOP_TIME else 0)
		return
	_nudge_time += delta
	var step: int = int(_nudge_time / NUDGE_STEP)
	if step >= NUDGE.size():
		_nudge_time = -1.0
		_icon.position = Vector2.ZERO
		return
	_icon.position = Vector2(NUDGE[step], 0)


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
