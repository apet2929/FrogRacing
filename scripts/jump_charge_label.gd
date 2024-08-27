extends RichTextLabel

@onready var game_manager = %GameManager

@export var charge_bar_length = 500 # pixels
@export var charge_bar_height = 30
	#
#func _on_draw() -> void:
	#var c = game_manager.jump_charge
	#text = "Jump Charge:"
	#var bar_width = lerp(50, charge_bar_length, c)
	#var charge_rect = Rect2(self.global_position.x + self.get_content_width(), self.global_position.y, bar_width, self.get_theme_default_font_size())
	#draw_rect(charge_rect, Color.AQUAMARINE)
	#var r = Rect2(50, 50, 50, 50)
	#draw_rect(charge_rect, Color.AQUAMARINE)

func _draw(): 
	#draw_rect(Rect2(1.0, 1.0, 500, 3.0), Color.GREEN)
	var c = game_manager.jump_charge
	var bar_width = lerp(0, charge_bar_length, c)
	var top_left = self.get_viewport_rect().position
	var charge_rect = Rect2(top_left.x + self.get_content_width() + 10, top_left.y, bar_width, charge_bar_height)
	draw_rect(charge_rect, Color.GREEN)

func _process(_delta):
	queue_redraw()
