tool
extends PanelContainer


#section members

var EDITOR_LAUNCH_VALUES := {
	APOC_CONTENT_FOLDER = 'C:/csquad/artifacts/public/apocrypha-patcher/gen/content'.simplify_path(),
	BUILD_FOLDER = OS.get_environment('USERPROFILE').plus_file('Desktop/patcher/build').simplify_path()
}
var PATCH_SCRIPT_SIMULATE := false

onready var rot := $"%Rotator" as MeshRotatorControl
onready var shell := $"%Shell" as AsyncShellNode
onready var exit_button := $"%ExitButton" as Button
onready var steam_msg := $"%SteamSearchMsg" as ElipsisLabel
onready var title_label := $"%TitleLabel" as Label
onready var patch_button := $"%PatchButton" as Button
onready var patch_msg := $"%PatchingMsg" as ElipsisLabel
onready var show_log_button := $"%LogButton" as Button
onready var open_build_button := $"%OpenBuildButton" as Button
onready var log_content := $"%LogContent" as RichTextLabel
onready var log_overlay := $"%LogOverlay" as PanelContainer
onready var patch_overlay := $"%PatchingMsg/.." as PanelContainer
onready var release_pck_path_config: PathConfigContainer
onready var apoc_content_dir_config: PathConfigContainer
onready var out_dir_config:          PathConfigContainer


# Cmdline args
var cmdline_args := OS.get_cmdline_args()
var cmd_flags := {
	debug_workdir = arg_check(['--debug-workdir', '-w']),
	autopatch = arg_check('--auto'),
	debug_simulate = arg_check('--simulate'),
}
# Check for command line argument to automatically start patching
var autopatch_tried := false
var autopatch_close_aborted := false

# Last patch attempt success
var success := false

var config: ConfigStorage
var standalone := OS.has_feature('standalone')
var editor := Engine.editor_hint
var godot_launch := not (standalone or editor)
var patcher_dir := (Constants.TestConfig.patcher_dir as String) if godot_launch else OS.get_executable_path().get_base_dir()

var patcher_running := false setget set_patcher_running
func set_patcher_running(value: bool) -> void:
	patcher_running = value
	exit_button.disabled = patcher_running


#section lifecycle


func _init() -> void:
	if not Engine.editor_hint:
		OS.center_window()
		config = ConfigStorage.new()


func _ready() -> void:
	if not Engine.editor_hint:
		try_resolve_and_populate_release_path()

	if OS.has_feature('editor'):
		init_config_paths_editor()

	if not Engine.editor_hint:
		check_ready()

	get_tree().connect("files_dropped", self, "_on_files_dropped")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			_init_config_paths()
			_init_members()
			patch_button.hide()
			check_ready()

		NOTIFICATION_ENTER_TREE:
			_init_members()
			log_overlay.hide()
			show_log_button.get_parent().hide()

		NOTIFICATION_EXIT_TREE:
			if is_instance_valid(steam_msg):
				steam_msg.stop()

			if not Engine.editor_hint and is_instance_valid(config):
				config.save()


func _input(event: InputEvent) -> void:
	if event as InputEventKey:
		var kevent: InputEventKey = event
		if log_overlay.visible and kevent.get_physical_scancode_with_modifiers() == KEY_ESCAPE:
			log_overlay.hide()
			get_tree().set_input_as_handled()


func _init_members() -> void:
	_init_rotator()
	release_pck_path_config = $"%ReleasePckConfig"
	apoc_content_dir_config = $"%ApocryphaContentDirConfig"
	out_dir_config          = $"%OutputDirConfig"
	exit_button             = $"%ExitButton"
	show_log_button         = $"%LogButton"
	log_content             = $"%LogContent"
	log_overlay             = $"%LogOverlay"
	open_build_button       = $"%OpenBuildButton"


func _init_rotator() -> void:
	if not rot:
		rot = $"%Rotator"
	if rot:
		rot.rect_scale = Vector2(2.0, 2.0)
		rot.rect_size = get_tree().root.size / 2.0


func _init_config_paths() -> void:
	# Do some guesswork if outside of editor
	if standalone:
		if out_dir_config.path.empty():
			if config.out_dir:
				out_dir_config.path = config.out_dir
			else:
				out_dir_config.path = patcher_dir

		if apoc_content_dir_config.path.empty():
			apoc_content_dir_config.path = patcher_dir.plus_file('content')


#section resolve


