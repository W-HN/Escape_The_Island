extends Area2D  # or Area2D if you want collision

@export var bush: Texture2D = preload("res://assets/objects/bush.png")
@export var bush_cut: Texture2D = preload("res://assets/objects/bush_cut.png")

var is_cut = false

func _ready():
	# Set to the whole bush at start
	$Sprite2D.texture = bush

func cut_bush():
	if not is_cut:
		is_cut = true
		$Sprite2D.texture = bush_cut
		$Sprite2D.z_index = -1
		$Bp1.restart()
		$Bp2.restart()
		$Bp3.restart()
		$Bp4.restart()
		$Bp5.restart()
		$Bp6.restart()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		cut_bush()
