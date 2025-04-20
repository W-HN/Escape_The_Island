extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

@export var pan_factor: float = 0.3
@export var max_pan_distance: float = 40.0  # Max pixels the camera can be offset from the player
@export var pan_speed: float = 5.0          # Smoothness of camera movement

func _process(delta: float) -> void:
	if not is_instance_valid(get_parent()):
		return

	var player_pos = get_parent().global_position
	var mouse_pos = get_global_mouse_position()

	# Midpoint between player and mouse
	var midpoint = player_pos.lerp(mouse_pos, pan_factor)

	# Clamp camera position within max_pan_distance from the player
	var offset_from_player = midpoint - player_pos
	if offset_from_player.length() > max_pan_distance:
		offset_from_player = offset_from_player.normalized() * max_pan_distance

	var clamped_target = player_pos + offset_from_player

	# Smooth camera movement
	global_position = global_position.lerp(clamped_target, pan_speed * delta)
