extends Spatial


var selected = false
var target
var speed = 3
var velocity = Vector3.ZERO
var units = 9


# owner
export var unit_owner := 0


onready var game = get_node("/root/Spatial")
onready var nav = game.get_node("DetourNavigation/Tiles/Navigation")


var positions = []
var taken_positions = []


func _ready():
	target = translation
	positions = [	$Unit.translation, $Unit2.translation, $Unit3.translation, 
					$Unit4.translation, $Unit5.translation, $Unit6.translation, 
					$Unit7.translation, $Unit8.translation, $Unit9.translation]
	# unlocking units transforms from the parent so they can move individually
	for unit in get_children():
		if unit.is_in_group("unit"):
			unit.set_as_toplevel(true)



func _on_Area_input_event(camera, event, click_position, click_normal, shape_idx):
	if event is InputEventMouseButton:
		if event.is_action_pressed("left_click", false):
			selected = !selected
			if selected:
				game.select_unit(self)


func unit_position_in_formation(unit):
	pass



func move_to(target_pos):
	var pos_in_formation = 0
	translation = target_pos
	for unit in get_children():
		if unit.is_in_group("unit"):
			unit.set_target(target_pos + positions[pos_in_formation])
			unit.position_in_formation = target_pos + positions[pos_in_formation]
			pos_in_formation += 1


func unit_died():
	units -= 1
	if units <= 0:
		queue_free()
