extends CharacterBody2D

@export var speed: float = 25.0
@export var follow_range: float = 100.0  
@export var invincibility_time: float = 0.3

@export var gold_pickup_scene: PackedScene
@export var heart_pickup_scene: PackedScene

@onready var attack_area = $AttackArea  
@onready var sprite = $AnimatedSprite2D

@export var attack_cooldown: float = 1.5
@export var projectile_scene: PackedScene = preload("res://scenes/mage_projectile.tscn")
@export var attack_range: float = 150.0  # max range to shoot

@export var wander_radius: float = 40.0
@export var wander_speed: float = 15.0
@export var wander_idle_min: float = 1.0
@export var wander_idle_max: float = 3.0
@export var wander_move_duration: float = 1.5

@export var reposition_radius: float = 30.0
@export var reposition_min_delay: float = 1.0
@export var reposition_max_delay: float = 2.5
var players: Array = []
var target: Node2D = null

var wander_target_position: Vector2
	
var knockback_velocity := Vector2.ZERO
const KNOCKBACK_DECAY := 2000.0 

var reposition_timer: float = 0.0
var combat_moving = false
var combat_target_position: Vector2

var combat_progress_timer: float = 0.0
var last_combat_distance: float = 0.0

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

var last_direction = "right" 
var last_vertical_direction = "down"  

func _ready():
	set_multiplayer_authority(1)
	spawn_position = global_position
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
	RandomNumberGenerator.new().seed = 12345

	start_idle_wandering() 

func _physics_process(delta):
	if dying:
		return

	# grab only actual Node2D players
	var players := []
	for obj in get_tree().get_nodes_in_group("Player"):
		if obj is Node2D:
			players.append(obj)
	if players.size() == 0:
		return

	target = players[0]
	var min_dist = global_position.distance_to(target.global_position)
	for p in players:
		var d = global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			target = p

	if knockback_velocity.length() > 0:
		knockback_velocity *= pow(0.5, 50.0 * delta)

	if is_attacking or min_dist <= attack_range:
		handle_combat_attack(delta)
	elif min_dist <= follow_range:
		handle_combat_chase(delta)
	else:
		handle_wandering(delta)


func handle_combat_attack(delta: float) -> void:
	is_wandering = false
	is_idle_wandering = false

	if is_attacking:
		velocity = Vector2.ZERO
		velocity += knockback_velocity
		move_and_slide()
		return

	if not combat_moving and not can_attack:
		reposition_timer -= delta
		if reposition_timer <= 0:
			pick_combat_reposition()

	if combat_moving:
		var move_vector = combat_target_position - global_position
		var distance = move_vector.length()
		
		if abs(distance - last_combat_distance) < 0.2:
			combat_progress_timer += delta
		else:
			combat_progress_timer = 0.0
		last_combat_distance = distance
		
		# If stuck >0.5s, abort and pick a new reposition
		if combat_progress_timer > 0.5:
			combat_moving = false
			combat_progress_timer = 0.0
			# Optional: Pick a new reposition target immediately or just wait for next cycle
			return

		if distance < 1.0:
			velocity = Vector2.ZERO
			velocity += knockback_velocity
			combat_moving = false
		else:
			velocity = move_vector.normalized() * speed
			velocity += knockback_velocity
		move_and_slide()

		if velocity.length() > 0:
			_play_walk_animation(velocity)
		else:
			face_player()
			_play_idle_animation()

	else:
		velocity = Vector2.ZERO
		velocity += knockback_velocity
		move_and_slide()
		face_player()
		_play_idle_animation()

		if can_attack:
			attack()

func perform_random_attack():
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	move_and_slide()

	var dir = (target.global_position - global_position).normalized()
	_play_attack_animation(dir)
	face_player()

	await sprite.animation_finished
	if dying:
		return

	var attack_type = randi() % 3 + 1
	match attack_type:
		1:
			spawn_cone_shot(dir)
		2:
			spawn_shotgun_burst(dir)
		3:
			spawn_dna_wave(dir)

	is_attacking = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func spawn_cone_shot(dir: Vector2):
	var angles = [-30, 0, 30]
	for angle_deg in angles:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		proj.direction = dir.rotated(deg_to_rad(angle_deg))
		proj.source = self
		proj.wave_strength = 4
		proj.wave_speed = 6

