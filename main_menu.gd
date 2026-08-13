extends Control

# مسار المرحلة التي سينتقل إليها الزر مباشرة
const TUTORIAL_SCENE_PATH: String = "res://tutorial_o.tscn"

# ربط العقد تلقائياً عبر المسارات Direct Node Paths
@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings_menu: PanelContainer = $SettingsMenu

@onready var play_button: Button = $MainButtons/PlayButton
@onready var settings_button: Button = $MainButtons/SettingsButton
@onready var quit_button: Button = $MainButtons/QuitButton

@onready var volume_slider: HSlider = get_node_or_null("SettingsMenu/SettingsVBox/VolumeHBox/VolumeSlider")
@onready var fullscreen_check: CheckBox = get_node_or_null("SettingsMenu/SettingsVBox/FullscreenCheck")
@onready var back_button: Button = get_node_or_null("SettingsMenu/SettingsVBox/BackButton")


func _ready():
	# طباعة للتأكد من تشغيل السكريبت في قائمة المخرجات (Output)
	print("MainMenu Ready!")

	if settings_menu:
		settings_menu.visible = false
	if main_buttons:
		main_buttons.visible = true

	# ربط الأزرار وإضافة رسائل طباعة للتأكد من الربط
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
		print("تم ربط زر Play بنجاح!")
	else:
		print("خطأ: لم يتم العثور على PlayButton في المسار MainButtons/PlayButton")

	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)

	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)

	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_initialize_settings_ui()


# ==========================================
# وظيفة زر PLAY
# ==========================================
func _on_play_pressed():
	print("تم الضغط على زر Play!") # للتأكد في نافذة الـ Output
	
	if ResourceLoader.exists(TUTORIAL_SCENE_PATH):
		print("جاري الانتقال إلى: ", TUTORIAL_SCENE_PATH)
		get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)
	else:
		print("خطأ قاتل: الملف غير موجود بهذا المسار بالضبط: ", TUTORIAL_SCENE_PATH)


func _on_settings_pressed():
	if main_buttons:
		main_buttons.visible = false
	if settings_menu:
		settings_menu.visible = true


func _on_quit_pressed():
	get_tree().quit()


func _on_back_pressed():
	if settings_menu:
		settings_menu.visible = false
	if main_buttons:
		main_buttons.visible = true


func _initialize_settings_ui():
	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	if volume_slider:
		var master_bus_index = AudioServer.get_bus_index("Master")
		var current_db = AudioServer.get_bus_volume_db(master_bus_index)
		volume_slider.min_value = 0.0001
		volume_slider.max_value = 1.0
		volume_slider.value = db_to_linear(current_db)


func _on_volume_changed(value: float):
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))


func _on_fullscreen_toggled(is_fullscreen: bool):
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
