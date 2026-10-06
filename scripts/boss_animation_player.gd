extends AnimationPlayer

func play_idle():
	play("idle")
	
func play_attack():
	play("attack")
	
func play_death():
	play("death")
	
func play_walk():
	play("walk")
	
func play_hurt():
	play("hurt")
	
func play_intro():
	play("death", -1, -0.8, true)

func flash_hurt(sprite:CharacterBody2D) -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE
