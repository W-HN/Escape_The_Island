extends Label

func _ready():
	var game = get_tree().root.get_node("Game")
	game.connect("gold_changed", _on_gold_changed)
	_on_gold_changed(game.gold) # Show initial value

func _on_gold_changed(amount):
	text = str(amount)
