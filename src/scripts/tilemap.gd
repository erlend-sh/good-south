extends Node

const _dirs := [Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK]
const LEFT        := 0
const FORWARD     := 1
const RIGHT       := 2
const BACK        := 3

const TILE_NODE   := 0
const TILE_NAME   := 1
const TILE_IND    := 2
const TILE_ROT    := 3
const TILE_NEIGHS := 4

const CORNER      := 0
const EDGE        := 1
const MIDDLE      := 2
const SOLO        := 3
const SOLO_EDGE   := 4
const SOLO_MIDDLE := 5

const ERASE_FILL  := 0
const DRAW_FILL   := 1

export(float, 0.1, 1.0, 0.1) var height = 0.5 setget set_height

onready var tiles_scene = preload('res://assets/scenes/Packed/Tiles.tscn').instance()
onready var plane_tile  = preload('res://assets/meshes/TileIndecator.mesh')

onready var plane      = get_node('Plane')                                as StaticBody
onready var mesh       = get_node('Plane/Plane')                          as MeshInstance
onready var cam        = get_node('Cam')                                  as MeshInstance
onready var tile_ind   = get_node('TileIndecator')                        as MeshInstance
onready var grid       = ImmediateGeometry.new()                          as ImmediateGeometry
onready var tiles_node = get_node('Tiles')                                as Spatial
onready var view_gizmo = get_node('../../../TopRight/Gizmo/Viewport/Cam') as Spatial
onready var mat        = SpatialMaterial.new()                            as SpatialMaterial
onready var tile_label = get_node('../../../Left/Tile')                   as Label
onready var UI         = get_tree().get_root().get_node('UI')             as MarginContainer

var _size         := 24 setget _set_size
var level         := 0 setget set_level
var axes          := Spatial.new()
var grid_col      := Color(1, 1, 1, 0.2)
var cur_ind_pos   := Vector3.ZERO
var last_ind_pos  := Vector3.ZERO
var mouse_out     := false
var has_backup    := false
var tileset       := {}
var tiles_backup  := {}
var tiles         := {}
var cur_tile_name := ''
var cur_layer     := 0
var sorted_layers := []

var layers := {
	'layer000': {
		'tiles': {},
		'visible': true
	}
}

func _ready():
	import_tiles(tiles_scene)
	init_grid()
	draw_grid()
	draw_axes()
	sort_layers()
	view_gizmo.rotation_degrees = cam.rotation_degrees
#END

# {'sand': [solo, corner, ...]}
func import_tiles(_scene : Spatial):
	for _child in _scene.get_children():
		if _child.get_index() == 0:
			cur_tile_name = _child.name
		if _child.get_child_count() > 0:
			var _node := []
			for _sub in _child.get_children():
				_node.append(_sub.duplicate())
			tiles[_child.name] = _node
	_scene.queue_free()
#END

func init_grid():
	plane.scale = Vector3(float(_size)/2 - 0.01, 1, float(_size)/2 - 0.01)
	add_child(grid)
	grid.name = 'Grid'
	grid.set_material_override(mat)
	mat.albedo_color = grid_col
	grid.cast_shadow = false
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.render_priority = 10
#END

func draw_grid():
	grid.clear()
	grid.begin(Mesh.PRIMITIVE_LINES)
	var s = _size
	for i in s + 1:
		grid.add_vertex(Vector3(i - s/2, level * height + 0.005, -s/2))
		grid.add_vertex(Vector3(i - s/2, level * height + 0.005,  s/2))
		grid.add_vertex(Vector3(-s/2, level * height + 0.005, i -s/2))
		grid.add_vertex(Vector3( s/2, level * height + 0.005, i -s/2))
	grid.end()
	plane.translation.y = level * height + 0.005
#END

