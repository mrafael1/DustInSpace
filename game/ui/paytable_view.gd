class_name PaytableView
extends Node2D
## The table (#94): the slot machine's paytable. A plaque over the sky lists each valid link and
## what it pays, read from balance.json, under one line of column heads (COMBOS, DUST, LIGHT): a row
## per triple (small, medium, big) and a row for one of each size, its stars in the sky's own art on
## a dim link line (N4, behind them, so each row reads as a link without competing with the
## rewards); the dust as a lavender number (D0, the dust's colour) by the dust icon, the icons in
## one column; the light as tiny pale gold suns (C1), one per unit (the smallest light any link
## gives, so the suns stay true when tuned), left-aligned. The one-of-each row cuts through all six
## orders in turn: any order counts. Owns no rules; the HUD opens it (the COMBOS button, the
## tutorial's first link), pauses the game while it shows, and closes it at a tap.

const TITLE: String = "COMBOS"
const TAP_TEXT: String = "TAP TO CLOSE"
const DUST_TEXT: String = "DUST"
const LIGHT_TEXT: String = "LIGHT"
## The colours: the dust's lavender, the light's pale gold (its suns' too), a dim line.
const DUST_COLOUR: Color = Palette.D0
const LIGHT_COLOUR: Color = Palette.C1
const LINE_COLOUR: Color = Palette.N4
## Every order of one of each size, cut through in turn, ORDER_TIME each.
const ORDERS: Array[Array] = [
	[Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG],
	[Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM],
	[Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG],
	[Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL],
	[Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM],
	[Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL],
]
const ORDER_TIME: float = 0.6
## The plaque: its top-left and width (centred on the 180 px game), PAD px inside its border.
const PLAQUE_AT := Vector2i(14, 90)
const PLAQUE_W: int = 152
const PAD: int = 7
## Line heights: the column heads, each row (a big star's art plus a gap).
const LINE_STEP: int = 11
const ROW_GAP: int = 9
## Where each column starts, from the plaque's left: the stars (under COMBOS), the dust, the light.
const STARS_X: int = PAD
const STAR_GAP: int = 5
const DUST_X: int = 70
const LIGHT_X: int = 100
## The dust number is right-aligned in DUST_NUM_W px, so the dust icons sit in one column,
## DUST_ICON_DX px right of the dust column's start.
const DUST_NUM_W: int = 11
const DUST_ICON_DX: int = 18
## The light suns: SUN_STEP px apart, each SUN_SIZE px wide (assets/art/light_icon.png).
const SUN_SIZE: int = 7
const SUN_STEP: int = 9
## The most suns a row shows: what fits from LIGHT_X inside the plaque. The unit grows to keep it.
const MAX_SUNS: int = 5

var _open: bool = false
var _time: float = 0.0
## Each row: {"key": combo key, "sizes": Array[int] (the triples'; the one-of-each row cycles),
## "dust": int, "marks": int}.
var _rows: Array[Dictionary] = []
var _labels: Array[Label] = []


func _ready() -> void:
	visible = false


## Opens the table with `balance`'s links and rewards, links paying `dust_percent` of their dust
## (Virgo's pay less).
func open(balance: Balance, dust_percent: int = 100) -> void:
	_rows = rows_for(balance, dust_percent)
	_open = true
	_time = 0.0
	visible = true
	_build_labels()
	queue_redraw()


func close() -> void:
	_open = false
	visible = false


func is_open() -> bool:
	return _open


## The rows on show (copies), for tests.
func rows() -> Array[Dictionary]:
	return _rows.duplicate(true)


## Moves the one-of-each row's orders on. Driven by the HUD; tests call it directly.
func advance(delta: float) -> void:
	if not _open:
		return
	var before: int = order_index(_time)
	_time += delta
	if order_index(_time) != before:
		queue_redraw()


## Which of ORDERS the one-of-each row shows at `time`.
static func order_index(time: float) -> int:
	return int(time / ORDER_TIME) % ORDERS.size()


