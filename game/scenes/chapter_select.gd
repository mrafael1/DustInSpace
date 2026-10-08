class_name ChapterSelect
extends CanvasLayer
## A chapter's chart (#62; ChapterDef gives its figure, stages and crown): the constellation as a
## pixel-art star chart over deep space (a stepped sky, a milky way, faint nebulae and cool
## background stars). Its stars are grouped into the chapter's part stages (Scorpio's Stinger,
## Tail, Body, Heart, Claws, travelled from the tail), and a crown point above the figure is the
## final stage, the full constellation. The text below describes Scorpio's chart; another chapter
## draws the same way, leaving out paintings it doesn't have yet (has_art). Tap a star to select
## the stage it belongs to (a comet travels there); PLAY starts it if it's available or completed.
## Locked stages can be selected to see what they are, never played.
## A stage's stars are gold once it's won; the stage to play next shows warm, with a breathing
## ring round its point (its first star from the tail); locked ones are cool and quieter. Each
## part's point is its main star: bigger than the rest and in its own tone (icy blue while locked,
## white gold once won), twinkling on its own beat; the point to play next is the biggest and flares
## brighter once a beat (solid steps, no fades). The
## selected stage's point wears C0 corner brackets. The path is solid: gold between won stars,
## warm through and into the stage to play next, a cool guide elsewhere. Numbers (3x5, UI text)
## count the stages from the tail. The selected stage sits in a chart label at the bottom, with no
## box: its name between two thin rules tipped with little stars, and PLAY below in the game's
## button style (N0 fill, C2 border).
## The space behind is alive: dust motes drift slowly along the milky way, some background stars
## twinkle, and now and then a cool shooting star streaks across behind the chart.
## Back from a won stage (show_progress), its point flashes as its stars light, then a comet
## travels to the stage it opened. Owns no rules: Chapter says what's won and available.
## The final's unlock (back from the win that opened it) plays bigger: after the point lights, a
## comet flies from every part's main star into the crown at once (UNLOCK_STAGGER apart, from the
## tail), rings close in on it, then it bursts: a ring thrown out to the screen's edge, eight rays,
## and every string flashing C0 for a beat. Then the final is selected. While it's open and not yet
## won, the crown is the boss's point: bigger, with diagonal glints, wearing an ember ring (S4).
## The chart assembles the painted Scorpio as the parts are won: each won part's piece of it
## (assets/art/scorpio_piece_<part>.png) lies behind the chart's stars, dormant (a few steps darker
## on the N ramp); back from a part's win its piece forms first from that part's stars on the chart,
## as a stage's painting does (#100, Apparition). Winning
## the final brings the scorpion to life: the whole figure flashes C0 twice, then shows in full
## colour from then on.
## The options' gear (App's OptionsMenu) sits in the screen's top-right corner, over the chart.
## Chapters: an arrow either side of the heading leads to the chapter before and after (none at the
## ends): a warm chevron when that chapter is open, a padlock while it's locked. The chapters share
## one sky, the zodiac along the ecliptic, each chart at its own sign's place: a tap on an arrow, or
## a swipe across the chart, is a voyage along it, the camera easing out of one constellation and
## past the others (faint, named) into the next, the background stars drifting behind at their own
## depth and streaking with the speed; a tap on a padlock shakes it and the subtitle says why. Back from the win of a final that
## opens the next chapter, once the figure has come to life, that padlock shakes and glows, bursts
## into shards, and a comet streaks from the crown out past the arrow and leads the voyage on to
## the new chapter, whose stars pop in one by one from its first stage under a shower of sparkles while
## the subtitle says NEW CHAPTER, then a comet runs from its crown to the stage to play.
## The game opens on the title (show_title): the camera a screen above the chart, in the same sky
## (the milky way and nebulae hold still, the background stars sit at their depth), with the title
## (TitleView) over it. A tap anywhere starts the way down (title_left): the light star under the
## title lifts off and leads, the camera eases down the sky at the voyage's pace (speeding up,
## cruising, slowing down over DESCENT_TIME; the stars drift up behind at STAR_PARALLAX of its
## speed) and the star lands on the stage to play (star_landed), where the chart takes over.
## Works in game coordinates (App sets the layer's offset like Main's UI layers).

## The player asked to play stage `stage`.
signal stage_chosen(stage: int)
## The player asked for the chapter `step` away (an arrow or a swipe: -1 before, +1 after). Only
## for an open one: a locked one is refused here (nav_refused).
signal chapter_step_requested(step: int)
## The next chapter's opening has played (its padlock broke, the comet left): App voyages on to it.
signal chapter_opened
## The selection star landed on the new chapter's stage at the end of a voyage. Feedback only (sound).
signal star_landed
## Feedback only (sound): a voyage to another chapter began; a padlock refused a tap; the opening
## padlock started shaking, then broke; the reveal popped its `order`-th star, then ended.
signal slid
signal nav_refused
signal padlock_shaken
signal padlock_broke
signal star_revealed(order: int)
signal chapter_revealed
## The player tapped the title: the way down to the chart began. Feedback only (sound).
signal title_left

## How a string of the path shows: a cool guide, the way to the stage to play next, or travelled.
enum Leg { GUIDE, NEXT, LIT }
## Where an arrow leads: nowhere (no chapter that way), a locked chapter, an open one.
enum Nav { NONE, LOCKED, OPEN }

const TITLE_Y: int = 30
const SUBTITLE_Y: int = 42
## The stage label: the name, and PLAY below; both inside PANEL (no box drawn).
const INFO_Y: int = 250
const PLAY := Rect2i(58, 265, 64, 21)
const PANEL := Rect2i(26, 236, 128, 52)
## On a taller phone (fit_screen) the heading goes to the top of the screen, the label stays at the
## bottom, and the chart sits halfway between; PLAY also drops up to PLAY_ROOM px below the name.
const PLAY_ROOM: int = 4
## The rules either side of the name: RULE px long, RULE_GAP px from it, a small star at the far end.
const RULE: int = 14
const RULE_GAP: int = 5
## Press circle around a point: 44 pt at 2 pt per px.
const HIT_RADIUS: int = 12
## The breathing ring round the point to play next: radius RING_RADIUS or one more, swapping every
## RING_STEP.
const RING_STEP: float = 0.45
const RING_RADIUS: int = 9
## A part's main star twinkles (step 1) for TWINKLE_ON once every TWINKLE_PERIOD, each part
## TWINKLE_OFFSET later than the one before, so they never all twinkle together.
const TWINKLE_PERIOD: float = 1.6
const TWINKLE_ON: float = 0.15
const TWINKLE_OFFSET: float = 0.55
## The point to play next flares once every FLARE_PERIOD: FLARE_STEPS says how long each step lasts
## (1: rising, 2: full, 1: falling), then it rests at step 0.
const FLARE_PERIOD: float = 1.2
const FLARE_STEPS: Array[Vector2] = [Vector2(0.08, 1), Vector2(0.2, 2), Vector2(0.3, 1)]
## The chart redraws its animations at most once per ANIM_TICK.
const ANIM_TICK: float = 1.0 / 30.0
## A comet travels the strings at TRAVEL_SPEED px a second: a small star for a head (C0 heart, C1
## arms) and a trail TRAIL long, cooling to C4.
const TRAVEL_SPEED: float = 140.0
const TRAIL: Array[Color] = [Palette.C0, Palette.C1, Palette.C1, Palette.C2, Palette.C2, Palette.C3, Palette.C3, Palette.C4, Palette.C4]
## A point lighting throws a ring out LIGHT_GROWTH px over LIGHT_TIME, cooling C0 to C3.
const LIGHT_TIME: float = 0.45
const LIGHT_GROWTH: int = 12
const LIGHT_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
## Space behind the chart (cool colours only: warm is for the route and stages). The sky steps
## down from N0 to N2 through ordered-dither seams (SKY_STOPS: the row each step starts at, in game
## rows); a milky way runs across it (dithered N2/N3 about MILKY_WAY's line, MILKY_WIDTH px either
## side); two nebulae glow faintly (NEBULAE: centre and radius, N4/N5 dither); background stars are
## 1 px N7/N8/M5, one in STAR_ODDS pixels, one in GLINT_ODDS of them a 3 px glint, kept STAR_CLEAR
## px from every stage point and off its number, the title and the stage panel.
const SKY_STOPS: Array[int] = [104, 214]
const SKY_STEPS: Array[Color] = [Palette.N0, Palette.N1, Palette.N2]
const SEAM: int = 32
const MILKY_WAY: Array[Vector2i] = [Vector2i(-40, 300), Vector2i(220, 10)]
const MILKY_WIDTH: int = 22
const NEBULAE: Array[Vector3i] = [Vector3i(46, 118, 34), Vector3i(150, 222, 26)]
const STAR_ODDS: int = 110
const GLINT_ODDS: int = 12
const STAR_CLEAR: int = 10
const STAR_COLOURS: Array[Color] = [Palette.N7, Palette.N7, Palette.N8, Palette.M5]
## One background star in SKY_TWINKLE_ODDS twinkles: it flashes M6 for SKY_TWINKLE_ON once every
## SKY_TWINKLE_PERIOD, at a phase of its own.
const SKY_TWINKLE_ODDS: int = 3
const SKY_TWINKLE_PERIOD: float = 2.6
const SKY_TWINKLE_ON: float = 0.2
## A shooting star every METEOR_WAIT seconds (x to y, at random): it starts in the top METEOR_TOP rows,
## streaks down and sideways at METEOR_SPEED px a second for METEOR_LENGTH px with a METEOR_TRAIL
## behind its head, all cool colours, behind the chart.
const METEOR_WAIT := Vector2(3.0, 8.0)
const METEOR_TOP: int = 200
const METEOR_SPEED: float = 200.0
const METEOR_LENGTH := Vector2i(60, 110)
const METEOR_TRAIL: Array[Color] = [Palette.M6, Palette.M6, Palette.M5, Palette.M5, Palette.M5, Palette.N8, Palette.N8, Palette.N8, Palette.N7, Palette.N7, Palette.N6, Palette.N6]
## Dust motes drifting along the milky way: MOTE_COUNT 1 px motes, N4 or N5 (a step above the band),
## each MOTE_SPREAD px or less from its line and moving along it at MOTE_SPEED px a second (x to y),
## wrapping round. Their layout is the same every time (MOTE_SEED).
const MOTE_COUNT: int = 30
const MOTE_SPREAD: int = 14
const MOTE_SPEED := Vector2(1.5, 4.0)
const MOTE_COLOURS: Array[Color] = [Palette.N4, Palette.N5]
const MOTE_SEED: int = 0x5C0

## The final's unlock, after its point lights: comets converge on the crown over UNLOCK_FLIGHT
## (each part's leaving UNLOCK_STAGGER after the one before), rings close in over UNLOCK_CHARGE,
## then the burst throws a ring out UNLOCK_BURST_GROWTH px over UNLOCK_BURST with UNLOCK_RAYS rays,
## and the strings flash C0 for UNLOCK_FLASH.
const UNLOCK_STAGGER: float = 0.08
const UNLOCK_FLIGHT: float = 0.6
const UNLOCK_CHARGE: float = 0.45
const UNLOCK_BURST: float = 0.6
const UNLOCK_BURST_GROWTH: int = 120
const UNLOCK_FLASH: float = 0.12
const UNLOCK_RAYS: int = 8
const UNLOCK_TIME: float = UNLOCK_STAGGER * 4 + UNLOCK_FLIGHT + UNLOCK_CHARGE + UNLOCK_BURST
const BURST_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.C4]
## A won part's piece of the Scorpio, dormant until the final is won: each colour a few steps down
## the N ramp.
const DORMANT: Dictionary = {
	Palette.N10: Palette.N7, Palette.N9: Palette.N6, Palette.N8: Palette.N6, Palette.N7: Palette.N5,
	Palette.N6: Palette.N4, Palette.N5: Palette.N3, Palette.N4: Palette.N3, Palette.N3: Palette.N2,
	Palette.N2: Palette.N1, Palette.N1: Palette.N1, Palette.D0: Palette.N6,
}
## The final's win brings it to life: C0 flashes at these times (start, end), then full colour.
const LIFE_FLASHES: Array[Vector2] = [Vector2(0.0, 0.1), Vector2(0.22, 0.32)]
const LIFE_TIME: float = 0.5

