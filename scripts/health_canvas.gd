extends CanvasLayer


func _ready() -> void:
	_on_player_health_changed(%PLAYER.player_hp)  # show the starting value

func _process(_delta: float) -> void:
	pass

func _on_player_health_changed(new_hp: float) -> void:
	%Health.text = "Health: %d" % new_hp
