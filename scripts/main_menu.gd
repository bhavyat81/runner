# main_menu.gd
# Main menu scene controller for Garbage Rush.
extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel

func _ready() -> void:
var hs: int = GameManager.high_score
high_score_label.text = "Best: ---" if hs == 0 else "Best: %d" % hs
play_button.pressed.connect(_on_play_pressed)
get_tree().paused = false

func _on_play_pressed() -> void:
GameManager.start_game()
