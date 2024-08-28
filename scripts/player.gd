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
@export var grapple_force = 120
@export var tongue_length = 200

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
var grapple_pos = null  # Vector2

func calculate_grapple_pos():
	print("Calculating grapple pos")
	# TODO: Keep track of separate direction that doesn't get set to null (current solution is hacky)
	if $AnimatedSprite2D.flip_h:
		$TongueRay.target_position.x = -tongue_length
	else:
		$TongueRay.target_position.x = tongue_length
	
		
	if $TongueRay.is_colliding():
		var p = $TongueRay.get_collision_point()
		var diff = p - self.position
		if diff.length_squared() < 100:
			set_grapple_pos(null)
		else: 
			set_grapple_pos(p)
	else:
		set_grapple_pos(null)
	return grapple_pos
	
func set_grapple_pos(pos):
	grapple_pos = pos
	$Tongue.grapple_pos = pos
	
	
func update_charge(delta):
	if Input.is_action_pressed("ui_accept"):
		jump_charge = move_toward(jump_charge, 1, delta / charge_duration)
	else:
		jump_charge = 0
		
	if game_manager:
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
		set_flipped(true)
	elif direction == Direction.RIGHT:
		set_flipped(false)
	return direction
	
func touching_ground() -> bool:
	return floors_in_contact > 0
	
func set_flipped(flipped):
	$AnimatedSprite2D.flip_h = flipped
	if flipped:
		$Tongue.position.x = -abs($Tongue.position.x)
	else:
		$Tongue.position.x = abs($Tongue.position.x)

func jump():
	var impulse = lerpf(0, max_jump_impulse * mass, last_jump_charge)
	self.apply_impulse(Vector2(impulse * direction * cos(deg_to_rad(jump_angle)), -impulse), Vector2.ZERO)
	state = States.HOP

func idle_state(delta: float) -> void:
	if !touching_ground():
		state = States.HOP
		hop_state(delta)
		return
	
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
		print(Input.is_action_pressed("grapple"))
		if Input.is_action_pressed("grapple") && calculate_grapple_pos():
			state = States.GRAPPLE
			grapple_state(delta)
		
	
func grapple_state(delta):
	if grapple_pos == null:
		state = States.IDLE
		idle_state(delta)
		return
	
	var diff = (grapple_pos - self.position)
	if diff.length_squared() < 100 || !Input.is_action_pressed("grapple"):
		set_grapple_pos(null)
		state = States.IDLE
		idle_state(delta)
		return

	var force_vector = grapple_force * (grapple_pos - self.position)
	print(force_vector)
	apply_central_force(force_vector)

func process_state(delta):
	if state == States.IDLE:
		idle_state(delta)
	elif state == States.HOP:
		hop_state(delta)
	elif state == States.GRAPPLE:
		grapple_state(delta)
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
