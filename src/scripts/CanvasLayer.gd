extends MarginContainer


onready var layers_scroll = get_node('Left/LayersPanel/VBox/Scroll') as ScrollContainer
onready var add_layer_button = get_node('Left/LayersPanel/VBox/Header/Add') as Button
onready var del_layer_button = get_node('Left/LayersPanel/VBox/Header/Del') as Button
onready var layers_panel_visibility_button = get_node('Left/LayersPanel/VBox/Header/Vis') as Button
onready var layers_container = get_node('Left/LayersPanel/VBox/Scroll/Layers_container') as VBoxContainer
onready var tilemap = get_node('VC/VP/Tilemap') as Spatial
onready var tile_button = preload('res://assets/scenes/Packed/TileButton.tscn')

onready var layer = preload('res://assets/scenes/Packed/Layer.tscn')

onready var canvas_layer : MarginContainer = self
onready var tiles_container = get_node('Left/TilesPanel/Scroll/TilesContainer') as VBoxContainer

onready var layers_group = preload('res://src/Groups/LayersGroup.tres') as ButtonGroup

var layers_panel_visible := true

func _ready() -> void:
	print_debug('layers_ready')
	get_tree().connect('screen_resized', self, '_on_screen_resize')
	update_tiles()
	if !layers_panel_visible:
		layers_panel_visibility_button.emit_signal('pressed')
	for i in tilemap.sorted_layers.size():
		var _name = 'Layer %s' % i
		var _tiles = tilemap.layers[tilemap.sorted_layers[i]]['tiles']
		var _visibility = tilemap.layers[tilemap.sorted_layers[i]]['visible']
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
			if tilemap.cur_layer == i:
				if child.get_index() == 0:
					child.pressed = true
#END

#Layer panel visibility
func _on_layers_visibility_pressed() -> void:
	if layers_panel_visible:
		layers_panel_visible = false
		layers_scroll.hide()
		add_layer_button.disabled = true
		del_layer_button.disabled = true
	else:
		layers_panel_visible = true
		layers_scroll.show()
		add_layer_button.disabled = false
		del_layer_button.disabled = false
#END

# layer changed
func _on_layer_toggled(pressed: bool) -> void:
	if pressed:
		tilemap.cur_layer = layers_group.get_pressed_button().get_parent().get_index()
	if tilemap.layers['layer%s' % str(tilemap.cur_layer).pad_zeros(3)]['visible'] == false:
		if tilemap != null:
			tilemap.can_draw = false
#END

func _on_layer_visibility_toggled(pressed : bool, button : Button):
	var _layer_name = 'layer%s' % str(button.get_parent().get_index()).pad_zeros(3)
	tilemap.layers[_layer_name]['visible'] = pressed
	var _keys = tilemap.layers[_layer_name]['tiles'].keys()
	for k in _keys:
		tilemap.layers[_layer_name]['tiles'][k][0].visible = pressed
#END

func _on_add_layer_pressed() -> void:
	add_layer()
#END

func _on_del_layer_pressed() -> void:
	del_layer()
#END

func _on_tile_toggle(pressed : bool, _tile_name : String):
	if pressed:
		tilemap.cur_tile_name = _tile_name
		tilemap.update_ind()
#END

#adds tile buttons to UI
func update_tiles():
	for i in tilemap.tiles.keys().size():
		var _tile_button = tile_button.instance()
		tiles_container.add_child(_tile_button)
		_tile_button.text = tilemap.tiles.keys()[i].capitalize()
		_tile_button.mouse_filter = Control.MOUSE_FILTER_PASS
		_tile_button.connect('toggled', self, '_on_tile_toggle', [tilemap.tiles.keys()[i]])
		if i == 0:
			_tile_button.pressed = true
#END

func add_layer():
	var _size = str(tilemap.layers.keys().size()).pad_zeros(3)
	tilemap.layers['layer%s' % _size] = {'tiles': {}, 'visible' : true}
	var _layer = layer.instance()
	layers_container.add_child(_layer)
	for child in _layer.get_children():
		child.connect('mouse_entered', tilemap, '_on_UI_mouse_enter_exit', [true])
		child.connect('mouse_exited', tilemap, '_on_UI_mouse_enter_exit', [false])
		if child.get_index() == 0:
			child.connect('toggled', canvas_layer, '_on_layer_toggled')
			child.text = 'Layer %s' % (tilemap.layers.keys().size() - 1)
			child.pressed = true
		else:
			child.connect('toggled', canvas_layer, '_on_layer_visibility_toggled', [child])
			child.pressed = true
	tilemap.sort_layers()
#END

func del_layer(): # NEEEEEEEEDS Fix 
	var _l = tilemap.cur_layer
	if tilemap.layers.keys().size() == 1:
		return
	var _layer_name = 'layer%s' % str(_l).pad_zeros(3)
	for key in tilemap.layers[_layer_name]['tiles'].keys():
		var _mesh = tilemap.layers[_layer_name]['tiles'][key][0].queue_free()
	if _l == 0:
		tilemap.cur_layer = 0
	else:
		tilemap.cur_layer = _l - 1
	_l = tilemap.cur_layer
	layers_container.get_child(_l).free()
	layers_container.get_child(_l).get_child(0).pressed = true
	if !layers_container.get_child(_l).get_child(1).is_pressed():
		tilemap.can_draw = false
		layers_container.get_child(_l).get_child(1).pressed = false
	tilemap.layers.erase(_layer_name)
	tilemap.sort_layers()
	var _temp_layers = {}
	for i in tilemap.sorted_layers.size():
		_temp_layers['layer%s' % str(i).pad_zeros(3)] = tilemap.layers[tilemap.sorted_layers[i]]
		layers_container.get_child(i).get_child(0).text = 'Layer %s' % i
		tilemap.layers = _temp_layers
	tilemap.sort_layers()
	if tilemap.has_backup:
		for i in tilemap.tiles_backup.size():
			if !tilemap.tiles_backup[i] == null:
				tilemap.tiles_backup[i].queue_free()
				tilemap.tiles_backup[i] = null
		for key in tilemap.tiles_to_set.keys():
			tilemap.tiles_to_set[key][tilemap.CUR_TILE_NODE].queue_free()
		tilemap.tiles_to_set = {}
		tilemap.has_backup = false
#END

func _on_screen_resize():
	var _s = get_viewport().size
	get_node('VC/VP').size = _s
	rect_size = _s
#END
