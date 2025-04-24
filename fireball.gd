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
	add_to_group("attack")
	sprite.play("fireball_stage_2")  # Start with default animation
	
	# Setup and start timer
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.start()
	if not timer.is_connected("timeout", _on_timer_timeout):
		timer.connect("timeout", _on_timer_timeout)

	# Setup collision signal
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)

	# Ensure collision is active
	$CollisionShape2D.set_deferred("disabled", false)


func _process(delta):
	# Move fireball forward
	position += direction * speed * delta
	sprite.rotation += delta * -5  # Adjust rotation speed as needed

func _on_timer_timeout():
	queue_free()  # Destroy the fireball after a while

func _on_body_entered(body):
	# Fireball hits an enemy
	if body.is_in_group("enemies"):
		if body.has_method("apply_knockback"):
			apply_knockback(body)  # Apply knockback effect
		if body.has_method("take_damage"):
			body.take_damage(damage)  # Apply damage

	queue_free()  # Destroy fireball on impact

func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(knockback_direction * knockback_force)
