extends Area2D

@export var speed: float = 100.0
@export var direction: Vector2 = Vector2.RIGHT  # Will be set by the player
@export var lifetime: float = 2.0  # Time before disappearing
@export var damage: int = 1  # Damage amount
@export var knockback_force: float = 500.0  # Adjust knockback strength

var source  # Reference to the player

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer

func _ready():
	sprite.play("projectile")  # Start with default animation
	timer.wait_time = lifetime
	timer.start()
	
	# Enable monitoring for collision detection
	connect("body_entered", _on_body_entered)  # Connect signal for enemy collision
	$CollisionShape2D.set_deferred("disabled", false)

func _process(delta):
	# Move fireball forward
	position += direction * speed * delta

	# 🔥 Make the fireball spin while moving
	sprite.rotation += delta * 10  # Adjust rotation speed as needed

func _on_timer_timeout():
	queue_free()  # Destroy the fireball after a while

func _on_body_entered(body):
	if body == source:
		return
		
	# Fireball hits an enemy
	if body.is_in_group("Player"):
		if body.has_method("apply_knockback"):
			apply_knockback(body)  # Apply knockback effect
		if body.has_method("take_damage"):
			body.take_damage(global_position)


	queue_free()  # Destroy fireball on impact

func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(knockback_direction * knockback_force)
