class_name Terrain
extends Node2D

const WIDTH = 160
const HEIGHT = 120
const TILE_PX = 8

const EMPTY = 0
const STONE = 1
const DIRT = 2
const SAND = 3
const WATER = 4
const LAVA = 5
const FIRE = 6

var cells: PackedByteArray
var fire_life: PackedByteArray
var sim_left_to_right := true

var dirty := false
var dirty_min_x := 0
var dirty_min_y := 0
var dirty_max_x := WIDTH
var dirty_max_y := HEIGHT

var terrain_image: Image
var terrain_texture: ImageTexture
var display_sprite: Sprite2D

static var TILE_COLORS: Array[Color] = []
const BG_COLOR = Color(0.024, 0.024, 0.063)

func _ready() -> void:
	TILE_COLORS = [
		BG_COLOR,
		Color(0.353, 0.353, 0.353),
		Color(0.478, 0.31, 0.18),
		Color(0.784, 0.643, 0.29),
		Color(0.165, 0.373, 0.812, 0.85),
		Color(0.878, 0.227, 0.0),
		Color(1.0, 0.467, 0.0),
	]
	cells = PackedByteArray()
	cells.resize(WIDTH * HEIGHT)
	fire_life = PackedByteArray()
	fire_life.resize(WIDTH * HEIGHT)

	terrain_image = Image.create(WIDTH * TILE_PX, HEIGHT * TILE_PX, false, Image.FORMAT_RGBA8)
	terrain_texture = ImageTexture.create_from_image(terrain_image)
	display_sprite = Sprite2D.new()
	display_sprite.texture = terrain_texture
	display_sprite.centered = false
	add_child(display_sprite)

	generate()
	_full_redraw()

	var timer := Timer.new(); add_child(timer)
	timer.wait_time = 0.1; timer.timeout.connect(_simulate); timer.start()

func idx(x: int, y: int) -> int: return y * WIDTH + x
func in_bounds(x: int, y: int) -> bool: return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT

func cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return STONE
	return cells[idx(x, y)]

func set_cell(x: int, y: int, v: int) -> void:
	if not in_bounds(x, y):
		return
	cells[idx(x, y)] = v
	if v == FIRE:
		fire_life[idx(x, y)] = randi_range(20, 40)
	_mark_dirty(x, y)

func _mark_dirty(x: int, y: int) -> void:
	if not dirty:
		dirty = true
		dirty_min_x = x
		dirty_min_y = y
		dirty_max_x = x + 1
		dirty_max_y = y + 1
	else:
		dirty_min_x = min(dirty_min_x, x)
		dirty_min_y = min(dirty_min_y, y)
		dirty_max_x = max(dirty_max_x, x + 1)
		dirty_max_y = max(dirty_max_y, y + 1)

func tile_at(world_pos: Vector2) -> int:
	return cell(int(world_pos.x / TILE_PX), int(world_pos.y / TILE_PX))

func set_tile(world_pos: Vector2, type: int) -> void:
	set_cell(int(world_pos.x / TILE_PX), int(world_pos.y / TILE_PX), type)

func explode(world_pos: Vector2, radius: float, _damage_material: bool) -> void:
	var cx = int(world_pos.x / TILE_PX)
	var cy = int(world_pos.y / TILE_PX)
	var r = int(radius / TILE_PX) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var tx = cx + dx
				var ty = cy + dy
				if in_bounds(tx, ty) and cells[idx(tx, ty)] != STONE:
					set_cell(tx, ty, EMPTY)
	_spawn_debris(world_pos, radius)

func _spawn_debris(pos: Vector2, _radius: float) -> void:
	for _i in randi_range(6, 12):
		var v = Vector2.from_angle(randf() * TAU) * randf_range(50.0, 160.0)
		var d = ColorRect.new()
		d.size = Vector2(3, 3); d.color = Color(0.55, 0.35, 0.15)
		d.position = pos - Vector2(1.5, 1.5)
		get_parent().add_child(d)
		var p = [0.0]
		var tw = create_tween()
		tw.tween_method(func(t: float):
			var dt = t - p[0]; p[0] = t
			v.y += 400.0 * dt; d.position += v * dt; d.modulate.a = 1.0 - t * 2.0
		, 0.0, 0.5, 0.5)
		tw.tween_callback(d.queue_free)

func force_refresh() -> void: _flush_dirty()

func _full_redraw() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			_write_tile_pixels(x, y)
	terrain_texture.update(terrain_image); dirty = false

func _flush_dirty() -> void:
	if not dirty: return
	for y in range(clamp(dirty_min_y,0,HEIGHT-1), clamp(dirty_max_y,0,HEIGHT)):
		for x in range(clamp(dirty_min_x,0,WIDTH-1), clamp(dirty_max_x,0,WIDTH)):
			_write_tile_pixels(x, y)
	terrain_texture.update(terrain_image); dirty = false

func _write_tile_pixels(x: int, y: int) -> void:
	terrain_image.fill_rect(Rect2i(x * TILE_PX, y * TILE_PX, TILE_PX, TILE_PX), TILE_COLORS[cells[idx(x, y)]])

