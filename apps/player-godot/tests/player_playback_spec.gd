extends RefCounted


func run(scene_tree: SceneTree, packed_scene: PackedScene) -> Array[String]:
	var failures: Array[String] = []
	var player := packed_scene.instantiate()
	scene_tree.root.add_child(player)

	var start_action := player.get_node_or_null("%StartAction") as Button
	var player_stage := player.get_node_or_null("%PlayerStage") as Control
	var loading_layer := player.get_node_or_null("%LoadingLayer") as Control
	var subtitle_layer := player.get_node_or_null("%SubtitleLayer") as Control
	var subtitle_text := player.get_node_or_null("%SubtitleText") as Label
	var video_player := player.get_node_or_null("%VideoStage") as VideoStreamPlayer
	var choice_layer := player.get_node_or_null("%ChoiceLayer") as Control
	var choice_one := player.get_node_or_null("%ChoiceOne") as Button
	var choice_two := player.get_node_or_null("%ChoiceTwo") as Button
	var pause_layer := player.get_node_or_null("%PauseLayer") as Control
	var ending_layer := player.get_node_or_null("%EndingLayer") as Control
	var ending_title := player.get_node_or_null("%EndingTitle") as Label
	var error_layer := player.get_node_or_null("%ErrorLayer") as Control
	var error_diagnostics := player.get_node_or_null("%ErrorDiagnostics") as Label

	_expect_true(start_action != null, "Player exposes the primary start action", failures)
	_expect_true(player_stage != null, "Player exposes a cinematic playback stage", failures)
	_expect_true(loading_layer != null, "Player stage owns a cinematic loading state", failures)
	_expect_true(subtitle_layer != null, "Player stage owns a subtitle layer", failures)
	_expect_true(subtitle_text != null, "subtitle layer owns visible text", failures)
	_expect_true(video_player != null, "Player stage owns a real VideoStreamPlayer seam", failures)
	_expect_true(choice_layer != null, "Player stage owns a cinematic choice layer", failures)
	_expect_true(choice_one != null, "choice layer owns the first authored option", failures)
	_expect_true(choice_two != null, "choice layer owns the second authored option", failures)
	_expect_true(pause_layer != null, "Player stage owns a cinematic pause layer", failures)
	_expect_true(ending_layer != null, "Player stage owns an ending layer", failures)
	_expect_true(ending_title != null, "ending layer owns a title", failures)
	_expect_true(error_layer != null, "Player stage owns an error layer", failures)
	_expect_true(error_diagnostics != null, "error layer owns developer diagnostics", failures)

	if (
		start_action == null
		or player_stage == null
		or loading_layer == null
		or subtitle_layer == null
		or subtitle_text == null
		or video_player == null
		or choice_layer == null
		or choice_one == null
		or choice_two == null
		or pause_layer == null
		or ending_layer == null
		or ending_title == null
		or error_layer == null
		or error_diagnostics == null
	):
		player.free()
		return failures

	await _activate_button(start_action, scene_tree)
	_expect_true(player_stage.visible, "starting immediately reveals the playback stage", failures)
	_expect_true(loading_layer.visible, "starting immediately reveals loading feedback", failures)
	_expect_between(
		loading_layer.modulate.a,
		0.0,
		1.0,
		"loading begins with a visible restrained fade",
		failures
	)
	await scene_tree.process_frame
	_expect_true(not loading_layer.visible, "loading clears when playback becomes ready", failures)

	await scene_tree.create_timer(0.35).timeout
	_expect_true(subtitle_layer.visible, "subtitle cue becomes visible from media time", failures)
	_expect_equal(subtitle_text.text, "信号接通。", "subtitle cue renders authored Simplified Chinese", failures)
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_ESCAPE
	pause_key.pressed = true
	Input.parse_input_event(pause_key)
	await scene_tree.process_frame
	_expect_true(pause_layer.visible, "Escape opens pause during playback", failures)
	_expect_between(
		pause_layer.modulate.a,
		0.0,
		1.0,
		"pause begins with a restrained fade",
		failures
	)
	var repeated_pause_key := InputEventKey.new()
	repeated_pause_key.keycode = KEY_ESCAPE
	repeated_pause_key.pressed = true
	repeated_pause_key.echo = true
	Input.parse_input_event(repeated_pause_key)
	await scene_tree.create_timer(0.15).timeout
	_expect_true(pause_layer.visible, "repeated Escape does not stack or dismiss pause", failures)
	_expect_equal(subtitle_text.text, "信号接通。", "paused subtitle remains synchronized", failures)
	var resume_action := player.get_node_or_null("%PauseResumeAction") as Button
	_expect_true(resume_action != null, "pause layer offers continue", failures)
	_expect_true(player.get_node_or_null("%PauseRestartAction") != null, "pause layer offers restart", failures)
	_expect_true(player.get_node_or_null("%PauseReturnTitleAction") != null, "pause layer offers return to title", failures)
	_expect_true(player.get_node_or_null("%PauseExitAction") != null, "pause layer offers exit", failures)
	if resume_action == null:
		player.free()
		return failures
	await _activate_button(resume_action, scene_tree)
	_expect_true(not pause_layer.visible, "continue closes the pause layer", failures)
	await scene_tree.create_timer(0.15).timeout
	_expect_equal(subtitle_text.text, "信号接通。", "continue resumes at the paused cue", failures)
	await _wait_for_text(subtitle_text, "零点回声，等待回应。", scene_tree)
	_expect_equal(
		subtitle_text.text,
		"零点回声，等待回应。",
		"subtitle remains synchronized after crossing a cue boundary",
		failures
	)
	var restart_pause_key := InputEventKey.new()
	restart_pause_key.keycode = KEY_ESCAPE
	restart_pause_key.pressed = true
	Input.parse_input_event(restart_pause_key)
	await scene_tree.process_frame
	_expect_true(pause_layer.visible, "playback can be paused again after continue", failures)
	var pause_restart_action := player.get_node_or_null("%PauseRestartAction") as Button
	await _activate_button(pause_restart_action, scene_tree)
	_expect_true(not pause_layer.visible, "restart closes the pause layer", failures)
	_expect_true(loading_layer.visible, "restart immediately returns to loading", failures)
	if not loading_layer.visible:
		player.free()
		return failures
	await scene_tree.process_frame
	await scene_tree.create_timer(0.35).timeout
	_expect_equal(subtitle_text.text, "信号接通。", "restart returns to the entry subtitle", failures)

	await _finish_common_clips(video_player, scene_tree)
	_expect_true(choice_layer.visible, "ClipFinished reveals the authored choice", failures)
	_expect_true(not ending_layer.visible, "choice presentation does not select a default ending", failures)
	_expect_equal(choice_one.text, "登上末班车", "first option renders authored text", failures)
	_expect_equal(choice_two.text, "离开站台", "second option renders authored text", failures)
	await scene_tree.create_timer(0.1).timeout
	_expect_true(not ending_layer.visible, "choice remains open without a countdown", failures)
	var choice_pause_key := InputEventKey.new()
	choice_pause_key.keycode = KEY_ESCAPE
	choice_pause_key.pressed = true
	Input.parse_input_event(choice_pause_key)
	await scene_tree.process_frame
	_expect_true(pause_layer.visible, "Escape pauses while waiting for a choice", failures)
	var blocked_choice_key := InputEventKey.new()
	blocked_choice_key.keycode = KEY_1
	blocked_choice_key.pressed = true
	Input.parse_input_event(blocked_choice_key)
	await scene_tree.process_frame
	_expect_true(not ending_layer.visible, "pause freezes choice input", failures)
	_expect_true(choice_layer.visible, "paused choice remains pending", failures)
	await _activate_button(resume_action, scene_tree)
	_expect_true(not pause_layer.visible, "continue returns to the pending choice", failures)
	_expect_true(not choice_one.disabled, "continue unlocks the pending first choice", failures)
	_expect_true(not choice_two.disabled, "continue unlocks the pending second choice", failures)

	await _click_button(choice_one, scene_tree)
	_expect_true(not choice_layer.visible, "first legal choice closes the choice layer", failures)
	_expect_true(video_player.is_playing(), "boarding starts its authored branch clip", failures)
	_expect_true(not ending_layer.visible, "branch media plays before its ending", failures)
	await _finish_current_clip(video_player, scene_tree)
	_expect_true(ending_layer.visible, "mouse choice reveals an authored ending", failures)
	_expect_between(
		ending_layer.modulate.a,
		0.0,
		1.0,
		"ending begins with a restrained fade",
		failures
	)
	_expect_equal(ending_title.text, "循环仍在继续", "mouse choice reaches the loop ending", failures)
	var repeated_choice_key := InputEventKey.new()
	repeated_choice_key.keycode = KEY_2
	repeated_choice_key.pressed = true
	Input.parse_input_event(repeated_choice_key)
	await scene_tree.process_frame
	_expect_equal(ending_title.text, "循环仍在继续", "repeated choice input cannot replace the ending", failures)
	var ending_escape := InputEventKey.new()
	ending_escape.keycode = KEY_ESCAPE
	ending_escape.pressed = true
	Input.parse_input_event(ending_escape)
	await scene_tree.process_frame
	_expect_true(not pause_layer.visible, "Escape cannot open pause from an ending", failures)
	var ending_restart_action := player.get_node_or_null("%EndingRestartAction") as Button
	var ending_title_action := player.get_node_or_null("%EndingReturnTitleAction") as Button
	_expect_true(ending_restart_action != null, "ending offers restart", failures)
	_expect_true(ending_title_action != null, "ending offers return to title", failures)
	_expect_true(player.get_node_or_null("%EndingExitAction") != null, "ending offers exit", failures)
	if ending_restart_action == null or ending_title_action == null:
		player.free()
		return failures
	await _activate_button(ending_restart_action, scene_tree)
	_expect_true(not ending_layer.visible, "ending restart closes the ending", failures)
	_expect_true(loading_layer.visible, "ending restart immediately returns to loading", failures)
	await _finish_common_clips(video_player, scene_tree)
	_expect_true(
		choice_layer.visible and not ending_layer.visible,
		"ending restart reaches a fresh authored choice",
		failures
	)
	await _click_button(choice_two, scene_tree)
	_expect_true(video_player.is_playing(), "leaving starts its authored branch clip", failures)
	_expect_true(not ending_layer.visible, "survivor branch media plays before its ending", failures)
	await _finish_current_clip(video_player, scene_tree)
	_expect_true(ending_layer.visible, "restarted StoryRuntime can reach a new ending", failures)
	_expect_equal(
		ending_title.text,
		"幸存者",
		"restarted StoryRuntime follows the newly selected branch",
		failures
	)
	await _activate_button(ending_title_action, scene_tree)
	await scene_tree.process_frame
	_expect_true(start_action.visible, "ending can return to the title", failures)
	_expect_between(
		start_action.modulate.a,
		0.0,
		1.0,
		"returning title begins with a restrained fade",
		failures
	)
	_expect_true(not player_stage.visible, "ending return hides the playback stage", failures)
	await _activate_button(start_action, scene_tree)
	await scene_tree.process_frame
	await scene_tree.process_frame

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
		"test detail" in error_diagnostics.text,
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

	var title_player := packed_scene.instantiate()
	scene_tree.root.add_child(title_player)
	var title_start := title_player.get_node("%StartAction") as Button
	var title_stage := title_player.get_node("%PlayerStage") as Control
	var title_pause_layer := title_player.get_node("%PauseLayer") as Control
	var title_subtitle_layer := title_player.get_node("%SubtitleLayer") as Control
	var title_subtitle_text := title_player.get_node("%SubtitleText") as Label
	var return_title_action := title_player.get_node("%PauseReturnTitleAction") as Button
	await _activate_button(title_start, scene_tree)
	await scene_tree.process_frame
	var title_pause_key := InputEventKey.new()
	title_pause_key.keycode = KEY_ESCAPE
	title_pause_key.pressed = true
	Input.parse_input_event(title_pause_key)
	await scene_tree.process_frame
	_expect_true(title_pause_layer.visible, "a new session can enter pause", failures)
	await _activate_button(return_title_action, scene_tree)
	await scene_tree.process_frame
	_expect_true(title_start.visible, "return to title restores the primary action", failures)
	_expect_true(not title_stage.visible, "return to title hides the playback stage", failures)
	var title_escape := InputEventKey.new()
	title_escape.keycode = KEY_ESCAPE
	title_escape.pressed = true
	Input.parse_input_event(title_escape)
	await scene_tree.process_frame
	_expect_true(not title_pause_layer.visible, "Escape cannot open pause from the title", failures)
	await _activate_button(title_start, scene_tree)
	_expect_true(title_stage.visible, "the restored title can start a new session", failures)
	await scene_tree.process_frame
	await scene_tree.create_timer(0.35).timeout
	_expect_true(title_subtitle_layer.visible, "a new session renders the entry subtitle", failures)
	_expect_equal(title_subtitle_text.text, "信号接通。", "return to title clears the previous session", failures)
	title_player.free()

	var keyboard_player := packed_scene.instantiate()
	scene_tree.root.add_child(keyboard_player)
	var keyboard_start := keyboard_player.get_node("%StartAction") as Button
	var keyboard_choice_layer := keyboard_player.get_node("%ChoiceLayer") as Control
	var keyboard_ending_layer := keyboard_player.get_node("%EndingLayer") as Control
	var keyboard_ending_title := keyboard_player.get_node("%EndingTitle") as Label
	var keyboard_video_player := keyboard_player.get_node("%VideoStage") as VideoStreamPlayer
	await _activate_button(keyboard_start, scene_tree)
	await _finish_common_clips(keyboard_video_player, scene_tree)
	_expect_true(keyboard_choice_layer.visible, "second run waits for keyboard choice", failures)
	var choose_second := InputEventKey.new()
	choose_second.keycode = KEY_2
	choose_second.pressed = true
	Input.parse_input_event(choose_second)
	await scene_tree.process_frame
	_expect_true(not keyboard_ending_layer.visible, "numeric choice plays its branch clip first", failures)
	await _finish_current_clip(keyboard_video_player, scene_tree)
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


