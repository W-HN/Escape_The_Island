extends CharacterBody2D

@export var speed: float = 100.0
@export var direction: Vector2 = Vector2.RIGHT  # Will be set by the player
@export var lifetime: float = 2.0  # Time before disappearing

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer

func _ready():
	sprite.play("fireball_stage_2")  # Start with smallest animation
	timer.wait_time = lifetime
	timer.start()

func _process(delta):
	velocity = direction * speed
	move_and_slide()

func _on_timer_timeout():
	queue_free()  # Destroy the fireball after a while

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(10)  # Example damage function
		queue_free()  # Destroy fireball on hit

func grow_fireball():
	if sprite.animation == "fireball_stage_1":
		sprite.play("fireball_stage_2")
	elif sprite.animation == "fireball_stage_2":
		sprite.play("fireball_stage_3")
