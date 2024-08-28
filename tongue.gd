extends Node2D

var grapple_pos = null
# Called when the node enters the scene tree for the first time.
func _draw() -> void:
	if grapple_pos:
		var start = Vector2(0, 0)
		var diff = grapple_pos - self.global_position
		var rect = Rect2(0,0,diff.length(), 3)
		draw_set_transform(start, diff.angle())
		draw_rect(rect, Color.INDIAN_RED)

func _process(_delta):
	queue_redraw()
