extends Control

@onready var sfx_button := $sfx_button

func _on_start_button_pressed() -> void:
	sfx_button.play()
	await sfx_button.finished
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed() -> void:
	sfx_button.play()
	await sfx_button.finished
	get_tree().quit()
