extends Node
const GAME_MODE = 0
const EDIT_MODE = 1

var shift_pr = false
var mode = EDIT_MODE
onready var tilemap : Spatial
onready var camera : MeshInstance


func _input(event: InputEvent) -> void:
	if !event.is_action_type():
		return
	if mode == EDIT_MODE: # Level Editor Input
		if Input.is_action_pressed('shift'):
			shift_pr = true
		if Input.is_action_just_released('shift'):
			shift_pr = false
		if Input.is_action_just_pressed('export'):
			tilemap.update_navmesh()
		if Input.is_action_just_pressed('save'):
			tilemap.save_tilemap()
	else: # Game Input
		if camera == null:
			return
		if Input.is_action_just_pressed('q'):
			camera._rot.y -= 90
		if Input.is_action_just_pressed('e'):
			camera._rot.y += 90
		pass
#END


