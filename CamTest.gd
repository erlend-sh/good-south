extends Position3D


var _pos    := Vector3.ZERO
var _rot    := Vector3(-45, 45, 0)
var pan_spd := 0.15
var rot_spd := 0.15

func _physics_process(delta: float):
	var axis = get_input_axis()
	_pos -= ((transform.basis.z - transform.basis.y) * axis.y + transform.basis.x * axis.x) * pan_spd
	_pos.x = clamp(_pos.x, -30, 30)
	_pos.z = clamp(_pos.z, -30, 30)

	if Input.is_action_just_pressed('q'):
		_rot.y -= 90
	if Input.is_action_just_pressed('e'):
		_rot.y += 90

	if !_pos.is_equal_approx(translation):
		translation += (_pos - translation) * pan_spd
	if !_rot.is_equal_approx(rotation_degrees):
		rotation_degrees.y += (_rot.y - rotation_degrees.y) * rot_spd
		rotation_degrees.x += (_rot.x - rotation_degrees.x) * rot_spd
#END

func get_input_axis() -> Vector2:
	var _axis = Vector2.ZERO
	_axis.x = int(Input.get_action_strength('a')) - int(Input.get_action_strength('d'))
	_axis.y = int(Input.get_action_strength('w')) - int(Input.get_action_strength('s'))
	if _axis.length() > 1:
		_axis = _axis.normalized()
	return _axis
#END