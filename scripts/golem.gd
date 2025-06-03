extends CharacterBody2D

@export var speed: float = 22.0
@export var follow_range: float = 200.0
@export var dash_speed: float = 180.0 
@export var dash_duration: float = 0.4
@export var dash_cooldown: float = 2.0
@export var bounce_strength: float = 1000.0
@export var dash_player_knockback: float = 100000.0

@export var stun_duration: float = 3.0
@export var telegraph_duration: float = 1.0

@export var invincibility_time: float = 0.5
@export var health: int = 8

@export var gold_pickup_scene: PackedScene
@export var heart_pickup_scene: PackedScene

@onready var attack_area = $AttackArea
@onready var sprite = $AnimatedSprite2D

@onready var sound_block = $sfx_block
@onready var sound_hit = $sfx_hit
@onready var sound_dong = $sfx_dong

var player: Node2D = null

enum State { IDLE, CHASING, TELEGRAPH, DASHING, STUNNED }
var state = State.IDLE

var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var telegraph_timer: float = 0.0
var telegraph_tween: Tween = null

var stun_timer: float = 0.0
var reset_dash_cooldown_on_unstun : bool = false
var dying: bool = false
var is_invincible: bool = false
var blink_timer: float = 0.06

var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_DECAY: float = 2000.0

var last_direction: String = "right"
var last_vertical_direction: String = "down"

func _ready():
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(delta):
	if dying:
		return
		
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")

	knockback_velocity *= pow(0.5, 50.0 * delta)
	var base_velocity: Vector2 = Vector2.ZERO

	match state:
		State.STUNNED:
			stun_timer -= delta
			velocity = knockback_velocity
			if stun_timer <= 0.0:
				state = State.IDLE
				_stop_telegraph_blink()
				if reset_dash_cooldown_on_unstun:
					dash_cooldown_timer = dash_cooldown  # Reset the dash cooldown!
					reset_dash_cooldown_on_unstun = false
			_play_stun_animation()
		State.TELEGRAPH:
			telegraph_timer -= delta
			_play_walk_animation(dash_direction)
			velocity = knockback_velocity
			if telegraph_timer <= 0.0:
				_stop_telegraph_blink()
				state = State.DASHING
				dash_timer = dash_duration
		State.DASHING:
			dash_timer -= delta
			velocity = dash_direction * dash_speed + knockback_velocity
			_play_walk_animation(dash_direction)
			if dash_timer <= 0.0:
				state = State.CHASING
				dash_cooldown_timer = dash_cooldown
		State.CHASING:
			if is_instance_valid(player):
				var to_player = (player.global_position - global_position)
				if to_player.length() <= follow_range:
					if dash_cooldown_timer <= 0.0:
						state = State.TELEGRAPH
						dash_direction = to_player.normalized()
						telegraph_timer = telegraph_duration
						_start_telegraph_blink()
					else:
						dash_cooldown_timer -= delta
						base_velocity = to_player.normalized() * speed
						_play_walk_animation(base_velocity)
				else:
					state = State.IDLE
					_play_idle_animation()
			else:
				state = State.IDLE
				_play_idle_animation()
			velocity = base_velocity + knockback_velocity
		State.IDLE:
			if is_instance_valid(player):
				var to_player = (player.global_position - global_position)
				if to_player.length() <= follow_range:
					state = State.CHASING
				else:
					_play_idle_animation()
			else:
				_play_idle_animation()
			velocity = knockback_velocity

	var was_dashing = (state == State.DASHING)
	move_and_slide()

	if was_dashing and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var other = collision.get_collider()
			if other and not other.is_in_group("Player"):
				_enter_stun()
				break

func _start_telegraph_blink():
	if telegraph_tween:
		telegraph_tween.kill()
	telegraph_tween = get_tree().create_tween()
	telegraph_tween.set_loops(int(telegraph_duration / 0.2))
	telegraph_tween.tween_property(sprite, "modulate", Color(2, 2, 0, 1), 0.1)  # Super Yellow
	telegraph_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)  # White

