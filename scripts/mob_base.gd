extends CharacterBody2D
class_name Mob
## Shared logic for every enemy. Subclasses override _roam(), _chase(),
## _pick_roam_direction() and optionally _update_animation().

@export_group("Stats")
@export var max_hp := 10.0
@export var contact_damage := 3.0   # the player reads this when touching the mob

@export_group("Movement")
@export var roam_speed := 50.0
@export var chase_speed := 70.0
@export var acceleration := 200.0
@export var affected_by_gravity := true

@export_group("Awareness")
@export var lose_interest_time := 2.2   # keeps heading to the last seen spot this long

@export_group("Knockback")
@export var knockback_force := 200.0
@export var knockback_time := 0.25

# Put your sprite (and anything that should flip) under a Node2D named
# "Visuals" with "Access as Unique Name" on. Falls back to flipping the root.
@onready var visuals: Node2D = get_node_or_null("%Visuals") as Node2D

var hp := 0.0
var dead := false
var facing := 1                       # 1 = right, -1 = left
var chasing := false
var roam_direction := Vector2.ZERO
var last_known_position := Vector2.ZERO

var _lose_interest_left := 0.0
var _knockback_left := 0.0

@export_group("Visuals")
@export var art_faces_left := false   # untick for art that faces right

signal health_changed

# facing is the sign applied to scale.x, not a world direction
func _face(dir_x: float) -> void:
	facing = -1 if (dir_x > 0.0) == art_faces_left else 1

func _ready() -> void:
	hp = max_hp
	update_health()
	add_to_group("mobs")
	_pick_roam_direction()

func _physics_process(delta: float) -> void:
	if dead:
		return

	_update_target(delta)

	if affected_by_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	if _knockback_left > 0.0:
		_knockback_left -= delta
		_decay_knockback(delta)
	elif chasing:
		_chase(delta)
	else:
		_roam(delta)

	_update_facing()
	move_and_slide()
	_update_animation()


# ---------- AWARENESS ----------
# Asks the detection area who is inside *right now* (a signal can't answer that).
func _update_target(delta: float) -> void:
	var seen: Node2D = null
	for body in %DETECTION.get_overlapping_bodies():
		if body.is_in_group("player"):
			seen = body
			break

	if seen:
		last_known_position = seen.global_position
		_lose_interest_left = lose_interest_time
	else:
		_lose_interest_left = maxf(_lose_interest_left - delta, 0.0)

	chasing = _lose_interest_left > 0.0


# ---------- VIRTUALS ----------
func _roam(_delta: float) -> void:
	pass

func _chase(_delta: float) -> void:
	pass

func _pick_roam_direction() -> void:
	roam_direction = Vector2.ZERO

func _update_animation() -> void:
	pass


# ---------- FACING ----------
func _update_facing() -> void:
	if _knockback_left <= 0.0 and absf(velocity.x) > 10.0:
		_face(velocity.x)
	var flip: Node2D = visuals if visuals else self
	flip.scale.x = facing

# ---------- ROAM TIMER ----------
# Connected to your Timer's timeout signal (same name as before)
func _on_timer_timeout() -> void:
	$Timer.wait_time = [0.8, 1.2, 1.6, 1.8].pick_random()
	if not chasing:
		_pick_roam_direction()


# ---------- DAMAGE ----------
func take_damage(value: float, source_position := Vector2.INF) -> void:
	if dead or value <= 0.0:
		return

	print("mob hit for ", value)

	hp = maxf(hp - value, 0.0)
	health_changed.emit()
	update_health()

	if hp <= 0.0:
		_die()
		return

	_on_hurt()

	var origin := source_position
	if origin == Vector2.INF:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		origin = p.global_position if p else global_position - Vector2(facing, 0.0)

	var away := global_position - origin
	if affected_by_gravity:
		var push := signf(away.x)
		if push == 0.0:
			push = -facing
		velocity = Vector2(push * knockback_force, -knockback_force * 0.4)
	else:
		velocity = away.normalized() * knockback_force

	_knockback_left = knockback_time


func _decay_knockback(delta: float) -> void:
	if affected_by_gravity:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)

func _on_hurt() -> void:
	if %AnimationPlayer.has_method("flash_hurt"):
		%AnimationPlayer.flash_hurt(self)
	
	update_health()

func update_health() -> void:
	%Health.value = hp

func _die() -> void:
	if dead:
		return
	
	hp = 0.0
	dead = true  
	remove_from_group("mobs")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	if %AnimationPlayer.has_method("play_death"):
		%AnimationPlayer.play_death()
		await get_tree().create_timer(%AnimationPlayer.current_animation_length).timeout
	queue_free()
