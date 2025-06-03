extends Node2D

@onready var closed_sprite = $Closed
@onready var open_sprite = $Open
@onready var collider = $CollisionShape2D
@onready var open_area = $OpenArea

var is_open = false

func _ready():
	open_sprite.visible = false
	closed_sprite.visible = true
	open_area.body_entered.connect(_on_open_area_body_entered)
	open_area.body_exited.connect(_on_open_area_body_exited)

func _on_open_area_body_entered(body):
	if is_open:
		return
	if body.is_in_group("Player"):
		# Check if player has a key
		var game = get_tree().root.get_node("Game")
		if game and game.keys > 0:
			game.keys -= 1
			game.emit_signal("keys_changed", game.keys) 
			set_open(true)

func _on_open_area_body_exited(body):
	pass 

func set_open(state: bool) -> void:
	is_open = state
	open_sprite.visible = is_open
	closed_sprite.visible = not is_open
	collider.set_deferred("disabled", is_open)