## Dormant pieces, built once per piece path.
static var _dormant: Dictionary = {}
## The chapter the static helpers draw when none is given: Scorpio, the first.
static var _scorpio: ChapterDef

## The chapter arrows: centred NAV_X either side of the screen's middle, on row NAV_Y (they rise
## with the heading); pressed within NAV_HIT round that. A chevron (C2, C0 pressed, an N0 shadow)
## or a padlock (an N8 shackle over an N7 body with an N3 keyhole).
const NAV_X: int = 62
const NAV_Y: int = 38
const NAV_HIT := Vector2i(26, 26)
## A tap on a padlock: it shakes a pixel side to side for REFUSE_SHAKE, and the subtitle says
## REFUSE_TEXT for REFUSE_SAY.
const REFUSE_SHAKE: float = 0.3
const REFUSE_SAY: float = 2.2
const REFUSE_TEXT: String = "WIN THIS CHAPTER FIRST"
## A swipe across the chart, at least SWIPE px and mostly sideways, steps chapter too.
const SWIPE: int = 28
## The sky the chapters share: the zodiac in the order the Sun passes it, SKY_SPAN px (a screen)
## per sign; a chapter's chart sits at its own sign's place. A voyage between two takes VOYAGE_BASE
## plus VOYAGE_PER_SIGN for every sign crossed: the camera speeds up over its first VOYAGE_EASE,
## cruises, and slows down over its last (a calm pan across the sky, not a warp). The charts and the
## constellations between them pass at the camera's speed, the background stars at STAR_PARALLAX of
## it (each trailing a short streak once that speed passes STREAK_SPEED px/s, up to STREAK_MAX px),
## the milky way and the nebulae stay put. Forward (the next chapter) is to the right.
const ZODIAC: Array[String] = ["scorpio", "sagittarius", "capricornus", "aquarius", "pisces", "aries", "taurus", "gemini", "cancer", "leo", "virgo"]
const SKY_SPAN: int = 180
const VOYAGE_BASE: float = 0.6
const VOYAGE_PER_SIGN: float = 0.28
const VOYAGE_EASE: float = 0.25
const STAR_PARALLAX: float = 0.4
const STREAK_SPEED: float = 160.0
const STREAK_MAX: int = 3
## The constellations passed on a voyage, in their screen's home place: their stars (an N8 cross
## with an M5 heart, the brightest an M6 glint with M5 arms), their strings (solid N5, stopping short
## of each star), their name (3x5, N8) centred under them.
const PASSING: Dictionary = {
	"sagittarius": {"name": "SAGITTARIUS", "stars": [Vector2i(56, 172), Vector2i(78, 158), Vector2i(98, 164), Vector2i(94, 188), Vector2i(70, 192), Vector2i(86, 138), Vector2i(118, 156), Vector2i(124, 184)], "lines": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 0), Vector2i(1, 5), Vector2i(5, 2), Vector2i(2, 6), Vector2i(3, 7)], "bright": [1, 2]},
	"capricornus": {"name": "CAPRICORNUS", "stars": [Vector2i(40, 140), Vector2i(70, 150), Vector2i(110, 160), Vector2i(140, 150), Vector2i(150, 128), Vector2i(100, 190), Vector2i(66, 180)], "lines": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(0, 6), Vector2i(6, 5), Vector2i(5, 3)], "bright": [0, 4]},
	"pisces": {"name": "PISCES", "stars": [Vector2i(30, 110), Vector2i(50, 140), Vector2i(70, 168), Vector2i(96, 194), Vector2i(120, 180), Vector2i(140, 168), Vector2i(156, 160), Vector2i(166, 146), Vector2i(152, 138), Vector2i(144, 152)], "lines": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(9, 6)], "bright": [3]},
	"aries": {"name": "ARIES", "stars": [Vector2i(50, 164), Vector2i(92, 150), Vector2i(112, 156), Vector2i(120, 168)], "lines": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)], "bright": [1]},
	"taurus": {"name": "TAURUS", "stars": [Vector2i(96, 172), Vector2i(118, 160), Vector2i(136, 150), Vector2i(112, 182), Vector2i(128, 188), Vector2i(160, 120), Vector2i(166, 172), Vector2i(48, 128), Vector2i(53, 125), Vector2i(51, 132)], "lines": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(3, 4), Vector2i(2, 5), Vector2i(4, 6)], "bright": [2, 8]},
	"gemini": {"name": "GEMINI", "stars": [Vector2i(60, 110), Vector2i(64, 140), Vector2i(70, 170), Vector2i(76, 200), Vector2i(92, 112), Vector2i(96, 142), Vector2i(102, 170), Vector2i(110, 198)], "lines": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(0, 4)], "bright": [0, 4]},
	"cancer": {"name": "CANCER", "stars": [Vector2i(92, 160), Vector2i(88, 130), Vector2i(70, 190), Vector2i(118, 186), Vector2i(94, 146)], "lines": [Vector2i(0, 4), Vector2i(4, 1), Vector2i(0, 2), Vector2i(0, 3)], "bright": []},
}
## The selection star leads every voyage: over the camera's speed-up it lifts off the stage that
## was selected and flies to LEAD_AHEAD px ahead of the screen's middle (towards where it's going),
## leads the cruise there, and over the slow-down lands on the new chapter's stage to play (the
## crown, when the voyage reveals a new chapter). Its trail follows the way it actually went, the
## last TRAIL.size() places it was drawn at; the selection brackets show again once it has landed.
const LEAD_AHEAD: int = 46
## A passing constellation's name sits this far under its lowest star.
const PASSING_NAME_GAP: int = 8
## The background stars: about one per STAR_ODDS px of sky, placed per SKY_SPAN-wide section from
## that section's own seed (STAR_SEED), in rows STAR_ROWS: the same sky every time, endless sideways.
const STAR_ROWS := Vector2i(-160, 330)
const STAR_SEED: int = 0x57A2
## The next chapter opening: its padlock shakes, ever faster, and heats (N7, C3, C2) for OPEN_SHAKE,
## then bursts: a ring and OPEN_SHARDS shards falling away over OPEN_BREAK as the chevron flashes
## in; a comet streaks from the crown out past the arrow and off the screen from OPEN_COMET_AT for
## OPEN_COMET. Then chapter_opened.
const OPEN_SHAKE: float = 0.6
const OPEN_BREAK: float = 0.55
const OPEN_SHARDS: int = 18
const OPEN_COMET_AT: float = 0.7
const OPEN_COMET: float = 0.7
const OPEN_TIME: float = OPEN_COMET_AT + OPEN_COMET
const SHARD_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
## The new chapter's reveal: its stars pop in one every REVEAL_STEP from its first stage (a C0 cross
## and a ring cooling over REVEAL_POP), each string once both its stars are in, the crown last;
## REVEAL_SPARKLES sparkles twinkle across the sky over REVEAL_SPARKLE; the heading's title stamps
## C0, and a title card (the finals' BossBanner) stamps the chapter's name over REVEAL_TEXT in the
## sky at REVEAL_CARD_Y for REVEAL_SAY. Then a comet runs from the crown to the stage to play.
const REVEAL_STEP: float = 0.07
const REVEAL_POP: float = 0.3
const REVEAL_SPARKLES: int = 56
const REVEAL_SPARKLE: float = 1.6
const REVEAL_SAY: float = 2.4
const REVEAL_TEXT: String = "CHAPTER %d IS OPEN"
const REVEAL_CARD_Y: int = 200
## The background stars above STAR_ROWS (the sky over the chart, seen from the title): rows
## STAR_ROWS_ABOVE, from a seed of their own so the chart's own stars stay as they were.
const STAR_ROWS_ABOVE := Vector2i(-560, -160)
const STAR_SEED_ABOVE: int = 0x7A11
## The way down from the title takes DESCENT_TIME, eased like a voyage (cruise).
const DESCENT_TIME: float = 1.6
## Where a stage's number sits from its point.
const NUMBER_OFFSET := Vector2i(10, -16)
## Scorpio's crown point (each chapter has its own: ChapterDef.final_at).
const FINAL_AT := Vector2i(90, 66)

var _chapter: Chapter
var _selected: int = 0
var _time: float = 0.0
## The comet: the pixels it follows and how far along it is (seconds); empty when none.
var _travel: Array[Vector2i] = []
var _travel_time: float = 0.0
var _travel_to: int = -1
## A point lighting up (back from its stage's win), and the point to travel to after, or -1.
var _light_point: int = -1
var _light_time: float = 0.0
var _then_travel_to: int = -1
var _pressed_point: int = -1
var _pressed_play: bool = false
## The final's unlock playing: seconds since it began (-1: none), and whether one waits for the
## point lighting to end.
var _unlock_time: float = -1.0
var _unlock_next: bool = false
## Where each arrow leads (left, right: Nav), which one is pressed (-1, +1 or 0), a refused one and
## the seconds since, and where the press began (for a swipe).
var _nav: Array[int] = [Nav.NONE, Nav.NONE]
var _pressed_nav: int = 0
var _refuse_side: int = 0
var _refuse_time: float = -1.0
var _press_at := Vector2i(-1, -1)
## Where the camera is on the shared sky (the world x of the screen's left edge), and a voyage to
## `_voyage_chapter`: seconds in (-1: none), how long it takes, from and to where, whether it has
## handed over to the new chart yet, and whether it reveals it.
var _camera: float = 0.0
var _voyage_time: float = -1.0
var _voyage_length: float = 1.0
var _voyage_from: float = 0.0
var _voyage_to: float = 0.0
var _voyage_chapter: Chapter
var _voyage_swapped: bool = false
var _voyage_reveal: bool = false
## The selection star on a voyage: where it lifts off and lands on the shared sky (world x), and the
## places it was last drawn at (its trail, newest first).
var _lead_from := Vector2i.ZERO
var _lead_to := Vector2i.ZERO
var _lead_trail: Array[Vector2i] = []
## The background stars on screen (screen x, y, their hash), worked out again whenever the camera
## or the chart moves; the key they were worked out for.
var _stars: Array[Vector3i] = []
var _stars_key := Vector4i(-1, -1, -1, -1)
## The passing constellations' names.
var _passing_names: Dictionary[String, Label] = {}
static var _sections: Dictionary[int, Array] = {}
static var _sections_above: Dictionary[int, Array] = {}
## The title: shown (waiting for a tap), and the way down: seconds in (-1: none). How far above
## the chart the camera is (px; a screen's height on the title, 0 on the chart), and the layer's
## offset on the chart (fit_screen).
var _title_view: TitleView
var _on_title: bool = false
var _descent_time: float = -1.0
var _camera_y: float = 0.0
var _base_offset := Vector2.ZERO
## The next chapter's opening: waiting for the figure to come to life, then seconds in (-1: none).
var _open_pending: bool = false
var _open_time: float = -1.0
## The reveal: waiting for the voyage to end, then seconds in (-1: none), and the stars' order.
var _reveal_pending: bool = false
var _reveal_time: float = -1.0
var _reveal_order: Array[int] = []
## The reveal's title card.
var _card: BossBanner
## The painting moving after a win: the stage whose piece rises (or FINAL: the scorpion coming to
## life), and seconds since it began (-1: none).
var _figure_stage: int = -1
var _figure_time: float = -1.0
## The visible screen in the chart's coordinates (fit_screen): the 9:16 layout, with any extra
## height split above and below it.
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
var _numbers: Array[Label] = []
## The space behind the chart, built once per screen, and its twinkling stars.
var _space: ImageTexture
## Picks when and where shooting stars fly (tests seed it).
var meteor_rng := RandomNumberGenerator.new()
## The shooting star: the pixels it streaks along and how long it's been flying (-1: none), and how
## long until the next.
var _meteor: Array[Vector2i] = []
var _meteor_age: float = -1.0
var _meteor_wait: float = 0.0
## The milky way's motes: where each starts along the band and across it, and its speed.
var _motes: Array[Vector3] = []

