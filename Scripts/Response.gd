extends Label

@onready var timer = $Timer
@onready var audio = $Audio

func _ready():
	audio.playing = true
	self.visible_ratio = 0

func _on_timer_timeout():
	if self.visible_ratio != 1:
		self.visible_ratio += 0.05
	else:
		audio.playing = false
		timer.stop


func _on_audio_finished():
	audio.playing = true
