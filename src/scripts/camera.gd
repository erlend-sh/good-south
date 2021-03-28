extends MeshInstance

const LEFT := 0
const FORWARD := 1
const RIGHT := 2
const BACK := 3
const CUR_TILE_NODE := 0
const CUR_TILE_NAME := 1
const CUR_TILE := 2
const CUR_TILE_ROT := 3
const _dirs := [Vector3.LEFT, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK]

onready var cam = get_node('3dCam') as Camera
onready var tilemap = get_node('../TileMap3D') as Node
onready var ray = get_node('../RayCast') as RayCast
onready var tile_indecator = get_node('../TileIndecator') as MeshInstance
onready var gizmo_cam = get_node('../CanvasLayer/UI/Viewport/Viewport/Cam') as Spatial
onready var tile_label = get_node('../CanvasLayer/UI/VBox/Tile') as Label

var _trans := translation
var _rot := rotation_degrees
var is_rotating := false
var rotation_speed := 0.1
var shift_pressed := false
var ray_length := 10000
var is_panning := false
var tile_pos := Vector3.ZERO
var cur_pos := Vector3.ZERO
var mouse_out := false
var has_backup := false
var tiles_backup := [null, null, null, null]
var tiles_to_set := {}


var cur_tile_name := ''
var cur_tile := ''

func _ready() -> void:
	G.cam = self
	_trans.y = tilemap.level
	cam.look_at(translation, Vector3.UP)

func get_tiles() -> Dictionary:
	return G.layers[G.sorted_layers[G.cur_layer]]['tiles']

func has_tile(_pos) -> bool:
	return true if get_tiles().has(_pos) else false

func has_same_tile(_pos) -> bool:
	if has_tile(_pos):
		if get_tiles()[_pos][1] == cur_tile_name: # && get_tiles()[_pos][2] == cur_tile
			return true
		else:
			return false
	else:
		return false

func draw_tile():
	if has_same_tile(tile_pos):
		print('same_tile')
		return
	var _tile = tile_indecator.duplicate()
	tilemap.add_child(_tile)
	if has_backup:
		for i in tiles_backup.size():
			if tiles_backup[i] != null:
				tiles_backup[i].free()
				tiles_backup[i] = null
		for k in tiles_to_set.keys():
			get_tiles()[k] = tiles_to_set[k]
		tiles_to_set = {}
		has_backup = false
	# [ 'mesh_instance_node', 'tileset_name', 'tile_name'  'tile_rot']
	get_tiles()[tile_pos] = [
		_tile, # MeshInstanceNode in TileMap3D children
		cur_tile_name, # tileset_name ie: sand/hill
		cur_tile, # tile name ie: solo/corner/middle/edge/solo_edge/solo_corner
		tile_indecator.rotation_degrees # Mesh Rotation
		]
	print(G.layers)

func remove_tile():
	if has_tile(tile_pos):
		get_tiles()[tile_pos][CUR_TILE_NODE].free()
