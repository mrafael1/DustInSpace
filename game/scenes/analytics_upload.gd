class_name AnalyticsUpload
extends RefCounted
## Sends playtest records to a remote endpoint (web playtest: friends play the web build, and the
## files PlaytestLog writes stay in their browser). The endpoint comes from CONFIG_PATH; empty (the
## default) sends nothing. It's meant for a Google Apps Script web app that appends each record to
## a sheet (tools/playtest/apps_script.gs).
## Each record is POSTed alone as plain-text JSON. On the web it goes by navigator.sendBeacon: no
## CORS preflight, nothing to wait for, and it still goes out as the tab closes. Elsewhere an
## HTTPRequest under the tree's root sends it, so it outlives the stage (Main) that logged it.
## Fire and forget: a record that fails is lost, and the game never waits on it.

const CONFIG_PATH: String = "res://game/config/analytics.json"


## The endpoint in `path`, or "" when there's none (no file, not JSON, or empty).
static func endpoint(path: String = CONFIG_PATH) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return ""
	return str((data as Dictionary).get("endpoint", "")).strip_edges()


## A Callable that sends one record (a JSON string) to `url`, or an empty Callable if `url` is "" or
## the game runs headless (the GUT runs and CI must never post).
static func sender(url: String) -> Callable:
	if url == "" or DisplayServer.get_name() == "headless":
		return Callable()
	if OS.has_feature("web"):
		return _beacon.bind(url)
	return _post.bind(url)


static func _beacon(body: String, url: String) -> void:
	JavaScriptBridge.eval("navigator.sendBeacon(%s, %s);" % [JSON.stringify(url), JSON.stringify(body)], true)


static func _post(body: String, url: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var request := HTTPRequest.new()
	request.request_completed.connect(func(..._args: Array) -> void: request.queue_free())
	# Deferred: a record logged as a stage leaves the tree can't add a child right then.
	tree.root.add_child.call_deferred(request)
	request.ready.connect(func() -> void:
		if request.request(url, ["Content-Type: text/plain;charset=utf-8"], HTTPClient.METHOD_POST, body) != OK:
			request.queue_free(), CONNECT_ONE_SHOT)
