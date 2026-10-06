extends AnimationPlayer

func play_walk():
	play('walk')

func play_hurt():
	play('hurt')

func play_idle():
	play('idle')

func play_attack1():
	play('attack 1')

func play_attack2():
	play('attack 2')
	
func play_death():
	play('death')

func flash_hurt(sprite:CharacterBody2D) -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
