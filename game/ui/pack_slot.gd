class_name PackSlot
extends Node2D
## One pack in the HUD: its icon (r6) with "×count", and "◆cost" below.
## Two tap targets (docs/design.md, Packs): the icon loads the pack if owned, or buys it if none
## is owned; the cost buys one more. The Hud decides what a tap does; this only shows the slot.
## Centred on the icon. Numbers are Labels in the 3x5 font; nothing is baked into art.

const ICON_RADIUS: int = 6
## Tap targets around the icon and under it, meeting at y +11. The icon's is 24x22 px (44 pt);
## the cost's runs from there to the bottom of the screen (17 px when the slot sits at y 292).
const ICON_TARGET := Rect2i(-12, -11, 24, 22)
const COST_TARGET := Rect2i(-12, 11, 24, 17)
## A refused tap nudges the icon (never the numbers) by whole pixels.
const NUDGE: Array[int] = [1, -1, 1, -1, 0]
const NUDGE_STEP: float = 0.04

var kind: String = "":
	set(value):
		kind = value
		if _icon != null:
			_icon.kind = value

var _loaded: bool = false
var _nudge_time: float = -1.0

@onready var _icon: PackView = $Icon
@onready var _count: Label = $Count
@onready var _cost: Label = $Cost


func _ready() -> void:
	_icon.radius_override = ICON_RADIUS
	_icon.kind = kind
	_count.label_settings = HudText.secondary(Palette.M6)
	_cost.label_settings = HudText.secondary(Palette.D0)


func _process(delta: float) -> void:
	advance(delta)


## A short C1 bar under the loaded pack: warm, because it is what the slingshot will fire.
func _draw() -> void:
	if _loaded:
		draw_rect(Rect2(-3, 8, 7, 1), Palette.C1)


func show_pack(count: int, cost: int, affordable: bool, loaded: bool) -> void:
	_count.text = "×%d" % count
	_cost.text = "%d" % cost
	# Cool N7 when the dust isn't there: warm/light colours mean something you can use.
	_cost.label_settings.font_color = Palette.D0 if affordable else Palette.N7
	_loaded = loaded
	queue_redraw()


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


## Moves the nudge forward. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _nudge_time < 0.0:
		return
	_nudge_time += delta
	var step: int = int(_nudge_time / NUDGE_STEP)
	if step >= NUDGE.size():
		_nudge_time = -1.0
		_icon.position = Vector2.ZERO
		return
	_icon.position = Vector2(NUDGE[step], 0)
