extends Mob
## Boss. Reuses Mob's hp, take_damage, death and facing code, but runs its own
## state machine instead of Mob's roam/chase logic. Dormant until activate() is called.

enum State { IDLE, INTRO, CHASE, EVADE, RETREAT, ATTACK, HURT, DEAD }
enum AttackPhase { WINDUP, STRIKE, RECOVERY }

signal boss_defeated

@export_group("Boss")
@export var intro_time := 1.5
@export var hurt_stun_time := 0.75 - 0.05 * Globals.game_difficulty
@export var facing_deadzone := 12.0
@export var turn_cooldown := 0.3   # min time between turns, so the sprite can't flip every frame

@export_group("Attack")
@export var attack_range := 120.0
@export var attack_cooldown := 1.1 + 0.1 * Globals.game_difficulty
@export var attack_commit_time := 0.3   # in the last X seconds of windup the boss stops re-aiming
@export var attack_windup := 0.72
@export var attack_strike_time := 0.2
@export var attack_recovery := 0.6
@export var attack_speed := 300.0
@export var attack_deceleration := 1800.0
@export var strike_contact_damage := 1.0
@export var attack_damage := 10.0 + 3 * Globals.game_difficulty

@export_group("Evade")
@export var evade_time := 0.8

@export_group("Retreat")
@export var too_close_distance := 70.0     # only used when there is no %DistanceRay
@export var retreat_speed := 500.0         # starting speed of the back-dash (eases out to 0)
@export var retreat_time := 0.5
@export var retreat_cooldown := 2.0
@export var retreat_clearance := 50.0      # needs this much free space behind it to dash

@export_group("Footwork")
@export var shuffle_speed := 160.0
@export var shuffle_acceleration := 1400.0
@export var shuffle_step_time := 0.11
@export var shuffle_steps := Vector2i(2, 6)
@export var shuffle_cooldown := Vector2(1.0, 1.5)

@export_group("Animation")
@export var walk_anim_base_speed := 40.0
@export var walk_anim_scale_range := Vector2(0.5, 1.5)

@onready var health_bar: CanvasLayer = %Health_Bar
@onready var state_label: Label = $state_label
@onready var attack_ray: RayCast2D = get_node_or_null("%AttackRay") as RayCast2D
@onready var distance_ray: RayCast2D = get_node_or_null("%DistanceRay") as RayCast2D
@onready var attack_hitbox: Area2D = get_node_or_null("%ATTACK HITBOXS") as Area2D

var state := State.INTRO
var state_time := 0.0
var target: player1

var active := false

var _attack_phase := AttackPhase.WINDUP
var _attack_dir := 1.0
var _evade_dir := 1.0
var _retreat_dir := 1.0
var _attack_cooldown_left := 0.0
var _retreat_cooldown_left := 0.0
var _turn_cooldown_left := 0.0
var _normal_contact_damage := 0.0

var _shuffle_steps_left := 0
var _shuffle_step_left := 0.0
var _shuffle_dir := 1.0
var _shuffle_cooldown_left := 0.0

func _init() -> void:
	max_hp = 50 + 50 * Globals.game_difficulty
	chase_speed = 80.0 + 10 * Globals.game_difficulty

func _ready() -> void:
	super()
	soul_value = 10
	add_to_group("boss")
	add_to_group("mobs")
	art_faces_left = true
	_normal_contact_damage = contact_damage
	contact_damage = 0.0
	knockback_force = 100.0
	knockback_time = 0.2
	health_bar.visible = false
	_shuffle_cooldown_left = randf_range(shuffle_cooldown.x, shuffle_cooldown.y)
	state = State.IDLE
	active = false
	%AnimationPlayer.play("death", -1, 0, true)
	%Health.max_value = max_hp

	if attack_ray == null:
		push_warning("Boss: no %AttackRay found, falling back to the attack_range distance")
	if distance_ray == null:
		push_warning("Boss: no %DistanceRay found, falling back to too_close_distance")

func activate() -> void:
	if state != State.IDLE:
		return
	state = State.INTRO
	target = get_tree().get_first_node_in_group("player") as player1
	health_bar.visible = true
	update_health()
	active = true

	%AnimationPlayer.play_intro()
	var length: float = %AnimationPlayer.current_animation_length
	var speed := absf(%AnimationPlayer.get_playing_speed())
	state_time = length / speed if (speed > 0.0 and length > 0.0) else intro_time


func _physics_process(delta: float) -> void:
	state_label.text = State.keys()[state]
	if dead or target == null:
		return

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_retreat_cooldown_left = maxf(_retreat_cooldown_left - delta, 0.0)
	_turn_cooldown_left = maxf(_turn_cooldown_left - delta, 0.0)

	if affected_by_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.IDLE:    velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		State.INTRO:   _intro_state(delta)
		State.CHASE:   _chase_state(delta)
		State.EVADE:   _evade_state(delta)
		State.RETREAT: _retreat_state(delta)
		State.ATTACK:  _attack_state(delta)
		State.HURT:    _hurt_state(delta)

	_update_facing()
	move_and_slide()
	_update_animation()


