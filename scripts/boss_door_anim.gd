extends AnimationPlayer

@onready var listen = %PLAYER_entered

var boss_door_open: = false

func _ready() -> void:
	boss_door_open = false

func _process(_delta: float) -> void:
	pass

func _on_player_entered_player_in_boss_area() -> void:
	if boss_door_open == false:
		play('door_open')
		await animation_finished
		boss_door_open = true
