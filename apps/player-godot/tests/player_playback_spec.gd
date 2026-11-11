extends RefCounted


func run(scene_tree: SceneTree, packed_scene: PackedScene) -> Array[String]:
	var failures: Array[String] = []
	var player := packed_scene.instantiate()
	scene_tree.root.add_child(player)

	var start_action := player.get_node_or_null("StartAction") as Button
	var player_stage := player.get_node_or_null("PlayerStage") as Control
	var video_player := player.get_node_or_null("PlayerStage/VideoStage") as VideoStreamPlayer
	var subtitle_layer := player.get_node_or_null("PlayerStage/SubtitleLayer") as Control
	var subtitle_text := player.get_node_or_null("PlayerStage/SubtitleLayer/SubtitleText") as Label
	var ending_layer := player.get_node_or_null("PlayerStage/EndingLayer") as Control
	var ending_title := player.get_node_or_null("PlayerStage/EndingLayer/EndingContent/EndingTitle") as Label
	var error_layer := player.get_node_or_null("PlayerStage/ErrorLayer") as Control
	var error_text := player.get_node_or_null("PlayerStage/ErrorLayer/ErrorContent/ErrorText") as Label

	_expect_true(start_action != null, "Player exposes the primary start action", failures)
	_expect_true(player_stage != null, "Player exposes a cinematic playback stage", failures)
	_expect_true(video_player != null, "Player stage owns a VideoStreamPlayer adapter", failures)
	_expect_true(subtitle_layer != null, "Player stage owns a subtitle layer", failures)
	_expect_true(subtitle_text != null, "subtitle layer owns visible text", failures)
	_expect_true(ending_layer != null, "Player stage owns an ending layer", failures)
	_expect_true(ending_title != null, "ending layer owns a title", failures)
	_expect_true(error_layer != null, "Player stage owns an error layer", failures)
	_expect_true(error_text != null, "error layer owns visible details", failures)

	if (
		start_action == null
		or player_stage == null
		or video_player == null
		or subtitle_layer == null
		or subtitle_text == null
		or ending_layer == null
		or ending_title == null
		or error_layer == null
		or error_text == null
	):
		player.free()
		return failures

	start_action.pressed.emit()
	await scene_tree.process_frame
	_expect_true(player_stage.visible, "starting a StoryPack reveals the playback stage", failures)
	_expect_true(video_player.stream != null, "PlayClip loads the authored Ogg Theora stream", failures)
	_expect_true(video_player.is_playing(), "PlayClip starts media playback", failures)

	await scene_tree.create_timer(0.35).timeout
	_expect_true(subtitle_layer.visible, "subtitle cue becomes visible from media time", failures)
	_expect_equal(subtitle_text.text, "信号接通。", "subtitle cue renders authored Simplified Chinese", failures)

	await video_player.finished
	await scene_tree.process_frame
	_expect_true(ending_layer.visible, "ClipFinished StoryEffect reveals the ending", failures)
	_expect_equal(ending_title.text, "回声归零", "ending renders authored StoryPack content", failures)

	player.render_story_effects(
		[
			{
				"type": "ShowError",
				"code": "InvalidStoryPack",
				"message": "StoryPack validation failed.",
				"details": ["test detail"],
			},
		]
	)
	await scene_tree.process_frame
	_expect_true(error_layer.visible, "ShowError reveals the cinematic error surface", failures)
	_expect_true(
		"test detail" in error_text.text,
		"ShowError renders diagnostic details for the player",
		failures
	)

	_expect_true(player.theme != null, "playback screen inherits the CineWeave theme", failures)
	_expect_true(
		subtitle_layer.has_theme_stylebox(&"panel"),
		"subtitle layer uses a themed cinematic surface",
		failures
	)
	_expect_true(
		ending_layer.has_theme_stylebox(&"panel"),
		"ending layer uses a themed cinematic surface",
		failures
	)

	player.free()
	return failures


func _expect_equal(
	actual: Variant,
	expected: Variant,
	behavior: String,
	failures: Array[String]
) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [behavior, expected, actual])


func _expect_true(condition: bool, behavior: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(behavior)
