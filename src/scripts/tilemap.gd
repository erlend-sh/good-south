extends Node

const LEFT := 0
const FORWARD := 1
const RIGHT := 2
const BACK := 3

const TILE_NODE := 0
const TILE_NAME := 1
const TILE_IND := 2
const TILE_ROT := 3
const TILE_NEIGHS := 4

const CORNER = 0
const EDGE = 1
const MIDDLE = 2
const SOLO = 3
const SOLO_EDGE = 4
const SOLO_MIDDLE = 5

const _dirs := [Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK]

export(bool) var reset = false setget _reset
export(int, 0, 5) var level setget set_level
export(float, 0.1, 1.0, 0.1) var height = 1.0 setget set_height
export(Color) var grid_col = Color(1, 1, 1, 0.2) setget set_grid_color
export(bool) var can_draw = true


onready var tiles_scene = preload('res://assets/scenes/Packed/Tiles.tscn').instance()
onready var plane_tile = preload('res://assets/meshes/TileIndecator.mesh')

onready var plane = get_node('Plane') as StaticBody
onready var mesh = get_node('Plane/Plane') as MeshInstance
onready var grid = ImmediateGeometry.new() as ImmediateGeometry
onready var mat = SpatialMaterial.new() as SpatialMaterial
onready var cam_gizmo = get_node('Cam') as MeshInstance
onready var cam = get_node('Cam/3dCam') as Camera
onready var ray = get_node('RayCast') as RayCast
onready var tile_ind = get_node('TileIndecator') as MeshInstance
onready var tile_label = get_node('../../../Left/Tile') as Label
onready var tiles_node = get_node('Tiles') as Spatial
onready var view_gizmo = get_node('../../../TopRight/Gizmo/Viewport/Cam') as Spatial
onready var UI = get_tree().get_root().get_node('UI') as MarginContainer

var tileset = {}
var axes := Spatial.new()
var _size := 24 setget _set_size
var is_motion := false
var is_draw = false
var is_erase = false
var is_rot := false
var rot_spd := 0.4
var shift_pr := false
var ray_length := 10000
var is_pan := false
var tile_pos := Vector3.ZERO
var last_pos := Vector3.ZERO
var cur_ind_pos := Vector3.ZERO
var last_ind_pos := Vector3.ZERO
var mouse_out := false
var has_backup := false
var tiles_backup := {}
var cur_neighs := [false, false, false, false]
var _translation := Vector3.ZERO
var _rotation := Vector3(-45, 0, 0)
var cur_tile_name := ''
var tiles = {}
var cur_layer := 0
var sorted_layers := []
var layers := {
	'layer000': {
		'tiles': {},
		'visible': true
	}
}

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

func _ready():
	import_tiles(tiles_scene)
	
	#draw_grid
	plane.scale = Vector3(float(_size)/2 - 0.01, 1, float(_size)/2 - 0.01)
	add_child(grid)
	grid.name = 'Grid'
	grid.set_material_override(mat)
	mat.albedo_color = grid_col
	grid.cast_shadow = false
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.render_priority = 10
	draw_grid()
	draw_axes()
	sort_layers()

	for _node in get_tree().get_nodes_in_group('UI'):
		_node.connect('mouse_entered', self, '_on_UI_mouse_enter_exit', [true])
		_node.connect('mouse_exited', self, '_on_UI_mouse_enter_exit', [false])
	cam_gizmo.translation.y = level * height
	_rotation = cam_gizmo.rotation_degrees
	_translation = cam_gizmo.translation
	call_deferred('update_ind')
	view_gizmo.set_deferred('rotation_degrees', cam_gizmo.rotation_degrees)
#END

func layer_is_visible(_layer := cur_layer) -> bool:
	return true if layers[sorted_layers[_layer]]['visible'] else false
#END

func get_tiles(_layer : int) -> Dictionary:
	sort_layers()
	return layers[sorted_layers[_layer]]['tiles']
#END

func has_tile(_tile_pos : Vector3, _layer : int) -> bool:
	return true if get_tiles(_layer).has(_tile_pos) else false
#END

func has_same_tile(_tile_pos1 : Vector3, _tile_pos2 : Vector3, _layer : int) -> bool:
	if has_tile(_tile_pos1, _layer) && has_tile(_tile_pos2, _layer):
		if get_tiles(_layer)[_tile_pos1][TILE_NAME] == get_tiles(_layer)[_tile_pos2][TILE_NAME]:
			return true
		else:
			return false
	else:
		return false
#END

# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors]
func draw_tile(_tile_pos : Vector3, _layer : int, _tile_name : String, inc_ind := false):
	if has_tile(_tile_pos, _layer):
		var _tiles = get_tiles(_layer)
		if _tiles[_tile_pos][TILE_NAME] == _tile_name:
			return
		else:
			var _name = _tiles[_tile_pos][TILE_NAME]
			var _neighs = []
			for i in 4:
				if has_same_tile(_tile_pos, _tile_pos + _dirs[i], _layer):
					_neighs.append(_tile_pos + _dirs[i])
			if _neighs.size() > 0:
				for i in _neighs.size():
					erase_tile(_neighs[i], _layer)
					draw_tile(_neighs[i], _layer, _name)
			erase_tile(_tile_pos, _layer)
	var _tiles = get_tiles(_layer)
	var _data = get_tile_data(get_neighs(_tile_pos, _layer, _tile_name, inc_ind), _tile_name)
	tiles_node.add_child(_data[TILE_NODE])
	_data[TILE_NODE].translation = get_tile_pos(_tile_pos)
	_data[TILE_NODE].rotation_degrees.y = _data[TILE_ROT]
	_data[TILE_NEIGHS] = get_neighs(_tile_pos, _layer, _tile_name, inc_ind)
	get_tiles(_layer)[_tile_pos] = _data
#END

func erase_tile(_tile_pos: Vector3, _layer := cur_layer):
	if has_tile(_tile_pos, _layer):
		var _tiles = get_tiles(_layer)
		var _name = _tiles[_tile_pos][TILE_NAME]
		_tiles[_tile_pos][TILE_NODE].queue_free()
		_tiles.erase(_tile_pos)
		if _name != cur_tile_name:
			backup(tile_pos, _name)
			restore_backup(_name)
#END

func sort_layers():
	sorted_layers = layers.keys()
	sorted_layers.sort()
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
		if has_tile(_neigh, _layer) && _tiles[_neigh][TILE_NAME] == _tile_name:
			_neighs[i] = true
			continue
		if include_ind:
			if _neigh == tile_pos && _tile_name == cur_tile_name:
				_neighs[i] = true
	return _neighs
#END

# update tile indecator mesh and rotation
func update_ind(_layer := cur_layer) -> void:
	var _neighs = get_neighs(tile_pos, _layer)
	var _data = get_tile_data(_neighs)
	tile_ind.mesh = _data[TILE_NODE].mesh
	tile_ind.scale.y = 1.0
	_data[TILE_NODE].queue_free()
	tile_ind.rotation_degrees.y = _data[TILE_ROT]
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

# get_tile_data(get_neighs(tile_pos, _layer, _tileset_name), _tileset_name) -> ['mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors]
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


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('shift'):
		shift_pr = true
	if Input.is_action_just_released('shift'):
		shift_pr = false
	if event is InputEventMouseButton:
		if((!is_draw && !is_erase) && (!is_rot && !is_pan)):
			if event.button_index == BUTTON_WHEEL_UP || event.button_index == BUTTON_WHEEL_DOWN:
				if event.button_index == BUTTON_WHEEL_UP && cam.translation.z > 3:
					cam.translation.z -= 1
				if event.button_index == BUTTON_WHEEL_DOWN && cam.translation.z < 40:
					cam.translation.z += 1

		if event.button_index == BUTTON_LEFT && (can_draw && !is_erase):
			if event.is_pressed():
				if layer_is_visible():
					if !is_rot && !is_pan && tile_ind.visible == true:
						is_draw = true
						_on_left_pressed()
			else:
				if is_draw:
					is_draw = false
					restore_backup()
					#draw_tile(tile_pos, cur_layer, cur_tile_name)
		if event.button_index == BUTTON_RIGHT && (can_draw && !is_draw):
			if event.is_pressed():
				if layer_is_visible():
					if !is_rot && !is_pan && tile_ind.visible == true:
						is_erase = true
						_on_right_pressed()
			else:
				if is_erase:
					is_erase = false
					if layer_is_visible():
						clean_backup()
						update_ind()
						if tile_ind.visible:
							backup(tile_pos, cur_tile_name, true)

		if event.button_index == BUTTON_MIDDLE:
			if event.is_pressed() && (!is_draw && !is_erase):
				can_draw = false
				clean_backup()
				backup()
				if !shift_pr:
					is_rot = true
					tile_ind.hide()
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					is_pan = true
					tile_ind.hide()
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				can_draw = true
				is_rot = false
				is_pan = false
				tile_ind.visible = true if can_draw else false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseMotion:
		is_motion = true
		var _motion = event.relative
		if is_pan:
			_translation -= ((cam_gizmo.transform.basis.z - cam_gizmo.transform.basis.y) * _motion.y + cam_gizmo.transform.basis.x * _motion.x) * 0.01
			_translation.x = clamp(_translation.x, -_size/2, _size/2)
			_translation.z = clamp(_translation.z, -_size/2, _size/2)
			_translation.y = level * height
		if is_rot:
			_rotation.y -= _motion.x * rot_spd
			_rotation.x -= _motion.y * rot_spd
			_rotation.x = clamp(_rotation.x, -90, 90)
	else:
		is_motion = false
