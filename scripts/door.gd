extends Node2D

@onready var closed_sprite = $Closed
@onready var open_sprite = $Open
@onready var collider = $CollisionShape2D

var is_open = false

func set_open(state: bool) -> void:
	is_open = state

	open_sprite.visible = is_open
	closed_sprite.visible = not is_open

	collider.disabled = is_open
