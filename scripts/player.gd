extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D  # Reference to the sprite
# @onready var Map = get_parent().get_node("Island1/TileMap")

@export var knockback_strength: float = 1000.0
@export var hit_recovery_time: float = 1.0  # Time to recover speed
@export var invincibility_time: float = 1.0  # Time to be invincible

var is_pushing = false
var pushable_object: RigidBody2D = null  # Store the box reference


var SPEED = 35.0
var DASH_SPEED = 200.0
const DASH_TIME = 0.2  # Duration of the dash
const RECOVERY_TIME = 1.0  # Time to recover from 20% speed to full speed
const MIN_SPEED_FACTOR = 0.2  # 20% of normal speed

# Health
var health = 3 # number of hits
var is_invincible = false
var hit_recovery = false
var hit_recovery_timer = 0.0
var original_speed = SPEED
var blink_timer = 0.1  # Time between each blink (adjust as needed)

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

func process_tile_collision(collision: KinematicCollision2D) -> bool:
	if collision.get_collider() is TileMapLayer:
		var tilemap = collision.get_collider() as TileMapLayer
		# Convert the collision point to tile coordinates.
		var tile_coords = tilemap.local_to_map(collision.get_position())
		# Get the cell’s tile data (which holds custom data)
		var cell_data = tilemap.get_cell_tile_data(tile_coords)
		if cell_data:
			# Retrieve the custom data; adjust the key name as needed.
			var is_water = cell_data.get_custom_data("is_water")
			if is_water:
				
				print("Water tile collision detected; ignoring collision.")
				return true  # Tell the caller to ignore this collision.
	return false

func custom_move_and_slide(delta: float) -> void:
	var displacement = velocity * delta
	var max_collisions = 4
	var collision_count = 0

	while collision_count < max_collisions and displacement.length() > 0.01:
		var collision = move_and_collide(displacement)
		if collision:
			# 1) Ask if we should ignore this collision
			var ignore_collision = process_tile_collision(collision)
			
			if ignore_collision:
				# Simply ignore the collision: we do not slide, nor do we add the collision normal.
				# But we increment collision_count so we don’t get stuck repeating this infinitely.
				collision_count += 1
				continue

			else:
				# Normal collision and slide
				if displacement.dot(collision.get_normal()) < 0:
					displacement = displacement.slide(collision.get_normal())
				else:
					# Not moving into the surface anymore
					break
			collision_count += 1
		else:
			# No collision => we can safely exit
			break



func _physics_process(delta: float) -> void:
	# Prevent movement updates if attacking (so animations don't get overridden)
	if is_attacking:
		velocity = Vector2.ZERO  # Stop movement while attacking
		move_and_slide()
		return
	
	if hit_recovery:
		hit_recovery_timer -= delta
		var recovery_factor = 1.0 - (hit_recovery_timer / hit_recovery_time)
		SPEED = lerp(original_speed * 0.5, original_speed, clamp(recovery_factor, 0.0, 1.0))
		
		if recovery_timer <= 0:
			recovering = false
			SPEED = original_speed  # Fully restore speed

	# Normal movement handling
	if attack_cooldown > 0:
		attack_cooldown -= delta

	handle_movement(delta)

	# Prevent attacking while dashing, but allow it in recovery
	if Input.is_action_just_pressed("attack") and not is_dashing and attack_cooldown <= 0:
		start_attack()
		
	if Input.is_action_just_pressed("fireball") and not is_dashing:
		cast_fireball()

	# move_and_slide()
	custom_move_and_slide(delta)
	




