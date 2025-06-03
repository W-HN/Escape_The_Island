extends RigidBody2D

@export var box_texture: Texture2D      # Whole box
@export var box_chunk_particles: Array  # Array of GPUParticles2D nodes
@export var gold_pickup_scene: PackedScene
@export var heart_pickup_scene: PackedScene

# single RNG we’ll use on the authority
var rng := RandomNumberGenerator.new()

var is_broken = false

func _ready():
	$Sprite2D.texture = box_texture
	set_multiplayer_authority(1)
	$Area2D.area_entered.connect(_on_area_entered)

@rpc("authority", "call_local", "reliable")
func request_break():
	if is_broken:
		return

	#uth only
	rng.seed = randi()  
	var gold_count = rng.randi_range(1, 3)
	var gold_datas = []
	for i in range(gold_count):
		gold_datas.append({
			"angle": rng.randf_range(0, TAU),
			"speed": rng.randf_range(20, 30),
		})
	var heart_drop = rng.randi_range(1, 5) == 1
	var heart_data = { "drop": heart_drop }
	if heart_drop:
		heart_data.angle = rng.randf_range(0, TAU)
		heart_data.speed = rng.randf_range(20, 30)
		heart_data.bounce = rng.randf_range(40.0, 46.0)

	rpc("break_box", gold_datas, heart_data)

@rpc("any_peer", "reliable", "call_local")
func break_box(gold_datas:Array, heart_data:Dictionary) -> void:
	if is_broken:
		return
	is_broken = true


	$Sprite2D.hide()
	$CollisionShape2D.set_deferred("disabled", true)
	for p in box_chunk_particles:
		p.restart()


	for data in gold_datas:
		var gold = gold_pickup_scene.instantiate()
		gold.position = position
		gold.velocity = Vector2.RIGHT.rotated(data.angle) * data.speed
		get_parent().call_deferred("add_child", gold)


	if heart_data.drop and heart_pickup_scene:
		var heart = heart_pickup_scene.instantiate()
		heart.position = position
		heart.velocity = Vector2.RIGHT.rotated(heart_data.angle) * heart_data.speed
		heart.bounce_velocity = heart_data.bounce
		heart.bouncing = true
		get_parent().call_deferred("add_child", heart)


	await get_tree().create_timer(1.0).timeout
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		# request the authority to break & distribute spawn data
		rpc_id(1, "request_break") 
