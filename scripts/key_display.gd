extends HBoxContainer

@onready var key_num = $KeyNum

func _ready():
	var game = get_tree().root.get_node("Game")
	game.connect("keys_changed", _on_keys_changed)
	_on_keys_changed(game.keys) # show initial value

func _on_keys_changed(amount):
	key_num.text = str(amount)
