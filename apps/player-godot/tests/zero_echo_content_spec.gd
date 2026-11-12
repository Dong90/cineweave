extends RefCounted

const STORY_PACK_PATH := "res://content/zero-echo/storypack.json"
const FONT_PATH := "res://assets/fonts/noto-sans-sc/NotoSansSC-Variable.ttf"
const THEME_PATH := "res://themes/cineweave_theme.tres"
const EXPECTED_CLIPS := {
	"platform-2357": {
		"path": "res://content/zero-echo/media/platform-2357.ogv",
		"duration_seconds": 50.0,
		"next": "future-warning",
	},
	"future-warning": {
		"path": "res://content/zero-echo/media/future-warning.ogv",
		"duration_seconds": 60.0,
		"next": "midnight-train-arrives",
	},
	"midnight-train-arrives": {
		"path": "res://content/zero-echo/media/midnight-train-arrives.ogv",
		"duration_seconds": 55.0,
		"next": "platform-decision",
	},
	"board-loop-reveal": {
		"path": "res://content/zero-echo/media/board-loop-reveal.ogv",
		"duration_seconds": 70.0,
		"next": "loop-ending",
	},
	"leave-to-0001": {
		"path": "res://content/zero-echo/media/leave-to-0001.ogv",
		"duration_seconds": 60.0,
		"next": "survivor-ending",
	},
}
const EXPECTED_KEY_CUES := {
	"platform-2357": [
		{"start_ms": 9000, "end_ms": 12500, "text": "站台时钟：23:57"},
	],
	"future-warning": [
		{"start_ms": 9000, "end_ms": 13500, "text": "未知号码：别上零点列车。"},
	],
	"midnight-train-arrives": [
		{"start_ms": 11500, "end_ms": 15500, "text": "零点列车即将进站。"},
	],
	"board-loop-reveal": [
		{"start_ms": 50000, "end_ms": 55500, "text": "警告发送者：循环中的你。"},
	],
	"leave-to-0001": [
		{"start_ms": 47000, "end_ms": 50000, "text": "00:01"},
		{"start_ms": 52000, "end_ms": 57500, "text": "未知号码：这一次，你做对了。"},
	],
}