func _stop_telegraph_blink():
	if telegraph_tween:
		telegraph_tween.kill()
	sprite.modulate = Color(1,1,1,1)
	telegraph_tween = null

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var direction = (body.global_position - global_position).normalized()
		if state == State.STUNNED:
			if body.has_method("apply_knockback"):
				body.apply_knockback(direction * 500)
			return
		if state == State.DASHING:
			body.take_damage(global_position)
			if body.has_method("apply_knockback"):
				body.apply_knockback(direction * dash_player_knockback)
		else:
			body.take_damage(global_position)

func _play_walk_animation(direction: Vector2) -> void:
	if direction.y < 0:
		last_vertical_direction = "up"
		if direction.x < 0:
			last_direction = "left"
			sprite.play("walk_up_left")
		else:
			last_direction = "right"
			sprite.play("walk_up_right")
	elif direction.y > 0:
		last_vertical_direction = "down"
		if direction.x < 0:
			last_direction = "left"
			sprite.play("walk_down_left")
		else:
			last_direction = "right"
			sprite.play("walk_down_right")
	else:
		if last_vertical_direction == "up":
			if direction.x < 0:
				last_direction = "left"
				sprite.play("walk_up_left")
			else:
				last_direction = "right"
				sprite.play("walk_up_right")
		else:
			if direction.x < 0:
				last_direction = "left"
				sprite.play("walk_down_left")
			else:
				last_direction = "right"
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

func _play_stun_animation() -> void:
	if last_vertical_direction == "up":
		if last_direction == "left":
			sprite.play("stun_up_left")
		else:
			sprite.play("stun_up_right")
	else:
		if last_direction == "left":
			sprite.play("stun_down_left")
		else:
			sprite.play("stun_down_right")

func _enter_stun():
	sound_dong.play()
	state = State.STUNNED
	stun_timer = stun_duration
	velocity = Vector2.ZERO
	_stop_telegraph_blink()
	reset_dash_cooldown_on_unstun = true
	if dash_direction.length() > 0.1:
		knockback_velocity = -dash_direction.normalized() * bounce_strength
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(16.0) 

func take_damage_knockback(amount: int, attacker_position: Vector2):
	if dying or is_invincible:
		return
	if state != State.STUNNED:
		sprite.modulate = Color(0.7, 0.7, 0.7, 1)
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.has_method("apply_knockback"):
			var direction = (player.global_position - global_position).normalized()
			player.apply_knockback(direction * 600)
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color(1,1,1,1)
		sound_block.play()
		return

	var weak_dir = get_weak_spot_direction()
	if not is_in_weak_spot(attacker_position, weak_dir, 60.0):
		sprite.modulate = Color(0.7, 0.7, 0.7, 1)
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.has_method("apply_knockback"):
			var direction = (player.global_position - global_position).normalized()
			player.apply_knockback(direction * 600)
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color(1,1,1,1)
		sound_block.play()
		return

	sound_hit.play()
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
	pass

func die():
	if dying:
		return
	dying = true
	velocity = Vector2.ZERO
	_stop_telegraph_blink()

	if gold_pickup_scene:
		var num_gold = randi_range(20, 30)
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
		attack_area.set_deferred("monitoring", false)

	var death_animation = _get_death_animation()
	sprite.play(death_animation)
	await sprite.animation_finished
	_fade_out_and_remove()
	
	await get_tree().create_timer(1.0).timeout
	
	var end_message_control = get_tree().current_scene.get_node("EndMessage/Control")
	var end_message = get_tree().current_scene.get_node("EndMessage")
	if end_message_control:
		end_message.visible = true
		end_message_control.visible = true
		get_tree().paused = true


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

		
func get_weak_spot_direction() -> Vector2:
	match sprite.animation:
		"stun_down_left":
			return Vector2(1, -1).normalized()
		"stun_down_right":
			return Vector2(-1, -1).normalized()
		"stun_up_left":
			return Vector2(1, 1).normalized()
		"stun_up_right":
			return Vector2(-1, 1).normalized()
	return Vector2.ZERO

func is_in_weak_spot(attack_position: Vector2, weak_spot_direction: Vector2, tolerance_degrees: float = 60.0) -> bool:
	var to_attack = (attack_position - global_position).normalized()
	var dot = to_attack.dot(weak_spot_direction)
	var angle_between = acos(dot)
	return abs(rad_to_deg(angle_between)) <= tolerance_degrees
