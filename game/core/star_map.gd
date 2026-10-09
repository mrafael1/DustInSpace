class_name StarMap
extends RefCounted
## A constellation map's layout (#62): the landmark stars a stage asks the player to light, the
## strings joining them, their sizes, which start lit, and how its finished drawing looks. The
## full Scorpio is one map (Scorpio's constants); each part stage of the chapter has its own
## smaller "false constellation" shaped like that part (the Stinger first). Layout, not balance.
## Positions are on the 180x320 grid in Scorpio.HOME_SKY; a taller sky shifts them (Scorpio.shift).

## The painted art that rises behind the stars when the map is complete
## (tools/art/build_scorpio_figure.py): the whole Scorpio for the full maps, or the stage's own
## piece of it, fitted to its stars, for a part stage.
const FIGURE := "res://assets/art/scorpio_figure.png"
const PART_PAINTING := "res://assets/art/scorpio_part_%s.png"
## Chapter 2's painted Aquarius, for its chart and final (tools/art/build_aquarius_figure.py).
const AQUARIUS_FIGURE := "res://assets/art/aquarius_figure.png"
## An Aquarius stage's own painting (tools/art/build_aquarius_figure.py).
const AQUARIUS_PART := "res://assets/art/aquarius_part_%s.png"
## Chapter 3's Leo and its stages' paintings, once drawn (a missing one is left out).
const LEO_FIGURE := "res://assets/art/leo_figure.png"
const LEO_PART := "res://assets/art/leo_part_%s.png"
## Chapter 4's Virgo and its stages' paintings, once drawn (a missing one is left out).
const VIRGO_FIGURE := "res://assets/art/virgo_figure.png"
const VIRGO_PART := "res://assets/art/virgo_part_%s.png"

var id: String = ""
## Shown on the end screen: "<NAME> COMPLETE".
var title: String = ""
var landmarks: Array[Vector2i] = []
## Pairs of landmark indices; they form a tree.
var segments: Array[Vector2i] = []
## Star.Size per landmark.
var sizes: Array[int] = []
var starting_lit: Array[int] = []
## The painting shown once the map is complete (a res:// path).
var painting: String = FIGURE
## Orion (#64) hunts this stage: he marks a loose star; the next link saves it or has it shot. With
## a volley too, both threats run (the final brings every one).
var orion: bool = false
## Orion looses a volley (#70) every few links on this stage: the balance.json block that tunes it
## (Balance.VOLLEY_BLOCKS), or "" for none.
var volley: String = ""
## Orion marks a hunting area (#71) here: each launch, once its pack bursts, his arrow strikes it
## and destroys the loose stars inside, then he marks a new one.
var hunt: bool = false
## Whether the stage opens by playing its threats' intros (the volley's, the hunting area's, Leo's
## heat or cold's, Aquarius's flow). The Claws (#74) bring threats each earlier stage already
## introduced, so they open without one; so do Aquarius's Legs (the Body's drain again).
var intros: bool = true
## The chapter's boss stage (the final): Orion opens it by showing himself and fights for the sky.
## Presentation only; the threats above are its rules.
var boss: bool = false
## Debug trial flow geometry in home layout. Its strength is tuning, read from Balance. A region
## spanning Scorpio.HOME_SKY's full height spans the whole play sky's height on any screen.
var current_region: Rect2i = Rect2i()
## The flow drains: stars it carries out of current_region are lost, for nothing.
var current_drains: bool = false
## Which way the flow runs (chapter 2's stream pours down; the rest run left).
var current_direction: Vector2i = Vector2i.LEFT
## A flow that turns after every launch takes these ways in order (the Jar's tide: left, right).
## Empty: it always runs current_direction.
var current_turns: Array[Vector2i] = []
## Leo's heat (chapter 3), over the whole stage: once each launch resolves, every loose star
## changes a size (StarHeat). +1: the heat, stars grow; -1: the cold, they shrink; 0: none.
var heat_change: int = 0
## A star pushed past the last size is lost: a big burns out in the heat, a small fades in the cold.
var heat_burns: bool = false
## The heat changes the constellation stars still to light as well as the loose ones (the Head):
## each launch they grow a size, and a big one burns back to small (StarHeat.preview_landmarks).
var heat_landmarks: bool = false
## The lion breathes (Leo's final): the heat acts after every successful link too, on the loose
## stars and (with heat_landmarks) the constellation stars still to light, from the link outward.
var heat_on_links: bool = false
## Heat and cold take turns, swapping after every launch (the Mane's day and night), starting with
## heat_change.
var heat_turns: bool = false
## Virgo's harvest (chapter 4): every few launches (balance.json's harvest block), the scythe reaps
## the loose stars for nothing (StarHarvest).
var harvest: bool = false
## Bound sheaves: at each harvest, a constellation star lit since the last one goes dark again unless
## lit strings join it to the figure lit before.
var harvest_binds: bool = false
## The quickening: after each harvest the clock is a launch shorter, down to one.
var harvest_quickens: bool = false
## Tied at once: the binding acts after every launch, not only at the harvest.
var harvest_ties: bool = false
## A final that isn't Orion's arrives with its title card: `title` over this ("" for none).
var arrival_epithet: String = ""


