extends Area2D

# متغير للتأكد من تفعيل الشكبوينت مرة واحدة فقط
var is_active = false

@onready var anim = get_node_or_null("AnimatedSprite2D")

func _ready():
	# ربط إشارة دخول جسم للمنطقة برمجياً بشكل آمن
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# التأكد من أن الجسم هو اللاعب أولاً (قبل تغيير حالة is_active)
	if not is_active and (body.is_in_group("player") or body.has_method("update_checkpoint")):
		is_active = true
		
		# تحديث نقطة الحفظ في اللاعب إلى موقع هذه الشكبوينت
		body.update_checkpoint(global_position)
		print("تم تفعيل نقطة الحفظ بنجاح عند: ", global_position)
		
		# تغيير أنيميشن العلم بشكل آمن
		if anim != null:
			if anim.sprite_frames.has_animation("flag_out"):
				anim.play("flag_out")
			elif anim.sprite_frames.has_animation("default"):
				anim.play("default")
