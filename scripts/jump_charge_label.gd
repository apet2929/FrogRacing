extends RichTextLabel

@onready var game_manager = %GameManager

@export var charge_bar_length = 500 # pixels
@export var charge_bar_height = 30

# Collision: 
# Layer 1 is floor
# Layer 2 is player

func _draw(): 
	#draw_rect(Rect2(1.0, 1.0, 500, 3.0), Color.GREEN)
	var charge_bar_width = lerp(0, charge_bar_length, game_manager.jump_charge)
	var effective_charge_bar_width = lerp(0, charge_bar_length, game_manager.effective_jump_charge)
	var top_left = self.get_viewport_rect().position
	var charge_rect = Rect2(top_left.x + self.get_content_width() + 10, top_left.y, charge_bar_width, charge_bar_height)
	var effective_charge_rect = Rect2(top_left.x + self.get_content_width() + 10, top_left.y, effective_charge_bar_width, charge_bar_height)
	draw_rect(charge_rect, Color.GREEN)
	draw_rect(effective_charge_rect, Color.MEDIUM_PURPLE)

func _process(_delta):
	queue_redraw()
