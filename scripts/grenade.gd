class_name Grenade
extends Node2D

var damage: float = 60.0
var explode_radius: float = 38.0
var terrain_ref: Node = null
var owner_node: Node = null
var fuse_timer: float = 2.8
var has_exploded: bool = false
var proj_color: Color = Color(0.533, 1.0, 0.267)
var velocity: Vector2 = Vector2.ZERO

const GRAVITY = 1080.0
const BOUNCE_DAMP = 0.55
const HALF_R = 4.0

func _ready() -> void:
	queue_redraw()

func setup(launch_velocity: Vector2, dmg: float, explode: float, col: Color) -> void:
	velocity = launch_velocity
	damage = dmg
	explode_radius = explode
	proj_color = col
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, proj_color)
	draw_circle(Vector2.ZERO, 2.0, Color(0.1, 0.1, 0.1))

func _physics_process(delta: float) -> void:
	if has_exploded:
		return
	fuse_timer -= delta
	if fuse_timer <= 0.0:
		_explode()
		return

	velocity.y = clamp(velocity.y + GRAVITY * delta, -1200.0, 1200.0)
	position += velocity * delta
	_resolve_terrain()

func _resolve_terrain() -> void:
	if terrain_ref == null:
		return
	var tile = terrain_ref.tile_at(global_position)
	if tile == Terrain.EMPTY:
		return
	if tile == Terrain.STONE:
		_explode()
		return
	var tx = int(global_position.x / Terrain.TILE_PX)
	var ty = int(global_position.y / Terrain.TILE_PX)
	var tile_center = Vector2((tx + 0.5) * Terrain.TILE_PX, (ty + 0.5) * Terrain.TILE_PX)
	var push = global_position - tile_center
	if abs(push.x) > abs(push.y):
		position.x += sign(push.x) * (Terrain.TILE_PX * 0.5 - abs(push.x) + 1)
		velocity.x = -velocity.x * BOUNCE_DAMP
	else:
		position.y += sign(push.y) * (Terrain.TILE_PX * 0.5 - abs(push.y) + 1)
		velocity.y = -velocity.y * BOUNCE_DAMP
		velocity.x *= 0.85

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	if terrain_ref != null:
		terrain_ref.explode(global_position, explode_radius, true)
	_hurt_nearby()
	queue_free()

func _hurt_nearby() -> void:
	var characters = get_tree().get_nodes_in_group("characters")
	for ch in characters:
		if ch == owner_node or not ch.has_method("take_damage"):
			continue
		var dist = global_position.distance_to(ch.global_position)
		if dist <= explode_radius:
			var falloff = 1.0 - clamp(dist / explode_radius, 0.0, 1.0)
			ch.take_damage(damage * (0.2 + 0.8 * falloff))
