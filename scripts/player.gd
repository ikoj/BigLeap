class_name Player
extends Node2D

signal player_died
signal weapon_changed(weapon_name: String)
signal stats_updated(health: float, max_health: float, fuel: float, max_fuel: float)

@export var max_health: float = 100.0
@export var max_fuel: float = 100.0

var health: float
var fuel: float
var weapon_index: int = 0
var weapons: Array = []
var is_dead: bool = false
var shoot_cooldown: float = 0.0
var terrain_ref: Node = null
var kills: int = 0
var velocity: Vector2 = Vector2.ZERO
var on_floor: bool = false
var is_crawling: bool = false

const SPEED = 180.0
const JUMP_FORCE = -320.0
const JET_ACCEL = 280.0
const FUEL_DRAIN = 40.0
const FUEL_REGEN = 25.0
const FRICTION = 0.82
const GRAVITY = 600.0
const HALF_W = 6.0
const HALF_H = 12.0
const CRAWL_H = 4.0

@onready var body_polygon: Polygon2D = $BodyPolygon
@onready var gun_pivot: Node2D = $GunPivot
@onready var jet_particles: Node2D = $JetParticles

func _ready() -> void:
	health = max_health
	fuel = max_fuel
	weapons = WeaponData.all_weapons()
	add_to_group("characters")

func _process(delta: float) -> void:
	if is_dead:
		return
	_update_aim()
	_handle_jet_particles()
	stats_updated.emit(health, max_health, fuel, max_fuel)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	shoot_cooldown = max(0.0, shoot_cooldown - delta)
	_handle_input(delta)
	_apply_physics(delta)
	_handle_shoot()

func _handle_input(delta: float) -> void:
	is_crawling = MobileInput.is_crawling()
	var input_x = MobileInput.get_move_x()

	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * SPEED, SPEED * 6.0 * delta)
	else:
		velocity.x *= FRICTION

	if on_floor:
		fuel = min(max_fuel, fuel + FUEL_REGEN * delta)
		if MobileInput.consume_jump_just():
			velocity.y = JUMP_FORCE
	elif MobileInput.is_jump_held() and fuel > 0.0:
		velocity.y -= JET_ACCEL * delta
		fuel = max(0.0, fuel - FUEL_DRAIN * delta)

func _apply_physics(delta: float) -> void:
	velocity.y = clamp(velocity.y + GRAVITY * delta, -800.0, 800.0)
	var hh = CRAWL_H if is_crawling else HALF_H

	position.x += velocity.x * delta
	var push_x = 0
	while push_x < 16 and _wall_overlap(-1.0, hh):
		position.x += 1.0
		push_x += 1
	if push_x > 0:
		velocity.x = max(0.0, velocity.x)
	push_x = 0
	while push_x < 16 and _wall_overlap(1.0, hh):
		position.x -= 1.0
		push_x += 1
	if push_x > 0:
		velocity.x = min(0.0, velocity.x)

	position.y += velocity.y * delta
	var push_y = 0
	while push_y < 20 and _ceil_overlap(hh):
		position.y += 1.0
		push_y += 1
	if push_y > 0:
		velocity.y = max(0.0, velocity.y)
	push_y = 0
	while push_y < 20 and _floor_overlap(hh):
		position.y -= 1.0
		push_y += 1
	if push_y > 0:
		velocity.y = min(0.0, velocity.y)

	on_floor = _is_solid(position.x - HALF_W + 2, position.y + hh + 1) or \
			   _is_solid(position.x + HALF_W - 2, position.y + hh + 1)

	position.x = clamp(position.x, HALF_W, Terrain.WIDTH * Terrain.TILE_PX - HALF_W)
	position.y = clamp(position.y, hh, Terrain.HEIGHT * Terrain.TILE_PX - hh)

func _is_solid(px: float, py: float) -> bool:
	if terrain_ref == null:
		return false
	var t = terrain_ref.tile_at(Vector2(px, py))
	return t == Terrain.STONE or t == Terrain.DIRT or t == Terrain.SAND

