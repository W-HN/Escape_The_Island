extends Area2D

@export var is_on: bool = false
@export var connected_door: NodePath  

@onready var sprite = $AnimatedSprite2D

func _ready():
	update_visual()

func toggle():
	is_on = !is_on
	update_visual()

	if connected_door:
		var door = get_node_or_null(connected_door)
		if door:
			door.call_deferred("set_open", is_on)

func update_visual():
	if is_on:
		sprite.play("turn_on")
	else:
		sprite.play("turn_off")
		
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		toggle()
