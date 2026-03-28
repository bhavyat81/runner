# main_menu.gd
# Main menu scene controller for Garbage Rush.
extends Control

@onready var play_button: Button = $MenuScroll/VBoxContainer/PlayButton
@onready var high_score_label: Label = $MenuScroll/VBoxContainer/HighScoreLabel
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

func _ready() -> void:
	get_tree().paused = false
	_refresh_stats()
	play_button.pressed.connect(_on_play_pressed)
	_setup_entrance_anim()
	_setup_title_anim()

func _refresh_stats() -> void:
	var hs: int = GameManager.high_score
	var coins: int = GameManager.coins
	var diamonds: int = GameManager.diamonds
	var lvl: int = GameManager.level
	high_score_label.text = (
		("🏆 Best: ---" if hs == 0 else "🏆 Best: %d" % hs) + "\n" +
		"🪙 %d   💎 %d   |   Lv.%d" % [coins, diamonds, lvl]
	)

func _setup_entrance_anim() -> void:
	# Slide title in from above
	var orig_title_y := title_label.position.y
	title_label.position.y = orig_title_y - 220.0
	var t1 := create_tween()
	t1.tween_property(title_label, "position:y", orig_title_y, 0.75) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Fade subtitle in with slight delay
	subtitle_label.modulate.a = 0.0
	var t2 := create_tween()
	t2.tween_interval(0.35)
	t2.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)
	# Slide menu container up and fade in
	var menu_scroll: Control = $MenuScroll
	var orig_menu_y := menu_scroll.position.y
	menu_scroll.position.y = orig_menu_y + 100.0
	menu_scroll.modulate.a = 0.0
	var t3 := create_tween()
	t3.tween_interval(0.2)
	t3.tween_property(menu_scroll, "position:y", orig_menu_y, 0.65) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var t4 := create_tween()
	t4.tween_interval(0.2)
	t4.tween_property(menu_scroll, "modulate:a", 1.0, 0.5)

func _setup_title_anim() -> void:
	# Neon color cycle on the title label
	var title_tween := create_tween().set_loops()
	title_tween.tween_property(title_label, "modulate", Color(0.35, 1.0, 0.35), 1.8)
	title_tween.tween_property(title_label, "modulate", Color(0.2, 0.85, 1.0), 1.8)
	title_tween.tween_property(title_label, "modulate", Color(1.0, 0.75, 0.15), 1.8)
	# Pulse play button to draw attention
	var btn_tween := create_tween().set_loops()
	btn_tween.tween_property(play_button, "modulate", Color(1.15, 1.2, 1.0), 0.85)
	btn_tween.tween_property(play_button, "modulate", Color(1.0, 1.0, 1.0), 0.85)

func _on_play_pressed() -> void:
	GameManager.start_game()
