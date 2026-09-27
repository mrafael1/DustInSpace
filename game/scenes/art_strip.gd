class_name ArtStrip
extends RefCounted
## One sprite strip from assets/art/ (built by tools/art/): a horizontal PNG of same-size frames
## and its JSON sidecar giving the frame size, the frame names, and the origin, the pixel that
## sits on the node's position. Views draw frames with draw() at whole-pixel offsets, never
## scaled; pixels() gives a frame's pixels for tests and for code that needs the shape.
## Strips are loaded once and shared.

const ART_DIR := "res://assets/art/"

var texture: Texture2D
var frame_size: Vector2i
var origin: Vector2i
var frames: Array[String] = []

var _image: Image

static var _loaded: Dictionary = {}


## The strip `name` (e.g. "pack_blue"), loaded once.
static func named(name: String) -> ArtStrip:
	if not _loaded.has(name):
		var strip := ArtStrip.new()
		strip.texture = load(ART_DIR + name + ".png")
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ART_DIR + name + ".json"))
		strip.frame_size = Vector2i(int(data["frame_size"][0]), int(data["frame_size"][1]))
		strip.origin = Vector2i(int(data["origin"][0]), int(data["origin"][1]))
		for frame: String in data["frames"]:
			strip.frames.append(frame)
		if not strip.fits_texture():
			push_error("%s%s.png is %s but its sidecar lists %d frames of %s: re-import the art (open the editor, or godot --headless --path . --import)"
				% [ART_DIR, name, strip.texture.get_size(), strip.frames.size(), strip.frame_size])
		_loaded[name] = strip
	return _loaded[name]


## Whether the texture holds every frame the sidecar lists. A stale import (a PNG that grew but
## wasn't re-imported) doesn't, and its missing frames would draw nothing.
func fits_texture() -> bool:
	return texture != null and texture.get_size() == Vector2(frame_size.x * frames.size(), frame_size.y)


func has_frame(frame: String) -> bool:
	return frames.has(frame)


## Draws `frame` on `canvas` with its origin at `at`.
func draw(canvas: CanvasItem, frame: String, at: Vector2i = Vector2i.ZERO) -> void:
	var i: int = frames.find(frame)
	assert(i >= 0, "no frame %s" % frame)
	canvas.draw_texture_rect_region(texture, Rect2(Vector2(at - origin), Vector2(frame_size)),
		Rect2(Vector2(i * frame_size.x, 0), Vector2(frame_size)))


## The frame's opaque pixels, as offsets from its origin.
func pixels(frame: String) -> Dictionary[Vector2i, Color]:
	if _image == null:
		_image = texture.get_image()
	var dots: Dictionary[Vector2i, Color] = {}
	var i: int = frames.find(frame)
	if i < 0:
		return dots
	for y: int in frame_size.y:
		for x: int in frame_size.x:
			var c: Color = _image.get_pixel(i * frame_size.x + x, y)
			if c.a > 0.0:
				dots[Vector2i(x, y) - origin] = c
	return dots
