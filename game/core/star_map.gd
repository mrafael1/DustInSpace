class_name StarMap
extends RefCounted
## A constellation map's layout (#62): the landmark stars a stage asks the player to light, the
## strings joining them, their sizes, which start lit, and how its finished drawing looks. The
## full Scorpio is one map (Scorpio's constants); each part stage of the chapter has its own
## smaller "false constellation" shaped like that part (the Stinger first). Layout, not balance.
## Positions are on the 180x320 grid in Scorpio.HOME_SKY; a taller sky shifts them (Scorpio.shift).

## How the finished drawing is traced: the whole scorpion, or only a stinger (tail bulbs and a
## hooked sting), or a tail (a row of bulbs), or a body (plated sides and legs), or a heart (a heart
## round Antares, with forked vessels).
enum Drawing { SCORPION, STINGER, TAIL, BODY, HEART }

var id: String = ""
## Shown on the end screen: "<NAME> COMPLETE".
var title: String = ""
var landmarks: Array[Vector2i] = []
## Pairs of landmark indices; they form a tree.
var segments: Array[Vector2i] = []
## Star.Size per landmark.
var sizes: Array[int] = []
var starting_lit: Array[int] = []
var drawing: Drawing = Drawing.SCORPION
## Orion (#64) hunts this stage: he marks a loose star; the next link saves it or has it shot. With
## a volley too, both threats run (the Claws are planned to bring every one).
var orion: bool = false
## Orion looses a volley (#70) every few links on this stage: the balance.json block that tunes it
## (Balance.VOLLEY_BLOCKS), or "" for none.
var volley: String = ""
## Orion marks a hunting area (#71) here: each launch, once its pack bursts, his arrow strikes it
## and destroys the loose stars inside, then he marks a new one.
var hunt: bool = false


## The full Scorpio (#61): every star of Scorpius's figure.
static func scorpio() -> StarMap:
	var map := StarMap.new()
	map.id = "scorpio"
	map.title = "SCORPIO"
	map.landmarks = Scorpio.LANDMARKS
	map.segments = Scorpio.SEGMENTS
	map.sizes = Scorpio.SIZES
	map.starting_lit = Scorpio.STARTING_LIT
	map.drawing = Drawing.SCORPION
	return map


## The Stinger, the chapter's first stage: a false constellation of six stars shaped like the
## scorpion's stinger. The tail's last joints run along the bottom of the sky and rise to the
## telson (big), then the sting hooks back up and left. The first joint starts lit, so five are
## left to light (tools/balance/sim.py: about 3.8 packs). Strings are 30-33 px.
static func stinger() -> StarMap:
	var map := StarMap.new()
	map.id = "stinger"
	map.title = "STINGER"
	map.landmarks = [Vector2i(36, 224), Vector2i(66, 236), Vector2i(98, 232), Vector2i(124, 212), Vector2i(138, 184), Vector2i(126, 156)]
	map.segments = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 5)]
	map.sizes = [Star.Size.SMALL, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG, Star.Size.MEDIUM]
	map.starting_lit = [0]
	map.drawing = Drawing.STINGER
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
	map.drawing = Drawing.TAIL
	map.orion = true
	return map


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
	map.drawing = Drawing.BODY
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
	map.drawing = Drawing.HEART
	map.hunt = true
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
