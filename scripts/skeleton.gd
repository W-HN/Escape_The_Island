extends CharacterBody2D

@export var speed: float = 25.0
@export var follow_range: float = 50.0  # Distance at which the skeleton starts following the player
@export var invincibility_time: float = 0.3

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var attack_area = $AttackArea  # Reference to Area2D
@onready var sprite = $AnimatedSprite2D

var health = 3
var dying = false
var is_invincible = false
var blink_timer = 0.05

var last_direction = "right"  # Track last horizontal movement direction
var last_vertical_direction = "down"  # Track last vertical movement direction

func _ready():
	set_multiplayer_authority(1)


	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(delta):
	if dying:
		return
		
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() == 0:
		return  # No players available

	# Choose the closest player
	var target_player = players[0]
	for p in players:
		if global_position.distance_to(p.global_position) < global_position.distance_to(target_player.global_position):
			target_player = p

	var distance_to_player = global_position.distance_to(target_player.global_position)
	if distance_to_player <= follow_range:
		var direction = (target_player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()

		if velocity.length() > 0:
			_play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		_play_idle_animation()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage.rpc(global_position)  # Call damage function on player

# Function to handle walking animations
func _play_walk_animation(direction: Vector2) -> void:
	if direction.y < 0:
		last_vertical_direction = "up"
		if last_direction == "left":
			sprite.play("walk_up_left")
		else:
			sprite.play("walk_up_right")
	elif direction.y > 0:
		last_vertical_direction = "down"
		if last_direction == "left":
			sprite.play("walk_down_left")
		else:
			sprite.play("walk_down_right")
	else:
		if last_vertical_direction == "up":
			if last_direction == "left":
				sprite.play("walk_up_left")
			else:
				sprite.play("walk_up_right")
		else:
			if last_direction == "left":
				sprite.play("walk_down_left")
			else:
				sprite.play("walk_down_right")

	# Update last movement direction
	if direction.x < 0:
		last_direction = "left"
	elif direction.x > 0:
		last_direction = "right"

# Function to handle idle animations
func _play_idle_animation() -> void:
	if last_vertical_direction == "up":
		if last_direction == "left":
			sprite.play("idle_up_left")
		else:
			sprite.play("idle_up_right")
	else:
		if last_direction == "left":
			sprite.play("idle_down_left")
		else:
			sprite.play("idle_down_right")
			
@rpc
func take_damage(amount):
	if dying or is_invincible:
		return
		
	health -= amount
	
	is_invincible = true
	_start_invincibility_effect()

	if health <= 0:
		die()
	else:
		await get_tree().create_timer(invincibility_time).timeout
		is_invincible = false
		_stop_invincibility_effect()

func apply_knockback(force: Vector2):
	if dying or is_invincible:
		return
	velocity += force  # Add force to velocity for knockback
	move_and_slide()
	
func die():
	if dying:
		return  # Prevent multiple deaths

	dying = true  # Mark skeleton as dead
	velocity = Vector2.ZERO  # Stop movement

	# Disable collisions so no more hits can register
	$CollisionShape2D.set_deferred("disabled", true)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)  # Stop detecting player

	# Select the correct death animation based on movement direction
	var death_animation = _get_death_animation()
	sprite.play(death_animation)

	# Wait for animation to finish
	await sprite.animation_finished

	# Start fade-out effect
	_fade_out_and_remove()

func _get_death_animation() -> String:
	if last_vertical_direction == "up":
		return "death_up_left" if last_direction == "left" else "death_up_right"
	else:
		return "death_down_left" if last_direction == "left" else "death_down_right"
		
func _fade_out_and_remove():
	var fade_tween = get_tree().create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 1.5)  # Fade out over 1.5 seconds
	await fade_tween.finished
	queue_free()  # Remove skeleton from scene
	
func _start_invincibility_effect():
	var blink_tween = get_tree().create_tween()
	blink_tween.set_loops(invincibility_time / (blink_timer * 2))
	blink_tween.tween_property(sprite, "modulate:a", 0.2, blink_timer)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, blink_timer)

func _stop_invincibility_effect():
	sprite.modulate.a = 1.0  # Reset transparency
