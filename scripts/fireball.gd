extends Area2D

@export var speed := 300.0
@export var damage := 15.0
@export var lifetime := 2.0

var direction := 1
var _spent := false

func _ready() -> void:
	%AnimationPlayer.play("fire")
	scale.x = direction
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	position.x += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	print("fireball touched: ", area.get_path(), " ", area.get_groups())
	if _spent or not area.is_in_group("hurtbox"):
		return
	var target = _find_damageable(area)
	if target == null or target.is_in_group("player"):
		return
	target.take_damage(damage)
	_explode()

func _on_body_entered(body: Node2D) -> void:
	if _spent or body.is_in_group("player"):
		return
	var target = _find_damageable(body)
	if target != null:
		target.take_damage(damage)
	_explode()

func _find_damageable(node: Node) -> Node:
	while node != null and not node.has_method("take_damage"):
		node = node.get_parent()
	return node

func _explode() -> void:
	_spent = true
	set_deferred("monitoring", false)
	%AnimationPlayer.play("explode")
	await %AnimationPlayer.animation_finished
	queue_free()
