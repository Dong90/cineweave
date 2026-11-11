extends Control

const STORY_RUNTIME = preload("res://scripts/story_runtime.gd")
const SAMPLE_STORY_PACK_PATH := "res://content/zero-echo/storypack.json"

var _runtime := STORY_RUNTIME.new()
var _subtitle_cues: Array = []
var _choice_option_ids: Array[String] = []
var _choice_locked := false

@onready var _start_action: Button = $StartAction
@onready var _player_stage: Control = $PlayerStage
@onready var _video_player: VideoStreamPlayer = $PlayerStage/VideoStage
@onready var _subtitle_layer: PanelContainer = $PlayerStage/SubtitleLayer
@onready var _subtitle_text: Label = $PlayerStage/SubtitleLayer/SubtitleText
@onready var _choice_layer: PanelContainer = $PlayerStage/ChoiceLayer
@onready var _choice_one: Button = $PlayerStage/ChoiceLayer/ChoiceMargin/ChoiceContent/ChoiceOne
@onready var _choice_two: Button = $PlayerStage/ChoiceLayer/ChoiceMargin/ChoiceContent/ChoiceTwo
@onready var _ending_layer: PanelContainer = $PlayerStage/EndingLayer
@onready var _ending_title: Label = $PlayerStage/EndingLayer/EndingContent/EndingTitle
@onready var _ending_text: Label = $PlayerStage/EndingLayer/EndingContent/EndingText
@onready var _error_layer: PanelContainer = $PlayerStage/ErrorLayer
@onready var _error_text: Label = $PlayerStage/ErrorLayer/ErrorContent/ErrorText


func _ready() -> void:
	_start_action.pressed.connect(_on_start_action_pressed)
	_video_player.finished.connect(_on_video_finished)
	_choice_one.pressed.connect(_submit_choice.bind(0))
	_choice_two.pressed.connect(_submit_choice.bind(1))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_submit_choice(0)
		KEY_2:
			_submit_choice(1)


func _process(_delta: float) -> void:
	if not _video_player.is_playing():
		return
	var media_time_ms := int(_video_player.stream_position * 1000.0)
	var active_text := ""
	for cue: Variant in _subtitle_cues:
		if (
			cue is Dictionary
			and media_time_ms >= int(cue.get("start_ms", -1))
			and media_time_ms < int(cue.get("end_ms", -1))
		):
			active_text = str(cue.get("text", ""))
			break
	_subtitle_text.text = active_text
	_subtitle_layer.visible = not active_text.is_empty()


func _on_start_action_pressed() -> void:
	var story_pack := _read_story_pack(SAMPLE_STORY_PACK_PATH)
	if story_pack.is_empty():
		_show_player_stage()
		_show_error("StoryPack 文件无法读取。", [])
		return

	var open_effects: Array = _runtime.open(story_pack)
	_show_player_stage()
	if not open_effects.is_empty():
		render_story_effects(open_effects)
		return
	render_story_effects(_runtime.start(str(story_pack.get("entry_node_id", ""))))


func _on_video_finished() -> void:
	render_story_effects(_runtime.dispatch({"type": "ClipFinished"}))


func _submit_choice(choice_index: int) -> void:
	if (
		_choice_locked
		or not _choice_layer.visible
		or choice_index < 0
		or choice_index >= _choice_option_ids.size()
	):
		return
	var option_id := _choice_option_ids[choice_index]
	if option_id.is_empty():
		return
	_choice_locked = true
	_choice_one.disabled = true
	_choice_two.disabled = true
	render_story_effects(
		_runtime.dispatch({"type": "ChoiceSelected", "option_id": option_id})
	)


func _read_story_pack(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _show_player_stage() -> void:
	for node: CanvasItem in [
		$Background,
		$GridLineTop,
		$AccentLine,
		$Brand,
		$SystemStatus,
		$Hero,
		$StartAction,
		$Hint,
		$Footer,
	]:
		node.hide()
	_player_stage.show()


func render_story_effects(effects: Array) -> void:
	for effect: Variant in effects:
		if not (effect is Dictionary):
			continue
		match effect.get("type"):
			"PlayClip":
				_reset_choices()
				_ending_layer.hide()
				_error_layer.hide()
				var stream := load(str(effect.get("media_path", ""))) as VideoStream
				if stream == null:
					_show_error("视频素材无法加载。", [])
					continue
				_video_player.stream = stream
				_video_player.play()
			"ShowSubtitles":
				_subtitle_cues = effect.get("cues", []).duplicate(true)
			"PresentChoices":
				_present_choices(effect)
			"ShowEnding":
				_video_player.stop()
				_subtitle_cues.clear()
				_subtitle_layer.hide()
				_choice_layer.hide()
				_ending_title.text = str(effect.get("title", ""))
				_ending_text.text = str(effect.get("text", ""))
				_ending_layer.show()
			"ShowError":
				var details: Array = effect.get("details", [])
				_show_error(str(effect.get("message", "StoryPack 校验失败。")), details)


func _present_choices(effect: Dictionary) -> void:
	var choices: Variant = effect.get("choices", [])
	if not (choices is Array) or choices.size() != 2:
		_show_error("选择数据无法显示。", [])
		return
	_video_player.stop()
	_subtitle_cues.clear()
	_subtitle_layer.hide()
	_ending_layer.hide()
	_choice_option_ids.clear()
	var buttons: Array[Button] = [_choice_one, _choice_two]
	for index in range(buttons.size()):
		var choice: Variant = choices[index]
		if not (choice is Dictionary):
			_show_error("选择数据无法显示。", [])
			return
		_choice_option_ids.append(str(choice.get("option_id", "")))
		buttons[index].text = str(choice.get("text", ""))
		buttons[index].disabled = false
	_choice_locked = false
	_choice_layer.show()
	_choice_one.grab_focus()


func _reset_choices() -> void:
	_choice_layer.hide()
	_choice_option_ids.clear()
	_choice_locked = false
	_choice_one.disabled = false
	_choice_two.disabled = false


func _show_error(message: String, details: Array) -> void:
	_video_player.stop()
	_subtitle_layer.hide()
	_choice_locked = true
	_choice_one.disabled = true
	_choice_two.disabled = true
	_choice_layer.hide()
	_error_text.text = message
	if not details.is_empty():
		_error_text.text += "\n%s" % "\n".join(details)
	_error_layer.show()