## The sizes the one-of-each row shows now.
func sequence_sizes() -> Array:
	return ORDERS[order_index(_time)]


## The table's rows for `balance`: the triples (small, medium, big), then one of each; only the
## links balance.json pays for. Each pays `dust_percent` of its dust (rounded down, as the run does).
static func rows_for(balance: Balance, dust_percent: int = 100) -> Array[Dictionary]:
	var unit: int = light_unit(balance)
	var rows: Array[Dictionary] = []
	for k: int in Combos.TRIPLES.size():
		var key: String = Combos.TRIPLES[k]
		if balance.combos.has(key):
			rows.append(_row(key, [k, k, k], balance.combos[key], unit, dust_percent))
	if balance.combos.has(Combos.SEQUENCE):
		rows.append(_row(Combos.SEQUENCE, ORDERS[0], balance.combos[Combos.SEQUENCE], unit, dust_percent))
	return rows


## The light one sun stands for: the smallest light any link gives (1 if none gives light), or
## more when the most light would take over MAX_SUNS suns (any tuning fits the plaque).
static func light_unit(balance: Balance) -> int:
	var unit: int = 0
	var most: int = 0
	for key: String in balance.combos:
		var light: int = balance.combos[key].light
		most = maxi(most, light)
		if light > 0 and (unit == 0 or light < unit):
			unit = light
	return maxi(maxi(unit, ceili(float(most) / MAX_SUNS)), 1)


## How many suns `light` shows, `unit` each (rounded; at least one for any light).
static func light_marks(light: int, unit: int) -> int:
	if light <= 0:
		return 0
	return maxi(roundi(float(light) / unit), 1)


## Where the stars of a row sit: `count` centres from `x`, each in a big star's width, STAR_GAP
## apart, on `mid`.
static func star_centres(count: int, x: int, mid: int) -> Array[Vector2i]:
	var slot: int = StarView.half_extent(Star.Size.BIG) * 2 + 1
	var centres: Array[Vector2i] = []
	for k: int in count:
		centres.append(Vector2i(x + k * (slot + STAR_GAP) + slot / 2, mid))
	return centres


## How wide a row of three stars is, from the first's left to the last's right (COMBOS centres on it).
static func stars_width() -> int:
	var slot: int = StarView.half_extent(Star.Size.BIG) * 2 + 1
	return 3 * slot + 2 * STAR_GAP


## The plaque's rect.
static func plaque_rect(row_count: int) -> Rect2i:
	var height: int = PAD + LINE_STEP + row_count * row_height() + LINE_STEP + PAD - ROW_GAP
	return Rect2i(PLAQUE_AT, Vector2i(PLAQUE_W, height))


## A row's height: a big star's art and ROW_GAP.
static func row_height() -> int:
	return StarView.half_extent(Star.Size.BIG) * 2 + 1 + ROW_GAP


static func _row(key: String, sizes: Array, reward: Balance.ComboReward, unit: int, dust_percent: int) -> Dictionary:
	return {"key": key, "sizes": sizes.duplicate(), "dust": reward.dust * dust_percent / 100, "marks": light_marks(reward.light, unit)}


