extends Mob

func _init() -> void:
	affected_by_gravity = false
	art_faces_left = false     
	contact_damage = 2.0       
	roam_speed = 100.0         
	chase_speed = 150.0


func _ready() -> void:
	super()
	%AnimationPlayer.play(&"idle")

func _roam(delta: float) -> void:
	velocity = velocity.move_toward(roam_direction * roam_speed, acceleration * delta)


func _chase(delta: float) -> void:
	var to_target := last_known_position - global_position
	var desired := Vector2.ZERO
	if to_target.length() > 6.0:   # dead zone so it doesn't jitter on top of you
		desired = to_target.normalized() * chase_speed
	velocity = velocity.move_toward(desired, acceleration * 2.0 * delta)


func _pick_roam_direction() -> void:
	var dir: Vector2 = [Vector2.LEFT, Vector2.RIGHT].pick_random()
	roam_direction = dir
