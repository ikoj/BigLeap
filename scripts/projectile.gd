class_name Projectile
extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 10.0
var bounces_left: int = 0
var explode_radius: float = 0.0
var proj_color: Color = Color.WHITE
var max_range: float = 0.0
var traveled: float = 0.0
var is_flamethrower: bool = false
var terrain_ref: Node = null
var owner_node: Node = null

const HIT_RADIUS = 5.0

func _ready() -> void:
	queue_redraw()

func setup(dir: Vector2, spd: float, dmg: float, bounces: int, explode: float,
		col: Color, mrange: float, flame: bool) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	bounces_left = bounces
	explode_radius = explode
	proj_color = col
	max_range = mrange
	is_flamethrower = flame
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, proj_color)

func _physics_process(delta: float) -> void:
	var move_dist = speed * delta
	var steps = max(1, int(move_dist / 4.0))
	var step_size = move_dist / float(steps)

	for _s in steps:
		position += direction * step_size
		traveled += step_size

		if max_range > 0.0 and traveled >= max_range:
			queue_free()
			return

		if _check_character_hit():
			return

		if terrain_ref != null:
			var t = terrain_ref.tile_at(global_position)
			if t != Terrain.EMPTY:
				if _handle_terrain_hit(t):
					return

func _check_character_hit() -> bool:
	var characters = get_tree().get_nodes_in_group("characters")
	for ch in characters:
		if ch == owner_node:
			continue
		if not ch.has_method("take_damage"):
			continue
		var ch_dead = ch.get("is_dead")
		if ch_dead != null and ch_dead:
			continue
		var dist = global_position.distance_to(ch.global_position)
		if dist <= HIT_RADIUS + 8.0:
			ch.take_damage(damage)
			if explode_radius > 0.0 and terrain_ref != null:
				terrain_ref.explode(global_position, explode_radius, true)
				_damage_splash()
			queue_free()
			return true
	return false

func _damage_splash() -> void:
	if explode_radius <= 0.0:
		return
	var characters = get_tree().get_nodes_in_group("characters")
	for ch in characters:
		if ch == owner_node:
			continue
		if not ch.has_method("take_damage"):
			continue
		var dist = global_position.distance_to(ch.global_position)
		if dist < explode_radius and dist > HIT_RADIUS + 8.0:
			var falloff = 1.0 - clamp(dist / explode_radius, 0.0, 1.0)
			ch.take_damage(damage * falloff * 0.5)

func _handle_terrain_hit(tile_type: int) -> bool:
	if is_flamethrower:
		if terrain_ref != null and tile_type != Terrain.STONE:
			terrain_ref.set_tile(global_position, Terrain.FIRE)
		queue_free()
		return true
	if bounces_left > 0:
		bounces_left -= 1
		var normal = _get_tile_normal()
		direction = direction.bounce(normal)
		return false
	if explode_radius > 0.0 and terrain_ref != null:
		terrain_ref.explode(global_position, explode_radius, true)
		_damage_splash()
	elif tile_type != Terrain.STONE and terrain_ref != null:
		terrain_ref.set_tile(global_position, Terrain.EMPTY)
	queue_free()
	return true

func _get_tile_normal() -> Vector2:
	if terrain_ref == null:
		return Vector2.UP
	var tx = int(global_position.x / Terrain.TILE_PX)
	var ty = int(global_position.y / Terrain.TILE_PX)
	var left = terrain_ref.cell(tx - 1, ty) == Terrain.EMPTY
	var right = terrain_ref.cell(tx + 1, ty) == Terrain.EMPTY
	var up = terrain_ref.cell(tx, ty - 1) == Terrain.EMPTY
	var down = terrain_ref.cell(tx, ty + 1) == Terrain.EMPTY
	var nx = 0.0
	var ny = 0.0
	if left: nx += 1.0
	if right: nx -= 1.0
	if up: ny += 1.0
	if down: ny -= 1.0
	if nx == 0.0 and ny == 0.0:
		ny = 1.0
	return Vector2(nx, ny).normalized()
