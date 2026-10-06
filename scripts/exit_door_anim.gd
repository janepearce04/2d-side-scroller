extends AnimationPlayer

var exit_door_open: = false

func _ready() -> void:
	exit_door_open = false

func _process(_delta: float) -> void:
	pass

func _on_fire_demon_boss_defeated() -> void:
	exit_door_open = true


func _on_player_in_player_exit_door() -> void:
	if exit_door_open == false:
		play('exit door')
		await animation_finished
		exit_door_open = true
