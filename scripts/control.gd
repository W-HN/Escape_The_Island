extends Control

@onready var resume_button = $VBoxContainer/Resume
@onready var quit_button = $VBoxContainer/Quit

func _ready():
	print("ready")
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_resume_pressed():
	get_tree().paused = false
	visible = false

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://TitleScreen.tscn") 
