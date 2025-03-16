## Player.gd
class_name Player
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

@export var knockback_strength: float = 1000.0
@export var hit_recovery_time: float = 1.0
@export var invincibility_time: float = 1.0

var SPEED: float = 75.0
var DASH_SPEED: float = 200.0
const DASH_TIME: float = 0.2
const RECOVERY_TIME: float = 1.0
const MIN_SPEED_FACTOR: float = 0.2

var health: int = 3
var is_invincible: bool = false
var hit_recovery: bool = false
var hit_recovery_timer: float = 0.0
var original_speed: float = SPEED
var blink_timer: float = 0.1

# Attack variables
var slash_scene = preload("res://scenes/slash_effect.tscn")
var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown: float = 0.0
const ATTACK_DURATION: float = 0.3
const ATTACK_COOLDOWN_DURATION: float = 0.5

var dash_timer: float = 0.0
var is_dashing: bool = false
var recovering: bool = false
var recovery_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var current_speed: float = SPEED
var last_direction: String = "right"
var last_vertical_direction: String = "down"

var first_move: bool = false
var dying: bool = false
var current_floor: int = 1

# Fireball
var fireball_scene = preload("res://scenes/fireball.tscn")

func _enter_tree() -> void:
	# Each player node sets its authority to its unique ID (from name)
	set_multiplayer_authority(int(str(name)))

func _ready() -> void:
	# Locally controlled player sets its camera to current
	if is_multiplayer_authority():
		camera.make_current()

func _physics_process(delta: float) -> void:
	# Only the authoritative player processes movement
	if not is_multiplayer_authority():
		return

	# Prevent movement updates if attacking
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Handle gradual speed recovery
	if hit_recovery:
		hit_recovery_timer -= delta
		var factor = 1.0 - (hit_recovery_timer / hit_recovery_time)
		SPEED = lerp(original_speed * 0.5, original_speed, clamp(factor, 0.0, 1.0))

		if recovery_timer <= 0:
			recovering = false
			SPEED = original_speed

	# Attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Movement, dashing, and input
	handle_movement(delta)

	# Check for attacks
	if Input.is_action_just_pressed("attack") and not is_dashing and attack_cooldown <= 0:
		var mouse_pos = get_global_mouse_position()
		var attack_dir = (mouse_pos - global_position).normalized()
		rpc("start_attack", attack_dir)

	if Input.is_action_just_pressed("fireball") and not is_dashing:
		var mouse_pos_2 = get_global_mouse_position()
		var attack_dir_2 = (mouse_pos_2 - global_position).normalized()
		rpc("cast_fireball", attack_dir_2)

	custom_move_and_slide(delta)

func handle_movement(delta: float) -> void:
	var direction = Vector2.ZERO

	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if sprite.animation != "roll":
			sprite.play("roll")

		# Invincible during dash
		is_invincible = true
		$CollisionShape2D.set_deferred("disabled", true)

		if dash_timer <= 0:
			is_dashing = false
			recovering = true
			recovery_timer = RECOVERY_TIME
			current_speed = SPEED * MIN_SPEED_FACTOR
			is_invincible = false
			$CollisionShape2D.set_deferred("disabled", false)

	elif recovering:
		direction = get_input_direction()
		recovery_timer -= delta
		var factor = 1.0 - (recovery_timer / RECOVERY_TIME)
		current_speed = lerp(SPEED * MIN_SPEED_FACTOR, SPEED, factor)

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

func custom_move_and_slide(delta: float) -> void:
	# Example custom collision logic, similar to your code
	var displacement = velocity * delta
	var max_collisions = 4
	var collision_count = 0

	while collision_count < max_collisions and displacement.length() > 0.01:
		var collision = move_and_collide(displacement)
		if collision:
			var ignore_collision = process_tile_collision(collision)
			if ignore_collision:
				collision_count += 1
				continue
			else:
				if displacement.dot(collision.get_normal()) < 0:
					displacement = displacement.slide(collision.get_normal())
				else:
					break
			collision_count += 1
		else:
			break

