extends Mob
#class_name  mob_crawler

@onready var ledge_check: RayCast2D = get_node_or_null("%LedgeCheck") as RayCast2D

var _ledge_offset := Vector2(12.0, 0.0)


func _ready() -> void:
	super()
	if ledge_check == null:
		push_warning("%s has no LedgeCheck RayCast2D, so it will walk off ledges" % name)
		return
	var off := ledge_check.global_position - global_position
	_ledge_offset = Vector2(absf(off.x), off.y)


func _roam(delta: float) -> void:
	if is_on_wall():
		roam_direction.x = 1.0 if get_wall_normal().x > 0.0 else -1.0
	elif _ledge_ahead(roam_direction.x):
		roam_direction.x = -roam_direction.x   # turn around at the edge
		velocity.x = 0.0

	velocity.x = move_toward(velocity.x, roam_direction.x * roam_speed, acceleration * delta)


func _chase(delta: float) -> void:
	var dx := last_known_position.x - global_position.x
	var dir := 0.0
	if absf(dx) > 6.0:                       # dead zone so it doesn't jitter on top of you
		dir = 1.0 if dx > 0.0 else -1.0
	if _ledge_ahead(dir):
		dir = 0.0                            # stop at the edge instead of jumping off
		velocity.x = 0.0

	velocity.x = move_toward(velocity.x, dir * chase_speed, acceleration * 2.0 * delta)


# True if there's no ground just ahead in the direction we want to move
func _ledge_ahead(dir: float) -> bool:
	if ledge_check == null or dir == 0.0 or not is_on_floor():
		return false
	ledge_check.global_position = global_position + Vector2(dir * _ledge_offset.x, _ledge_offset.y)
	ledge_check.force_raycast_update()
	return not ledge_check.is_colliding()


func _on_hurt() -> void:
	%AnimationPlayer.flash_hurt(self)


func _pick_roam_direction() -> void:
	var x: float = [-1.0, 0.0, 1.0].pick_random()
	roam_direction = Vector2(x, 0.0)


func _update_animation() -> void:
	if is_on_floor() and absf(velocity.x) > 5.0:
		%AnimationPlayer.play_walk()
	else:
		%AnimationPlayer.play_idle()
