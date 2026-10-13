extends CanvasLayer


func _ready() -> void:
	%HealthBar.max_value = %PLAYER.max_hp
	%HealthBar.value = %PLAYER.player_hp
	_on_player_health_changed(%PLAYER.player_hp)  # show the starting value

func _process(_delta: float) -> void:
	pass

func _on_player_health_changed(new_hp: float) -> void:
	%Health.text = "Health: %d" % new_hp
	%HealthBar.value = new_hp
