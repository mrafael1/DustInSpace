extends GutTest


func test_a_line_joins_its_ends_pixel_by_pixel() -> void:
	var cases: Array[Array] = [
		[Vector2i(10, 10), Vector2i(20, 10)],
		[Vector2i(10, 10), Vector2i(10, 3)],
		[Vector2i(0, 0), Vector2i(7, 3)],
		[Vector2i(30, 150), Vector2i(12, 171)],
		[Vector2i(5, 5), Vector2i(5, 5)],
	]
	for ends: Array in cases:
		var pixels: Array[Vector2i] = LinkLayer.line_pixels(ends[0], ends[1])
		assert_eq(pixels[0], ends[0])
		assert_eq(pixels[-1], ends[1])
		var span: Vector2i = (ends[1] - ends[0]).abs()
		assert_eq(pixels.size(), maxi(span.x, span.y) + 1, "one pixel per step along the long axis")
		for i: int in range(1, pixels.size()):
			var step: Vector2i = (pixels[i] - pixels[i - 1]).abs()
			assert_true(step.x <= 1 and step.y <= 1, "no gaps in %s" % [ends])


func test_a_path_counts_each_joint_once() -> void:
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 0), Vector2i(4, 4)]
	var pixels: Array[Vector2i] = LinkLayer.path_pixels(points)
	assert_eq(pixels.size(), 9)
	assert_eq(pixels.count(Vector2i(4, 0)), 1)
	assert_eq(LinkLayer.path_pixels([Vector2i(3, 3)] as Array[Vector2i]), [] as Array[Vector2i], "one point is no line")


func test_rejected_and_collected_lines_fade_on_their_own() -> void:
	var layer: LinkLayer = LinkLayer.new()
	add_child_autofree(layer)
	layer.flash_rejected([Vector2i(30, 150), Vector2i(90, 150)] as Array[Vector2i])
	assert_true(layer.is_flashing())
	layer.advance(LinkLayer.REJECT_TIME + 0.01)
	assert_false(layer.is_flashing())
	layer.flash_collected([Vector2i(30, 150), Vector2i(90, 150), Vector2i(60, 120)] as Array[Vector2i])
	layer.advance(LinkLayer.COLLECT_TIME + 0.01)
	assert_false(layer.is_flashing())


func test_a_single_point_has_no_feedback_line() -> void:
	var layer: LinkLayer = LinkLayer.new()
	add_child_autofree(layer)
	layer.flash_rejected([Vector2i(30, 150)] as Array[Vector2i])
	assert_false(layer.is_flashing())
