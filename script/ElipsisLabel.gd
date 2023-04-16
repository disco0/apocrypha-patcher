tool
class_name ElipsisLabel
extends Label


#section members


export (String) var text_base := "" setget set_text_base
export (int) var elipsis_count := 3
export (float) var text_frame_time := 0.75 setget set_text_frame_time
export (Vector2) var center_offset := Vector2.ZERO setget set_center_offset
export (bool) var toplevel := true setget _set_toplevel
export (bool) var static_size := true

var timer: Timer setget set_timer, get_timer
var text_frame_idx := 0
var active := false


#section lifecycle


func _init() -> void:
	_set_toplevel(toplevel)
	_update_position()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_update_position()

		NOTIFICATION_PROCESS:
			if active:
				_update_position()

		NOTIFICATION_READY,\
		NOTIFICATION_RESIZED,\
		NOTIFICATION_THEME_CHANGED,\
		NOTIFICATION_MOVED_IN_PARENT,\
		NOTIFICATION_VISIBILITY_CHANGED:
			_update_position()

		NOTIFICATION_VISIBILITY_CHANGED:
			if not visible:
				if active:
					stop()
			else:
				_update_position()


#section methods


func _set_toplevel(value: bool) -> void:
	toplevel = value
	set_as_toplevel(value)


func _update_size() -> void:
	# @TODO: Remember why this is here
	get_font("font").get_string_size(text)


func _update_position():
	if static_size and is_instance_valid(owner) and owner as Control:
		var frame := OS.get_window_safe_area()
		set_position((frame.size - get_global_rect().size) / 2.0 + center_offset)


func set_center_offset(value: Vector2) -> void:
	center_offset = value
	_update_position()


func start() -> void:
	if active:
		push_warning('Already active')
		return

	active = true

	if not visible:
		show()

	get_timer().start()


func stop() -> void:
	if not active:
		push_warning('Currently inactive')
		return

	if is_instance_valid(timer):
		timer.stop()
		clear_timer()


func set_timer(value) -> void:
	pass


func get_timer() -> Timer:
	if not timer:
		timer = Timer.new()
		add_child(timer)
		timer.one_shot = false
		timer.wait_time = text_frame_time
		timer.connect("timeout", self, "_step_text_frame")

	return timer


func clear_timer() -> void:
	if timer:
		if timer.is_inside_tree():
			timer.get_parent().remove_child(timer)
			timer.queue_free()


func set_text_base(value: String) -> void:
	text_base = value
	text = text_base + ' '.repeat(elipsis_count)
	_update_size()
	_update_position()


func set_text_frame_time(value: float) -> void:
	text_frame_time = value
	if timer:
		timer.wait_time = text_frame_time


func _step_text_frame() -> void:
	var idx_mod := elipsis_count + 1
	text_frame_idx = (text_frame_idx + 1) % idx_mod
	var dot_count := text_frame_idx
	set('text', '%s%s%s' % [ text_base, '.'.repeat(dot_count), ' '.repeat(elipsis_count - dot_count) ])
	_update_size()
	_update_position()
