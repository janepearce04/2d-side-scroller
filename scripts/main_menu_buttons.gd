extends Node2D

const GAME_SCENE := "res://Scenes/main.tscn"

@export var start_pressed := false
@export var scroll_speed := 200.0

@onready var menu_buttons: Control = $Control
@onready var parallax: ParallaxBackground = $Background2/ParallaxBackground

func _ready() -> void:
	get_tree().paused = false
	start_pressed = false
	Globals.game_state = Globals.GameState.MAINMENU
	menu_buttons.visible = true
	#%AnimationPlayer.play('FADE', -1, -1.0, true)

func _process(delta: float) -> void:
	if Globals.game_state == Globals.GameState.MAINMENU:
		parallax.scroll_offset.x += scroll_speed * minf(delta, 0.05)
	
	if %Options.menu_open == false:
		menu_buttons.visible = true
	else:
		menu_buttons.visible = false

func _on_start_pressed() -> void:
	if start_pressed:
		return
	if Globals.game_state != Globals.GameState.MAINMENU:
		return
	start_pressed = true
	%AnimationPlayer.play('FADE')
	if get_tree().change_scene_to_file(GAME_SCENE) != OK:
		start_pressed = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	%Options.open()
	menu_buttons.visible = false
