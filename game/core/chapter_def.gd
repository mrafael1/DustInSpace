class_name ChapterDef
extends RefCounted
## What makes a chapter itself: its constellation, its five part stages and final, where they sit
## on its chart and how it opens. Every chapter has Chapter.FINAL parts and then its final. Pure
## data; Chapter keeps the progress through it, and the chart draws it.

var id: String = ""
var title: String = ""
## Shown under the title: CHAPTER <number>.
var number: int = 0
## The stages, travelled in order. `stars`: the chart stars (figure landmark indices) the stage
## owns, the first one its point on the chart; `map`: its StarMap id, or "" while it isn't built.
## The last is the final (its stars empty: it's the whole figure).
var stages: Array[Dictionary] = []
## The whole constellation, as the chart draws it.
var figure: StarMap
## The final stage's crown point on the chart, above the figure.
var final_at: Vector2i
## A won part's piece of the painting: a path with %s for the part's "piece" name (else its map id).
var piece: String = ""
## The chapter whose final opens this one, or "" for open from the start.
var unlocked_by: String = ""


## Chapter 1: Scorpio (#62), travelled from the tail. Orion's chapter.
static func scorpio() -> ChapterDef:
	var def := ChapterDef.new()
	def.id = "scorpio"
	def.title = "SCORPIO"
	def.number = 1
	def.stages = [
		{"name": "STINGER", "map": "stinger", "stars": [13, 12, 11]},
		{"name": "TAIL", "map": "tail", "stars": [10, 9, 8]},
		{"name": "BODY", "map": "body", "stars": [7, 6, 5]},
		{"name": "HEART", "map": "heart", "stars": [4, 3]},
		{"name": "CLAWS", "map": "claws", "stars": [1, 0, 2]},
		{"name": "SCORPIO", "map": "final", "stars": []},
	]
	def.figure = StarMap.scorpio()
	def.final_at = Vector2i(90, 66)
	def.piece = "res://assets/art/scorpio_piece_%s.png"
	return def


## Chapter 2: Aquarius, the water carrier, whose stream drains the sky. Opens once Scorpio's final
## is won. Travelled as the water goes: from the hand through the head and body, down the legs to
## the stream, then up to the jar it pours from, the last part before the final: the whole
## Aquarius in a rotating box of drains.
static func aquarius() -> ChapterDef:
	var def := ChapterDef.new()
	def.id = "aquarius"
	def.title = "AQUARIUS"
	def.number = 2
	def.stages = [
		{"name": "HAND", "map": "aquarius_hand", "piece": "hand", "stars": [0, 1]},
		{"name": "BODY", "map": "aquarius_body", "piece": "body", "stars": [2, 7]},
		{"name": "LEGS", "map": "aquarius_legs", "piece": "legs", "stars": [8, 9, 10]},
		{"name": "STREAM", "map": "aquarius_stream", "piece": "stream", "stars": [11, 12, 13]},
		{"name": "JAR", "map": "aquarius_jar", "piece": "jar", "stars": [3, 4, 5, 6]},
		{"name": "AQUARIUS", "map": "aquarius_final", "stars": []},
	]
	def.figure = StarMap.aquarius()
	def.final_at = Vector2i(110, 72)
	def.piece = "res://assets/art/aquarius_piece_%s.png"
	def.unlocked_by = "scorpio"
	return def


## Every chapter, in campaign order.
static func all() -> Array[ChapterDef]:
	return [scorpio(), aquarius()]


## A won part's piece of the painting, or "" while it has no map (and so no piece).
func piece_path(stage: int) -> String:
	var map: String = stages[stage]["map"]
	return piece % stages[stage].get("piece", map) if map != "" else ""
