extends Area2D

func _on_body_entered(body):
	if body.name == "player":  # أو تحقق بـ body is CharacterBody2D
		get_tree().change_scene_to_file("res://path/to/next_level2.tscn")
