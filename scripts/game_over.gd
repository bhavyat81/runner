# game_over.gd
# Standalone game over scene (alternative to overlay).
# Used if you want a separate scene instead of an overlay.
extends Control

@onready var final_score_label: Label = $VBoxContainer/FinalScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var menu_button: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	# Display scores
	final_score_label.text = "Score: " + str(GameManager.score)
	high_score_label.text = "Best: " + str(GameManager.high_score)
	
	# Connect buttons
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	# Make sure tree is not paused
	get_tree().paused = false

func _on_restart_pressed() -> void:
	GameManager.start_game()

func _on_menu_pressed() -> void:
	GameManager.go_to_main_menu()
