class_name Bot
extends Node2D

signal bot_died

@export var bot_color: Color = Color.RED
@export var max_health: float = 80.0

var health: float
var is_dead: bool = false
var terrain_ref: Node = null
var player_ref: Node = null
var weapons: Array = []
var weapon_index: int = 0
var shoot_cooldown: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var on_floor: bool = false
var fuel: float = 100.0

const MAX_FUEL = 100.0
const FUEL_DRAIN = 40.0
const FUEL_REGEN = 25.0
const GRAVITY = 600.0
const HALF_W = 6.0
const HALF_H = 12.0

const WANDER = 0
const CHASE = 1
const SHOOT = 2

var state: int = WANDER
var wander_timer: float = 0.0
var wander_dir: float = 1.0
var los_timer: float = 0.0
var has_los: bool = false
var jump_cooldown: float = 0.0

@onready var body_poly: Polygon2D = $BodyPolygon
@onready var gun_pivot: Node2D = $GunPivot

func _ready() -> void:
	health = max_health
	weapons = WeaponData.all_weapons()
	weapon_index = randi() % weapons.size()
	wander_timer = randf_range(1.0, 3.0)
	body_poly.color = bot_color
	add_to_group("characters")

func _process(_delta: float) -> void:
	if is_dead or player_ref == null:
		return
	var to_player = player_ref.global_position - global_position
	if gun_pivot:
		gun_pivot.rotation = to_player.angle()
	if body_poly:
		body_poly.scale.x = -1.0 if to_player.x < 0 else 1.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	shoot_cooldown = max(0.0, shoot_cooldown - delta)
	los_timer -= delta
	if los_timer <= 0.0:
		_check_los()
		los_timer = 0.25

	velocity.y = clamp(velocity.y + GRAVITY * delta, -800.0, 800.0)

	if on_floor:
		fuel = min(MAX_FUEL, fuel + FUEL_REGEN * delta)
		jump_cooldown = max(0.0, jump_cooldown - delta)

	match state:
		WANDER: _do_wander(delta)
		CHASE: _do_chase(delta)
		SHOOT: _do_shoot(delta)

	_apply_physics(delta)

func _apply_physics(delta: float) -> void:
	position.x += velocity.x * delta
	var push_x = 0
	while push_x < 16 and _wall_overlap(-1.0):
		position.x += 1.0
		push_x += 1
	if push_x > 0:
		velocity.x = max(0.0, velocity.x)
	push_x = 0
	while push_x < 16 and _wall_overlap(1.0):
		position.x -= 1.0
		push_x += 1
	if push_x > 0:
		velocity.x = min(0.0, velocity.x)

	position.y += velocity.y * delta
	var push_y = 0
	while push_y < 20 and _ceil_overlap():
		position.y += 1.0
		push_y += 1
	if push_y > 0:
		velocity.y = max(0.0, velocity.y)
	push_y = 0
	while push_y < 20 and _floor_overlap():
		position.y -= 1.0
		push_y += 1
	if push_y > 0:
		velocity.y = min(0.0, velocity.y)

	on_floor = _is_solid(position.x - HALF_W + 2, position.y + HALF_H + 1) or \
			   _is_solid(position.x + HALF_W - 2, position.y + HALF_H + 1)

	position.x = clamp(position.x, HALF_W, Terrain.WIDTH * Terrain.TILE_PX - HALF_W)
	position.y = clamp(position.y, HALF_H, Terrain.HEIGHT * Terrain.TILE_PX - HALF_H)

func _is_solid(px: float, py: float) -> bool:
	if terrain_ref == null:
		return false
	var t = terrain_ref.tile_at(Vector2(px, py))
	return t == Terrain.STONE or t == Terrain.DIRT or t == Terrain.SAND

func _wall_overlap(side: float) -> bool:
	var x = position.x + HALF_W * side
	return _is_solid(x, position.y - HALF_H + 2) or _is_solid(x, position.y) or _is_solid(x, position.y + HALF_H - 2)

func _floor_overlap() -> bool:
	return _is_solid(position.x - HALF_W + 2, position.y + HALF_H) or \
		   _is_solid(position.x + HALF_W - 2, position.y + HALF_H)

func _ceil_overlap() -> bool:
	return _is_solid(position.x - HALF_W + 2, position.y - HALF_H) or \
		   _is_solid(position.x + HALF_W - 2, position.y - HALF_H)

func _check_los() -> void:
	if player_ref == null or terrain_ref == null:
		has_los = false
		return
	var from = global_position
	var to = player_ref.global_position
	var dist = from.distance_to(to)
	var steps = int(dist / 8.0)
	has_los = true
	for i in range(1, steps):
		var t = float(i) / float(steps)
		var check = from.lerp(to, t)
		if terrain_ref.tile_at(check) == Terrain.STONE:
			has_los = false
			break

