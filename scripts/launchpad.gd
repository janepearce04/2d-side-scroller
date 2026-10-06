extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("player in")
		body.set_boosted(true)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("player out")
		body.set_boosted(false)