func run(scene_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var story_pack := _read_story_pack()
	if story_pack.is_empty():
		failures.append("the bundled zero-echo PublishedStoryPack is readable")
		return failures

	_expect_equal(story_pack.get("story_id"), "zero-echo", "sample keeps its stable identity", failures)
	_expect_equal(story_pack.get("title"), "零点回声", "sample exposes its authored title", failures)
	_expect_equal(story_pack.get("entry_node_id"), "platform-2357", "sample starts at 23:57", failures)

	var nodes: Array = story_pack.get("nodes", [])
	_expect_equal(nodes.size(), 8, "sample contains five clips, one choice, and two endings", failures)
	var nodes_by_id: Dictionary = {}
	for node: Variant in nodes:
		if node is Dictionary:
			nodes_by_id[str(node.get("id", ""))] = node

	for node_id: String in EXPECTED_CLIPS:
		var expected: Dictionary = EXPECTED_CLIPS[node_id]
		var node: Dictionary = nodes_by_id.get(node_id, {})
		_expect_equal(node.get("type"), "clip", "%s is an authored clip" % node_id, failures)
		_expect_equal(node.get("media_path"), expected.path, "%s uses its formal media" % node_id, failures)
		_expect_equal(node.get("next_node_id"), expected.next, "%s advances through the authored graph" % node_id, failures)
		_validate_subtitles(node_id, node, int(expected.duration_seconds * 1000.0), failures)
		for expected_cue: Dictionary in EXPECTED_KEY_CUES.get(node_id, []):
			_expect_true(
				_has_exact_cue(node.get("subtitles", []), expected_cue),
				"%s keeps key cue '%s' at %s–%sms" % [
					node_id,
					expected_cue.text,
					expected_cue.start_ms,
					expected_cue.end_ms,
				],
				failures
			)
		await _validate_media(scene_tree, node_id, expected, failures)

	var choice: Dictionary = nodes_by_id.get("platform-decision", {})
	_expect_equal(choice.get("type"), "choice", "the platform decision is the sole choice", failures)
	_expect_equal(
		choice.get("options", []),
		[
			{
				"id": "board-last-train",
				"text": "登上末班车",
				"target_node_id": "board-loop-reveal",
			},
			{
				"id": "leave-platform",
				"text": "离开站台",
				"target_node_id": "leave-to-0001",
			},
		],
		"the choice preserves both confirmed V0.1 routes",
		failures
	)

	var loop_ending: Dictionary = nodes_by_id.get("loop-ending", {})
	_expect_equal(loop_ending.get("title"), "循环仍在继续", "boarding reaches the loop ending", failures)
	var survivor_ending: Dictionary = nodes_by_id.get("survivor-ending", {})
	_expect_equal(survivor_ending.get("title"), "幸存者", "leaving reaches the survivor ending", failures)

	var serialized := JSON.stringify(story_pack)
	for required_fragment: String in [
		"23:57",
		"零点列车",
		"循环中的你",
		"循环仍在继续",
		"00:01",
		"这一次，你做对了",
		"幸存者",
	]:
		_expect_true(
			required_fragment in serialized,
			"sample contains the confirmed narrative beat '%s'" % required_fragment,
			failures
		)

	_expect_between(50.0 + 60.0 + 55.0 + 70.0, 180.0, 300.0, "boarding route runs 3–5 minutes", failures)
	_expect_between(50.0 + 60.0 + 55.0 + 60.0, 180.0, 300.0, "leaving route runs 3–5 minutes", failures)

	_expect_true(FileAccess.file_exists(FONT_PATH), "Player bundles the approved Simplified Chinese font", failures)
	if FileAccess.file_exists(FONT_PATH):
		var theme := load(THEME_PATH) as Theme
		_expect_true(theme != null and theme.default_font != null, "Player theme uses the bundled Chinese font", failures)
	return failures


func _read_story_pack() -> Dictionary:
	var file := FileAccess.open(STORY_PACK_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _has_exact_cue(cues: Array, expected: Dictionary) -> bool:
	for cue: Variant in cues:
		if (
			cue is Dictionary
			and int(cue.get("start_ms", -1)) == int(expected.get("start_ms", -2))
			and int(cue.get("end_ms", -1)) == int(expected.get("end_ms", -2))
			and str(cue.get("text", "")) == str(expected.get("text", "missing"))
		):
			return true
	return false


func _validate_subtitles(
	node_id: String,
	node: Dictionary,
	duration_ms: int,
	failures: Array[String]
) -> void:
	var cues: Array = node.get("subtitles", [])
	_expect_true(not cues.is_empty(), "%s has Simplified Chinese subtitle cues" % node_id, failures)
	var previous_end := -1
	for cue: Variant in cues:
		if not (cue is Dictionary):
			failures.append("%s subtitle cues are objects" % node_id)
			continue
		var start_ms := int(cue.get("start_ms", -1))
		var end_ms := int(cue.get("end_ms", -1))
		var text := str(cue.get("text", ""))
		_expect_true(start_ms >= previous_end, "%s subtitle cues do not overlap" % node_id, failures)
		_expect_true(end_ms > start_ms and end_ms <= duration_ms, "%s subtitle cues stay inside media time" % node_id, failures)
		_expect_true(not text.is_empty(), "%s subtitle cues contain player-facing text" % node_id, failures)
		previous_end = end_ms


func _validate_media(
	scene_tree: SceneTree,
	node_id: String,
	expected: Dictionary,
	failures: Array[String]
) -> void:
	var media_path := str(expected.path)
	if not FileAccess.file_exists(media_path):
		failures.append("%s formal media exists at %s" % [node_id, media_path])
		return
	var stream := load(media_path) as VideoStream
	if stream == null:
		failures.append("%s formal media loads as VideoStream" % node_id)
		return
	var video_player := VideoStreamPlayer.new()
	scene_tree.root.add_child(video_player)
	video_player.stream = stream
	var actual_duration := video_player.get_stream_length()
	_expect_true(
		absf(actual_duration - float(expected.duration_seconds)) <= 0.75,
		"%s duration is %ss, got %ss" % [node_id, expected.duration_seconds, actual_duration],
		failures
	)
	video_player.play()
	await scene_tree.process_frame
	var initial_position := video_player.stream_position
	await scene_tree.create_timer(0.12).timeout
	_expect_true(video_player.is_playing(), "%s starts in official Godot" % node_id, failures)
	_expect_true(
		video_player.stream_position > initial_position,
		"%s advances through official Godot's Theora decoder" % node_id,
		failures
	)
	video_player.stop()
	video_player.free()


func _expect_equal(actual: Variant, expected: Variant, behavior: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [behavior, expected, actual])


func _expect_true(condition: bool, behavior: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(behavior)


func _expect_between(
	actual: float,
	minimum: float,
	maximum: float,
	behavior: String,
	failures: Array[String]
) -> void:
	if actual < minimum or actual > maximum:
		failures.append("%s: expected %s–%s seconds, got %s" % [behavior, minimum, maximum, actual])
