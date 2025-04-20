extends CharacterBody2D

@export var speed: float = 25.0
@export var follow_range: float = 100.0  # Distance at which the skeleton starts following the player
@export var invincibility_time: float = 0.3

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var attack_area = $AttackArea  # Reference to Area2D
@onready var sprite = $AnimatedSprite2D

@export var wander_radius: float = 40.0
@export var wander_speed: float = 15.0
@export var wander_idle_min: float = 1.0
@export var wander_idle_max: float = 3.0
@export var wander_move_duration: float = 1.5
@export var wander_cooldown_min: float = 1.0
@export var wander_cooldown_max: float = 2.0
var wander_cooldown_timer: float = 0.0

enum CombatMode { STALK, CHARGE }
var combat_mode: CombatMode = CombatMode.STALK
var mode_timer: float = 0.0
var circling_direction := 1  # 1 = clockwise, -1 = counter-clockwise

@export var stalk_speed: float = 20.0
@export var charge_speed: float = 50.0
@export var charge_duration: float = 0.8
@export var combat_swap_min: float = 2.0
@export var combat_swap_max: float = 4.0



var spawn_position: Vector2
var is_wandering = false
var wandering_timer = 0.0
var is_idle_wandering = false
var wandering_direction = Vector2.ZERO
var wander_target_position: Vector2

var health = 3
var dying = false
var is_invincible = false
var blink_timer = 0.05

var knockback_velocity := Vector2.ZERO
const KNOCKBACK_DECAY := 2000.0  # Tune to control how fast the knockback slows

var last_direction = "right"  # Track last horizontal movement direction
var last_vertical_direction = "down"  # Track last vertical movement direction

func _ready():
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	spawn_position = global_position
	start_idle_wandering()


func _physics_process(delta):
	if dying:
		return

	# Decay knockback velocity (exponential)
	knockback_velocity *= pow(0.5, 50.0 * delta)  # Fast decay at first, smooth slide

	# Follow player if not dying
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		var base_velocity = Vector2.ZERO

		if distance_to_player <= follow_range:
			# Swap modes if timer is done
			mode_timer -= delta
			if mode_timer <= 0:
				var next_mode = CombatMode.STALK if randi() % 2 == 0 else CombatMode.CHARGE
				if next_mode == CombatMode.STALK:
					# Flip circling direction randomly
					circling_direction = -1 if randi() % 2 == 0 else 1
					mode_timer = randf_range(combat_swap_min, combat_swap_max)
				else:
					mode_timer = charge_duration

				combat_mode = next_mode

			if combat_mode == CombatMode.STALK:
				# Direction to player
				var to_player = (player.global_position - global_position).normalized()

				# Perpendicular to the player direction (creates side-walking)
				var side_dir = to_player.orthogonal() * circling_direction
				
				# Bias slightly toward the player so we don't drift away
				var stalk_direction = (side_dir * 0.5 + to_player * 1.0).normalized()
				
				base_velocity = stalk_direction * stalk_speed
			else:
				var direction = (player.global_position - global_position).normalized()
				base_velocity = direction * charge_speed

			_play_walk_animation(base_velocity)



		velocity = base_velocity + knockback_velocity
		move_and_slide()



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
	
func handle_wandering(delta: float) -> void:
	if dying:
		return

	# Wait before starting new wander behavior
	if wander_cooldown_timer > 0.0:
		wander_cooldown_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_play_idle_animation()
		return

	if not is_wandering and not is_idle_wandering:
		if randf() < 0.5:
			start_idle_wandering()
		else:
			start_move_wandering()

	elif is_wandering:
		wandering_timer -= delta
		var move_vector = wander_target_position - global_position

		if move_vector.length() < 2.0:
			velocity = Vector2.ZERO
		else:
			velocity = move_vector.normalized() * wander_speed

		move_and_slide()
		_play_walk_animation(velocity)

		if wandering_timer <= 0.0:
			is_wandering = false
			wander_cooldown_timer = randf_range(wander_cooldown_min, wander_cooldown_max)

	elif is_idle_wandering:
		wandering_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_play_idle_animation()

		if wandering_timer <= 0.0:
			is_idle_wandering = false
			wander_cooldown_timer = randf_range(wander_cooldown_min, wander_cooldown_max)

func start_move_wandering():
	is_wandering = true
	wandering_timer = wander_move_duration

	var angle = randf() * TAU
	wandering_direction = Vector2(cos(angle), sin(angle))
	wander_target_position = spawn_position + wandering_direction * wander_radius

func start_idle_wandering():
	is_idle_wandering = true
	wandering_timer = randf_range(wander_idle_min, wander_idle_max)
