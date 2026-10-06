extends CharacterBody2D
class_name Player

signal health_changed(new_hp: float)

enum State { NORMAL, DASH, ATTACK, CHARGE, HURT, DEAD }

@export_group("Health")
@export var max_hp := 50.0
@export var player_hp := 50.0
@export var contact_damage_default := 5.0   # used if the enemy has no `contact_damage` property
@export var invulnerable_time := 0.4        # i-frames after being hit
@export var hurt_stun_time := 0.1         # control lost after being hit
@export var knockback := Vector2(220.0, -200.0)

@export_group("Movement")
@export var max_speed := 240.0
@export var acceleration := 2000.0
@export var deceleration := 2500.0
@export var jump_acceleration := 1000.0
@export var jump_deceleration := 1200.0
@export var fall_acceleration := 1500.0
@export var fall_deceleration := 1800.0

@export_group("Jump")
@export var jump_velocity := -400.0
@export var boost_jump_velocity := -700.0   # used while standing on a launchpad
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.5
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1

@export_group("Gravity")
@export var gravity := 1000.0
@export var fall_gravity := 1600.0
@export var apex_gravity := 700.0
@export var apex_threshold := 60.0

@export_group("Dash")
@export var DASH_SPEED := 375.0
@export var DASH_DURATION := 0.30
@export var DASH_COOLDOWN := 1.5
@export var DASH_GRAVITY_SCALE := 0.15

@export_group("Attack")
@export var attack_damage := 10.0
@export var ATTACK_DURATION := 0.8
@export var ATTACK_FRICTION := 600.0
@export var ATTACK_GRAVITY_SCALE := 0.15
@export var ATTACK_VERTICAL_DAMP := 0.4

@export_group("Fireball")
@export var fireball_scene: PackedScene
@export var CHARGE_TIME := 0.3
@export var CHARGE_MOVE_SCALE := 0.3
@export var FIREBALL_RECOIL := 120.0

@export_group("Sprite Squash")
@export var stretch_intensity := 0.001
@export var stretch_lerp_speed := 10.0
@export var max_stretch := 0.1

@onready var visuals: Node2D = %Visuals
@onready var attack_hitbox: Area2D = get_node_or_null("%AttackHitbox")  # rename to match your node

var state := State.NORMAL
var state_time := 0.0
var direction := 0.0
var facing := 1
var boosted := false
var dead := false

var can_dash := true
var dash_cooldown_left := 0.0
var invulnerable_left := 0.0

var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _base_scale := Vector2.ONE
var _squash := Vector2.ONE
var _hit_this_swing: Array = []


func _ready() -> void:
	add_to_group("player")
	_base_scale = Vector2(absf(visuals.scale.x), visuals.scale.y)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.y += gravity * delta
		move_and_slide()
		return

	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	invulnerable_left = max(invulnerable_left - delta, 0.0)
	direction = Input.get_axis("ui_left", "ui_right")

	if is_on_floor() and state != State.DASH:
		can_dash = true

	_update_jump_timers(delta)

	# Facing is only free to change in the normal state
	if state == State.NORMAL and direction != 0.0:
		facing = signi(direction)

	# Actions can only start from the normal state
	if state == State.NORMAL:
		if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_left == 0.0:
			start_dash()
		elif Input.is_action_just_pressed("attack"):
			start_attack()
		elif Input.is_action_just_pressed("fireball"):
			start_charge()

	match state:
		State.NORMAL: _normal_state(delta)
		State.DASH:   _dash_state(delta)
		State.ATTACK: _attack_state(delta)
		State.CHARGE: _charge_state(delta)
		State.HURT:   _hurt_state(delta)

	_check_contact_damage()
	_update_animation()
	_update_visuals(delta)
	move_and_slide()


# ---------- NORMAL ----------
func _normal_state(delta: float) -> void:
	_movement(delta)
	_jump()
	_apply_gravity(delta)


func _movement(delta: float) -> void:
	var acc: float
	var dec: float
	if is_on_floor():
		acc = acceleration
		dec = deceleration
	elif velocity.y < 0.0:
		acc = jump_acceleration
		dec = jump_deceleration
	else:
		acc = fall_acceleration
		dec = fall_deceleration

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * max_speed, acc * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, dec * delta)


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("ui_accept"):
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer -= delta


func _jump() -> void:
	if _coyote_timer > 0.0 and _buffer_timer > 0.0:
		velocity.y = boost_jump_velocity if boosted else jump_velocity
		_coyote_timer = 0.0
		_buffer_timer = 0.0

	# Variable jump height: releasing early cuts the rise short
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _current_gravity() -> float:
	if is_on_floor():
		return 0.0
	if absf(velocity.y) < apex_threshold:
		return apex_gravity
	if velocity.y > 0.0:
		return fall_gravity
	return gravity


func _apply_gravity(delta: float, scale := 1.0) -> void:
	velocity.y += _current_gravity() * scale * delta


# ---------- DASH ----------
func start_dash() -> void:
	state = State.DASH
	can_dash = false
	state_time = DASH_DURATION
	dash_cooldown_left = DASH_COOLDOWN
	velocity.y = 0.0


