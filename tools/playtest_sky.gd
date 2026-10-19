extends RefCounted
## The play sky the playtest bots run on (docs/wide_sky_design.md §6). Preload it:
## `const PlaytestSky := preload("res://tools/playtest_sky.gd")`.
## `--sky=WxH` is the visible area in game px (what fill_size shows: 640x360 for a 1080p window);
## the bots play on the sky Main would build there (ScreenZones.sky_margin and play_sky). Without
## it they play on the 9:16 sky, Scorpio.HOME_SKY, as before.

const PREFIX := "--sky="


## The sky for one `--sky=WxH` argument (the 9:16 sky when it doesn't parse).
static func parse_sky(argument: String) -> Rect2i:
	var size: PackedStringArray = argument.trim_prefix(PREFIX).split("x")
	if size.size() != 2 or not size[0].is_valid_int() or not size[1].is_valid_int():
		push_warning("--sky wants WxH in game px, e.g. --sky=640x360; playing on the 9:16 sky")
		return Scorpio.HOME_SKY
	var visible := Vector2(size[0].to_int(), size[1].to_int())
	var margin: Vector2i = ScreenZones.sky_margin(visible)
	return ScreenZones.play_sky(margin.y, margin.x)


## The sky from the command line's user args (the 9:16 sky without `--sky=`).
static func from_args() -> Rect2i:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(PREFIX):
			return parse_sky(argument)
	return Scorpio.HOME_SKY


## The results file name's sky part: "" on the 9:16 sky (the names stay as before), "-sky640x212"
## (the play sky's size) on any other.
static func suffix(sky: Rect2i) -> String:
	return "" if sky == Scorpio.HOME_SKY else "-sky%dx%d" % [sky.size.x, sky.size.y]


## The table line naming the sky.
static func label(sky: Rect2i) -> String:
	return "sky %dx%d at (%d, %d)" % [sky.size.x, sky.size.y, sky.position.x, sky.position.y]
