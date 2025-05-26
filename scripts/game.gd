extends Node2D

var gold: int = 0
var keys: int = 0

signal gold_changed(new_gold)
signal keys_changed(new_keys)

func add_gold(amount: int):
	gold += amount
	emit_signal("gold_changed", gold)

func add_key():
	keys += 1
	emit_signal("keys_changed", keys)
