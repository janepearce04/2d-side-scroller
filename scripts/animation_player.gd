extends AnimationPlayer

func play_idle():
	play("idle")
	
func play_move():
	play('move')

func play_attack():
	play('attack')

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
