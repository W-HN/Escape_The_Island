extends Area2D

@export var speed: float = 100.0
@export var direction: Vector2 = Vector2.RIGHT
@export var lifetime: float = 2.0
@export var damage: int = 1
@export var knockback_force: float = 500.0

var stage: int = 1
const MAX_STAGE := 3

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

func _ready():
	set_multiplayer_authority(1)
	add_to_group("attack")
	_update_stage_visuals()
	timer.wait_time = lifetime
	timer.start()
	connect("body_entered", _on_body_entered)
	$CollisionShape2D.disabled = false

func _process(delta):
	position += direction * speed * delta
	sprite.rotation += delta * 10

func _on_timer_timeout():
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		if body.has_method("apply_knockback"):
			apply_knockback(body)
		if body.has_method("take_damage"):
			body.take_damage.rpc(damage * stage)  # optional scale by stage
	queue_free()

func apply_knockback(enemy):
	var dir = (enemy.global_position - global_position).normalized()
	enemy.apply_knockback(dir * knockback_force)

func reflect(new_direction: Vector2) -> void:
	direction = new_direction.normalized()
	if stage < MAX_STAGE:
		stage += 1
		damage += 1
		speed += 10
	_update_stage_visuals()
	timer.start()  # reset lifetime

# ─── helper to pick the right animation ───
func _update_stage_visuals() -> void:
	var name = "fireball_stage_%d" % stage
	sprite.play(name)