func draw_axes() -> void:
	var axis := ImmediateGeometry.new()
	axis.cast_shadow = false
	var x_axis := axis.duplicate(); var y_axis := axis.duplicate(); var z_axis := axis.duplicate()
	var _mat := SpatialMaterial.new()
	_mat.flags_unshaded = true
	_mat.flags_transparent = true
	_mat.render_priority = 2
	var x; var y; var z
	add_child(axes)
	axes.name = 'Axes'
	for i in 2:
		var cur_ax = null
		var _cur_mat =  _mat.duplicate()
		match i:
			0:
				cur_ax = x_axis
				_cur_mat.albedo_color = Color(1, 0, 0, 0.6)
				cur_ax.set_material_override(_cur_mat)
				_cur_mat.render_priority = 20
				x = 50; y = 0.005; z = 0
			1:
				cur_ax = z_axis
				_cur_mat.albedo_color = Color(0, 0, 1, 0.6)
				cur_ax.set_material_override(_cur_mat)
				_cur_mat.render_priority = 20
				x = 0; y = 0.005; z = 50
		cur_ax.clear()
		cur_ax.begin(Mesh.PRIMITIVE_LINES)
		cur_ax.add_vertex(Vector3(-x, -y, -z))
		cur_ax.add_vertex(Vector3(x, y, z))
		cur_ax.end()
		axes.add_child(cur_ax, true)
#END

func sort_layers():
	sorted_layers = layers.keys()
	sorted_layers.sort()
#END

# updates tile_indecator[mesh & rotation] for live updates while moving
func update_ind(_layer := cur_layer) -> void:
	var _data = get_tile_data( get_neighs(cam.tile_pos, _layer) )
	tile_ind.mesh = _data[TILE_NODE].mesh
	tile_ind.scale.y = 1.0
	tile_ind.rotation_degrees.y = _data[TILE_ROT]
	_data[TILE_NODE].free()
#END

# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors]
func draw_tile(_tile_pos : Vector3, _layer := cur_layer, _tile_name := cur_tile_name, inc_ind := false):
	var _tiles = get_tiles(_layer)
	if has_tile(_tile_pos, _tiles, _layer):
		if _tiles[_tile_pos][TILE_NAME] == _tile_name:
			return
		else: #has different tile
			var _name = _tiles[_tile_pos][TILE_NAME]
			var _neighs = []
			for i in 4:
				var _neigh = _tile_pos + _dirs[i]
				if has_tile(_neigh):
					if _tiles[_neigh][TILE_NAME] == _name:
						_neighs.append(_neigh)
			erase_tile(_tile_pos, _layer)
			if _neighs.size() > 0:
				for i in _neighs.size():
					update_tile(_neighs[i], _name)
	var _data = get_tile_data(get_neighs(_tile_pos, _layer, _tile_name, inc_ind), _tile_name)
	tiles_node.add_child(_data[TILE_NODE])
	_data[TILE_NODE].translation = get_tile_pos(_tile_pos)
	_data[TILE_NODE].rotation_degrees.y = _data[TILE_ROT]
	_data[TILE_NEIGHS] = get_neighs(_tile_pos, _layer, _tile_name, inc_ind)
	get_tiles(_layer)[_tile_pos] = _data
	_tiles = get_tiles(_layer)
	for i in 4:
		var _neigh = _tile_pos + _dirs[i]
		if has_tile(_neigh):
			if _tiles[_neigh][TILE_NAME] == _tile_name:
				update_tile(_neigh)
#END

func erase_tile(_tile_pos: Vector3, _layer := cur_layer):
	var _tiles = get_tiles(_layer)
	var _neighs := []
	if has_tile(_tile_pos, _tiles, _layer):
		var _name = _tiles[_tile_pos][TILE_NAME]
		_tiles[_tile_pos][TILE_NODE].queue_free()
		_tiles.erase(_tile_pos)
		_tiles = get_tiles(_layer)
		for i in 4:
			var _neigh = _tile_pos + _dirs[i]
			if has_tile(_neigh):
				if _tiles[_neigh][TILE_NAME] == _name:
					_neighs.append(_neigh)
		if _neighs.size() > 0:
			for _n in _neighs:
				update_tile(_n)
#END

