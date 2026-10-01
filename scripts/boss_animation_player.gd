extends AnimationPlayer

func play_intro_animation():
	play("death", -1, -2.0, true)

func play_idle_animation():
	play("idle")
	
func play_attack_animation():
	play("attack")

func play_walk_animation():
	play("walk")

func play_hurt_animation():
	play("hurt")

func play_death_animation():
	play("death")