func _click_button(button: Button, scene_tree: SceneTree) -> void:
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	scene_tree.root.push_input(motion, true)
	await scene_tree.process_frame
	var down := InputEventMouseButton.new()
	down.position = center
	down.global_position = center
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	scene_tree.root.push_input(down, true)
	var up := InputEventMouseButton.new()
	up.position = center
	up.global_position = center
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	scene_tree.root.push_input(up, true)
	await scene_tree.process_frame


func _activate_button(button: Button, scene_tree: SceneTree) -> void:
	button.grab_focus()
	await scene_tree.process_frame
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.pressed = true
	scene_tree.root.push_input(press, true)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.pressed = false
	scene_tree.root.push_input(release, true)


func _finish_common_clips(video_player: VideoStreamPlayer, scene_tree: SceneTree) -> void:
	await scene_tree.process_frame
	for _clip_index in range(3):
		await _finish_current_clip(video_player, scene_tree)


func _finish_current_clip(video_player: VideoStreamPlayer, scene_tree: SceneTree) -> void:
	video_player.finished.emit()
	await scene_tree.process_frame
	await scene_tree.process_frame


func _wait_for_text(label: Label, expected: String, scene_tree: SceneTree) -> void:
	var deadline := Time.get_ticks_msec() + 1500
	while label.text != expected and Time.get_ticks_msec() < deadline:
		await scene_tree.process_frame


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


func _expect_between(
	actual: float,
	minimum: float,
	maximum: float,
	behavior: String,
	failures: Array[String]
) -> void:
	if actual <= minimum or actual >= maximum:
		failures.append(
			"%s: expected between %s and %s, got %s" % [
				behavior, minimum, maximum, actual
			]
		)
