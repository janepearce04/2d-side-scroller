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

enum GameState {MAINMENU, LEVEL, FAIL}

var game_state: GameState
