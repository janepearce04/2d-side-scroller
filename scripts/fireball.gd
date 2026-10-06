extends Area2D

@export var speed := 300.0
@export var damage := 15.0
@export var lifetime := 2.0

var direction := 1

func _ready() -> void:
	handle_animation()
	scale.x = direction
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta

func handle_animation():
	%AnimationPlayer.play('fire')

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox"):
		var target = area.get_parent()
		if target.is_in_group("mobs") and target.has_method("take_damage"):
			print('target hit!')
			target.take_damage(damage)
			%AnimationPlayer.play('explode')
			await %AnimationPlayer.animation_finished
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		%AnimationPlayer.play('explode')
		await %AnimationPlayer.animation_finished
		queue_free()  # hit a wall or floor