@onready var _chart: Node2D = $Chart
@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _info: Label = $Info
@onready var _play: Label = $Play


func _ready() -> void:
	meteor_rng.randomize()
	_meteor_wait = meteor_rng.randf_range(METEOR_WAIT.x, METEOR_WAIT.y)
	_chart.draw.connect(_draw_chart)
	_title.label_settings = HudText.primary(Palette.C1)
	_subtitle.label_settings = HudText.primary(Palette.N8)
	_info.label_settings = HudText.primary(Palette.C1)
	_play.label_settings = HudText.primary(Palette.C1)
	_motes = mote_layout()
	# The paintings load before any draw call uses them.
	_load_paintings(_def())
	_place_heading()
	_card = BossBanner.new()
	_card.name = "RevealCard"
	add_child(_card)
	_title_view = TitleView.new()
	_title_view.name = "Title"
	_title_view.visible = false
	add_child(_title_view)
	for sign: String in PASSING:
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.label_settings = HudText.secondary(Palette.N8)
		name_label.text = PASSING[sign]["name"]
		name_label.visible = false
		add_child(name_label)
		_passing_names[sign] = name_label
	for stage: int in Chapter.stage_count():
		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = "%d" % (stage + 1)
		add_child(number)
		_numbers.append(number)


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and handle_pointer(ScreenZones.to_game(event, Vector2i(offset))):
		get_viewport().set_input_as_handled()


## Shows `chapter`, the point to play next selected.
func setup(chapter: Chapter) -> void:
	var changed: bool = _chapter == null or _chapter.def.id != chapter.def.id
	_chapter = chapter
	if changed:
		_load_paintings(chapter.def)
	if _voyage_time < 0.0:
		_camera = sky_x(chapter.def.id)
	_travel.clear()
	_light_point = -1
	_then_travel_to = -1
	_unlock_time = -1.0
	_unlock_next = false
	_figure_time = -1.0
	_figure_stage = -1
	_open_pending = false
	_open_time = -1.0
	_reveal_time = -1.0
	_reveal_pending = false
	if _card != null:
		_card.hide_card()
	_selected = chapter.current()
	_restore_heading()
	_refresh()


## Fits the chart to `screen`, the visible area in game coordinates (the game's 180x320 at the
## bottom). Extra height is split: the chart lifts by half of it and sets its own offset to match,
## so the heading can rise to the top and the label stay at the bottom, each half as far from it.
func fit_screen(screen: Rect2i) -> void:
	var extra: int = maxi(0, -screen.position.y)
	var lift: int = extra / 2
	_base_offset = Vector2(-screen.position.x, extra - lift)
	var local := Rect2i(screen.position + Vector2i(0, lift), screen.size)
	if local != _screen or _space == null:
		_space = ImageTexture.create_from_image(space_image(local, _def(), false))
	_screen = local
	if _on_title:
		_camera_y = _screen.size.y
	_place_title()
	_place_heading()
	_refresh()
	_chart.queue_redraw()


## How far the heading rises above its 9:16 place on `screen` (chart coordinates).
static func heading_rise(screen: Rect2i) -> int:
	return maxi(0, -screen.position.y)


## How far the stage label drops below its 9:16 place on `screen` (chart coordinates).
static func label_drop(screen: Rect2i) -> int:
	return maxi(0, screen.end.y - ScreenZones.SCREEN.y)


## Where PLAY sits on `screen` (chart coordinates).
static func play_rect(screen: Rect2i = Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)) -> Rect2i:
	var drop: int = label_drop(screen)
	return Rect2i(PLAY.position + Vector2i(0, drop + mini(drop / 8, PLAY_ROOM)), PLAY.size)


## The background stars of `screen` that twinkle: plain 1 px ones (not glints), one in
## SKY_TWINKLE_ODDS.
static func twinkling_stars(screen: Rect2i, def: ChapterDef = null) -> Array[Vector2i]:
	var twinklers: Array[Vector2i] = []
	for star: Vector3i in sky_stars(screen, def):
		if twinkles(star.z):
			twinklers.append(Vector2i(star.x, star.y))
	return twinklers


## A background star (by its hash) is a 3 px glint, plain, or a plain one that twinkles.
static func is_glint(h: int) -> bool:
	return h % GLINT_ODDS == 0


static func twinkles(h: int) -> bool:
	return not is_glint(h) and (h / GLINT_ODDS) % SKY_TWINKLE_ODDS == 0


## Section `section` of the sky's background stars (world x, y, hash): from its own seed.
static func sky_section(section: int) -> Array:
	if _sections.has(section):
		return _sections[section]
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED ^ (section * 2654435761)
	var stars: Array[Vector3i] = []
	for i: int in SKY_SPAN * (STAR_ROWS.y - STAR_ROWS.x) / STAR_ODDS:
		stars.append(Vector3i(section * SKY_SPAN + rng.randi_range(0, SKY_SPAN - 1), rng.randi_range(STAR_ROWS.x, STAR_ROWS.y - 1), rng.randi() & 0x3FFFFFFF))
	_sections[section] = stars
	return stars


## Section `section` of the background stars above the chart's (STAR_ROWS_ABOVE), seen from the
## title.
static func sky_section_above(section: int) -> Array:
	if _sections_above.has(section):
		return _sections_above[section]
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED_ABOVE ^ (section * 2654435761)
	var stars: Array[Vector3i] = []
	for i: int in SKY_SPAN * (STAR_ROWS_ABOVE.y - STAR_ROWS_ABOVE.x) / STAR_ODDS:
		stars.append(Vector3i(section * SKY_SPAN + rng.randi_range(0, SKY_SPAN - 1), rng.randi_range(STAR_ROWS_ABOVE.x, STAR_ROWS_ABOVE.y - 1), rng.randi() & 0x3FFFFFFF))
	_sections_above[section] = stars
	return stars


## The background stars on `screen` (screen x, y, hash) with the sky's stars at `stars_x` (their
## world x of the screen's left) and `stars_y` px lower, and the chart drawn `chart_x` px across and
## `chart_y` down: clear of the chart's stars, stage points and numbers, its heading and its stage
## label, and of the `off` areas (screen coordinates).
static func sky_stars(screen: Rect2i, def: ChapterDef = null, stars_x: int = 0, chart_x: int = 0, stars_y: int = 0, chart_y: int = 0, off: Array[Rect2i] = []) -> Array[Vector3i]:
	def = _or_scorpio(def)
	var shift := Vector2i(chart_x, chart_y)
	var title := Rect2i(40, TITLE_Y - heading_rise(screen) - 3, 100, SUBTITLE_Y - TITLE_Y + 13)
	var keep_off: Array[Rect2i] = [Rect2i(title.position + shift, title.size)]
	keep_off.append_array(off)
	for area: Rect2i in label_areas(screen):
		keep_off.append(Rect2i(area.position + shift, area.size))
	for stage: int in Chapter.stage_count():
		keep_off.append(Rect2i(stage_position(stage, def) + NUMBER_OFFSET - Vector2i(2, 2) + shift, Vector2i(12, 10)))
	var points: Array[Vector2i] = []
	for star: Vector2i in def.figure.landmarks + [def.final_at]:
		points.append(star + shift)
	var found: Array[Vector3i] = []
	var left: int = stars_x + screen.position.x
	for section: int in range(floori(float(left) / SKY_SPAN), floori(float(left + screen.size.x) / SKY_SPAN) + 1):
		for star: Vector3i in sky_section(section) + (sky_section_above(section) if stars_y > 0 else []):
			var p := Vector2i(star.x - stars_x, star.y + stars_y)
			if not screen.has_point(p) or _covered(p, keep_off, points):
				continue
			found.append(Vector3i(p.x, p.y, star.z))
	return found


## The milky way's motes: x how far along the band each starts, y how far across it, z its speed.
static func mote_layout() -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = MOTE_SEED
	var motes: Array[Vector3] = []
	var length: float = Vector2(MILKY_WAY[1] - MILKY_WAY[0]).length()
	for i: int in MOTE_COUNT:
		motes.append(Vector3(rng.randf() * length, rng.randf_range(-MOTE_SPREAD, MOTE_SPREAD), rng.randf_range(MOTE_SPEED.x, MOTE_SPEED.y)))
	return motes


## Where the motes are at `time`, with their colours: whole pixels drifting up the band.
static func mote_pixels(motes: Array[Vector3], time: float) -> Dictionary[Vector2i, Color]:
	var a := Vector2(MILKY_WAY[0])
	var along: Vector2 = Vector2(MILKY_WAY[1] - MILKY_WAY[0])
	var length: float = along.length()
	along /= length
	var dots: Dictionary[Vector2i, Color] = {}
	for i: int in motes.size():
		var m: Vector3 = motes[i]
		var at: Vector2 = a + along * fposmod(m.x + m.z * time, length) + along.orthogonal() * m.y
		dots[Vector2i(at.round())] = MOTE_COLOURS[i % MOTE_COLOURS.size()]
	return dots


## Whether the background star at `p` (or with hash `h`) is lit up at `time`, on its own phase.
static func sky_twinkles(p: Vector2i, time: float, h: int = -1) -> bool:
	var phase: float = float((h if h >= 0 else _hash(p + Vector2i(7, 3))) % 1000) / 1000.0 * SKY_TWINKLE_PERIOD
	return fmod(time + phase, SKY_TWINKLE_PERIOD) < SKY_TWINKLE_ON


## Starts a shooting star now, from a random point near the top, streaking down and sideways.
func launch_meteor() -> void:
	var from := Vector2i(meteor_rng.randi_range(_screen.position.x + 10, _screen.end.x - 10), meteor_rng.randi_range(_screen.position.y + 4, METEOR_TOP))
	var side: int = -1 if from.x > _screen.position.x + _screen.size.x / 2 else 1
	var length: int = meteor_rng.randi_range(METEOR_LENGTH.x, METEOR_LENGTH.y)
	var drop: int = meteor_rng.randi_range(length / 3, length / 2)
	_meteor = LinkLayer.line_pixels(from, from + Vector2i(side * length, drop))
	_meteor_age = 0.0


func is_meteor_flying() -> bool:
	return _meteor_age >= 0.0


## The shooting star's pixels now, head first, with their colours; none when none flies.
func meteor_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if _meteor_age < 0.0:
		return dots
	var head: int = int(_meteor_age * METEOR_SPEED)
	for k: int in METEOR_TRAIL.size():
		var i: int = head - k
		if i >= 0 and i < _meteor.size():
			dots[_meteor[i]] = METEOR_TRAIL[k]
	# A head a pixel thicker, below the line.
	if head < _meteor.size():
		dots[_meteor[head] + Vector2i.DOWN] = Palette.M5
	return dots


## The space behind the chart for a visible screen `screen` (game coordinates; the image's 0,0 is
## screen.position). Opaque, cool palette colours only, the same pixels for the same place.
static func space_image(screen: Rect2i, def: ChapterDef = null, with_stars: bool = true) -> Image:
	var image := Image.create_empty(screen.size.x, screen.size.y, false, Image.FORMAT_RGBA8)
	var a := Vector2(MILKY_WAY[0])
	var along: Vector2 = (Vector2(MILKY_WAY[1]) - a).normalized()
	for y: int in screen.size.y:
		for x: int in screen.size.x:
			var p := Vector2i(x, y) + screen.position
			image.set_pixel(x, y, _space_colour(p, a, along))
	for star: Vector3i in (sky_stars(screen, def) if with_stars else ([] as Array[Vector3i])):
		var h: int = star.z
		var local: Vector2i = Vector2i(star.x, star.y) - screen.position
		if is_glint(h):
			for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var q: Vector2i = local + n
				if q.x >= 0 and q.y >= 0 and q.x < screen.size.x and q.y < screen.size.y:
					image.set_pixel(q.x, q.y, Palette.N7)
			image.set_pixel(local.x, local.y, Palette.M5)
		else:
			image.set_pixel(local.x, local.y, STAR_COLOURS[(h / GLINT_ODDS) % STAR_COLOURS.size()])
	return image