func process_tile_collision(collision: KinematicCollision2D) -> bool:
	# Example: ignoring collisions with water
	if collision.get_collider() is TileMapLayer:
		var tilemap = collision.get_collider() as TileMapLayer
		var tile_coords = tilemap.local_to_map(collision.get_position())
		var cell_data = tilemap.get_cell_tile_data(tile_coords)
		if cell_data:
			if cell_data.get_custom_data("is_water"):
				return true
	return false

func get_input_direction() -> Vector2:
	if dying:
		return Vector2.ZERO

	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
		last_direction = "left"
	if Input.is_action_pressed("move_right"):
		dir.x += 1
		last_direction = "right"
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
		last_vertical_direction = "up"
	if Input.is_action_pressed("move_down"):
		dir.y += 1
		last_vertical_direction = "down"

	if not first_move and dir != Vector2.ZERO:
		# Stop sleep particles across network
		rpc("stop_sleep_particles")
		first_move = true

	return dir.normalized()

@rpc("call_local")
func stop_sleep_particles() -> void:
	if $Sleep_particles:
		$Sleep_particles.queue_free()

@rpc("call_local")
func start_attack(attack_direction: Vector2) -> void:
	if dying or is_attacking:
		return
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity = Vector2.ZERO
	attack_cooldown = ATTACK_COOLDOWN_DURATION

	_play_attack_animation(attack_direction)

	await get_tree().create_timer(0.2).timeout

	var slash = slash_scene.instantiate()
	slash.global_position = global_position + (attack_direction * 10)
	slash.rotation = attack_direction.angle()
	get_parent().add_child(slash)

	await sprite.animation_finished
	is_attacking = false

@rpc("call_local")
func cast_fireball(attack_direction: Vector2) -> void:
	if dying or is_attacking:
		return

	is_attacking = true
	velocity = Vector2.ZERO

	var anim_name = _get_special_attack_animation(attack_direction)
	sprite.play(anim_name)

	await get_tree().create_timer(0.3).timeout

	var fireball = fireball_scene.instantiate()
	var offset = attack_direction * 8
	fireball.global_position = global_position + offset
	fireball.direction = attack_direction
	get_parent().add_child(fireball)

	await sprite.animation_finished
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
	if is_attacking or dying or not first_move:
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

	var spawn_point = $"../Island1/SpawnPoint"
	player_instance.global_position = spawn_point.global_position
	get_parent().add_child(player_instance)

	queue_free()

func _on_collisiondetector_drown() -> void:
	drown()

@rpc("call_local")
func take_damage(source_position: Vector2) -> void:
	if is_invincible or dying:
		return

	health -= 1
	# Calculate knockback direction
	var knockback_direction = (global_position - source_position).normalized()
	velocity = knockback_direction * knockback_strength

	# If you have a hurt animation, you can play it here
	SPEED *= 0.5
	hit_recovery = true
	hit_recovery_timer = hit_recovery_time

	is_invincible = true
	$CollisionShape2D.set_deferred("disabled", true)

	_start_invincibility_effect()

	if health <= 0:
		die()

	move_and_slide()

	# Restore collisions and invincibility after a timeout
	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	$CollisionShape2D.set_deferred("disabled", false)
	_stop_invincibility_effect()

func die() -> void:
	if dying:
		return
	dying = true
	is_dashing = false
	is_attacking = false
	velocity = Vector2.ZERO

	if last_direction == "left":
		sprite.play("death_left")
	else:
		sprite.play("death_right")

	await sprite.animation_finished

	$"../AudioStreamPlayer2D".play()

	var player_scene = load("res://scenes/player.tscn")
	var player_instance = player_scene.instantiate()

	var spawn_point = $"../Island1/SpawnPoint"
	player_instance.global_position = spawn_point.global_position
	get_parent().add_child(player_instance)

	queue_free()

func _start_invincibility_effect():
	var blink_tween = get_tree().create_tween()
	blink_tween.set_loops(invincibility_time / (blink_timer * 2))
	blink_tween.tween_property(sprite, "modulate:a", 0.2, blink_timer)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, blink_timer)

func _stop_invincibility_effect():
	sprite.modulate.a = 1.0