# ---------- INTRO ----------
func _intro_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	state_time -= delta
	if state_time <= 0.0:
		contact_damage = _normal_contact_damage
		state = State.CHASE


# ---------- CHASE (also the decision point) ----------
func _chase_state(delta: float) -> void:
	# 1. Player is on top of us: back-dash if we can. If we can't (cooldown, wall behind,
	#    airborne) fall through and treat it like any other fight.
	if _player_too_close() and _can_retreat():
		start_retreat()
		return

	# 2. In attack range: attack if the player can be hurt, back off if they can't
	var in_range := _player_in_attack_range()
	if in_range:
		if player_vulnerable():
			if _attack_cooldown_left <= 0.0:
				start_attack()
				return
		else:
			evade()
			return

	if _update_shuffle(delta):
		return

	var dx := absf(target.global_position.x - global_position.x)
	var speed := 0.0 if (in_range or dx < 6.0) else chase_speed
	velocity.x = move_toward(velocity.x, _dir_to_target() * speed, acceleration * delta)


# ---------- EVADE (slow walk-away while the player has i-frames) ----------
func evade() -> void:
	state = State.EVADE
	state_time = evade_time
	_evade_dir = -_dir_to_target()


func _evade_state(delta: float) -> void:
	state_time -= delta
	if state_time <= 0.0 or is_on_wall() or player_vulnerable():
		state = State.CHASE
		return

	if _update_shuffle(delta):
		return

	velocity.x = move_toward(velocity.x, _evade_dir * chase_speed, acceleration * delta)


# ---------- RETREAT (fast back-dash) ----------
func _can_retreat() -> bool:
	if _retreat_cooldown_left > 0.0 or not is_on_floor():
		return false
	# Don't dash into a wall: ask the physics engine if there's room behind us
	return not test_move(global_transform, Vector2(-_dir_to_target() * retreat_clearance, 0.0))


func start_retreat() -> void:
	state = State.RETREAT
	state_time = retreat_time
	_retreat_dir = -_dir_to_target()
	_retreat_cooldown_left = retreat_cooldown
	_shuffle_steps_left = 0


func _retreat_state(delta: float) -> void:
	state_time -= delta
	# Eases out from retreat_speed to 0, so there's no slide at the end
	var t := clampf(state_time / retreat_time, 0.0, 1.0)
	velocity.x = _retreat_dir * retreat_speed * t
	if state_time <= 0.0 or is_on_wall():
		state = State.CHASE


# ---------- FOOTWORK ----------
# Quick back-and-forth steps layered over CHASE and EVADE. Returns true while it is
# driving the boss, so the caller skips its normal movement for that frame.
func _update_shuffle(delta: float) -> bool:
	if _shuffle_steps_left <= 0:
		_shuffle_cooldown_left -= delta
		if _shuffle_cooldown_left > 0.0 or not is_on_floor():
			return false
		_shuffle_steps_left = randi_range(shuffle_steps.x, shuffle_steps.y)
		_shuffle_step_left = shuffle_step_time
		# Directions are relative to the player, so this still works after they jump over us
		_shuffle_dir = -_dir_to_target() if _player_too_close() else _dir_to_target()

	_shuffle_step_left -= delta
	if _shuffle_step_left <= 0.0 or is_on_wall():
		_shuffle_steps_left = 0 if is_on_wall() else _shuffle_steps_left - 1
		_shuffle_dir = -_shuffle_dir
		_shuffle_step_left = shuffle_step_time

	if _shuffle_steps_left <= 0:
		_shuffle_cooldown_left = randf_range(shuffle_cooldown.x, shuffle_cooldown.y)
		return false

	velocity.x = move_toward(velocity.x, _shuffle_dir * shuffle_speed, shuffle_acceleration * delta)
	return true

# ---------- RANGE ----------
func _player_in_attack_range() -> bool:
	return _ray_sees_player(attack_ray, attack_range)

func _player_too_close() -> bool:
	return _ray_sees_player(distance_ray, too_close_distance)

# Points the ray at the player's side (whatever way the boss/visuals are flipped),
# then checks whether it actually hits the player. Falls back to a plain x distance.
func _ray_sees_player(ray: RayCast2D, fallback_distance: float) -> bool:
	if ray == null:
		return absf(target.global_position.x - global_position.x) <= fallback_distance
	# global_scale.x is never negative in Godot 4, so read the mirror from the x axis
	var mirrored := signf(ray.global_transform.x.x)
	ray.target_position.x = absf(ray.target_position.x) * _dir_to_target() * mirrored
	ray.force_raycast_update()
	var hit := ray.get_collider() as Node
	return hit != null and (hit == target or target.is_ancestor_of(hit))


# True when the player is alive and out of their i-frames
func player_vulnerable() -> bool:
	return target != null and not target.dead and target.invulnerable_left <= 0.0


# ---------- ATTACK ----------
func start_attack() -> void:
	state = State.ATTACK
	_shuffle_steps_left = 0
	_attack_phase = AttackPhase.WINDUP
	state_time = attack_windup
	_attack_dir = _dir_to_target()
	_hit_this_swing.clear()
	
	_face(_attack_dir)
	_play(&"attack")


