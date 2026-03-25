# game_over.gd
# Game Over screen showing final stats and restart / menu buttons.
extends Control

@onready var final_score: Label = $Panel/VBox/FinalScore
@onready var garbage_label: Label = $Panel/VBox/GarbageLabel
@onready var best_score: Label = $Panel/VBox/BestScore
@onready var new_high_score_label: Label = $Panel/VBox/NewHighScore
@onready var restart_btn: Button = $Panel/VBox/ButtonRow/RestartButton
@onready var menu_btn: Button = $Panel/VBox/ButtonRow/MenuButton

var _continue_btn: Button = null

func _ready() -> void:
	final_score.text = "Score: %d" % GameManager.score
	garbage_label.text = "Bags Collected: %d" % GameManager.garbage_collected
	best_score.text = "Best: %d" % GameManager.high_score
	# Show "NEW HIGH SCORE!" when the player just set a new record
	new_high_score_label.visible = (GameManager.score > 0 and GameManager.score == GameManager.high_score)
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	get_tree().paused = false
	_setup_continue_button()

func _setup_continue_button() -> void:
	var vbox: VBoxContainer = $Panel/VBox
	_continue_btn = Button.new()
	_continue_btn.text = "Continue (💎 1)  [%d 💎 available]" % GameManager.diamonds
	_continue_btn.custom_minimum_size = Vector2(0, 50)
	_continue_btn.add_theme_font_size_override("font_size", 18)
	var can_continue: bool = GameManager.diamonds >= 1 and not GameManager._continued_this_run
	_continue_btn.disabled = not can_continue
	if can_continue:
		_continue_btn.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	else:
		_continue_btn.modulate = Color(0.5, 0.5, 0.5)
	_continue_btn.pressed.connect(_on_continue)
	# Insert before the ButtonRow
	var button_row: HBoxContainer = $Panel/VBox/ButtonRow
	vbox.add_child(_continue_btn)
	vbox.move_child(_continue_btn, button_row.get_index())

func _on_continue() -> void:
	if GameManager.continue_with_diamond():
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_restart() -> void:
	GameManager.start_game()

func _on_menu() -> void:
	GameManager.go_to_main_menu()
