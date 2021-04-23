extends Spatial

onready var camera = $DetourNavigation/CamOrigin/Cam
var ray_length = 100

var selected_unit = null


func raycast_from_mouse(m_pos, collision_mask):
	var ray_start = camera.project_ray_origin(m_pos)
	var ray_end = ray_start + camera.project_ray_normal(m_pos) * ray_length
	var space_state = get_world().direct_space_state
	return space_state.intersect_ray(ray_start, ray_end, [], collision_mask)


func select_unit(unit_group):
	selected_unit = unit_group


func move_unit(m_pos):
	var result = raycast_from_mouse(m_pos, 1)
	if result:
		selected_unit.move_to(result.collider.get_parent().get_global_transform().origin)


func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("right_click", false):
			if selected_unit != null:
				move_unit(event.position)
