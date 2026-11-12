extends Control

const STORY_RUNTIME = preload("res://scripts/story_runtime.gd")
const BUNDLED_PUBLISHED_STORY_PACK_PATH := "res://content/zero-echo/storypack.json"

enum PlayerState { TITLE, LOADING, PLAYING, AWAITING_CHOICE, PAUSED, ENDING, ERROR }

@export var developer_diagnostics := OS.is_debug_build()
@export_file("*.json") var published_story_pack_path := BUNDLED_PUBLISHED_STORY_PACK_PATH

var _runtime := STORY_RUNTIME.new()
var _subtitle_cues: Array = []
var _choice_option_ids: Array[String] = []
var _choice_locked := false
var _player_state := PlayerState.TITLE
var _state_before_pause := PlayerState.TITLE

@onready var _start_action: Button = $StartAction
@onready var _player_stage: Control = $PlayerStage
@onready var _loading_layer: PanelContainer = $PlayerStage/LoadingLayer
@onready var _video_player: VideoStreamPlayer = $PlayerStage/VideoStage
@onready var _subtitle_layer: PanelContainer = $PlayerStage/SubtitleLayer
@onready var _subtitle_text: Label = $PlayerStage/SubtitleLayer/SubtitleText
@onready var _choice_layer: PanelContainer = $PlayerStage/ChoiceLayer
@onready var _choice_one: Button = $PlayerStage/ChoiceLayer/ChoiceMargin/ChoiceContent/ChoiceOne
@onready var _choice_two: Button = $PlayerStage/ChoiceLayer/ChoiceMargin/ChoiceContent/ChoiceTwo
@onready var _pause_layer: Control = $PlayerStage/PauseLayer
@onready var _resume_action: Button = %PauseResumeAction
@onready var _pause_restart_action: Button = %PauseRestartAction
@onready var _pause_title_action: Button = %PauseReturnTitleAction
@onready var _pause_exit_action: Button = %PauseExitAction
@onready var _ending_layer: PanelContainer = $PlayerStage/EndingLayer
@onready var _ending_title: Label = $PlayerStage/EndingLayer/EndingContent/EndingTitle
@onready var _ending_text: Label = $PlayerStage/EndingLayer/EndingContent/EndingText
@onready var _ending_restart_action: Button = %EndingRestartAction
@onready var _ending_title_action: Button = %EndingReturnTitleAction
@onready var _ending_exit_action: Button = %EndingExitAction
@onready var _error_layer: Control = %ErrorLayer
@onready var _error_summary: Label = %ErrorSummary
@onready var _error_diagnostics: Label = %ErrorDiagnostics
@onready var _error_title_action: Button = %ErrorReturnTitleAction
@onready var _error_exit_action: Button = %ErrorExitAction


func _ready() -> void:
	_set_title_visible(true, true)
	_start_action.pressed.connect(_on_start_action_pressed)
	_video_player.finished.connect(_on_video_finished)
	_choice_one.pressed.connect(_submit_choice.bind(0))
	_choice_two.pressed.connect(_submit_choice.bind(1))
	_resume_action.pressed.connect(_resume_story)
	_pause_restart_action.pressed.connect(_restart_story)
	_pause_title_action.pressed.connect(_return_to_title)
	_pause_exit_action.pressed.connect(_exit_player)
	_ending_restart_action.pressed.connect(_restart_story)
	_ending_title_action.pressed.connect(_return_to_title)
	_ending_exit_action.pressed.connect(_exit_player)
	_error_title_action.pressed.connect(_return_to_title)
	_error_exit_action.pressed.connect(_exit_player)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_ESCAPE:
			if _player_state in [PlayerState.PLAYING, PlayerState.AWAITING_CHOICE]:
				_pause_story()
		KEY_1:
			_submit_choice(0)
		KEY_2:
			_submit_choice(1)


