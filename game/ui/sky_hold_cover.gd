class_name SkyHoldCover
extends CanvasLayer
## The plaque shown while the run's sky doesn't fit the screen (docs/wide_sky_design.md Q1): a window
## made smaller or turned upright mid-run, a tablet turned. Main holds the game still under it and
## lets go once the sky fits again. It says why and what to do: PAUSED, THE SKY NO LONGER FITS, and
## the action (action_line), and on a desktop the fullscreen key (key_line). Owns no rules: Main decides when it shows (ScreenZones.holds_sky).
## Over the player's own pause menu (which has its PAUSED heading) it drops its heading and sits just
## below the menu's plaque, so one PAUSED reads and the menu stays whole (show_hold's `below`).
## Text is bitmap-font Labels (HudText); the plaque is drawn in code: N0 fill, N6 border with clipped
## corners, like the end screen's. It draws in game coordinates (Main sets `offset` like the other
## UI layers) and centres on the visible screen (fit_screen). Nothing on it is interactive, so
## nothing on it is warm but the heading, as on every menu.

const HEADING: String = "PAUSED"
const REASON: String = "THE SKY NO LONGER FITS"
## The action, by the cause: the width short (or both), only the height short, or a wide run's
## phone or tablet turned upright.
const WIDEN_TEXT: String = "WIDEN THE WINDOW TO PLAY ON"
const GROW_TEXT: String = "GROW THE WINDOW TO PLAY ON"
const TURN_TEXT: String = "TURN THE SCREEN BACK TO PLAY ON"
## On a desktop, the way out when the window can't be made bigger (a maximised laptop window):
## FullscreenKey's F11 (Alt+Enter also works; one key keeps the line short).
const KEY_TEXT: String = "OR PRESS F11 FOR FULL SCREEN"
const WIDTH: int = 140
const PADDING: int = 8
## The heading's 5x7 row plus a 5 px gap, then each 3x5 row plus a 3 px gap.
const HEADING_STEP: int = 12
const LINE_STEP: int = 8
## Under another plaque (`below`), this far beneath it.
const BELOW_GAP: int = 4

var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
var _below := Rect2i()
var _canvas := Node2D.new()
var _heading := Label.new()
var _reason := Label.new()
var _action := Label.new()
var _key := Label.new()


func _init() -> void:
	layer = 40
	visible = false
	add_child(_canvas)
	_canvas.draw.connect(_draw_plaque)
	_heading.label_settings = HudText.primary(Palette.C1)
	_reason.label_settings = HudText.secondary(Palette.N8)
	_action.label_settings = HudText.secondary(Palette.M6)
	_key.label_settings = HudText.secondary(Palette.M6)
	_heading.text = HEADING
	_reason.text = REASON
	for label: Label in [_heading, _reason, _action, _key] as Array[Label]:
		_canvas.add_child(label)


## What the player can do so that a run whose sky is `sky` fits a visible area of `visible` px, by the
## cause. A wide run (its sky has side columns) on a phone or tablet (`mobile`) whose screen is now
## upright (taller than wide) was turned: turn it back. A square screen can't have been turned from a
## landscape one, and turning it changes nothing. Otherwise the window was made smaller (a desktop, or
## a phone's split-screen or freeform window, where turning wouldn't help): widen it if the sky is cut
## at its sides, else grow it (only the height is short).
static func action_line(visible: Vector2, sky: Rect2i, mobile: bool) -> String:
	if mobile and sky.position.x < 0 and visible.y > visible.x:
		return TURN_TEXT
	var field: Rect2i = ScreenZones.sky_field(sky)
	var screen := Rect2i(-ScreenZones.game_offset(visible), Vector2i(visible.floor()))
	return WIDEN_TEXT if screen.position.x > field.position.x or screen.end.x < field.end.x else GROW_TEXT


## The extra line under the action: the fullscreen key on a desktop (`desktop`, the `pc` feature),
## none on a phone or tablet, which has no key to press.
static func key_line(desktop: bool) -> String:
	return KEY_TEXT if desktop else ""


## Shows the plaque with `action` (action_line) and, when not empty, `key` (key_line) under it,
## centred on `screen`, or hides it (`on` false). With a `below` that has area (the player's pause
## menu's plaque, open under the hold), it drops its PAUSED heading and sits centred just below that
## plaque instead.
func show_hold(on: bool, screen: Rect2i, action: String = "", below: Rect2i = Rect2i(), key: String = "") -> void:
	visible = on
	_screen = screen
	_below = below
	_action.text = action
	_key.text = key
	_key.visible = not key.is_empty()
	_layout()


func is_showing() -> bool:
	return visible


## The action line shown (tests).
func action_text() -> String:
	return _action.text


## The fullscreen key line shown, empty when there is none (tests).
func key_text() -> String:
	return _key.text if _key.visible else ""


## Whether the plaque shows its PAUSED heading (not under the pause menu).
func shows_heading() -> bool:
	return visible and _heading.visible


## The plaque, in game coordinates: WIDTH wide, centred on the screen on whole pixels.
## Under `below` (show_hold), it has no heading row and its top is BELOW_GAP under that plaque.
## The key line, when shown, adds a row.
func plaque_rect() -> Rect2i:
	var lines: int = PADDING * 2 + LINE_STEP + 5 + (LINE_STEP if _key.visible else 0)
	if _below.has_area():
		return Rect2i(_below.position.x + (_below.size.x - WIDTH) / 2, _below.end.y + BELOW_GAP, WIDTH, lines)
	var height: int = lines + HEADING_STEP
	var centre: Vector2i = _screen.position + _screen.size / 2
	return Rect2i(centre - Vector2i(WIDTH, height) / 2, Vector2i(WIDTH, height))


func _layout() -> void:
	var plaque: Rect2i = plaque_rect()
	var top: int = plaque.position.y + PADDING
	_heading.visible = not _below.has_area()
	if _heading.visible:
		_centre(_heading, plaque.position.x, top)
		top += HEADING_STEP
	_centre(_reason, plaque.position.x, top)
	_centre(_action, plaque.position.x, top + LINE_STEP)
	_centre(_key, plaque.position.x, top + LINE_STEP * 2)
	_canvas.queue_redraw()


## Centres `label` across the plaque from `left`, on whole pixels, its top at `top`.
func _centre(label: Label, left: int, top: int) -> void:
	label.reset_size()
	label.position = Vector2(left + (WIDTH - floori(label.size.x)) / 2, top)


func _draw_plaque() -> void:
	var r := Rect2(plaque_rect())
	_canvas.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Palette.N0)
	_canvas.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), Palette.N6)
	_canvas.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), Palette.N6)
	_canvas.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), Palette.N6)
	_canvas.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), Palette.N6)
