extends State

@export var walk_state: State

func update(_delta: float) -> void:
	if Input.get_vector("ui_up", "ui_left", "ui_right", "ui_down") != Vector2.ZERO:
		switch_state.emit(walk_state)
