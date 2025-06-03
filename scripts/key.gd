extends Area2D

@onready var sprite = $Sprite2D

func _ready():
	pass
	
func _on_body_entered(body):
	if body.is_in_group("Player"):
		
		var game = get_tree().root.get_node("Game")
		if game and game.has_method("add_key"):
			game.add_key.rpc()
		queue_free()
