extends Area2D

@onready var sprite = $Sprite2D
@onready var magnet_area = $MagnetArea2D
@onready var sound_getmoney = $sfx_getmoney

var velocity := Vector2.ZERO
var friction := 18.0
var magnet_active := false
var player_ref : CharacterBody2D = null

var bounce_offset := 0.0
var bounce_velocity := 0.0
var bouncing := true

var magnet_grace_time := 0.25 
var magnet_timer := 0.0
var magnet_pending := false

const BOUNCE_INITIAL = 40.0
const BOUNCE_GRAVITY = 120.0
const BOUNCE_DAMPING = 0.55

const MAGNET_SPEED = 100.0

func _ready():
	bounce_velocity = randf_range(BOUNCE_INITIAL, BOUNCE_INITIAL * 1.15)
	bouncing = true
	magnet_area.connect("body_entered", _on_magnet_body_entered)
	magnet_area.connect("body_exited", _on_magnet_body_exited)

func _physics_process(delta):
	if magnet_pending and player_ref:
		magnet_timer += delta
		if magnet_timer >= magnet_grace_time:
			magnet_active = true
			magnet_pending = false

	if magnet_active and player_ref:
		var direction = (player_ref.global_position - global_position).normalized()
		velocity = direction * MAGNET_SPEED
		position += velocity * delta
	else:
		if bouncing:
			position += velocity * delta
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			bounce_offset += bounce_velocity * delta
			bounce_velocity -= BOUNCE_GRAVITY * delta
			if bounce_offset < 0.0:
				bounce_offset = 0.0
				if abs(bounce_velocity) < 7.0:
					bouncing = false
					bounce_velocity = 0.0
					velocity = Vector2.ZERO
				else:
					bounce_velocity = -bounce_velocity * BOUNCE_DAMPING
			sprite.position.y = -bounce_offset
		else:
			sprite.position.y = 0

func _on_body_entered(body):
	if body.is_in_group("Player"):
		var game = get_tree().root.get_node("Game")
		game.add_gold(1)
		queue_free()

func _on_magnet_body_entered(body):
	if body.is_in_group("Player"):
		magnet_pending = true
		magnet_timer = 0.0
		player_ref = body


func _on_magnet_body_exited(body):
	if body == player_ref:
		magnet_active = false
		magnet_pending = false
		player_ref = null
		magnet_timer = 0.0