# warning-ignore:return_value_discarded
		get_tiles().erase(tile_pos)
		var neighbors := [false, false, false, false]
		var neighs_of_neighs := [
			[false, false, false, false],
			[false, false, false, false],
			[false, false, false, false],
			[false, false, false, false]
		] 
		for i in range(neighbors.size()):
			if get_tiles().has(tile_pos + _dirs[i]):
				neighbors[i] = true
		if neighbors.has(true):
			for i in neighbors.size():
				if neighbors[i]:
					for j in _dirs.size():
						if has_same_tile(tile_pos + _dirs[i] + _dirs[j]):
							neighs_of_neighs[i][j] = true
					#prints( "NON", i , neighs_of_neighs[i])
					var _tile_name = ''
					var _tile = MeshInstance.new()
					tilemap.add_child(_tile)
					match neighs_of_neighs[i]:
						#case zero
						[false, false, false, false]:
							_tile.mesh = G.tiles[cur_tile_name]['solo']
							_tile.rotation_degrees.y = 0
							_tile_name = 'solo'
						# case one
						[true, false, false, false]: # has left neigh
							#print('has_left')
							_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
							_tile.rotation_degrees.y = 0
							_tile_name = 'solo_edge'
						[false, true, false, false]: # has forward neigh
							#print('has_forward')
							_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
							_tile.rotation_degrees.y = -90
							_tile_name = 'solo_edge'
						[false, false, true, false]: # has right neigh 
							#print('has_right')
							_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
							_tile.rotation_degrees.y = 180
							_tile_name = 'solo_edge'
						[false, false, false, true]: # has back neigh
							#print('has_back')
							_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
							_tile.rotation_degrees.y = 90
							_tile_name = 'solo_edge'
						# case two
						[true, true, false, false]: # has left and forward neighs
							#print('has_left_forward')
							_tile.mesh = G.tiles[cur_tile_name]['corner']
							_tile.rotation_degrees.y = 0
							_tile_name = 'corner'
						[true, false, true, false]: # has left and right neighs
							#print('has_left_right')
							_tile.mesh = G.tiles[cur_tile_name]['solo_middle']
							_tile.rotation_degrees.y = 0
							_tile_name = 'solo_middle'
						[true, false, false, true]: # has left and back neighs
							#print('has_left_back')
							_tile.mesh = G.tiles[cur_tile_name]['corner']
							_tile.rotation_degrees.y = 90
							_tile_name = 'corner'
						[false, true, true, false]: # has forward and right neighs
							#print('has_forward_right')
							_tile.mesh = G.tiles[cur_tile_name]['corner']
							_tile.rotation_degrees.y = -90
							_tile_name = 'corner'
						[false, true, false, true]: # has forward and back neighs
							#print('has_forward_back')
							_tile.mesh = G.tiles[cur_tile_name]['solo_middle']
							_tile.rotation_degrees.y = 90
							_tile_name = 'solo_middle'
						[false, false, true, true]: # has right and back neighs
							#print('has_right_back')
							_tile.mesh = G.tiles[cur_tile_name]['corner']
							_tile.rotation_degrees.y = 180
							_tile_name = 'corner'
						# case three
						[true, true, true, false]: # has left, right and forward neighs
							#print('has_left_forward_right')
							_tile.mesh = G.tiles[cur_tile_name]['edge']
							_tile.rotation_degrees.y = -90
							_tile_name = 'edge'
						[false, true, true, true]: # has forward, right and back neighs
							#print('has_forward_right_back')
							_tile.mesh = G.tiles[cur_tile_name]['edge']
							_tile.rotation_degrees.y = 180
							_tile_name = 'edge'
						[true, false, true, true]: # has left, right and back neighs
							#print('has_left_right_back')
							_tile.mesh = G.tiles[cur_tile_name]['edge']
							_tile.rotation_degrees.y = 90
							_tile_name = 'edge'
						[true, true, false, true]: # has left, forward and back neighs
							#print('has_left_forward_back')
							_tile.mesh = G.tiles[cur_tile_name]['edge']
							_tile.rotation_degrees.y = 0
							_tile_name = 'edge'
						# case four
						[true, true, true, true]: # has all neighs
							#print('has_all')
							_tile.mesh = G.tiles[cur_tile_name]['middle']
							_tile.rotation_degrees.y = 0
							_tile_name = 'middle'
						_:
							prints('something else !', neighs_of_neighs[i])
					_tile.translation = get_tiles()[tile_pos + _dirs[i]][CUR_TILE_NODE].translation
					get_tiles()[tile_pos + _dirs[i]][CUR_TILE_NODE].free()
					get_tiles()[tile_pos + _dirs[i]] = [
						_tile,
						cur_tile_name,
						_tile_name,
						_tile.rotation_degrees
					]

