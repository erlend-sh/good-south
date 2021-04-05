extends Node

const CORNER = 0
const EDGE = 1
const MIDDLE = 2
const SOLO = 3
const SOLO_EDGE = 4
const SOLO_MIDDLE = 5

onready var layer = preload('res://assets/scenes/Packed/Layer.tscn')
onready var tile_button = preload('res://assets/scenes/Packed/TileButton.tscn')
onready var plane_tile = preload('res://assets/meshes/TileIndecator.mesh')

onready var tiles_scene = preload('res://assets/scenes/Packed/Tiles.tscn').instance()

var layers_group : ButtonGroup
var canvas_layer : MarginContainer
var layers_container : VBoxContainer
var tilemap : Node
var tiles_container : VBoxContainer
var cur_layer := 0
var layers_panel_visible := true
var sorted_layers := []
var tiles = {}
var cur_tile_name := ''

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
	tiles_scene.queue_free()


func update_tiles():
	for i in tiles.keys().size():
		var _tile_button = tile_button.instance()
		tiles_container.add_child(_tile_button)
		_tile_button.text = tiles.keys()[i].capitalize()
		_tile_button.mouse_filter = Control.MOUSE_FILTER_PASS
		_tile_button.connect('toggled', self, '_on_tile_toggle', [tiles.keys()[i]])
		if i == 0:
			_tile_button.pressed = true

func _on_tile_toggle(pressed : bool, _tile_name : String):
	if pressed:
		cur_tile_name = _tile_name
		if tilemap != null:
			tilemap.update_ind()


func _ready() -> void:
	import_tiles(tiles_scene)
	get_tree().connect('screen_resized', self, '_on_screen_resize')
	yield(get_tree(), 'idle_frame')
	tilemap.resize_viewport(get_viewport().size)
	update_tiles()
	print_debug('global_ready')
	sort_layers()
	for i in sorted_layers.size():
		var _name = 'Layer %s' % i
		var _tiles = layers[sorted_layers[i]]['tiles']
		var _visibility = layers[sorted_layers[i]]['visible']
		var _layer = layer.instance()
		layers_container.add_child(_layer)
		for child in _layer.get_children():
			child.connect('mouse_entered', tilemap, '_on_UI_mouse_enter_exit', [true])
			child.connect('mouse_exited', tilemap, '_on_UI_mouse_enter_exit', [false])
			if child.get_index() == 0:
				child.connect('toggled', canvas_layer, '_on_layer_toggled')
				child.text = _name
			else:
				child.connect('toggled', canvas_layer, '_on_layer_visibility_toggled', [child])
				child.pressed = _visibility
			if cur_layer == i:
				if child.get_index() == 0:
					child.pressed = true


func _on_screen_resize():
	tilemap.resize_viewport(get_viewport().size)

func add_layer():
	var _size = str(layers.keys().size()).pad_zeros(3)
	layers['layer%s' % _size] = {'tiles': {}, 'visible' : true}
	var _layer = layer.instance()
	layers_container.add_child(_layer)
	for child in _layer.get_children():
		child.connect('mouse_entered', tilemap, '_on_UI_mouse_enter_exit', [true])
		child.connect('mouse_exited', tilemap, '_on_UI_mouse_enter_exit', [false])
		if child.get_index() == 0:
			child.connect('toggled', canvas_layer, '_on_layer_toggled')
			child.text = 'Layer %s' % (layers.keys().size() - 1)
			child.pressed = true
		else:
			child.connect('toggled', canvas_layer, '_on_layer_visibility_toggled', [child])
			child.pressed = true
	sort_layers()

func del_layer(): # NEEEEEEEEDS Fix 
	if layers.keys().size() == 1:
		return
	var _layer_name = 'layer%s' % str(cur_layer).pad_zeros(3)
	for key in layers[_layer_name]['tiles'].keys():
		var _mesh = layers[_layer_name]['tiles'][key][0].queue_free()
# warning-ignore:return_value_discarded
	if cur_layer == 0:
		cur_layer = 0
	else:
		cur_layer = cur_layer - 1
	layers_container.get_child(cur_layer).queue_free()
	layers_container.get_child(cur_layer).get_child(0).pressed = true
	if !layers_container.get_child(cur_layer).get_child(1).is_pressed():
		tilemap.can_draw = false
		layers_container.get_child(cur_layer).get_child(1).pressed = false
	layers.erase(_layer_name)
	sort_layers()
	var _temp_layers = {}
	for i in sorted_layers.size():
		_temp_layers['layer%s' % str(i).pad_zeros(3)] = layers[sorted_layers[i]]
		layers_container.get_child(i).get_child(0).text = 'Layer %s' % i
	layers = _temp_layers
	sort_layers()
	if tilemap.has_backup:
		for i in tilemap.tiles_backup.size():
			if !tilemap.tiles_backup[i] == null:
				tilemap.tiles_backup[i].queue_free()
				tilemap.tiles_backup[i] = null
		for key in tilemap.tiles_to_set.keys():
			tilemap.tiles_to_set[key][tilemap.CUR_TILE_NODE].queue_free()
		tilemap.tiles_to_set = {}
		tilemap.has_backup = false

func sort_layers():
	sorted_layers = layers.keys()
	sorted_layers.sort()
