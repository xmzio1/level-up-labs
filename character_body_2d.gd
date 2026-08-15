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
# قائمة رسائل الموت الساخرة (5 عبارات بالإنجليزية)
# ==========================================
var death_messages = [
	"You are a NOOB!",
	"Nice jump! Gravity won again.",
	"Keyboard isn't the problem...",
	"Pro tip: Avoid dying.",
	"Are you playing with your eyes closed?"
]

# ==========================================
# متغيرات ميكانيك الالتصاق بالجدار (Wall Stick)
# ==========================================
@export var wall_slide_speed: float = 0.0        # ثبات تام بالفعل المغناطيسي
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
@onready var slide_sound: AudioStreamPlayer2D = get_node_or_null("slidesound")

var is_magnet_on: bool = false
var held_object: Node2D = null         # الجسم الممسوك حالياً
var is_object_attached: bool = false    # هل وصل الجسم للرأس وتم تثبيته؟

# عداد وقت الضغط المطول للرمي
var e_press_timer: float = 0.0
var is_e_held: bool = false

# ==========================================
# متغيرات أنيميشن الانتظار المطول (Idle Long System)
# ==========================================
const IDLE_LONG_TIME = 15.0
var idle_timer: float = 0.0
var is_playing_idle_long: bool = false
var is_in_idle_2: bool = false

# ==========================================
# ربط عقد التصادم المنفصلة (Stand & Slide)
# ==========================================
@onready var stand_collision: CollisionShape2D = get_node_or_null("StandCollision")
@onready var slide_collision: CollisionShape2D = get_node_or_null("SlideCollision")

@onready var anim = get_node_or_null("AnimatedSprite2D")

@export var respawn_position = Vector2(100, 200)
@export var tilemap : TileMap

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

# حفظ حجم الأنيميشن الأصلية
var original_anim_scale: Vector2 = Vector2.ONE


func _ready():
	add_to_group("player")
	respawn_position = global_position
	
	if stand_collision != null and slide_collision != null:
		stand_collision.disabled = false
		slide_collision.disabled = true

	if anim != null:
		original_anim_scale = anim.scale
		if not anim.animation_finished.is_connected(_on_animation_finished):
			anim.animation_finished.connect(_on_animation_finished)

	is_magnet_on = false
	if magnet_sprite != null:
		magnet_sprite.visible = false


func _physics_process(delta):

	if is_falling:
		return

	# ==========================================
	# تدوير المغناطيس (تقييد الحركة بـ 180 درجة أمام اللاعب)
	# ==========================================
	if magnet_pivot != null:
		var target_angle: float = 0.0
		var aim_dir = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		
		if aim_dir.length_squared() > 0:
			target_angle = aim_dir.angle()
		else:
			target_angle = (get_global_mouse_position() - magnet_pivot.global_position).angle()

		# تحديد الاتجاه الذي ينظر إليه اللاعب (يمين أم يسار)
		var is_facing_left = (anim != null and anim.flip_h)
		
		if is_facing_left:
			# النصف الأيسر: من 90 درجة (أسفل) إلى -90 درجة (أعلى) مروراً بـ 180 (يسار)
			# نطاق الزاوية بالراديان: [PI/2, -PI/2]
			if target_angle > -PI/2 and target_angle < PI/2:
				# إذا كان الهدف في النصف الأيمن، نوجّه المغناطيس لأقرب حد (أعلى أو أسفل)
				if target_angle > 0:
					target_angle = PI / 2
				else:
					target_angle = -PI / 2
		else:
			# النصف الأيمن: من -90 درجة (أعلى) إلى 90 درجة (أسفل) مروراً بـ 0 (يمين)
			# clampf يحد الزاوية بين -PI/2 و PI/2
			target_angle = clampf(target_angle, -PI / 2, PI / 2)

		magnet_pivot.rotation = target_angle

	# ==========================================
	# معالجة الضغط المطول على E للرمي أو السحب
	# ==========================================
	handle_magnet_input(delta)

	# معالجة سحب وتثبيت الجسم (يعمل حتى لو كان ملتصقاً بالجدار)
	if is_magnet_on:
		process_magnet_logic(delta)

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
		if anim != null: anim.flip_h = false
	elif direction < 0 and not is_wall_sticking:
		if anim != null: anim.flip_h = true

	# =========================
	# معالجة الالتصاق بالجدار (Wall Stick Setup)
	# =========================
	handle_wall_stick()

	# =========================
	# التحكم برؤية المغناطيس (إخفاؤه عند الالتصاق بالجدار)
	# =========================
	if magnet_sprite != null:
		if is_wall_sticking:
			magnet_sprite.visible = false
		else:
			magnet_sprite.visible = is_magnet_on

	# =========================
	# بدء السلايد الأرضي
	# =========================
	if Input.is_action_just_pressed("ui_page_down") \
	and is_on_floor() \
	and slide_cooldown_timer <= 0 \
	and not is_sliding:

		start_slide()

	# =========================
	# حركة السلايد والسرعة الأفقية
	# =========================
	if is_sliding:
		velocity.x = slide_direction * SLIDE_SPEED
		slide_timer -= delta
		
		if slide_timer <= 0:
			if can_stand_up():
				stop_slide()
	elif not is_wall_sticking:
		velocity.x = direction * SPEED

	# =========================
	# الجاذبية وسلوك الجدار
	# =========================
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jump_count = 0
		is_wall_sticking = false
	elif is_wall_sticking:
		velocity.y = 0
		velocity.x = 0
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
			if is_sliding: stop_slide()
			velocity.y = JUMP_VELOCITY
			velocity.x = wall_normal.x * SPEED * 1.2
			is_wall_sticking = false
			jump_count = 1

			if jump_sound != null:
				jump_sound.pitch_scale = randf_range(0.95, 1.05)
				jump_sound.play()

			jump_buffer_timer = 0

		elif coyote_timer > 0 or jump_count < MAX_JUMPS:

			if is_sliding: stop_slide()
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
	# معالجة الأنيميشن وعداد Idle
	# =========================
	handle_animations(direction, delta)

	# =========================
	# السقوط في الـ Void أو الوقوع على الهلاك
	# =========================
	if global_position.y > FALL_LIMIT:
		die()

	if is_on_danger_tile():
		die()


