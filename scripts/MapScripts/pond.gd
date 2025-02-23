extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
#Pond var inconsistent med signals, bruker heller custom data layer tiles for pond
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.enter_pond()



func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.leave_pond()
