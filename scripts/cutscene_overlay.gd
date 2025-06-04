extends Control

@export var story_texts := [
	"Amid uncharted waters a storm descends and soon nothing remains of your ship.",
	"You drift unconscious into uncharted waters, washing ashore on a mysterious island.",
	"Armed with only your trusty sword and newfound powers, you awaken to a land crawling with hostile creatures.",
	"Thunderous stomping echoes from the northeast, its source unknown. Whatever lies there may hold the key to your escape.",
	"Danger lies ahead, but so do discoveries that may reveal your path..."
]

@onready var sound_button := $sfx_button
@onready var label := $RichTextLabel

var idx := 0

func _ready():
	sound_button.process_mode = Node.PROCESS_MODE_ALWAYS  
	label.text = story_texts[idx]
	get_tree().paused = true

func _on_texture_button_pressed() -> void:
	sound_button.play()
	idx += 1
	if idx < story_texts.size():
		label.text = story_texts[idx]
	else:
		get_tree().paused = false
		visible = false
