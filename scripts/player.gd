extends CharacterBody2D
class_name player1

signal health_changed(new_hp: float)

enum State { NORMAL, DASH, ATTACK, CHARGE, CAST, HURT, DEAD }

@export_group("Health")
@export var max_hp := 65.0
@export var player_hp := 65.0
@export var contact_damage_default := 5.0   # used if the enemy has no `contact_damage` property
@export var spike_damage := 5.0
@export var invulnerable_time := 0.6        # i-frames after being hit
@export var hurt_stun_time := 0.0           # control lost after being hit
@export var knockback := Vector2(200.0, -50.0)

@export_group("Movement")
@export var max_speed := 200.0
@export var acceleration := 1600.0
@export var deceleration := 2200.0
@export var jump_acceleration := 900.0
@export var jump_deceleration := 1200.0
@export var fall_acceleration := 1400.0
@export var fall_deceleration := 1800.0

@export_group("Jump")
@export var jump_velocity := -400.0
@export var boost_jump_velocity := -725.0   # used while standing on a launchpad
@export_range(0.0, 1.0) var jump_cut_multiplier := 0.5
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1

@export_group("Gravity")
@export var gravity := 1000.0
@export var fall_gravity := 1600.0
@export var apex_gravity := 600.0
@export var apex_threshold := 60.0

@export_group("Dash")
@export var DASH_SPEED := 375.0
@export var DASH_DURATION := 0.3
@export var DASH_COOLDOWN := 1.2
@export var DASH_GRAVITY_SCALE := 0.15

@export_group("Scythe")
@export var attack_damage := 8.0
@export var ATTACK_DURATION := 0.93
@export var ATTACK_FRICTION := 250.0
@export var ATTACK_GRAVITY_SCALE := 0.15
@export var ATTACK_VERTICAL_DAMP := 0.2

@export_group("Fireball")
@export var fireball_scene: PackedScene
@export var CHARGE_MOVE_SCALE := 0.3
@export var FIREBALL_RECOIL := 120.0

@export_group("Sprite Squash")
@export var stretch_intensity := 0.001
@export var stretch_lerp_speed := 15.0
@export var max_stretch := 0.2

@onready var visuals: Node2D = %Visuals
@onready var spikes: TileMapLayer = %spikes
@onready var attack_hitbox: Area2D = get_node_or_null("%AttackHitbox")      # rename to match your node
@onready var charge_effect: CanvasItem = get_node_or_null("%ChargeEffect")  # rename to your fireball glow node

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
var _loop_start := 0.0
var _loop_end := 0.0

var _last_safe_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	dead = false
	_base_scale = Vector2(absf(visuals.scale.x), visuals.scale.y)
	_last_safe_position = global_position

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.y += gravity * delta
		move_and_slide()
		return

	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	invulnerable_left = max(invulnerable_left - delta, 0.0)
	direction = Input.get_axis("left", "right")

	if is_on_floor() and state != State.DASH:
		can_dash = true

	_update_jump_timers(delta)

	# Facing is only free to change in the normal state
	if state == State.NORMAL and direction != 0.0:
		facing = 1 if direction > 0.0 else -1

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
		State.CAST:   _cast_state(delta)   # this line was missing
		State.HURT:   _hurt_state(delta)

	_check_contact_damage()
	_check_spikes()
	_update_safe_position()
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

func _apply_gravity(delta: float, gravity_scale := 1.0) -> void:
	velocity.y += _current_gravity() * gravity_scale * delta


# ---------- DASH ----------
func start_dash() -> void:
	state = State.DASH
	can_dash = false
	state_time = DASH_DURATION
	dash_cooldown_left = DASH_COOLDOWN
	velocity.y = 0.0
	%AnimationPlayer.flash_dash()
	%AnimationPlayer.play_dash()

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
	if state == State.ATTACK:
		print("attack state active")
	_hit_this_swing.clear()
	state_time = ATTACK_DURATION
	velocity.y *= ATTACK_VERTICAL_DAMP
	%AnimationPlayer.play("attack")

func _attack_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ATTACK_FRICTION * delta)
	_apply_gravity(delta, ATTACK_GRAVITY_SCALE)
	_poll_attack_hits()
	state_time -= delta
	if state_time <= 0.0:
		print("return state normal")
		state = State.NORMAL

func _poll_attack_hits() -> void:
	if attack_hitbox == null:
		return
	for area in attack_hitbox.get_overlapping_areas():
		print("areas in attack hitbox")
		_try_hit(area)

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if state == State.ATTACK:
		print("body in attack hitbox")
		_try_hit(area)

func _try_hit(area: Area2D) -> void:
	print(area.get_path(), " ", area.get_groups())
	if not area.is_in_group("hurtbox"):
		return
	var target = _find_damageable(area)
	if target == null or target == self or target in _hit_this_swing:
		return
	_hit_this_swing.append(target)
	target.take_damage(attack_damage)
	print(target, " took ", attack_damage, " hp")

func _find_damageable(node: Node) -> Node:
	while node != null and not node.has_method("take_damage"):
		node = node.get_parent()
	return node


