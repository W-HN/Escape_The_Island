extends Node2D

var gold: int = 0
var keys: int = 0

signal gold_changed(new_gold)
signal keys_changed(new_keys)

@onready var pause_menu = $PauseMenu 
@onready var sound_getmoney = $sfx_getMoney
@onready var sound_getkey = $sfx_getkey

func _ready():
	pause_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  

func add_gold(amount: int):
	sound_getmoney.pitch_scale = randf_range(0.9, 1.2)
	sound_getmoney.play()
	gold += amount
	emit_signal("gold_changed", gold)

func add_key():
	sound_getkey.pitch_scale = randf_range(0.9, 1.2)
	sound_getkey.play()
	keys += 1
	emit_signal("keys_changed", keys)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game():
	get_tree().paused = true
	pause_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume_game():
	get_tree().paused = false
	pause_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)



func _on_resume_pressed() -> void:
	resume_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
