extends Label

func _ready():
	var game = get_tree().root.get_node("Game")
	game.connect("keys_changed", _on_keys_changed)
	_on_keys_changed(game.keys) # Show initial value

func _on_keys_changed(amount):
	text = str(amount)