func update_tile(_tile_pos : Vector3, _tile_name := cur_tile_name):
	var _tiles = get_tiles(cur_layer)
	var _neighs = get_neighs(_tile_pos, cur_layer, _tile_name)
	var _data = get_tile_data(_neighs, _tile_name)
	_tiles[_tile_pos][TILE_NODE].mesh = _data[TILE_NODE].mesh
	_tiles[_tile_pos][TILE_NODE].rotation_degrees.y = _data[TILE_ROT]
	_tiles[_tile_pos][TILE_ROT] = _data[TILE_ROT]
	_tiles[_tile_pos][TILE_IND] = _data[TILE_IND]
	_tiles[_tile_pos][TILE_NEIGHS] = _neighs
	_data[TILE_NODE].free()
#END

func fill_gaps(_mode : int) -> void:
	#Thanks to pixelorama ^
	var dist_x := int(abs(cam.tile_pos.x - cam.last_pos.x))
	var dist_z := int(-abs(cam.tile_pos.z - cam.last_pos.z))
	var err := dist_x + dist_z
	var e2 := err << 1 #err * 2
	var sx = 1 if cam.last_pos.x < cam.tile_pos.x else -1
	var sy = 1 if cam.last_pos.z < cam.tile_pos.z else -1
	var x = cam.last_pos.x
	var z = cam.last_pos.z
	var _last_pos = cam.last_pos
	while !(x == cam.tile_pos.x && z == cam.tile_pos.z):
		var _pos = Vector3(x, cam.tile_pos.y, z)
		if _mode == DRAW_FILL:
			draw_tile(_pos)
		else:
			erase_tile(_pos)
		e2 = err << 1
		if e2 >= dist_z:
			err += dist_z
			x += sx
		if e2 <= dist_x:
			err += dist_x
			z += sy
		_last_pos = _pos
#END

func layer_is_visible(_layer := cur_layer) -> bool:
	return layers[sorted_layers[_layer]]['visible']
#END

func has_tile(_tile_pos : Vector3, _tiles:= {}, _layer:= cur_layer) -> bool:
	if _tiles.keys().size() == 0:
		_tiles = get_tiles(_layer)
	return _tiles.has(_tile_pos)
#END

###### SetGet ######

func set_height(val):
	height = val
	if grid != null: draw_grid()
#END

func _set_size(_s):
	_size = _s
	if grid != null: draw_grid()
#END

func set_level(val):
	level = val
	if grid != null:
		draw_grid()
	if cam != null:
		cam._pos.y = level * height
#END

func get_tiles(_layer : int) -> Dictionary:
	return layers[sorted_layers[_layer]]['tiles']
#END

func get_tile_pos(_tile : Vector3) -> Vector3:
	var _s = (_size / 2) - 0.5
	return _tile - Vector3(_s, 0, _s)
#END

# get_neighs(_pos, _layer, _tileset_name, include_ind?) -> [false, false, false, false]
func get_neighs(_tile_pos : Vector3, _layer := cur_layer,_tile_name := cur_tile_name, include_ind := false) -> Array:
	var _neighs = [false, false, false, false]
	var _tiles = get_tiles(_layer)
	for i in 4:
		var _neigh = _tile_pos + _dirs[i]
		if has_tile(_neigh, _tiles, _layer):
			if _tiles[_neigh][TILE_NAME] == _tile_name:
				_neighs[i] = true
				continue
			if include_ind:
				if _neigh == cam.tile_pos && _tiles[_neigh][TILE_NAME] == _tile_name:
					_neighs[i] = true
	return _neighs
#END

