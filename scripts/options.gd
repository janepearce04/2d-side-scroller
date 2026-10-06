extends Control

@onready var menu_layer: CanvasLayer = $CanvasLayer

signal closed

var menu_open: bool = false

@onready var difficulty_buttons := {
	Globals.Difficulty.EASY: %Easy,
	Globals.Difficulty.NORMAL: %Intermediate,
	Globals.Difficulty.HARD: %Difficult,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_layer.visible = false

	var group := ButtonGroup.new()

	for button in difficulty_buttons.values():
		button.button_group = group

	group.pressed.connect(_on_difficulty_pressed)


func open() -> void:
	menu_open = true
	_sync_buttons()
	menu_layer.visible = true


func close() -> void:
	menu_open = false
	menu_layer.visible = false

func _sync_buttons() -> void:
	var current: BaseButton = difficulty_buttons.get(Globals.game_difficulty)

	if current:
		current.set_pressed_no_signal(true)

func _on_difficulty_pressed(button: BaseButton) -> void:
	Globals.set_difficulty(difficulty_buttons.find_key(button))

func _on_back_pressed() -> void:
	close()
