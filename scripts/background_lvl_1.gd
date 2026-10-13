extends Node2D

@onready var anim = %AnimationPlayer
@onready var fade_layer = %death_fade

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_player_died() -> void:
	anim.play("play_death_fade")
