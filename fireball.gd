extends Area2D

@export var speed: float = 100.0
@export var direction: Vector2 = Vector2.RIGHT  # Will be set by the player
@export var lifetime: float = 2.0  # Time before disappearing
@export var damage: int = 1  # Damage amount
@export var knockback_force: float = 500.0  # Adjust knockback strength

var source  # Reference to the player

@onready var sprite = $AnimatedSprite2D
@onready var timer = $Timer

@onready var sound_stop = $sfx_stop
@onready var sound_hitenemy = $sfx_hitenemy

func _ready():
	add_to_group("attack")
	sprite.play("fireball_stage_2")

	# Setup and start timer
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.start()
	if not timer.is_connected("timeout", _on_timer_timeout):
		timer.connect("timeout", _on_timer_timeout)

	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)

	$CollisionShape2D.set_deferred("disabled", false)


func _process(delta):
	position += direction * speed * delta
	sprite.rotation += delta * -5  # Optional rotation


func _on_timer_timeout():
	detach_and_play_sound(sound_stop)
	queue_free()


func _on_body_entered(body):
	if body.is_in_group("enemies"):
		if body.has_method("apply_knockback"):
			apply_knockback(body)
		if body.has_method("take_damage"):
			body.take_damage(damage)
			detach_and_play_sound(sound_hitenemy)

	detach_and_play_sound(sound_stop)
	queue_free()


func apply_knockback(enemy):
	var knockback_direction = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(knockback_direction * knockback_force)


func detach_and_play_sound(sound: AudioStreamPlayer2D):
	if not sound.stream:
		return  # Don't try to play if no sound assigned

	var clone = sound.duplicate()
	clone.global_position = sound.global_position
	get_tree().current_scene.add_child(clone)
	clone.play()

	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = clone.stream.get_length()
	cleanup_timer.one_shot = true
	cleanup_timer.connect("timeout", Callable(clone, "queue_free"))
	clone.add_child(cleanup_timer)
	cleanup_timer.start()
