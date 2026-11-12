extends RefCounted

var _nodes_by_id: Dictionary = {}
var _current_node_id := ""


func open(story_pack: Dictionary) -> Array[Dictionary]:
	_nodes_by_id.clear()
	_current_node_id = ""
	if story_pack.get("format_version") != "0.1":
		return _invalid_story_pack("format_version must equal 0.1")
	if str(story_pack.get("story_id", "")).is_empty():
		return _invalid_story_pack("story_id is required")
	if str(story_pack.get("title", "")).is_empty():
		return _invalid_story_pack("title is required")
	var nodes: Variant = story_pack.get("nodes")
	if not (nodes is Array) or nodes.is_empty():
		return _invalid_story_pack("nodes must contain at least one StoryNode")
	for node: Variant in nodes:
		if not (node is Dictionary):
			return _invalid_story_pack("every StoryNode must be an object")
		var node_id := str(node.get("id", ""))
		if node_id.is_empty():
			return _invalid_story_pack("StoryNode id is required")
		if node.get("type") not in ["clip", "choice", "end"]:
			return _invalid_story_pack("StoryNode type must be clip, choice, or end")
		if _nodes_by_id.has(node_id):
			return _invalid_story_pack("StoryNode ids must be unique")
		_nodes_by_id[node_id] = node.duplicate(true)
	if not _nodes_by_id.has(str(story_pack.get("entry_node_id", ""))):
		return _invalid_story_pack("entry_node_id must reference an existing StoryNode")
	for node: Dictionary in _nodes_by_id.values():
		if node.get("type") == "clip" and not _nodes_by_id.has(str(node.get("next_node_id", ""))):
			return _invalid_story_pack("clip next_node_id must reference an existing StoryNode")
		if node.get("type") == "clip":
			var media_path := str(node.get("media_path", ""))
			if not FileAccess.file_exists(media_path):
				return _invalid_story_pack(
					"clip media_path must reference an existing file",
					str(node.get("id", "")),
					ProjectSettings.globalize_path(media_path)
				)
			if (
				not ResourceLoader.exists(media_path, "VideoStream")
				or not (ResourceLoader.load(media_path, "VideoStream") is VideoStream)
			):
				return _invalid_story_pack(
					"clip media_path must reference a playable VideoStream",
					str(node.get("id", "")),
					ProjectSettings.globalize_path(media_path)
				)
		var subtitles: Variant = node.get("subtitles")
		if node.get("type") == "clip" and (not (subtitles is Array) or subtitles.is_empty()):
			return _invalid_story_pack("clip subtitles must contain at least one cue")
		if node.get("type") == "clip":
			var previous_cue_end_ms := -1.0
			for cue: Variant in subtitles:
				var cue_is_invalid := not (cue is Dictionary)
				if not cue_is_invalid:
					cue_is_invalid = (
						not cue.has("start_ms")
						or not cue.has("end_ms")
						or float(cue.get("start_ms", -1)) < 0.0
						or float(cue.get("end_ms", -1)) <= float(cue.get("start_ms", -1))
						or str(cue.get("text", "")).is_empty()
					)
				if cue_is_invalid:
					return _invalid_story_pack(
						"subtitle cues require ordered start_ms, end_ms, and text"
					)
				var cue_start_ms := float(cue.get("start_ms", -1))
				if cue_start_ms < previous_cue_end_ms:
					return _invalid_story_pack(
						"subtitle cues must be ordered and non-overlapping"
					)
				previous_cue_end_ms = float(cue.get("end_ms", -1))
		var options: Variant = node.get("options")
		if node.get("type") == "choice" and (
			not (options is Array) or options.size() != 2
		):
			return _invalid_story_pack("choice options must contain exactly two options")
		if node.get("type") == "choice":
			var option_ids: Dictionary = {}
			for option: Variant in options:
				if not (option is Dictionary):
					return _invalid_story_pack("every choice option must be an object")
				var option_id := str(option.get("id", ""))
				if option_id.is_empty():
					return _invalid_story_pack("choice option id is required")
				if option_ids.has(option_id):
					return _invalid_story_pack(
						"choice option ids must be unique within the StoryNode"
					)
				option_ids[option_id] = true
				if str(option.get("text", "")).is_empty():
					return _invalid_story_pack("choice option text is required")
				if not _nodes_by_id.has(str(option.get("target_node_id", ""))):
					return _invalid_story_pack(
						"choice option target_node_id must reference an existing StoryNode"
					)
		if node.get("type") == "end" and (
			str(node.get("title", "")).is_empty() or str(node.get("text", "")).is_empty()
		):
			return _invalid_story_pack("end StoryNode requires title and text")
	return []


func start(entry_node_id: String) -> Array[Dictionary]:
	return _enter_node(entry_node_id)


func dispatch(player_action: Dictionary) -> Array[Dictionary]:
	var current_node: Dictionary = _nodes_by_id.get(_current_node_id, {})
	match player_action.get("type"):
		"ClipFinished":
			if current_node.get("type") == "clip":
				return _enter_node(str(current_node.get("next_node_id", "")))
		"ChoiceSelected":
			if current_node.get("type") != "choice":
				return []
			var option_id := str(player_action.get("option_id", ""))
			for option: Dictionary in current_node.get("options", []):
				if str(option.get("id", "")) == option_id:
					return _enter_node(str(option.get("target_node_id", "")))
	return []


func _invalid_story_pack(
	detail: String,
	resource_id: String = "",
	resolved_path: String = ""
) -> Array[Dictionary]:
	_nodes_by_id.clear()
	var effect := {
		"type": "ShowError",
		"code": "InvalidStoryPack",
		"message": "剧情数据无效，无法开始播放。",
		"details": [detail],
	}
	if not resource_id.is_empty():
		effect["resource_id"] = resource_id
	if not resolved_path.is_empty():
		effect["resolved_path"] = resolved_path
	return [effect]


func _enter_node(node_id: String) -> Array[Dictionary]:
	var node: Dictionary = _nodes_by_id.get(node_id, {})
	if node.is_empty():
		return []
	_current_node_id = node_id
	match node.get("type"):
		"clip":
			return [
				{
					"type": "PlayClip",
					"node_id": node_id,
					"media_path": str(node.get("media_path", "")),
				},
				{
					"type": "ShowSubtitles",
					"node_id": node_id,
					"cues": node.get("subtitles", []).duplicate(true),
				},
			]
		"choice":
			var choices: Array[Dictionary] = []
			for option: Variant in node.get("options", []):
				if option is Dictionary:
					choices.append(
						{
							"option_id": str(option.get("id", "")),
							"text": str(option.get("text", "")),
						}
					)
			return [
				{
					"type": "PresentChoices",
					"node_id": node_id,
					"choices": choices,
				},
			]
		"end":
			return [
				{
					"type": "ShowEnding",
					"node_id": node_id,
					"title": str(node.get("title", "")),
					"text": str(node.get("text", "")),
				},
			]
	return []