func handle_movement(delta: float) -> void:
	var direction := get_input_direction()  # Get player input direction
	var movement_velocity = direction * current_speed  # Normal movement speed

	# Check for collisions BEFORE moving the player
	var collision = move_and_collide(movement_velocity * delta)

	if collision:
		var collider = collision.get_collider()

		# If colliding with a pushable RigidBody2D, apply force to it
		if collider is RigidBody2D and collider.is_in_group("pushable"):
			pushable_object = collider

			# Apply force to the box WITHOUT changing player speed
			pushable_object.apply_central_force(direction * 1500)  # Adjust force

			# Do NOT modify movement_velocity at all
		else:
			pushable_object = null  # No pushable object in contact

	# Move the player normally, without modifying their velocity
	velocity = movement_velocity

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if sprite.animation != "roll":
			sprite.play("roll")

		# 🔥 Make player invincible during dash
		is_invincible = true
		# Change player to a temporary layer (so enemies don't detect it)
		set_collision_layer_value(1, false)  # Remove from default player layer
		set_collision_layer_value(4, true)   # Assign to a new "dashing" layer

		# Keep colliding with terrain (since terrain has layer 1 and 2)
		set_collision_mask_value(1, true)  # Still collide with terrain
		set_collision_mask_value(2, false) # Ignore enemies
		set_collision_mask_value(3, false) # Ignore enemies


		if dash_timer <= 0:
			is_dashing = false
			recovering = true
			recovery_timer = RECOVERY_TIME
			current_speed = SPEED * MIN_SPEED_FACTOR

			# 🔥 Remove invincibility after dash ends
			is_invincible = false
			# Restore collision with terrain & enemies
			# Move player back to its original layer
			set_collision_layer_value(1, true)  # Restore default player layer
			set_collision_layer_value(4, false) # Remove dashing layer

			# Restore interaction with enemies
			set_collision_mask_value(2, true)  # Detect enemies again
			set_collision_mask_value(3, true)  # Detect enemies again


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
	fireball.source = self  # Set the player as the source of the fireball
	get_parent().add_child(fireball)
	
	# Wait for the full animation to complete before allowing movement
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
	
	


func _on_collisiondetector_drown() -> void:
	drown()
	

func take_damage(source_position):
	if is_invincible:
		return
		
	health -= 1

	# Calculate knockback direction
	var knockback_direction = (global_position - source_position).normalized()
	velocity = knockback_direction * knockback_strength  # Adjust knockback strength as needed

	# Play hurt animation if you have one
	#if sprite.has_animation("hurt"):
		#sprite.play("hurt")
		
	SPEED *= 0.5
	hit_recovery = true
	hit_recovery_timer = hit_recovery_time
	
	# Invincibility timer
	is_invincible = true
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Optional: Flash effect during invincibility
	_start_invincibility_effect()

	# If the player dies, call die()
	if health <= 0:
		die()
	
	move_and_slide()  # Apply knockback movement
	
	# Restore collisions and invincibility after timeout
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	$CollisionShape2D.set_deferred("disabled", false)  # Re-enable collisions
	_stop_invincibility_effect()

		
func die():
	if dying:
		return  # Prevent multiple deaths
	dying = true  # Mark player as dead
	is_dashing = false
	is_attacking = false
	velocity = Vector2.ZERO  # Stop movement

	# Play the correct death animation
	if last_direction == "left":
		sprite.play("death_left")
	else:
		sprite.play("death_right")

	# Wait for the death animation to finish
	await sprite.animation_finished  

	# Play death sound effect (optional)
	$"../AudioStreamPlayer2D".play()

	# Respawn player at SpawnPoint
	var player_scene = load("res://scenes/player.tscn")
	var player_instance = player_scene.instantiate()
	
	var spawn_point = $"../Island1/SpawnPoint"
	player_instance.global_position = spawn_point.global_position
	get_parent().add_child(player_instance)

	# Remove the current (dead) player instance
	queue_free()
	
func _start_invincibility_effect():
	var blink_tween = get_tree().create_tween()
	blink_tween.set_loops(invincibility_time / (blink_timer * 2))
	blink_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.2, blink_timer)
	blink_tween.tween_property($AnimatedSprite2D, "modulate:a", 1.0, blink_timer)

func _stop_invincibility_effect():
	$AnimatedSprite2D.modulate.a = 1.0  # Reset transparency
	
