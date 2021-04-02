extends CanvasLayer


onready var layers_scroll = get_node('UI/Left/LayersPanel/VBox/Scroll') as ScrollContainer
onready var add_layer_button = get_node('UI/Left/LayersPanel/VBox/Header/Add') as Button
onready var del_layer_button = get_node('UI/Left/LayersPanel/VBox/Header/Del') as Button
onready var layers_panel_visibility_button = get_node('UI/Left/LayersPanel/VBox/Header/Vis') as Button
onready var layers_container = get_node('UI/Left/LayersPanel/VBox/Scroll/Layers_container') as VBoxContainer

onready var layers_group = preload('res://src/Groups/LayersGroup.tres') as ButtonGroup

func _ready() -> void:
	print_debug('layers_ready')
	G.canvas_layer = self
	G.layers_container = layers_container
	G.layers_group = layers_group
	G.tiles_container = get_node('UI/Left/TilesPanel/Scroll/TilesContainer') as VBoxContainer
	if !G.layers_panel_visible:
		layers_panel_visibility_button.emit_signal('pressed')

#Layer panel visibility
func _on_layers_visibility_pressed() -> void:
	if G.layers_panel_visible:
		G.layers_panel_visible = false
		layers_scroll.hide()
		add_layer_button.disabled = true
		del_layer_button.disabled = true
	else:
		G.layers_panel_visible = true
		layers_scroll.show()
		add_layer_button.disabled = false
		del_layer_button.disabled = false

# layer changed
func _on_layer_toggled(pressed: bool) -> void:
	if pressed:
		G.cur_layer = layers_group.get_pressed_button().get_parent().get_index()
	if G.layers['layer%s' % str(G.cur_layer).pad_zeros(3)]['visible'] == false:
		if G.tilemap != null:
			G.tilemap.can_draw = false



func _on_layer_visibility_toggled(pressed : bool, button : Button):
	var _layer_name = 'layer%s' % str(button.get_parent().get_index()).pad_zeros(3)
	G.layers[_layer_name]['visible'] = pressed
	var _keys = G.layers[_layer_name]['tiles'].keys()
	for k in _keys:
		G.layers[_layer_name]['tiles'][k][0].visible = pressed
	# if G.layers['layer%s' % str(G.cur_layer).pad_zeros(3)]['visible'] == false:
	# 	if G.tilemap != null:
	# 		G.tilemap.can_draw = false
	# 	print('hello')

func _on_add_layer_pressed() -> void:
	G.add_layer()

func _on_del_layer_pressed() -> void:
	G.del_layer()
