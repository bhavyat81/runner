# main_menu.gd
# Main menu scene controller for Garbage Rush.
extends Control

@onready var play_button: Button = $MenuScroll/VBoxContainer/PlayButton
@onready var high_score_label: Label = $MenuScroll/VBoxContainer/HighScoreLabel

func _ready() -> void:
	get_tree().paused = false
	_refresh_stats()
	play_button.pressed.connect(_on_play_pressed)
	_setup_title_anim()

func _refresh_stats() -> void:
	var hs: int = GameManager.high_score
	var coins: int = GameManager.coins
	var diamonds: int = GameManager.diamonds
	var lvl: int = GameManager.level
	high_score_label.text = (
		("Best: ---" if hs == 0 else "Best: %d" % hs) +
		"   |   🪙 %d   💎 %d   |   Lv.%d" % [coins, diamonds, lvl]
	)

func _setup_title_anim() -> void:
	# Animate the play button with a subtle pulse
	var tween := create_tween().set_loops()
	tween.tween_property(play_button, "modulate", Color(1.2, 1.2, 0.8), 0.7)
	tween.tween_property(play_button, "modulate", Color(1.0, 1.0, 1.0), 0.7)

func _on_play_pressed() -> void:
	GameManager.start_game()
