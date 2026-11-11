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
	var choice_layer := player.get_node_or_null("PlayerStage/ChoiceLayer") as Control
	var choice_one := player.get_node_or_null(
		"PlayerStage/ChoiceLayer/ChoiceMargin/ChoiceContent/ChoiceOne"
	) as Button
	var choice_two := player.get_node_or_null(
		"PlayerStage/ChoiceLayer/ChoiceMargin/ChoiceContent/ChoiceTwo"
	) as Button
	var ending_layer := player.get_node_or_null("PlayerStage/EndingLayer") as Control
	var ending_title := player.get_node_or_null("PlayerStage/EndingLayer/EndingContent/EndingTitle") as Label
	var error_layer := player.get_node_or_null("PlayerStage/ErrorLayer") as Control
	var error_text := player.get_node_or_null("PlayerStage/ErrorLayer/ErrorContent/ErrorText") as Label

	_expect_true(start_action != null, "Player exposes the primary start action", failures)
	_expect_true(player_stage != null, "Player exposes a cinematic playback stage", failures)
	_expect_true(video_player != null, "Player stage owns a VideoStreamPlayer adapter", failures)
	_expect_true(subtitle_layer != null, "Player stage owns a subtitle layer", failures)
	_expect_true(subtitle_text != null, "subtitle layer owns visible text", failures)
	_expect_true(choice_layer != null, "Player stage owns a cinematic choice layer", failures)
	_expect_true(choice_one != null, "choice layer owns the first authored option", failures)
	_expect_true(choice_two != null, "choice layer owns the second authored option", failures)
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
		or choice_layer == null
		or choice_one == null
		or choice_two == null
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
	_expect_true(not video_player.is_playing(), "choice presentation stops narrative time", failures)
	_expect_true(choice_layer.visible, "ClipFinished reveals the authored choice", failures)
	_expect_true(not ending_layer.visible, "choice presentation does not select a default ending", failures)
	_expect_equal(choice_one.text, "登上末班车", "first option renders authored text", failures)
	_expect_equal(choice_two.text, "离开站台", "second option renders authored text", failures)
	await scene_tree.create_timer(0.1).timeout
	_expect_true(not ending_layer.visible, "choice remains open without a countdown", failures)

	var choice_center := choice_one.get_global_rect().get_center()
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = choice_center
	mouse_motion.global_position = choice_center
	scene_tree.root.push_input(mouse_motion, true)
	await scene_tree.process_frame
	var mouse_down := InputEventMouseButton.new()
	mouse_down.position = choice_center
	mouse_down.global_position = choice_center
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	scene_tree.root.push_input(mouse_down, true)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.position = choice_center
	mouse_up.global_position = choice_center
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	scene_tree.root.push_input(mouse_up, true)
	await scene_tree.process_frame
	_expect_true(choice_one.disabled, "first legal choice immediately locks its button", failures)
	_expect_true(choice_two.disabled, "first legal choice immediately locks the other button", failures)
	_expect_true(ending_layer.visible, "mouse choice reveals an authored ending", failures)
	_expect_equal(ending_title.text, "循环仍在继续", "mouse choice reaches the loop ending", failures)
	choice_two.pressed.emit()
	await scene_tree.process_frame
	_expect_equal(ending_title.text, "循环仍在继续", "repeated choice input cannot replace the ending", failures)

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
	_expect_true(
		choice_layer.has_theme_stylebox(&"panel"),
		"choice layer uses a themed cinematic surface",
		failures
	)

	player.free()

	var keyboard_player := packed_scene.instantiate()
	scene_tree.root.add_child(keyboard_player)
	var keyboard_start := keyboard_player.get_node("StartAction") as Button
	var keyboard_video := keyboard_player.get_node("PlayerStage/VideoStage") as VideoStreamPlayer
	var keyboard_choice_layer := keyboard_player.get_node("PlayerStage/ChoiceLayer") as Control
	var keyboard_ending_layer := keyboard_player.get_node("PlayerStage/EndingLayer") as Control
	var keyboard_ending_title := keyboard_player.get_node(
		"PlayerStage/EndingLayer/EndingContent/EndingTitle"
	) as Label
	keyboard_start.pressed.emit()
	await keyboard_video.finished
	await scene_tree.process_frame
	_expect_true(keyboard_choice_layer.visible, "second run waits for keyboard choice", failures)
	var choose_second := InputEventKey.new()
	choose_second.keycode = KEY_2
	choose_second.pressed = true
	Input.parse_input_event(choose_second)
	await scene_tree.process_frame
	_expect_true(keyboard_ending_layer.visible, "numeric key choice reveals an ending", failures)
	_expect_equal(keyboard_ending_title.text, "幸存者", "numeric key 2 reaches the survivor ending", failures)
	var late_first := InputEventKey.new()
	late_first.keycode = KEY_1
	late_first.pressed = true
	Input.parse_input_event(late_first)
	await scene_tree.process_frame
	_expect_equal(keyboard_ending_title.text, "幸存者", "late numeric input cannot replace the ending", failures)
	keyboard_player.free()
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
