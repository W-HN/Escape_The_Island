extends RigidBody2D

@export var box_texture: Texture2D      # Whole box
@export var box_chunk_particles: Array  # Array of GPUParticles2D nodes (optional)

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
		await get_tree().create_timer(1.0).timeout
		queue_free()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		break_box()
