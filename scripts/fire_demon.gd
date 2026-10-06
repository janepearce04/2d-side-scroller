extends Mob
## Boss. Reuses Mob's hp, take_damage, death and facing code, but runs its own
## state machine instead of Mob's roam/chase logic. Dormant until activate() is called.

enum State { IDLE, INTRO, CHASE, EVADE, ATTACK, HURT, DEAD }
enum AttackPhase { WINDUP, STRIKE, RECOVERY }

signal boss_defeated

@export_group("Boss")
@export var intro_time := 1.5
@export var hurt_stun_time := 0.15
@export var facing_deadzone := 12.0

@export_group("Attack")
@export var attack_range := 120.0
@export var attack_cooldown := 1.5
@export var attack_windup := 0.93
@export var attack_strike_time := 0.1
@export var attack_recovery := 0.4
@export var attack_speed := 300.0
@export var attack_deceleration := 1800.0 
@export var strike_contact_damage := 2.0 

@export_group("Evade")
@export var evade_time := 0.8

@export_group("Footwork")
@export var shuffle_speed := 120.0
@export var shuffle_acceleration := 1200.0
@export var shuffle_step_time := 0.13
@export var shuffle_steps := Vector2i(5, 9)
@export var shuffle_cooldown := Vector2(2.0, 3.5)

@export_group("Animation")
@export var walk_anim_base_speed := 50.0
@export var walk_anim_scale_range := Vector2(0.5, 2.5)

@onready var health_bar: CanvasLayer = %Health_Bar

@onready var attack_ray: RayCast2D = get_node_or_null("%AttackRay") as RayCast2D

var state := State.IDLE
var state_time := 0.0
var target: Player

var _attack_phase := AttackPhase.WINDUP
var _attack_dir := 1.0
var _evade_dir := 1.0
var _attack_cooldown_left := 0.0
var _normal_contact_damage := 0.0

var _shuffle_steps_left := 0
var _shuffle_step_left := 0.0
var _shuffle_dir := 1.0
var _shuffle_cooldown_left := 0.0

func _init() -> void:
	max_hp = 50 + 50 * Globals.game_difficulty
	chase_speed = 80.0 + 10 * Globals.game_difficulty
	knockback_force = 4.0


func _ready() -> void:
	super()
	add_to_group("boss")
	art_faces_left = true
	_normal_contact_damage = contact_damage
	contact_damage = 0.0
	health_bar.visible = false
	_shuffle_cooldown_left = randf_range(shuffle_cooldown.x, shuffle_cooldown.y)
	state = State.IDLE
	
	if attack_ray == null:
		push_warning("Boss: no %AttackRay found, falling back to the attack_range distance")

func activate() -> void:
	if state != State.IDLE:
		return
	print("boss active")
	state = State.INTRO
	health_bar.visible = true
	update_health()
	target = get_tree().get_first_node_in_group("player") as Player
	
	%AnimationPlayer.play_intro()
	await %AnimationPlayer.animation_finished
	print("intro anim finished")

	var speed := absf(%AnimationPlayer.get_playing_speed())
	state_time = %AnimationPlayer.current_animation_length / speed if speed > 0.0 else intro_time

func _physics_process(delta: float) -> void:
	if dead or target == null:
		return

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)

	if affected_by_gravity and not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.IDLE:   velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		State.INTRO:  _intro_state(delta)
		State.CHASE:  _chase_state(delta)
		State.EVADE:  _evade_state(delta)
		State.ATTACK: _attack_state(delta)
		State.HURT:   _hurt_state(delta)

	_update_facing()
	move_and_slide()
	_update_animation()


# ---------- INTRO ----------
func _intro_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	state_time -= delta
	contact_damage = _normal_contact_damage
	if state_time <= 0.0:
		print("boss intro done; active")
		contact_damage = _normal_contact_damage
		state = State.IDLE

# ---------- CHASE (also the decision point) ----------
func _chase_state(delta: float) -> void:
	var in_range := _player_in_attack_range()

	# Close enough to act: attack if the player can be hurt, back off if they can't
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


# ---------- EVADE ----------
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
		_shuffle_dir = -1.0 if randf() < 0.5 else 1.0

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
	if attack_ray == null:
		return absf(target.global_position.x - global_position.x) <= attack_range
	attack_ray.force_raycast_update()
	var hit := attack_ray.get_collider() as Node
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
	_face(_attack_dir)
	_play(&"attack")


func _attack_state(delta: float) -> void:
	state_time -= delta
	match _attack_phase:
		AttackPhase.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, attack_deceleration * delta)
			if state_time <= 0.0:
				_attack_phase = AttackPhase.STRIKE
				state_time = attack_strike_time
				contact_damage = strike_contact_damage
		AttackPhase.STRIKE:
			velocity.x = _attack_dir * attack_speed
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


# ---------- HURT / DEATH ----------
# Mob.take_damage() calls this on every non-lethal hit
func _on_hurt() -> void:
	if %AnimationPlayer.has_method("flash_hurt"):
		%AnimationPlayer.flash_hurt(self)
	update_health()

	# Hits during an attack (or the intro) don't interrupt it, or its animation
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


func _die() -> void:
	state = State.DEAD
	contact_damage = 0.0
	%AnimationPlayer.speed_scale = 1.0
	health_bar.visible = false
	await super()
	boss_defeated.emit()


# ---------- HELPERS ----------
func _dir_to_target() -> float:
	return 1.0 if target.global_position.x >= global_position.x else -1.0


# Overrides Mob's version: the boss looks at the player instead of where it's moving
func _update_facing() -> void:
	if state == State.INTRO or state == State.CHASE or state == State.EVADE:
		var dx := target.global_position.x - global_position.x
		if absf(dx) > facing_deadzone:
			_face(dx)
	var flip: Node2D = visuals if visuals else self
	flip.scale.x = facing


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
			_play(&"idle")
		State.CHASE, State.EVADE:
			_play(&"walk" if moving else &"idle")


func _play(anim: StringName) -> void:
	if %AnimationPlayer.has_animation(anim):
		%AnimationPlayer.play(anim)