func _dash_state(delta: float) -> void:
	velocity.x = facing * DASH_SPEED
	velocity.y += gravity * DASH_GRAVITY_SCALE * delta
	state_time -= delta
	if state_time <= 0.0 or is_on_wall():
		state = State.NORMAL
		velocity.x = facing * max_speed


# ---------- MELEE ATTACK ----------
func start_attack() -> void:
	state = State.ATTACK
	state_time = ATTACK_DURATION
	_hit_this_swing.clear()
	velocity.y *= ATTACK_VERTICAL_DAMP
	%AnimationPlayer.play("attack")


func _attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ATTACK_FRICTION * delta)
	_apply_gravity(delta, ATTACK_GRAVITY_SCALE)
	_poll_attack_hits()
	state_time -= delta
	if state_time <= 0.0:
		state = State.NORMAL


# Catches enemies already inside the hitbox when the swing starts
func _poll_attack_hits() -> void:
	if attack_hitbox == null:
		return
	for area in attack_hitbox.get_overlapping_areas():
		_try_hit(area)


# Your existing signal connection still works; it just routes through _try_hit
func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if state == State.ATTACK:
		_try_hit(area)


func _try_hit(area: Area2D) -> void:
	if not area.is_in_group("hurtbox"):
		return
	var target = area.get_parent()
	if target in _hit_this_swing:
		return  # each enemy is hit once per swing
	if target.is_in_group("mobs") and target.has_method("take_damage"):
		_hit_this_swing.append(target)
		target.take_damage(attack_damage)


# ---------- FIREBALL ----------
func start_charge() -> void:
	state = State.CHARGE
	state_time = 0.0
	%AnimationPlayer.play("charge")


func _charge_state(delta: float) -> void:
	state_time += delta
	_apply_gravity(delta)
	var target := direction * max_speed * CHARGE_MOVE_SCALE
	velocity.x = move_toward(velocity.x, target, acceleration * delta)

	if Input.is_action_just_released("fireball"):
		if state_time >= CHARGE_TIME:
			fire_fireball()
		state = State.NORMAL  # released early = cancelled


func fire_fireball() -> void:
	velocity.x = -facing * FIREBALL_RECOIL
	var fb = fireball_scene.instantiate()
	fb.direction = facing
	fb.global_position = %FireballSpawn.global_position
	get_tree().current_scene.add_child(fb)


# ---------- HURT / HITS ----------
func _hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * 0.3 * delta)
	_apply_gravity(delta)
	state_time -= delta
	if state_time <= 0.0:
		state = State.NORMAL


# Polls overlaps every frame so standing inside an enemy still hurts
# once your i-frames run out (signals only fire on the moment of entry).
func _check_contact_damage() -> void:
	if invulnerable_left > 0.0 or state == State.DEAD:
		return
	for body in %HURTBOX.get_overlapping_bodies():
		if body.is_in_group("mobs"):
			var dmg = body.get("contact_damage")  # null if the enemy doesn't define it
			take_damage(dmg if dmg != null else contact_damage_default, body.global_position)
			return


func take_damage(damage: float, source_position := Vector2.INF) -> void:
	if state == State.DEAD or damage <= 0.0 or invulnerable_left > 0.0:
		return

	player_hp = max(player_hp - damage, 0.0)
	health_changed.emit(player_hp)

	if player_hp <= 0.0:
		handle_death()
		return

	invulnerable_left = invulnerable_time
	state = State.HURT
	state_time = hurt_stun_time

	var push: float = -facing
	if source_position != Vector2.INF:
		var away := global_position.x - source_position.x
		if not is_zero_approx(away):
			push = signf(away)
	velocity = Vector2(push * knockback.x, knockback.y)


func handle_death() -> void:
	state = State.DEAD
	dead = true
	Globals.playerAlive = false
	velocity.x = 0.0
	%AnimationPlayer.play_death()
	await %AnimationPlayer.animation_finished
	queue_free()


# ---------- ANIMATION / VISUALS ----------
func _update_animation() -> void:
	match state:
		State.DASH:
			%AnimationPlayer.flash_dash()
		State.ATTACK, State.CHARGE:
			%AnimationPlayer.flash_fire()
		State.HURT:
			pass
		_:
			if is_on_floor() and not is_zero_approx(velocity.x):
				%AnimationPlayer.play_move()
			else:
				%AnimationPlayer.play_idle()


func _update_visuals(delta: float) -> void:
	# Squash & stretch, composed with the facing flip so they don't fight
	var stretch := clampf(absf(velocity.y) * stretch_intensity, 0.0, max_stretch)
	var target := Vector2(1.0 / (1.0 + stretch), 1.0 + stretch)
	_squash = _squash.lerp(target, clampf(stretch_lerp_speed * delta, 0.0, 1.0))
	visuals.scale = Vector2(facing * _base_scale.x * _squash.x, _base_scale.y * _squash.y)

	# Flicker during i-frames
	var flicker := invulnerable_left > 0.0 and int(invulnerable_left * 20.0) % 2 == 0
	visuals.modulate.a = 0.4 if flicker else 1.0


func set_boosted(value: bool) -> void:
	boosted = value
