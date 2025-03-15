extends Area2D

@export var attack_damage: int = 1  # Damage value
@export var knockback_force: float = 1000  # Adjust knockback strength

@onready var sprite = $AnimatedSprite2D

func _ready():
	sprite.play("slash_effect")  # Play the slash animation
	connect("body_entered", _on_body_entered)  # Connect `body_entered` event
	await sprite.animation_finished
	queue_free()  # Destroy the slash effect after animation finishes

func _on_body_entered(body):  # Detect `CharacterBody2D` enemies
	if body.is_in_group("enemies"):

		if body.has_method("apply_knockback"):
			apply_knockback(body)  # Apply knockback effect
		
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)  # Apply damage
		

func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(knockback_direction * knockback_force)
