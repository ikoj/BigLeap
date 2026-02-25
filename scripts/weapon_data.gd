class_name WeaponData
extends Resource

var name: String = ""
var damage: float = 10.0
var projectile_speed: float = 300.0
var spread_deg: float = 0.0
var pellet_count: int = 1
var bounce_count: int = 0
var explode_radius: float = 0.0
var cooldown: float = 0.5
var is_grenade: bool = false
var color: Color = Color.WHITE
var max_range: float = 0.0
var is_flamethrower: bool = false

static func make_plasma() -> WeaponData:
	var w = WeaponData.new()
	w.name = "Plasma Wand"
	w.damage = 25.0
	w.projectile_speed = 480.0
	w.spread_deg = 2.0
	w.pellet_count = 1
	w.bounce_count = 0
	w.explode_radius = 18.0
	w.cooldown = 0.22
	w.color = Color(0.0, 0.93, 1.0)
	return w

static func make_bouncer() -> WeaponData:
	var w = WeaponData.new()
	w.name = "Bouncer"
	w.damage = 35.0
	w.projectile_speed = 300.0
	w.spread_deg = 0.0
	w.pellet_count = 1
	w.bounce_count = 5
	w.explode_radius = 8.0
	w.cooldown = 0.55
	w.color = Color(1.0, 0.267, 0.667)
	return w

static func make_shotgun() -> WeaponData:
	var w = WeaponData.new()
	w.name = "Shotgun"
	w.damage = 12.0
	w.projectile_speed = 420.0
	w.spread_deg = 14.0
	w.pellet_count = 7
	w.bounce_count = 0
	w.explode_radius = 0.0
	w.cooldown = 0.85
	w.color = Color(1.0, 0.8, 0.0)
	return w

static func make_flamethrower() -> WeaponData:
	var w = WeaponData.new()
	w.name = "Flamethrower"
	w.damage = 8.0
	w.projectile_speed = 200.0
	w.spread_deg = 18.0
	w.pellet_count = 3
	w.bounce_count = 0
	w.explode_radius = 0.0
	w.cooldown = 0.05
	w.is_flamethrower = true
	w.max_range = 80.0
	w.color = Color(1.0, 0.4, 0.0)
	return w

static func make_grenade() -> WeaponData:
	var w = WeaponData.new()
	w.name = "Grenade"
	w.damage = 60.0
	w.projectile_speed = 320.0
	w.spread_deg = 0.0
	w.pellet_count = 1
	w.bounce_count = 0
	w.explode_radius = 38.0
	w.cooldown = 1.2
	w.is_grenade = true
	w.color = Color(0.533, 1.0, 0.267)
	return w

static func all_weapons() -> Array:
	return [make_plasma(), make_bouncer(), make_shotgun(), make_flamethrower(), make_grenade()]