func _do_wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_dir = 1.0 if randf() > 0.5 else -1.0
		wander_timer = randf_range(1.0, 3.0)
	velocity.x = move_toward(velocity.x, wander_dir * 100.0, 400.0 * delta)
	if on_floor and jump_cooldown <= 0.0 and randf() < 0.015:
		velocity.y = -280.0
		jump_cooldown = 1.5
	if player_ref != null and global_position.distance_to(player_ref.global_position) < 280.0:
		state = CHASE

func _do_chase(delta: float) -> void:
	if player_ref == null:
		state = WANDER
		return
	var diff = player_ref.global_position - global_position
	var dist = diff.length()
	velocity.x = move_toward(velocity.x, sign(diff.x) * 140.0, 500.0 * delta)
	if on_floor and jump_cooldown <= 0.0:
		var tx = int((position.x + sign(diff.x) * 10.0) / Terrain.TILE_PX)
		var ty = int(position.y / Terrain.TILE_PX)
		if terrain_ref != null:
			var blocked = terrain_ref.cell(tx, ty) != Terrain.EMPTY
			var above_open = terrain_ref.cell(tx, ty - 1) == Terrain.EMPTY
			if blocked and above_open:
				velocity.y = -300.0
				jump_cooldown = 0.8
	if diff.y < -60.0 and fuel > 20.0 and not on_floor:
		velocity.y -= 250.0 * delta
		fuel = max(0.0, fuel - FUEL_DRAIN * delta)
	if dist < 180.0 and has_los:
		state = SHOOT
	elif dist > 400.0:
		state = WANDER

func _do_shoot(delta: float) -> void:
	if player_ref == null:
		state = WANDER
		return
	velocity.x *= 0.88
	if shoot_cooldown <= 0.0:
		_bot_fire()
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > 220.0 or not has_los:
		state = CHASE

func _bot_fire() -> void:
	if player_ref == null:
		return
	var wdata: WeaponData = weapons[weapon_index]
	shoot_cooldown = wdata.cooldown
	var pvel = player_ref.get("velocity") if player_ref.get("velocity") != null else Vector2.ZERO
	var target_pos = player_ref.global_position + pvel * 0.3
	var base_dir = (target_pos - global_position).normalized()
	for _p in wdata.pellet_count:
		var spread_rad = deg_to_rad(wdata.spread_deg)
		var dir = base_dir.rotated(randf_range(-spread_rad, spread_rad))
		_spawn_projectile(wdata, dir)
	if randf() < 0.25:
		weapon_index = randi() % weapons.size()

func _spawn_projectile(wdata: WeaponData, dir: Vector2) -> void:
	if wdata.is_grenade:
		var g = preload("res://scenes/Grenade.tscn").instantiate()
		get_parent().add_child(g)
		g.global_position = global_position
		g.terrain_ref = terrain_ref
		g.owner_node = self
		g.setup(dir * wdata.projectile_speed, wdata.damage, wdata.explode_radius, wdata.color)
		g.add_to_group("projectiles")
		return
	var proj = preload("res://scenes/Projectile.tscn").instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.terrain_ref = terrain_ref
	proj.owner_node = self
	proj.setup(dir, wdata.projectile_speed, wdata.damage, wdata.bounce_count,
		wdata.explode_radius, wdata.color, wdata.max_range, wdata.is_flamethrower)
	proj.add_to_group("projectiles")

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(2.0, 2.0, 2.0), 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.06)
	if health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	_spawn_limbs()
	bot_died.emit()

func _spawn_limbs() -> void:
	for i in 4:
		var limb = Polygon2D.new()
		var sz = randf_range(3.0, 8.0)
		limb.polygon = PackedVector2Array([Vector2(-sz, -sz*0.5), Vector2(sz, -sz*0.5),
			Vector2(sz, sz*0.5), Vector2(-sz, sz*0.5)])
		limb.color = bot_color
		limb.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		get_parent().add_child(limb)
		var lvel = Vector2(randf_range(-180, 180), randf_range(-300, -40))
		var avel = randf_range(-6.0, 6.0)
		var prev_t = [0.0]
		var duration = 1.0
		var tween = create_tween()
		tween.tween_method(func(t: float):
			var dt = t - prev_t[0]
			prev_t[0] = t
			lvel.y += 600.0 * dt
			limb.position += lvel * dt
			limb.rotation += avel * dt
			limb.modulate.a = 1.0 - t / duration
		, 0.0, duration, duration)
		tween.tween_callback(limb.queue_free)
