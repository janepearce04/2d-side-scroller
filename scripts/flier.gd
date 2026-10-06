extends CharacterBody2D

class_name mob_flier

const SPEED = 150.0

var aerial: bool
var chasing_player: bool
var dead: bool = false
var taking_damage: bool = false

var attacktime_damage = 2.0

var knockback_force = -200
var is_roaming: bool = true

var direction: Vector2
var facing := 1    # 1 = right, -1 = left

var mob_hp = 10.0
var hp_max = 10.0

@export var target: CharacterBody2D
var player_in_area: bool = false

func _ready() -> void:
	chasing_player = false
	add_to_group('mobs')
	%AnimationPlayer.play('idle')

func _physics_process(delta: float) -> void:
	Globals.crawlerDamageAmt = 2
	Globals.crawlerDamageZone = %"FLIER BOX"
	
	seek_target()
	
	scale.x = facing
	move(delta)
	move_and_slide()

func seek_target():
	if !dead:
		if %DETECTION.body_entered and %DETECTION.get_overlapping_bodies():
			chasing_player = true

func move(delta):
	if !dead:
		if !chasing_player:
			var movement = direction * SPEED * delta
			velocity -= clamp(movement, Vector2(-200, -100), Vector2(250, 250))
		elif chasing_player and !taking_damage:
			var dir_to_play = position.direction_to(target.position).normalized()
			velocity = dir_to_play * SPEED
			direction.x = abs(velocity.x) / velocity.x
			if direction[0] > 0:
				facing = 1
			elif direction[0] < 0:
				facing = -1
		elif chasing_player and taking_damage:
			var knockback_dir = position.direction_to(target.position) * knockback_force
			velocity.x = knockback_dir.x
		is_roaming = true
	elif dead:
		velocity.x = 0
		handle_death()

func handle_death():
	#%AnimationPlayer.play_death()
	self.queue_free()
	pass

func _on_timer_timeout() -> void:
	$Timer.wait_time = choose([0.8, 1.2, 1.6, 1.8])
	if !chasing_player:
		direction = choose([Vector2.LEFT, Vector2.RIGHT])
	
func choose(array: Array):
	array.shuffle()
	return array.front()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var damage: float
	var hit = area.get_parent()
	if hit.has_method('take_damage'):
		take_damage(damage)

func take_damage(value):
	mob_hp -= value
	taking_damage = true
	if mob_hp <= 0:
		dead = true
