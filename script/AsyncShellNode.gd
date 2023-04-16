class_name AsyncShellNode
extends Node


#section members


var shell := 'powershell'
var prefix_args := [ '-NoProfile', '-NoLogo', '-ExecutionPolicy', 'Bypass', '-Command' ]
var args := [ ]
var thread: Thread
var read_stderr := false


#section lifecycle


#section methods


func run_command(cmd_args: PoolStringArray) -> PoolStringArray:
	thread = Thread.new()
	print('Starting thread')
	thread.start(self, "_thread", cmd_args)

	while thread.is_alive():
		yield(get_tree(), "idle_frame")

	var result: PoolStringArray = thread.wait_to_finish()

	thread = null

	return result


func _thread(thread_args) -> PoolStringArray:
	var cmd_args := prefix_args.duplicate()
	cmd_args.append_array(thread_args)

	var stdout := []

	var err: int = OS.execute(shell, cmd_args, true, stdout, read_stderr)

	if err != 0:
		printerr("Error occurred: %d" % err)

	var output_lines := PoolStringArray()
	for line in stdout:
		output_lines.push_back(line.trim_suffix("\r\n"))

	return output_lines