# ---------- FIREBALL ----------
func start_charge() -> void:
	var anim: Animation = %AnimationPlayer.get_animation("charge")
	if not (anim.has_marker(&"loop_start") and anim.has_marker(&"loop_end")):
		push_warning("'charge' animation needs 'loop' and 'loop_end' markers")
		return

	_loop_start = anim.get_marker_time(&"loop_start")
	_loop_end = anim.get_marker_time(&"loop_end")
	state = State.CHARGE
	state_time = 0.0
	%AnimationPlayer.flash_charge()
	%AnimationPlayer.play("charge")

func _charge_state(delta: float) -> void:
	state_time += delta
	_apply_gravity(delta)
	var target := direction * max_speed * CHARGE_MOVE_SCALE
	velocity.x = move_toward(velocity.x, target, acceleration * delta)

	var pos: float = %AnimationPlayer.current_animation_position

	if Input.is_action_pressed("fireball"):
		if not %AnimationPlayer.is_playing():
			# Safety net
			%AnimationPlayer.play("charge")
			%AnimationPlayer.seek(_loop_start, true)
		elif pos >= _loop_end:
			print('charge animation looping')
			var loop_len := maxf(_loop_end - _loop_start, 0.1)
			%AnimationPlayer.seek(_loop_start + fposmod(pos - _loop_start, loop_len), true)
	elif pos >= _loop_start:
		fire_fireball()
		state = State.CAST
		state_time = maxf(%AnimationPlayer.current_animation_length - pos, 0.05)
	else:
		_end_fireball_visuals()
		%AnimationPlayer.flash_fire()
		state = State.NORMAL

func _cast_state(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)  # bleeds off the recoil
	state_time -= delta
	if state_time <= 0.0:
		_end_fireball_visuals()
		state = State.NORMAL

func fire_fireball() -> void:
	velocity.x = -facing * FIREBALL_RECOIL
	var fb = fireball_scene.instantiate()
	fb.direction = facing
	fb.global_position = %FireballSpawn.global_position
	get_tree().current_scene.add_child(fb)
	%AnimationPlayer.flash_fire()

func _end_fireball_visuals() -> void:
	if charge_effect:
		charge_effect.visible = false
	if %AnimationPlayer.has_animation("RESET"):
		%AnimationPlayer.play("RESET")
		%AnimationPlayer.flash_fire()
		%AnimationPlayer.advance(0.0)


# ---------- HURT / HITS ----------
func _hurt_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * 0.3 * delta)
	_apply_gravity(delta)
	state_time -= delta
	if state_time <= 0.0:
		state = State.NORMAL


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

	# Getting hit mid-charge cancels it, so clean up the glow
	if state == State.CHARGE or state == State.CAST:
		_end_fireball_visuals()

	invulnerable_left = invulnerable_time
	state = State.HURT
	state_time = hurt_stun_time

	var push: float = -facing
	if source_position != Vector2.INF:
		var away := global_position.x - source_position.x
		if not is_zero_approx(away):
			push = signf(away)
	velocity = Vector2(push * knockback.x, knockback.y)

# ---------- SPIKES ----------
func _update_safe_position() -> void:
	if is_on_floor() and state != State.HURT:
		_last_safe_position = global_position

func _check_spikes() -> void:
	if state == State.DEAD:
		return
	for body in %HURTBOX.get_overlapping_bodies():
		if body.is_in_group("spikes"):
			_spike_hit()
			return

func _spike_hit() -> void:
	take_damage(spike_damage)
	if state == State.DEAD:
		return   # died to the spikes, so no respawn

	if state != State.HURT:
		if state == State.CHARGE or state == State.CAST:
			_end_fireball_visuals()
		state = State.NORMAL

	global_position = _last_safe_position
	velocity = Vector2.ZERO

signal died

func handle_death() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD   # must be first
	dead = true
	_end_fireball_visuals()
	velocity.x = 0.0
	%AnimationPlayer.play_death()
	await get_tree().create_timer(%AnimationPlayer.current_animation_length).timeout
	Globals.playerAlive = false
	print("player dead")
	died.emit()

# ---------- ANIMATION / VISUALS ----------
func _update_animation() -> void:
	match state:
		State.ATTACK, State.DASH, State.CHARGE, State.CAST, State.HURT:
			pass   # these states start their own animation once
		_:
			if is_on_floor() and not is_zero_approx(velocity.x):
				%AnimationPlayer.play_move()
			else:
				%AnimationPlayer.play_idle()


func _update_visuals(delta: float) -> void:
	var stretch := clampf(absf(velocity.y) * stretch_intensity, 0.0, max_stretch)
	var target := Vector2(1.0 / (1.0 + stretch), 1.0 + stretch)
	_squash = _squash.lerp(target, clampf(stretch_lerp_speed * delta, 0.0, 1.0))
	visuals.scale = Vector2(facing * _base_scale.x * _squash.x, _base_scale.y * _squash.y)

	var flicker := invulnerable_left > 0.0 and int(invulnerable_left * 20.0) % 2 == 0
	visuals.modulate.a = 0.4 if flicker else 1.0


func set_boosted(value: bool) -> void:
	boosted = value
