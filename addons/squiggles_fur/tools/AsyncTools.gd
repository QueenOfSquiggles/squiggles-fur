@tool
class_name AsyncTools

class MaxMillis:
	var start := 0
	var max := 0
	func _init(max_millis: int) -> void:
		start = Time.get_ticks_msec()
		max = max_millis
	## await this function to do awaits once a certain millisecond threshold is reached
	func tick() -> void:
		var now := Time.get_ticks_msec()
		if (now - start) > max:
			await RenderingServer.frame_post_draw
			start = Time.get_ticks_msec()
