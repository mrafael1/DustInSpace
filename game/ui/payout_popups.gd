class_name PayoutPopups
extends CanvasLayer
## Floating dust payouts (#59): a collected link's dust pops out of it as "+3" and a small dust
## diamond, rises a few pixels and stays until that payout's last dust particle lands on the
## counter (CollectParticles, wired by Main), then goes. The top combo's payout flashes C0 and hops.
## On the Scorpio map, each star the Sun bursts pops its own dust the same way, as it bursts.
## Feedback only: the dust is credited by the core and counted as the particles land; nothing here
## holds the sequencer or takes input. Numbers are Labels in the 5x7 font; nothing is baked in.
## Placed in game coordinates (Main offsets the layer like the HUD): starting at the link's middle,
## pushed away from its last star (where the finger lifted), inside the visible sky, and moved to
## the nearest free spot (up first, then down, then sideways) if it would overlap one showing.

## A popup's parts: the number, a gap, then the small dust diamond.
const TEXT_HEIGHT: int = 7
const GLYPH_ADVANCE: int = 6
const ICON_GAP: int = 1
const ICON_SIZE: int = 5
## The diamond's centre: 3 px in from the popup's right end, on the text's middle row.
const ICON_CENTRE := Vector2i(-3, 3)
## Rise RISE px, one per RISE_STEP; linger a moment after the dust lands; never shorter than
## MIN_TIME nor longer than MAX_TIME (if the landing never comes, e.g. a restart).
const RISE: int = 5
const RISE_STEP: float = 0.05
const LINGER: float = 0.15
const MIN_TIME: float = 0.8
const MAX_TIME: float = 2.5
## Where it starts: this far from the link's middle, away from its last star, and a bit up.
const PUSH: int = 10
const LIFT: int = 6
## The top payout: a C0 flash for FLASH_TIME, then a 1 px hop at HOP_AT for HOP_TIME.
const FLASH_TIME: float = 0.08
const HOP_AT: float = 0.4
const HOP_TIME: float = 0.12
## Space kept between a popup and the visible screen's sides.
const EDGE: int = 2


class PayoutPopup:
	extends RefCounted
	var payout: int
	var node: Node2D
	var label: Label
	var start: Vector2i
	var size: Vector2i
	var top: bool
	## Seconds before it shows (a star the Sun bursts shows its dust as it bursts).
	var delay: float = 0.0
	## Seconds since it was asked for; it shows from `delay` on.
	var age: float = 0.0
	## Seconds left once its dust has landed; INF while it's still flying.
	var leave_in: float = INF

	## Seconds it has been showing (0 while it waits for its delay).
	func shown_for() -> float:
		return maxf(age - delay, 0.0)

	func rect() -> Rect2i:
		return Rect2i(start - Vector2i(0, RISE), size + Vector2i(0, RISE))


var _run: RunState
var _popups: Array[PayoutPopup] = []
var _top_dust: int = 0
## The visible screen in game coordinates (Main's fit_screen).
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)


func _process(delta: float) -> void:
	advance(delta)


## A new run clears every popup still showing.
func setup(run: RunState, _sequencer: EventSequencer) -> void:
	_run = run
	_top_dust = 0
	for reward: Balance.ComboReward in run.balance.combos.values():
		_top_dust = maxi(_top_dust, reward.dust)
	clear()


func fit_screen(screen: Rect2i) -> void:
	_screen = screen


func clear() -> void:
	for popup: PayoutPopup in _popups:
		popup.node.queue_free()
	_popups.clear()


func count() -> int:
	return _popups.size()


## The text showing for each popup, oldest first.
func texts() -> Array[String]:
	var shown: Array[String] = []
	for popup: PayoutPopup in _popups:
		shown.append(popup.label.text)
	return shown


## Each popup's rectangle now (text and icon), oldest first, in game coordinates.
func rects() -> Array[Rect2i]:
	var shown: Array[Rect2i] = []
	for popup: PayoutPopup in _popups:
		shown.append(Rect2i(Vector2i(popup.node.position), popup.size))
	return shown


