extends Control

@onready var menu_visible: CanvasLayer = %PAUSEMENU

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu_visible.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_main_pause_menu() -> void:
	if menu_visible.visible == false:
		menu_visible.visible = true

func _on_main_unpaused() -> void:
	if menu_visible.visible == true:
		menu_visible.visible = false
