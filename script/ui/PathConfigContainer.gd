tool
class_name PathConfigContainer
extends Container


#section members


signal value_changed(path)


#section members


enum MODE { DIR, FILE, ANY }
const DebugTheme := preload("res://res/theme/main_theme.tres")

export (String) var config_name := "PathConfig" setget set_config_name
export (bool) var editable := true setget set_editable
export (MODE) var path_mode: int = MODE.ANY
export (String) var file_path_filter = "*.*"
export (String) var placeholder = "" setget set_placeholder

var name_label:   Label
var path_edit:    LineEdit
var file_dialog:  FileDialog
var popup_button: Button
var overlay:      Panel
var dialog:       FileDialog

var debug_theme_set := false
var path: String = "" setget set_path


#section lifecycle


func _init() -> void:
	if is_inside_tree():
		_init_node_members()


func _ready() -> void:
	_init_node_members()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if Engine.editor_hint and not theme and get_tree().edited_scene_root == self:
				_set_debug_theme()
		NOTIFICATION_PREDELETE:
			# Clear debug theme if set
			if debug_theme_set and theme == DebugTheme:
				theme = null
		NOTIFICATION_READY,\
		NOTIFICATION_ENTER_TREE:
			set_editable(editable)
			set_config_name(config_name)
			set_placeholder(placeholder)


#section methods


func _set(property: String, value) -> bool:
	if property == 'theme' and value is Theme:
		theme = value
		debug_theme_set = false
		return true

	return false


func _init_node_members() -> void:
	name_label   = $"%NameLabel"
	path_edit    = $"%PathEdit"
	file_dialog  = $"%FileDialog"
	popup_button = $"%PopupButton"
	overlay      = $"%ExclusiveOverlay"
	dialog       = $"%FileDialog"


func set_value(value: String) -> void: set_path(value)


func set_path(value: String) -> void:
	path = value.simplify_path()
	if is_inside_tree():
		path_edit.text = path

	emit_signal("value_changed", path)


func set_editable(value: bool) -> void:
	editable = value

	if is_inside_tree():
		path_edit.editable = editable


func set_config_name(value: String) -> void:
	config_name = value

	if is_inside_tree():
		_update_config_name_label()


func set_placeholder(value: String) -> void:
	placeholder = value
	if is_inside_tree():
		path_edit.placeholder_text = placeholder


func _update_config_name_label() -> void:
	name_label.text = config_name


func _set_debug_theme() -> void:
	assert(theme == null, 'Theme already set.')
	assert(is_inside_tree(), "Setting preview debug theme outside of tree.")
	assert(not debug_theme_set, "debug_theme_set == true")
	theme = DebugTheme
	debug_theme_set = true


func present_file_dialog() -> void:
	file_dialog.popup_exclusive = true

	match path_mode:
		MODE.ANY:
			file_dialog.mode = FileDialog.MODE_OPEN_ANY
		MODE.DIR:
			file_dialog.mode = FileDialog.MODE_OPEN_DIR
		MODE.FILE:
			file_dialog.mode = FileDialog.MODE_OPEN_FILE
			file_dialog.filters = PoolStringArray([file_path_filter])

	file_dialog.window_title = "SELECT %s" % [ config_name.to_upper() ]

	set_overlay_state(true)
	file_dialog.connect("popup_hide", self, "set_overlay_state", [false], CONNECT_ONESHOT)

	var menu_size := get_tree().root.size
	var y_offset := 20
	file_dialog.popup_centered(menu_size - Vector2(menu_size.x * 0.1, y_offset * 2.0))
	file_dialog.rect_global_position.y += y_offset


#section handlers


func set_overlay_state(state: bool) -> void:
	match state:
		true:
			overlay.set_as_toplevel(true)
			overlay.set_size(Vector2.ONE * 10000.0)
			# probably not right
			overlay.set_global_position(Vector2.ZERO) #(overlay.rect_size / 2.0) - (get_tree().root.size / 2.0))
			overlay.show()
		false:
			overlay.hide()


func _on_PopupButton_pressed() -> void:
	present_file_dialog()


func _on_FileDialog_file_selected(selected_path: String) -> void:
	if path_mode == MODE.FILE:
		set_path(selected_path)


func _on_FileDialog_dir_selected(selected_dir: String) -> void:
	if path_mode == MODE.DIR:
		set_path(selected_dir)


func _on_PathEdit_text_changed(new_text: String) -> void:
	set_path(new_text)
