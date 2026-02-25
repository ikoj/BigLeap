extends Node2D

@onready var terrain_node: Terrain = $Terrain
@onready var entities_layer: Node2D = $EntitiesLayer
@onready var player_node: Player = $EntitiesLayer/Player
@onready var hud_node: HUD = $HUD
@onready var camera: Camera2D = $Camera2D

var bots: Array = []
var bots_dead: int = 0
var cam_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	_setup_player()
	_setup_bots()
	_connect_signals()
	cam_target = player_node.global_position
	camera.global_position = cam_target
	hud_node.update_weapon(player_node.weapons[0].name)
	hud_node.update_score(0)

func _setup_player() -> void:
	player_node.terrain_ref = terrain_node
	player_node.global_position = Vector2(12 * Terrain.TILE_PX, 10 * Terrain.TILE_PX)
	_clear_spawn(player_node.global_position, 8)

func _clear_spawn(world_pos: Vector2, radius_tiles: int) -> void:
	var cx = int(world_pos.x / Terrain.TILE_PX)
	var cy = int(world_pos.y / Terrain.TILE_PX)
	for dy in range(-radius_tiles, radius_tiles + 1):
		for dx in range(-radius_tiles, radius_tiles + 1):
			if dx * dx + dy * dy <= radius_tiles * radius_tiles:
				terrain_node.set_cell(cx + dx, cy + dy, Terrain.EMPTY)
	terrain_node.force_refresh()

func _setup_bots() -> void:
	var bot_colors = [Color(1.0, 0.2, 0.2), Color(1.0, 0.85, 0.1), Color(0.4, 0.5, 1.0)]
	var bot_scene = preload("res://scenes/Bot.tscn")
	for i in 3:
		var bot = bot_scene.instantiate()
		bot.bot_color = bot_colors[i]
		entities_layer.add_child(bot)
		bot.terrain_ref = terrain_node
		bot.player_ref = player_node
		var spawn_x = (Terrain.WIDTH - 12) * Terrain.TILE_PX + randf_range(-24, 24)
		var spawn_y = 10 * Terrain.TILE_PX + randf_range(-8, 24)
		bot.global_position = Vector2(spawn_x, spawn_y)
		_clear_spawn(bot.global_position, 6)
		bot.bot_died.connect(_on_bot_died)
		bots.append(bot)

func _connect_signals() -> void:
	player_node.player_died.connect(_on_player_died)
	player_node.weapon_changed.connect(hud_node.update_weapon)
	player_node.stats_updated.connect(hud_node.update_stats)

func _process(delta: float) -> void:
	if not player_node.is_dead:
		var target = player_node.global_position
		cam_target = cam_target.lerp(target, 1.0 - pow(1.0 - 0.08, delta * 60.0))
		var hw = 640.0 / camera.zoom.x
		var hh = 360.0 / camera.zoom.y
		var max_x = Terrain.WIDTH * Terrain.TILE_PX - hw
		var max_y = Terrain.HEIGHT * Terrain.TILE_PX - hh
		camera.global_position = Vector2(
			clamp(cam_target.x, hw, max_x),
			clamp(cam_target.y, hh, max_y)
		)

func _on_player_died() -> void:
	hud_node.show_game_over(false)

func _on_bot_died() -> void:
	bots_dead += 1
	player_node.kills = bots_dead
	hud_node.update_score(bots_dead)
	if bots_dead >= 3:
		hud_node.show_game_over(true)
