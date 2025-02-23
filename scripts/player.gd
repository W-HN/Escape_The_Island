extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D  # Reference to the sprite
@onready var Map = get_parent().get_node("Island1/TileMap")

var SPEED = 75.0
var DASH_SPEED = 200.0
const DASH_TIME = 0.2  # Duration of the dash
const RECOVERY_TIME = 1.0  # Time to recover from 20% speed to full speed
const MIN_SPEED_FACTOR = 0.2  # 20% of normal speed

# Attack variables
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

var dying = false
var current_floor = 1


func _physics_process(delta: float) -> void:
	#var elevation_map = $"../Island1/Map/Elevation"
	#var tile_pos = elevation_map.local_to_map(global_position)
	#var custom_data = elevation_map.get_cell_tile_data(tile_pos)
	#if custom_data:
		#var height = custom_data.get_custom_data("height")
		#print("Height:", height)
			
	# Update cooldown timers
	if attack_cooldown > 0:
		attack_cooldown -= delta

	if is_attacking:
		attack_timer -= delta
		velocity = Vector2.ZERO  # Prevent movement during attack
		if attack_timer <= 0:
			is_attacking = false
	else:
		handle_movement(delta)

	# Prevent attacking while dashing, but allow it in recovery
	if Input.is_action_just_pressed("attack") and not is_dashing and attack_cooldown <= 0:
		start_attack()

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

	return direction.normalized()

func start_attack() -> void:
	if dying:
		return
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity = Vector2.ZERO  # Stop movement while attacking
	attack_cooldown = ATTACK_COOLDOWN_DURATION  # Set cooldown

	# Determine attack direction based on mouse position
	var mouse_position = get_global_mouse_position()
	var attack_direction = (mouse_position - global_position).normalized()

	# Determine animation
	_play_attack_animation(attack_direction)



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


func _play_idle_animation() -> void:
	if dying:
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
	
