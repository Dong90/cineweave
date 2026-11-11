extends RefCounted

const RUNTIME_PATH := "res://scripts/story_runtime.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	var runtime_script := load(RUNTIME_PATH)
	if runtime_script == null:
		failures.append("StoryRuntime public seam exists at %s" % RUNTIME_PATH)
		return failures

	var subtitles := [
		{
			"start_ms": 100,
			"end_ms": 900,
			"text": "Signal acquired.",
		},
	]
	var story_pack := {
		"format_version": "0.1",
		"story_id": "runtime-seam",
		"title": "Runtime Seam",
		"entry_node_id": "intro",
		"nodes": [
			{
				"id": "intro",
				"type": "clip",
				"media_path": "res://project.godot",
				"subtitles": subtitles,
				"next_node_id": "ending",
			},
			{
				"id": "ending",
				"type": "end",
				"title": "Signal Lost",
				"text": "The relay goes quiet.",
			},
		],
	}
	var expected_start := [
		{
			"type": "PlayClip",
			"node_id": "intro",
			"media_path": "res://project.godot",
		},
		{
			"type": "ShowSubtitles",
			"node_id": "intro",
			"cues": subtitles,
		},
	]
	var expected_end := [
		{
			"type": "ShowEnding",
			"node_id": "ending",
			"title": "Signal Lost",
			"text": "The relay goes quiet.",
		},
	]

	var runtime: RefCounted = runtime_script.new()
	_expect_equal(runtime.open(story_pack), [], "valid StoryPack opens without errors", failures)
	var first_start: Array = runtime.start("intro")
	_expect_equal(
		first_start,
		expected_start,
		"starting a clip emits ordered PlayClip and ShowSubtitles effects",
		failures
	)
	var first_end: Array = runtime.dispatch({"type": "ClipFinished"})
	_expect_equal(
		first_end,
		expected_end,
		"ClipFinished advances through StoryRuntime to ShowEnding",
		failures
	)

	var repeated_runtime: RefCounted = runtime_script.new()
	repeated_runtime.open(story_pack)
	var repeated_start: Array = repeated_runtime.start("intro")
	var repeated_end: Array = repeated_runtime.dispatch({"type": "ClipFinished"})
	_expect_equal(
		[repeated_start, repeated_end],
		[first_start, first_end],
		"the same StoryPack and PlayerAction sequence emits the same StoryEffect sequence",
		failures
	)

	var missing_version_pack := story_pack.duplicate(true)
	missing_version_pack.erase("format_version")
	_expect_open_error(
		runtime_script,
		missing_version_pack,
		"format_version must equal 0.1",
		"StoryPack format_version is required before startup",
		failures
	)
	var missing_story_id_pack := story_pack.duplicate(true)
	missing_story_id_pack.erase("story_id")
	_expect_open_error(
		runtime_script,
		missing_story_id_pack,
		"story_id is required",
		"StoryPack identity is required before startup",
		failures
	)
	var missing_entry_pack := story_pack.duplicate(true)
	missing_entry_pack["entry_node_id"] = "missing"
	_expect_open_error(
		runtime_script,
		missing_entry_pack,
		"entry_node_id must reference an existing StoryNode",
		"StoryPack entry must resolve before startup",
		failures
	)
	var duplicate_node_pack := story_pack.duplicate(true)
	duplicate_node_pack["nodes"].append(duplicate_node_pack["nodes"][1].duplicate(true))
	_expect_open_error(
		runtime_script,
		duplicate_node_pack,
		"StoryNode ids must be unique",
		"StoryNode identity must be unique before startup",
		failures
	)
	var missing_target_pack := story_pack.duplicate(true)
	missing_target_pack["nodes"][0]["next_node_id"] = "missing"
	_expect_open_error(
		runtime_script,
		missing_target_pack,
		"clip next_node_id must reference an existing StoryNode",
		"clip targets must resolve before startup",
		failures
	)
	var missing_media_pack := story_pack.duplicate(true)
	missing_media_pack["nodes"][0]["media_path"] = "res://missing-video.ogv"
	_expect_open_error(
		runtime_script,
		missing_media_pack,
		"clip media_path must reference an existing file",
		"clip media references must exist before startup",
		failures
	)
	var missing_node_id_pack := story_pack.duplicate(true)
	missing_node_id_pack["nodes"][1].erase("id")
	_expect_open_error(
		runtime_script,
		missing_node_id_pack,
		"StoryNode id is required",
		"every StoryNode requires an identity before startup",
		failures
	)
	var unsupported_node_pack := story_pack.duplicate(true)
	unsupported_node_pack["nodes"][1]["type"] = "choice"
	_expect_open_error(
		runtime_script,
		unsupported_node_pack,
		"StoryNode type must be clip or end",
		"V0.1 runtime rejects unsupported StoryNode types before startup",
		failures
	)
	var missing_subtitles_pack := story_pack.duplicate(true)
	missing_subtitles_pack["nodes"][0]["subtitles"] = []
	_expect_open_error(
		runtime_script,
		missing_subtitles_pack,
		"clip subtitles must contain at least one cue",
		"clip subtitle data is required before startup",
		failures
	)
	var invalid_subtitle_cue_pack := story_pack.duplicate(true)
	invalid_subtitle_cue_pack["nodes"][0]["subtitles"][0]["text"] = ""
	_expect_open_error(
		runtime_script,
		invalid_subtitle_cue_pack,
		"subtitle cues require ordered start_ms, end_ms, and text",
		"subtitle cues are valid before startup",
		failures
	)
	var incomplete_end_pack := story_pack.duplicate(true)
	incomplete_end_pack["nodes"][1].erase("title")
	_expect_open_error(
		runtime_script,
		incomplete_end_pack,
		"end StoryNode requires title and text",
		"end presentation data is required before startup",
		failures
	)
	var missing_nodes_pack := story_pack.duplicate(true)
	missing_nodes_pack["nodes"] = []
	_expect_open_error(
		runtime_script,
		missing_nodes_pack,
		"nodes must contain at least one StoryNode",
		"StoryPack nodes are required before startup",
		failures
	)

	return failures


func _expect_equal(
	actual: Variant,
	expected: Variant,
	behavior: String,
	failures: Array[String]
) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [behavior, expected, actual])


func _expect_open_error(
	runtime_script: Script,
	story_pack: Dictionary,
	expected_detail: String,
	behavior: String,
	failures: Array[String]
) -> void:
	var runtime: RefCounted = runtime_script.new()
	var effects: Array = runtime.open(story_pack)
	if effects.size() != 1:
		failures.append("%s: expected one ShowError, got %s" % [behavior, effects])
		return
	var effect: Dictionary = effects[0]
	if effect.get("type") != "ShowError" or not effect.get("details", []).has(expected_detail):
		failures.append(
			"%s: expected ShowError detail '%s', got %s" % [behavior, expected_detail, effect]
		)