func update_checkpoint(new_position: Vector2) -> void:
	respawn_position = new_position


func start_slide() -> void:
	is_sliding = true
	slide_timer = SLIDE_DURATION
	slide_cooldown_timer = SLIDE_COOLDOWN

	if anim != null:
		if anim.flip_h:
			slide_direction = -1
		else:
			slide_direction = 1
		anim.play("slide")

	if stand_collision != null and slide_collision != null:
		stand_collision.set_deferred("disabled", true)
		slide_collision.set_deferred("disabled", false)

	if slide_sound != null:
		slide_sound.pitch_scale = randf_range(0.95, 1.05)
		slide_sound.play()


func stop_slide() -> void:
	is_sliding = false

	if stand_collision != null and slide_collision != null:
		stand_collision.set_deferred("disabled", false)
		slide_collision.set_deferred("disabled", true)

	if slide_sound != null and slide_sound.playing:
		slide_sound.stop()


func can_stand_up() -> bool:
	if stand_collision == null or stand_collision.shape == null:
		return true

	var space_state = get_world_2d().direct_space_state
	var ray_length = 32.0
	if stand_collision.shape is CapsuleShape2D:
		ray_length = stand_collision.shape.height
	elif stand_collision.shape is RectangleShape2D:
		ray_length = stand_collision.shape.size.y

	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, -ray_length))
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	
	return result.size() == 0


func handle_animations(direction: float, delta: float) -> void:
	if anim == null:
		return

	if is_sliding:
		reset_idle_timers()
		anim.play("slide")
	elif is_wall_sticking:
		reset_idle_timers()
		if anim.sprite_frames.has_animation("wall_stick"):
			anim.play("wall_stick")
		elif anim.sprite_frames.has_animation("wall_slide"):
			anim.play("wall_slide")
			anim.frame = 0
		else:
			anim.play("idle")
	elif is_on_floor():
		if direction != 0:
			reset_idle_timers()
			if anim.animation != "run":
				run_first_time = true
				anim.play("run")
				anim.frame = 0
		else:
			run_first_time = true
			
			if is_in_idle_2:
				anim.play("idle_2")
			elif is_playing_idle_long:
				pass
			else:
				idle_timer += delta
				if idle_timer >= IDLE_LONG_TIME:
					if anim.sprite_frames.has_animation("idle_fortolong"):
						is_playing_idle_long = true
						anim.play("idle_fortolong")
					elif anim.sprite_frames.has_animation("idle_2"):
						is_in_idle_2 = true
						anim.play("idle_2")
				else:
					anim.play("idle")
	else:
		reset_idle_timers()
		run_first_time = true
		if velocity.y < 0:
			anim.play("jump")
		else:
			anim.play("fall")


func reset_idle_timers() -> void:
	idle_timer = 0.0
	is_playing_idle_long = false
	is_in_idle_2 = false


func _on_animation_finished() -> void:
	if anim != null and anim.animation == "idle_fortolong":
		is_playing_idle_long = false
		is_in_idle_2 = true
		if anim.sprite_frames.has_animation("idle_2"):
			anim.play("idle_2")