func _input(event: InputEvent) -> void:
	if Input.is_action_pressed('shift') && !is_rotating:
		if !shift_pressed:
			shift_pressed = true

	if Input.is_action_just_released('shift'):
		if shift_pressed:
			shift_pressed = false

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP || event.button_index == BUTTON_WHEEL_DOWN:
			if event.button_index == BUTTON_WHEEL_UP && cam.translation.z > 3:
				cam.translation.z -= 1
			if event.button_index == BUTTON_WHEEL_DOWN && cam.translation.z < 40:
				cam.translation.z += 1
		
		if event.button_index == BUTTON_LEFT:
			if event.is_pressed():
				if !is_rotating && !is_panning && tile_indecator.visible == true:
					print('draw')
					draw_tile()
		
		if event.button_index == BUTTON_RIGHT:
			if event.is_pressed():
				if !is_rotating && !is_panning && tile_indecator.visible == true:
					print('remove')
					remove_tile()
		
		if event.button_index == BUTTON_MIDDLE:
			if event.is_pressed():
				if !shift_pressed:
					is_rotating = true
					tile_pos = Vector3.ZERO
					tile_indecator.hide()
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				is_rotating = false
				tile_indecator.show()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			if event.is_pressed():
				if shift_pressed:
					is_panning = true
					tile_pos = Vector3.ZERO
					tile_indecator.hide()
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				is_panning = false
				tile_indecator.show()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion:
		if is_panning:
			_trans -= ((transform.basis.z - transform.basis.y) * event.relative.y + transform.basis.x * event.relative.x) * 0.01
			_trans.x = clamp(_trans.x, -tilemap._size/2, tilemap._size/2)
			_trans.z = clamp(_trans.z, -tilemap._size/2, tilemap._size/2)
			_trans.y = tilemap.level
		if is_rotating:
			_rot.y -= event.relative.x * rotation_speed
			_rot.x -= event.relative.y * rotation_speed
			_rot.x = clamp(_rot.x, -90 - cam.rotation_degrees.x, 0 - cam.rotation_degrees.x)

