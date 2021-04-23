extends StateMachine


# difference between engaging and attacking states is that units' engage range is
# higher. when units are within engaging range they will move into attacking
# range and then can start attacking.


func _ready():
	add_state("idle")
	add_state("moving")
	add_state("engaging")
	add_state("attacking")
	set_state(states.idle)

# do whatever a unit does within a certain state
func _state_logic(delta):
	match state:
		states.idle:
			pass
		states.moving:
			parent.move_to_target()
		states.engaging:
			parent.move_to_target()
		states.attacking: 
			pass

# check whether a state transition needs to happen
func _get_transition(delta):
	match state:
		states.idle:
			while !parent.enemies_in_range.empty():
				# check if closest enemy is alive
				if parent.enemies_in_range[0].get_ref():
					set_state(states.engaging)
					parent.attack_target = parent.enemies_in_range[0]
					parent.set_nav_path(parent.attack_target.get_ref().translation)
					break
				else:
					parent.enemies_in_range.remove(0)
		states.moving:
			if parent.reached_target():
				set_state(states.idle)
		states.engaging:
			if !parent.attack_target.get_ref():
				parent.set_target(parent.position_in_formation)
			elif (	parent.translation.distance_to(parent.attack_target.get_ref().translation) 
					< parent.attack_range):
				set_state(states.attacking)
				parent.attack_target()
			elif parent.nav_path.size() <= 0:
				parent.set_nav_path(parent.attack_target.get_ref().translation)
		states.attacking: 
			pass


func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "ATTACK":
		parent.set_target(parent.position_in_formation)
