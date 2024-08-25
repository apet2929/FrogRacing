extends RichTextLabel

@onready var game_manager = %GameManager

func _process(delta: float) -> void:
	var c = game_manager.jump_charge
	text = "Jump Charge: %.2f" % c
	
