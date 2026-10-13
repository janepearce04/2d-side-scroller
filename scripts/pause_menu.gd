extends Control

@onready var menu_visible: CanvasLayer = %PAUSEMENU
@onready var options: Control = %Options
@onready var main: Node2D = $"../.."

#signal restart
#signal quit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_visible.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_visible.layer = 10   # above the HUD
	menu_visible.visible = false

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if Globals.game_state == Globals.GameState.FAIL:
		return
	
	if options.menu_open:
		options.close()
		menu_visible.visible = true
	else:
		_set_paused(not get_tree().paused)


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	menu_visible.visible = value
	print("paused is ", value)

	if value:
		Globals.game_state = Globals.GameState.PAUSE
	else:
		Globals.game_state = Globals.GameState.LEVEL


func _on_resume_pressed() -> void:
	print("resume pressed")
	_set_paused(false)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	print("quit pressed")
	get_tree().quit()

var menu_pressed: bool = false
signal go_to_menu

func _on_menu_pressed() -> void:
	if menu_pressed:
		return
		
	menu_pressed = true
	menu_visible.visible = false
	go_to_menu.emit()

func _on_options_pressed() -> void:
	print("options pressed")
	options.open()
	menu_visible.visible = false

func _on_options_closed() -> void:
	print("options closed")
	menu_visible.visible = true

func _on_player_died() -> void:
	Globals.game_state = Globals.GameState.FAIL
	get_tree().call_group("mobs", "set_physics_process", false)
	%"GAME OVER".visible = true
	%GO_AnimationPlayer.play("game over")