func generate() -> void:
	for i in WIDTH * HEIGHT:
		cells[i] = DIRT

	for _w in 8:
		var wx = WIDTH / 2 + randi_range(-30, 30)
		var wy = HEIGHT / 2 + randi_range(-20, 20)
		for _step in 400:
			match randi() % 4:
				0: wx = min(wx + 1, WIDTH - 1)
				1: wx = max(wx - 1, 0)
				2: wy = min(wy + 1, HEIGHT - 1)
				3: wy = max(wy - 1, 0)
			var r = randi_range(3, 5)
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy <= r * r and in_bounds(wx + dx, wy + dy):
						cells[idx(wx + dx, wy + dy)] = EMPTY

	for _pass in 4:
		var new_cells = cells.duplicate()
		for y in range(1, HEIGHT - 1):
			for x in range(1, WIDTH - 1):
				var ec = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and cells[idx(x + dx, y + dy)] == EMPTY:
							ec += 1
				if ec >= 5:
					new_cells[idx(x, y)] = EMPTY
				elif ec <= 3:
					new_cells[idx(x, y)] = DIRT
		cells = new_cells

	for _s in 80:
		var sx = randi_range(5, WIDTH - 8)
		var sy = randi_range(5, HEIGHT - 8)
		for dy in 3:
			for dx in 3:
				if in_bounds(sx+dx, sy+dy) and cells[idx(sx+dx, sy+dy)] == EMPTY:
					cells[idx(sx+dx, sy+dy)] = SAND

	for _pool in 40:
		var px = randi_range(5, WIDTH - 5)
		var py = randi_range(5, HEIGHT - 5)
		if cells[idx(px, py)] != EMPTY:
			continue
		var filled = 0
		var frontier = [[px, py]]
		while frontier.size() > 0 and filled < 30:
			var pos = frontier.pop_back()
			var fx = pos[0]; var fy = pos[1]
			if not in_bounds(fx, fy) or cells[idx(fx, fy)] != EMPTY:
				continue
			cells[idx(fx, fy)] = WATER
			filled += 1
			frontier.append([fx+1, fy]); frontier.append([fx-1, fy])
			frontier.append([fx, fy+1])

	var lava_min_y = int(HEIGHT * 0.6)
	for _lv in 15:
		var lx = randi_range(5, WIDTH - 8)
		var ly = randi_range(lava_min_y, HEIGHT - 8)
		for dy in 3:
			for dx in 3:
				if in_bounds(lx+dx, ly+dy) and cells[idx(lx+dx, ly+dy)] == EMPTY:
					cells[idx(lx+dx, ly+dy)] = LAVA

	_fill_border()

	for _p in 10:
		var px = randi_range(10, WIDTH - 15)
		var py = randi_range(10, HEIGHT - 15)
		for dy in 5:
			for dx in 5:
				if in_bounds(px+dx, py+dy):
					cells[idx(px+dx, py+dy)] = STONE

	_carve_circle(12, 12, 8)
	_carve_circle(WIDTH - 12, 12, 8)

func _fill_border() -> void:
	for x in WIDTH:
		for y in range(0, 2): cells[idx(x, y)] = STONE
		for y in range(HEIGHT-2, HEIGHT): cells[idx(x, y)] = STONE
	for y in HEIGHT:
		for x in range(0, 2): cells[idx(x, y)] = STONE
		for x in range(WIDTH-2, WIDTH): cells[idx(x, y)] = STONE

func _carve_circle(cx: int, cy: int, r: int) -> void:
	for dy in range(-r,r+1):
		for dx in range(-r,r+1):
			if dx*dx+dy*dy<=r*r and in_bounds(cx+dx,cy+dy): cells[idx(cx+dx,cy+dy)]=EMPTY

func _simulate() -> void:
	sim_left_to_right = not sim_left_to_right
	var x_range = range(1, WIDTH - 1) if sim_left_to_right else range(WIDTH - 2, 0, -1)
	for y in range(HEIGHT - 2, 0, -1):
		for x in x_range:
			match cells[idx(x, y)]:
				FIRE: _sim_fire(x, y)
				LAVA: _sim_lava(x, y)
				SAND: _sim_sand(x, y)
				WATER: _sim_water(x, y)
	_flush_dirty()

func _sim_fire(x: int, y: int) -> void:
	var fi = idx(x, y)
	if fire_life[fi] > 0: fire_life[fi] -= 1
	if fire_life[fi] == 0: cells[fi] = EMPTY; _mark_dirty(x, y); return
	if randf() < 0.15:
		for d in [[0,-1],[1,0],[-1,0],[0,1]]:
			var nx = x+d[0]; var ny = y+d[1]
			if in_bounds(nx,ny):
				var nc = cells[idx(nx,ny)]
				if nc == DIRT or nc == SAND: set_cell(nx, ny, FIRE)

func _sim_lava(x: int, y: int) -> void:
	if randf() < 0.05:
		var nx = x + randi_range(-1, 1)
		if in_bounds(nx, y-1) and cells[idx(nx, y-1)] == EMPTY: set_cell(nx, y-1, FIRE)

func _sim_sand(x: int, y: int) -> void:
	if cell(x, y+1) == EMPTY:
		_swap(x, y, x, y+1)
	elif cell(x, y+1) == WATER:
		_swap(x, y, x, y+1)
	elif cell(x-1, y+1) == EMPTY:
		_swap(x, y, x-1, y+1)
	elif cell(x+1, y+1) == EMPTY:
		_swap(x, y, x+1, y+1)

func _sim_water(x: int, y: int) -> void:
	if cell(x, y+1) == EMPTY:
		_swap(x, y, x, y+1)
		return
	var go_left = randf() < 0.5
	for i in 3:
		var nx = x + (-1 if go_left else 1) * (i + 1)
		if cell(nx, y) == EMPTY:
			_swap(x, y, nx, y)
			return
		go_left = not go_left

func _swap(x1: int, y1: int, x2: int, y2: int) -> void:
	var i1 = idx(x1,y1); var i2 = idx(x2,y2); var tmp = cells[i1]
	cells[i1] = cells[i2]; cells[i2] = tmp
	_mark_dirty(x1,y1); _mark_dirty(x2,y2)

func _process(_d: float) -> void:
	if dirty: _flush_dirty()
