extends Control

@onready var menu_visible: CanvasLayer = %PAUSEMENU
@onready var options: Control = %Options
@onready var main: Node2D = $"../.."

#signal restart
#signal quit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_visible.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return

	if options.menu_open:
		options.close()
		menu_visible.visible = true
	else:
		_set_paused(not get_tree().paused)


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	menu_visible.visible = value

	if value:
		Globals.game_state = Globals.GameState.PAUSE
	else:
		Globals.game_state = Globals.GameState.LEVEL


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_restart_pressed() -> void:
	main._restart()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	options.open()
	menu_visible.visible = false

func _on_options_closed() -> void:
	menu_visible.visible = true
