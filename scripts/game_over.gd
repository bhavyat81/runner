# game_over.gd
# Game Over screen showing final stats and restart / menu buttons.
extends Control

@onready var final_score: Label = $Panel/VBox/FinalScore
@onready var garbage_label: Label = $Panel/VBox/GarbageLabel
@onready var best_score: Label = $Panel/VBox/BestScore
@onready var restart_btn: Button = $Panel/VBox/ButtonRow/RestartButton
@onready var menu_btn: Button = $Panel/VBox/ButtonRow/MenuButton

func _ready() -> void:
final_score.text = "Score: %d" % GameManager.score
garbage_label.text = "Bags Collected: %d" % GameManager.garbage_collected
best_score.text = "Best: %d" % GameManager.high_score
restart_btn.pressed.connect(_on_restart)
menu_btn.pressed.connect(_on_menu)
get_tree().paused = false

func _on_restart() -> void:
GameManager.start_game()

func _on_menu() -> void:
GameManager.go_to_main_menu()
