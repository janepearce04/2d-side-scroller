extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Globals.game_state == Globals.GameState.MAINMENU:
		%ParallaxBackground.scroll_base_offset = Vector2(-920, 0)
	else:
		return

var scroll_x = 0
var scroll = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Globals.game_state == Globals.GameState.MAINMENU:
		scroll -= 50 * delta
		%ParallaxBackground.scroll_offset.x = scroll
	else:
		return
