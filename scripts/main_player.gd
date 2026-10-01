extends CharacterBody2D

@export var SPEED = 250.0
@export var JUMP_VELOCITY = -300.0

var direction = 0
#const SPEED = 300.0
#const JUMP_VELOCITY = -600.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	#else:
	#	velocity.x = move_toward(velocity.x, 0, SPEED)
	if abs(velocity) >= Vector2.ZERO:
		%AnimationPlayer.play_move()
		if velocity.x < 0:
			%Visuals.scale.x = -1
		elif velocity.x > 0:
			%Visuals.scale.x = 1
	else:
		%AnimationPlayer.play_idle()

	move_and_slide()
