class_name PackView
extends Node2D
## One star pack, drawn from its art (assets/art/pack_<kind>.png, tools/art/build_ui_art.py).
## Blue: a banded planet, r8. Red: a smaller planet with a ring. Lit from the top-left, no outline.
## Tremble frames are drawn, never scaled: `grown` is the next radius up, `bright` is every pixel
## one step up its ramp. The HUD shows the r6 frame, still: lit a step up when the dust can buy
## one, `greyed` (on the land ramp) when it can't.
## Idle, the planet spins: its bands drift through SPIN_FRAMES frames, one every SPIN_STEP.

const RADIUS: Dictionary[String, int] = {"blue": 8, "red": 6}
## The HUD's icon radius, the only override the art has a frame for.
const HUD_RADIUS: int = 6
## The idle spin: a full turn in SPIN_FRAMES frames.
const SPIN_FRAMES: int = 6
const SPIN_STEP: float = 0.18

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
var greyed: bool = false:
	set(value):
		greyed = value
		queue_redraw()
## Draws the planet at this radius instead of the kind's own (0 = the kind's). The HUD uses r6.
var radius_override: int = 0:
	set(value):
		radius_override = value
		queue_redraw()


var _spin_time: float = 0.0
var _spin: int = 0


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var frame: String = frame_name(grown, bright, radius_override, _spin, greyed)
	if RADIUS.has(kind):
		ArtStrip.named("pack_" + kind).draw(self, frame)


## The pack's pixels as offsets from its centre, read from its art. Empty for an unknown kind.
static func pixels(p_kind: String, p_grown: bool = false, p_bright: bool = false, p_radius: int = 0, p_greyed: bool = false) -> Dictionary[Vector2i, Color]:
	if not RADIUS.has(p_kind):
		return {} as Dictionary[Vector2i, Color]
	return ArtStrip.named("pack_" + p_kind).pixels(frame_name(p_grown, p_bright, p_radius, 0, p_greyed))


## The spin frame showing now, 0 to SPIN_FRAMES - 1.
func spin_frame() -> int:
	return _spin


## Moves the idle spin on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_spin_time += delta
	var spin: int = floori(_spin_time / SPIN_STEP) % SPIN_FRAMES
	if spin != _spin:
		_spin = spin
		if not grown and not bright and radius_override == 0:
			queue_redraw()


## The art frame for a state: the HUD's r6 icon (still; lit or grey), the tremble's grown and
## bright steps, or the idle spin's frame `spin`. Only the HUD's icon has a grey frame.
static func frame_name(p_grown: bool, p_bright: bool, p_radius: int, spin: int = 0, p_greyed: bool = false) -> String:
	if p_radius == HUD_RADIUS:
		if p_greyed:
			return "hud_grey"
		return "hud_bright" if p_bright else "hud"
	assert(not p_greyed, "only the HUD's r%d icon greys out" % HUD_RADIUS)
	assert(p_radius == 0, "pack art has the kind's own radius and the HUD's r%d only" % HUD_RADIUS)
	if p_grown:
		return "grown_bright" if p_bright else "grown"
	return "bright" if p_bright else "idle_%d" % posmod(spin, SPIN_FRAMES)
