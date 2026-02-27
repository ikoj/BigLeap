extends Control

# Touch finger tracking
var joy_idx: int = -1
var joy_origin: Vector2 = Vector2.ZERO
var aim_idx: int = -1
var jump_idx: int = -1
var wprev_idx: int = -1
var wnext_idx: int = -1

const JOY_CENTER := Vector2(110.0, 600.0)
const JOY_RADIUS := 70.0
const JOY_DEAD := 10.0

const JUMP_RECT  := Rect2(10,  490, 90, 90)
const WPREV_RECT := Rect2(660, 620, 70, 70)
const WNEXT_RECT := Rect2(740, 620, 70, 70)
const AIM_MIN_X  := 700.0

@onready var joy_knob: Control = $LeftJoystick/Knob
@onready var jump_btn: Control = $JumpButton
@onready var wprev_btn: Control = $WeaponPrev
@onready var wnext_btn: Control = $WeaponNext
@onready var joy_base: Control = $LeftJoystick

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(event: InputEventScreenTouch) -> void:
	var pos: Vector2 = event.position
	if event.pressed:
		_assign_touch(event.index, pos)
	else:
		_release_touch(event.index)

func _assign_touch(idx: int, pos: Vector2) -> void:
	# Joystick area: circle around JOY_CENTER
	if joy_idx == -1 and pos.distance_to(JOY_CENTER) <= JOY_RADIUS + 30.0:
		joy_idx = idx
		joy_origin = pos
		return
	if jump_idx == -1 and JUMP_RECT.has_point(pos):
		jump_idx = idx
		MobileInput.jump_held = true
		MobileInput.set_jump_just()
		_highlight(jump_btn, true)
		return
	if wprev_idx == -1 and WPREV_RECT.has_point(pos):
		wprev_idx = idx
		MobileInput.set_weapon_prev()
		_highlight(wprev_btn, true)
		return
	if wnext_idx == -1 and WNEXT_RECT.has_point(pos):
		wnext_idx = idx
		MobileInput.set_weapon_next()
		_highlight(wnext_btn, true)
		return
	# Aim/fire zone — right side of screen
	if aim_idx == -1 and pos.x >= AIM_MIN_X:
		aim_idx = idx
		MobileInput.shooting = true
		MobileInput.aim_active = true
		MobileInput.aim_screen_pos = pos

func _release_touch(idx: int) -> void:
	if idx == joy_idx:
		joy_idx = -1
		MobileInput.move_x = 0.0
		MobileInput.crawling = false
		_update_knob(Vector2.ZERO)
	elif idx == jump_idx:
		jump_idx = -1
		MobileInput.jump_held = false
		_highlight(jump_btn, false)
	elif idx == aim_idx:
		aim_idx = -1
		MobileInput.shooting = false
		MobileInput.aim_active = false
	elif idx == wprev_idx:
		wprev_idx = -1
		_highlight(wprev_btn, false)
	elif idx == wnext_idx:
		wnext_idx = -1
		_highlight(wnext_btn, false)

func _on_drag(event: InputEventScreenDrag) -> void:
	var pos: Vector2 = event.position
	if event.index == joy_idx:
		_update_joystick(pos)
	elif event.index == aim_idx:
		MobileInput.aim_screen_pos = pos

func _update_joystick(pos: Vector2) -> void:
	var offset = pos - joy_origin
	var clamped = offset.limit_length(JOY_RADIUS)
	_update_knob(clamped)

	var norm = offset.length()
	if norm < JOY_DEAD:
		MobileInput.move_x = 0.0
		MobileInput.crawling = false
		return

	var dir = offset / norm
	MobileInput.move_x = clamp(dir.x, -1.0, 1.0)
	# Crawl when dragging down at >45 degrees
	MobileInput.crawling = dir.y > 0.6 and abs(dir.x) > 0.2

func _update_knob(offset: Vector2) -> void:
	if joy_knob:
		joy_knob.position = offset

func _highlight(btn: Control, on: bool) -> void:
	if btn:
		btn.modulate.a = 0.9 if on else 0.55

func _draw() -> void:
	# Joystick base
	draw_circle(JOY_CENTER, JOY_RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(JOY_CENTER, JOY_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.3), 2.0)