#END

func _on_left_pressed():
	if layer_is_visible():
		restore_backup()
		draw_tile(tile_pos, cur_layer, cur_tile_name)
		backup(tile_pos, cur_tile_name, true)
#END


func _on_right_pressed():
	if layer_is_visible():
		var _name := ''
		tile_ind.mesh = plane_tile
		tile_ind.scale.y = height
		restore_backup()
		erase_tile(tile_pos, cur_layer)
		backup()
#END



func backup(_tile_pos:= tile_pos, _tile_name:= cur_tile_name, _inc_ind:= false):
	for i in 4:
		var _neigh = _tile_pos + _dirs[i]
		var _tiles = get_tiles(cur_layer)
		if has_tile(_neigh, cur_layer):
			if _tiles[_neigh][TILE_NAME] == _tile_name:
				var _neighs = get_neighs(_neigh, cur_layer, _tiles[_neigh][TILE_NAME], _inc_ind)
				var _data = get_tile_data(_neighs, _tile_name)
				tiles_backup[_neigh] = [_tiles[_neigh][TILE_NODE].mesh, _tiles[_neigh][TILE_NODE].rotation_degrees.y]
				_tiles[_neigh][TILE_NODE].mesh = _data[TILE_NODE].mesh
				_data[TILE_NODE].queue_free()
				_tiles[_neigh][TILE_NODE].rotation_degrees.y = _data[TILE_ROT]
	if tiles_backup.keys().size() > 0:
		has_backup = true
#END

func clean_backup():
	if has_backup:
		for _key in tiles_backup.keys():
			get_tiles(cur_layer)[_key][TILE_NODE].mesh = tiles_backup[_key][0]
			tiles_backup[_key][0] = null
			get_tiles(cur_layer)[_key][TILE_NODE].rotation_degrees.y = tiles_backup[_key][1]
		tiles_backup.clear()
		has_backup = false
#END

func restore_backup(_name := cur_tile_name):
	if has_backup:
		var _tiles = get_tiles(cur_layer)
		for _key in tiles_backup.keys():
			erase_tile(_key, cur_layer)
			draw_tile(_key, cur_layer, _name, true)
		tiles_backup.clear()
		has_backup = false
#END

func erase_gaps() -> void:
	#Thanks to pixelorama ^
	var dist_x := int(abs(tile_pos.x - last_pos.x))
	var dist_z := int(-abs(tile_pos.z - last_pos.z))
	var err := dist_x + dist_z
	var e2 := err << 1 #err * 2
	var sx = 1 if last_pos.x < tile_pos.x else -1
	var sy = 1 if last_pos.z < tile_pos.z else -1
	var x = last_pos.x
	var z = last_pos.z
	var _last_pos = last_pos
	while !(x == tile_pos.x && z == tile_pos.z):
		var _pos = Vector3(x, tile_pos.y, z)
		if (Vector2(x, z) - Vector2(_last_pos.x, _last_pos.z)).length() >= 1:
			print('aa')
			erase_tile(_last_pos, cur_layer)
			backup(_pos)
		else:
			print('zz')
			erase_tile(last_pos, cur_layer)
			backup(tile_pos)
		erase_tile(_pos)
		restore_backup()
		e2 = err << 1
		if e2 >= dist_z:
			err += dist_z
			x += sx
		if e2 <= dist_x:
			err += dist_x
			z += sy
		_last_pos = _pos
	erase_tile(tile_pos)
#END

func fill_gaps() -> void:
	#Thanks to pixelorama ^
	var dist_x := int(abs(tile_pos.x - last_pos.x))
	var dist_z := int(-abs(tile_pos.z - last_pos.z))
	var err := dist_x + dist_z
	var e2 := err << 1 #err * 2
	var sx = 1 if last_pos.x < tile_pos.x else -1
	var sy = 1 if last_pos.z < tile_pos.z else -1
	var x = last_pos.x
	var z = last_pos.z
	var _last_pos = last_pos
	while !(x == tile_pos.x && z == tile_pos.z):
		var _pos = Vector3(x, tile_pos.y, z)
		if (Vector2(x, z) - Vector2(_last_pos.x, _last_pos.z)).length() >= 1:
			print('aa')
			erase_tile(_last_pos, cur_layer)
			# prints(last_pos, _last_pos)
			draw_tile(_last_pos, cur_layer, cur_tile_name, true)
			backup(_pos, cur_tile_name, true)
			#get_tiles(cur_layer)[_last_pos][TILE_NODE].translation = get_tile_pos(_last_pos)
		else:
			print('zz')
			erase_tile(last_pos, cur_layer)
			draw_tile(last_pos, cur_layer, cur_tile_name, true)
			backup(tile_pos, cur_tile_name, true)
		draw_tile(_pos, cur_layer, cur_tile_name, true)
		restore_backup()
		e2 = err << 1
		if e2 >= dist_z:
			err += dist_z
			x += sx
		if e2 <= dist_x:
			err += dist_x
			z += sy
		_last_pos = _pos
	update_ind()
	draw_tile(tile_pos, cur_layer,cur_tile_name)
