extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D  # Reference to the sprite
@onready var heart_container = get_node("/root/Game/UI/HeartContainer")

# @onready var Map = get_parent().get_node("Island1/TileMap")


@export var knockback_strength: float = 1000.0
@export var hit_recovery_time: float = 1.0  # Time to recover speed
@export var invincibility_time: float = 1.0  # Time to be invincible

var is_pushing = false
var pushable_object: RigidBody2D = null  # Store the box reference

var knockback_velocity := Vector2.ZERO
const KNOCKBACK_DECAY := 2000.0  # Higher = faster slide stop

var SPEED = 35.0
var DASH_SPEED = 200.0
const DASH_TIME = 0.2  # Duration of the dash
const RECOVERY_TIME = 1.0  # Time to recover from 20% speed to full speed
const MIN_SPEED_FACTOR = 0.2  # 20% of normal speed
const MAX_VELOCITY := 200.0  # Tune this to feel right

# Health
var health = 6 # number of hits (3 full hearts (2 hits each) )
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
var attack_dash_timer := 0.0
var attack_velocity := Vector2.ZERO
const ATTACK_DASH_DURATION := 0.15
const ATTACK_DASH_SPEED := 100.0

# Attack combo variables
var combo_step = 0
var combo_timer = 0.0
const COMBO_MAX_DELAY = 0.5  # 0.5 seconds window to input next attack

var my_id
var root

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

func _enter_tree():
	set_multiplayer_authority(int(str(name)))
	my_id = int(str(name))
	root = get_tree().get_current_scene() 
	
func _ready() -> void:
	if is_multiplayer_authority():
		print("isauth")
		$Camera2D.make_current()
	


func reset():
	health = 6
	if is_instance_valid(heart_container):
		heart_container.update_hearts(health)


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
	if not is_multiplayer_authority():
		return
		
	# === 1. Decay knockback naturally
	var resistance_dir := get_input_direction()
	if resistance_dir != Vector2.ZERO and knockback_velocity.length() > 0:
		var opposing_strength: float = resistance_dir.normalized().dot(-knockback_velocity.normalized())
		if opposing_strength > 0.1:
			# Reduce knockback more if walking against it
			knockback_velocity -= knockback_velocity.normalized() * opposing_strength * 500.0 * delta
	
	# Faster at start, slower at end (tunable factor)
	var knockback_drag := 20.0  # Higher = faster decay at start, lower = more slide
	knockback_velocity *= pow(0.5, knockback_drag * delta)


	# === 2. Handle base movement
	var input_dir := get_input_direction()
	var base_velocity: Vector2 = Vector2.ZERO

	if is_attacking and attack_dash_timer > 0:
		attack_dash_timer -= delta
		base_velocity += attack_velocity.lerp(Vector2.ZERO, 1.0 - (attack_dash_timer / ATTACK_DASH_DURATION))
	elif is_dashing:
		base_velocity += dash_direction * DASH_SPEED
	else:
		base_velocity += input_dir * current_speed


	
	# === 3. Combine everything into final velocity
	velocity = base_velocity + knockback_velocity

	# Clamp if needed
	if velocity.length() > MAX_VELOCITY:
		velocity = velocity.normalized() * MAX_VELOCITY

	# === 4. Apply movement
	custom_move_and_slide(delta)

	# === 5. Handle animations and state timers
	if attack_cooldown > 0:
		attack_cooldown -= delta

	if hit_recovery:
		hit_recovery_timer -= delta
		var recovery_factor = 1.0 - (hit_recovery_timer / hit_recovery_time)
		SPEED = lerp(original_speed * 0.5, original_speed, clamp(recovery_factor, 0.0, 1.0))
		if hit_recovery_timer <= 0:
			hit_recovery = false
			SPEED = original_speed

	if not is_attacking:
		handle_movement(delta)

	if Input.is_action_just_pressed("attack") and not is_dashing and attack_cooldown <= 0:
		start_attack()

	if Input.is_action_just_pressed("fireball") and not is_dashing:
		cast_fireball()
		
	# Handle combo timeout
	if combo_step > 0 and not is_attacking:
		combo_timer -= delta
		if combo_timer <= 0.0:
			print("Combo timeout. Resetting combo.")
			combo_step = 0


	update_cursor_pointer()




