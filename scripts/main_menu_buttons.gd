extends Node2D

const GAME_SCENE := "res://Scenes/main.tscn"

@export var scroll_speed := 200.0

@onready var menu_buttons: Control = $Control
@onready var parallax: ParallaxBackground = $Background2/ParallaxBackground

func _ready() -> void:
	Globals.game_state = Globals.GameState.MAINMENU
	menu_buttons.visible = true
	ResourceLoader.load_threaded_request(GAME_SCENE)

func _process(delta: float) -> void:
	if Globals.game_state == Globals.GameState.MAINMENU:
		parallax.scroll_offset.x += scroll_speed * minf(delta, 0.05)
	
	if %Options.menu_open == false:
		menu_buttons.visible = true
	else:
		menu_buttons.visible = false


func _on_start_pressed() -> void:
	var game := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	%AnimationPlayer.play('FADE')
	await %AnimationPlayer.animation_finished
	if game:
		get_tree().change_scene_to_packed(game)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	%Options.open()
	menu_buttons.visible = false
