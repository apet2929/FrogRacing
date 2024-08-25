extends RigidBody2D

enum States {
	IDLE,
	HOP,
	GRAPPLE
}
enum Direction {
	LEFT=-1,
	RIGHT=1,
	NONE=0
}

@export var max_jump_impulse = 3000
@export var hop_impulse = 500
@export var charge_duration = 1
@export var air_control = 50
@export var jump_angle = 45

@onready var game_manager = %GameManager

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var state = States.IDLE
var direction = Direction.NONE
var touched_ground_last_frame = false
var floors_in_contact = 0
var last_jump = -1
var jump_charge = 0
var last_jump_charge = 0 



func update_charge(delta):
	if Input.is_action_pressed("ui_accept"):
		jump_charge = move_toward(jump_charge, 1, delta / charge_duration)
	else:
		jump_charge = 0
	game_manager.jump_charge = jump_charge
	return jump_charge

func update_direction() -> int:
	var d := Input.get_axis("ui_left", "ui_right")
	if d == 1:
		direction = Direction.RIGHT
	elif d == -1:
		direction = Direction.LEFT
	elif d == 0:
		direction = Direction.NONE
		
	if direction == Direction.LEFT:
		$AnimatedSprite2D.flip_h = true
	elif direction == Direction.RIGHT:
		$AnimatedSprite2D.flip_h = false
	return direction
	
func touching_ground() -> bool:
	return floors_in_contact > 0

func jump():
	var impulse = lerpf(0, max_jump_impulse * mass, last_jump_charge)
	self.apply_impulse(Vector2(impulse * direction * cos(deg_to_rad(jump_angle)), -impulse), Vector2.ZERO)
	state = States.HOP

func idle_state(delta: float) -> void:
	if last_jump_charge != 0 && jump_charge == 0:
		jump()
	elif jump_charge == 0 && direction != Direction.NONE:
		state = States.HOP
		hop_state(delta)
	
func hop_state(delta):
	if touching_ground() && jump_charge == 0:
		if direction == Direction.NONE:
			state = States.IDLE
		elif last_jump == -1:
			var impulse = Vector2(hop_impulse * mass * direction * 0.5, -hop_impulse * mass)
			self.apply_impulse(impulse, Vector2.ZERO)
			last_jump = 0
	elif touching_ground():
		state = States.IDLE
	else:
		apply_central_force(Vector2(air_control * mass * direction, 0))
	


func process_state(delta):
	if state == States.IDLE:
		idle_state(delta)
	elif state == States.HOP:
		hop_state(delta)
	else:
		pass

func _physics_process(delta: float) -> void:
	last_jump_charge = jump_charge
	update_charge(delta)
	update_direction()
	
	process_state(delta)

	if last_jump != -1:
		last_jump += delta

func _on_body_entered(body: Node) -> void:
	last_jump = -1
	floors_in_contact += 1


func _on_body_exited(body: Node) -> void:
	floors_in_contact -= 1
