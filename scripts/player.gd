extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D  # Reference to the sprite
# @onready var Map = get_parent().get_node("Island1/TileMap")

var SPEED = 75.0
var DASH_SPEED = 200.0
const DASH_TIME = 0.2  # Duration of the dash
const RECOVERY_TIME = 1.0  # Time to recover from 20% speed to full speed
const MIN_SPEED_FACTOR = 0.2  # 20% of normal speed

# Attack variables
var slash_scene = preload("res://scenes/slash_effect.tscn")
var is_attacking = false
var attack_timer = 0.0
var attack_cooldown = 0.0
const ATTACK_DURATION = 0.3  # Adjust as needed
const ATTACK_COOLDOWN_DURATION = 0.5  # Adjust as needed


var dash_timer = 0.0
var is_dashing = false
var recovering = false
var recovery_timer = 0.0
var dash_direction = Vector2.ZERO
var current_speed = SPEED
var last_direction = "right"  # Track last horizontal movement direction
var last_vertical_direction = "down"  # Track last vertical movement direction

var first_move = false
var dying = false
var current_floor = 1

# fireball
var fireball_scene = preload("res://scenes/fireball.tscn")



func _physics_process(delta: float) -> void:
	# Prevent movement updates if attacking (so animations don't get overridden)
	if is_attacking:
		velocity = Vector2.ZERO  # Stop movement while attacking
		move_and_slide()
		return

	# Normal movement handling
	if attack_cooldown > 0:
		attack_cooldown -= delta

	handle_movement(delta)

	# Prevent attacking while dashing, but allow it in recovery
	if Input.is_action_just_pressed("attack") and not is_dashing and attack_cooldown <= 0:
		start_attack()
		
	if Input.is_action_just_pressed("fireball") and not is_dashing:
		cast_fireball()

	move_and_slide()




func handle_movement(delta: float) -> void:
	var direction := Vector2.ZERO
	
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if sprite.animation != "roll":
			sprite.play("roll")
		if dash_timer <= 0:
			is_dashing = false
			recovering = true
			recovery_timer = RECOVERY_TIME
			current_speed = SPEED * MIN_SPEED_FACTOR

	elif recovering:
		direction = get_input_direction()
		recovery_timer -= delta
		var recovery_factor = 1.0 - (recovery_timer / RECOVERY_TIME)
		current_speed = lerp(SPEED * MIN_SPEED_FACTOR, SPEED, recovery_factor)
		if recovery_timer <= 0:
			recovering = false
		velocity = direction * current_speed
		if direction != Vector2.ZERO:
			_play_walk_animation(direction)
		else:
			_play_idle_animation()
	else:
		direction = get_input_direction()
		if direction != Vector2.ZERO:
			_play_walk_animation(direction)
		else:
			_play_idle_animation()
		if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO:
			is_dashing = true
			dash_timer = DASH_TIME
			dash_direction = direction
			velocity = dash_direction * DASH_SPEED
		else:
			velocity = direction * current_speed


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
				
func get_input_direction() -> Vector2:
	if dying:
		return Vector2.ZERO
		
	var direction := Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		direction.x -= 1
		last_direction = "left"
	if Input.is_action_pressed("move_right"):
		direction.x += 1
		last_direction = "right"
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
		last_vertical_direction = "up"
	if Input.is_action_pressed("move_down"):
		direction.y += 1
		last_vertical_direction = "down"
	
	if first_move == false and direction != Vector2.ZERO:
		$Sleep_particles.queue_free()
		first_move = true
		
	return direction.normalized()

func start_attack() -> void:
	if dying or is_attacking:
		return
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity = Vector2.ZERO  # Stop movement while attacking
	attack_cooldown = ATTACK_COOLDOWN_DURATION  # Set cooldown

	# Determine attack direction based on mouse position
	var mouse_position = get_global_mouse_position()
	var attack_direction = (mouse_position - global_position).normalized()

	# Play correct attack animation
	_play_attack_animation(attack_direction)
	
	await get_tree().create_timer(0.2).timeout

	# Spawn the slash effect slightly in front of the player
	var slash = slash_scene.instantiate()
	slash.global_position = global_position + (attack_direction * 10)  # Offset
	slash.rotation = attack_direction.angle()  # Rotate slash based on attack direction
	get_parent().add_child(slash)

	# Wait for animation to finish before allowing movement again
	await sprite.animation_finished
	slash.queue_free()  # Remove slash effect

	is_attacking = false
	
	
func cast_fireball():
	if dying or is_attacking:
		return  # Don't cast if dead

	# Prevent movement during attack
	is_attacking = true
	velocity = Vector2.ZERO  
	
	# Determine direction towards the mouse
	var mouse_position = get_global_mouse_position()
	var attack_direction = (mouse_position - global_position).normalized()

	# Play the correct animation
	var animation_name = _get_special_attack_animation(attack_direction)
	sprite.play(animation_name)

	# Wait for 3 frames before spawning fireball
	await get_tree().create_timer(0.3).timeout

	# Spawn fireball after animation delay
	var fireball = fireball_scene.instantiate()
	
	# Fireball offset
	var fireball_offset = attack_direction * 8
	
	fireball.global_position = global_position + fireball_offset # Spawn at player’s position
	fireball.direction = attack_direction  # Set direction
	get_parent().add_child(fireball)
	
	# Wait for the full animation to complete before allowwing movement
	await sprite.animation_finished

	# Reset attack state after fireball is spawned
	is_attacking = false




func _play_attack_animation(attack_direction: Vector2) -> void:
	if attack_direction.y < 0:
		if attack_direction.x < 0:
			sprite.play("attack_up_left")
		else:
			sprite.play("attack_up_right")
	else:
		if attack_direction.x < 0:
			sprite.play("attack_down_left")
		else:
			sprite.play("attack_down_right")
			

func _get_special_attack_animation(attack_direction: Vector2) -> String:
	if attack_direction.y < 0:
		return "attack_special_up_left" if attack_direction.x < 0 else "attack_special_up_right"
	else:
		return "attack_special_down_left" if attack_direction.x < 0 else "attack_special_down_right"




func _play_idle_animation() -> void:
	if is_attacking:
		return
	
	if dying:
		return
	if first_move == false:
		return
		
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
			
func drown() -> void:
	if dying:
		return
	is_dashing = false
	dying = true
	sprite.play("drown")
	
	await get_tree().create_timer(1.8).timeout
	$"../AudioStreamPlayer2D".play()

	var player_scene = load("res://scenes/player.tscn")
	var player_instance = player_scene.instantiate()
	
	#respawn at SpawnPoint
	var spawn_point = $"../Island1/SpawnPoint"
	player_instance.global_position = spawn_point.global_position
	get_parent().add_child(player_instance)
		
	queue_free() #free current player mem and rem
	
# temp for pond signals
func enter_pond() -> void:
	pass
func leave_pond() -> void:
	pass
	