func _physics_process(delta: float) -> void:
		var mouse = get_viewport().get_mouse_position()
		var from = cam.project_ray_origin(mouse)
		var to = from + cam.project_ray_normal(mouse) * ray_length
		ray.cast_to = to
		ray.translation = from
		if ray.is_colliding() && (!is_rotating && !is_panning):
			var pos = ray.get_collision_point().floor()
			pos.y = tilemap.level
			pos.x += 0.5
			pos.z += 0.5
			tile_indecator.show()
			tile_indecator.translation = pos
			tile_pos = pos + Vector3(tilemap._size/2 - 0.5, 0, tilemap._size/2 - 0.5)
			tile_label.text = 'Tile %s' % tile_pos
		else:
			tile_indecator.hide()
			tile_label.text = 'Tile Null'
		if !translation.is_equal_approx(_trans):
			translation = translation.linear_interpolate(_trans, delta * 20)
		if !rotation_degrees.is_equal_approx(_rot):
			rotation_degrees = rotation_degrees.linear_interpolate(_rot, delta * 20)
			gizmo_cam.rotation_degrees = rotation_degrees
		if cur_pos != tile_pos: #move
			if cur_tile_name != '':
				if has_backup:
					for i in tiles_backup.size():
						if !tiles_backup[i] == null:
							tiles_backup[i].show()
							tiles_backup[i] = null
					for key in tiles_to_set.keys():
						tiles_to_set[key][CUR_TILE_NODE].free()
					tiles_to_set = {}
					has_backup = false
				if has_tile(tile_pos):
					tile_indecator.mesh = G.plane_tile
				if !has_same_tile(tile_pos):
					#left, forwad, right, back
					var neighbors := [false, false, false, false]
					var neighs_of_neighs := [
						[false, false, false, false],
						[false, false, false, false],
						[false, false, false, false],
						[false, false, false, false]
					]
					for i in _dirs.size():
						if has_same_tile(tile_pos + _dirs[i]):
							neighbors[i] = true
					prints('N', neighbors)
					if neighbors.has(true):
						has_backup = true
						for i in neighbors.size():
							match neighbors:
								# case one
								[true, false, false, false]: # has left neigh
									print('has_left')
									tile_indecator.mesh = G.tiles[cur_tile_name]['solo_edge']
									tile_indecator.rotation_degrees.y = 0
									cur_tile = 'solo_edge'
								[false, true, false, false]: # has forward neigh
									print('has_forward')
									tile_indecator.mesh = G.tiles[cur_tile_name]['solo_edge']
									tile_indecator.rotation_degrees.y = -90
									cur_tile = 'solo_edge'
								[false, false, true, false]: # has right neigh 
									print('has_right')
									tile_indecator.mesh = G.tiles[cur_tile_name]['solo_edge']
									tile_indecator.rotation_degrees.y = 180
									cur_tile = 'solo_edge'
								[false, false, false, true]: # has back neigh
									print('has_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['solo_edge']
									tile_indecator.rotation_degrees.y = 90
									cur_tile = 'solo_edge'
								# case two
								[true, true, false, false]: # has left and forward neighs
									print('has_left_forward')
									tile_indecator.mesh = G.tiles[cur_tile_name]['corner']
									tile_indecator.rotation_degrees.y = 0
									cur_tile = 'corner'
								[true, false, true, false]: # has left and right neighs
									print('has_left_right')
									tile_indecator.mesh = G.tiles[cur_tile_name]['solo_middle']
									tile_indecator.rotation_degrees.y = 0
									cur_tile = 'solo_middle'
								[true, false, false, true]: # has left and back neighs
									print('has_left_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['corner']
									tile_indecator.rotation_degrees.y = 90
									cur_tile = 'corner'
								[false, true, true, false]: # has forward and right neighs
									print('has_forward_right')
									tile_indecator.mesh = G.tiles[cur_tile_name]['corner']
									tile_indecator.rotation_degrees.y = -90
									cur_tile = 'corner'
								[false, true, false, true]: # has forward and back neighs
									print('has_forward_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['solo_middle']
									tile_indecator.rotation_degrees.y = 90
									cur_tile = 'solo_middle'
								[false, false, true, true]: # has right and back neighs
									print('has_right_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['corner']
									tile_indecator.rotation_degrees.y = 180
									cur_tile = 'corner'
								# case three
								[true, true, true, false]: # has left, right and forward neighs
									print('has_left_forward_right')
									tile_indecator.mesh = G.tiles[cur_tile_name]['edge']
									tile_indecator.rotation_degrees.y = -90
									cur_tile = 'edge'
								[false, true, true, true]: # has forward, right and back neighs
									print('has_forward_right_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['edge']
									tile_indecator.rotation_degrees.y = 180
									cur_tile = 'edge'
								[true, false, true, true]: # has left, right and back neighs
									print('has_left_right_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['edge']
									tile_indecator.rotation_degrees.y = 90
									cur_tile = 'edge'
								[true, true, false, true]: # has left, forward and back neighs
									print('has_left_forward_back')
									tile_indecator.mesh = G.tiles[cur_tile_name]['edge']
									tile_indecator.rotation_degrees.y = 0
									cur_tile = 'edge'
								# case four
								[true, true, true, true]: # has all neighs
									print('has_all')
									tile_indecator.mesh = G.tiles[cur_tile_name]['middle']
									tile_indecator.rotation_degrees.y = 0
									cur_tile = 'middle'
								_:
									prints('something else !', neighbors[i])

							if neighbors[i]:
								for j in _dirs.size():
									if tile_pos + _dirs[i] + _dirs[j] == tile_pos:
										neighs_of_neighs[i][j] = true
										continue
									if has_same_tile(tile_pos + _dirs[i] + _dirs[j]):
										neighs_of_neighs[i][j] = true
								#prints( "NON", i , neighs_of_neighs[i])
								var _tile_name = ''
								tiles_backup[i] = get_tiles()[tile_pos + _dirs[i]][CUR_TILE_NODE]
								tiles_backup[i].hide()
								var _tile = MeshInstance.new()
								tilemap.add_child(_tile)
								_tile.translation = tiles_backup[i].translation
								
								match neighs_of_neighs[i]:
									# case one
									[true, false, false, false]: # has left neigh
										#print('has_left')
										_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
										_tile.rotation_degrees.y = 0
										_tile_name = 'solo_edge'
									[false, true, false, false]: # has forward neigh
										#print('has_forward')
										_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
										_tile.rotation_degrees.y = -90
										_tile_name = 'solo_edge'
									[false, false, true, false]: # has right neigh 
										#print('has_right')
										_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
										_tile.rotation_degrees.y = 180
										_tile_name = 'solo_edge'
									[false, false, false, true]: # has back neigh
										#print('has_back')
										_tile.mesh = G.tiles[cur_tile_name]['solo_edge']
										_tile.rotation_degrees.y = 90
										_tile_name = 'solo_edge'
									# case two
									[true, true, false, false]: # has left and forward neighs
										#print('has_left_forward')
										_tile.mesh = G.tiles[cur_tile_name]['corner']
										_tile.rotation_degrees.y = 0
										_tile_name = 'corner'
									[true, false, true, false]: # has left and right neighs
										#print('has_left_right')
										_tile.mesh = G.tiles[cur_tile_name]['solo_middle']
										_tile.rotation_degrees.y = 0
										_tile_name = 'solo_middle'
									[true, false, false, true]: # has left and back neighs
										#print('has_left_back')
										_tile.mesh = G.tiles[cur_tile_name]['corner']
										_tile.rotation_degrees.y = 90
										_tile_name = 'corner'
									[false, true, true, false]: # has forward and right neighs
										#print('has_forward_right')
										_tile.mesh = G.tiles[cur_tile_name]['corner']
										_tile.rotation_degrees.y = -90
										_tile_name = 'corner'
									[false, true, false, true]: # has forward and back neighs
										#print('has_forward_back')
										_tile.mesh = G.tiles[cur_tile_name]['solo_middle']
										_tile.rotation_degrees.y = 90
										_tile_name = 'solo_middle'
									[false, false, true, true]: # has right and back neighs
										#print('has_right_back')
										_tile.mesh = G.tiles[cur_tile_name]['corner']
										_tile.rotation_degrees.y = 180
										_tile_name = 'corner'
									# case three
									[true, true, true, false]: # has left, right and forward neighs
										#print('has_left_forward_right')
										_tile.mesh = G.tiles[cur_tile_name]['edge']
										_tile.rotation_degrees.y = -90
										_tile_name = 'edge'
									[false, true, true, true]: # has forward, right and back neighs
										#print('has_forward_right_back')
										_tile.mesh = G.tiles[cur_tile_name]['edge']
										_tile.rotation_degrees.y = 180
										_tile_name = 'edge'
									[true, false, true, true]: # has left, right and back neighs
										#print('has_left_right_back')
										_tile.mesh = G.tiles[cur_tile_name]['edge']
										_tile.rotation_degrees.y = 90
										_tile_name = 'edge'
									[true, true, false, true]: # has left, forward and back neighs
										#print('has_left_forward_back')
										_tile.mesh = G.tiles[cur_tile_name]['edge']
										_tile.rotation_degrees.y = 0
										_tile_name = 'edge'
									# case four
									[true, true, true, true]: # has all neighs
										#print('has_all')
										_tile.mesh = G.tiles[cur_tile_name]['middle']
										_tile.rotation_degrees.y = 0
										_tile_name = 'middle'
									_:
										prints('something else !', neighs_of_neighs[i])
								tiles_to_set[tile_pos + _dirs[i]] = [
									_tile,
									cur_tile_name,
									_tile_name,
									_tile.rotation_degrees
								]
					else:
						tile_indecator.mesh = G.tiles[cur_tile_name]['solo']
						tile_indecator.rotation_degrees.y = 0
						cur_tile = 'solo'
				else: # has same tile
					print('same tile')
			cur_pos = tile_pos

func _on_UI_mouse_enter_exit(entered: bool) -> void:
	get_tree().paused = entered
