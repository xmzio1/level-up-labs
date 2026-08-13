extends CharacterBody2D

const SPEED = 250
const JUMP_VELOCITY = -500

# جاذبية أكثر سلاسة
const GRAVITY = 950
const FALL_GRAVITY = 1900

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
# متغيرات ميكانيك الالتصاق بالجدار (Wall Stick) - معدلة
# ==========================================
@export var wall_slide_speed: float = 120.0     # أقصى سرعة للانزلاق لأسفل أثناء التعلق
var is_wall_sticking: bool = false               # هل اللاعب ملتصق بالجدار حالياً؟
var wall_normal: Vector2 = Vector2.ZERO          # اتجاه الجدار الملتصق به

# ==========================================
# متغيرات المغناطيس المطور والرمي
# ==========================================
@export var magnet_speed: float = 600.0        # سرعة سحب الجسم نحو الرأس
@export var throw_force_x: float = 700.0       # قوة الرمي الأفقي
@export var throw_force_y: float = -200.0      # قوة الرمي للأعلى قليلاً
@export var hold_throw_time: float = 0.25      # الوقت المطلوب بالثواني للضغط المطول للرمي
@export var hold_height_offset: float = 60.0   # المسافة/الارتفاع فوق رأس اللاعب
@export var drop_side_offset: float = 40.0     # المسافة الأفقية لإسقاط الجسم بجانب اللاعب

@onready var magnet_pivot: Node2D = get_node_or_null("MagnetPivot")
@onready var magnet_area: Area2D = get_node_or_null("MagnetPivot/MagnetArea")
@onready var magnet_sprite: Sprite2D = get_node_or_null("MagnetPivot/MagnetSprite")

# عقدة موضع التثبيت فوق الرأس
@onready var hold_position: Node2D = get_node_or_null("HoldPosition")

# عقد الأصوات
@onready var jump_sound: AudioStreamPlayer2D = get_node_or_null("JumpSound")
@onready var charge_sound: AudioStreamPlayer2D = get_node_or_null("ChargeSound")
@onready var magnet_stick_sound: AudioStreamPlayer2D = get_node_or_null("MagnetStickSound")

var is_magnet_on: bool = false
var held_object: Node2D = null         # الجسم الممسوك حالياً
var is_object_attached: bool = false    # هل وصل الجسم للرأس وتم تثبيته؟

# عداد وقت الضغط المطول للرمي
var e_press_timer: float = 0.0
var is_e_held: bool = false
# ==========================================

@onready var anim = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

@export var respawn_position = Vector2(100, 200)

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
	if magnet_sprite != null:
		magnet_sprite.visible = false


