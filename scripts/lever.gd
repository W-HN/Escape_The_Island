extends Area2D

@export var is_on: bool = false
@export var connected_door: NodePath  # Drag in your Door node

@export var enemy_scene: PackedScene
@export var enemy_scene_2: PackedScene
@export var spawn_positions: Array[Vector2] = [
	Vector2(290, -800),
	Vector2(420, -1030),
	Vector2(400, -1050),
	Vector2(380, -1000),
	Vector2(820, -1020),
	Vector2(790, -990),
	Vector2(1100, -750),
	Vector2(1150, -730),
	Vector2(1050, -780)
	]
	
@export var spawn_positions_2: Array[Vector2] = [
	Vector2(790, -950),
	Vector2(1200, -1000),
	Vector2(1300, -1000),
	Vector2(1200, -700)
	]
@export var spawns_enemies: bool = false

@onready var sprite = $AnimatedSprite2D

func _ready():
	update_visual()

func toggle():
	if is_on:
		return
	is_on = !is_on
	update_visual()

	if connected_door:
		var door = get_node_or_null(connected_door)
		if door:
			door.call_deferred("set_open", is_on)
	if spawns_enemies:
		call_deferred("spawn_enemies")

func update_visual():
	if is_on:
		sprite.play("turn_on")
	else:
		sprite.play("turn_off")
		
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("attack"):
		toggle()

func spawn_enemies():
	for pos in spawn_positions:
		var enemy = enemy_scene.instantiate()
		enemy.global_position = pos
		get_tree().current_scene.add_child(enemy)
	for pos in spawn_positions_2:
		var enemy_2 = enemy_scene_2.instantiate()
		enemy_2.global_position = pos
		get_tree().current_scene.add_child(enemy_2)
