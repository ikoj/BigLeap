extends Node

var is_mobile: bool = false

# Written by MobileControls, read + consumed by Player
var move_x: float = 0.0
var crawling: bool = false
var jump_held: bool = false
var shooting: bool = false
var aim_screen_pos: Vector2 = Vector2(960.0, 360.0)
var aim_active: bool = false
var _last_aim_screen_pos: Vector2 = Vector2(960.0, 360.0)

var _jump_just: bool = false
var _rope_just: bool = false
var _weapon_prev: bool = false
var _weapon_next: bool = false

func _ready() -> void:
	is_mobile = (OS.has_feature("mobile") or
		OS.has_feature("web_android") or
		OS.has_feature("web_ios"))

# --- Unified API for player.gd ---

func get_move_x() -> float:
	if is_mobile:
		return move_x
	return Input.get_axis("ui_left", "ui_right")

func is_crawling() -> bool:
	if is_mobile:
		return crawling
	return Input.is_action_pressed("ui_down") and Input.get_axis("ui_left", "ui_right") != 0.0

func is_jump_held() -> bool:
	if is_mobile:
		return jump_held
	return Input.is_action_pressed("ui_accept")

func consume_jump_just() -> bool:
	if is_mobile:
		var v = _jump_just
		_jump_just = false
		return v
	return Input.is_action_just_pressed("ui_accept")

func consume_rope_just() -> bool:
	if is_mobile:
		var v = _rope_just
		_rope_just = false
		return v
	return Input.is_action_just_pressed("rope")

func is_shooting() -> bool:
	if is_mobile:
		return shooting
	return Input.is_action_pressed("shoot")

func consume_weapon_prev() -> bool:
	if is_mobile:
		var v = _weapon_prev
		_weapon_prev = false
		return v
	return Input.is_action_just_pressed("ui_page_up")

func consume_weapon_next() -> bool:
	if is_mobile:
		var v = _weapon_next
		_weapon_next = false
		return v
	return Input.is_action_just_pressed("ui_page_down")

func get_aim_world_pos(viewport: Viewport) -> Vector2:
	if is_mobile:
		if aim_active:
			_last_aim_screen_pos = aim_screen_pos
		return viewport.get_canvas_transform().affine_inverse() * _last_aim_screen_pos
	# Desktop: convert mouse screen pos to world coords
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()

# --- Called by MobileControls ---

func set_jump_just() -> void:
	_jump_just = true

func set_rope_just() -> void:
	_rope_just = true

func set_weapon_prev() -> void:
	_weapon_prev = true

func set_weapon_next() -> void:
	_weapon_next = true
