extends CharacterBody2D

const SPEED = 100.0
var direction = 1
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var can_flip = true

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	if animated_sprite:
		animated_sprite.play("default")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_on_wall() and can_flip:
		flip_direction()

	velocity.x = direction * SPEED
	move_and_slide()

func flip_direction():
	can_flip = false
	direction *= -1
	
	if animated_sprite:
		# تعديل الاتجاه: يعكس الصورة للاتجاه الصحيح عند الحركة لليمين
		animated_sprite.flip_h = (direction == 1)
	
	await get_tree().create_timer(0.15).timeout
	can_flip = true
