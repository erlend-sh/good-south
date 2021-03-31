extends Node

const CORNER = 0
const EDGE = 1
const MIDDLE = 2
const SOLO = 3
const SOLO_EDGE = 4
const SOLO_MIDDLE = 5

onready var layer = preload('res://assets/scenes/Packed/Layer.tscn')
onready var tile_button = preload('res://assets/scenes/Packed/TileButton.tscn')
onready var plane_tile = preload('res://assets/meshes/TileIndecator.tres')

onready var tiles_scene = preload('res://assets/scenes/Packed/Tiles.tscn').instance()

var layers_group : ButtonGroup
var layers_panel : PanelContainer
var layers_container : VBoxContainer
var cam : MeshInstance
var tiles_scroll : ScrollContainer
var cur_layer := 0
var layers_panel_visible := true
var sorted_layers := []
var tiles = {}
var cur_tile_name := ''

var layers := {
	'layer000': {
		'tiles': {},
		'visibility': true
		}
	}

	# {'sand': [solo, corner, ...]}
func import_tiles(_scene : Spatial):
	var _tileset := {}
	for _child in _scene.get_children():
		if _child.get_index() == 0:
			cur_tile_name = _child.name
		var _mesh := []
		if _child.get_child_count() > 0:
			for _sub in _child.get_children():
				_mesh.append(_sub)
				print(_sub.name)
		tiles[_child.name] = _mesh


func _on_tile_toggle(pressed : bool, _tile_name : String):
	if cam == null:
		print_debug('cam == Null')
		return
	if pressed:
		G.cur_tile_name = _tile_name
		#cam.tile_ind.mesh = tiles[_tile_name][SOLO].mesh

func _ready() -> void:
	import_tiles(tiles_scene)
	print(tiles)
	yield(get_tree(), 'idle_frame')
	cam.update_ind(cur_layer)
	print_debug('global_ready')
	for i in tiles.keys().size():
		var _tile_button = tile_button.instance()
		tiles_scroll.add_child(_tile_button)
		_tile_button.text = tiles.keys()[i].capitalize()
		_tile_button.connect('mouse_entered', cam, '_on_UI_mouse_enter_exit', [true])
		_tile_button.connect('mouse_exited', cam, '_on_UI_mouse_enter_exit', [false])
		_tile_button.connect('toggled', self, '_on_tile_toggle', [tiles.keys()[i]])
		if i == 0:
			_tile_button.pressed = true
	sort_layers()
	for i in sorted_layers.size():
		var _name = 'Layer %s' % i
		var _tiles = layers[sorted_layers[i]]['tiles']
		var _visibility = layers[sorted_layers[i]]['visibility']
		var _layer = layer.instance()
		layers_container.add_child(_layer)
		for child in _layer.get_children():
			child.connect('mouse_entered', cam, '_on_UI_mouse_enter_exit', [true])
			child.connect('mouse_exited', cam, '_on_UI_mouse_enter_exit', [false])
			if child.get_index() == 0:
				child.connect('toggled', layers_panel, '_on_layer_toggled')
				child.text = _name
			else:
				child.connect('toggled', layers_panel, '_on_layer_visibility_toggled', [child])
				child.pressed = _visibility
			if cur_layer == i:
				if child.get_index() == 0:
					child.pressed = true

func add_layer():
	var _size = str(layers.keys().size()).pad_zeros(3)
	layers['layer%s' % _size] = {'tiles': {}, 'visibility' : true}
	var _layer = layer.instance()
	layers_container.add_child(_layer)
	for child in _layer.get_children():
		child.connect('mouse_entered', cam, '_on_UI_mouse_enter_exit', [true])
		child.connect('mouse_exited', cam, '_on_UI_mouse_enter_exit', [false])
		if child.get_index() == 0:
			child.connect('toggled', layers_panel, '_on_layer_toggled')
			child.text = 'Layer %s' % (layers.keys().size() - 1)
			child.pressed = true
		else:
			child.connect('toggled', layers_panel, '_on_layer_visibility_toggled', [child])
			child.pressed = true
	sort_layers()

func del_layer(): # NEEEEEEEEDS Fix 
	if layers.keys().size() == 1:
		return
	var _layer_name = 'layer%s' % str(cur_layer).pad_zeros(3)
	for key in layers[_layer_name]['tiles'].keys():
		var _mesh = layers[_layer_name]['tiles'][key][0].free()
# warning-ignore:return_value_discarded
	if cur_layer == 0:
		cur_layer = 0
	else:
		cur_layer = cur_layer - 1
	layers_container.get_child(cur_layer).free()
	layers_container.get_child(cur_layer).get_child(0).pressed = true
	if !layers_container.get_child(cur_layer).get_child(1).is_pressed():
		cam.can_draw = false
		layers_container.get_child(cur_layer).get_child(1).pressed = false
		print('hidden')
	layers.erase(_layer_name)
	sort_layers()
	var _temp_layers = {}
	for i in sorted_layers.size():
		_temp_layers['layer%s' % str(i).pad_zeros(3)] = layers[sorted_layers[i]]
		layers_container.get_child(i).get_child(0).text = 'Layer %s' % i
	layers = _temp_layers
	sort_layers()
	if cam.has_backup:
		for i in cam.tiles_backup.size():
			if !cam.tiles_backup[i] == null:
				cam.tiles_backup[i].free()
				cam.tiles_backup[i] = null
		for key in cam.tiles_to_set.keys():
			cam.tiles_to_set[key][cam.CUR_TILE_NODE].free()
		cam.tiles_to_set = {}
		cam.has_backup = false

func sort_layers():
	sorted_layers = layers.keys()
	sorted_layers.sort()
