extends Area2D

@onready var sound_waves = $sfx_waves
var players_inside := []

var fade_speed := 1.0  
var target_volume_db := 0  
var min_volume_db := -80  
var is_fading_in := false
var is_fading_out := false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body not in players_inside:
			players_inside.append(body)
		
		if not sound_waves.playing:
			sound_waves.volume_db = min_volume_db
			sound_waves.play()
			is_fading_in = true
		elif is_fading_out:
			is_fading_out = false
			is_fading_in = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		players_inside.erase(body)
		if players_inside.is_empty():
			is_fading_in = false
			is_fading_out = true

func _process(delta: float) -> void:
	if is_fading_in and sound_waves.playing:
		sound_waves.volume_db += fade_speed * delta * 10
		if sound_waves.volume_db >= target_volume_db:
			sound_waves.volume_db = target_volume_db
			is_fading_in = false

	elif is_fading_out and sound_waves.playing:
		sound_waves.volume_db -= fade_speed * delta * 10
		if sound_waves.volume_db <= min_volume_db:
			sound_waves.stop()
			sound_waves.volume_db = min_volume_db
			is_fading_out = false
