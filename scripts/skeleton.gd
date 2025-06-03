extends CharacterBody2D

@export var speed: float = 30.0
@export var follow_range: float = 100.0  
@export var invincibility_time: float = 0.3

@export var gold_pickup_scene: PackedScene
@export var heart_pickup_scene: PackedScene

@onready var attack_area = $AttackArea  
@onready var sprite = $AnimatedSprite2D

@export var wander_radius: float = 40.0
@export var wander_speed: float = 15.0
@export var wander_idle_min: float = 1.0
@export var wander_idle_max: float = 3.0
@export var wander_move_duration: float = 1.5
@export var wander_cooldown_min: float = 1.0
@export var wander_cooldown_max: float = 2.0
var wander_cooldown_timer: float = 0.0
var player: Node2D = null

enum CombatMode { STALK, CHARGE }
var combat_mode: CombatMode = CombatMode.STALK
var mode_timer: float = 0.0
var circling_direction := 1  

@export var stalk_speed: float = 30.0
@export var charge_speed: float = 60.0
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
const KNOCKBACK_DECAY := 2000.0  

var last_direction = "right"  
var last_vertical_direction = "down"

func _ready():
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	spawn_position = global_position
	start_idle_wandering()


func _physics_process(delta):
	
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")

	if dying:
		return

	# Decay knockback velocity
	knockback_velocity *= pow(0.5, 50.0 * delta)

	var base_velocity = Vector2.ZERO

	if is_instance_valid(player) and not dying:
		var distance_to_player = global_position.distance_to(player.global_position)

		if distance_to_player <= follow_range:
			# Combat mode swap logic
			mode_timer -= delta
			if mode_timer <= 0:
				var next_mode = CombatMode.STALK if randi() % 2 == 0 else CombatMode.CHARGE
				if next_mode == CombatMode.STALK:
					circling_direction = -1 if randi() % 2 == 0 else 1
					mode_timer = randf_range(combat_swap_min, combat_swap_max)
				else:
					mode_timer = charge_duration

				combat_mode = next_mode

			if combat_mode == CombatMode.STALK:
				var to_player = (player.global_position - global_position).normalized()
				var side_dir = to_player.orthogonal() * circling_direction
				var stalk_direction = (side_dir * 0.5 + to_player * 1.0).normalized()
				base_velocity = stalk_direction * stalk_speed
			else:
				var direction = (player.global_position - global_position).normalized()
				base_velocity = direction * charge_speed

			_play_walk_animation(base_velocity)
		else:
			handle_wandering(delta)
	else:
		handle_wandering(delta)

	if is_instance_valid(player):
		var min_distance = 8.0
		var to_player = player.global_position - global_position
		var distance = to_player.length()

		if distance < min_distance and distance > 0:
			var push_direction = -to_player.normalized()
			base_velocity += push_direction * (min_distance - distance) * 10.0


	velocity = base_velocity + knockback_velocity
	move_and_slide()



func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(global_position)  # call damage function on player


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
		return

	dying = true
	velocity = Vector2.ZERO
	
	
	if gold_pickup_scene:
		var num_gold = randi_range(1, 3)
		for i in num_gold:
			var gold_pickup = gold_pickup_scene.instantiate()
			gold_pickup.position = position
			var angle = randf_range(0, TAU)
			var speed = randf_range(20, 30)
			gold_pickup.velocity = Vector2.RIGHT.rotated(angle) * speed
			get_parent().call_deferred("add_child", gold_pickup)
	
	if heart_pickup_scene and randi_range(1, 5) == 1:
		var heart_pickup = heart_pickup_scene.instantiate()
		heart_pickup.position = position
		var angle = randf_range(0, TAU)
		var speed = randf_range(20, 30)
		heart_pickup.velocity = Vector2.RIGHT.rotated(angle) * speed
		heart_pickup.bounce_velocity = randf_range(40.0, 46.0)
		heart_pickup.bouncing = true
		get_parent().call_deferred("add_child", heart_pickup)

	$CollisionShape2D.set_deferred("disabled", true)
	
	if attack_area:
		attack_area.set_deferred("monitoring", false)  # Stop detecting player


	var death_animation = _get_death_animation()
	sprite.play(death_animation)

	
	await sprite.animation_finished

	
	_fade_out_and_remove()

func _get_death_animation() -> String:
	if last_vertical_direction == "up":
		return "death_up_left" if last_direction == "left" else "death_up_right"
	else:
		return "death_down_left" if last_direction == "left" else "death_down_right"
		
func _fade_out_and_remove():
	var fade_tween = get_tree().create_tween()
	fade_tween.tween_property(sprite, "modulate:a", 0.0, 1.5)  
	await fade_tween.finished
	queue_free()  
	
func _start_invincibility_effect():
	var blink_tween = get_tree().create_tween()
	blink_tween.set_loops(invincibility_time / (blink_timer * 2))
	blink_tween.tween_property(sprite, "modulate:a", 0.2, blink_timer)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, blink_timer)

func _stop_invincibility_effect():
	sprite.modulate.a = 1.0
	
func handle_wandering(delta: float) -> void:
	if dying:
		return

	
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