# get_tile_data(get_neighs(cam.tile_pos, _layer, _tileset_name), _tileset_name) -> ['mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors]
func get_tile_data(_neighs : Array, _tileset := cur_tile_name) -> Array:
	# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors(Updated)]
	var _data := [ null, 'tileset', 'name', 0]
	match _neighs:
		# case one
		[true, false, false, false]: # has left neigh
			_data = solo_edge(_tileset, 0)
		[false, false, false, true]: # has back neigh
			_data = solo_edge(_tileset, 90)
		[false, false, true, false]: # has right neigh 
			_data = solo_edge(_tileset, 180)
		[false, true, false, false]: # has forward neigh
			_data = solo_edge(_tileset, -90)	
		# case two
		[true, true, false, false]: # has left and forward neighs
			_data = corner(_tileset, 0)
		[true, false, false, true]: # has left and back neighs
			_data = corner(_tileset, 90)
		[false, false, true, true]: # has right and back neighs
			_data = corner(_tileset, 180)
		[false, true, true, false]: # has forward and right neighs
			_data = corner(_tileset, -90)
		[true, false, true, false]: # has left and right neighs
			_data = solo_middle(_tileset, 0)
		[false, true, false, true]: # has forward and back neighs
			_data = solo_middle(_tileset, 90)
		# case three
		[true, true, false, true]: # has left, forward and back neighs
			_data = edge(_tileset, 0)
		[true, false, true, true]: # has left, right and back neighs
			_data = edge(_tileset, 90)
		[false, true, true, true]: # has forward, right and back neighs
			_data = edge(_tileset, 180)
		[true, true, true, false]: # has left, right and forward neighs
			_data = edge(_tileset, -90)
		# case four
		[true, true, true, true]: # has all neighs
			_data[TILE_NODE] = tiles[_tileset][MIDDLE].duplicate()
			_data[TILE_NAME] = _tileset
			_data[TILE_IND] = 'middle'
			_data[TILE_ROT] = 0
		_: # has no neighbors
			_data[TILE_NODE] = tiles[_tileset][SOLO].duplicate()
			_data[TILE_NAME] = _tileset
			_data[TILE_IND] = 'solo'
			_data[TILE_ROT] = 0
	_data.append(_neighs)
	return _data
#END

# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors]
func solo_edge(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(tiles[_tile_name][SOLO_EDGE].duplicate())
	_arr.append(_tile_name)
	_arr.append('solo_edge')
	_arr.append(_rot)
	return _arr
#END

func corner(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(tiles[_tile_name][CORNER].duplicate())
	_arr.append(_tile_name)
	_arr.append('corner')
	_arr.append(_rot)
	return _arr
#END

func solo_middle(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(tiles[_tile_name][SOLO_MIDDLE].duplicate())
	_arr.append(_tile_name)
	_arr.append('solo_middle')
	_arr.append(_rot)
	return _arr
#END

func edge(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(tiles[_tile_name][EDGE].duplicate())
	_arr.append(_tile_name)
	_arr.append('edge')
	_arr.append(_rot)
	return _arr
#END

###### Events ######

func _on_change_level(_val : int) -> void:
	set_level(_val)
#END

func _on_Grid_toggled(_pressed: bool) -> void:
	grid.visible = _pressed
	plane.visible = _pressed
#END

func _on_axis_toggle(_pressed: bool, _ind: int) -> void:
	axes.get_child(_ind).visible = _pressed
#END

func _on_change_height(_val : float) -> void:
	set_height(_val)
#END

func _on_UI_mouse_enter_exit(entered: bool) -> void:
	cam.can_draw = !entered
	if entered:
		if cam.is_draw || cam.is_erase:
			cam.is_draw = false
			cam.is_erase = false
#END

func _on_tile_mouse_enter() -> void:
	tile_ind.translation = get_tile_pos(cam.tile_pos)
	if cam.is_draw:
		fill_gaps(DRAW_FILL)
		draw_tile(cam.tile_pos)
	elif cam.is_erase:
		fill_gaps(ERASE_FILL)
		erase_tile(cam.tile_pos)
	else:
		update_ind()
#END

func _on_left_pressed():
	draw_tile(cam.tile_pos)
	tile_ind.hide()
#END

func _on_left_released():
	tile_ind.show()
#END

func _on_right_pressed():
	erase_tile(cam.tile_pos)
	tile_ind.mesh = plane_tile
	tile_ind.scale.y = height
#END

func _on_right_released():
	update_ind()
#END

func ray_is_colliding():
	tile_label.text = 'Tile %s' % cam.tile_pos
	if !tile_ind.visible:	
		tile_ind.show()
		cam.last_pos = cam.tile_pos
#END

func ray_not_colliding():
	if tile_ind.visible:
		tile_ind.hide()
		tile_label.text = 'Tile Null'
#END
