extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
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
		_expect_true(title_screen is Control, "main scene is a Control-based Player screen")
		if title_screen is Control:
			_expect_true(title_screen.theme != null, "title screen has a project theme")
			var control_text := _collect_control_text(title_screen)
			_expect_true(control_text.has("影织"), "title screen presents the CineWeave name")
			_expect_true(control_text.has("开始体验"), "title screen presents a primary start action")
			_expect_control_theme(title_screen)
		title_screen.free()

	if _failures.is_empty():
		print("PASS: CineWeave Godot startup baseline")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _collect_control_text(node: Node) -> Array[String]:
	var copy: Array[String] = []
	if node is Label or node is Button:
		copy.append(str(node.get("text")))
	for child in node.get_children():
		copy.append_array(_collect_control_text(child))
	return copy


func _expect_control_theme(title_screen: Control) -> void:
	var start_action := title_screen.get_node_or_null("StartAction") as Button
	_expect_true(start_action != null, "title screen exposes its primary action")
	if start_action != null:
		_expect_equal(
			start_action.focus_mode,
			Control.FOCUS_ALL,
			"primary action supports keyboard and controller focus"
		)
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_expect_true(
				start_action.has_theme_stylebox(state),
				"primary action defines a %s theme state" % state
			)

	var system_status := title_screen.get_node_or_null("SystemStatus") as PanelContainer
	_expect_true(system_status != null, "title screen exposes its offline status panel")
	if system_status != null:
		_expect_true(
			system_status.has_theme_stylebox(&"panel"),
			"offline status panel uses a themed surface"
		)


func _expect_equal(actual: Variant, expected: Variant, behavior: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [behavior, expected, actual])


func _expect_true(condition: bool, behavior: String) -> void:
	if not condition:
		_failures.append("%s" % behavior)
