# main_menu.gd
# Main menu scene controller for Garbage Rush.
extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var _vbox: VBoxContainer = $VBoxContainer

# Pre-game power selection state
var _selected_power: int = GameManager.PreGamePower.NONE
var _power_buttons: Array[Button] = []
var _level_buttons: Array[Button] = []

func _ready() -> void:
	get_tree().paused = false
	_setup_scroll_layout()
	_refresh_stats()
	play_button.pressed.connect(_on_play_pressed)
	_setup_level_ui()
	_setup_powers_ui()
	_setup_title_anim()

func _setup_scroll_layout() -> void:
	# Wrap the existing VBoxContainer in a ScrollContainer so all content is
	# accessible even on small screens. We do this at runtime to avoid modifying
	# the scene file.
	var parent := _vbox.get_parent()
	var scroll := ScrollContainer.new()
	# Use anchor-based layout so it adapts to any resolution
	scroll.layout_mode = 1
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 290.0
	scroll.offset_top = 290.0
	scroll.offset_right = -290.0
	scroll.offset_bottom = -50.0
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.remove_child(_vbox)
	_vbox.layout_mode = 2
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_vbox)
	parent.add_child(scroll)

func _refresh_stats() -> void:
	var hs: int = GameManager.high_score
	var coins: int = GameManager.coins
	var lvl: int = GameManager.level
	high_score_label.text = (
		("Best: ---" if hs == 0 else "Best: %d" % hs) +
		"   |   🪙 %d   |   Lv.%d" % [coins, lvl]
	)

func _setup_title_anim() -> void:
	# Animate the play button with a subtle pulse
	var tween := create_tween().set_loops()
	tween.tween_property(play_button, "modulate", Color(1.2, 1.2, 0.8), 0.7)
	tween.tween_property(play_button, "modulate", Color(1.0, 1.0, 1.0), 0.7)

func _setup_level_ui() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	var lvl_title := Label.new()
	lvl_title.text = "— SELECT LEVEL —"
	lvl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_title.add_theme_font_size_override("font_size", 18)
	lvl_title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_vbox.add_child(lvl_title)

	# Use a 2-column grid via two HBoxContainers for a compact layout
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	_vbox.add_child(row1)
	_vbox.add_child(row2)

	for i in range(GameManager.LEVEL_NAMES.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 14)
		var lvl_id: int = i
		btn.pressed.connect(func(): _on_level_button_pressed(lvl_id))
		if i < 2:
			row1.add_child(btn)
		else:
			row2.add_child(btn)
		_level_buttons.append(btn)

	_refresh_level_buttons()

func _refresh_level_buttons() -> void:
	var level_icons := ["🏙️", "🛣️", "🏜️", "🌉"]
	for i in range(_level_buttons.size()):
		var btn: Button = _level_buttons[i]
		var name_str: String = "%s %s" % [level_icons[i], GameManager.LEVEL_NAMES[i]]
		if GameManager.unlocked_levels[i]:
			btn.text = name_str
			btn.modulate = Color(1.3, 1.3, 1.0) if GameManager.selected_level == i else Color(1.0, 1.0, 1.0)
			btn.add_theme_color_override("font_color",
				Color(1.0, 1.0, 0.3) if GameManager.selected_level == i else Color(1.0, 1.0, 1.0))
		else:
			var cost: int = GameManager.LEVEL_COSTS[i]
			btn.text = "%s  🔒 %d 🪙" % [name_str, cost]
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

func _on_level_button_pressed(lvl_id: int) -> void:
	if GameManager.unlocked_levels[lvl_id]:
		GameManager.select_level(lvl_id)
		_refresh_level_buttons()
	else:
		# Try to unlock
		if GameManager.unlock_level(lvl_id):
			GameManager.select_level(lvl_id)
			_refresh_stats()
			_refresh_level_buttons()

func _setup_powers_ui() -> void:
	# Append power selection UI below existing VBoxContainer children
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	var powers_title := Label.new()
	powers_title.text = "— SELECT PRE-GAME POWER —"
	powers_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers_title.add_theme_font_size_override("font_size", 16)
	powers_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_vbox.add_child(powers_title)

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
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 14)
		var pw: int = entry["power"]
		btn.pressed.connect(func(): _select_power(pw))
		_vbox.add_child(btn)
		_power_buttons.append(btn)

	# Bottom padding
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	_vbox.add_child(spacer)

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