func handle_movement(delta: float) -> void:
	_update_facing_direction()
	var direction := get_input_direction()
	var movement_velocity = direction * current_speed

	# Check for collisions BEFORE moving the player
	var collision = move_and_collide(movement_velocity * delta)

	if collision:
		var collider = collision.get_collider()
		if collider is RigidBody2D and collider.is_in_group("pushable"):
			pushable_object = collider
			pushable_object.apply_central_force(direction * 1500)
		else:
			pushable_object = null

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if sprite.animation != "roll":
			sprite.play("roll")

		is_invincible = true
		set_collision_layer_value(1, false)
		set_collision_layer_value(8, true)
		set_collision_mask_value(1, true)
		set_collision_mask_value(2, false)

		if dash_timer <= 0:
			is_dashing = false
			recovering = true
			recovery_timer = RECOVERY_TIME
			current_speed = SPEED * MIN_SPEED_FACTOR
			is_invincible = false
			set_collision_layer_value(1, true)
			set_collision_layer_value(8, false)
			set_collision_mask_value(2, true)

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
			velocity = direction * current_speed
			_play_walk_animation(direction)

			if Input.is_action_just_pressed("dash"):
				is_dashing = true
				dash_timer = DASH_TIME
				dash_direction = direction
				velocity = dash_direction * DASH_SPEED
		else:
			if velocity.length() > 0:
				velocity = velocity.lerp(Vector2.ZERO, 5 * delta)
				_play_idle_animation()
				if velocity.length() < 1:
					velocity = Vector2.ZERO
			else:
				_play_idle_animation()



func _play_walk_animation(_direction: Vector2) -> void:
	var mouse_direction = (get_global_mouse_position() - global_position).normalized()

	if mouse_direction.y < 0:
		if mouse_direction.x < 0:
			sprite.play("walk_up_left")
		else:
			sprite.play("walk_up_right")
	else:
		if mouse_direction.x < 0:
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
	
# 1) Declare the RPC to run on every peer
@rpc("call_local", "any_peer", "reliable")
func spawn_slash(origin: Vector2, direction: Vector2, combo_step: int) -> void:
	var slash = slash_scene.instantiate()
	slash.global_position = origin + (direction * 10) + Vector2(0, -4)
	slash.rotation = direction.angle() - PI / 4
	slash.direction = direction
	
	# decide whether to swap
	var should_swap = false
	if (direction.x < 0 and direction.y > 0) or (direction.x > 0 and direction.y < 0):
		should_swap = true

	# pick animation & scale based on combo_step
	var slash_anim = ""
	if combo_step == 0:
		slash_anim = "slash_effect2" if should_swap else "slash_effect"
	elif combo_step == 1:
		slash_anim = "slash_effect"  if should_swap else "slash_effect2"
	elif combo_step == 2:
		slash_anim = "slash_effect2" if should_swap else "slash_effect"
		slash.scale = Vector2(1.4, 1.4)

	slash.animation_name = slash_anim
	get_parent().add_child(slash)


func start_attack() -> void:
	_update_facing_direction()
	if dying or is_attacking:
		return

	is_attacking = true
	velocity = Vector2.ZERO
	attack_cooldown = ATTACK_COOLDOWN_DURATION

	var mouse_pos = get_global_mouse_position()
	var attack_dir = (mouse_pos - global_position).normalized()
	attack_velocity = attack_dir * ATTACK_DASH_SPEED
	attack_dash_timer = ATTACK_DASH_DURATION

	# figure out combo suffix
	var anim_suffix = ""
	if combo_step == 1:
		anim_suffix = "2"
	elif combo_step == 2:
		anim_suffix = "3"

	# play your local animation
	_play_attack_animation(attack_dir, anim_suffix)
	await get_tree().create_timer(0.2).timeout

	# broadcast to all peers
	rpc("spawn_slash", global_position, attack_dir, combo_step)

	await sprite.animation_finished
	is_attacking = false

	# advance/reset combo
	if combo_step < 2:
		combo_step += 1
		combo_timer = COMBO_MAX_DELAY
	else:
		combo_step = 0



	