## Where the stage label draws (the name with its rules, PLAY): background stars keep off these.
static func label_areas(screen: Rect2i = Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)) -> Array[Rect2i]:
	return [Rect2i(PANEL.position.x, INFO_Y + label_drop(screen) - 3, PANEL.size.x, 13), play_rect(screen).grow(3)]


## Whether a background star at `p` would sit in one of `areas` or too near one of `points`.
static func _covered(p: Vector2i, areas: Array[Rect2i], points: Array[Vector2i]) -> bool:
	for area: Rect2i in areas:
		if area.has_point(p):
			return true
	for q: Vector2i in points:
		if (q - p).length_squared() < STAR_CLEAR * STAR_CLEAR:
			return true
	return false


## Where the background stars are in `screen`, at rest (see sky_stars).
static func space_stars(screen: Rect2i, def: ChapterDef = null) -> Array[Vector2i]:
	var stars: Array[Vector2i] = []
	for star: Vector3i in sky_stars(screen, def):
		stars.append(Vector2i(star.x, star.y))
	return stars


static func _space_colour(p: Vector2i, milky_start: Vector2, milky_along: Vector2) -> Color:
	var bayer: float = StarView.BAYER[posmod(p.y, 4) * 4 + posmod(p.x, 4)] / 16.0
	# The sky's steps, each seam an ordered dither SEAM rows deep.
	var step: int = 0
	for i: int in SKY_STOPS.size():
		var into: float = float(p.y - SKY_STOPS[i]) / SEAM
		if into >= 1.0 or (into > 0.0 and bayer < into):
			step = i + 1
	var colour: Color = SKY_STEPS[step]
	# The milky way: N2, then N3 at its heart, thinning out to its edges.
	var rel: Vector2 = Vector2(p) - milky_start
	var off: float = absf(rel.dot(milky_along.orthogonal())) + 4.0 * sin(rel.dot(milky_along) * 0.05)
	var band: float = 1.0 - absf(off) / MILKY_WIDTH
	if band > 0.0:
		if band > 0.6 and bayer < (band - 0.6) * 1.2:
			colour = Palette.N3
		elif bayer < band * 0.55:
			colour = Palette.N2 if step < 2 else Palette.N3
	# Nebulae: a soft N4 cloud with an N5 heart, dithered sparser to its rim.
	for nebula: Vector3i in NEBULAE:
		var d: float = Vector2(p).distance_to(Vector2(nebula.x, nebula.y)) / nebula.z
		var wobble: float = 0.12 * sin(p.x * 0.21 + nebula.x) * cos(p.y * 0.17 + nebula.y)
		var k: float = 1.0 - d + wobble
		if k > 0.55 and bayer < (k - 0.55) * 1.4:
			colour = Palette.N5
		elif k > 0.0 and bayer < k * 0.5:
			colour = Palette.N4
	return colour


## A fixed, well-mixed hash of a pixel (non-negative).
static func _hash(p: Vector2i) -> int:
	var h: int = p.x * 374761393 + p.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


## Back from a stage: `lit` (a stage just won, or -1) flashes as its stars light, then a comet
## travels to `unlocked` (the stage it opened, or -1) and selects it.
## The final's own moments play bigger: its unlock (unlock_sequence), and the painted Scorpio rising
## once it's won.
func show_progress(lit: int, unlocked: int, opens_next: bool = false) -> void:
	_open_pending = opens_next and Chapter.is_final(lit)
	_travel.clear()
	_unlock_time = -1.0
	_unlock_next = false
	_figure_time = -1.0
	_figure_stage = -1
	if lit >= 0:
		_selected = lit
		_light_point = lit
		_light_time = 0.0
		_unlock_next = Chapter.is_final(unlocked)
		_then_travel_to = -1 if _unlock_next else unlocked
		_figure_stage = lit
		_figure_time = 0.0
	else:
		_selected = _chapter.current()
	_refresh()


func is_unlocking() -> bool:
	return _unlock_time >= 0.0 or _unlock_next


## Whether something plays that a tap mustn't interrupt: an unlock, the next chapter opening, a
## voyage or a reveal.
func is_busy() -> bool:
	return is_unlocking() or is_opening() or is_voyaging() or is_revealing() or is_on_title()


## Where each arrow leads: `left` and `right` (Nav).
func show_navigation(left: Nav, right: Nav) -> void:
	_nav = [left, right]
	_chart.queue_redraw()


## Where the arrow on `side` (-1 left, +1 right) leads (Nav).
func navigation(side: int) -> int:
	return _nav[0 if side < 0 else 1]


## The arrow on `side`'s centre and its tap target (chart coordinates).
func nav_centre(side: int) -> Vector2i:
	return Vector2i(ScreenZones.SCREEN.x / 2 + side * NAV_X, NAV_Y - heading_rise(_screen))


func nav_target(side: int) -> Rect2i:
	return Rect2i(nav_centre(side) - NAV_HIT / 2, NAV_HIT)


## Steps to the chapter on `side`: asks for it if it's open, shakes its padlock if it's locked.
func step(side: int) -> void:
	match navigation(side):
		Nav.OPEN:
			chapter_step_requested.emit(side)
		Nav.LOCKED:
			_refuse_side = side
			_refuse_time = 0.0
			_say(REFUSE_TEXT, Palette.N8)
			nav_refused.emit()
			_chart.queue_redraw()


## Voyages along the sky to `chapter`'s constellation; with `reveal`, its stars then pop in (the new
## chapter's reveal), and the opening's comet leads the way.
func voyage_to(chapter: Chapter, reveal: bool = false) -> void:
	_voyage_chapter = chapter
	_voyage_reveal = reveal
	_voyage_from = _camera
	_voyage_to = sky_x(chapter.def.id)
	_voyage_length = voyage_time(absi(roundi(_voyage_to - _voyage_from)) / SKY_SPAN)
	_voyage_swapped = false
	_voyage_time = 0.0
	# The opening's comet left off the screen's right edge by the arrow; otherwise the star lifts off
	# the stage that was selected.
	var lift: Vector2i = Vector2i(_screen.end.x + 12, nav_centre(1).y) if reveal else stage_position(_selected, _def())
	_lead_from = lift + Vector2i(roundi(_camera), 0)
	var land: Vector2i = stage_position(Chapter.FINAL if reveal else chapter.current(), chapter.def)
	_lead_to = land + Vector2i(sky_x(chapter.def.id), 0)
	_lead_trail.clear()
	_travel.clear()
	slid.emit()


## Where the selection star is on screen now, on a voyage: lifting off, leading, landing.
func lead_star() -> Vector2i:
	var k: float = clampf(_voyage_time / _voyage_length, 0.0, 1.0) if _voyage_time >= 0.0 else 1.0
	var forward: int = signi(roundi(_voyage_to - _voyage_from))
	var from: Vector2i = _lead_from - Vector2i(roundi(_camera), 0)
	var to: Vector2i = _lead_to - Vector2i(roundi(_camera), 0)
	var ahead := Vector2i(ScreenZones.SCREEN.x / 2 + forward * LEAD_AHEAD, (from.y + to.y) / 2)
	var a: float = VOYAGE_EASE
	if k < a:
		return Vector2i(Vector2(from).lerp(Vector2(ahead), smoothstep(0.0, 1.0, k / a)).round())
	if k > 1.0 - a:
		return Vector2i(Vector2(ahead).lerp(Vector2(to), smoothstep(0.0, 1.0, (k - 1.0 + a) / a)).round())
	return ahead


## How long a voyage across `signs` signs of the zodiac takes.
static func voyage_time(signs: int) -> float:
	return VOYAGE_BASE + VOYAGE_PER_SIGN * maxi(signs, 1)


## Where a chapter's chart (or a passing constellation, by its id) sits on the shared sky.
static func sky_x(id: String) -> int:
	return maxi(ZODIAC.find(id), 0) * SKY_SPAN


## How far through the voyage the camera is (0-1): speeding up, cruising, slowing down.
func voyage_progress() -> float:
	if _voyage_time < 0.0:
		return 1.0
	return cruise(_voyage_time / _voyage_length)


## A voyage's progress `k` of the way through its time: a steady speed-up over VOYAGE_EASE, a
## cruise, a steady slow-down over the last VOYAGE_EASE.
static func cruise(k: float) -> float:
	var a: float = VOYAGE_EASE
	k = clampf(k, 0.0, 1.0)
	if k < a:
		return k * k / (2.0 * a * (1.0 - a))
	if k > 1.0 - a:
		return 1.0 - (1.0 - k) * (1.0 - k) / (2.0 * a * (1.0 - a))
	return (k - a / 2.0) / (1.0 - a)


## The camera's speed now, px a second (signed).
func voyage_speed() -> float:
	if _voyage_time < 0.0:
		return 0.0
	return (_voyage_to - _voyage_from) * cruise_rate(_voyage_time / _voyage_length) / _voyage_length


func camera() -> float:
	return _camera


## Plays the next chapter's opening now (debug: after a final's win it follows the figure's life).
func play_opening() -> void:
	_open_pending = false
	_open_time = 0.0
	padlock_shaken.emit()
	_chart.queue_redraw()


func is_voyaging() -> bool:
	return _voyage_time >= 0.0


func is_opening() -> bool:
	return _open_pending or _open_time >= 0.0


func is_revealing() -> bool:
	return _reveal_pending or _reveal_time >= 0.0


## Shows the title: the camera a screen above the chart, waiting for a tap.
func show_title() -> void:
	_on_title = true
	_descent_time = -1.0
	_camera_y = _screen.size.y
	_title_view.visible = true
	_title_view.set_started(false)
	_place_title()
	_chart.queue_redraw()


## Goes straight to the chart (a stage opened from the title: back from it, the chart shows).
func leave_title() -> void:
	if not is_on_title():
		return
	_on_title = false
	_descent_time = -1.0
	_camera_y = 0.0
	_lead_trail.clear()
	_title_view.visible = false
	_place_title()
	_chart.queue_redraw()


## On the title or on the way down from it: the chart doesn't take taps yet.
func is_on_title() -> bool:
	return _on_title or is_descending()


func is_descending() -> bool:
	return _descent_time >= 0.0


func title_view() -> TitleView:
	return _title_view


## How far above the chart the camera is now (px).
func camera_y() -> int:
	return roundi(_camera_y)


## Leaves the title: the light star lifts off from under it and leads the camera down to the stage
## to play.
func start_descent() -> void:
	if not _on_title:
		return
	_on_title = false
	_descent_time = 0.0
	_selected = _chapter.current()
	# On the way down, places are on the screen with the camera at the chart (layer coordinates).
	_lead_from = _title_view.star_at() - Vector2i(0, _screen.size.y)
	_lead_to = stage_position(_selected, _def())
	_lead_trail.clear()
	_title_view.set_started(true)
	_refresh()
	title_left.emit()


## Where the light star is on the way down (on screen): lifting off the title, leading the camera
## LEAD_AHEAD px below the screen's middle, landing on the stage.
func descent_star() -> Vector2i:
	var k: float = clampf(_descent_time / DESCENT_TIME, 0.0, 1.0) if _descent_time >= 0.0 else 1.0
	var down := Vector2i(0, roundi(_camera_y))
	var from: Vector2i = _lead_from + down
	var to: Vector2i = _lead_to + down
	var ahead := Vector2i((from.x + to.x) / 2, _screen.position.y + _screen.size.y / 2 + LEAD_AHEAD)
	var a: float = VOYAGE_EASE
	if k < a:
		return Vector2i(Vector2(from).lerp(Vector2(ahead), smoothstep(0.0, 1.0, k / a)).round())
	if k > 1.0 - a:
		return Vector2i(Vector2(ahead).lerp(Vector2(to), smoothstep(0.0, 1.0, (k - 1.0 + a) / a)).round())
	return ahead


## How fast the view moves down now, px a second.
func descent_speed() -> float:
	if _descent_time < 0.0:
		return 0.0
	return _screen.size.y * cruise_rate(_descent_time / DESCENT_TIME) / DESCENT_TIME


