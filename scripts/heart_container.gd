extends HBoxContainer

@export var full_heart: Texture2D
@export var half_heart: Texture2D
@export var empty_heart: Texture2D

func update_hearts(current_health: int):
	var heart_images = [$Heart1, $Heart2, $Heart3]
	var health_remaining = current_health

	for heart in heart_images:
		if health_remaining >= 2:
			heart.texture = full_heart
			health_remaining -= 2
		elif health_remaining == 1:
			heart.texture = half_heart
			health_remaining -= 1
		else:
			heart.texture = empty_heart
