extends CharacterBody2D

@export var speed: float = 25.0
@export var follow_range: float = 30.0  # Distance at which the enemy starts following the player
@export var invincibility_time: float = 0.3

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var attack_area = $AttackArea  # Reference to Area2D
@onready var sprite = $AnimatedSprite2D

@export var attack_cooldown: float = 1.5
@export var projectile_scene: PackedScene = preload("res://scenes/mage_projectile.tscn")
@export var attack_range: float = 50.0  # Max range to shoot

@export var wander_radius: float = 40.0
@export var wander_speed: float = 15.0
@export var wander_idle_min: float = 1.0
@export var wander_idle_max: float = 3.0
@export var wander_move_duration: float = 1.5

@export var reposition_radius: float = 30.0
@export var reposition_min_delay: float = 1.0
@export var reposition_max_delay: float = 2.5

var wander_target_position: Vector2

var knockback_velocity := Vector2.ZERO
const KNOCKBACK_DECAY := 2000.0  # Similar to player

var reposition_timer: float = 0.0
var combat_moving = false
var combat_target_position: Vector2

var spawn_position: Vector2
var is_wandering = false
var wandering_timer = 0.0
var wandering_direction = Vector2.ZERO
var is_idle_wandering = false

var can_attack = true
var is_attacking = false

var health = 3
var dying = false
var is_invincible = false
var blink_timer = 0.05

var last_direction = "right"  # Track last horizontal movement direction
var last_vertical_direction = "down"  # Track last vertical movement direction

func _ready():
	spawn_position = global_position
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	start_idle_wandering()  # Begin wandering logic on spawn

func _physics_process(delta):
	if dying:
		return
	
	# Knockback decay
	if knockback_velocity.length() > 0:
		var knockback_drag := 50.0  # Same as player
		knockback_velocity *= pow(0.5, knockback_drag * delta)

	if player:
		var distance_to_player = global_position.distance_to(player.global_position)

		if is_attacking:
			handle_combat_attack(delta)  # Let the attack finish
		elif distance_to_player <= attack_range:
			handle_combat_attack(delta)
		elif distance_to_player <= follow_range:
			handle_combat_chase(delta)
		else:
			handle_wandering(delta)






func handle_combat_attack(delta: float) -> void:
	# Stop wandering if entering combat
	is_wandering = false
	is_idle_wandering = false
	# Let attacks always finish even if player walks out of range
	if is_attacking:
		velocity = Vector2.ZERO
		velocity += knockback_velocity
		move_and_slide()
		return

	# If we're not repositioning, start a reposition when cooldown allows
	if not combat_moving and not can_attack:
		reposition_timer -= delta
		if reposition_timer <= 0:
			pick_combat_reposition()

	# Repositioning logic
	if combat_moving:
		var move_vector = combat_target_position - global_position
		if move_vector.length() < 1.0:
			# Close enough to destination
			velocity = Vector2.ZERO
			velocity += knockback_velocity
			combat_moving = false
		else:
			velocity = move_vector.normalized() * speed
			velocity += knockback_velocity

		move_and_slide()

		# Animation based on movement
		if velocity.length() > 0:
			_play_walk_animation(velocity)
		else:
			face_player()
			_play_idle_animation()
	else:
		# Standing still but ready to attack
		velocity = Vector2.ZERO
		velocity += knockback_velocity
		move_and_slide()
		face_player()
		_play_idle_animation()

		if can_attack:
			attack()

func handle_combat_chase(delta: float) -> void:
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	velocity += knockback_velocity
	move_and_slide()
	_play_walk_animation(direction)

func pick_combat_reposition():
	combat_target_position = global_position + Vector2(randf_range(-reposition_radius, reposition_radius), randf_range(-reposition_radius, reposition_radius))
	combat_moving = true
	reposition_timer = randf_range(reposition_min_delay, reposition_max_delay)
	
func attack():
	print("🔥 ATTACK STARTED")
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	move_and_slide()

	var dir = (player.global_position - global_position).normalized()
	_play_attack_animation(dir)

	# Face player during attack
	face_player()
	
	print("▶️ Playing animation:", sprite.animation)

	# Wait for animation to finish
	await sprite.animation_finished
	print("🎯 Animation done, firing projectile")

	# Dont shoot if dead
	if dying:
		return
		
	# Fire projectile
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.direction = dir
	projectile.source = self

	is_attacking = false  # Now free to reposition again

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func face_player():
	var dir = (player.global_position - global_position).normalized()

	# Just update last known direction — don't play animations here
	if dir.y < 0:
		last_vertical_direction = "up"
	elif dir.y > 0:
		last_vertical_direction = "down"

	if dir.x < 0:
		last_direction = "left"
	elif dir.x > 0:
		last_direction = "right"


func _play_idle_animation_from_direction(direction: Vector2):
	if direction.y < 0:
		last_vertical_direction = "up"
	elif direction.y > 0:
		last_vertical_direction = "down"

	if direction.x < 0:
		last_direction = "left"
	elif direction.x > 0:
		last_direction = "right"

	_play_idle_animation()


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(global_position)  # Call damage function on player

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
			
func _play_attack_animation(direction: Vector2):
	if direction.y < 0:
		last_vertical_direction = "up"
		if last_direction == "left":
			sprite.play("attack_up_left")
		else:
			sprite.play("attack_up_right")
	elif direction.y > 0:
		last_vertical_direction = "down"
		if last_direction == "left":
			sprite.play("attack_down_left")
		else:
			sprite.play("attack_down_right")
	else:
		if last_vertical_direction == "up":
			if last_direction == "left":
				sprite.play("attack_up_left")
			else:
				sprite.play("attack_up_right")
		else:
			if last_direction == "left":
				sprite.play("attack_down_left")
			else:
				sprite.play("attack_down_right")

	if direction.x < 0:
		last_direction = "left"
	elif direction.x > 0:
		last_direction = "right"

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
	knockback_velocity = force

	
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
	if last_direction == "left":
		return "death_left"
	else:
		return "death_right"
		
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
	
func handle_wandering(delta: float) -> void:
	if dying:
		return

	if not is_wandering and not is_idle_wandering:
		if randf() < 0.5:
			start_idle_wandering()
		else:
			start_move_wandering()

	# Wandering by moving
	elif is_wandering:
		wandering_timer -= delta
		var move_vector = (wander_target_position - global_position)
		if move_vector.length() < 2.0:
			velocity = Vector2.ZERO
		else:
			velocity = move_vector.normalized() * wander_speed
			velocity += knockback_velocity
		move_and_slide()
		_play_walk_animation(velocity)

		if wandering_timer <= 0:
			is_wandering = false

	# Wandering by idling
	elif is_idle_wandering:
		wandering_timer -= delta
		velocity = Vector2.ZERO
		velocity += knockback_velocity
		move_and_slide()
		_play_idle_animation()

		if wandering_timer <= 0:
			is_idle_wandering = false

func start_move_wandering():
	is_wandering = true
	wandering_timer = wander_move_duration

	var angle = randf() * TAU
	wandering_direction = Vector2(cos(angle), sin(angle))
	wander_target_position = spawn_position + wandering_direction * wander_radius


func start_idle_wandering():
	is_idle_wandering = true
	wandering_timer = randf_range(wander_idle_min, wander_idle_max)
