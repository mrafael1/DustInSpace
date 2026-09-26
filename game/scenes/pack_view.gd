class_name PackView
extends Node2D
## One star pack, drawn from its art (assets/art/pack_<kind>.png, tools/art/build_ui_art.py).
## Blue: a banded planet, r8. Red: a smaller planet with a ring. Lit from the top-left, no outline.
## Tremble frames are drawn, never scaled: `grown` is the next radius up, `bright` is every pixel
## one step up its ramp. The HUD shows the r6 frame.

const RADIUS: Dictionary[String, int] = {"blue": 8, "red": 6}
## The HUD's icon radius, the only override the art has a frame for.
const HUD_RADIUS: int = 6

## "" draws nothing.
var kind: String = "":
	set(value):
		kind = value
		queue_redraw()
var grown: bool = false:
	set(value):
		grown = value
		queue_redraw()
var bright: bool = false:
	set(value):
		bright = value
		queue_redraw()
## Draws the planet at this radius instead of the kind's own (0 = the kind's). The HUD uses r6.
var radius_override: int = 0:
	set(value):
		radius_override = value
		queue_redraw()


func _draw() -> void:
	var frame: String = frame_name(grown, bright, radius_override)
	if RADIUS.has(kind):
		ArtStrip.named("pack_" + kind).draw(self, frame)


## The pack's pixels as offsets from its centre, read from its art. Empty for an unknown kind.
static func pixels(p_kind: String, p_grown: bool = false, p_bright: bool = false, p_radius: int = 0) -> Dictionary[Vector2i, Color]:
	if not RADIUS.has(p_kind):
		return {} as Dictionary[Vector2i, Color]
	return ArtStrip.named("pack_" + p_kind).pixels(frame_name(p_grown, p_bright, p_radius))


## The art frame for a state: the HUD's r6 icon, or the tremble's grown and bright steps.
static func frame_name(p_grown: bool, p_bright: bool, p_radius: int) -> String:
	if p_radius == HUD_RADIUS:
		return "hud"
	assert(p_radius == 0, "pack art has the kind's own radius and the HUD's r%d only" % HUD_RADIUS)
	if p_grown:
		return "grown_bright" if p_bright else "grown"
	return "bright" if p_bright else "idle"