# Fill in default paths for testing from godot
func init_config_paths_editor():
	print('[init_config_paths_editor] Editor launch detected, initializing default values')
	apoc_content_dir_config.set_path(EDITOR_LAUNCH_VALUES.APOC_CONTENT_FOLDER)
	out_dir_config.set_path(EDITOR_LAUNCH_VALUES.BUILD_FOLDER)


func find_steam_install_dir() -> String:
	var lines: PoolStringArray = yield(
			shell.run_command(PoolStringArray([PowershellCommands.SteamLibraryFoldersFileCommand])),
			'completed')

	return lines.join('\n')


func try_resolve_and_populate_release_path() -> void:
	if Engine.editor_hint: return

	steam_msg.show()
	steam_msg.start()

	var resolved_steam_dir := false
	var resolved_dir = yield(find_steam_install_dir(), 'completed')

	if resolved_dir and typeof(resolved_dir) == TYPE_STRING and not resolved_dir.empty():
		resolved_dir = resolved_dir.simplify_path() # replace('\\', '/')
		var dir: Directory = Directory.new()
		match dir.open(resolved_dir):
			OK: pass
			var err:
				push_error('Error %s opening <%s>' % [ err, resolved_dir ])
				steam_msg.stop()
				steam_msg.hide()
				return

		var expected_pck_path := (resolved_dir as String).plus_file(Constants.ReleasePckName)

		print("Checking if %s in directory %s" % [ Constants.ReleasePckName, resolved_dir ])
		if dir.file_exists(Constants.ReleasePckName):
			print("Checking if config path empty (%s)" % [ release_pck_path_config ])
			if release_pck_path_config.path.empty():
				release_pck_path_config.path = expected_pck_path
				resolved_steam_dir = true

	if not resolved_steam_dir:
		push_error('Failed to resolve steam dir, returning before build cmd test')
		steam_msg.stop()
		steam_msg.hide()
		return

	steam_msg.stop()
	steam_msg.hide()


#section patch


func start_patcher() -> void:
	if patcher_running:
		push_warning('Patcher process already running.')
		return

	print('Patcher started')

	var dir: Directory = Directory.new()
	var params := {
		patcher_dir      = patcher_dir,
		apoc_content_dir = apoc_content_dir_config.path,
		steam_pck_file   = release_pck_path_config.path,
		out_dir          = out_dir_config.path
	}
	var failed_check := false
	for path_name in params.keys():
		var path: String = params.get(path_name)
		match path_name.rsplit('_', 1)[0]:
			'dir':
				if not dir.dir_exists(path):
					push_error('Configured directory path for %s does not exist: <%s>' % [ path_name, path ])
					failed_check = true
			'file':
				if not dir.file_exists(path):
					push_error('Configured file path for %s does not exist: <%s>' % [ path_name, path ])
					failed_check = true

	if failed_check:
		yield(get_tree(), "idle_frame")
		return

	# Test
	var build_apoc_cmd := PowershellCommands.BuildPackApocPckCommandFmtString(
			params.patcher_dir,
			params.steam_pck_file,
			params.apoc_content_dir,
			params.out_dir,
			cmd_flags.debug_workdir,
			PATCH_SCRIPT_SIMULATE)

	#print("Build patch command:\n-----\n%s-----\n" % [ build_apoc_cmd ])
	var lines: PoolStringArray = yield(
			shell.run_command(PoolStringArray([build_apoc_cmd])),
			'completed')

	success = false
	for line in lines:
		if line.match("*" + PowershellCommands.SUCCESS_SIGIL):
			success = true

	var stdout := lines.join('\n')

	open_build_button.get_parent().visible = success

	log_content.text = stdout
	show_log_button.get_parent().show()

	patcher_running = false


func begin_autoclose_routine() -> void:
	print('[--auto] Patching successful, exiting patcher in')
	for count in [ 3, 2, 1 ]:
		print('[--auto] %d' % [ count ])
		yield(get_tree().create_timer(1.0), "timeout")
		if autopatch_close_aborted:
			print('[--auto] Autoclose cancelled.')
			return

	get_tree().quit()


func cancel_autoclose_routine(context: String = "") -> void:
	if not context.empty():
		print('%s, cancelling autoclose' % [ context])
	autopatch_close_aborted = true


