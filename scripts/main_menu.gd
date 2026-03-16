# main_menu.gd
# Controls the main menu scene.
extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	# Update high score display
	_update_high_score()
	
	# Connect button signal
	play_button.pressed.connect(_on_play_button_pressed)
	
	# Make sure the game tree is not paused
	get_tree().paused = false

func _update_high_score() -> void:
	var hs = GameManager.high_score
	if hs > 0:
		high_score_label.text = "Best: " + str(hs)
	else:
		high_score_label.text = "Best: ---"

func _on_play_button_pressed() -> void:
	GameManager.start_game()
