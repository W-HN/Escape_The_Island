extends Area2D

@export var bush: Texture2D = preload("res://assets/objects/bush.png")
@export var bush_cut: Texture2D = preload("res://assets/objects/bush_cut.png")
@export var gold_pickup_scene: PackedScene
@export var heart_pickup_scene: PackedScene

var rng := RandomNumberGenerator.new()
var is_cut = false

func _ready():
	$Sprite2D.texture = bush
	set_multiplayer_authority(1)


# any client calls this; only the authority actually runs the RNG
@rpc("authority", "call_local", "reliable")
func request_cut():
	if is_cut:
		return

	#auth only
	rng.seed = randi()
	# how many gold? 0–1
	var gold_count = rng.randi_range(0, 1)
	var gold_datas = []
	for i in range(gold_count):
		gold_datas.append({
			"angle": rng.randf_range(0, TAU),
			"speed": rng.randf_range(20, 30),
		})

	# heart 1-in-5 chance
	var heart_drop = rng.randi_range(1, 5) == 1
	var heart_data = {"drop": heart_drop}
	if heart_drop:
		heart_data.angle = rng.randf_range(0, TAU)
		heart_data.speed = rng.randf_range(20, 30)
		heart_data.bounce = rng.randf_range(40.0, 46.0)

	# broadcast spawn data to everyone
	rpc("cut_bush", gold_datas, heart_data)

# everyone runs this with identical data
@rpc("any_peer", "reliable", "call_local")
func cut_bush(gold_datas: Array, heart_data: Dictionary) -> void:
	if is_cut:
		return
	is_cut = true

	#swap sprite and play particles
	$Sprite2D.texture = bush_cut
	$Sprite2D.z_index = -1
	for p in [$Bp1, $Bp2, $Bp3, $Bp4, $Bp5, $Bp6]:
		p.restart()

	# spawn gold
	for data in gold_datas:
		var gold = gold_pickup_scene.instantiate()
		gold.position = position
		gold.velocity = Vector2.RIGHT.rotated(data.angle) * data.speed
		get_parent().call_deferred("add_child", gold)

	# spawn heart if any
	if heart_data.drop and heart_pickup_scene:
		var heart = heart_pickup_scene.instantiate()
		heart.position = position
		heart.velocity = Vector2.RIGHT.rotated(heart_data.angle) * heart_data.speed
		heart.bounce_velocity = heart_data.bounce
		heart.bouncing = true
		get_parent().call_deferred("add_child", heart)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		# ask the authority to cut & distribute spawn data
		rpc_id(1, "request_cut")
