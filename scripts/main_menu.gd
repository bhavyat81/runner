# main_menu.gd
# Main menu scene controller for Garbage Rush.
extends Control

@onready var play_button: Button = $MenuScroll/VBoxContainer/PlayButton
@onready var high_score_label: Label = $MenuScroll/VBoxContainer/HighScoreLabel

# Pre-game power selection state
var _selected_power: int = GameManager.PreGamePower.NONE
var _power_buttons: Array[Button] = []

func _ready() -> void:
	get_tree().paused = false
	_refresh_stats()
	play_button.pressed.connect(_on_play_pressed)
	_setup_powers_ui()
	_setup_title_anim()

func _refresh_stats() -> void:
	var hs: int = GameManager.high_score
	var coins: int = GameManager.coins
	var lvl: int = GameManager.level
	high_score_label.text = (
		("Best: ---" if hs == 0 else "Best: %d" % hs) +
		"   |   Coins: %d   |   Lv.%d" % [coins, lvl]
	)

func _setup_title_anim() -> void:
	# Animate the play button with a subtle pulse
	var tween := create_tween().set_loops()
	tween.tween_property(play_button, "modulate", Color(1.2, 1.2, 0.8), 0.7)
	tween.tween_property(play_button, "modulate", Color(1.0, 1.0, 1.0), 0.7)

func _setup_powers_ui() -> void:
	# Append power selection UI below existing VBoxContainer children
	var vbox: VBoxContainer = $MenuScroll/VBoxContainer
	# Give the VBoxContainer breathing room between items
	vbox.add_theme_constant_override("separation", 12)

	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(sep)

	var powers_title := Label.new()
	powers_title.text = "— SELECT PRE-GAME POWER —"
	powers_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers_title.add_theme_font_size_override("font_size", 18)
	powers_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vbox.add_child(powers_title)

	var power_data := [
		{
			"power": GameManager.PreGamePower.NONE,
			"label": "No Power",
			"desc": "Standard run",
			"color": Color(0.7, 0.7, 0.7),
		},
		{
			"power": GameManager.PreGamePower.GHOST_MODE,
			"label": "👻 Ghost Mode",
			"desc": "Semi-transparent & invincible for 8s",
			"color": Color(0.4, 0.8, 1.0),
		},
		{
			"power": GameManager.PreGamePower.COIN_FRENZY,
			"label": "💰 Coin Frenzy",
			"desc": "3× coins for the first 15s",
			"color": Color(1.0, 0.85, 0.0),
		},
		{
			"power": GameManager.PreGamePower.HEADSTART,
			"label": "🚀 Headstart",
			"desc": "2× speed + invincible for 5s",
			"color": Color(1.0, 0.4, 0.2),
		},
	]

	for entry in power_data:
		var btn := Button.new()
		btn.text = "%s\n%s" % [entry["label"], entry["desc"]]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 15)
		var pw: int = entry["power"]
		btn.pressed.connect(func(): _select_power(pw))
		vbox.add_child(btn)
		_power_buttons.append(btn)

	# Bottom padding so the last button isn't flush against the screen edge
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(bottom_pad)

	# Default selection
	_select_power(GameManager.PreGamePower.NONE)

func _select_power(power: int) -> void:
	_selected_power = power
	GameManager.selected_power = power as GameManager.PreGamePower
	for i in range(_power_buttons.size()):
		var btn: Button = _power_buttons[i]
		# 0 = NONE, 1 = GHOST, 2 = COIN_FRENZY, 3 = HEADSTART
		var pw_values := [
			GameManager.PreGamePower.NONE,
			GameManager.PreGamePower.GHOST_MODE,
			GameManager.PreGamePower.COIN_FRENZY,
			GameManager.PreGamePower.HEADSTART,
		]
		if i < pw_values.size() and pw_values[i] == power:
			btn.modulate = Color(1.3, 1.3, 1.0)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)
			btn.remove_theme_color_override("font_color")

func _on_play_pressed() -> void:
	GameManager.start_game()