## The labels: the column heads, each row's dust, TAP TO CLOSE at the bottom (small: it's a hint).
func _build_labels() -> void:
	for label: Label in _labels:
		label.queue_free()
	_labels.clear()
	var plaque: Rect2i = plaque_rect(_rows.size())
	var left: int = plaque.position.x
	var top: int = plaque.position.y + PAD
	var title: Label = _add_label(TITLE, Palette.C1, Vector2i(left + STARS_X, top))
	title.position.x = left + STARS_X + floori((stars_width() - title.get_minimum_size().x) / 2.0)
	_add_label(DUST_TEXT, DUST_COLOUR, Vector2i(left + DUST_X, top))
	_add_label(LIGHT_TEXT, LIGHT_COLOUR, Vector2i(left + LIGHT_X, top))
	for i: int in _rows.size():
		var mid: int = _row_mid(i)
		var dust: Label = _add_label("%d" % _rows[i]["dust"], DUST_COLOUR, Vector2i(left + DUST_X, mid - 3))
		dust.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dust.size = Vector2(DUST_NUM_W, dust.get_minimum_size().y)
	var tap: Label = _add_label(TAP_TEXT, Palette.N8, Vector2i(0, plaque.end.y - PAD - HudText.SECONDARY_SIZE))
	tap.label_settings = HudText.secondary(Palette.N8)
	tap.position.x = ScreenZones.SCREEN.x / 2 - floori(tap.get_minimum_size().x / 2.0)


func _add_label(text: String, colour: Color, at: Vector2i) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = HudText.primary(colour)
	label.text = text
	label.position = Vector2(at)
	add_child(label)
	_labels.append(label)
	return label


## Row `i`'s middle line, in the HUD's coordinates.
func _row_mid(i: int) -> int:
	var first: int = plaque_rect(_rows.size()).position.y + PAD + LINE_STEP
	return first + i * row_height() + StarView.half_extent(Star.Size.BIG)


func _draw() -> void:
	if not _open:
		return
	var plaque: Rect2i = plaque_rect(_rows.size())
	_draw_plaque(plaque)
	for i: int in _rows.size():
		var sizes: Array = sequence_sizes() if _rows[i]["key"] == Combos.SEQUENCE else _rows[i]["sizes"]
		_draw_stars(sizes, plaque.position.x + STARS_X, _row_mid(i))
		var icon: Dictionary[Vector2i, Color] = DustIcon.pixels(true)
		var at := Vector2i(plaque.position.x + DUST_X + DUST_ICON_DX, _row_mid(i))
		for d: Vector2i in icon:
			draw_rect(Rect2(Vector2(at + d), Vector2.ONE), icon[d])
		_draw_suns(_rows[i]["marks"], plaque.position.x + LIGHT_X, _row_mid(i))


## Where a row's suns sit: `count` centres from `x`, SUN_STEP apart, on `mid`.
static func sun_centres(count: int, x: int, mid: int) -> Array[Vector2i]:
	var centres: Array[Vector2i] = []
	for k: int in count:
		centres.append(Vector2i(x + k * SUN_STEP + SUN_SIZE / 2, mid))
	return centres


## A row's light: `count` tiny suns, left-aligned from `x`, centred on `mid`.
func _draw_suns(count: int, x: int, mid: int) -> void:
	var art: Dictionary[Vector2i, Color] = ArtStrip.named("light_icon").pixels("sun")
	for centre: Vector2i in sun_centres(count, x, mid):
		for d: Vector2i in art:
			draw_rect(Rect2(Vector2(centre + d), Vector2.ONE), art[d])


## A row of stars in the sky's art on a dim line through them, from `x`, centred on `mid`. Each
## takes a big star's width so the columns stay put as the orders change.
func _draw_stars(sizes: Array, x: int, mid: int) -> void:
	var centres: Array[Vector2i] = star_centres(sizes.size(), x, mid)
	for p: Vector2i in LinkLayer.line_pixels(centres[0], centres[-1]):
		draw_rect(Rect2(Vector2(p), Vector2.ONE), LINE_COLOUR)
	for k: int in sizes.size():
		var art: Dictionary[Vector2i, Color] = ConstellationView.star_pixels(sizes[k])
		for d: Vector2i in art:
			draw_rect(Rect2(Vector2(centres[k] + d), Vector2.ONE), art[d])


## A filled rect with a 1 px border that skips its four corner pixels (the end screen's plaque).
func _draw_plaque(rect: Rect2i) -> void:
	var r := Rect2(rect)
	draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Palette.N0)
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), Palette.N6)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), Palette.N6)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), Palette.N6)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), Palette.N6)