func _physics_process(delta):

	if is_falling:
		return

	# ==========================================
	# تدوير المغناطيس نحو أزرار الإدخال أو الماوس (or)
	# ==========================================
	if magnet_pivot != null:
		var aim_dir = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		
		if aim_dir.length_squared() > 0:
			magnet_pivot.rotation = aim_dir.angle()
		else:
			magnet_pivot.look_at(get_global_mouse_position())

	# ==========================================
	# معالجة الضغط المطول على E للرمي أو السحب
	# ==========================================
	handle_magnet_input(delta)

	# معالجة سحب وتثبيت الجسم
	if is_magnet_on:
		process_magnet_logic(delta)
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
	var direction = Input.get_axis("ui_left", "ui_right")

	if direction > 0 and not is_wall_sticking:
		anim.flip_h = false
	elif direction < 0 and not is_wall_sticking:
		anim.flip_h = true

	# =========================
	# معالجة الالتصاق بالجدار (Wall Stick Setup)
	# =========================
	handle_wall_stick()

	# =========================
	# بدء السلايد الأرضي
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
	# حركة السلايد والسرعة الأفقية
	# =========================
	if is_sliding:
		velocity.x = slide_direction * SLIDE_SPEED
		slide_timer -= delta
		if slide_timer <= 0:
			is_sliding = false
	elif not is_wall_sticking:
		velocity.x = direction * SPEED

	# =========================
	# الجاذبية وسلوك الجدار - معدل
	# =========================
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jump_count = 0
		is_wall_sticking = false
	elif is_wall_sticking:
		# إذا كان اللاعب يضغط O، فالجاذبية لا تؤثر إلا كقوة انزلاق بطيئة لأسفل
		# لتطبيق فكرة "لا يتحرك للأعلى" ولكن ينزلق لأسفل فقط
		# velocity.y = 0 # إذا أردت تثبيته تماماً حتى لو لم يضغط شيئاً (غير منطقي مع الجاذبية)
		#velocity.y = min(velocity.y + (GRAVITY * 0.2 * delta), wall_slide_speed)
		velocity.y = min(velocity.y + (GRAVITY * 0.3 * delta), wall_slide_speed)
		velocity.x = 0 # إلغاء الحركة الأفقية تماماً أثناء الالتصاق
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
	# تنفيذ القفز (مع دعم قفزة الجدار)
	# =========================
	if jump_buffer_timer > 0:

		if is_wall_sticking:
			# قفزة الجدار: دفعة للأعلى وللخارج بعيداً عن الجدار
			velocity.y = JUMP_VELOCITY
			velocity.x = wall_normal.x * SPEED * 1.2
			is_wall_sticking = false
			jump_count = 1

			if jump_sound != null:
				jump_sound.pitch_scale = randf_range(0.95, 1.05)
				jump_sound.play()

			jump_buffer_timer = 0

		elif coyote_timer > 0 or jump_count < MAX_JUMPS:

			velocity.y = JUMP_VELOCITY
			jump_count += 1

			if jump_sound != null:
				jump_sound.pitch_scale = randf_range(0.95, 1.05)
				jump_sound.play()

			jump_buffer_timer = 0
			coyote_timer = 0

	# =========================
	# قفزة قصيرة
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
	# الأنيميشن - معدل لإضافة التمييز على الجدار
	# =========================
	if is_sliding:
		anim.play("slide")
	elif is_wall_sticking:
		# التمييز بين حالتي الثبات والتحرك لأسفل
		# نستخدم velocity.y للتأكد من وجود حركة فعلية لأسفل
		# نستخدم عتبة صغيرة (مثلاً 5.0) لتجنب تشغيل أنميشن الحركة بسبب اهتزازات بسيطة في الفيزياء
		if abs(velocity.y) > 5.0:
			if anim.sprite_frames.has_animation("wall_slide"):
				anim.play("wall_slide")
			else:
				anim.play("fall") # Fallback
		else:
			if anim.sprite_frames.has_animation("wall_stick"):
				anim.play("wall_stick")
			else:
				# إذا لم يوجد أنميشن ثبات، جرب تجميد الإطار الأول لأنميشن الانزلاق
				if anim.sprite_frames.has_animation("wall_slide"):
					anim.play("wall_slide")
					anim.frame = 0 # تجميد على الإطار الأول
				else:
					anim.play("idle") # Fallback final
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
	# السقوط والموت
	# =========================
	if global_position.y > FALL_LIMIT:
		start_fall_sequence()

	if is_on_danger_tile():
		die()


# ==========================================
# دالة فحص وتفعيل الالتصاق بالجدران التي تحتوي على "wa"
# ==========================================
func handle_wall_stick() -> void:
	# يجب أن نكون ملامسين للجدار في الهواء ويتم الضغط على زر "wall_stick" (زر O)
	if is_on_wall() and not is_on_floor() and Input.is_action_pressed("wall_stick"):
		var wall_valid = false

		# الفحص عبر تصدعات واحتكاك التصادم مع الجدران
		for i in get_slide_collision_count():
			var collision_info = get_slide_collision(i)
			var collider = collision_info.get_collider()

			if collider != null:
				var collider_name = collider.name.to_lower()
				
				# 1. فحص إذا كان اسم العقدة يحتوي على "wa"
				if "wa" in collider_name:
					wall_valid = true
					wall_normal = collision_info.get_normal()
					break
				
				# 2. إذا كانت بلاطات TileMap أو TileMapLayer
				if collider is TileMap or collider.has_method("get_tileset") or (Engine.get_version_info().major >= 4 and collider.is_class("TileMapLayer")):
					# إذا كان اسم طبقة البلاطات يحوي wa
					if "wa" in collider_name:
						wall_valid = true
						wall_normal = collision_info.get_normal()
						break

		if wall_valid:
			is_wall_sticking = true
			# توجيه وجه الشخصية بالاتجاه المعاكس للجدار
			# ملاحظة: تم نقل هذا الجزء هنا ليعمل مرة واحدة عند الالتصاق، وليس في كل إطار
			if wall_normal.x > 0:
				anim.flip_h = true
			elif wall_normal.x < 0:
				anim.flip_h = false
		else:
			is_wall_sticking = false
	else:
		is_wall_sticking = false