func cast_fireball():
	if dying or is_attacking:
		return

	is_attacking = true
	velocity = Vector2.ZERO
	_update_facing_direction()

	var attack_direction = (get_global_mouse_position() - global_position).normalized()
	sprite.play(_get_special_attack_animation(attack_direction))

	# Tell everyone (including self) to spawn a fireball
	rpc("spawn_fireball", global_position, attack_direction)

	await get_tree().create_timer(0.3).timeout
	is_attacking = false

@rpc("call_local", "reliable")
func spawn_fireball(origin: Vector2, direction: Vector2) -> void:
	var fireball = fireball_scene.instantiate()
	fireball.global_position = origin + direction * 8
	fireball.direction = direction
	get_parent().add_child(fireball)


func _play_attack_animation(attack_direction: Vector2, suffix := "") -> void:
	var anim = ""

	if attack_direction.y < 0:
		anim = "attack_up_left" if attack_direction.x < 0 else "attack_up_right"
	else:
		anim = "attack_down_left" if attack_direction.x < 0 else "attack_down_right"

	sprite.play(anim + suffix)


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
	player_instance.health = 6  # Full hearts
	player_instance.heart_container.update_hearts(6)  # Update heart UI
	#respawn at SpawnPoint
	var spawn_point = $"../Island1/SpawnPoint"
	player_instance.global_position = spawn_point.global_position
	get_parent().add_child(player_instance)
	player_instance.call_deferred("reset")

		
	queue_free() #free current player mem and rem
	
	


func _on_collisiondetector_drown() -> void:
	drown()
	

func take_damage(source_position):
	if is_invincible:
		return

	health -= 1
	heart_container.update_hearts(health)


	# Calculate knockback direction
	var knockback_direction = (global_position - source_position).normalized()
	knockback_velocity = knockback_direction * knockback_strength


	SPEED *= 0.5
	hit_recovery = true
	hit_recovery_timer = hit_recovery_time

	# Invincibility timer
	is_invincible = true
	# Disable enemy detection
	set_collision_mask_value(2, false)


	# Optional: Flash effect during invincibility
	_start_invincibility_effect()

	# If the player dies, call die()
	if health <= 0:
		die()

	move_and_slide()  # Apply knockback movement

	# Restore collisions and invincibility after timeout
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	# Re-enable enemy detection
	set_collision_mask_value(2, true)
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
	player_instance.call_deferred("reset")


	# Remove the current (dead) player instance
	queue_free()
	
func _start_invincibility_effect():
	var blink_tween = get_tree().create_tween()
	blink_tween.set_loops(invincibility_time / (blink_timer * 2))
	blink_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.2, blink_timer)
	blink_tween.tween_property($AnimatedSprite2D, "modulate:a", 1.0, blink_timer)

func _stop_invincibility_effect():
	$AnimatedSprite2D.modulate.a = 1.0  # Reset transparency
	
	
func _update_facing_direction():
	var mouse_direction = (get_global_mouse_position() - global_position).normalized()
	
	last_direction = "right" if mouse_direction.x > 0 else "left"
	last_vertical_direction = "down" if mouse_direction.y > 0 else "up"
	
func update_cursor_pointer() -> void:
	var cursor = get_global_mouse_position()
	var to_cursor = (cursor - global_position).angle()
	$CursorPointer.rotation = to_cursor - PI / 4  # or to_cursor - deg2rad(90))

func heal(amount: int):
	health = min(health + amount, 6)  # Don't allow more than 6 health
	if is_instance_valid(heart_container):
		heart_container.update_hearts(health)
