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
	var nodes: Variant = story_pack.get("nodes")
	if not (nodes is Array) or nodes.is_empty():
		return _invalid_story_pack("nodes must contain at least one StoryNode")
	for node: Variant in nodes:
		if node is Dictionary:
			var node_id := str(node.get("id", ""))
			if node_id.is_empty():
				return _invalid_story_pack("StoryNode id is required")
			if node.get("type") not in ["clip", "end"]:
				return _invalid_story_pack("StoryNode type must be clip or end")
			if _nodes_by_id.has(node_id):
				return _invalid_story_pack("StoryNode ids must be unique")
			_nodes_by_id[node_id] = node.duplicate(true)
	if not _nodes_by_id.has(str(story_pack.get("entry_node_id", ""))):
		return _invalid_story_pack("entry_node_id must reference an existing StoryNode")
	for node: Dictionary in _nodes_by_id.values():
		if node.get("type") == "clip" and not _nodes_by_id.has(str(node.get("next_node_id", ""))):
			return _invalid_story_pack("clip next_node_id must reference an existing StoryNode")
		if node.get("type") == "clip" and not FileAccess.file_exists(str(node.get("media_path", ""))):
			return _invalid_story_pack("clip media_path must reference an existing file")
		var subtitles: Variant = node.get("subtitles")
		if node.get("type") == "clip" and (not (subtitles is Array) or subtitles.is_empty()):
			return _invalid_story_pack("clip subtitles must contain at least one cue")
		if node.get("type") == "clip":
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
		if node.get("type") == "end" and (
			str(node.get("title", "")).is_empty() or str(node.get("text", "")).is_empty()
		):
			return _invalid_story_pack("end StoryNode requires title and text")
	return []


func start(entry_node_id: String) -> Array[Dictionary]:
	return _enter_node(entry_node_id)


func dispatch(player_action: Dictionary) -> Array[Dictionary]:
	if player_action.get("type") != "ClipFinished":
		return []
	var current_node: Dictionary = _nodes_by_id.get(_current_node_id, {})
	return _enter_node(str(current_node.get("next_node_id", "")))


func _invalid_story_pack(detail: String) -> Array[Dictionary]:
	_nodes_by_id.clear()
	return [
		{
			"type": "ShowError",
			"code": "InvalidStoryPack",
			"message": "StoryPack validation failed.",
			"details": [detail],
		},
	]


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