## How fast cruise() moves at `k` of the way through (its slope).
static func cruise_rate(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	var a: float = VOYAGE_EASE
	return minf(minf(k, 1.0 - k), a) / (a * (1.0 - a))


## The title sits a screen above the chart; the layer follows the camera.
func _place_title() -> void:
	if _title_view != null:
		_title_view.position = Vector2(0, -_screen.size.y)
		_title_view.layout(_screen)
	offset = _base_offset + Vector2(0, roundi(_camera_y))


func _advance_descent(delta: float) -> bool:
	if _descent_time < 0.0:
		return false
	_descent_time += delta
	if _descent_time >= DESCENT_TIME:
		_descent_time = -1.0
		_camera_y = 0.0
		_lead_trail.clear()
		_title_view.visible = false
		star_landed.emit()
	else:
		_camera_y = _screen.size.y * (1.0 - cruise(_descent_time / DESCENT_TIME))
		_lead_trail.push_front(descent_star())
		if _lead_trail.size() > TRAIL.size():
			_lead_trail.pop_back()
	_place_title()
	return true


## How far across the screen the chart is drawn now: 0 at rest, its place on the sky against the
## camera's on a voyage (whole pixels).
func chart_x() -> int:
	if _chapter == null:
		return 0
	return roundi(sky_x(_chapter.def.id) - _camera)


## Whether landmark `landmark` shows: always, except while the reveal hasn't popped it yet.
func revealed(landmark: int) -> bool:
	if not is_revealing():
		return true
	if _reveal_time < 0.0:
		return false
	return _reveal_order.find(landmark) * REVEAL_STEP <= _reveal_time


## The order a chapter's stars pop in when it's revealed: each part's stars, from the first part.
static func reveal_order(def: ChapterDef) -> Array[int]:
	var order: Array[int] = []
	for stage: int in Chapter.FINAL:
		for landmark: int in def.stages[stage]["stars"]:
			order.append(landmark)
	return order


func _start_reveal() -> void:
	_reveal_pending = false
	_reveal_order = reveal_order(_def())
	_reveal_time = 0.0
	_title.label_settings.font_color = Palette.C0
	_card.position = Vector2(ScreenZones.SCREEN.x / 2, REVEAL_CARD_Y + label_drop(_screen))
	_card.play_arrival(_def().title, REVEAL_TEXT % _def().number, REVEAL_SAY, Palette.C1, Palette.C2)
	star_revealed.emit(0)


## The subtitle says `text` for a while (a refusal, the reveal) in `colour`.
func _say(text: String, colour: Color) -> void:
	_subtitle.text = text
	_subtitle.label_settings.font_color = colour
	_place_heading()


## The heading as the chapter has it: its title in C1, CHAPTER n in N8.
func _restore_heading() -> void:
	if _chapter == null or _title == null:
		return
	_title.text = _def().title
	_title.label_settings.font_color = Palette.C1
	_subtitle.text = "CHAPTER %d" % _def().number
	_subtitle.label_settings.font_color = Palette.N8
	_place_heading()


## Whether the whole Scorpio shows alive: once the final is won.
func shows_figure() -> bool:
	return _chapter != null and _chapter.is_completed(Chapter.FINAL) and has_art(_def().figure.painting)


## Whether part `stage`'s piece of the Scorpio shows (dormant until the final is won).
func shows_piece(stage: int) -> bool:
	return _chapter != null and not Chapter.is_final(stage) and _chapter.is_completed(stage) and has_art(piece_path(stage, _def()))


func is_figure_rising() -> bool:
	return _figure_time >= 0.0


## Part `stage`'s piece of the Scorpio, in full colour (the chart's own coordinates).
static func piece_path(stage: int, def: ChapterDef = null) -> String:
	return _or_scorpio(def).piece_path(stage)


## Part `stage`'s piece, dormant: each colour stepped down (DORMANT).
static func dormant_piece(stage: int, def: ChapterDef = null) -> Texture2D:
	var path: String = piece_path(stage, def)
	if not _dormant.has(path):
		# A copy: get_image() can hand back the texture's own cached image.
		var image: Image = ConstellationView.painting(path).get_image().duplicate()
		image.convert(Image.FORMAT_RGBA8)
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c: Color = image.get_pixel(x, y)
				if c.a > 0.5:
					image.set_pixel(x, y, DORMANT.get(Color(c.r, c.g, c.b), c))
		_dormant[path] = ImageTexture.create_from_image(image)
	return _dormant[path]


## Whether a chapter's piece or painting at `path` has been drawn yet (a new chapter's art comes
## after its stages: until then the chart leaves it out).
static func has_art(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


## Whether the scorpion coming to life flashes C0 at `t` seconds.
static func life_flashing(t: float) -> bool:
	for flash: Vector2 in LIFE_FLASHES:
		if t >= flash.x and t < flash.y:
			return true
	return false


## The final's unlock at `t` seconds: where each part's comet is (its head, along its line to the
## crown, or -1 before it leaves / after it lands).
static func unlock_comet_heads(t: float, def: ChapterDef = null) -> Array[int]:
	def = _or_scorpio(def)
	var heads: Array[int] = []
	for stage: int in Chapter.FINAL:
		var k: float = (t - stage * UNLOCK_STAGGER) / UNLOCK_FLIGHT
		var line: Array[Vector2i] = LinkLayer.line_pixels(stage_position(stage, def), def.final_at)
		heads.append(roundi(k * (line.size() - 1)) if k >= 0.0 and k < 1.0 else -1)
	return heads


## The final's unlock at `t`: 0 comets flying, 1 charging, 2 bursting, -1 over.
static func unlock_phase(t: float) -> int:
	var charge_at: float = UNLOCK_STAGGER * 4 + UNLOCK_FLIGHT
	if t < 0.0 or t >= UNLOCK_TIME:
		return -1
	if t < charge_at:
		return 0
	return 1 if t < charge_at + UNLOCK_CHARGE else 2


func selected() -> int:
	return _selected


func is_travelling() -> bool:
	return not _travel.is_empty()


func is_lighting() -> bool:
	return _light_point >= 0


## Selects stage `stage`; a comet travels there from the stage selected before.
func select(stage: int) -> void:
	if stage == _selected:
		return
	_travel = travel_pixels(_selected, stage, _def())
	_travel_time = 0.0
	_travel_to = stage
	_selected = stage
	_refresh()


## Whether PLAY shows for the selected stage: its map exists and it's available or done, and the
## final's unlock isn't playing (the stage that opened it is still selected until it ends).
func can_play() -> bool:
	return _chapter != null and _chapter.state(_selected) != Chapter.PointState.LOCKED and not is_unlocking()


## Where stage `stage`'s point is drawn (game coordinates): a part's first star from the tail,
## or the crown point for the final.
static func stage_position(stage: int, def: ChapterDef = null) -> Vector2i:
	def = _or_scorpio(def)
	if Chapter.is_final(stage):
		return def.final_at
	return def.figure.landmarks[def.stages[stage]["stars"][0]]


## The stage a tap at `at` picks: the part owning the nearest star in reach, or the final on its
## crown point, or -1.
static func stage_at(at: Vector2i, def: ChapterDef = null) -> int:
	def = _or_scorpio(def)
	var chapter := Chapter.new(def)
	var best: int = -1
	var best_d: int = HIT_RADIUS * HIT_RADIUS + 1
	for landmark: int in def.figure.count():
		var d: int = (def.figure.landmarks[landmark] - at).length_squared()
		if d < best_d:
			best_d = d
			best = chapter.stage_of(landmark)
	if (def.final_at - at).length_squared() < best_d:
		best = Chapter.FINAL
	return best


## The pixels a comet follows from one stage's point to another's: along the strings between
## parts, straight up to the crown for the final.
static func travel_pixels(from_stage: int, to_stage: int, def: ChapterDef = null) -> Array[Vector2i]:
	def = _or_scorpio(def)
	if Chapter.is_final(from_stage) or Chapter.is_final(to_stage):
		return LinkLayer.line_pixels(stage_position(from_stage, def), stage_position(to_stage, def))
	var pixels: Array[Vector2i] = []
	var marks: Array[int] = def.figure.path(def.stages[from_stage]["stars"][0], def.stages[to_stage]["stars"][0])
	var at: Array[Vector2i] = def.figure.landmarks
	for k: int in range(1, marks.size()):
		var line: Array[Vector2i] = LinkLayer.line_pixels(at[marks[k - 1]], at[marks[k]])
		if not pixels.is_empty():
			line.pop_front()
		pixels.append_array(line)
	return pixels


## Shows the TUTORIAL plaque (once the guided first run has been finished).


## Feeds one touch (game coordinates). Returns true if it was used.
func handle_pointer(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0 or _chapter == null:
		return false
	var at := Vector2i(touch.position.floor())
	# The title takes every tap: one anywhere starts the way down.
	if is_on_title():
		if not touch.pressed and not touch.canceled:
			start_descent()
		return true
	for side: int in [-1, 1]:
		var on: bool = nav_target(side).has_point(at)
		if _pressed_nav == side or (touch.pressed and on and navigation(side) != Nav.NONE):
			_pressed_nav = side if touch.pressed else 0
			if not touch.pressed and not touch.canceled and on and not is_busy():
				step(side)
			_chart.queue_redraw()
			return true
	if touch.pressed:
		_press_at = at
	elif not touch.canceled and _press_at.x >= 0 and not is_busy():
		# A swipe: mostly sideways and long enough steps to the chapter it pulls in.
		var drag: Vector2i = at - _press_at
		_press_at = Vector2i(-1, -1)
		if absi(drag.x) >= SWIPE and absi(drag.x) > 2 * absi(drag.y):
			_pressed_play = false
			_pressed_point = -1
			step(1 if drag.x < 0 else -1)
			_chart.queue_redraw()
			return true
	if touch.pressed:
		_pressed_play = can_play() and play_rect(_screen).has_point(at)
		_pressed_point = -1 if _pressed_play else stage_at(at, _def())
		_chart.queue_redraw()
		return _pressed_play or _pressed_point >= 0
	var used: bool = _pressed_play or _pressed_point >= 0
	if touch.canceled:
		_pressed_play = false
		_pressed_point = -1
		_chart.queue_redraw()
		return used
	if _pressed_play and play_rect(_screen).has_point(at) and can_play():
		stage_chosen.emit(_selected)
	elif _pressed_point >= 0 and stage_at(at, _def()) == _pressed_point and not is_travelling() and not is_lighting() and not is_busy():
		select(_pressed_point)
	_pressed_play = false
	_pressed_point = -1
	_chart.queue_redraw()
	return used


## Moves the comet, the lighting and the breathing ring on. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	var tick: int = int(_time / ANIM_TICK)
	_time += delta
	var redraw: bool = int(_time / ANIM_TICK) != tick
	if not _travel.is_empty():
		_travel_time += delta
		redraw = true
		if _travel_time * TRAVEL_SPEED >= _travel.size() + TRAIL.size():
			_travel.clear()
	# After the comet, so a trip the lighting starts begins from its start.
	_advance_meteor(delta)
	if _light_point >= 0:
		_light_time += delta
		redraw = true
		if _light_time >= LIGHT_TIME:
			_light_point = -1
			if _unlock_next:
				_unlock_next = false
				_unlock_time = 0.0
			if _then_travel_to >= 0:
				var to: int = _then_travel_to
				_then_travel_to = -1
				select(to)
	if _unlock_time >= 0.0:
		_unlock_time += delta
		redraw = true
		if _unlock_time >= UNLOCK_TIME:
			_unlock_time = -1.0
			_selected = Chapter.FINAL
			_refresh()
	if _figure_time >= 0.0:
		_figure_time += delta
		redraw = true
		var length: float = LIFE_TIME if Chapter.is_final(_figure_stage) else ConstellationView.FIGURE_RISE + ConstellationView.FIGURE_FLASH
		if _figure_time >= length:
			_figure_time = -1.0
			_figure_stage = -1
	redraw = _advance_chapters(delta) or redraw
	redraw = _advance_descent(delta) or redraw
	if redraw:
		_chart.queue_redraw()


## Moves the chapter navigation's animations on: a refusal, a voyage, the next chapter opening and
## its reveal. Returns whether anything moved.
func _advance_chapters(delta: float) -> bool:
	var moved: bool = false
	if _refuse_time >= 0.0:
		_refuse_time += delta
		moved = true
		if _refuse_time >= REFUSE_SAY:
			_refuse_time = -1.0
			if not is_revealing():
				_restore_heading()
	if _open_pending and _figure_time < 0.0 and _light_point < 0:
		_open_pending = false
		_open_time = 0.0
		padlock_shaken.emit()
	if _open_time >= 0.0:
		var before: float = _open_time
		_open_time += delta
		moved = true
		if before < OPEN_SHAKE and _open_time >= OPEN_SHAKE:
			padlock_broke.emit()
		if _open_time >= OPEN_TIME:
			_open_time = -1.0
			chapter_opened.emit()
	if _voyage_time >= 0.0:
		_voyage_time += delta
		moved = true
		_camera = lerpf(_voyage_from, _voyage_to, voyage_progress())
		# The new chart takes over halfway, while neither is on screen (they're signs apart).
		if not _voyage_swapped and voyage_progress() >= 0.5:
			_voyage_swapped = true
			setup(_voyage_chapter)
			_reveal_pending = _voyage_reveal
		if _voyage_time >= _voyage_length:
			_voyage_time = -1.0
			_camera = _voyage_to
			_lead_trail.clear()
			star_landed.emit()
			if _reveal_pending:
				_start_reveal()
		else:
			_lead_trail.push_front(lead_star())
			if _lead_trail.size() > TRAIL.size():
				_lead_trail.pop_back()
		_place_slid()
	if _reveal_time >= 0.0:
		var before: float = _reveal_time
		_reveal_time += delta
		moved = true
		for k: int in range(1, _reveal_order.size()):
			if before < k * REVEAL_STEP and _reveal_time >= k * REVEAL_STEP:
				star_revealed.emit(k)
		if before < 0.12 and _reveal_time >= 0.12:
			_title.label_settings.font_color = Palette.C1
		var popped: float = _reveal_order.size() * REVEAL_STEP + REVEAL_POP
		if before < popped and _reveal_time >= popped:
			chapter_revealed.emit()
			# The crown's comet runs to the stage to play.
			_selected = Chapter.FINAL
			select(_chapter.current())
		if _reveal_time >= maxf(popped, maxf(REVEAL_SAY, REVEAL_SPARKLE)):
			_reveal_time = -1.0
			_card.hide_card()
			_restore_heading()
			_refresh()
	return moved


## The labels that travel with the chart (the numbers, the heading, the stage label) and the passing
## constellations' names follow the camera.
func _place_slid() -> void:
	_place_heading()
	_refresh()
	for sign: String in PASSING:
		var shift: int = roundi(sky_x(sign) - _camera)
		var label: Label = _passing_names[sign]
		label.visible = is_voyaging() and shift > -SKY_SPAN and shift < _screen.end.x
		if label.visible:
			var lowest: int = 0
			var span := Vector2i(SKY_SPAN, 0)
			for star: Vector2i in PASSING[sign]["stars"]:
				lowest = maxi(lowest, star.y)
				span = Vector2i(mini(span.x, star.x), maxi(span.y, star.x))
			label.size = label.get_minimum_size()
			label.position = Vector2(shift + (span.x + span.y) / 2 - floori(label.size.x / 2.0), lowest + PASSING_NAME_GAP)


## The shooting star flies on and ends; the next one waits its turn.
func _advance_meteor(delta: float) -> void:
	if _meteor_age >= 0.0:
		_meteor_age += delta
		if _meteor_age * METEOR_SPEED >= _meteor.size() + METEOR_TRAIL.size():
			_meteor_age = -1.0
			_meteor_wait = meteor_rng.randf_range(METEOR_WAIT.x, METEOR_WAIT.y)
		return
	_meteor_wait -= delta
	if _meteor_wait <= 0.0:
		launch_meteor()


func _ring_frame() -> int:
	return int(_time / RING_STEP) % 2


## Stage `stage`'s main star twinkle step at `time`: 1 for TWINKLE_ON once a period, else 0.
static func twinkle_step(stage: int, time: float) -> int:
	return 1 if fposmod(time - stage * TWINKLE_OFFSET, TWINKLE_PERIOD) >= TWINKLE_PERIOD - TWINKLE_ON else 0


## The point to play next's flare step at `time`: 0 at rest, 1 rising and falling, 2 at full.
static func flare_step(time: float) -> int:
	var t: float = fmod(time, FLARE_PERIOD)
	for step: Vector2 in FLARE_STEPS:
		if t < step.x:
			return int(step.y)
	return 0


## A part's main star (its point), centred on 0,0, in `state` at animation `step`: a 4-point star,
## bigger than the other chart stars and in its own tone. Locked: icy blue (the land ramp, unlike
## the chart's purple), twinkling longer and whiter (step 1). Won: white gold with diagonal glints,
## twinkling the same. To play next: the biggest, flaring (steps 1 and 2) longer and whiter.
static func main_star_pixels(state: Chapter.PointState, step: int) -> Dictionary[Vector2i, Color]:
	var core: Color = Palette.C0
	var corners: Color
	var arms: Array[Color] = []
	var glints: Array[Color] = []
	match state:
		Chapter.PointState.LOCKED:
			core = Palette.M6
			corners = Palette.M4
			if step == 0:
				arms = [Palette.M6, Palette.M5, Palette.M4]
			else:
				arms = [Palette.M6, Palette.M6, Palette.M5, Palette.M4]
		Chapter.PointState.COMPLETED:
			corners = Palette.C1
			if step == 0:
				arms = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
				glints = [Palette.C3]
			else:
				arms = [Palette.C0, Palette.C0, Palette.C1, Palette.C2, Palette.C3]
				glints = [Palette.C2]
		_:
			corners = Palette.C1
			match step:
				0:
					arms = [Palette.C0, Palette.C0, Palette.C1, Palette.C2, Palette.C3]
					glints = [Palette.C2]
				1:
					arms = [Palette.C0, Palette.C0, Palette.C0, Palette.C1, Palette.C2, Palette.C3]
					glints = [Palette.C1, Palette.C3]
				_:
					arms = [Palette.C0, Palette.C0, Palette.C0, Palette.C0, Palette.C1, Palette.C2, Palette.C3]
					glints = [Palette.C0, Palette.C2]
	var dots: Dictionary[Vector2i, Color] = {}
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		dots[d] = corners
		for k: int in glints.size():
			dots[d * (k + 2)] = glints[k]
	for axis: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for k: int in arms.size():
			dots[axis * (k + 1)] = arms[k]
	dots[Vector2i.ZERO] = core
	return dots


func _refresh() -> void:
	if _chapter == null or _info == null:
		return
	for stage: int in _numbers.size():
		var colour: Color = Palette.N8
		match _chapter.state(stage):
			Chapter.PointState.COMPLETED:
				colour = Palette.C1
			Chapter.PointState.AVAILABLE:
				colour = Palette.C2
		_numbers[stage].label_settings = HudText.secondary(colour)
		_numbers[stage].position = Vector2(stage_position(stage, _def()) + NUMBER_OFFSET + Vector2i(chart_x(), 0))
		_numbers[stage].visible = not is_revealing()
	if _chapter.has_stage(_selected):
		_info.text = _chapter.stage_name(_selected)
		_info.label_settings.font_color = Palette.C1
	else:
		_info.text = "COMING SOON"
		_info.label_settings.font_color = Palette.N8
	_centre(_info, INFO_Y + label_drop(_screen))
	_info.position.x += chart_x()
	_play.visible = can_play()
	_play.text = "REPLAY" if _chapter.is_completed(_selected) else "PLAY"
	_play.size = _play.get_minimum_size()
	var play: Rect2i = play_rect(_screen)
	_play.position = Vector2(play.position.x + floori((play.size.x - _play.size.x) / 2.0) + chart_x(), play.position.y + 7)
	_play.visible = can_play() and not is_revealing()
	_chart.queue_redraw()


func _place_heading() -> void:
	if _title == null:
		return
	var rise: int = heading_rise(_screen)
	_centre(_title, TITLE_Y - rise)
	_centre(_subtitle, SUBTITLE_Y - rise)
	_title.position.x += chart_x()
	_subtitle.position.x += chart_x()


func _centre(label: Label, y: int) -> void:
	label.size = label.get_minimum_size()
	label.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(label.size.x / 2.0), y)


func _draw_chart() -> void:
	if _space == null:
		_space = ImageTexture.create_from_image(space_image(_screen, _def(), false))
	# The sky behind is drawn on the screen as it is: it holds still while the camera rises.
	_chart.draw_set_transform(Vector2(0, -roundi(_camera_y)))
	_chart.draw_texture(_space, Vector2(_screen.position))
	var motes: Dictionary[Vector2i, Color] = mote_pixels(_motes, _time)
	for p: Vector2i in motes:
		_dot(p, motes[p])
	_draw_sky_stars()
	_draw_passing()
	var meteor: Dictionary[Vector2i, Color] = meteor_pixels()
	for p: Vector2i in meteor:
		_dot(p, meteor[p])
	if _chapter == null:
		_chart.draw_set_transform(Vector2.ZERO)
		return
	_draw_sparkles()
	_draw_lead_comet()
	# The chart is drawn at its place on the sky against the camera's.
	_chart.draw_set_transform(Vector2(chart_x(), 0))
	_draw_figure()
	var legs: Array[Leg] = string_legs()
	for leg: Leg in [Leg.GUIDE, Leg.NEXT, Leg.LIT]:
		for segment: int in _def().figure.segment_count():
			var ends: Vector2i = _def().figure.segments[segment]
			if legs[segment] == leg and revealed(ends.x) and revealed(ends.y):
				_draw_string(segment, leg)
	if unlock_phase(_unlock_time) == 2 and _unlock_time - (UNLOCK_TIME - UNLOCK_BURST) < UNLOCK_FLASH:
		for segment: int in _def().figure.segment_count():
			for p: Vector2i in LinkLayer.line_pixels(_def().figure.landmarks[_def().figure.segments[segment].x], _def().figure.landmarks[_def().figure.segments[segment].y]):
				_dot(p, Palette.C0)
	for landmark: int in _def().figure.landmarks.size():
		if revealed(landmark):
			_draw_star(landmark)
	_draw_pops()
	if not is_revealing() or _reveal_time >= _reveal_order.size() * REVEAL_STEP:
		_draw_crown()
	if not is_revealing() and not is_voyaging() and not is_on_title():
		_draw_selection(stage_position(_selected, _def()))
	if _light_point >= 0:
		var k: float = _light_time / LIGHT_TIME
		var colour: Color = LIGHT_COLOURS[mini(floori(k * LIGHT_COLOURS.size()), LIGHT_COLOURS.size() - 1)]
		var radius: int = 4 + roundi(k * LIGHT_GROWTH)
		for d: Vector2i in ConstellationView.circle_pixels(radius):
			_dot(stage_position(_light_point, _def()) + d, colour)
	_draw_comet()
	_draw_unlock()
	_draw_label_rules()
	if can_play() and not is_revealing():
		_draw_plaque(play_rect(_screen), Palette.M3 if _pressed_play else Palette.N0, Palette.C2)
	_chart.draw_set_transform(Vector2.ZERO)
	_draw_navigation()
	_draw_opening()


## The background stars at their depth: still at rest, drifting behind the camera on a voyage at
## STAR_PARALLAX of its speed, each streaking behind itself (N6, then N5) as that speed grows. Seen
## from the title they sit lower by STAR_PARALLAX of the camera's height, and drift up on the way
## down (calmly: no streaks).
func _draw_sky_stars() -> void:
	var stars_x: int = roundi(_camera * STAR_PARALLAX)
	var key := Vector4i(stars_x, chart_x(), ZODIAC.find(_def().id), camera_y())
	if key != _stars_key:
		_stars_key = key
		var off: Array[Rect2i] = []
		if camera_y() > 0:
			var title: Rect2i = _title_view.title_rect().grow(3)
			off.append(Rect2i(title.position + Vector2i(0, camera_y() - _screen.size.y), title.size))
		_stars = sky_stars(_screen, _def(), stars_x, chart_x(), roundi(_camera_y * STAR_PARALLAX), camera_y(), off)
	var speed: float = voyage_speed() * STAR_PARALLAX
	var streak: int = clampi(roundi((absf(speed) - STREAK_SPEED) / 60.0), 0, STREAK_MAX)
	var behind: int = -signi(roundi(speed))
	for star: Vector3i in _stars:
		var p := Vector2i(star.x, star.y)
		# Only the brighter half streaks, so the sky keeps its points.
		if star.z % 2 == 0:
			for k: int in range(1, streak + 1):
				_dot(p - Vector2i(behind * k, 0), Palette.N5 if k == 1 else Palette.N4)
		if is_glint(star.z):
			for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				_dot(p + n, Palette.N7)
			_dot(p, Palette.M5)
		elif twinkles(star.z) and sky_twinkles(p, _time, star.z):
			_dot(p, Palette.M6)
		else:
			_dot(p, STAR_COLOURS[(star.z / GLINT_ODDS) % STAR_COLOURS.size()])


## The constellations between the chapters, passing on a voyage: faint stars, dotted strings.
func _draw_passing() -> void:
	if not is_voyaging():
		return
	for sign: String in PASSING:
		var shift := Vector2i(roundi(sky_x(sign) - _camera), 0)
		if shift.x <= -SKY_SPAN or shift.x >= _screen.end.x:
			continue
		var stars: Array = PASSING[sign]["stars"]
		for line: Vector2i in PASSING[sign]["lines"]:
			var pixels: Array[Vector2i] = LinkLayer.line_pixels(stars[line.x] + shift, stars[line.y] + shift)
			for k: int in range(3, pixels.size() - 3):
				_dot(pixels[k], Palette.N5)
		for i: int in stars.size():
			var at: Vector2i = stars[i] + shift
			var bright: bool = PASSING[sign]["bright"].has(i)
			for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				_dot(at + n, Palette.M5 if bright else Palette.N8)
				if bright:
					_dot(at + n * 2, Palette.N7)
			_dot(at, Palette.M6 if bright else Palette.M5)


## The selection star leading a voyage (lead_star) or the way down from the title (descent_star).
func _draw_lead_comet() -> void:
	if is_voyaging():
		_draw_lead(lead_star(), Vector2(voyage_speed(), 0.0))
	elif is_descending():
		_draw_lead(descent_star(), Vector2(0.0, descent_speed()))


## The leading star at `head` with its trail along the way it went, the camera moving at `speed`
## (px a second).
func _draw_lead(head: Vector2i, speed: Vector2) -> void:
	# The trail joins the places it was drawn at, cooling along the way.
	var points: Array[Vector2i] = [head]
	points.append_array(_lead_trail)
	var trail: Array[Vector2i] = []
	for k: int in range(1, points.size()):
		var leg: Array[Vector2i] = LinkLayer.line_pixels(points[k - 1], points[k])
		trail.append_array(leg.slice(1))
	# Leading the cruise it holds still on screen while the sky streams past: a speed trail streams
	# out behind it, as long as the camera is fast.
	var along := Vector2i(signi(roundi(speed.x)), signi(roundi(speed.y)))
	var streak: int = clampi(roundi(speed.length() / 22.0), 0, TRAIL.size() * 3)
	for k: int in range(streak, 0, -1):
		_dot(head - along * k, TRAIL[mini(k * TRAIL.size() / maxi(streak, 1), TRAIL.size() - 1)])
	var length: int = mini(trail.size(), TRAIL.size() * 3)
	for k: int in range(length - 1, -1, -1):
		_dot(trail[k], TRAIL[mini(k * TRAIL.size() / maxi(length, 1), TRAIL.size() - 1)])
	for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		_dot(head + n, Palette.C1)
	_dot(head, Palette.C0)


## The chapter arrows: a chevron to an open chapter, a padlock to a locked one, nothing at the
## ends. The opening's padlock shakes and heats, then gives way to the chevron.
func _draw_navigation() -> void:
	for side: int in [-1, 1]:
		var state: int = navigation(side)
		var at: Vector2i = nav_centre(side)
		if side == 1 and is_opening():
			if _open_time < OPEN_SHAKE:
				var k: float = maxf(_open_time, 0.0) / OPEN_SHAKE
				var rate: float = lerpf(0.06, 0.025, k)
				var shake: int = [1, 0, -1, 0][int(maxf(_open_time, 0.0) / rate) % 4] if _open_time >= 0.0 else 0
				var heat: Color = Palette.N7 if k < 0.4 else (Palette.C3 if k < 0.75 else Palette.C2)
				_draw_padlock(at + Vector2i(shake, 0), heat)
				if _open_time >= 0.0:
					for d: Vector2i in ConstellationView.circle_pixels(8 + int(_open_time / 0.08) % 2):
						if (d.x + d.y) % 2 == 0:
							_dot(at + d, Palette.C3 if k < 0.6 else Palette.C2)
				continue
			# Flashes in, then bounces towards the new chapter as the comet passes it.
			var bounce: int = 2 if absf(_open_time - (OPEN_COMET_AT + OPEN_COMET * 0.45)) < 0.08 else 0
			_draw_chevron(at + Vector2i(bounce, 0), side, Palette.C0 if _open_time - OPEN_SHAKE < 0.12 or bounce > 0 else Palette.C2)
			continue
		if state == Nav.NONE:
			continue
		var shift: int = 0
		if side == _refuse_side and _refuse_time >= 0.0 and _refuse_time < REFUSE_SHAKE:
			shift = [1, 0, -1, 0][int(_refuse_time / 0.03) % 4]
		if state == Nav.LOCKED:
			_draw_padlock(at + Vector2i(shift, 0), Palette.N7)
		else:
			_draw_chevron(at, side, Palette.C0 if _pressed_nav == side else Palette.C2)


## A chevron pointing to `side`, two pixels thick, with an N0 shadow.
func _draw_chevron(at: Vector2i, side: int, colour: Color) -> void:
	var pixels: Array[Vector2i] = chevron_pixels(side)
	for p: Vector2i in pixels:
		_dot(at + p + Vector2i.ONE, Palette.N0)
	for p: Vector2i in pixels:
		_dot(at + p, colour)


static func chevron_pixels(side: int) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	for y: int in range(-4, 5):
		var x: int = 2 - absi(y)
		pixels.append(Vector2i(x * side, y))
		pixels.append(Vector2i((x - 1) * side, y))
	return pixels


## A padlock: a shackle (N8) over a body in `body` with an N3 keyhole, and an N0 shadow.
func _draw_padlock(at: Vector2i, body: Color) -> void:
	var shape: Dictionary[Vector2i, Color] = padlock_pixels(body)
	for p: Vector2i in shape:
		_dot(at + p + Vector2i.ONE, Palette.N0)
	for p: Vector2i in shape:
		_dot(at + p, shape[p])


static func padlock_pixels(body: Color) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	for p: Vector2i in [Vector2i(-1, -5), Vector2i(0, -5), Vector2i(1, -5), Vector2i(-2, -4), Vector2i(2, -4), Vector2i(-2, -3), Vector2i(2, -3), Vector2i(-2, -2), Vector2i(2, -2)]:
		pixels[p] = Palette.N8
	for y: int in range(-1, 4):
		for x: int in range(-3, 4):
			pixels[Vector2i(x, y)] = body
	pixels[Vector2i(0, 0)] = Palette.N3
	pixels[Vector2i(0, 1)] = Palette.N3
	return pixels


## The next chapter opening, past its shake: the padlock's burst (a ring and shards falling away)
## and the comet from the crown out past the arrow.
func _draw_opening() -> void:
	if _open_time < OPEN_SHAKE:
		return
	var at: Vector2i = nav_centre(1)
	var t: float = _open_time - OPEN_SHAKE
	if t < OPEN_BREAK:
		for p: Vector2i in shard_pixels(t):
			_dot(at + p, SHARD_COLOURS[mini(floori(t / OPEN_BREAK * SHARD_COLOURS.size()), SHARD_COLOURS.size() - 1)])
		if t < 0.28:
			var k: float = t / 0.28
			for d: Vector2i in ConstellationView.circle_pixels(4 + roundi(k * 20.0)):
				_dot(at + d, SHARD_COLOURS[mini(floori(k * SHARD_COLOURS.size()), SHARD_COLOURS.size() - 1)])
		if t < 0.12:
			for r: int in 8:
				var dir: Vector2 = Vector2.from_angle(TAU * r / 8.0)
				for p: Vector2i in LinkLayer.line_pixels(at + Vector2i((dir * 5.0).round()), at + Vector2i((dir * (9.0 + t * 80.0)).round())):
					_dot(p, Palette.C0)
	var c: float = (_open_time - OPEN_COMET_AT) / OPEN_COMET
	if c < 0.0 or c >= 1.0:
		return
	var path: Array[Vector2i] = opening_path()
	var head: int = roundi(c * (path.size() + TRAIL.size()))
	for k: int in range(TRAIL.size() - 1, -1, -1):
		var i: int = head - k
		if i >= 0 and i < path.size():
			_dot(path[i], TRAIL[k])
	if head < path.size():
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(path[head] + n, Palette.C1)
		_dot(path[head], Palette.C0)


## The padlock's shards `t` seconds after it broke: flung out round it, falling.
static func shard_pixels(t: float) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	for i: int in OPEN_SHARDS:
		var angle: float = TAU * i / OPEN_SHARDS + 0.3
		var speed: float = 42.0 + 22.0 * float((i * 7) % 5) / 4.0
		var p := Vector2(cos(angle), sin(angle)) * speed * t + Vector2(0.0, 110.0 * t * t)
		pixels.append(Vector2i(p.round()))
	return pixels


## The opening comet's way: from the crown to the arrow, then on off the screen's right edge.
func opening_path() -> Array[Vector2i]:
	var arrow: Vector2i = nav_centre(1)
	var path: Array[Vector2i] = LinkLayer.line_pixels(stage_position(Chapter.FINAL, _def()), arrow)
	path.append_array(LinkLayer.line_pixels(arrow, Vector2i(_screen.end.x + 12, arrow.y)).slice(1))
	return path


## The reveal's pops: each star just in throws a C0 cross and a ring that cools as it grows.
func _draw_pops() -> void:
	if _reveal_time < 0.0:
		return
	for k: int in _reveal_order.size():
		var age: float = _reveal_time - k * REVEAL_STEP
		if age < 0.0 or age >= REVEAL_POP:
			continue
		var at: Vector2i = _def().figure.landmarks[_reveal_order[k]]
		if age < 0.08:
			for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				_dot(at + d, Palette.C0)
		var ring: float = age / REVEAL_POP
		for d: Vector2i in ConstellationView.circle_pixels(3 + roundi(ring * 7.0)):
			_dot(at + d, LIGHT_COLOURS[mini(floori(ring * LIGHT_COLOURS.size()), LIGHT_COLOURS.size() - 1)])


## The reveal's shower: sparkles twinkling up across the sky (a C0 cross, then a C1 dot, then N8).
func _draw_sparkles() -> void:
	if _reveal_time < 0.0:
		return
	for i: int in REVEAL_SPARKLES:
		var h: int = CurrentView._hash(i * 7 + 13)
		var at := Vector2i(_screen.position.x + 6 + h % (_screen.size.x - 12), _screen.position.y + 50 + (h / 97) % (_screen.size.y - 120))
		var age: float = _reveal_time - (REVEAL_SPARKLE - 0.35) * i / REVEAL_SPARKLES
		if age < 0.0 or age >= 0.35:
			continue
		if age < 0.12:
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				_dot(at + d, Palette.C1)
			_dot(at, Palette.C0)
		else:
			_dot(at, Palette.C1 if age < 0.24 else Palette.N8)


## The thin rules either side of the stage name, each tipped with a small star: warm for a stage
## that can be played, cool otherwise.
func _draw_label_rules() -> void:
	if _info == null:
		return
	var y: int = INFO_Y + label_drop(_screen) + 3
	var half: int = floori(_info.size.x / 2.0)
	var tip: Color = Palette.C2 if can_play() else Palette.N8
	for side: int in [-1, 1]:
		var start: int = ScreenZones.SCREEN.x / 2 + side * (half + RULE_GAP)
		var end: int = start + side * RULE
		for p: Vector2i in LinkLayer.line_pixels(Vector2i(start, y), Vector2i(end, y)):
			_dot(p, Palette.N6)
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(Vector2i(end + side * 2, y) + n, tip)
		_dot(Vector2i(end + side * 2, y), Palette.C0 if can_play() else Palette.M6)


## How each string shows (_def().figure.segments order): LIT between two won stars, NEXT through
## and into the part to play next (from the won stars before it), GUIDE elsewhere.
func string_legs() -> Array[Leg]:
	var legs: Array[Leg] = []
	for segment: int in _def().figure.segment_count():
		var ends: Array[int] = _def().figure.segment_landmarks(segment)
		var a: Chapter.PointState = _star_state(ends[0])
		var b: Chapter.PointState = _star_state(ends[1])
		if a == Chapter.PointState.COMPLETED and b == Chapter.PointState.COMPLETED:
			legs.append(Leg.LIT)
		elif a != Chapter.PointState.LOCKED and b != Chapter.PointState.LOCKED:
			legs.append(Leg.NEXT)
		else:
			legs.append(Leg.GUIDE)
	return legs


## A chart star shows its part stage's state.
func _star_state(landmark: int) -> Chapter.PointState:
	return _chapter.state(_chapter.stage_of(landmark))


## A solid 1 px string: C1 when travelled, C3 on the way to the next stage, an N6 guide elsewhere.
func _draw_string(segment: int, leg: Leg) -> void:
	var ends: Array[int] = _def().figure.segment_landmarks(segment)
	var colour: Color = Palette.N6
	if leg == Leg.LIT:
		colour = Palette.C1
	elif leg == Leg.NEXT:
		colour = Palette.C3
	for p: Vector2i in LinkLayer.line_pixels(_def().figure.landmarks[ends[0]], _def().figure.landmarks[ends[1]]):
		_dot(p, colour)


## A chart star in its part's state: a gold star once won; warm while its part is the one to
## play; cool and quieter while locked. A part's first star is its main star (main_star_pixels),
## wearing the breathing ring while it's the one to play.
func _draw_star(landmark: int) -> void:
	var at: Vector2i = _def().figure.landmarks[landmark]
	var stage: int = _chapter.stage_of(landmark)
	if landmark == _chapter.stars(stage)[0]:
		_draw_main_star(stage)
		return
	match _chapter.state(stage):
		Chapter.PointState.COMPLETED:
			for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				_dot(at + d, Palette.C2)
			_fill(at, 1, Palette.C1)
			_dot(at, Palette.C0)
		Chapter.PointState.AVAILABLE:
			_fill(at, 1, Palette.C2)
			_dot(at, Palette.C0)
		_:
			_fill(at, 1, Palette.N0)
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				_dot(at + d, Palette.N8)
			_dot(at, Palette.M6)


## Stage `stage`'s main star, animated: the point to play next flares and wears the ring; the others
## twinkle on their own beat.
func _draw_main_star(stage: int) -> void:
	var at: Vector2i = stage_position(stage, _def())
	var state: Chapter.PointState = _chapter.state(stage)
	var step: int = flare_step(_time) if state == Chapter.PointState.AVAILABLE else twinkle_step(stage, _time)
	var dots: Dictionary[Vector2i, Color] = main_star_pixels(state, step)
	for d: Vector2i in dots:
		_dot(at + d, dots[d])
	if state == Chapter.PointState.AVAILABLE:
		_ring(at)


## The final stage's crown point: a star with 3 px arms (gold once won, cool while locked). While
## it's open and not won it's the boss's point: arms of 5 px stepping down the warm ramp, diagonal
## glints, the flare of the point to play next, and an ember ring (S4) instead of the warm one.
## Hidden while its unlock charges; it appears with the burst.
func _draw_crown() -> void:
	var state: Chapter.PointState = _chapter.state(Chapter.FINAL)
	var phase: int = unlock_phase(_unlock_time)
	if (phase == 0 or phase == 1 or _unlock_next):
		state = Chapter.PointState.LOCKED
	if state == Chapter.PointState.AVAILABLE:
		var dots: Dictionary[Vector2i, Color] = main_star_pixels(state, flare_step(_time))
		for d: Vector2i in dots:
			_dot(_def().final_at + d, dots[d])
		for d: Vector2i in ConstellationView.circle_pixels(RING_RADIUS + 2 + _ring_frame()):
			_dot(_def().final_at + d, Palette.S4)
		return
	var core: Color = Palette.N8
	var arms: Color = Palette.N6
	if state == Chapter.PointState.COMPLETED:
		core = Palette.C0
		arms = Palette.C1
	elif state == Chapter.PointState.AVAILABLE:
		core = Palette.C1
		arms = Palette.C2
		_ring(_def().final_at)
	for k: int in range(1, 4):
		for d: Vector2i in [Vector2i(0, -k), Vector2i(0, k), Vector2i(-k, 0), Vector2i(k, 0)]:
			_dot(_def().final_at + d, core if k == 1 else arms)
	_dot(_def().final_at, Palette.C0 if state != Chapter.PointState.LOCKED else Palette.M6)


## The final's unlock: the comets flying into the crown, the rings closing in on it, then the burst
## (a ring thrown out, cooling down the warm ramp, and rays).
func _draw_unlock() -> void:
	var phase: int = unlock_phase(_unlock_time)
	if phase < 0:
		return
	if phase == 0:
		var heads: Array[int] = unlock_comet_heads(_unlock_time, _def())
		for stage: int in heads.size():
			if heads[stage] < 0:
				continue
			var line: Array[Vector2i] = LinkLayer.line_pixels(stage_position(stage, _def()), _def().final_at)
			for k: int in range(TRAIL.size() - 1, -1, -1):
				var i: int = heads[stage] - k
				if i >= 0:
					_dot(line[i], TRAIL[k])
			for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				_dot(line[heads[stage]] + n, Palette.C1)
			_dot(line[heads[stage]], Palette.C0)
		return
	var start: float = UNLOCK_STAGGER * 4 + UNLOCK_FLIGHT
	if phase == 1:
		var k: float = (_unlock_time - start) / UNLOCK_CHARGE
		for ring: int in 3:
			var radius: int = roundi((1.0 - fposmod(k * 2.0 + ring / 3.0, 1.0)) * 18.0) + 2
			for d: Vector2i in ConstellationView.circle_pixels(radius):
				_dot(_def().final_at + d, Palette.C2 if ring == 0 else Palette.C3)
		for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(_def().final_at + d, Palette.C0)
		return
	var b: float = (_unlock_time - start - UNLOCK_CHARGE) / UNLOCK_BURST
	var colour: Color = BURST_COLOURS[mini(floori(b * BURST_COLOURS.size()), BURST_COLOURS.size() - 1)]
	for d: Vector2i in ConstellationView.circle_pixels(6 + roundi(b * UNLOCK_BURST_GROWTH)):
		_dot(_def().final_at + d, colour)
	var reach: int = 8 + roundi(b * 26.0)
	for r: int in UNLOCK_RAYS:
		var dir: Vector2 = Vector2.from_angle(TAU * r / UNLOCK_RAYS)
		var tip := Vector2i((dir * reach).round())
		var tail := Vector2i((dir * maxf(reach - 10.0, 4.0)).round())
		for p: Vector2i in LinkLayer.line_pixels(_def().final_at + tail, _def().final_at + tip):
			_dot(p, colour)


## The Scorpio behind the chart: alive in full colour once the final is won (flashing C0 twice as
## it comes to life); before that, each won part's dormant piece, the one just won forming from its
## stars with a bright edge, then one C0 flash.
func _draw_figure() -> void:
	if shows_figure():
		if _figure_stage == Chapter.FINAL and life_flashing(_figure_time):
			var rows: Dictionary = ConstellationView.figure_rows(_def().figure.painting)
			for y: int in rows:
				for x: int in rows[y]:
					_dot(Vector2i(x, y), Palette.C0)
			return
		_chart.draw_texture(ConstellationView.painting(_def().figure.painting), Vector2.ZERO)
		return
	for stage: int in Chapter.FINAL:
		if not shows_piece(stage):
			continue
		if stage == _figure_stage and _figure_time >= 0.0:
			_draw_rising_piece(stage)
		else:
			_chart.draw_texture(dormant_piece(stage, _def()), Vector2.ZERO)


## Part `stage`'s piece forming after its win, from its stars on the chart: what's inside the edge
## dormant, the edge C0 at the front and C1 behind; then one C0 flash.
func _draw_rising_piece(stage: int) -> void:
	var path: String = piece_path(stage, _def())
	var rows: Dictionary = ConstellationView.figure_rows(path)
	if _figure_time >= ConstellationView.FIGURE_RISE:
		for y: int in rows:
			for x: int in rows[y]:
				_dot(Vector2i(x, y), Palette.C0)
		return
	var forming: Apparition = piece_apparition(stage, _def())
	var radius: int = forming.radius_at(_figure_time / ConstellationView.FIGURE_RISE)
	_chart.draw_texture(forming.formed(radius), Vector2.ZERO)
	var edge: Dictionary[Vector2i, Color] = forming.edge(radius)
	for p: Vector2i in edge:
		_dot(p, edge[p])


## How part `stage`'s dormant piece forms on the chart: from that part's stars there.
static func piece_apparition(stage: int, def: ChapterDef = null) -> Apparition:
	def = _or_scorpio(def)
	var stars: Array[Vector2i] = []
	for index: int in def.stages[stage]["stars"]:
		stars.append(def.figure.landmarks[index])
	return Apparition.of(piece_path(stage, def) + "|dormant", dormant_piece(stage, def), stars)


## The chapter shown (Scorpio before setup).
func _def() -> ChapterDef:
	return _chapter.def if _chapter != null else _or_scorpio(null)


static func _or_scorpio(def: ChapterDef) -> ChapterDef:
	if def != null:
		return def
	if _scorpio == null:
		_scorpio = ChapterDef.scorpio()
	return _scorpio


## Reads `def`'s paintings that exist before any draw call uses them, and titles the chart.
func _load_paintings(def: ChapterDef) -> void:
	if has_art(def.figure.painting):
		ConstellationView.figure_rows(def.figure.painting)
	for stage: int in Chapter.FINAL:
		if has_art(piece_path(stage, def)):
			ConstellationView.figure_rows(piece_path(stage, def))
			dormant_piece(stage, def)
	_title.text = def.title
	_subtitle.text = "CHAPTER %d" % def.number


func _ring(at: Vector2i) -> void:
	for d: Vector2i in ConstellationView.circle_pixels(RING_RADIUS + _ring_frame()):
		_dot(at + d, Palette.C2)


## C0 corner brackets round the selected point (a lighter C1 while it's pressed).
func _draw_selection(at: Vector2i) -> void:
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var c: Vector2i = at + corner * 9
		for i: int in 3:
			_dot(c - Vector2i(corner.x * i, 0), Palette.C0)
			_dot(c - Vector2i(0, corner.y * i), Palette.C0)


func _draw_comet() -> void:
	if _travel.is_empty():
		return
	var head: int = int(_travel_time * TRAVEL_SPEED)
	for k: int in range(TRAIL.size() - 1, -1, -1):
		var i: int = head - k
		if i >= 0 and i < _travel.size():
			_dot(_travel[i], TRAIL[k])
	if head < _travel.size():
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(_travel[head] + n, Palette.C1)
		_dot(_travel[head], Palette.C0)


func _fill(at: Vector2i, half: int, colour: Color) -> void:
	_chart.draw_rect(Rect2(Vector2(at - Vector2i(half, half)), Vector2(2 * half + 1, 2 * half + 1)), colour)


func _dot(p: Vector2i, colour: Color) -> void:
	_chart.draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)


## A filled rect with a 1 px border that skips its four corner pixels (like the end screen's).
func _draw_plaque(rect: Rect2i, fill: Color, border: Color) -> void:
	var r := Rect2(rect)
	_chart.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill)
	_chart.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	_chart.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	_chart.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	_chart.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)
