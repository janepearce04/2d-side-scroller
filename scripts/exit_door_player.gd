extends Area2D

signal player_exit_door

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and %PLAYER.player_hp >= 0:
		player_exit_door.emit()
		print("player in exit door")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("player out of exit door")