func _attack_state(delta: float) -> void:
	state_time -= delta
	match _attack_phase:
		AttackPhase.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, attack_deceleration * delta)
			if state_time > attack_commit_time:
				_attack_dir = _dir_to_target()   # keep aiming until the commit point
			if state_time <= 0.0:
				_attack_phase = AttackPhase.STRIKE
				_face(_attack_dir)               # make the sprite match the lunge direction
				state_time = attack_strike_time
				contact_damage = strike_contact_damage
		AttackPhase.STRIKE:
			velocity.x = _attack_dir * attack_speed/2 * Globals.game_difficulty
			_poll_attack_hits()
			if state_time <= 0.0 or is_on_wall():
				_attack_phase = AttackPhase.RECOVERY
				state_time = attack_recovery
				contact_damage = _normal_contact_damage
		AttackPhase.RECOVERY:
			# Without this the lunge speed carries through the whole recovery
			velocity.x = move_toward(velocity.x, 0.0, attack_deceleration * delta)
			if state_time <= 0.0:
				_attack_cooldown_left = attack_cooldown
				state = State.CHASE

var _hit_this_swing: Array = []

func _poll_attack_hits() -> void:
	if attack_hitbox == null:
		return
	for area in attack_hitbox.get_overlapping_areas():
		print("areas in boss attack hitbox")
		_try_hit(area)
		get_hitbox_damage()

func get_hitbox_damage() -> float:
	print("player receiving hitbox damage")
	return attack_damage

func _on_attack_hitboxs_area_entered(area: Area2D) -> void:
	print("body in attack hitbox")
	_try_hit(area)

func _try_hit(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	var victim := _find_damageable(area)
	if victim == null or victim in _hit_this_swing:
		return
	_hit_this_swing.append(victim)
	victim.take_damage(attack_damage, global_position)

func _find_damageable(node: Node) -> Node:
	while node != null and not node.has_method("take_damage"):
		node = node.get_parent()
	return node

func _can_turn() -> bool:
	match state:
		State.DEAD:
			return false
		State.ATTACK:
			match _attack_phase:
				AttackPhase.WINDUP:
					return state_time > attack_commit_time
				AttackPhase.STRIKE:
					return false
				_:
					return true   # recovery
		_:
			return true
			
# ---------- HURT / DEATH ----------
# Mob.take_damage() calls this on every non-lethal hit
func _on_hurt() -> void:
	if %AnimationPlayer.has_method("flash_hurt"):
		%AnimationPlayer.flash_hurt(self)
	update_health()

	# Only CHASE/EVADE can be interrupted. During ATTACK, RETREAT or INTRO the boss just
	# flashes: playing the hurt animation there would replace the attack animation (and its
	# hitbox) while the state machine carried on with the lunge.
	if state == State.CHASE or state == State.EVADE:
		%AnimationPlayer.play_hurt()
		_shuffle_steps_left = 0
		state = State.HURT
		state_time = hurt_stun_time


func update_health() -> void:
	%Health.value = hp

func _hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	state_time -= delta
	if state_time <= 0.0:
		state = State.CHASE


func _die(Variant) -> void:
	state = State.DEAD
	contact_damage = 0.0
	%AnimationPlayer.speed_scale = 1.0
	health_bar.visible = false
	await super(soul_value)
	boss_defeated.emit()

# ---------- HELPERS ----------
func _dir_to_target() -> float:
	return 1.0 if target.global_position.x >= global_position.x else -1.0


# Overrides Mob's version: the boss looks at the player instead of where it's moving
func _update_facing() -> void:
	if _can_turn():
		var dx := target.global_position.x - global_position.x
		if absf(dx) > facing_deadzone and _turn_cooldown_left <= 0.0:
			var before := facing
			_face(dx)
			if facing != before:
				_turn_cooldown_left = turn_cooldown
	var flip: Node2D = visuals if visuals else self
	flip.scale.x = absf(flip.scale.x) * facing


# Animation names are placeholders; missing ones are skipped instead of erroring.
func _update_animation() -> void:
	var moving := absf(velocity.x) > 5.0
	var walking := moving and (state == State.CHASE or state == State.EVADE)

	if walking:
		var s := absf(velocity.x) / walk_anim_base_speed
		%AnimationPlayer.speed_scale = clampf(s, walk_anim_scale_range.x, walk_anim_scale_range.y)
	else:
		%AnimationPlayer.speed_scale = 1.0

	match state:
		State.IDLE:
			if not active:
				%AnimationPlayer.play("death", -1, 0, true)
				return
			
			_play(&"idle")
		State.CHASE, State.EVADE:
			_play(&"walk" if moving else &"idle")
		State.RETREAT:
			_play(&"retreat" if %AnimationPlayer.has_animation(&"dashback") else &"walk")

func _play(anim: StringName) -> void:
	if %AnimationPlayer.has_animation(anim):
		%AnimationPlayer.play(anim)