# Update menu state based on config points completion
func check_ready() -> void:
	var dir: Directory = Directory.new()

	match [ dir.file_exists(release_pck_path_config.path) and not release_pck_path_config.path.empty(),
			dir.dir_exists(out_dir_config.path)           and not out_dir_config.path.empty(),
			dir.dir_exists(apoc_content_dir_config.path)  and not apoc_content_dir_config.path.empty() ]:

		[ true, true, true ]:
			patch_button.show()
			title_label.hide()
			rot.color = Color.red
			rot.mesh_fps = 15.0
			rot.mesh_rotation_scale = 3.0

			# Start autopatch if not yet tried
			if cmd_flags.autopatch and not autopatch_tried:
				autopatch_tried = true
				print('[--auto] flag passed, immediately starting patcher')
				yield(_on_PatchButton_pressed(), 'completed')
				autopatch_close_aborted = false
				if success:
					begin_autoclose_routine()

		[ false, false, false ]:
			patch_button.hide()
			title_label.show()
			rot.color = Color.yellow
			rot.mesh_fps = 5.0
			rot.mesh_rotation_scale = 0.5

		[ true,  false, false ],\
		[ false, true,  false ],\
		[ false, false, true  ]:
			patch_button.hide()
			title_label.show()
			rot.color = Color.green
			rot.mesh_fps = 8.0
			rot.mesh_rotation_scale = 0.8

		_:
			patch_button.hide()
			title_label.show()
			rot.color = Color.green
			rot.mesh_fps = 10.0
			rot.mesh_rotation_scale = 1.25


#section util


# @param args: string | Array<string> | PoolStringArray
func arg_check(args) -> bool:
	if typeof(args) == TYPE_STRING: args = [ args ]

	for arg in args:
		if arg in cmdline_args:
			return true

	return false


#section config


func sync_dialog_dir(source: PathConfigContainer):
	var new_dir := source.dialog.current_dir
	for config in [ apoc_content_dir_config, release_pck_path_config ]:
		config.dialog.current_dir = new_dir

	if out_dir_config.path.empty():
		out_dir_config.dialog.current_dir = new_dir
	else:
		# There's a better place for this
		out_dir_config.dialog.current_dir = out_dir_config.path


#section signals


func _on_files_dropped(files: PoolStringArray, screen: int) -> void:
	cancel_autoclose_routine('Files dropped')
	pass


func _on_ReleasePckPath_value_changed(path: String) -> void:
	cancel_autoclose_routine('New release pck path set')

	sync_dialog_dir(release_pck_path_config)
	check_ready()


func _on_OutputDirPath_value_changed(path: String) -> void:
	cancel_autoclose_routine('New output dir path set')

	sync_dialog_dir(out_dir_config)
	if config:
		config.out_dir = path
	check_ready()


func _on_ApocryphaContentDir_value_changed(path: String) -> void:
	cancel_autoclose_routine('New apoc content dir path set')

	sync_dialog_dir(apoc_content_dir_config)
	check_ready()


func _on_ExitButton_pressed() -> void:
	cancel_autoclose_routine('Exit button pressed')

	if not patcher_running:
		get_tree().quit()


func _on_PatchButton_pressed() -> void:
	cancel_autoclose_routine('Patch button pressed')

	call_deferred('grab_focus')
	patch_overlay.show()
	patch_msg.show()
	patch_msg.start()
	yield(start_patcher(), 'completed')
	patch_overlay.hide()
	patch_msg.stop()
	patch_msg.hide()


func _on_LogButton_pressed() -> void:
	cancel_autoclose_routine('Log button pressed')

	log_overlay.show()


func _on_OpenBuildButton_pressed() -> void:
	cancel_autoclose_routine('Open build button pressed')

	OS.shell_open(out_dir_config.path)


#section statics


#section classes


class ConfigStorage:
	const CONFIG_PATH = 'user://config.cfg'

	var cfg: ConfigFile
	var _dir: Directory = Directory.new()

	# Config points
	var out_dir: String setget set_out_dir, get_out_dir


	func _init() -> void:
		cfg = ConfigFile.new()
		# Ignore load error
		cfg.load(CONFIG_PATH)


	func save() -> int:
		print('Saving config to <%s>' % [ CONFIG_PATH ])
		return cfg.save(CONFIG_PATH)


	func set_out_dir(path: String) -> void:
		# Allow for clearing
		if path.empty() or _dir.dir_exists(path):
			cfg.set_value('paths', 'out_dir', path)
			print('Stored value for out_dir: %s' % [ path ])
		else:
			push_warning('Directory does not exist: %s' % [ path ])


	func get_out_dir() -> String:
		return cfg.get_value('paths', 'out_dir', '')