## Dust set off from `stars` (a link's, in link order, or one star the Sun burst): show
## "+amount" for it, after `delay` seconds.
func show_payout(payout: int, amount: int, stars: Array[Vector2i], delay: float = 0.0) -> void:
	if amount <= 0 or stars.is_empty() or _run == null:
		return
	var popup := PayoutPopup.new()
	popup.payout = payout
	popup.delay = delay
	popup.top = amount >= _top_dust
	popup.size = Vector2i(("+%d" % amount).length() * GLYPH_ADVANCE - 1 + ICON_GAP + ICON_SIZE, TEXT_HEIGHT)
	popup.start = _stack(place(stars, popup.size, bounds()), popup.size)
	popup.node = Node2D.new()
	popup.label = Label.new()
	popup.label.text = "+%d" % amount
	popup.label.label_settings = HudText.primary(Palette.C0 if popup.top else Palette.D0)
	popup.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.node.add_child(popup.label)
	var icon := DustIcon.new()
	icon.small = true
	icon.position = Vector2(Vector2i(popup.size.x, 0) + ICON_CENTRE)
	popup.node.add_child(icon)
	add_child(popup.node)
	_popups.append(popup)
	_pose(popup)


## The last dust of `payout` landed: its popup goes after a moment.
func release(payout: int) -> void:
	for popup: PayoutPopup in _popups:
		if popup.payout == payout and popup.leave_in == INF:
			popup.leave_in = maxf(LINGER, MIN_TIME - popup.shown_for())


## Moves every popup on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	var gone: Array[PayoutPopup] = []
	for popup: PayoutPopup in _popups:
		popup.age += delta
		popup.leave_in -= delta
		if popup.leave_in <= 0.0 or popup.shown_for() >= MAX_TIME:
			gone.append(popup)
		else:
			_pose(popup)
	for popup: PayoutPopup in gone:
		popup.node.queue_free()
		_popups.erase(popup)


## Where popups may go: the visible screen's width (less EDGE) and the run's sky's height.
func bounds() -> Rect2i:
	var sky: Rect2i = _run.sky_rect if _run != null else ScreenZones.SKY
	return Rect2i(_screen.position.x + EDGE, sky.position.y, _screen.size.x - 2 * EDGE, sky.size.y)


## Where a popup of `size` starts (its top-left before rising) for a link through `stars`:
## centred a little up from the link's middle, pushed away from the last star, and clamped so it
## stays inside `area` all the way up.
static func place(stars: Array[Vector2i], size: Vector2i, area: Rect2i) -> Vector2i:
	var middle := Vector2.ZERO
	for star: Vector2i in stars:
		middle += Vector2(star)
	middle /= stars.size()
	var away: Vector2 = middle - Vector2(stars[-1])
	if away.length() < 1.0:
		away = Vector2.UP
	var centre := Vector2i((middle + away.normalized() * PUSH).round()) - Vector2i(0, LIFT)
	var at: Vector2i = centre - size / 2
	return Vector2i(
		clampi(at.x, area.position.x, area.end.x - size.x),
		clampi(at.y, area.position.y + RISE, area.end.y - size.y))


## The nearest free spot for a popup of `size` wanted at `at`: the same column a row up, a row
## down, two rows up and so on; then the same one popup-width to the left and right. Only spots
## inside the sky all the way up count. With no free spot anywhere, `at` (it overlaps).
@warning_ignore("integer_division")
func _stack(at: Vector2i, size: Vector2i) -> Vector2i:
	var area: Rect2i = bounds()
	var row: int = TEXT_HEIGHT + RISE + 1
	var rows: Array[int] = [0]
	for k: int in range(1, area.size.y / row + 1):
		rows.append_array([-k, k])
	for column: int in [0, -1, 1, -2, 2]:
		for r: int in rows:
			var spot: Vector2i = at + Vector2i(column * (size.x + ICON_GAP + 1), r * row)
			if _fits(spot, size, area) and not _clashes(spot, size):
				return spot
	return at


## True if a popup of `size` at `spot` stays inside `area` all the way up its rise.
static func _fits(spot: Vector2i, size: Vector2i, area: Rect2i) -> bool:
	return area.encloses(Rect2i(spot - Vector2i(0, RISE), size + Vector2i(0, RISE)))


## True if a popup of `size` at `spot` would overlap one still showing (or waiting to show).
func _clashes(spot: Vector2i, size: Vector2i) -> bool:
	var rect := Rect2i(spot - Vector2i(0, RISE), size + Vector2i(0, RISE))
	for popup: PayoutPopup in _popups:
		if rect.intersects(popup.rect()):
			return true
	return false


## Rise, the top payout's flash and hop, on whole pixels.
func _pose(popup: PayoutPopup) -> void:
	var shown: float = popup.shown_for()
	popup.node.visible = popup.age >= popup.delay
	var rise: int = mini(int(shown / RISE_STEP), RISE)
	var hop: int = 1 if popup.top and shown >= HOP_AT and shown < HOP_AT + HOP_TIME else 0
	popup.node.position = Vector2(popup.start - Vector2i(0, rise + hop))
	if popup.top:
		popup.label.label_settings.font_color = Palette.C0 if shown < FLASH_TIME else Palette.D0
