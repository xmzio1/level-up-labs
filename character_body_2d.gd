extends CharacterBody2D

const SPEED = 250
const JUMP_VELOCITY = -500
const GRAVITY = 1200
const FALL_LIMIT = 1000
const MAX_JUMPS = 3

const SLIDE_SPEED = 700
const SLIDE_DURATION = 0.4

@onready var anim = $AnimatedSprite2D
@export var respawn_position = Vector2(100, 200)

var tilemap : TileMap

var is_falling = false
var jump_count = 0
var run_first_time = true

# slide
var is_sliding = false
var slide_timer = 0.0
var slide_direction = 1

func _ready():
	respawn_position = global_position

func _physics_process(delta):

	if is_falling:
		return

	# =========================
	# الاتجاه
	# =========================
	var direction = Input.get_axis("ui_left", "ui_right")

	if direction > 0:
		anim.flip_h = false

	elif direction < 0:
		anim.flip_h = true

	# =========================
	# بدء السلايد
	# =========================
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding:

		print("SLIDE START")

		is_sliding = true
		slide_timer = SLIDE_DURATION

		if anim.flip_h:
			slide_direction = -1
		else:
			slide_direction = 1

		anim.play("slide")

	# =========================
	# حركة السلايد
	# =========================
	if is_sliding:

		velocity.x = slide_direction * SLIDE_SPEED

		slide_timer -= delta

		if slide_timer <= 0:
			is_sliding = false

	else:

		velocity.x = direction * SPEED

	# =========================
	# الجاذبية
	# =========================
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jump_count = 0

	# =========================
	# القفز
	# =========================
	if Input.is_action_just_pressed("ui_accept"):

		if is_on_floor():

			velocity.y = JUMP_VELOCITY
			jump_count += 1

		elif jump_count < MAX_JUMPS:

			velocity.y = JUMP_VELOCITY
			jump_count += 1

	# =========================
	# الحركة
	# =========================
	move_and_slide()

	# =========================
	# الأنيميشن
	# =========================
	if is_sliding:

		anim.play("slide")

	elif is_on_floor():

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

		if velocity.y < 0:
			anim.play("jump")
		else:
			anim.play("fall")

	# =========================
	# السقوط
	# =========================
	if global_position.y > FALL_LIMIT:
		start_fall_sequence()

	# =========================
	# الموت من البلاطات
	# =========================
	if is_on_danger_tile():
		die()

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
