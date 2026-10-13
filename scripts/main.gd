extends Node2D
class_name level_1

@onready var player = %PLAYER
const MENU_SCENE := "res://Scenes/main_menu.tscn"
 
@export var wall_drop_distance := 850.0
var boss_started := false
var menu_pressed: bool = false

func _ready() -> void:
	get_tree().paused = false
	Globals.playerAlive = true
	Globals.game_state = Globals.GameState.LEVEL
	Globals.gameStarted = true
	%"GAME OVER".visible = false
	%FADE_LAYER.visible = true
	%PLAYER_entered.body_entered.connect(_on_boss_room_body_entered)
	%RESTARTBUTTON.pressed.connect(_restart)
	%FIO_AnimationPlayer.play('fade')
	await %FIO_AnimationPlayer.animation_finished
	%FADE_LAYER.visible = false
	menu_pressed=false
 
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.player_hp)
	
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.mob_died.connect(player.add_souls)
	player.souls_level_changed.connect(func(s): %"Level Souls".text = "SOULS: %d" % s)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not %GO_AnimationPlayer.is_playing():
		_restart()

func _on_health_changed(hp: float) -> void:
	%Health.text = "Health: %d" % hp
	%HealthBar.value = hp

func _on_boss_room_body_entered(body: Node2D) -> void:
	if boss_started or not body.is_in_group("player"):
		return
	
	boss_started = true
	var tween := create_tween()
	tween.tween_property(%BOSSWALLS, "position:y", %BOSSWALLS.position.y + wall_drop_distance, 0.6)
	await tween.finished
	%FIRE_DEMON.activate()
	%FIRE_DEMON.health_bar.visible = true

func _on_player_died() -> void:
	Globals.game_state = Globals.GameState.FAIL
	get_tree().call_group("mobs", "set_physics_process", false)
	%"GAME OVER".visible = true
	%GO_AnimationPlayer.play("game over")
 
func _restart() -> void:
	%"GAME OVER".visible = false
	if Globals.game_state == Globals.GameState.LEVEL or Globals.game_state == Globals.GameState.FAIL:
		get_tree().reload_current_scene()

func _on_fire_demon_boss_defeated() -> void:
	%WINNER.visible = true
	%FIRE_DEMON.health_bar.visible = false
	var tween := create_tween()
	tween.tween_property(%BOSSWALLS, "position:y", %BOSSWALLS.position.y - wall_drop_distance, 1.0)

func _on_menu_pressed() -> void:
	if menu_pressed:
		return
	menu_pressed = true
	print("level: menu pressed")

	var ap: AnimationPlayer = %FIO_AnimationPlayer
	ap.process_mode = Node.PROCESS_MODE_ALWAYS
	%FADE_LAYER.visible = true
	ap.play('fade', -1, -1.0, true)                      # plays backwards (fade out)
	await get_tree().create_timer(ap.get_animation('fade').length).timeout   # timers run while paused

	get_tree().paused = false
	Globals.game_state = Globals.GameState.MAINMENU
	var err := get_tree().change_scene_to_file(MENU_SCENE)
	if err != OK:
		push_error("Could not load " + MENU_SCENE)
		menu_pressed = false