func _process(_delta: float) -> void:
	if _player_state != PlayerState.PLAYING or not _video_player.is_playing():
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
	_begin_story()


func _begin_story() -> void:
	_player_state = PlayerState.LOADING
	_show_player_stage()
	_reveal_layer(_loading_layer)
	await get_tree().process_frame
	var loaded_content: Variant = _read_published_story_pack(published_story_pack_path)
	if not (loaded_content is Dictionary):
		_loading_layer.hide()
		_show_error(
			{
				"type": "ShowError",
				"code": "StoryPackReadFailed",
				"message": "剧情文件无法读取，无法开始播放。",
				"resource_id": published_story_pack_path.get_file(),
				"resolved_path": ProjectSettings.globalize_path(published_story_pack_path),
			}
		)
		return

	var published_story_pack := loaded_content as Dictionary
	var open_effects: Array = _runtime.open(published_story_pack)
	_loading_layer.hide()
	if not open_effects.is_empty():
		render_story_effects(open_effects)
		return
	render_story_effects(
		_runtime.start(str(published_story_pack.get("entry_node_id", "")))
	)


func _on_video_finished() -> void:
	if _player_state != PlayerState.PLAYING:
		return
	render_story_effects(_runtime.dispatch({"type": "ClipFinished"}))


func _submit_choice(choice_index: int) -> void:
	if (
		_player_state != PlayerState.AWAITING_CHOICE
		or
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


func _read_published_story_pack(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	var parsed: Variant = parser.data
	if parsed is Dictionary:
		return parsed
	return null


func _show_player_stage() -> void:
	_set_title_visible(false)
	_player_stage.show()


func _set_title_visible(is_visible: bool, with_fade: bool = false) -> void:
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
		if is_visible and with_fade:
			_reveal_layer(node)
		else:
			node.visible = is_visible
			if not is_visible:
				node.modulate.a = 1.0


func _reveal_layer(layer: CanvasItem) -> void:
	layer.modulate.a = 0.35
	layer.show()
	var tween := layer.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer, "modulate:a", 1.0, 0.18)


func render_story_effects(effects: Array) -> void:
	if _player_state == PlayerState.ERROR:
		return
	for effect: Variant in effects:
		if not (effect is Dictionary):
			continue
		match effect.get("type"):
			"PlayClip":
				_reset_choices()
				_ending_layer.hide()
				_error_layer.hide()
				var media_path := str(effect.get("media_path", ""))
				var stream: VideoStream = null
				if ResourceLoader.exists(media_path, "VideoStream"):
					stream = ResourceLoader.load(media_path, "VideoStream") as VideoStream
				if stream == null:
					_show_media_playback_error(effect)
					return
				_video_player.stream = stream
				if _video_player.get_stream_length() <= 0.0:
					_show_media_playback_error(effect)
					return
				_video_player.paused = false
				_video_player.play()
				if not _video_player.is_playing():
					_show_media_playback_error(effect)
					return
				_player_state = PlayerState.PLAYING
			"ShowSubtitles":
				_subtitle_cues = effect.get("cues", []).duplicate(true)
			"PresentChoices":
				_present_choices(effect)
				if _player_state == PlayerState.ERROR:
					return
			"ShowEnding":
				_player_state = PlayerState.ENDING
				_video_player.stop()
				_subtitle_cues.clear()
				_subtitle_layer.hide()
				_choice_layer.hide()
				_ending_title.text = str(effect.get("title", ""))
				_ending_text.text = str(effect.get("text", ""))
				_reveal_layer(_ending_layer)
			"ShowError":
				_show_error(effect)
				return


func _present_choices(effect: Dictionary) -> void:
	var choices: Variant = effect.get("choices", [])
	if not (choices is Array) or choices.size() != 2:
		_show_choice_presentation_error()
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
			_show_choice_presentation_error()
			return
		_choice_option_ids.append(str(choice.get("option_id", "")))
		buttons[index].text = str(choice.get("text", ""))
		buttons[index].disabled = false
	_choice_locked = false
	_player_state = PlayerState.AWAITING_CHOICE
	_choice_layer.show()
	_choice_one.grab_focus()


func _show_choice_presentation_error() -> void:
	_show_error(
		{
			"type": "ShowError",
			"code": "ChoicePresentationFailed",
			"message": "剧情选择无法显示。",
		}
	)


func _show_media_playback_error(effect: Dictionary) -> void:
	var media_path := str(effect.get("media_path", ""))
	_show_error(
		{
			"type": "ShowError",
			"code": "MediaPlaybackFailed",
			"message": "视频素材无法播放。",
			"resource_id": str(effect.get("node_id", media_path.get_file())),
			"resolved_path": ProjectSettings.globalize_path(media_path),
		}
	)


func _reset_choices() -> void:
	_choice_layer.hide()
	_choice_option_ids.clear()
	_choice_locked = false
	_choice_one.disabled = false
	_choice_two.disabled = false


func _pause_story() -> void:
	_state_before_pause = _player_state
	_player_state = PlayerState.PAUSED
	if _state_before_pause == PlayerState.PLAYING:
		_video_player.paused = true
	_choice_one.disabled = true
	_choice_two.disabled = true
	_reveal_layer(_pause_layer)
	_resume_action.grab_focus()


func _resume_story() -> void:
	if _player_state != PlayerState.PAUSED:
		return
	_pause_layer.hide()
	_player_state = _state_before_pause
	if _player_state == PlayerState.PLAYING:
		_video_player.paused = false
	elif _player_state == PlayerState.AWAITING_CHOICE and not _choice_locked:
		_choice_one.disabled = false
		_choice_two.disabled = false
		_choice_one.grab_focus()


func _restart_story() -> void:
	if _player_state not in [PlayerState.PAUSED, PlayerState.ENDING]:
		return
	_reset_story_session()
	_begin_story()


func _return_to_title() -> void:
	if _player_state not in [PlayerState.PAUSED, PlayerState.ENDING, PlayerState.ERROR]:
		return
	_reset_story_session()
	_loading_layer.hide()
	_player_stage.hide()
	_set_title_visible(true, true)
	_player_state = PlayerState.TITLE
	_start_action.grab_focus()


func _exit_player() -> void:
	get_tree().quit(0)


func _reset_story_session() -> void:
	_video_player.stop()
	_video_player.paused = false
	_video_player.stream = null
	_subtitle_cues.clear()
	_subtitle_text.text = ""
	_subtitle_layer.hide()
	_reset_choices()
	_pause_layer.hide()
	_ending_layer.hide()
	_error_layer.hide()
	_error_summary.text = ""
	_error_diagnostics.text = ""
	_error_diagnostics.hide()
	_runtime = STORY_RUNTIME.new()


func _show_error(effect: Dictionary) -> void:
	_player_state = PlayerState.ERROR
	_show_player_stage()
	_video_player.stop()
	_video_player.paused = false
	_loading_layer.hide()
	_subtitle_cues.clear()
	_subtitle_text.text = ""
	_subtitle_layer.hide()
	_reset_choices()
	_pause_layer.hide()
	_ending_layer.hide()
	_error_summary.text = str(effect.get("message", "剧情数据无效，无法开始播放。"))
	var diagnostic_lines: Array[String] = []
	for field: String in ["code", "resource_id", "resolved_path"]:
		var value := str(effect.get(field, ""))
		if not value.is_empty():
			diagnostic_lines.append("%s: %s" % [field, value])
	for detail: Variant in effect.get("details", []):
		diagnostic_lines.append(str(detail))
	_error_diagnostics.text = "\n".join(diagnostic_lines)
	_error_diagnostics.visible = developer_diagnostics and not diagnostic_lines.is_empty()
	_reveal_layer(_error_layer)
	_error_title_action.grab_focus()
