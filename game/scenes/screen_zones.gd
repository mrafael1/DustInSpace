class_name ScreenZones
extends RefCounted
## Screen zones of the game's own 180x320 screen, from docs/art-direction.md. Layout, not balance.
## They are the portrait frame: a window that shows more (taller, or a landscape one) widens and
## raises the play sky past SKY (play_sky), in the same game pixels, so a position can be above 0
## or, on a wide sky, left of 0 and right of 180.
## Land overlaps the bottom of the sky on purpose: the horizon sits behind the lowest stars.

const SUN := Rect2i(0, 0, 180, 78)
const SKY := Rect2i(0, 78, 180, 172)
const LAND := Rect2i(0, 230, 180, 54)
const HUD := Rect2i(0, 284, 180, 36)
## The game's own screen. A window that isn't 9:16 (a taller phone, a desktop window, a tablet on its
## side) shows more than this (Main sizes the view to fill the window at a whole-number scale,
## fill_size): the game sits at the bottom, centred across, and the play sky and the Backdrop fill the
## rest (sky above, and on a landscape window sky to both sides).
const SCREEN := Vector2i(180, 320)
## The Sun's centre on a 9:16 screen. On a taller one it rises by the extra height (sun_centre),
## to the top of the screen, and the play sky grows up into the space it leaves (play_sky).
const SUN_CENTRE := Vector2i(90, 39)


## The widest play sky, in game px: 16:9 shows 640 columns at every whole-number scale (1080p at
## 3x, 1440p at 4x, 4K at 6x). A wider window keeps a 640-wide sky and the Backdrop fills the rest.
const MAX_SKY_WIDTH := 640


## The play sky when the screen shows `rows` more rows above the game's 180x320 and `side` more
## columns on each side of it. With side 0 it is the portrait sky, the game's own 180 columns.
static func play_sky(rows: int, side: int = 0) -> Rect2i:
	return Rect2i(SKY.position.x - side, SKY.position.y - rows, SKY.size.x + 2 * side, SKY.size.y + rows)


## Whether a visible area of `visible` px is wide enough to widen the play sky: only a landscape one,
## wider than it is tall (a desktop window, a tablet held sideways). A portrait one, every phone, a
## tablet held upright or a tall desktop window, keeps the game's own 180 columns whatever columns it
## has to spare, so it looks and plays as it always has (the user, 2026-10-20). A square one counts
## as portrait.
static func widens_sky(visible: Vector2) -> bool:
	return visible.x > visible.y


## How far the play sky reaches past the game's screen in a visible area of `visible` px: x is the
## columns added on EACH side, y the rows added above. Only a landscape area adds columns (widens_sky);
## a portrait one adds rows only, its spare columns staying backdrop. Both sides get the same columns
## (game_offset's floor of half the extra width), so the sky stays centred on x 90 and an odd leftover
## column is backdrop; the width caps at MAX_SKY_WIDTH. Rows have no cap: tall phones already grow
## upward.
static func sky_margin(visible: Vector2) -> Vector2i:
	var offset: Vector2i = game_offset(visible)
	var side: int = mini(offset.x, (MAX_SKY_WIDTH - SKY.size.x) / 2) if widens_sky(visible) else 0
	return Vector2i(side, offset.y)


## The smallest desktop window, in device px (docs/wide_sky_design.md Q1, the user 2026-10-20): small
## enough that a maximised window on a 1366x768 laptop (about 1366x705) still opens. At 1x it shows
## 960x540, more than the whole widest sky; a window under 640 px tall plays at 1x. Phones and tablets
## size their own window, so they get none.
const MIN_WINDOW := Vector2i(960, 540)
## The desktop window when the player leaves fullscreen (the game opens fullscreen on a desktop,
## project.godot's `.pc` overrides): 16:9 at 2x, 640x360, the whole widest sky.
const WINDOWED_SIZE := Vector2i(1280, 720)
## A handheld screen whose shorter side is at least this many dp is a tablet (Android's sw600dp).
const TABLET_MIN_DP := 600


