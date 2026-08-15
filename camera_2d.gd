extends Camera2D

# تحديد اللاعب يدويًا أو تلقائيًا
@export var target: Node2D

# ==========================================
# إعدادات السرعة والإزاحة
# ==========================================
# سرعة استجابة عالية جدًا لتتبع اللاعب فورًا بدون تأخير
@export var follow_speed: float = 20.0

# إنزال الكاميرا لأسفل (قيمة موجبة تعني إنزال الكاميرا)
@export var vertical_offset: float = 60.0

# مسافة النظر للأمام عند الحركة
@export var look_ahead_distance: float = 70.0
@export var look_ahead_speed: float = 10.0

var current_look_ahead: float = 0.0


func _ready():
	# تفعيل الكاميرا لتكون هي الكاميرا الأساسية للعبة
	enabled = true
	
	# محاولة العثور على اللاعب فور بدء اللعبة
	find_player_target()


func _process(delta: float):
	# إذا فقدت الكاميرا الهدف (مثلاً عند إعادة تحميل المشهد)، تبحث عنه مجددًا
	if target == null or not is_instance_valid(target):
		find_player_target()
		return

	# 1. حساب النظر للأمام بناءً على اتجاه حركة اللاعب
	var desired_look_ahead = 0.0
	if "velocity" in target:
		if target.velocity.x > 10:
			desired_look_ahead = look_ahead_distance
		elif target.velocity.x < -10:
			desired_look_ahead = -look_ahead_distance

	current_look_ahead = lerp(current_look_ahead, desired_look_ahead, look_ahead_speed * delta)

	# 2. حساب موقع الكاميرا المستهدف مع الإزاحة العمودية
	var target_pos = target.global_position + Vector2(current_look_ahead, vertical_offset)

	# 3. التحريك السريع للكاميرا
	global_position = global_position.lerp(target_pos, follow_speed * delta)


func find_player_target():
	# 1. البحث عبر مجموعة "player"
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		return

	# 2. البحث عن أي عقدة تحتوي اسمها على "Player" في حال عدم ضبط Group
	var root = get_tree().current_scene
	if root != null:
		for child in root.get_children():
			if "player" in child.name.to_lower():
				target = child
				return
