extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D  # Reference to the sprite

const SPEED = 75.0
const DASH_SPEED = 200.0
const DASH_TIME = 0.2  # Duration of the dash
const RECOVERY_TIME = 1.0  # Time to recover from 20% speed to full speed
const MIN_SPEED_FACTOR = 0.2  # 20% of normal speed

var dash_timer = 0.0
var is_dashing = false
var recovering = false
var recovery_timer = 0.0
var dash_direction = Vector2.ZERO
var current_speed = SPEED
var last_direction = "right"  # Track last horizontal movement direction
var last_vertical_direction = "down"  # Track last vertical movement direction

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var is_moving = false  # Track if player is moving

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED

		# Play roll animation only during dash
		if sprite.animation != "roll":
			sprite.play("roll")

		if dash_timer <= 0:
			is_dashing = false
			recovering = true
			recovery_timer = RECOVERY_TIME
			current_speed = SPEED * MIN_SPEED_FACTOR  # Start recovery at 20% speed

	elif recovering:
		# Allow movement in all directions during recovery
		if Input.is_action_pressed("move_left"):
			direction.x -= 1
			last_direction = "left"
			is_moving = true
		elif Input.is_action_pressed("move_right"):
			direction.x += 1
			last_direction = "right"
			is_moving = true

		if Input.is_action_pressed("move_up"):
			direction.y -= 1
			last_vertical_direction = "up"
			is_moving = true
		if Input.is_action_pressed("move_down"):
			direction.y += 1
			last_vertical_direction = "down"
			is_moving = true

		direction = direction.normalized()

		# Gradually increase speed during recovery
		recovery_timer -= delta
		var recovery_factor = 1.0 - (recovery_timer / RECOVERY_TIME)
		current_speed = lerp(SPEED * MIN_SPEED_FACTOR, SPEED, recovery_factor)

		if recovery_timer <= 0:
			recovering = false  # Fully recovered to normal speed

		velocity = direction * current_speed  # Apply movement during recovery

		# Ensure correct animation plays in recovery phase
		if is_moving:
			_play_walk_animation(direction)
		else:
			_play_idle_animation()

	else:
		# Normal movement
		if Input.is_action_pressed("move_left"):
			direction.x -= 1
			last_direction = "left"
			is_moving = true
		elif Input.is_action_pressed("move_right"):
			direction.x += 1
			last_direction = "right"
			is_moving = true

		if Input.is_action_pressed("move_up"):
			direction.y -= 1
			last_vertical_direction = "up"
			is_moving = true
		if Input.is_action_pressed("move_down"):
			direction.y += 1
			last_vertical_direction = "down"
			is_moving = true

		direction = direction.normalized()

		# Animation Handling
		if is_moving:
			_play_walk_animation(direction)
		else:
			_play_idle_animation()

		# Dash Handling
		if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO:
			is_dashing = true
			dash_timer = DASH_TIME
			dash_direction = direction
			velocity = dash_direction * DASH_SPEED
		else:
			velocity = direction * current_speed

	move_and_slide()
	
	

# Function to determine correct walk animation based on movement direction
# Functions for animation selection during movement remain the same
func _play_walk_animation(direction: Vector2) -> void:
	if direction.y < 0:
		if last_direction == "left":
			sprite.play("walk_up_left")
		else:
			sprite.play("walk_up_right")
	elif direction.y > 0:
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
