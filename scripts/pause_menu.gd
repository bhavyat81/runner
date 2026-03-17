# pause_menu.gd
# Pause menu overlay. Handles Resume, Restart, and Main Menu actions.
# Must have process_mode = PROCESS_MODE_ALWAYS so it works while tree is paused.
extends Control

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume_pressed)
	$Panel/VBox/RestartButton.pressed.connect(_on_restart_pressed)
	$Panel/VBox/MenuButton.pressed.connect(_on_menu_pressed)

func _on_resume_pressed() -> void:
	GameManager.resume_game()
	hide()

func _on_restart_pressed() -> void:
	GameManager.resume_game()
	GameManager.start_game()

func _on_menu_pressed() -> void:
	GameManager.resume_game()
	GameManager.go_to_main_menu()