## The window's minimum size: MIN_WINDOW on a desktop (`desktop`), none (zero) elsewhere.
static func min_window(desktop: bool) -> Vector2i:
	return MIN_WINDOW if desktop else Vector2i.ZERO


## Whether a handheld screen of `screen` px at `dpi` is a tablet, which may turn (Q9): an iPad
## (`model` from OS.get_model_name, on iOS), or a screen whose shorter side is at least TABLET_MIN_DP
## dp (px * 160 / dpi, as Android counts it). A phone, or an unknown dpi, is not.
static func is_tablet(model: String, screen: Vector2i, dpi: int) -> bool:
	if model.begins_with("iPad"):
		return true
	if model.begins_with("iPhone") or model.begins_with("iPod") or dpi <= 0:
		return false
	return mini(screen.x, screen.y) * 160 >= TABLET_MIN_DP * dpi


## What a run needs on screen: its play sky `sky` and the Sun's band above it (the Sun follows the
## run's sky), down to the bottom of the game's screen (the land and the HUD), across the sky's width.
static func sky_field(sky: Rect2i) -> Rect2i:
	var top: int = sky.position.y - SUN.size.y
	return Rect2i(sky.position.x, top, sky.size.x, SCREEN.y - top)


## Whether a visible area of `visible` px still shows the whole of a run whose play sky is `sky`
## (sky_field), with the game's screen placed as game_offset places it. A run built for this area
## always fits it (play_sky from sky_margin); one built for a larger or wider area may not, and the
## game holds still until it fits again (Main, Q1).
static func holds_sky(visible: Vector2, sky: Rect2i) -> bool:
	var screen := Rect2i(-game_offset(visible), Vector2i(visible.floor()))
	return screen.encloses(sky_field(sky))


## The distance from `from` to the farthest corner pixel of `rect` (its last column and row are
## `end - 1`).
static func farthest_corner(from: Vector2i, rect: Rect2i) -> float:
	var lo: Vector2i = rect.position
	var hi: Vector2i = rect.end - Vector2i.ONE
	var far: float = 0.0
	for corner: Vector2i in [lo, Vector2i(hi.x, lo.y), Vector2i(lo.x, hi.y), hi]:
		far = maxf(far, Vector2(corner - from).length())
	return far


## How much longer an animation that covers `far` px runs than one covering `home` px, the farthest
## it covers on the portrait frame (docs/wide_sky_design.md §4): 1 up to `home`, so a portrait sky
## keeps today's timing; past it, in proportion, so it keeps today's speed.
static func stretch(far: float, home: float) -> float:
	return maxf(1.0, far / home) if home > 0.0 else 1.0


## The Sun's centre when the screen shows `extra` more rows above the game's 180x320.
static func sun_centre(extra: int) -> Vector2i:
	return SUN_CENTRE - Vector2i(0, extra)


## The largest whole-number scale at which the game's screen fits in a window of `window` px.
static func fill_scale(window: Vector2i) -> int:
	return maxi(1, mini(window.x / SCREEN.x, window.y / SCREEN.y))


## The view that fills a window of `window` px at fill_scale: as many game pixels as fit, never
## fewer than the game's screen. What's left over is under one scale step (a few device pixels).
static func fill_size(window: Vector2i) -> Vector2i:
	var scale: int = fill_scale(window)
	return Vector2i(window.x / scale, window.y / scale).max(SCREEN)


## Where the game's screen sits in a visible area of `visible` px, on whole pixels: centred across
## and on the bottom edge, so the HUD sits at the bottom and the extra height is sky above.
static func game_offset(visible: Vector2) -> Vector2i:
	var extra := Vector2i((visible - Vector2(SCREEN)).floor()).max(Vector2i.ZERO)
	return Vector2i(extra.x / 2, extra.y)


## A pointer event in game coordinates (the game's 180x320 screen at 0,0; a wide sky reaches past it
## at negative x and past 180), from one in the visible area's.
static func to_game(event: InputEvent, offset: Vector2i) -> InputEvent:
	return event.xformed_by(Transform2D(0.0, Vector2(-offset)))
