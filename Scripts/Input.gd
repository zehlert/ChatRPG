extends LineEdit

@onready var timer = $"../MarginContainer/Timer"
var dice_count

# Called when the node enters the scene tree for the first time.
func _ready():
	grab_focus()
	

func _on_text_submitted(new_text):
	clear()


func _on_button_button_down():
	dice_count = 20
	timer.start()
	
	
func _on_timer_timeout():
	if dice_count > 0:
		var rng = RandomNumberGenerator.new()
		var random_number = rng.randf_range(1, 21)
		var random_int = int(random_number)
		self.text = str(random_int)
		dice_count -= 1
	else:
		grab_focus()
		timer.stop()