func _wall_overlap(side: float, hh: float) -> bool:
	var x = position.x + HALF_W * side
	return _is_solid(x, position.y - hh + 2) or _is_solid(x, position.y) or _is_solid(x, position.y + hh - 2)

func _floor_overlap(hh: float) -> bool:
	return _is_solid(position.x - HALF_W + 2, position.y + hh) or \
		   _is_solid(position.x + HALF_W - 2, position.y + hh)

func _ceil_overlap(hh: float) -> bool:
	return _is_solid(position.x - HALF_W + 2, position.y - hh) or \
		   _is_solid(position.x + HALF_W - 2, position.y - hh)

func _update_aim() -> void:
	if gun_pivot == null:
		return
	var aim_pos = MobileInput.get_aim_world_pos(get_viewport())
	var to_aim = aim_pos - global_position
	gun_pivot.rotation = to_aim.angle()
	if body_polygon:
		body_polygon.scale.x = -1.0 if to_aim.x < 0 else 1.0

func _handle_jet_particles() -> void:
	if jet_particles == null:
		return
	jet_particles.visible = (not on_floor) and MobileInput.is_jump_held() and fuel > 0.0


func _handle_shoot() -> void:
	if not MobileInput.is_mobile:
		for i in min(5, weapons.size()):
			if Input.is_key_pressed(KEY_1 + i):
				if weapon_index != i:
					weapon_index = i
					weapon_changed.emit(weapons[weapon_index].name)
				break
	if MobileInput.consume_weapon_prev():
		weapon_index = (weapon_index - 1 + weapons.size()) % weapons.size()
		weapon_changed.emit(weapons[weapon_index].name)
	if MobileInput.consume_weapon_next():
		weapon_index = (weapon_index + 1) % weapons.size()
		weapon_changed.emit(weapons[weapon_index].name)
	if MobileInput.is_shooting() and shoot_cooldown <= 0.0:
		_fire_weapon()

func _fire_weapon() -> void:
	var wdata: WeaponData = weapons[weapon_index]
	shoot_cooldown = wdata.cooldown
	var mouse_pos = get_global_mouse_position()
	var base_dir = (mouse_pos - global_position).normalized()
	for _p in wdata.pellet_count:
		var spread_rad = deg_to_rad(wdata.spread_deg)
		var dir = base_dir.rotated(randf_range(-spread_rad, spread_rad))
		_spawn_projectile(wdata, dir)

func _spawn_projectile(wdata: WeaponData, dir: Vector2) -> void:
	if wdata.is_grenade:
		var g = preload("res://scenes/Grenade.tscn").instantiate()
		get_parent().add_child(g)
		g.global_position = global_position
		g.terrain_ref = terrain_ref
		g.owner_node = self
		g.setup(dir * wdata.projectile_speed + velocity * 0.5, wdata.damage, wdata.explode_radius, wdata.color)
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
	tween.tween_property(self, "modulate", Color.RED, 0.06)
	tween.tween_property(self, "modulate", Color.WHITE, 0.06)
	if health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	_spawn_limbs()
	player_died.emit()

func _spawn_limbs() -> void:
	var limb_colors = [Color(0.2, 0.8, 0.2), Color(0.15, 0.65, 0.15),
		Color(0.25, 0.9, 0.25), Color(0.1, 0.7, 0.1), Color(0.3, 0.75, 0.3)]
	for i in 5:
		var limb = Polygon2D.new()
		var sz = randf_range(4.0, 10.0)
		limb.polygon = PackedVector2Array([Vector2(-sz, -sz*0.5), Vector2(sz, -sz*0.5),
			Vector2(sz, sz*0.5), Vector2(-sz, sz*0.5)])
		limb.color = limb_colors[i % limb_colors.size()]
		limb.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		get_parent().add_child(limb)
		var lvel = Vector2(randf_range(-200, 200), randf_range(-350, -50))
		var avel = randf_range(-8.0, 8.0)
		var prev_t = [0.0]
		var duration = 1.2
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
