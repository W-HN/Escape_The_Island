extends RigidBody2D

@export var box_texture: Texture2D      # Whole box
@export var box_chunk_particles: Array  # Array of GPUParticles2D nodes
@export var gold_pickup_scene: PackedScene


var is_broken = false

func _ready():
	$Sprite2D.texture = box_texture

func break_box():
	if not is_broken:
		is_broken = true
		$Sprite2D.hide()
		$CollisionShape2D.set_deferred("disabled", true)
		# Play all chunk particles
		$Bp1.restart()
		$Bp2.restart()
		$Bp3.restart()
		$Bp4.restart()
		$Bp5.restart()
		$Bp6.restart()
		# Drop 1–3 gold coins
		if gold_pickup_scene:
			var num_gold = randi_range(1, 3)
			for i in num_gold:
				var gold_pickup = gold_pickup_scene.instantiate()
				gold_pickup.position = position
				var angle = randf_range(0, TAU)
				var speed = randf_range(20, 30)
				gold_pickup.velocity = Vector2.RIGHT.rotated(angle) * speed
				get_parent().call_deferred("add_child", gold_pickup)
		await get_tree().create_timer(1.0).timeout
		queue_free()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		break_box()
