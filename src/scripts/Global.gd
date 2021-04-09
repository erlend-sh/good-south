extends Node
const GAME_MODE = 0
const EDIT_MODE = 1

var shift_pr = false
var mode = EDIT_MODE
onready var tilemap : Spatial


func _input(event: InputEvent) -> void:
	if !event.is_action_type():
		return
	if Input.is_action_pressed('shift'):
		shift_pr = true
	if Input.is_action_just_released('shift'):
		shift_pr = false
		print('hi')
	if Input.is_action_just_pressed('export'):
		tilemap.update_navmesh()
	if Input.is_action_just_pressed('save'):
		tilemap.save_tilemap()
#END


