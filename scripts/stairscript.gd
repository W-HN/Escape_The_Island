# Staircase.gd
extends Area2D

@export var floor_a: int = 1
@export var floor_b: int = 2


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		#check which floor player is on and send them to the opposite
		if body.current_floor == floor_a:
			body.change_floor(floor_b)
		else:
			body.change_floor(floor_a)
