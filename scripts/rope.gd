class_name Rope
extends Node2D

const SEGMENT_COUNT = 8
const SEGMENT_LENGTH = 22.0
const GRAVITY = 600.0
const STIFFNESS = 0.4

var anchor: Vector2 = Vector2.ZERO
var points: Array = []
var prev_points: Array = []
var player_ref: Node2D = null
var active: bool = false

func _ready() -> void:
	for i in SEGMENT_COUNT:
		points.append(Vector2.ZERO)
		prev_points.append(Vector2.ZERO)

func attach(world_anchor: Vector2, player: Node2D) -> void:
	anchor = world_anchor
	player_ref = player
	active = true
	for i in SEGMENT_COUNT:
		var t = float(i) / float(SEGMENT_COUNT - 1)
		var p = anchor.lerp(player.global_position, t)
		points[i] = p
		prev_points[i] = p
	queue_redraw()

func detach() -> void:
	active = false
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active or player_ref == null:
		return

	for i in SEGMENT_COUNT:
		var vel = points[i] - prev_points[i]
		prev_points[i] = points[i]
		points[i] += vel
		points[i].y += GRAVITY * delta * delta

	points[0] = anchor
	prev_points[0] = anchor

	if player_ref != null:
		var target = player_ref.global_position
		var diff = target - points[SEGMENT_COUNT - 1]
		points[SEGMENT_COUNT - 1] += diff * STIFFNESS

	for _iter in 3:
		points[0] = anchor
		for i in range(1, SEGMENT_COUNT):
			var seg_dir = (points[i] - points[i - 1])
			var seg_len = seg_dir.length()
			if seg_len > 0.0001:
				var correction = seg_dir.normalized() * (seg_len - SEGMENT_LENGTH) * 0.5
				points[i] -= correction
				if i > 1:
					points[i - 1] += correction
		points[0] = anchor

	if player_ref != null:
		var rope_end = points[SEGMENT_COUNT - 1]
		var to_player = player_ref.global_position - rope_end
		var rope_dir = (rope_end - points[SEGMENT_COUNT - 2]).normalized()
		var tangent = Vector2(-rope_dir.y, rope_dir.x)
		var tension = to_player.dot(rope_dir)
		if tension > 0:
			var swing_impulse = tangent * tension * 0.08
			player_ref.velocity += swing_impulse

	queue_redraw()

func _draw() -> void:
	if not active or points.size() < 2:
		return
	for i in range(1, SEGMENT_COUNT):
		draw_line(points[i - 1] - global_position, points[i] - global_position, Color(0.8, 0.7, 0.3), 2.0)
