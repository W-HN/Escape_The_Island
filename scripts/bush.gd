extends Area2D

@export var bush: Texture2D = preload("res://assets/objects/bush.png")
@export var bush_cut: Texture2D = preload("res://assets/objects/bush_cut.png")
@export var gold_pickup_scene: PackedScene
@export var heart_pickup_scene: PackedScene

@onready var sound_break = $sfx_breakGrass

var is_cut = false

func _ready():
	$Sprite2D.texture = bush

func cut_bush():
	if not is_cut:
		sound_break.play()
		is_cut = true
		$Sprite2D.texture = bush_cut
		$Sprite2D.z_index = -1
		$Bp1.restart()
		$Bp2.restart()
		$Bp3.restart()
		$Bp4.restart()
		$Bp5.restart()
		$Bp6.restart()
		if gold_pickup_scene:
			var num_gold = randi_range(0, 1)
			for i in num_gold:
				var gold_pickup = gold_pickup_scene.instantiate()
				gold_pickup.position = position
				var angle = randf_range(0, TAU)
				var speed = randf_range(20, 30)
				gold_pickup.velocity = Vector2.RIGHT.rotated(angle) * speed
				get_parent().call_deferred("add_child", gold_pickup)
				
		if heart_pickup_scene and randi_range(1, 5) == 1:
			var heart_pickup = heart_pickup_scene.instantiate()
			heart_pickup.position = position

			var angle = randf_range(0, TAU)
			var speed = randf_range(20, 30)
			heart_pickup.velocity = Vector2.RIGHT.rotated(angle) * speed
			heart_pickup.bounce_velocity = randf_range(40.0, 46.0)  
			heart_pickup.bouncing = true
			get_parent().call_deferred("add_child", heart_pickup)



func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		cut_bush()
