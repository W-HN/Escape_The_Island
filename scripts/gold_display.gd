extends HBoxContainer

@onready var gold_num = $GoldNum

func _ready():
	var game = get_tree().root.get_node("Game")
	game.connect("gold_changed", _on_gold_changed)
	_on_gold_changed(game.gold) # show initial value

func _on_gold_changed(amount):
	gold_num.text = str(amount)
