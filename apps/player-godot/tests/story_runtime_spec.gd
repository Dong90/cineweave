extends RefCounted

const RUNTIME_PATH := "res://scripts/story_runtime.gd"
const VALID_MEDIA_PATH := "res://content/zero-echo/media/platform-2357.ogv"


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
				"media_path": VALID_MEDIA_PATH,
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
			"media_path": VALID_MEDIA_PATH,
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
	var choice_story_pack := {
		"format_version": "0.1",
		"story_id": "choice-seam",
		"title": "Choice Seam",
		"entry_node_id": "intro",
		"nodes": [
			{
				"id": "intro",
				"type": "clip",
				"media_path": VALID_MEDIA_PATH,
				"subtitles": subtitles,
				"next_node_id": "platform-choice",
			},
			{
				"id": "platform-choice",
				"type": "choice",
				"options": [
					{
						"id": "board-last-train",
						"text": "登上末班车",
						"target_node_id": "loop-ending",
					},
					{
						"id": "leave-platform",
						"text": "离开站台",
						"target_node_id": "survivor-ending",
					},
				],
			},
			{
				"id": "loop-ending",
				"type": "end",
				"title": "循环仍在继续",
				"text": "你再次回到 23:57。",
			},
			{
				"id": "survivor-ending",
				"type": "end",
				"title": "幸存者",
				"text": "00:01，这一次你做对了。",
			},
		],
	}
	var expected_choices := [
		{
			"type": "PresentChoices",
			"node_id": "platform-choice",
			"choices": [
				{"option_id": "board-last-train", "text": "登上末班车"},
				{"option_id": "leave-platform", "text": "离开站台"},
			],
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

	var choice_runtime: RefCounted = runtime_script.new()
	_expect_equal(
		choice_runtime.open(choice_story_pack),
		[],
		"a valid choice StoryPack opens without errors",
		failures
	)
	choice_runtime.start("intro")
	_expect_equal(
		choice_runtime.dispatch({"type": "ClipFinished"}),
		expected_choices,
		"ClipFinished reaches choice and emits presentation data without branch targets",
		failures
	)
	_expect_equal(
		choice_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "board-last-train"}
		),
		[
			{
				"type": "ShowEnding",
				"node_id": "loop-ending",
				"title": "循环仍在继续",
				"text": "你再次回到 23:57。",
			},
		],
		"the board-last-train PlayerAction reaches the loop ending",
		failures
	)
	var survivor_runtime: RefCounted = runtime_script.new()
	survivor_runtime.open(choice_story_pack)
	survivor_runtime.start("intro")
	survivor_runtime.dispatch({"type": "ClipFinished"})
	_expect_equal(
		survivor_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "leave-platform"}
		),
		[
			{
				"type": "ShowEnding",
				"node_id": "survivor-ending",
				"title": "幸存者",
				"text": "00:01，这一次你做对了。",
			},
		],
		"the leave-platform PlayerAction reaches the survivor ending",
		failures
	)
	var guarded_choice_runtime: RefCounted = runtime_script.new()
	guarded_choice_runtime.open(choice_story_pack)
	guarded_choice_runtime.start("intro")
	guarded_choice_runtime.dispatch({"type": "ClipFinished"})
	_expect_equal(
		guarded_choice_runtime.dispatch({"type": "ClipFinished"}),
		[],
		"a choice node advances only through ChoiceSelected",
		failures
	)
	_expect_equal(
		guarded_choice_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "not-an-authored-option"}
		),
		[],
		"an unknown choice is ignored without advancing StoryRuntime",
		failures
	)
	_expect_equal(
		guarded_choice_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "leave-platform"}
		),
		[
			{
				"type": "ShowEnding",
				"node_id": "survivor-ending",
				"title": "幸存者",
				"text": "00:01，这一次你做对了。",
			},
		],
		"an ignored choice leaves the authored choice available",
		failures
	)
	_expect_equal(
		guarded_choice_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "board-last-train"}
		),
		[],
		"a second choice is ignored after the first authored branch wins",
		failures
	)
	var deterministic_runtime: RefCounted = runtime_script.new()
	deterministic_runtime.open(choice_story_pack)
	_expect_equal(
		deterministic_runtime.start("intro"),
		choice_runtime.start("intro"),
		"the same StoryPack and start action produce identical StoryEffects",
		failures
	)
	_expect_equal(
		deterministic_runtime.dispatch({"type": "ClipFinished"}),
		choice_runtime.dispatch({"type": "ClipFinished"}),
		"the same StoryPack and PlayerAction produce identical choices",
		failures
	)
	_expect_equal(
		deterministic_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "board-last-train"}
		),
		choice_runtime.dispatch(
			{"type": "ChoiceSelected", "option_id": "board-last-train"}
		),
		"the same complete PlayerAction sequence produces an identical ending",
		failures
	)
	var wrong_option_count_pack := choice_story_pack.duplicate(true)
	wrong_option_count_pack["nodes"][1]["options"].pop_back()
	_expect_open_error(
		runtime_script,
		wrong_option_count_pack,
		"choice options must contain exactly two options",
		"V0.1 choice requires exactly two player options",
		failures
	)
	var empty_options_pack := choice_story_pack.duplicate(true)
	empty_options_pack["nodes"][1]["options"] = []
	_expect_open_error(
		runtime_script,
		empty_options_pack,
		"choice options must contain exactly two options",
		"empty choice options are rejected before startup",
		failures
	)
	var non_object_option_pack := choice_story_pack.duplicate(true)
	non_object_option_pack["nodes"][1]["options"][0] = "not-an-option"
	_expect_open_error(
		runtime_script,
		non_object_option_pack,
		"every choice option must be an object",
		"every choice option is structurally valid before startup",
		failures
	)
	var missing_option_id_pack := choice_story_pack.duplicate(true)
	missing_option_id_pack["nodes"][1]["options"][0].erase("id")
	_expect_open_error(
		runtime_script,
		missing_option_id_pack,
		"choice option id is required",
		"every choice option has a stable identity before startup",
		failures
	)
	var duplicate_option_id_pack := choice_story_pack.duplicate(true)
	duplicate_option_id_pack["nodes"][1]["options"][1]["id"] = "board-last-train"
	_expect_open_error(
		runtime_script,
		duplicate_option_id_pack,
		"choice option ids must be unique within the StoryNode",
		"choice option identities are unique before startup",
		failures
	)
	var missing_option_text_pack := choice_story_pack.duplicate(true)
	missing_option_text_pack["nodes"][1]["options"][0]["text"] = ""
	_expect_open_error(
		runtime_script,
		missing_option_text_pack,
		"choice option text is required",
		"every choice option has player-facing text before startup",
		failures
	)
	var missing_option_target_pack := choice_story_pack.duplicate(true)
	missing_option_target_pack["nodes"][1]["options"][0]["target_node_id"] = "missing"
	_expect_open_error(
		runtime_script,
		missing_option_target_pack,
		"choice option target_node_id must reference an existing StoryNode",
		"every choice option target resolves before startup",
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
	var missing_title_pack := story_pack.duplicate(true)
	missing_title_pack.erase("title")
	_expect_open_error(
		runtime_script,
		missing_title_pack,
		"title is required",
		"StoryPack title is required before startup",
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
	_expect_media_error_context(
		runtime_script,
		missing_media_pack,
		"intro",
		"missing-video.ogv",
		"missing media errors identify the StoryNode and resolved path",
		failures
	)
	var unplayable_media_pack := story_pack.duplicate(true)
	unplayable_media_pack["nodes"][0]["media_path"] = "res://project.godot"
	_expect_open_error(
		runtime_script,
		unplayable_media_pack,
		"clip media_path must reference a playable VideoStream",
		"clip media references must be playable before startup",
		failures
	)
	_expect_media_error_context(
		runtime_script,
		unplayable_media_pack,
		"intro",
		"project.godot",
		"unplayable media errors identify the StoryNode and resolved path",
		failures
	)
	var non_object_node_pack := story_pack.duplicate(true)
	non_object_node_pack["nodes"].append("not-a-StoryNode")
	_expect_open_error(
		runtime_script,
		non_object_node_pack,
		"every StoryNode must be an object",
		"every StoryNode is structurally valid before startup",
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
	unsupported_node_pack["nodes"][1]["type"] = "jump"
	_expect_open_error(
		runtime_script,
		unsupported_node_pack,
		"StoryNode type must be clip, choice, or end",
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
	var overlapping_subtitles_pack := story_pack.duplicate(true)
	overlapping_subtitles_pack["nodes"][0]["subtitles"] = [
		{
			"start_ms": 100,
			"end_ms": 900,
			"text": "First cue.",
		},
		{
			"start_ms": 500,
			"end_ms": 800,
			"text": "Overlapping cue.",
		},
	]
	_expect_open_error(
		runtime_script,
		overlapping_subtitles_pack,
		"subtitle cues must be ordered and non-overlapping",
		"overlapping subtitle cues are rejected before startup",
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


func _expect_media_error_context(
	runtime_script: Script,
	story_pack: Dictionary,
	expected_resource_id: String,
	expected_path_fragment: String,
	behavior: String,
	failures: Array[String]
) -> void:
	var runtime: RefCounted = runtime_script.new()
	var effects: Array = runtime.open(story_pack)
	if effects.size() != 1:
		failures.append("%s: expected one ShowError, got %s" % [behavior, effects])
		return
	var effect: Dictionary = effects[0]
	if (
		effect.get("resource_id") != expected_resource_id
		or not expected_path_fragment in str(effect.get("resolved_path", ""))
	):
		failures.append(
			"%s: expected resource %s and path containing %s, got %s" % [
				behavior, expected_resource_id, expected_path_fragment, effect
			]
		)
