extends CharacterBody2D

const SPEED = 250
const JUMP_VELOCITY = -500
const WALL_JUMP_FORCE = 350
const GRAVITY = 1200
const WALL_SLIDE_GRAVITY = 300
const FALL_LIMIT = 1000
const MAX_JUMPS = 2

@onready var anim = $AnimatedSprite2D
@export var respawn_position = Vector2(100, 200)

var tilemap : TileMap
var is_falling = false
var jump_count = 0
var wall_jump_timer = 0.0
var wall_dir = 0
var wall_stick_time = 0.2
var wall_stick_counter = 0.0
var run_first_time = true

func _ready():
	respawn_position = global_position
	tilemap = get_parent().get_node("! LEVEL")  # ربط التايل ماب بعد تحميل المشهد

func _physics_process(delta):
	if is_falling:
		return

	var direction = 0
	if Input.is_action_pressed("ui_right"):
		direction += 1
		anim.flip_h = false
	elif Input.is_action_pressed("ui_left"):
		direction -= 1
		anim.flip_h = true

	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	else:
		velocity.x = direction * SPEED

	var on_wall_left = false
	var on_wall_right = false

	if is_on_wall() and get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		if collision:
			on_wall_left = collision.get_normal().x > 0.9
			on_wall_right = collision.get_normal().x < -0.9

	var on_wall = on_wall_left or on_wall_right

	if on_wall:
		wall_dir = 1 if on_wall_left else -1

	if not is_on_floor():
		if on_wall and velocity.y > 0 and wall_jump_timer <= 0:
			velocity.y += WALL_SLIDE_GRAVITY * delta
			if wall_stick_counter < wall_stick_time:
				wall_stick_counter += delta
				velocity.y = 0
		else:
			velocity.y += GRAVITY * delta
			wall_stick_counter = 0.0
	else:
		jump_count = 0
		wall_stick_counter = 0.0

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jump_count += 1
		elif on_wall and wall_jump_timer <= 0:
			velocity.y = JUMP_VELOCITY
			velocity.x = WALL_JUMP_FORCE * wall_dir
			wall_jump_timer = 0.2
			wall_stick_counter = 0.0
		elif jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1

	if is_on_danger_tile():
		die()

	move_and_slide()

	if is_on_floor():
		if direction != 0:
			if anim.animation != "run":
				run_first_time = true
				anim.play("run")
				anim.frame = 0
			elif run_first_time:
				if anim.frame > 3:
					anim.frame = 0
				if anim.frame == 3:
					run_first_time = false
			else:
				if anim.frame <= 1:
					anim.frame = 5
		else:
			anim.play("idle")
			run_first_time = true
	else:
		run_first_time = true
		if on_wall and velocity.y > 0 and wall_jump_timer <= 0:
			anim.play("wall_jump")
		elif velocity.y < 0:
			anim.play("jump")
		else:
			anim.play("fall")

	if global_position.y > FALL_LIMIT:
		start_fall_sequence()

func start_fall_sequence():
	is_falling = true
	anim.play("fall")
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.7).timeout
	global_position = respawn_position
	is_falling = false

func die():
	if is_falling:
		return
	is_falling = true
	anim.play("fall")
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.7).timeout
	global_position = respawn_position
	is_falling = false

func is_on_danger_tile() -> bool:
	if tilemap == null:
		return false
	var local_position = tilemap.to_local(global_position)
	var map_coords = tilemap.local_to_map(local_position)
	var tile_data = tilemap.get_cell_tile_data(1, map_coords)
	if tile_data != null:
		return tile_data.get_custom_data("danger") == true
	return false
