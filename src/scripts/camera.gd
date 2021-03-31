extends MeshInstance

const LEFT := 0
const FORWARD := 1
const RIGHT := 2
const BACK := 3
const CUR_TILE_NODE := 0
const TILE_NAME := 1
const CUR_TILE := 2
const CUR_TILE_ROT := 3
const NEIGHBORS := 4
const _dirs := [Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK]

onready var cam = get_node('3dCam') as Camera
onready var tilemap = get_node('../TileMap3D') as Node
onready var ray = get_node('../RayCast') as RayCast
onready var tile_ind = get_node('../TileIndecator') as MeshInstance
onready var cam_gizmo = get_node('../CanvasLayer/UI/Viewport/Viewport/Cam') as Spatial
onready var tile_label = get_node('../CanvasLayer/UI/VBox/Tile') as Label

export(bool) var can_draw = true

var is_motion := false
var is_draw = false
var is_erase = false
var is_rot := false
var rot_spd := 0.1
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

func _ready() -> void:
	G.cam = self
	translation.y = tilemap.level
	call_deferred('update_ind', G.cur_layer)

func get_tiles(_layer : int) -> Dictionary:
	G.sort_layers()
	return G.layers[G.sorted_layers[_layer]]['tiles']

func has_tile(_tile_pos : Vector3, _layer : int) -> bool:
	return true if get_tiles(_layer).has(_tile_pos) else false

func has_same_tile(_tile_pos1 : Vector3, _tile_pos2 : Vector3, _layer : int) -> bool:
	if has_tile(_tile_pos1, _layer) && has_tile(_tile_pos2, _layer):
		if get_tiles(_layer)[_tile_pos1][TILE_NAME] == get_tiles(_layer)[_tile_pos2][TILE_NAME]:
			return true
		else:
			return false
	else:
		return false

# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors(Updated)]
func draw_tile(_tile_pos : Vector3, _layer : int, inc_ind := false):
	if has_tile(_tile_pos, _layer):
		if get_tiles(_layer)[_tile_pos][TILE_NAME] == G.cur_tile_name:
			return
	var _tiles = get_tiles(_layer)
	var _data = get_tile_data(get_neighs(_tile_pos, _layer, G.cur_tile_name, inc_ind), G.cur_tile_name)
	tilemap.add_child(_data[CUR_TILE_NODE])
	_data[CUR_TILE_NODE].translation = get_tile_pos(_tile_pos)
	_data[CUR_TILE_NODE].rotation_degrees.y = _data[CUR_TILE_ROT]
	_data[NEIGHBORS] = get_neighs(_tile_pos, _layer, G.cur_tile_name, inc_ind)
	get_tiles(_layer)[_tile_pos] = _data

func get_tile_pos(_tile : Vector3) -> Vector3:
	return _tile - Vector3(11.5 , 0, 11.5)

func erase_tile(_tile_pos: Vector3, _layer := G.cur_layer):
	if has_tile(_tile_pos, _layer):
		var _tiles = get_tiles(_layer)
		_tiles[_tile_pos][CUR_TILE_NODE].free()
		#warning-ignore:return_value_discarded
		_tiles.erase(_tile_pos)

# get_neighs(_pos, _layer, _tileset_name, include_ind?) -> [false, false, false, false]
func get_neighs(_tile_pos : Vector3, _layer : int,_tile_name : String, include_ind := false) -> Array:
	var _neighs = [false, false, false, false]
	var _tiles = get_tiles(_layer)
	for i in range(4):
		var _neigh = _tile_pos + _dirs[i]
		if has_tile(_neigh, _layer) && _tiles[_neigh][TILE_NAME] == _tile_name:
			_neighs[i] = true
			continue
		if include_ind && _neigh == tile_pos:
			if _tile_name == G.cur_tile_name:
				_neighs[i] = true
	return _neighs

# update tile indecator mesh and rotation
func update_ind(_layer : int) -> void:
	var _neighs = get_neighs(tile_pos, _layer, G.cur_tile_name)
	var _data = get_tile_data(_neighs, G.cur_tile_name)
	tile_ind.mesh = _data[0].mesh
	tile_ind.rotation_degrees.y = _data[3]

# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors(Updated)]
func solo_edge(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(G.tiles[_tile_name][G.SOLO_EDGE].duplicate())
	_arr.append(_tile_name)
	_arr.append('solo_edge')
	_arr.append(_rot)
	return _arr

func corner(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(G.tiles[_tile_name][G.CORNER].duplicate())
	_arr.append(_tile_name)
	_arr.append('corner')
	_arr.append(_rot)
	return _arr

func solo_middle(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(G.tiles[_tile_name][G.SOLO_MIDDLE].duplicate())
	_arr.append(_tile_name)
	_arr.append('solo_middle')
	_arr.append(_rot)
	return _arr

func edge(_tile_name : String , _rot : int) -> Array:
	var _arr = []
	_arr.append(G.tiles[_tile_name][G.EDGE].duplicate())
	_arr.append(_tile_name)
	_arr.append('edge')
	_arr.append(_rot)
	return _arr

# get_tile_data(get_neighs(tile_pos, _layer, _tileset_name), _tileset_name) -> ['mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot', Neighbors]
func get_tile_data(_neighs : Array, _tileset : String) -> Array:
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
			_data[0] = G.tiles[_tileset][G.MIDDLE].duplicate()
			_data[1] = _tileset
			_data[2] = 'middle'
			_data[3] = 0
		_: # has no neighbors
			_data[0] = G.tiles[_tileset][G.SOLO].duplicate()
			_data[1] = _tileset
			_data[2] = 'solo'
			_data[3] = 0
	_data.append(_neighs)
	return _data

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('shift'):
		shift_pr = true

	if Input.is_action_just_released('shift'):
		shift_pr = false

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP || event.button_index == BUTTON_WHEEL_DOWN:
			if event.button_index == BUTTON_WHEEL_UP && cam.translation.z > 3:
				cam.translation.z -= 1
			if event.button_index == BUTTON_WHEEL_DOWN && cam.translation.z < 40:
				cam.translation.z += 1

		if event.button_index == BUTTON_LEFT && can_draw:
			if event.is_pressed():
				if !is_rot && !is_pan && tile_ind.visible == true:
					is_draw = true
					_on_left_pressed()
			else:
				is_draw = false
				backup(true)

		if event.button_index == BUTTON_RIGHT && can_draw:
			if event.is_pressed():
				if !is_rot && !is_pan && tile_ind.visible == true:
					is_erase = true
					_on_right_pressed()
			else:
				clean_backup()
				is_erase = false
				update_ind(G.cur_layer)
				backup()

		if event.button_index == BUTTON_MIDDLE:
			if event.is_pressed():
				can_draw = false
				clean_backup()
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
		var _motion = event.relative
		if is_pan:
			translation -= ((transform.basis.z - transform.basis.y) * _motion.y + transform.basis.x * _motion.x) * 0.01
			translation.x = clamp(translation.x, -tilemap._size/2, tilemap._size/2)
			translation.z = clamp(translation.z, -tilemap._size/2, tilemap._size/2)
			translation.y = tilemap.level
		if is_rot:
			rotation_degrees.y -= _motion.x * rot_spd
			rotation_degrees.x -= _motion.y * rot_spd
			rotation_degrees.x = clamp(rotation_degrees.x, -90 - cam.rotation_degrees.x, 0 - cam.rotation_degrees.x)
		is_motion = true
	else:
		is_motion = false

func _on_left_pressed():
	restore_backup()
	draw_tile(tile_pos, G.cur_layer)
	backup(true)

func _on_right_pressed():
	tile_ind.mesh = G.plane_tile
	erase_tile(tile_pos, G.cur_layer)
	clean_backup()
	backup()

# on mouse movement
func _on_update(delta : float):
	var mouse = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse)
	var to = from + cam.project_ray_normal(mouse) * ray_length
	ray.cast_to = to
	ray.translation = from
	if ray.is_colliding() && (!is_rot && !is_pan):
		can_draw = true
		var _pos = ray.get_collision_point().floor()
		_pos.y = tilemap.level
		_pos.x += 0.5
		_pos.z += 0.5
		tile_ind.show()
		tile_ind.translation = _pos
		tile_pos = _pos + Vector3(tilemap._size/2 - 0.5, 0, tilemap._size/2 - 0.5)
		tile_label.text = 'Tile %s' % tile_pos
	else:
		can_draw = false
		tile_ind.hide()
		tile_label.text = 'Tile Null'
	if !translation.is_equal_approx(translation):
		translation = translation.linear_interpolate(translation, delta * 20)
	if !rotation_degrees.is_equal_approx(rotation_degrees):
		rotation_degrees = rotation_degrees.linear_interpolate(rotation_degrees, delta * 20)
		cam_gizmo.rotation_degrees = rotation_degrees
	#ON tile mouse enter
	if last_pos != tile_pos:
		_on_tile_mouse_enter()
		last_pos = tile_pos


func backup(_inc_ind := false):
	for i in range(4):
		var _neigh = tile_pos + _dirs[i]
		if has_tile(_neigh, G.cur_layer):
			var _tiles = get_tiles(G.cur_layer)
			var _neighs = get_neighs(_neigh, G.cur_layer, G.cur_tile_name, _inc_ind)
			var _data = get_tile_data(_neighs, G.cur_tile_name)
			tiles_backup[_neigh] = [_tiles[_neigh][CUR_TILE_NODE].mesh, _tiles[_neigh][CUR_TILE_NODE].rotation_degrees.y]
			_tiles[_neigh][CUR_TILE_NODE].mesh = _data[CUR_TILE_NODE].mesh
			_tiles[_neigh][CUR_TILE_NODE].rotation_degrees.y = _data[CUR_TILE_ROT]
	if tiles_backup.keys().size() > 0:
		has_backup = true

#cleans the backup 
func clean_backup():
	if has_backup:
		for _key in tiles_backup.keys():
			get_tiles(G.cur_layer)[_key][CUR_TILE_NODE].mesh = tiles_backup[_key][0]
			get_tiles(G.cur_layer)[_key][CUR_TILE_NODE].rotation_degrees.y = tiles_backup[_key][1]
		tiles_backup.clear()
		has_backup = false

func restore_backup():
	if has_backup:
		var _tiles = get_tiles(G.cur_layer)
		for _key in tiles_backup.keys():
			erase_tile(_key, G.cur_layer)
			draw_tile(_key, G.cur_layer, true)
		tiles_backup.clear()
		has_backup = false

func _on_tile_mouse_enter() -> void:
	cur_ind_pos = tile_ind.translation
	if is_draw:
		restore_backup()
		update_ind(G.cur_layer)
		erase_tile(last_pos, G.cur_layer)
		draw_tile(last_pos, G.cur_layer, true)
		get_tiles(G.cur_layer)[last_pos][CUR_TILE_NODE].translation = last_ind_pos
		draw_tile(tile_pos, G.cur_layer)
		backup()
	elif is_erase:
		restore_backup()
		erase_tile(tile_pos, G.cur_layer)
		backup(false)
	else: #is move
		update_ind(G.cur_layer)
		restore_backup()
		backup(true)
	last_ind_pos = tile_ind.translation

func _process(delta: float) -> void:
	if is_motion:
		_on_update(delta)

func _on_UI_mouse_enter_exit(entered: bool) -> void:
	can_draw = false if entered else true