#END

func _process(delta: float) -> void:
	if is_motion:
		_on_update(delta)
	if cam_gizmo != null:
		if !_translation.is_equal_approx(cam_gizmo.translation):
			cam_gizmo.translation += (_translation - cam_gizmo.translation) * 0.6
		if !_rotation.is_equal_approx(cam_gizmo.rotation_degrees):
			cam_gizmo.rotation_degrees.y += (_rotation.y - cam_gizmo.rotation_degrees.y) * 0.1
			cam_gizmo.rotation_degrees.x += (_rotation.x - cam_gizmo.rotation_degrees.x) * 0.1
			view_gizmo.rotation_degrees = cam_gizmo.rotation_degrees
#END

func _on_update(delta : float):
	var mouse = get_parent().get_mouse_position()
	var from = cam.project_ray_origin(mouse)
	var to = from + cam.project_ray_normal(mouse) * ray_length
	ray.cast_to = to
	ray.translation = from
	if can_draw:
		if ray.is_colliding() && (!is_rot && !is_pan):
			var _pos = ray.get_collision_point().floor()
			_pos.y = level * height
			_pos.x += 0.5
			_pos.z += 0.5
			tile_ind.translation = _pos
			tile_pos = _pos + Vector3(_size/2 - 0.5, 0, _size/2 - 0.5)
			tile_label.text = 'Tile %s' % tile_pos
			if !tile_ind.visible:	
				tile_ind.show()
				last_pos = tile_pos
				if is_draw:
					print('draw')
					update_ind()
					backup(tile_pos, cur_tile_name, true)
					draw_tile(tile_pos, cur_layer, cur_tile_name)
					restore_backup()
				elif is_erase:
					print('erase')
					tile_ind.mesh = plane_tile
					erase_tile(tile_pos)
					backup(tile_pos, cur_tile_name)
					#restore_backup()
				else:
					print('move')
					update_ind()
					backup(tile_pos, cur_tile_name, true)
		else:
			if tile_ind.visible:
				tile_ind.hide()
				if is_erase:
					backup(last_pos)
					#restore_backup()
					print('erase2')
				else:
					restore_backup()
					backup(last_pos)
					print('move2')

				tile_label.text = 'Tile Null'
	#ON tile mouse enter
	if last_pos != tile_pos:
		_on_tile_mouse_enter()
		last_pos = tile_pos
#END

func _on_tile_mouse_enter() -> void:
	if layer_is_visible():
		if is_draw:
			fill_gaps()
		elif is_erase:
			restore_backup()
			erase_gaps()
			backup()
		else: #is move
			update_ind()
			restore_backup()
			backup(tile_pos, cur_tile_name, true)
#END

func _on_UI_mouse_enter_exit(entered: bool) -> void:
	can_draw = false if entered else true
	if entered:
		is_draw = false
		is_erase = false
		clean_backup()
#END

func set_grid_color(col):
	if mat != null:
		grid_col = col
		mat.albedo_color = col
#END

func _set_size(_s):
	_size = _s
	if grid != null: draw_grid()
#END

func set_level(val):
	level = val
	if grid != null: draw_grid()
	_translation.y = level * height
#END

func _reset(_a):
	if grid != null: draw_grid()
#END

func set_height(val):
	height = val
	if grid != null: draw_grid()
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

func draw_grid():
	grid.clear()
	grid.begin(Mesh.PRIMITIVE_LINES)
	var s = _size
	for i in s + 1:
		grid.add_vertex(Vector3(i - s/2, level * height + 0.005, -s/2))
		grid.add_vertex(Vector3(i - s/2, level * height+ 0.005,  s/2))
		grid.add_vertex(Vector3(-s/2, level * height+ 0.005, i -s/2))
		grid.add_vertex(Vector3( s/2, level * height+ 0.005, i -s/2))
	grid.end()
	plane.translation.y = level * height + 0.005
#END

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
