tool
extends Node

export(bool) var reset = false setget _reset
export(int, 0, 5) var level setget set_level
export(float, 0.1, 1.0, 0.1) var height = 1.0 setget set_height
export(Color) var grid_col = Color(1, 1, 1, 0.2) setget set_grid_color

onready var plane = get_node('../Plane') as StaticBody
onready var mesh = get_node('../Plane/Plane') as MeshInstance
onready var grid = ImmediateGeometry.new() as ImmediateGeometry
onready var mat = SpatialMaterial.new() as SpatialMaterial
onready var cam = get_node('../Cam') as MeshInstance

var tileset = {}
var axes := Spatial.new()
var _size := 24 setget _set_size

func set_grid_color(col):
	grid_col = col
	mat.albedo_color = col

func _set_size(_s):
	_size = _s
	if grid != null: draw_grid()
	
func set_level(val):
	level = val
	if grid != null: draw_grid()
	if cam != null: cam._trans.y = level
		
func _reset(_a):
	if grid != null: draw_grid()

func set_height(val):
	height = val
	if grid != null: draw_grid()

func draw_axes() -> void:
	var axis := ImmediateGeometry.new()
	axis.cast_shadow = false
	var x_axis : ImmediateGeometry = axis.duplicate(); var y_axis : ImmediateGeometry = axis.duplicate(); var z_axis : ImmediateGeometry = axis.duplicate()
	var _mat := SpatialMaterial.new()
	_mat.flags_unshaded = true
	_mat.flags_transparent = true
	_mat.render_priority = 2
	var x_mat : SpatialMaterial = _mat.duplicate(); var y_mat : SpatialMaterial = _mat.duplicate(); var z_mat : SpatialMaterial = _mat.duplicate()
	x_mat.albedo_color = Color(1, 0, 0, 0.6); y_mat.albedo_color = Color(0, 1, 0, 0.6); z_mat.albedo_color = Color(0, 0, 1, 0.6)
	var x; var y; var z
	add_child(axes)
	axes.name = 'Axes'
	for i in range(3):
		var cur_ax = null
		match i:
			0:
				cur_ax = x_axis
				cur_ax.set_material_override(x_mat)
				x = 50; y = 0; z = 0
			1:
				cur_ax = y_axis
				cur_ax.set_material_override(y_mat)
				y_mat.render_priority = 4
				x = 0; y = 50; z = 0
			2:
				cur_ax = z_axis
				cur_ax.set_material_override(z_mat)
				x = 0; y = 0; z = 50
		cur_ax.clear()
		cur_ax.begin(Mesh.PRIMITIVE_LINES)
		cur_ax.add_vertex(Vector3(-x, -y, -z))
		cur_ax.add_vertex(Vector3(x, y, z))
		cur_ax.end()
		axes.add_child(cur_ax, true)

func _ready():
	plane.scale = Vector3(float(_size)/2, 1, float(_size)/2)
	add_child(grid)
	grid.name = 'Grid'
	grid.set_material_override(mat)
	mat.albedo_color = grid_col
	grid.cast_shadow = false
	mat.flags_unshaded = true
	mat.flags_transparent = true
	draw_grid()
	draw_axes()

func draw_grid():
	grid.clear()
	grid.begin(Mesh.PRIMITIVE_LINES)
	var s = _size
	for i in range(s + 1):
		grid.add_vertex(Vector3(i - s/2, level, -s/2))
		grid.add_vertex(Vector3(i - s/2, level,  s/2))
		grid.add_vertex(Vector3(-s/2, level , i -s/2))
		grid.add_vertex(Vector3( s/2, level , i -s/2))
	grid.end()
	plane.translation.y = level
	
