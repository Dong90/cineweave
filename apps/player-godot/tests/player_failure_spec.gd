extends RefCounted


func run(scene_tree: SceneTree, packed_scene: PackedScene) -> Array[String]:
	var failures: Array[String] = []
	var player := packed_scene.instantiate()
	if not _has_property(player, &"developer_diagnostics"):
		failures.append("Player exposes the developer diagnostics configuration seam")
		player.free()
		return failures
	player.set(&"developer_diagnostics", false)
	scene_tree.root.add_child(player)

	var error_layer := player.get_node_or_null("%ErrorLayer") as Control
	var error_summary := player.get_node_or_null("%ErrorSummary") as Label
	var error_diagnostics := player.get_node_or_null("%ErrorDiagnostics") as Label
	var return_title_action := player.get_node_or_null("%ErrorReturnTitleAction") as Button
	var exit_action := player.get_node_or_null("%ErrorExitAction") as Button
	_expect_true(error_layer != null, "Player exposes a blocking error layer", failures)
	_expect_true(error_summary != null, "error layer exposes a player-safe summary", failures)
	_expect_true(error_diagnostics != null, "error layer exposes separate diagnostics", failures)
	_expect_true(return_title_action != null, "error layer offers return to title", failures)
	_expect_true(exit_action != null, "error layer offers exit", failures)
	if (
		error_layer == null
		or error_summary == null
		or error_diagnostics == null
		or return_title_action == null
		or exit_action == null
	):
		player.free()
		return failures

	player.render_story_effects(
		[
			{
				"type": "ShowError",
				"code": "InvalidStoryPack",
				"message": "剧情数据无效，无法开始播放。",
				"resource_id": "zero-echo",
				"resolved_path": "C:/private/content/storypack.json",
				"details": ["entry_node_id must reference an existing StoryNode"],
			},
		]
	)
	await scene_tree.process_frame
	_expect_true(error_layer.is_visible_in_tree(), "ShowError blocks the Player", failures)
	_expect_equal(
		error_summary.text,
		"剧情数据无效，无法开始播放。",
		"ordinary players receive the safe error summary",
		failures
	)
	_expect_true(
		not "C:/private" in error_summary.text,
		"ordinary player summary does not expose local paths",
		failures
	)
	_expect_true(
		not error_diagnostics.is_visible_in_tree(),
		"ordinary players do not see developer diagnostics",
		failures
	)
	_expect_true(return_title_action.has_theme_stylebox(&"normal"), "error return is themed", failures)
	_expect_true(exit_action.has_theme_stylebox(&"normal"), "error exit is themed", failures)

	await _activate_button(return_title_action, scene_tree)
	await scene_tree.process_frame
	_expect_true(not error_layer.is_visible_in_tree(), "error return closes the failure state", failures)
	_expect_true(
		(player.get_node("%StartAction") as Button).is_visible_in_tree(),
		"error return restores the title action",
		failures
	)
	player.free()

	var developer_player := packed_scene.instantiate()
	developer_player.set(&"developer_diagnostics", true)
	scene_tree.root.add_child(developer_player)
	var developer_error_layer := developer_player.get_node("%ErrorLayer") as Control
	var developer_summary := developer_player.get_node("%ErrorSummary") as Label
	var developer_details := developer_player.get_node("%ErrorDiagnostics") as Label
	var developer_choice_layer := developer_player.get_node("%ChoiceLayer") as Control
	var developer_ending_layer := developer_player.get_node("%EndingLayer") as Control
	var developer_return := developer_player.get_node("%ErrorReturnTitleAction") as Button
	developer_player.render_story_effects(
		[
			{
				"type": "ShowError",
				"code": "InvalidStoryPack",
				"message": "剧情数据无效，无法开始播放。",
				"resource_id": "intro",
				"resolved_path": "C:/private/content/storypack.json",
				"details": ["entry_node_id must reference an existing StoryNode"],
			},
			{
				"type": "PresentChoices",
				"choices": [
					{"option_id": "one", "text": "不应显示"},
					{"option_id": "two", "text": "不应显示"},
				],
			},
			{
				"type": "ShowEnding",
				"title": "不应到达",
				"text": "错误后不得继续剧情。",
			},
		]
	)
	await scene_tree.process_frame
	_expect_true(developer_details.is_visible_in_tree(), "developer mode reveals diagnostics", failures)
	for expected_diagnostic: String in [
		"InvalidStoryPack",
		"intro",
		"C:/private/content/storypack.json",
		"entry_node_id must reference an existing StoryNode",
	]:
		_expect_true(
			expected_diagnostic in developer_details.text,
			"developer diagnostics include %s" % expected_diagnostic,
			failures
		)
	_expect_true(
		not "C:/private" in developer_summary.text,
		"developer mode still keeps local paths out of the player summary",
		failures
	)
	_expect_true(not developer_choice_layer.visible, "ShowError blocks later choices in the batch", failures)
	_expect_true(not developer_ending_layer.visible, "ShowError blocks later endings in the batch", failures)

	developer_player.render_story_effects(
		[
			{
				"type": "PresentChoices",
				"choices": [
					{"option_id": "one", "text": "仍不应显示"},
					{"option_id": "two", "text": "仍不应显示"},
				],
			},
		]
	)
	await scene_tree.process_frame
	_expect_true(
		developer_error_layer.is_visible_in_tree() and not developer_choice_layer.visible,
		"ERROR state rejects later StoryEffects",
		failures
	)

	await _activate_button(developer_return, scene_tree)
	await scene_tree.process_frame
	developer_player.render_story_effects(
		[
			{
				"type": "PlayClip",
				"node_id": "missing-clip",
				"media_path": "res://missing-video.ogv",
			},
		]
	)
	await scene_tree.process_frame
	_expect_equal(developer_summary.text, "视频素材无法播放。", "missing media is player-safe", failures)
	_expect_true(
		"missing-clip" in developer_details.text and "missing-video.ogv" in developer_details.text,
		"missing media identifies the resource in developer diagnostics",
		failures
	)

	await _activate_button(developer_return, scene_tree)
	await scene_tree.process_frame
	developer_player.render_story_effects(
		[
			{
				"type": "PlayClip",
				"node_id": "unplayable-video",
				"media_path": "res://tests/fixtures/unplayable-video.tres",
			},
		]
	)
	await scene_tree.process_frame
	_expect_equal(
		developer_summary.text,
		"视频素材无法播放。",
		"unplayable media is converted to ShowError",
		failures
	)
	_expect_true(
		"unplayable-video" in developer_details.text and "unplayable-video.tres" in developer_details.text,
		"unplayable media remains diagnosable",
		failures
	)
	developer_player.free()

	var startup_player := packed_scene.instantiate()
	if not _has_property(startup_player, &"published_story_pack_path"):
		failures.append("Player exposes the PublishedStoryPack path configuration seam")
		startup_player.free()
		return failures
	startup_player.set(&"developer_diagnostics", false)
	startup_player.set(&"published_story_pack_path", "res://missing-storypack.json")
	scene_tree.root.add_child(startup_player)
	var startup_action := startup_player.get_node("%StartAction") as Button
	var startup_error_layer := startup_player.get_node("%ErrorLayer") as Control
	var startup_summary := startup_player.get_node("%ErrorSummary") as Label
	var startup_return := startup_player.get_node("%ErrorReturnTitleAction") as Button
	await _activate_button(startup_action, scene_tree)
	await scene_tree.process_frame
	await scene_tree.process_frame
	_expect_true(startup_error_layer.is_visible_in_tree(), "missing StoryPack blocks startup", failures)
	_expect_equal(
		startup_summary.text,
		"剧情文件无法读取，无法开始播放。",
		"missing StoryPack uses a player-safe summary",
		failures
	)
	_expect_true(
		not "missing-storypack.json" in startup_summary.text,
		"missing StoryPack does not leak its path to ordinary players",
		failures
	)

	await _activate_button(startup_return, scene_tree)
	await scene_tree.process_frame
	startup_player.set(&"published_story_pack_path", "res://project.godot")
	await _activate_button(startup_action, scene_tree)
	await scene_tree.process_frame
	await scene_tree.process_frame
	_expect_true(startup_error_layer.is_visible_in_tree(), "invalid StoryPack JSON blocks startup", failures)
	_expect_equal(
		startup_summary.text,
		"剧情文件无法读取，无法开始播放。",
		"invalid StoryPack JSON uses the same safe failure surface",
		failures
	)

	await _activate_button(startup_return, scene_tree)
	await scene_tree.process_frame
	startup_player.set(&"developer_diagnostics", true)
	startup_player.set(&"published_story_pack_path", "res://tests/fixtures/empty-storypack.json")
	await _activate_button(startup_action, scene_tree)
	await scene_tree.process_frame
	await scene_tree.process_frame
	var startup_diagnostics := startup_player.get_node("%ErrorDiagnostics") as Label
	_expect_true(startup_error_layer.is_visible_in_tree(), "empty StoryPack blocks startup", failures)
	_expect_equal(
		startup_summary.text,
		"剧情数据无效，无法开始播放。",
		"valid JSON with missing required fields is rejected by StoryRuntime",
		failures
	)
	_expect_true(
		"format_version must equal 0.1" in startup_diagnostics.text,
		"empty StoryPack preserves StoryRuntime validation diagnostics",
		failures
	)
	startup_player.free()
	return failures


func _has_property(instance: Object, property_name: StringName) -> bool:
	for descriptor: Dictionary in instance.get_property_list():
		if descriptor.get("name") == property_name:
			return true
	return false


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
