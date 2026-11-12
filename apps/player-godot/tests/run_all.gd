extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_run_story_runtime_spec()

	_expect_equal(
		ProjectSettings.get_setting("application/config/name"),
		"CineWeave",
		"project exposes the CineWeave application name"
	)
	_expect_equal(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		1280,
		"project uses a 1280-wide internal canvas"
	)
	_expect_equal(
		ProjectSettings.get_setting("display/window/size/viewport_height"),
		720,
		"project uses a 720-high internal canvas"
	)
	_expect_equal(
		ProjectSettings.get_setting("display/window/stretch/mode"),
		"canvas_items",
		"project scales its internal canvas with the window"
	)
	_expect_equal(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"gl_compatibility",
		"project uses the Compatibility renderer"
	)

	var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect_true(not main_scene_path.is_empty(), "project declares a main scene")

	var packed_scene := load(main_scene_path) as PackedScene
	_expect_true(packed_scene != null, "main scene can be loaded")
	if packed_scene != null:
		var title_screen := packed_scene.instantiate()
		root.add_child(title_screen)
		_expect_true(title_screen is Control, "main scene is a Control-based Player screen")
		if title_screen is Control:
			_expect_true(title_screen.theme != null, "title screen has a project theme")
			var control_text := _collect_control_text(title_screen)
			_expect_true(control_text.has("影织"), "title screen presents the CineWeave name")
			_expect_true(control_text.has("开始体验"), "title screen presents a primary start action")
			_expect_control_theme(title_screen)
		title_screen.free()
		await _run_player_playback_spec(packed_scene)

	if _failures.is_empty():
		print("PASS: CineWeave Godot startup baseline")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run_story_runtime_spec() -> void:
	var spec_script := load("res://tests/story_runtime_spec.gd")
	_expect_true(spec_script != null, "StoryRuntime public seam specification can be loaded")
	if spec_script == null:
		return
	var spec: RefCounted = spec_script.new()
	_failures.append_array(spec.run())


func _run_player_playback_spec(packed_scene: PackedScene) -> void:
	var spec_script := load("res://tests/player_playback_spec.gd")
	_expect_true(spec_script != null, "Player playback public seam specification can be loaded")
	if spec_script == null:
		return
	var spec: RefCounted = spec_script.new()
	var playback_failures: Array[String] = await spec.run(self, packed_scene)
	_failures.append_array(playback_failures)


func _collect_control_text(node: Node) -> Array[String]:
	var copy: Array[String] = []
	if node is Label or node is Button:
		copy.append(str(node.get("text")))
	for child in node.get_children():
		copy.append_array(_collect_control_text(child))
	return copy


func _expect_control_theme(title_screen: Control) -> void:
	var buttons := _collect_buttons(title_screen)
	var visible_buttons: Array[Button] = []
	for button in buttons:
		if button.is_visible_in_tree():
			visible_buttons.append(button)
	_expect_equal(visible_buttons.size(), 1, "title screen exposes one visible primary action")
	if visible_buttons.size() == 1:
		var start_action := visible_buttons[0]
		_expect_equal(
			start_action.focus_mode,
			Control.FOCUS_ALL,
			"primary action supports keyboard and controller focus"
		)
		start_action.grab_focus()
		_expect_true(start_action.has_focus(), "primary action can receive interface focus")
	for button in buttons:
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_expect_true(
				button.has_theme_stylebox(state),
				"Player action defines a %s theme state" % state
			)

	var panels := _collect_panels(title_screen)
	_expect_true(not panels.is_empty(), "title screen exposes a themed status surface")
	for panel in panels:
		_expect_true(
			panel.has_theme_stylebox(&"panel"),
			"title screen panels use themed surfaces"
		)


func _collect_buttons(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _collect_panels(node: Node) -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	if node is PanelContainer:
		panels.append(node)
	for child in node.get_children():
		panels.append_array(_collect_panels(child))
	return panels


func _expect_equal(actual: Variant, expected: Variant, behavior: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [behavior, expected, actual])


func _expect_true(condition: bool, behavior: String) -> void:
	if not condition:
		_failures.append("%s" % behavior)
