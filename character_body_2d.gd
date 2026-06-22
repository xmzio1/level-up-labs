extends CharacterBody2D

const SPEED = 250
const JUMP_VELOCITY = -500

# جاذبية أكثر سلاسة
const GRAVITY = 900
const FALL_GRAVITY = 1800

const FALL_LIMIT = 1000
const MAX_JUMPS = 1

# القفزة القصيرة
const JUMP_CUT = 0.5
const SHORT_PRESS_TIME = 0.15

# تحسين الإحساس
const COYOTE_TIME = 0.12
const JUMP_BUFFER = 0.12

const SLIDE_SPEED = 700
const SLIDE_DURATION = 0.4
const SLIDE_COOLDOWN = 0.25

# ==========================================
# متغيرات المغناطيس المطور (التوجيه بالماوس)
# ==========================================
@export var magnet_speed: float = 350.0  # سرعة السحب الثابتة نحو اللاعب
@onready var magnet_pivot: Node2D = get_node_or_null("MagnetPivot")
@onready var magnet_area: Area2D = get_node_or_null("MagnetPivot/MagnetArea")
var is_magnet_on: bool = false
# ==========================================

@onready var anim = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

@export var respawn_position = Vector2(100,200)

var tilemap : TileMap

var is_falling = false
var jump_count = 0
var run_first_time = true

# slide
var is_sliding = false
var slide_timer = 0.0
var slide_direction = 1
var slide_cooldown_timer = 0.0

# jump
var jump_hold_time = 0.0
var jumping = false
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# حفظ مكان الكولجن
var original_position


func _ready():
	respawn_position = global_position
	original_position = collision.position
	is_magnet_on = false


func _physics_process(delta):

	if is_falling:
		return

	# ==========================================
	# تدوير المغناطيس باتجاه الماوس والتحقق من زر E
	# ==========================================
	if magnet_pivot != null:
		magnet_pivot.look_at(get_global_mouse_position())
	
	if Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E):
		is_magnet_on = true
		var bodies_count = magnet_area.get_overlapping_bodies().size() if magnet_area else 0
		print("زر E يعمل بنجاح! المغناطيس مشتعل الآن. عدد الأجسام في النطاق: ", bodies_count)
	else:
		# عند ترك الزر، نعيد الجاذبية فوراً لأي صندوق كان يسحب
		if is_magnet_on == true and magnet_area != null:
			for body in magnet_area.get_overlapping_bodies():
				if body is RigidBody2D and body.is_in_group("pullable"):
					body.gravity_scale = 1.0
		is_magnet_on = false

	if is_magnet_on:
		pull_objects(delta)
	# ==========================================

	# =========================
	# تحريك الكولجن أثناء السلايد
	# =========================
	if is_sliding:
		collision.position.y = original_position.y - 8
	else:
		collision.position = original_position

	# =========================
	# عداد ضغط القفز
	# =========================
	if jumping:
		jump_hold_time += delta

	# =========================
	# تقليل كولداون السلايد
	# =========================
	if slide_cooldown_timer > 0:
		slide_cooldown_timer -= delta

	# =========================
	# الاتجاه
	# =========================
	var direction = Input.get_axis("ui_left","ui_right")

	if direction > 0:
		anim.flip_h = false
	elif direction < 0:
		anim.flip_h = true

	# =========================
	# بدء السلايد
	# =========================
	if Input.is_action_just_pressed("ui_page_down") \
	and is_on_floor() \
	and slide_cooldown_timer <= 0 \
	and not is_sliding:

		is_sliding = true
		slide_timer = SLIDE_DURATION
		slide_cooldown_timer = SLIDE_COOLDOWN

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
	if is_on_floor():

		coyote_timer = COYOTE_TIME
		jump_count = 0

	else:

		coyote_timer -= delta

		if velocity.y < 0:
			velocity.y += GRAVITY * delta
		else:
			velocity.y += FALL_GRAVITY * delta

	# =========================
	# تخزين ضغط القفز
	# =========================
	if Input.is_action_just_pressed("ui_accept"):

		jump_buffer_timer = JUMP_BUFFER
		jumping = true
		jump_hold_time = 0

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# =========================
	# تنفيذ القفز
	# =========================
	if jump_buffer_timer > 0:

		if coyote_timer > 0 or jump_count < MAX_JUMPS:

			velocity.y = JUMP_VELOCITY
			jump_count += 1

			jump_buffer_timer = 0
			coyote_timer = 0

	# =========================
	# قفزة قصيرة فقط إذا كانت ضغطة قصيرة
	# =========================
	if Input.is_action_just_released("ui_accept"):

		jumping = false

		if jump_hold_time < SHORT_PRESS_TIME and velocity.y < 0:
			velocity.y *= JUMP_CUT

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


# ==========================================
# دالة السحب الصارم نحو مركز دائرة اللاعب (الـ Pivot) مباشرة
# ==========================================
func pull_objects(_delta: float) -> void:
	if magnet_area == null:
		return
		
	var overlapping_bodies = magnet_area.get_overlapping_bodies()
	
	# تحديد نقطة الهدف المركزية (موقع اللاعب العالمي الثابت)
	var target_center = global_position
	if magnet_pivot != null:
		target_center = magnet_pivot.global_position # مركز الدوران للاعب بالظبط
	
	for body in overlapping_bodies:
		# حماية الكود من بلاطات الأرضية واللاعب نفسه
		if body == self or body is TileMap or (Engine.get_version_info().major >= 4 and body.is_class("TileMapLayer")) or body.has_method("get_tileset"):
			continue
			
		if body.is_in_group("pullable"):
			# حساب المسافة الصافية من الجسم إلى مركز اللاعب
			var distance = target_center.distance_to(body.global_position)
			
			# التوقف الصارم والكامل عند الوصول لمركز دائرة اللاعب (45 بكسل كمحيط آمن)
			if distance < 45.0:
				if body is RigidBody2D:
					body.linear_velocity = Vector2.ZERO
					body.angular_velocity = 0.0
					body.gravity_scale = 1.0 
				continue
				
			# حساب الاتجاه الصافي مباشرة من الجسم إلى مركز هدف اللاعب 
			var direction = body.global_position.direction_to(target_center)
			
			if body is RigidBody2D:
				body.gravity_scale = 0.0      # إلغاء الجاذبية تماماً أثناء التمغنط لمنع أي هبوط أو ارتطام عكسي
				body.angular_velocity = 0.0    # إلغاء عزم الدوران لضمان سحب مستقيم
				body.linear_velocity = direction * magnet_speed  # تطبيق السرعة الصارمة نحو مركز اللاعب مباشرة
				
			elif body is CharacterBody2D:
				body.velocity = direction * magnet_speed
				body.move_and_slide()
# ==========================================


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