## The full Scorpio (#61): every star of Scorpius's figure.
static func scorpio() -> StarMap:
	var map := StarMap.new()
	map.id = "scorpio"
	map.title = "SCORPIO"
	map.landmarks = Scorpio.LANDMARKS
	map.segments = Scorpio.SEGMENTS
	map.sizes = Scorpio.SIZES
	map.starting_lit = Scorpio.STARTING_LIT
	return map


## The Stinger, the chapter's first stage: a false constellation of six stars shaped like the
## scorpion's stinger, laid out as the whole Scorpio's is: the tail's last joints come in from the
## right along the bottom of the sky and turn up at the left, then the telson runs right to the big
## star and the sting curls up from it. The first joint starts lit, so five are left to light
## (tools/balance/sim.py: about 3.8 packs). Strings are 31-34 px.
static func stinger() -> StarMap:
	var map := StarMap.new()
	map.id = "stinger"
	map.title = "STINGER"
	map.landmarks = [Vector2i(112, 236), Vector2i(80, 234), Vector2i(52, 216), Vector2i(66, 188), Vector2i(98, 180), Vector2i(112, 152)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.painting = PART_PAINTING % "stinger"
	return map


## The Tail, stage 2 (#64): six stars in a curve down the right of the sky and along the bottom,
## the scorpion's tail segments, with the top left left open for Orion the hunter, who marks a star
## that a link leaving it behind has shot. The first segment starts lit: five to light.
static func tail() -> StarMap:
	var map := StarMap.new()
	map.id = "tail"
	map.title = "TAIL"
	map.landmarks = [Vector2i(146, 112), Vector2i(150, 142), Vector2i(144, 172), Vector2i(128, 198), Vector2i(104, 216), Vector2i(74, 224)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = PART_PAINTING % "tail"
	map.orion = true
	return map


## Debug experiment: borrow only Tail geometry, never its Orion threats or progress identity.
static func current_trial(enabled: bool = true) -> StarMap:
	var map: StarMap = tail()
	map.id = "current_trial" if enabled else "current_baseline"
	map.title = "CURRENT TRIAL" if enabled else "CURRENT OFF"
	map.orion = false
	map.volley = ""
	map.hunt = false
	map.intros = false
	map.boss = false
	if enabled:
		map.current_region = Rect2i(64, 124, 108, 100)
	return map


## A debug current trial's map: "aquarius" (the flow layout) or the Tail trial (anything else).
static func current_layout(layout: String, enabled: bool = true) -> StarMap:
	return aquarius_flow(enabled) if layout == "aquarius" else current_trial(enabled)


## Debug experiment: the Aquarius Body's layout (aquarius_body) as a trial that the FLOW ON/OFF
## switch can turn the current off on, to compare. The Tail's painting stands in.
static func aquarius_flow(enabled: bool = true) -> StarMap:
	var map: StarMap = aquarius_body()
	map.id = "current_aquarius" if enabled else "current_aquarius_off"
	map.title = "AQUARIUS FLOW" if enabled else "AQUARIUS OFF"
	map.painting = PART_PAINTING % "tail"
	# A plain trial: no opening demo of the flow.
	map.intros = false
	if not enabled:
		map.current_region = Rect2i()
		map.current_drains = false
	return map


## Aquarius, stage 1: the Hand. An arm of five stars reaching from the shoulder (upper right, lit)
## down to the hand (lower left): four to light. It teaches the current on its own: a leftward flow
## over the sky's full height from x 72 to the right edge, with no drain. Stars launched by the upper
## arm drift down the arm toward the forearm and hand, which sit just past the flow, where drifting
## stars come to rest. Strings are 34-35 px.
static func aquarius_hand() -> StarMap:
	var map := StarMap.new()
	map.id = "aquarius_hand"
	map.title = "HAND"
	map.landmarks = [Vector2i(146, 104), Vector2i(120, 126), Vector2i(94, 148), Vector2i(64, 166), Vector2i(36, 186)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4)]
	map.sizes = [Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.painting = AQUARIUS_PART % "hand"
	map.current_region = _full_height_from(72)
	return map


## Aquarius, stage 2: the Body. The drain arrives: a leftward flow over the sky's full height from
## x 48 to the right edge, and any star it carries out past that edge is lost. The head (lit) sits
## at the upper right; the neck and body fall through the flow to the knee at its edge, with a hip
## branching right, so stars saved beside them drift a launch at a time toward the drain (a waiting
## pair has a clock), while stars stranded upstream drift toward them. The foot lies past the
## drain, in the strip the flow leaves still. Five to light. Strings are 33-49 px. Measured as the
## current trial's Aquarius layout (docs/chapter_2_current_trial.md).
static func aquarius_body() -> StarMap:
	var map := StarMap.new()
	map.id = "aquarius_body"
	map.title = "BODY"
	map.landmarks = [Vector2i(146, 104), Vector2i(128, 132), Vector2i(104, 156), Vector2i(72, 178), Vector2i(32, 196), Vector2i(140, 190)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = AQUARIUS_PART % "body"
	map.current_region = _full_height_from(48)
	map.current_drains = true
	return map


## Aquarius, stage 3: the Legs. Two legs branch from the hip (upper right, lit) at the knee: one
## reaches down and left through the flow, its shin near the drain at x 48 and its foot past it;
## the other stays upstream to the right, its calf and heel (Skat, big) in the flow. Stars saved by
## the shin have little time; stars by the right leg drift across toward the knee and shin. Five to
## light. Strings are 36-39 px.
static func aquarius_legs() -> StarMap:
	var map := StarMap.new()
	map.id = "aquarius_legs"
	map.title = "LEGS"
	map.landmarks = [Vector2i(124, 100), Vector2i(96, 124), Vector2i(68, 148), Vector2i(34, 166), Vector2i(116, 154), Vector2i(140, 184)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(1, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL, Star.Size.BIG]
	map.starting_lit = [0]
	map.painting = AQUARIUS_PART % "legs"
	map.intros = false
	map.current_region = _full_height_from(48)
	map.current_drains = true
	return map


## Aquarius, stage 4: the Stream. The water pours down: the flow runs downward over the sky from
## x 16 to 163 and drains along its bottom edge (y 200), like a waterfall. The stream winds down
## from its source at the top left (lit) through the flow; its last star lies below the drain, in
## the still strip above the ground. Stars saved low in the stream fall into the drain soonest.
## Five to light. Strings are 33-50 px.
static func aquarius_stream() -> StarMap:
	var map := StarMap.new()
	map.id = "aquarius_stream"
	map.title = "STREAM"
	map.landmarks = [Vector2i(44, 100), Vector2i(72, 122), Vector2i(48, 148), Vector2i(80, 170), Vector2i(110, 188), Vector2i(132, 226)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.painting = AQUARIUS_PART % "stream"
	map.current_region = Rect2i(16, Scorpio.HOME_SKY.position.y, 148, 200 - Scorpio.HOME_SKY.position.y)
	map.current_drains = true
	map.current_direction = Vector2i.DOWN
	return map


## Aquarius, stage 5: the Jar, where the water comes from, and the tide. The flow reverses after
## every launch (left, then right, then left...) over the sky's full height from x 24 to 155, and
## drains at both sides: a star safe on one launch can be carried out the other way on the next.
## The jar's Y (pi, lit, at the top; zeta at its centre; eta and Sadachbia its arms) stands in the
## middle, its lip below with the spout pouring down and left. Five to light. Strings are 28-42 px.
##
static func aquarius_jar() -> StarMap:
	var map := StarMap.new()
	map.id = "aquarius_jar"
	map.title = "JAR"
	map.landmarks = [Vector2i(90, 100), Vector2i(90, 128), Vector2i(60, 146), Vector2i(120, 146), Vector2i(90, 170), Vector2i(66, 196)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = AQUARIUS_PART % "jar"
	map.current_region = Rect2i(24, Scorpio.HOME_SKY.position.y, 132, Scorpio.HOME_SKY.size.y)
	map.current_drains = true
	map.current_turns = [Vector2i.LEFT, Vector2i.RIGHT]
	return map


## Aquarius's final: the full figure in a rotating box. A box drains on all four sides (x 20 to
## 159, y 96 to 227), and its flow turns a quarter after every launch (left, down, right, up), so
## each side drains in turn: the Jar's tide, now all the way round. The whole Aquarius (the chart's
## figure) stands in it; only pi, atop the jar, sits just above the box. The hand and shoulder
## start lit: twelve to light.
static func aquarius_final() -> StarMap:
	var map: StarMap = aquarius()
	map.id = "aquarius_final"
	map.current_region = Rect2i(20, 96, 140, 132)
	map.current_drains = true
	map.current_turns = [Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP]
	map.arrival_epithet = "THE WATER BEARER"
	return map


## A current over the home sky's full height (a taller sky stretches it: RunState) from `x` to the
## right edge.
static func _full_height_from(x: int) -> Rect2i:
	return Rect2i(x, Scorpio.HOME_SKY.position.y, Scorpio.HOME_SKY.end.x - x, Scorpio.HOME_SKY.size.y)


## The Body, stage 3 (#70): nine stars, more connected than the Tail. A spine of five runs from the
## upper right down to the lower left (landmarks 0-4), and its second and third stars each branch
## to a leg on either side (5-8), so two stars join four strings. The top left stays Orion's: he
## looses a volley every few links here. The spine's top star starts lit: eight to light.
static func body() -> StarMap:
	var map := StarMap.new()
	map.id = "body"
	map.title = "BODY"
	map.landmarks = [Vector2i(150, 100), Vector2i(128, 128), Vector2i(104, 154), Vector2i(80, 180), Vector2i(56, 206), Vector2i(100, 112), Vector2i(152, 146), Vector2i(76, 146), Vector2i(128, 178)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(1, 5), Vector2i(1, 6), Vector2i(2, 7), Vector2i(2, 8)]
	map.sizes = [Star.Size.BIG, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = PART_PAINTING % "body"
	map.volley = "volley"
	return map


## The Heart, stage 4 (#71): seven stars. A spine of five climbs from the lower left (towards the
## Body) through Antares (big, in the middle) to sigma and on to the upper right (towards the
## Claws); Antares also branches up-left and down-right, so four strings meet at the heart. Orion
## keeps the top left and hunts an area: each launch strikes the circle he marked. The lower-left
## star starts lit: six to light.
static func heart() -> StarMap:
	var map := StarMap.new()
	map.id = "heart"
	map.title = "HEART"
	map.landmarks = [Vector2i(60, 204), Vector2i(80, 180), Vector2i(104, 156), Vector2i(128, 132), Vector2i(150, 108), Vector2i(76, 140), Vector2i(130, 178)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5), Vector2i(2, 6)]
	map.sizes = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.painting = PART_PAINTING % "heart"
	map.hunt = true
	return map


## The Claws, stage 5 (#74): seven stars. A neck climbs from the lower left (towards the Heart) to
## Dschubba (the head, big), which forks into two arms: one up to beta, one down to pi, each
## bending back at its elbow, as in the whole Scorpio, with a pincer opening right in the painting. Orion keeps the top left and brings two of his threats:
## the single mark and the hunting area; no volley (#97: with all three the stage was too punishing).
## No intros (each stage before introduced one).
## The neck's first star starts lit: six to light.
static func claws() -> StarMap:
	var map := StarMap.new()
	map.id = "claws"
	map.title = "CLAWS"
	map.landmarks = [Vector2i(64, 194), Vector2i(94, 178), Vector2i(124, 160), Vector2i(104, 140), Vector2i(116, 114), Vector2i(118, 188), Vector2i(136, 210)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5), Vector2i(5, 6)]
	map.sizes = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.painting = PART_PAINTING % "claws"
	map.orion = true
	map.hunt = true
	map.intros = false
	return map


## The final, stage 6: the full Scorpio as a boss stage. Every star of the figure (11 to light,
## the claw arc lit), with all three of Orion's threats at once: the single mark,
## the volley and the hunting area, and no intros.
static func final() -> StarMap:
	var map := scorpio()
	map.id = "final"
	map.orion = true
	map.volley = "volley"
	map.hunt = true
	map.intros = false
	map.boss = true
	return map


## The full Aquarius (chapter 2's chart and, once built, its final): 14 stars of its usual figure,
## spread out to at least 24 px apart like the Scorpio, keeping the shape with east to the left:
## the hand (epsilon) and shoulder (Sadalsuud) on the right, the head (Sadalmelik), the water jar
## at the upper left (Sadachbia, zeta, eta, pi: its Y), the body (theta) down to the knee (lambda),
## the leg (tau, Skat) to the lower right, and the stream (phi, psi, 98) pouring down the left.
## Sizes follow brightness: Sadalsuud, Sadalmelik and Skat big; Sadachbia, zeta, lambda and 98
## medium; the rest small. The hand starts lit.
static func aquarius() -> StarMap:
	var map := StarMap.new()
	map.id = "aquarius"
	map.title = "AQUARIUS"
	map.landmarks = [
		Vector2i(150, 156), Vector2i(124, 140), Vector2i(98, 124), Vector2i(74, 118),
		Vector2i(50, 112), Vector2i(26, 118), Vector2i(52, 88), Vector2i(90, 150),
		Vector2i(66, 160), Vector2i(70, 186), Vector2i(88, 206), Vector2i(42, 170),
		Vector2i(30, 192), Vector2i(24, 218),
	]
	map.segments = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5),
		Vector2i(4, 6), Vector2i(2, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(9, 10),
		Vector2i(8, 11), Vector2i(11, 12), Vector2i(12, 13),
	]
	map.sizes = [
		Star.Size.SMALL, Star.Size.BIG, Star.Size.BIG, Star.Size.MEDIUM,
		Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL,
		Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL,
		Star.Size.SMALL, Star.Size.MEDIUM,
	]
	map.starting_lit = [0, 1]
	map.painting = AQUARIUS_FIGURE
	return map


## The full Leo (chapter 3's chart and, once built, its final): 13 stars of its usual figure,
## spread out to at least 24 px apart, east to the left: the Sickle (the mane and head: lambda,
## epsilon, mu, zeta, Algieba, eta down to Regulus) at the right, the fore paw (omicron) below
## Regulus, the back from Algieba to Zosma, the tail to Denebola at the left, and the hind leg from
## Chertan (theta) down through iota to sigma. Sizes follow brightness: Regulus, Algieba and
## Denebola big; Zosma, epsilon and Chertan medium; the rest small. The tail starts lit.
static func leo() -> StarMap:
	var map := StarMap.new()
	map.id = "leo"
	map.title = "LEO"
	map.landmarks = [
		Vector2i(160, 134), Vector2i(154, 110), Vector2i(136, 92), Vector2i(112, 100),
		Vector2i(102, 124), Vector2i(112, 148), Vector2i(116, 176), Vector2i(144, 194),
		Vector2i(60, 122), Vector2i(26, 150), Vector2i(64, 156), Vector2i(50, 184),
		Vector2i(54, 212),
	]
	map.segments = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5),
		Vector2i(5, 6), Vector2i(6, 7), Vector2i(4, 8), Vector2i(8, 9), Vector2i(9, 10),
		Vector2i(10, 11), Vector2i(11, 12),
	]
	map.sizes = [
		Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL,
		Star.Size.BIG, Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL,
		Star.Size.MEDIUM, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL,
		Star.Size.SMALL,
	]
	map.starting_lit = [9]
	map.painting = LEO_FIGURE
	return map


## Leo, stage 1: the Tail. It teaches the heat alone (its intro shows it), and nothing burns: over the whole stage,
## stars grow a size each launch, and a big one stays big. The tail runs from the haunch (lit,
## upper right) down to the left and curls up at its tuft (Denebola, big): stars saved by the tuft
## ripen into the big ones it needs. Five to light. Strings are 28-33 px.
static func leo_tail() -> StarMap:
	var map := StarMap.new()
	map.id = "leo_tail"
	map.title = "TAIL"
	map.landmarks = [Vector2i(150, 110), Vector2i(126, 126), Vector2i(100, 146), Vector2i(74, 160), Vector2i(48, 172), Vector2i(30, 150)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG]
	map.starting_lit = [0]
	map.painting = LEO_PART % "tail"
	map.heat_change = 1
	return map


## Leo, stage 2: the Haunch. Burning arrives: a big star that grows again burns out. From the back
## (lit, upper right) the leg runs through Chertan and the thigh (big) down to the knee, the hock
## and the paw; the belly branches right from Chertan. Six to light. Strings are 30-36 px.
static func leo_haunch() -> StarMap:
	var map := StarMap.new()
	map.id = "leo_haunch"
	map.title = "HAUNCH"
	map.landmarks = [Vector2i(146, 104), Vector2i(120, 124), Vector2i(96, 146), Vector2i(80, 174), Vector2i(92, 202), Vector2i(68, 222), Vector2i(144, 150)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(1, 6)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = LEO_PART % "haunch"
	map.heat_change = 1
	map.heat_burns = true
	return map


## Leo, stage 3: the Heart. The cold arrives (its intro shows it): each launch every loose star shrinks a size (big to
## medium to small), and a small one fades, lost for nothing. From the mane (lit, upper right) the
## chest runs down to Regulus (big) in the middle, then the fore leg down to the paw (omicron), the
## breast branching left. A big for Regulus has one launch before it shrinks; the small paw is fed
## by stars the cold wears down. Five to light. Strings are 30-35 px.
static func leo_heart() -> StarMap:
	var map := StarMap.new()
	map.id = "leo_heart"
	map.title = "HEART"
	map.landmarks = [Vector2i(146, 100), Vector2i(124, 124), Vector2i(104, 150), Vector2i(118, 180), Vector2i(142, 204), Vector2i(76, 166)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.painting = LEO_PART % "heart"
	map.heat_change = -1
	map.heat_burns = true
	return map


## Leo, stage 4: the Mane. Day and night: heat and cold take turns, swapping after every launch,
## starting with the heat. By day stars grow and a big one burns out; by night they shrink and a
## small one fades. The mane curls as the Sickle does: up from the heart (lit, bottom) through
## Algieba (big) and over to zeta and the brow at the right, a tuft branching left from Algieba.
## Six to light. Strings are 27-35 px.
static func leo_mane() -> StarMap:
	var map := StarMap.new()
	map.id = "leo_mane"
	map.title = "MANE"
	map.landmarks = [Vector2i(110, 224), Vector2i(90, 200), Vector2i(84, 170), Vector2i(100, 142), Vector2i(126, 128), Vector2i(150, 140), Vector2i(56, 150)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(2, 6)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = LEO_PART % "mane"
	map.heat_change = 1
	map.heat_burns = true
	map.heat_turns = true
	return map


## Leo, stage 5: the Head. The heat turns on the lion itself: each launch the constellation stars
## still to light grow a size too, and a big one burns back to small (it can't be lost), while the
## loose stars grow and burn out as on the Haunch. A pair saved for one may stop matching it. And the
## lion breathes, as on the final: every successful link stokes the heat too (#149: a rehearsal of the
## final's rule, so careless hoarding loses before it; spatial bots, launch-first 99.3% -> 72.3%,
## linking at once 99.3%, reading the heat 100%). From the mane
## (lit, left) the brow climbs to the crown (mu), then the face (epsilon) runs down to the mouth
## (lambda) at the right, the jaw branching below the face. Five to light. Strings are 31-35 px.
static func leo_head() -> StarMap:
	var map := StarMap.new()
	map.id = "leo_head"
	map.title = "HEAD"
	map.landmarks = [Vector2i(40, 150), Vector2i(64, 124), Vector2i(94, 108), Vector2i(124, 118), Vector2i(146, 144), Vector2i(112, 148)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(3, 5)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG]
	map.starting_lit = [0]
	map.painting = LEO_PART % "head"
	map.heat_change = 1
	map.heat_burns = true
	map.heat_landmarks = true
	map.heat_on_links = true
	return map


## Leo's final, stage 6: the whole Leo (the chart's figure, the tail tuft lit: twelve to light), and
## the lion breathes: the heat acts after every launch and after every successful link. Loose stars
## grow and a big one burns out; the lion's own stars grow and a big one burns back to small. So
## the order of the links matters: link the stars about to burn first (spatial bots: linking at once
## 79%, linking the stars about to burn first 100%, launching every pack first 38%). It arrives with
## its title card: LEO, THE LION OF SUMMER.
static func leo_final() -> StarMap:
	var map: StarMap = leo()
	map.id = "leo_final"
	map.heat_change = 1
	map.heat_burns = true
	map.heat_landmarks = true
	map.heat_on_links = true
	map.arrival_epithet = "THE LION OF SUMMER"
	return map


## Chapter 4: Virgo, the maiden of the harvest, holding the ear of wheat (Spica). 13 stars at least
## 24 px apart, east to the left: the head (Zavijava, eta) at the right, Porrima at the waist, the
## arm up through delta to Vindemiatrix, the hand down through theta to Spica, the robe (zeta, tau,
## 109) to the left and the feet (iota, mu, kappa) below it. Sizes follow brightness (Vindemiatrix
## drawn big). The head starts lit.
static func virgo() -> StarMap:
	var map := StarMap.new()
	map.id = "virgo"
	map.title = "VIRGO"
	map.landmarks = [
		Vector2i(162, 136), Vector2i(140, 152), Vector2i(116, 160), Vector2i(106, 132),
		Vector2i(98, 96), Vector2i(100, 186), Vector2i(86, 216), Vector2i(78, 150),
		Vector2i(56, 134), Vector2i(24, 126), Vector2i(50, 178), Vector2i(22, 172),
		Vector2i(48, 206),
	]
	map.segments = [
		Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5),
		Vector2i(5, 6), Vector2i(3, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(7, 10),
		Vector2i(10, 11), Vector2i(10, 12),
	]
	map.sizes = [
		Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL,
		Star.Size.BIG, Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM,
		Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL,
		Star.Size.SMALL,
	]
	map.starting_lit = [0]
	map.painting = VIRGO_FIGURE
	return map


## Virgo, stage 1: the Head. The scythe alone (its intro shows it): every few launches the harvest
## reaps every loose star still standing, for nothing (the stars that launch brought stand). Nothing
## else changes: link before the scythe comes. From the neck (lit, lower left) the face climbs to the
## brow, the veil falling right from it. Five to light. Strings are 30-33 px.
static func virgo_head() -> StarMap:
	var map := StarMap.new()
	map.id = "virgo_head"
	map.title = "HEAD"
	map.landmarks = [Vector2i(58, 206), Vector2i(84, 188), Vector2i(108, 168), Vector2i(122, 140), Vector2i(116, 108), Vector2i(148, 126)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(3, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG]
	map.starting_lit = [0]
	map.painting = VIRGO_PART % "head"
	map.harvest = true
	return map


## Virgo, stage 2: the Wing. Bound sheaves arrive (its intro shows a far star put out): at each harvest, a constellation star lit since
## the last one goes dark again unless lit strings join it to the figure lit before. From the
## shoulder (lit, bottom) the arm reaches up and left to Vindemiatrix (big, the far hand) and the
## wing sweeps up and right: light out from the shoulder, or lose the far stars to the scythe. Six
## to light. Strings are 31-33 px.
static func virgo_wing() -> StarMap:
	var map := StarMap.new()
	map.id = "virgo_wing"
	map.title = "WING"
	map.landmarks = [Vector2i(96, 206), Vector2i(72, 184), Vector2i(54, 156), Vector2i(46, 124), Vector2i(120, 184), Vector2i(142, 158), Vector2i(150, 126)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(0, 4), Vector2i(4, 5), Vector2i(5, 6)]
	map.sizes = [Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = VIRGO_PART % "wing"
	map.harvest = true
	map.harvest_binds = true
	return map


## Virgo, stage 3: the Robe. A quicker scythe (a 2-launch clock) on a figure that branches: from the
## waist (lit, top) the robe falls three ways, the near folds big, the hems small and far. Seven to
## light. Strings are 32-36 px.
static func virgo_robe() -> StarMap:
	var map := StarMap.new()
	map.id = "virgo_robe"
	map.title = "ROBE"
	map.landmarks = [
		Vector2i(90, 100), Vector2i(68, 124), Vector2i(50, 152), Vector2i(90, 136),
		Vector2i(90, 168), Vector2i(90, 200), Vector2i(112, 124), Vector2i(130, 152),
	]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(0, 6), Vector2i(6, 7)]
	map.sizes = [Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = VIRGO_PART % "robe"
	map.intros = false
	map.harvest = true
	map.harvest_binds = true
	return map


## Virgo, stage 4: the Feet. Tied at once (its intro shows a far star put out): after every launch,
## not only at the harvest, a lit star not joined to the figure goes dark. From the hip (lit, top) the
## legs part, each ending in a foot that forks into toe and heel. Eight to light. Strings are 31-34 px.
static func virgo_feet() -> StarMap:
	var map := StarMap.new()
	map.id = "virgo_feet"
	map.title = "FEET"
	map.landmarks = [
		Vector2i(90, 104), Vector2i(66, 128), Vector2i(52, 158), Vector2i(30, 180), Vector2i(64, 188),
		Vector2i(114, 128), Vector2i(128, 158), Vector2i(150, 180), Vector2i(116, 188),
	]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(0, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(6, 8)]
	map.sizes = [Star.Size.MEDIUM, Star.Size.BIG, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = VIRGO_PART % "feet"
	map.harvest = true
	map.harvest_binds = true
	map.harvest_ties = true
	return map


## Virgo, stage 5: the Wheat, the ear of wheat in her hand (Spica). The quickening: after each
## harvest the clock is a launch shorter (3, then 2, then every launch), and the bound sheaves hold.
## From the stalk's foot (lit, bottom) the stalk climbs to Spica (big) at the top, a grain branching
## off each joint by turns. Seven to light. Strings are 27-32 px.
static func virgo_wheat() -> StarMap:
	var map := StarMap.new()
	map.id = "virgo_wheat"
	map.title = "WHEAT"
	map.landmarks = [
		Vector2i(90, 222), Vector2i(90, 190), Vector2i(90, 158), Vector2i(90, 126), Vector2i(90, 96),
		Vector2i(66, 178), Vector2i(114, 146), Vector2i(66, 114),
	]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
	map.sizes = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL]
	map.starting_lit = [0]
	map.painting = VIRGO_PART % "wheat"
	map.harvest = true
	map.harvest_binds = true
	map.harvest_quickens = true
	return map


## Virgo's final, stage 6: the whole Virgo (the chart's figure, the head lit: twelve to light),
## under the scythe, tied at once: after every launch a lit star not joined to the figure goes dark
## (spatial bots: careless linking 50%, lighting next to the figure first 81%, hoarding 0%). It
## arrives with its title card: VIRGO, MAIDEN OF THE HARVEST.
static func virgo_final() -> StarMap:
	var map: StarMap = virgo()
	map.id = "virgo_final"
	# Its arrival is its intro: the binding was shown on the Wing and the Feet.
	map.intros = false
	map.harvest = true
	map.harvest_binds = true
	map.harvest_ties = true
	map.arrival_epithet = "MAIDEN OF THE HARVEST"
	return map


## The map for `id`, the full Scorpio for anything unknown.
static func by_id(p_id: String) -> StarMap:
	match p_id:
		"stinger":
			return stinger()
		"tail":
			return tail()
		"body":
			return body()
		"heart":
			return heart()
		"claws":
			return claws()
		"final":
			return final()
		"aquarius":
			return aquarius()
		"aquarius_hand":
			return aquarius_hand()
		"aquarius_body":
			return aquarius_body()
		"aquarius_legs":
			return aquarius_legs()
		"aquarius_stream":
			return aquarius_stream()
		"aquarius_jar":
			return aquarius_jar()
		"aquarius_final":
			return aquarius_final()
		"leo":
			return leo()
		"leo_tail":
			return leo_tail()
		"leo_haunch":
			return leo_haunch()
		"leo_heart":
			return leo_heart()
		"leo_mane":
			return leo_mane()
		"leo_head":
			return leo_head()
		"leo_final":
			return leo_final()
		"virgo":
			return virgo()
		"virgo_head":
			return virgo_head()
		"virgo_wing":
			return virgo_wing()
		"virgo_robe":
			return virgo_robe()
		"virgo_feet":
			return virgo_feet()
		"virgo_wheat":
			return virgo_wheat()
		"virgo_final":
			return virgo_final()
	return scorpio()


func count() -> int:
	return landmarks.size()


func segment_count() -> int:
	return segments.size()


## The landmarks string `segment` joins, as indices.
func segment_landmarks(segment: int) -> Array[int]:
	return [segments[segment].x, segments[segment].y]


## Where string `segment`'s two landmarks sit (home layout).
func segment_ends(segment: int) -> Array[Vector2i]:
	return [landmarks[segments[segment].x], landmarks[segments[segment].y]]


## The landmarks a string joins to landmark `index`.
func neighbours(index: int) -> Array[int]:
	var found: Array[int] = []
	for pair: Vector2i in segments:
		if pair.x == index:
			found.append(pair.y)
		elif pair.y == index:
			found.append(pair.x)
	return found


## The strings that end at landmark `index`, in order.
func segments_of(index: int) -> Array[int]:
	var found: Array[int] = []
	for segment: int in segments.size():
		if segments[segment].x == index or segments[segment].y == index:
			found.append(segment)
	return found


## The landmarks from `from` to `to` along the strings, both ends included (a tree: one way).
func path(from: int, to: int) -> Array[int]:
	var came_from: Dictionary = {from: -1}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		if at == to:
			break
		for n: int in neighbours(at):
			if not came_from.has(n):
				came_from[n] = at
				queue.append(n)
	var route: Array[int] = []
	if not came_from.has(to):
		return route
	var step: int = to
	while step != -1:
		route.push_front(step)
		step = came_from[step]
	return route
