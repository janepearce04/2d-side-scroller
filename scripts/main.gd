extends Node2D
class_name level_1

@onready var player: player1 = %PLAYER
 
@export var wall_drop_distance := 200.0
var boss_started := false

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
 
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.player_hp)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not %GO_AnimationPlayer.is_playing():
		_restart()

func _on_health_changed(hp: float) -> void:
	%Health.text = "Health: %d" % hp

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
	get_tree().call_group("mobs", "set_physics_process", false)
 
	%GO_AnimationPlayer.play("game over")
	await %GO_AnimationPlayer.animation_finished
	%"GAME OVER".visible = true
 
func _restart() -> void:
	%"GAME OVER".visible = false
	get_tree().reload_current_scene()

func _on_fire_demon_boss_defeated() -> void:
	%WINNER.visible = true
	%FIRE_DEMON.health_bar.visible = false
