extends Node

var gameStarted: bool

var playerBody: CharacterBody2D

var playerAlive: bool
var playerDamageZone: Area2D
var playerDamageAmt: float

var flierDamageZone: Area2D
var flierDamageAmt: float

var crawlerDamageZone: Area2D
var crawlerDamageAmt: float

var BossDamageZone: Area2D
var BossDamageAmt: float

enum GameState {MAINMENU, LEVEL, PAUSE, FAIL}

var game_state: GameState

enum Difficulty { EASY = 1, NORMAL = 2, HARD = 3 }
signal difficulty_changed

var game_difficulty: int = Difficulty.NORMAL

const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	game_state = GameState.MAINMENU
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		game_difficulty = cfg.get_value("game", "difficulty", Difficulty.NORMAL)

func set_difficulty(value: int) -> void:
	game_difficulty = value
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keeps any other saved settings
	cfg.set_value("game", "difficulty", value)
	print("game difficulty set to ", game_difficulty)
	cfg.save(SETTINGS_PATH)
	difficulty_changed.emit()
