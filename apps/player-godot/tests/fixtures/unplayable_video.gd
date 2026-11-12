class_name UnplayableVideo
extends VideoStream


class RejectedPlayback extends VideoStreamPlayback:
	func _play() -> void:
		pass


	func _is_playing() -> bool:
		return false


	func _get_length() -> float:
		return 0.0


	func _update(_delta: float) -> void:
		pass


func _instantiate_playback() -> VideoStreamPlayback:
	return RejectedPlayback.new()
