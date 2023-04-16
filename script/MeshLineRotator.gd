tool
class_name MeshRotatorControl
extends Control


#section members


export (float, 1.0, 120.0, 0.5) var mesh_fps := 15.0
export (float, 0.05, 20.0, 0.05) var mesh_rotation_scale := 1.0
export (Vector2) var offset := Vector2()
export (Color) var initial_color := Color.red
export (int, 1, 10) var line_width := 1

var mdt: MeshDataTool
var nd:  MeshInstance
var mdt_edge_count: int
var color: Color = initial_color


#section lifecycle


func _init() -> void:
	if is_inside_tree():
		init_mesh()


func _ready() -> void:
	init_mesh()


func _process(_delta: float) -> void: update()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			init_mesh()
		NOTIFICATION_DRAW:
			_draw_mesh()


#section methods


func _draw_mesh() -> void:
	var draw_pos  := rect_size / 2.0
	var draw_size := rect_size / 2.0
	var line_color := Color(color)
	var mouse_pos := get_local_mouse_position()

	var ticks := Time.get_ticks_msec()
	ticks = ticks - (fmod(ticks, (1000.0 / mesh_fps)))
	var t := ticks / 1000.0 * mesh_rotation_scale
	var rot := t
	var _rot_axis := Vector3(0.3, 0.0, 1.0).normalized()
	var xform := Transform().scaled(Vector3(1.0, 1.2, 1.0))
	xform = xform.rotated(Vector3.UP, rot)

	for edg in range(mdt_edge_count):
		var vert1: Vector3 = xform.xform(mdt.get_vertex(mdt.get_edge_vertex(edg, 0)))
		var vert2: Vector3 = xform.xform(mdt.get_vertex(mdt.get_edge_vertex(edg, 1)))

		var period := PI * 2.0 + t * 0.05 * mesh_fps
		var _line_sin := sin(period)
		var _line_cos := cos(period)

		# line1
		#var p1_x_xform := vert1.x * draw_size.x * line_cos
		#var p1_z_xform := vert1.z * draw_size.x * line_sin
		#var p1_y_xform := vert1.y * draw_size.x
		var p1_xform_draw_x := vert1 * draw_size.x #* Vector3(line_sin, line_cos, 1.0)
		var p1 := Vector2(draw_pos.x
								+ vert1.x
								+ p1_xform_draw_x.z # p2_z_xform
								+ p1_xform_draw_x.x, # p2_x_xform,
						  draw_pos.y
								- p1_xform_draw_x.y #p2_y_xform
					) - offset
		#var p1 := Vector2(draw_pos.x + vert1.x
		#						+ p1_z_xform
		#						+ p1_x_xform,
		#					draw_pos.y - p1_y_xform) - offset
		# line2
		#* Vector3(line_cos, line_sin, 1.0)
		#var p2_x_xform := vert2.x * draw_size.x * line_cos
		#var p2_z_xform := vert2.z * draw_size.x * line_sin
		#var p2_y_xform := vert2.y * draw_size.x
		var p2_xform_draw_x := vert2 * draw_size.x
		var p2 := Vector2(draw_pos.x + vert2.x
								+ p2_xform_draw_x.z # p2_z_xform
								+ p2_xform_draw_x.x, # p2_x_xform,
							draw_pos.y
								- p2_xform_draw_x.y #p2_y_xform
					) - offset

		var mouse_factor := max(p1.distance_to(mouse_pos), p2.distance_to(mouse_pos))
		#var alpha_raw := pow(smoothstep(0.0, 200.0, mouse_factor), 0.89)
		#line_color.a = 0.1 + smoothstep(1.0, 0.2, alpha_raw)
		line_color.a = clamp(stepify(pow(smoothstep(0.0, 500.0, mouse_factor), 0.5) * 5.0, 0.5), -100.0, 14.0)

		draw_line(p1,
				  p2,
				  line_color,
				  line_width)


func init_mesh() -> void:
	mdt = MeshDataTool.new()
	nd = get_node('Target')
	var m := nd.get_mesh()
	mdt.create_from_surface(m, 0)
	mdt_edge_count = mdt.get_edge_count()


#section statics


#section classes
