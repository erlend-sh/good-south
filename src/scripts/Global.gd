extends Node


onready var layer = preload('res://assets/scenes/Packed/Layer.tscn')
onready var tile_button = preload('res://assets/scenes/Packed/TileButton.tscn')
onready var plane_tile = preload('res://assets/meshes/TileIndecator.tres')

var layers_group : ButtonGroup
var layers_panel : PanelContainer
var layers_container : VBoxContainer
var cam : MeshInstance
var cur_layer := 0
var layers_panel_visible := true
var sorted_layers := []
var cur_brush = 'sand'
var tiles = {}
var tiles_scroll : ScrollContainer


var layers := {
	'layer000': {
		'tiles': {},
		'visibility': true
		},
	'layer001': {
		'tiles': {},
		'visibility': false
		},
	'layer002': {
		'tiles': {},
		'visibility': true
		}
	}

func tileset_dir_contents(path) -> Dictionary:
	var _sets := {}
	var files := []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif !file.begins_with("."):
			files.append(file)
	dir.list_dir_end()
	for _str in files:
		var _path = path + _str
		dir.open(_path)
		dir.list_dir_begin()
		while true:
			var file = dir.get_next()
			if file == "":
				break
			elif !file.begins_with("."):
				var n = file.replace('.mesh', '')
				if !_sets.has(_str):
					_sets[_str] = {}
				_sets[_str][n] = load(path + _str + '/' + file)
		dir.list_dir_end()
	return _sets

func _on_tile_toggle(pressed : bool, _tile_name : String):
	if pressed:
		cam.cur_tile_name = _tile_name
		cam.cur_tile = 'solo'
		cam.tile_indecator.mesh = tiles[_tile_name]['solo']

func _ready() -> void:
	tiles = tileset_dir_contents('res://assets/meshes/tileset/')
	print(tiles)
	yield(get_tree(), 'idle_frame')
	print('global_ready')
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
	#print(layers.keys())

func del_layer():
	var _layer_ind = layers_group.get_pressed_button().get_parent().get_index()
	var _layer_name = 'layer%s' % str(_layer_ind).pad_zeros(3)
	layers_container.get_child(_layer_ind).free()
# warning-ignore:return_value_discarded
	layers.erase(_layer_name)
	sort_layers()
	var _temp_layers = {}
	for i in sorted_layers.size():
		_temp_layers['layer%s' % str(i).pad_zeros(3)] = layers[sorted_layers[i]]
		layers_container.get_child(i).get_child(0).text = 'Layer %s' % i
	layers = _temp_layers
	print(layers)

func sort_layers():
	sorted_layers = layers.keys()
	sorted_layers.sort()
