extends AnimationPlayer

@onready var sprite = %Visuals

signal fire_charged
signal death_anim_over

func play_idle():
	play("idle")
	
func play_move():
	play('move')

func play_attack():
	play('attack')

func play_dash():
	play('dash')

func flash_dash() -> void:
	var tween1 = get_tree().create_tween()
	tween1.tween_property(%Visuals, "modulate", Color.LIGHT_SKY_BLUE, 0.1)
	tween1.tween_property(%Visuals, "modulate", Color.WHITE, 0.4)

func flash_charge() -> void:
	var tween1 = get_tree().create_tween()
	tween1.tween_property(%Visuals, "modulate", Color.ORANGE_RED, 0.2)
	fire_charged.emit()

func flash_fire() -> void:
	var tween1 = get_tree().create_tween()
	tween1.tween_property(%Visuals, "modulate", Color.WHITE, 0.3)

func flash_hurt() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE

func play_death() -> void:
	play("death")
	await animation_finished
	death_anim_over.emit()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
