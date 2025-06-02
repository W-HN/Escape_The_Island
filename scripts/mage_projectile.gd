extends Area2D

@export var speed: float = 100.0
@export var direction: Vector2 = Vector2.RIGHT
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var knockback_force: float = 500.0

@export var wave_strength: float = 0.0  # 0 = no wave
@export var wave_speed: float = 1.0
@export var wave_phase: float = 0.0

var source  # Reference to whoever fired it
var time_alive: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer
@onready var sound_cast = $sfx_cast

func _ready():
	sprite.play("projectile")
	timer.wait_time = lifetime
	timer.start()
	connect("body_entered", _on_body_entered)
	$CollisionShape2D.set_deferred("disabled", false)
	sound_cast.play()

func _process(delta):
	time_alive += delta

	# Stronger and clearer wave motion
	var perp = Vector2(-direction.y, direction.x)  # Perpendicular to direction
	var wave_factor = sin((time_alive + wave_phase) * wave_speed * TAU)
	var wave_offset = perp * wave_factor * wave_strength

	position += (direction * speed * delta) + (wave_offset * delta)

	# Optional: make sprite face forward
	rotation = direction.angle() + wave_factor * 0.2  # Slight sway

	# Optional: Add rotation spin (for fireball style)
	# sprite.rotation += delta * 10


func _on_timer_timeout():
	queue_free()

func _on_body_entered(body):
	if body == source:
		return

	if body.is_in_group("Player"):
		if body.has_method("apply_knockback"):
			apply_knockback(body)
		if body.has_method("take_damage"):
			body.take_damage(global_position)

	queue_free()

func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(knockback_direction * knockback_force)