func spawn_shotgun_burst(dir: Vector2):
	for i in 4:
		var spread_angle = randf_range(-0.2, 0.2)
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		proj.direction = dir.rotated(spread_angle)
		proj.source = self

func spawn_dna_wave(dir: Vector2):
	for i in 3:
		var left = projectile_scene.instantiate()
		var right = projectile_scene.instantiate()
		get_parent().add_child(left)
		get_parent().add_child(right)
		left.global_position = global_position
		right.global_position = global_position
		left.direction = dir
		right.direction = dir
		left.wave_strength = 6
		right.wave_strength = 6
		left.wave_speed = 10
		right.wave_speed = 10
		left.wave_phase = 0.0
		right.wave_phase = PI
		left.source = self
		right.source = self
		await get_tree().create_timer(0.2).timeout

func handle_combat_chase(delta: float) -> void:
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * speed
	velocity += knockback_velocity
	move_and_slide()
	_play_walk_animation(direction)

func pick_combat_reposition():
	combat_target_position = global_position + Vector2(
		randf_range(-reposition_radius, reposition_radius),
		randf_range(-reposition_radius, reposition_radius)
	)
	combat_moving = true
	reposition_timer = randf_range(reposition_min_delay, reposition_max_delay)
	combat_progress_timer = 0.0
	last_combat_distance = global_position.distance_to(combat_target_position)

	
func attack():
	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO
	move_and_slide()

	var dir = (target.global_position - global_position).normalized()
	_play_attack_animation(dir)
	face_player()

	await sprite.animation_finished

	if dying:
		return

	var attack_type = randi() % 3
	match attack_type:
		0:
			rpc("fire_cone_shot", dir)
		1:
			rpc("fire_shotgun_shot", dir)
		2:
			rpc("fire_dna_shot", dir)

	is_attacking = false
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

@rpc('call_local', "reliable", "authority")
func fire_cone_shot(base_dir):
	var angles = [-30, 0, 30]
	for i in range(3):
		var p = projectile_scene.instantiate()
		p.global_position = global_position
		p.direction = base_dir.rotated(deg_to_rad(angles[i]))
		p.source = self
		p.wave_strength = 10.0
		p.wave_speed = 2.0
		p.wave_phase = (i - 1) * 0.3
		get_parent().add_child(p)

@rpc('call_local', "reliable", "authority")
func fire_shotgun_shot(base_dir):
	for i in range(4):
		var p = projectile_scene.instantiate()
		p.global_position = global_position
		var angle_offset = deg_to_rad(5)
		p.direction = base_dir.rotated(angle_offset)
		p.source = self
		p.wave_strength = 4.0
		p.wave_speed = 3.5
		p.wave_phase = randf_range(0.0, TAU)
		get_parent().add_child(p)

@rpc('call_local', "reliable", "authority")
func fire_dna_shot(base_dir):
	for i in range(3):
		await get_tree().create_timer(0.2).timeout
		for j in range(2):
			var p = projectile_scene.instantiate()
			p.global_position = global_position
			p.direction = base_dir
			p.source = self
			p.wave_strength = 80.0
			p.wave_speed = 2.0
			p.wave_phase = PI * j
			get_parent().add_child(p)


func face_player():
	var dir = (target.global_position - global_position).normalized()

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
		body.take_damage(global_position)  


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

@rpc('authority', 'reliable', 'call_local')
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
		attack_area.set_deferred("monitoring", false) 

	var death_animation = _get_death_animation()
	sprite.play(death_animation)


	await sprite.animation_finished


	_fade_out_and_remove()

func _get_death_animation() -> String:
	if last_direction == "left":
		return "death_left"
	else:
		return "death_right"
		
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

	if not is_wandering and not is_idle_wandering:
		if randf() < 0.5:
			start_idle_wandering()
		else:
			start_move_wandering()

	
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