# ==========================================
# معالجة إدخال زر المغناطيس وصوت الشحن (E)
# ==========================================
func handle_magnet_input(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_magnet"):
		e_press_timer = 0.0
		is_e_held = false

	if Input.is_action_pressed("toggle_magnet"):
		e_press_timer += delta
		if e_press_timer >= hold_throw_time:
			if not is_e_held:
				is_e_held = true
				if charge_sound != null and not charge_sound.playing:
					charge_sound.play()

	if Input.is_action_just_released("toggle_magnet"):
		if charge_sound != null and charge_sound.playing:
			charge_sound.stop()

		if is_e_held and held_object != null:
			throw_held_object()
		else:
			toggle_magnet()
		
		e_press_timer = 0.0
		is_e_held = false


# ==========================================
# دالة إيقاف/تفعيل المغناطيس وتشغيل الصوت
# ==========================================
func toggle_magnet() -> void:
	is_magnet_on = !is_magnet_on
	
	if magnet_stick_sound != null:
		magnet_stick_sound.pitch_scale = randf_range(0.95, 1.05)
		magnet_stick_sound.play()

	if magnet_sprite != null:
		magnet_sprite.visible = is_magnet_on

	if not is_magnet_on:
		release_held_object()


# ==========================================
# دالة رمي الجسم في اتجاه نظر اللاعب
# ==========================================
func throw_held_object() -> void:
	if held_object != null and is_instance_valid(held_object):
		remove_collision_exception_with(held_object)
		
		var throw_dir = -1.0 if anim.flip_h else 1.0
		
		if held_object is RigidBody2D:
			held_object.gravity_scale = 1.0
			held_object.sleeping = false
			held_object.linear_velocity = Vector2(throw_dir * throw_force_x, throw_force_y) + (velocity * 0.3)
			
		elif held_object is CharacterBody2D:
			held_object.velocity = Vector2(throw_dir * throw_force_x, throw_force_y)
			
		held_object = null
		is_object_attached = false
		is_magnet_on = false
		
		if magnet_sprite != null:
			magnet_sprite.visible = false


# ==========================================
# دالة معالجة سحب وتثبيت الجسم فوق الرأس
# ==========================================
func process_magnet_logic(delta: float) -> void:
	if magnet_area == null:
		return

	var target_pos = global_position + Vector2(0, -hold_height_offset)
	if hold_position != null:
		target_pos = hold_position.global_position

	# 1. البحث عن جسم قابل للسحب
	if held_object == null or not is_instance_valid(held_object):
		var bodies = magnet_area.get_overlapping_bodies()
		for body in bodies:
			if body == self or body is TileMap or (Engine.get_version_info().major >= 4 and body.is_class("TileMapLayer")) or body.has_method("get_tileset"):
				continue
			if body.is_in_group("pullable"):
				held_object = body
				is_object_attached = false
				
				if held_object is RigidBody2D or held_object is CharacterBody2D:
					add_collision_exception_with(held_object)
				break

	# 2. متابعة حركة الجسم والسحب
	if held_object != null and is_instance_valid(held_object):
		
		if check_for_obstacle(target_pos):
			release_held_object()
			is_magnet_on = false
			if magnet_sprite != null:
				magnet_sprite.visible = false
			return

		var distance = held_object.global_position.distance_to(target_pos)

		if distance <= 25.0:
			is_object_attached = true

		if is_object_attached:
			held_object.global_position = target_pos
			
			if held_object is RigidBody2D:
				held_object.linear_velocity = Vector2.ZERO
				held_object.angular_velocity = 0.0
				held_object.gravity_scale = 0.0
				held_object.sleeping = true
			elif held_object is CharacterBody2D:
				held_object.velocity = Vector2.ZERO
		else:
			var dir = held_object.global_position.direction_to(target_pos)
			if held_object is RigidBody2D:
				if held_object.sleeping:
					held_object.sleeping = false
				held_object.gravity_scale = 0.0
				held_object.linear_velocity = dir * magnet_speed
			elif held_object is CharacterBody2D:
				held_object.velocity = dir * magnet_speed
				held_object.move_and_slide()


# ==========================================
# دالة الكشف عن العوائق بين اللاعب والجسم
# ==========================================
func check_for_obstacle(target_pos: Vector2) -> bool:
	if held_object == null or not is_instance_valid(held_object):
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, held_object.global_position)
	
	query.exclude = [get_rid(), held_object.get_rid()]
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0


# ==========================================
# دالة تحرير وإسقاط الجسم المسحوب بجانب اللاعب
# ==========================================
func release_held_object() -> void:
	if held_object != null and is_instance_valid(held_object):
		remove_collision_exception_with(held_object)
		
		var side_dir = -1.0 if anim.flip_h else 1.0
		var drop_pos = global_position + Vector2(side_dir * drop_side_offset, 0)
		
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, drop_pos)
		query.exclude = [get_rid(), held_object.get_rid()]
		var result = space_state.intersect_ray(query)
		
		if result.size() > 0:
			drop_pos = held_object.global_position
			
		held_object.global_position = drop_pos
		
		if held_object is RigidBody2D:
			held_object.gravity_scale = 1.0
			held_object.sleeping = false
			held_object.linear_velocity = velocity
			
	held_object = null
	is_object_attached = false


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
