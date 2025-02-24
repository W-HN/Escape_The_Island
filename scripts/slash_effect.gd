extends CharacterBody2D

@export var attack_damage: int = 10  # Damage value
@export var knockback_force: float = 200  # Adjust knockback strength

@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D

func _ready():
	sprite.play("slash_effect")  # Play the slash animation
	await sprite.animation_finished
	queue_free()  # Destroy the slash effect after animation finishes

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(attack_damage)  # Apply damage
		apply_knockback(body)  # Apply knockback effect

func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	if enemy.has_method("apply_knockback"):  # Ensure the enemy has this function
		enemy.apply_knockback(knockback_direction * knockback_force)
