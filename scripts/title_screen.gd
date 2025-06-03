extends Control

@onready var sound_button = $sfx_button

func _on_start_button_pressed() -> void:
	sound_button.play()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed() -> void:
	sound_button.play()
	get_tree().quit()
