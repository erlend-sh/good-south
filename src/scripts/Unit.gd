extends KinematicBody

# the majority of the unit functionality is within the UnitStateMachine script.

# navigation
var speed = 10
var velocity = Vector3.ZERO
var nav_path: PoolVector3Array
var position_in_formation = Vector3.ZERO

# attacking
var damage = 1
var health = 3
var attack_range = 0.5
var attack_target = null
var return_position = Vector3.ZERO
var attack_distance = 1
var attacking = false
var enemies_in_range = [] # array of weakrefs to enemies


# owner
var unit_owner = 0


# Navigation instance from the game
onready var nav = get_node("/root/Spatial/DetourNavigation/Tiles/Navigation")
onready var cam_origin = get_node("/root/Spatial/DetourNavigation/CamOrigin")
onready var sprite = $Sprite3D
onready var tween = $Tween
onready var state_machine = $UnitSM



func _ready():
	unit_owner = get_parent().unit_owner
	position_in_formation = global_transform.origin



# Moves along the navpath as long as there are points in the path
func _physics_process(delta):
	var camera_pos = get_viewport().get_camera().global_transform.origin
	camera_pos.y = 0
	sprite.look_at(camera_pos, Vector3(0, 1, 0))



func move_to_target():
	if nav_path.size() > 0:
		var distance_to_next_point = translation.distance_to(nav_path[0])
		if distance_to_next_point < 0.1:
			nav_path.remove(0)
			if nav_path.size() != 0:
				velocity = translation.direction_to(nav_path[0]) * speed
				velocity = move_and_slide(velocity)
		else:
			velocity = translation.direction_to(nav_path[0]) * speed
			velocity = move_and_slide(velocity)


func reached_target() -> bool:
	if nav_path.size() == 0:
		return true
	else:
		return false


# Uses navigation to get path to the selected target vector
func set_target(target: Vector3):
	set_nav_path(target)
	state_machine.set_state(state_machine.states.moving)


func set_nav_path(target: Vector3):
	nav_path = nav.get_simple_path(translation, target)


func attack_unit(unit):
	var unit_direction = translation.direction_to(unit.translation)
	return_position = translation
	tween.interpolate_property(	sprite, "translation", sprite.translation,
								sprite.translation + unit_direction * attack_distance,
								0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	attacking = true


func _on_Area_body_entered(body):
	if body.is_in_group("unit"):
		if unit_owner != body.unit_owner:
			enemies_in_range.append(weakref(body))


func _on_Area_body_exited(body):
	if body.is_in_group("unit"):
		if unit_owner != body.unit_owner:
			enemies_in_range.erase(weakref(body))


func attack_target():
	var anim = $AnimationPlayer.get_animation("ATTACK")
	var track_id = anim.find_track("Sprite3D:translation")
	var key_id = anim.track_find_key(track_id, 0.1)
	anim.track_set_key_value(track_id, key_id, attack_target.get_ref().translation - translation)
	$AnimationPlayer.play("ATTACK")


func deal_damage():
	if attack_target.get_ref():
		attack_target.get_ref().take_damage(damage)


func take_damage(amount):
	health -= amount
	if health <= 0:
		get_parent().unit_died()
		queue_free()
