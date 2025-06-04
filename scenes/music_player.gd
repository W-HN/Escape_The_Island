extends Node

@onready var omphTheme = $omphTheme  
@onready var cozyTheme = $cozyTheme  
@onready var birdChirps = $sfx_chirps
@onready var chirpTimer = $ChirpTimer

var themes := []

func _ready():
	themes = [omphTheme, cozyTheme]
	omphTheme.play()

	_start_chirp_timer()


func _play_random_theme():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var idx = rng.randi_range(0, themes.size() - 1)
	var picked = themes[idx]


	for t in themes:
		if t.playing:
			t.stop()

	picked.play()


func _on_cozy_theme_finished() -> void:
	_play_random_theme()


func _on_omph_theme_finished() -> void:
	_play_random_theme()


func _start_chirp_timer():
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var next_delay = rng.randf_range(5.0, 20.0)
	chirpTimer.wait_time = next_delay
	chirpTimer.one_shot = true
	chirpTimer.start()

func _on_chirp_timer_timeout() -> void:
	
	if not birdChirps.playing:
		birdChirps.play()

	_start_chirp_timer()
