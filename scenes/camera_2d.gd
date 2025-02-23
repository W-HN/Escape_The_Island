extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


@export var pan_factor: float = 0.2      
@export var max_pan_distance: float = 10.0  
@export var pan_speed: float = 1.          

func _process(delta: float) -> void:
	
	#lerp to mouse
	var mouse_pos = get_global_mouse_position()
	var target_offset = (mouse_pos - global_position) * pan_factor

	if target_offset.length() > max_pan_distance:
		target_offset = target_offset.normalized() * max_pan_distance
	offset = offset.lerp(target_offset, pan_speed * delta)
