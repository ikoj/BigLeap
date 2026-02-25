class_name HUD
extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var fuel_bar: ProgressBar = $FuelBar
@onready var weapon_label: Label = $WeaponLabel
@onready var score_label: Label = $ScoreLabel
@onready var controls_hint: Label = $ControlsHint
@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: RichTextLabel = $GameOverPanel/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton

var hint_timer: float = 4.0

func _ready() -> void:
	layer = 10
	controls_hint.visible = true
	game_over_panel.visible = false
	restart_button.pressed.connect(_on_restart)

func _process(delta: float) -> void:
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			controls_hint.visible = false

func update_stats(health: float, max_health: float, fuel: float, max_fuel: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	fuel_bar.max_value = max_fuel
	fuel_bar.value = fuel

func update_weapon(weapon_name: String) -> void:
	weapon_label.text = "[ " + weapon_name + " ]"

func update_score(kills: int) -> void:
	score_label.text = "Kills: " + str(kills) + " / 3"

func show_game_over(won: bool) -> void:
	game_over_panel.visible = true
	if won:
		game_over_label.text = "[center][color=#00ff88][b]YOU WIN![/b][/color][/center]"
	else:
		game_over_label.text = "[center][color=#ff4444][b]YOU DIED[/b][/color][/center]"

func _on_restart() -> void:
	get_tree().reload_current_scene()
