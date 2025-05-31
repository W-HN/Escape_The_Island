extends Camera2D

@export var pan_factor: float = 0.3
@export var max_pan_distance: float = 40.0  # Max pixels the camera can be offset from the player
@export var pan_speed: float = 5.0          # Smoothness of camera movement

var shake_strength: float = 0.0
var shake_decay: float = 8.0
var shake_offset: Vector2 = Vector2.ZERO

func shake(amount: float):
	shake_strength = max(shake_strength, amount)

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

	# --- Screen shake effect ---
	if shake_strength > 0.01:
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength
		global_position += shake_offset
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
