extends Area2D

@export var attack_damage: int = 1
@export var knockback_force: float = 1000
@export var animation_name: String = "slash_effect"  # Set from player script

@onready var sprite = $AnimatedSprite2D

func _ready():
	add_to_group("attack")
	sprite.play(animation_name)
	connect("body_entered", _on_body_entered)
	await sprite.animation_finished
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("golem_hitbox"):
		# Use the hitbox's parent as the golem node
		var golem = body.get_parent()
		if golem and golem.has_method("take_damage_knockback"):
			golem.take_damage_knockback(attack_damage, global_position)
		# ... apply knockback, etc, as before
		return

	# Existing logic for other enemies:
	if body.is_in_group("enemies"):
		if body.has_method("apply_knockback"):
			apply_knockback(body)
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
		if body.has_method("take_damage_knockback"):
			body.take_damage_knockback(attack_damage, global_position)


func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(knockback_direction * knockback_force)