func handle_wall_stick() -> void:
	if is_on_wall() and not is_on_floor():
		var wall_valid = false

		for i in get_slide_collision_count():
			var collision_info = get_slide_collision(i)
			var collider = collision_info.get_collider()

			if collider != null:
				var is_in_layer_1 = false
				if "collision_layer" in collider:
					is_in_layer_1 = (collider.collision_layer & 1) != 0
				else:
					is_in_layer_1 = true

				if not is_in_layer_1:
					continue

				var node_name = collider.name.to_lower()
				var parent_name = ""
				if collider.get_parent() != null:
					parent_name = collider.get_parent().name.to_lower()

				if "wa" in node_name or "wa" in parent_name or collider.is_in_group("wa"):
					wall_valid = true
					wall_normal = collision_info.get_normal()
					break

				if collider is TileMap or (Engine.get_version_info().major >= 4 and collider.is_class("TileMapLayer")):
					var collision_point = collision_info.get_position() - collision_info.get_normal()
					var tile_pos = collider.local_to_map(collider.to_local(collision_point))
					
					var tile_data = null
					if collider.has_method("get_cell_tile_data"):
						if collider.is_class("TileMapLayer"):
							tile_data = collider.get_cell_tile_data(tile_pos)
						else:
							for layer in range(5):
								tile_data = collider.get_cell_tile_data(layer, tile_pos)
								if tile_data != null:
									break

					if tile_data != null:
						var custom_val = tile_data.get_custom_data("tile_type")
						if custom_val == null or custom_val == "":
							custom_val = tile_data.get_custom_data("wa")
						
						if custom_val == "wa" or custom_val == true:
							wall_valid = true
							wall_normal = collision_info.get_normal()
							break

		if wall_valid:
			is_wall_sticking = true
			if anim != null:
				if wall_normal.x > 0:
					anim.flip_h = false
				elif wall_normal.x < 0:
					anim.flip_h = true
		else:
			is_wall_sticking = false
	else:
		is_wall_sticking = false


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


func toggle_magnet() -> void:
	is_magnet_on = !is_magnet_on
	
	if magnet_stick_sound != null:
		magnet_stick_sound.pitch_scale = randf_range(0.95, 1.05)
		magnet_stick_sound.play()

	# تحديث الرؤية فقط إذا لم يكن ملتصقاً بالجدار
	if magnet_sprite != null and not is_wall_sticking:
		magnet_sprite.visible = is_magnet_on

	if not is_magnet_on:
		release_held_object()


func throw_held_object() -> void:
	if held_object != null and is_instance_valid(held_object):
		remove_collision_exception_with(held_object)
		
		var throw_dir = 1.0
		if anim != null:
			throw_dir = -1.0 if anim.flip_h else 1.0
		
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


func process_magnet_logic(delta: float) -> void:
	if magnet_area == null:
		return

	var target_pos = global_position + Vector2(0, -hold_height_offset)
	if hold_position != null:
		target_pos = hold_position.global_position

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


func check_for_obstacle(target_pos: Vector2) -> bool:
	if held_object == null or not is_instance_valid(held_object):
		return false

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, held_object.global_position)
	query.exclude = [get_rid(), held_object.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.size() > 0


func release_held_object() -> void:
	if held_object != null and is_instance_valid(held_object):
		remove_collision_exception_with(held_object)
		
		var side_dir = 1.0
		if anim != null:
			side_dir = -1.0 if anim.flip_h else 1.0
			
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


func die():
	if is_falling:
		return

	is_falling = true
	velocity = Vector2.ZERO

	if slide_sound != null and slide_sound.playing:
		slide_sound.stop()

	if anim != null:
		if anim.sprite_frames.has_animation("die"):
			anim.play("die")
		else:
			anim.play("fall")

		var tween = create_tween()
		tween.tween_property(anim, "scale", original_anim_scale * 2.2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var random_text = death_messages[randi() % death_messages.size()]
	var noob_layer = show_noob_screen(random_text)

	await get_tree().create_timer(2.0).timeout

	if anim != null:
		anim.scale = original_anim_scale
		
	if is_instance_valid(noob_layer):
		noob_layer.queue_free()

	global_position = respawn_position
	reset_idle_timers()
	is_falling = false


func show_noob_screen(text_to_display: String) -> CanvasLayer:
	var canvas_layer = CanvasLayer.new()
	
	var color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0.5)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(color_rect)

	var label = Label.new()
	label.text = text_to_display
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	
	canvas_layer.add_child(label)
	get_tree().root.add_child(canvas_layer)
	
	return canvas_layer


func is_on_danger_tile() -> bool:
	if tilemap == null:
		return false

	var local_position = tilemap.to_local(global_position)
	var map_coords = tilemap.local_to_map(local_position)
	var tile_data = tilemap.get_cell_tile_data(1, map_coords)

	if tile_data != null:
		return tile_data.get_custom_data("danger") == true

	return false
