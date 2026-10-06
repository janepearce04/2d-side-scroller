extends Area2D

func _ready() -> void:
	pass

signal player_in_boss_area

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and %PLAYER.player_hp >= 0:
		player_in_boss_area.emit()
		print("player in boss arena")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("player out of boss arena")
