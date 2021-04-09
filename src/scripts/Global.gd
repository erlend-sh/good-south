extends Node
const GAME_MODE = 0
const EDIT_MODE = 1

var shift_pr = false
var mode = EDIT_MODE


#INPUT ACTIONS!
func _input(event: InputEvent) -> void:
   if !event.is_action_type():
      return
   if mode == EDIT_MODE:
      if Input.is_action_pressed('shift'):
         shift_pr = true
      elif Input.is_action_just_released('shift'):
         shift_pr = false
#END


